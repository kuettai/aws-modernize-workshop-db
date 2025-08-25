-- =============================================
-- Weekly Batch Job 3: Customer Analytics Report (PostgreSQL)
-- Runs weekly to populate weekly_customer_analytics table
-- Analyzes customer segments, payment behavior, and risk profiles
-- =============================================

DO $$
DECLARE
    v_report_week DATE := DATE_TRUNC('week', CURRENT_DATE - INTERVAL '1 week') + INTERVAL '1 day'; -- Monday of previous week
    v_week_end DATE := v_report_week + INTERVAL '6 days'; -- Sunday of previous week
    v_execution_id BIGINT;
    v_records_processed INTEGER := 0;
    v_records_inserted INTEGER := 0;
    v_start_time TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    -- Start job logging
    SELECT start_batch_job(
        'Weekly Customer Analytics',
        'Weekly',
        v_report_week
    ) INTO v_execution_id;

    RAISE NOTICE '=== WEEKLY CUSTOMER ANALYTICS BATCH JOB ===';
    RAISE NOTICE 'Processing Week: % to %', v_report_week, v_week_end;
    RAISE NOTICE 'ExecutionId: %', v_execution_id;
    RAISE NOTICE '';

    -- Clear existing data for this week (if re-running)
    DELETE FROM weekly_customer_analytics WHERE report_week = v_report_week;
    RAISE NOTICE 'Cleared existing data for week of %', v_report_week;

    -- Customer Segmentation Analysis
    WITH customer_segments AS (
        SELECT 
            c.customer_id,
            c.first_name || ' ' || c.last_name AS customer_name,
            c.monthly_income,
            c.employment_status,
            CASE 
                WHEN c.monthly_income >= 100000 THEN 'High Income (100K+)'
                WHEN c.monthly_income >= 75000 THEN 'Upper Middle (75K-100K)'
                WHEN c.monthly_income >= 50000 THEN 'Middle Income (50K-75K)'
                WHEN c.monthly_income >= 35000 THEN 'Lower Middle (35K-50K)'
                ELSE 'Low Income (<35K)'
            END AS income_segment,
            CASE 
                WHEN EXTRACT(YEAR FROM AGE(c.date_of_birth)) >= 65 THEN 'Senior (65+)'
                WHEN EXTRACT(YEAR FROM AGE(c.date_of_birth)) >= 45 THEN 'Middle Age (45-64)'
                WHEN EXTRACT(YEAR FROM AGE(c.date_of_birth)) >= 30 THEN 'Young Adult (30-44)'
                ELSE 'Young (18-29)'
            END AS age_segment,
            -- Combine income and age for detailed segmentation
            CASE 
                WHEN c.monthly_income >= 75000 AND EXTRACT(YEAR FROM AGE(c.date_of_birth)) BETWEEN 30 AND 55 THEN 'Prime Customers'
                WHEN c.monthly_income >= 50000 AND EXTRACT(YEAR FROM AGE(c.date_of_birth)) >= 45 THEN 'Established Professionals'
                WHEN c.monthly_income < 35000 OR EXTRACT(YEAR FROM AGE(c.date_of_birth)) < 25 THEN 'High Risk'
                WHEN c.employment_status = 'Self-Employed' THEN 'Self-Employed'
                WHEN c.employment_status = 'Retired' THEN 'Retirees'
                ELSE 'Standard Customers'
            END AS customer_segment
        FROM customers c
        WHERE c.is_active = true
    ),
    application_data AS (
        SELECT 
            cs.*,
            COUNT(a.application_id) AS total_applications,
            COUNT(CASE WHEN a.application_status = 'Approved' THEN 1 END) AS approved_applications,
            AVG(a.credit_score::NUMERIC) AS avg_credit_score,
            AVG(a.requested_amount) AS avg_loan_amount
        FROM customer_segments cs
        LEFT JOIN applications a ON cs.customer_id = a.customer_id 
            AND a.submission_date >= v_report_week 
            AND a.submission_date <= v_week_end
            AND a.is_active = true
        GROUP BY cs.customer_id, cs.customer_name, cs.monthly_income, cs.employment_status, 
                 cs.income_segment, cs.age_segment, cs.customer_segment
    ),
    payment_data AS (
        SELECT 
            ad.*,
            COUNT(p.payment_id) AS total_payments,
            SUM(p.payment_amount) AS total_payment_amount,
            AVG(p.payment_amount) AS avg_payment_amount,
            COUNT(CASE WHEN p.payment_status = 'Failed' THEN 1 END) AS failed_payments
        FROM application_data ad
        LEFT JOIN applications a ON ad.customer_id = a.customer_id AND a.is_active = true
        LEFT JOIN loans l ON a.application_id = l.application_id
        LEFT JOIN payments p ON l.loan_id = p.loan_id 
            AND p.payment_date >= v_report_week 
            AND p.payment_date <= v_week_end
        GROUP BY ad.customer_id, ad.customer_name, ad.monthly_income, ad.employment_status,
                 ad.income_segment, ad.age_segment, ad.customer_segment, ad.total_applications,
                 ad.approved_applications, ad.avg_credit_score, ad.avg_loan_amount
    ),
    segment_summary AS (
        SELECT 
            customer_segment,
            COUNT(DISTINCT customer_id) AS customer_count,
            SUM(total_applications) AS total_applications,
            CASE 
                WHEN SUM(total_applications) > 0 
                THEN ROUND((SUM(approved_applications) * 100.0 / SUM(total_applications))::NUMERIC, 2)
                ELSE 0 
            END AS approval_rate,
            ROUND(AVG(avg_credit_score)::NUMERIC, 0) AS avg_credit_score,
            ROUND(AVG(monthly_income)::NUMERIC, 2) AS avg_monthly_income,
            ROUND(AVG(avg_loan_amount)::NUMERIC, 2) AS avg_loan_amount,
            COALESCE(SUM(total_payment_amount), 0) AS total_payments_made,
            ROUND(AVG(avg_payment_amount)::NUMERIC, 2) AS avg_payment_amount,
            CASE 
                WHEN SUM(total_payments) > 0 
                THEN ROUND((SUM(failed_payments) * 100.0 / SUM(total_payments))::NUMERIC, 2)
                ELSE 0 
            END AS default_rate
        FROM payment_data
        GROUP BY customer_segment
    )
    INSERT INTO weekly_customer_analytics (
        report_week,
        customer_segment,
        customer_count,
        total_applications,
        approval_rate,
        avg_credit_score,
        avg_monthly_income,
        avg_loan_amount,
        total_payments_made,
        avg_payment_amount,
        default_rate
    )
    SELECT 
        v_report_week,
        customer_segment,
        customer_count,
        total_applications,
        approval_rate,
        avg_credit_score,
        avg_monthly_income,
        avg_loan_amount,
        total_payments_made,
        avg_payment_amount,
        default_rate
    FROM segment_summary;

    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    RAISE NOTICE 'Inserted % customer segment analytics records.', v_records_inserted;

    -- Display Customer Segment Analysis
    RAISE NOTICE '';
    RAISE NOTICE 'CUSTOMER SEGMENT ANALYSIS:';
    RAISE NOTICE '=========================';

    FOR rec IN (
        SELECT 
            customer_segment,
            customer_count,
            total_applications,
            approval_rate,
            avg_credit_score,
            avg_monthly_income,
            avg_loan_amount,
            total_payments_made,
            avg_payment_amount,
            default_rate
        FROM weekly_customer_analytics 
        WHERE report_week = v_report_week
        ORDER BY customer_count DESC
    ) LOOP
        RAISE NOTICE 'Segment: % - Customers: %, Apps: %, Rate: %%, Credit: %, Income: %, Default: %%',
            rec.customer_segment,
            rec.customer_count,
            rec.total_applications,
            rec.approval_rate,
            rec.avg_credit_score,
            rec.avg_monthly_income,
            rec.default_rate;
    END LOOP;

    -- Risk Analysis by Segment
    RAISE NOTICE '';
    RAISE NOTICE 'RISK ANALYSIS BY SEGMENT:';
    RAISE NOTICE '========================';

    FOR rec IN (
        SELECT 
            customer_segment,
            CASE 
                WHEN default_rate >= 10 THEN 'High Risk'
                WHEN default_rate >= 5 THEN 'Medium Risk'
                WHEN default_rate >= 2 THEN 'Low Risk'
                ELSE 'Very Low Risk'
            END AS risk_level,
            default_rate,
            approval_rate,
            avg_credit_score,
            customer_count,
            CASE 
                WHEN default_rate >= 10 THEN 'Tighten approval criteria'
                WHEN default_rate >= 5 THEN 'Enhanced monitoring required'
                WHEN approval_rate < 50 THEN 'Review approval process'
                ELSE 'Continue current strategy'
            END AS recommendation
        FROM weekly_customer_analytics 
        WHERE report_week = v_report_week
        ORDER BY default_rate DESC
    ) LOOP
        RAISE NOTICE 'Segment: % - Risk: % (%%%) - Customers: % - Recommendation: %',
            rec.customer_segment,
            rec.risk_level,
            rec.default_rate,
            rec.customer_count,
            rec.recommendation;
    END LOOP;

    -- Top Performing Segments
    RAISE NOTICE '';
    RAISE NOTICE 'TOP PERFORMING SEGMENTS (High Volume + Low Risk):';
    RAISE NOTICE '===============================================';

    FOR rec IN (
        SELECT 
            customer_segment,
            customer_count,
            total_applications,
            approval_rate,
            default_rate,
            total_payments_made,
            ROUND(((approval_rate * 0.4) + ((100 - default_rate) * 0.4) + 
                   (CASE WHEN customer_count >= 100 THEN 20 ELSE customer_count * 0.2 END))::NUMERIC, 2) AS performance_score
        FROM weekly_customer_analytics 
        WHERE report_week = v_report_week
            AND customer_count >= 10  -- Minimum volume threshold
        ORDER BY performance_score DESC
    ) LOOP
        RAISE NOTICE 'Segment: % - Score: % - Customers: %, Apps: %, Rate: %%, Default: %%',
            rec.customer_segment,
            rec.performance_score,
            rec.customer_count,
            rec.total_applications,
            rec.approval_rate,
            rec.default_rate;
    END LOOP;

    -- New Customer Acquisition Analysis
    RAISE NOTICE '';
    RAISE NOTICE 'NEW CUSTOMER ACQUISITION (This Week):';
    RAISE NOTICE '====================================';

    FOR rec IN (
        SELECT 
            CASE 
                WHEN c.monthly_income >= 75000 AND EXTRACT(YEAR FROM AGE(c.date_of_birth)) BETWEEN 30 AND 55 THEN 'Prime Customers'
                WHEN c.monthly_income >= 50000 AND EXTRACT(YEAR FROM AGE(c.date_of_birth)) >= 45 THEN 'Established Professionals'
                WHEN c.monthly_income < 35000 OR EXTRACT(YEAR FROM AGE(c.date_of_birth)) < 25 THEN 'High Risk'
                WHEN c.employment_status = 'Self-Employed' THEN 'Self-Employed'
                WHEN c.employment_status = 'Retired' THEN 'Retirees'
                ELSE 'Standard Customers'
            END AS customer_segment,
            COUNT(*) AS new_customers,
            ROUND(AVG(c.monthly_income)::NUMERIC, 0) AS avg_income,
            COUNT(a.application_id) AS immediate_applications,
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND((COUNT(a.application_id) * 100.0 / COUNT(*))::NUMERIC, 2)
                ELSE 0 
            END AS application_rate
        FROM customers c
        LEFT JOIN applications a ON c.customer_id = a.customer_id 
            AND a.submission_date >= v_report_week 
            AND a.submission_date <= v_week_end
        WHERE c.created_date >= v_report_week 
            AND c.created_date <= v_week_end
            AND c.is_active = true
        GROUP BY 
            CASE 
                WHEN c.monthly_income >= 75000 AND EXTRACT(YEAR FROM AGE(c.date_of_birth)) BETWEEN 30 AND 55 THEN 'Prime Customers'
                WHEN c.monthly_income >= 50000 AND EXTRACT(YEAR FROM AGE(c.date_of_birth)) >= 45 THEN 'Established Professionals'
                WHEN c.monthly_income < 35000 OR EXTRACT(YEAR FROM AGE(c.date_of_birth)) < 25 THEN 'High Risk'
                WHEN c.employment_status = 'Self-Employed' THEN 'Self-Employed'
                WHEN c.employment_status = 'Retired' THEN 'Retirees'
                ELSE 'Standard Customers'
            END
        ORDER BY new_customers DESC
    ) LOOP
        RAISE NOTICE 'Segment: % - New: %, Income: %, Apps: %, Rate: %%',
            rec.customer_segment,
            rec.new_customers,
            rec.avg_income,
            rec.immediate_applications,
            rec.application_rate;
    END LOOP;

    -- Get record count for logging
    SELECT COUNT(*) INTO v_records_processed 
    FROM customers 
    WHERE is_active = true;

    -- Complete job logging
    PERFORM complete_batch_job(
        v_execution_id,
        v_records_processed,
        v_records_inserted,
        'Completed'
    );

    RAISE NOTICE '';
    RAISE NOTICE 'Job Duration: % seconds', 
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time))::INTEGER;
    RAISE NOTICE 'Records Processed: % customer segments', v_records_inserted;
    RAISE NOTICE '=== END WEEKLY CUSTOMER ANALYTICS JOB ===';

EXCEPTION
    WHEN OTHERS THEN
        -- Handle errors
        PERFORM complete_batch_job(
            v_execution_id,
            v_records_processed,
            v_records_inserted,
            0,
            'Failed',
            SQLERRM
        );
        
        RAISE NOTICE 'Job failed with error: %', SQLERRM;
        RAISE;
END $$;
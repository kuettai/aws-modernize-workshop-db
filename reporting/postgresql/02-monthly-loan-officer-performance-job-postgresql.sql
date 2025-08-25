-- =============================================
-- Monthly Batch Job 2: Loan Officer Performance Report (PostgreSQL)
-- Runs monthly to populate monthly_loan_officer_performance table
-- Analyzes loan officer productivity and rankings
-- =============================================

DO $$
DECLARE
    v_report_month DATE := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month'); -- First day of previous month
    v_execution_id BIGINT;
    v_records_processed INTEGER := 0;
    v_records_inserted INTEGER := 0;
    v_start_time TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    -- Start job logging
    SELECT start_batch_job(
        'Monthly Loan Officer Performance',
        'Monthly',
        v_report_month
    ) INTO v_execution_id;

    RAISE NOTICE '=== MONTHLY LOAN OFFICER PERFORMANCE BATCH JOB ===';
    RAISE NOTICE 'Processing Month: %', v_report_month;
    RAISE NOTICE 'ExecutionId: %', v_execution_id;
    RAISE NOTICE '';

    -- Clear existing data for this month (if re-running)
    DELETE FROM monthly_loan_officer_performance WHERE report_month = v_report_month;
    RAISE NOTICE 'Cleared existing data for %', v_report_month;

    -- Insert performance data with ranking
    WITH loan_officer_stats AS (
        SELECT 
            lo.loan_officer_id,
            lo.first_name || ' ' || lo.last_name AS loan_officer_name,
            b.branch_name,
            COUNT(a.application_id) AS total_applications,
            COUNT(CASE WHEN a.application_status = 'Approved' THEN 1 END) AS approved_applications,
            CASE 
                WHEN COUNT(a.application_id) > 0 
                THEN ROUND((COUNT(CASE WHEN a.application_status = 'Approved' THEN 1 END) * 100.0 / COUNT(a.application_id))::NUMERIC, 2)
                ELSE 0 
            END AS approval_rate,
            COALESCE(SUM(CASE WHEN a.application_status = 'Approved' THEN a.requested_amount ELSE 0 END), 0) AS total_loan_amount,
            COALESCE(AVG(CASE WHEN a.application_status = 'Approved' THEN a.requested_amount END), 0) AS avg_loan_amount,
            AVG(CASE 
                WHEN a.decision_date IS NOT NULL 
                THEN EXTRACT(EPOCH FROM (a.decision_date - a.submission_date)) / 86400.0 -- Convert to days
                END) AS avg_processing_days
        FROM loan_officers lo
        INNER JOIN branches b ON lo.branch_id = b.branch_id
        LEFT JOIN applications a ON lo.loan_officer_id = a.loan_officer_id 
            AND a.submission_date >= v_report_month 
            AND a.submission_date < v_report_month + INTERVAL '1 month'
            AND a.is_active = true
        WHERE lo.is_active = true
        GROUP BY lo.loan_officer_id, lo.first_name, lo.last_name, b.branch_name
        HAVING COUNT(a.application_id) > 0  -- Only include officers with applications
    ),
    ranked_officers AS (
        SELECT 
            *,
            ROW_NUMBER() OVER (ORDER BY approval_rate DESC, total_loan_amount DESC, total_applications DESC) AS ranking
        FROM loan_officer_stats
    )
    INSERT INTO monthly_loan_officer_performance (
        report_month,
        loan_officer_id,
        loan_officer_name,
        branch_name,
        total_applications,
        approved_applications,
        approval_rate,
        total_loan_amount,
        avg_loan_amount,
        avg_processing_days,
        ranking
    )
    SELECT 
        v_report_month,
        loan_officer_id,
        loan_officer_name,
        branch_name,
        total_applications,
        approved_applications,
        approval_rate,
        total_loan_amount,
        avg_loan_amount,
        avg_processing_days,
        ranking
    FROM ranked_officers;

    GET DIAGNOSTICS v_records_inserted = ROW_COUNT;
    RAISE NOTICE 'Inserted % loan officer performance records.', v_records_inserted;

    -- Display Top 10 Performers
    RAISE NOTICE '';
    RAISE NOTICE 'TOP 10 LOAN OFFICERS (By Approval Rate & Volume):';
    RAISE NOTICE '================================================';

    FOR rec IN (
        SELECT 
            ranking,
            loan_officer_name,
            branch_name,
            total_applications,
            approved_applications,
            approval_rate,
            total_loan_amount,
            avg_loan_amount,
            ROUND(avg_processing_days::NUMERIC, 2) AS avg_processing_days
        FROM monthly_loan_officer_performance 
        WHERE report_month = v_report_month
            AND ranking <= 10
        ORDER BY ranking
    ) LOOP
        RAISE NOTICE 'Rank %: % (%) - Apps: %, Rate: %%, Amount: %, Avg Days: %',
            rec.ranking,
            rec.loan_officer_name,
            rec.branch_name,
            rec.total_applications,
            rec.approval_rate,
            rec.total_loan_amount,
            rec.avg_processing_days;
    END LOOP;

    -- Branch Performance Summary
    RAISE NOTICE '';
    RAISE NOTICE 'BRANCH PERFORMANCE SUMMARY:';
    RAISE NOTICE '==========================';

    FOR rec IN (
        SELECT 
            branch_name,
            COUNT(*) AS active_officers,
            SUM(total_applications) AS branch_total_applications,
            SUM(approved_applications) AS branch_approved_applications,
            ROUND((SUM(approved_applications) * 100.0 / SUM(total_applications))::NUMERIC, 2) AS branch_approval_rate,
            SUM(total_loan_amount) AS branch_total_loan_amount,
            ROUND(AVG(approval_rate)::NUMERIC, 2) AS avg_officer_approval_rate,
            MIN(ranking) AS best_officer_rank,
            MAX(ranking) AS worst_officer_rank
        FROM monthly_loan_officer_performance 
        WHERE report_month = v_report_month
        GROUP BY branch_name
        ORDER BY branch_approval_rate DESC, branch_total_loan_amount DESC
    ) LOOP
        RAISE NOTICE 'Branch: % - Officers: %, Apps: %, Rate: %%, Amount: %, Best Rank: %',
            rec.branch_name,
            rec.active_officers,
            rec.branch_total_applications,
            rec.branch_approval_rate,
            rec.branch_total_loan_amount,
            rec.best_officer_rank;
    END LOOP;

    -- Performance Distribution Analysis
    RAISE NOTICE '';
    RAISE NOTICE 'PERFORMANCE DISTRIBUTION:';
    RAISE NOTICE '========================';

    FOR rec IN (
        SELECT 
            CASE 
                WHEN approval_rate >= 80 THEN 'Excellent (80%+)'
                WHEN approval_rate >= 70 THEN 'Good (70-79%)'
                WHEN approval_rate >= 60 THEN 'Average (60-69%)'
                WHEN approval_rate >= 50 THEN 'Below Average (50-59%)'
                ELSE 'Poor (<50%)'
            END AS performance_category,
            COUNT(*) AS officer_count,
            ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER())::NUMERIC, 2) AS percentage,
            ROUND(AVG(total_applications)::NUMERIC, 0) AS avg_applications_per_officer,
            ROUND(AVG(total_loan_amount)::NUMERIC, 0) AS avg_loan_amount_per_officer
        FROM monthly_loan_officer_performance 
        WHERE report_month = v_report_month
        GROUP BY 
            CASE 
                WHEN approval_rate >= 80 THEN 'Excellent (80%+)'
                WHEN approval_rate >= 70 THEN 'Good (70-79%)'
                WHEN approval_rate >= 60 THEN 'Average (60-69%)'
                WHEN approval_rate >= 50 THEN 'Below Average (50-59%)'
                ELSE 'Poor (<50%)'
            END
        ORDER BY MIN(approval_rate) DESC
    ) LOOP
        RAISE NOTICE 'Category: % - Officers: % (%%), Avg Apps: %, Avg Amount: %',
            rec.performance_category,
            rec.officer_count,
            rec.percentage,
            rec.avg_applications_per_officer,
            rec.avg_loan_amount_per_officer;
    END LOOP;

    -- Officers Needing Attention (Bottom 10%)
    RAISE NOTICE '';
    RAISE NOTICE 'OFFICERS NEEDING ATTENTION (Bottom 10%%):';
    RAISE NOTICE '=======================================';

    DECLARE
        v_total_officers INTEGER;
        v_bottom_10_percent INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_total_officers 
        FROM monthly_loan_officer_performance 
        WHERE report_month = v_report_month;
        
        v_bottom_10_percent := CEIL(v_total_officers * 0.1);

        FOR rec IN (
            SELECT 
                ranking,
                loan_officer_name,
                branch_name,
                total_applications,
                approval_rate,
                total_loan_amount,
                ROUND(avg_processing_days::NUMERIC, 2) AS avg_processing_days
            FROM monthly_loan_officer_performance 
            WHERE report_month = v_report_month
                AND ranking > (v_total_officers - v_bottom_10_percent)
            ORDER BY ranking DESC
        ) LOOP
            RAISE NOTICE 'Rank %: % (%) - Rate: %%, Apps: %, Amount: %, Days: % - ACTION: Performance Review Recommended',
                rec.ranking,
                rec.loan_officer_name,
                rec.branch_name,
                rec.approval_rate,
                rec.total_applications,
                rec.total_loan_amount,
                rec.avg_processing_days;
        END LOOP;
    END;

    -- Get record count for logging
    SELECT COUNT(*) INTO v_records_processed 
    FROM loan_officers 
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
    RAISE NOTICE 'Records Processed: % loan officers', v_records_inserted;
    RAISE NOTICE '=== END MONTHLY LOAN OFFICER PERFORMANCE JOB ===';

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
-- =============================================
-- Daily Batch Job 1: Daily Application Summary (PostgreSQL)
-- Runs daily to populate daily_application_summary table
-- Analyzes previous day's application activity
-- =============================================

DO $$
DECLARE
    v_report_date DATE := CURRENT_DATE - INTERVAL '1 day'; -- Previous day
    v_execution_id BIGINT;
    v_records_processed INTEGER := 0;
    v_start_time TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    -- Start job logging
    SELECT start_batch_job(
        'Daily Application Summary',
        'Daily',
        v_report_date
    ) INTO v_execution_id;

    RAISE NOTICE '=== DAILY APPLICATION SUMMARY BATCH JOB ===';
    RAISE NOTICE 'Processing Date: %', v_report_date;
    RAISE NOTICE 'ExecutionId: %', v_execution_id;
    RAISE NOTICE '';

    -- Check if report already exists for this date
    IF EXISTS (SELECT 1 FROM daily_application_summary WHERE report_date = v_report_date) THEN
        RAISE NOTICE 'Report already exists for %. Updating existing record.', v_report_date;
        
        -- Update existing record
        UPDATE daily_application_summary 
        SET 
            total_applications = (
                SELECT COUNT(*) 
                FROM applications 
                WHERE DATE(submission_date) = v_report_date 
                    AND is_active = true
            ),
            approved_applications = (
                SELECT COUNT(*) 
                FROM applications 
                WHERE DATE(submission_date) = v_report_date 
                    AND application_status = 'Approved' 
                    AND is_active = true
            ),
            rejected_applications = (
                SELECT COUNT(*) 
                FROM applications 
                WHERE DATE(submission_date) = v_report_date 
                    AND application_status = 'Rejected' 
                    AND is_active = true
            ),
            pending_applications = (
                SELECT COUNT(*) 
                FROM applications 
                WHERE DATE(submission_date) = v_report_date 
                    AND application_status IN ('Submitted', 'Under Review') 
                    AND is_active = true
            ),
            approval_rate = (
                SELECT CASE 
                    WHEN COUNT(*) > 0 
                    THEN ROUND((COUNT(CASE WHEN application_status = 'Approved' THEN 1 END) * 100.0 / COUNT(*))::NUMERIC, 2)
                    ELSE 0 
                END
                FROM applications 
                WHERE DATE(submission_date) = v_report_date 
                    AND is_active = true
            ),
            total_requested_amount = (
                SELECT COALESCE(SUM(requested_amount), 0)
                FROM applications 
                WHERE DATE(submission_date) = v_report_date 
                    AND is_active = true
            ),
            avg_requested_amount = (
                SELECT COALESCE(AVG(requested_amount), 0)
                FROM applications 
                WHERE DATE(submission_date) = v_report_date 
                    AND is_active = true
            ),
            avg_processing_hours = (
                SELECT AVG(EXTRACT(EPOCH FROM (COALESCE(decision_date, CURRENT_TIMESTAMP) - submission_date)) / 3600.0)
                FROM applications 
                WHERE DATE(submission_date) = v_report_date 
                    AND is_active = true
                    AND decision_date IS NOT NULL
            ),
            created_date = CURRENT_TIMESTAMP
        WHERE report_date = v_report_date;
        
        RAISE NOTICE 'Existing record updated successfully.';
    ELSE
        RAISE NOTICE 'Creating new report record for %', v_report_date;
        
        -- Insert new record
        INSERT INTO daily_application_summary (
            report_date,
            total_applications,
            approved_applications,
            rejected_applications,
            pending_applications,
            approval_rate,
            total_requested_amount,
            avg_requested_amount,
            avg_processing_hours
        )
        SELECT 
            v_report_date,
            COUNT(*) AS total_applications,
            COUNT(CASE WHEN application_status = 'Approved' THEN 1 END) AS approved_applications,
            COUNT(CASE WHEN application_status = 'Rejected' THEN 1 END) AS rejected_applications,
            COUNT(CASE WHEN application_status IN ('Submitted', 'Under Review') THEN 1 END) AS pending_applications,
            CASE 
                WHEN COUNT(*) > 0 
                THEN ROUND((COUNT(CASE WHEN application_status = 'Approved' THEN 1 END) * 100.0 / COUNT(*))::NUMERIC, 2)
                ELSE 0 
            END AS approval_rate,
            COALESCE(SUM(requested_amount), 0) AS total_requested_amount,
            COALESCE(AVG(requested_amount), 0) AS avg_requested_amount,
            AVG(EXTRACT(EPOCH FROM (COALESCE(decision_date, CURRENT_TIMESTAMP) - submission_date)) / 3600.0) AS avg_processing_hours
        FROM applications 
        WHERE DATE(submission_date) = v_report_date 
            AND is_active = true;
        
        RAISE NOTICE 'New record inserted successfully.';
    END IF;

    -- Display results
    RAISE NOTICE '';
    RAISE NOTICE 'DAILY SUMMARY RESULTS:';
    RAISE NOTICE '=====================';

    -- Get record count for logging
    SELECT COUNT(*) INTO v_records_processed 
    FROM applications 
    WHERE DATE(submission_date) = v_report_date AND is_active = true;

    -- Complete job logging
    PERFORM complete_batch_job(
        v_execution_id,
        v_records_processed,
        1, -- records_inserted
        'Completed'
    );

    -- Display summary
    PERFORM (
        SELECT 
            RAISE NOTICE 'Report Date: %, Total Apps: %, Approved: %, Rejected: %, Pending: %, Approval Rate: %%, Total Amount: %, Avg Amount: %, Avg Processing: % hours',
            report_date,
            total_applications,
            approved_applications,
            rejected_applications,
            pending_applications,
            approval_rate,
            total_requested_amount,
            avg_requested_amount,
            ROUND(avg_processing_hours::NUMERIC, 2)
        FROM daily_application_summary 
        WHERE report_date = v_report_date
    );

    -- Performance comparison with previous day
    RAISE NOTICE '';
    RAISE NOTICE 'COMPARISON WITH PREVIOUS DAY:';
    RAISE NOTICE '============================';

    PERFORM (
        WITH current_day AS (
            SELECT * FROM daily_application_summary WHERE report_date = v_report_date
        ),
        previous_day AS (
            SELECT * FROM daily_application_summary WHERE report_date = v_report_date - INTERVAL '1 day'
        )
        SELECT 
            RAISE NOTICE 'Applications - Today: %, Yesterday: %, Change: %',
            cd.total_applications,
            COALESCE(pd.total_applications, 0),
            CASE 
                WHEN COALESCE(pd.total_applications, 0) > 0 
                THEN ROUND(((cd.total_applications - COALESCE(pd.total_applications, 0)) * 100.0 / pd.total_applications)::NUMERIC, 2)
                ELSE 0 
            END
        FROM current_day cd
        LEFT JOIN previous_day pd ON true
    );

    -- Weekly trend (last 7 days)
    RAISE NOTICE '';
    RAISE NOTICE 'WEEKLY TREND (Last 7 Days):';
    RAISE NOTICE '===========================';

    FOR rec IN (
        SELECT 
            report_date,
            TO_CHAR(report_date, 'Day') AS day_of_week,
            total_applications,
            approval_rate,
            total_requested_amount
        FROM daily_application_summary 
        WHERE report_date >= v_report_date - INTERVAL '7 days'
            AND report_date <= v_report_date
        ORDER BY report_date DESC
    ) LOOP
        RAISE NOTICE '% (%) - Apps: %, Rate: %%, Amount: %',
            rec.report_date,
            TRIM(rec.day_of_week),
            rec.total_applications,
            rec.approval_rate,
            rec.total_requested_amount;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE 'Job Duration: % seconds', 
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time))::INTEGER;
    RAISE NOTICE '=== END DAILY APPLICATION SUMMARY JOB ===';

EXCEPTION
    WHEN OTHERS THEN
        -- Handle errors
        PERFORM complete_batch_job(
            v_execution_id,
            v_records_processed,
            0,
            0,
            'Failed',
            SQLERRM
        );
        
        RAISE NOTICE 'Job failed with error: %', SQLERRM;
        RAISE;
END $$;
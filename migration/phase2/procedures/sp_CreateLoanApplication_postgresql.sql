-- =============================================
-- PostgreSQL Function: create_loan_application
-- Purpose: Insert new loan application with validation
-- Converted from SQL Server stored procedure
-- =============================================

CREATE OR REPLACE FUNCTION create_loan_application(
    p_customer_id INTEGER,
    p_loan_officer_id INTEGER,
    p_branch_id INTEGER,
    p_requested_amount NUMERIC(12,2),
    p_loan_purpose VARCHAR(100)
)
RETURNS TABLE (
    application_id INTEGER,
    application_number VARCHAR(20),
    message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_application_number VARCHAR(20);
    v_application_id INTEGER;
    v_app_count INTEGER;
    v_error_message TEXT;
BEGIN
    -- Validate customer exists and is active
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customerid = p_customer_id AND isactive = true) THEN
        RAISE EXCEPTION 'Customer not found or inactive' USING ERRCODE = 'P0001';
    END IF;
    
    -- Validate loan officer exists and is active
    IF NOT EXISTS (SELECT 1 FROM loanofficers WHERE loanofficeid = p_loan_officer_id AND isactive = true) THEN
        RAISE EXCEPTION 'Loan Officer not found or inactive' USING ERRCODE = 'P0001';
    END IF;
    
    -- Validate branch exists and is active
    IF NOT EXISTS (SELECT 1 FROM branches WHERE branchid = p_branch_id AND isactive = true) THEN
        RAISE EXCEPTION 'Branch not found or inactive' USING ERRCODE = 'P0001';
    END IF;
    
    -- Validate requested amount
    IF p_requested_amount <= 0 OR p_requested_amount > 1000000 THEN
        RAISE EXCEPTION 'Invalid loan amount. Must be between $1 and $1,000,000' USING ERRCODE = 'P0001';
    END IF;
    
    -- Generate application number
    SELECT COUNT(*) INTO v_app_count FROM applications;
    v_application_number := 'APP' || TO_CHAR(NOW(), 'YYYYMM') || LPAD((v_app_count + 1)::TEXT, 6, '0');
    
    -- Insert application
    INSERT INTO applications (
        applicationnumber,
        customerid,
        loanofficeid,
        branchid,
        requestedamount,
        loanpurpose,
        applicationstatus,
        submissiondate,
        isactive,
        createddate,
        modifieddate
    )
    VALUES (
        v_application_number,
        p_customer_id,
        p_loan_officer_id,
        p_branch_id,
        p_requested_amount,
        p_loan_purpose,
        'Submitted',
        NOW(),
        true,
        NOW(),
        NOW()
    )
    RETURNING applicationid INTO v_application_id;
    
    -- Log the creation
    INSERT INTO integrationlogs (
        applicationid,
        logtype,
        servicename,
        requestdata,
        statuscode,
        issuccess,
        logtimestamp,
        userid
    )
    VALUES (
        v_application_id,
        'Application Creation',
        'create_loan_application',
        'CustomerId: ' || p_customer_id::TEXT || ', Amount: ' || p_requested_amount::TEXT,
        '200',
        true,
        NOW(),
        CURRENT_USER
    );
    
    -- Return success result
    RETURN QUERY SELECT 
        v_application_id,
        v_application_number,
        'Application created successfully'::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        -- Get error details
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        
        -- Log the error (best effort - don't fail if this fails)
        BEGIN
            INSERT INTO integrationlogs (
                logtype,
                servicename,
                errormessage,
                statuscode,
                issuccess,
                logtimestamp,
                userid
            )
            VALUES (
                'Application Creation Error',
                'create_loan_application',
                v_error_message,
                '500',
                false,
                NOW(),
                CURRENT_USER
            );
        EXCEPTION
            WHEN OTHERS THEN
                -- Ignore logging errors
                NULL;
        END;
        
        -- Re-raise the original exception
        RAISE;
END;
$$;

-- =============================================
-- Helper function for application layer transaction management
-- =============================================

CREATE OR REPLACE FUNCTION create_loan_application_with_transaction(
    p_customer_id INTEGER,
    p_loan_officer_id INTEGER,
    p_branch_id INTEGER,
    p_requested_amount NUMERIC(12,2),
    p_loan_purpose VARCHAR(100)
)
RETURNS TABLE (
    application_id INTEGER,
    application_number VARCHAR(20),
    message TEXT,
    success BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_result RECORD;
BEGIN
    -- Start transaction (will be managed by application layer)
    SELECT * INTO v_result 
    FROM create_loan_application(
        p_customer_id,
        p_loan_officer_id,
        p_branch_id,
        p_requested_amount,
        p_loan_purpose
    );
    
    RETURN QUERY SELECT 
        v_result.application_id,
        v_result.application_number,
        v_result.message,
        true;

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            NULL::INTEGER,
            NULL::VARCHAR(20),
            SQLERRM::TEXT,
            false;
END;
$$;

-- =============================================
-- Usage Examples:
-- =============================================

-- Example 1: Direct function call (transaction managed by application)
/*
BEGIN;
SELECT * FROM create_loan_application(1, 1, 1, 50000.00, 'Home Purchase');
COMMIT;
*/

-- Example 2: Using wrapper function with built-in error handling
/*
SELECT * FROM create_loan_application_with_transaction(1, 1, 1, 50000.00, 'Home Purchase');
*/
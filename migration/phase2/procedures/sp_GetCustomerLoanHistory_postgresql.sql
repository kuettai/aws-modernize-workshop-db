-- =============================================
-- PostgreSQL Function: get_customer_loan_history
-- Purpose: Retrieve customer's loan history with payments
-- Converted from SQL Server stored procedure
-- =============================================

-- Customer info result type
CREATE TYPE customer_info_type AS (
    customerid INTEGER,
    customernumber VARCHAR(20),
    fullname TEXT,
    email VARCHAR(100),
    monthlyincome NUMERIC(12,2)
);

-- Loan history result type
CREATE TYPE loan_history_type AS (
    applicationid INTEGER,
    applicationnumber VARCHAR(20),
    requestedamount NUMERIC(12,2),
    applicationstatus VARCHAR(50),
    submissiondate TIMESTAMP,
    decisiondate TIMESTAMP,
    dsrratio NUMERIC(5,2),
    creditscore INTEGER,
    loanid INTEGER,
    loannumber VARCHAR(20),
    approvedamount NUMERIC(12,2),
    interestrate NUMERIC(5,4),
    loantermmonths INTEGER,
    monthlypayment NUMERIC(10,2),
    loanstatus VARCHAR(50),
    disbursementdate TIMESTAMP,
    outstandingbalance NUMERIC(12,2),
    nextpaymentdate TIMESTAMP,
    recordtype TEXT
);

-- Payment history result type
CREATE TYPE payment_history_type AS (
    paymentid INTEGER,
    loanid INTEGER,
    loannumber VARCHAR(20),
    paymentnumber VARCHAR(20),
    paymentdate TIMESTAMP,
    paymentamount NUMERIC(10,2),
    principalamount NUMERIC(10,2),
    interestamount NUMERIC(10,2),
    paymentmethod VARCHAR(50),
    paymentstatus VARCHAR(50),
    transactionid VARCHAR(100)
);

-- Main function returning customer info
CREATE OR REPLACE FUNCTION get_customer_loan_history(
    p_customer_id INTEGER,
    p_include_payments BOOLEAN DEFAULT true
)
RETURNS SETOF customer_info_type
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
BEGIN
    -- Validate customer exists
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customerid = p_customer_id) THEN
        RAISE EXCEPTION 'Customer not found' USING ERRCODE = 'P0001';
    END IF;
    
    -- Log the query
    INSERT INTO integrationlogs (
        logtype,
        servicename,
        requestdata,
        statuscode,
        issuccess,
        logtimestamp,
        userid
    )
    VALUES (
        'Customer Query',
        'get_customer_loan_history',
        'CustomerId: ' || p_customer_id::TEXT,
        '200',
        true,
        NOW(),
        CURRENT_USER
    );
    
    -- Return customer basic info
    RETURN QUERY
    SELECT 
        c.customerid,
        c.customernumber,
        (c.firstname || ' ' || c.lastname)::TEXT AS fullname,
        c.email,
        c.monthlyincome
    FROM customers c
    WHERE c.customerid = p_customer_id;

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        
        -- Log the error
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
                'Customer Query Error',
                'get_customer_loan_history',
                v_error_message,
                '500',
                false,
                NOW(),
                CURRENT_USER
            );
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Ignore logging errors
        END;
        
        RAISE;
END;
$$;

-- Function returning loan history
CREATE OR REPLACE FUNCTION get_customer_loan_history_details(
    p_customer_id INTEGER
)
RETURNS SETOF loan_history_type
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate customer exists
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customerid = p_customer_id) THEN
        RAISE EXCEPTION 'Customer not found' USING ERRCODE = 'P0001';
    END IF;
    
    -- Return applications and loans
    RETURN QUERY
    SELECT 
        a.applicationid,
        a.applicationnumber,
        a.requestedamount,
        a.applicationstatus,
        a.submissiondate,
        a.decisiondate,
        a.dsrratio,
        a.creditscore,
        l.loanid,
        l.loannumber,
        l.approvedamount,
        l.interestrate,
        l.loantermmonths,
        l.monthlypayment,
        l.loanstatus,
        l.disbursementdate,
        l.outstandingbalance,
        l.nextpaymentdate,
        CASE 
            WHEN l.loanid IS NOT NULL THEN 'Loan Created'::TEXT
            ELSE 'Application Only'::TEXT
        END AS recordtype
    FROM applications a
    LEFT JOIN loans l ON a.applicationid = l.applicationid
    WHERE a.customerid = p_customer_id
    ORDER BY a.submissiondate DESC;
END;
$$;

-- Function returning payment history
CREATE OR REPLACE FUNCTION get_customer_payment_history(
    p_customer_id INTEGER
)
RETURNS SETOF payment_history_type
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate customer exists
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customerid = p_customer_id) THEN
        RAISE EXCEPTION 'Customer not found' USING ERRCODE = 'P0001';
    END IF;
    
    -- Return payment history
    RETURN QUERY
    SELECT 
        p.paymentid,
        p.loanid,
        l.loannumber,
        p.paymentnumber,
        p.paymentdate,
        p.paymentamount,
        p.principalamount,
        p.interestamount,
        p.paymentmethod,
        p.paymentstatus,
        p.transactionid
    FROM payments p
    INNER JOIN loans l ON p.loanid = l.loanid
    INNER JOIN applications a ON l.applicationid = a.applicationid
    WHERE a.customerid = p_customer_id
    ORDER BY p.paymentdate DESC;
END;
$$;

-- Wrapper function that combines all results (for application layer)
CREATE OR REPLACE FUNCTION get_complete_customer_loan_history(
    p_customer_id INTEGER,
    p_include_payments BOOLEAN DEFAULT true
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_info JSON;
    v_loan_history JSON;
    v_payment_history JSON;
    v_result JSON;
BEGIN
    -- Get customer info
    SELECT row_to_json(t) INTO v_customer_info
    FROM (
        SELECT * FROM get_customer_loan_history(p_customer_id, p_include_payments)
    ) t;
    
    -- Get loan history
    SELECT json_agg(row_to_json(t)) INTO v_loan_history
    FROM (
        SELECT * FROM get_customer_loan_history_details(p_customer_id)
    ) t;
    
    -- Get payment history if requested
    IF p_include_payments THEN
        SELECT json_agg(row_to_json(t)) INTO v_payment_history
        FROM (
            SELECT * FROM get_customer_payment_history(p_customer_id)
        ) t;
    ELSE
        v_payment_history := '[]'::JSON;
    END IF;
    
    -- Combine results
    v_result := json_build_object(
        'customer_info', v_customer_info,
        'loan_history', COALESCE(v_loan_history, '[]'::JSON),
        'payment_history', v_payment_history
    );
    
    RETURN v_result;
END;
$$;

-- =============================================
-- Usage Examples:
-- =============================================

-- Example 1: Get customer info only
/*
SELECT * FROM get_customer_loan_history(1);
*/

-- Example 2: Get loan history details
/*
SELECT * FROM get_customer_loan_history_details(1);
*/

-- Example 3: Get payment history
/*
SELECT * FROM get_customer_payment_history(1);
*/

-- Example 4: Get complete history as JSON (recommended for application layer)
/*
SELECT get_complete_customer_loan_history(1, true);
*/
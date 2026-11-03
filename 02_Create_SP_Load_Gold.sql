CREATE OR ALTER PROCEDURE gold.sp_load_gold
AS
BEGIN

    --------------------------------------------------
    -- 1. Clear Gold tables
    --------------------------------------------------
    TRUNCATE TABLE gold.fact_complaint;
    TRUNCATE TABLE gold.dim_response;
    TRUNCATE TABLE gold.dim_channel;
    TRUNCATE TABLE gold.dim_location;
    TRUNCATE TABLE gold.dim_company;
    TRUNCATE TABLE gold.dim_issue;
    TRUNCATE TABLE gold.dim_product;
    TRUNCATE TABLE gold.dim_date;

    --------------------------------------------------
    -- 2. Load Date Dimension
    --------------------------------------------------
    DECLARE @min_date DATE;
    DECLARE @max_date DATE;

    select
        @min_date = min(date_value),
        @max_date = max(date_value)
    from
    (
        SELECT date_received as date_value
        FROM lh_cfpb_complaints.silver.consumer_complaints

        union all 

        SELECT date_sent_to_company as date_value
        FROM lh_cfpb_complaints.silver.consumer_complaints
    ) as d;

    insert into gold.dim_date
    (
        date_key,
        full_date,
        year_number,
        quarter_number,
        quarter_name,
        month_number,
        month_name,
        year_month,
        day_number,
        day_name
    )
    select
        CAST(FORMAT(calendar_date, 'yyyyMMdd') AS INT),
        calendar_date,
        YEAR(calendar_date),
        DATEPART(QUARTER, calendar_date),
        CONCAT('Q', DATEPART(QUARTER, calendar_date)),
        MONTH(calendar_date),
        DATENAME(MONTH, calendar_date),
        FORMAT(calendar_date, 'yyyy-MM'),
        DAY(calendar_date),
        DATENAME(WEEKDAY, calendar_date)
    from 
    (
        SELECT
            CAST(DATEADD(DAY, value, @min_date) AS DATE) AS calendar_date

        FROM GENERATE_SERIES
        (
            0,
            DATEDIFF(DAY, @min_date, @max_date)
        )
    ) as d; 
    
    --------------------------------------------------
    -- 3. Load Product Dimension
    ---------------------------------------------------
        INSERT INTO gold.dim_product
    (
        product,
        product_standardized,
        sub_product,
        sub_product_standardized
    )
    SELECT DISTINCT 
        product,
        product_standardized,
        sub_product,
        sub_product_standardized
    FROM lh_cfpb_complaints.silver.consumer_complaints;

    --------------------------------------------------
    -- 4. Load Issue Dimension
    --------------------------------------------------
    INSERT INTO gold.dim_issue
    (
        issue,
        issue_standardized,
        sub_issue,
        sub_issue_standardized
    )
    SELECT DISTINCT
        issue,
        issue_standardized,
        sub_issue,
        sub_issue_standardized
    FROM lh_cfpb_complaints.silver.consumer_complaints;
    
       --------------------------------------------------
   -- 5. Load Company Dimension
   --------------------------------------------------
   INSERT INTO gold.dim_company
   (
        company,
        company_clean
   )
   SELECT DISTINCT
        company,
        company_clean
   FROM lh_cfpb_complaints.silver.consumer_complaints;

   --------------------------------------------------
   -- 6. Load Location Dimension
   --------------------------------------------------
   INSERT INTO gold.dim_location
   (
        state,
        zip_code
   )
   SELECT DISTINCT
        state,
        zip_code
   FROM lh_cfpb_complaints.silver.consumer_complaints;

   --------------------------------------------------
   -- 7. Load Channel Dimension
   --------------------------------------------------

   INSERT INTO gold.dim_channel
   (
        submitted_via
   )
   SELECT DISTINCT
        submitted_via
   FROM lh_cfpb_complaints.silver.consumer_complaints;
        --------------------------------------------------
    -- 8. Load Response Dimension
    --------------------------------------------------

    INSERT INTO gold.dim_response
    (
        company_public_repsonse,
        company_response_to_consumer,
        timely_response,
        consumer_disputed,
        consumer_consent_provided
    )
    SELECT DISTINCT
        company_public_response,
        company_response_to_consumer,
        timely_response,
        consumer_disputed,
        consumer_consent_provided
    FROM lh_cfpb_complaints.silver.consumer_complaints;

    --------------------------------------------------
    -- 9. Load Fact Complaint
    --------------------------------------------------
    INSERT INTO gold.fact_complaint
    (
        complaint_id,
        received_date_key,
        sent_date_key,
        product_key,
        issue_key,
        company_key,
        location_key,
        channel_key,
        response_key,
        tags,
        days_to_send,
        complaint_count
    )
    SELECT
    s.complaint_id,
    CAST(FORMAT(s.date_received, 'yyyyMMdd') AS INT) AS received_date_key,
    CAST(FORMAT(s.date_sent_to_company, 'yyyyMMdd') AS INT) AS sent_date_key,
    p.product_key,
    i.issue_key,
    c.company_key,
    l.location_key,
    ch.channel_key,
    r.response_key,
    s.tags,
    DATEDIFF(DAY, s.date_received, s.date_sent_to_company) AS days_to_send,
    1 AS complaint_count
    FROM lh_cfpb_complaints.silver.consumer_complaints as s
    JOIN gold.dim_product as p
    ON s.product = p.product
    AND s.product_standardized = p.product_standardized
    AND (
        s.sub_product = p.sub_product
        OR (s.sub_product IS NULL AND p.sub_product IS NULL)
    )
    AND (
        s.sub_product_standardized = p.sub_product_standardized
        OR (s.sub_product_standardized IS NULL
        AND p.sub_product_standardized IS NULL)
    )

    JOIN gold.dim_issue as i
    ON s.issue = i.issue
    AND s.issue_standardized = i.issue_standardized
    AND (
        s.sub_issue = i.sub_issue
        OR (s.sub_issue IS NULL AND i.sub_issue IS NULL)
    )
    AND (
        s.sub_issue_standardized = i.sub_issue_standardized
        OR ( s.sub_issue_standardized IS NULL AND i.sub_issue_standardized IS NULL)
    )

    JOIN gold.dim_company as c
    ON s.company = c.company
    AND s.company_clean = c.company_clean

    JOIN gold.dim_location as l
    ON (
        s.state = l.state
        OR (s.state IS NULL AND l.state IS NULL)
    )
    AND (
        s.zip_code = l.zip_code
        OR (s.zip_code IS NULL AND l.zip_code IS NULL)
    )

    JOIN gold.dim_channel as ch
    ON s.submitted_via = ch.submitted_via

    JOIN gold.dim_response as r
    ON (
        s.company_public_response = r.company_public_repsonse
        OR (
            s.company_public_response IS NULL AND r.company_public_repsonse IS NULL
        )
    )
    AND s.company_response_to_consumer  = r.company_response_to_consumer 
    AND s.timely_response = r.timely_response
    AND (
        s.consumer_disputed = r.consumer_disputed
        OR (
            s.consumer_disputed IS NULL
            AND r.consumer_disputed IS NULL
        )
    )
    AND (
        s.consumer_consent_provided  = r.consumer_consent_provided 
        OR (
            s.consumer_consent_provided IS NULL
            AND r.consumer_consent_provided IS NULL
        )
    );
END;

EXEC gold.sp_load_gold;

SELECT
    (SELECT COUNT(*)
     FROM lh_cfpb_complaints.silver.consumer_complaints) AS silver_rows,

    (SELECT COUNT(*)
     FROM gold.fact_complaint) AS fact_rows,

    (SELECT COUNT(DISTINCT complaint_id)
     FROM gold.fact_complaint) AS distinct_fact_complaints;

SELECT
    SUM(CASE WHEN rd.date_key IS NULL THEN 1 ELSE 0 END)
        AS missing_received_date_keys,

    SUM(CASE WHEN sd.date_key IS NULL THEN 1 ELSE 0 END)
        AS missing_sent_date_keys,

    SUM(CASE WHEN f.days_to_send < 0 THEN 1 ELSE 0 END)
        AS negative_days_to_send

FROM gold.fact_complaint AS f

LEFT JOIN gold.dim_date AS rd
    ON f.received_date_key = rd.date_key

LEFT JOIN gold.dim_date AS sd
    ON f.sent_date_key = sd.date_key;

-----------------------------------------------------------
SELECT 'dim_date' AS table_name, COUNT(*) AS row_count
FROM gold.dim_date

UNION ALL

SELECT 'dim_product', COUNT(*)
FROM gold.dim_product

UNION ALL

SELECT 'dim_issue', COUNT(*)
FROM gold.dim_issue

UNION ALL

SELECT 'dim_company', COUNT(*)
FROM gold.dim_company

UNION ALL

SELECT 'dim_location', COUNT(*)
FROM gold.dim_location

UNION ALL

SELECT 'dim_channel', COUNT(*)
FROM gold.dim_channel

UNION ALL

SELECT 'dim_response', COUNT(*)
FROM gold.dim_response

UNION ALL

SELECT 'fact_complaint', COUNT(*)
FROM gold.fact_complaint;

SELECT
    SUM(CASE WHEN product_key  IS NULL THEN 1 ELSE 0 END) AS null_product_keys,
    SUM(CASE WHEN issue_key    IS NULL THEN 1 ELSE 0 END) AS null_issue_keys,
    SUM(CASE WHEN company_key  IS NULL THEN 1 ELSE 0 END) AS null_company_keys,
    SUM(CASE WHEN location_key IS NULL THEN 1 ELSE 0 END) AS null_location_keys,
    SUM(CASE WHEN channel_key  IS NULL THEN 1 ELSE 0 END) AS null_channel_keys,
    SUM(CASE WHEN response_key IS NULL THEN 1 ELSE 0 END) AS null_response_keys
FROM gold.fact_complaint;

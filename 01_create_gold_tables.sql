SELECT TOP (10) *
FROM [lh_cfpb_complaints].[silver].[consumer_complaints];

CREATE SCHEMA gold; 

CREATE TABLE gold.dim_date
(
    date_key INT NOT NULL,
    full_date DATE NOT NULL,
    year_number INT NOT NULL,
    quarter_number INT NOT NULL,
    quarter_name VARCHAR(2) NOT NULL,
    month_number INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    year_month VARCHAR(7) NOT NULL,
    day_number INT NOT NULL,
    day_name VARCHAR(20) NOT NULL
);

CREATE TABLE gold.dim_product
(
    product_key BIGINT IDENTITY,     --IDENTITY is there to create a surrogate key automatically for each unique row in the dimension.
    product VARCHAR(200) NOT NULL,
    product_standardized VARCHAR(200) NOT NULL,
    sub_product VARCHAR(300) NULL,
    sub_product_standardized VARCHAR(300) NULL
);

CREATE TABLE gold.dim_issue
(
    issue_key BIGINT IDENTITY,
    issue VARCHAR(500) NOT NULL,
    issue_standardized VARCHAR(500) NOT NULL,
    sub_issue VARCHAR(500) NULL,
    sub_issue_standardized VARCHAR(500) NULL
);

CREATE TABLE gold.dim_company
(
    company_key BIGINT IDENTITY,
    company VARCHAR(500) NOT NULL,
    company_clean VARCHAR(500) NOT NULL
);

CREATE TABLE gold.dim_location
(
    location_key BIGINT IDENTITY,
    state VARCHAR(10) NULL,
    zip_code VARCHAR(10) NULL
);


CREATE TABLE gold.dim_channel
(
    channel_key BIGINT IDENTITY,
    submitted_via VARCHAR(100) NOT NULL
);

CREATE TABLE gold.dim_response
(
    response_key BIGINT IDENTITY,
    company_public_repsonse VARCHAR(500) NULL,
    company_response_to_consumer VARCHAR(500) NOT NULL,
    timely_response VARCHAR(10) NOT NULL,
    consumer_disputed VARCHAR(20) NULL,
    consumer_consent_provided VARCHAR(50) NULL
);

CREATE TABLE gold.fact_complaint
(
    complaint_id INT NOT NULL,

    received_date_key INT NOT NULL,
    sent_date_key INT NOT NULL,

    product_key BIGINT NOT NULL,
    issue_key BIGINT NOT NULL,
    company_key BIGINT NOT NULL,
    location_key BIGINT NOT NULL,
    channel_key BIGINT NOT NULL,
    response_key BIGINT NOT NULL,

    tags VARCHAR(100) NULL,

    days_to_send INT NOT NULL,
    complaint_count INT NOT NULL
);



    -- ==============================================================================================
    -- 1. DATABASE SETUP
    -- ==============================================================================================

    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'superstore_dw')
        CREATE DATABASE superstore_dw;
    GO

    USE superstore_dw;
    GO

    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging') EXEC('CREATE SCHEMA staging');
    GO
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')  EXEC('CREATE SCHEMA bronze');
    GO
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')  EXEC('CREATE SCHEMA silver');
    GO
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')    EXEC('CREATE SCHEMA gold');
    GO

    -- ==============================================================================================
    -- >>> DATA WAREHOUSE BEGINS HERE <<<
    -- ==============================================================================================


    -- ==============================================================================================
    -- 2. STAGING AREA
    -- ==============================================================================================

    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'staging' AND t.name = 'central_superstore')
    BEGIN
        CREATE TABLE staging.central_superstore (
          row_id          NVARCHAR(255),
         order_id        NVARCHAR(255),
         order_date      NVARCHAR(255),
          ship_date       NVARCHAR(255),
          ship_mode       NVARCHAR(255),
         customer_id     NVARCHAR(255),
         customer_name   NVARCHAR(255),
        segment         NVARCHAR(255),
          country         NVARCHAR(255),
         city            NVARCHAR(255),
        state           NVARCHAR(255),
          postal_code     NVARCHAR(255),
          region          NVARCHAR(255),
         product_id      NVARCHAR(255),
         category        NVARCHAR(255),
          sub_category    NVARCHAR(255),
          product_name    NVARCHAR(1000),
          sales           NVARCHAR(255),
         quantity        NVARCHAR(255),
       discount        NVARCHAR(255),
       profit          NVARCHAR(255)
        );
    END;
    GO

    TRUNCATE TABLE staging.central_superstore;

    -- Load from the CSV export of Central_Superstore.xlsx 
    BULK INSERT staging.central_superstore
    FROM 'E:\DEPI\Mini Project 2\Central_Superstore.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '\n',
        FORMAT = 'CSV',
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        MAXERRORS = 0,
        ERRORFILE = 'E:\DEPI\Mini Project 2\Central_Region_err.log'
    );
    GO


    SELECT COUNT(*) 
    FROM staging.central_superstore;



    -- ==============================================================================================
    -- 3. BRONZE SCHEMA
    -- ==============================================================================================

    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'bronze' AND t.name = 'central_superstore')
    BEGIN
        CREATE TABLE bronze.central_superstore (
            row_id          INT             NOT NULL,
            order_id        NVARCHAR(20)    NOT NULL,
            order_date      DATE            NULL,
            ship_date       DATE            NULL,
            ship_mode       NVARCHAR(20)    NULL,
            customer_id     NVARCHAR(20)    NOT NULL,
            customer_name   NVARCHAR(100)   NULL,
            segment         NVARCHAR(20)    NULL,
            country         NVARCHAR(50)    NULL,
            city            NVARCHAR(50)    NULL,
            state           NVARCHAR(50)    NULL,
            postal_code     INT             NULL,
            region          NVARCHAR(20)    NULL,
            product_id      NVARCHAR(30)    NOT NULL,
            category        NVARCHAR(30)    NULL,
            sub_category    NVARCHAR(30)    NULL,
            product_name    NVARCHAR(500)   NULL,
            sales           DECIMAL(12,4)   NULL,
            quantity        INT             NULL,
            discount        DECIMAL(5,2)    NULL,
            profit          DECIMAL(12,4)   NULL,
            load_ts         DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
            CONSTRAINT PK_bronze_central_superstore PRIMARY KEY (row_id)
        );
    END;
    GO

    TRUNCATE TABLE bronze.central_superstore;

    INSERT INTO bronze.central_superstore
        (row_id, order_id, order_date, ship_date, ship_mode, customer_id, customer_name, segment,
         country, city, state, postal_code, region, product_id, category, sub_category, product_name,
         sales, quantity, discount, profit)
    SELECT
        TRY_CAST(row_id AS INT),
        LTRIM(RTRIM(order_id)),
        TRY_CAST(order_date AS DATE),
        TRY_CAST(ship_date AS DATE),
        LTRIM(RTRIM(ship_mode)),
        LTRIM(RTRIM(customer_id)),
        LTRIM(RTRIM(customer_name)),
        LTRIM(RTRIM(segment)),
        LTRIM(RTRIM(country)),
        LTRIM(RTRIM(city)),
        LTRIM(RTRIM(state)),
        TRY_CAST(postal_code AS INT),
        LTRIM(RTRIM(region)),
        LTRIM(RTRIM(product_id)),
        LTRIM(RTRIM(category)),
        LTRIM(RTRIM(sub_category)),
        LTRIM(RTRIM(product_name)),
        TRY_CAST(sales AS DECIMAL(12,4)),
        TRY_CAST(quantity AS INT),
        TRY_CAST(discount AS DECIMAL(5,2)),
        TRY_CAST(profit AS DECIMAL(12,4))
    FROM staging.central_superstore
    WHERE TRY_CAST(row_id AS INT) IS NOT NULL;
    GO

    -- ==============================================================================================
    -- 4. SILVER SCHEMA
    -- ==============================================================================================

    -- silver.customers
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'silver' AND t.name = 'customers')
    BEGIN
        CREATE TABLE silver.customers (
            customer_id     NVARCHAR(20)  NOT NULL PRIMARY KEY,
            customer_name   NVARCHAR(100) NOT NULL,
            segment         NVARCHAR(20)  NOT NULL
        );
    END;
    GO

    TRUNCATE TABLE silver.customers;

    INSERT INTO silver.customers (customer_id, customer_name, segment)
    SELECT DISTINCT customer_id, customer_name, segment
    FROM bronze.central_superstore;
    GO

    -- silver.products
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'silver' AND t.name = 'products')
    BEGIN
        CREATE TABLE silver.products (
            product_id      NVARCHAR(30)  NOT NULL PRIMARY KEY,
            product_name    NVARCHAR(500) NOT NULL,
            category        NVARCHAR(30)  NOT NULL,
            sub_category    NVARCHAR(30)  NOT NULL
        );
    END;
    GO

    TRUNCATE TABLE silver.products;

    WITH ranked_products AS (
        SELECT
            product_id, product_name, category, sub_category,
            ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY order_date DESC, row_id DESC) AS rn
        FROM bronze.central_superstore
    )
    INSERT INTO silver.products (product_id, product_name, category, sub_category)
    SELECT product_id, product_name, category, sub_category
    FROM ranked_products
    WHERE rn = 1;
    GO

    -- silver.locations
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'silver' AND t.name = 'locations')
    BEGIN
        CREATE TABLE silver.locations (
            city            NVARCHAR(50) NOT NULL,
            state           NVARCHAR(50) NOT NULL,
            postal_code     INT          NOT NULL,
            region          NVARCHAR(20) NOT NULL,
            country         NVARCHAR(50) NOT NULL,
            CONSTRAINT PK_silver_locations PRIMARY KEY (city, state, postal_code)
        );
    END;
    GO

    TRUNCATE TABLE silver.locations;

    INSERT INTO silver.locations (city, state, postal_code, region, country)
    SELECT DISTINCT city, state, postal_code, region, country
    FROM bronze.central_superstore;
    GO

    -- silver.ship_modes
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'silver' AND t.name = 'ship_modes')
    BEGIN
        CREATE TABLE silver.ship_modes (
            ship_mode NVARCHAR(20) NOT NULL PRIMARY KEY
        );
    END;
    GO

    TRUNCATE TABLE silver.ship_modes;

    INSERT INTO silver.ship_modes (ship_mode)
    SELECT DISTINCT ship_mode FROM bronze.central_superstore;
    GO

    -- silver.sales_transactions
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'silver' AND t.name = 'sales_transactions')
    BEGIN
        CREATE TABLE silver.sales_transactions (
            row_id          INT           NOT NULL PRIMARY KEY,
            order_id        NVARCHAR(20)  NOT NULL,
            order_date      DATE          NOT NULL,
            ship_date       DATE          NOT NULL,
            ship_mode       NVARCHAR(20)  NOT NULL,
            customer_id     NVARCHAR(20)  NOT NULL,
            product_id      NVARCHAR(30)  NOT NULL,
            city            NVARCHAR(50)  NOT NULL,
            state           NVARCHAR(50)  NOT NULL,
            postal_code     INT           NOT NULL,
            sales_amount    DECIMAL(12,4) NOT NULL,
            quantity        INT           NOT NULL,
            discount        DECIMAL(5,2)  NOT NULL,
            profit          DECIMAL(12,4) NOT NULL,
            shipping_days   INT           NOT NULL
        );
    END;
    GO

    TRUNCATE TABLE silver.sales_transactions;

    INSERT INTO silver.sales_transactions
        (row_id, order_id, order_date, ship_date, ship_mode, customer_id, product_id,
         city, state, postal_code, sales_amount, quantity, discount, profit, shipping_days)
    SELECT
        row_id, order_id, order_date, ship_date, ship_mode, customer_id, product_id,
        city, state, postal_code,
        sales, quantity, discount, profit,
        DATEDIFF(DAY, order_date, ship_date) AS shipping_days
    FROM bronze.central_superstore
    WHERE order_date IS NOT NULL AND ship_date IS NOT NULL
      AND sales IS NOT NULL AND quantity IS NOT NULL;
    GO


    -- ==============================================================================================
    -- 5. GOLD SCHEMA / STAR SCHEMA
    -- ==============================================================================================

    -- gold.dim_date
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'gold' AND t.name = 'dim_date')
    BEGIN
        CREATE TABLE gold.dim_date (
            date_key      INT          NOT NULL PRIMARY KEY,   -- yyyymmdd
            full_date     DATE         NOT NULL,
            [year]        SMALLINT     NOT NULL,
            [quarter]     TINYINT      NOT NULL,
            [month]       TINYINT      NOT NULL,
            month_name    NVARCHAR(20) NOT NULL,
            [day]         TINYINT      NOT NULL,
            day_of_week   TINYINT      NOT NULL,
            day_name      NVARCHAR(20) NOT NULL,
            is_weekend    BIT          NOT NULL
        );
    END;
    GO

    IF OBJECT_ID('gold.fact_sales', 'U') IS NOT NULL
    BEGIN
        TRUNCATE TABLE gold.fact_sales;
    END;
    GO

    DELETE  FROM gold.dim_date;

    ;WITH bounds AS (
        SELECT MIN(order_date) AS min_d, MAX(ship_date) AS max_d FROM silver.sales_transactions
    ),
    calendar AS (
        SELECT min_d AS d FROM bounds
        UNION ALL
        SELECT DATEADD(DAY, 1, d) FROM calendar, bounds WHERE d < bounds.max_d
    )
    INSERT INTO gold.dim_date (date_key, full_date, [year], [quarter], [month], month_name,
                               [day], day_of_week, day_name, is_weekend)
    SELECT
        CONVERT(INT, FORMAT(d, 'yyyyMMdd')),
        d,
        YEAR(d),
        DATEPART(QUARTER, d),
        MONTH(d),
        DATENAME(MONTH, d),
        DAY(d),
        DATEPART(WEEKDAY, d),
        DATENAME(WEEKDAY, d),
        CASE WHEN DATENAME(WEEKDAY, d) IN ('Saturday','Sunday') THEN 1 ELSE 0 END
    FROM calendar
    OPTION (MAXRECURSION 0);
    GO

    INSERT INTO gold.dim_date (date_key, full_date, [year], [quarter], [month], month_name,
                               [day], day_of_week, day_name, is_weekend)
    VALUES (19000101, '1900-01-01', 1900, 1, 1, 'Unknown', 1, 1, 'Unknown', 0);
    GO

    -- gold.dim_customer
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'gold' AND t.name = 'dim_customer')
    BEGIN
        CREATE TABLE gold.dim_customer (
            customer_key    INT IDENTITY(1,1) PRIMARY KEY,
            customer_id     NVARCHAR(20)  NOT NULL UNIQUE,
            customer_name   NVARCHAR(100) NOT NULL,
            segment         NVARCHAR(20)  NOT NULL
        );
    END;
    GO

    IF NOT EXISTS (SELECT 1 FROM gold.dim_customer WHERE customer_id = 'UNKNOWN')
        INSERT INTO gold.dim_customer (customer_id, customer_name, segment)
        VALUES ('UNKNOWN', 'Unknown Customer', 'Unknown');
    GO

    INSERT INTO gold.dim_customer (customer_id, customer_name, segment)
    SELECT c.customer_id, c.customer_name, c.segment
    FROM silver.customers c
    WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customer d WHERE d.customer_id = c.customer_id);
    GO

    -- gold.dim_product
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'gold' AND t.name = 'dim_product')
    BEGIN
        CREATE TABLE gold.dim_product (
            product_key     INT IDENTITY(1,1) PRIMARY KEY,
            product_id      NVARCHAR(30)  NOT NULL UNIQUE,
            product_name    NVARCHAR(500) NOT NULL,
            category        NVARCHAR(30)  NOT NULL,
            sub_category    NVARCHAR(30)  NOT NULL
        );
    END;
    GO

    IF NOT EXISTS (SELECT 1 FROM gold.dim_product WHERE product_id = 'UNKNOWN')
        INSERT INTO gold.dim_product (product_id, product_name, category, sub_category)
        VALUES ('UNKNOWN', 'Unknown Product', 'Unknown', 'Unknown');
    GO

    INSERT INTO gold.dim_product (product_id, product_name, category, sub_category)
    SELECT p.product_id, p.product_name, p.category, p.sub_category
    FROM silver.products p
    WHERE NOT EXISTS (SELECT 1 FROM gold.dim_product d WHERE d.product_id = p.product_id);
    GO

    -- gold.dim_location
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'gold' AND t.name = 'dim_location')
    BEGIN
        CREATE TABLE gold.dim_location (
            location_key    INT IDENTITY(1,1) PRIMARY KEY,
            city            NVARCHAR(50) NOT NULL,
            state           NVARCHAR(50) NOT NULL,
            postal_code     INT          NOT NULL,
            region          NVARCHAR(20) NOT NULL,
            country         NVARCHAR(50) NOT NULL,
            CONSTRAINT UQ_dim_location UNIQUE (city, state, postal_code)
        );
    END;
    GO

    IF NOT EXISTS (SELECT 1 FROM gold.dim_location WHERE city = 'Unknown')
        INSERT INTO gold.dim_location (city, state, postal_code, region, country)
        VALUES ('Unknown', 'Unknown', -1, 'Unknown', 'Unknown');
    GO

    INSERT INTO gold.dim_location (city, state, postal_code, region, country)
    SELECT l.city, l.state, l.postal_code, l.region, l.country
    FROM silver.locations l
    WHERE NOT EXISTS (
        SELECT 1 FROM gold.dim_location d
        WHERE d.city = l.city AND d.state = l.state AND d.postal_code = l.postal_code
    );
    GO

    -- gold.dim_ship_mode
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'gold' AND t.name = 'dim_ship_mode')
    BEGIN
        CREATE TABLE gold.dim_ship_mode (
            ship_mode_key   INT IDENTITY(1,1) PRIMARY KEY,
            ship_mode       NVARCHAR(20) NOT NULL UNIQUE
        );
    END;
    GO

    IF NOT EXISTS (SELECT 1 FROM gold.dim_ship_mode WHERE ship_mode = 'Unknown')
        INSERT INTO gold.dim_ship_mode (ship_mode) VALUES ('Unknown');
    GO

    INSERT INTO gold.dim_ship_mode (ship_mode)
    SELECT sm.ship_mode
    FROM silver.ship_modes sm
    WHERE NOT EXISTS (SELECT 1 FROM gold.dim_ship_mode d WHERE d.ship_mode = sm.ship_mode);
    GO

    -- gold.fact_sales 
    IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
                   WHERE s.name = 'gold' AND t.name = 'fact_sales')
    BEGIN
        CREATE TABLE gold.fact_sales (
            sales_key           INT           NOT NULL PRIMARY KEY,   -- = source row_id, preserved as the fact's natural grain key
            order_id            NVARCHAR(20)  NOT NULL,                -- degenerate dimension: order-level rollups
            customer_key        INT           NOT NULL,
            product_key         INT           NOT NULL,
            location_key        INT           NOT NULL,
            ship_mode_key       INT           NOT NULL,
            order_date_key      INT           NOT NULL,
            ship_date_key       INT           NOT NULL,
            quantity            INT           NOT NULL,
            sales_amount        DECIMAL(12,4) NOT NULL,
            discount            DECIMAL(5,2)  NOT NULL,
            profit              DECIMAL(12,4) NOT NULL,
            profit_margin       DECIMAL(9,6)  NULL,   -- profit / sales_amount; NULL when sales_amount = 0
            shipping_days       INT           NOT NULL,
            CONSTRAINT FK_fact_sales_customer   FOREIGN KEY (customer_key)   REFERENCES gold.dim_customer(customer_key),
            CONSTRAINT FK_fact_sales_product    FOREIGN KEY (product_key)    REFERENCES gold.dim_product(product_key),
            CONSTRAINT FK_fact_sales_location   FOREIGN KEY (location_key)   REFERENCES gold.dim_location(location_key),
            CONSTRAINT FK_fact_sales_ship_mode  FOREIGN KEY (ship_mode_key)  REFERENCES gold.dim_ship_mode(ship_mode_key),
            CONSTRAINT FK_fact_sales_order_date FOREIGN KEY (order_date_key) REFERENCES gold.dim_date(date_key),
            CONSTRAINT FK_fact_sales_ship_date  FOREIGN KEY (ship_date_key)  REFERENCES gold.dim_date(date_key)
        );
    END;
    GO

    TRUNCATE TABLE gold.fact_sales;

    INSERT INTO gold.fact_sales
        (sales_key, order_id, customer_key, product_key, location_key, ship_mode_key,
         order_date_key, ship_date_key, quantity, sales_amount, discount, profit, profit_margin, shipping_days)
    SELECT
        st.row_id,
        st.order_id,
        ISNULL(dc.customer_key, -1),
        ISNULL(dp.product_key, -1),
        ISNULL(dl.location_key, -1),
        ISNULL(dsm.ship_mode_key, -1),
        ISNULL(CONVERT(INT, FORMAT(st.order_date, 'yyyyMMdd')), 19000101),
        ISNULL(CONVERT(INT, FORMAT(st.ship_date, 'yyyyMMdd')), 19000101),
        st.quantity,
        st.sales_amount,
        st.discount,
        st.profit,
        CASE WHEN st.sales_amount <> 0 THEN CAST(st.profit / st.sales_amount AS DECIMAL(9,6)) ELSE NULL END,
        st.shipping_days
    FROM silver.sales_transactions st
    LEFT JOIN gold.dim_customer  dc  ON dc.customer_id = st.customer_id
    LEFT JOIN gold.dim_product   dp  ON dp.product_id  = st.product_id
    LEFT JOIN gold.dim_location  dl  ON dl.city = st.city AND dl.state = st.state AND dl.postal_code = st.postal_code
    LEFT JOIN gold.dim_ship_mode dsm ON dsm.ship_mode = st.ship_mode;
    GO

    -- ==============================================================================================
    -- >>> DATA WAREHOUSE ENDS HERE <<<
    -- ==============================================================================================


    -- ==============================================================================================
    -- >>> ANALYTICAL QUERIES BEGIN HERE <<<
    -- ==============================================================================================


    -- ==============================================================================================
    -- 6. BUSINESS ANALYTICAL QUERIES
    -- ==============================================================================================

    -- Business Question 1:
    -- What are the total sales, profit, orders, and customers?
 

    SELECT SUM(sales_amount) AS total_sales,
    SUM(profit) AS total_profit,
    SUM(quantity) AS total_units,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    CAST(SUM(sales_amount) / COUNT(DISTINCT order_id) AS DECIMAL(12,2)) AS average_order_value,
    CAST(SUM(profit) * 100.0 / SUM(sales_amount) AS DECIMAL(6,2)) AS profit_margin 
    FROM gold.fact_sales;


    -- ------------------------------------------------------------------------------------------


    -- Business Question 2:
    -- Which product categories have the highest sales and profit?

    SELECT dp.category,
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit,
    CAST(SUM(fs.profit) * 100.0 / SUM(fs.sales_amount) AS DECIMAL(6,2)) AS profit_margin
    FROM gold.fact_sales fs JOIN gold.dim_product dp ON fs.product_key = dp.product_key 
    GROUP BY dp.category ORDER BY total_sales DESC;


    -- ------------------------------------------------------------------------------------------


    -- Business Question 3:
    -- Which product sub-categories make a loss or have low profit?

    SELECT dp.category,
    dp.sub_category, SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit,
    CAST(SUM(fs.profit) * 100.0 / SUM(fs.sales_amount) AS DECIMAL(6,2)) AS profit_margin,
    CASE WHEN SUM(fs.profit) < 0 THEN 'Loss' WHEN SUM(fs.profit) * 100.0 / SUM(fs.sales_amount) < 10 THEN 'Low Profit' ELSE 'Good Profit' END AS status 
    FROM gold.fact_sales fs JOIN gold.dim_product dp ON fs.product_key = dp.product_key
    GROUP BY dp.category, dp.sub_category 
    ORDER BY total_profit ASC;

    -- ------------------------------------------------------------------------------------------


    -- Business Question 4:
    -- How much sales and profit did we make each year?

    SELECT dd.[year],
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    CAST(SUM(fs.profit) * 100.0 / SUM(fs.sales_amount) AS DECIMAL(6,2)) AS profit_margin
    FROM gold.fact_sales fs JOIN gold.dim_date dd ON fs.order_date_key = dd.date_key
    WHERE dd.[year] <> 1900 
    GROUP BY dd.[year] 
    ORDER BY dd.[year];

    -- ------------------------------------------------------------------------------------------


    -- Business Question 5:
    -- How did sales change from one month to the next?
    WITH monthly_sales AS
    (
        SELECT
            dd.[year],
            dd.[month],
            dd.month_name,
            SUM(fs.sales_amount) AS total_sales
        FROM gold.fact_sales fs
        JOIN gold.dim_date dd
            ON fs.order_date_key = dd.date_key
        WHERE dd.[year] <> 1900
        GROUP BY dd.[year], dd.[month], dd.month_name
    )
    SELECT
        [year],
        month_name,
        total_sales,
        LAG(total_sales) OVER (ORDER BY [year], [month]) AS previous_month_sales
    FROM monthly_sales
    ORDER BY [year], [month];

    -- ------------------------------------------------------------------------------------------


    -- Business Question 6:
    -- What are the total sales over time?
    WITH monthly_sales AS ( SELECT dd.[year], dd.[month], dd.month_name, SUM(fs.sales_amount) AS monthly_sales FROM gold.fact_sales fs JOIN gold.dim_date dd ON fs.order_date_key = dd.date_key WHERE dd.[year] <> 1900 GROUP BY dd.[year], dd.[month], dd.month_name )
    SELECT [year],month_name, monthly_sales,
    SUM(monthly_sales) OVER ( ORDER BY [year], [month] ) AS running_sales 
    FROM monthly_sales 
    ORDER BY [year], [month];

    -- ------------------------------------------------------------------------------------------


    -- Business Question 7:
    -- Who are the top 10 customers by sales?

    SELECT TOP 10 dc.customer_id,
    dc.customer_name,
    dc.segment,
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit,
    CASE WHEN SUM(fs.profit) < 0 THEN 'Unprofitable' ELSE 'Profitable' END AS status
    FROM gold.fact_sales fs JOIN gold.dim_customer dc ON fs.customer_key = dc.customer_key
    GROUP BY dc.customer_id, dc.customer_name, dc.segment 
    ORDER BY total_sales DESC;

    -- ------------------------------------------------------------------------------------------


    -- Business Question 8:
    -- Which customers are making a loss for the company?

    SELECT dc.customer_id,
    dc.customer_name,
    dc.segment,
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit,
    COUNT(DISTINCT fs.order_id) AS total_orders
    FROM gold.fact_sales fs JOIN gold.dim_customer dc ON fs.customer_key = dc.customer_key 
    GROUP BY dc.customer_id, dc.customer_name, dc.segment
    HAVING SUM(fs.profit) < 0 
    ORDER BY total_profit ASC;


    -- ------------------------------------------------------------------------------------------


    -- Business Question 9:
    -- How much sales and profit does each customer segment make?

    SELECT dc.segment,
    COUNT(DISTINCT dc.customer_id) AS customers,
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit,
    CAST(SUM(fs.profit) * 100.0 / SUM(fs.sales_amount) AS DECIMAL(6,2)) AS profit_margin
    FROM gold.fact_sales fs JOIN gold.dim_customer dc ON fs.customer_key = dc.customer_key 
    GROUP BY dc.segment 
    ORDER BY total_profit DESC;


    -- ------------------------------------------------------------------------------------------


    -- Business Question 10:
    -- Which states have the highest sales and profit?

    SELECT dl.state,
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit,
    CAST(SUM(fs.profit) * 100.0 / SUM(fs.sales_amount) AS DECIMAL(6,2)) AS profit_margin 
    FROM gold.fact_sales fs JOIN gold.dim_location dl ON fs.location_key = dl.location_key
    WHERE dl.state <> 'Unknown' 
    GROUP BY dl.state 
    ORDER BY total_sales DESC;


    -- ------------------------------------------------------------------------------------------


    -- Business Question 11:
    -- Which products have low profit compared with other products in the same category?

    SELECT dp.category,
    dp.product_name,
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit 
    FROM gold.fact_sales fs
    JOIN gold.dim_product dp ON fs.product_key = dp.product_key 
    GROUP BY dp.category, dp.product_id, dp.product_name
    HAVING SUM(fs.profit) < ( SELECT AVG(product_profit)
    FROM ( SELECT dp2.product_id,
    SUM(fs2.profit) AS product_profit
    FROM gold.fact_sales fs2
    JOIN gold.dim_product dp2 
    ON fs2.product_key = dp2.product_key 
    WHERE dp2.category = dp.category 
    GROUP BY dp2.product_id ) AS products ) 
    ORDER BY total_profit ASC;

    -- ------------------------------------------------------------------------------------------


    -- Business Question 12:
    -- What are the top 10 and bottom 10 products by sales?
    WITH product_sales AS (
        SELECT
            dp.product_id,
            dp.product_name,
            dp.category,
            SUM(fs.sales_amount) AS total_sales,
            RANK() OVER (ORDER BY SUM(fs.sales_amount) DESC) AS sales_rank_desc,
            RANK() OVER (ORDER BY SUM(fs.sales_amount) ASC)  AS sales_rank_asc
        FROM gold.fact_sales fs
        JOIN gold.dim_product dp ON dp.product_key = fs.product_key
        GROUP BY dp.product_id, dp.product_name, dp.category
    )
    SELECT product_id, product_name, category, total_sales,
           CASE WHEN sales_rank_desc <= 10 THEN 'Top 10' ELSE 'Bottom 10' END AS performance_tier
    FROM product_sales
    WHERE sales_rank_desc <= 10 OR sales_rank_asc <= 10
    ORDER BY total_sales DESC;


    -- ------------------------------------------------------------------------------------------


    -- Business Question 13:
    -- What is the sales rank of each product inside its category?

    SELECT dp.category, dp.product_name, SUM(fs.sales_amount) AS total_sales,
    RANK() OVER ( PARTITION BY dp.category ORDER BY SUM(fs.sales_amount) DESC ) AS product_rank 
    FROM gold.fact_sales fs 
    JOIN gold.dim_product dp 
    ON fs.product_key = dp.product_key 
    GROUP BY dp.category, dp.product_id, dp.product_name;


    -- ------------------------------------------------------------------------------------------


    -- Business Question 14:
    -- What percentage of total sales comes from each category?
    SELECT dp.category,
    SUM(fs.sales_amount) AS category_sales,
    CAST( SUM(fs.sales_amount) * 100.0 / SUM(SUM(fs.sales_amount)) OVER () AS DECIMAL(6,2) ) AS sales_percentage
    FROM gold.fact_sales fs
    JOIN gold.dim_product dp 
    ON fs.product_key = dp.product_key
    GROUP BY dp.category 
    ORDER BY category_sales DESC;

    -- ------------------------------------------------------------------------------------------


    -- Business Question 15:
    -- Which customers have sales higher than the average customer?

    SELECT dc.customer_id, dc.customer_name, dc.segment,
    SUM(fs.sales_amount) AS total_sales
    FROM gold.fact_sales fs
    JOIN gold.dim_customer dc
    ON fs.customer_key = dc.customer_key
    GROUP BY dc.customer_id, dc.customer_name, dc.segment 
    HAVING SUM(fs.sales_amount) > ( SELECT AVG(total_sales)
    FROM ( SELECT customer_key, SUM(sales_amount) AS total_sales
    FROM gold.fact_sales GROUP BY customer_key ) AS customers ) ORDER BY total_sales DESC;
    -- ------------------------------------------------------------------------------------------


    -- Business Question 16:
    -- How does the discount level affect profit?
    SELECT CASE WHEN discount = 0 THEN '0%' WHEN discount <= 0.20 THEN '1-20%'
    WHEN discount <= 0.40 THEN '21-40%' WHEN discount <= 0.60
    THEN '41-60%' ELSE '61%+' END AS discount_level, COUNT(*) AS number_of_sales, SUM(sales_amount) AS total_sales, SUM(profit) AS total_profit,
    CAST(AVG(profit_margin) * 100 AS DECIMAL(6,2)) AS average_profit_margin
    FROM gold.fact_sales
    GROUP BY CASE WHEN discount = 0 THEN '0%' WHEN discount <= 0.20 THEN '1-20%' WHEN discount <= 0.40 THEN '21-40%' WHEN discount <= 0.60 THEN '41-60%' ELSE '61%+' END 
    ORDER BY MIN(discount);

    -- ------------------------------------------------------------------------------------------


    -- Business Question 17:
    -- What is the average shipping time for each shipping method?

    SELECT dsm.ship_mode,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    AVG(fs.shipping_days) AS average_shipping_days
    FROM gold.fact_sales fs
    JOIN gold.dim_ship_mode dsm
    ON fs.ship_mode_key = dsm.ship_mode_key 
    WHERE dsm.ship_mode <> 'Unknown' 
    GROUP BY dsm.ship_mode 
    ORDER BY average_shipping_days;


    -- ------------------------------------------------------------------------------------------


    -- Business Question 18:
    -- Which customers bought from us in more than one year?

    WITH customer_years AS 
    ( SELECT fs.customer_key, COUNT(DISTINCT dd.[year]) AS number_of_years,
    SUM(fs.sales_amount) AS total_sales,
    SUM(fs.profit) AS total_profit 
    FROM gold.fact_sales fs JOIN gold.dim_date dd 
    ON fs.order_date_key = dd.date_key 
    WHERE dd.[year] <> 1900 
    GROUP BY fs.customer_key ) 
    SELECT dc.customer_id, dc.customer_name, cy.number_of_years, cy.total_sales, cy.total_profit 
    FROM customer_years cy JOIN gold.dim_customer dc 
    ON cy.customer_key = dc.customer_key 
    WHERE cy.number_of_years > 1 
    ORDER BY cy.total_profit DESC;

    -- ------------------------------------------------------------------------------------------


    -- Business Question 19:
    -- How many customers are High, Medium, or Low value based on their sales?

    WITH customer_totals AS
    ( SELECT customer_key, SUM(sales_amount) AS total_sales,
    SUM(profit) AS total_profit
    FROM gold.fact_sales 
    GROUP BY customer_key ) 
    SELECT CASE WHEN total_sales >= 5000 THEN 'High Value' 
    WHEN total_sales >= 1500 THEN 'Medium Value' ELSE 'Low Value' END AS customer_type, COUNT(*) AS customer_count,
    SUM(total_sales) AS total_sales,
    SUM(total_profit) AS total_profit
    FROM customer_totals
    GROUP BY CASE WHEN total_sales >= 5000 THEN 'High Value' WHEN total_sales >= 1500 THEN 'Medium Value' ELSE 'Low Value' END ORDER BY total_sales DESC;

    -- ==============================================================================================
    -- >>> ANALYTICAL QUERIES END HERE <<<
    -- ==============================================================================================


    -- ==============================================================================================
    -- 7. KPI VIEW
    -- ==============================================================================================

    IF OBJECT_ID('gold.vw_kpi_dashboard', 'V') IS NOT NULL DROP VIEW gold.vw_kpi_dashboard;
    GO

    CREATE VIEW gold.vw_kpi_dashboard AS
    SELECT
        dp.category,
        dd.[year],
        SUM(fs.sales_amount)                                   AS total_sales,
        SUM(fs.profit)                                          AS total_profit,
        SUM(fs.quantity)                                         AS total_quantity,
        COUNT(DISTINCT fs.order_id)                              AS order_count,
        COUNT(DISTINCT fs.customer_key)                          AS customer_count,
        CAST(SUM(fs.sales_amount) / NULLIF(COUNT(DISTINCT fs.order_id), 0) AS DECIMAL(12,2)) AS avg_order_value,
        CAST(SUM(fs.profit) * 100.0 / NULLIF(SUM(fs.sales_amount), 0) AS DECIMAL(6,2))        AS profit_margin_pct
    FROM gold.fact_sales fs
    JOIN gold.dim_product dp ON dp.product_key = fs.product_key
    JOIN gold.dim_date dd    ON dd.date_key = fs.order_date_key
    WHERE dp.category <> 'Unknown'
    GROUP BY dp.category, dd.[year];
    GO

    -- ==============================================================================================
    -- 8. KPI STORED PROCEDURE
    -- ==============================================================================================

    IF OBJECT_ID('gold.usp_GetKPISummary', 'P') IS NOT NULL DROP PROCEDURE gold.usp_GetKPISummary;
    GO

    CREATE PROCEDURE gold.usp_GetKPISummary
        @StartDate  DATE          = NULL,   
        @EndDate    DATE          = NULL,   
        @Category   NVARCHAR(30)  = NULL,   
        @State      NVARCHAR(50)  = NULL    
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT
            ISNULL(@Category, 'All Categories') AS category_filter,
            ISNULL(@State, 'All States')        AS state_filter,
            SUM(fs.sales_amount)                                                          AS total_sales,
            SUM(fs.profit)                                                                 AS total_profit,
            SUM(fs.quantity)                                                                AS total_quantity,
            COUNT(DISTINCT fs.order_id)                                                     AS order_count,
            COUNT(DISTINCT fs.customer_key)                                                 AS customer_count,
            CAST(SUM(fs.sales_amount) / NULLIF(COUNT(DISTINCT fs.order_id), 0) AS DECIMAL(12,2)) AS avg_order_value,
            CAST(SUM(fs.profit) * 100.0 / NULLIF(SUM(fs.sales_amount), 0) AS DECIMAL(6,2))       AS profit_margin_pct
        FROM gold.fact_sales fs
        JOIN gold.dim_product  dp ON dp.product_key = fs.product_key
        JOIN gold.dim_location dl ON dl.location_key = fs.location_key
        JOIN gold.dim_date     dd ON dd.date_key = fs.order_date_key
        WHERE (@StartDate IS NULL OR dd.full_date >= @StartDate)
          AND (@EndDate   IS NULL OR dd.full_date <= @EndDate)
          AND (@Category  IS NULL OR dp.category  = @Category)
          AND (@State     IS NULL OR dl.state     = @State);
    END;
    GO


    -- ==============================================================================================
    -- 9. QUERY OPTIMIZATION (INDEXES)
    -- ==============================================================================================

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_fact_sales_customer'
          AND object_id = OBJECT_ID('gold.fact_sales')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_sales_customer
        ON gold.fact_sales (customer_key);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_fact_sales_product'
          AND object_id = OBJECT_ID('gold.fact_sales')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_sales_product
        ON gold.fact_sales (product_key);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_fact_sales_location'
          AND object_id = OBJECT_ID('gold.fact_sales')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_sales_location
        ON gold.fact_sales (location_key);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_fact_sales_order_date'
          AND object_id = OBJECT_ID('gold.fact_sales')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_sales_order_date
        ON gold.fact_sales (order_date_key)
        INCLUDE (sales_amount, profit, quantity);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_fact_sales_order_id'
          AND object_id = OBJECT_ID('gold.fact_sales')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_fact_sales_order_id
        ON gold.fact_sales (order_id);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_dim_product_category'
          AND object_id = OBJECT_ID('gold.dim_product')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_dim_product_category
        ON gold.dim_product (category, sub_category);
    END;

    GO

    -- ==============================================================================================
    -- 10. FINAL VALIDATION
    -- ==============================================================================================


    SELECT
        SUM(CASE WHEN customer_key  = -1 THEN 1 ELSE 0 END) AS unresolved_customer,
        SUM(CASE WHEN product_key   = -1 THEN 1 ELSE 0 END) AS unresolved_product,
        SUM(CASE WHEN location_key  = -1 THEN 1 ELSE 0 END) AS unresolved_location,
        SUM(CASE WHEN ship_mode_key = -1 THEN 1 ELSE 0 END) AS unresolved_ship_mode
    FROM gold.fact_sales;


    -- 10.2 Row counts across every layer should all equal the source row count (2,323)
    SELECT 'staging' AS layer, COUNT(*) AS row_count FROM staging.central_superstore
    UNION ALL
    SELECT 'bronze', COUNT(*) FROM bronze.central_superstore
    UNION ALL
    SELECT 'silver.sales_transactions', COUNT(*) FROM silver.sales_transactions
    UNION ALL
    SELECT 'gold.fact_sales', COUNT(*) FROM gold.fact_sales;


    -- 10.3 Star Schema objects exist: 5 dimensions + 1 fact table in the gold schema
    SELECT s.name AS schema_name, t.name AS table_name
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'gold'
    ORDER BY t.name;


    -- 10.4 Foreign Key constraints exist on gold.fact_sales
    SELECT fk.name AS foreign_key_name, OBJECT_NAME(fk.parent_object_id) AS fact_table,
           OBJECT_NAME(fk.referenced_object_id) AS dimension_table
    FROM sys.foreign_keys fk
    WHERE OBJECT_NAME(fk.parent_object_id) = 'fact_sales';


    -- 10.5 Required View and Stored Procedure exist
    SELECT
        OBJECT_ID('gold.vw_kpi_dashboard', 'V')   AS kpi_view_object_id,
        OBJECT_ID('gold.usp_GetKPISummary', 'P')  AS kpi_procedure_object_id;


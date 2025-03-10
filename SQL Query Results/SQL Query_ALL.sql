--- ### Financial Market Analysis With SQL ###

# Quick look at the data
SELECT * FROM financials LIMIT 5;
SELECT * FROM companies LIMIT 5;
SELECT * FROM sec_filings LIMIT 5;

SELECT COUNT(*) FROM financials;
SELECT COUNT(*) FROM companies;
SELECT COUNT(*) FROM sec_filings;

SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE
        WHEN symbol IS NULL THEN 1
        ELSE 0
    END) AS missing_symbol,
    SUM(CASE
        WHEN price_to_earnings IS NULL THEN 1
        ELSE 0
    END) AS missing_pe_ratio,
    SUM(CASE
        WHEN earnings_per_share IS NULL THEN 1
        ELSE 0
    END) AS missing_eps,
    SUM(CASE
        WHEN market_cap IS NULL THEN 1
        ELSE 0
    END) AS missing_market_cap,
    SUM(CASE
        WHEN ebitda IS NULL THEN 1
        ELSE 0
    END) AS missing_ebitda
FROM
    financials;

SELECT 
    symbol, COUNT(*)
FROM
    financials
GROUP BY symbol
HAVING COUNT(*) > 1;

SELECT 
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(AVG(price), 2) AS avg_price,
    MIN(market_cap) AS min_market_cap,
    MAX(market_cap) AS max_market_cap,
    ROUND(AVG(market_cap), 2) AS avg_market_cap
FROM
    financials;

# Delete Duplicate Rows
DELETE FROM financials
WHERE symbol IN (
    SELECT symbol FROM (
        SELECT symbol, ROW_NUMBER() OVER(PARTITION BY symbol ORDER BY symbol) AS row_num
        FROM financials
    ) t
    WHERE row_num > 1
);

UPDATE financials f
        JOIN
    (SELECT 
        c.sector, AVG(f2.price_to_earnings) AS avg_pe
    FROM
        financials f2
    JOIN companies c ON f2.symbol = c.symbol
    WHERE
        f2.price_to_earnings IS NOT NULL
    GROUP BY c.sector) sector_avg ON (SELECT 
            sector
        FROM
            companies
        WHERE
            symbol = f.symbol) = sector_avg.sector 
SET 
    f.price_to_earnings = sector_avg.avg_pe
WHERE
    f.price_to_earnings IS NULL;

UPDATE financials 
SET 
    market_cap = 0
WHERE
    market_cap IS NULL;




-- # Question 1: Which sector has the highest average earnings per share (EPS)?

SELECT 
    c.sector, ROUND(AVG(f.earnings_per_share), 2) AS avg_eps
FROM
    financials f
        JOIN
    companies c ON f.symbol = c.symbol
WHERE
    f.earnings_per_share IS NOT NULL
GROUP BY c.sector
ORDER BY avg_eps DESC;





-- # Question #2: Which stocks are undervalued based on low Price-to-Earnings (P/E) ratio?

SELECT 
    c.sector, AVG(f.price_to_earnings) AS avg_pe_ratio
FROM
    financials f
        JOIN
    companies c ON f.symbol = c.symbol
WHERE
    f.price_to_earnings IS NOT NULL
GROUP BY c.sector
ORDER BY avg_pe_ratio ASC;

# 
SELECT 
	f.symbol, c.name, c.sector, f.price_to_earnings, 
    (SELECT AVG(f2.price_to_earnings)
    FROM financials f2
    JOIN companies c2 on f2.symbol = c2.symbol
    WHERE c2.sector = c.sector) AS sector_avg_pe, DENSE_RANK() OVER(PARTITION BY c.sector ORDER BY f.price_to_earnings DESC) as pe_rank
FROM financials f 
JOIN companies c ON f.symbol = c.symbol
HAVING f.price_to_earnings < sector_avg_pe
ORDER BY c.sector, f.price_to_earnings ASC;		


SELECT DISTINCT
    (sector)
FROM
    companies;





-- # Question #3: Which Companies Have an EBITDA Higher Than Their Sector Average?

SELECT 
    c.sector, ROUND(AVG(f.ebitda), 2) AS avg_sector_ebitda
FROM
    financials f
        JOIN
    companies c ON f.symbol = c.symbol
GROUP BY c.sector
ORDER BY avg_sector_ebitda DESC;

SELECT 
	f.symbol, 
	c.name, 
    c.sector, 
    f.ebitda, 
    (SELECT avg(f2.ebitda) FROM financials f2 JOIN companies c2 ON f2.symbol = c2.symbol
		where c2.sector = c.sector) as sector_avg_ebitda, 
	DENSE_RANK() OVER(PARTITION BY c.sector ORDER BY f.ebitda DESC) as ebitda_rank
FROM financials f
JOIN companies c ON f.symbol = c.symbol
WHERE f.ebitda > 
	(SELECT avg(f2.ebitda) FROM financials f2 JOIN companies c2 ON f2.symbol = c2.symbol
	WHERE c2.sector = c.sector) 
ORDER BY c.sector, ebitda_rank DESC;






-- # Question #4: Which Sector Has the Highest Revenue-to-Market Capitalization Ratio (Price/Sales)?

SELECT 
    c.sector,
    ROUND(AVG(1 / f.price_to_sales), 2) AS avg_revenue_to_market_cap
FROM
    financials f
        JOIN
    companies c ON f.symbol = c.symbol
WHERE
    f.price_to_sales IS NOT NULL
        AND f.price_to_sales > 0
GROUP BY c.sector
ORDER BY avg_revenue_to_market_cap DESC;






-- # Question #5: What is the Average Price-to-Book Ratio for Each Sector?

SELECT 
    c.sector,
    ROUND(AVG(f.price_to_book), 2) AS avg_price_to_book
FROM
    financials f
        JOIN
    companies c ON f.symbol = c.symbol
WHERE
    f.price_to_book IS NOT NULL
        AND f.price_to_book > 0
GROUP BY c.sector
ORDER BY avg_price_to_book DESC;



WITH ranked_companies AS (
    SELECT 
        c.sector, 
        f.symbol, 
        c.name, 
        f.price_to_book,
        DENSE_RANK() OVER (PARTITION BY c.sector ORDER BY f.price_to_book DESC) AS pb_rank
    FROM financials f
    JOIN companies c ON f.symbol = c.symbol
    WHERE f.price_to_book IS NOT NULL
    AND f.price_to_book > 0
)
SELECT *
FROM ranked_companies
WHERE pb_rank <= 5
ORDER BY sector, pb_rank;



-- # Question #6: What Percentage of Stocks in Each Sector Pay Dividends?


SELECT 
    c.sector,
    COUNT(f.symbol) AS total_stocks,
    SUM(CASE
        WHEN f.dividend_yield > 0 THEN 1
        ELSE 0
    END) AS dividend_paying_stocks,
    ROUND((SUM(CASE
                WHEN f.dividend_yield > 0 THEN 1
                ELSE 0
            END) / COUNT(f.symbol)) * 100,
            2) AS dividend_stocks_percentage
FROM
    financials f
        JOIN
    companies c ON f.symbol = c.symbol
WHERE
    f.dividend_yield IS NOT NULL
GROUP BY c.sector
ORDER BY dividend_stocks_percentage DESC;

SELECT 
    c.symbol,
    c.name,
    c.sector,
    ROUND(f.dividend_yield, 2) dividend_yield,
    f.market_cap,
    f.ebitda
FROM
    financials f
        JOIN
    companies c ON f.symbol = c.symbol
WHERE
    dividend_yield != 0
ORDER BY sector ASC , dividend_yield DESC;

SELECT DISTINCT
    sector
FROM
    companies;


SELECT * 
FROM (
    SELECT 
        c.symbol, 
        c.name, 
        c.sector, 
        ROUND(f.dividend_yield,2) AS dividend_yield, 
        f.market_cap, 
        f.ebitda, 
        DENSE_RANK() OVER(PARTITION BY c.sector ORDER BY f.dividend_yield DESC) AS sector_rank
    FROM financials f
    JOIN companies c ON f.symbol = c.symbol
    WHERE f.dividend_yield != 0
) AS ranked_dividends 
WHERE sector_rank <= 5
ORDER BY sector ASC, dividend_yield DESC;

-- # Question 7: Which companies have the top 5 highest and bottom 5 lowest earnings per share (EPS)?

# Bottom 5 Companies
WITH bottom_eps AS (
    SELECT 
        c.sector,  
        f.symbol, 
        c.name, 
        f.earnings_per_share, 
        RANK() OVER(PARTITION BY c.sector ORDER BY f.earnings_per_share ASC) AS eps_rank
    FROM financials f 
    JOIN companies c ON f.symbol = c.symbol
    WHERE f.earnings_per_share IS NOT NULL
)
SELECT * 
FROM bottom_eps
WHERE eps_rank <= 5
ORDER BY sector, earnings_per_share ASC;




# Top 5 Companies
WITH top_eps AS (
    SELECT 
        c.sector,  
        f.symbol, 
        c.name, 
        f.earnings_per_share, 
        RANK() OVER(PARTITION BY c.sector ORDER BY f.earnings_per_share DESC) AS eps_rank
    FROM financials f 
    JOIN companies c ON f.symbol = c.symbol
    WHERE f.earnings_per_share IS NOT NULL
)
SELECT * 
FROM top_eps
WHERE eps_rank <= 5
ORDER BY sector, earnings_per_share DESC;

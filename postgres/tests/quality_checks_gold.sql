/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency,
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- Checking 'gold.dim_city'
-- ====================================================================
-- Check for Uniqueness of city Key in gold.dim_city
-- Expectation: No results
SELECT
    city_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_city
GROUP BY city_key
HAVING COUNT(*) > 1;

-- Check One row per city per hour
-- Expectation: No results
SELECT city_key, timestamp_utc, COUNT(*)
FROM gold.fact_solar_hourly
GROUP BY city_key, timestamp_utc
HAVING COUNT(*) > 1;

-- Check PV Output is physically possible
-- Expectation: No results
SELECT *
FROM gold.fact_solar_hourly
WHERE pv_kwh_per_kwp < 0 OR pv_kwh_per_kwp > 1;

-- Check Panels are never cooler than the air
-- Expectation: No results
SELECT *
FROM gold.fact_solar_hourly
WHERE cell_temperature_c < temperature_c;

-- ====================================================================
-- Checking 'gold.fact_solar_hourly'
-- ====================================================================
-- Check the data model connectivity between fact and dimensions
SELECT *
FROM gold.fact_solar_hourly f
LEFT JOIN gold.dim_city d
ON d.city_key = f.city_key
WHERE d.city_key IS NULL;

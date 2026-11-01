/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks for data completeness, accuracy,
    and physical plausibility across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys (one row per city per hour).
    - Completeness of hourly data (24 hours per city per day).
    - Missing values (NASA fill value -999 or NULLs).
    - Physically plausible ranges for irradiance, temperature, and wind speed.
    - Night-time irradiance equal to zero (validates UTC timestamp conversion).
    - Valid city coordinates (within Egypt's geographic bounds).

Usage Notes:
    - Run these checks after loading the Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- Checking 'silver.nasa_power'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key (city, ts_utc)
-- Expectation: No Results

SELECT id, count(*) AS cnt
FROM bronze.nasa_power
GROUP BY id
HAVING count(id)>1 OR id IS NULL;

-- Check for unwanted spaces
-- Expectation: No Result

SELECT city
FROM bronze.nasa_power
WHERE city != TRIM(city);

-- Check all latitudes within roughly 22–32 and longitudes within 24–37 (Egypt’s box)
-- Expectation: No Result

SELECT latitude 
FROM bronze.nasa_power
WHERE latitude < 22 OR latitude > 32;

SELECT longitude 
FROM bronze.nasa_power
WHERE longitude < 24 OR longitude > 37;

-- Check Dates are valid
-- Expectations: No Result

SELECT *
FROM bronze.nasa_power
WHERE start_date > end_date;

-- Check for NASA warnings
-- Expectations: No Result

SELECT city, response -> 'messages' AS msgs
FROM bronze.nasa_power
WHERE jsonb_array_length(response -> 'messages') > 0;

-- Check Complete hours: each row should contain (days × 24) hours, i.e. 744 for January
-- Expectations: No Result

SELECT b.city,
       left(e.key, 8) AS day,
       count(*)       AS hours
FROM bronze.nasa_power b,
     jsonb_each_text(b.response -> 'properties' -> 'parameter' -> 'ALLSKY_SFC_SW_DWN') AS e
GROUP BY b.city, left(e.key, 8)
HAVING count(*) <> 24;

-- Check for Physically impossible irradiance: below 0, or above ~1,400 W/m².
-- Expectations: No Result

SELECT b.city,
	   e.key AS timestmp,
	   e.value AS irradiance
FROM bronze.nasa_power as b,
	 jsonb_each_text(b.response -> 'properties' -> 'parameter' -> 'ALLSKY_SFC_SW_DWN') AS e
WHERE CAST(e.value AS NUMERIC) < 0 
	 OR CAST(e.value AS NUMERIC) > 1400 
	 OR CAST(e.value AS NUMERIC) = -999;

-- Check for Night must be dark: irradiance should be 0 at night
-- Expectations: No Result

SELECT b.city,
	   e.value AS irradiance,
	   right(e.key,2)::numeric AS hour_utc
FROM bronze.nasa_power as b,
	 jsonb_each_text(b.response -> 'properties' -> 'parameter' -> 'ALLSKY_SFC_SW_DWN') AS e
WHERE e.value::numeric > 0 AND (right(e.key, 2)::int >= 18 OR right(e.key, 2)::int <= 1);

-- Check for Plausible temperature: roughly -5 to 55 °C for Egypt
-- Expectations: No Result

SELECT b.city,
		e.key,
		e.value
FROM bronze.nasa_power AS b,
	 jsonb_each_text(b.response -> 'properties' -> 'parameter' -> 'T2M') AS e
WHERE e.value::numeric NOT BETWEEN -5 AND 55;

-- Check for Plausible wind: not negative, and below ~40 m/s.
-- Expectations: No Result

SELECT b.city,
		e.key,
		e.value
FROM bronze.nasa_power AS b,
	 jsonb_each_text(b.response -> 'properties' -> 'parameter' -> 'WS10M') AS e
WHERE e.value::numeric < 0 OR e.value::numeric > 40;

-- ====================================================================
-- Checking 'silver.city_location'
-- ====================================================================
-- Check for NULLs or Duplicates in city
-- Expectation: No Results

SELECT city
FROM silver.city_location
WHERE city is NULL;

SELECT city, count(*)
FROM silver.city_location
GROUP BY city
HAVING count(*) >1 OR city IS NULL;
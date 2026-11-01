/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Fact: gold.fact_solar_hourly
-- =============================================================================
DROP VIEW IF EXISTS gold.fact_solar_hourly;

CREATE VIEW gold.fact_solar_hourly AS
SELECT
	c.city_id AS city_key,
	n.allsky_sfc_sw_dwn AS irradiance_wm2,
	n.t2m AS temperature_c,
	n.ws10m AS wind_ms,
	n.ts_utc AS timestamp_utc,
	n.ts_utc AT TIME ZONE 'Africa/Cairo' AS timestamp_local,
    (n.ts_utc AT TIME ZONE 'Africa/Cairo')::date AS date_local,
	(n.t2m + 0.03125 * n.allsky_sfc_sw_dwn) AS cell_temperature_c,
	((n.allsky_sfc_sw_dwn / 1000) * (1 - 0.004 * ((n.t2m + 0.03125 * n.allsky_sfc_sw_dwn) - 25)) * 0.86) AS pv_kwh_per_kwp
FROM silver.nasa_power AS n
LEFT JOIN silver.city_location AS c
ON n.city = c.city;

-- =============================================================================
-- Create Dimension: gold.dim_city
-- =============================================================================
DROP VIEW IF EXISTS gold.dim_city;

CREATE VIEW gold.dim_city AS
SELECT
	city_id AS city_key,
	initcap(city) AS city_name,
	latitude,
	longitude,
    elevation_m
FROM silver.city_location;
	
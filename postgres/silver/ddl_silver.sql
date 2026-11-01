/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, if they dont exist.
===============================================================================
*/
CREATE TABLE IF NOT EXISTS silver.nasa_power (
    city                text,
    ts_utc              timestamptz,
    allsky_sfc_sw_dwn   numeric,
    t2m                 numeric,
    ws10m               numeric,
    bronze_id           bigint       NOT NULL,
    dwh_create_date     timestamptz  DEFAULT now(),
    PRIMARY KEY (city, ts_utc)
);

CREATE TABLE IF NOT EXISTS silver.city_location (
    city_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city             text NOT NULL UNIQUE,
    latitude         numeric,
    longitude        numeric,
    elevation_m      numeric,
    dwh_create_date  timestamptz DEFAULT now(),
    dwh_update_date  timestamptz DEFAULT now()
);
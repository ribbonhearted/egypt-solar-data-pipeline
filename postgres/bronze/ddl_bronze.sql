/*
===============================================================================
DDL Script: Create Bronze Table
===============================================================================
Script Purpose:
    This script creates table in the 'bronze' schema, if they dont exist.
===============================================================================
*/

CREATE TABLE IF NOT EXISTS bronze.nasa_power (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city        text        NOT NULL,
    latitude    numeric     NOT NULL,
    longitude   numeric     NOT NULL,
    start_date  date        NOT NULL,
    end_date    date        NOT NULL,
    response    jsonb       NOT NULL,
    fetched_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (city, start_date, end_date)
);
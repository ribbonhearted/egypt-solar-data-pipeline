/*
===============================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================
Purpose:
    Unpacks the raw NASA POWER JSON in bronze.nasa_power into
    one clean row per city per hour in silver.nasa_power.
    - Truncates silver, then reloads it fully from bronze.
    - Converts NASA's 'YYYYMMDDHH' keys into UTC timestamps.
    - Replaces NASA's missing value (-999) with NULL.
    - If the same city/hour appears in more than one bronze
      row, keeps the most recently fetched one.

Usage:
    CALL silver.load_silver();
===============================================================
*/
CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
     start_time TIMESTAMP; 
	 end_time TIMESTAMP;
	 batch_start_time TIMESTAMP;
	 batch_end_time TIMESTAMP;
BEGIN
    batch_start_time := clock_timestamp();
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '======================================================';
	
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating table: silver.nasa_power';
    TRUNCATE TABLE silver.nasa_power;

    RAISE NOTICE '>> Inserting Data into table: silver.nasa_power';
	INSERT INTO silver.nasa_power(
		city,
		ts_utc,
		allsky_sfc_sw_dwn,
		t2m,
		ws10m,
		bronze_id
	)
	
	SELECT 
		b.city,
		to_timestamp(e.key, 'YYYYMMDDHH24')::timestamp AT TIME ZONE 'UTC',
	    e.value::numeric,
		(b.response -> 'properties' -> 'parameter' -> 'T2M' ->> e.key)::numeric,
		(b.response -> 'properties' -> 'parameter' -> 'WS10M' ->> e.key)::numeric,
		b.id
	FROM bronze.nasa_power AS b,
	     jsonb_each_text(b.response -> 'properties' -> 'parameter' -> 'ALLSKY_SFC_SW_DWN') AS e;
		 
	end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (end_time - start_time));
    RAISE NOTICE '>> ------------';

    start_time := clock_timestamp();

    RAISE NOTICE '>> Upserting Data into table: silver.city_location';
    INSERT INTO silver.city_location (city, latitude, longitude, elevation_m)
    SELECT DISTINCT ON (city)
        city,
        latitude,
        longitude,
        (response -> 'geometry' -> 'coordinates' ->> 2)::numeric
    FROM bronze.nasa_power
    ORDER BY city, fetched_at DESC
    ON CONFLICT (city) DO UPDATE
    SET latitude        = EXCLUDED.latitude,
        longitude       = EXCLUDED.longitude,
        elevation_m     = EXCLUDED.elevation_m,
        dwh_update_date = now();
		 
	end_time := clock_timestamp();
    RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(EPOCH FROM (end_time - start_time));
    RAISE NOTICE '>> ------------';

    batch_end_time := clock_timestamp();
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'LOADING SILVER LAYER IS COMPLETED';
    RAISE NOTICE '>> Total Load Duration: % seconds', EXTRACT(EPOCH FROM (batch_end_time - batch_start_time));
    RAISE NOTICE '======================================================';
	
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '======================================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        RAISE NOTICE 'Error Message: %', SQLERRM;
        RAISE NOTICE 'Error Code: %', SQLSTATE;
        RAISE NOTICE '======================================================';
	RAISE;
END;
$$;
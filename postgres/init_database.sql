/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    Runs automatically on the Postgres container's first start
    (empty volume). Creates the 'solar_dw' database and the
    medallion schemas: 'bronze', 'silver', and 'gold'.
*/

-- Create the 'solar_dw' database
CREATE DATABASE solar_dw;

-- Switch to the new database (works because Docker runs this file with psql)
\connect solar_dw

-- Create Schemas
CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;
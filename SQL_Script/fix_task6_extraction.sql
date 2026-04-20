/*
===================================================================================
  FILE : fix_task6_extraction.sql
  DESCRIPTION:
    As the SSIS package 'DFT - Extract to Staging' is empty, this script 
    manually extracts data from OLTP and populates the Staging tables.
    Run this script before running the SCD Type 1 part of the SSIS package.
===================================================================================
*/

-- 1. CLEAN STAGING
USE Airline_Staging;
GO

PRINT 'Truncating stg_Airports and stg_Airlines...';
TRUNCATE TABLE dbo.stg_Airports;
TRUNCATE TABLE dbo.stg_Airlines;
GO

-- 2. EXTRACT AIRPORTS (OLTP -> Staging)
PRINT 'Extracting Airports...';
INSERT INTO dbo.stg_Airports (
    IATA_Code, Airport_Name, City, State, Country, Latitude, Longitude
)
SELECT 
    IATA_Code, 
    Airport_Name, 
    City, 
    State, 
    Country, 
    CAST(Latitude AS NVARCHAR(200)), 
    CAST(Longitude AS NVARCHAR(200))
FROM Airline_OLTP.dbo.tb_Airports;
GO

-- 3. EXTRACT AIRLINES (OLTP -> Staging)
PRINT 'Extracting Airlines...';
INSERT INTO dbo.stg_Airlines (IATA_Code, Airline_Name)
SELECT IATA_Code, Airline_Name
FROM Airline_OLTP.dbo.tb_Airlines;
GO

-- 4. VERIFY STAGING COUNTS
SELECT 'stg_Airports' AS [Table], COUNT(*) AS [Rows] FROM dbo.stg_Airports
UNION ALL
SELECT 'stg_Airlines' AS [Table], COUNT(*) AS [Rows] FROM dbo.stg_Airlines;
GO

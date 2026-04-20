/*
===================================================================================
  FILE : 06_Verify_Dim_Airport_Airline.sql
  DESCRIPTION:
    Validates data integrity across OLTP, Staging, and DWH for Task 6.
===================================================================================
*/

-- 1. COUNT COMPARISON (Integrity Check)
SELECT 'OLTP Airports' AS Source, COUNT(*) AS Rows FROM Airline_OLTP.dbo.tb_Airports
UNION ALL
SELECT 'STG Airports'  AS Source, COUNT(*) AS Rows FROM Airline_Staging.dbo.stg_Airports
UNION ALL
SELECT 'DWH Airports'  AS Source, COUNT(*) AS Rows FROM AirlineDWH.dbo.Dim_Airport WHERE BKAirportCode <> 'UNK'

UNION ALL
SELECT 'OLTP Airlines' AS Source, COUNT(*) AS Rows FROM Airline_OLTP.dbo.tb_Airlines
UNION ALL
SELECT 'STG Airlines'  AS Source, COUNT(*) AS Rows FROM Airline_Staging.dbo.stg_Airlines
UNION ALL
SELECT 'DWH Airlines'  AS Source, COUNT(*) AS Rows FROM AirlineDWH.dbo.Dim_Airline WHERE BKAirlineCode <> 'UN';
GO

-- 2. CHECK UNKNOWN MEMBER (-1)
SELECT 'Dim_Airport Unknown' AS CheckType, BKAirportCode, AirportName FROM AirlineDWH.dbo.Dim_Airport WHERE AirportKey = -1
UNION ALL
SELECT 'Dim_Airline Unknown' AS CheckType, BKAirlineCode, AirlineName FROM AirlineDWH.dbo.Dim_Airline WHERE AirlineKey = -1;
GO

-- 3. DATA SAMPLE (Attribute Check)
PRINT 'Sample from Dim_Airport (Last 5 inserted/updated):';
SELECT TOP 5 BKAirportCode, AirportName, City, State, Latitude, Longitude
FROM AirlineDWH.dbo.Dim_Airport
ORDER BY AirportKey DESC;

PRINT 'Sample from Dim_Airline:';
SELECT TOP 5 BKAirlineCode, AirlineName
FROM AirlineDWH.dbo.Dim_Airline
ORDER BY AirlineKey DESC;
GO

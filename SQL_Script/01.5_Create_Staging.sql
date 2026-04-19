/*
===================================================================================
  FILE : 01.5_Create_Staging.sql
  DB   : Airline_Staging
  DATE : 2026-04-18

  DESCRIPTION:
    Creates the persistent Staging Database for the Airline DWH project. 
    This database serves as a "Landing Zone" for extracting data from OLTP.
    Standardized schema: All data columns are NVARCHAR/VARCHAR to allow
    100% ingestion success. No constraints (PK/FK) to maximize flexibility.
===================================================================================
*/

-- 1. Create Database
USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Airline_Staging')
BEGIN
    CREATE DATABASE Airline_Staging;
END
GO

USE Airline_Staging;
GO

-- 2. Drop existing tables if they exist
DROP TABLE IF EXISTS dbo.stg_Flights;
DROP TABLE IF EXISTS dbo.stg_Aircraft_Master;
DROP TABLE IF EXISTS dbo.stg_Airports;
DROP TABLE IF EXISTS dbo.stg_Airlines;
GO

-- 3. Create Staging Tables

-- stg_Airlines
CREATE TABLE dbo.stg_Airlines (
    IATA_Code      NVARCHAR(200) NULL,
    Airline_Name   NVARCHAR(MAX) NULL,
    Staging_Date   DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- stg_Airports
CREATE TABLE dbo.stg_Airports (
    IATA_Code      NVARCHAR(200) NULL,
    Airport_Name   NVARCHAR(MAX) NULL,
    City           NVARCHAR(MAX) NULL,
    State          NVARCHAR(200) NULL,
    Country        NVARCHAR(200) NULL,
    Latitude       NVARCHAR(200) NULL,
    Longitude      NVARCHAR(200) NULL,
    Staging_Date   DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- stg_Aircraft_Master
CREATE TABLE dbo.stg_Aircraft_Master (
    Tail_Number       NVARCHAR(200) NULL,
    Manufacturer      NVARCHAR(MAX) NULL,
    Model_Name        NVARCHAR(MAX) NULL,
    Year_Manufactured NVARCHAR(200) NULL,
    Engine_Type       NVARCHAR(MAX) NULL,
    No_Engines        NVARCHAR(200) NULL,
    No_Seats          NVARCHAR(200) NULL,
    Airline_Owner     NVARCHAR(200) NULL,
    Staging_Date      DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- stg_Flights
CREATE TABLE dbo.stg_Flights (
    Flight_Year          NVARCHAR(200) NULL,
    Flight_Month         NVARCHAR(200) NULL,
    Flight_Day           NVARCHAR(200) NULL,
    Day_Of_Week          NVARCHAR(200) NULL,
    Airline_Code         NVARCHAR(200) NULL,
    Flight_Number        NVARCHAR(200) NULL,
    Tail_Number          NVARCHAR(200) NULL,
    Origin_Airport       NVARCHAR(200) NULL,
    Destination_Airport  NVARCHAR(200) NULL,
    Scheduled_Departure  NVARCHAR(200) NULL,
    Departure_Time       NVARCHAR(200) NULL,
    Departure_Delay      NVARCHAR(200) NULL,
    Taxi_Out             NVARCHAR(200) NULL,
    Wheels_Off           NVARCHAR(200) NULL,
    Scheduled_Time       NVARCHAR(200) NULL,
    Elapsed_Time         NVARCHAR(200) NULL,
    Air_Time             NVARCHAR(200) NULL,
    Distance             NVARCHAR(200) NULL,
    Wheels_On            NVARCHAR(200) NULL,
    Taxi_In              NVARCHAR(200) NULL,
    Scheduled_Arrival    NVARCHAR(200) NULL,
    Arrival_Time         NVARCHAR(200) NULL,
    Arrival_Delay        NVARCHAR(200) NULL,
    Diverted             NVARCHAR(200) NULL,
    Cancelled            NVARCHAR(200) NULL,
    Cancellation_Reason  NVARCHAR(200) NULL,
    Air_System_Delay     NVARCHAR(200) NULL,
    Security_Delay       NVARCHAR(200) NULL,
    Airline_Delay        NVARCHAR(200) NULL,
    Late_Aircraft_Delay  NVARCHAR(200) NULL,
    Weather_Delay        NVARCHAR(200) NULL,
    Staging_Date         DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

PRINT '========================================================';
PRINT 'SUCCESS: Airline_Staging database and tables created.';
PRINT '  - stg_Airlines';
PRINT '  - stg_Airports';
PRINT '  - stg_Aircraft_Master';
PRINT '  - stg_Flights';
PRINT '========================================================';
GO


-------- update-stagging.sql 
-------- add table Staging_Fact_Aircraft_Daily
USE Airline_Staging;
GO

-- Xóa bảng nếu đã tồn tại để làm mới
IF OBJECT_ID('dbo.Staging_Fact_Aircraft_Daily', 'U') IS NOT NULL 
    DROP TABLE dbo.Staging_Fact_Aircraft_Daily;
GO

CREATE TABLE dbo.Staging_Fact_Aircraft_Daily (
    Tail_Number              NVARCHAR(20) NULL,
    Flight_Date              DATE         NULL,
    Daily_Flight_Count       INT          NULL,
    Daily_Air_Time_Mins      INT          NULL,
    Daily_Airline_Delay_Mins INT          NULL,
    Tech_Incident_Count      INT          NULL
);



GO
--------- giả lập dữ liệu
USE AirlineDWH;
GO

-- 1. Tạm thời xóa các dòng lỗi bạn vừa load vào (nếu có)
TRUNCATE TABLE dbo.Fact_Aircraft_Daily_Snapshot;

-- 2. Giả lập dữ liệu cho Dim_Aircraft từ bảng Staging của bạn
-- Đoạn này sẽ lấy các số đuôi máy bay có trong bảng Staging và nạp tạm vào Dim
INSERT INTO dbo.Dim_Aircraft (BKTailNumber, Manufacturer, ModelName, Valid_From, Is_Active)
SELECT DISTINCT Tail_Number, 'Mock Manufacturer', 'Mock Model', '1900-01-01', 1
FROM Airline_Staging.dbo.Staging_Fact_Aircraft_Daily
WHERE Tail_Number NOT IN (SELECT BKTailNumber FROM dbo.Dim_Aircraft);
GO
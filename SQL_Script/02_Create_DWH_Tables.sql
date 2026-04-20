/*
===================================================================================
  FILE    : 02_Create_DWH_Tables.sql
  PROJECT : Airline Flight Operations & Asset Health DWH
  AUTHOR  : Data Engineering Team (3 members)
  MODEL   : Kimball Lifecycle – Star Schema
  DATE    : 2026-04-18
  DB      : AirlineDWH

  DESCRIPTION:
    Creates all Dimension and Fact tables for the DWH layer.
    Auto-generated from Detailed-Dimensional-Modeling-Workbook-KimballU.xlsm.

  TABLES CREATED:
    Dimensions:
      dbo.Dim_Date
      dbo.Dim_Time
      dbo.Dim_Airport          (SCD Type 1)
      dbo.Dim_Airline          (SCD Type 1)
      dbo.Dim_Aircraft         (SCD Type 2 – Valid_From / Valid_To / Is_Active)

    Facts:
      dbo.Fact_Flight_Transaction      (Transaction Fact)
      dbo.Fact_Aircraft_Daily_Snapshot (Periodic Snapshot Fact)
      dbo.Fact_Turnaround_Efficiency   (Accumulating Snapshot Fact)

  WATERMARK SUPPORT:
      dbo.ETL_Watermark                (Incremental Load CDC table)

  EXECUTION ORDER:
    Run this script AFTER 01_Create_OLTP_Staging_DB.sql.
    Drop-create order is safe (DROP IF EXISTS before each CREATE).
===================================================================================
*/

USE master;
GO

-- Tạo database AirlineDWH nếu chưa tồn tại
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'AirlineDWH')
BEGIN
    CREATE DATABASE AirlineDWH;
END
GO

USE AirlineDWH;
GO

-- ====================================================================================================
-- 0. HELPER: Audit Dimension (required FK target for all tables)
-- ====================================================================================================
IF OBJECT_ID('dbo.Dim_Audit', 'U') IS NOT NULL DROP TABLE dbo.Dim_Audit;
GO

CREATE TABLE dbo.Dim_Audit (
    AuditKey           INT           NOT NULL IDENTITY(1,1),
    ETL_Package        NVARCHAR(100) NOT NULL,
    ETL_RunDate        DATETIME      NOT NULL DEFAULT GETDATE(),
    ETL_RowsInserted   INT           NOT NULL DEFAULT 0,
    ETL_RowsUpdated    INT           NOT NULL DEFAULT 0,
    ETL_ServerName     NVARCHAR(50)  NULL,
    ETL_DatabaseName   NVARCHAR(50)  NULL,
    CONSTRAINT PK_Dim_Audit PRIMARY KEY CLUSTERED (AuditKey)
);
GO

-- Insert unknown member
SET IDENTITY_INSERT dbo.Dim_Audit ON;
INSERT INTO dbo.Dim_Audit (AuditKey, ETL_Package, ETL_RunDate, ETL_RowsInserted, ETL_RowsUpdated)
VALUES (-1, 'Unknown', '1900-01-01', 0, 0);
SET IDENTITY_INSERT dbo.Dim_Audit OFF;
GO

-- ====================================================================================================
-- 1. DIMENSION: Dim_Date
--    Type: SCD Type 0 (static, auto-generated)
--    Grain: One row per calendar date
--    Hierarchy: Year > Quarter > Month > Day
-- ====================================================================================================
IF OBJECT_ID('dbo.Dim_Date', 'U') IS NOT NULL DROP TABLE dbo.Dim_Date;
GO

CREATE TABLE dbo.Dim_Date (
    -- KEY
    DateKey                 INT       NOT NULL,          -- YYYYMMDD integer format

    -- ATTRIBUTES – SCD Type 0 (never change)
    FullDateAlternateKey    DATE      NOT NULL,          -- Full calendar date
    DayNumberOfWeek         SMALLINT   NOT NULL,          -- Changed from TINYINT to avoid -1 overflow
    DayNameOfWeek           NVARCHAR(10) NOT NULL,
    DayOfMonth              SMALLINT   NOT NULL,          -- Changed from TINYINT
    MonthNumber             SMALLINT   NOT NULL,          -- Changed from TINYINT
    MonthName               NVARCHAR(15) NOT NULL,
    CalendarQuarter         SMALLINT   NOT NULL,          -- Changed from TINYINT
    CalendarYear            SMALLINT   NOT NULL,
    IsWeekend               BIT       NOT NULL DEFAULT 0, -- 1=Saturday/Sunday

    -- AUDIT
    InsertAuditKey          INT       NOT NULL DEFAULT -1,

    CONSTRAINT PK_Dim_Date PRIMARY KEY CLUSTERED (DateKey),
    CONSTRAINT FK_Dim_Date_Audit FOREIGN KEY (InsertAuditKey)
        REFERENCES dbo.Dim_Audit (AuditKey)
);
GO

-- Unknown member row
INSERT INTO dbo.Dim_Date (
    DateKey, FullDateAlternateKey,
    DayNumberOfWeek, DayNameOfWeek, DayOfMonth,
    MonthNumber, MonthName, CalendarQuarter, CalendarYear, IsWeekend,
    InsertAuditKey
)
VALUES (
    -1, '1900-01-01',
    -1, 'Unknown', -1,
    -1, 'Unknown', -1, -1, 0,
    -1
);
GO

-- Extended property / table description
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Date dimension auto-generated from SQL script. Covers all calendar dates in dataset range (2015). Hierarchy: Year > Quarter > Month > Day.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Dim_Date';
GO


-- ====================================================================================================
-- 2. DIMENSION: Dim_Time
--    Type: SCD Type 0 (static, 1,440 rows – one per minute)
--    Grain: One row per minute of day
--    Hierarchy: Time_Period > Hour > Minute
-- ====================================================================================================
IF OBJECT_ID('dbo.Dim_Time', 'U') IS NOT NULL DROP TABLE dbo.Dim_Time;
GO

CREATE TABLE dbo.Dim_Time (
    -- KEY
    TimeKey             SMALLINT    NOT NULL,         -- HHMM integer e.g. 1530

    -- ATTRIBUTES – SCD Type 0
    TimeValue           CHAR(5)     NOT NULL,         -- "15:30"
    HourNumber          SMALLINT    NOT NULL,         -- Changed from TINYINT to avoid -1 overflow
    MinuteNumber        SMALLINT    NOT NULL,         -- Changed from TINYINT
    TimePeriod          NVARCHAR(20) NOT NULL,

    -- AUDIT
    InsertAuditKey      INT         NOT NULL DEFAULT -1,

    CONSTRAINT PK_Dim_Time PRIMARY KEY CLUSTERED (TimeKey),
    CONSTRAINT FK_Dim_Time_Audit FOREIGN KEY (InsertAuditKey)
        REFERENCES dbo.Dim_Audit (AuditKey)
);
GO

INSERT INTO dbo.Dim_Time (TimeKey, TimeValue, HourNumber, MinuteNumber, TimePeriod, InsertAuditKey)
VALUES (-1, '00:00', -1, -1, 'Unknown', -1);
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Time-of-day dimension at minute granularity (1,440 rows). Hierarchy: Time_Period > Hour > Minute.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Dim_Time';
GO


-- ====================================================================================================
-- 3. DIMENSION: Dim_Airport
--    Type: SCD Type 1 (overwrite on change)
--    Grain: One row per IATA airport code
--    Hierarchy: State > City > Airport_Code
--    Source: airports.csv (Kaggle)
-- ====================================================================================================
IF OBJECT_ID('dbo.Dim_Airport', 'U') IS NOT NULL DROP TABLE dbo.Dim_Airport;
GO

CREATE TABLE dbo.Dim_Airport (
    -- KEY
    AirportKey          INT           NOT NULL IDENTITY(1,1),

    -- BUSINESS KEY
    BKAirportCode       NCHAR(3)      NOT NULL,        -- IATA 3-letter code

    -- ATTRIBUTES – SCD Type 1 (overwrite)
    AirportName         NVARCHAR(100) NOT NULL,
    City                NVARCHAR(50)  NOT NULL,
    State               NCHAR(2)      NOT NULL,
    Latitude            DECIMAL(8,4)  NULL,
    Longitude           DECIMAL(9,4)  NULL,

    -- AUDIT
    InsertAuditKey      INT           NOT NULL DEFAULT -1,
    UpdateAuditKey      INT           NOT NULL DEFAULT -1,

    CONSTRAINT PK_Dim_Airport PRIMARY KEY CLUSTERED (AirportKey),
    CONSTRAINT UQ_Dim_Airport_BK UNIQUE (BKAirportCode),
    CONSTRAINT FK_Dim_Airport_InsAudit FOREIGN KEY (InsertAuditKey)
        REFERENCES dbo.Dim_Audit (AuditKey),
    CONSTRAINT FK_Dim_Airport_UpdAudit FOREIGN KEY (UpdateAuditKey)
        REFERENCES dbo.Dim_Audit (AuditKey)
);
GO

SET IDENTITY_INSERT dbo.Dim_Airport ON;
INSERT INTO dbo.Dim_Airport (AirportKey, BKAirportCode, AirportName, City, State, InsertAuditKey, UpdateAuditKey)
VALUES (-1, 'UNK', 'Unknown Airport', 'Unknown City', 'UN', -1, -1);
SET IDENTITY_INSERT dbo.Dim_Airport OFF;
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Airport reference data – SCD Type 1 (overwrite). Hierarchy: State > City > Airport_Code. Source: airports.csv.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Dim_Airport';
GO


-- ====================================================================================================
-- 4. DIMENSION: Dim_Airline
--    Type: SCD Type 1 (overwrite on change)
--    Grain: One row per IATA airline code
--    Source: airlines.csv (Kaggle)
-- ====================================================================================================
IF OBJECT_ID('dbo.Dim_Airline', 'U') IS NOT NULL DROP TABLE dbo.Dim_Airline;
GO

CREATE TABLE dbo.Dim_Airline (
    -- KEY
    AirlineKey          INT           NOT NULL IDENTITY(1,1),

    -- BUSINESS KEY
    BKAirlineCode       NCHAR(2)      NOT NULL,        -- IATA 2-letter code

    -- ATTRIBUTES – SCD Type 1 (overwrite)
    AirlineName         NVARCHAR(100) NOT NULL,

    -- AUDIT
    InsertAuditKey      INT           NOT NULL DEFAULT -1,
    UpdateAuditKey      INT           NOT NULL DEFAULT -1,

    CONSTRAINT PK_Dim_Airline PRIMARY KEY CLUSTERED (AirlineKey),
    CONSTRAINT UQ_Dim_Airline_BK UNIQUE (BKAirlineCode),
    CONSTRAINT FK_Dim_Airline_InsAudit FOREIGN KEY (InsertAuditKey)
        REFERENCES dbo.Dim_Audit (AuditKey),
    CONSTRAINT FK_Dim_Airline_UpdAudit FOREIGN KEY (UpdateAuditKey)
        REFERENCES dbo.Dim_Audit (AuditKey)
);
GO

SET IDENTITY_INSERT dbo.Dim_Airline ON;
INSERT INTO dbo.Dim_Airline (AirlineKey, BKAirlineCode, AirlineName, InsertAuditKey, UpdateAuditKey)
VALUES (-1, 'UN', 'Unknown Airline', -1, -1);
SET IDENTITY_INSERT dbo.Dim_Airline OFF;
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Airline carrier reference data – SCD Type 1 (overwrite). Source: airlines.csv.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Dim_Airline';
GO


-- ====================================================================================================
-- 5. DIMENSION: Dim_Aircraft         *** CORE DIMENSION – SCD TYPE 2 ***
--    Type: SCD Type 2 (track history of EngineType and AirlineOwner changes)
--    Grain: One row per version of an aircraft (per Tail Number)
--    Business Key: BKTailNumber (TAIL_NUMBER in flights.csv)
--    SCD-2 Tracking Columns: Valid_From, Valid_To, Is_Active
--    Source: flights.csv (TAIL_NUMBER) + FAA ardata.pdf (enrichment)
--    Hierarchy: Manufacturer > Engine_Type > Tail_Number
-- ====================================================================================================
IF OBJECT_ID('dbo.Dim_Aircraft', 'U') IS NOT NULL DROP TABLE dbo.Dim_Aircraft;
GO

CREATE TABLE dbo.Dim_Aircraft (
    -- KEY (unique per version row)
    AircraftKey         INT           NOT NULL IDENTITY(1,1),

    -- BUSINESS KEY (multiple rows per tail number – one per SCD-2 version)
    BKTailNumber        NVARCHAR(10)  NOT NULL,        -- FAA N-number

    -- ATTRIBUTES – SCD Type 1 (overwrite in place, do NOT trigger new version)
    Manufacturer        NVARCHAR(50)  NOT NULL DEFAULT 'Unknown Manufacturer',
    ModelName           NVARCHAR(50)  NOT NULL DEFAULT 'Unknown Model',
    YearManufactured    SMALLINT      NULL,             -- From FAA ardata.pdf
    AircraftAgeBand     NVARCHAR(10)  NOT NULL DEFAULT 'Unknown',  -- Derived: <5 / 5-15 / >15 yrs

    -- ATTRIBUTES – SCD Type 2 (tracked – changes trigger new version row)
    EngineType          NVARCHAR(30)  NOT NULL DEFAULT 'Unknown',  -- FAA ENG TYPE
    AirlineOwner        NCHAR(2)      NOT NULL DEFAULT 'UN',       -- Operating carrier code

    -- *** SCD TYPE 2 TRACKING COLUMNS ***
    Valid_From          DATE          NOT NULL DEFAULT '1900-01-01',  -- Effective start date of this version
    Valid_To            DATE          NOT NULL DEFAULT '9999-12-31',  -- Expiry date (9999-12-31 = current)
    Is_Active           BIT           NOT NULL DEFAULT 1,             -- 1 = current row, 0 = historical

    -- AUDIT
    InsertAuditKey      INT           NOT NULL DEFAULT -1,
    UpdateAuditKey      INT           NOT NULL DEFAULT -1,

    CONSTRAINT PK_Dim_Aircraft PRIMARY KEY CLUSTERED (AircraftKey),
    CONSTRAINT FK_Dim_Aircraft_InsAudit FOREIGN KEY (InsertAuditKey)
        REFERENCES dbo.Dim_Audit (AuditKey),
    CONSTRAINT FK_Dim_Aircraft_UpdAudit FOREIGN KEY (UpdateAuditKey)
        REFERENCES dbo.Dim_Audit (AuditKey)
);
GO

-- Create index on BKTailNumber + Is_Active for fast FK lookups
CREATE NONCLUSTERED INDEX IX_Dim_Aircraft_TailNumber_Active
    ON dbo.Dim_Aircraft (BKTailNumber, Is_Active)
    INCLUDE (AircraftKey, Valid_From, Valid_To);
GO

-- Unknown member
SET IDENTITY_INSERT dbo.Dim_Aircraft ON;
INSERT INTO dbo.Dim_Aircraft (
    AircraftKey, BKTailNumber, Manufacturer, ModelName, AircraftAgeBand,
    EngineType, AirlineOwner,
    Valid_From, Valid_To, Is_Active,
    InsertAuditKey, UpdateAuditKey
)
VALUES (
    -1, 'UNKNOWN', 'Unknown Manufacturer', 'Unknown Model', 'Unknown',
    'Unknown', 'UN',
    '1900-01-01', '9999-12-31', 1,
    -1, -1
);
SET IDENTITY_INSERT dbo.Dim_Aircraft OFF;
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Aircraft (tail number) dimension enriched with FAA Registry. SCD Type 2 tracks EngineType and AirlineOwner changes. Business Key = TAIL_NUMBER. Hierarchy: Manufacturer > Engine_Type > Tail_Number.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Dim_Aircraft';
GO


-- ====================================================================================================
-- 6. FACT TABLE: Fact_Flight_Transaction
--    Type: Transaction Fact
--    Grain: One row per flight leg
--    Source: flights.csv (~6 million rows)
-- ====================================================================================================
IF OBJECT_ID('dbo.Fact_Flight_Transaction', 'U') IS NOT NULL DROP TABLE dbo.Fact_Flight_Transaction;
GO

CREATE TABLE dbo.Fact_Flight_Transaction (
    -- SURROGATE PK
    FlightTransactionKey    BIGINT        NOT NULL IDENTITY(1,1),

    -- FOREIGN KEYS
    DateKey                 INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Date
    DepTimeKey              SMALLINT      NOT NULL DEFAULT -1,    -- FK -> Dim_Time (scheduled dep)
    ArrTimeKey              SMALLINT      NOT NULL DEFAULT -1,    -- FK -> Dim_Time (scheduled arr)
    OriginAirportKey        INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Airport (origin)
    DestAirportKey          INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Airport (dest)
    AirlineKey              INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Airline
    AircraftKey             INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Aircraft (SCD-2 active row)
    InsertAuditKey          INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Audit

    -- NATURAL KEY
    BKFlightID              NVARCHAR(30)  NOT NULL,               -- AIRLINE + FLIGHT_NUMBER + FL_DATE

    -- MEASURES
    Distance                INT           NULL,                   -- Source: DISTANCE (statute miles)
    Dep_Delay_Mins          SMALLINT      NOT NULL DEFAULT 0,    -- Source: DEP_DELAY (ISNULL->0)
    Arr_Delay_Mins          SMALLINT      NOT NULL DEFAULT 0,    -- Source: ARR_DELAY (ISNULL->0)
    Weather_Delay_Mins      SMALLINT      NOT NULL DEFAULT 0,    -- Source: WEATHER_DELAY
    Carrier_Delay_Mins      SMALLINT      NOT NULL DEFAULT 0,    -- Source: CARRIER_DELAY
    NAS_Delay_Mins          SMALLINT      NOT NULL DEFAULT 0,    -- Source: NAS_DELAY
    Security_Delay_Mins     SMALLINT      NOT NULL DEFAULT 0,    -- Source: SECURITY_DELAY
    LateAircraft_Delay_Mins SMALLINT      NOT NULL DEFAULT 0,    -- Source: LATE_AIRCRAFT_DELAY
    Is_Delayed              BIT           NOT NULL DEFAULT 0,    -- ARR_DELAY >= 15 → 1 (DOT rule)
    Is_Cancelled            BIT           NOT NULL DEFAULT 0,    -- Source: CANCELLED
    Cancellation_Code       NCHAR(1)      NULL,                  -- A/B/C/D or NULL
    Air_Time_Mins           SMALLINT      NULL DEFAULT 0,        -- Source: AIR_TIME (ISNULL->0)

    -- DERIVED MEASURE (calculated in SSIS Derived Column)
    Estimated_Financial_Loss_USD  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    -- Formula: CASE WHEN Is_Delayed=1 THEN Arr_Delay_Mins * 74.24 ELSE 0 END

    CONSTRAINT PK_Fact_Flight_Transaction PRIMARY KEY CLUSTERED (FlightTransactionKey),

    -- Foreign Key Constraints
    CONSTRAINT FK_FFT_Date         FOREIGN KEY (DateKey)           REFERENCES dbo.Dim_Date    (DateKey),
    CONSTRAINT FK_FFT_DepTime      FOREIGN KEY (DepTimeKey)        REFERENCES dbo.Dim_Time    (TimeKey),
    CONSTRAINT FK_FFT_ArrTime      FOREIGN KEY (ArrTimeKey)        REFERENCES dbo.Dim_Time    (TimeKey),
    CONSTRAINT FK_FFT_OriginAirport FOREIGN KEY (OriginAirportKey) REFERENCES dbo.Dim_Airport (AirportKey),
    CONSTRAINT FK_FFT_DestAirport  FOREIGN KEY (DestAirportKey)    REFERENCES dbo.Dim_Airport (AirportKey),
    CONSTRAINT FK_FFT_Airline      FOREIGN KEY (AirlineKey)        REFERENCES dbo.Dim_Airline (AirlineKey),
    CONSTRAINT FK_FFT_Aircraft     FOREIGN KEY (AircraftKey)       REFERENCES dbo.Dim_Aircraft(AircraftKey),
    CONSTRAINT FK_FFT_Audit        FOREIGN KEY (InsertAuditKey)    REFERENCES dbo.Dim_Audit   (AuditKey)
);
GO

-- Performance indexes
CREATE NONCLUSTERED INDEX IX_FFT_DateKey       ON dbo.Fact_Flight_Transaction (DateKey);
CREATE NONCLUSTERED INDEX IX_FFT_AirlineKey    ON dbo.Fact_Flight_Transaction (AirlineKey);
CREATE NONCLUSTERED INDEX IX_FFT_AircraftKey   ON dbo.Fact_Flight_Transaction (AircraftKey);
CREATE NONCLUSTERED INDEX IX_FFT_OriginDest    ON dbo.Fact_Flight_Transaction (OriginAirportKey, DestAirportKey);
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Transaction Fact. Grain: one row per flight leg. Source: flights.csv (~6M rows). Tracks on-time performance and estimated financial loss per flight.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Fact_Flight_Transaction';
GO


-- ====================================================================================================
-- 7. FACT TABLE: Fact_Aircraft_Daily_Snapshot
--    Type: Periodic Snapshot Fact
--    Grain: One row per aircraft per calendar day
--    Source: Aggregated from Fact_Flight_Transaction in Staging
-- ====================================================================================================
IF OBJECT_ID('dbo.Fact_Aircraft_Daily_Snapshot', 'U') IS NOT NULL DROP TABLE dbo.Fact_Aircraft_Daily_Snapshot;
GO

CREATE TABLE dbo.Fact_Aircraft_Daily_Snapshot (
    -- SURROGATE PK
    SnapshotKey                 BIGINT     NOT NULL IDENTITY(1,1),

    -- FOREIGN KEYS
    DateKey                     INT        NOT NULL DEFAULT -1,    -- FK -> Dim_Date
    AircraftKey                 INT        NOT NULL DEFAULT -1,    -- FK -> Dim_Aircraft
    AirlineKey                  INT        NOT NULL DEFAULT -1,    -- FK -> Dim_Airline
    InsertAuditKey              INT        NOT NULL DEFAULT -1,    -- FK -> Dim_Audit

    -- MEASURES
    Daily_Flight_Count          SMALLINT    NOT NULL DEFAULT 0,    -- Changed from TINYINT
    Daily_Air_Time              SMALLINT    NOT NULL DEFAULT 0,    -- SUM(AIR_TIME) per tail per day (mins)

    -- Asset Health KPI
    Tech_Incident_Count         SMALLINT    NOT NULL DEFAULT 0,    -- Changed from TINYINT
                                                                   -- Proxy: carrier-delay as tech incident

    -- Maintenance planning KPI (window function in Staging)
    Cumulative_Flight_Hours     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    -- SUM(AIR_TIME/60.0) OVER (PARTITION BY TAIL_NUMBER ORDER BY FL_DATE ROWS UNBOUNDED PRECEDING)

    Daily_Delay_Mins_Total      SMALLINT   NOT NULL DEFAULT 0,    -- SUM(ARR_DELAY) per tail per day

    CONSTRAINT PK_Fact_Aircraft_Daily_Snapshot PRIMARY KEY CLUSTERED (SnapshotKey),

    CONSTRAINT FK_FADS_Date     FOREIGN KEY (DateKey)        REFERENCES dbo.Dim_Date    (DateKey),
    CONSTRAINT FK_FADS_Aircraft FOREIGN KEY (AircraftKey)    REFERENCES dbo.Dim_Aircraft(AircraftKey),
    CONSTRAINT FK_FADS_Airline  FOREIGN KEY (AirlineKey)     REFERENCES dbo.Dim_Airline (AirlineKey),
    CONSTRAINT FK_FADS_Audit    FOREIGN KEY (InsertAuditKey) REFERENCES dbo.Dim_Audit   (AuditKey)
);
GO

-- Unique constraint: one snapshot row per aircraft per day
CREATE UNIQUE NONCLUSTERED INDEX UQ_FADS_AircraftDate
    ON dbo.Fact_Aircraft_Daily_Snapshot (AircraftKey, DateKey);
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Periodic Snapshot Fact. Grain: one row per aircraft per calendar day. Supports asset health KPIs: tech incident frequency, cumulative flight hours for maintenance scheduling.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Fact_Aircraft_Daily_Snapshot';
GO


-- ====================================================================================================
-- 8. FACT TABLE: Fact_Turnaround_Efficiency
--    Type: Accumulating Snapshot Fact
--    Grain: One row per ground turnaround cycle (one aircraft at one airport)
--    Milestones: Arrival_Time (inbound) → Departure_Time (outbound)
--    Source: Staging using SQL Window Function LAG() on TAIL_NUMBER + DEST/ORIGIN
-- ====================================================================================================
IF OBJECT_ID('dbo.Fact_Turnaround_Efficiency', 'U') IS NOT NULL DROP TABLE dbo.Fact_Turnaround_Efficiency;
GO

CREATE TABLE dbo.Fact_Turnaround_Efficiency (
    -- SURROGATE PK
    TurnaroundKey           BIGINT        NOT NULL IDENTITY(1,1),

    -- FOREIGN KEYS
    ArrivalDateKey          INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Date (inbound date)
    DepartureDateKey        INT           NULL,                   -- FK -> Dim_Date (outbound date, NULL until updated)
    ArrivalTimeKey          SMALLINT      NOT NULL DEFAULT -1,    -- FK -> Dim_Time (actual arrival)
    DepartureTimeKey        SMALLINT      NULL,                   -- FK -> Dim_Time (actual departure, NULL until updated)
    AirportKey              INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Airport (turnaround location)
    AircraftKey             INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Aircraft
    AirlineKey              INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Airline
    InsertAuditKey          INT           NOT NULL DEFAULT -1,    -- FK -> Dim_Audit

    -- NATURAL KEYS
    BKInboundFlightID       NVARCHAR(30)  NOT NULL,               -- Inbound flight BK
    BKOutboundFlightID      NVARCHAR(30)  NULL,                   -- Outbound flight BK (NULL until departure)

    -- MILESTONE TIMESTAMPS (populated as each milestone is reached)
    Actual_Arrival_Time     DATETIME      NOT NULL,               -- Milestone 1: Inbound arrival
    Actual_Departure_Time   DATETIME      NULL,                   -- Milestone 2: Outbound departure (updated)

    -- MEASURES
    Planned_Turnaround_Mins SMALLINT      NOT NULL DEFAULT 45,   -- Changed from TINYINT
    Actual_Turnaround_Mins  SMALLINT      NULL,                  -- DATEDIFF(min, Arrival, Departure)
    Turnaround_Variance_Mins SMALLINT     NULL,                  -- Actual - Planned (positive = bottleneck)
    Is_Bottleneck           BIT           NOT NULL DEFAULT 0,    -- 1 if Variance > 30 mins

    CONSTRAINT PK_Fact_Turnaround_Efficiency PRIMARY KEY CLUSTERED (TurnaroundKey),

    CONSTRAINT FK_FTE_ArrDate    FOREIGN KEY (ArrivalDateKey)    REFERENCES dbo.Dim_Date    (DateKey),
    CONSTRAINT FK_FTE_DepDate    FOREIGN KEY (DepartureDateKey)  REFERENCES dbo.Dim_Date    (DateKey),
    CONSTRAINT FK_FTE_ArrTime    FOREIGN KEY (ArrivalTimeKey)    REFERENCES dbo.Dim_Time    (TimeKey),
    CONSTRAINT FK_FTE_DepTime    FOREIGN KEY (DepartureTimeKey)  REFERENCES dbo.Dim_Time    (TimeKey),
    CONSTRAINT FK_FTE_Airport    FOREIGN KEY (AirportKey)        REFERENCES dbo.Dim_Airport (AirportKey),
    CONSTRAINT FK_FTE_Aircraft   FOREIGN KEY (AircraftKey)       REFERENCES dbo.Dim_Aircraft(AircraftKey),
    CONSTRAINT FK_FTE_Airline    FOREIGN KEY (AirlineKey)        REFERENCES dbo.Dim_Airline (AirlineKey),
    CONSTRAINT FK_FTE_Audit      FOREIGN KEY (InsertAuditKey)    REFERENCES dbo.Dim_Audit   (AuditKey)
);
GO

CREATE NONCLUSTERED INDEX IX_FTE_AirportKey  ON dbo.Fact_Turnaround_Efficiency (AirportKey);
CREATE NONCLUSTERED INDEX IX_FTE_AircraftKey ON dbo.Fact_Turnaround_Efficiency (AircraftKey);
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Accumulating Snapshot Fact. Grain: one row per ground turnaround cycle. Milestones: arrival of inbound flight -> departure of outbound. Identifies Ground Ops bottlenecks at major hubs (ATL, ORD).',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Fact_Turnaround_Efficiency';
GO


-- ====================================================================================================
-- 9. INCREMENTAL LOAD SUPPORT: ETL_Watermark
--    Used by SSIS packages for CDC (Change Data Capture) incremental load.
--    SSIS extracts rows where Updated_Date > Last_Load_Time.
-- ====================================================================================================
IF OBJECT_ID('dbo.ETL_Watermark', 'U') IS NOT NULL DROP TABLE dbo.ETL_Watermark;
GO

CREATE TABLE dbo.ETL_Watermark (
    WatermarkID         INT           NOT NULL IDENTITY(1,1),
    TableName           NVARCHAR(100) NOT NULL,         -- Target DWH table name
    Last_Load_Time      DATETIME      NOT NULL DEFAULT '1900-01-01',  -- Initial load boundary
    Last_Updated        DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_ETL_Watermark PRIMARY KEY CLUSTERED (WatermarkID),
    CONSTRAINT UQ_ETL_Watermark_Table UNIQUE (TableName)
);
GO

-- Seed watermark rows for each fact (incremental load from OLTP Staging)
INSERT INTO dbo.ETL_Watermark (TableName, Last_Load_Time) VALUES
    ('Fact_Flight_Transaction',      '1900-01-01'),
    ('Fact_Aircraft_Daily_Snapshot', '1900-01-01'),
    ('Fact_Turnaround_Efficiency',   '1900-01-01');
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'ETL watermark table for incremental load (CDC pattern). SSIS packages extract from OLTP where Updated_Date > Last_Load_Time.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'ETL_Watermark';
GO


-- ====================================================================================================
-- VERIFY: List all created tables
-- ====================================================================================================
SELECT
    t.name          AS TableName,
    s.name          AS [Schema],
    t.create_date   AS CreatedAt,
    p.rows          AS [RowCount]
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.partitions p ON t.object_id = p.object_id
WHERE s.name = 'dbo'
  AND p.index_id IN (0, 1)
ORDER BY t.create_date;
GO

PRINT '========================================================';
PRINT 'SUCCESS: All DWH tables created for AirlineDWH database.';
PRINT '  - Dim_Audit (helper)';
PRINT '  - Dim_Date       (SCD Type 0)';
PRINT '  - Dim_Time       (SCD Type 0)';
PRINT '  - Dim_Airport    (SCD Type 1)';
PRINT '  - Dim_Airline    (SCD Type 1)';
PRINT '  - Dim_Aircraft   (SCD Type 2 - Valid_From/Valid_To/Is_Active)';
PRINT '  - Fact_Flight_Transaction      (Transaction Fact)';
PRINT '  - Fact_Aircraft_Daily_Snapshot (Periodic Snapshot Fact)';
PRINT '  - Fact_Turnaround_Efficiency   (Accumulating Snapshot Fact)';
PRINT '  - ETL_Watermark  (CDC Incremental Load support)';
PRINT '========================================================';
GO

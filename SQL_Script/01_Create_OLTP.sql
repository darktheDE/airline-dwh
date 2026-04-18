/*
===================================================================================
  FILE : 01_Create_OLTP.sql
  DB   : Airline_OLTP
  DATE : 2026-04-18

  Bước 1 - Tạo 4 bảng
  Bước 2 - BULK INSERT từ CSV
  Bước 3 - Inject dữ liệu bẩn để thực hành ETL

  TRUOC KHI CHAY: Dat 3 file CSV vào thư muc:
    D:\HCMUTE\HCMUTE_HK6\DataWarehouse\final\airline-dwh\Data\2015-flight-delays-and-cancellations\
      airlines.csv
      airports.csv
      flights.csv   (~800MB)
===================================================================================
*/

USE Airline_OLTP;
GO

-- ============================================================
-- BUOC 1: TAO BANG
-- ============================================================

DROP TABLE IF EXISTS dbo.tb_Flights;
DROP TABLE IF EXISTS dbo.tb_Aircraft_Master;
DROP TABLE IF EXISTS dbo.tb_Airports;
DROP TABLE IF EXISTS dbo.tb_Airlines;
GO

CREATE TABLE dbo.tb_Airlines (
    Airline_ID    INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IATA_Code     VARCHAR(2)     NOT NULL UNIQUE,
    Airline_Name  NVARCHAR(100)  NOT NULL,
    Created_Date  DATETIME       NOT NULL DEFAULT GETDATE(),
    Updated_Date  DATETIME       NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.tb_Airports (
    Airport_ID    INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IATA_Code     VARCHAR(3)     NOT NULL UNIQUE,
    Airport_Name  NVARCHAR(150)  NOT NULL,
    City          NVARCHAR(100)  NOT NULL,
    State         VARCHAR(2)     NOT NULL,
    Country       VARCHAR(3)     NOT NULL,
    Latitude      DECIMAL(9,6)   NULL,
    Longitude     DECIMAL(9,6)   NULL,
    Created_Date  DATETIME       NOT NULL DEFAULT GETDATE(),
    Updated_Date  DATETIME       NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.tb_Aircraft_Master (
    Aircraft_ID       INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Tail_Number       VARCHAR(10)   NOT NULL UNIQUE,
    Manufacturer      NVARCHAR(50)  NULL,
    Model_Name        NVARCHAR(50)  NULL,
    Year_Manufactured SMALLINT      NULL,
    Engine_Type       VARCHAR(30)   NULL,
    No_Engines        TINYINT       NULL,
    No_Seats          SMALLINT      NULL,
    Airline_Owner     VARCHAR(2)    NULL,
    Created_Date      DATETIME      NOT NULL DEFAULT GETDATE(),
    Updated_Date      DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.tb_Flights (
    Flight_ID            INT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Flight_Year          SMALLINT     NOT NULL,
    Flight_Month         TINYINT      NOT NULL,
    Flight_Day           TINYINT      NOT NULL,
    Day_Of_Week          TINYINT      NOT NULL,
    Airline_Code         VARCHAR(2)   NOT NULL,
    Flight_Number        INT          NOT NULL,
    Tail_Number          VARCHAR(10)  NULL,
    Origin_Airport       VARCHAR(7)   NOT NULL,  -- VARCHAR(7): dataset dung ca IATA (3 ky tu) va FAA ID (so 4+ ky tu)
    Destination_Airport  VARCHAR(7)   NOT NULL,
    Scheduled_Departure  INT          NULL,
    Departure_Time       INT          NULL,
    Departure_Delay      FLOAT        NULL,
    Taxi_Out             FLOAT        NULL,
    Wheels_Off           INT          NULL,
    Scheduled_Time       FLOAT        NULL,
    Elapsed_Time         FLOAT        NULL,
    Air_Time             FLOAT        NULL,
    Distance             FLOAT        NULL,
    Wheels_On            INT          NULL,
    Taxi_In              FLOAT        NULL,
    Scheduled_Arrival    INT          NULL,
    Arrival_Time         INT          NULL,
    Arrival_Delay        FLOAT        NULL,
    Diverted             BIT          NOT NULL DEFAULT 0,
    Cancelled            BIT          NOT NULL DEFAULT 0,
    Cancellation_Reason  VARCHAR(1)   NULL,
    Air_System_Delay     FLOAT        NULL,
    Security_Delay       FLOAT        NULL,
    Airline_Delay        FLOAT        NULL,
    Late_Aircraft_Delay  FLOAT        NULL,
    Weather_Delay        FLOAT        NULL,
    Created_Date         DATETIME     NOT NULL DEFAULT GETDATE(),
    Updated_Date         DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

PRINT 'Buoc 1 OK: 4 tables created.';
GO


-- ============================================================
-- BUOC 2: BULK INSERT TU CSV
-- Su dung bang staging tam (#stg_*) vi BULK INSERT
-- khong cho phep chi dinh danh sach cot truc tiep
-- ROWTERMINATOR = '0x0a' xu ly ca \n lan \r\n (Windows/Linux CSV)
-- ============================================================

-- airlines.csv (IATA_CODE, AIRLINE)
CREATE TABLE #stg_Airlines (
    IATA_Code    VARCHAR(10),
    Airline_Name NVARCHAR(200)
);

BULK INSERT #stg_Airlines
FROM 'D:\HCMUTE\HCMUTE_HK6\DataWarehouse\final\airline-dwh\Data\2015-flight-delays-and-cancellations\airlines.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    CODEPAGE        = '65001',
    TABLOCK
);

INSERT INTO dbo.tb_Airlines (IATA_Code, Airline_Name)
SELECT
    LTRIM(RTRIM(IATA_Code)),
    LTRIM(RTRIM(Airline_Name))
FROM #stg_Airlines
WHERE LTRIM(RTRIM(ISNULL(IATA_Code,''))) <> '';

DROP TABLE #stg_Airlines;
GO

PRINT 'OK: tb_Airlines loaded.';
SELECT COUNT(*) AS [tb_Airlines rows] FROM dbo.tb_Airlines;
GO


-- airports.csv (IATA_CODE, AIRPORT, CITY, STATE, COUNTRY, LATITUDE, LONGITUDE)
CREATE TABLE #stg_Airports (
    IATA_Code    VARCHAR(10),
    Airport_Name NVARCHAR(200),
    City         NVARCHAR(150),
    State        VARCHAR(10),
    Country      VARCHAR(10),
    Latitude     VARCHAR(20),   -- dung VARCHAR truoc, cast sau de tranh loi format
    Longitude    VARCHAR(20)
);

BULK INSERT #stg_Airports
FROM 'D:\HCMUTE\HCMUTE_HK6\DataWarehouse\final\airline-dwh\Data\2015-flight-delays-and-cancellations\airports.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    CODEPAGE        = '65001',
    TABLOCK
);

INSERT INTO dbo.tb_Airports (IATA_Code, Airport_Name, City, State, Country, Latitude, Longitude)
SELECT
    LTRIM(RTRIM(IATA_Code)),
    LTRIM(RTRIM(Airport_Name)),
    LTRIM(RTRIM(City)),
    LTRIM(RTRIM(State)),
    LTRIM(RTRIM(Country)),
    TRY_CAST(LTRIM(RTRIM(Latitude))  AS DECIMAL(9,6)),
    TRY_CAST(LTRIM(RTRIM(Longitude)) AS DECIMAL(9,6))
FROM #stg_Airports
WHERE LTRIM(RTRIM(ISNULL(IATA_Code,''))) <> '';

DROP TABLE #stg_Airports;
GO

PRINT 'OK: tb_Airports loaded.';
SELECT COUNT(*) AS [tb_Airports rows] FROM dbo.tb_Airports;
GO


-- ============================================================
-- tb_Aircraft_Master: Dung SSMS Import/Export Wizard
-- (FAA MASTER.txt co 34 cot phuc tap)
-- Sau khi Wizard xong, chay:
--   UPDATE dbo.tb_Aircraft_Master
--   SET Created_Date = GETDATE(), Updated_Date = GETDATE();
-- ============================================================
PRINT 'NOTE: tb_Aircraft_Master - load bang SSMS Import/Export Wizard tu FAA MASTER.txt';
GO


-- flights.csv (31 cot theo thu tu goc)
-- Buoc A: Tao bang staging + BULK INSERT (batch rieng)
CREATE TABLE #stg_Flights (
    c01 VARCHAR(10),  -- YEAR
    c02 VARCHAR(10),  -- MONTH
    c03 VARCHAR(10),  -- DAY
    c04 VARCHAR(10),  -- DAY_OF_WEEK
    c05 VARCHAR(5),   -- AIRLINE
    c06 VARCHAR(10),  -- FLIGHT_NUMBER
    c07 VARCHAR(15),  -- TAIL_NUMBER
    c08 VARCHAR(7),   -- ORIGIN_AIRPORT (IATA 3 ky tu hoac FAA ID so)
    c09 VARCHAR(7),   -- DESTINATION_AIRPORT
    c10 VARCHAR(10),  -- SCHEDULED_DEPARTURE
    c11 VARCHAR(10),  -- DEPARTURE_TIME
    c12 VARCHAR(15),  -- DEPARTURE_DELAY
    c13 VARCHAR(15),  -- TAXI_OUT
    c14 VARCHAR(10),  -- WHEELS_OFF
    c15 VARCHAR(15),  -- SCHEDULED_TIME
    c16 VARCHAR(15),  -- ELAPSED_TIME
    c17 VARCHAR(15),  -- AIR_TIME
    c18 VARCHAR(15),  -- DISTANCE
    c19 VARCHAR(10),  -- WHEELS_ON
    c20 VARCHAR(15),  -- TAXI_IN
    c21 VARCHAR(10),  -- SCHEDULED_ARRIVAL
    c22 VARCHAR(10),  -- ARRIVAL_TIME
    c23 VARCHAR(15),  -- ARRIVAL_DELAY
    c24 VARCHAR(5),   -- DIVERTED
    c25 VARCHAR(5),   -- CANCELLED
    c26 VARCHAR(5),   -- CANCELLATION_REASON
    c27 VARCHAR(15),  -- AIR_SYSTEM_DELAY
    c28 VARCHAR(15),  -- SECURITY_DELAY
    c29 VARCHAR(15),  -- AIRLINE_DELAY
    c30 VARCHAR(15),  -- LATE_AIRCRAFT_DELAY
    c31 VARCHAR(15)   -- WEATHER_DELAY
);
GO
-- ^^^ GO o day bat buoc: SQL Server can biet #stg_Flights ton tai
-- truoc khi compile lenh BULK INSERT + INSERT SELECT phia duoi

BULK INSERT #stg_Flights
FROM 'D:\HCMUTE\HCMUTE_HK6\DataWarehouse\final\airline-dwh\Data\2015-flight-delays-and-cancellations\flights.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    CODEPAGE        = '65001',
    MAXERRORS       = 2000,
    TABLOCK
);
GO

-- Buoc B: Chuyen du lieu tu staging vao bang chinh (batch rieng)
INSERT INTO dbo.tb_Flights (
    Flight_Year, Flight_Month, Flight_Day, Day_Of_Week,
    Airline_Code, Flight_Number, Tail_Number,
    Origin_Airport, Destination_Airport,
    Scheduled_Departure, Departure_Time, Departure_Delay,
    Taxi_Out, Wheels_Off, Scheduled_Time, Elapsed_Time,
    Air_Time, Distance, Wheels_On, Taxi_In,
    Scheduled_Arrival, Arrival_Time, Arrival_Delay,
    Diverted, Cancelled, Cancellation_Reason,
    Air_System_Delay, Security_Delay, Airline_Delay,
    Late_Aircraft_Delay, Weather_Delay
)
SELECT
    TRY_CAST(c01 AS SMALLINT),
    TRY_CAST(c02 AS TINYINT),
    TRY_CAST(c03 AS TINYINT),
    TRY_CAST(c04 AS TINYINT),
    LTRIM(RTRIM(c05)),
    TRY_CAST(c06 AS INT),
    NULLIF(LTRIM(RTRIM(c07)), ''),
    LTRIM(RTRIM(c08)),
    LTRIM(RTRIM(c09)),
    TRY_CAST(c10 AS INT),
    NULLIF(TRY_CAST(c11 AS INT), 0),
    TRY_CAST(c12 AS FLOAT),
    TRY_CAST(c13 AS FLOAT),
    TRY_CAST(c14 AS INT),
    TRY_CAST(c15 AS FLOAT),
    TRY_CAST(c16 AS FLOAT),
    TRY_CAST(c17 AS FLOAT),
    TRY_CAST(c18 AS FLOAT),
    TRY_CAST(c19 AS INT),
    TRY_CAST(c20 AS FLOAT),
    TRY_CAST(c21 AS INT),
    TRY_CAST(c22 AS INT),
    TRY_CAST(c23 AS FLOAT),
    CAST(TRY_CAST(c24 AS TINYINT) AS BIT),
    CAST(TRY_CAST(c25 AS TINYINT) AS BIT),
    NULLIF(LTRIM(RTRIM(c26)), ''),
    TRY_CAST(c27 AS FLOAT),
    TRY_CAST(c28 AS FLOAT),
    TRY_CAST(c29 AS FLOAT),
    TRY_CAST(c30 AS FLOAT),
    TRY_CAST(REPLACE(c31, CHAR(13), '') AS FLOAT)
FROM #stg_Flights
WHERE TRY_CAST(c01 AS SMALLINT) IS NOT NULL;

DROP TABLE #stg_Flights;
GO

PRINT 'Buoc 2 OK: Data loaded.';
GO

SELECT 'tb_Airlines'        AS [Table], COUNT(*) AS [Rows] FROM dbo.tb_Airlines      UNION ALL
SELECT 'tb_Airports'        AS [Table], COUNT(*) AS [Rows] FROM dbo.tb_Airports      UNION ALL
SELECT 'tb_Aircraft_Master' AS [Table], COUNT(*) AS [Rows] FROM dbo.tb_Aircraft_Master UNION ALL
SELECT 'tb_Flights'         AS [Table], COUNT(*) AS [Rows] FROM dbo.tb_Flights;
GO


-- ============================================================
-- BUOC 3: INJECT DU LIEU BAN - thuc hanh ETL
-- ============================================================

-- 3.1 NULL bo sung o delay (ETL: ISNULL -> 0)
UPDATE TOP (5000) dbo.tb_Flights
SET Departure_Delay = NULL,
    Arrival_Delay   = NULL
WHERE Cancelled = 0 AND Arrival_Delay IS NOT NULL;
GO

-- 3.2 Departure_Time = 0 thay vi NULL (ETL: NULLIF -> NULL)
UPDATE TOP (2000) dbo.tb_Flights
SET Departure_Time = 0
WHERE Departure_Time IS NULL AND Cancelled = 0;
GO

-- 3.3 Tail_Number mat chu N dau (ETL: CONCAT N)
UPDATE TOP (500) dbo.tb_Flights
SET Tail_Number = SUBSTRING(Tail_Number, 2, LEN(Tail_Number))
WHERE Tail_Number LIKE 'N[0-9]%'
  AND LEN(Tail_Number) > 3;
GO

-- 3.4 Airline_Delay am vo ly (ETL: IIF < 0 thi = 0)
UPDATE TOP (300) dbo.tb_Flights
SET Airline_Delay = -1 * ABS(ISNULL(Airline_Delay, 5))
WHERE Airline_Delay > 0;
GO

-- 3.5 Cancelled=1 nhung van co Arrival_Time (ETL: Conditional Split)
UPDATE TOP (200) dbo.tb_Flights
SET Arrival_Time = 1200
WHERE Cancelled = 1 AND Arrival_Time IS NULL;
GO

-- 3.6 SCD Type 2 Demo Tuan 3: doi Engine_Type 5 tau bay
--     Updated_Date = 2026-02-01 -> SSIS se detect khi chay incremental load
UPDATE dbo.tb_Aircraft_Master
SET Engine_Type  = 'Turbo-fan',
    Updated_Date = '2026-02-01 08:00:00'
WHERE Tail_Number IN (
    SELECT TOP 5 Tail_Number
    FROM   dbo.tb_Flights
    WHERE  Tail_Number IS NOT NULL
    GROUP  BY Tail_Number
    ORDER  BY COUNT(*) DESC
);
GO

PRINT 'Buoc 3 OK: Dirty data injected.';
PRINT 'ETL practice:';
PRINT '  [3.1] 5000 rows: NULL Delay -> ISNULL(..., 0)';
PRINT '  [3.2] 2000 rows: Departure_Time=0 -> NULLIF(col, 0)';
PRINT '  [3.3]  500 rows: Tail_Number mat chu N -> CONCAT';
PRINT '  [3.4]  300 rows: Airline_Delay am -> IIF(col<0, 0, col)';
PRINT '  [3.5]  200 rows: Cancelled=1 co Arrival_Time -> Conditional Split';
PRINT '  [3.6]    5 rows: Engine_Type thay doi (SCD-2 demo Tuan 3)';
GO












------------------------ PHẦN DATASET 2
USE Airline_OLTP;
GO

-- 1. Tạo bảng tạm để chứa dữ liệu thô từ FAA MASTER.txt
CREATE TABLE #stg_FAA_Master (
    N_Number          VARCHAR(10),
    Serial_Number     VARCHAR(30),
    Mfr_Mdl_Code      VARCHAR(10),
    Eng_Mfr_Mdl       VARCHAR(10),
    Year_Mfr          VARCHAR(10),
    Type_Registrant   VARCHAR(10),
    Name              VARCHAR(100),
    Street            VARCHAR(100),
    Street2           VARCHAR(100),
    City              VARCHAR(50),
    State             VARCHAR(10),
    Zip_Code          VARCHAR(20),
    Region            VARCHAR(10),
    County            VARCHAR(10),
    Country           VARCHAR(10),
    Last_Action_Date  VARCHAR(20),
    Cert_Issue_Date   VARCHAR(20),
    Certification     VARCHAR(20),
    Type_Aircraft     VARCHAR(10),
    Type_Engine       VARCHAR(10),
    Status_Code       VARCHAR(10),
    Mode_S_Code       VARCHAR(20),
    Fract_Owner       VARCHAR(10),
    Air_Worth_Date    VARCHAR(20),
    Other_Names1      VARCHAR(100),
    Other_Names2      VARCHAR(100),
    Other_Names3      VARCHAR(100),
    Other_Names4      VARCHAR(100),
    Other_Names5      VARCHAR(100),
    Expiration_Date   VARCHAR(20),
    Unique_ID         VARCHAR(20),
    Kit_Mfr           VARCHAR(50),
    Kit_Model         VARCHAR(50),
    Mode_S_Code_Hex   VARCHAR(20),
    Dummy             VARCHAR(10) -- Cột dư cuối file
);

-- 2. Tạo bảng tạm để chứa dữ liệu hãng/model từ ACFTREF.txt
CREATE TABLE #stg_FAA_Ref (
    Code            VARCHAR(10),
    Mfr             VARCHAR(100),
    Model           VARCHAR(100),
    Type_Acft       VARCHAR(10),
    Type_Eng        VARCHAR(10),
    Ac_Cat          VARCHAR(10),
    Build_Cert_Ind  VARCHAR(10),
    No_Eng          VARCHAR(10),
    No_Seats        VARCHAR(10),
    Ac_Weight       VARCHAR(20),
    Speed           VARCHAR(10),
    TC_Data_Sheet   VARCHAR(50),
    TC_Data_Holder  VARCHAR(100)
);
GO

-- 3. BULK INSERT vào Staging (Sửa đường dẫn nếu cần)
BULK INSERT #stg_FAA_Master
FROM 'D:\HCMUTE\HCMUTE_HK6\DataWarehouse\final\airline-dwh\Data\faa-aircraft-registry\MASTER.txt'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

BULK INSERT #stg_FAA_Ref
FROM 'D:\HCMUTE\HCMUTE_HK6\DataWarehouse\final\airline-dwh\Data\faa-aircraft-registry\ACFTREF.txt'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);
GO

-- 4. Tổng hợp và INSERT vào bảng chính tb_Aircraft_Master
TRUNCATE TABLE dbo.tb_Aircraft_Master;

INSERT INTO dbo.tb_Aircraft_Master (
    Tail_Number, Manufacturer, Model_Name, Year_Manufactured, 
    Engine_Type, No_Engines, No_Seats, Created_Date, Updated_Date
)
SELECT 
    'N' + LTRIM(RTRIM(m.N_Number)), -- Gắn thêm chữ N để khớp với flights.csv
    LTRIM(RTRIM(r.Mfr)), 
    LTRIM(RTRIM(r.Model)),
    TRY_CAST(LTRIM(RTRIM(m.Year_Mfr)) AS SMALLINT),
    CASE LTRIM(RTRIM(m.Type_Engine))
        WHEN '1' THEN 'Reciprocating'
        WHEN '2' THEN 'Turbo-prop'
        WHEN '3' THEN 'Turbo-shaft'
        WHEN '4' THEN 'Turbo-jet'
        WHEN '5' THEN 'Turbo-fan'
        ELSE 'Other'
    END,
    TRY_CAST(LTRIM(RTRIM(r.No_Eng)) AS TINYINT),
    TRY_CAST(LTRIM(RTRIM(r.No_Seats)) AS SMALLINT),
    GETDATE(),
    GETDATE()
FROM #stg_FAA_Master m
LEFT JOIN #stg_FAA_Ref r ON LTRIM(RTRIM(m.Mfr_Mdl_Code)) = LTRIM(RTRIM(r.Code))
WHERE LTRIM(RTRIM(m.N_Number)) <> '';

-- 5. Cập nhật Airline_Owner dựa trên dữ liệu bay thực tế có nhiều nhất
UPDATE am
SET am.Airline_Owner = top_airline.Airline_Code
FROM dbo.tb_Aircraft_Master am
JOIN (
    SELECT Tail_Number, Airline_Code, 
           ROW_NUMBER() OVER(PARTITION BY Tail_Number ORDER BY COUNT(*) DESC) as rn
    FROM dbo.tb_Flights
    WHERE Tail_Number IS NOT NULL
    GROUP BY Tail_Number, Airline_Code
) top_airline ON am.Tail_Number = top_airline.Tail_Number
WHERE top_airline.rn = 1;

-- 6. Dọn dẹp
DROP TABLE #stg_FAA_Master;
DROP TABLE #stg_FAA_Ref;

-- Kiểm tra lại số dòng
SELECT COUNT(*) AS [tb_Aircraft_Master Total] FROM dbo.tb_Aircraft_Master;

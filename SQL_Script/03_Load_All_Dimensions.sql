/*
===================================================================================
Script: 03_Load_All_Dimensions.sql
Description: Nạp dữ liệu cho các bảng Dimension cốt lõi (Date, Time, Airport, Airline)
             giúp bỏ qua bước cấu hình SSIS phức tạp.
Dữ liệu nguồn: Airline_OLTP
Dữ liệu đích: AirlineDWH
===================================================================================
*/

USE AirlineDWH;
GO

PRINT 'Bắt đầu nạp dữ liệu Dimensions...';

-- 1. NẠP DỮ LIỆU DIM_DATE (Năm 2015)
-- ============================================================
PRINT '1. Đang nạp Dim_Date...';
SET NOCOUNT ON;

-- Xóa dữ liệu cũ (trừ dòng Unknown -1)
DELETE FROM dbo.Dim_Date WHERE DateKey <> -1;

DECLARE @StartDate DATE = '2015-01-01';
DECLARE @EndDate DATE = '2015-12-31';
DECLARE @CurrentDate DATE = @StartDate;

WHILE @CurrentDate <= @EndDate
BEGIN
    INSERT INTO dbo.Dim_Date (
        DateKey, FullDateAlternateKey, DayNumberOfWeek, DayNameOfWeek, 
        DayOfMonth, MonthNumber, MonthName, CalendarQuarter, CalendarYear, 
        IsWeekend, InsertAuditKey
    )
    SELECT 
        CAST(CONVERT(VARCHAR(8), @CurrentDate, 112) AS INT),
        @CurrentDate,
        DATEPART(WEEKDAY, @CurrentDate),
        DATENAME(WEEKDAY, @CurrentDate),
        DATEPART(DAY, @CurrentDate),
        DATEPART(MONTH, @CurrentDate),
        DATENAME(MONTH, @CurrentDate),
        DATEPART(QUARTER, @CurrentDate),
        DATEPART(YEAR, @CurrentDate),
        CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 1 ELSE 0 END,
        -1;

    SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
END
GO
PRINT 'DONE: Dim_Date loaded.';

-- 2. NẠP DỮ LIỆU DIM_TIME (1,440 phút)
-- ============================================================
PRINT '2. Đang nạp Dim_Time...';

-- Xóa dữ liệu cũ (trừ dòng Unknown -1)
DELETE FROM dbo.Dim_Time WHERE TimeKey <> -1;

DECLARE @Hour INT = 0;
DECLARE @Minute INT = 0;

WHILE @Hour < 24
BEGIN
    SET @Minute = 0;
    WHILE @Minute < 60
    BEGIN
        INSERT INTO dbo.Dim_Time (TimeKey, TimeValue, HourNumber, MinuteNumber, TimePeriod, InsertAuditKey)
        SELECT 
            (@Hour * 100) + @Minute,
            RIGHT('0' + CAST(@Hour AS VARCHAR(2)), 2) + ':' + RIGHT('0' + CAST(@Minute AS VARCHAR(2)), 2),
            @Hour,
            @Minute,
            CASE 
                WHEN @Hour >= 6 AND @Hour < 12 THEN 'Morning'
                WHEN @Hour >= 12 AND @Hour < 18 THEN 'Afternoon'
                WHEN @Hour >= 18 AND @Hour < 24 THEN 'Evening'
                ELSE 'Night'
            END,
            -1;

        SET @Minute = @Minute + 1;
    END
    SET @Hour = @Hour + 1;
END
GO
PRINT 'DONE: Dim_Time loaded.';

-- 3. NẠP DỮ LIỆU DIM_AIRPORT (SCD Type 1 - MERGE)
-- ============================================================
PRINT '3. Đang nạp Dim_Airport từ Airline_OLTP...';

MERGE INTO dbo.Dim_Airport AS Target
USING (
    SELECT 
        IATA_Code,
        Airport_Name,
        City,
        State,
        TRY_CAST(Latitude AS DECIMAL(8,4)) AS Latitude,
        TRY_CAST(Longitude AS DECIMAL(9,4)) AS Longitude
    FROM Airline_OLTP.dbo.tb_Airports
) AS Source
ON (Target.BKAirportCode = Source.IATA_Code)
WHEN MATCHED THEN
    UPDATE SET 
        Target.AirportName = Source.Airport_Name,
        Target.City = Source.City,
        Target.State = Source.State,
        Target.Latitude = Source.Latitude,
        Target.Longitude = Source.Longitude,
        Target.UpdateAuditKey = -1
WHEN NOT MATCHED BY TARGET THEN
    INSERT (BKAirportCode, AirportName, City, State, Latitude, Longitude, InsertAuditKey, UpdateAuditKey)
    VALUES (Source.IATA_Code, Source.Airport_Name, Source.City, Source.State, Source.Latitude, Source.Longitude, -1, -1);
GO
PRINT 'DONE: Dim_Airport loaded.';

-- 4. NẠP DỮ LIỆU DIM_AIRLINE (SCD Type 1 - MERGE)
-- ============================================================
PRINT '4. Đang nạp Dim_Airline từ Airline_OLTP...';

MERGE INTO dbo.Dim_Airline AS Target
USING (
    SELECT 
        IATA_Code,
        Airline_Name
    FROM Airline_OLTP.dbo.tb_Airlines
) AS Source
ON (Target.BKAirlineCode = Source.IATA_Code)
WHEN MATCHED THEN
    UPDATE SET 
        Target.AirlineName = Source.Airline_Name,
        Target.UpdateAuditKey = -1
WHEN NOT MATCHED BY TARGET THEN
    INSERT (BKAirlineCode, AirlineName, InsertAuditKey, UpdateAuditKey)
    VALUES (Source.IATA_Code, Source.Airline_Name, -1, -1);
GO
PRINT 'DONE: Dim_Airline loaded.';

PRINT '=======================================================';
PRINT 'HOÀN TẤT: Toàn bộ Dimension đã được nạp thành công.';
PRINT '=======================================================';

-- Kiểm tra kết quả
SELECT 'Dim_Date' AS [Table], COUNT(*) AS [Rows] FROM dbo.Dim_Date
UNION ALL
SELECT 'Dim_Time', COUNT(*) FROM dbo.Dim_Time
UNION ALL
SELECT 'Dim_Airport', COUNT(*) FROM dbo.Dim_Airport
UNION ALL
SELECT 'Dim_Airline', COUNT(*) FROM dbo.Dim_Airline;
GO

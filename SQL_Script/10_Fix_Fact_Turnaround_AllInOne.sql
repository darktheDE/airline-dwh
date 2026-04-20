/*
===================================================================================
  FILE: 10_Fix_Fact_Turnaround_AllInOne.sql
  DESCRIPTION: 
    Script duy nhất để thiết lập và xử lý dữ liệu cho Fact Turnaround.
    1. Tạo bảng staging stg_Turnaround trong Airline_Staging.
    2. Tạo stored procedure usp_ExtractTurnaround trong Airline_Staging.
    3. Cung cấp câu lệnh mẫu để kiểm tra dữ liệu.
===================================================================================
*/

-- --------------------------------------------------------------------------------
-- 1. CHUẨN BỊ TẠI Airline_Staging
-- --------------------------------------------------------------------------------
USE Airline_Staging;
GO

PRINT 'Dang thiet lap bang staging stg_Turnaround...';
IF OBJECT_ID('dbo.stg_Turnaround', 'U') IS NOT NULL 
    DROP TABLE dbo.stg_Turnaround;
GO

CREATE TABLE dbo.stg_Turnaround (
    Tail_Number              NVARCHAR(20) NULL,
    Airline_Code             NVARCHAR(20) NULL,
    Turnaround_Airport       NVARCHAR(20) NULL,
    Inbound_Flight_BK        NVARCHAR(50) NULL,
    Inbound_Arrival_Time     DATETIME     NULL,
    Outbound_Flight_BK       NVARCHAR(50) NULL,
    Outbound_Departure_Time  DATETIME     NULL,
    Staging_Date             DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- --------------------------------------------------------------------------------
-- 2. TẠO STORED PROCEDURE TRÍCH XUẤT (Cho SSIS sử dụng)
-- --------------------------------------------------------------------------------
PRINT 'Dang tao stored procedure dbo.usp_ExtractTurnaround...';
GO

CREATE OR ALTER PROCEDURE dbo.usp_ExtractTurnaround
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Xóa dữ liệu cũ tại Staging trước khi nạp mới
    TRUNCATE TABLE dbo.stg_Turnaround;

    -- Trích xuất cặp chuyến bay (Đến -> Đi) của cùng một máy bay tại cùng một sân bay
    INSERT INTO dbo.stg_Turnaround (
        Tail_Number, Airline_Code, Turnaround_Airport, 
        Inbound_Flight_BK, Inbound_Arrival_Time, 
        Outbound_Flight_BK, Outbound_Departure_Time, 
        Staging_Date
    )
    SELECT 
        f1.Tail_Number, 
        f1.Airline_Code, 
        f1.Destination_Airport,
        -- Tạo Business Key cho Inbound Flight (Khớp với định dạng DWH)
        CONCAT(f1.Airline_Code, '-', f1.Flight_Number, '-', f1.Flight_Year, '-', f1.Flight_Month, '-', f1.Flight_Day) AS Inbound_Flight_BK,
        -- Chuyển đổi Arrival_Time (INT kiểu HHmm) sang DATETIME sử dụng DATEFROMPARTS
        DATEADD(MINUTE, (f1.Arrival_Time % 100), 
            DATEADD(HOUR, (f1.Arrival_Time / 100), 
                DATEFROMPARTS(f1.Flight_Year, f1.Flight_Month, f1.Flight_Day))),
        
        -- Tạo Business Key cho Outbound Flight
        CONCAT(f2.Airline_Code, '-', f2.Flight_Number, '-', f2.Flight_Year, '-', f2.Flight_Month, '-', f2.Flight_Day) AS Outbound_Flight_BK,
        -- Chuyển đổi Departure_Time (INT kiểu HHmm) sang DATETIME
        DATEADD(MINUTE, (f2.Departure_Time % 100), 
            DATEADD(HOUR, (f2.Departure_Time / 100), 
                DATEFROMPARTS(f2.Flight_Year, f2.Flight_Month, f2.Flight_Day))),
        
        GETDATE()
    FROM Airline_OLTP.dbo.tb_Flights f1
    JOIN Airline_OLTP.dbo.tb_Flights f2 ON f1.Tail_Number = f2.Tail_Number 
        AND f1.Destination_Airport = f2.Origin_Airport 
        AND (
            -- Điểm mấu chốt: f1 đến và f2 đi cùng một nơi, f2 phải cất cánh sau khi f1 hạ cánh
            -- Trường hợp cùng ngày
            (f1.Flight_Year = f2.Flight_Year AND f1.Flight_Month = f2.Flight_Month AND f1.Flight_Day = f2.Flight_Day AND f2.Departure_Time > f1.Arrival_Time)
            OR
            -- Trường hợp vắt qua ngày hôm sau (Turnaround qua đêm)
            (DATEADD(DAY, 1, DATEFROMPARTS(f1.Flight_Year, f1.Flight_Month, f1.Flight_Day)) = 
             DATEFROMPARTS(f2.Flight_Year, f2.Flight_Month, f2.Flight_Day))
        )
    WHERE f1.Arrival_Time IS NOT NULL AND f2.Departure_Time IS NOT NULL
      AND f1.Cancelled = 0 AND f2.Cancelled = 0;

    PRINT 'Chay thanh cong: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dong da duoc nap vao Staging.';
END;
GO

-- --------------------------------------------------------------------------------
-- 3. THỰC THI KIỂM TRA
-- --------------------------------------------------------------------------------
PRINT 'Dang chay thu procedure de kiem tra...';
EXEC dbo.usp_ExtractTurnaround;
GO

PRINT 'Kiem tra 10 dong du lieu dau tien trong Staging:';
SELECT TOP 10 * FROM dbo.stg_Turnaround;
GO

PRINT '===================================================================';
PRINT 'SUCCESS: Bay gio ban co the chay lai SSIS Package Load_Fact_Turnaround.dtsx';
PRINT '===================================================================';

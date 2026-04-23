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
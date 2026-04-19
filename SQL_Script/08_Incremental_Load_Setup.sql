/*
===================================================================================
  FILE    : 08_Incremental_Load_Setup.sql
  PROJECT : Airline DWH - Task 8
  DATE    : 2026-04-19
  
  Mục tiêu: Thiết lập cơ chế Watermark cho Incremental Load.
  Dựa trên Task 8: Nhớ lần chạy cuối cùng để SSIS chỉ load data mới.
===================================================================================
*/

USE AirlineDWH;
GO

-- 1. Tạo bảng ETL_Watermark (nếu chưa có hoặc muốn reset theo yêu cầu Task 8)
IF OBJECT_ID('dbo.ETL_Watermark', 'U') IS NOT NULL DROP TABLE dbo.ETL_Watermark;
GO

CREATE TABLE dbo.ETL_Watermark (
    TableName      VARCHAR(100) NOT NULL,
    Last_Load_Date DATETIME     NOT NULL,
    CONSTRAINT PK_ETL_Watermark PRIMARY KEY (TableName)
);
GO

-- 2. Chèn dữ liệu ban đầu (Watermark seeding)
-- Sử dụng mốc 1900-01-01 để lần đầu tiên chạy SSIS sẽ kéo toàn bộ dữ liệu lịch sử.
-- Map tên bảng theo thực tế schema đã tạo trong 02_Create_DWH_Tables.sql

INSERT INTO dbo.ETL_Watermark (TableName, Last_Load_Date)
VALUES 
    ('Fact_Flight_Transaction',      '1900-01-01'),
    ('Fact_Aircraft_Daily_Snapshot', '1900-01-01'),
    ('Fact_Turnaround_Efficiency',   '1900-01-01');
GO

PRINT 'OK: Bảng ETL_Watermark đã được thiết lập với mốc 1900-01-01.';
GO

-- Kiểm tra kết quả
SELECT * FROM dbo.ETL_Watermark;
GO

/*
===================================================================================
  FILE : 07_Verify_Dim_Aircraft.sql
  TASK : Task 7 - SCD Type 2 Verification
  DATE : 2026-04-19

  INSTRUCTIONS:
   1. Chạy phần 1 để xem dữ liệu ban đầu sau khi nạp (Initial Load).
   2. Chạy phần 2 để giả lập thay đổi dữ liệu (Update máy bay N101DA).
   3. Chạy package SSIS Load_Dim_Aircraft.dtsx.
   4. Chạy phần 3 để kiểm tra lịch sử SCD-2.
===================================================================================
*/

-- PHẦN 1: KIỂM TRA SAU LẦN CHẠY ĐẦU TIÊN (INITIAL LOAD)
USE AirlineDWH;
GO

PRINT '--- 1. Kiểm tra dữ liệu nạp lần đầu ---';
SELECT TOP 10 
    AircraftKey, BKTailNumber, Manufacturer, ModelName, EngineType, 
    Valid_From, Valid_To, Is_Active
FROM dbo.Dim_Aircraft
WHERE BKTailNumber <> 'UNKNOWN'
ORDER BY AircraftKey DESC;

-- Kiểm tra xem có dòng nào mang Is_Active = 1 và Valid_To IS NULL không
SELECT COUNT(*) AS [Active Rows With Null ValidTo]
FROM dbo.Dim_Aircraft
WHERE Is_Active = 1 AND Valid_To IS NULL;


-- PHẦN 2: GIẢ LẬP THAY ĐỔI DỮ LIỆU ĐỂ DEMO SCD TYPE 2
-- Ta chọn một máy bay cụ thể, ví dụ: N101DA
USE Airline_OLTP;
GO

PRINT '--- 2. Cập nhật Engine_Type để demo SCD Type 2 ---';
UPDATE dbo.tb_Aircraft_Master
SET Engine_Type = 'Turbo-fan (New)', -- Giả sử đổi từ Turbo-jet sang Turbo-fan
    Updated_Date = GETDATE()
WHERE Tail_Number = 'N101DA';


-- SAU KHI CHẠY SSIS PACKAGE, HÃY CHẠY PHẦN 3
-- PHẦN 3: XÁC MINH LỊCH SỬ SCD TYPE 2 TRONG DWH
USE AirlineDWH;
GO

PRINT '--- 3. Kiểm tra lịch sử máy bay N101DA sau khi chạy SSIS ---';
SELECT 
    AircraftKey, BKTailNumber, Manufacturer, ModelName, EngineType, 
    Valid_From, Valid_To, Is_Active
FROM dbo.Dim_Aircraft
WHERE BKTailNumber = 'N101DA'
ORDER BY Valid_From;
GO

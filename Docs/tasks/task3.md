# Task 3: Viết Script SQL tạo DB Staging và DWH (Star Schema)

* **Mục tiêu:** Thiết kế đích đến (Destination) cho kho dữ liệu theo chuẩn mô hình đa chiều của Ralph Kimball, sẵn sàng cho việc làm ETL ở Cycle 2 & 3.

**Step-by-Step (Các bước thực hiện):**

* **Bước 1 (Tạo Staging DB):** Tạo Database Airline_Staging. Tạo các bảng y hệt OLTP nhưng **kiểu dữ liệu 100% là NVARCHAR/VARCHAR** và **KHÔNG có Khóa chính (PK/FK)**. (Giải thích: Để hứng dữ liệu thô bị lỗi mà không làm sập pipeline SSIS).

* **Bước 2 (Tạo DWH DB):** Tạo Database Airline_DWH.

* **Bước 3 (Thiết kế Dimensions):** Viết script tạo các bảng:

  * Dim_Date (Date_SK INT PK, Full_Date, Year, Quarter, Month, Day, Season...)

  * Dim_Time (Time_SK INT PK, Hour, Minute, Time_Period)

  * Dim_Airline (Airline_SK INT IDENTITY(1,1) PK, IATA_Code, Airline_Name...)

  * Dim_Airport (Airport_SK INT IDENTITY(1,1) PK, IATA_Code, City, State...)

  * Dim_Aircraft (Aircraft_SK INT IDENTITY(1,1) PK, Tail_Number, Manufacturer, Engine_Type...). **BẮT BUỘC THÊM CỘT CHO SCD 2:** Valid_From DATETIME, Valid_To DATETIME, Is_Active BIT.

* **Bước 4 (Thiết kế Facts):** Viết script tạo 3 bảng Fact: Fact_Flight_Transaction, Fact_Aircraft_Daily_Snapshot, Fact_Turnaround_Efficiency. Thiết lập các Khóa ngoại (Foreign Keys) trỏ về các Dim_SK tương ứng. Khai báo các cột Measures (Độ đo) như đã chốt trong Project Overview.

* **Bước 5 (Thiết lập CDC):** Tạo một bảng quản lý thời gian load data.

  * CREATE TABLE ETL_Watermark (TableName VARCHAR(50), Last_Load_Date DATETIME);

  * Insert sẵn các dòng mặc định (Ví dụ: INSERT INTO ETL_Watermark VALUES ('Fact_Flight', '1900-01-01');)

**Tiêu chí nghiệm thu (Definition of Done):**

* File script 02_Create_Staging_and_DWH.sql được push lên Github.

* Dùng SSMS sinh ra Database Diagram (ERD) dạng Star Schema, chụp ảnh lưu lại để bỏ vào Báo cáo Word Chương 2.

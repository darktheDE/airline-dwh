# Task 3: Viết Script SQL tạo DB Staging và DWH (Star Schema)

* **Mục tiêu:** Thiết kế đích đến (Destination) cho kho dữ liệu theo chuẩn mô hình đa chiều của Ralph Kimball, sẵn sàng cho việc làm ETL ở Cycle 2 & 3.

**Step-by-Step (Các bước thực hiện):**

* **Bước 1 (Tạo Staging DB):** Tạo Database `Airline_Staging`. 
    * Thiết kế các bảng: `stg_Airlines`, `stg_Airports`, `stg_Aircraft_Master`, `stg_Flights`.
    * **Đặc tả kỹ thuật:** Toàn bộ kiểu dữ liệu là `NVARCHAR(MAX)` hoặc `NVARCHAR(4000)`, KHÔNG có Khóa chính (PK), Khóa ngoại (FK) hay ràng buộc Check.
    * **Mục tiêu:** Làm vùng đệm (Landing Zone) an toàn cho SSIS, tránh lỗi truncation hoặc lỗi kiểu dữ liệu khi nạp từ OLTP. Đây cũng là nơi tính toán các logic phức tạp (ví dụ: `Turnaround Duration` bằng lệnh `LAG()`) trước khi nạp vào Fact.

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

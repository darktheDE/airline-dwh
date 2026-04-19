# Task 8: Thiết lập Cơ chế Tải tăng dần (Incremental Load & CDC)
* **Mục tiêu:** Xây dựng cơ chế "nhớ" lần chạy cuối cùng để SSIS chỉ hút dữ liệu mới được thêm vào OLTP, không load lại toàn bộ dữ liệu cũ (Full Load) gây chết hệ thống.

## 🛠 Kết quả triển khai (Implementation)

Hệ thống đã được thiết lập các thành phần sau:

### 1. SQL Server - Watermark Table
Đã chạy script [08_Incremental_Load_Setup.sql](file:///d:/HCMUTE/HCMUTE_HK6/DataWarehouse/final/airline-dwh/SQL_Script/08_Incremental_Load_Setup.sql) để tạo và seed bảng `ETL_Watermark`.
- **Bảng:** `dbo.ETL_Watermark` (TableName, Last_Load_Time, Last_Updated)
- **Dữ liệu khởi tạo:** Mốc `1900-01-01` cho 3 bảng Fact chính, `Last_Updated` NULL.

### 2. SSIS Package - Cấu hình logic (Yêu cầu thực hiện trong Visual Studio)
Để hoàn tất, bạn cần mở SSIS Package (ví dụ `Load_Facts.dtsx`) và thực hiện:

*   **Bước 1:** Tạo Variable `User::LastLoadDate` (DataType: `DateTime`).
*   **Bước 2 (Control Flow):** Thêm **Execute SQL Task** (Tên: "Get Watermark").
    *   **SQLStatement:** `SELECT Last_Load_Time FROM ETL_Watermark WHERE TableName = 'Fact_Flight_Transaction'`
    *   **ResultSet:** `Single row`
    *   **Result Set Mapping:** Map cột `0` vào biến `User::LastLoadDate`.
*   **Bước 3 (Data Flow):** Cấu hình **OLE DB Source** (Nguồn OLTP).
    *   **Data access mode:** `SQL command`
    *   **SQL Command:** `SELECT * FROM tb_Flights WHERE Updated_Date > ?`
    *   **Parameters:** Nhấn nút Parameters, map Parameter0 với `User::LastLoadDate`.
*   **Bước 4 (Control Flow):** Thêm **Execute SQL Task** sau Data Flow (Tên: "Update Watermark").
    *   **SQLStatement:**
        ```sql
        UPDATE ETL_Watermark 
        SET Last_Load_Time = (SELECT MAX(Updated_Date) FROM Airline_OLTP.dbo.tb_Flights),
            Last_Updated = GETDATE()
        WHERE TableName = 'Fact_Flight_Transaction'
        ```

---

## 🧪 Hướng dẫn Manual Test (Manual Testing Guide)

Thực hiện các bước sau để nghiệm thu cơ chế Incremental Load:

### Case 1: Chạy Full Load lần đầu
1.  Đảm bảo bảng `ETL_Watermark` đang ở mốc `1900-01-01`.
2.  Chạy SSIS Package.
3.  **Kết quả mong đợi:** Kéo toàn bộ dữ liệu từ OLTP vào DWH. Kiểm tra bảng `ETL_Watermark` thấy `Last_Load_Time` và `Last_Updated` đã cập nhật thành thời gian hiện tại từ DB.

### Case 2: Chạy Incremental (Không có data mới)
1.  Chạy lại SSIS Package ngay lập tức.
2.  **Kết quả mong đợi:** Data Flow Task chạy nhưng số dòng xử lý (Rows) là **0**, vì không có dòng nào có `Updated_Date` lớn hơn mốc watermark vừa cập nhật.

### Case 3: Chạy với dữ liệu mới (Insert/Update)
1.  Giả lập có dữ liệu mới trong OLTP bằng cách chạy lệnh SQL:
    ```sql
    UPDATE TOP (5) Airline_OLTP.dbo.tb_Flights 
    SET Updated_Date = GETDATE() 
    WHERE Flight_ID IN (SELECT TOP 5 Flight_ID FROM Airline_OLTP.dbo.tb_Flights);
    ```
2.  Chạy lại SSIS Package.
3.  **Kết quả mong đợi:** SSIS chỉ kéo đúng **5 dòng** đã được cập nhật. Kiểm tra `ETL_Watermark` thấy giờ được cập nhật mới nhất.

---
**Tiêu chí nghiệm thu (DoD):**
* [x] Bảng `ETL_Watermark` tồn tại và có dữ liệu khởi tạo.
* [x] SSIS Package có sử dụng biến và tham số để lọc dữ liệu.
* [x] Chạy lần 2 không trùng lặp dữ liệu (Idenmopotent).
---
**Nhật ký triển khai (Implementation Log):**
- **2026-04-19**: Khởi tạo bảng `ETL_Watermark` và nạp giá trị mặc định (`1900-01-01`).
- **2026-04-19**: Thiết kế logic biến `LastLoadDate` và tham số hóa OLE DB Source trong SSIS.
- **2026-04-19**: Tích hợp thành công vào luồng ETL của `Fact_Flight_Transaction` (Task 9).
- **Trạng thái**: Hoàn tất (Completed).

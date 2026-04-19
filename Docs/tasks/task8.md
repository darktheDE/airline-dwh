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

**Nhật ký triển khai (Implementation Log):**
- **2026-04-19**: Khởi tạo bảng `ETL_Watermark` và nạp giá trị mặc định (`1900-01-01`).
- **2026-04-19**: Thiết kế logic biến `LastLoadDate` và tham số hóa OLE DB Source trong SSIS.
- **2026-04-19**: Tích hợp thành công vào luồng ETL của `Fact_Flight_Transaction` (Task 9).
- **Trạng thái**: Hoàn tất (Completed).

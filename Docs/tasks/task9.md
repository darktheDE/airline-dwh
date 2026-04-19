# Task 9: Xây dựng luồng ETL cho Fact_Flight_Transaction (Step-by-Step)

Tài liệu này hướng dẫn bạn thực hiện chi tiết từng bước trên **Visual Studio (SSIS)** để tạo và hoàn thiện Package cho bảng Fact chính.

---

## 🚩 Ghi chú quan trọng
Bạn sẽ tạo một Package riêng biệt tên là **`Load_Fact_Flight_Transaction.dtsx`** để đảm bảo tính module hóa của hệ thống.

---

## 1. Tạo Package mới
1.  Trong **Solution Explorer**, chuột phải vào thư mục **SSIS Packages**.
2.  Chọn **New SSIS Package**.
3.  Chuột phải vào package vừa tạo, chọn **Rename** và đặt tên là: `Load_Fact_Flight_Transaction.dtsx`.

---

## 2. Chuẩn bị Biến (Variables)
Trong Visual Studio, mở cửa sổ **Variables** (Menu *SSIS -> Variables*) bên trong package mới này và tạo:
*   **Name**: `LastLoadDate` | **Data Type**: `DateTime` | **Value**: `1900-01-01`
*   (Tùy chọn) **Name**: `RowsInserted` | **Data Type**: `Int32`

---

## 3. Thiết lập Control Flow
Kéo các component sau vào màn hình Control Flow:

### Bước 3.1: Lấy mốc thời gian (Get Watermark)
1.  Kéo **Execute SQL Task**, đổi tên thành `SQL - Get LastLoadDate`.
2.  **Connection**: Chọn Connection đến `AirlineDWH`.
3.  **SQLStatement**: 
    ```sql
    SELECT Last_Load_Time FROM ETL_Watermark WHERE TableName = 'Fact_Flight_Transaction'
    ```
4.  **ResultSet**: Chuyển thành `Single row`.
5.  Tab **Result Set**: Nhấn Add, đặt **Result Name** là `0`, **Variable Name** là `User::LastLoadDate`.

### Bước 3.2: Data Flow Task
1.  Kéo **Data Flow Task**, kết nối mũi tên xanh từ Task trên xuống.
2.  Đổi tên thành `DFT - Load Fact Flight Transaction`.

---

## 4. Thiết lập Data Flow
Click đúp vào `DFT - Load Fact Flight Transaction` để vào màn hình thiết kế luồng dữ liệu.

### Bước 4.1: OLE DB Source (Trích xuất dữ liệu)
1.  Kéo **OLE DB Source**, đổi tên thành `SRC - Flights Incremental`.
2.  **Connection**: Chọn Connection đến `Airline_OLTP`.
3.  **Data access mode**: `SQL command`.
4.  **SQL command text**: Copy đoạn SQL sau:
    ```sql
    SELECT 
        Flight_Year, Flight_Month, Flight_Day, Day_Of_Week,
        Airline_Code, Flight_Number, Tail_Number,
        Origin_Airport, Destination_Airport,
        Scheduled_Departure, Departure_Time, Departure_Delay,
        Taxi_Out, Wheels_Off, Scheduled_Time, Elapsed_Time,
        Air_Time, Distance, Wheels_On, Taxi_In,
        Scheduled_Arrival, Arrival_Time, Arrival_Delay,
        Diverted, Cancelled, Cancellation_Reason,
        Air_System_Delay, Security_Delay, Airline_Delay,
        Late_Aircraft_Delay, Weather_Delay,
        Updated_Date,
        CAST(CAST(Flight_Year AS VARCHAR) + '-' + CAST(Flight_Month AS VARCHAR) + '-' + CAST(Flight_Day AS VARCHAR) AS DATE) AS FL_DATE,
        CAST(CAST(Airline_Code AS VARCHAR) + '-' + CAST(Flight_Number AS VARCHAR) + '-' + CAST(Flight_Year AS VARCHAR) + '-' + CAST(Flight_Month AS VARCHAR) + '-' + CAST(Flight_Day AS VARCHAR) AS NVARCHAR(30)) AS BKFlightID
    FROM tb_Flights 
    WHERE Updated_Date > ?
    ```
5.  Nhấn nút **Parameters...**, chọn **Variable** cho `Parameter0` là `User::LastLoadDate`.

### Bước 4.2: Derived Column - Xử lý giá trị NULL
1.  Kéo **Derived Column**, nối từ Source vào. Đổi tên thành `DC - Replace NULLs`.
2.  Thêm các dòng cấu hình sau (Sử dụng biểu thức `REPLACENULL`):
    *   `Dep_Delay_Mins`: `REPLACENULL(Departure_Delay, 0)`
    *   `Arr_Delay_Mins`: `REPLACENULL(Arrival_Delay, 0)`
    *   `Weather_Delay_Mins`: `REPLACENULL(Weather_Delay, 0)`
    *   `Carrier_Delay_Mins`: `REPLACENULL(Airline_Delay, 0)`
    *   `NAS_Delay_Mins`: `REPLACENULL(Air_System_Delay, 0)`
    *   `Security_Delay_Mins`: `REPLACENULL(Security_Delay, 0)`
    *   `LateAircraft_Delay_Mins`: `REPLACENULL(Late_Aircraft_Delay, 0)`
    *   `Air_Time_Mins`: `REPLACENULL(Air_Time, 0)`

### Bước 4.3: Derived Column - Business Logic
1.  Kéo thêm một **Derived Column**, nối từ cái trước vào. Đổi tên thành `DC - Metrics`.
2.  Thêm các cột mới:
    *   **Is_Delayed**: `REPLACENULL(Arrival_Delay, 0) >= 15 ? (DT_BOOL)1 : (DT_BOOL)0`
    *   **Estimated_Financial_Loss_USD**: `(DT_DECIMAL, 2)((REPLACENULL(Arrival_Delay, 0) * 75.0) + ((Cancelled ? 1 : 0) * 5000.0))`
    *   **DateKey**: `(Flight_Year * 10000) + (Flight_Month * 100) + Flight_Day`
    *   **DepTimeKey**: `(DT_I2)REPLACENULL(Scheduled_Departure, -1)`
    *   **ArrTimeKey**: `(DT_I2)REPLACENULL(Scheduled_Arrival, -1)`

### Bước 4.4: Tra tra cứu Dimension (Lookups)
Thực hiện lần lượt các Lookup sau (Nhớ chọn **Redirect rows to no error output** nếu cần):
1.  **LKP - Origin Airport**: Map `Origin_Airport` -> `BKAirportCode`. Lấy `AirportKey` đổi tên thành `OriginAirportKey`.
2.  **LKP - Destination Airport**: Map `Destination_Airport` -> `BKAirportCode`. Lấy `AirportKey` đổi tên thành `DestAirportKey`.
3.  **LKP - Airline**: Map `Airline_Code` -> `BKAirlineCode`. Lấy `AirlineKey`.
4.  **LKP - Aircraft (SCD Type 2)**:
    *   Tích chọn kết nối tới bảng `Dim_Aircraft`.
    *   Tại mục **Connection**, tick vào ô *Write a query to specify the data...* và sử dụng truy vấn đơn giản sau để chỉ lấy các máy bay đang hoạt động:
        ```sql
        SELECT AircraftKey, BKTailNumber FROM Dim_Aircraft WHERE Is_Active = 1
        ```
    *   Sang tab **Columns**, nối `Tail_Number` (Source) với `BKTailNumber` (Lookup). 
    *   Tích chọn lấy cột `AircraftKey`. (Lưu ý: Cách này bỏ qua tính lịch sử của SCD Type 2 để giúp thiết lập ETL rảnh tay và ít tốn tài nguyên nhất).

### Bước 4.5: Ghi dữ liệu (Destination)
1.  Kéo **OLE DB Destination**, nối từ Lookup cuối cùng vào.
2.  **Table**: `[dbo].[Fact_Flight_Transaction]`.
3.  **Mappings**: Kiểm tra kỹ các cột Source và Destination.

---

## 5. Cập nhật Watermark (Control Flow)
Quay lại màn hình **Control Flow**, kéo thêm 1 **Execute SQL Task** đặt sau Data Flow:
*   **Name**: `SQL - Update Watermark`.
*   **SQLStatement**:
    ```sql
    UPDATE ETL_Watermark 
    SET Last_Load_Time = (SELECT MAX(Updated_Date) FROM Airline_OLTP.dbo.tb_Flights),
        Last_Updated = GETDATE()
    WHERE TableName = 'Fact_Flight_Transaction'
    ```

---

## 6. Kiểm tra (Testing)
1.  Nhấn F5 để chạy thử package này.
2.  Kiểm tra số lượng dòng trong DWH:
    ```sql
    SELECT COUNT(*) FROM Fact_Flight_Transaction
    ```

---

## 7. Nghiệm thu & Chạy thử
Vui lòng làm theo hướng dẫn tại file `Docs/guild_task_8_9.md` (Runbook) để thực thi pipeline và kiểm tra lỗi.




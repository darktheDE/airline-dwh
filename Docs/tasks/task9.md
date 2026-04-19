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
        CAST(CAST(Flight_Year AS VARCHAR) + '-' + CAST(Flight_Month AS VARCHAR) + '-' + CAST(Flight_Day AS VARCHAR) AS DATE) AS FL_DATE
    FROM tb_Flights 
    WHERE Updated_Date > ?
    ```
5.  Nhấn nút **Parameters...**, chọn **Variable** cho `Parameter0` là `User::LastLoadDate`.

### Bước 4.2: Derived Column - Xử lý giá trị NULL
1.  Kéo **Derived Column**, nối từ Source vào. Đổi tên thành `DC - Replace NULLs`.
2.  Thêm các dòng cấu hình sau (Sử dụng biểu thức `REPLACENULL`):
    *   `Weather_Delay_Mins`: `REPLACENULL(Weather_Delay, 0)`
    *   `Carrier_Delay_Mins`: `REPLACENULL(Airline_Delay, 0)`
    *   `NAS_Delay_Mins`: `REPLACENULL(Air_System_Delay, 0)`
    *   `Security_Delay_Mins`: `REPLACENULL(Security_Delay, 0)`
    *   `LateAircraft_Delay_Mins`: `REPLACENULL(Late_Aircraft_Delay, 0)`
    *   `Air_Time_Mins`: `REPLACENULL(Air_Time, 0)`

### Bước 4.3: Derived Column - Business Logic
1.  Kéo thêm một **Derived Column**, nối từ cái trước vào. Đổi tên thành `DC - Metrics`.
2.  Thêm các cột mới:
    *   **Is_Delayed**: `(Arrival_Delay >= 15) ? (DT_BOOL)1 : (DT_BOOL)0`
    *   **Estimated_Financial_Loss_USD**: `(DT_DECIMAL, 2)((Arrival_Delay * 75.0) + (Cancelled * 5000.0))`
    *   **DateKey**: `(Flight_Year * 10000) + (Flight_Month * 100) + Flight_Day`

### Bước 4.4: Tra tra cứu Dimension (Lookups)
Thực hiện lần lượt các Lookup sau (Nhớ chọn **Redirect rows to no error output** nếu cần):
1.  **LKP - Origin Airport**: Map `Origin_Airport` -> `BKAirportCode`. Lấy `AirportKey` đổi tên thành `OriginAirportKey`.
2.  **LKP - Destination Airport**: Map `Destination_Airport` -> `BKAirportCode`. Lấy `AirportKey` đổi tên thành `DestAirportKey`.
3.  **LKP - Airline**: Map `Airline_Code` -> `BKAirlineCode`. Lấy `AirlineKey`.
4.  **LKP - Aircraft (SCD Type 2)**:
    *   Nối `Tail_Number` (Source) với `BKTailNumber` (Lookup). 
    *   Để đơn giản nhất, lấy `AircraftKey` từ dòng có `Is_Active = 1`.

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

## 7. Troubleshooting (Nhật ký xử lý lỗi thực thi)

Trong quá trình thực thi Package `Load_Fact_Flight_Transaction.dtsx`, có thể gặp phải một số lỗi phổ biến dựa trên thực tế dữ liệu. Dưới đây là phân tích và cách khắc phục:

### Lỗi 1: Vi phạm ràng buộc NOT NULL (Integrity Constraints)
*   **Hiện tượng / Log báo lỗi**: 
    `The value violated the integrity constraints for the column.` trên các cột delay, hệ thống báo `not subsequently used` ở Derived Column.
*   **Nguyên nhân**: 
    Trong **OLE DB Destination**, các cột gốc từ source (`Departure_Delay`, `Arrival_Delay` - có thể chứa gía trị `NULL`) đang được map trực tiếp vào các cột `NOT NULL` của bảng Fact thay vì sử dụng các cột đã được thay thế `NULL` bằng `0` (như `Dep_Delay_Mins`) từ component **DC - Replace NULLs**.
*   **Cách khắc phục**:
    Mở component **OLE DB Destination**, vào phần **Mappings**. Break kết nối của các cột gốc có khả năng chứa NULL và map lại bằng những cột sinh ra từ Data Flow `DC - Replace NULLs` (Map đúng tên `_Mins`).

### Lỗi 2: Vi phạm khóa ngoại (Foreign Key Constraint) với Dim_Time
*   **Hiện tượng / Log báo lỗi**:
    Lỗi Insert: `conflicted with the FOREIGN KEY constraint "FK_FFT_ArrTime" ... table "dbo.Dim_Time", column 'TimeKey'.`
*   **Nguyên nhân**:
    Tiến trình ETL load thành công phần lớn data nhưng sẽ báo lỗi fail do trong raw dataset (từ Kaggle), một số chuyến bay cất/hạ cánh lúc nửa đêm mang giá trị giờ là `2400`. Trong khi đó, bảng thời gian `Dim_Time` chỉ được giới hạn từ `0` (00:00) đến `2359` (23:59). Khi SSIS map giá trị key `2400`, nó không tìm thấy trong dimension nên gây ra lỗi Foreign Key.
*   **Cách khắc phục**:
    Gắn thêm giá trị đại diện cho nửa đêm (`2400`) vào bảng `Dim_Time` trong SQL Server bằng script sau để không cần sửa code bên trong SSIS:
    ```sql
    USE AirlineDWH;
    GO
    IF NOT EXISTS (SELECT 1 FROM dbo.Dim_Time WHERE TimeKey = 2400)
    BEGIN
        INSERT INTO dbo.Dim_Time (TimeKey, TimeValue, HourNumber, MinuteNumber, TimePeriod, InsertAuditKey)
        VALUES (2400, '24:00', 0, 0, 'Midnight', -1);
    END
    GO
    ```

### Lỗi 3: Chạy SSIS báo thành công (tích xanh) nhưng OLE DB Destination ghi 0 dòng
*   **Hiện tượng / Log báo lỗi**: 
    Data Flow chạy thành công, không báo lỗi, nhưng log hiển thị: `"OLE DB Destination" wrote 0 rows`. Trong SSMS, bảng Fact vẫn rỗng (`Fact_Count = 0`).
*   **Nguyên nhân**: 
    Do cơ chế Incremental Load đang lưu mốc thời gian (Watermark) sai lệch. Trong quá trình Debug, bạn có thể đã `TRUNCATE` bảng Fact nhưng lại quên reset mốc thời gian trong bảng `ETL_Watermark`. Kết quả là câu lệnh SQL ở Source (`WHERE Updated_Date > ?`) bị khớp với ngày hiện tại (hoặc ngày quét cuối cùng), dẫn đến truy xuất ra 0 dòng dữ liệu mới.
*   **Cách khắc phục**:
    Chạy đoạn SQL sau để reset Watermark:
    ```sql
    UPDATE dbo.ETL_Watermark 
    SET Last_Load_Time = '1900-01-01' 
    WHERE TableName = 'Fact_Flight_Transaction';
    ```

### Lỗi 4: SSIS báo lỗi "Attempt to find the input column named... failed" trong Derived Column
*   **Hiện tượng / Log báo lỗi**:
    `Attempt to find the input column named "Air_Time" failed with error code 0xC0010009`.
*   **Nguyên nhân**:
    Hàm `REPLACENULL(Air_Time, 0)` tìm kiếm đến cột `Air_Time`, nhưng cột này lại chưa được tích chọn ở component lấy dữ liệu (OLE DB Source). Do đó luồng Pipeline không hề có chứa cột nào mang tên này.
*   **Cách khắc phục**:
    1. Mở lại khối **OLE DB Source** (`SRC - Flights Incremental`).
    2. Chuyển sang thẻ **Columns** ở bên trái.
    3. Tìm và đánh dấu tick `[v]` vào những cột đang bị thiếu (VD: tick vào `Air_Time`).
    4. Quay lại mở hộp thoại Derived Column, bung thư mục **Columns** (góc trên bên trái) để xem danh sách. Nếu cột đã hiện, hãy kéo/thả thủ công vào biểu thức để phòng lỗi gõ sai chính tả.

### Lỗi 5: Cảnh báo lệch kiểu Data Type (double-precision float vs smallint) và trùng tên cột
*   **Hiện tượng / Log báo lỗi**: 
    SSIS hiện thông báo nền vàng: `Multiple derived columns are found with the same name: 'NAS_Delay_Mins'`. Hoặc các Data Type sinh ra bị gắn mác `double-precision float [DT_R8]` mặc dù database đang chờ nhận kiểu số nguyên `smallint`. Bản thân logic rẽ nhánh gán trị biểu thức `Air_Time_Mins = REPLACENULL(NAS_Delay_Mins, 0)` bị sai logic nghiệp vụ.
*   **Nguyên nhân**:
    - Nhấn chọn <add as new column> hai lần với chung một tên đích (`NAS_Delay_Mins`).
    - Viết nhầm mã logic của một column này sử dụng thông số ngắt của column kia (nhầm Delay cho Time).
    - Lấy cấu trúc hàm `REPLACENULL(Col, 0)`, SSIS tự hiểu ngầm là `float/double`.
*   **Cách khắc phục**:
    - Click phải chuột ở giao diện của dòng trùng, chọn **Delete Row**.
    - Sửa lại nguồn đúng biểu thức (VD: Sửa tên nguồn cho Air Time thành `REPLACENULL(Air_Time, 0)`).
    - Cực kỳ khuyến nghị: Chủ động ép kiểu dữ liệu ngay tại đây (Cast). Gắn kèm `(DT_I2)` vào trước để đồng nhất với `smallint` ở SQL Server.
      Cú pháp chuẩn: `(DT_I2)REPLACENULL(Air_Time, 0)` hoặc `(DT_I2)REPLACENULL(Arrival_Delay, 0)`.
    - Riêng với Derived `Is_Delayed` (boolean), phải bọc chặt `NULL` trước khi so sánh: 
      `REPLACENULL(Arrival_Delay, 0) >= 15 ? (DT_BOOL)1 : (DT_BOOL)0`.

### Lỗi 6: Vi phạm ràng buộc khóa ngoại (Foreign Key) với Dim_Audit
*   **Hiện tượng / Log báo lỗi**:
    `The MERGE statement conflicted with the FOREIGN KEY constraint "FK_Dim_Airport_InsAudit". The conflict occurred in database "AirlineDWH", table "dbo.Dim_Audit", column 'AuditKey'.`
*   **Nguyên nhân**:
    Trong các script `MERGE` (như ở `Dim_Airport`, `Dim_Airline`), chúng ta đang gán cứng giá trị `InsertAuditKey = -2` hoặc `UpdateAuditKey = -2` để đánh dấu các dòng được xử lý bởi logic Task 6. Tuy nhiên, bảng `Dim_Audit` mặc định chỉ được khởi tạo với khóa `-1` (Unknown), dẫn đến việc SQL Server từ chối ghi dữ liệu vì không tìm thấy khóa `-2`.
*   **Cách khắc phục**:
    Thêm bản ghi Audit gán cho khóa `-2` vào bảng `Dim_Audit` để thỏa mãn ràng buộc khóa ngoại:
    ```sql
    USE AirlineDWH;
    GO
    SET IDENTITY_INSERT dbo.Dim_Audit ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Dim_Audit WHERE AuditKey = -2)
    BEGIN
        INSERT INTO dbo.Dim_Audit (AuditKey, ETL_Package, ETL_RunDate, ETL_RowsInserted, ETL_RowsUpdated)
        VALUES (-2, 'Manual/Task6_SCD1', GETDATE(), 0, 0);
    END
    SET IDENTITY_INSERT dbo.Dim_Audit OFF;
    GO
    ```
    Đồng thời, cập nhật lại script `02_Create_DWH_Tables.sql` để đảm bảo khi khởi tạo lại DWH, hệ thống sẽ tự động có sẵn khóa này.

---

## 8. Nhật ký triển khai và Sửa lỗi hệ thống (Vận hành)

Dưới đây là ghi chép các lỗi phát sinh trong quá trình triển khai thực tế trên môi trường Lab và cách đã xử lý để đảm bảo luồng dữ liệu thông suốt:

| Ngày | Vấn đề phát sinh | Nguyên nhân | Giải pháp xử lý |
| :--- | :--- | :--- | :--- |
| 19/04 | Lỗi "Invalid column name 'Last_Load_Time'" | Database dùng tên `Last_Load_Date` nhưng SSIS Package gọi `Last_Load_Time`. | Đã chạy lại Script SQL để tái cấu trúc bảng `ETL_Watermark` khớp với SSIS. |
| 19/04 | Lỗi "read-only column" tại Destination | Chọn nhầm Destination trỏ ngược lại database `OLTP` (có cột Identity) thay vì trỏ tới `Staging`. | Chỉnh lại Connection Manager của OLE DB Destination về đúng database `Airline_Staging`. |
| 19/04 | Lỗi Unicode conversion (IATA_Code) | Source là `Varchar` nhưng Staging là `NVarchar`. | Sử dụng `CAST(column AS NVARCHAR)` ngay tại câu lệnh SQL ở Source để không cần dùng component Data Conversion. |
| 19/04 | Staging trống dữ liệu (0 rows) | Task Extract bị lỗi/trống làm luồng nạp DWH không có đầu vào. | Đã nạp "mồi" dữ liệu bằng SQL script để thông luồng nạp DWH và sửa lại các task Extract bị hỏng. |
| 19/04 | Thiếu luồng nạp cho Dim_Airline | Package `Load_Dim_Airport_Airline` chỉ mới có logic nạp cho Airport. | Cần bổ sung thêm 1 Data Flow Task riêng hoặc tích hợp cùng SCD cho bảng Airline. |

### 💡 Bài học kinh nghiệm:
1.  **Kiểm tra Connection Manager:** Luôn đảm bảo OLE DB Source trỏ về `OLTP` và OLE DB Destination trỏ về `Staging`/`DWH`.
2.  **Đồng bộ Metadata:** Nếu đổi Schema ở SQL Server, phải vào lại SSIS nhấn **Refresh** hoặc mở lại Mapping để package nhận diện lại cột.
3.  **Thứ tự thực hiện:** Chạy thử từng bước (Extract -> Staging, rồi mới Staging -> DWH) để dễ dàng cô lập lỗi.




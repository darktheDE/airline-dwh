# Hướng dẫn Runbook (Tutorial) - Chạy Task 8 & 9 trên môi trường mới

Tài liệu này là cẩm nang hướng dẫn bạn từ lúc chưa có gì cho đến khi thiết lập thành công và chạy thử nghiệm (test) hoàn chỉnh luồng ETL Incremental Load cho bảng `Fact_Flight_Transaction` (Task 8 & 9) trên một máy tính / môi trường SQL Server mới.

---

## 1. Khởi tạo môi trường (Pre-requisites)

Trước khi chạy SSIS Package `Load_Fact_Flight_Transaction.dtsx`, bạn cần đảm bảo Database đã được chuẩn bị đầy đủ metadata và dummy data để tránh vi phạm các ràng buộc (Constraints) hay khoá ngoại (Foreign Keys).

Hãy mở SQL Server Management Studio (SSMS) và chạy lần lượt các script sau.

### 1.1 Khởi tạo bảng Watermark (Task 8)

Bảng Watermark dùng để lưu lại thời điểm đồng bộ luồng ETL cuối cùng. Mở connection đến `Airline_OLTP` (hoặc `AirlineDWH` tuỳ thiết kế) và chạy script:

```sql
USE AirlineDWH; -- Hoặc Database chứa metadata ETL của bạn
GO

-- 1. Tạo bảng Watermark nếu chưa có
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ETL_Watermark')
BEGIN
    CREATE TABLE ETL_Watermark (
        TableName VARCHAR(100) PRIMARY KEY,
        Last_Load_Time DATETIME NOT NULL,
        Last_Updated DATETIME NULL
    );
END
GO

-- 2. Seed dữ liệu mặc định (Quét từ đầu)
IF NOT EXISTS (SELECT 1 FROM ETL_Watermark WHERE TableName = 'Fact_Flight_Transaction')
BEGIN
    INSERT INTO ETL_Watermark (TableName, Last_Load_Time)
    VALUES ('Fact_Flight_Transaction', '1900-01-01');
END
ELSE
BEGIN
    -- Reset lại mốc nếu đã tồn tại để bắt đầu test lại từ đầu
    UPDATE ETL_Watermark 
    SET Last_Load_Time = '1900-01-01', Last_Updated = NULL 
    WHERE TableName = 'Fact_Flight_Transaction';
END
GO
```

### 1.2 Cập nhật Metadata cho DWH (Fix lỗi Foreign Keys)

Trong bộ dữ liệu đặc thù, có những thời điểm hạ cánh lúc nửa đêm (24:00). Ngoài ra, cơ chế Merge của dimension có sử dụng một khóa kiểm toán (AuditKey) âm (`-2`) mà mặc định khi khởi tạo DWH chưa có.
Hãy chạy script sau trên `AirlineDWH` để vá:

```sql
USE AirlineDWH;
GO

-- Fix 1: Thêm mốc thời gian 24:00 vào bảng Dim_Time để không lỗi FK_ArrTime / FK_DepTime
IF NOT EXISTS (SELECT 1 FROM dbo.Dim_Time WHERE TimeKey = 2400)
BEGIN
    INSERT INTO dbo.Dim_Time (TimeKey, TimeValue, HourNumber, MinuteNumber, TimePeriod, InsertAuditKey)
    VALUES (2400, '24:00', 0, 0, 'Midnight', -1);
END
GO

-- Fix 2: Thêm AuditKey = -2 cho các thao tác SCD thủ công
SET IDENTITY_INSERT dbo.Dim_Audit ON;
IF NOT EXISTS (SELECT 1 FROM dbo.Dim_Audit WHERE AuditKey = -2)
BEGIN
    INSERT INTO dbo.Dim_Audit (AuditKey, ETL_Package, ETL_RunDate, ETL_RowsInserted, ETL_RowsUpdated)
    VALUES (-2, 'Manual/Task6_SCD1', GETDATE(), 0, 0);
END
SET IDENTITY_INSERT dbo.Dim_Audit OFF;
GO
```

---

## 2. Hướng dẫn Test luồng ETL (Manual Test)

Mở Visual Studio, mở solution chứa Package `Load_Fact_Flight_Transaction.dtsx` và thực hiện kịch bản test sau.

### Case 1: Chạy Full Load lần đầu tiên
1. Ở Bước 1, ta đã đảm bảo `ETL_Watermark` ở mốc `1900-01-01`.
2. Bấm `Start` (F5) để chạy package `Load_Fact_Flight_Transaction.dtsx`.
3. **Kỳ vọng**: 
    - Luồng Data Flow sẽ quét qua toàn bộ dữ liệu hiện có trong bảng `tb_Flights` (OLTP) và đổ toàn bộ vào `Fact_Flight_Transaction`.
    - Ở SQL, chạy `SELECT * FROM ETL_Watermark` sẽ thấy cột `Last_Load_Time` cập nhật bằng thời gian dữ liệu mới nhất (Ví dụ 2015).

### Case 2: Chạy Incremental - Không có data mới
1. Không tác động gì đến database. Vẫn ở Visual Studio, bấm `Start` (F5) chạy lại Package lần thứ hai.
2. **Kỳ vọng**:
    - Package chạy rất nhanh và kết thúc (Tích xanh).
    - Ở tab *Data Flow*, dòng dữ liệu chuyển từ Source sang Destination sẽ ghi **0 rows**. (Vì hệ thống biết rằng không có dữ liệu nào có `Updated_Date` lớn hơn mốc watermark hiện tại).

### Case 3: Chạy Incremental - Có update data từ OLTP
Để giả lập việc hệ thống thực có chuyến bay mới, chúng ta sẽ "Update" một vài record ở bảng gốc `tb_Flights` cho thời gian `Updated_Date` vọt lên hiện tại.
1. Chạy Script giả lập tại SQL Server:
    ```sql
    USE Airline_OLTP;
    GO
    UPDATE TOP (5) dbo.tb_Flights 
    SET Updated_Date = GETDATE() 
    WHERE Flight_ID IN (SELECT TOP 5 Flight_ID FROM dbo.tb_Flights);
    ```
2. Mở Visual Studio và chạy lại Package.
3. **Kỳ vọng**:
    - Data Flow sẽ chỉ báo hút và ghi đúng **5 rows**.
    - Bảng `ETL_Watermark` được cập nhật lại giờ phút giây chạy mới nhất (hiện tại).

---

## 3. Nhật ký gỡ lỗi (Troubleshooting Guide)

Trong quá trình xây dựng và chạy thử, nếu bạn gặp sự cố, dưới đây là tổng hợp kinh nghiệm và cách xử lý nhanh trên SSIS:

### 3.1 Lỗi "The value violated the integrity constraints... NOT NULL"
- **Nguyên nhân**: Bảng Fact cấm gán NULL cho các trường Delay, nhưng bạn lại map trực tiếp từ OLE DB Source vào Destination.
- **Giải pháp**: Xóa map các trường gốc chứa NULL, và map lại cho Destination bằng các trường sinh ra từ khối Derived Column đã dùng hàm `REPLACENULL(..., 0)` (VD: Map vào `Dep_Delay_Mins`).

### 3.2 Lỗi "Attempt to find the input column named "Air_Time"... failed"
- **Nguyên nhân**: Hàm thay thế NULL đang trỏ tới một cột mà trong khối *OLE DB Source* bạn chưa check (chọn) lấy ra.
- **Giải pháp**: Mở lại OLE DB Source (`SRC - Flights Incremental`), sang tab Columns và tích chọn những cột bị báo thiếu này.

### 3.3 Chạy SSIS cấu hình sai Watermark khiến hút 0 row không rõ lý do
- **Hiện tượng**: Bảng Fact rỗng, SSIS báo chạy thành công, hút 0 row dù ở OLTP đang có đầy dữ liệu.
- **Nguyên nhân**: Biến watermark `LastLoadDate` (lấy từ SQL Task) đang chứa một ngày tháng gần đây thay vì `1900-01-01`. Thường xảy ra sau chu kỳ Debug bạn Truncate Fact nhưng quên Truncate/Reset Watermark.
- **Giải pháp**: Chạy lại query ở phần "1.1 Khởi tạo bảng Watermark" để `UPDATE ETL_Watermark SET Last_Load_Time = '1900-01-01'`. Mở Data Flow để chạy lại.

### 3.4 Cảnh báo nền vàng "double-precision float [DT_R8]" lệch Type với SQL Server
- **Nguyên nhân**: SSIS ngầm định hàm `REPLACENULL(Col, 0)` sẽ sinh ra số thập phân. Khi nạp vào bảng Fact có định dạng `smallint` (nguyên nhỏ), hệ thống sẽ cảnh báo mất mát dữ liệu (Data truncation / mismatch).
- **Giải pháp**: Sử dụng Explicit Cast trực tiếp trong Derived Column. 
    - Ví dụ thay vì ghi: `REPLACENULL(Air_Time, 0)`
    - Hãy ghi thành: `(DT_I2)REPLACENULL(Air_Time, 0)` để ép chặt về số nguyên (smallint).

### 3.5 Báo lỗi Connection Manager "Read-only Column"
- **Nguyên nhân**: Chọn nhầm OLE DB Destination trỏ vào bảng OLTP gốc (bảng gốc có khóa tự động sinh Identity column không cho Insert).
- **Giải pháp**: Nhớ mở Destination và sửa connection trỏ sang database `Airline_Staging` hoặc `AirlineDWH` nhé.

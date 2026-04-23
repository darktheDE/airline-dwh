# Hướng Dẫn Chi Tiết: Chạy Toàn Bộ Pipeline Dự Án Airline Data Warehouse

Tài liệu này hướng dẫn bạn cách khởi chạy dự án từ con số 0, dành cho người mới bắt đầu. Quy trình bao gồm việc tạo cơ sở dữ liệu (Database), nạp dữ liệu nguồn (OLTP), chạy tiến trình ETL (SSIS) và xử lý khối lập phương phân tích (SSAS).

---

## 📋 Yêu Cầu Hệ Thống

Trước khi bắt đầu, hãy đảm bảo máy tính của bạn đã cài đặt:
1. **SQL Server** (Phiên bản 2019 trở lên, khuyên dùng 2022).
2. **Visual Studio** (2019 hoặc 2022) kèm theo gói cài đặt **SQL Server Data Tools (SSDT)**.
3. Các Extensions trong Visual Studio:
   *   **SQL Server Integration Services (SSIS)** Projects.
   *   **SQL Server Analysis Services (SSAS)** Projects.

---

## 📂 Giai Đoạn 1: Chuẩn Bị Dữ Liệu & Khởi Tạo Database

### Bước 1.1: Tạo 3 Cơ sở dữ liệu trống
Mở **SQL Server Management Studio (SSMS)** và tạo 3 database với tên chính xác như sau:
*   `Airline_OLTP` (Dữ liệu nguồn)
*   `Airline_Staging` (Vùng đệm)
*   `AirlineDWH` (Kho dữ liệu)

### Bước 1.2: Chuẩn bị file dữ liệu CSV
Đảm bảo bạn có các file sau trong thư mục `Data\` của dự án:
*   `airlines.csv`, `airports.csv`, `flights.csv` (trong thư mục `2015-flight-delays-and-cancellations`)
*   `MASTER.txt`, `ACFTREF.txt` (trong thư mục `faa-aircraft-registry`)

### Bước 1.3: Nạp dữ liệu vào OLTP
1.  Mở file script `SQL_Script\01_Create_OLTP.sql` trong SSMS.
2.  **QUAN TRỌNG**: Tìm các dòng có ghi chú `-- TODO: UPDATE PATH` và sửa đường dẫn tới các file CSV/TXT trên máy của bạn.
3.  Nhấn **Execute** (F5) để chạy. Script này sẽ tạo bảng và nạp hàng triệu dòng dữ liệu vào `Airline_OLTP`.

### Bước 1.4: Tạo cấu trúc Staging và DWH
Lần lượt mở và chạy (Execute) các file script sau:
1.  `SQL_Script\01.5_Create_Staging.sql` (Tạo bảng vùng đệm).
2.  `SQL_Script\02_Create_DWH_Tables.sql` (Tạo cấu trúc Fact/Dim cho kho dữ liệu).

---

## 🔄 Giai Đoạn 2: Chạy Tiến Trình ETL (SSIS)

### Bước 2.1: Mở dự án SSIS
Mở file `SSIS_Package\Airline_DWH_ETL\Airline_DWH_ETL.sln` bằng Visual Studio.

### Bước 2.2: Cấu hình Connection Managers
Ở cửa sổ **Solution Explorer**, quan sát mục **Connection Managers**. Đảm bảo 3 kết nối sau trỏ đúng về SQL Server của bạn (Local):
*   `__SQLDEV.Airline_OLTP.conmgr`
*   `__SQLDEV.Airline_Staging.conmgr`
*   `__SQLDEV.AirlineDWH.conmgr`
*(Chuột phải vào từng cái -> Edit -> Kiểm tra Server Name là `.` hoặc tên máy của bạn).*

### Bước 2.3: Thực hiện chạy toàn bộ Pipeline
1.  Tìm và mở file `Master_Package.dtsx`.
2.  Nhấn nút **Start** (Mũi tên xanh) trên thanh công cụ để chạy.
3.  Package này sẽ tự động gọi các package con để nạp dữ liệu theo thứ tự: **Dimensions** (Kích thước) -> **Facts** (Sự kiện).

---

## 🧊 Giai Đoạn 3: Triển Khai Khối Phân Tích (SSAS)

### Bước 3.1: Mở dự án SSAS
Mở file `SSAS_Cube\Airline_Cube_Project\Airline_Cube_Project.sln` bằng Visual Studio.

### Bước 3.2: Cập nhật Data Source
1.  Trong **Solution Explorer**, mở mục **Data Sources**.
2.  Chuột phải vào `Airline DWH.ds` -> **Edit**.
3.  Nhấn **Edit...** ở mục Connection String, đảm bảo nó trỏ về Database `AirlineDWH` bạn vừa nạp dữ liệu xong.

### Bước 3.3: Deploy và Process Cube
1.  Chuột phải vào dự án `Airline_Cube_Project` trong Solution Explorer -> Chọn **Deploy**.
2.  Sau khi Deploy thành công, nếu cần, chuột phải tiếp vào dự án -> Chọn **Process** -> Nhấn **Run** để tính toán dữ liệu cho Cube.

---

## 📊 Giai Đoạn 4: Kiểm Tra Kết Quả

1.  **Kiểm tra bằng SQL**: Chạy script `SQL_Script\07_Verify_Dim_Aircraft.sql` hoặc query `SELECT COUNT(*) FROM Dim_Flight_Transaction` để xem dữ liệu đã vào kho chưa.
2.  **Xem báo cáo**: Mở file Dashboard (nếu có) trong thư mục `Dashboard\` hoặc dùng Excel kết nối vào SSAS Cube để xem các biểu đồ trực quan.

---
> [!TIP]
> Nếu gặp lỗi "Truncation Error" trong SSIS, hãy kiểm tra lại kiểu dữ liệu của cột đó trong SQL Server (có thể cần tăng kích thước cột).

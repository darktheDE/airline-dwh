# Hướng dẫn Chạy Script SQL (SQL Scripts Guide)

Thư mục này chứa các script SQL khởi tạo hệ thống Airline OLTP và DWH. Để chạy thành công, vui lòng thực hiện theo các bước dưới đây.

## 1. Chuẩn bị (Prerequisites)

Trước khi chạy bất kỳ script nào, bạn **BẮT BUỘC** phải:
1.  **Tạo Database**: Khởi tạo 3 database rỗng trên SQL Server:
    *   `Airline_OLTP`
    *   `Airline_Staging`
    *   `AirlineDWH`
2.  **Dữ liệu thô**: Đảm bảo các file CSV/TXT đã được giải nén và đặt đúng cấu trúc thư mục trong folder `Data/`.

## 2. Cấu hình Đường dẫn (Configuration)

Mặc định, các script đang sử dụng đường dẫn tuyệt đối của máy hiện tại:
`D:\HCMUTE\HCMUTE_HK6\DataWarehouse\final\airline-dwh\Data\...`

> [!IMPORTANT]  
> Nếu bạn di chuyển thư mục project sang vị trí khác hoặc sử dụng máy tính khác, bạn cần mở file `01_Create_OLTP.sql` và sử dụng tính năng **Find & Replace (Ctrl+H)** để cập nhật lại đường dẫn cho tất cả các lệnh `BULK INSERT`.

## 3. Thứ tự thực thi (Execution Order)

Vui lòng thực hiện theo đúng thứ tự sau để đảm bảo ràng buộc dữ liệu:

### Bước 1: Khởi tạo OLTP & Nạp dữ liệu nguồn
*   **File**: `01_Create_OLTP.sql`
*   **Mục tiêu**: Tạo bảng, nạp dữ liệu từ CSV (Airlines, Airports, Flights) và TXT (FAA Registry), sau đó giả lập dữ liệu bẩn.

### Bước 2: Khởi tạo Staging Database
*   **File**: `01.5_Create_Staging.sql`
*   **Mục tiêu**: Tạo Database và các bảng Staging (kiểu dữ liệu NVARCHAR) làm vùng đệm cho quá trình ETL. Database này đóng vai trò quan trọng trong việc xử lý các phép biến đổi phức tạp trước khi nạp vào kho dữ liệu.

### Bước 3: Khởi tạo Structure cho Data Warehouse
*   **File**: `02_Create_DWH_Tables.sql`
*   **Mục tiêu**: Tạo các bảng Dimension (SCD Type 1 & 2) và Fact (Star Schema) cho `AirlineDWH`.
*   **Lưu ý**: Script này chỉ tạo cấu trúc và các dòng "Unknown member". Việc đổ dữ liệu từ OLTP vào DWH sẽ được thực hiện qua các gói SSIS/Spark ở bước sau.

---
*Cập nhật lần cuối: 18/04/2026*

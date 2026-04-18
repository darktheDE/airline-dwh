# BÁO CÁO VÀ HƯỚNG DẪN SETUP SSIS FRAMEWORK (TASK 2-4)

Tài liệu này ghi lại các bước đã thực hiện để tạo bộ khung dự án SSIS và hướng dẫn cho thành viên mới để đảm bảo tính nhất quán, không xảy ra lỗi kết nối khi làm việc nhóm.

---

## PHẦN 1: CÁC BƯỚC ĐÃ THỰC HIỆN (NHẬT KÝ DỰ ÁN)

Chúng ta đã thiết lập một cấu trúc dự án SSIS chuyên nghiệp với các đặc điểm sau:

1. **Khởi tạo Project**:
   - Tạo Project **Airline_DWH_ETL** (Integration Services Project) tại thư mục `SSIS_Package`.
   - Thiết lập **TargetServerVersion** phù hợp với SQL Server của cả nhóm (SQL Server 2022).

2. **Cấu hình Kết nối (Project Level)**:
   - Tạo 3 Connection Managers mức Project: **CONN_OLTP**, **CONN_STAGING**, **CONN_DWH**.
   - **Driver**: Sử dụng `Microsoft OLE DB Driver for SQL Server` (Driver mới nhất, ổn định hơn Native Client cũ).
   - **Server Name**: Sử dụng `.\SQLDEV` (Instance cụ thể trên máy tạo) hoặc `.` (Localhost).
   - **Database**: Trỏ chính xác về 3 database tương ứng.

3. **Xử lý Bảo mật & Chia sẻ (Quan trọng nhất)**:
   - Chuyển `ProtectionLevel` của Project từ *EncryptSensitiveWithUserKey* sang **`DontSaveSensitive`**.
   - Đồng bộ hóa `ProtectionLevel` của tất cả các file Package (.dtsx) về **`DontSaveSensitive`**. 
   - *Lợi ích: Giúp thành viên khác mở project không bị mất mật khẩu/connection và không bị lỗi dấu x đỏ do lệch mã hóa.*

4. **Xây dựng Master Control Flow**:
   - Tạo 3 Package con rỗng: `Load_Dimensions.dtsx`, `Load_Facts.dtsx`, `Post_Processing.dtsx`.
   - Tạo `Master_Package.dtsx` sử dụng **Execute Package Task** với kiểu **Project Reference**.
   - Kết nối trình tự: Dimensions -> Facts -> Post Processing.

---

## PHẦN 2: HƯỚNG DẪN DÀNH CHO THÀNH VIÊN MỚI (B & C)

Để chạy được Project này trên máy cá nhân mà không bị lỗi, các bạn hãy làm đúng theo các bước sau:

### 1. Chuẩn bị môi trường (Cài một lần duy nhất)
* **SQL Server**: Đảm bảo máy bạn đã cài SQL Server (bản Express, Developer hoặc Standard).
* **Driver**: Cài đặt **Microsoft OLE DB Driver for SQL Server (MSOLEDBSQL)**. Đây là Driver chúng ta dùng chung cho Project.
  - Tải tại: [Microsoft OLE DB Driver for SQL Server](https://learn.microsoft.com/en-us/sql/connect/oledb/download-oledb-driver)

### 2. Chuẩn bị Database
Chuẩn bị sẵn 3 database "rỗng" trong SQL Server máy bạn bằng cách chạy lệnh SQL sau:
```sql
CREATE DATABASE Airline_OLTP;
CREATE DATABASE Airline_Staging;
CREATE DATABASE AirlineDWH; -- Lưu ý tên viết liền
```
*(Nếu bạn đã có data rồi thì bỏ qua bước này).*

### 3. Clone và Mở Project
1. **Pull code** từ nhánh `qui-dev` (hoặc nhánh master) về máy.
2. Mở file `Airline_DWH_ETL.sln` bằng **Visual Studio**.
3. Nếu ở thư mục **Connection Managers** có dấu X đỏ:
   - Nháy đúp vào từng Connection (ví dụ `CONN_OLTP`).
   - Sửa **Server name** thành tên máy của bạn (hoặc dấu `.` nếu máy bạn dùng Default Instance).
   - Bấm **Test Connection** để đảm bảo xanh lè.

### 4. Kiểm tra cấu hình bảo mật
* Đảm bảo Project và các Package luôn ở chế độ **`DontSaveSensitive`** trước khi commit/push code lên Git. Nếu thấy báo lỗi *"Project consistency check failed"*, hãy kiểm tra lại mức bảo mật này.

### 5. Chạy thử
1. Nhấn chuột phải vào Project `Airline_DWH_ETL` -> Chọn **Build**.
2. Mở file `Master_Package.dtsx`.
3. Nhấn **Start** (mũi tên xanh). 
4. **Kết quả đạt**: Cả 3 ô Task đều hiện dấu tích xanh là thành công.

---
*Người soạn: Qui*

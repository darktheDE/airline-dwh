# Task Guide 1.2: Xây dựng Hệ thống Nguồn (Airline_OLTP)

Tài liệu này hướng dẫn cách thiết lập cơ sở dữ liệu tác nghiệp (OLTP) làm nguồn dữ liệu cho dự án Airline DWH.

---

## 1. Mục tiêu (Objective)
- Xây dựng database `Airline_OLTP` mô phỏng hệ thống thực tế.
- Nạp dữ liệu từ các file CSV lớn (~5.8 triệu dòng) một cách hiệu quả.
- Chuẩn bị sẵn "dữ liệu bẩn" và các thay đổi logic để thực hành SSIS (SCD Type 2, Data Cleansing).

## 2. Thiết kế Cấu trúc Bảng (Schema Design)

Hệ thống bao gồm 4 bảng chính với các cột Audit bắt buộc:
- **tb_Airlines**: Danh mục hãng hàng không.
- **tb_Airports**: Danh mục sân bay (Lưu ý: mã sân bay tăng lên `VARCHAR(7)` để chứa các ID FAA dạng số).
- **tb_Aircraft_Master**: Thông tin đăng kiểm tàu bay (Kết hợp từ FAA Master và ACFTREF).
- **tb_Flights**: Giao dịch chuyến bay (Bảng lớn nhất).

> [!IMPORTANT]
> **Audit Columns**: Tất cả các bảng đều có `Created_Date` và `Updated_Date`. Cột `Updated_Date` đóng vai trò quan trọng trong việc cấu hình **Incremental Load (Lấy dữ liệu thay đổi)** của SSIS sau này.

---

## 3. Chiến lược Nạp dữ liệu (Data Ingestion)

Do hạn chế của lệnh `BULK INSERT` (không cho phép chọn cột và nhạy cảm với kiểu dữ liệu), chúng ta sử dụng quy trình **Staging**:

1. **Staging Table**: Tạo bảng tạm (`#stg_...`) với tất cả các cột là `VARCHAR` để đảm bảo nạp file thành công 100%.
2. **Bulk Insert**: Sử dụng `ROWTERMINATOR = '0x0a'` để xử lý tương thích với cả định dạng file Windows và Linux.
3. **Data Transformation**: Sử dụng `INSERT INTO ... SELECT` kết hợp với `TRY_CAST` và `NULLIF` để làm sạch dữ liệu ngay khi chuyển từ Staging vào bảng chính.

---

## 4. Giả lập Dữ liệu Bẩn (Dirty Data Injection)

Để thực hành phần ETL, chúng ta đã cố định một số lỗi phổ biến vào database:

| Loại lỗi | Số dòng ảnh hưởng | Mục tiêu thực hành SSIS |
| :--- | :--- | :--- |
| **NULL Delay** | ~5,000 | Sử dụng `Derived Column` (ISNULL -> 0) |
| **Time Format (0)** | ~2,000 | Sử dụng `Data Conversion` hoặc `NULLIF` |
| **Tail Number Format** | ~500 | Xử lý chuỗi (Thêm tiền tố 'N' bị thiếu) |
| **Negative Values** | ~300 | Xử lý logic nghiệp vụ (Delay không thể âm) |
| **Logic Mâu thuẫn** | ~200 | Sử dụng `Conditional Split` (Đã hủy thì không có giờ đến) |

---

## 5. Giả lập SCD Type 2 (Demo cho Tuần 3)

Chúng ta đã thực hiện cập nhật `Engine_Type` cho 5 máy bay và đẩy `Updated_Date` về tương lai (**2026-02-01**):
- **Hiện tượng**: Dữ liệu thay đổi nhưng không làm mất dữ liệu cũ.
- **SSIS Requirement**: Khi chạy ETL lần tới, SSIS phải nhận diện được 5 dòng này thông qua Watermark và áp dụng cơ chế SCD Type 2 để lưu lịch sử.

---

## 6. Kiểm tra Kết quả (Verification)

Sau khi chạy script `01_Create_OLTP.sql`, hãy kiểm tra số lượng dòng để đảm bảo khớp với dataset:
```sql
SELECT 'tb_Flights' as Tbl, COUNT(*) as Rows FROM dbo.tb_Flights;
-- Kỳ vọng: ~5,819,079 dòng
```

> [!TIP]
> Nếu bảng `tb_Flights` vẫn trống (0 dòng), hãy kiểm tra xem file CSV có đang bị chương trình khác (Excel, WinRAR) mở và khóa lại không.

---

## 7. Nhật ký Thay đổi (Change Log)

| Ngày | Người thực hiện | Nội dung thay đổi |
| :--- | :--- | :--- |
| 2026-04-18 | Kiến Hưng | Cấu hình lại toàn bộ đường dẫn tuyệt đối (Absolute Path) trong script SQL sang: `D:\HCMUTE\HCMUTE_HK6\DataWarehouse\final\airline-dwh\Data\...` |
| 2026-04-18 | Kiến Hưng | Bổ sung file `README.md` trong thư mục `SQL_Script` hướng dẫn chạy script step-by-step. |


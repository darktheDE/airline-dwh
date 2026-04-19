# Tài liệu Hướng dẫn Triển khai SCD Type 1 (Slowly Changing Dimension)
## Chủ đề: Nạp dữ liệu Dimension Airport & Airline

---

## 1. Mục tiêu (Objective)
Xây dựng luồng ETL tự động để di chuyển dữ liệu từ hệ thống nguồn (OLTP) qua vùng đệm (Staging) và nạp vào kho dữ liệu (Data Warehouse). 
- **Cơ chế áp dụng**: SCD Type 1 (Overwrite).
- **Ý nghĩa**: Đảm bảo dữ liệu trong kho luôn cập nhật mới nhất theo nguồn. Nếu thông tin (tên sân bay, thành phố...) thay đổi ở nguồn, hệ thống sẽ ghi đè dữ liệu mới lên dữ liệu cũ tại DWH- [x] Task 11: Implement Fact_Turnaround_Efficiency (Accumulating Snapshot)
    - [x] Create Stored Procedure `usp_ExtractTurnaround` with correct OLTP Schema
    - [x] Handle Aircraft/Airport data mismatches using `LEFT JOIN` and `Unknown Member` logic
    - [x] Batch load 10M+ rows successfully into `Fact_Turnaround_Efficiency`

## 2. Quy trình triển khai chi tiết

### Bước 1: Control Flow - Làm sạch vùng đệm (Truncate Staging)
- **Hành động**: Sử dụng `Execute SQL Task`.
- **Lệnh SQL**: `TRUNCATE TABLE stg_Airports; TRUNCATE TABLE stg_Airlines;`
- **Ý nghĩa**: Vùng Staging chỉ đóng vai trò chứa dữ liệu tạm thời cho phiên làm việc hiện tại. Việc xóa dữ liệu cũ giúp tránh tình trạng nạp trùng lặp hoặc dư thừa dữ liệu từ các phiên chạy trước.

### Bước 2: Data Flow - Trích xuất dữ liệu (Extract OLTP to Staging)
- **Hành động**: Tạo `Data Flow Task`.
- **Thành phần**: 
    - **OLE DB Source**: Kết nối tới DB `Airline_OLTP`.
    - **OLE DB Destination**: Kết nối tới DB `Airline_Staging`.
- **Ý nghĩa**: Chuyển dữ liệu thô từ hệ thống vận hành sang môi trường trung gian để chuẩn bị cho các bước biến đổi phức tạp hơn, giúp giảm tải trực tiếp cho hệ thống nguồn.

### Bước 3: Data Flow - Cấu hình SCD Type 1 (Load Staging to DWH)
Đây là bước quan trọng nhất, sử dụng công cụ **Slowly Changing Dimension (SCD)** chuyên dụng của SSIS.

#### 3.1. Tiền xử lý dữ liệu (Data Conversion)
- **Vấn đề**: Kiểu dữ liệu giữa Staging (thường là NVARCHAR(MAX) hoặc String) và DWH (thành phần số Decimal hoặc NVARCHAR có độ dài cố định) có sự khác biệt.
- **Giải pháp**: Dùng `Data Conversion` để ép kiểu (Cast) về đúng định dạng trước khi đưa vào SCD Wizard.

#### 3.2. Cấu hình SCD Wizard
- **Business Key (`IATA_Code`)**: Được chọn làm mã định danh duy nhất. SSIS sẽ dựa vào mã này để tìm kiếm xem sân bay/hãng bay đã tồn tại trong DWH chưa.
- **Changing Attribute (SCD Type 1)**: Chọn loại này cho các cột thông tin mô tả (AirportName, City, State, Latitude, Longitude).
    - **Ý nghĩa**: Khi SSIS phát hiện `IATA_Code` đã tồn tại nhưng có sự khác biệt ở các cột mô tả, nó sẽ kích hoạt nhánh **Changing Attributes Updates Output** để thực hiện lệnh `UPDATE` ghi đè.
- **Fixed Attribute**: (Không dùng trong bài này) Dùng cho các dữ liệu không bao giờ được phép thay đổi.
- **Historical Attribute (SCD Type 2)**: (Không dùng trong bài này) Dùng khi muốn lưu lại lịch sử thay đổi (tạo dòng mới).

## 3. Hoạt động của hệ thống (How it works)
Sơ đồ tự động sinh ra bởi SCD Wizard sẽ hoạt động theo logic sau:
1. **Dòng mới (New Member)**: Nếu `IATA_Code` chưa có trong DWH -> Đẩy vào nhánh `Insert Destination`.
2. **Dòng cũ có thay đổi (Changed Member)**: Nếu `IATA_Code` đã có nhưng nội dung khác đi -> Đẩy vào nhánh `OLE DB Command` để chạy lệnh `UPDATE`.
3. **Dòng không đổi**: Không thực hiện hành động nào để tiết kiệm tài nguyên.

## 4. Kiểm tra và Nghiệm thu (DoD)
| Tiêu chí | Kết quả mong đợi |
|----------|------------------|
| **Tính toàn vẹn** | Số lượng dòng sau khi nạp phải khớp với nguồn (sau khi trừ các dòng lỗi). |
| **Cơ chế ghi đè** | Khi UPDATE tên sân bay ở OLTP, chạy lại SSIS thì tên ở DWH phải đổi theo. |
| **Không trùng lặp** | Không được có 2 dòng cùng `IATA_Code` trong bảng Dimension. |

---
> [!TIP]
> **Mẹo báo cáo**: Hãy chụp ảnh màn hình luồng Data Flow có các dấu tích xanh (Green Checkmarks) và bảng so sánh dữ liệu trước/sau khi Update ở SQL để minh chứng cho cơ chế SCD Type 1.

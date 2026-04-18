# TÀI LIỆU KỸ THUẬT TASK 5: XÂY DỰNG LUỒNG ETL DIM_DATE & DIM_TIME

Tài liệu này trình bày chi tiết về việc xây dựng các chiều thời gian tĩnh trong dự án Airline DWH, bao gồm lý do thực hiện, ý nghĩa nghiệp vụ và các bước triển khai kỹ thuật.

---

## 1. TẠI SAO PHẢI LÀM BƯỚC NÀY? (LÝ DO & Ý NGHĨA)

Trong mô hình dữ liệu Kimball (Star Schema), `Dim_Date` và `Dim_Time` là hai chiều cơ bản (Core Dimensions) vì hầu hết các phân tích đều dựa trên trục thời gian.

*   **Tính liên tục của báo cáo (Reporting Continuity):** Dữ liệu OLTP chỉ lưu những ngày có giao dịch. Bảng Dim_Date tự sinh (populate) đảm bảo trục thời gian có đủ 365 ngày (kể cả những ngày không có chuyến bay), giúp biểu đồ báo cáo không bị đứt đoạn.
*   **Tối ưu hiệu năng (Performance):** Thay vì dùng kiểu `DATETIME` (8 bytes) để JOIN, chúng ta dùng kiểu số nguyên `INT` (Surrogate Key) như `20150101` (4 bytes). Điều này giúp tốc độ truy vấn trên hàng triệu dòng dữ liệu nhanh hơn đáng kể.
*   **Tính toán sẵn Business Rules:** Các logic như "Thứ trong tuần", "Quý", "Buổi trong ngày (Sáng/Chiều)" được tính sẵn một lần duy nhất. Người dùng báo cáo chỉ việc kéo-thả mà không cần viết lại logic code.
*   **Đảm bảo sự thống nhất (Single Version of Truth):** Toàn bộ dự án sẽ dùng chung một định nghĩa về "Buổi sáng" hay "Ngày cuối tuần", tránh việc mỗi thành viên tự tính ra một kết quả khác nhau.

---

## 2. CÁC PHẦN ĐÃ THỰC HIỆN

1.  **Tạo Package con**: `Load_Dim_Date_Time.dtsx` được tách riêng để quản lý dữ liệu tĩnh.
2.  **Xây dựng Logic T-SQL**: 
    - Sử dụng vòng lặp `WHILE` để sinh 365 ngày của năm 2015 cho `Dim_Date`.
    - Sử dụng vòng lặp lồng để sinh 1,440 phút trong ngày cho `Dim_Time`.
3.  **Áp dụng Quy tắc nghiệp vụ (Business Rules)**:
    - Định nghĩa khung giờ: Morning (06-11h), Afternoon (12-17h), Evening (18-23h), Night (00-05h).
    - Phân loại ngày cuối tuần (Saturday/Sunday).
4.  **Tích hợp hệ thống**: Nối package nạp thời gian vào `Master_Package.dtsx` để tự động hóa quy trình nạp dữ liệu.

---

## 3. CÁC BƯỚC THỰC HIỆN CHI TIẾT

### Bước 1: Thiết lập Execute SQL Task cho Dim_Date
- **Công cụ**: Execute SQL Task.
- **Connection**: `CONN_DWH`.
- **Logic**: 
    - Xóa dữ liệu cũ (gia tăng tính tái sử dụng).
    - Dùng vòng lặp tăng dần biến `@CurrentDate` từ `2015-01-01`.
    - Dùng hàm `DATEPART` và `DATENAME` để bóc tách thông tin: Năm, Quý, Tháng, Thứ.
    - Ép kiểu ngày sang định dạng số nguyên `YYYYMMDD` để làm khóa chính.

### Bước 2: Thiết lập Execute SQL Task cho Dim_Time
- **Công cụ**: Execute SQL Task.
- **Logic**:
    - Chạy vòng lặp từ 0 đến 23 (Giờ) và 0 đến 59 (Phút).
    - Sử dụng mệnh đề `CASE WHEN` để phân loại BUỔI trong ngày dựa trên số giờ.
    - Khóa chính là tổ hợp `(Giờ * 100) + Phút`.

### Bước 3: Ràng buộc thứ tự (Precedence Constraints)
- Nối mũi tên xanh từ Task nạp Ngày sang Task nạp Giờ. Điều này đảm bảo tính tuần tự và tránh xung đột tài nguyên nếu server xử lý song song.

### Bước 4: Xử lý lỗi Syntax trong Visual Studio
- Do VS Parser không hiểu hết các hàm T-SQL phức tạp, chúng ta thiết lập thuộc tính **BypassPrepare = True** để ép SSIS gửi thẳng script xuống SQL Server mà không cần kiểm tra cú pháp tại GUI.

---

## 4. TIÊU CHÍ NGHIỆM THU (DoD) ĐÃ ĐẠT ĐƯỢC
- [x] Package chạy thành công, không có dấu X đỏ.
- [x] Bảng `Dim_Date` có 366 dòng (365 ngày năm 2015 + 1 dòng Unknown).
- [x] Bảng `Dim_Time` có 1441 dòng (1440 phút + 1 dòng Unknown).
- [x] Đã đồng bộ `ProtectionLevel = DontSaveSensitive` để team có thể pull về dùng ngay.

---
*Người soạn: Qui*

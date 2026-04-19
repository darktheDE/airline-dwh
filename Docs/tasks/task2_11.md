# Tài liệu Hướng dẫn Triển khai Fact Table (Accumulating Snapshot)
## Chủ đề: Tính toán Hiệu suất Quay đầu Máy bay (Fact Turnaround Efficiency)

---

## 1. Mục tiêu (Objective)
Xây dựng bảng Fact theo mô hình **Accumulating Snapshot** để theo dõi toàn bộ vòng đời của một quy trình quay đầu máy bay (từ lúc hạ cánh chuyến trước đến lúc cất cánh chuyến sau).
- **Cơ chế nạp**: Trích xuất dữ liệu từ OLTP, tiền xử lý tại Staging và nạp vào DWH.
- **Ý nghĩa**: Giúp hãng hàng không nhận diện các "điểm nghẽn" (Bottlenecks) tại các sân bay và tối ưu hóa thời gian sử dụng tàu bay.

## 2. Quy trình triển khai chi tiết

### Bước 1: Trích xuất & Kết hợp (Extract & Pair Flights)
Do dữ liệu gốc `tb_Flights` là các dòng riêng lẻ, chúng ta cần ghép cặp (Pair) chuyến bay đến và chuyến bay đi kế tiếp của cùng một tàu bay.
- **Công cụ**: Stored Procedure `usp_ExtractTurnaround`.
- **Logic quan trọng**:
    - Ghép cặp dựa trên `Tail_Number` (Số đuôi máy bay) và `Destination = Origin`.
    - Chuyển đổi thời gian từ định dạng số (HHmm) sang `DATETIME` chuẩn để tính toán.
    - Xử lý các chuyến bay quay đầu xuyên đêm (vắt qua ngày hôm sau).

### Bước 2: Nạp dữ liệu vào Kho (Load to DWH)
Sử dụng `Execute SQL Task` hoặc `Data Flow` để chuyển dữ liệu từ Staging vào bảng Fact chính.

#### 2.1. Xử lý dữ liệu không khớp (Data Integrity)
> [!IMPORTANT]
> **Bài học kinh nghiệm**: Trong thực tế, dữ liệu chuyến bay (Fact) thường chứa các mã máy bay hoặc sân bay mới chưa kịp cập nhật vào danh mục (Dimension).
> - **Giải pháp an toàn**: Sử dụng **LEFT JOIN** thay vì INNER JOIN.
> - **Xử lý NULL**: Sử dụng hàm `ISNULL(Key, -1)` để gán về thành phần **Unknown** thay vì loại bỏ dòng dữ liệu. Điều này đảm bảo bảng Fact luôn đầy đủ 100% số lượng chuyến bay.

#### 2.2. Tính toán các chỉ số Hiệu suất (Metrics)
- **Actual_Turnaround_Mins**: Khoảng thời gian thực tế giữa hai chuyến bay.
- **Turnaround_Variance_Mins**: Hiệu số giữa thực tế và mục tiêu (ví dụ: mục tiêu là 45 phút).
- **Is_Bottleneck**: Cờ đánh dấu 1 nếu thời gian quay đầu vượt quá ngưỡng cho phép (ví dụ: trễ hơn 30 phút so với mục tiêu).

## 3. Hoạt động của hệ thống (How it works)
1. **SSIS Package** gọi thủ tục `usp_ExtractTurnaround` để làm sạch và chuẩn bị dữ liệu tại Staging.
2. Lệnh T-SQL thực hiện phép nối với các bảng Dimension (`Dim_Airport`, `Dim_Aircraft`, `Dim_Airline`, `Dim_Date`) để lấy các Surrogate Keys.
3. Dữ liệu được nạp theo từng đợt (Batch) vào `Fact_Turnaround_Efficiency` để tối ưu tài nguyên máy chủ.

## 4. Kiểm tra và Nghiệm thu (DoD)
| Tiêu chí | Kết quả mong đợi |
|----------|------------------|
| **Khớp số lượng** | Số dòng trong Fact phải bằng số lượng cặp chuyến bay hợp lệ tại Staging. |
| **Tính chính xác** | `Actual_Turnaround_Mins` phải đúng bằng chênh lệch thời gian cất/hạ cánh. |
| **Tính toàn vẹn** | Không có dòng nào bị mất do lỗi không khớp Dimension (nhờ xử lý `-1`). |

---
> [!TIP]
> **Mẹo triển khai**: Luôn sử dụng `(NOLOCK)` khi kiểm tra số lượng bản ghi trên bảng Fact lớn để tránh làm chậm hệ thống đang nạp dữ liệu.

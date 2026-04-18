# 🚀 TÀI LIỆU TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

**Tên dự án:** Hệ thống Kho dữ liệu Phân tích Hoạt động Khai thác Chuyến bay và Tình trạng Bảo trì Tàu bay (Airline Flight Operations & Asset Health DWH).
**Mô hình triển khai:** Kimball Lifecycle.
**Quy mô nhân sự:** 03 Data Engineers.

## 1. TÓM TẮT DỰ ÁN (EXECUTIVE SUMMARY)
Ngành hàng không thiệt hại hàng tỷ USD mỗi năm do hoãn/hủy chuyến. Thay vì chỉ thống kê các chuyến bay bị trễ một cách đơn thuần, dự án này xây dựng một Kho dữ liệu (DWH) tích hợp dữ liệu giao dịch chuyến bay với cơ sở dữ liệu đăng kiểm kỹ thuật tàu bay của Cục Hàng không Liên bang (FAA). 

Hệ thống cung cấp một góc nhìn toàn diện 360 độ, giúp Ban quản trị giải quyết 3 bài toán chiến lược: 
1. Đánh giá hiệu suất đúng giờ (On-Time Performance) và thiệt hại tài chính.
2. Theo dõi sức khỏe tài sản (Asset Health) để dự báo bảo trì.
3. Đo lường độ hiệu quả của thời gian quay đầu (Turnaround) trên mặt đất tại các sân bay lớn.

## 2. KIẾN TRÚC VÀ NGUỒN DỮ LIỆU (DATA ARCHITECTURE & SOURCES)
*   **Nguồn dữ liệu 1 (Giao dịch):** Dataset "2015 Flight Delays and Cancellations" (từ Kaggle/DOT), chứa thông tin chi tiết của gần 6 triệu chuyến bay (bao gồm cột `TAIL_NUMBER`).
*   **Nguồn dữ liệu 2 (Master Data):** Dữ liệu FAA Aircraft Registry (`ardata.pdf`), chứa thông tin đăng kiểm của từng tàu bay (Năm sản xuất, Hãng sản xuất, Loại động cơ).
*   **Kiến trúc luồng dữ liệu:** 
    `CSV Files` ➡️ `SQL Server (OLTP)` ➡️ `SSIS (Staging Area -> DWH)` ➡️ `SSAS (OLAP Cube)` ➡️ `Power BI (Dashboard)`.

## 3. THIẾT KẾ MÔ HÌNH ĐA CHIỀU (DIMENSIONAL MODELING)
Dự án sử dụng **Star Schema** với các Chiều dùng chung (Conformed Dimensions) để đảm bảo tính nhất quán dữ liệu qua 3 bảng Fact.

### 3.1. Các Bảng Chiều (Dimensions)
1.  **Dim_Date & Dim_Time:** Tự động tạo bằng SQL script. *Hierarchy: Year > Quarter > Month > Day* và *Time_Period > Hour > Minute*.
2.  **Dim_Airport:** Chứa thông tin sân bay đi/đến. *Hierarchy: State > City > Airport_Code*. (Xử lý theo **SCD Type 1**).
3.  **Dim_Airline:** Chứa thông tin hãng hàng không. (Xử lý theo **SCD Type 1**).
4.  **Dim_Aircraft (Core Dimension):** Kết nối qua `TAIL_NUMBER`. *Hierarchy: Manufacturer > Engine_Type > Tail_Number*. (Xử lý theo **SCD Type 2** để lưu lịch sử chuyển nhượng/thay đổi động cơ của tàu bay).

### 3.2. Ma trận Bảng Sự kiện (Fact Tables)
Nhóm áp dụng cả 3 loại Fact chuẩn của Kimball, chia đều cho 3 thành viên:

*   **Fact 1: Fact_Flight_Transaction (Loại: Transaction Fact)**
    *   *Độ hạt (Grain):* 1 dòng = 1 chặng bay (Flight Leg).
    *   *Measures:* `Distance`, `Dep_Delay_Mins`, `Arr_Delay_Mins`, `Is_Delayed` (Cờ 0/1), `Estimated_Financial_Loss_USD` (Độ đo phái sinh tính thiệt hại kinh tế).
*   **Fact 2: Fact_Aircraft_Daily_Snapshot (Loại: Periodic Snapshot Fact)**
    *   *Độ hạt (Grain):* 1 dòng = Thông tin tổng hợp của 1 tàu bay trong 1 ngày lịch.
    *   *Measures:* `Daily_Flight_Count`, `Daily_Air_Time`, `Tech_Incident_Count` (Số lần lỗi kỹ thuật), `Cumulative_Flight_Hours` (Giờ bay tích lũy để lên lịch bảo trì).
*   **Fact 3: Fact_Turnaround_Efficiency (Loại: Accumulating Snapshot Fact)**
    *   *Độ hạt (Grain):* 1 dòng = 1 chu trình quay đầu của 1 máy bay tại 1 sân bay.
    *   *Milestones (Mốc thời gian):* `Arrival_Time` (Chuyến trước) ➡️ `Departure_Time` (Chuyến sau).
    *   *Measures:* `Actual_Turnaround_Mins`, `Turnaround_Variance_Mins` (Chênh lệch thực tế so với kế hoạch).

## 4. CHIẾN LƯỢC XỬ LÝ ETL VỚI SSIS

### 4.1. Cơ chế Tải dữ liệu tăng dần (Incremental Load & CDC)
*   **Phương pháp:** Sử dụng cơ sở dữ liệu OLTP làm trung gian, thêm cột `Updated_Date`. Tạo bảng `ETL_Watermark` trong DWH để lưu `Last_Load_Time`.
*   **Thực thi:** Package SSIS sẽ chỉ Extract những dòng trong OLTP có `Updated_Date > Last_Load_Time`.

### 4.2. Xử lý Slowly Changing Dimension (SCD)
*   Sử dụng component `SCD Transformation` trong SSIS cho `Dim_Aircraft`.
*   Map cột `TAIL_NUMBER` làm Business Key. Track changes trên các cột `Engine_Type` và `Airline_Owner`. Sử dụng `Valid_From`, `Valid_To`, và `Is_Active` flag.

### 4.3. Các Quy tắc Nghiệp vụ (Business Rules) tại khâu Transform
1.  **Data Cleaning:** Chuyển đổi định dạng giờ (float: `1530.0`) thành định dạng thời gian chuẩn (`15:30`) hoặc pad số 0 để map với `Dim_Time`.
2.  **Handling NULLs:** Replace toàn bộ giá trị NULL ở các cột Delay (Weather, Carrier, NAS, Security, Late Aircraft) thành `0` bằng `Derived Column`.
3.  **Xác định Delay (Is_Delayed):** Áp dụng rule của Cục Hàng không: Nếu `ARR_DELAY >= 15` thì `Is_Delayed = 1`, ngược lại `= 0`.
4.  **Tính Turnaround (Dành cho Fact 3):** Sử dụng câu lệnh SQL Window Function `LAG()` ở khu vực Staging để nối `ARR_TIME` của chuyến trước với `DEP_TIME` của chuyến sau cho cùng một `TAIL_NUMBER`.

## 5. KHAI THÁC VÀ TRỰC QUAN HÓA (OLAP & VISUALIZATION)
Dự án xây dựng **01 Executive Dashboard** duy nhất trên Power BI, kết nối với SSAS Cube để trả lời 3 Insight cốt lõi (Tương ứng với 3 câu lệnh MDX trong báo cáo):

1.  **Financial & Operations Insight (Từ Fact 1):** Top 5 tuyến đường (Origin -> Dest) và Hãng hàng không "đốt" nhiều tiền nhất do lỗi chậm trễ/hủy chuyến.
2.  **Asset Health Insight (Từ Fact 2):** Biểu đồ tương quan (Scatter Plot) giữa Tuổi đời tàu bay (Age Bands: <5 năm, 5-15 năm, >15 năm) và Tần suất xảy ra lỗi kỹ thuật (`Tech_Incident_Count`).
3.  **Ground Operations Insight (Từ Fact 3):** Đánh giá "Nút thắt cổ chai" (Bottlenecks) tại các Hub lớn (ATL, ORD) thông qua chỉ số `Turnaround_Variance_Mins` kém nhất.

## 6. CÔNG NGHỆ SỬ DỤNG (TECH STACK)
*   **Database:** Microsoft SQL Server (OLTP, Staging, DWH).
*   **ETL Tool:** SQL Server Integration Services (SSIS).
*   **OLAP Tool:** SQL Server Analysis Services (SSAS - Multidimensional/Tabular).
*   **BI Tool:** Microsoft Power BI.
*   **Version Control & Scripting:** Github (Lưu trữ SQL scripts và tài liệu báo cáo).

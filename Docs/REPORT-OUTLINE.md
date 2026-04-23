**LỜI CẢM ƠN**\
**TÓM TẮT DỰ ÁN (ABSTRACT)** _(Phần này tóm tắt 1 trang về bài toán, kiến trúc và 3 insight lớn nhất đạt được)_\
**BẢNG PHÂN CÔNG VÀ ĐÁNH GIÁ THÀNH VIÊN**\
**DANH MỤC HÌNH ẢNH & BẢNG BIỂU**

### CHƯƠNG 1: TỔNG QUAN DỰ ÁN VÀ KIẾN TRÚC HỆ THỐNG

_(Chương này ăn điểm ở việc giải thích tại sao phải làm DWH và vẽ kiến trúc chuẩn)_\
**1.1. Bối cảnh và Mục tiêu kinh doanh**

* 1.1.1. Vấn đề của ngành hàng không (Hoãn/hủy chuyến, chi phí bảo trì).

* 1.1.2. Mục tiêu của Kho dữ liệu (Tài chính, Vận hành, Sức khỏe tài sản).\
  **1.2. Phân tích Nguồn dữ liệu (Source Data) & Exploratory Data Analysis (EDA)**

* 1.2.1. Dữ liệu Giao dịch: Kaggle Flight Delays 2015.

* 1.2.2. Dữ liệu Master: FAA Aircraft Registry.

* 1.2.3. Các vấn đề Chất lượng dữ liệu (Data Quality) cần xử lý (NULL, sai format giờ, khoảng trắng).\
  **1.3. Kiến trúc Hệ thống Kho dữ liệu**

* 1.3.1. Sơ đồ Kiến trúc Tổng thể (Vẽ luồng: CSV -> SQL OLTP -> Staging -> DWH -> SSAS -> Power BI).

* 1.3.2. Giải pháp kỹ thuật: Lý do sử dụng OLTP trung gian và khu vực Staging.

### CHƯƠNG 2: THIẾT KẾ MÔ HÌNH ĐA CHIỀU (DIMENSIONAL MODELING)

_(Chương này chiếm 35 điểm - Thể hiện rõ việc dùng template của Kimball)_\
**2.1. Ma trận Nghiệp vụ (High-Level Detailed Bus Matrix)**\
**2.2. Lựa chọn Mô hình và Sơ đồ quan hệ** (Giải thích lý do chọn Star Schema).\
**2.3. Thiết kế các Chiều dùng chung (Conformed Dimensions) & Phân cấp (Hierarchies)**

* 2.3.1. Chiều Thời gian (Dim_Date, Dim_Time).

* 2.3.2. Chiều Vị trí Địa lý (Dim_Airport).

* 2.3.3. Chiều Hãng Hàng không (Dim_Airline).\
  **2.4. Chiến lược Xử lý Chiều thay đổi chậm (Slowly Changing Dimension - SCD)**

* 2.4.1. Áp dụng SCD Type 1 cho Sân bay và Hãng hàng không (Ghi đè).

* 2.4.2. Áp dụng SCD Type 2 cho Tàu bay (Dim_Aircraft) (Lưu lịch sử thay đổi động cơ/hãng sở hữu).\
  **2.5. Thiết kế các Bảng Sự kiện (Fact Tables)**

* 2.5.1. Bảng Sự kiện Giao dịch: Fact_Flight_Transaction (Độ hạt, Độ đo Tài chính/OTP).

* 2.5.2. Bảng Sự kiện Tích lũy Định kỳ: Fact_Aircraft_Daily_Snapshot (Độ hạt, Độ đo Bảo trì).

* 2.5.3. Bảng Sự kiện Chu trình: Fact_Turnaround_Efficiency (Độ hạt, Mốc thời gian, Đo lường thời gian nằm sân).

### CHƯƠNG 3: TRIỂN KHAI TÍCH HỢP DỮ LIỆU (ETL VỚI SSIS)

_(Chương này chiếm 30 điểm - Phần "Khoe" kỹ năng SSIS đỉnh cao)_\
**3.1. Cấu trúc Master Package và Quản lý Kết nối (Connection Managers)**\
**3.2. Kỹ thuật Tải dữ liệu Tăng dần (Incremental Load) và Bắt giữ Thay đổi (CDC)**\
_(Trình bày cơ chế bảng ETL_Watermark và biến Last_Load_Date)_.\
**3.3. Extract: Quá trình Nạp dữ liệu từ CSV vào Cơ sở dữ liệu OLTP**\
**3.4. Transform & Load: Quy trình Xử lý các Bảng Chiều (Dimensions)**

* 3.4.1. Nạp và sinh dữ liệu tĩnh (Dim_Date, Dim_Time).

* 3.4.2. Nạp dữ liệu cấu hình SCD Type 1 (Dim_Airline, Dim_Airport).

* 3.4.3. Nạp dữ liệu cấu hình SCD Type 2 (Dim_Aircraft từ FAA).\
  **3.5. Transform & Load: Quy trình Xử lý các Bảng Sự kiện (Facts)**

* 3.5.1. Quy tắc Nghiệp vụ (Business Rules): Xử lý NULL, Clean Data và Tính toán Derived Columns.

* 3.5.2. Luồng xử lý Fact_Flight_Transaction (Sử dụng Lookup map Surrogate Key).

* 3.5.3. Luồng xử lý Fact_Aircraft_Daily (Sử dụng Aggregate tối ưu hiệu năng).

* 3.5.4. Luồng xử lý Fact_Turnaround_Efficiency (Sử dụng SQL Window Function LAG() ở Staging).

### CHƯƠNG 4: KHAI THÁC DỮ LIỆU - SSAS CUBE VÀ TRUY VẤN SQL

_(Chương này chứng minh Cube hoạt động tốt và SQL giải quyết các bài toán kinh doanh)_\
**4.1. Xây dựng Analysis Services Project (SSAS)**

* 4.1.1. Khởi tạo Data Source View (DSV).

* 4.1.2. Thiết lập Data Cube và Cấu hình Hierarchies.

* 4.1.3. Triển khai và Xử lý (Deploy & Process).\
  **4.2. Truy vấn SQL giải quyết Bài toán Kinh doanh**

* 4.2.1. Insight 1: Financial Loss & Delay by State (Fact_Flight_Transaction).

* 4.2.2. Insight 2: Delay Root Cause Breakdown by Airline (Fact_Flight_Transaction).

* 4.2.3. Insight 3: Monthly Fleet Activity & Delay Trend (Fact_Aircraft_Daily_Snapshot).

* 4.2.4. Insight 4: Turnaround Delay by City (Fact_Turnaround_Efficiency).

### CHƯƠNG 5: TRỰC QUAN HÓA DỮ LIỆU (EXECUTIVE DASHBOARD)

_(Chương này trình bày sản phẩm cuối cùng)_\
**5.1. Thiết kế Executive Dashboard trên Power BI** (Giới thiệu layout 2x2 và các Slicers).\
**5.2. Phân tích Chuyên sâu (Data Insights)**

* 5.2.1. Insight 1: Thiệt hại Tài chính và Tổng Delay theo Bang (Financial Loss & Arr Delay by State).

* 5.2.2. Insight 2: Hoạt động Đội tàu bay theo Tháng (Monthly Fleet Activity & Delay Trend).

* 5.2.3. Insight 3: Phân tích Nguyên nhân Chậm trễ theo Hãng (Delay Root Cause by Airline).

* 5.2.4. Insight 4: Tổng Thời gian Quay đầu theo Thành phố (Turnaround Variance by City).

### CHƯƠNG 6: TỔNG KẾT

**6.1. Kết quả đạt được** (Đối chiếu với mục tiêu ban đầu).\
**6.2. Hạn chế và Hướng phát triển tương lai.**

**TÀI LIỆU THAM KHẢO**

### 💡 Hướng dẫn cách chia phần viết Báo cáo cho 3 thành viên:

Để hoàn thành báo cáo này một cách nhanh chóng mà không bị "râu ông nọ cắm cằm bà kia", các bạn chia việc trên Word như sau:

* **Thành viên A (Lead - Làm Fact_Flight):** Phụ trách viết Chương 1, Mục 2.1 đến 2.4, Mục 2.5.1, Mục 3.1, Mục 3.4 và Mục 3.5.2. (Người nắm kiến trúc tổng).

* **Thành viên B (Làm Fact_Aircraft_Daily & Incremental Load):** Phụ trách viết Mục 2.5.2, Mục 3.2 (Phần CDC rất quan trọng), Mục 3.3, Mục 3.5.3 và toàn bộ Chương 5 (Vẽ Dashboard và giải thích Insight).

* **Thành viên C (Làm Fact_Turnaround & SSAS):** Phụ trách viết Mục 2.5.3, Mục 3.5.4 (Giải thích kỹ hàm LAG trong SQL), toàn bộ Chương 4 (SSAS & MDX) và Chương 6.
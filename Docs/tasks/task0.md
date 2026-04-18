# Task 0: Thiết kế Mô hình Đa chiều trên Excel (Kimball Templates)

* **Mục tiêu:** Hoàn thiện bản vẽ thiết kế Kho dữ liệu trên 2 file Excel chuẩn của Kimball (High-Level-Dimensional-Modeling-Workbook và Detailed-Dimensional-Modeling-Workbook-Kimball). Đây là tài liệu lõi để nộp kèm báo cáo và dùng để tự động sinh ra code SQL.

**Step-by-Step (Các bước thực hiện):**

* **Bước 1 (High-Level Dimensional Modeling):** Mở file Excel High-Level.

  * Vào sheet **Detailed Bus Matrix**: Định nghĩa 3 Business Processes (tương ứng 3 bảng Fact của 3 người).

  * Đánh dấu "X" để map 3 Fact này với các Conformed Dimensions (Dim_Date, Dim_Time, Dim_Airport, Dim_Airline, Dim_Aircraft).

  * Ở các cột Grain, ghi rõ độ hạt đã chốt (VD: _1 row = 1 flight leg_).

* **Bước 2 (Detailed Modeling - Dimensions):** Mở file Excel Detailed Kimball.

  * Nhân bản (Duplicate) sheet **BlankDimension** ra thành 5 sheets tương ứng với 5 Dim.

  * Điền chi tiết từng cột: Column Name, Display Name, Description, Data Type.

  * **Đặc biệt quan trọng:** Ở cột **SCD Type**, ghi rõ Type 1 cho Airport/Airline và Type 2 cho Aircraft (Nhớ khai báo thêm 3 cột Valid_From, Valid_To, Is_Active cho Dim_Aircraft).

* **Bước 3 (Detailed Modeling - Facts):**

  * Nhân bản sheet **BlankFact** ra thành 3 sheets tương ứng với 3 Fact.

  * Điền chi tiết các Khóa ngoại (Foreign Keys) trỏ về Dim.

  * Điền chi tiết các Độ đo (Measures) đã thống nhất (VD: Flight_Count, Financial_Loss_USD, Turnaround_Variance_Mins). Xác định rõ cột **Source** (lấy từ trường nào trong file CSV).

* **Bước 4 (Sinh code SQL tự động):**

  * Sau khi điền xong chuẩn xác, quay lại sheet **Home** của file Excel.

  * Click vào nút macro **Generate SQL Script** (như trong ảnh refdoc.pdf) để tool tự động sinh ra các lệnh CREATE TABLE.

  * Lưu đoạn script này lại thành file 02_Create_DWH_Tables.sql. (Nếu macro bị lỗi do phiên bản Excel, hãy copy các trường đã điền để tự viết lệnh SQL).

**Tiêu chí nghiệm thu (Definition of Done):**

* 2 file Excel đã được điền đầy đủ 100% không bỏ trống các trường quan trọng và được push lên Github của nhóm.

* Chụp ảnh màn hình sheet **Detailed Bus Matrix** và 1-2 sheet **BlankFact / BlankDimension** tiêu biểu để đưa vào **Chương 2** của báo cáo Word.

* Sinh được file Script SQL tạo bảng thành công.

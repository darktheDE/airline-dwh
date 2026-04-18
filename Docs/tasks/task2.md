# Task 2: Viết Script SQL tạo DB OLTP và Import CSV

* **Mục tiêu:** Giả lập một hệ thống cơ sở dữ liệu tác nghiệp (OLTP) thực tế của hãng hàng không. Đây là nguồn (Source) để SSIS kết nối vào kéo dữ liệu.

**Step-by-Step (Các bước thực hiện):**

* **Bước 1:** Mở SQL Server Management Studio (SSMS), tạo Database mới tên là Airline_OLTP.

* **Bước 2:** Viết script CREATE TABLE cho các bảng: tb_Flights, tb_Airlines, tb_Airports, tb_Aircraft_Master với các kiểu dữ liệu phù hợp (INT, VARCHAR, FLOAT).

* **Bước 3:** Thêm 2 cột Audit vào TẤT CẢ các bảng vừa tạo:

  * Created_Date DATETIME DEFAULT GETDATE()

  * Updated_Date DATETIME DEFAULT GETDATE()

* **Bước 4:** Dùng công cụ SQL Server Import and Export Wizard (hoặc lệnh BULK INSERT) để nạp dữ liệu từ các file CSV ở Task 1 vào các bảng trong Airline_OLTP.

* **Bước 5 (Giả lập SCD Type 2):** Cố tình dùng lệnh UPDATE sửa thông tin của khoảng 5 chiếc máy bay trong bảng tb_Aircraft_Master (VD: Đổi Engine_Type từ Turbo-jet sang Turbo-fan) và SET Updated_Date = _Ngày của tuần 3_. (Mục đích để tuần 3 demo cho giảng viên xem SSIS bắt được sự thay đổi này như thế nào).

**Tiêu chí nghiệm thu (Definition of Done):**

* File script 01_Create_OLTP.sql được push lên thư mục Github của nhóm.

* DB Airline_OLTP đã có đầy đủ data, truy vấn SELECT TOP 1000 chạy tốt.

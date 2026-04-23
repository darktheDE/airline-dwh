### 3.5.1. Thiết lập Cơ chế Tải tăng dần (Incremental Load & CDC) cho Fact_Flight_Transaction

[Đoạn giới thiệu về ý nghĩa và mục đích của việc thiết lập Incremental Load. Lưu ý rằng bảng Fact_Flight_Transaction có lượng dữ liệu giao dịch khổng lồ phát sinh mỗi ngày, nếu sử dụng Full Load (xóa toàn bộ và tải lại từ đầu) sẽ gây quá tải và sập hệ thống. Do vậy, ta cần xây dựng cơ chế Watermark để hệ thống "nhớ" được mốc thời gian load cuối cùng và chỉ truy xuất những dòng dữ liệu mới hoặc vừa được cập nhật kể từ mốc thời gian đó.]

Quá trình cấu hình cơ chế Incremental Load dựa trên bảng Watermark được thực hiện step-by-step như sau: 

#### 1. Khởi tạo bảng Control dưới Database (SQL Server)
![Hình: Chạy Script tạo bảng ETL_Watermark](URL_MOCKUP_CHO_HINH_B_1)

* **Ngữ cảnh cấu hình:** Tại Database OLAP (`AirlineDWH`), ta tiến hành chạy script SQL để tạo bảng `ETL_Watermark`. Bảng này đóng vai trò như một "nhật ký" lưu trữ thông tin với các cột chính là `TableName` (Tên bảng Fact), `Last_Load_Time` (Mốc thời gian lấy dữ liệu cuối cùng), và `Last_Updated`. Ta sẽ khởi tạo dòng dữ liệu đầu tiên cho `Fact_Flight_Transaction` với giá trị mốc ban đầu là `1900-01-01` (để trong lần chạy đầu tiên, gói ETL sẽ tự động tải toàn bộ hệ thống).

#### 2. Khai báo Biến trong SSIS (Variables)
![Hình: Cấu hình Variable User::LastLoadDate trong Visual Studio](URL_MOCKUP_CHO_HINH_B_2)

* **Ngữ cảnh cấu hình:** Trong Package SSIS, mở cửa sổ **Variables** và tạo một biến mới có tên là `User::LastLoadDate` với Data Type là `DateTime`. Biến này sẽ đóng vai trò như một thùng chứa trung gian trên RAM để nhận giá trị ngày tháng từ bảng `ETL_Watermark` dưới Database, sau đó truyền vào câu lệnh SELECT trích xuất dữ liệu.

#### 3. Trích xuất mốc thời gian (Get Watermark - Control Flow)
![Hình: Cấu hình Execute SQL Task Get Watermark](URL_MOCKUP_CHO_HINH_B_3)
![Hình: Cấu hình Result Set của SQL Task](URL_MOCKUP_CHO_HINH_B_4)

* **Ngữ cảnh cấu hình:** Tại màn hình Control Flow, kéo thả component **Execute SQL Task** (đặt tên là `SQL - Get LastLoadDate`) và cấu hình:
    * **SQL Statement:** `SELECT Last_Load_Time FROM ETL_Watermark WHERE TableName = 'Fact_Flight_Transaction'`
    * **Result Set:** Chuyển sang `Single row`.
    * Qua tab **Result Set**, map cột Index `0` vào biến `User::LastLoadDate`. Bước này giúp gán thời điểm ETL của lần chạy rạng sáng hôm qua (ví dụ) vào bộ nhớ.

#### 4. Truyền tham số lọc dữ liệu Nguồn (Data Flow)
![Hình: Cấu hình Parameters cho OLE DB Source](URL_MOCKUP_CHO_HINH_B_5)

* **Ngữ cảnh cấu hình:** Đi vào Data Flow Task, tại component **OLE DB Source** (Nguồn OLTP), chuyển chế độ Data access mode sang `SQL command`. Trong câu truy vấn, ta thêm mệnh đề `WHERE Updated_Date > ?`. Dấu `?` ở đây đại diện cho tham số động. Nhấn vào nút **Parameters...** và map Parameter `0` với biến `User::LastLoadDate` đã lấy ở bước trên. Chỉ những records mới bị thay đổi hoặc insert mới được đưa vào luồng trích xuất.

#### 5. Cập nhật lại Watermark sau khi Load xong (Update Watermark - Control Flow)
![Hình: Cấu hình Execute SQL Task Update Watermark](URL_MOCKUP_CHO_HINH_B_6)

* **Ngữ cảnh cấu hình:** Rất quan trọng, sau khi Data Flow Task chạy xong và ghi dữ liệu thành công vào bảng Fact, ta đặt tiếp một **Execute SQL Task** (`SQL - Update Watermark`). Lệnh update sẽ SET `Last_Load_Time` bằng với `MAX(Updated_Date)` đọc từ dữ liệu OLTP nguồn của đợt này. Lệnh này đóng sổ đợt load hiện tại và chốt mốc thời gian an toàn cho lượt ETL của ngày hôm sau.

---

### Một số lỗi thường gặp & Cách giải quyết

**1. Lỗi Type Mismatch khi truyền tham số "?" vào OLE DB Source**
* **Nguyên nhân:** Kiểu dữ liệu của biến `User::LastLoadDate` (DateTime) trong SSIS đôi khi không khớp với kiểu string hoặc datetime2 khi truyền parameter thông qua driver OLE DB. 
* **Cách giải quyết:** Đảm bảo kiểu dữ liệu biến khai báo trong SSIS là `DateTime`. Nếu vẫn lỗi, thử dùng kỹ thuật Explicit Cast ngay trong câu lệnh SQL `WHERE Updated_Date > CAST(? AS DATETIME)`.

**2. Lỗi quá trình load Fact bị fail nhưng Watermark vẫn được cập nhật (Data Inconsistency)**
* **Nguyên nhân:** Nếu bạn nối **Update Watermark** trực tiếp sau **Data Flow** bằng mũi tên xanh mà không dùng Transaction, giả sử Data Flow bị lỗi ở giữa chừng (một phần đã vào Fact, một phần chưa), việc không cập nhật Watermark có thể khiến lần chạy sau bị duplicate dữ liệu đã ghi rồi, hoặc nếu lỡ cập nhật Watermark sẽ khiến mất mát dòng lỗi.
* **Cách giải quyết:** Cấu hình thuộc tính `TransactionOption` của Package thành `Required` để đưa toàn bộ quá trình Get - Load - Update vào 1 giao dịch. Nếu fail, hệ thống sẽ Rollback cả Fact lẫn Watermark.

**3. Khởi tạo mốc Data kiểu NULL làm SQL Task báo lỗi**
* **Nguyên nhân:** Nếu lúc setup ban đầu trong Database bạn gán `Last_Load_Time` là `NULL`, khi SSIS đọc lên (Get Watermark) sẽ không map được vào biến kiểu `DateTime` (do biến SSIS cấm gán NULL cho kiểu dữ liệu gốc).
* **Cách giải quyết:** Bắt buộc phải mồi dữ liệu (Seed data) cho bảng Watermark bằng một ngày cực bé (như `1900-01-01`). Như vậy lần chạy đầu lệnh so sánh `Updated_Date > '1900-01-01'` vẫn trích xuất ra toàn bộ (Full load tự nhiên), mà SSIS lại không bị vướng lỗi Type Cast.

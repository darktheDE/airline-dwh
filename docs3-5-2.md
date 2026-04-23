### 3.5.2. Luồng xử lý Fact_Flight_Transaction (Sử dụng Lookup map Surrogate Key)

[Đoạn giới thiệu về ý nghĩa và mục đích của package Load_Fact_Flight_Transaction. Cụ thể có thể đề cập đến việc đây là bảng Fact chính ghi nhận từng giao dịch chuyến bay với khối lượng dữ liệu lớn, do vậy cần thiết kế cơ chế Incremental Load lấy dữ liệu theo lần chạy gần nhất để tối ưu hiệu suất, đồng thời sử dụng cơ chế Lookup để thay thế Business Key (Mã sân bay, Tail number...) bằng Surrogate Key trước khi lưu vào Data Warehouse...]

Sau khi thiết lập các biến (như `LastLoadDate`), cấu hình luồng xử lý SSIS này được thực hiện step-by-step như sau: 

#### 1. Lấy mốc thời gian (Get Watermark) - Control Flow
![Hình: Execute SQL Task Get Watermark](URL_MOCKUP_CHO_HINH_A_1)

* **Ngữ cảnh cấu hình:** Sử dụng **Execute SQL Task** (`SQL - Get LastLoadDate`) kết nối với Database `AirlineDWH` để truy xuất giá trị `Last_Load_Time` từ bảng `ETL_Watermark` (với điều kiện `TableName = 'Fact_Flight_Transaction'`). Kết quả trả về (Single row) được gán vào biến `User::LastLoadDate`. Việc này giúp hệ thống biết được lần lấy dữ liệu gần nhất là khi nào.

#### 2. Trích xuất dữ liệu (Data Flow)
![Hình: Cấu hình OLE DB Source SRC - Flights Incremental](URL_MOCKUP_CHO_HINH_A_2)

* **Ngữ cảnh cấu hình:** Trong Data Flow, **OLE DB Source** (`SRC - Flights Incremental`) được cấu hình bằng `SQL command`. Câu query sẽ đọc từ bảng `tb_Flights` của hệ thống OLTP để lấy các chuyến bay có `Updated_Date > ?` (Tham số `?` map vào biến `User::LastLoadDate`). Ngoài ra SQL command còn thực hiện Cast một số cột cơ bản như tạo `FL_DATE` định dạng chuẩn và nối chuỗi cho mã chuyến bay (`BKFlightID`).

#### 3. Xử lý giá trị NULL (Derived Column)
![Hình: Cấu hình Derived Column Replace NULLs](URL_MOCKUP_CHO_HINH_A_3)

* **Ngữ cảnh cấu hình:** Kéo component **Derived Column** (`DC - Replace NULLs`) để tiền xử lý. Source data có thể chứa nhiều giá trị `NULL` cho các trường thời gian bị hoãn (như `Arrival_Delay`, `Weather_Delay`, `Departure_Delay`...). Ta sử dụng hàm `REPLACENULL(<Cột>, 0)` để đổi những gía trị này về `0` cho an toàn (các trường này trong DB đích giới hạn NOT NULL).

#### 4. Thêm Metrics và Business Logic (Derived Column)
![Hình: Cấu hình Derived Column Business Logic metrics](URL_MOCKUP_CHO_HINH_A_4)

* **Ngữ cảnh cấu hình:** Ở component **Derived Column** tiếp theo (`DC - Metrics`), ta tích hợp các công thức chuyên sâu hơn. Ví dụ tính tổn thất kinh tế nếu chuyến bị Delay hoặc Hủy (`Estimated_Financial_Loss_USD`), cờ trễ chuyến (`Is_Delayed`), và đặc biệt là convert dữ liệu giờ/ngày thành dạng số Int (`DateKey`, `DepTimeKey`, `ArrTimeKey`) để tiện map sau này.

#### 5. Tra cứu Dimension lấy Surrogate Key (Lookups)
![Hình: Cấu hình Lookup map Surrogate Key tổng quan](URL_MOCKUP_CHO_HINH_A_5)
![Hình: Cấu hình Lookup SCD Type 2 cho Aircraft](URL_MOCKUP_CHO_HINH_A_6)

* **Ngữ cảnh cấu hình:** Các bước Lookup được thực hiện tuần tự để đối chiếu Business Key của Fact trong các Dimension tương ứng:
    * **LKP Origin/Dest Airport & Airline:** Cấu hình map cột mã của Source (VD `Origin_Airport`) vào `BKAirportCode` của bảng Dimension để lấy ra khóa Surrogate `OriginAirportKey`, `DestAirportKey`, `AirlineKey`.
    * **LKP Aircraft (Dimension có chứa SCD Type 2):** Vì dòng đời mỗi máy bay thay đổi liên tục, thay vì map toàn bộ dữ liệu Lookup, ta cấu hình Use `SQL query` lọc với mệnh đề `WHERE Is_Active = 1`. Qua đó chỉ lấy Version đang hoạt động duy nhất của `BKTailNumber` (Tail_Number) rồi lấy ra mã `AircraftKey`.

#### 6. Ghi dữ liệu vào DWH (OLE DB Destination)
![Hình: Cấu hình OLE DB Destination Fact_Flight_Transaction](URL_MOCKUP_CHO_HINH_A_7)

* **Ngữ cảnh cấu hình:** Sau khi đã đủ các khoá thay thế (Surrogate keys) và metrics, dữ liệu được đưa vào component **OLE DB Destination**, mapping đích đúng cấu trúc các trường bảng `Fact_Flight_Transaction`. Ở đây kiểm tra kỹ các mapping của Lookup Output cho hợp lệ.

#### 7. Cập nhật lại Watermark (Control Flow)
![Hình: Cấu hình Execute SQL Task Update Watermark](URL_MOCKUP_CHO_HINH_A_8)

* **Ngữ cảnh cấu hình:** Sau khi Data Flow hoàn tất đổ dữ liệu thành công, một **Execute SQL Task** (`SQL - Update Watermark`) được chạy để `UPDATE` lại bảng `ETL_Watermark`. Cụ thể gán `Last_Load_Time` bằng `MAX(Updated_Date)` từ bảng Source `tb_Flights`, thiết lập mốc thời gian an toàn cho lượt xử lý Incremental kế tiếp.

---

### Một số lỗi thường gặp & Cách giải quyết

Trong quá trình triển khai cấu hình package Fact với các thao tác Lookup, một số lỗi khá phổ biến sẽ được ghi nhận và có thể xử lý như sau:

**1. Lỗi Constraint do giá trị NULL (Ví dụ: The value violated the integrity constraints)**
* **Nguyên nhân:** Bảng Fact trên DataWarehouse thường ràng buộc Data Type rất khắt khe (VD sử dụng NOT NULL) để đảm bảo tính toàn vẹn. Nhất là với dữ liệu hàng không, Source thường trả `NULL` ở các cột `Departure_Delay`, `Arrival_Time` nếu chuyến bay đó bị Hủy sớm.
* **Cách giải quyết:** Bắt buộc chèn bước **Derived Column** sớm từ đầu flow để thay thế rủi ro. Sử dụng hàm `REPLACENULL([Cột], 0)` hoặc dùng toán tử 3 ngôi gán giá trị mặc định tránh lỗi trước khi đẩy xuống Lookup và insert Fact.

**2. Lỗi Duplicate Key liên quan đến các lookup mang tính SCD Type 2 (Dimension thay đổi theo thời gian)**
* **Nguyên nhân:** Khi lookup lấy khóa `AircraftKey` bằng Tail_Number trên bảng `Dim_Aircraft` nhưng 1 đuôi máy bay có nhiều phiên bản (SCD Type 2), dẫn đến kết quả trả về của Lookup Task nhiều hơn 1 bản ghi và SSIS báo lỗi vi phạm dòng Single Row Mapping của Lookup.
* **Cách giải quyết:** Thay vì load nguyên Table trong Lookup Task, chọn **Write a query to specify the data** và bổ sung thêm điều kiện lọc: `WHERE Is_Active = 1` (hoặc điều kiện lọc RowEffectiveDate hợp lệ) để lấy duy nhất 1 Surrogate Key hiện tại trong thời gian ghi log chuyến bay. Mặc dù là cách hardcode (không thuần historic lookup point-in-time) nhưng giúp tránh lỗi triệt để trong mô hình hiện hành.

**3. Lỗi Lookup No Match Output (Không tìm ra key dẫn đến fail cả dòng)**
* **Nguyên nhân:** Xảy ra hiện tượng "Late Arriving Dimension" - tức là dữ liệu giao dịch Fact trích ra đã xuất hiện mã nghiệp vụ (`Business Key`) chưa từng có trên bảng Dimension nên không sinh ra được Surrogate Key tương ứng.
* **Cách giải quyết:** Tùy thuộc vào chiến lược xử lý ETL của dự án, người thiết kế có thể cấu hình **Lookup Error Output**: 
  - Chọn `Redirect rows to error output` chuyển dữ liệu lỗi ra bảng trung gian (Table Error) ghi nhận xem sau.
  - Hoặc chọn `Ignore failure` để ép dòng đó chạy qua và sử dụng các xử lý như **Derived Column** kế tiếp để kiểm tra nếu NULL `SurrogateKey` thì gán tạm `-1` / `-2` (Unknown Key) để insert vào bằng mọi giá giữ nguyên bản Fact.

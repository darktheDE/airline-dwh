### 3.1.9. Luồng xử lý Fact_Aircraft_Daily_Snapshot (Sử dụng Aggregate tối ưu hiệu năng)

[Đoạn giới thiệu về ý nghĩa và mục đích của package Load_Fact_Aircraft_Daily. Đây là luồng ETL nạp dữ liệu cho bảng sự kiện dạng Periodic Snapshot (Tích lũy định kỳ), nhằm theo dõi hoạt động và sức khỏe của từng máy bay theo từng ngày. Việc tính toán tổng hợp (Aggregation) khối lượng lớn dữ liệu giao dịch chuyến bay đòi hỏi giải pháp tối ưu. Do đó, thay vì dùng component tính toán chậm chạp trên RAM của SSIS, kiến trúc sử dụng Execute SQL Task để gộp dữ liệu đẩy xuống vùng Staging trước, sau đó mới nạp vào thư mục Data Warehouse.]

Sau khi thiết lập các biến (như `LastLoadDate`), cấu hình luồng xử lý SSIS này được thực hiện step-by-step như sau: 

#### 1. Trích xuất và Tổng hợp dữ liệu vào Staging (Control Flow)
![Hình: Execute SQL Task Extract and Aggregate to Staging](URL_MOCKUP_CHO_HINH_C_1)

* **Ngữ cảnh cấu hình:** Sử dụng **Execute SQL Task** (`Extract and Aggregate to Staging`) thực thi lệnh SQL trực tiếp trên hệ thống nguồn để trích xuất và gom nhóm. Câu truy vấn này kết hợp việc lọc dữ liệu mới (Incremental) thông qua điều kiện lọc ngày cập nhật lớn hơn biến `User::LastLoadDate` đã lấy ở bước Get Watermark, đồng thời sử dụng lệnh `GROUP BY` theo máy bay và ngày bay kết hợp các hàm `SUM()`, `COUNT()` để tổng đếm các độ đo. Dữ liệu sau khi tổng kết sẽ được lưu thẳng vào cấu trúc vùng `Airline_Staging` (bảng tạm). Trọng điểm của giải pháp này là mượn hoàn toàn sức mạnh xử lý của Database Engine, khắc phục yếu điểm tràn bộ nhớ Memory của SSIS thao tác với khối lượng lớn.

#### 2. Trích xuất dữ liệu từ Staging (Data Flow)
![Hình: Cấu hình OLE DB Source trong Data Flow Task](URL_MOCKUP_CHO_HINH_C_2)

* **Ngữ cảnh cấu hình:** Bước vào **Data Flow Task**, component **OLE DB Source** được thiết lập kết nối đến luồng dữ liệu đã được gom nhóm cô đọng, dọn dẹp sẵn tại vùng `Airline_Staging`. Vì mọi logic tính toán nặng nề đã được thực hiện ở Control Flow trước đó nên lúc này luồng Data Flow rất nhẹ, chỉ làm nhiệm vụ nạp và gán thêm khóa Dimension.

#### 3. Tra cứu Dimension lấy Surrogate Key (Lookups)
![Hình: Cấu hình Lookup Dim_Date và Dim_Airline](URL_MOCKUP_CHO_HINH_C_3)

* **Ngữ cảnh cấu hình:** Lần lượt thiết lập các component **Lookup** để bổ sung Surrogate Key còn thiếu cho Fact (Bản thân AircraftKey có thể đã được join ngay từ bước Staging hoặc map thêm nếu cần thiết):
    * **Lookup - Dim_Date:** Nhận luồng dữ liệu chứa trường ngày bay (`Flight_Date`), đi vào dò tìm tương ứng trong bảng `Dim_Date` và trích xuất khóa đại diện `DateKey`.
    * **Lookup - Dim_Airline:** Dò ID hoặc mã của Hãng hàng không chuyên trách máy bay trong bảng `Dim_Airline` thông qua bộ mapping để lấy ra `AirlineKey`.

#### 4. Ghi dữ liệu vào DWH (OLE DB Destination)
![Hình: Cấu hình OLE DB Destination Fact_Aircraft_Daily_Snapshot](URL_MOCKUP_CHO_HINH_C_4)

* **Ngữ cảnh cấu hình:** Cuối cùng, component **OLE DB Destination** nhận luồng dữ liệu đã đầy đủ Surrogate Keys và Mapping tải vào bảng đích `Fact_Aircraft_Daily_Snapshot` thuộc cở sở dữ liệu `AirlineDWH`. Cần rà soát kỹ thẻ Mappings để đảm bảo các khóa Dimension và các Measures (Khối lượng bay, Thời gian trễ tích lũy...) khớp 100% với schema đích định dạng từ đầu.

#### 5. Cập nhật lại Watermark (Control Flow)
![Hình: Cấu hình Execute SQL Task Update Watermark](URL_MOCKUP_CHO_HINH_C_5)

* **Ngữ cảnh cấu hình:** Sau khi quá trình `Data Flow Task` ghi fact thành công, mũi tên luồng điều khiển chuyển sang thực thi component **Execute SQL Task** (`SQL - Update Watermark`). Khối lệnh SQL này truy xuất và cập nhật lại biến thời điểm `Last_Load_Time` lớn nhất đợt này vào trong bảng `ETL_Watermark` ở mốc của chu trình `Fact_Aircraft_Daily_Snapshot` báo hiệu thành công quy trình Incremental đợt này.

---

### Một số lỗi thường gặp & Cách giải quyết

**1. Lỗi tràn kiểu dữ liệu khi gom nhóm các Measures**
* **Nguyên nhân:** Khi tính tổng các số phút bay hoặc độ trễ từ rất nhiều chuyến bay cộng dồn cho 1 chiếc tàu bay trong 1 ngày, giá trị sum có thể vượt quá giới hạn lưu trữ của kiểu `SMALLINT` ở thiết kế DWH đích ban đầu, gây lỗi Arithmetic Overflow Data.
* **Cách giải quyết:** Nâng cấp cấu trúc Schema Data Type của các cột độ đo trên bảng Fact ở SQL Server từ mốc `SMALLINT` sang `INT`. Đồng thời phải vào lại component `OLE DB Destination` để Update Metadata đảm bảo luồng Data Flow SSIS tải lại kích thước mới.

**2. Lỗi Duplicate Key do thao tác gom nhóm (Aggregate) sai khóa**
* **Nguyên nhân:** Table Fact Snapshot định kỳ yêu cầu tính độc nhất: 1 Máy bay trong 1 Ngày chỉ có 1 dòng duy nhất (Định danh bởi Primary Key là tổ hợp AircraftKey + DateKey). Nếu câu lệnh Group By bỏ sót thuộc tính gom nhóm, sẽ sinh trùng lặp khóa chính cho cùng 1 máy bay trong 1 ngày, vi phạm Primary Key Constraints.
* **Cách giải quyết:** Bám sát cấu trúc của câu lệnh Query trong bước cấu hình `Extract and Aggregate to Staging`. Yêu cầu bắt buộc mọi cột không phải Measure/Aggregate đều phải thiết thuật cẩn thận làm thông số phân mảnh vào mệnh đề `GROUP BY` đảm bảo độ phân giải (grain) chuẩn là Daily Snapshot theo từng Máy bay.

## CHƯƠNG 4: KHAI THÁC DỮ LIỆU – SSAS CUBE VÀ TRUY VẤN SQL

Sau khi hoàn thành việc xây dựng và chuẩn hóa Kho dữ liệu tại tầng vật lý, bước tiếp theo trong quy trình kiến trúc là thiết lập tầng ngữ nghĩa (Semantic Layer) thông qua công cụ SQL Server Analysis Services (SSAS). Việc xây dựng cấu trúc đa chiều (Cube) đóng vai trò then chốt trong việc trừu tượng hóa các bảng dữ liệu vật lý phức tạp thành các thực thể đo lường (Measures) và các chiều phân tích (Dimensions) có tính chất định hướng nghiệp vụ cao. Tầng trung gian này không chỉ giúp tối ưu hóa hiệu năng truy vấn trên các tập dữ liệu hàng không quy mô lớn mà còn cung cấp một giao diện thân thiện, cho phép người dùng cuối tiếp cận dữ liệu một cách nhất quán mà không cần am hiểu sâu về cấu trúc SQL cơ sở. Sau khi Cube được triển khai thành công, các truy vấn SQL được sử dụng để xác minh và khai thác trực tiếp bốn insight chiến lược nhằm trả lời các bài toán kinh doanh cốt lõi của dự án.

### 4.1. Xây dựng Analysis Services Project (SSAS)

Việc khởi tạo dự án Analysis Services là giai đoạn chuyển đổi các mô hình dữ liệu quan hệ sang mô hình dữ liệu đa chiều, tạo tiền đề cho các phân tích OLAP chuyên sâu. Quy trình này tập trung vào việc định nghĩa các mối quan hệ logic và tối ưu hóa cấu trúc lưu trữ để đáp ứng các yêu cầu báo cáo đa chiều từ cấp độ vận hành đến cấp độ chiến lược của hãng hàng không.

#### 4.1.1. Khởi tạo Data Source View (DSV)

Data Source View đóng vai trò là lớp ánh xạ logic quan trọng, kết nối trực tiếp giữa kho dữ liệu SQL Server vật lý và mô hình đa chiều trong môi trường SSAS. Trong giai đoạn này, hệ thống thực hiện đưa vào DSV toàn bộ năm bảng chiều – bao gồm ngày (Dim_Date), giờ (Dim_Time), sân bay (Dim_Airport), hãng hàng không (Dim_Airline), tàu bay (Dim_Aircraft) – cùng với ba bảng sự kiện trọng tâm là Fact_Flight_Transaction, Fact_Aircraft_Daily_Snapshot và Fact_Turnaround_Efficiency đã được thiết lập ở các chương trước. Việc tái lập các mối quan hệ Star Schema thông qua hệ thống khóa ngoại là bước bắt buộc để đảm bảo tính liên kết dữ liệu xuyên suốt trong không gian đa chiều.

Một điểm nhấn kỹ thuật đặc biệt trong thiết kế DSV cho bài toán hàng không là việc áp dụng kỹ thuật **Role-playing Dimensions**. Do bảng Fact_Flight_Transaction chứa đồng thời cả thông tin về sân bay khởi hành (OriginAirportKey) và sân bay đích (DestAirportKey), việc sử dụng vai trò kép cho phép một bảng vật lý duy nhất là Dim_Airport đóng hai vai trò phân tích khác nhau trong cùng một Cube. Cơ chế này cung cấp khả năng phân tích độc lập lưu lượng đi và đến tại từng cảng hàng không mà không cần nhân bản dữ liệu, từ đó đảm bảo tính nhất quán và tối ưu hóa không gian lưu trữ cho hệ thống.

*[Hình 4.1: Giao diện Data Source View trong SSAS – toàn bộ 8 bảng (5 Dim + 3 Fact) với các mối quan hệ khóa ngoại được tái lập]*

*[Hình 4.2: Chi tiết Dim_Date – phân cấp Year → Quarter → Month → Day]*

*[Hình 4.3: Chi tiết Dim_Airport – phân cấp State → City → Airport_Code]*

*[Hình 4.4: Chi tiết Dim_Airline – thuộc tính AirlineCode, AirlineName]*

*[Hình 4.5: Chi tiết Dim_Aircraft – thuộc tính TailNumber, Manufacturer, EngineType, SCD Type 2)*

*[Hình 4.6: Chi tiết Dim_Time – phân cấp Time_Period → Hour → Minute]*

#### 4.1.2. Thiết lập Data Cube và Cấu hình Hierarchies

Đây được coi là giai đoạn định nghĩa các thành phần cốt lõi của hệ thống phân tích, nơi các quy tắc nghiệp vụ được cụ thể hóa thành các chỉ số định lượng. Hệ thống thực hiện phân tách các độ đo thành các nhóm (Measure Groups) tương ứng với ba bảng sự kiện chuyên biệt để quản lý một cách khoa học. Các hàm tập hợp (Aggregation Functions) được áp dụng linh hoạt tùy theo bản chất của từng chỉ số: tính tổng (SUM) cho các cột delay và financial loss, tính đếm (COUNT) cho số lượng chuyến bay, và tính trung bình (AVERAGE) cho thời gian quay đầu.

Song song với việc thiết lập các độ đo, công tác tối ưu hóa các phân cấp (Hierarchies) trong từng chiều dữ liệu đóng vai trò quyết định đến hiệu năng của hệ thống. Bằng cách thiết lập các mối quan hệ thuộc tính (Attribute Relationships) theo trình tự logic như từ ngày đến tháng, quý và năm, bộ máy SSAS có khả năng thực hiện các phép tiền tính toán (Pre-aggregation) dữ liệu một cách hiệu quả. Điều này giúp các thao tác khoan sâu dữ liệu (Drill-down) từ bức tranh tổng thể xuống chi tiết diễn ra gần như tức thì, ngay cả trên tập dữ liệu gần 6 triệu bản ghi chuyến bay.

*[Hình 4.7: Giao diện Cube Designer trong SSAS – hiển thị 3 Measure Groups và các Dimensions được kết nối]*

#### 4.1.3. Triển khai và Xử lý (Deploy & Process)

Sau khi hoàn tất giai đoạn thiết kế và cấu hình chi tiết, Cube được triển khai lên máy chủ thực thi (Server: `KIENHUNG`, Database: `Airline_Cube_Project`) để bắt đầu quy trình xử lý dữ liệu (Process Full). Trong giai đoạn này, hệ thống thực hiện đổ dữ liệu từ các bảng vật lý vào các cấu trúc đa chiều và kích hoạt các thuật toán tính toán sẵn cho các chỉ số tích lũy dựa trên các phân cấp đã định nghĩa. Để đảm bảo tính tươi mới của thông tin phân tích, một kế hoạch bảo trì và xử lý Cube định kỳ đã được thiết lập nhằm kích hoạt quy trình xử lý ngay sau khi các gói Master ETL hoàn thành việc nạp dữ liệu vào kho. Sự phối hợp nhịp nhàng giữa quy trình tích hợp dữ liệu và quy trình xử lý đa chiều đảm bảo rằng các báo cáo quản trị và Dashboard luôn phản ánh tình trạng vận hành mới nhất của đội tàu bay và mạng lưới sân bay.

---

### 4.2. Truy vấn SQL giải quyết Bài toán Kinh doanh

Sau khi SSAS Cube được triển khai thành công và Power BI thiết lập kết nối Live Connection, các truy vấn SQL được sử dụng song song để xác minh tính đúng đắn của dữ liệu và khai thác chi tiết bốn insight chiến lược trực tiếp từ các bảng Kho dữ liệu. Phương pháp này vừa đảm bảo tính minh bạch, kiểm chứng được kết quả thể hiện trên Dashboard, vừa cung cấp nền tảng kỹ thuật cho các phân tích đặc thù không được cấu hình sẵn trong Cube. Mỗi truy vấn được thiết kế để trả lời một câu hỏi kinh doanh cụ thể, sử dụng phép JOIN đa bảng giữa các Fact Table và Dimension Table theo mô hình Star Schema đã định nghĩa.

#### 4.2.1. Insight 1 – Financial Loss & Delay by State (Fact_Flight_Transaction)

**Câu hỏi kinh doanh:** *"Bang nào chịu thiệt hại tài chính và tổng thời gian chậm trễ đến (Arrival Delay) lớn nhất?"*

Truy vấn này thực hiện tổng hợp hai chỉ số thiệt hại trọng yếu – ước tính thiệt hại tài chính quy đổi ra USD và tổng số phút delay đến – theo đơn vị hành chính cấp bang tại sân bay đích. Bằng cách JOIN bảng Fact_Flight_Transaction với chiều Dim_Airport theo khóa DestAirportKey, hệ thống xác định được vị trí địa lý của các chuyến bay bị ảnh hưởng nhiều nhất. Kết quả cho phép Ban quản trị ưu tiên nguồn lực cải thiện tại các tiểu bang có mức thiệt hại kinh tế cao nhất, đồng thời cung cấp cơ sở đàm phán với các hãng hàng không về cam kết chất lượng dịch vụ.

```sql
SELECT TOP 10
    da.State,
    SUM(f.Estimated_Financial_Loss_USD) AS TotalLoss,
    SUM(f.Arr_Delay_Mins)               AS TotalArrDelay
FROM Fact_Flight_Transaction f
JOIN Dim_Airport da ON f.DestAirportKey = da.AirportKey
GROUP BY da.State
ORDER BY TotalLoss DESC;
```

*[Hình 4.8: Kết quả thực thi SQL Insight 1 – Top 10 bang có tổng thiệt hại tài chính lớn nhất; CA dẫn đầu với $174.89M, tiếp theo TX ($150.65M), IL ($112.80M)]*

**Nhận xét:** California (CA) và Texas (TX) dẫn đầu với mức thiệt hại vượt 100 triệu USD, phản ánh mật độ chuyến bay cực cao tại các trung tâm hàng không lớn như LAX (Los Angeles) và DFW (Dallas). Tổng phút delay tỷ lệ thuận với thiệt hại tài chính, xác nhận độ đo `Estimated_Financial_Loss_USD` được tính toán hợp lệ trong pipeline ETL.

---

#### 4.2.2. Insight 2 – Delay Root Cause Breakdown by Airline (Fact_Flight_Transaction)

**Câu hỏi kinh doanh:** *"Nguyên nhân chậm trễ chính (thời tiết, lỗi hãng, hệ thống NAS, tàu bay đến muộn) của từng hãng hàng không là gì?"*

Truy vấn này phân tách tổng thời gian delay của mỗi hãng thành bốn nhóm nguyên nhân đặc thù: Weather Delay (thời tiết – nằm ngoài tầm kiểm soát hãng), Carrier Delay (lỗi vận hành nội bộ – có thể cải thiện), NAS Delay (do hệ thống kiểm soát không lưu), và Late Aircraft Delay (tàu bay từ chặng trước đến muộn). Điều kiện lọc `WHERE f.Is_Delayed = 1` chỉ xét các chuyến bay thực sự bị trễ (≥ 15 phút theo tiêu chuẩn FAA), loại bỏ nhiễu từ các chuyến bay đúng giờ. Kết quả là cơ sở để phân biệt hãng nào đang gặp vấn đề hệ thống nội bộ (Carrier Delay cao) so với hãng chịu ảnh hưởng chủ yếu từ yếu tố bên ngoài.

```sql
SELECT
    dl.AirlineName,
    SUM(f.Weather_Delay_Mins)      AS Weather,
    SUM(f.Carrier_Delay_Mins)      AS Carrier,
    SUM(f.NAS_Delay_Mins)          AS NAS,
    SUM(f.LateAircraft_Delay_Mins) AS LateAircraft
FROM Fact_Flight_Transaction f
JOIN Dim_Airline dl ON f.AirlineKey = dl.AirlineKey
WHERE f.Is_Delayed = 1
GROUP BY dl.AirlineName
ORDER BY Carrier DESC;
```

*[Hình 4.9: Kết quả thực thi SQL Insight 2 – Phân tách 4 loại delay theo từng hãng; Southwest Airlines và Delta Airlines có tổng Late Aircraft Delay cao nhất (>3M phút)]*

**Nhận xét:** Southwest Airlines Co. có Late Aircraft Delay Mins cao nhất (~3.16M phút), cho thấy mô hình khai thác point-to-point dày đặc khiến sự cố trên một chặng bay lan truyền hiệu ứng domino mạnh. Ngược lại, Hawaiian Airlines Inc. có tổng delay thấp nhất do tần suất chuyến bay trong mạng nội địa Hawaii ít hơn đáng kể.

---

#### 4.2.3. Insight 3 – Monthly Fleet Activity & Delay Trend (Fact_Aircraft_Daily_Snapshot)

**Câu hỏi kinh doanh:** *"Xu hướng lượng chuyến bay và tổng phút delay của đội tàu bay biến động thế nào qua các tháng trong năm 2015?"*

Truy vấn này khai thác bảng Fact_Aircraft_Daily_Snapshot – bảng sự kiện dạng Periodic Snapshot – để phân tích hành vi của đội tàu bay ở cấp độ tổng hợp theo tháng. Bằng cách JOIN với chiều Dim_Date và nhóm theo tháng, hệ thống tạo ra góc nhìn về xu hướng theo mùa của toàn bộ đội tàu. Lưu ý quan trọng về ngữ cảnh kỹ thuật: do cơ chế tra cứu AircraftKey trong SSIS gặp giới hạn với dữ liệu nguồn, phân tích được thực hiện theo chiều Date để đảm bảo tính toàn vẹn kết quả.

```sql
SELECT
    dd.CalendarYear,
    dd.MonthName,
    SUM(f.Daily_Flight_Count)       AS TotalFlights,
    SUM(f.Daily_Delay_Mins_Total)   AS TotalDelayMins
FROM Fact_Aircraft_Daily_Snapshot f
JOIN Dim_Date dd ON f.DateKey = dd.DateKey
GROUP BY dd.CalendarYear, dd.MonthNumber, dd.MonthName
ORDER BY dd.MonthNumber;
```

*[Hình 4.10: Kết quả thực thi SQL Insight 3 – Tổng số ngày bay và tổng phút delay theo tháng; June đạt đỉnh tổng delay (2,296,333 phút) trong khi October có tổng delay thấp nhất (1,206,011 phút)]*

**Nhận xét:** Biểu đồ cho thấy tháng 6 (June) có tổng phút delay cao nhất (~2.3M phút) tương ứng với cao điểm du lịch mùa hè, trong khi tháng 10 (October) là tháng vận hành hiệu quả nhất với tổng delay thấp nhất (~1.2M phút). Số ngày bay (Daily Flight Count) tương đối ổn định quanh 30-31 ngày/tháng, cho thấy biến động chủ yếu đến từ điều kiện khai thác chứ không phải tần suất bay.

---

#### 4.2.4. Insight 4 – Total Turnaround Delay by City (Fact_Turnaround_Efficiency)

**Câu hỏi kinh doanh:** *"Thành phố nào có tổng thời gian trễ quay đầu (Turnaround Variance) tích lũy lớn nhất, chỉ ra điểm nghẽn trong vận hành mặt đất?"*

Truy vấn này khai thác bảng Fact_Turnaround_Efficiency – bảng sự kiện dạng Accumulating Snapshot đặc thù nhất trong mô hình – để đo lường tổng khoảng thời gian chênh lệch giữa thời gian quay đầu thực tế và kế hoạch tại từng thành phố. Cột `Turnaround_Variance_Mins` được tính toán bởi hàm cửa sổ SQL `LAG()` trong giai đoạn Staging, phản ánh mức độ trễ lũy kế phát sinh khi tàu bay phải chờ quá lâu giữa chuyến đến và chuyến đi tiếp theo. Kết quả từ truy vấn này là nền tảng để bộ phận Ground Operations xác định các sân bay "nút thắt cổ chai" cần ưu tiên cải thiện quy trình phục vụ mặt đất.

```sql
SELECT TOP 10
    da.City,
    da.State,
    SUM(f.Turnaround_Variance_Mins) AS TotalDelayMins
FROM Fact_Turnaround_Efficiency f
JOIN Dim_Airport da ON f.AirportKey = da.AirportKey
GROUP BY da.City, da.State
ORDER BY TotalDelayMins DESC;
```

*[Hình 4.11: Kết quả thực thi SQL Insight 4 – Top 10 thành phố có tổng Turnaround Variance lớn nhất; Atlanta dẫn đầu (~910M phút), tiếp theo Chicago (~580M phút) và Dallas-Fort Worth (~568M phút)]*

**Nhận xét:** Atlanta (ATL) đứng đầu với tổng Turnaround Variance gần 910 triệu phút – kết quả trực tiếp từ việc đây là sân bay có lưu lượng chuyến bay nội địa cao nhất nước Mỹ năm 2015. Chicago và Dallas-Fort Worth cũng nằm trong nhóm Hub lớn, xác nhận rằng các trung tâm trung chuyển đông đúc chịu áp lực quay đầu tàu bay cao hơn nhiều so với các sân bay khu vực.

---


## CHƯƠNG 5: TRỰC QUAN HÓA DỮ LIỆU (EXECUTIVE DASHBOARD)

Sau khi tầng ngữ nghĩa SSAS Cube được triển khai và các truy vấn SQL xác minh tính đúng đắn của dữ liệu, giai đoạn cuối cùng của quy trình phân tích là xây dựng Executive Dashboard trên Power BI. Dashboard đóng vai trò là giao diện trực quan duy nhất mà Ban quản trị tương tác với toàn bộ hệ thống Kho dữ liệu, chuyển hóa hàng chục triệu dòng giao dịch thành bốn biểu đồ chiến lược có khả năng trả lời trực tiếp các câu hỏi kinh doanh cốt lõi về tổn thất tài chính, hiệu quả đội tàu và vận hành mặt đất.

### 5.1. Tổng quan Executive Dashboard

Dashboard được thiết kế theo **bố cục 2×2** (hai hàng, hai cột) trên Power BI Desktop, kết nối trực tiếp với SSAS Cube qua chế độ **Live Connection** đến Server `KIENHUNG`, Database `Airline_Cube_Project`. Cơ chế kết nối trực tiếp này đảm bảo Dashboard luôn phản ánh dữ liệu mới nhất sau mỗi chu kỳ ETL mà không cần import dữ liệu thủ công, đồng thời tận dụng toàn bộ khả năng tổng hợp sẵn của Cube để tăng tốc độ phản hồi truy vấn.

**Bố cục tổng thể:**

| Vị trí | Biểu đồ | Nguồn dữ liệu |
|---|---|---|
| Trên – Trái | **Financial Loss & Arr Delay by State** (Clustered Bar) | Fact_Flight_Transaction |
| Trên – Phải | **Monthly Fleet Activity – Flight Volume vs Total Delay** (Combo Chart) | Fact_Aircraft_Daily_Snapshot |
| Dưới – Trái | **Delay Root Cause Breakdown by Airline** (Stacked Bar) | Fact_Flight_Transaction |
| Dưới – Phải | **Turnaround Variance Mins by City** (Bar Chart) | Fact_Turnaround_Efficiency |

**Slicers (Bộ lọc thời gian):** Dashboard tích hợp hai bộ lọc liên kết với chiều Dim_Date – `Calendar Year` và `Month Name` – áp dụng đồng thời lên tất cả bốn biểu đồ. Người dùng có thể thu hẹp phạm vi phân tích xuống một quý hoặc một tháng cụ thể chỉ với một thao tác click, cung cấp tính linh hoạt cao trong các buổi họp điều hành.

*[Hình 5.1: Giao diện tổng thể Executive Dashboard trên Power BI – bố cục 2×2 với 4 biểu đồ chiến lược và bộ lọc thời gian]*

---

### 5.2. Phân tích Chuyên sâu (Data Insights)

#### 5.2.1. Insight 1 – Thiệt hại Tài chính và Tổng Delay theo Bang

**Loại biểu đồ:** Clustered Bar Chart (Biểu đồ thanh nhóm ngang)

**Thiết kế visual:** Trục Y hiển thị tên bang (State), trục X thể hiện đồng thời hai chỉ số trên cùng thang đo: `Estimated Financial Loss USD` (thanh màu xanh dương đậm) và `Arr Delay Mins` (thanh màu xanh dương nhạt). Hai chuỗi dữ liệu được đặt cạnh nhau cho từng bang, tạo ra khả năng so sánh trực quan giữa thiệt hại tài chính quy đổi và mức độ chậm trễ thực tế.

*[Hình 5.2: Chart 1 – Estimated Financial Loss USD and Arr Delay Mins by State; chi tiết dữ liệu trong bảng kèm theo]*

**Phân tích kết quả:**

Biểu đồ xác nhận rõ ràng mối tương quan gần như tuyến tính giữa tổng phút delay và ước tính thiệt hại tài chính trên toàn bộ các bang, phản ánh tính nhất quán của công thức tính `Estimated_Financial_Loss_USD` được thiết kế trong pipeline ETL. California (CA) dẫn đầu với **$174.89 triệu USD** thiệt hại và **2,073,243 phút** delay đến – tương đương gần 1.44 tỷ phút-hành-khách nếu tính bình quân 695 hành khách bị ảnh hưởng mỗi chuyến bay bị trễ. Texas (TX) đứng thứ hai với $150.65M, tiếp theo là Illinois (IL) với $112.80M.

**Insight kinh doanh cốt lõi:** Ba bang CA-TX-IL chiếm hơn **40% tổng thiệt hại tài chính** toàn quốc, tập trung tại các trung tâm Hub lớn là LAX/SFO (California), DFW/IAH (Texas) và ORD/MDW (Illinois). Đây là ưu tiên can thiệp số một cho Ban quản trị. Các bang Arizona (AZ), Virginia (VA) và Massachusetts (MA) có mức thiệt hại thấp hơn đáng kể ($24-32M), gợi ý rằng các sân bay nhỏ hơn tại các bang này vận hành hiệu quả hơn hoặc chịu ít áp lực chuyến bay hơn.

---

#### 5.2.2. Insight 2 – Hoạt động Đội tàu bay theo Tháng

**Loại biểu đồ:** Line and Stacked Column Chart (Biểu đồ kết hợp cột + đường)

**Thiết kế visual:** Trục X là tên tháng (Month Name) lấy từ chiều Dim_Date. Trục Y trái (cột màu xanh dương) hiển thị `Daily Flight Count` – số ngày có chuyến bay trong tháng, phản ánh mức độ hoạt động của đội tàu. Trục Y phải (đường màu tối) hiển thị `Daily Delay Mins Total` – tổng phút delay trong tháng. Sự kết hợp hai trục tạo ra khả năng quan sát cùng lúc khối lượng hoạt động và mức độ trễ tương ứng.

*[Hình 5.3: Chart 2 – Monthly Fleet Activity: Flight Volume vs Total Delay (2015); dữ liệu đầy đủ trong bảng chi tiết]*

**Phân tích kết quả:**

Biểu đồ số liệu thực từ bảng dữ liệu cho thấy xu hướng không đồng đều theo mùa rõ rệt trong năm 2015:

| Tháng | Ngày bay | Tổng Delay Mins |
|--------|----------|----------------|
| June | 30 | **2,296,333** (cao nhất) |
| July | 31 | 2,021,379 |
| December | 31 | 1,896,130 |
| October | 31 | **1,206,011** (thấp nhất) |
| February | 28 | 1,712,660 |

**Insight kinh doanh cốt lõi:** Đường delay (trục phải) không tỷ lệ thuận với cột số ngày bay (trục trái) – minh chứng rõ nhất là tháng 6 (30 ngày bay) có delay cao hơn tháng 7 (31 ngày bay). Điều này chứng tỏ **tần suất hoạt động không phải yếu tố quyết định** mức delay; thay vào đó, thời điểm cao điểm du lịch hè (June-July) và cuối năm (December) kéo delay tăng vọt. Tháng 10 là tháng vận hành tối ưu nhất trong năm, trùng với giai đoạn off-peak giữa hè và Thanksgiving – đây là tháng tham chiếu tốt nhất để đặt KPI chuẩn cho hệ thống.

---

#### 5.2.3. Insight 3 – Phân tích Nguyên nhân Chậm trễ theo Hãng

**Loại biểu đồ:** Stacked Bar Chart (Biểu đồ thanh xếp chồng ngang)

**Thiết kế visual:** Trục Y liệt kê tên hãng hàng không (Airline Name), trục X tổng số phút delay phân tách theo bốn nhóm màu: **Weather** (xanh lam nhạt), **Carrier** (xanh navy), **NAS** (cam), **Late Aircraft** (tím). Filter `Is Delayed = 1` được áp dụng để chỉ phân tích các chuyến bay thực sự bị trễ (theo chuẩn FAA ≥ 15 phút). Conditional Formatting được kích hoạt để làm nổi bật hãng có tổng delay cao nhất.

*[Hình 5.4: Chart 3 – Delay Root Cause Breakdown by Airline (Delayed Flights Only); chi tiết 4 loại delay trong bảng kèm theo]*

**Phân tích kết quả:**

| Hãng | Weather | Carrier | NAS | Late Aircraft | Tổng |
|---|---|---|---|---|---|
| Delta Air Lines | 334,607 | 1,412,487 | 1,017,769 | 1,158,761 | **3,923,624** |
| Southwest Airlines | 306,360 | 1,988,024 | 878,277 | 3,159,338 | **6,331,999** |
| United Air Lines | 295,507 | 1,902,599 | 1,293,210 | 2,369,445 | **5,860,761** |
| Skywest Airlines | 204,263 | 1,562,017 | 1,061,520 | 2,221,192 | **5,048,992** |

**Insight kinh doanh cốt lõi:** Southwest Airlines nổi bật với **Late Aircraft Delay Mins cao nhất** (~3.16M phút) – chiếm gần 50% tổng delay của hãng này. Mô hình khai thác point-to-point dày đặc của Southwest khiến bất kỳ sự cố nào trên một chặng đều lan truyền hiệu ứng domino mạnh sang các chuyến tiếp theo trong ngày. Ngược lại, **Carrier Delay** cao ở Delta và United (>1.4M phút) biểu thị vấn đề vận hành nội bộ có thể kiểm soát. Hawaiian Airlines và Spirit Air Lines có tổng delay thấp nhất, phù hợp với quy mô hoạt động nhỏ hơn của hai hãng này trong mạng lưới nội địa Mỹ.

---

#### 5.2.4. Insight 4 – Tổng Thời gian Quay đầu theo Thành phố

**Loại biểu đồ:** Bar Chart (Biểu đồ cột đứng)

**Thiết kế visual:** Trục X sắp xếp các thành phố (City) theo thứ tự giảm dần của `Turnaround Variance Mins`, trục Y hiển thị tổng phút quay đầu trễ tích lũy theo đơn vị tỷ phút (bn). Màu sắc xanh đồng nhất kết hợp với độ cao cột tạo ra gradient trực quan rõ ràng về thứ hạng "nút thắt cổ chai" theo địa lý.

*[Hình 5.5: Chart 4 – Turnaround Variance Mins by City; bảng chi tiết top 15 thành phố có tổng Variance cao nhất]*

**Phân tích kết quả:**

| Thành phố | Turnaround Variance Mins |
|---|---|
| Atlanta | **910,738,458** |
| Chicago | 580,395,921 |
| Dallas-Fort Worth | 568,442,479 |
| Unknown City | 531,261,485 |
| Houston | 242,110,306 |
| Los Angeles | 236,452,991 |
| New York | 235,387,769 |

**Insight kinh doanh cốt lõi:** Atlanta (ATL) vượt trội hơn gần **57%** so với Chicago đứng thứ hai, phản ánh thực tế ATL là sân bay có lưu lượng nội địa lớn nhất nước Mỹ với hơn 900,000 chuyến bay/năm. Cụm bốn thành phố dẫn đầu (Atlanta, Chicago, Dallas-Fort Worth, Houston) đều là Super-Hubs của các hãng lớn (Delta tại ATL, United tại ORD/IAH, American tại DFW), xác nhận rằng **cường độ hoạt động Hub là nguyên nhân chính** của áp lực quay đầu tàu bay, không phải hiệu suất vận hành mặt đất của từng hãng. Điểm đáng chú ý là "Unknown City" (531M phút) xuất hiện ở vị trí thứ tư – đây là giá trị cần làm sạch thêm trong Dim_Airport, nhắc nhở rằng chất lượng dữ liệu nguồn FAA cần được cải thiện ở chu kỳ ETL tiếp theo.

---


## CHƯƠNG 6: KẾT LUẬN

### 6.1. Kết quả đạt được

Dự án đã hoàn thành xây dựng một hệ thống Kho dữ liệu hoàn chỉnh theo phương pháp luận Kimball Lifecycle, từ tầng ingest dữ liệu thô đến tầng trực quan hóa chiến lược. Các kết quả cụ thể đạt được bao gồm:

**1. Thiết kế mô hình đa chiều đầy đủ *(Chương 2)*:**
Xây dựng thành công mô hình **Star Schema** với 5 chiều dùng chung (Dim_Date, Dim_Time, Dim_Airport, Dim_Airline, Dim_Aircraft) và 3 bảng sự kiện bao phủ toàn diện các nghiệp vụ phân tích: Fact_Flight_Transaction (Transaction Fact), Fact_Aircraft_Daily_Snapshot (Periodic Snapshot Fact) và Fact_Turnaround_Efficiency (Accumulating Snapshot Fact). Đây là lần đầu tiên cả 3 loại Fact Table chuẩn Kimball được triển khai đồng thời trong cùng một hệ thống. Grain và các độ đo của từng bảng được định nghĩa rõ ràng, phục vụ cho các câu hỏi kinh doanh cụ thể.

**2. Chiến lược SCD phù hợp từng chiều *(Mục 2.4)*:**
Áp dụng **SCD Type 1** (ghi đè) cho Dim_Airport và Dim_Airline nơi lịch sử thay đổi không có giá trị phân tích; áp dụng **SCD Type 2** (lưu lịch sử) cho Dim_Aircraft để theo dõi các thay đổi quan trọng như loại động cơ và hãng khai thác theo thời gian thực tế. Cấu hình Hierarchy rõ ràng trên từng chiều: `Year → Quarter → Month → Day` (Dim_Date), `State → City → Airport_Code` (Dim_Airport), `Manufacturer → Engine_Type → Tail_Number` (Dim_Aircraft).

**3. Pipeline ETL hoàn chỉnh với SSIS *(Chương 3)*:**
Triển khai toàn bộ pipeline ETL với SQL Server Integration Services, tích hợp từ **2 nguồn dữ liệu độc lập** (bộ dữ liệu Kaggle 2015 Flights và FAA Aircraft Registry). Quy trình staging riêng biệt thực hiện làm sạch dữ liệu, chuẩn hóa định dạng giờ, xử lý NULL và tính toán các cột phái sinh trước khi nạp vào DWH. Kỹ thuật SQL Window Function `LAG()` được áp dụng trong tầng Staging để tính toán `Turnaround_Variance_Mins` cho Fact_Turnaround_Efficiency *(Mục 3.5.4)*.

**4. Tải dữ liệu tăng dần (Incremental Load) *(Mục 3.2)*:**
Cơ chế tải tăng dần được triển khai qua bảng `ETL_Watermark` lưu `Last_Load_Time`. Mỗi lần chạy, SSIS chỉ trích xuất các bản ghi mới từ OLTP có `Updated_Date > Last_Load_Time`, tránh tải lại toàn bộ dữ liệu và đảm bảo idempotency cho pipeline khi chạy lại.

**5. Tầng ngữ nghĩa SSAS Cube *(Chương 4)*:**
Xây dựng SSAS Multidimensional Cube với Data Source View ánh xạ đầy đủ 8 bảng (5 Dim + 3 Fact), cấu hình Role-playing Dimensions cho Dim_Airport (hai vai trò Origin và Destination trong cùng một Cube), thiết lập các Measure Groups và Hierarchies tối ưu cho drill-down phân tích. Cube được deploy lên server và xử lý Process Full thành công.

**6. Executive Dashboard trả lời 4 Insight chiến lược *(Chương 5)*:**
Xây dựng 01 Executive Dashboard bố cục 2×2 trên Power BI với Live Connection SSAS, tích hợp Slicers thời gian linh hoạt. Dashboard trả lời 4 câu hỏi kinh doanh cốt lõi: bang nào chịu thiệt hại tài chính lớn nhất, nguyên nhân chậm trễ từng hãng, xu hướng hoạt động đội tàu theo tháng, và thành phố nào có áp lực quay đầu tàu bay lớn nhất. Kết quả phân tích được xác minh song song bằng SQL query trực tiếp trên DWH *(Mục 4.2)*.

---

### 6.2. Hạn chế


Mặc dù dự án hoàn thành đầy đủ các yêu cầu kỹ thuật, một số giới hạn thực tế sau đây cần được ghi nhận để định hướng cải tiến:

**1. Hạn chế về chất lượng dữ liệu nguồn:**
Bộ dữ liệu Kaggle 2015 Flight Delays chứa một số bản ghi có `TAIL_NUMBER` không hợp lệ hoặc không khớp với cơ sở dữ liệu FAA Registry, dẫn đến một phần dữ liệu tàu bay được ghi nhận là `"Unknown"` trong Dim_Aircraft. Hệ quả là trong biểu đồ Turnaround Variance by City, thành phố `"Unknown City"` xuất hiện ở vị trí thứ tư (531M phút), làm méo kết quả phân tích địa lý nếu không có bộ lọc loại trừ phù hợp.

**2. Hạn chế về dữ liệu Fact_Aircraft_Daily_Snapshot:**
Do cơ chế tra cứu AircraftKey trong SSIS gặp vấn đề đối với các `TAIL_NUMBER` không tồn tại trong Dim_Aircraft, một phần dữ liệu của bảng này không được ánh xạ chính xác theo chiều Aircraft. Phân tích Insight 3 (Monthly Fleet Activity) vì vậy được thực hiện thuần theo chiều Date, chưa khai thác được góc nhìn "hiệu suất từng tàu bay theo thời gian" theo đúng mục tiêu ban đầu.

**3. Phạm vi dữ liệu giới hạn trong năm 2015:**
Hệ thống chỉ xử lý dữ liệu của năm 2015, không cho phép phân tích xu hướng đa năm hoặc so sánh liên kỳ (YoY). Điều này làm hạn chế giá trị của các phân tích dự báo (predictive analytics) mà dự án hướng đến ở giai đoạn tiếp theo.

**4. Mô hình Cube chưa có tính năng Write-back:**
SSAS Cube hiện tại chỉ hỗ trợ đọc dữ liệu, không tích hợp tính năng phân bổ ngân sách hoặc điều chỉnh kế hoạch trực tiếp từ giao diện Dashboard, vốn là tính năng cao cấp thường thấy trong các hệ thống BI cấp doanh nghiệp.

---

### 6.3. Hướng phát triển tương lai

Dựa trên nền tảng kiến trúc đã xây dựng, dự án có thể được mở rộng theo các hướng sau:

**1. Mở rộng phạm vi dữ liệu và nguồn tích hợp:**
Bổ sung dữ liệu từ các năm 2016-2024 để xây dựng mô hình xu hướng đa năm. Tích hợp thêm dữ liệu thời tiết thực tế (NOAA Weather API) để nâng cao độ chính xác của phân tích nguyên nhân chậm trễ do thời tiết, từ đó phân biệt rõ Weather Delay "thực sự" với các delay được hãng phân loại nhầm vào nhóm này.

**2. Xây dựng mô hình Machine Learning dự báo**:
Sử dụng bộ dữ liệu lịch sử từ DWH để huấn luyện mô hình dự báo xác suất delay cho từng chuyến bay dựa trên các yếu tố tháng bay, hãng, tuyến đường và loại máy bay. Mô hình có thể được tích hợp vào Power BI thông qua Python visual hoặc Azure ML endpoint để cung cấp dự báo thời gian thực.

**3. Triển khai lên môi trường Cloud (Azure Synapse Analytics):**
Di chuyển hệ thống từ môi trường SQL Server on-premises lên Azure Synapse Analytics, kết hợp với Azure Data Factory thay thế SSIS để đạt được khả năng mở rộng tự động (auto-scaling), lưu trữ tiết kiệm chi phí (Data Lake Gen2), và tích hợp với Power BI Service để chia sẻ Dashboard trong tổ chức qua web browser mà không cần cài đặt Power BI Desktop.

**4. Cải thiện chất lượng dữ liệu chiều Aircraft:**
Xây dựng pipeline làm giàu dữ liệu (data enrichment) bằng cách tra cứu FAA API theo thời gian thực để bổ sung thông tin cho các `TAIL_NUMBER` không khớp, giải quyết triệt để vấn đề "Unknown" trong Dim_Aircraft và nâng cao tỷ lệ match lên trên 95%.

**5. Tự động hóa Pipeline và Giám sát:**
Triển khai SQL Server Agent Jobs để tự động hóa toàn bộ chu kỳ ETL → Process Cube → Refresh Dashboard theo lịch hàng ngày. Kết hợp với hệ thống cảnh báo email khi pipeline thất bại hoặc khi các chỉ số vận hành vượt ngưỡng định trước (ví dụ: tổng delay tháng này tăng hơn 20% so với cùng kỳ).

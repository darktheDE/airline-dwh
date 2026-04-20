# Task 11: Executive Dashboard – Power BI + SSAS

**Kết nối:** Live Connection → Server: `KIENHUNG` → Database: `Airline_Cube_Project`

---

## 5. KHAI THÁC VÀ TRỰC QUAN HÓA (OLAP & VISUALIZATION)

Dự án xây dựng **01 Executive Dashboard** duy nhất trên Power BI, thực hiện Live Connection đến SSAS Cube để trả lời 4 Insight chiến lược (sử dụng cả 3 loại bảng Fact):

### INSIGHT 1 – Financial Loss & Delay by State (Fact_Flight_Transaction)
**Business Question:** "Bang nào chịu thiệt hại tài chính và tổng thời gian chậm trễ lớn nhất?"

**Verify SQL:**
```sql
SELECT TOP 10 da.State,
       SUM(f.Estimated_Financial_Loss_USD) AS TotalLoss,
       SUM(f.Arr_Delay_Mins) AS TotalArrDelay
FROM Fact_Flight_Transaction f
JOIN Dim_Airport da ON f.DestAirportKey = da.AirportKey
GROUP BY da.State ORDER BY TotalLoss DESC
```
**Power BI:** visual *Clustered Bar Chart*. Y-axis: `Dest Airport[State]`, X-axis: `Estimated Financial Loss USD`, `Arr Delay Mins`.

---

### INSIGHT 2 – Delay Root Cause Breakdown by Airline (Fact_Flight_Transaction)
**Business Question:** "Nguyên nhân chậm trễ chính của từng hãng hàng không là gì?"

**Verify SQL:**
```sql
SELECT dl.AirlineName, SUM(f.Weather_Delay_Mins) AS Weather, 
       SUM(f.Carrier_Delay_Mins) AS Carrier, SUM(f.NAS_Delay_Mins) AS NAS,
       SUM(f.LateAircraft_Delay_Mins) AS LateAircraft
FROM Fact_Flight_Transaction f
JOIN Dim_Airline dl ON f.AirlineKey = dl.AirlineKey
WHERE f.Is_Delayed = 1 GROUP BY dl.AirlineName
```
**Power BI:** visual *Stacked Bar Chart*. Y-axis: `Dim Airline[Airline Name]`, X-axis: 4 loại delay measures (Weather, Carrier, NAS, Late Aircraft). Filter: `Is Delayed = True`.

---

### INSIGHT 3 – Monthly Fleet Activity & Delay Trend (Fact_Aircraft_Daily_Snapshot)
**Business Question:** "Xu hướng lượng chuyến bay và tổng phút delay biến động thế nào qua các tháng (phân tích mức độ hoạt động đội tàu)?"
*> Lưu ý: Sử dụng Date-based analysis do AircraftKey lookup lỗi.*

**Verify SQL:**
```sql
SELECT dd.CalendarYear, dd.MonthName,
       SUM(f.Daily_Flight_Count) AS TotalFlights,
       SUM(f.Daily_Delay_Mins_Total) AS TotalDelayMins
FROM Fact_Aircraft_Daily_Snapshot f
JOIN Dim_Date dd ON f.DateKey = dd.DateKey
GROUP BY dd.CalendarYear, dd.MonthNumber, dd.MonthName
ORDER BY dd.MonthNumber
```
**Power BI:** visual *Line and Stacked Column Chart*. X-axis: `Dim Date[Month Name]`, Column: `Daily Flight Count`, Line: `Daily Delay Mins Total`.

---

### INSIGHT 4 – Total Turnaround Delay by City (Fact_Turnaround_Efficiency)
**Business Question:** "Thành phố nào có tổng thời gian trễ quay đầu (Turnaround) tích lũy lớn nhất?"

**Verify SQL:**
```sql
SELECT TOP 10 da.City, da.State,
       SUM(f.Turnaround_Variance_Mins) AS TotalDelayMins
FROM Fact_Turnaround_Efficiency f
JOIN Dim_Airport da ON f.AirportKey = da.AirportKey
GROUP BY da.City, da.State ORDER BY TotalDelayMins DESC
```
**Power BI:** visual *Bar Chart*. 
- **Y-axis:** `Dim Airport[City]`
- **X-axis:** `Turnaround Variance Mins` (Dùng mặc định là Sum)
- **Title:** *"Top 10 Cities by Total Ground Turnaround Delay (Minutes)"*

---

## Bố cục Dashboard (2x2 Layout)

| Insight 1 (Bar) | Insight 2 (Stacked Bar) |
|-----------------|-------------------------|
| **Insight 3 (Combo Chart)** | **Insight 4 (Table)** |

**Slicers:** Thêm `Dim Date[Calendar Year]` và `Dim Date[Month Name]` để lọc toàn bộ báo cáo.

## Checklist đạt điểm A (9-10)
- [x] Dashboad kết nối Live SSAS (OLAP).
- [x] Sử dụng đa dạng các bảng Fact (Transaction, Periodic Snapshot, Accumulating Snapshot).
- [x] Có Slicer thời gian linh hoạt.
- [x] Sử dụng Conditional Formatting thể hiện Bottleneck.
- [x] Insights trả lời trực tiếp các vấn đề tổn thất tài chính và vận hành.

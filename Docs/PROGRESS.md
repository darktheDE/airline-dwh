### 1. MODULES

1. `MOD-01: Data & DB Infrastructure` (Chuẩn bị dữ liệu và CSDL).

2. `MOD-02: Dimensions & Master ETL` (Xây dựng các bảng Chiều và luồng SSIS tổng).

3. `MOD-03: Fact Tables & CDC` (Xây dựng 3 bảng Fact và Cơ chế Tải tăng dần).

4. `MOD-04: SSAS Cube & MDX` (Xây dựng Cube và viết truy vấn phân tích).

5. `MOD-05: BI Dashboard & Documentation` (Trực quan hóa và Viết Báo cáo Word).

### 2. CYCLES

* `Cycle 1: Foundation (Tuần 1)`

* `Cycle 2: Dim Modeling & SCD (Tuần 2)`

* `Cycle 3: Fact ETL & Incremental Load (Tuần 3)`

* `Cycle 4: OLAP, Dashboard & Report (Tuần 4)`

### 3. DANH SÁCH ISSUES / WORK ITEMS

| Issue Title (Tên Task)                                             | Module | Cycle   | Assignee     | Priority | Labels                         |
| ------------------------------------------------------------------ | ------ | ------- | ------------ | -------- | ------------------------------ |
| **1. Tải và làm sạch dữ liệu thô (Kaggle 2015 & FAA ardata)**      | MOD-01 | Cycle 1 | Thành viên A | High     | `Data-Prep`                    |
| **2. Viết Script SQL tạo DB OLTP và Import CSV**                   | MOD-01 | Cycle 1 | Thành viên B | High     | `SQL`, `DB-Design`             |
| **3. Viết Script SQL tạo DB Staging và DWH (Star Schema)**         | MOD-01 | Cycle 1 | Thành viên C | Urgent   | `SQL`, `DB-Design`             |
| **4. Tạo Master SSIS Package và thiết lập Connection Managers**    | MOD-02 | Cycle 2 | Thành viên A | Urgent   | `SSIS`, `Architecture`         |
| **5. Xây dựng luồng ETL: Dim_Date & Dim_Time**                     | MOD-02 | Cycle 2 | Thành viên C | Medium   | `SSIS`, `Dimension`            |
| **6. Xây dựng luồng ETL: Dim_Airport & Dim_Airline (SCD Type 1)**  | MOD-02 | Cycle 2 | Thành viên B | High     | `SSIS`, `Dimension`            |
| **7. Xây dựng luồng ETL: Dim_Aircraft (SCD Type 2)**               | MOD-02 | Cycle 2 | Thành viên A | Urgent   | `SSIS`, `SCD2`                 |
| **8. Thiết lập Bảng ETL_Watermark cho Incremental Load**           | MOD-03 | Cycle 3 | Thành viên B | High     | `SQL`, `CDC`                   |
| **9. Xây dựng luồng ETL: Fact_Flight_Transaction**                 | MOD-03 | Cycle 3 | Thành viên A | Urgent   | `SSIS`, `Fact`                 |
| **10. Xây dựng luồng ETL: Fact_Aircraft_Daily_Snapshot**           | MOD-03 | Cycle 3 | Thành viên B | Urgent   | `SSIS`, `Fact`                 |
| **11. Xây dựng luồng ETL: Fact_Turnaround_Efficiency**             | MOD-03 | Cycle 3 | Thành viên C | Urgent   | `SSIS`, `Fact`, `Advanced-SQL` |
| **12. Kiểm thử Incremental Load toàn hệ thống**                    | MOD-03 | Cycle 3 | Thành viên A | High     | `Testing`                      |
| **13. Xây dựng SSAS Cube (Add DSV, Cubes, Hierarchies)**           | MOD-04 | Cycle 4 | Thành viên C | High     | `SSAS`, `OLAP`                 |
| **14. Viết 3 truy vấn MDX trả lời Business Insights**              | MOD-04 | Cycle 4 | Cả 3 người   | Medium   | `MDX`                          |
| **15. Thiết kế Executive Dashboard trên Power BI**                 | MOD-05 | Cycle 4 | Thành viên B | High     | `PowerBI`                      |
| **16. Viết Báo cáo Word: Chương 1 & 2 (Tổng quan & Dim Modeling)** | MOD-05 | Cycle 4 | Thành viên A | High     | `Docs`                         |
| **17. Viết Báo cáo Word: Chương 3 (SSIS) & Chương 4 (SSAS/BI)**    | MOD-05 | Cycle 4 | Thành viên C | High     | `Docs`                         |
| **18. Review toàn bộ Báo cáo khớp với Rubric (Lấy điểm A)**        | MOD-05 | Cycle 4 | Cả 3 người   | Urgent   | `Review`                       |

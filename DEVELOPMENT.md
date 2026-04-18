# Development Guide

## 1. Prerequisites
*   Microsoft SQL Server 2019+
*   SQL Server Integration Services (SSIS)
*   SQL Server Analysis Services (SSAS) - Multidimensional
*   Visual Studio (with SSIS/SSAS extensions)
*   Power BI Desktop

## 2. Environment Setup
1.  Clone the repository:
    ```bash
    git clone https://github.com/darktheDE/airline-dwh.git
    ```
2.  Download datasets and place them in:
    *   `Data/2015-flight-delays-and-cancellations/`
    *   `Data/faa-aircraft-registry/`

## 3. Database Layer
1.  Open SQL Server Management Studio (SSMS).
2.  Run scripts in `SQL_Script/` in order:
    1.  Create OLTP database and tables.
    2.  Create Data Warehouse (DWH) schema.
    3.  Load initial lookup data or procedures.

## 4. ETL Pipeline (SSIS)
1.  Open the SSIS Solution in `SSIS_Package/` using Visual Studio.
2.  Configure Connection Managers to point to your local SQL Server instance.
3.  Execute the `Master_Package.dtsx` to run the full workflow.

## 5. OLAP Layer (SSAS)
1.  Open the SSAS Project in `SSAS_Cube/` using Visual Studio.
2.  Update the Data Source connection string.
3.  Deploy and Process the cube.

## 6. Visualization
1.  Open the `.pbix` file in the `Dashboard/` folder using Power BI Desktop.
2.  Click **Refresh** to load data from your local DWH.

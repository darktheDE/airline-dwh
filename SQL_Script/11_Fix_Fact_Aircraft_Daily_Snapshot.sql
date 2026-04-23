USE AirlineDWH;
GO

-- 1. Daily_Flight_Count
DECLARE @ConstraintName NVARCHAR(200);
SELECT @ConstraintName = d.name
FROM sys.tables t
JOIN sys.default_constraints d ON d.parent_object_id = t.object_id
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = d.parent_column_id
WHERE t.name = 'Fact_Aircraft_Daily_Snapshot' AND c.name = 'Daily_Flight_Count';

IF @ConstraintName IS NOT NULL
    EXEC('ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot DROP CONSTRAINT ' + @ConstraintName);

ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot ALTER COLUMN Daily_Flight_Count INT NOT NULL;
ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot ADD CONSTRAINT DF_FADS_Daily_Flight_Count DEFAULT 0 FOR Daily_Flight_Count;

-- 2. Daily_Air_Time
SET @ConstraintName = NULL;
SELECT @ConstraintName = d.name
FROM sys.tables t
JOIN sys.default_constraints d ON d.parent_object_id = t.object_id
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = d.parent_column_id
WHERE t.name = 'Fact_Aircraft_Daily_Snapshot' AND c.name = 'Daily_Air_Time';

IF @ConstraintName IS NOT NULL
    EXEC('ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot DROP CONSTRAINT ' + @ConstraintName);

ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot ALTER COLUMN Daily_Air_Time INT NOT NULL;
ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot ADD CONSTRAINT DF_FADS_Daily_Air_Time DEFAULT 0 FOR Daily_Air_Time;

-- 3. Tech_Incident_Count
SET @ConstraintName = NULL;
SELECT @ConstraintName = d.name
FROM sys.tables t
JOIN sys.default_constraints d ON d.parent_object_id = t.object_id
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = d.parent_column_id
WHERE t.name = 'Fact_Aircraft_Daily_Snapshot' AND c.name = 'Tech_Incident_Count';

IF @ConstraintName IS NOT NULL
    EXEC('ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot DROP CONSTRAINT ' + @ConstraintName);

ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot ALTER COLUMN Tech_Incident_Count INT NOT NULL;
ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot ADD CONSTRAINT DF_FADS_Tech_Incident_Count DEFAULT 0 FOR Tech_Incident_Count;

-- 4. Daily_Delay_Mins_Total
SET @ConstraintName = NULL;
SELECT @ConstraintName = d.name
FROM sys.tables t
JOIN sys.default_constraints d ON d.parent_object_id = t.object_id
JOIN sys.columns c ON c.object_id = t.object_id AND c.column_id = d.parent_column_id
WHERE t.name = 'Fact_Aircraft_Daily_Snapshot' AND c.name = 'Daily_Delay_Mins_Total';

IF @ConstraintName IS NOT NULL
    EXEC('ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot DROP CONSTRAINT ' + @ConstraintName);

ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot ALTER COLUMN Daily_Delay_Mins_Total INT NOT NULL;
ALTER TABLE dbo.Fact_Aircraft_Daily_Snapshot ADD CONSTRAINT DF_FADS_Daily_Delay_Mins DEFAULT 0 FOR Daily_Delay_Mins_Total;
GO

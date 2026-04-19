USE Airline_Staging;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ExtractTurnaround
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE dbo.stg_Turnaround;

    INSERT INTO dbo.stg_Turnaround (
        Tail_Number, Airline_Code, Turnaround_Airport, 
        Inbound_Flight_BK, Inbound_Arrival_Time, 
        Outbound_Flight_BK, Outbound_Departure_Time, 
        Staging_Date
    )
    SELECT 
        f1.Tail_Number, f1.Airline_Code, f1.Destination_Airport,
        f1.Flight_ID, 
        -- Convert f1.Arrival_Time (HHmm as INT) to DATETIME
        DATEADD(MINUTE, (f1.Arrival_Time % 100), 
            DATEADD(HOUR, (f1.Arrival_Time / 100), 
                CAST(CAST(f1.Flight_Year AS VARCHAR)+'-'+CAST(f1.Flight_Month AS VARCHAR)+'-'+CAST(f1.Flight_Day AS VARCHAR) AS DATETIME))),
        
        f2.Flight_ID, 
        -- Convert f2.Departure_Time (HHmm as INT) to DATETIME
        DATEADD(MINUTE, (f2.Departure_Time % 100), 
            DATEADD(HOUR, (f2.Departure_Time / 100), 
                CAST(CAST(f2.Flight_Year AS VARCHAR)+'-'+CAST(f2.Flight_Month AS VARCHAR)+'-'+CAST(f2.Flight_Day AS VARCHAR) AS DATETIME))),
        
        GETDATE()
    FROM Airline_OLTP.dbo.tb_Flights f1
    JOIN Airline_OLTP.dbo.tb_Flights f2 ON f1.Tail_Number = f2.Tail_Number 
        AND f1.Destination_Airport = f2.Origin_Airport 
        AND (
            -- Same day
            (f1.Flight_Year = f2.Flight_Year AND f1.Flight_Month = f2.Flight_Month AND f1.Flight_Day = f2.Flight_Day AND f2.Departure_Time > f1.Arrival_Time)
            OR
            -- Next day (Approximate check if date+1 matches)
            (CAST(CAST(f2.Flight_Year AS VARCHAR)+'-'+CAST(f2.Flight_Month AS VARCHAR)+'-'+CAST(f2.Flight_Day AS VARCHAR) AS DATE) = 
             DATEADD(DAY, 1, CAST(CAST(f1.Flight_Year AS VARCHAR)+'-'+CAST(f1.Flight_Month AS VARCHAR)+'-'+CAST(f1.Flight_Day AS VARCHAR) AS DATE)))
        )
    WHERE f1.Arrival_Time IS NOT NULL AND f2.Departure_Time IS NOT NULL;
END;
GO

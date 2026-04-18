USE Airline_OLTP;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ExtractTurnaround
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Xóa dữ liệu cũ tại Staging trước khi nạp mới
    TRUNCATE TABLE Airline_Staging.dbo.stg_Turnaround;

    INSERT INTO Airline_Staging.dbo.stg_Turnaround (
        Tail_Number, Airline_Code, Turnaround_Airport, 
        Inbound_Flight_BK, Inbound_Arrival_Time, 
        Outbound_Flight_BK, Outbound_Departure_Time, 
        Staging_Date
    )
    SELECT 
        f1.Tail_Number, f1.Airline_Code, f1.Destination_Airport,
        f1.Flight_ID, 
        -- Chuyển đổi f1.Arrival_Time (định dạng HHmm kiểu INT) sang DATETIME
        DATEADD(MINUTE, (f1.Arrival_Time % 100), 
            DATEADD(HOUR, (f1.Arrival_Time / 100), 
                CAST(CAST(f1.Flight_Year AS VARCHAR)+'-'+CAST(f1.Flight_Month AS VARCHAR)+'-'+CAST(f1.Flight_Day AS VARCHAR) AS DATETIME))),
        
        f2.Flight_ID, 
        -- Chuyển đổi f2.Departure_Time (định dạng HHmm kiểu INT) sang DATETIME
        DATEADD(MINUTE, (f2.Departure_Time % 100), 
            DATEADD(HOUR, (f2.Departure_Time / 100), 
                CAST(CAST(f2.Flight_Year AS VARCHAR)+'-'+CAST(f2.Flight_Month AS VARCHAR)+'-'+CAST(f2.Flight_Day AS VARCHAR) AS DATETIME))),
        
        GETDATE()
    FROM Airline_OLTP.dbo.tb_Flights f1
    JOIN Airline_OLTP.dbo.tb_Flights f2 ON f1.Tail_Number = f2.Tail_Number 
        AND f1.Destination_Airport = f2.Origin_Airport 
        AND (
            -- Trường hợp đi và đến trong cùng một ngày
            (f1.Flight_Year = f2.Flight_Year AND f1.Flight_Month = f2.Flight_Month AND f1.Flight_Day = f2.Flight_Day AND f2.Departure_Time > f1.Arrival_Time)
            OR
            -- Trường hợp chuyến bay đi vào ngày hôm sau (Xử lý vắt ngày)
            (CAST(CAST(f2.Flight_Year AS VARCHAR)+'-'+CAST(f2.Flight_Month AS VARCHAR)+'-'+CAST(f2.Flight_Day AS VARCHAR) AS DATE) = 
             DATEADD(DAY, 1, CAST(CAST(f1.Flight_Year AS VARCHAR)+'-'+CAST(f1.Flight_Month AS VARCHAR)+'-'+CAST(f1.Flight_Day AS VARCHAR) AS DATE)))
        )
    WHERE f1.Arrival_Time IS NOT NULL AND f2.Departure_Time IS NOT NULL;
END;
GO

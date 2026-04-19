/*
===================================================================================
  FILE    : 09_Extract_Flights_Incremental.sql
  PROJECT : Airline DWH - Task 9
  DATE    : 2026-04-19
  
  Mục tiêu: Trích xuất dữ liệu tăng dần từ OLTP sang Staging.
  SSIS sử dụng tham số ? để truyền giá trị User::LastLoadDate.
===================================================================================
*/

-- Câu lệnh này thường được đặt trong OLE DB Source của SSIS
-- Map tham số ? với biến User::LastLoadDate (Task 8)

SELECT 
    Flight_Year, Flight_Month, Flight_Day, Day_Of_Week,
    Airline_Code, Flight_Number, Tail_Number,
    Origin_Airport, Destination_Airport,
    Scheduled_Departure, Departure_Time, Departure_Delay,
    Taxi_Out, Wheels_Off, Scheduled_Time, Elapsed_Time,
    Air_Time, Distance, Wheels_On, Taxi_In,
    Scheduled_Arrival, Arrival_Time, Arrival_Delay,
    Diverted, Cancelled, Cancellation_Reason,
    Air_System_Delay, Security_Delay, Airline_Delay,
    Late_Aircraft_Delay, Weather_Delay,
    Updated_Date -- Để Debug nếu cần
FROM Airline_OLTP.dbo.tb_Flights
WHERE Updated_Date > ?; -- ? là biến LastLoadDate
GO

/*
  Gợi ý cấu hình Derived Column (Xử lý Business Rules Task 9):
  -------------------------------------------------------------
  1. Xử lý NULL:
     Weather_Delay_Mins   = REPLACENULL(Weather_Delay, 0)
     Carrier_Delay_Mins   = REPLACENULL(Airline_Delay, 0)
     
  2. Is_Delayed:
     Is_Delayed = (Arrival_Delay >= 15) ? 1 : 0
     
  3. Estimated_Loss_USD:
     Estimated_Loss_USD = (Arrival_Delay * 75) + (Cancelled * 5000)
*/

# 2015 Flight Delays and Cancellations Dataset

This directory contains the primary flight operations data.

### Contents:
- **airlines.csv**: Contains the names and codes of the airlines. Used for `Dim_Airline`.
- **airports.csv**: Contains airport names, codes, and locations (city, state). Used for `Dim_Airport`.
- **flights.csv**: The main transaction file containing details of every flight, including departure/arrival times, delays, and cancellation reasons. Used for `Fact_Flight_Transaction`.

### Source:
[Kaggle: 2015 Flight Delays and Cancellations](https://www.kaggle.com/datasets/usdot/flight-delays)

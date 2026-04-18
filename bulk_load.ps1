$conString = "Data Source=.;Initial Catalog=Airline_Staging;Integrated Security=True"
$con = New-Object System.Data.SqlClient.SqlConnection($conString)
$con.Open()

function Import-CsvToSql($csvPath, $tableName) {
    Write-Host "Importing $csvPath to $tableName..."
    $csv = Import-Csv -Path $csvPath
    if ($csv.Count -eq 0) { return }
    
    $dt = New-Object System.Data.DataTable
    $cols = $csv[0].PSObject.Properties.Name
    foreach($col in $cols) { 
        [void]$dt.Columns.Add($col) 
    }
    
    foreach($row in $csv) {
        $dr = $dt.NewRow()
        foreach($col in $cols) { 
            $dr[$col] = $row.$col 
        }
        $dt.Rows.Add($dr)
    }
    
    $bc = New-Object System.Data.SqlClient.SqlBulkCopy($con)
    $bc.DestinationTableName = $tableName
    $bc.WriteToServer($dt)
    Write-Host "Successfully imported $($dt.Rows.Count) rows."
}

Import-CsvToSql -csvPath 'c:\D Dirve\HK2_25-26\Data_Warehouse\airline-dwh\Data\2015-flight-delays-and-cancellations\airlines.csv' -tableName 'dbo.stg_Airlines_Temp'
Import-CsvToSql -csvPath 'c:\D Dirve\HK2_25-26\Data_Warehouse\airline-dwh\Data\2015-flight-delays-and-cancellations\airports.csv' -tableName 'dbo.stg_Airports_Temp'

$con.Close()

﻿## Example that shows how to find two subsets 

# Import of module
Import-Module ..\MSSQL-SqlSizer

# Connection settings
$server = "localhost"
$database = "AdventureWorks2019"
$login = "someuser"
$password = "pass"

# Create connection
$connection = New-SqlConnectionInfo -Server $server -Login $login -Password $password

# Get database info
$info = Get-DatabaseInfo -Database $database -ConnectionInfo $connection

# Install SqlSizer
Install-SqlSizer -Database $database -ConnectionInfo $connection -DatabaseInfo $info


# Find subset1

# Query 1: All persons with first name = 'Michael'
$query = New-Object -TypeName Query
$query.Color = [Color]::Yellow
$query.Schema = "Person"
$query.Table = "Person"
$query.KeyColumns = @('BusinessEntityID')
$query.Where = "[`$table].FirstName = 'Michael'"

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info
Find-Subset -Database $database -ConnectionInfo $connection -DatabaseInfo $info
$subset1 = Get-SubsetTables -Database $database -ConnectionInfo $connection -DatabaseInfo $info

# Query 2: All persons with first name = 'Wanida'
$query2 = New-Object -TypeName Query
$query2.Color = [Color]::Yellow
$query2.Schema = "Person"
$query2.Table = "Person"
$query2.KeyColumns = @('BusinessEntityID')
$query2.Where = "[`$table].FirstName = 'Wanida'"

Initialize-StartSet -Database $database -ConnectionInfo $connection -Queries @($query) -DatabaseInfo $info
Find-Subset -Database $database -ConnectionInfo $connection -DatabaseInfo $info
$subset2 = Get-SubsetTables -Database $database -ConnectionInfo $connection -DatabaseInfo $info

Write-Host "First subset:"
$subset1
Write-Host "====="

Write-Host "Second subset:"
$subset2
Write-Host "====="
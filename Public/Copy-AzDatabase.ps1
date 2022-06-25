function Copy-AzDatabase
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$NewDatabase,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    
    Write-Progress -Activity "Copy Azure database" -PercentComplete 0
    
    $sql = "CREATE DATABASE $NewDatabase AS COPY OF $Database"
        
    $null = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    Write-Progress -Activity "Copy Azure database" -Completed
}
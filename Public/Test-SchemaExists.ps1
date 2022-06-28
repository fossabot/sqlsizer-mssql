function Test-SchemaExists
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )
    
    # create schema if not exist
    $sql = "SELECT 1 as [Result] FROM sys.schemas WHERE name = '$SchemaName'"
    $results = Execute-SQL -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    if (($null -ne $results) -and ($results.Result -eq 1))
    {
        return $true
    }
    return $false
}
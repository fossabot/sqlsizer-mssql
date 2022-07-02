function Copy-SubsetToAzStorageContainer
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$ContainerName,

        [Parameter(Mandatory=$true)]
        [Object]$StorageContext,

        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [bool]$Secure,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    New-AzStorageContainer -Name $ContainerName -Context $StorageContext

    $subsetTables = Get-SubsetTables -Database $Database -DatabaseInfo $DatabaseInfo -ConnectionInfo $ConnectionInfo

    foreach ($table in $subsetTables)
    {
        $tmpFile = New-TemporaryFile
        $csv = Get-SubsetTableCsv -Database $Database -SchemaName $table.SchemaName -TableName $table.TableName -ConnectionInfo $ConnectionInfo -Secure $Secure

        [System.IO.File]::WriteAllText($tmpFile.FullName, $csv, [Text.Encoding]::GetEncoding("utf-8"))

        $null = Set-AzStorageBlobContent -Container $ContainerName -File $tmpFile.FullName -Blob "$($table.SchemaName).$($table.TableName).csv" -Context $StorageContext

        Remove-Item $tmpFile.FullName -Force
    }
}
function Test-IgnoredTables
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [TableInfo2[]]$IgnoredTables,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    foreach ($table in $info.Tables)
    {
        foreach ($fk in $table.ForeignKeys)
        {
            foreach ($fkColumn in $fk.FkColumns)
            {
                if ($fkColumn.IsNullable -eq $true)
                {
                    continue
                }

                foreach ($ignoredTable in $IgnoredTables)
                {
                    if (($ignoredTable.TableName -eq $fk.Table) -and ($ignoredTable.SchemaName -eq $fk.Schema))
                    {
                        throw "Invalid ignored table: " + ($ignoredTable.SchemaName) + "." + ($ignoredTable.tableName) + " used by " + $fk.Name + " not null"
                    }
                }
            }
        }
    }

    Write-Verbose "Ignored tables validated"
}
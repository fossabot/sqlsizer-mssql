﻿function Remove-SubsetData
{
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Target,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo
    $structure = [Structure]::new($info)
    
    foreach ($table in $info.Tables)
    {
        $schema = $table.SchemaName
        $tableName = $table.TableName
        
        if ($table.IsHistoric -eq $true)
        {
            continue
        }

        $where = GetTableWhere -Database $Source -TableInfo $table -Structure $structure
        $sql = "DELETE FROM " + $schema + ".[" +  $tableName + "] " + $where
        
        $null = Execute-SQL -Sql $sql -Database $Target -ConnectionInfo $ConnectionInfo 
    }
}

# Function that creates a where part of query
function GetTableWhere
{
     param (
        [string]$Database,
        [TableInfo]$TableInfo,
        [Structure]$Structure
     )

     $primaryKey = $TableInfo.PrimaryKey
     $processing = $Structure.GetProcessingName($Structure.Tables[$TableInfo])
     $where = " WHERE EXISTS(SELECT * FROM " + $Database + ".$($processing) WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' "

     $i = 0
     foreach ($column in $primaryKey)
     {
        $where += " AND Key" + $i + " = " + $column.Name + " " 
        $i += 1
     }

     $where += ")"

     $where
}
﻿function Copy-Data
{
    
    [cmdletbinding()]
    param
    (   
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfo -Database $Source -Connection $ConnectionInfo

    foreach ($table in $info.Tables)
    {
        if ($table.IsHistoric -eq $true)
        {
            continue
        }

        $isIdentity = $table.IsIdentity
        $schema = $table.SchemaName
        $tableName = $table.TableName
        
        $tableColumns = GetTableSelect -TableInfo $table -Raw $true
        $tableSelect = GetTableSelect -TableInfo $table -Raw $false

        $where = GetTableWhere -Database $Source -TableInfo $table

        $sql = "INSERT INTO " +  $schema + ".[" +  $tableName + "] (" + $tableColumns + ") SELECT " + $tableSelect +  " FROM " + $Source + "." + $schema + ".[" +  $tableName + "]"
        
        $sql = $sql + $where
        if ($isIdentity)
        {
            $sql = "SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] ON " + $sql + " SET IDENTITY_INSERT " + $schema + ".[" +  $tableName + "] OFF" 
        }
        $_ = Execute-SQL -Sql $sql -Database $Destination -ConnectionInfo $ConnectionInfo 
    }
   
}

function GetTableSelect
{
    param (
        [bool]$Raw,
        [TableInfo]$TableInfo
    )

    
    $select = ""
    $j = 0
    for ($i = 0; $i -lt $table.Columns.Count; $i++)
    {
        $column = $table.Columns[$i]
        $columnName = $column.Name

        if (($column.IsComputed -eq $true) -or ($column.IsGenerated -eq $true) -or ($column.DataType -eq "timestamp"))
        {
            continue
        }
        else
        {
            if ($j -gt 0)
            {
                $select += ","
            }

            if ($Raw)
            {
                $select +=  "[" + $columnName + "]"
            }
            else
            {
                $select += GetColumnValue -columnName $columnName -dataType $column.DataType -prefix ""
            }

            $j += 1
        }
    }

    $select
}

# Function that creates a where part of query
function GetTableWhere
{
     param (
        [string]$Database,
        [TableInfo]$TableInfo
     )

     $primaryKey = $TableInfo.PrimaryKey
     $where = " WHERE EXISTS(SELECT * FROM " + $Database + ".SqlSizer.Processing WHERE [Schema] = '" +  $Schema + "' and TableName = '" + $TableName + "' "

     $i = 0
     foreach ($column in $primaryKey)
     {
        $where += " AND Key" + $i + " = " + $column.Name + " " 
        $i += 1
     }

     $where += ")"

     $where
}

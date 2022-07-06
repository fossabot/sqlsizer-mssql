﻿function Get-DatabaseInfo
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [bool]$MeasureSize,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $sql = "SELECT 
	tables.TABLE_SCHEMA as [schema],
	tables.TABLE_NAME as [table],
	OBJECTPROPERTY(OBJECT_ID(tables.TABLE_SCHEMA + '.' + tables.TABLE_NAME), 	'TableHasIdentity') as [identity],
	CASE 
		WHEN t.history_table_name IS NOT NULL 
			THEN 1
			ELSE 0
	END as [is_historic],
	t.table_name as [history_owner],
	t.[schema] as [history_owner_schema]
FROM INFORMATION_SCHEMA.TABLES tables
LEFT JOIN 
	(	SELECT t.name as table_name, OBJECT_NAME(history_table_id) as history_table_name, s.[name] as [schema]
		FROM sys.tables t
			INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
		WHERE OBJECT_NAME(history_table_id) IS NOT NULL
	) t ON tables.TABLE_NAME = t.history_table_name AND tables.TABLE_SCHEMA = t.[schema]
WHERE tables.TABLE_TYPE = 'BASE TABLE'
ORDER BY [schema], [table]"

    $rows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $result = New-Object -TypeName DatabaseInfo

    $sql = "SELECT
    t.TABLE_SCHEMA [schema],
    t.TABLE_NAME [table],
    c.COLUMN_NAME [column],
    c.DATA_TYPE [dataType],
	c.CHARACTER_MAXIMUM_LENGTH [length],
	row_number() over(PARTITION BY c.TABLE_SCHEMA, c.TABLE_NAME order by c.ORDINAL_POSITION) as [position]
FROM	
	INFORMATION_SCHEMA.COLUMNS c 
	INNER JOIN 	INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cc ON c.COLUMN_NAME = cc.COLUMN_NAME AND c.TABLE_NAME = cc.TABLE_NAME AND c.TABLE_SCHEMA = cc.TABLE_SCHEMA
	INNER JOIN  INFORMATION_SCHEMA.TABLE_CONSTRAINTS t ON t.TABLE_NAME = cc.TABLE_NAME AND t.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
WHERE
	t.CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY 
	c.TABLE_SCHEMA, c.TABLE_NAME, [position]"

    $primaryKeyRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $primaryKeyRowsGrouped = $primaryKeyRows | Group-Object -Property schema, table -AsHashTable -AsString

    $sql = "SELECT
    c.TABLE_SCHEMA [schema], 
    c.TABLE_NAME [table],
    c.COLUMN_NAME [column],
	row_number() over(PARTITION BY c.TABLE_SCHEMA, c.TABLE_NAME order by c.ORDINAL_POSITION) as [position],
    c.DATA_TYPE [dataType],
	c.IS_NULLABLE [isNullable],
	CASE 
		WHEN computed.[isComputed] IS NULL 
			THEN 0 
			ELSE 1
	END as [isComputed],
	CASE 
		WHEN computed.[isComputed] IS NULL 
			THEN NULL
			ELSE computed.definition
	END as [computedDefinition],
	CASE 
		WHEN computed2.generated_always_type <> 0
			THEN 1
			ELSE 0
	END as [isGenerated]
FROM 
    INFORMATION_SCHEMA.COLUMNS c
	LEFT JOIN 
		(SELECT 1 as [isComputed], c.[definition], s.name as [schema], o.name as [table], c.[name] as [column]
		FROM sys.computed_columns c
		INNER JOIN sys.objects o ON o.object_id = c.object_id
		INNER JOIN sys.schemas s ON s.schema_id = o.schema_id) computed 
		ON c.TABLE_SCHEMA = computed.[schema] and c.TABLE_NAME = computed.[table] and c.COLUMN_NAME = computed.[column]
	LEFT JOIN 
		(SELECT c.generated_always_type, s.name as [schema], o.name as [table], c.[name] as [column]
		FROM sys.columns c
		INNER JOIN sys.objects o ON o.object_id = c.object_id
		INNER JOIN sys.schemas s ON s.schema_id = o.schema_id) computed2 
		ON c.TABLE_SCHEMA = computed2.[schema] and c.TABLE_NAME = computed2.[table] and c.COLUMN_NAME = computed2.[column]
ORDER BY 
	c.TABLE_SCHEMA, c.TABLE_NAME, [position]"

    $columnsRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $columnsRowsGrouped = $columnsRows | Group-Object -Property schema, table -AsHashTable -AsString

    $sql = "SELECT  
    [objects].name AS [fk_name],
    [schemas].name AS [fk_schema],
    [tables].name AS [fk_table],
    [columns].name AS [fk_column],
	[columns].is_nullable AS [fk_column_is_nullable],
	[columnsT].name AS [fk_column_data_type],
	[schemas2].name as [schema],
    [tables2].name AS [table],
    [columns2].name AS [column],
	ROW_NUMBER() OVER(PARTITION BY [objects].name ORDER BY [columns2].column_id) as [column_position]
FROM 
    sys.foreign_key_columns [fk]
INNER JOIN sys.objects [objects]
    ON [objects].object_id = [fk].constraint_object_id
INNER JOIN sys.tables [tables]
    ON [tables].object_id = [fk].parent_object_id
INNER JOIN sys.schemas [schemas]
    ON [tables].schema_id = [schemas].schema_id
INNER JOIN sys.columns [columns]
    ON [columns].column_id = [fk].parent_column_id AND [columns].object_id = [tables].object_id
INNER JOIN sys.types [columnsT] 
	ON [columnsT].user_type_id = [columns].user_type_id
INNER JOIN sys.tables [tables2]
    ON [tables2].object_id = [fk].referenced_object_id
INNER JOIN sys.schemas [schemas2]
    ON [tables2].schema_id = [schemas2].schema_id
INNER JOIN sys.columns [columns2]
    ON [columns2].column_id = [fk].referenced_column_id AND [columns2].object_id = [tables2].object_id
ORDER BY 
 [fk_schema], [fk_table], [column_position]"

    $foreignKeyRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $foreignKeyRowsGrouped = $foreignKeyRows | Group-Object -Property fk_schema, fk_table -AsHashTable -AsString

    $sql = "SELECT DISTINCT
	i.[name] as [index], [schemas].[name] as [schema], t.[name] as [table], c.[name] as [column]
FROM 
	sys.objects t
INNER JOIN sys.indexes i 
	ON [t].object_id = [i].object_id
INNER JOIN sys.objects [objects]
    ON [objects].object_id = i.object_id
INNER JOIN sys.tables [tables]
    ON [tables].object_id = [objects].object_id
INNER JOIN sys.schemas [schemas]
    ON [tables].schema_id = [schemas].schema_id
INNER JOIN sys.index_columns ic
	ON ic.object_id = i.object_id and ic.index_id = i.index_id
INNER JOIN sys.columns c 
	ON c.object_id = ic.object_id and c.column_id = ic.column_id
WHERE
	i.is_primary_key = 0 and [schemas].[name] not like 'SqlSizer%'
ORDER BY 
	[schemas].[name], t.[name]"

    $indexesRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $indexesRowsGrouped = $indexesRows | Group-Object -Property schema, table -AsHashTable -AsString

    $sql = "WITH Dependencies ([referenced_type], [referenced_id], [referenced_schema_name],[referenced_entity_name], [referencing_type], [referencing_id], [view_schema_name], [view_name])
    AS
    (
        SELECT DISTINCT o2.[type], d.referenced_id, d.referenced_schema_name, d.referenced_entity_name, o.[type], d.referencing_id, s.name as [view_schema_name], OBJECT_NAME(o.object_id) as [view_name]
        FROM sys.sql_expression_dependencies  d
        INNER JOIN sys.objects AS o ON d.referencing_id = o.object_id  and o.type IN ('V')
        INNER JOIN sys.objects AS o2 ON d.referenced_id = o2.object_id
        LEFT JOIN sys.schemas s ON s.schema_id = o.schema_id
        WHERE o2.[type] IN ('U', 'V')
        
        UNION ALL
    
        SELECT o2.[type], ed.referenced_id, ed.referenced_schema_name, ed.referenced_entity_name, d.referencing_type, d.referencing_id, d.view_schema_name, d.view_name
        FROM Dependencies d 
        INNER JOIN sys.sql_expression_dependencies ed ON d.referenced_id = ed.referencing_id
        INNER JOIN sys.objects AS o ON ed.referencing_id = o.object_id  and o.type IN ('V')
        INNER JOIN sys.objects AS o2 ON ed.referenced_id = o2.object_id
        INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
    
    )
    SELECT DISTINCT d.*
    FROM Dependencies d
    ORDER BY d.referenced_schema_name, d.referenced_entity_name"

    $depRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    $depRowsGrouped = $depRows | Group-Object -Property referenced_schema_name, referenced_entity_name -AsHashTable -AsString

    $sql = "SELECT 
    TABLE_SCHEMA as [schema],
    TABLE_NAME as [view]
FROM 
    INFORMATION_SCHEMA.VIEWS
ORDER BY 
	TABLE_SCHEMA"
    
    $viewsInfoRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    $sql = "select s.[name]
    from sys.schemas s"

    $schemasRows = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    if ($true -eq $MeasureSize)
    {
        $statsRows = Invoke-SqlcmdEx -Sql ("EXEC sp_spaceused") -Database $Database -ConnectionInfo $ConnectionInfo
        $result.DatabaseSize = $statsRows[0]["database_size"]
    }

    foreach ($row in $viewsInfoRows)
    {
        $view = New-Object -TypeName ViewInfo
        $view.SchemaName = $row["schema"]
        $view.ViewName = $row["view"]
        $result.Views += $view
    }

    foreach ($row in $rows)
    {
        $table = New-Object -TypeName TableInfo
        $table.SchemaName = $row["schema"]
        $table.TableName = $row["table"]
        $table.IsIdentity = $row["identity"]
        $table.IsHistoric = $row["is_historic"]
        $table.HistoryOwner = $row["history_owner"]
        $table.HistoryOwnerSchema = $row["history_owner_schema"]
        $table.IsReferencedBy = @()

        if ($true -eq $MeasureSize)
        {
            $statsRow = Invoke-SqlcmdEx -Sql ("EXEC sp_spaceused [" + $table.SchemaName + "." + $table.TableName + "]") -Database $Database -ConnectionInfo $ConnectionInfo
            $stats = New-Object -TypeName TableStatistics

            $stats.Rows = $statsRow["rows"]
            $stats.DataKB = $statsRow["data"].Trim(' KB')
            $stats.IndexSize = $statsRow["index_size"].Trim(' KB')
            $stats.UnusedKB = $statsRow["unused"].Trim(' KB')
            $stats.ReservedKB = $statsRow["reserved"].Trim(' KB')

            $table.Statistics = $stats
        }

        $key = $table.SchemaName + ", " + $table.TableName
        $tableKey = $primaryKeyRowsGrouped[$key]

        foreach ($tableKeyColumn in $tableKey)
        {
            $pkColumn = New-Object -TypeName ColumnInfo
            $pkColumn.Name = $tableKeyColumn["column"]
            $pkColumn.DataType = $tableKeyColumn["dataType"]
            $pkColumn.Length = $tableKeyColumn["length"]
            $pkColumn.IsNullable = $false
            $pkColumn.IsComputed = $false
            $table.PrimaryKey += $pkColumn
        }

        $tableColumns = $columnsRowsGrouped[$key]

        foreach ($tableColumn in $tableColumns)
        {
            $column = New-Object -TypeName ColumnInfo
            $column.Name = $tableColumn["column"]
            $column.DataType = $tableColumn["dataType"]
            $column.IsComputed = $tableColumn["isComputed"]
            $column.IsGenerated = $tableColumn["isGenerated"]
            $column.IsNullable = $tableColumn["isNullable"] -eq "YES"
            $column.ComputedDefinition = $tableColumn["computedDefinition"]
            $table.Columns += $column
        }

        $tableForeignKeys = $foreignKeyRowsGrouped[$key]

        $tableForeignKeysGrouped = $tableForeignKeys | Group-Object -Property fk_name

        foreach ($item in $tableForeignKeysGrouped)
        {
            $fk = New-Object -TypeName TableFk
            $fk.Name = $item.Name

            foreach ($column in $item.Group)
            {
                $fk.Schema = $column["schema"]
                $fk.Table = $column["table"]
                $fk.FkSchema = $column["fk_schema"]
                $fk.FkTable = $column["fk_table"]

                $fkColumn = New-Object -TypeName ColumnInfo
                $fkColumn.Name = $column["fk_column"]
                $fkColumn.DataType = $column["fk_column_data_type"]
                $fkColumn.IsNullable = $column["fk_column_is_nullable"]
                $fkColumn.IsComputed = $false

                $baseColumn = New-Object -TypeName ColumnInfo
                $baseColumn.Name = $column["column"]
                $baseColumn.DataType = $column["fk_column_data_type"]
                $baseColumn.IsNullable = $false
                $baseColumn.IsComputed = $false

                $fk.Columns += $baseColumn
                $fk.FkColumns += $fkColumn
            }

            $table.ForeignKeys += $fk
        }

        if ($null -ne $indexesRowsGrouped)
        {
            $indexesForTable = $indexesRowsGrouped[$key]
            $indexesForTableGrouped = $indexesForTable | Group-Object -Property index

            foreach ($item in $indexesForTableGrouped)
            {
                $index = New-Object -TypeName Index
                $index.Name = $item.Name

                foreach ($column in $item.Group)
                {
                    $index.Columns += $column["column"]
                }

                $table.Indexes += $index
            }
        }

        if ($null -ne $depRowsGrouped)
        {
            $viewsForTable = $depRowsGrouped[$key]
            $table.Views = @()

            foreach ($item in $viewsForTable)
            {
                $view = New-Object ViewInfo
                $view.SchemaName = $item.view_schema_name
                $view.ViewName = $item.view_name
                $table.Views += $view
            }
        }

        $result.Tables += $table
    }

    $primaryKeyMaxSize = 0

    $tablesGrouped = @{}
    foreach ($table in $result.Tables)
    {
        $tablesGrouped[$table.SchemaName + ", " + $table.TableName] = $table
    }

    $tablesGroupedByHistory = $result.Tables | Group-Object -Property HistoryOwnerSchema, HistoryOwner

    foreach ($table in $result.Tables)
    {
        if ($table.PrimaryKey.Count -gt $primaryKeyMaxSize)
        {
            $primaryKeyMaxSize = $table.PrimaryKey.Count
        }

        $table.HasHistory = $false
        if ($null -ne $tablesGroupedByHistory[$table.SchemaName + ", " + $table.TableName])
        {
            $table.HasHistory = $true
        }

        foreach ($fk in $table.ForeignKeys)
        {
            $schema = $fk.Schema
            $tableName = $fk.Table

            $primaryTable = $tablesGrouped[$schema + ", " + $tableName]

            if ($primaryTable.IsReferencedBy.Contains($table) -eq $false)
            {
                $primaryTable.IsReferencedBy += $table
            }

        }
    }

    $result.PrimaryKeyMaxSize = $primaryKeyMaxSize

    foreach ($row in $schemasRows)
    {
        $result.AllSchemas += $row.Name
    }

    return $result
}


﻿function Get-ColumnValue
{
    param 
    (
        [string]$ColumnName,
        [string]$DataType,
        [string]$Prefix,
        [bool]$ConvertBit,
        [bool]$Conversion
    )

    if ($Conversion -eq $false)
    {
        return "$($Prefix)[" + $ColumnName + "]"    
    }

    if ($DataType -in @('hierarchyid', 'geography', 'xml'))
    {
        return "CONVERT(nvarchar(max), " + $Prefix + $ColumnName + ")"        
    }
    else 
    {
        if ($ConvertBit -and ($DataType -eq 'bit'))
        {
            return "CONVERT(char(1), $Prefix[" + $ColumnName + "])"           
        }
        else
        {
            return "$($Prefix)[" + $ColumnName + "]"    
        }
    }
}

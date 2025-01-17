enum Color
{
    Red = 1
    Green = 2
    Yellow = 3
    Blue = 4
    Purple = 5
}

class ColorMap
{
    [ColorItem[]]$Items
}

class ColorItem
{
    [string]$SchemaName
    [string]$TableName
    [ForcedColor]$ForcedColor
    [Condition]$Condition
}

class ForcedColor
{
    [Color]$Color
}

class Condition
{
    [int]$Top = -1
    [string]$SourceSchemaName = ""
    [string]$SourceTableName = ""
    [int]$MaxDepth = -1
    [string]$FkName = ""
}

class Query
{
    [Color]$Color
    [string]$Schema
    [string]$Table
    [string[]]$KeyColumns
    [string]$Where
    [int]$Top
    [string]$OrderBy
}
class DatabaseInfo
{
    [TableInfo[]]$Tables
    [ViewInfo[]]$Views
    [string[]]$AllSchemas
    [int]$PrimaryKeyMaxSize
    [string]$DatabaseSize
}

class TableInfo2
{
    [string]$SchemaName
    [string]$TableName

    static [bool] IsIgnored([string] $schemaName, [string] $tableName, [TableInfo2[]] $ignoredTables)
    {
        $result = $false

        foreach ($ignoredTable in $ignoredTables)
        {
            if (($ignoredTable.SchemaName -eq $schemaName) -and ($ignoredTable.TableName -eq $tableName))
            {
                $result = $true
                break
            }
        }

        return $result
    }

    [string] ToString() {
        return "$($this.SchemaName).$($this.TableName)"
    }
}

class TableInfo2WithColor
{
    [string]$SchemaName
    [string]$TableName
    [Color]$Color
}

class SubsettingTableResult
{
    [string]$SchemaName
    [string]$TableName
    [long]$RowCount
}

class SubsettingProcess
{
    [long]$ToProcess
    [long]$Processed
}

class TableStatistics
{
    [long]$Rows
    [long]$ReservedKB
    [long]$DataKB
    [long]$IndexSize
    [long]$UnusedKB

    [string] ToString() {
        return "$($this.Rows) rows  => [$($this.DataKB) used of $($this.ReservedKB) reserved KB, $($this.IndexSize) index KB]"
    }
}

class ViewInfo
{
    [string]$SchemaName
    [string]$ViewName
}

class TableInfo
{
    [int]$Id
    [string]$SchemaName
    [string]$TableName
    [bool]$IsIdentity
    [bool]$IsHistoric
    [bool]$HasHistory
    [string]$HistoryOwner
    [string]$HistoryOwnerSchema

    [ColumnInfo[]]$PrimaryKey
    [ColumnInfo[]]$Columns

    [Tablefk[]]$ForeignKeys
    [TableInfo[]]$IsReferencedBy

    [ViewInfo[]]$Views

    [string[]]$Triggers

    [TableStatistics]$Statistics

    [Index[]]$Indexes

    [string] ToString() {
        return "$($this.SchemaName).$($this.TableName)"
    }
}

class Index 
{
    [string]$Name
    [string[]]$Columns
}

class ColumnInfo
{
    [string]$Name
    [string]$DataType
    [string]$Length
    [bool]$IsNullable
    [bool]$IsComputed
    [bool]$IsGenerated
    [string]$ComputedDefinition

    [string] ToString() {
        return $this.Name;
    }
}


class TableFk
{
    [int]$Id
    [string]$Name
    [string]$FkSchema
    [string]$FkTable

    [string]$Schema
    [string]$Table

    [ColumnInfo[]]$FkColumns
    [ColumnInfo[]]$Columns
}

class SqlConnectionStatistics
{
    [int]$LogicalReads
}

class SqlConnectionInfo
{
    [string]$Server
    [System.Management.Automation.PSCredential]$Credential
    [string]$AccessToken = $null
    [bool]$EncryptConnection = $false
    [SqlConnectionStatistics]$Statistics
}

class TableFile
{
    [string]$FileId
    [SubsettingTableResult]$TableContent
}

class Structure
{
    [DatabaseInfo] $DatabaseInfo
    [System.Collections.Generic.Dictionary[String, ColumnInfo[]]] $Signatures
    [System.Collections.Generic.Dictionary[TableInfo, String]] $Tables

    Structure(
        [DatabaseInfo]$DatabaseInfo
    )
    {
        $this.DatabaseInfo = $DatabaseInfo
        $this.Signatures = New-Object "System.Collections.Generic.Dictionary[[string], ColumnInfo[]]"
        $this.Tables = New-Object "System.Collections.Generic.Dictionary[[TableInfo], [string]]"

        foreach ($table in $this.DatabaseInfo.Tables) {

            if ($table.PrimaryKey.Count -eq 0)
            {
                continue
            }

            $signature = $this.GetTablePrimaryKeySignature($table)
            $this.Tables[$table] = $signature

            if ($this.Signatures.ContainsKey($signature) -eq $false)
            {
                $this.Signatures.Add($signature, $table.PrimaryKey)
            }
        }
    }

    [string] GetProcessingName([string] $Signature) {
        return "SqlSizer.Processing" + $Signature
    }

    [string] GetSliceName([string] $Signature) {
        return "SqlSizer.Slice" + $Signature
    }

    [string] GetTablePrimaryKeySignature([TableInfo]$Table) {
        $result = ""
        foreach ($pkColumn in $Table.PrimaryKey)
        {
            $result += "__" + $pkColumn.DataType
            if (($null -ne $pkColumn.Length) -and ("" -ne $pkColumn.Length))
            {
                $result += "_" + $pkColumn.Length
            }
        }
        return $result
    }
}
# SIG # Begin signature block
# MIIojQYJKoZIhvcNAQcCoIIofjCCKHoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB9jL1yLrCpam98
# IloXh+o5JCw6BLdx5l/JKc5n39kyFqCCIL8wggXJMIIEsaADAgECAhAbtY8lKt8j
# AEkoya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQK
# ExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5l
# dHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkG
# A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAl
# BgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMb
# Q2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7XGeMycxca6mR5rlC
# 5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Va
# qp3cKcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ
# 0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8DikSiJucBb+R3Z5yet
# /5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cWKtvMrTscpIfcRnNe
# GWJoRVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcV
# WiNoidQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpneLO/lv403L3nUlbl
# s+V1e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZb
# MI28iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc5SwlFcieLnhO+Nqc
# noYsylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5CAKT41v4wLsfSRvbl
# jnX98sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVPORa5sWOd/7cCAwEA
# AaOCAT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLahVDkCw6A/joq8
# +tT4HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1Ud
# DwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8vY3JsLmNlcnR1bS5w
# bC9jdG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUFBzABhhxodHRwOi8v
# c3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVodHRwOi8vcmVwb3Np
# dG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQG
# CCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEM
# BQADggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1
# BXqxC/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOriY/1B9ZN9DbxdkjuR
# mmW60F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulNndrnQ/tjUoCFBMQl
# lVXwfqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjs
# NhI9qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads0h5YbBRRfopUofbv
# n3l6XYGaFpAP4bvxSgD5+d2+7arszgowggaVMIIEfaADAgECAhEA8WQljAm24nvi
# DjJgjkv0qDANBgkqhkiG9w0BAQwFADBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMY
# QXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0
# YW1waW5nIDIwMjEgQ0EwHhcNMjEwNTE5MDU0MjQ2WhcNMzIwNTE4MDU0MjQ2WjBQ
# MQswCQYDVQQGEwJQTDEhMB8GA1UECgwYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEu
# MR4wHAYDVQQDDBVDZXJ0dW0gVGltZXN0YW1wIDIwMjEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDVYb6AAL3dhGPuEmWYHXhUi0b6xpEWGro9Hny+NBj2
# 6L94gmI8kONVYdu2Cz9Bftkiyvk4+3MFDrkovZZQ8WDcmGXltX4xAwPAcjXEbXgE
# Z0exEP5Ae2bkwKlTiyUXCaq0D9JEaK5t4Kq7rH7rndKd5kX7KARcMFWEN+ikV1cg
# GlKgqmJSTk0Bvbgbc67oolIhtohcEktZZFut5VJxTJ1OKsRR3FUmN+4QrAk0RIv4
# dw2Z4sWilqbdBaBS/5hqLt58sptiORkxnijr33VnviLP2+wbWyQM5k/AgrKj8lk6
# A5C8V/dShj6l/TqqRMykGAKOmi6CcvGbUDibPKkjlxlALd4mHLFujWoE91GicKUK
# fVkLsFqplb/dPPXQjw2TCmZbAegDQlsAppndi9UUZxHvPcryyy0Eyh1y4Gn7Xv1v
# EwnwBisZjB72My8kzUQ0gjxP26vhBkvF2Cic16nVAHxyGOPm0Y0v7lFmcSyYVWg1
# J56YZb+QAJZCL7BJ9CBSJpAXNGxcNURN0baABlZTHn3bbBPOBhOSY9vbGwL34nOm
# TFpRG5mP6HQVXc/EO9cj856a9aueDGyz2hclMIZijGEa5rwacGtPw1HzWpgNAOI2
# 4ChDBRQ8YmD23IN1rmLlzCMsRZ9wFYIvNDtMJVMSQgC0+XQBFPOe69kPwxgPNN4C
# CwIDAQABo4IBYjCCAV4wDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUxUcSTnJXtkQU
# a4hxGhSsMbk/uggwHwYDVR0jBBgwFoAUvlQCL79AbHNDzqwJJU6eQ0Qa7uAwDgYD
# VR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMDMGA1UdHwQsMCow
# KKAmoCSGImh0dHA6Ly9jcmwuY2VydHVtLnBsL2N0c2NhMjAyMS5jcmwwbwYIKwYB
# BQUHAQEEYzBhMCgGCCsGAQUFBzABhhxodHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0u
# Y29tMDUGCCsGAQUFBzAChilodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3Rz
# Y2EyMDIxLmNlcjBABgNVHSAEOTA3MDUGCyqEaAGG9ncCBQELMCYwJAYIKwYBBQUH
# AgEWGGh0dHA6Ly93d3cuY2VydHVtLnBsL0NQUzANBgkqhkiG9w0BAQwFAAOCAgEA
# N3PMMLfCX4nmqnSsHU2rZhE/dkqrdSYLvI3U9i49hxs+i+9oo5mJl4urPLZJ0xIz
# 6B7CHFBNW9dFwgahnFMXiT7QnPuZ5CAwfL/9CfsAL3XdnS0AWll+7ISomRo8d51b
# fpHHt3P3jx9C6Imh1A73JSp90Cq0NqPqnEflrVxYX+sYa2SO9vGsRMYshU7uzE1V
# 5cYWWoFUMaDHpwQuH4DNXiZO6D7f8QGWnXNHXu6S3SlaYDG4Yox7SIW1tQv0jskm
# F1vdNfoxVAymQGRdNLsGzAXn6OPAUiw1xQ6M1qpjK4UnKTUiFJfvgDXbT1cvrYsJ
# rybB/41so+DsAt0yjKxbpS5iP7SpxyHsnch0VcI54sIf0K66f4LJGocBpDTKbU1A
# Oq3OvHbVqI7Vwqs+TGCu7TKqrTL2NQTRDAxHkso7FtH841R2A2lvYSFDfGx87B1N
# vPWYU3mY/GRsmQx+RgA8Pl/7Nvp7ZAY+AU8mDVr2KXrFP4unpswVBQlHxtIOxz6j
# eyfdLIG2oFJll3ipcASHav/obYEt/F1GRlJ+mFIQtKDadxUBmfhRlgIgYvEEtuJG
# ERHuxfMD26jLmixu8STPGRRco+R5Bdgu+qFbnymKfuXO4sR96JYqaOOxilcN/xr7
# ms13iS7wqANpd2txKZjPy3wdWniVQcuL7yCXD2uEc20wgga5MIIEoaADAgECAhEA
# maOACiZVO2Wr3G6EprPqOTANBgkqhkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwx
# IjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNl
# cnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRy
# dXN0ZWQgTmV0d29yayBDQSAyMB4XDTIxMDUxOTA1MzIxOFoXDTM2MDUxODA1MzIx
# OFowVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMg
# Uy5BLjEkMCIGA1UEAxMbQ2VydHVtIENvZGUgU2lnbmluZyAyMDIxIENBMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnSPPBDAjO8FGLOczcz5jXXp1ur5c
# Tbq96y34vuTmflN4mSAfgLKTvggv24/rWiVGzGxT9YEASVMw1Aj8ewTS4IndU8s7
# VS5+djSoMcbvIKck6+hI1shsylP4JyLvmxwLHtSworV9wmjhNd627h27a8RdrT1P
# H9ud0IF+njvMk2xqbNTIPsnWtw3E7DmDoUmDQiYi/ucJ42fcHqBkbbxYDB7SYOou
# u9Tj1yHIohzuC8KNqfcYf7Z4/iZgkBJ+UFNDcc6zokZ2uJIxWgPWXMEmhu1gMXgv
# 8aGUsRdaCtVD2bSlbfsq7BiqljjaCun+RJgTgFRCtsuAEw0pG9+FA+yQN9n/kZtM
# LK+Wo837Q4QOZgYqVWQ4x6cM7/G0yswg1ElLlJj6NYKLw9EcBXE7TF3HybZtYvj9
# lDV2nT8mFSkcSkAExzd4prHwYjUXTeZIlVXqj+eaYqoMTpMrfh5MCAOIG5knN4Q/
# JHuurfTI5XDYO962WZayx7ACFf5ydJpoEowSP07YaBiQ8nXpDkNrUA9g7qf/rCkK
# bWpQ5boufUnq1UiYPIAHlezf4muJqxqIns/kqld6JVX8cixbd6PzkDpwZo4SlADa
# Ci2JSplKShBSND36E/ENVv8urPS0yOnpG4tIoBGxVCARPCg1BnyMJ4rBJAcOSnAW
# d18Jx5n858JSqPECAwEAAaOCAVUwggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0O
# BBYEFN10XUwA23ufoHTKsW73PMAywHDNMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8
# +tT4HKbROg79MA4GA1UdDwEB/wQEAwIBBjATBgNVHSUEDDAKBggrBgEFBQcDAzAw
# BgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3Js
# MGwGCCsGAQUFBwEBBGAwXjAoBggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3At
# Y2VydHVtLmNvbTAyBggrBgEFBQcwAoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVt
# LnBsL2N0bmNhMi5jZXIwOQYDVR0gBDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEW
# GGh0dHA6Ly93d3cuY2VydHVtLnBsL0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAdYhY
# D+WPUCiaU58Q7EP89DttyZqGYn2XRDhJkL6P+/T0IPZyxfxiXumYlARMgwRzLRUS
# tJl490L94C9LGF3vjzzH8Jq3iR74BRlkO18J3zIdmCKQa5LyZ48IfICJTZVJeChD
# UyuQy6rGDxLUUAsO0eqeLNhLVsgw6/zOfImNlARKn1FP7o0fTbj8ipNGxHBIutiR
# sWrhWM2f8pXdd3x2mbJCKKtl2s42g9KUJHEIiLni9ByoqIUul4GblLQigO0ugh7b
# WRLDm0CdY9rNLqyA3ahe8WlxVWkxyrQLjH8ItI17RdySaYayX3PhRSC4Am1/7mAT
# wZWwSD+B7eMcZNhpn8zJ+6MTyE6YoEBSRVrs0zFFIHUR08Wk0ikSf+lIe5Iv6RY3
# /bFAEloMU+vUBfSouCReZwSLo8WdrDlPXtR0gicDnytO7eZ5827NS2x7gCBibESY
# kOh1/w1tVxTpV2Na3PR7nxYVlPu1JPoRZCbH86gc96UTvuWiOruWmyOEMLOGGniR
# +x+zPF/2DaGgK2W1eEJfo2qyrBNPvF7wuAyQfiFXLwvWHamoYtPZo0LHuH8X3n9C
# +xN4YaNjt2ywzOr+tKyEVAotnyU9vyEVOaIYMk3IeBrmFnn0gbKeTTyYeEEUz/Qw
# t4HOUBCrW602NCmvO1nm+/80nLy5r0AZvCQxaQ4wgga5MIIEoaADAgECAhEA5/9p
# xzs1zkuRJth0fGilhzANBgkqhkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwxIjAg
# BgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1
# bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0
# ZWQgTmV0d29yayBDQSAyMB4XDTIxMDUxOTA1MzIwN1oXDTM2MDUxODA1MzIwN1ow
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBMIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA6RIfBDXtuV16xaaVQb6KZX9Od9FtJXXT
# Zo7b+GEof3+3g0ChWiKnO7R4+6MfrvLyLCWZa6GpFHjEt4t0/GiUQvnkLOBRdBqr
# 5DOvlmTvJJs2X8ZmWgWJjC7PBZLYBWAs8sJl3kNXxBMX5XntjqWx1ZOuuXl0R4x+
# zGGSMzZ45dpvB8vLpQfZkfMC/1tL9KYyjU+htLH68dZJPtzhqLBVG+8ljZ1ZFilO
# KksS79epCeqFSeAUm2eMTGpOiS3gfLM6yvb8Bg6bxg5yglDGC9zbr4sB9ceIGRtC
# QF1N8dqTgM/dSViiUgJkcv5dLNJeWxGCqJYPgzKlYZTgDXfGIeZpEFmjBLwURP5A
# BsyKoFocMzdjrCiFbTvJn+bD1kq78qZUgAQGGtd6zGJ88H4NPJ5Y2R4IargiWAmv
# 8RyvWnHr/VA+2PrrK9eXe5q7M88YRdSTq9TKbqdnITUgZcjjm4ZUjteq8K331a4P
# 0s2in0p3UubMEYa/G5w6jSWPUzchGLwWKYBfeSu6dIOC4LkeAPvmdZxSB1lWOb9H
# zVWZoM8Q/blaP4LWt6JxjkI9yQsYGMdCqwl7uMnPUIlcExS1mzXRxUowQref/EPa
# S7kYVaHHQrp4XB7nTEtQhkP0Z9Puz/n8zIFnUSnxDof4Yy650PAXSYmK2TcbyDoT
# Nmmt8xAxzcMCAwEAAaOCAVUwggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FL5UAi+/QGxzQ86sCSVOnkNEGu7gMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8+tT4
# HKbROg79MA4GA1UdDwEB/wQEAwIBBjATBgNVHSUEDDAKBggrBgEFBQcDCDAwBgNV
# HR8EKTAnMCWgI6Ahhh9odHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3JsMGwG
# CCsGAQUFBwEBBGAwXjAoBggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2Vy
# dHVtLmNvbTAyBggrBgEFBQcwAoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBs
# L2N0bmNhMi5jZXIwOQYDVR0gBDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEWGGh0
# dHA6Ly93d3cuY2VydHVtLnBsL0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAuJNZd8lM
# Ff2UBwigp3qgLPBBk58BFCS3Q6aJDf3TISoytK0eal/JyCB88aUEd0wMNiEcNVMb
# K9j5Yht2whaknUE1G32k6uld7wcxHmw67vUBY6pSp8QhdodY4SzRRaZWzyYlviUp
# yU4dXyhKhHSncYJfa1U75cXxCe3sTp9uTBm3f8Bj8LkpjMUSVTtMJ6oEu5JqCYzR
# fc6nnoRUgwz/GVZFoOBGdrSEtDN7mZgcka/tS5MI47fALVvN5lZ2U8k7Dm/hTX8C
# WOw0uBZloZEW4HB0Xra3qE4qzzq/6M8gyoU/DE0k3+i7bYOrOk/7tPJg1sOhytOG
# UQ30PbG++0FfJioDuOFhj99b151SqFlSaRQYz74y/P2XJP+cF19oqozmi0rRTkfy
# EJIvhIZ+M5XIFZttmVQgTxfpfJwMFFEoQrSrklOxpmSygppsUDJEoliC05vBLVQ+
# gMZyYaKvBJ4YxBMlKH5ZHkRdloRYlUDplk8GUa+OCMVhpDSQurU6K1ua5dmZftnv
# SSz2H96UrQDzA6DyiI1V3ejVtvn2azVAXg6NnjmuRZ+wa7Pxy0H3+V4K4rOTHlG3
# VYA6xfLsTunCz72T6Ot4+tkrDYOeaU1pPX1CBfYj6EW2+ELq46GP8KCNUQDirWLU
# 4nOmgCat7vN0SD6RlwUiSsMeCiQDmZwgwrUwggbbMIIEw6ADAgECAhBilKjY27T0
# hE7tepqKLE3VMA0GCSqGSIb3DQEBCwUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQK
# ExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2Rl
# IFNpZ25pbmcgMjAyMSBDQTAeFw0yMjA3MDYxNzU5MThaFw0yMzA3MDYxNzU5MTda
# MIGAMQswCQYDVQQGEwJQTDESMBAGA1UECAwJcG9tb3Jza2llMR0wGwYDVQQKDBRN
# YXJjaW4gR2/FgsSZYmlvd3NraTEdMBsGA1UEAwwUTWFyY2luIEdvxYLEmWJpb3dz
# a2kxHzAdBgkqhkiG9w0BCQEWEHhvcm11c0BnbWFpbC5jb20wggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQCq9lrlEX8hYH940cwMVCfAeDBpdqYB3Bp7043o
# gS+scBpVs2IhdbnElFvDJILpVXPlk9sjVyvkpthfCMmc7JAdEfr2X6eYTzJfBqMg
# e6BLbsLpxCQyKFAlmrUTL1Twk+/k5S9Pn2bj50N6Kp2PgKk/xE/CJvKFTtDHCZ3a
# mkX7aNZO2pNzaOLtVv9u+IbuA3pWAMXm/ZqTXhZ2H5AK7qGLIDfTVYQ/RTDq3XMB
# vInO7UBj6DF2vQvKnYMnlxEkq4EpHB16utk8BFaCux79gO93v4Zccz6l+VcFJGZF
# dY8AsEMI9JBiDxc1VKceIK7mFrieW7R8B7WZQeyIaUAcLkJBdF7VpieiFs0dkSss
# sRh7dgWGwQkwxDFcKTOZiz+CpLsDnKSS9rICglarl9vV/aD6aqkM3iB4bG8rwJpa
# 38UBVM+vdCXg2C693dh6cQ+4854iXA2quLH/28XbalNWSAFwCNShKwegelVkKHrF
# sXTw10k25ocP+3fGnVGBocVonFGNFafTe69qBLC+4QO94bHHL3iQXh6L1A1LdslW
# GcTDXwQPmveHdoFw8uHT32dQpk+4n0N/ApYJA1mVMXpI4bcftVj52E+BeErhp3ig
# yJfSZ0c7besRtFEyDHC4MxOTay5WinSCz1xv6j+FUSUcoxCYHQ9SMLwH03QGBmly
# 18+jvQIDAQABo4IBeDCCAXQwDAYDVR0TAQH/BAIwADA9BgNVHR8ENjA0MDKgMKAu
# hixodHRwOi8vY2NzY2EyMDIxLmNybC5jZXJ0dW0ucGwvY2NzY2EyMDIxLmNybDBz
# BggrBgEFBQcBAQRnMGUwLAYIKwYBBQUHMAGGIGh0dHA6Ly9jY3NjYTIwMjEub2Nz
# cC1jZXJ0dW0uY29tMDUGCCsGAQUFBzAChilodHRwOi8vcmVwb3NpdG9yeS5jZXJ0
# dW0ucGwvY2NzY2EyMDIxLmNlcjAfBgNVHSMEGDAWgBTddF1MANt7n6B0yrFu9zzA
# MsBwzTAdBgNVHQ4EFgQUm6OFYnNgZqHTNTZrAFuDdfzdFZQwSwYDVR0gBEQwQjAI
# BgZngQwBBAEwNgYLKoRoAYb2dwIFAQQwJzAlBggrBgEFBQcCARYZaHR0cHM6Ly93
# d3cuY2VydHVtLnBsL0NQUzATBgNVHSUEDDAKBggrBgEFBQcDAzAOBgNVHQ8BAf8E
# BAMCB4AwDQYJKoZIhvcNAQELBQADggIBAA2deC7SIrFHZ2hEQ/DhzqWzDGWO85aI
# u2lbj9Hrns73IjOZdEv9cui3cECsgvBKC5vCJnUluRy/a4C5nQ4QGZZhag3/jq7H
# DN6ziLzmP2bNFZkWOXDp+h7e+tD7z7HQUh6HT4Wd8wkwEllGmpH/gCN3EQZBKs6r
# WEeC+PvUYS8g05AiACnUWMwYZjQBls4iOolvRMJ8cTUfCcVbGHbKXIG+8FSiNCBQ
# 2dCc1yKLWoYtfrQB4Evj11l633wuoxt2a+2XTWp8WEw5+MMk9dXzbk9TCQzAjqbr
# 7SLJ10HscVbFaL0s3/+MLWikKeJ8nJII60kEFJBUU0+cp8hACwYRLONqPM2OtVmi
# iNo1o2XiwACxQaKCIhCtIcnv1KnMRHNqu+g4rm/B+xxTDt/nyLBQ2TGlwdyQZqGV
# uF/Al+OZ7++lXbepXZR/+ls0tSdy3X1udZGzsG8vGS2ZMs+nGsHLH5nohzM2PcN2
# i+OfYu8XixJ+ewXw2TL4txduC6ABAOg9gjP77witvii+Z82zYWqtSrH5e0Aw3YYP
# PLc/KrB42OjxBHMHnXAfWBHPchLjGizZsU44GtIYuciC+xbF2f7an+ZJi8FEsju6
# +Ws4pRGEtT0ODucvlFlEQ0O7Sh+gmzxOULkN+ZA3xmlTEM4hMTltUECsH9DdEd/d
# 3NfOB4BAK9G1MYIHJDCCByACAQEwajBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMY
# QXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gQ29kZSBT
# aWduaW5nIDIwMjEgQ0ECEGKUqNjbtPSETu16moosTdUwDQYJYIZIAWUDBAIBBQCg
# gYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0B
# CQQxIgQg10d1b1ZIwiV3p/MBHQWIfIc3LPdXVdyeuyt58VgXg48wDQYJKoZIhvcN
# AQEBBQAEggIAcRxV7B0W9k4PsGQVz6O3geHAfkqYonG2mQ3OqGHTUarLWfe2Hy2L
# 5w4epe7Tdw7Qz2MbwE4zSkNcZW4U5tpnB1Mvrj3VbneKvA/3Ub1hrE823cZFo9jP
# u6wqhlJ5y25jnmiuo+cS36Lg1pUP8xsA/O9Yu2FVVDdCkdYRvYdG7AqcDrIhRVZ8
# g9pv0BOg0nOQy7nybNLWZHcYlitZAO9q5DalrT+7mZr6aeJxO6mb5U2unZu5MH9r
# JWLRxzS/t5t5wWfNoF78OmXFG6LkSVAw5tTNAL1LrRi5TC4d/6icyY6NGbV9y6Z9
# 50ij3jK+mxmKrKDPdgfIwWKUTLMuN+v2lCEkYbTVsFalhSOxG50phK++w+P1Nohl
# Qgh6zmI17QPE82GQNK7veiE1a1HOCm/InryV8QVh/LYu4IBgEfFPHujKYZz52IoF
# fHxQdjnqpEVMfEXG+4Kq7a8py2UGTnA5WlmhpEmaKLD+zFWItMziNvdV7PajG5BE
# aBWzUaszFaghLnvlBgCENBuSWWOTqNokJksZ3trSupqtVzyGDIqPRJ59DZM5+phu
# CImJLmjCt4z1XicXl3B6k7QAqx26bKPJW9TobZ6ae+fKELagVx5tcH5gP/gZw6xl
# 3jxDkBXM+9E8X3iwONde3v779xBriahpdy5MqKCA9MJ8SqTkXhCvgk6hggQEMIIE
# AAYJKoZIhvcNAQkGMYID8TCCA+0CAQEwazBWMQswCQYDVQQGEwJQTDEhMB8GA1UE
# ChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGlt
# ZXN0YW1waW5nIDIwMjEgQ0ECEQDxZCWMCbbie+IOMmCOS/SoMA0GCWCGSAFlAwQC
# AgUAoIIBVzAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkF
# MQ8XDTIyMDgyOTIwMDIwMlowNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgG1m/6OV3
# K6z2Q7t5rLSOgVh4TyHFVK4TR206Gj4FxdMwPwYJKoZIhvcNAQkEMTIEMKN1c+rO
# i2iuucVF+w0R7A64FGcd7/EjRxPfgty+KmYUFF+aLvrGnvXgAlKCecIhjzCBoAYL
# KoZIhvcNAQkQAgwxgZAwgY0wgYowgYcEFNMRxpUxG4znP9W1Uxis31mK4ZsTMG8w
# WqRYMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1z
# IFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAyMSBDQQIRAPFk
# JYwJtuJ74g4yYI5L9KgwDQYJKoZIhvcNAQEBBQAEggIAZKx5j2n7ELe4JBgTfjms
# G23N9kRHwCHAlps+t1ECaZHwkwn9wUWt0vXrq3sdNAqKtG233aaLiu7PzyMO1X3r
# kDxVhdb/xhzaQB6oci6QxJnpTeXMGhxztUjgvqgfn7jf659I6UlGdP+jPk7yXy5F
# Awzts5fWTkFPmy/iZPK7FUsWoMEC0ZBvPcgz47Jke9u9w/6XezrchqU1tHtelWcv
# ScU9dmiosaZBcBl+j2d4kTXAej1uAQT/247XILqlVDVL9/fDjbTCrvQgiQA141Fr
# dUPlREbQB1iryvJzO43J5p29Zvt9aobuLL312zXC9LRJ/fhdTAYo4cNSPMFOth0q
# TlBAF2W3wMeuz+d/0iOZ5ZkA8NP20OA2QeiNdHSYFxSdaD2ajvy6wGMJ8257wLjl
# kQoy+I1nnZ6FN+W3qAKLLXrUTNuyvdkon3DnPTbf9jDZDsnAcgHwuhHNzfSI1rPb
# Wb9RRvlydg4AtZpMWluazddjXhdhJt0rhjFOa89rz3rMNHUAknnhUr0XKLQnkB1q
# Omup3BI2yPLyZ8inil/oWHjz4yNuLsU55Q2/v8uV2TlC3N5DQ6Al16bBky1fhih+
# +aQMhPu6w/GYHgd1/IWiUAIhCryBTRkzduzdTI2p0yLZPzLMLd5nH7N86FsFXTpA
# HIXx0b8N4VZsIsK9Ano5NkA=
# SIG # End signature block

function New-TableCompare
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Database,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName1,

        [Parameter(Mandatory=$true)]
        [string]$TableName1,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName2,

        [Parameter(Mandatory=$true)]
        [string]$TableName2,

        [Parameter(Mandatory=$false)]
        [DatabaseInfo]$DatabaseInfo = $null,

        [Parameter(Mandatory=$true)]
        [SqlConnectionInfo]$ConnectionInfo
    )

    $info = Get-DatabaseInfoIfNull -Database $Database -Connection $ConnectionInfo -DatabaseInfo $DatabaseInfo

    $table1 = $info.Tables | Where-Object { ($_.SchemaName -eq $SchemaName1) -and ($_.TableName -eq $TableName1) }
    $table2 = $info.Tables | Where-Object { ($_.SchemaName -eq $SchemaName2) -and ($_.TableName -eq $TableName2) }

    if ([string]::Join(',', $table1.Columns) -ne [string]::Join(',', $table2.Columns))
    {
        Write-Output "Tables have different schema."
        return
    }

    $schemaExists = Test-SchemaExists -SchemaName "SqlSizerCompare" -Database $Database -ConnectionInfo $ConnectionInfo
    if ($schemaExists -eq $false)
    {
        $sql = "CREATE SCHEMA SqlSizerCompare"
        $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    }

    $compareId = (New-Guid).ToString().Replace('-', '_')

    $sql = "CREATE TABLE SqlSizerCompare.Comparision_$compareId ("
    foreach ($primaryColumn in $table1.PrimaryKey)
    {
        $sql += $primaryColumn.Name + " " + $primaryColumn.DataType + " NOT NULL, "
    }
    $sql += " [Result] int NOT NULL)"
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    
    $sql = "ALTER TABLE SqlSizerCompare.TableCompare_$compareId ADD PRIMARY KEY " + [string]::Join(",", $table1.PrimaryKey)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    # prepare
    $primary = @()
    $cond = @()
    $cond2 = @()
    $columns = @()
    $columnsOr = @()
    foreach ($primaryColumn in $table1.PrimaryKey)
    {
        $primary += "t." + $primaryColumn
        $cond += "t." + $primaryColumn + " = " + "t2." + $primaryColumn
        $cond2 += "t2." + $primaryColumn  + " IS NULL "
    }

    foreach ($column in $table1.Columns)
    {
        if ($column.DataType -eq 'xml')
        {
            $columns += "((CONVERT(nvarchar(max), t." + $column + ") = CONVERT(nvarchar(max), t2." + $column + ")) or (t.$column is null and t2.$column is null))"
            $columnsOr += "(CONVERT(nvarchar(max), t." + $column + ") <> CONVERT(nvarchar(max), t2." + $column + "))"
        }
        else
        {
            $columns += "((t.$column=t2.$column) or (t.$column is null and t2.$column is null))"
            $columnsOr += "(t.$column <> t2.$column)"
        }
    }

    # only in schema1.table1
    $sql = "INSERT INTO SqlSizerCompare.TableCompare_$compareId SELECT $([string]::Join(",", $primary)), -1 FROM $SchemaName1.$TableName1 t LEFT JOIN  $SchemaName2.$TableName2 t2 ON " + [string]::Join(" and ", $cond) + " WHERE " + [string]::Join(" and ", $cond2)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    # only in schem2.table2
    $sql = "INSERT INTO SqlSizerCompare.TableCompare_$compareId SELECT $([string]::Join(",", $primary)), 1 FROM $SchemaName2.$TableName2 t LEFT JOIN  $SchemaName1.$TableName1 t2 ON " + [string]::Join(" and ", $cond) + " WHERE " + [string]::Join(" and ", $cond2)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo
    
    # same
    $sql = "INSERT INTO SqlSizerCompare.TableCompare_$compareId SELECT $([string]::Join(",", $primary)), 0 FROM $SchemaName1.$TableName2 t INNER JOIN  $SchemaName2.$TableName1 t2 ON " + [string]::Join(" and ", $cond) + " WHERE " + [string]::Join(" and ", $columns)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    # different
    $sql = "INSERT INTO SqlSizerCompare.TableCompare_$compareId SELECT $([string]::Join(",", $primary)), 2 FROM $SchemaName1.$TableName2 t INNER JOIN  $SchemaName2.$TableName1 t2 ON " + [string]::Join(" and ", $cond) + " WHERE " + [string]::Join(" or ", $columnsOr)
    $null = Invoke-SqlcmdEx -Sql $sql -Database $Database -ConnectionInfo $ConnectionInfo

    return $compareId
}
# SIG # Begin signature block
# MIIojQYJKoZIhvcNAQcCoIIofjCCKHoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBRsCJXtRikzVXt
# EfvBLP5D5OUQERddj3aB6y+p3mxct6CCIL8wggXJMIIEsaADAgECAhAbtY8lKt8j
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
# CQQxIgQgjIPbRwQvK7+BSYTk+2Ik3KSR+baGMsV7/S1xl3HC6lYwDQYJKoZIhvcN
# AQEBBQAEggIAkSIsJDTpmD7P1ZImljhEpKg0QWFGV3iKlbPjU5vElee5enCdTEhL
# plJzVy6FI5e7yjUAph16Jw6l+IXedaNNu5/CixZAaJ6eJs+mnPoxJNTZet6PC2PE
# s0axZxfq7OPNgy1PXMxP0JxLNznDdjYI3MAqR4o9L/KNaxRjPg76+IWs3t44E1V9
# scrbTB4LKv8CviDF/t19ZEtqmrjzgN0JoW1ihR00L3wqmzMebgJsH8Lnm8oyXXwc
# vy9QguCHl1UVPOYW8Dq7jMlr2r3nMy76dhGJJLn9o2FyTHhgQOpqZbhQjvdrvjkc
# 65QwM9F46AdVC47DYbLWEzd3KCyhXO8lSuqFxomaSEdtFFgh4a7HUVIyToWR7+L6
# 7Ign8EiaX9kC6abrDgAM2hX0I9ceyInwzrIqA/JE+Je/tgVUwPWogPSINtdVEOT2
# WRA91sZFmPKlbP7FLuDU4ZRImncUx2BKUY2r3DX6D+y0oy2vl3Z7jWigOkN2pSou
# A8VZSSADHb8BpBFPqi4dEICuDOuV4j0WPdHgdIO6dSUIYSF/+PHLtZ5svemrnJvg
# /VexaY+Em34D7gJ8RBS8SV1e70VSrxhUL16WnyVGysJHqoS3RqghdOgrX8bsf29b
# IzC2cUN0kLVSd0c+c6Gc9QccicJHwon4ncWZXlp8rhXp2ElUS/ofPqShggQEMIIE
# AAYJKoZIhvcNAQkGMYID8TCCA+0CAQEwazBWMQswCQYDVQQGEwJQTDEhMB8GA1UE
# ChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGlt
# ZXN0YW1waW5nIDIwMjEgQ0ECEQDxZCWMCbbie+IOMmCOS/SoMA0GCWCGSAFlAwQC
# AgUAoIIBVzAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkF
# MQ8XDTIyMDcyNzIwMzEzN1owNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgG1m/6OV3
# K6z2Q7t5rLSOgVh4TyHFVK4TR206Gj4FxdMwPwYJKoZIhvcNAQkEMTIEMHJRRUyG
# OQluRzCyWp1TtJNYua9DihecbDg4QnK/X3EydiXzG3Afw7IaUM5OLAug9zCBoAYL
# KoZIhvcNAQkQAgwxgZAwgY0wgYowgYcEFNMRxpUxG4znP9W1Uxis31mK4ZsTMG8w
# WqRYMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1z
# IFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAyMSBDQQIRAPFk
# JYwJtuJ74g4yYI5L9KgwDQYJKoZIhvcNAQEBBQAEggIAjtOWOXUkrnN7/IbKGc9a
# 4pmiWJsL30961KOmT/Z2wqfxYnj4cb3khRDAW+1QZ7u3OPO40FomD9LokAn7jMAy
# JUfv+OKxmz+s3DNnEPUtc0a1QrdQLCJFwQ2Cg1bP7LGktCbhCWvfUVem7Wj960Oy
# 2dYFq1ycEdrzAqVCHtTu5Y1vHoRYp6/sZ4EaG/WGGV1++fH2ha2OgFS6/xTZ9CRU
# UmdyimdOp46cZZAuEugKSdyT3NSiI6vRlDZn/aYJotUefKjI6NgEFFfFxQ5wlt87
# bAhY49gAmED6Im6Fu2XBiWOSWIGGQEezJYZ8bHr9MZE/b1Oy5njABZ+NPmvlUgZ7
# UKBKfJRgWrganlWbZZ6AWwUdjWccrUA7ybmDZZ7bquxFFXHzRCUDCDYorpocC3y1
# N/HsL+nqns0Z5WFHfoZ6CuaViSpbFyFe+0fDn1T2ppu09Yhq2c6aJ2SctocnidBv
# gNzzQ//WMRgsjuxlTSEUumBjHJekKmtBu8f6tcbjEs1+ZewTtlBJXdXp2IzsOURa
# H8Fq3VwSXZEk7IursncKEQT/4Pc3bF3XzZGb5OH63yyToE2F9XyfZGgXmNEEjAwd
# D7I/tD6Pmdi6Y8cLHd7c+H602VaFDPwpMyfPGf1MN6sN8T+OSi0U9VT9Qf7prnyQ
# PfppiWSLjxUJdk1CiSTY7Qo=
# SIG # End signature block
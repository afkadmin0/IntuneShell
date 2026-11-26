function Get-IntuneAppInstallSummary
{
    [CmdletBinding()]
    param()

    $uri = 'https://graph.microsoft.com/beta/deviceManagement/reports/getAppsInstallSummaryReport'
    $top = 50
    $skip = 0
    $lookup = @{}

    do
    {
        $body = @{ skip = $skip; top = $top; filter = ''; search = ''; orderBy = @() } | ConvertTo-Json
        $response = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType 'application/json' -ErrorAction Stop

        $columns = @($response['Schema'] | ForEach-Object { $_['Column'] })
        $rows = @($response['Values'] | Where-Object { $null -ne $_ })

        foreach ($row in $rows)
        {
            $record = @{}
            for ($i = 0; $i -lt $columns.Count; $i++) { $record[$columns[$i]] = $row[$i] }

            $lookup["$($record['ApplicationId'])"] = [pscustomobject]@{
                Installed     = [int]$record['InstalledDeviceCount']
                Failed        = [int]$record['FailedDeviceCount']
                Pending       = [int]$record['PendingInstallDeviceCount']
                NotInstalled  = [int]$record['NotInstalledDeviceCount']
                NotApplicable = [int]$record['NotApplicableDeviceCount']
            }
        }

        $skip += $rows.Count
        $total = $response['TotalRowCount']
        $more = if ($null -ne $total) { $skip -lt [int]$total } else { $rows.Count -ge $top }
    }
    while ($rows.Count -gt 0 -and $more)

    $lookup
}

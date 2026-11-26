function Get-IntuneAppInstallSummary
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AppId)

    $lookup = @{}
    $failed = 0
    $batchSize = 20

    for ($offset = 0; $offset -lt $AppId.Count; $offset += $batchSize)
    {
        $chunk = @($AppId[$offset..([math]::Min($offset + $batchSize, $AppId.Count) - 1)])

        $body = @{
            requests = @($chunk | ForEach-Object {
                    @{ id = $_; method = 'GET'; url = "/deviceAppManagement/mobileApps/$_/installSummary" }
                })
        } | ConvertTo-Json -Depth 5

        $response = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/beta/$batch' -Body $body -ContentType 'application/json' -ErrorAction Stop

        foreach ($item in $response['responses'])
        {
            if ($item['status'] -ne 200) { $failed++; continue }

            $summary = $item['body']
            $lookup["$($item['id'])"] = [pscustomobject]@{
                Installed     = [int]$summary['installedDeviceCount']
                Failed        = [int]$summary['failedDeviceCount']
                Pending       = [int]$summary['pendingInstallDeviceCount']
                NotInstalled  = [int]$summary['notInstalledDeviceCount']
                NotApplicable = [int]$summary['notApplicableDeviceCount']
            }
        }
    }

    if ($failed -gt 0) { Write-Warning "Install statistics could not be read for $failed app(s); they are reported with 0 devices." }

    $lookup
}

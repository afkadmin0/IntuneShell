function ConvertTo-IntuneAppResult
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $App,
        [Parameter(Mandatory)][hashtable]$Summary
    )

    process
    {
        $stats = $Summary["$($App.AppId)"]
        if (-not $stats)
        {
            $stats = [pscustomobject]@{ Installed = 0; Failed = 0; Pending = 0; NotInstalled = 0; NotApplicable = 0 }
        }

        $attempts = $stats.Installed + $stats.Failed
        $failureRate = if ($attempts -gt 0) { [math]::Round(($stats.Failed / $attempts) * 100, 1) } else { 0 }

        [pscustomobject]@{
            AppName              = $App.AppName
            AppType              = $App.AppType
            Version              = $App.Version
            Publisher            = $App.Publisher
            FailureRate          = $failureRate
            FailedDevices        = $stats.Failed
            SucceededDevices     = $stats.Installed
            PendingDevices       = $stats.Pending
            NotInstalledDevices  = $stats.NotInstalled
            NotApplicableDevices = $stats.NotApplicable
            IsAssigned           = $App.IsAssigned
            CreatedDateTime      = $App.CreatedDateTime
            LastModified         = $App.LastModified
            AppId                = $App.AppId
        }
    }
}

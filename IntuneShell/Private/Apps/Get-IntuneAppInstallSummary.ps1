function Get-IntuneAppInstallSummary
{
    # Device install counts for every app, keyed by app ID.
    # Uses the Intune "AppInstallStatusAggregate" export report (the same data the
    # portal shows). Export jobs are asynchronous: create the job, poll until it is
    # completed, download the zipped CSV and parse it. No cmdlet exists for this,
    # so Invoke-MgGraphRequest is used.
    [CmdletBinding()]
    param([int]$TimeoutSeconds = 300)

    $base = 'https://graph.microsoft.com/v1.0/deviceManagement/reports/exportJobs'
    $body = @{ reportName = 'AppInstallStatusAggregate'; format = 'csv' } | ConvertTo-Json

    try
    {
        $job = Invoke-MgGraphRequest -Method POST -Uri $base -Body $body -ContentType 'application/json' -ErrorAction Stop
    }
    catch
    {
        Write-Verbose "v1.0 export job failed ($($_.Exception.Message)); trying beta."
        $base = 'https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs'
        $job = Invoke-MgGraphRequest -Method POST -Uri $base -Body $body -ContentType 'application/json' -ErrorAction Stop
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ($job['status'] -ne 'completed')
    {
        if ($job['status'] -eq 'failed') { throw 'The app install status export job failed.' }
        if ((Get-Date) -gt $deadline) { throw "Timed out after $TimeoutSeconds seconds waiting for the app install status report." }

        Start-Sleep -Seconds 3
        $job = Invoke-MgGraphRequest -Method GET -Uri "$base('$($job['id'])')" -ErrorAction Stop
        Write-Verbose "Export job status: $($job['status'])"
    }

    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) "IntuneShell-$([guid]::NewGuid())"
    $null = New-Item -ItemType Directory -Path $workDir

    try
    {
        $zip = Join-Path $workDir 'report.zip'
        Invoke-WebRequest -Uri $job['url'] -OutFile $zip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $zip -DestinationPath $workDir -Force

        $csv = Get-ChildItem -Path $workDir -Filter *.csv | Select-Object -First 1
        if (-not $csv) { throw 'The app install status report contained no CSV file.' }

        $lookup = @{}
        foreach ($row in Import-Csv -Path $csv.FullName)
        {
            $lookup["$($row.ApplicationId)"] = [pscustomobject]@{
                Installed     = [int]$row.InstalledDeviceCount
                Failed        = [int]$row.FailedDeviceCount
                Pending       = [int]$row.PendingInstallDeviceCount
                NotInstalled  = [int]$row.NotInstalledDeviceCount
                NotApplicable = [int]$row.NotApplicableDeviceCount
            }
        }
        $lookup
    }
    finally
    {
        Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

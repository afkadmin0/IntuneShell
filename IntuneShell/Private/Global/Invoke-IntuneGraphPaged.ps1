function Invoke-IntuneGraphPaged
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,

        # Query the beta endpoint only (no v1.0 attempt). Needed for objects that only exist in beta.
        [switch]$Beta
    )

    if ($Beta)
    {
        $response = Invoke-IntuneGraphRequest -Path "https://graph.microsoft.com/beta/$Path"
    }
    else
    {
        $base = 'https://graph.microsoft.com/v1.0'
        try
        {
            $response = Invoke-MgGraphRequest -Method GET -Uri "$base/$Path" -ErrorAction Stop
        }
        catch
        {
            Write-Verbose "v1.0 request for '$Path' failed ($($_.Exception.Message)); falling back to beta."
            $base = 'https://graph.microsoft.com/beta'
            $response = Invoke-MgGraphRequest -Method GET -Uri "$base/$Path" -ErrorAction Stop
        }
    }

    while ($true)
    {
        $response['value']
        $next = $response['@odata.nextLink']
        if (-not $next) { break }
        $response = Invoke-IntuneGraphRequest -Path $next
    }
}

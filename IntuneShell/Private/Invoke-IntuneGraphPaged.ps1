function Invoke-IntuneGraphPaged
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

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

    while ($true)
    {
        $response['value']
        $next = $response['@odata.nextLink']
        if (-not $next) { break }
        $response = Invoke-MgGraphRequest -Method GET -Uri $next -ErrorAction Stop
    }
}

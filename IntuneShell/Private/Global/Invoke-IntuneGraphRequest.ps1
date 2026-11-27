function Invoke-IntuneGraphRequest
{
    [CmdletBinding()]
    param(
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter(Mandatory)]
        [string]$Path,

        $Body,

        [ValidateRange(0, 10)]
        [int]$MaxRetries = 3
    )

    $uri = if ($Path -match '^https://') { $Path } else { "https://graph.microsoft.com/beta/$($Path.TrimStart('/'))" }

    $params = @{ Method = $Method; Uri = $uri; ErrorAction = 'Stop' }
    if ($null -ne $Body)
    {
        $params['Body'] = if ($Body -is [string]) { $Body } else { ConvertTo-Json -InputObject $Body -Depth 100 -Compress }
        $params['ContentType'] = 'application/json'
    }

    $attempt = 0
    while ($true)
    {
        try
        {
            return Invoke-MgGraphRequest @params
        }
        catch
        {
            $err = $_
            $status = 0
            try { $status = [int]$err.Exception.Response.StatusCode } catch { $status = 0 }

            if ($attempt -lt $MaxRetries -and $status -in 429, 502, 503, 504)
            {
                $delay = [math]::Pow(2, $attempt + 1)
                Write-Verbose "Graph returned $status for $Method $Path; retrying in $delay s."
                Start-Sleep -Seconds $delay
                $attempt++
                continue
            }

            $detail = $err.Exception.Message
            if ($err.ErrorDetails -and $err.ErrorDetails.Message)
            {
                try
                {
                    $parsed = $err.ErrorDetails.Message | ConvertFrom-Json
                    if ($parsed.error.message) { $detail = $parsed.error.message }
                }
                catch { $detail = $err.ErrorDetails.Message }
            }
            throw "Graph $Method $Path failed ($status): $detail"
        }
    }
}

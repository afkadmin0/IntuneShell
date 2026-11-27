function Confirm-GraphConnection
{
    [CmdletBinding()]
    param(
        [string[]]$Scopes = @(
            'DeviceManagementConfiguration.Read.All',
            'Group.Read.All'
        )
    )

    $context = Get-MgContext -ErrorAction SilentlyContinue

    if ($context)
    {
        $missing = @($Scopes | Where-Object { $_ -notin $context.Scopes -and ($_ -replace '\.Read\.', '.ReadWrite.') -notin $context.Scopes })
        
        if ($missing.Count -eq 0 -or $context.AuthType -eq 'AppOnly')
        {
            Write-Verbose "Already connected to Microsoft Graph as $($context.Account)."
            return
        }
        Write-Warning "Graph session is missing scopes: $($missing -join ', '). Re-authenticating."
    }
    else
    {
        Write-Host 'Not connected to Microsoft Graph. Prompting for login...' -ForegroundColor Yellow
    }

    try
    {
        Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop | Out-Null
    }
    catch
    {
        throw "Failed to connect to Microsoft Graph: $_"
    }
}

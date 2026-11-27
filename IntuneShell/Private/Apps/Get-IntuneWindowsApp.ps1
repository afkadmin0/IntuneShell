function Get-IntuneWindowsApp
{
    [CmdletBinding()]
    param(
        [ValidateSet('Win32', 'MSI', 'Modern', 'Store', 'Microsoft365')]
        [string[]]$Type = @('Win32', 'MSI', 'Modern', 'Store', 'Microsoft365'),

        [switch]$ExpandAssignments
    )

    $typeMap = @{
        Win32        = 'win32LobApp'
        MSI          = 'windowsMobileMSI'
        Modern       = 'windowsUniversalAppX', 'windowsAppX'
        Store        = 'winGetApp', 'windowsStoreApp', 'microsoftStoreForBusinessApp'
        Microsoft365 = 'officeSuiteApp', 'windowsMicrosoftEdgeApp'
    }

    $typeInfo = @{
        win32LobApp                  = @{ Label = 'Win32'; Version = 'displayVersion' }
        windowsMobileMSI             = @{ Label = 'MSI'; Version = 'productVersion' }
        windowsUniversalAppX         = @{ Label = 'Modern (AppX/MSIX)'; Version = 'identityVersion' }
        windowsAppX                  = @{ Label = 'Modern (AppX/MSIX)'; Version = 'identityVersion' }
        winGetApp                    = @{ Label = 'Microsoft Store'; Version = $null }
        windowsStoreApp              = @{ Label = 'Microsoft Store'; Version = $null }
        microsoftStoreForBusinessApp = @{ Label = 'Microsoft Store'; Version = $null }
        officeSuiteApp               = @{ Label = 'Microsoft 365 Apps'; Version = $null }
        windowsMicrosoftEdgeApp      = @{ Label = 'Microsoft Edge'; Version = $null }
    }

    $wanted = @($Type | ForEach-Object { $typeMap[$_] })

    $params = @{ All = $true; ErrorAction = 'Stop' }
    if ($ExpandAssignments) { $params['ExpandProperty'] = 'assignments' }

    Get-MgDeviceAppManagementMobileApp @params | ForEach-Object {
        $odata = $_.AdditionalProperties['@odata.type'] -replace '^#microsoft\.graph\.', ''
        if ($odata -notin $wanted) { return }

        $info = $typeInfo[$odata]

        [pscustomobject]@{
            AppId           = $_.Id
            AppName         = $_.DisplayName
            AppType         = $info.Label
            Version         = if ($info.Version) { $_.AdditionalProperties[$info.Version] } else { $null }
            Publisher       = $_.Publisher
            IsAssigned      = $_.IsAssigned
            CreatedDateTime = $_.CreatedDateTime
            LastModified    = $_.LastModifiedDateTime
            Assignments     = $_.Assignments
        }
    }
}

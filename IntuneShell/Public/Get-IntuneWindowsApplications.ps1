function Get-IntuneWindowsApplications
{
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name = '*',

        [ValidateSet('Win32', 'MSI', 'Modern', 'Store', 'Microsoft365')]
        [string[]]$Type = @('Win32', 'MSI', 'Modern', 'Store', 'Microsoft365')
    )

    Confirm-GraphConnection -Scopes 'DeviceManagementApps.Read.All'

    $apps = @(Get-IntuneWindowsApp -Type $Type | Where-Object { $_.AppName -like $Name })

    $summary = Get-IntuneAppInstallSummary -AppId @($apps.AppId)

    $apps |
    ConvertTo-IntuneAppResult -Summary $summary |
    Sort-Object @{ Expression = 'FailureRate'; Descending = $true }, @{ Expression = 'FailedDevices'; Descending = $true }, AppName
}

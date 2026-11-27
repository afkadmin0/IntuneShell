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

    Get-IntuneWindowsApp -Type $Type |
    Where-Object { $_.AppName -like $Name } |
    Select-Object AppName, AppType, Version, Publisher, IsAssigned, CreatedDateTime, LastModified, AppId |
    Sort-Object AppName
}

function Get-IntuneWindowsApplicationAssignment
{
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name = '*',

        [ValidateSet('Win32', 'MSI', 'Modern', 'Store', 'Microsoft365')]
        [string[]]$Type = @('Win32', 'MSI', 'Modern', 'Store', 'Microsoft365')
    )

    Confirm-GraphConnection -Scopes 'DeviceManagementApps.Read.All', 'Group.Read.All'

    $groupNames = @{}

    Get-IntuneWindowsApp -Type $Type -ExpandAssignments |
    Where-Object { $_.AppName -like $Name } |
    ConvertTo-IntuneAppAssignmentResult -GroupNames $groupNames |
    Sort-Object AppName, AssignmentType, Intent, GroupName
}

function Restore-IntuneApplication
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [string]$Name = '*',

        [string]$PackagePath,

        [switch]$SkipAssignments,

        [string]$NamePrefix = '',

        [string]$NameSuffix = '',

        [ValidateSet('Skip', 'Rename', 'Overwrite')]
        [string]$ConflictAction = 'Skip'
    )

    begin
    {
        Confirm-GraphConnection -Scopes 'DeviceManagementApps.ReadWrite.All', 'Group.Read.All'
        $cache = @{}
        $explicitPackages = @()
        if ($PackagePath) { $explicitPackages = @(Read-IntuneWinPackage -Path $PackagePath) }
    }

    process
    {
        foreach ($location in $Path)
        {
            foreach ($item in @(Import-IntuneBackupItem -Path $location -Type 'Application'))
            {
                if ($item.Name -notlike $Name) { continue }

                $package = $null
                if ($item.Policy['@odata.type'] -eq '#microsoft.graph.win32LobApp')
                {
                    $candidates = $explicitPackages
                    if (-not $PackagePath)
                    {
                        $candidates = @(Read-IntuneWinPackage -Path (Split-Path -Parent $item.File))
                    }
                    $package = Find-IntuneWinPackage -App $item.Policy -Package $candidates
                }

                # Passed through a variable so the script block sees the package of the current item.
                $create = { param($i, $n, $skip) Restore-IntuneApplicationObject -Item $i -Name $n -Package $package -SkipAssignments:$skip }

                Invoke-IntuneRestoreItem -Item $item -CollectionPath 'deviceAppManagement/mobileApps' -NameProperty 'displayName' `
                    -Create $create -Cache $cache -NamePrefix $NamePrefix -NameSuffix $NameSuffix -ConflictAction $ConflictAction `
                    -SkipAssignments:$SkipAssignments
            }
        }
    }
}

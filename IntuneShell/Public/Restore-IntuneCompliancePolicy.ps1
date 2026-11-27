function Restore-IntuneCompliancePolicy
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [string]$Name = '*',

        [switch]$SkipAssignments,

        [string]$NamePrefix = '',

        [string]$NameSuffix = '',

        [ValidateSet('Skip', 'Rename', 'Overwrite')]
        [string]$ConflictAction = 'Skip'
    )

    begin
    {
        Confirm-GraphConnection -Scopes 'DeviceManagementConfiguration.ReadWrite.All', 'Group.Read.All'
        $cache = @{}
        $create = { param($i, $n, $skip) Restore-IntuneCompliancePolicyObject -Item $i -Name $n -SkipAssignments:$skip }
    }

    process
    {
        foreach ($location in $Path)
        {
            foreach ($item in @(Import-IntuneBackupItem -Path $location -Type 'CompliancePolicy'))
            {
                if ($item.Name -notlike $Name) { continue }

                Invoke-IntuneRestoreItem -Item $item -CollectionPath 'deviceManagement/deviceCompliancePolicies' -NameProperty 'displayName' `
                    -Create $create -Cache $cache -NamePrefix $NamePrefix -NameSuffix $NameSuffix -ConflictAction $ConflictAction `
                    -SkipAssignments:$SkipAssignments
            }
        }
    }
}

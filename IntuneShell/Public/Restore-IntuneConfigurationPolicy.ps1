function Restore-IntuneConfigurationPolicy
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [string]$Name = '*',

        [ValidateSet('SettingsCatalog', 'DeviceConfiguration', 'EndpointSecurityIntent', 'GroupPolicyConfiguration')]
        [string[]]$Type,

        # Only policies of these categories, e.g. Firewall, Antivirus, DiskEncryption, AttackSurfaceReduction, ApplicationControl.
        [string[]]$Category,

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
        $supported = @('SettingsCatalog', 'DeviceConfiguration', 'EndpointSecurityIntent', 'GroupPolicyConfiguration')
        $types = if ($Type) { $Type } else { $supported }
    }

    process
    {
        foreach ($location in $Path)
        {
            foreach ($item in @(Import-IntuneBackupItem -Path $location -Type $types))
            {
                if ($item.Name -notlike $Name) { continue }
                if ($Category -and $item.Category -notin $Category) { continue }

                switch ($item.Type)
                {
                    'SettingsCatalog'
                    {
                        $collection = 'deviceManagement/configurationPolicies'; $nameProperty = 'name'
                        $create = { param($i, $n, $skip) Restore-IntuneSettingsCatalogPolicy -Item $i -Name $n -SkipAssignments:$skip }
                    }
                    'DeviceConfiguration'
                    {
                        $collection = 'deviceManagement/deviceConfigurations'; $nameProperty = 'displayName'
                        $create = { param($i, $n, $skip) Restore-IntuneDeviceConfigurationPolicy -Item $i -Name $n -SkipAssignments:$skip }
                    }
                    'EndpointSecurityIntent'
                    {
                        $collection = 'deviceManagement/intents'; $nameProperty = 'displayName'
                        $create = { param($i, $n, $skip) Restore-IntuneEndpointSecurityIntent -Item $i -Name $n -SkipAssignments:$skip }
                    }
                    'GroupPolicyConfiguration'
                    {
                        $collection = 'deviceManagement/groupPolicyConfigurations'; $nameProperty = 'displayName'
                        $create = { param($i, $n, $skip) Restore-IntuneGroupPolicyConfiguration -Item $i -Name $n -SkipAssignments:$skip }
                    }
                }

                Invoke-IntuneRestoreItem -Item $item -CollectionPath $collection -NameProperty $nameProperty -Create $create -Cache $cache `
                    -NamePrefix $NamePrefix -NameSuffix $NameSuffix -ConflictAction $ConflictAction -SkipAssignments:$SkipAssignments
            }
        }
    }
}

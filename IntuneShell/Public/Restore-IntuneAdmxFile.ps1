function Restore-IntuneAdmxFile
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [string]$Name = '*',

        [ValidateSet('Skip', 'Overwrite')]
        [string]$ConflictAction = 'Skip'
    )

    begin
    {
        Confirm-GraphConnection -Scopes 'DeviceManagementConfiguration.ReadWrite.All', 'Group.Read.All'
        $cache = @{}
        $create = { param($i, $n, $skip) Restore-IntuneAdmxFileObject -Item $i -Name $n -SkipAssignments:$skip }
    }

    process
    {
        foreach ($location in $Path)
        {
            foreach ($item in @(Import-IntuneBackupItem -Path $location -Type 'AdmxFile'))
            {
                if ($item.Name -notlike $Name) { continue }

                Invoke-IntuneRestoreItem -Item $item -CollectionPath 'deviceManagement/groupPolicyUploadedDefinitionFiles' -NameProperty 'fileName' `
                    -Create $create -Cache $cache -ConflictAction $ConflictAction -SkipAssignments
            }
        }
    }
}

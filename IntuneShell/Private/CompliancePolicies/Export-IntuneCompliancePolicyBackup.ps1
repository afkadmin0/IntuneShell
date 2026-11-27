function Export-IntuneCompliancePolicyBackup
{
    <#
    .SYNOPSIS
        Backs up device compliance policies including their non-compliance actions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SkipAssignments
    )

    $directory = Join-Path $Path 'CompliancePolicies'
    $expand = 'scheduledActionsForRule($expand=scheduledActionConfigurations)'
    if (-not $SkipAssignments) { $expand = "assignments,$expand" }

    foreach ($policy in @(Invoke-IntuneGraphPaged -Beta -Path ('deviceManagement/deviceCompliancePolicies?$expand=' + $expand)))
    {
        $name = [string]$policy['displayName']
        $id = [string]$policy['id']

        try
        {
            $object = ConvertTo-IntuneGraphObject -InputObject $policy

            $assignments = @()
            if ($object['assignments']) { $assignments = @($object['assignments']) }
            [void]$object.Remove('assignments')

            $file = Export-IntuneBackupItem -Directory $directory -Type 'CompliancePolicy' -Name $name -Object $object -Assignment $assignments
            New-IntuneOperationResult -Type 'CompliancePolicy' -Name $name -SourceId $id -Status 'Exported' -Path $file.FullName
        }
        catch
        {
            Write-Warning "Failed to back up compliance policy '$name': $($_.Exception.Message)"
            New-IntuneOperationResult -Type 'CompliancePolicy' -Name $name -SourceId $id -Status 'Failed' -Message $_.Exception.Message
        }
    }
}

function Export-IntuneDeviceConfigurationBackup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SkipAssignments
    )

    $directory = Join-Path (Join-Path $Path 'ConfigurationPolicies') 'DeviceConfiguration'
    $uri = 'deviceManagement/deviceConfigurations'
    if (-not $SkipAssignments) { $uri += '?$expand=assignments' }

    foreach ($profile in @(Invoke-IntuneGraphPaged -Beta -Path $uri))
    {
        $name = [string]$profile['displayName']
        $id = [string]$profile['id']

        try
        {
            $object = ConvertTo-IntuneGraphObject -InputObject $profile

            $assignments = @()
            if ($object['assignments']) { $assignments = @($object['assignments']) }
            [void]$object.Remove('assignments')

            $message = $null
            $encrypted = @($object['omaSettings'] | Where-Object { $_ -and $_['isEncrypted'] })
            if ($encrypted.Count -gt 0)
            {
                $message = "$($encrypted.Count) encrypted OMA-URI value(s) cannot be read from Graph and must be re-entered after a restore."
            }

            $file = Export-IntuneBackupItem -Directory $directory -Type 'DeviceConfiguration' -Name $name -Object $object -Assignment $assignments
            New-IntuneOperationResult -Type 'DeviceConfiguration' -Name $name -SourceId $id -Status 'Exported' -Message $message -Path $file.FullName
        }
        catch
        {
            Write-Warning "Failed to back up device configuration '$name': $($_.Exception.Message)"
            New-IntuneOperationResult -Type 'DeviceConfiguration' -Name $name -SourceId $id -Status 'Failed' -Message $_.Exception.Message
        }
    }
}

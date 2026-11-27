function Export-IntuneRemediationScriptBackup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SkipAssignments
    )

    $directory = Join-Path $Path 'Remediations'
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    foreach ($listed in @(Invoke-IntuneGraphPaged -Beta -Path 'deviceManagement/deviceHealthScripts'))
    {
        if ($listed['isGlobalScript'] -eq $true)
        {
            Write-Verbose "Skipping built-in remediation script '$($listed['displayName'])'."
            continue
        }

        $name = [string]$listed['displayName']
        $id = [string]$listed['id']

        try
        {
            # The list call may omit the script bodies, so read the full object.
            $script = Invoke-IntuneGraphRequest -Path "deviceManagement/deviceHealthScripts/$id"
            $object = ConvertTo-IntuneGraphObject -InputObject $script

            $assignments = @()
            if (-not $SkipAssignments)
            {
                $assignments = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/deviceHealthScripts/$id/assignments")
            }

            $file = Export-IntuneBackupItem -Directory $directory -Type 'RemediationScript' -Name $name -Object $object -Assignment $assignments
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

            foreach ($part in @(@('detectionScriptContent', 'detection'), @('remediationScriptContent', 'remediation')))
            {
                $content = [string]$object[$part[0]]
                if (-not $content) { continue }
                $text = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($content)).TrimStart([char]0xFEFF)
                [System.IO.File]::WriteAllText((Join-Path $directory "$baseName.$($part[1]).ps1"), $text, $utf8)
            }

            New-IntuneOperationResult -Type 'RemediationScript' -Name $name -SourceId $id -Status 'Exported' -Path $file.FullName
        }
        catch
        {
            Write-Warning "Failed to back up remediation script '$name': $($_.Exception.Message)"
            New-IntuneOperationResult -Type 'RemediationScript' -Name $name -SourceId $id -Status 'Failed' -Message $_.Exception.Message
        }
    }
}

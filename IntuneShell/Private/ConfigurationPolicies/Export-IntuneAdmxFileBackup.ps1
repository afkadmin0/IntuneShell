function Export-IntuneAdmxFileBackup
{
    # Backs up imported (custom) ADMX files with their ADML language files. Besides the JSON used for restore, the ADMX / ADML
    # are written as normal files (<name>.admx, <language>\<name>.adml) so they can be used or inspected outside Intune.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $root = Join-Path (Join-Path (Join-Path $Path 'ConfigurationPolicies') 'AdministrativeTemplates') 'ImportedADMX'
    $collection = 'deviceManagement/groupPolicyUploadedDefinitionFiles'

    foreach ($listed in @(Invoke-IntuneGraphPaged -Beta -Path $collection))
    {
        $fileName = [string]$listed['fileName']
        $id = [string]$listed['id']

        if ($listed['status'] -and $listed['status'] -notin 'available', 'assigned')
        {
            Write-Verbose "Skipping ADMX '$fileName' (status '$($listed['status'])')."
            continue
        }

        try
        {
            try
            {
                $full = Invoke-IntuneGraphRequest -Path ("$collection/$id" + '?$expand=groupPolicyUploadedLanguageFiles')
            }
            catch
            {
                $full = Invoke-IntuneGraphRequest -Path "$collection/$id"
                $full['groupPolicyUploadedLanguageFiles'] = @(Invoke-IntuneGraphPaged -Beta -Path "$collection/$id/groupPolicyUploadedLanguageFiles")
            }

            if (-not $full['content']) { throw 'Graph did not return the ADMX content.' }

            $object = ConvertTo-IntuneGraphObject -InputObject $full
            $directory = Join-Path $root (ConvertTo-IntuneSafeFileName -Name $fileName)
            $file = Export-IntuneBackupItem -Directory $directory -Type 'AdmxFile' -Category 'ImportedADMX' -Name $fileName -Object $object

            [System.IO.File]::WriteAllBytes((Join-Path $directory (ConvertTo-IntuneSafeFileName -Name $fileName)), [Convert]::FromBase64String([string]$object['content']))

            $languages = @($object['groupPolicyUploadedLanguageFiles'] | Where-Object { $_ })
            foreach ($language in $languages)
            {
                if (-not $language['content']) { continue }
                $languageDirectory = Join-Path $directory (ConvertTo-IntuneSafeFileName -Name ([string]$language['languageCode']))
                [void][System.IO.Directory]::CreateDirectory($languageDirectory)
                [System.IO.File]::WriteAllBytes((Join-Path $languageDirectory (ConvertTo-IntuneSafeFileName -Name ([string]$language['fileName']))), [Convert]::FromBase64String([string]$language['content']))
            }

            New-IntuneOperationResult -Type 'AdmxFile' -Category 'ImportedADMX' -Name $fileName -SourceId $id -Status 'Exported' `
                -Message "$($languages.Count) language file(s)." -Path $file.FullName
        }
        catch
        {
            Write-Warning "Failed to back up ADMX file '$fileName': $($_.Exception.Message)"
            New-IntuneOperationResult -Type 'AdmxFile' -Category 'ImportedADMX' -Name $fileName -SourceId $id -Status 'Failed' -Message $_.Exception.Message
        }
    }
}

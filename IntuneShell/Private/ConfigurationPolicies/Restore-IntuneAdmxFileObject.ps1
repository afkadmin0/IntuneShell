function Restore-IntuneAdmxFileObject
{
    # Imports an ADMX file (with its ADML files) from a backup item and waits until Intune has processed it. Outputs the new file ID.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipAssignments
    )

    $policy = ConvertTo-IntuneGraphObject -InputObject $Item.Policy
    if (-not $policy['content']) { throw 'The backup contains no ADMX content.' }

    $languageFiles = New-Object System.Collections.Generic.List[object]
    foreach ($language in @($policy['groupPolicyUploadedLanguageFiles']))
    {
        if (-not $language) { continue }
        $languageFiles.Add([ordered]@{
                fileName     = $language['fileName']
                languageCode = $language['languageCode']
                content      = $language['content']
            })
    }

    $body = [ordered]@{
        '@odata.type'                    = '#microsoft.graph.groupPolicyUploadedDefinitionFile'
        fileName                         = $Name
        defaultLanguageCode              = if ($policy['defaultLanguageCode']) { $policy['defaultLanguageCode'] } else { 'en-US' }
        content                          = $policy['content']
        groupPolicyUploadedLanguageFiles = $languageFiles.ToArray()
    }
    if ($policy['description']) { $body['description'] = $policy['description'] }

    $collection = 'deviceManagement/groupPolicyUploadedDefinitionFiles'
    $created = Invoke-IntuneGraphRequest -Method POST -Path $collection -Body $body
    $newId = [string]$created['id']

    # The service processes the upload asynchronously.
    $deadline = (Get-Date).AddMinutes(5)
    while ($true)
    {
        $status = [string](Invoke-IntuneGraphRequest -Path "$collection/$newId")['status']

        if ($status -in 'available', 'assigned') { break }
        if ($status -match 'Failed$')
        {
            try { Invoke-IntuneGraphRequest -Method DELETE -Path "$collection/$newId" | Out-Null } catch { Write-Verbose "Cleanup of the failed ADMX import failed: $($_.Exception.Message)" }
            throw "Intune rejected the ADMX import (status '$status'). Check that the ADMX / ADML files are valid and that the namespace is not already imported."
        }
        if ((Get-Date) -gt $deadline) { throw "Timed out waiting for the ADMX import to finish (last status '$status')." }
        Start-Sleep -Seconds 3
    }

    $newId
}

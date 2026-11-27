function Get-IntuneUploadedAdmxDefinitionMap
{
    # Definition ID -> imported ADMX file, for every definition that comes from a custom (imported) ADMX file.
    # Built-in Microsoft definitions are not in the map: their IDs are the same in every tenant.
    [CmdletBinding()]
    param()

    $map = New-Object System.Collections.Hashtable ([System.StringComparer]::OrdinalIgnoreCase)

    try
    {
        $files = @(Invoke-IntuneGraphPaged -Beta -Path 'deviceManagement/groupPolicyUploadedDefinitionFiles')
    }
    catch
    {
        Write-Verbose "Imported ADMX files could not be listed: $($_.Exception.Message)"
        return , $map
    }

    foreach ($file in $files)
    {
        if ($file['status'] -and $file['status'] -notin 'available', 'assigned') { continue }
        $fileId = [string]$file['id']

        try
        {
            $definitions = @(Invoke-IntuneGraphPaged -Beta -Path ("deviceManagement/groupPolicyUploadedDefinitionFiles/$fileId/definitions" + '?$select=id'))
        }
        catch
        {
            try { $definitions = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/groupPolicyUploadedDefinitionFiles/$fileId/definitions") }
            catch
            {
                Write-Warning "The definitions of imported ADMX '$($file['fileName'])' could not be read; policies using it will not be re-linkable on restore."
                continue
            }
        }

        foreach ($definition in $definitions)
        {
            $map[[string]$definition['id']] = [ordered]@{
                id              = $fileId
                fileName        = [string]$file['fileName']
                targetNamespace = [string]$file['targetNamespace']
            }
        }
    }

    , $map
}

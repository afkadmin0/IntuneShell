function Resolve-IntuneAdmxDefinition
{
    # Finds the definition in this tenant that corresponds to a definition from a backup that came from an imported ADMX file.
    # Re-importing an ADMX file creates new definition IDs, so the match is made on file name + class + category path + name.
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Definition)

    $fileName = [string]$Definition['definitionFile']['fileName']
    $label = [string]$Definition['displayName']

    if (-not $script:IntuneLookupCache) { $script:IntuneLookupCache = @{} }
    $context = Get-MgContext -ErrorAction SilentlyContinue
    $filesKey = '{0}|admxFiles' -f $context.TenantId

    # The list is cached, but refreshed on a miss so an ADMX file imported moments ago is found.
    $fileId = $null
    foreach ($attempt in 1, 2)
    {
        if ($attempt -eq 2 -or -not $script:IntuneLookupCache.ContainsKey($filesKey))
        {
            $files = @{}
            foreach ($file in @(Invoke-IntuneGraphPaged -Beta -Path 'deviceManagement/groupPolicyUploadedDefinitionFiles'))
            {
                if ($file['status'] -in 'available', 'assigned') { $files[([string]$file['fileName']).ToLowerInvariant()] = [string]$file['id'] }
            }
            $script:IntuneLookupCache[$filesKey] = $files
        }
        $fileId = $script:IntuneLookupCache[$filesKey][$fileName.ToLowerInvariant()]
        if ($fileId) { break }
    }
    if (-not $fileId) { throw "the ADMX file '$fileName' is not imported in this tenant; restore it first with Restore-IntuneAdmxFile" }

    $definitionsKey = '{0}|admxDefinitions|{1}' -f $context.TenantId, $fileId
    if (-not $script:IntuneLookupCache.ContainsKey($definitionsKey))
    {
        try { $definitions = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/groupPolicyUploadedDefinitionFiles/$fileId/definitions") }
        catch { $definitions = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/groupPolicyDefinitionFiles/$fileId/definitions") }
        $script:IntuneLookupCache[$definitionsKey] = $definitions
    }

    $candidates = @($script:IntuneLookupCache[$definitionsKey] | Where-Object {
            [string]$_['displayName'] -ieq $label -and [string]$_['classType'] -ieq [string]$Definition['classType']
        })
    if ($candidates.Count -gt 1)
    {
        $exact = @($candidates | Where-Object { [string]$_['categoryPath'] -ieq [string]$Definition['categoryPath'] })
        if ($exact.Count -gt 0) { $candidates = $exact }
    }
    if ($candidates.Count -eq 0) { throw "'$label' was not found in the imported ADMX file '$fileName'" }

    $candidates[0]
}

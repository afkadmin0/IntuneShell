function Get-IntuneIntentCategoryMap
{
    # Template ID -> category for legacy endpoint security profiles (intents), so they are filed next to their modern counterparts.
    [CmdletBinding()]
    param()

    $map = @{}

    try
    {
        foreach ($template in @(Invoke-IntuneGraphPaged -Beta -Path 'deviceManagement/templates'))
        {
            $subtype = [string]$template['templateSubtype']
            $type = [string]$template['templateType']

            $category = switch -Regex ($subtype)
            {
                '^antivirus$' { 'Antivirus' }
                '^diskEncryption$' { 'DiskEncryption' }
                '^firewall' { 'Firewall' }
                '^endpointDetectionRespon?se$|^endpointDetectionReponse$' { 'EndpointDetectionAndResponse' }
                '^attackSurfaceReduction$' { 'AttackSurfaceReduction' }
                '^accountProtection$' { 'AccountProtection' }
                default { if ($type -match 'baseline') { 'SecurityBaselines' } else { 'Other' } }
            }
            $map[[string]$template['id']] = $category
        }
    }
    catch
    {
        Write-Verbose "Intent templates could not be read; legacy profiles go into 'Other': $($_.Exception.Message)"
    }

    , $map
}

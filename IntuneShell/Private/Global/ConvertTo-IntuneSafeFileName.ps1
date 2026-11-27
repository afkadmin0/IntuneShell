function ConvertTo-IntuneSafeFileName
{
    [CmdletBinding()]
    param([AllowEmptyString()][AllowNull()][string]$Name)

    $safe = if ($Name) { $Name -replace '[\\/:*?"<>|\x00-\x1f]', '_' } else { '' }
    $safe = $safe.Trim().TrimEnd('.')

    if (-not $safe) { $safe = 'unnamed' }
    if ($safe -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') { $safe = "_$safe" }
    if ($safe.Length -gt 100) { $safe = $safe.Substring(0, 100).TrimEnd() }

    $safe
}

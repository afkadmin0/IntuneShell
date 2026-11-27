function Find-IntuneWinPackage
{
    <#
    .SYNOPSIS
        Picks the package that belongs to a Win32 app: same file name, and the same setup file when both are known.
    .DESCRIPTION
        Returns $null when nothing matches or when the match is ambiguous (with a warning for the latter).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$App,
        [AllowNull()][object[]]$Package
    )

    $fileName = [string]$App['fileName']
    if (-not $fileName) { return $null }

    $candidates = @($Package | Where-Object { $_ -and $_.FileName -ieq $fileName })

    $setupFile = [string]$App['setupFilePath']
    if ($setupFile -and $candidates.Count -gt 1)
    {
        $narrowed = @($candidates | Where-Object { $_.SetupFile -ieq $setupFile })
        if ($narrowed.Count -gt 0) { $candidates = $narrowed }
    }

    if ($candidates.Count -eq 1) { return $candidates[0] }
    if ($candidates.Count -gt 1)
    {
        Write-Warning "More than one package matches '$fileName' for '$($App['displayName'])' ($($candidates.Path -join '; ')); none was used."
    }
    $null
}

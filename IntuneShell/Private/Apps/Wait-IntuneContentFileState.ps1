function Wait-IntuneContentFileState
{
    <#
    .SYNOPSIS
        Polls an app content file until its uploadState reaches the wanted value; throws on a failed or timed-out state.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$State,
        [int]$TimeoutSeconds = 300,
        [int]$IntervalSeconds = 2
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ($true)
    {
        $file = Invoke-IntuneGraphRequest -Path $Path
        $current = [string]$file['uploadState']

        if ($current -eq $State) { return $file }
        if ($current -match 'Failed$|TimedOut$|^error$')
        {
            throw "The content file entered state '$current' while waiting for '$State'."
        }
        if ((Get-Date) -gt $deadline)
        {
            throw "Timed out after $TimeoutSeconds s waiting for content state '$State' (last state: '$current')."
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
}

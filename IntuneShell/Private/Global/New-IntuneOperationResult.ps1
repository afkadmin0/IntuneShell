function New-IntuneOperationResult
{
    [CmdletBinding()]
    param(
        [string]$Type,
        [string]$Category,
        [string]$Name,
        [string]$Status,
        [string]$Message,
        [string]$SourceId,
        [string]$NewId,
        [string]$Path
    )

    [pscustomobject]@{
        PSTypeName = 'IntuneShell.OperationResult'
        Type       = $Type
        Category   = $Category
        Name       = $Name
        Status     = $Status
        Message    = $Message
        SourceId   = $SourceId
        NewId      = $NewId
        Path       = $Path
    }
}

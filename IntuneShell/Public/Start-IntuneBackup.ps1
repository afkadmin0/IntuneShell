function Start-IntuneBackup
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [string]$Path = (Join-Path $PWD.Path ('IntuneBackup_{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),

        [ValidateSet('SettingsCatalog', 'DeviceConfiguration', 'EndpointSecurity', 'AdmxFiles', 'AdministrativeTemplates', 'CompliancePolicies', 'Remediations')]
        [string[]]$Include,

        [ValidateSet('SettingsCatalog', 'DeviceConfiguration', 'EndpointSecurity', 'AdmxFiles', 'AdministrativeTemplates', 'CompliancePolicies', 'Remediations')]
        [string[]]$Exclude,

        [switch]$IncludeApplications,

        [string]$ApplicationName = '*',

        [string]$ApplicationPackagePath,

        [switch]$SkipAssignments,

        [switch]$Compress,

        [switch]$Force
    )

    $started = Get-Date
    $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path).TrimEnd('\', '/')

    if ($ApplicationPackagePath)
    {
        if (-not (Test-Path -LiteralPath $ApplicationPackagePath)) { throw "Application package path '$ApplicationPackagePath' was not found." }
        $IncludeApplications = $true
    }

    $policyCategories = @('SettingsCatalog', 'DeviceConfiguration', 'EndpointSecurity', 'AdmxFiles', 'AdministrativeTemplates', 'CompliancePolicies', 'Remediations')
    $selected = @($policyCategories | Where-Object { (-not $Include -or $_ -in $Include) -and $_ -notin $Exclude })

    if ($selected.Count -eq 0 -and -not $IncludeApplications) { throw 'Nothing to back up: every category is excluded.' }

    if (Test-Path -LiteralPath $root)
    {
        if (-not $Force -and @(Get-ChildItem -LiteralPath $root -Force).Count -gt 0)
        {
            throw "'$root' already contains files. Choose another path or use -Force."
        }
    }
    if ($Compress -and -not $Force -and (Test-Path -LiteralPath "$root.zip"))
    {
        throw "'$root.zip' already exists. Choose another path or use -Force."
    }

    if (-not $PSCmdlet.ShouldProcess($root, 'Back up Intune configuration')) { return }

    $scopes = @('Group.Read.All')
    if ($selected.Count -gt 0) { $scopes += 'DeviceManagementConfiguration.Read.All' }
    if ($IncludeApplications) { $scopes += 'DeviceManagementApps.Read.All' }
    Confirm-GraphConnection -Scopes $scopes

    [void][System.IO.Directory]::CreateDirectory($root)

    $steps = New-Object System.Collections.Generic.List[object]
    foreach ($category in $selected)
    {
        switch ($category)
        {
            'SettingsCatalog' { $steps.Add(@{ Name = $category; Run = { Export-IntuneSettingsCatalogBackup -Path $root -Scope SettingsCatalog -SkipAssignments:$SkipAssignments } }) }
            'DeviceConfiguration' { $steps.Add(@{ Name = $category; Run = { Export-IntuneDeviceConfigurationBackup -Path $root -SkipAssignments:$SkipAssignments } }) }
            'EndpointSecurity'
            {
                # Antivirus, Disk encryption, Firewall, EDR, Attack surface reduction, Account protection, App Control for Business, ...
                $steps.Add(@{ Name = $category; Run = { Export-IntuneSettingsCatalogBackup -Path $root -Scope EndpointSecurity -SkipAssignments:$SkipAssignments } })
                $steps.Add(@{ Name = 'EndpointSecurityLegacy'; Run = { Export-IntuneEndpointSecurityIntentBackup -Path $root -SkipAssignments:$SkipAssignments } })
            }
            'AdmxFiles' { $steps.Add(@{ Name = $category; Run = { Export-IntuneAdmxFileBackup -Path $root } }) }
            'AdministrativeTemplates' { $steps.Add(@{ Name = $category; Run = { Export-IntuneGroupPolicyBackup -Path $root -SkipAssignments:$SkipAssignments } }) }
            'CompliancePolicies' { $steps.Add(@{ Name = $category; Run = { Export-IntuneCompliancePolicyBackup -Path $root -SkipAssignments:$SkipAssignments } }) }
            'Remediations' { $steps.Add(@{ Name = $category; Run = { Export-IntuneRemediationScriptBackup -Path $root -SkipAssignments:$SkipAssignments } }) }
        }
    }
    if ($IncludeApplications)
    {
        $steps.Add(@{
                Name = 'Applications'
                Run  = { Export-IntuneApplicationBackup -Path $root -Name $ApplicationName -PackagePath $ApplicationPackagePath -SkipAssignments:$SkipAssignments }
            })
    }

    $results = New-Object System.Collections.Generic.List[object]
    $categories = New-Object System.Collections.Generic.List[object]
    $index = 0

    foreach ($step in $steps)
    {
        Write-Progress -Activity 'Intune backup' -Status $step.Name -PercentComplete (100 * $index / $steps.Count)
        $index++

        $categoryError = $null
        $categoryResults = @()
        try
        {
            $categoryResults = @(& $step.Run)
        }
        catch
        {
            $categoryError = $_.Exception.Message
            Write-Warning "Category '$($step.Name)' was skipped: $categoryError"
        }

        foreach ($result in $categoryResults) { $results.Add($result) }
        $categories.Add([pscustomobject]@{
                Category = $step.Name
                Exported = @($categoryResults | Where-Object Status -eq 'Exported').Count
                Failed   = @($categoryResults | Where-Object Status -eq 'Failed').Count
                Error    = $categoryError
            })
    }
    Write-Progress -Activity 'Intune backup' -Completed

    $context = Get-MgContext -ErrorAction SilentlyContinue
    $module = $MyInvocation.MyCommand.Module
    $prefix = $root + [System.IO.Path]::DirectorySeparatorChar

    $manifest = [ordered]@{
        schemaVersion = 1
        createdAt     = $started.ToUniversalTime().ToString('o')
        moduleVersion = if ($module) { $module.Version.ToString() } else { 'unknown' }
        tenantId      = $context.TenantId
        account       = $context.Account
        options       = [ordered]@{
            categories          = $selected
            includeApplications = [bool]$IncludeApplications
            applicationName     = $ApplicationName
            packagePath         = $ApplicationPackagePath
            skipAssignments     = [bool]$SkipAssignments
        }
        categories    = $categories.ToArray()
        items         = @($results | ForEach-Object {
                [ordered]@{
                    type     = $_.Type
                    category = $_.Category
                    name     = $_.Name
                    id       = $_.SourceId
                    status   = $_.Status
                    message  = $_.Message
                    file     = if ($_.Path -and $_.Path.StartsWith($prefix)) { $_.Path.Substring($prefix.Length) } else { $_.Path }
                }
            })
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'manifest.json'), (ConvertTo-Json -InputObject $manifest -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

    $finalPath = $root
    if ($Compress)
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = "$root.zip"
        if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($root, $zip)
        Remove-Item -LiteralPath $root -Recurse -Force
        $finalPath = $zip
    }

    [pscustomobject]@{
        PSTypeName = 'IntuneShell.BackupSummary'
        Path       = $finalPath
        TenantId   = $context.TenantId
        Exported   = @($results | Where-Object Status -eq 'Exported').Count
        Failed     = @($results | Where-Object Status -eq 'Failed').Count
        Categories = $categories.ToArray()
        Results    = $results.ToArray()
        Duration   = (Get-Date) - $started
    }
}

@{

    RootModule           = 'IntuneShell.psm1'

    ModuleVersion        = '0.1.1'

    CompatiblePSEditions = @('Desktop', 'Core')

    GUID                 = '576ed2e4-2f6d-4ee4-8c48-9b219763e1e3'

    Author               = 'Carlo Rohrer'
    CompanyName          = 'IntuneShell'
    Copyright            = '(c) 2026 Carlo Rohrer. All rights reserved.'
    Description          = 'Find the Intune policies, endpoint security profiles and remediations a group is assigned to or excluded from'

    PowerShellVersion    = '5.1'

    RequiredModules      = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Groups'
        'Microsoft.Graph.DeviceManagement'
    )

    FunctionsToExport    = @(
        'Get-IntunePolicyByGroup'
        'Get-IntuneRemediationByGroup'
    )

    CmdletsToExport      = @()

    VariablesToExport    = ''

    AliasesToExport      = @()

    FileList             = @()

    PrivateData          = @{

        PSData = @{
            Tags       = @('Intune', 'MicrosoftGraph', 'Endpoint')
            # LicenseUri = 'https://github.com/afkadmin0/IntuneShell'
            ProjectUri = 'https://github.com/afkadmin0/IntuneShell'
        }

    }

    DefaultCommandPrefix = 'Intune'
}

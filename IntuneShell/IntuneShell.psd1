@{

    RootModule           = 'IntuneShell.psm1'

    ModuleVersion        = '0.1.3'

    CompatiblePSEditions = @('Desktop', 'Core')

    GUID                 = '576ed2e4-2f6d-4ee4-8c48-9b219763e1e3'

    Author               = 'Carlo Rohrer'
    CompanyName          = 'IntuneShell'
    Copyright            = '(c) 2026 Carlo Rohrer. All rights reserved.'
    Description          = 'NOT AFILIATED WITH MICROSOFT IN ANY WAY. CmdLets for managing Intune.'

    PowerShellVersion    = '5.1'

    RequiredModules      = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Groups'
        'Microsoft.Graph.DeviceManagement'
        'Microsoft.Graph.Devices.CorporateManagement'
    )

    FunctionsToExport    = @(
        'Get-IntunePolicyByGroup'
        'Get-IntuneRemediationByGroup'
        'Get-IntuneWindowsApplications'
        'Get-IntuneWindowsApplicationAssignment'
        'Get-IntuneWindowsApplicationByGroup'
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
}

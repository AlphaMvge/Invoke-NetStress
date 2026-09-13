@{
    RootModule = 'Invoke-NetStress.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a89c7451-b0e1-4c72-9bfa-b9560f7823e4'
    Author = 'NetStress Engineering Team'
    CompanyName = 'Community'
    Copyright = '(c) 2026. All rights reserved.'
    Description = 'High-Intensity Multi-Threaded Bandwidth & Bufferbloat Stress Suite with real-time ANSI terminal dashboard, compliance guardrails, and HTML/JSON/CSV reporting.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Invoke-NetStress')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Network', 'Bandwidth', 'Bufferbloat', 'StressTest', 'Latency', 'Jitter', 'Throughput', 'QoS', 'SQM')
            ProjectUri = 'https://github.com/your-org/Invoke-NetStress'
            LicenseUri = 'https://github.com/your-org/Invoke-NetStress/blob/main/LICENSE'
        }
    }
}

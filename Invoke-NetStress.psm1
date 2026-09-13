<#
    Invoke-NetStress Module Definition
#>

function Invoke-NetStress {
    [CmdletBinding(DefaultParameterSetName = "Standard")]
    param (
        [Parameter(Position = 0)]
        [ValidateSet("Low", "Medium", "High", "Extreme")]
        [string]$Intensity = "Medium",

        [Parameter(Position = 1)]
        [ValidateSet("Duplex", "Download", "Upload")]
        [string]$Mode = "Duplex",

        [Parameter(Position = 2)]
        [ValidateRange(5, 3600)]
        [int]$Duration = 30,

        [Parameter(Position = 3)]
        [string]$PingTarget = "1.1.1.1",

        [Parameter()]
        [ValidateRange(1, 512)]
        [int]$CustomThreads = 0,

        [Parameter()]
        [string]$DownloadUri = "https://speed.cloudflare.com/__down?bytes=50000000",

        [Parameter()]
        [string]$UploadUri = "https://speed.cloudflare.com/__up",

        [Parameter()]
        [ValidateRange(1, 32)]
        [int]$PayloadChunkMB = 2,

        [Parameter()]
        [Alias("AcceptTerms", "Authorized")]
        [switch]$AcknowledgeAuthorization,

        [Parameter()]
        [string]$ReportPath = "reports",

        [Parameter()]
        [switch]$NoReport,

        [Parameter()]
        [switch]$SimpleDisplay,

        [Parameter()]
        [switch]$PassThru
    )

    $scriptPath = Join-Path $PSScriptRoot "Invoke-NetStress.ps1"
    & $scriptPath @PSBoundParameters
}

Export-ModuleMember -Function Invoke-NetStress

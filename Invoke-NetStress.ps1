<#
.SYNOPSIS
    Invoke-NetStress: High-Performance Network Bandwidth & Bufferbloat Stress Suite.

.DESCRIPTION
    Generates heavy, multi-threaded, asynchronous HTTP/S traffic to completely saturate
    network links (WAN, LAN, SD-WAN, or VPN) while continuously sampling latency and jitter
    via hardware-level .NET ICMP pings. Measures bufferbloat severity, calculates queueing delay,
    assigns an industry-standard Bufferbloat Grade (A+ to F), renders a real-time ANSI terminal
    dashboard with sparklines, and exports comprehensive post-test reports (HTML, JSON, CSV).

    Supports both public global Edge CDNs (e.g. Cloudflare) and air-gapped private LAN / intranet
    endpoints without requiring third-party agents or listeners.

.PARAMETER Intensity
    Preconfigured traffic intensity profile:
    - 'Low'     : 4 concurrent sockets
    - 'Medium'  : 16 concurrent sockets
    - 'High'    : 32 concurrent sockets (Default)
    - 'Extreme' : 64 concurrent sockets
    - 'Ultra'   : 128 concurrent sockets

.PARAMETER Mode
    Traffic pattern:
    - 'Duplex'   : Concurrent upload and download (maximum stress on bidirectional queues)
    - 'Download' : Heavy multi-stream download only
    - 'Upload'   : Heavy multi-stream upload only

.PARAMETER Duration
    Duration of the stress test in seconds (default: 30 seconds).

.PARAMETER PingTarget
    Target host or IP address to ping continuously to observe latency increase under load (default: 1.1.1.1).

.PARAMETER CustomThreads
    Specify any custom number of parallel worker threads (overrides -Intensity).

.PARAMETER DownloadUri
    Target endpoint URL for download streams (default: Cloudflare Edge speed endpoint).
    Can be pointed to internal web servers (e.g. NGINX, Apache, IIS) for local LAN testing.

.PARAMETER UploadUri
    Target endpoint URL for upload streams (default: Cloudflare Edge speed endpoint).

.PARAMETER PayloadChunkMB
    Size of upload buffer chunks in megabytes (default: 2 MB).

.PARAMETER AcknowledgeAuthorization
    Required compliance flag confirming authorization to stress-test the network link.
    Aliases: -AcceptTerms, -Authorized.

.PARAMETER ReportPath
    Directory path to store exported reports (HTML, JSON, CSV). Default is 'reports'.

.PARAMETER NoReport
    Suppress generation of report files.

.PARAMETER SimpleDisplay
    Use traditional scrolling text display instead of the dynamic in-place ANSI terminal dashboard.

.PARAMETER PassThru
    Outputs the final test result object to the PowerShell pipeline for automated scripting.

.EXAMPLE
    .\Invoke-NetStress.ps1 -Duration 20 -Intensity Medium -AcknowledgeAuthorization
    Runs a 20-second duplex stress test with 16 parallel sockets and displays the live ANSI dashboard.

.EXAMPLE
    .\Invoke-NetStress.ps1 -Mode Download -Duration 45 -Intensity Extreme -PingTarget "8.8.8.8" -AcknowledgeAuthorization
    Runs a 45-second high-intensity download saturation test pinging Google DNS.

.EXAMPLE
    .\Invoke-NetStress.ps1 -DownloadUri "http://192.168.1.100:8080/large.bin" -UploadUri "http://192.168.1.100:8080/upload" -AcknowledgeAuthorization
    Runs a stress test against an internal enterprise server on an isolated LAN.

.NOTES
    Author: NetStress Engineering Team
    Repository: https://github.com/AlphaMvge/Invoke-NetStress
    License: MIT
#>

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

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# ==============================================================================
# 1. INTERACTIVE TARGET & INTENSITY SELECTION & CONFIRMATION
# ==============================================================================
function Request-TestConfiguration {
    [CmdletBinding()]
    param(
        [ref]$TargetHost,
        [ref]$IntensityLevel
    )

    $defaultTarget = if ($TargetHost.Value) { $TargetHost.Value } else { "1.1.1.1" }

    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                 INVOKE-NETSTRESS: PRE-FLIGHT CONFIGURATION                   ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # Step 1: Prompt for target IP
    Write-Host "`n[STEP 1/2] TARGET SPECIFICATION" -ForegroundColor Cyan
    $promptMsg = " Enter Target IP or Hostname to stress test [$defaultTarget]"
    $userEntry = Read-Host -Prompt $promptMsg

    if (-not [string]::IsNullOrWhiteSpace($userEntry)) {
        $TargetHost.Value = $userEntry.Trim()
    } else {
        $TargetHost.Value = $defaultTarget
    }

    $activeTarget = $TargetHost.Value

    # Step 2: Prompt for Intensity with Estimated Output
    Write-Host "`n[STEP 2/2] SELECT TRAFFIC INTENSITY (TARGET: $activeTarget)" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [1] Low      |  4 Sockets  | Est. Output: ~150 - 500 Mbps   (Light / Baseline Check)" -ForegroundColor Green
    Write-Host "  [2] Medium   | 16 Sockets  | Est. Output: ~500 - 1,200 Mbps (Standard Gigabit Link)" -ForegroundColor Cyan
    Write-Host "  [3] High     | 32 Sockets  | Est. Output: ~1.2 - 2.5 Gbps   (Multi-Gig WAN / Fiber)" -ForegroundColor Yellow
    Write-Host "  [4] Extreme  | 64 Sockets  | Est. Output: ~2.5 - 5.0+ Gbps  (Max Saturation / 10GbE)" -ForegroundColor Red
    Write-Host " ------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $curIntensity = if ($IntensityLevel.Value) { $IntensityLevel.Value } else { "Medium" }
    $defaultIndex = switch ($curIntensity) {
        "Low"     { "1" }
        "Medium"  { "2" }
        "High"    { "3" }
        "Extreme" { "4" }
        default   { "2" }
    }

    $intensityInput = Read-Host -Prompt " Select intensity profile [1-4] or name (Default: [$defaultIndex] $curIntensity)"

    if ([string]::IsNullOrWhiteSpace($intensityInput)) {
        $intensityInput = $defaultIndex
    }

    $selectedIntensity = switch -Regex ($intensityInput.Trim()) {
        "^1$|^low$"     { "Low" }
        "^2$|^medium$"  { "Medium" }
        "^3$|^high$"    { "High" }
        "^4$|^extreme$" { "Extreme" }
        default         { "Medium" }
    }

    $IntensityLevel.Value = $selectedIntensity

    $selectedEstimate = switch ($selectedIntensity) {
        "Low"     { "4 Sockets | Est. Output: ~150 - 500 Mbps" }
        "Medium"  { "16 Sockets | Est. Output: ~500 - 1,200 Mbps" }
        "High"    { "32 Sockets | Est. Output: ~1.2 - 2.5 Gbps" }
        "Extreme" { "64 Sockets | Est. Output: ~2.5 - 5.0+ Gbps" }
    }

    # Step 3: Explicit Verification & Confirmation
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                          CONFIRM TEST PARAMETERS                             ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "  • Target Host      : " -NoNewline -ForegroundColor Gray
    Write-Host "$activeTarget" -ForegroundColor Green
    Write-Host "  • Intensity Level  : " -NoNewline -ForegroundColor Gray
    Write-Host "$selectedIntensity ($selectedEstimate)" -ForegroundColor Yellow
    Write-Host " ------------------------------------------------------------------------------" -ForegroundColor DarkGray

    $confirmResponse = Read-Host -Prompt " [?] Confirm these parameters and launch stress test? [Y/n]"

    if ([string]::IsNullOrWhiteSpace($confirmResponse) -or $confirmResponse -match "^[yY]([eE][sS])?$") {
        Write-Host " [✓] Parameters confirmed. Initializing engine...`n" -ForegroundColor Green
    } else {
        throw "Operation aborted by user: Target and intensity were not confirmed."
    }
}

Request-TestConfiguration -TargetHost ([ref]$PingTarget) -IntensityLevel ([ref]$Intensity)

# ==============================================================================
# 2. AUTHORIZATION & COMPLIANCE GUARDRAIL
# ==============================================================================
function Assert-AuthorizationConsent {
    [CmdletBinding()]
    param([switch]$Acknowledge)

    if ($Acknowledge) {
        return $true
    }

    $banner = @"
╔══════════════════════════════════════════════════════════════════════════════╗
║               NETWORK STRESS TEST AUTHORIZATION & COMPLIANCE                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
 WARNING: This tool generates high-volume multi-threaded saturated network traffic
 designed to test link throughput and bufferbloat queue delays.

 Unauthorized network stress testing or volumetric traffic generation against
 targets or networks you do not own or have explicit written permission to test
 is strictly illegal and may violate national cybersecurity laws and ISP terms.

 Target Endpoints:
   • Ping Monitor  : $PingTarget
   • Download URI  : $DownloadUri
   • Upload URI    : $UploadUri
   • Stress Mode   : $Mode
════════════════════════════════════════════════════════════════════════════════
"@

    Write-Host $banner -ForegroundColor Yellow
    $response = Read-Host -Prompt "Do you confirm you have explicit authorization to stress-test this network? [y/N]"

    if ($response -match "^[yY]([eE][sS])?$") {
        Write-Host "[✓] Authorization confirmed by operator.`n" -ForegroundColor Green
        return $true
    } else {
        throw "Operation aborted by user: Authorization not confirmed."
    }
}

Assert-AuthorizationConsent -Acknowledge:$AcknowledgeAuthorization

# ==============================================================================
# 2. ATOMIC COUNTERS & .NET INITIALIZATION
# ==============================================================================
Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

if (-not ([System.Management.Automation.PSTypeName]'NetStressAtomicCounters').Type) {
    Add-Type @"
    public class NetStressAtomicCounters {
        private long downloadBytes = 0;
        private long uploadBytes = 0;
        public void AddDownload(long amount) { System.Threading.Interlocked.Add(ref downloadBytes, amount); }
        public void AddUpload(long amount) { System.Threading.Interlocked.Add(ref uploadBytes, amount); }
        public long GetDownload() { return System.Threading.Interlocked.Read(ref downloadBytes); }
        public long GetUpload() { return System.Threading.Interlocked.Read(ref uploadBytes); }
        public long GetTotal() { return System.Threading.Interlocked.Read(ref downloadBytes) + System.Threading.Interlocked.Read(ref uploadBytes); }
    }
"@
}

# Network connection settings for maximum concurrency
try {
    [System.Net.ServicePointManager]::DefaultConnectionLimit = 1024
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
} catch {}

# Determine thread count
$threads = switch ($Intensity) {
    "Low"     { 4 }
    "Medium"  { 16 }
    "High"    { 32 }
    "Extreme" { 64 }
}

if ($CustomThreads -gt 0) {
    $threads = $CustomThreads
    $Intensity = "Custom ($threads threads)"
}

# ==============================================================================
# 3. ICMP PING ENGINE & BUFFERBLOAT GRADING
# ==============================================================================
function Get-FastPingSample {
    param(
        [string]$Target,
        [int]$TimeoutMs = 1000
    )
    $pinger = New-Object System.Net.NetworkInformation.Ping
    try {
        $buffer = [byte[]](1..32 | ForEach-Object { 65 })
        $options = New-Object System.Net.NetworkInformation.PingOptions(64, $true)
        $reply = $pinger.Send($Target, $TimeoutMs, $buffer, $options)
        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            return [double]$reply.RoundtripTime
        }
        return $null
    } catch {
        return $null
    } finally {
        $pinger.Dispose()
    }
}

function Get-BufferbloatAssessment {
    param([double]$DeltaMs, [double]$PacketLossRate)

    if ($PacketLossRate -gt 0.05 -or $DeltaMs -ge 120.0) {
        return @{
            Grade       = "F"
            Title       = "Poor / Severe Bufferbloat"
            Description = "Severe queueing delay or packet loss. Real-time apps (VoIP, gaming) will stutter heavily."
            Color       = "Red"
        }
    } elseif ($DeltaMs -ge 60.0) {
        return @{
            Grade       = "D"
            Title       = "Substandard Queueing"
            Description = "Noticeable latency spike under link saturation. Noticeable lag during heavy transfers."
            Color       = "Magenta"
        }
    } elseif ($DeltaMs -ge 30.0) {
        return @{
            Grade       = "C"
            Title       = "Fair Performance"
            Description = "Moderate queueing delay. Typical for unmanaged consumer ISP routers without SQM."
            Color       = "Yellow"
        }
    } elseif ($DeltaMs -ge 15.0) {
        return @{
            Grade       = "B"
            Title       = "Good Management"
            Description = "Minor latency increase. General web browsing and streaming remain smooth."
            Color       = "Green"
        }
    } elseif ($DeltaMs -ge 5.0) {
        return @{
            Grade       = "A"
            Title       = "Great Queue Discipline"
            Description = "Very low latency increase. Responsive link under heavy load."
            Color       = "Green"
        }
    } else {
        return @{
            Grade       = "A+"
            Title       = "Exceptional (Zero Bloat)"
            Description = "Virtually imperceptible buffer latency. State-of-the-art SQM (CAKE/fq_codel) active."
            Color       = "Cyan"
        }
    }
}

function Render-Sparkline {
    param(
        [double[]]$Values,
        [int]$MaxItems = 20
    )
    if (-not $Values -or $Values.Count -eq 0) { return "...................." }
    $recent = if ($Values.Count -gt $MaxItems) { $Values[($Values.Count - $MaxItems)..($Values.Count - 1)] } else { $Values }
    $min = ($recent | Measure-Object -Minimum).Minimum
    $max = ($recent | Measure-Object -Maximum).Maximum
    $range = $max - $min
    if ($range -le 0) { $range = 1 }

    $glyphs = @(' ', '▂', '▃', '▄', '▅', '▆', '▇', '█')
    $builder = New-Object System.Text.StringBuilder
    foreach ($val in $recent) {
        $normalized = ($val - $min) / $range
        $idx = [int][math]::Floor($normalized * ($glyphs.Count - 1))
        if ($idx -lt 0) { $idx = 0 }
        if ($idx -ge $glyphs.Count) { $idx = $glyphs.Count - 1 }
        [void]$builder.Append($glyphs[$idx])
    }
    return $builder.ToString()
}

function Render-MeterBar {
    param(
        [double]$Value,
        [double]$MaxExpected = 1000.0,
        [int]$Width = 18
    )
    if ($MaxExpected -le 0) { $MaxExpected = 100 }
    $ratio = [math]::Min(1.0, [math]::Max(0.0, $Value / $MaxExpected))
    $filled = [int][math]::Round($ratio * $Width)
    $empty = $Width - $filled
    $bar = ("█" * $filled) + ("░" * $empty)
    return $bar
}

# ==============================================================================
# 4. BASELINE IDLE LATENCY CALIBRATION
# ==============================================================================
Write-Host "`n[1/3] Measuring baseline idle latency to $PingTarget (5 samples)..." -ForegroundColor Cyan
$baselineSamples = @()
for ($i = 1; $i -le 5; $i++) {
    $sample = Get-FastPingSample -Target $PingTarget -TimeoutMs 1200
    if ($null -ne $sample) {
        $baselineSamples += $sample
        Write-Host "  Sample ${i}: $sample ms" -ForegroundColor DarkGray
    } else {
        Write-Host "  Sample ${i}: Timed out" -ForegroundColor Yellow
    }
    Start-Sleep -Milliseconds 250
}

if ($baselineSamples.Count -gt 0) {
    $baselinePing = [math]::Round(($baselineSamples | Measure-Object -Average).Average, 1)
    $baselineMin = [math]::Round(($baselineSamples | Measure-Object -Minimum).Minimum, 1)
    $baselineMax = [math]::Round(($baselineSamples | Measure-Object -Maximum).Maximum, 1)
    Write-Host "[✓] Baseline Idle Ping: $baselinePing ms (min: $baselineMin ms, max: $baselineMax ms)" -ForegroundColor Green
} else {
    $baselinePing = 20.0
    Write-Host "[!] Ping to $PingTarget timed out during baseline. Using fallback estimated baseline (20.0 ms)." -ForegroundColor Yellow
}

# ==============================================================================
# 5. ASYNC WORKER SETUP (RUNSPACE POOL)
# ==============================================================================
Write-Host "`n[2/3] Initializing $threads traffic worker threads..." -ForegroundColor Cyan

$cancellationTokenSource = New-Object System.Threading.CancellationTokenSource
$token = $cancellationTokenSource.Token
$counter = New-Object NetStressAtomicCounters

# Upload payload generation: in-memory chunk
$payloadBytesCount = $PayloadChunkMB * 1024 * 1024
$uploadPayload = New-Object byte[] $payloadBytesCount
$rng = New-Object System.Random
$rng.NextBytes($uploadPayload)

$runspacePool = [runspacefactory]::CreateRunspacePool(1, $threads + 2)
$runspacePool.Open()

# Asynchronous HTTP Stream Worker Script
$workerScript = {
    param(
        $Token,
        $WorkerMode,
        $WorkerId,
        $CounterObj,
        $UploadBytes,
        $DownUrl,
        $UpUrl
    )

    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.MaxConnectionsPerServer = 512
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(15)

    $readBuffer = New-Object byte[] 262144 # 256KB buffer

    while (-not $Token.IsCancellationRequested) {
        try {
            $isDownload = ($WorkerMode -eq "Download") -or ($WorkerMode -eq "Duplex" -and ($WorkerId % 2 -eq 0))
            if ($isDownload) {
                $response = $client.GetAsync($DownUrl, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $Token).GetAwaiter().GetResult()
                if ($response.IsSuccessStatusCode) {
                    $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                    while (-not $Token.IsCancellationRequested) {
                        $bytesRead = $stream.Read($readBuffer, 0, $readBuffer.Length)
                        if ($bytesRead -le 0) { break }
                        $CounterObj.AddDownload([long]$bytesRead)
                    }
                    $stream.Dispose()
                } else {
                    Start-Sleep -Milliseconds 200
                }
                $response.Dispose()
            } else {
                $content = [System.Net.Http.ByteArrayContent]::new($UploadBytes)
                $response = $client.PostAsync($UpUrl, $content, $Token).GetAwaiter().GetResult()
                if ($response.IsSuccessStatusCode) {
                    $CounterObj.AddUpload([long]$UploadBytes.Length)
                } else {
                    Start-Sleep -Milliseconds 200
                }
                $content.Dispose()
                $response.Dispose()
            }
        } catch {
            Start-Sleep -Milliseconds 40
        }
    }
    $client.Dispose()
}

$asyncJobs = @()
for ($w = 0; $w -lt $threads; $w++) {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $runspacePool
    [void]$ps.AddScript($workerScript)
    [void]$ps.AddArgument($token)
    [void]$ps.AddArgument($Mode)
    [void]$ps.AddArgument($w)
    [void]$ps.AddArgument($counter)
    [void]$ps.AddArgument($uploadPayload)
    [void]$ps.AddArgument($DownloadUri)
    [void]$ps.AddArgument($UploadUri)
    $asyncJobs += [PSCustomObject]@{
        PowerShell = $ps
        Handle     = $ps.BeginInvoke()
    }
}

# ==============================================================================
# 6. REAL-TIME MONITORING & ANSI DASHBOARD
# ==============================================================================
Write-Host "[3/3] Saturated traffic engine running! Monitoring link in real-time...`n" -ForegroundColor Green

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$lastDown = 0L
$lastUp = 0L
$pingHistory = @()
$timelineData = @()
$maxLoadedPing = 0.0
$totalLostPackets = 0
$totalPingSamples = 0
$lastPingMs = $baselinePing
$maxObservedMbps = 100.0

# Prepare terminal capabilities
$isAnsiSupported = -not $SimpleDisplay -and [Environment]::UserInteractive -and -not [Console]::IsOutputRedirected

if ($isAnsiSupported) {
    [Console]::CursorVisible = $false
} else {
    Write-Host ("{0,-7} | {1,-11} | {2,-11} | {3,-11} | {4,-15} | {5,-8} | {6,-16}" -f `
        "Time", "Down(Mbps)", "Up(Mbps)", "Total(Mbps)", "Ping (ms)", "Jitter", "Status") -ForegroundColor Gray
    Write-Host ("-" * 85) -ForegroundColor DarkGray
}

$cleanTeardownDone = $false

try {
    $lastSampleSec = 0.0
    while ($stopwatch.Elapsed.TotalSeconds -lt $Duration) {
        $loopStart = [System.Diagnostics.Stopwatch]::GetTimestamp()
        Start-Sleep -Milliseconds 980

        $curTimeSec = $stopwatch.Elapsed.TotalSeconds
        $intervalSec = if ($lastSampleSec -gt 0) { [math]::Max(0.1, $curTimeSec - $lastSampleSec) } else { 1.0 }
        $lastSampleSec = $curTimeSec

        $elapsedSec = [math]::Round($curTimeSec, 1)
        $curDown = $counter.GetDownload()
        $curUp = $counter.GetUpload()

        $deltaDown = $curDown - $lastDown
        $deltaUp = $curUp - $lastUp
        $lastDown = $curDown
        $lastUp = $curUp

        $downMbps = [math]::Round(($deltaDown * 8) / ($intervalSec * 1000000.0), 2)
        $upMbps = [math]::Round(($deltaUp * 8) / ($intervalSec * 1000000.0), 2)
        $totalMbps = [math]::Round((($deltaDown + $deltaUp) * 8) / ($intervalSec * 1000000.0), 2)
        if ($totalMbps -gt $maxObservedMbps) { $maxObservedMbps = $totalMbps }

        $transferredMB = [math]::Round(($curDown + $curUp) / (1024 * 1024), 1)

        # Ping & Jitter measurement
        $totalPingSamples++
        $pingMs = Get-FastPingSample -Target $PingTarget -TimeoutMs 900
        $jitter = 0.0

        if ($null -ne $pingMs) {
            $pingHistory += $pingMs
            if ($pingMs -gt $maxLoadedPing) { $maxLoadedPing = $pingMs }
            $deltaPing = [math]::Round($pingMs - $baselinePing, 1)
            $jitter = [math]::Round([math]::Abs($pingMs - $lastPingMs), 1)
            $lastPingMs = $pingMs

            $assessment = Get-BufferbloatAssessment -DeltaMs $deltaPing -PacketLossRate ($totalLostPackets / [math]::Max(1, $totalPingSamples))
            $statusText = $assessment.Title
            $statusColor = $assessment.Color
            $pingFormatted = "$pingMs ms (+$deltaPing ms)"
        } else {
            $totalLostPackets++
            $deltaPing = $null
            $pingFormatted = "TIMED OUT"
            $statusText = "PACKET LOSS"
            $statusColor = "Red"
        }

        # Record timeline point
        $timelineData += [PSCustomObject]@{
            Timestamp    = (Get-Date).ToString("o")
            ElapsedSec   = $elapsedSec
            DownBytes    = $curDown
            UpBytes      = $curUp
            DownMbps     = $downMbps
            UpMbps       = $upMbps
            TotalMbps    = $totalMbps
            TotalMB      = $transferredMB
            PingMs       = $pingMs
            DeltaPingMs  = $deltaPing
            JitterMs     = $jitter
            Status       = $statusText
        }

        # Visual rendering
        if ($isAnsiSupported) {
            # Compute current stats
            $lossPct = [math]::Round(($totalLostPackets / [math]::Max(1, $totalPingSamples)) * 100, 1)
            $sparkline = Render-Sparkline -Values $pingHistory -MaxItems 24
            $downBar = Render-MeterBar -Value $downMbps -MaxExpected $maxObservedMbps -Width 16
            $upBar   = Render-MeterBar -Value $upMbps -MaxExpected $maxObservedMbps -Width 16
            $progressPct = [math]::Min(100, [int][math]::Round(($elapsedSec / $Duration) * 100))
            $progressBar = ("=" * [int]($progressPct / 5)) + (" " * (20 - [int]($progressPct / 5)))
            $currentGrade = if ($pingHistory.Count -gt 0) {
                $avgLoaded = ($pingHistory | Measure-Object -Average).Average
                (Get-BufferbloatAssessment -DeltaMs ($avgLoaded - $baselinePing) -PacketLossRate ($totalLostPackets / $totalPingSamples)).Grade
            } else { "N/A" }

            # ANSI Clear & Home
            $esc = [char]27
            $dashboard = @"
$esc[2J$esc[H
╔══════════════════════════════════════════════════════════════════════════════╗
║             INVOKE-NETSTRESS: REAL-TIME NETWORK SATURATION ENGINE            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ Profile: $("{0,-9}" -f $Intensity) | Mode: $("{0,-8}" -f $Mode) | Sockets: $("{0,-3}" -f $threads) | Ping Target: $("{0,-15}" -f $PingTarget) ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ PROGRESS   : [$progressBar] $progressPct% (${elapsedSec}s / ${Duration}s)
║ DATA STATS : Total Transferred: $transferredMB MB | Peak Link Rate: $maxObservedMbps Mbps
╠══════════════════════════════════════════════════════════════════════════════╣
║ THROUGHPUT :
║   • Download : [$downBar] $("{0,8:N2}" -f $downMbps) Mbps
║   • Upload   : [$upBar] $("{0,8:N2}" -f $upMbps) Mbps
║   • Combined : $("{0,8:N2}" -f $totalMbps) Mbps
╠══════════════════════════════════════════════════════════════════════════════╣
║ LATENCY & BUFFERBLOAT :
║   • Baseline Ping : $baselinePing ms
║   • Current Ping  : $("{0,-18}" -f $pingFormatted) Jitter: ${jitter} ms
║   • Ping Sparkline: [$sparkline]
║   • Packet Loss   : $totalLostPackets / $totalPingSamples ($lossPct%)
║   • Active Grade  : [ GRADE: $currentGrade ] - $statusText
╚══════════════════════════════════════════════════════════════════════════════╝
  Press [Ctrl+C] to abort stress test early and generate final reports.
"@
            [Console]::Write($dashboard)
        } else {
            Write-Host ("{0,-7} | {1,11} | {2,11} | {3,11} | {4,-15} | {5,8} | " -f `
                "${elapsedSec}s", "$downMbps", "$upMbps", "$totalMbps", $pingFormatted, "${jitter}ms") -NoNewline
            Write-Host "$statusText" -ForegroundColor $statusColor
        }
    }
} finally {
    if (-not $cleanTeardownDone) {
        $cleanTeardownDone = $true
        if ($isAnsiSupported) {
            [Console]::CursorVisible = $true
            Write-Host "`n"
        }

        Write-Host "`nStopping stress traffic workers cleanly..." -ForegroundColor DarkGray
        $cancellationTokenSource.Cancel()
        Start-Sleep -Milliseconds 400

        foreach ($job in $asyncJobs) {
            try {
                $job.PowerShell.EndInvoke($job.Handle)
                $job.PowerShell.Dispose()
            } catch {}
        }
        $runspacePool.Dispose()
        $stopwatch.Stop()
    }
}

# ==============================================================================
# 7. SUMMARY STATISTICS COMPUTATION
# ==============================================================================
$testDurationSec = [math]::Max(1.0, [math]::Round($stopwatch.Elapsed.TotalSeconds, 2))
$totalBytesDown = $counter.GetDownload()
$totalBytesUp   = $counter.GetUpload()
$totalBytesAll  = $totalBytesDown + $totalBytesUp

$totalMBTransferred = [math]::Round($totalBytesAll / (1024 * 1024), 2)
$avgDownMbps = [math]::Round(($totalBytesDown * 8) / ($testDurationSec * 1000000.0), 2)
$avgUpMbps   = [math]::Round(($totalBytesUp * 8) / ($testDurationSec * 1000000.0), 2)
$avgTotalMbps = [math]::Round(($totalBytesAll * 8) / ($testDurationSec * 1000000.0), 2)

$packetLossRate = if ($totalPingSamples -gt 0) { $totalLostPackets / $totalPingSamples } else { 0.0 }
$packetLossPct  = [math]::Round($packetLossRate * 100, 2)

if ($pingHistory.Count -gt 0) {
    $sortedPings = $pingHistory | Sort-Object
    $avgLoadedPing = [math]::Round(($pingHistory | Measure-Object -Average).Average, 1)
    $minLoadedPing = [math]::Round(($pingHistory | Measure-Object -Minimum).Minimum, 1)
    $maxLoadedPing = [math]::Round(($pingHistory | Measure-Object -Maximum).Maximum, 1)
    $deltaAvgPing  = [math]::Round($avgLoadedPing - $baselinePing, 1)

    # Percentiles
    $p50Index = [int][math]::Floor($sortedPings.Count * 0.50)
    $p95Index = [int][math]::Floor($sortedPings.Count * 0.95)
    $p99Index = [int][math]::Floor($sortedPings.Count * 0.99)
    $p50Ping  = $sortedPings[[math]::Min($p50Index, $sortedPings.Count - 1)]
    $p95Ping  = $sortedPings[[math]::Min($p95Index, $sortedPings.Count - 1)]
    $p99Ping  = $sortedPings[[math]::Min($p99Index, $sortedPings.Count - 1)]

    # Jitter calculation (Mean absolute difference)
    $jitterList = @()
    for ($k = 1; $k -lt $pingHistory.Count; $k++) {
        $jitterList += [math]::Abs($pingHistory[$k] - $pingHistory[$k-1])
    }
    $avgJitter = if ($jitterList.Count -gt 0) { [math]::Round(($jitterList | Measure-Object -Average).Average, 1) } else { 0.0 }
} else {
    $avgLoadedPing = 0.0
    $minLoadedPing = 0.0
    $maxLoadedPing = 0.0
    $deltaAvgPing  = 0.0
    $p50Ping = 0.0
    $p95Ping = 0.0
    $p99Ping = 0.0
    $avgJitter = 0.0
}

$finalAssessment = Get-BufferbloatAssessment -DeltaMs $deltaAvgPing -PacketLossRate $packetLossRate

# Display Final Summary Banner
Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    NETSTRESS FINAL TEST AUDIT                         ║" -ForegroundColor Yellow
Write-Host "╠═══════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║ BUFFERBLOAT GRADE     : [ $($finalAssessment.Grade) ] - $($finalAssessment.Title)" -ForegroundColor $finalAssessment.Color
Write-Host "║ Data Transferred      : $totalMBTransferred MB ($([math]::Round($totalBytesDown/(1024*1024),1)) MB Down / $([math]::Round($totalBytesUp/(1024*1024),1)) MB Up)" -ForegroundColor White
Write-Host "║ Avg Saturated Speed   : $avgTotalMbps Mbps (Down: $avgDownMbps Mbps | Up: $avgUpMbps Mbps)" -ForegroundColor Yellow
Write-Host "║ Baseline Idle Latency : $baselinePing ms" -ForegroundColor White
Write-Host "║ Loaded Avg Latency    : $avgLoadedPing ms (+$deltaAvgPing ms under saturation)" -ForegroundColor White
Write-Host "║ Loaded Latency Spread : Min: $minLoadedPing ms | Max Peak: $maxLoadedPing ms" -ForegroundColor White
Write-Host "║ Latency Percentiles   : p50: $p50Ping ms | p95: $p95Ping ms | p99: $p99Ping ms" -ForegroundColor White
Write-Host "║ Average Loaded Jitter : $avgJitter ms" -ForegroundColor White
Write-Host "║ Packet Loss           : $totalLostPackets / $totalPingSamples ($packetLossPct%)" -ForegroundColor $(if ($packetLossPct -gt 0) { "Red" } else { "Green" })
Write-Host "║ Assessment            : $($finalAssessment.Description)" -ForegroundColor DarkGray
Write-Host "╚═══════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ==============================================================================
# 8. MULTI-FORMAT REPORT GENERATION (JSON, CSV, HTML)
# ==============================================================================
$reportData = [PSCustomObject]@{
    Metadata = [PSCustomObject]@{
        SuiteName         = "Invoke-NetStress"
        Version           = "1.0.0"
        TimestampUtc      = (Get-Date).ToUniversalTime().ToString("o")
        Operator          = $env:USERNAME
        ComputerName      = $env:COMPUTERNAME
        OperatingSystem   = [System.Environment]::OSVersion.ToString()
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Authorized        = $true
    }
    Parameters = [PSCustomObject]@{
        Intensity     = $Intensity
        Threads       = $threads
        Mode          = $Mode
        DurationSec   = $Duration
        PingTarget    = $PingTarget
        DownloadUri   = $DownloadUri
        UploadUri     = $UploadUri
    }
    Summary = [PSCustomObject]@{
        BufferbloatGrade     = $finalAssessment.Grade
        BufferbloatTitle     = $finalAssessment.Title
        BufferbloatSummary   = $finalAssessment.Description
        BaselinePingMs       = $baselinePing
        AvgLoadedPingMs      = $avgLoadedPing
        DeltaPingMs          = $deltaAvgPing
        MinLoadedPingMs      = $minLoadedPing
        MaxLoadedPingMs      = $maxLoadedPing
        Percentile50PingMs   = $p50Ping
        Percentile95PingMs   = $p95Ping
        Percentile99PingMs   = $p99Ping
        AvgJitterMs          = $avgJitter
        TotalLostPackets     = $totalLostPackets
        TotalPingSamples     = $totalPingSamples
        PacketLossPct        = $packetLossPct
        AvgDownloadMbps      = $avgDownMbps
        AvgUploadMbps        = $avgUpMbps
        AvgTotalMbps         = $avgTotalMbps
        PeakObservedMbps     = $maxObservedMbps
        TotalTransferredMB   = $totalMBTransferred
        ActualDurationSec    = $testDurationSec
    }
    Timeline = $timelineData
}

if (-not $NoReport) {
    if (-not (Test-Path -Path $ReportPath)) {
        New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
    }

    $timeTag = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $baseName = "NetStress_Report_$timeTag"

    # 1. JSON Export
    $jsonPath = Join-Path $ReportPath "$baseName.json"
    $reportData | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding utf8
    Write-Host "[✓] Exported JSON report: $jsonPath" -ForegroundColor Green

    # 2. CSV Export (Timeline + Summary + Direct Folder Copy)
    $csvPath = Join-Path $ReportPath "$baseName.csv"
    $enhancedTimeline = $timelineData | ForEach-Object {
        [PSCustomObject]@{
            Target           = $PingTarget
            Intensity        = $Intensity
            DurationSec      = $Duration
            ElapsedSec       = $_.ElapsedSec
            DownMbps         = $_.DownMbps
            UpMbps           = $_.UpMbps
            TotalMbps        = $_.TotalMbps
            TotalMB          = $_.TotalMB
            PingMs           = $_.PingMs
            DeltaPingMs      = $_.DeltaPingMs
            JitterMs         = $_.JitterMs
            Status           = $_.Status
            BufferbloatGrade = $finalAssessment.Grade
            Timestamp        = $_.Timestamp
        }
    }
    $enhancedTimeline | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

    # Also export dedicated Summary CSV
    $summaryCsvPath = Join-Path $ReportPath "NetStress_Summary_$timeTag.csv"
    [PSCustomObject]@{
        Timestamp          = (Get-Date).ToString("o")
        TargetHost         = $PingTarget
        Intensity          = $Intensity
        Sockets            = $threads
        DurationSec        = $testDurationSec
        BufferbloatGrade   = $finalAssessment.Grade
        BufferbloatTitle   = $finalAssessment.Title
        AvgTotalMbps       = $avgTotalMbps
        AvgDownMbps        = $avgDownMbps
        AvgUpMbps          = $avgUpMbps
        PeakObservedMbps   = $maxObservedMbps
        TotalMBTransferred = $totalMBTransferred
        BaselinePingMs     = $baselinePing
        AvgLoadedPingMs    = $avgLoadedPing
        DeltaPingMs        = $deltaAvgPing
        MaxLoadedPingMs    = $maxLoadedPing
        AvgJitterMs        = $avgJitter
        PacketLossPct      = $packetLossPct
        TotalPacketsLost   = $totalLostPackets
        TotalPingSamples   = $totalPingSamples
    } | Export-Csv -Path $summaryCsvPath -NoTypeInformation -Encoding utf8

    # Save direct CSV copy into the working directory
    $rootCsvPath = "NetStress_Latest_Report.csv"
    $enhancedTimeline | Export-Csv -Path $rootCsvPath -NoTypeInformation -Encoding utf8

    Write-Host "[✓] Exported CSV Timeline Report : $csvPath" -ForegroundColor Green
    Write-Host "[✓] Exported CSV Summary Report  : $summaryCsvPath" -ForegroundColor Green
    Write-Host "[✓] Saved CSV in Working Folder  : $rootCsvPath" -ForegroundColor Green

    # 3. HTML Export (Self-contained, dark-mode with SVG charts)
    $htmlPath = Join-Path $ReportPath "$baseName.html"
    
    # Generate SVG Path for Throughput
    $svgW = 760
    $svgH = 200
    $ptsCount = $timelineData.Count

    $throughSvgPoints = ""
    $pingSvgPoints = ""
    if ($ptsCount -gt 1) {
        $maxChartMbps = [math]::Max(10.0, $maxObservedMbps * 1.1)
        $maxChartPing = [math]::Max(50.0, $maxLoadedPing * 1.2)

        for ($idx = 0; $idx -lt $ptsCount; $idx++) {
            $pt = $timelineData[$idx]
            $x = [math]::Round(($idx / ($ptsCount - 1)) * $svgW, 1)
            $yMbps = [math]::Round($svgH - (($pt.TotalMbps / $maxChartMbps) * $svgH), 1)
            $throughSvgPoints += "$x,$yMbps "

            $pVal = if ($null -ne $pt.PingMs) { $pt.PingMs } else { $maxChartPing }
            $yPing = [math]::Round($svgH - (($pVal / $maxChartPing) * $svgH), 1)
            $pingSvgPoints += "$x,$yPing "
        }
    }

    $gradeColorHex = switch ($finalAssessment.Grade) {
        "A+" { "#00f0ff" }
        "A"  { "#10b981" }
        "B"  { "#34d399" }
        "C"  { "#f59e0b" }
        "D"  { "#ec4899" }
        default { "#ef4444" }
    }

    $tableRowsHtml = ""
    foreach ($row in $timelineData) {
        $pMs = if ($null -ne $row.PingMs) { "$($row.PingMs) ms" } else { '<span style="color:#ef4444">LOSS</span>' }
        $dMs = if ($null -ne $row.DeltaPingMs) { "+$($row.DeltaPingMs) ms" } else { "-" }
        $tableRowsHtml += "<tr><td>$($row.ElapsedSec)s</td><td>$($row.DownMbps)</td><td>$($row.UpMbps)</td><td>$($row.TotalMbps)</td><td>$($row.TotalMB) MB</td><td>$pMs</td><td>$dMs</td><td>$($row.JitterMs) ms</td><td>$($row.Status)</td></tr>"
    }

    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NetStress Report - $($reportData.Metadata.TimestampUtc)</title>
  <style>
    :root {
      --bg: #0b0f19;
      --card: #151d30;
      --border: #232f48;
      --text: #f1f5f9;
      --muted: #94a3b8;
      --accent: #38bdf8;
      --grade: $gradeColorHex;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: var(--bg); color: var(--text); padding: 30px 20px; line-height: 1.5; }
    .container { max-width: 1080px; margin: 0 auto; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); padding-bottom: 20px; margin-bottom: 25px; }
    .header h1 { font-size: 24px; font-weight: 700; color: #fff; letter-spacing: -0.5px; }
    .badge { background: rgba(56, 189, 248, 0.15); color: var(--accent); padding: 4px 12px; border-radius: 9999px; font-size: 12px; font-weight: 600; }
    .grade-hero { display: flex; align-items: center; gap: 24px; background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 24px; margin-bottom: 25px; box-shadow: 0 4px 20px rgba(0,0,0,0.4); }
    .grade-box { width: 90px; height: 90px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 44px; font-weight: 900; background: rgba(255,255,255,0.04); border: 2px solid var(--grade); color: var(--grade); }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; margin-bottom: 25px; }
    .card { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 18px; }
    .card-title { font-size: 12px; font-weight: 600; text-transform: uppercase; color: var(--muted); margin-bottom: 6px; }
    .card-value { font-size: 22px; font-weight: 700; color: #fff; }
    .card-sub { font-size: 12px; color: var(--muted); margin-top: 4px; }
    .chart-box { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 20px; margin-bottom: 25px; }
    .chart-box h3 { font-size: 15px; margin-bottom: 15px; color: #fff; display: flex; justify-content: space-between; }
    svg { width: 100%; height: auto; display: block; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; text-align: left; }
    th { background: rgba(255,255,255,0.03); color: var(--muted); padding: 10px 12px; border-bottom: 1px solid var(--border); }
    td { padding: 8px 12px; border-bottom: 1px solid rgba(255,255,255,0.05); color: var(--text); }
    tr:hover { background: rgba(255,255,255,0.02); }
    .footer { text-align: center; color: var(--muted); font-size: 12px; margin-top: 40px; border-top: 1px solid var(--border); padding-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div>
        <h1>⚡ Invoke-NetStress Benchmark Report</h1>
        <p style="font-size:13px; color:var(--muted); margin-top:4px;">Target: <strong>$PingTarget</strong> | Operator: <strong>$($reportData.Metadata.Operator)</strong> | Host: <strong>$($reportData.Metadata.ComputerName)</strong></p>
      </div>
      <div>
        <span class="badge">$Intensity Profile ($threads Workers)</span>
      </div>
    </div>

    <div class="grade-hero">
      <div class="grade-box">$($finalAssessment.Grade)</div>
      <div>
        <h2 style="color:var(--grade); font-size:22px; margin-bottom:4px;">$($finalAssessment.Title)</h2>
        <p style="color:var(--text); font-size:14px; max-width:700px;">$($finalAssessment.Description)</p>
        <p style="color:var(--muted); font-size:12px; margin-top:6px;">Baseline Idle: <strong>$baselinePing ms</strong> ➔ Loaded Average: <strong>$avgLoadedPing ms</strong> (Delta: <strong>+$deltaAvgPing ms</strong>)</p>
      </div>
    </div>

    <div class="grid">
      <div class="card">
        <div class="card-title">Avg Saturated Throughput</div>
        <div class="card-value">$avgTotalMbps <span style="font-size:14px; font-weight:normal;">Mbps</span></div>
        <div class="card-sub">Down: $avgDownMbps Mbps | Up: $avgUpMbps Mbps</div>
      </div>
      <div class="card">
        <div class="card-title">Peak Bandwidth Burst</div>
        <div class="card-value">$maxObservedMbps <span style="font-size:14px; font-weight:normal;">Mbps</span></div>
        <div class="card-sub">Total Transferred: $totalMBTransferred MB</div>
      </div>
      <div class="card">
        <div class="card-title">Bufferbloat Latency Spike</div>
        <div class="card-value">+$deltaAvgPing <span style="font-size:14px; font-weight:normal;">ms</span></div>
        <div class="card-sub">Peak Ping: $maxLoadedPing ms (p95: $p95Ping ms)</div>
      </div>
      <div class="card">
        <div class="card-title">Packet Reliability</div>
        <div class="card-value">$(100 - $packetLossPct)%</div>
        <div class="card-sub">Loss: $packetLossPct% ($totalLostPackets lost) | Jitter: ${avgJitter}ms</div>
      </div>
    </div>

    <div class="chart-box">
      <h3><span>Throughput Saturation Over Time (Mbps)</span> <span style="font-size:12px; color:var(--muted)">Peak: $maxObservedMbps Mbps</span></h3>
      <svg viewBox="0 0 $svgW $svgH">
        <line x1="0" y1="0" x2="$svgW" y2="0" stroke="rgba(255,255,255,0.08)" />
        <line x1="0" y1="100" x2="$svgW" y2="100" stroke="rgba(255,255,255,0.08)" />
        <line x1="0" y1="$svgH" x2="$svgW" y2="$svgH" stroke="rgba(255,255,255,0.15)" />
        <polyline fill="none" stroke="#38bdf8" stroke-width="2.5" points="$throughSvgPoints" />
      </svg>
    </div>

    <div class="chart-box">
      <h3><span>Latency Response Under Saturation (ms)</span> <span style="font-size:12px; color:var(--muted)">Baseline: $baselinePing ms | Peak: $maxLoadedPing ms</span></h3>
      <svg viewBox="0 0 $svgW $svgH">
        <line x1="0" y1="0" x2="$svgW" y2="0" stroke="rgba(255,255,255,0.08)" />
        <line x1="0" y1="100" x2="$svgW" y2="100" stroke="rgba(255,255,255,0.08)" />
        <line x1="0" y1="$svgH" x2="$svgW" y2="$svgH" stroke="rgba(255,255,255,0.15)" />
        <polyline fill="none" stroke="#f59e0b" stroke-width="2.5" points="$pingSvgPoints" />
      </svg>
    </div>

    <div class="chart-box">
      <h3 style="margin-bottom:12px;">Timeline Telemetry Log</h3>
      <div style="max-height: 380px; overflow-y: auto;">
        <table>
          <thead>
            <tr>
              <th>Time</th>
              <th>Down Mbps</th>
              <th>Up Mbps</th>
              <th>Total Mbps</th>
              <th>Transferred</th>
              <th>Ping</th>
              <th>Delta</th>
              <th>Jitter</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            $tableRowsHtml
          </tbody>
        </table>
      </div>
    </div>

    <div class="footer">
      Generated automatically by <strong>Invoke-NetStress</strong> v1.0.0 &bull; Network Stress & Bufferbloat Suite
    </div>
  </div>
</body>
</html>
"@

    [System.IO.File]::WriteAllText($htmlPath, $htmlContent, [System.Text.Encoding]::UTF8)
    Write-Host "[✓] Exported Interactive HTML report: $htmlPath`n" -ForegroundColor Green
}

if ($PassThru) {
    return $reportData
}

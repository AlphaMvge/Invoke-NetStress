# ⚡ Invoke-NetStress

[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Code Style](https://img.shields.io/badge/Code%20Style-PSScriptAnalyzer-brightgreen.svg)](https://github.com/PowerShell/PSScriptAnalyzer)

> **High-Performance Multi-Threaded Bandwidth Saturation & Bufferbloat Suite for PowerShell.**

`Invoke-NetStress` is a production-grade, zero-dependency network benchmarking tool designed to push bandwidth links to true queue saturation without requiring third-party listeners on the destination server. It features an **interactive pre-flight target & intensity wizard**, an **in-place real-time ANSI terminal dashboard**, **live latency sparklines**, an automated **Bufferbloat Quality Grading engine ($A^+$ to $F$)**, strict **authorization guardrails**, and **instant report generation (HTML, JSON, CSV)**.

---

## 📸 Real-Time ANSI Terminal Dashboard

```text
╔══════════════════════════════════════════════════════════════════════════════╗
║             INVOKE-NETSTRESS: REAL-TIME NETWORK SATURATION ENGINE            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ Profile: Medium    | Mode: Duplex   | Sockets: 16  | Ping Target: 1.1.1.1     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ PROGRESS   : [============>       ] 60% (18.0s / 30s)
║ DATA STATS : Total Transferred: 845.2 MB | Peak Link Rate: 428.15 Mbps
╠══════════════════════════════════════════════════════════════════════════════╣
║ THROUGHPUT :
║   • Download : [████████████░░░░]   312.40 Mbps
║   • Upload   : [████░░░░░░░░░░░░]   115.75 Mbps
║   • Combined :                      428.15 Mbps
╠══════════════════════════════════════════════════════════════════════════════╣
║ LATENCY & BUFFERBLOAT :
║   • Baseline Ping : 14.2 ms
║   • Current Ping  : 23.8 ms (+9.6 ms)  Jitter: 2.1 ms
║   • Ping Sparkline: [ ▂▃▅▇█▆▄▃  ▂▃▅▆ ]
║   • Packet Loss   : 0 / 18 (0.0%)
║   • Active Grade  : [ GRADE: A ] - Great Queue Discipline
╚══════════════════════════════════════════════════════════════════════════════╝
  Press [Ctrl+C] to abort stress test early and generate final reports.
```

---

## 🚀 Key Features

- 🏎️ **Hardware-Level Asynchronous Sockets**: Utilizes .NET `HttpClient` with RunspacePool concurrency to reliably saturate multi-gigabit links with minimal CPU overhead.
- 🎯 **Interactive Pre-Flight Wizard**: Prompts for target IP and displays rated throughput estimates across 4 intensity profiles before execution.
- 📊 **Real-Time ANSI Dashboard**: Flicker-free console monitoring complete with live throughput meters, active latency sparklines, and second-by-second link statistics.
- 📉 **Bufferbloat & Queue Delay Grading**: Continuously measures bufferbloat and assigns an industry-standard quality grade ($A^+$ to $F$) based on latency delta under saturation and packet loss.
- 🌐 **Public CDN & Private LAN / Air-Gapped Testing**: Supports public high-capacity edge networks (Cloudflare CDN) as well as internal enterprise endpoints (`-DownloadUri`, `-UploadUri`) for private LAN, SD-WAN, and VPN stress testing.
- 🛡️ **Built-In Authorization Guardrails**: Mandatory consent mechanism (`-AcknowledgeAuthorization` or interactive prompt) prevents accidental or unapproved network flooding.
- 📑 **Instant CSV Reports Saved in Root Folder & Reports Directory**: Automatically outputs comprehensive `.csv` telemetry right into your working folder as well as the `reports/` archive.
- 🔀 **Cross-Platform & Cross-Version**: Fully compatible with Windows PowerShell 5.1 and modern PowerShell 7+ on Windows, Linux, and macOS.

---

## 🎮 Interactive Pre-Flight Configuration

When launched interactively, `Invoke-NetStress` guides you through a safe, two-step pre-flight menu before opening any network sockets:

```text
╔══════════════════════════════════════════════════════════════════════════════╗
║                 INVOKE-NETSTRESS: PRE-FLIGHT CONFIGURATION                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

[STEP 1/2] TARGET SPECIFICATION
 Enter Target IP or Hostname to stress test [1.1.1.1]: 8.8.8.8

[STEP 2/2] SELECT TRAFFIC INTENSITY (TARGET: 8.8.8.8)
 ------------------------------------------------------------------------------
  [1] Low      |  4 Sockets  | Est. Output: ~150 - 500 Mbps   (Light / Baseline Check)
  [2] Medium   | 16 Sockets  | Est. Output: ~500 - 1,200 Mbps (Standard Gigabit Link)
  [3] High     | 32 Sockets  | Est. Output: ~1.2 - 2.5 Gbps   (Multi-Gig WAN / Fiber)
  [4] Extreme  | 64 Sockets  | Est. Output: ~2.5 - 5.0+ Gbps  (Max Saturation / 10GbE)
 ------------------------------------------------------------------------------
 Select intensity profile [1-4] or name (Default: [2] Medium): 2

╔══════════════════════════════════════════════════════════════════════════════╗
║                          CONFIRM TEST PARAMETERS                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
  • Target Host      : 8.8.8.8
  • Intensity Level  : Medium (16 Sockets | Est. Output: ~500 - 1,200 Mbps)
 ------------------------------------------------------------------------------
 [?] Confirm these parameters and launch stress test? [Y/n]: y
 [✓] Parameters confirmed. Initializing engine...
```

---

## ⚡ 4 Intensity Profiles & Throughput Ratings

| Level | Profile | Sockets | Estimated Output | Best Used For |
|:---:|:---|:---:|:---|:---|
| **1** | **Low** | 4 | `~150 - 500 Mbps` | Initial connectivity check, DSL/Cable links, sensitive router queues. |
| **2** | **Medium** | 16 | `~500 - 1,200 Mbps` *(1.2 Gbps)* | Standard residential/office Gigabit broadband saturation test. *(Default)* |
| **3** | **High** | 32 | `~1.2 - 2.5 Gbps` | High-speed fiber, 2.5 Gbps multi-gigabit WAN circuits. |
| **4** | **Extreme** | 64 | `~2.5 - 5.0+ Gbps` *(up to 9.8 Gbps on LAN)* | 10GbE enterprise interfaces, datacenter links, maximum line-rate saturation. |

---

## 🏆 Bufferbloat Grading System

When a network connection is saturated, buffers in modems, routers, or switches fill up, inducing queue delays (bufferbloat). `Invoke-NetStress` measures the exact delta ($\Delta$) between your idle baseline ping and your loaded latency under full stress:

| Grade | Latency Delta ($\Delta$) | Link Status | Real-World Impact |
|:---:|:---:|:---|:---|
| **$A^+$** | $\le 5\text{ ms}$ | **Exceptional** | Active Queue Management (CAKE / fq_codel). Zero perceptible lag. |
| **A** | $5 - 15\text{ ms}$ | **Great** | Minimal queueing delay. Online gaming and VoIP remain pristine. |
| **B** | $15 - 30\text{ ms}$ | **Good** | Slight delay under full load. Smooth streaming & browsing. |
| **C** | $30 - 60\text{ ms}$ | **Fair** | Noticeable lag spikes during large downloads or cloud backups. |
| **D** | $60 - 120\text{ ms}$ | **Poor** | Severe latency surge. High packet buffering. |
| **F** | $> 120\text{ ms}$ or $>5\%$ loss | **Critical** | Unusable under saturation. Call drops, rubber-banding, timeout errors. |

---

## 📦 How to Run the Tests

### 1. Interactive Mode (With Live Prompts & Confirmation)
Prompts you for the target IP, allows selecting 1 of the 4 intensity presets, confirms your choice, and runs:
```powershell
.\Invoke-NetStress.ps1 -Duration 30 -AcknowledgeAuthorization
```

### 2. Direct CLI Run (Bypassing Prompts)
Specify the target IP and intensity directly on the command line:
```powershell
.\Invoke-NetStress.ps1 -PingTarget "1.1.1.1" -Intensity High -Duration 30 -AcknowledgeAuthorization
```

### 3. High-Speed Download Saturation Only
Test pure download saturation (64 sockets) with traditional scrolling output:
```powershell
.\Invoke-NetStress.ps1 -Mode Download -Intensity Extreme -Duration 45 -SimpleDisplay -AcknowledgeAuthorization
```

### 4. Private LAN / Enterprise Air-Gapped Testing
Stress-test an internal server, router, or firewall using custom web endpoints on your private subnet:
```powershell
.\Invoke-NetStress.ps1 `
    -DownloadUri "http://192.168.1.100:8080/large.bin" `
    -UploadUri "http://192.168.1.100:8080/upload" `
    -PingTarget "192.168.1.1" `
    -Intensity Extreme `
    -Duration 30 `
    -AcknowledgeAuthorization
```

### 5. Automated CI/CD & Pipeline Integration
Run headlessly and export the structured result object directly to PowerShell:
```powershell
$result = .\Invoke-NetStress.ps1 -Duration 15 -Intensity Low -NoReport -PassThru -AcknowledgeAuthorization
$result.Summary | Format-List BufferbloatGrade, AvgTotalMbps, DeltaPingMs, PacketLossPct
```

---

## 📊 Automated Reports & CSV Export

After each test completes, reports are automatically generated and saved:

```text
[✓] Exported CSV Timeline Report : reports\NetStress_Report_20260912_184800.csv
[✓] Exported CSV Summary Report  : reports\NetStress_Summary_20260912_184800.csv
[✓] Saved CSV in Working Folder  : NetStress_Latest_Report.csv
[✓] Exported Interactive HTML    : reports\NetStress_Report_20260912_184800.html
```

| Output File | Location | Content & Purpose |
|:---|:---|:---|
| **`NetStress_Latest_Report.csv`** | **Working Folder Root** | Direct second-by-second telemetry CSV saved right in your script folder for instant opening in Excel. |
| **`NetStress_Report_*.csv`** | `reports/` | Timestamped historical archive of second-by-second metrics (Mbps, Ping, Delta, Jitter, Status). |
| **`NetStress_Summary_*.csv`** | `reports/` | Executive summary metrics (Averages, Peaks, Latency Spread, Packet Loss, Bufferbloat Grade). |
| **`NetStress_Report_*.html`** | `reports/` | Self-contained dark-theme interactive HTML report with vector SVG latency and throughput charts. |
| **`NetStress_Report_*.json`** | `reports/` | Machine-readable telemetry for integration with automated monitoring pipelines. |

---

## 🛠️ Parameter Reference

| Parameter | Type | Default | Description |
|:---|:---:|:---:|:---|
| `-Intensity` | String | `Medium` | Preset intensity: `Low` (4), `Medium` (16), `High` (32), `Extreme` (64). |
| `-Mode` | String | `Duplex` | Traffic direction: `Duplex` (Simultaneous Down/Up), `Download`, `Upload`. |
| `-Duration` | Int | `30` | Duration of test in seconds (5 to 3600). |
| `-PingTarget` | String | `1.1.1.1` | Target IP or hostname to ping continuously for queue delay. |
| `-CustomThreads` | Int | `0` | Explicit socket count (overrides `-Intensity`). |
| `-DownloadUri` | String | *Cloudflare CDN* | HTTP/S endpoint for download streams. |
| `-UploadUri` | String | *Cloudflare CDN* | HTTP/S endpoint for upload streams. |
| `-PayloadChunkMB` | Int | `2` | Size of upload buffer chunks in megabytes. |
| `-AcknowledgeAuthorization` | Switch | `False` | Compliance flag confirming authorization to stress-test the network. |
| `-ReportPath` | String | `reports` | Output directory for HTML, JSON, and CSV exports. |
| `-NoReport` | Switch | `False` | Suppresses saving report files. |
| `-SimpleDisplay` | Switch | `False` | Disables ANSI dashboard for traditional scrolling output. |
| `-PassThru` | Switch | `False` | Outputs test result object directly to the PowerShell pipeline. |

---

## 🚀 Preparing & Pushing to GitHub

To publish this repository to your GitHub account:

### 1. Initialize Git & Create Initial Commit
```powershell
# Navigate to the project folder
cd C:\Users\Administrator\Documents\Invoke-NetStress

# Initialize local git repository
& "C:\Program Files\Git\cmd\git.exe" init

# Stage all project files (.gitignore will exclude reports and temp files)
& "C:\Program Files\Git\cmd\git.exe" add .

# Create your initial release commit
& "C:\Program Files\Git\cmd\git.exe" commit -m "feat: Initial release of Invoke-NetStress v1.0.0 with 4-tier intensity wizard & CSV reporting"
```

### 2. Link to Your GitHub Repository & Push
```powershell
# Rename default branch to main
& "C:\Program Files\Git\cmd\git.exe" branch -M main

# Add your GitHub remote (replace with your repository URL)
& "C:\Program Files\Git\cmd\git.exe" remote add origin https://github.com/<YOUR-USERNAME>/Invoke-NetStress.git

# Push to GitHub
& "C:\Program Files\Git\cmd\git.exe" push -u origin main
```

---

## 🧪 Testing & Verification

Run the automated test suite with [Pester](https://pester.dev/):
```powershell
Invoke-Pester -Path .\tests\Invoke-NetStress.Tests.ps1
```

Run syntax & best-practice analysis with [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer):
```powershell
Invoke-ScriptAnalyzer -Path .\Invoke-NetStress.ps1, .\Invoke-NetStress.psm1
```

---

## ⚖️ Legal & Ethical Compliance

> [!WARNING]
> Generating saturated network traffic consumes significant bandwidth and system resources. **You must only test networks, links, and devices that you personally own or have explicit, documented authorization to stress test.** Unauthorized saturation of third-party networks or internet service provider links may violate national cybersecurity laws and acceptable use terms.

---

## 📄 License

Distributed under the [MIT License](LICENSE).

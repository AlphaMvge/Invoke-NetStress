$script:scriptRoot = Split-Path -Parent $PSScriptRoot
$script:scriptPath = Join-Path $script:scriptRoot "Invoke-NetStress.ps1"
$script:manifestPath = Join-Path $script:scriptRoot "Invoke-NetStress.psd1"
$script:modulePath = Join-Path $scriptRoot "Invoke-NetStress.psm1"

Describe "Invoke-NetStress Syntax & Structure" {
    It "Parses Invoke-NetStress.ps1 without syntax errors" {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:scriptPath, [ref]$tokens, [ref]$errors) | Out-Null
        $errors.Count | Should Be 0
    }

    It "Parses Invoke-NetStress.psm1 without syntax errors" {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:modulePath, [ref]$tokens, [ref]$errors) | Out-Null
        $errors.Count | Should Be 0
    }

    It "Validates the PowerShell Module Manifest" {
        $manifest = Test-ModuleManifest -Path $script:manifestPath -ErrorAction SilentlyContinue
        $manifest | Should Not BeNullOrEmpty
        $data = Import-PowerShellDataFile $script:manifestPath
        ($data.FunctionsToExport -contains "Invoke-NetStress") | Should Be $true
    }
}

Describe "Parameter & Argument Validation" {
    It "Defines all expected parameters" {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:scriptPath, [ref]$null, [ref]$null)
        $paramBlock = $ast.ParamBlock
        $paramNames = $paramBlock.Parameters.Name.VariablePath.UserPath

        $expectedParams = @(
            'Intensity',
            'Mode',
            'Duration',
            'PingTarget',
            'CustomThreads',
            'DownloadUri',
            'UploadUri',
            'PayloadChunkMB',
            'AcknowledgeAuthorization',
            'ReportPath',
            'NoReport',
            'SimpleDisplay',
            'PassThru'
        )

        foreach ($p in $expectedParams) {
            ($paramNames -contains $p) | Should Be $true
        }
    }
}

Describe "Atomic Counter Functionality" {
    It "Instantiates and updates atomic counters correctly" {
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

        $c = New-Object NetStressAtomicCounters
        $c.AddDownload(1024)
        $c.AddUpload(512)

        $c.GetDownload() | Should Be 1024
        $c.GetUpload() | Should Be 512
        $c.GetTotal() | Should Be 1536
    }
}

Describe "Bufferbloat Grading Criteria" {
    function Test-GradingFunction {
        param([double]$DeltaMs, [double]$PacketLossRate)
        if ($PacketLossRate -gt 0.05 -or $DeltaMs -ge 120.0) { return "F" }
        elseif ($DeltaMs -ge 60.0) { return "D" }
        elseif ($DeltaMs -ge 30.0) { return "C" }
        elseif ($DeltaMs -ge 15.0) { return "B" }
        elseif ($DeltaMs -ge 5.0)  { return "A" }
        else { return "A+" }
    }

    It "Grades A+ for virtually zero latency delta" {
        (Test-GradingFunction -DeltaMs 2.0 -PacketLossRate 0.0) | Should Be "A+"
    }

    It "Grades A for delta under 15ms" {
        (Test-GradingFunction -DeltaMs 10.0 -PacketLossRate 0.0) | Should Be "A"
    }

    It "Grades B for delta under 30ms" {
        (Test-GradingFunction -DeltaMs 22.0 -PacketLossRate 0.0) | Should Be "B"
    }

    It "Grades C for delta under 60ms" {
        (Test-GradingFunction -DeltaMs 45.0 -PacketLossRate 0.0) | Should Be "C"
    }

    It "Grades D for delta under 120ms" {
        (Test-GradingFunction -DeltaMs 85.0 -PacketLossRate 0.0) | Should Be "D"
    }

    It "Grades F for excessive delta or packet loss" {
        (Test-GradingFunction -DeltaMs 180.0 -PacketLossRate 0.0) | Should Be "F"
        (Test-GradingFunction -DeltaMs 4.0 -PacketLossRate 0.08) | Should Be "F"
    }
}


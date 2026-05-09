# Silent GUT Test Runner for AI Agents
# Usage: .\scripts\run_tests_silent.ps1

$godotPath = "C:\Users\XSrkT\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
$gutScript = "addons/gut/gut_cmdln.gd"
$timeoutSeconds = 60

# Run Godot and capture BOTH output and errors to temporary files
$tempLog = "test_run.tmp"
$tempErr = "test_err.tmp"

# Clean up old logs
if (Test-Path $tempLog) { Remove-Item $tempLog }
if (Test-Path $tempErr) { Remove-Item $tempErr }

$process = Start-Process -FilePath $godotPath -ArgumentList "--path", ".", "-s", $gutScript, "--headless", "-gexit", "-glog=0" -NoNewWindow -PassThru -RedirectStandardOutput $tempLog -RedirectStandardError $tempErr

# Wait for process with timeout
$timeoutReached = $false
$timer = [System.Diagnostics.Stopwatch]::StartNew()
while (-not $process.HasExited) {
    if ($timer.Elapsed.TotalSeconds -gt $timeoutSeconds) {
        $timeoutReached = $true
        Stop-Process -Id $process.Id -Force
        break
    }
    Start-Sleep -Milliseconds 500
}
$timer.Stop()

if ($timeoutReached) {
    Write-Host "TEST_RESULTS: FAIL (TIMEOUT reached after $timeoutSeconds seconds)"
    exit 1
}

$output = @()
$errors = @()
if (Test-Path $tempLog) { $output = Get-Content $tempLog; Remove-Item $tempLog }
if (Test-Path $tempErr) { $errors = Get-Content $tempErr; Remove-Item $tempErr }

$failedTests = @()
$totals = @()
$isFailed = ($process.ExitCode -ne 0)
$inSummary = $false
$currentFile = "Unknown File"

# Parse Standard Output for GUT failures and summary
foreach ($line in $output) {
    $line = $line.Trim()
    
    # Detect summary section
    if ($line -match "Run Summary") {
        $inSummary = $true
        continue
    }
    
    if ($inSummary) {
        if ($line -match "^res://") {
            $currentFile = $line
        }
        elseif ($line -match "^-\s*(test_\S+)") {
            $failedTests += "$($currentFile): $($matches[1])"
        }
        elseif ($line -match "^(Tests|Passing Tests|Failing Tests|Asserts|Orphans|Time)") {
            $totals += $line
            if ($line -match "Failing Tests" -and $line -match "[1-9]") {
                $isFailed = $true
            }
        }
    }
}

if ($isFailed) {
    Write-Host "TEST_RESULTS: FAIL"
    
    if ($failedTests.Count -gt 0) {
        Write-Host "FAILED_SAMPLES:"
        $uniqueFailedTests = $failedTests | Select-Object -Unique
        for ($i = 0; $i -lt $uniqueFailedTests.Count; $i++) {
            Write-Host "[$($i + 1)] $($uniqueFailedTests[$i])"
        }
    }

    $uniqueErrors = $errors | Select-String "SCRIPT ERROR" | Select-Object -First 3 -Unique
    if ($uniqueErrors) {
        Write-Host "SCRIPT_ERRORS_DETECTED: YES"
        foreach ($err in $uniqueErrors) {
            Write-Host "  $($err.ToString().Trim())"
        }
    }

    if ($totals.Count -gt 0) {
        Write-Host "SUMMARY:"
        foreach ($total in $totals) {
            Write-Host "  $total"
        }
    } else {
        Write-Host "SUMMARY: No summary found (Process exit code: $($process.ExitCode))"
    }
    exit 1
} else {
    Write-Host "TEST_RESULTS: PASS"
    exit 0
}

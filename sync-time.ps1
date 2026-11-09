# Resyncs the Windows clock with internet time.
# Run at boot/logon/resume by the "Sync clock on boot" scheduled task (see install-sync-time.ps1).
# Needed because booting Linux writes UTC to the hardware clock, and Windows reads it back as
# local time, leaving the clock 5h30m behind in India.

$log = Join-Path $PSScriptRoot 'sync-time.log'
function Log($msg) { "$(Get-Date -Format 's')  $msg" | Out-File $log -Append -Encoding utf8 }

Set-Service w32time -StartupType Automatic
if ((Get-Service w32time).Status -ne 'Running') { Start-Service w32time }

w32tm /config /manualpeerlist:"time.windows.com,0x9 pool.ntp.org,0x9" /syncfromflags:manual /update | Out-Null

# The network may not be up yet right after boot, so retry for a few minutes.
$before = Get-Date
for ($i = 1; $i -le 12; $i++) {
    $out = w32tm /resync /force 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log "synced on attempt $i (clock was $before, now $(Get-Date))"
        break
    }
    if ($i -eq 12) { Log "gave up after $i attempts: $out" }
    Start-Sleep -Seconds 15
}

# Keep the log short.
if ((Test-Path $log) -and (Get-Content $log).Count -gt 200) {
    Get-Content $log -Tail 100 | Set-Content $log -Encoding utf8
}

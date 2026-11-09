#Requires -RunAsAdministrator
# Registers sync-time.ps1 as a scheduled task that runs as SYSTEM at boot, at logon and on
# resume from sleep/hibernate (Fast Startup boots are resumes, so AtStartup alone misses them).
# Run once from an admin PowerShell:  powershell -ExecutionPolicy Bypass -File install-sync-time.ps1

$script = Join-Path $PSScriptRoot 'sync-time.ps1'
$taskName = 'Sync clock on boot'

# Let w32time make big corrections in one step (the Linux offset is 5h30m).
$cfg = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config'
Set-ItemProperty $cfg -Name MaxPosPhaseCorrection -Value 0xFFFFFFFF -Type DWord
Set-ItemProperty $cfg -Name MaxNegPhaseCorrection -Value 0xFFFFFFFF -Type DWord

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

$eventTriggerClass = Get-CimClass MSFT_TaskEventTrigger root/Microsoft/Windows/TaskScheduler
$onResume = New-CimInstance -CimClass $eventTriggerClass -ClientOnly
$onResume.Enabled = $true
$onResume.Subscription = @'
<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]</Select></Query></QueryList>
'@

$triggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -AtLogOn),
    $onResume
)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers `
    -Principal $principal -Settings $settings -Force | Out-Null

Start-ScheduledTask -TaskName $taskName
Write-Host "Installed '$taskName' and ran it once. Log: $(Join-Path $PSScriptRoot 'sync-time.log')"

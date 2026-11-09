# sync-time

Fixes the Windows clock on a machine that dual-boots Linux.

Linux stores UTC in the hardware clock. Windows reads the hardware clock as local time, so
after a Linux session Windows comes up behind by your UTC offset (5h30m in India). Browsers then
reject TLS certificates, 2FA codes fail and file timestamps drift.

`sync-time.ps1` forces a resync with internet time. `install-sync-time.ps1` registers it as a
scheduled task so it runs at the right moments without you thinking about it.

## Install

From an admin PowerShell, in this folder:

```powershell
powershell -ExecutionPolicy Bypass -File install-sync-time.ps1
```

That registers a task named **Sync clock on boot** and runs it once. Keep the folder where it is:
the task points at `sync-time.ps1` by its full path.

## What it does

- **Runs as SYSTEM at startup, at logon and on resume** from sleep or hibernate. Fast Startup boots
  are technically resumes, so a startup trigger alone misses most of them. The resume trigger is
  event `1` from `Microsoft-Windows-Power-Troubleshooter`.
- **Allows big corrections in one step.** By default w32time refuses to move the clock by large
  amounts. The installer sets `MaxPosPhaseCorrection` and `MaxNegPhaseCorrection` to unlimited so a
  5h30m jump is accepted.
- **Points w32time at `time.windows.com` and `pool.ntp.org`** and makes sure the service is set to
  start automatically.
- **Retries for up to three minutes.** Right after boot the network is often not up yet, so it tries
  `w32tm /resync /force` every 15 seconds, 12 times.
- **Logs each run** to `sync-time.log` next to the script and trims it to the last 100 lines once it
  passes 200.

## The other fix

You can instead tell Linux to keep the hardware clock in local time:

```bash
timedatectl set-local-rtc 1 --adjust-system-clock
```

systemd warns against this because daylight-saving changes and time zone moves get applied twice
when both systems adjust the clock. Resyncing from Windows leaves Linux alone and avoids that.

## Uninstall

```powershell
Unregister-ScheduledTask -TaskName 'Sync clock on boot' -Confirm:$false
```

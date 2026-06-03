$ErrorActionPreference = "Stop"

$TaskName = "WinGuiAgent"

Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

Get-Process powershell -ErrorAction SilentlyContinue |
    Where-Object { $_.SessionId -eq 1 -and $_.Id -ne $PID } |
    ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force
        } catch {}
    }

Start-Sleep -Milliseconds 500
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 2

Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
Invoke-RestMethod -Uri http://127.0.0.1:8765/health

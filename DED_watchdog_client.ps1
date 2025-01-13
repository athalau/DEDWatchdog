# powershell.exe -ExecutionPolicy Bypass -file  E:\Repositories\DEDWatchdog\DED_watchdog_client.ps1

# Named Pipe Client
$pipeName = "\\.\pipe\DEDWatchdog"

# Location of the Simgears DED Hub Executable, change accordingly
$DEDHubExecutable = "C:\Program Files (x86)\SimGears\DEDHub\DEDHub.exe"

# Function to bring an application to the foreground
function setForegroundWindow {
    param (
        [string]$processName
    )

    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public class User32 {
        [DllImport("User32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
    }
"@
    $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($process) {
        $hWnd = $process.MainWindowHandle
        [User32]::SetForegroundWindow($hWnd)
    } else {
        Write-Host "Process '$processName' not found."
    }
}

# Check whether Simgears DEDHub is running
$DEDHubRunning = Get-Process -Name 'DEDHub' -ErrorAction SilentlyContinue

# setup pipe
$pipeClient = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeName, [System.IO.Pipes.PipeDirection]::Out)

# connect to pipe
$pipeClient.Connect()
$streamWriter = New-Object System.IO.StreamWriter($pipeClient)

Write-Output "Trying to reset DED..."

if ($DEDHubRunning -ne $null) {
    # forcibly quit DEDHub. It spills debug and errormessages all over the place
    Write-Output "Killing DEDHub..."
    Stop-Process -Name DEDHub -Force
    
}


if (!$DEDHubRunning.HasExited) {
   Start-Sleep 2
}
# send restart message to Watchdog to restart the USB device
$streamWriter.Write("RestartDED")
$streamWriter.Flush()
$pipeClient.Close()

Write-Output "Sleeping 2 seconds before relaunching DEDHub"
Start-Sleep 2

# restart DED Hub
Write-Output "Restarting DED Hub..."
Start-Process -FilePath $DEDHubExecutable

# Bring 'DEDHub' to the foreground
setForegroundWindow -processName "DEDHub"
Start-Sleep -Milliseconds 1000

# Send Tab and Return keys to 'foo'
Add-Type -AssemblyName System.Windows.Forms
#[System.Windows.Forms.SendKeys]::SendWait("{TAB}")
Start-Sleep -Milliseconds 1000
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

# Bring 'bar' to the foreground
Start-Sleep -Milliseconds 700
setForegroundWindow -processName "Falcon BMS"

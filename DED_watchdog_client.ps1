# powershell.exe -ExecutionPolicy Bypass -file  E:\Repositories\DEDWatchdog\DED_watchdog_client.ps1

# Named Pipe Client
$pipeName = "\\.\pipe\DEDWatchdog"

# Location of the Simgears DED Hub Executable, change accordingly
$DEDHubExecutable = "C:\Program Files (x86)\SimGears\DEDHub\DEDHub.exe"

# Check whether Simgears DEDHub is running
$DEDHubRunning = Get-Process 'DEDHub' -ErrorAction SilentlyContinue

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

# wait a bit
Write-Output "Sleeping 2 seconds before sending restart message to Watchdog"
sleep 2
# send restart message to Watchdog to restart the USB device
$streamWriter.Write("RestartDED")
Write-Output "Sleeping 2 seconds before relaunching DEDHub"
sleep 2
# restart DED Hub
# TODO: it fails to reconnect to the device even if it's availabletried to call DEDHub via cmd.exe too.
# Makes no difference. Trigger a rescann is a manual button click. No idea why.
Write-Output "Restarting DED Hub..."
Start-Process -FilePath $DEDHubExecutable
#Start-Process -FilePath "cmd.exe" -ArgumentList '/C "C:\Program Files (x86)\SimGears\DEDHub\DEDHub.exe"' -PassThru

$streamWriter.Flush()
$pipeClient.Close()


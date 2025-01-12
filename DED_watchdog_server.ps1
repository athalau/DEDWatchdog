# https://learn.microsoft.com/en-us/dotnet/api/system.io.pipes.namedpipeserverstream
# https://learn.microsoft.com/en-us/dotnet/api/system.io.pipes.pipeaccessrule
# https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax
# https://www.uwe-sieber.de/misc_tools_e.html (RestartUsbPort V1.2.1 - Restarts a USB port)
#
# This script sets up a named pipe (a communication channel so to speak) that only allows for incoming
# connection if the user sending messages equals you current login user. The username is gathered with
# the call of GetCurrent().Name and stored in the $whoAmI variable.If this fails, simply replace it
# a fixed string (i.e. "r00t" in my case).
#
# When the Watchdog receives the message "RestartDED" from a client connected to the pipe, the
# Watchdog restart the USB Device defined in $DEDDeviceID. Note: there will be no bell sound from
# Windows like unplugging the device phyisically. This is by design.
#
# Change the string of $DEDDeviceId to the Device ID of your DED device. This can be found in the
# Device Manager. Right click the
#    
#     COM Port Device > Properties > Details > Hardware-IDs from the drop down
#
# This powershell script needs to be executed as "Administrator". It's not sufficient
# to be a member of the Adminstrators group. The pnputil /restart-device needs Administrator
# permissions.
#
# Create a windows shortcut with a "Target" like
#
#     powershell.exe -noexit -ExecutionPolicy Bypass -file  E:\DEDWatchdog\DED_watchdog_server.ps1
#
# and either
#
# a) Right-click and "Run As Administrator" OR
# b) Right-click > Properties > Advanced
#
# A UAC pop-up will ask for permission to run as Administrator. This is per design every time you
# launch it. When the Watchdog is running, no more UAC messages will appear.
# 

# this is the USB device ID of the Simgears DED. Change accordingly.
$DEDDeviceId = "USB\VID_2E8A&PID_000A\E66250D5C3268329"
# $USBResetCmd = "pnputil /restart-device"
$USBResetCmd = "C:\Users\r00t\Downloads\RestartUsbPort\x64\RestartUsbPort.exe"

$whoAmI = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$pipeName = "\\.\pipe\DEDWatchdog"

# Create a security descriptor that allows only the specified user to write
$pipeSecurity = New-Object System.IO.Pipes.PipeSecurity
$accessRule = New-Object System.IO.Pipes.PipeAccessRule($WhoAmI, "ReadWrite", "Allow" )
$pipeSecurity.AddAccessRule($accessRule)

#$pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream($pipeName, [System.IO.Pipes.PipeDirection]::In)
$pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream($pipeName, "In", 1, "Byte", "None", 1024, 1024, $pipeSecurity)

$pipeACL = $pipeServer.GetAccessControl().access

Write-Output "Named pipe '$pipeName' created and writable only by user '$whoAmI'"
Out-String -InputObject $pipeACL

while ($true) {
    $pipeServer.WaitForConnection()
    
    $streamReader = New-Object System.IO.StreamReader($pipeServer)
    $receivedString = $streamReader.ReadToEnd()
    
    if ($receivedString -eq "RestartDED") {
        $DEDconnectedPresent = (Get-PnpDevice -InstanceId "$DEDDeviceId").Present

        if ($DEDconnectedPresent) {
            $DEDStatus = (Get-PnpDevice -InstanceId "$DEDDeviceId").Status
            Write-Output "Current state of device is: $DEDStatus"
            # pnputil /restart-device "$DEDDeviceId"
            #C:\Users\r00t\Downloads\RestartUsbPort\x64\RestartUsbPort.exe "$DEDDeviceId"
            Start-Process -FilePath $USBResetCmd -ArgumentList $DEDDeviceId -NoNewWindow -Wait -PassThru
            Write-Output "DED restarted, new status is: $DEDStatus"

        } else {
            $DEDStatus = (Get-PnpDevice -InstanceId "$DEDDeviceId").Status
            Write-Output "DED not connected or in error state: Present: $DEDconnectedPresent, Status: $DEDStatus"
        }
    } else {
        Write-Output "Received: $receivedString"
    }
    
    # Reset connection and keep listening
    $pipeServer.Disconnect()
}

$pipeServer.Close()
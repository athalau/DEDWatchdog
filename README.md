# DEDWatchdog
Simgears DED - Watchdog Prototype

# Problem Description
This repo is all about a freeze / disco bug in Simgears DED (see https://www.simgears.com/products/f16-ded-data-entry-display/ what this product is all about). It exists in the currently available firmware (v1.0) / DEDHub Software (v0910).

Background for those that do not own it: the Simgears DED seems to be based on a Raspberry Pi Pico. The connection is USB. Simgears made a custom firmware for the Pi Pico. Installation procedure is just like any other Pi Pico flash procedure. The DED device is registered as Serial Console device in the Windows Device Manager.

Communication from the Falcon BMS client to the DED is done with "Simgears DEDHub", a  .Net application. The application attaches to the F4 shared mem with it's F4SharedMem.dll contained in the installation. For whatever reason, the .Net application throws the following error from time to time:

![dotNetUNhandledExeption.png](https://i.imgur.com/Z6KaHRA.png) 

It's an "Unhandled Exception" message. Before you can click anything, you need to "OK" the modal that tells you to restart the DED. The *details* button in the Exception reveals, that the DEDHub application lost the connection to the serial console:
```
System.IO.IOException: Ein an das System angeschlossenes Gerät funktioniert nicht.

   bei System.IO.Ports.InternalResources.WinIOError(Int32 errorCode, String str)
   bei System.IO.Ports.SerialStream.Dispose(Boolean disposing)
   bei System.IO.Stream.Close()
   bei System.IO.Ports.SerialPort.Dispose(Boolean disposing)
   bei System.IO.Ports.SerialPort.Close()
   bei DEDHub.MainForm.RescanNTimes()
   bei DEDHub.MainForm.checkBMSdataTimer_Fired(Object sender, EventArgs e)
   bei System.Windows.Forms.Timer.OnTick(EventArgs e)
   bei System.Windows.Forms.Timer.TimerNativeWindow.WndProc(Message& m)
   bei System.Windows.Forms.NativeWindow.Callback(IntPtr hWnd, Int32 msg, IntPtr wparam, IntPtr lparam)
```

DEDHub normal operational status when Falcon BMS is running and Hub is connected to the serial port of the DED device:

![OK.png](https://i.imgur.com/KoPjnu2.png) 

As soon as the exception is thrown, the DED Hub states that it's unable to find a suitable COM port / device instead of the Green "....on port COMx"):

![NOK.png](https://i.imgur.com/1MSpWra.png) 

Hitting the *Rescan* button does not help as long as you dont replug the USB device. This may be achived by physically replugging the cable or through software that is able to reset a specific USB port (pnputil or the like).

This is by no means a bug in Falcon BMS but either a bug in the DEDHub application or the Firmware on the USB device.

# PARTIAL WORKAROUND
It's partial because you need to click the rescan button for whatever reason, even if you reset the port. The Watchdog and client script will get you rid of the clickdance for the Exception messages and manual restart of stuff.

**Note:** the Watchdog needs an additional .exe from here:
 https://www.uwe-sieber.de/misc_tools_e.html (RestartUsbPort V1.2.1 - Restarts a USB port)

It's full path is configured in the $USBResetCmd variable. You need to modify it to your needs. Drto. for the USD ID of your DED. It may be different from mine.

RestartUsbPort.exe is needed, because the powershell build-in pnputil /restart-device mechanic seems to be unreliable for this task. It works the first time you execute, but then it refuses to reset again because it insists on rebooting to take effect. Uwe Sieber developed several useful tools, especially USB stuff. I can recommend taking a look at his old-school software repo.

Back to topic:
I created a Windows powershell based Watchdog daemon and a Client script. Both communicate over a named pipe so that the unrpivileged Client can notify the privileged Watchdog to restart the USB device with a "magic string".

Default setting in windows for running powershell scripts seems to be: disabled. Hence, an error would be thrown if you simply execute this in a powershell or as an argument to a powershell.exe call. You need to temporary bypass this restriction with the *-ExecutionPolicy Bypass* parameter. This does not change your default setting, but lets you execute the script in question.

I used Powershell because it should be available on every Windows client running Falcon BMS. I have very limited knowledge in Windows Powershell, so don't expect fancy or even beautyful code compliant to any paradigm :). I split it into two scripts because I like the idea of least privilege. The only thing that is needed to be done as real Administrator is the reset of the USB port/device. This is the job of the Watchdog, code as follows (poor mens documentation see code).

Recap: Save the code above to a file named DEDWatchdog.ps1, create a shortcut next to it, edit the shortcut properties Target to be *powershell.exe -noexit -ExecutionPolicy Bypass -file  <path_to_DEDWatchdog.ps1>*, right click "Run As Administrator" or tick the "run as administrator" checkbox in the properties of the shortcut. Double clickk the shortcut, and the Watchdog runs until you close it:

![7dae97fa-8961-475c-94ac-8e9dd5fcdcf8-grafik.png](https://i.imgur.com/1KNH0HE.png) 

The client part can and should be run in a powerswhell launched with your user, i.e. the one you are using to normally launch Falcon, DEDHub etc.. Save the code to DEDWatchdogClient.ps1, create a Shortcut to the script so you can launch it with a double click.

The client script does the following:
- terminate DEDHub, wait 2 seconds
- send message to Watrchdog to reset USB device, wait 2 seconds
- restart DEDHub

Try it by double clicking the DEDWatchdogClient.ps1 shortcut. It sould laucnch a powershell window, terminate DEDHub (if running), send the magic bytes toi the Watchdog (which then resets the USB device) and launch the DEDHub again, This can be done at any time. It doesn't hurt, nothing will go poof. It's like you would replug the USB cable of the USB device.

The Watchdog window should have a mesage that looks similar to the following:
![20e5a158-caae-4cdb-bbaa-799225d0adde-grafik.png](https://i.imgur.com/6jPNSo8.png) 

FAMOUS LAST WORDS:
- there is no proper error handling implemented
- the solution helps you to get the freeze situation solved without fiddling around with a USB cable and clicking five different buttons spread over three screens (happens to me always....). It limits your work to trigger the client sciprt with <some technique> and click the Rescan button once.
- you can either trigger the clientscript by double clicking the shortcut manually or by executing the powershell command with tools that are able to execute external code (FoxVox or additional joystick tools etc., ymmv)
- pnputil fails, that's why I relied on an additonal  3rd-party .exe instead of built-in powershello features
- The DEDHub does not trigger a RESCAN on launch for whatever reason. When it failed once with the mentioned Exception, you'd even need to click RESCAN manually. This is in contrast to the behavior when you execute the clientscript in a normal behaviour moment, i.e., no error occured on the DED.

**I'm currently looking for a solution to click that damn RESCAN button from the powershell client code. That seems to be not as easy as I hoped.** UIAutomation Module for powershell seems to be non-existent anymore. I found some code with various approaches, but none of them worked.

References:
- https://learn.microsoft.com/en-us/dotnet/api/system.io.pipes.namedpipeserverstream
- https://learn.microsoft.com/en-us/dotnet/api/system.io.pipes.pipeaccessrule
- https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax
- https://www.uwe-sieber.de/misc_tools_e.html (RestartUsbPort V1.2.1 - Restarts a USB port)
- https://forum.falcon-bms.com/topic/26270/simgears-ded-keeps-freezing

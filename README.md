# DEDWatchdog
Simgears DED - Watchdog Prototype

The DEDWatchdog is trying to encounter a freeze / serial line disconnect bug in flight simulator hardware known as [Simgears DED](https://www.simgears.com/products/f16-ded-data-entry-display/). The (currently most recent) DED firmware (v1.0) / DEDHub Software (v0910) provided by the vendor is affected by a bug that, when triggered, "freezes" the display, i.e. no updates occur.

The DEDHub application is then unable to communicate with the DED on the serial port until you replug the USB cable, relaunch the DEDHub Application and let the DEDHUb rescan the available ports by manualy clicking a button in the app.

This bug triggers at least when using Simgears DED with [Falcon BMS](https://www.falcon-bms.com). I can't say whether or not this applies to [DCS](https://www.digitalcombatsimulator.com/) too. I have no DCS installed, let alone the F16 model.

There is no official fix available as per this writing. They promised to release a new firmware / fix / workaround, tho. I decided to approach this on my own for educational purposes.
## Background
The Simgears DED seems to be based on a Raspberry Pi Pico according to the raw device output. It is connected via the USB port and registers itself as a serial device in the Windows Device Manager. Simgears made a custom firmware for the Pico. Installation procedure is just like any other Pi Pico flash procedure (hence, unplug, push bootsel button on the outside of the case, replug, put new image on the mounted disk, replug).

Communication from the [Falcon BMS](https://www.falcon-bms.com) client to the Simgears DED is done with [Simgears DEDHub](https://www.simgears.com/customer-area/),  a .Net based application. It's closed source and not available to the public. You need to have a customer account at simgears.com to download it.

The DEDHub attaches to the Falcon BMS shared memory segments. The shm is provided by Falcon BMS for the purpose of exchanging in-flight simulator data with external applications and devices. The DEDHub reads the data with the help of the F4SharedMem.dll library that is shipped with the DEDHub and can be found in the installation directory. The DEDHub attaches to the serial device that is connected on the USB port, too.

## Problem Description
For whatever reason, the .Net application throws the following error from time to time:

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

The root cause for the loss of connectivity remains unclear. The USB device is in state OK, does not have any error entries etc. From the Operating System perspective, the device is ready.

It seems like the bug is triggered with a much higher probability / more frequently (e.g. 5-15 minutes after you entered the 3d world) when having Falcon BMS running in background and the user doing stuff in other apps on the desktop (a browser, editor, any other 3rd-party app for example). But it happens too if you are flying around with your shiny F16. I've had crashes after 10ish minutes and experienced flights of 45mins that had no issue at all.

Besides having Falcon BMS in the background, I noticed a more frequent crash behavior if you stay in the 2d world of Falcon (e.g. the Briefing screen) for ages and then commit to the 3d world. Timeframes comparable wot the "having Falcon BMS running in the background.

### DEDHub normal operational status
This is the Simgears DEDHub Application UI. Bottom right reads the Simulator it connected to (Falcon BMS in the example) and bottom left reads that it's connected to the serial port of the DED device
![OK.png](https://i.imgur.com/KoPjnu2.png)

### DEDHub error status
As soon as the exception is thrown, the DED Hub states that it's unable to find a suitable COM port / device like shown blow
![NOK.png](https://i.imgur.com/1MSpWra.png) 

Hitting the *Rescan* button does not help as long as you dont replug the USB device. This may be achived by physically replugging the cable or through software that is able to reset a specific USB port (pnputil or the like).

This is by no means a bug in Falcon BMS but either a bug in the DEDHub application or the Firmware on the USB device.

## PARTIAL WORKAROUND
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

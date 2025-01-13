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

![Z6KaHRA](https://github.com/user-attachments/assets/1aa83b25-d814-4556-9537-f8e978d7f8e2)


It's an "Unhandled Exception" message. Before you can click anything, you need to `OK` the modal that tells you to restart the DED. The `Details` button in the Exception reveals, that the DEDHub application lost the connection to the serial console:
```C#
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

![KoPjnu2](https://github.com/user-attachments/assets/0efd3022-e811-4c69-a9ba-f6a17d1511cf)

### DEDHub error status
As soon as the exception is thrown, the DED Hub states that it's unable to find a suitable COM port / device like shown below

![1MSpWra](https://github.com/user-attachments/assets/e0885924-4e85-4d8e-b24c-4a12aea88cf5)

Hitting the `Rescan` button does not help as long as you dont replug the USB device. This may be achived by physically replugging the cable or through software that is able to reset a specific USB port (pnputil or the like).

This is by no means a bug in Falcon BMS but either a bug in the DEDHub application or the Firmware on the USB device.

## PARTIAL WORKAROUND
Using the Watchdog client/server scripts will help to limit the clickdance - i.e. close the info popup and exception error window, replug the USB cable, and restarting the DEDHub software. It's partial only, because you still need to click the rescan button in the DEDHub. For whatever reason, even if you reset the USB port and restart the DEDHub, a rescan seems not to get triggered automagically by the DEDHub.

I created a Windows powershell based Watchdog daemon and a client script. Both communicate over a named pipe so that the watchdog client can run unprivileged and notify the watchdog daemon (running privileged) to restart the USB device. This is achived by sending the magic string "RestartDED" from the client to the server. Every other string is ignored by the watchdog daemon. After the magic string is send, the watchdog client then restarts the DEDHub application.

I used Powershell because it should be available on every Windows client running Falcon BMS. I have very limited knowledge in Windows Powershell, so don't expect fancy or even beautyful code compliant to any paradigm :). I split it into two scripts because I like the idea of least privilege. The only thing that is needed to be done as real Administrator is the reset of the USB port/device. it could have been done in one script that just does everything. But this would have been ended up running the DEDHub with Administrator privileges.
### Watchdog Daemon - DED_watchdog_server.ps1

#### Prerequesite
**Note:** the Watchdog needs an additional .exe from here:
 https://www.uwe-sieber.de/misc_tools_e.html (RestartUsbPort V1.2.1 - Restarts a USB port)

It's full path is configured in the `$USBResetCmd` variable. You need to modify it to your needs. Drto. for the USD ID of your DED. It may be different from mine.

`RestartUsbPort.exe` is needed, because the Powershell build-in `pnputil /restart-device` mechanic seems to be unreliable for this task. It works the first time you execute, but then it refuses to reset again because it insists on rebooting to take effect. YMMV. Uwe Sieber, the author of RestatUsbPort, developed several useful tools. I recommend taking a look at his old-school software repo.

#### ExecutionPolicy switch
Default setting in windows for running powershell scripts seems to be: *disabled*. Hence, an error would be thrown if you simply execute this in a powershell like `powershell.exe <scriptname>`.

![grafik](https://github.com/user-attachments/assets/d6601ef6-9660-48f5-8680-f558ee7d0428)

If an error message like the above hits you, the execution of scripts is not allowed and you need to pass the `ExecutionPolicy` switch with the value `Bypass` on the command line., i.e. `powershell.exe -ExecutionPolicy Bypass <other options>... <script>`. This temporary bypasses the restriction to execute Powershell scripts for excactly this single call. This does not change your default setting, but lets you execute the script in question.

See https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies for more information.

1. Create a shortcut pointing to `DED_watchdog_server.ps1`
2. Edit `Properties` > `Target` to be `powershell.exe -noexit -ExecutionPolicy Bypass -file  <path_to_DEDWatchdog.ps1>`
3. tick the "Run As Administrator" checkbox in the properties of the shortcut

![grafik](https://github.com/user-attachments/assets/00fdc1fb-0093-4841-8e96-41fe5b15e298)

Alternatively right-click on the shortcut and select "Run As Administrator" manually everytime you launch the daemon. The watchdog server runs forever until you close the powersehll window it launched:

![1KNH0HE](https://github.com/user-attachments/assets/a9fe6731-f419-4a2d-a0ef-50ef1736e451)

### Watchdog Client - DED_watchdog_client.ps1
The client part can and should be run in a powerswhell launched with your user, i.e. the one you are using to normally launch Falcon, DEDHub etc.. Save the code to DEDWatchdogClient.ps1, create a Shortcut to the script so you can launch it with a double click.

The client script does the following:
- terminate DEDHub, wait 2 seconds
- send message to Watrchdog to reset USB device, wait 2 seconds
- restart DEDHub

Try it by double clicking the DEDWatchdogClient.ps1 shortcut. It sould laucnch a powershell window, terminate DEDHub (if running), send the magic bytes toi the Watchdog (which then resets the USB device) and launch the DEDHub again, This can be done at any time. It doesn't hurt, nothing will go poof. It's like you would replug the USB cable of the USB device.

The Watchdog window should have a mesage that looks similar to the following:

![6jPNSo8](https://github.com/user-attachments/assets/08f4faf2-96b3-4d7e-9a24-377616ef68e3)

### FAMOUS LAST WORDS
- this is just a prototype
- there is no proper error handling implemented
- the solution helps to get the freeze situation solved without fiddling around with a USB cable, clicking five different buttons spread over three screens (happens to me always....)
- It limits your work to trigger the client scpirt with <some technique> and click the Rescan button once. [FoxVox] (https://foxster.itch.io/) may be helpful as a trigger mechanic if you're using a voice control or similar.
- pnputil fails with "need reboot", that's why I relied on an additonal 3rd-party .exe instead of built-in powershell features. But again, the tools provided by Uwe Sieber are useful, you might want to take a look regardless.
- The DEDHub does not trigger a RESCAN on launch for whatever reason. When it failed once with the mentioned Exception, you'd even need to click RESCAN manually. This is in contrast to the behavior when you execute the clientscript in a normal behaviour moment, i.e., no error occured on the DED.

**I'm currently looking for a solution to click that damn RESCAN button from the powershell client code. That seems to be not as easy as I thought.** UIAutomation Module for powershell seems to be non-existent anymore. I found some code with various approaches, but none of them worked.

## References
- https://learn.microsoft.com/en-us/dotnet/api/system.io.pipes.namedpipeserverstream
- https://learn.microsoft.com/en-us/dotnet/api/system.io.pipes.pipeaccessrule
- https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax
- https://www.uwe-sieber.de/misc_tools_e.html (RestartUsbPort V1.2.1 - Restarts a USB port)
- https://forum.falcon-bms.com/topic/26270/simgears-ded-keeps-freezing

# VVMachine
Vallox ventilation machine plug-in for Vera home automation system. Compatible with Vallox MV series ventilation units.

# Features
Displays main temperatures (Indoor, Exhaust, Extract, Outdoor), fan speed, current humidity and heat exchanger operating state in easily readable user interface. Buttons for selecting active profile (Home, Away, Boost, Fireplace).

# Installation
- Install from Vera (Apps -> Install apps)

or

- Download files from github to your computer, upload to your Vera (Apps -> Develop apps -> Luup files). Then select Create device and give D_VVMachine1.xml as Upnp Device Filename. The device can be renamed afterwards. Then reload Luup by going to Apps -> Develop apps -> Test Luup code, enter and run code: luup.reload() Then hard refresh your browser (usually Ctrl+F5).

# Configuration
Go to device control page and navigate to Advanced -> Variables. 
Set variable ValloxIP to your Vallox MV unit IP addess, for example 192.168.1.15. The IP depends on your network setup and must be static i.e. not to change over time. Input IP in x.x.x.x format, no any extra characters or port numbers. VVMachine uses port 80 always.

Device configuration:

![alt text](https://sqjeeq.am.files.1drv.com/y4m0qxMLJzkxtwMdTMzuVZI60y3OIg7ArgFP0cT4NAdRIaewPhQcLVjkDIG-LybdfrAhyUxAOnLQLH2VEx_3LRS4GvS7UMcV8UaIwRUTpLqPAx5eaJ2wFtC-TJfoQsK0oOF-6WvvRmQHXRr4Se75lHVKJdi4ViX5W2l_pKYFXRIwZHIkDRjwaXfhz6A8nQiqNWlsXECXyIYcqN-TAx4DzP5xg)

# Usage
The user interface shows current values of following signals:
- indoor temperature
- exhaust temperature
- extract temperature
- outdoor temperature
- fan speed (% of the maximum)
- humidity (relative humidity %)
- heat exchanger operating state (heat recovery, cool recovery, bypass, defrost)

Next to display are four control buttons for selecting active profile: Home, Away, Boost and Fireplace.
The buttons also reflect the state of the Vallox unit, if profile is changed from other control location the buttons status will change accordingly. Note that changing profile is not instantenous, it will take some time that command is processed and status is relayed back to plugin.

If plugin cannot connect to Vallox unit, then display will not show any values, buttons do not show any profile and plugin logo is gray color. If plugin is connected normally values and profile are shown and plugin logo is blue. Note that logos are stored in external server, if your Vera is not connected to internet the logos are not shown.

Connected and not connected device view:

![alt text](
https://rgi8eq.am.files.1drv.com/y4m4F4ZmC62eo5D7XNl3vKEsDpFuwS9O78LR9nOkmlFaDzKt39D5GoY-M6dDD4nVm8405IEX024SmdVOhNfDIZlQFA-QakLAuknKXrBe-CF2fF1AWv0qbZkmLzz7RQ1xoAK-hl_ACPDHJ4x0Zus-G3vySQQCy6_aceB-jovlZiuG9r-nkrCZx3L2hNub5ypQVu6oQ13GGI57swRPT7rps5QDA)   
![alt text](https://sqjfeq.am.files.1drv.com/y4mHsuuUko7DCnRtbX4T5V-kn49ls4mEFEbUH4YfCY1uIikNDpfdIfwT-qLEbLLpSG2Ackw8FPoSvazkOZV7dcdGgXoUQkZzB4XP1iKOgi1-eimpAuOhDI_X67u5zTn8BGQXg_gyfZX_r8LTq5gyv17c_Y6yFUDBeSNoTX7pBRNZPhoOErJEuVwNgJz76FtEEqqoDmhkNLNu7siZVD5jvqALw)

The plugin itself does not support standard device services e.g. temperature or humidity or others. If this functionality is needed it can be achieved by using another plugin, for example https://github.com/toggledbits/VirtualSensor which can be used to create wanted sensor types and setup to pull data from VVMachine plugin.

The plugin provides basic events (like temperature goes below or above) to be used in Vera scenes and notifications. If more complex automation is needed it can be again achieved by using another plugin, for example https://github.com/toggledbits/Reactor which provides great selection of rules for any task.

Following actions are provided by the plugin to control ventilation unit:
- SetProfileHome()
- SetProfileAway()
- SetProfileBoost()
- SetProfileFireplace()
- SetProfileExtra()
Each of these actions set the operating profile for ventilation unit. Actions do not take any parameters.

- SetOnOff(onoff)
Sets the ventilation unit on or off. Parameter is boolean type (1=turn unit on, 0=turn unit off).

- SetVariable(addr, val)
Sets one or multiple variable(s) in the ventilation unit. Address and value parameters are string type. When setting multiple values addresses and corresponding values must be comma separated.
Example to set one variable: SetVariable("4610", "0")
Example to set multiple variables: SetVariable("20493,20494,20495,4614", "29015,40,45,65535")



# Links
[Vallox ventilation units](https://www.vallox.com/en/products/vallox_ventilation_units.html)

[Vallox Modbus manual](https://www.vallox.com/files/1092/Manual_Modbus_ENG_20190215_PRINT.pdf)

[Python implementation of Vallox websocket interface](https://github.com/yozik04/vallox_websocket_api)

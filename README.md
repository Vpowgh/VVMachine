# VVMachine
Vallox ventilation machine plug-in for Vera home automation system. Compatible with Vallox MV series ventilation units.

# Features
Displays main temperatures (Indoor, Exhaust, Extract, Outdoor), fan speed and current humidity in easily readable user interface. Buttons for selecting active profile (Home, Away, Boost, Fireplace). All signals and commands are available for use in automations elsewhere in Vera.

# Installation
- Install from Vera (Apps -> Install apps)
or
- Download files from github to your computer, upload to your Vera (Apps -> Develop apps -> Luup files). Then select Create device and give D_VVMachine1.xml as Upnp Device Filename. The device can be renamed afterwards.

# Configuration
Go to device control page and navigate to Advanced -> Variables. 
Set variable ValloxIP to your Vallox MV unit IP addess, for example 192.168.1.15. The IP depends on your network setup and must be static i.e. not to change over time.
Optionally set variable ValloxPollRate to adjust update interval for values. Default is 60s, minimum 10s and maximum 600s.

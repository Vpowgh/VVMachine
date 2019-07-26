# VVMachine
Vallox ventilation machine plug-in for Vera home automation system. Compatible with Vallox MV series ventilation units.

# Features
Displays main temperatures (Indoor, Exhaust, Extract, Outdoor), fan speed and current humidity in easily readable user interface. Buttons for selecting active profile (Home, Away, Boost, Fireplace).

# Installation
- Install from Vera (Apps -> Install apps)

or

- Download files from github to your computer, upload to your Vera (Apps -> Develop apps -> Luup files). Then select Create device and give D_VVMachine1.xml as Upnp Device Filename. The device can be renamed afterwards.

# Configuration
Go to device control page and navigate to Advanced -> Variables. 
Set variable ValloxIP to your Vallox MV unit IP addess, for example 192.168.1.15. The IP depends on your network setup and must be static i.e. not to change over time. Input IP in x.x.x.x format, no any extra characters or port numbers. VVMachine uses port 80 always.
Optionally set variable ValloxPollRate to adjust update interval for values. Default is 20s, minimum 10s and maximum 120s.

# Usage
The user interface shows current values of following signals:
- indoor temperature
- exhaust temperature
- extract temperature
- outdoor temperature
- fan speed
- humidity

Next to display are four control buttons for selecting active profile: Home, Away, Boost and Fireplace.
The buttons also reflect the state of the Vallox unit, if profile is changed from other control location the buttons status will change accordingly. Note that changing profile is not instantenous, it will take some time that command is processed and status is relayed back to plugin.

If plugin cannot connect to Vallox unit, then display will not show any values, buttons do not show any profile and plugin logo is gray color. If plugin is connected normally values and profile are shown and plugin logo is blue.

Currently the plugin does not support standard services which means usage with third party applications might be limited. Also usage with Vera scenes is not currently possible. Automations can be created for example with Reactor plugin which is able to read all variables and set all actions.

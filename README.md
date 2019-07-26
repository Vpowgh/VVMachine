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

![alt text](https://sqjeeq.am.files.1drv.com/y4m4sUT1yZ2LXKJltdrjI2ijEzszs6JOm4ZGSN5slVV0714FYwyzpz-L7u9pJ5KwvHRvQTueuyUEar0KoA6UMev9XQIWUap_B-zTSPfYUJYr_fXwL1UWyb-OHUUyBVojxa33acpjkNS_Ozdd-qaOzrIVoAZLCtGnN2r3scFDkiN33SpbA3B51NP8usDcXGP2C3cXgQUozz3DhI6uqY_YHkzmg)


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

![alt text](https://rgi8eq.am.files.1drv.com/y4mDDcJvf5tjgC6jaIejFLD5Vt7i4nx-dkAmbJqhGjE8fXd7yI_-6swLK8aF_y9ucbgjkgHSpwxRwj6xIP6asqpiGQn2tM-MIXY0XGuKd7CHbKZFO54uIymSWj2ZH2YjY-o8koref2DNpu6dW7xL4_DNyM0KIJ0o4kNjtdRJanMM3naa9mDFpKmrBzGo521OZjELCJs_qboeEl7u-CKAXxIXA)

![alt text](https://sqjfeq.am.files.1drv.com/y4m8iWdFB_TP5Ku9MiIAs3Nj5hrgyVZQ6aCDnZXCrAoTgHb5ytLDNI6bukOUjEi0_bKYDaBF2JgeVUIjUK64qjiQ8QQ7ur8cSUJFs964hdZVkakWDQB3VCIr7PSmfGJzD7AsMSOHYYwc5G11eMljVM5WfGtJD_v0N975xl0r6yw8ojwpjkJUkSTKkh4Wm-pQ4gDGaWiPBgQsh56OgTdjXGujA)


Currently the plugin does not support standard services which means usage with third party applications might be limited. Also usage with Vera scenes is not currently possible. Automations can be created for example with Reactor plugin which is able to read all variables and set all actions.

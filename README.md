# MOSQUITO TRAPPING MODEL IN NETLOGO

# ► What the project does

This agent-based simulation demonstrates the effect of mosquito traps in proximity to human dwellings. It specifically targets tiger mosquitos, a species that has evolved to prey on humans. Tiger mosquitos are known to be attracted to CO2, heat, movement, and chemicals emitted from the skin. The distribution of CO2 and chemicals is highly dependant on the wind. As such, this model incorporates both wind speed and orientation. A statistical approach is applied to the wind speed since the wind is never constant. Some variability to the orientation is also applied.

Since only female mosquitos feed on human blood and mating is out of scope, no male population is considered. The simulation examines the case where chemical attractions only happen during the meal-seeking phase.

The user can place traps and houses. Each house has humans in the vicinity. The traps release their chemicals and the humans release CO2 and carboxylic acids, a type of chemical that is released from the skin and attracts mosquitos. The mosquitos will bite humans if they are close (heat and movement aspect of their sensing). The number of mosquito bites per house is charted, allowing a full analysis of the role trap placement and wind play in the effectiveness of the trap(s). The number of trapped mosquitos is also counted.

# ► The interest of the project

Mosquito modelling is generally performed using differential equations applied to large distances. An agent-based model allows analysis of mosquito behavior at an individual level and analysis of the best placement of mosquito traps all while taking into account wind.

# ► How to Install and Run the Project

## Installation
Install the program [NetLogo](https://ccl.northwestern.edu/netlogo/download.shtml) on Windows, MacOS, or Linux. The model file should be immediately functional after installation of the program.

This code was developped and tested on version 6.4.0 in Windows.

# ► Credit
This project was created and is maintained by Andrew Wieber.

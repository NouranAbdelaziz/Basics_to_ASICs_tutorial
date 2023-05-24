# Basics_to_ASICs_tutorial
In this tutorial you will learn how to ....

## Prerequisites:
* GNU Make
* Python 3.6+ with pip and virtualenv
* Git 2.22+
* Docker 19.03.12+
#### On Ubuntu:
```
apt install -y build-essential python3 python3-venv python3-pip
```
Docker Installation instructions: https://docs.docker.com/engine/install/ubuntu/
#### On Mac:
Get [Homebrew](https://brew.sh/)
Then:
```
brew install python make
brew install –-cask docker
```
Other tools needed:
* [Klayout](https://www.klayout.de/build.html)
* [GTKWave](https://sourceforge.net/projects/gtkwave/)

## Step 1: Hardening Macro using OpenLane
[Openlane](https://github.com/The-OpenROAD-Project/OpenLane) is  
#### OpenLane Installation:
```
git clone https://github.com/The-OpenROAD-Project/Openlane.git
cd Openlane/
make
make test # A 5-min test that ensures that Openlane and the pdk were properly installed
```
In OpenLane directory run the following commands in order to add the mul32 design:
```
cd designs 
mkdir mul32
cd mul32
mkdir src
```
Then add [spm.v]() [mul32.v]() files under the director ``Openlane/designs/mul32/src``
Then run the following commands to export the PDK_ROOT environmental variable. It should be installed with OpenLane under OpenLane/pdks but if you installed it in another location, export it to this location.
```
cd OpenLane
export PDK_ROOT=$(pwd)/pdks
```
Then run the following command to create an OpenLane docker container 
```
make mount
```
Then use this command to add the default configuration file to the mul32 design 
```
./flow.tcl -design mul32 -init_design_config -add_to_designs -confif_file config.tcl 
```
You will then find a config.json file created in ``OpenLane/designs/mul32`` directory with the following content:
```
{
    "DESIGN_NAME": "mul32",
    "VERILOG_FILES": "dir::src/*.v",
    "CLOCK_PORT": "clk",
    "CLOCK_PERIOD": 10.0,
    "DESIGN_IS_CORE": true
}
```
This basic configuration sets the design name to mul32, and clock port to clk and clock period to 10 and design core to true. 
The DESIGN_IS_CORE variable indicates whether the design is a macro or an entire chip. In this example it is a macro so we should set it to false instead; so change the config.json file content to be:
```
{
    "DESIGN_NAME": "mul32",
    "VERILOG_FILES": "dir::src/*.v",
    "CLOCK_PORT": "clk",
    "CLOCK_PERIOD": 10.0,
    "DESIGN_IS_CORE": false
}
```
For more OpenLane configuration variables, you can check [this](https://openlane.readthedocs.io/en/latest/reference/configuration.html)
The last thing you need to do is to actually run the flow for mul32 design. You can optionally pass a tag name as well
```
./flow.tcl -design mul32 -tag run_1
```
To make sure that the flow was successful, you should get the following messages at the end of the flow
```
[INFO]: There are no hold violations in the design at the typical corner.
[INFO]: There are no setup violations in the design at the typical corner.
[SUCCESS]: Flow complete.
```
However you will also find this message which shows that the core area was so small for the power grid. 
```
[INFO]: Note that the following warnings have been generated:
[WARNING]: Current core area is too small for the power grid settings chosen. The power grid will be scaled down.
```
The core area by default is double the area of the design because the default ``CORE_UTILIZATION`` is set to 50% and aspect ratio 1 (square). This area was small because the design is small (used fewer cells). OpenLane automatically reduces the value of the ``FP_PDN_VPITCH`` and ``FP_PDN_HPITCH`` which are the distance between power straps to match the new area. 
So always make sure that you check the warnings even if the flow was successful because not all warnings will be resolved automatically by OpenLane like this one.

You can examine the output from the flow run under ``OpenLane/designs/mul32/runs/run_1`` 
For example, you can find information about how long each step takes in the ``runtime.yaml`` file. Here is a snippet of it
```
- status: 0 - openlane design prep
  runtime_s: 1.01
  runtime_ts: 0h0m1s6ms
- status: 1 - synthesis - yosys
  runtime_s: 1.03
  runtime_ts: 0h0m1s30ms
- status: 2 - sta - openroad
  runtime_s: 0.32
  runtime_ts: 0h0m0s316ms
```
You can also find the final gds layout in ``OpenLane/designs/mul32/runs/run_1/results/final/gds`` and you can open it using [Klayout](https://www.klayout.de/build.html) (make sure it was installed).
This is how it would look like:

![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/0303a85a-fe56-4dfb-98d0-62c89c24dac6)


You can also examine the layout after a certain step not just the final one. For example, if you want to view the layout after the placement step, for this you need def and lef files. The def file you can find in ``OpenLane/designs/mul32/runs/run_1/results/placement`` while the lef file you can find it in ``OpenLane/designs/mul32/runs/run_1/tmp``. You can take a copy of the ``merged.nom.lef`` file and place it in ``OpenLane/designs/mul32/runs/run_1/results/placement`` (the same dir as the def file).
To open the temporary layout using Klayout, open Klayout and click on File, Import, DEF/LEF, then add the mul32.def file and it will add the merged.nom.lef file in the same directory automatically. Then press OK. 

![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/82cb8da6-68be-4422-b582-f67ac4188e23)
![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/8af55e79-0910-4fc7-ae08-a225b0f87550)


And here is the layout after placement. This helps you to track what went wrong with your hardening process if the flow failed at a certain step:

![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/b7924572-2cfe-48db-a4f0-40ee816f0bee)
``
Another important output you might check is the ``metrics.csv`` report. You will find it under ``OpenLane/designs/mul32/runs/run_1/reports``. It contain important metrics like:
* Total number of cells used in the design 
* Power consumption
* Core area
* Number of violations
and many other metrics.
Another report is ``manufacturability.rpt`` which you can also find under ``OpenLane/designs/mul32/runs/run_1/reports``. It contains the magic DRC, the LVS, and the antenna violations summaries.

## Step 2: Integrating the Design into the Caravel’s User Wrapper

[Caravel](https://github.com/efabless/caravel/tree/main) is a template chip for the Open MPW and chipIgnite shuttles. It provides the neededinfrastructure for Open MPW/chipIgnite designs. In addition to the padframe, it contains two main areas; Management Area and User’s Project Area.
We are considered with the user project area because this is the area we are using to integrate our design with. The User's area contain:
* 10 mm2 silicon area
* Four Supply domains: 2x1.8V and 2x3.3V
* 38 User’s I/O Pads
* 128 Logic probes (Control/Observe)
* Access to the Management SoC wishbone bus
Those things cannot change in the hardened user project wrapper in order to be integrated successfully with Caravel chip:
* Area (2.920um x 3.520um)
* Top module name "user_project_wrapper"
* Pin Placement
* Pin Sizes
* Core Rings Width and Offset
* PDN Vertical and Horizontal Straps Width

To integrate the SPM design with the user wrapper, we will use [user_proj_mul32]() which will communicate with the management SoC throught the wishbone bus as shown below.  
![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/10ecf6ca-65ab-4f5e-a60a-6b0560be42ee)


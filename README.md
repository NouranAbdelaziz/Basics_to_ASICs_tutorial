# Design_integration_into_Caravel_tutorial
In this tutorial you will learn how to integrate a design into [Caravel](https://github.com/efabless/caravel/tree/main) which is a  a ready-to-use test harness for creating designs with the Google/Skywater 130nm Open PDK. You will be able to know first how to harden your design using [OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) which is an automated RTL to GDS flow, then how to integrate the design RTL into the user project wrapper (the part in caravel which the users place their designs). After that, you will be shown how to use cocotb to verify the design using APIs customized for Caravel verification. Finally, you will be shown how to harden the user project wrapper. The design example used in this tutorial is SPM (serial parllel mutiplier) which take two 32-bit numbers, perform multiplication to produce a 64-
bit product. However,one of the inputs is parallel and the other is serial and we get a serial output.    

## Design Overview:
The SPM design receives a 32-bit input standing for the multiplicand (x) and with each clock cycle, the least significant bit is being read from the multiplier (y). One bit from the product (p) is calculated and sent as an output. We can use the SPM to create a full parallel version out of it as shown in the diagaram bellow. The mul32 module receives the mp and mc 32 bit registersand shifts the multiplier to the right each clock cycle and feeds its least significant bit to the spm. Then it takes the spm output (p), concatenates it to the final output and shifts it to the right until the multiplication process is done (64 clock cycles).It also receives a start signal and sends the final product along with a done signal when the process is finished.

![image](https://github.com/NouranAbdelaziz/Caravel_design_integration_and_hardening_tutorial/assets/79912650/a418f9d2-d2fb-426e-9327-b9ffa00f81de)


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
[Openlane](https://github.com/The-OpenROAD-Project/OpenLane) is an automated RTL to GDSII flow based on several components including OpenROAD, Yosys, Magic, Netgen, CVC, SPEF-Extractor, KLayout and a number of custom scripts for design exploration and optimization. The flow performs all ASIC implementation steps from RTL all the way down to GDSII.
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
Then add [spm.v](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/spm.v) [mul32.v](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/mul32.v) files under the director ``Openlane/designs/mul32/src``
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
./flow.tcl -design mul32 -init_design_config -add_to_designs 
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
The last thing you need to do is to actually run the flow for mul32 design. You can optionally pass a tag name as well using ``-tag`` to give a name for your run folder instead of automatically naming it with the date and time of the run which could be confusing. 
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

The following items cannot change in the hardened user project wrapper in order to be integrated successfully with Caravel chip:
* Area (2.920um x 3.520um)
* Top module name "user_project_wrapper"
* Pin Placement
* Pin Sizes
* Core Rings Width and Offset
* PDN Vertical and Horizontal Straps Width

To integrate the SPM design with the user wrapper, we will use [user_proj_mul32](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/user_proj_mul32.v) which will communicate with the management SoC throught the wishbone bus as shown below.  
![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/10ecf6ca-65ab-4f5e-a60a-6b0560be42ee)


In the wishbone communication, the management core will be the “master” and the peripheral in the user’s project area will be the “slave”. The master is responsible for initiating any read or write operation. Those are the wishbone slave interface signals and their explaination 

![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/432ca57b-6263-4aa2-9ca3-a4719ad673b2)

This is an example waveview of how would the signals be in a read or write operation:

![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/6756bb66-b54f-4a83-925b-b8d5e6f61560)

In the mul32 design, we will have a total of four 32-bit registers because the product is 64-bits and will be divided into two registers

| Operand | Variable in Verilog | Address in memory | Name of register |
| ------- | ------------------- | ----------------- | ---------------- |
| Multiplicand | MC | 0x30000000 | reg_mprj_slave_X |
| Multiplier | MP | 0x30000004 | reg_mprj_slave_Y |
| Product (least significanr 32 bits) | P0[31:0] | 0x30000008 | reg_mprj_slave_P0 |
| Product (most significanr 32 bits) | P0[63:32] | 0x3000000C | reg_mprj_slave_P1 |


The difference between the MP and P0 wishbone slave ports is that the ack in the Product ports occur when wbs_we_i is 0; a read operation is taking place. Also, the ack must wait for the done signal in the P ports.
The MC will be the same as MP and P1 will be the same as P0. 

![image](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/assets/79912650/4cf2a0e5-c9da-4d5d-92a5-770492156275)

The verilog file for this logic is ready in [user_proj_mul32.v](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/user_proj_mul32.v). Now, we need to harden it. 

## Step 3: Verifing the design using cocotb
First, we need to create a new repository based on the caravel_user_project template and make sure your repo is public and includes a README.
Follow [this](https://github.com/efabless/caravel_user_project/generate) in order to cerate a template repository from the [caravel_user_project](https://github.com/efabless/caravel_user_project). Name the repository ``user_proj_mul32`` (or any name you want but be careful to change the name in the rest of the steps). 
Then clone the repository you created using:
```
git clone <your github repo URL>
```
#### 1. Install prerequisites:
Make sure you followed the [quickstart guide](https://caravel-sim-infrastructure.readthedocs.io/en/latest/usage.html#quickstart-guide) to install the prerequisites and cloned the [Caravel cocotb simulation infrastructure repo](https://github.com/efabless/caravel-sim-infrastructure) 
#### 2. Update design_info.yaml file:
Make sure you updated the paths inside the ``design_info.yaml`` to match your paths as shown [here](https://github.com/efabless/caravel-sim-infrastructure/tree/main/cocotb#configure-the-repo). You can find the ``design_info.yaml``  file in the ```caravel-sim-infrastructure/cocotb/``` directory
#### 3. Create the firmware program:
The firmware is written in C code and it is the program that will be running on the Caravel management SoC. You can use it to make any configurations you want. You can find a description for all the firmware C APIs [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/C_api.html#firmware-apis)
For example, you can use it to configure the GPIO pins to have a certain value as shown in the code below. You can find the source file [here](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/cocotb/mul32_wb/mul32_wb.c):
```
#include <common.h>

void main(){
    // Enable managment gpio as output to use as indicator for finishing configuration  
    mgmt_gpio_o_enable();
    mgmt_gpio_wr(0);
    enable_hk_spi(0); // disable housekeeping spi
    // configure all gpios as  user out then chenge gpios from 32 to 37 before loading this configurations
    configure_all_gpios(GPIO_MODE_MGMT_STD_OUT);
    
    gpio_config_load(); // load the configuration 
    enable_user_interface(); 
    mgmt_gpio_wr(1); // configuration finished 

    // write value 7 in the MC register (with address offset 0x0)
    write_user_double_word(0x07,0x00);
    mgmt_gpio_wr(0); // writing to MC finished 

    // write value 3 in the MP register (with address offset 0x4)
    write_user_double_word(0x03,0x1);
    mgmt_gpio_wr(1); // writing to MP finished 

    // read the first 32 bits of the product 
    int P0 = read_user_double_word(0x02);

    set_gpio_l(P0);

    mgmt_gpio_wr(0); // Writing to GPIOs finished 

    // read the second 32 bits of the product 
    int P1 = read_user_double_word(0x3);

    set_gpio_l(P1);
    
    mgmt_gpio_wr(1); // Writing to GPIOs finished 

    return;
}
```
* ``#include <common.h>``  is used to include the firmware APIs. This must be included in any firmware that will use the APIs provided. 
* ``mgmt_gpio_o_enable();`` is a function used to set the management gpio to output (this is a single gpio pin inside used by the management soc). You can read more about this function [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/C_api.html#_CPPv418mgmt_gpio_o_enablev). 
* ``mgmt_gpio_wr(0);`` is a function to set the management gpio pin to a certain value. Here I am setting it to 0 and later will set it to 1 after the configurations are finished. This is to make sure in the python testbench that the configurations are done and you can begin to check the gpios value. You can read more about this function [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/C_api.html#_CPPv412mgmt_gpio_wrb). 
* ``enable_hk_spi(0);`` is used to disable housekeeping spi and this is required for gpio 3 to function as a normal gpio.  
* ``configure_all_gpios(GPIO_MODE_MGMT_STD_OUTPUT);`` is a function used to configure all caravel’s 38 gpio pins with a certain mode. Here I chose the ``GPIO_MODE_MGMT_STD_OUTPUT`` mode because I will use the gpios as output and the management SoC will be the one using the gpios not the user project. You can read more about this function [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/C_api.html#_CPPv419configure_all_gpios9gpio_mode). 
* ``gpio_config_load();`` is a function to load the gpios configuration. It must be called whenever we change gpio configuration. 
* ``enable_user_interface();`` is necessary when reading or writing between wishbone and user project if interface isn't enabled no ack would be recieve and the command will be stuck. You can read more about it [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/C_api.html#_CPPv421enable_user_interfacev)
* * ``mgmt_gpio_wr(1);`` is a function to set the management gpio to 1 to indicate configurations are done as explained above.
* ``write_user_double_word(0x07,0x00);`` is a function used to write double word (four bytes) at a certain offset. Here I want to write to the MC register which has address 0x0 a value of 7. You can check more about the function [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/C_api.html#_CPPv422write_user_double_wordji)
* ``read_user_double_word(0x02)`` is a function used to write double word (four bytes) at a certain offset. Here I want to read from P0 register which has address 0x8 (offset 2). You can check more about the function [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/C_api.html#_CPPv421read_user_double_wordi)
* Same thing will be done for MP and P1
* ``set_gpio_l(P0);`` is a function used to set the value of the lower 32 gpios with a certain value. In this example, I am setting the first 32 gpios to have the value of P0, then the value of P1. you can read more about this function [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/C_api.html#_CPPv410set_gpio_lj). 


#### 4. Create the python testbench:
The python testbench is used to monitor the signals of the Caravel chip just like the testbenches used in hardware simulators. You can find a description for all the python testbench APIs [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/python_api.html#python-apis). 
Continuing on the example above,  if we want to check whether the gpios are set to the correct value, we can do that using the following code. You can find the source file [here](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/cocotb/mul32_wb/mul32_wb.py):

```
from cocotb_includes import test_configure
from cocotb_includes import report_test
import cocotb

@cocotb.test()
@report_test
async def mul32_wb(dut):
    caravelEnv = await test_configure(dut,timeout_cycles=3346140)

    cocotb.log.info(f"[TEST] Start mul32_wb test")  
    # wait for start of sending
    await caravelEnv.release_csb()
    await caravelEnv.wait_mgmt_gpio(1)
    cocotb.log.info(f"[TEST] finish configuration") 
    
    # wait until writing to MC finish
    await caravelEnv.wait_mgmt_gpio(0)
    cocotb.log.info(f"[TEST] finished writing to MC") 

    # wait until writing to MP finish
    await caravelEnv.wait_mgmt_gpio(1)
    cocotb.log.info(f"[TEST] finished writing to MP") 

    # wait until reading from P0 finish
    await caravelEnv.wait_mgmt_gpio(0)
    cocotb.log.info(f"[TEST] finished reading P0")
    gpios_value_str = caravelEnv.monitor_gpio(37, 0).binstr
    cocotb.log.info (f"All gpios value '{gpios_value_str}'")
    gpio_value_int_0 = caravelEnv.monitor_gpio(37, 0).integer
    expected_P0_value = 23


     # wait until reading from P0 finish
    await caravelEnv.wait_mgmt_gpio(1)
    cocotb.log.info(f"[TEST] finished reading P1")
    gpios_value_str = caravelEnv.monitor_gpio(37, 0).binstr
    cocotb.log.info (f"All gpios value'{gpios_value_str}'")
    gpio_value_int_1 = caravelEnv.monitor_gpio(37, 0).integer
    expected_P1_value = 0

    if (gpio_value_int_0==expected_P0_value and gpio_value_int_1==expected_P1_value):
        cocotb.log.info (f"[TEST] Pass the P0 (product least significant 32 bits) value is '{gpio_value_int_0}' and P1 (product most significant 32 bits) value is '{gpio_value_int_1}'.")
    else:
        cocotb.log.error (f"[TEST] Fail the P0 value (product least significant 32 bits) is '{gpio_value_int_0}' and P1 (product most significant 32 bits) value is '{gpio_value_int_1}' expected them to be P0: '{expected_P0_value}' and P1: '{expected_P1_value}'")
```
* ``from cocotb_includes import *`` is to include the python APIs for Caravel. It must be included in any python testbench you create 
* ``import cocotb`` is to import cocotb library 
* ``@cocotb.test()`` is a function wrapper which must be used before any cocotb test. You can read more about it [here](https://docs.cocotb.org/en/stable/quickstart.html#creating-a-test)
* ``@report_test `` is a function wrapper which is used to configure the test reports
* ``async def gpio_test(dut):``  is to define the test function. The async keyword is the syntax used to define python coroutine function (a function which can run in the background and does need to complete executing in order to return to the caller function). You must name this function the same name you will give the test in the ``-test`` argument while running. Here for example I used ``gpio_test`` for both. 
* ``caravelEnv = await test_configure(dut)`` is used to set up what is needed for the caravel testing environment such as reset, clock, and timeout cycles.This function must be called before any test as it returns an object with type Cravel_env which has the functions we can use to monitor different Caravel signals.
* ``await caravelEnv.release_csb()`` is to release housekeeping spi. By default, the csb is gpio value is 1 in order to disable housekeeping spi. This function drives csb gpio pin to Z to enable using it as output.  
* ``await caravelEnv.wait_mgmt_gpio(1)`` is to wait until the management gpio is 1 to ensure that all the configurations done in the firmware are finished. The ``await`` keyword is used to stop the execution of the coroutine until it returns the results. You can read more about the function [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/python_api.html#interfaces.caravel.Caravel_env.wait_mgmt_gpio)
* ``gpios_value_str = caravelEnv.monitor_gpio(37, 0).binstr`` is used to get the value of the gpios. The monitor_gpio() function takes the gpio number or range as a tuple and returns a [BinaryValue](https://docs.cocotb.org/en/stable/library_reference.html#cocotb.binary.BinaryValue) object. You can read more about the function [here](https://caravel-sim-infrastructure.readthedocs.io/en/latest/python_api.html#interfaces.caravel.Caravel_env.monitor_gpio). One of the functions   of the BinaryValue object is binstr which returns the binary value as a string (string consists of 0s and 1s)
* ``cocotb.log.info (f"All gpios '{gpios_value_str}'")``will print the given string to the full.log file which can be useful to check what went wrong if the test fails
* ``gpio_value_int_0 = caravelEnv.monitor_gpio(37, 0).integer`` will return the value of the gpios as an integer
``` 
 if (gpio_value_int_0==expected_P0_value and gpio_value_int_1==expected_P1_value):
        cocotb.log.info (f"[TEST] Pass the P0 (product least significant 32 bits) value is '{gpio_value_int_0}' and P1 (product most significant 32 bits) value is '{gpio_value_int_1}'.")
    else:
        cocotb.log.error (f"[TEST] Fail the P0 value (product least significant 32 bits) is '{gpio_value_int_0}' and P1 (product most significant 32 bits) value is '{gpio_value_int_1}' expected them to be P0: '{expected_P0_value}' and P1: '{expected_P1_value}'")
   ```
   This compares the gpio value with the expected product value and print a string to the log file if they are equal and raises an error if they are not equal. 

#### 5. Place the test files in the user project:
Create a folder called cocotb in ``user_proj_mul32/verilog/dv/`` directory and place in it [cocotb_includes.py](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/cocotb/cocotb_includes.py) and [cocotb_tests.py](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/cocotb/cocotb_tests.py). Those files are essential for running any test. Then cereate a folder for this test in ``user_proj_mul32/verilog/dv/cocotb`` directory and call it ``mul32_wb`` and place in it [mul32_wb.c](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/cocotb/mul32_wb/mul32_wb.c) and [mul32_wb.py](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/cocotb/mul32_wb/mul32_wb.py) files. This will lead to this file sructure:
```
verilog
| dv
| ├── cocotb
| │   ├── mul32_wb
| │   │   └── mul32_wb.py
| │   │   └── mul32_wb.c
| |   ├── cocotb_includes.py
| │   └── cocotb_tests.py
|
```
#### 6. Import the new tests to ``cocotb_tests.py``:
Add this line ``from mul32_wb.mul32_wb import mul32_wb`` in ``user_proj_mul32/verilog/dv/cocotb/cocotb_tests.py``. You will find the import for this file exists but in general you need to add any new tests to this file.
#### 7. Add rtl files to includes:
In the file ``includes.rtl.caravel_user_project`` in the directory ``user_proj_mul32/verilog/includes/includes.rtl.caravel_user_project`` add those lines to include all the RTL files of the design:
```
-v $(USER_PROJECT_VERILOG)/rtl/user_proj_mul32.v
-v $(USER_PROJECT_VERILOG)/rtl/mul32.v
-v $(USER_PROJECT_VERILOG)/rtl/spm.v
-v $(USER_PROJECT_VERILOG)/rtl/user_defines.v
```
#### 8. Run the test:
To run the test you have to be in ``caravel-sim-infrastructure/cocotb/`` directory and run the ``verify_cocotb.py`` script using the following command
```
python3 verify_cocotb.py -test mul32_wb -sim RTL -tag mul32_wb_test
```
You can know more about the argument options [here](https://github.com/efabless/caravel-sim-infrastructure/tree/main/cocotb#run-a-test)
#### 9. Check if the test passed or failed:
When you run the above you will get this ouput:
```
Run tag: mul32_wb_test 
invalid mail None
Start running test:  RTL-mul32_wb 
Error: Fail to compile the C code for more info refer to /home/nouran/caravel-sim-infrastructure/cocotb/sim/mul32_wb_test/RTL-mul32_wb/firmware.log 
```
It shows that there is an error in the firmware c-code and it could'nt be compiled. You should check the ``firmware.log`` log file in the ``caravel-sim-infrastructure/cocotb/sim/mul32_wb_test/RTL-mul32_wb/firmware.log`` directory to check any firmware errors.
In the log file you will find this error:
```
/home/nouran/user_proj_mul32/verilog/dv/cocotb/mul32_wb/mul32_wb.c: In function 'main':
/home/nouran/user_proj_mul32/verilog/dv/cocotb/mul32_wb/mul32_wb.c:9:25: error: 'GPIO_MODE_MGMT_STD_OUT' undeclared (first use in this function); did you mean 'GPIO_MODE_MGMT_STD_OUTPUT'?
    9 |     configure_all_gpios(GPIO_MODE_MGMT_STD_OUT);
      |                         ^~~~~~~~~~~~~~~~~~~~~~
      |                         GPIO_MODE_MGMT_STD_OUTPUT
/home/nouran/user_proj_mul32/verilog/dv/cocotb/mul32_wb/mul32_wb.c:9:25: note: each undeclared identifier is reported only once for each function it appears in
Error: when generating hex
```
#### 10. Modify the firmware:
The error was because passign the wrong gpio mode name. To fix this, you should change `configure_all_gpios(GPIO_MODE_MGMT_STD_OUT);` to `configure_all_gpios(GPIO_MODE_MGMT_STD_OUTPUT);` and rerun. 
#### 11. Check if the test passed or failed:
 When you rerun you will get the following at the end of the terminal output:
 ```                                                     
Fail: Test RTL-mul32_wb has Failed for more info refer to /home/nouran/caravel-sim-infrastructure/cocotb/sim/mul32_wb_test/RTL-mul32_wb/mul32_wb.log
 ```

The test has failed. You should check the `compilation.log` log file in the directory ``caravel-sim-infrastructure/cocotb/sim/mul32_wb_test/RTL-mul32_wb/``. You will find the following error message:
```
 2854925.00ns ERROR    cocotb                             [TEST] Fail the P0 value (product least significant 32 bits) is '21' and P1 (product most significant 32 bits) value is '0' expected them to be P0: '23' and P1: '0'
2854925.00ns INFO     cocotb.regression                  report_test.<locals>.wrapper_func failed
                                                         Traceback (most recent call last):
                                                           File "/home/nouran/caravel-sim-infrastructure/cocotb/interfaces/common_functions/test_functions.py", line 120, in wrapper_func
                                                             raise cocotb.result.TestComplete(f"Test failed {msg}")
                                                         cocotb.result.TestComplete: Test failed with (0)criticals (1)errors (0)warnings 
2854925.00ns INFO     cocotb.regression                  **************************************************************************************************************************************
                                                         ** TEST                                                                          STATUS  SIM TIME (ns)  REAL TIME (s)  RATIO (ns/s) **
                                                         **************************************************************************************************************************************
                                                         ** interfaces.common_functions.test_functions.report_test.<locals>.wrapper_func   FAIL     2854925.00          73.16      39023.67  **
                                                         **************************************************************************************************************************************
                                                         ** TESTS=1 PASS=0 FAIL=1 SKIP=0                                                            2854925.00          73.17      39015.46  **
                                                         **************************************************************************************************************************************
```
This means the result weren't as expected and test failed message was raised because of the cocotb.log.error() function. 
#### 12. Modify the python test bench:
The error is because the expected value is 23 is not equal to the gpios value 21. To fix this change the expected value to 21 ``expected_P0_value = 23`` and rerun
#### 13. Check if the test passed or failed:
When you run the modified code you will get this at the end of terminal output:
```
Test: RTL-mul32_wb has passed
```
It shows that the test has passsed. You can check the log files resulted from compilation of the c code (firmware) in ``caravel-sim-infrastructure/cocotb/sim/mul32_wb_test/RTL-mul32_wb/firmware.log`` and the results from compiling the verilog and running the python testbench in ``caravel-sim-infrastructure/cocotb/sim/mul32_wb_test/RTL-mul32_wb/compilation.log`` 


## Step 4: Hardening the User’s Wrapper
To harden the user project, we will use [caravel_user_project](https://github.com/efabless/caravel_user_project) template we cereated and cloned in the above step. 

#### Setting up the environment
To use the most updated OpenLane, you need to export OPENLANE_TAG variable. You will find the openlane tags [here](https://github.com/The-OpenROAD-Project/OpenLane/tags). Get the name of the latest tag, then you can run before make setup:
```
export OPENLANE_TAG=<tag_name>
```
This will install the latest openlane for you which might have more features than the one which will be installed by default by make setup. 

To setup your local environment run:
```
cd <project_name> # project_name is the name of your repo

mkdir dependencies

export OPENLANE_ROOT=$(pwd)/dependencies/openlane_src # you need to export this whenever you start a new shell

export PDK_ROOT=$(pwd)/dependencies/pdks # you need to export this whenever you start a new shell

# export the PDK variant depending on your shuttle, if you don't know leave it to the default

# for sky130 MPW shuttles....
export PDK=sky130A

make setup
```
This command will setup your environment by installing the following:
* caravel_lite (a lite version of caravel)
* management core for simulation
* openlane to harden your design
* pdk

To harden the project wrapper, you have three options:
1. A single Macro: this means hardening the design then inserting it as a blackbox macro inside the user_project_wrapper and then hardening the project wrapper as a whole.
2. Flattened design: this means you will flatten the design with the wrapper (integrate it as an RTL and not as blackbox GDS) and then harden it all at once.
3. Multiple Macros: this is a mix of both, where you can use multiple macros as well as some designs hardened with the project wrapper 

For this tutorial, we will use the first option. This means we will harden the design then integrate it as a blackbox with the wrapper and harden the wrapper. 

#### To harden the design:
1. copy [spm.v](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/spm.v), [mul32.v](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/mul32.v), and [user_proj_mul32.v](https://github.com/NouranAbdelaziz/Basics_to_ASICs_tutorial/blob/main/user_proj_mul32.v) into ``user_proj_mul32/verilog/rtl`` directory. 
2. Make a copy of the ``user_proj_example`` folder under ``user_proj_mul32/openlane`` and rename it as ``user_proj_mul32``
3. Edit the configuration file ``config.json`` under the folder we created ``user_proj_mul32/openlane/user_proj_mul32`` you should change:
    * "DESIGN_NAME" to user_proj_mul32
    * "VERILOG_FILES" to the paths of the three verilog files we have.
    * Remove "CLOCK_NET": "counter.clk"
    * Remove "FP_SIZING" and "DIE_AREA" variables. This change will make the floor planning sizing to be relative by default and you need to specify the "FP_CORE_UTIL".
    * Set "FP_CORE_UTIL" to be 20% and "FP_ASPECT_RATIO" to be 0.6 to make the width of the macro wider to aviod congestion in the bottom part
   You will find the updated config.json file [here]()
   Note: those variables are not fixed. You can try different values and see if the flow will complete successfuly with them. 
  
4. Run the following command to run OpenLane ASIC flow and generate GDS for the design:
```
make user_proj_mul32
```
5. If you used an updated Openlane version, you will get this warning when you run Openlane:
```
[WARNING]: OpenLane may not function properly: The version of open_pdks used in building the PDK does not match the version OpenLane was tested on (installed: e6f9c8876da77220403014b116761b0b2d79aab4, tested: af3485525297d5cbe93c129ea853da2d588fac41)
```
To solve this issue, you should update the PDK as well by running:
```
export OPEN_PDKS_COMMIT=af3485525297d5cbe93c129ea853da2d588fac41 #Note: Use the PDK version which is stated in the warning. 
make pdk-with-volare 
```
Then rerun
```
make user_proj_mul32
```
6.  View the results of the OpenLane run under ``user_proj_mul32/openlane/user_proj_mul32/runs/<run_name>``

#### To harden the wrapper:
1. Edit the ``user_project_wrapper.v`` in ``user_proj_mul32/verilog/rtl`` directory and edit the instance name from ``user_proj_example`` to ``user_proj_mul32``
2. Add those lines to the RTL because they are not connected and not used in the mul32 design:
```
// Not used
//IO
assign io_oeb = 0;
assign io_out = 0;
// LA
// Not used
assign la_data_out = 0;
```
The updated user_project_wrapper could be found [here]()
4.  Edit the configuration file ``config.json`` under the folder we created ``user_proj_mul32/openlane/user_project_wrapper`` you should change:
    * "VERILOG_FILES_BLACKBOX" to include the the path of the gate level netlist of ``user_proj_mul32.v``
    * "EXTRA_LEFS" to point to the ``user_proj_mul32.lef`` file 
    * "EXTRA_GDS_FILES" to point to the ``user_proj_mul32.gds`` file 
    * Remove "SYNTH_ELABORATE_ONLY", "FP_PDN_ENABLE_RAILS", "RUN_FILL_INSERTION", "RUN_TAP_DECAP_INSERTION". All those variable were set in the example  that the wrapper will not have any logic in it and just a macro. But when we added the logic for the LAs and IOs to set them to 0, we had to adjust this or we will get into LVS errors.   
   You will find the changed config.json file [here]()
3.  Run the following command to run OpenLane ASIC flow and generate GDS for the wrapper:
```
make user_project_wrapper
``` 
Now you have the final GDS of the wrapper in ``user_proj_mul32/openlane/user_project_wrapper/runs/<run_tag>/results/final/gds``
This is the final GDS layout of the wrapper:

![image](https://github.com/NouranAbdelaziz/Design_integration_into_Caravel_tutorial/assets/79912650/f464f6c6-5379-4957-8487-0fb8e1bf599f)

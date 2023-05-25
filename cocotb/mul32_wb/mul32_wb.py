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
    expected_P0_value = 21


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

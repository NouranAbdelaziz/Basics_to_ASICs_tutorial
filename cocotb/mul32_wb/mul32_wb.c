#include <common.h>

void main(){
    // Enable managment gpio as output to use as indicator for finishing configuration  
    mgmt_gpio_o_enable();
    mgmt_gpio_wr(0);
    enable_hk_spi(0); // disable housekeeping spi
    // configure all gpios as  user out then chenge gpios from 32 to 37 before loading this configurations
    configure_all_gpios(GPIO_MODE_MGMT_STD_OUTPUT);
    
    gpio_config_load(); // load the configuration 
    enable_user_interface(); // this necessary when reading or writing between wishbone and user project if interface isn't enabled no ack would be recieve and the command will be stuck
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

`default_nettype none

module user_proj_mul32 
(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output reg wbs_ack_o,
    output reg [31:0] wbs_dat_o,

    // IRQ
    output [2:0] irq
);
    reg start;
    wire done;
    wire sys_clk;
    localparam MC_OFF = 8'h00, MP_OFF = 8'h04, P0_OFF = 8'h08, P1_OFF = 8'h0C;
    //  WB Interface
    //  3 32 regsisters:
    //  MP  (RW)    0x00 
    //  MC  (RW)    0x04
    //  P   (RO)    0x08
    reg  [31:0]         MP, MC;
    wire [63:0]         P;
    wire                valid           = wbs_stb_i & wbs_cyc_i;
    wire                we              = wbs_we_i && valid;
    wire                re              = ~wbs_we_i && valid;
    wire [3:0]          byte_wr_en      = wbs_sel_i & {4{we}}; 
    wire                we_mp_reg       = we & (wbs_adr_i[7:0] == MP_OFF);
    wire                we_mc_reg       = we & (wbs_adr_i[7:0] == MC_OFF);
    wire                re_mp_reg       = re & (wbs_adr_i[7:0] == MP_OFF);
    wire                re_mc_reg       = re & (wbs_adr_i[7:0] == MC_OFF);
    wire                re_p0_reg       = re & (wbs_adr_i[7:0] == P0_OFF);
    wire                re_p1_reg       = re & (wbs_adr_i[7:0] == P1_OFF);

    assign sys_clk = wb_clk_i;
    
    always @(posedge sys_clk or posedge wb_rst_i) begin // Always block to assign MC
        if(wb_rst_i)
            MC <= 32'h0;
        else if(we_mc_reg)  
            MC <= wbs_dat_i;
    end

    always @(posedge sys_clk or posedge wb_rst_i) begin // Always block to assign MP
        if(wb_rst_i)
            MP <= 32'h0;
        else if(we_mp_reg) 
            MP <= wbs_dat_i;
    end 


    always @(posedge sys_clk or posedge wb_rst_i) begin // Always block to assign MP
        if(wb_rst_i)
            wbs_ack_o <= 0;
        else
        begin
            if ((we_mc_reg || we_mp_reg || (re_p0_reg && done) || (re_p1_reg && done)))
            begin
                wbs_ack_o <=1;
            end
            else 
                wbs_ack_o <=0; 
        end
    end

    always@(posedge sys_clk or posedge wb_rst_i) begin
        if(wb_rst_i)
            wbs_dat_o <= 32'hDEADBEEF;
        else
        begin
            if (re_p0_reg)
                wbs_dat_o <= P[31:0];
            else if (re_p1_reg)
                 wbs_dat_o <= P[63:32];
            else if (re_mp_reg)
                 wbs_dat_o <= MP;
            else if (re_mc_reg)
                 wbs_dat_o <= MC;
            else
               wbs_dat_o <= 32'hDEADBEEF; 
        end
    end

    always @(posedge sys_clk) 
        start <= (we_mp_reg && wbs_ack_o) ? 1'b1 : 1'b0;
   
    // IRQ
    assign irq = 3'b000;	// Unused
    
    mul32 mul (
        .clk(wb_clk_i),
        .rst(wb_rst_i),
        .start(start),
        .mc(MC),
        .mp(MP),
        .p(P),
        .done(done)
    );

endmodule

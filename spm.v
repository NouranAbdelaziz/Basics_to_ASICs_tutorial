// A Serial-Parallel Multiplier (SPM)
// Modeled after the design outlined by shorturl.at/rwxGK
// Copyright 2016, mshalan@aucegypt.edu

`default_nettype none

module spm #(parameter size = 32)(
    input wire              clk, 
    input wire              rst,
    input wire              y,
    input wire [size-1:0]   x,
    output wire             p
);
    wire[size-1:1] pp;
    wire[size-1:0] xy;

    genvar i;

    CSADD csa0 (.clk(clk), .rst(rst), .x(x[0]&y), .y(pp[1]), .sum(p));
    
    generate 
        for(i=1; i<size-1; i=i+1) begin
            CSADD csa (.clk(clk), .rst(rst), .x(x[i]&y), .y(pp[i+1]), .sum(pp[i]));
        end 
    endgenerate
    
    TCMP tcmp (.clk(clk), .rst(rst), .a(x[size-1]&y), .s(pp[size-1]));

endmodule


module CSADD(
    input wire  clk, 
    input wire  rst,
    input wire  x, 
    input wire  y,
    output reg  sum
);

    reg sc;

    // Half Adders logic
    wire hsum1, hco1;
    assign hsum1 = y ^ sc;
    assign hco1 = y & sc;

    wire hsum2, hco2;
    assign hsum2 = x ^ hsum1;
    assign hco2 = x & hsum1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum <= 1'b0;
            sc <= 1'b0;
        end
        else begin
            sum <= hsum2;
            sc <= hco1 ^ hco2;
        end
    end
endmodule

module TCMP (
    input wire  clk, 
    input wire  rst,
    input wire  a, 
    output reg  s
);
  
    reg z;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s <= 1'b0;
            z <= 1'b0;
        end
        else begin
            z <= a | z;
            s <= a ^ z;
        end
    end

endmodule

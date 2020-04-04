`timescale 1ns / 1ps

module Bram (
    input wire i_clk,
    input wire [15:0] i_addr,           //2^17 = 131,100 Adresses. Address = one Pixel on screen only need 76,800
    input wire i_write,
    input wire [5:0] i_data,            // 8 bits of color used per pixel: Input and output 256 possible colors
    output reg [5:0] o_data 
    );

    reg [5:0] memory_array [0:63_999]; 
    
    always @ (posedge i_clk)
    begin
        if(i_write) 
        begin
            memory_array[i_addr] <= i_data;
        end
        else 
        begin
            o_data <= memory_array[i_addr];
        end     
    end
endmodule

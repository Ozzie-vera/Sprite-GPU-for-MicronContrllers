`timescale 1ns / 1ps

module Background (
    input wire i_clk,
    input wire [15:0] i_addr, 
    output reg [5:0] o_data 
    );
    
    parameter MEMFILE = "Background.mem";

    reg [5:0] memory_array [0:64_000]; 

    initial begin
        if (MEMFILE > 0)
        begin
            $readmemb(MEMFILE, memory_array);
        end
    end

    always @ (posedge i_clk)
    begin    
            o_data <= memory_array[i_addr];    
    end
endmodule
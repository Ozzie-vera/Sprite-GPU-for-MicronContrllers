`timescale 1ns / 1ps



module VGA_Controller(

    input  i_px_clk,        // PIxel clock
    input  i_rst,           // reset frames
    
    output  o_hs,           //Horizontal Sync
    output  o_vs,           //Vericle Sync
    
    
    output  o_active,       //high during active period
    output  o_endframe,     // high at the end of a frame
   
    
    output  [9:0] o_xpos,   // x pixel position
    output  [8:0] o_ypos    // y pixel position      

    );
    
    //Horizontal constants
    localparam LINE     = 800;              // Full line with fp, sync, bp
    localparam HS_ST    = 16;               //Horizontal sync Start
    localparam HS_EN    = 16 + 96;          //Horizontal Synch end
    localparam H_ACT_ST = 16 + 96 + 48;     //Horizontal Active period start
    
    //Veritcle Constant
    localparam SCREEN   = 525;              //Full screen with fp, sync, bp
    localparam VS_ST    = 480 + 11;         //Verticle sync Start
    localparam VS_EN    = 480 + 11 + 2;     //Verticle Synch end
    localparam V_ACT_EN = 480;              //Verticle Active period end
    
    //Timing Params
    reg[9:0] h_count;     //line position
    reg[9:0] v_count;     //Screen position
    
    //generating output sync signlas
    assign o_hs = ~((h_count >= HS_ST) & (h_count < HS_EN));
    assign o_vs = ~((v_count >= VS_ST) & (v_count < VS_EN));
    
    //Active and screenend signals
    assign o_active = ~((h_count < H_ACT_ST) | (v_count > V_ACT_EN - 40 - 1) //  output active high whenever not in active period, negate
                                             | (v_count < 40));       // high when in active period
    assign o_endframe = ((v_count == SCREEN - 1) & (h_count == LINE));
   
    //Making sure X and Y output positions stay within active regions depending on timing
    assign o_xpos = (h_count < H_ACT_ST) ? 0 : (h_count - H_ACT_ST) >> 1;
    assign o_ypos = (v_count >= V_ACT_EN) ? (V_ACT_EN - 40 - 1) : (v_count -40) >> 1;
    
    
    always @(posedge i_px_clk)
    begin
        if (i_rst)  // reset to start of frame
        begin
            h_count <= 0;
            v_count <= 0;
        end
        
        if (h_count == LINE)  // end of line
        begin
            h_count <= 0;     //Reset line, add screen  
            v_count <= v_count + 1;
        end
        else 
            h_count <= h_count + 1; // add to line

        if (v_count == SCREEN)  // end of screen, reset screen
            v_count <= 0;
       
    
    
    end
    
    
endmodule

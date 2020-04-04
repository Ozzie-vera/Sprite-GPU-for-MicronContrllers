`timescale 1ns / 1ps

module Top(
    input  clk,             // board clock: 100 MHz on Arty/Basys3/Nexys
    input  btnC,            // reset button
    input  [2:0]JA,
    input  [2:0]JB,
    input  [7:0]JC,
    input [4:0]pl_in,  //Player movement
    input [4:0]pl2_in,
    input [15:0]sw,
    
    output reg[15:0] led,
    
    output  Hsync,          // horizontal sync output
    output  Vsync,          // vertical sync output
    
    output reg [3:0] vgaRed,    // 4-bit VGA red output
    output reg [3:0] vgaGreen,    // 4-bit VGA green output
    output reg [3:0] vgaBlue     // 4-bit VGA blue output
    );

     // generate a 25 MHz pixel strobe
    reg [15:0] cnt = 0;
    reg pix_stb = 0;

    always @(posedge clk)
        {pix_stb, cnt} <= cnt + 16'h4000;  // divide by 4: (2^16)/4 = 0x4000
        
    //Display with VGA Controller    
    wire rst = btnC;  // reset is active high on Basys3 (BTNC)

    wire [8:0] x;  // current pixel x position: 10-bit value: 0-511
    wire [8:0] y;  // current pixel y position:  9-bit value: 0-511
    
    wire active;    //high during active region
    wire endframe;  //High for one tick at the end of the screen
    
    VGA_Controller display (
        .i_px_clk(pix_stb),
        .i_rst(rst),
        .o_hs(Hsync), 
        .o_vs(Vsync), 
        .o_xpos(x), 
        .o_ypos(y),
        .o_active(active),
        .o_endframe(endframe)
    );
    

    //Frame Buffers, Double Buffering 1buffer for drawing another for displaying
    reg write_1 = 0, write_2 = 1;
    reg [15:0] addr_1, addr_2;
    reg [5:0]  datain_1, datain_2;
    wire[5:0]  dataout_1, dataout_2;
    
    Bram Buffer1(
        .i_clk(clk),
        .i_write(write_1),
        .i_addr(addr_1),
        .i_data(datain_1),
        .o_data(dataout_1)
    );
    
   Bram Buffer2(
        .i_clk(clk),
        .i_write(write_2),
        .i_addr(addr_2),
        .i_data(datain_2),
        .o_data(dataout_2)
    );
    
    
    //Sprites Memory
    reg [13:0] addr_s;
    reg [13:0] addr_sB;
    wire [5:0] dataout_s;
    
    Sprites SpMem(
        .i_clk(clk),
        .i_addr(addr_s),
        .o_data(dataout_s)
    );
    
    
    //Background Memory
    reg [15:0] addr_b = 0;
    wire [5:0] dataout_b;
    
    Background BGMem(
        .i_clk(clk),
        .i_addr(addr_b),
        .o_data(dataout_b)
    );
    
    
  
    
     //Params and Registers for Drawing Module||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    localparam PL1_X = 0;           localparam PL1_Y = 100 - 16;
    localparam PL2_X = 320 - 33;    localparam PL2_Y = 100 - 16;
    localparam EAST = 4'b0010;      localparam NORTHEAST  = 4'b1010;
    localparam NORTH  =  4'b1000;   localparam NORTHWEST  = 4'b1001;
    localparam WEST  = 4'b0001;     localparam SOUTHWEST  = 4'b0101;
    localparam SOUTH  = 4'b0100;    localparam SOUTHEAST  = 4'b0110;
    
    
    
    
    //player1 registers
    reg [5:0] pl_stat;// used to communicate with uart
    reg [8:0] pl_x; 
    reg [8:0] pl_y;
    reg [3:0] pl_sprite;
    
    reg [8:0] pl_bl_x [0:2];
    reg [8:0] pl_bl_y [0:2];
    reg [4:0] pl_bl_stat [0:2];
    reg [3:0] pl_bl_dir;
    reg [5:0] bl_delay;
        
    reg [3:0] pl_bg_dir;
    reg [3:0] pl_bbg_dir[0:2];
    
    //player 2 registers
    reg [5:0] pl2_stat;//used to communicate with uart 
    reg [8:0] pl2_x; 
    reg [8:0] pl2_y;  
    reg [3:0] pl2_sprite;
    
    reg [8:0] pl2_bl_x [0:2];
    reg [8:0] pl2_bl_y [0:2];
    reg [4:0] pl2_bl_stat [0:2];
    reg [3:0] pl2_bl_dir;
    reg [5:0] bl2_delay;
    
    reg [3:0] pl2_bg_dir;
    reg [3:0] pl2_bbg_dir[0:2];

    // pipeline registers for for address calculation
    reg [5:0] data_buff;  // buff for data out
    reg [15:0] address_fb1;  //buffer for Address
    reg [15:0] address_fb2;  
    reg [15:0] address_fb3; 
    
    
    //general drawing registers
    reg [5:0] draw_x;
    reg [5:0] draw_y;
    //general bullet registers 
    reg [1:0] bullet_it;
    // pipeline register for VGA output
    reg [5:0] color;
    //state register
    reg [2:0] state;
   
    reg GameOver;
    
    initial begin
    
    
    GameOver <= 0;
    state <= 0;
    
    draw_x <= 0;
    draw_y <= 0;
    bullet_it <= 0;
    
    //player 1
           
    pl_x <= PL1_X; 
    pl_y <= PL1_Y; 
    pl_sprite = 0;
        
    pl_bl_stat[0] <= 0;
    pl_bl_stat[1] <= 0;
    pl_bl_stat[2] <= 0;
    pl_bl_x [0] <= 0;
    pl_bl_x [1] <= 0;
    pl_bl_x [2] <= 0;
    pl_bl_y [0] <= 0;
    pl_bl_y [1] <= 0;
    pl_bl_y [2] <= 0;
    pl_bl_dir <= 0;
    bl_delay <= 0;
    
    pl_bg_dir <= 0;
    pl_bbg_dir[0] <= 0;
    pl_bbg_dir[1] <= 0;
    pl_bbg_dir[2] <= 0;
    
    //player 2
    
    pl2_x <= PL2_X; 
    pl2_y <= PL2_Y;
    pl2_sprite = 4;
    
    pl2_bl_stat[0] <= 0;
    pl2_bl_stat[1] <= 0;
    pl2_bl_stat[2] <= 0;
    pl2_bl_x [0] <= 0;
    pl2_bl_x [1] <= 0;
    pl2_bl_x [2] <= 0;
    pl2_bl_y [0] <= 0;
    pl2_bl_y [1] <= 0;
    pl2_bl_y [2] <= 0;
    pl2_bl_dir <= 0;
    bl2_delay <= 0;
    
    pl2_bg_dir <= 0;
    pl2_bbg_dir[0] <= 0;
    pl2_bbg_dir[1] <= 0;
    pl2_bbg_dir[2] <= 0;
    
    end
    
    
    
    
    always @ (posedge clk)
    begin
        //stuff to replace UART communication
        pl_stat[5:1] <= {pl_in[3:0],pl_in[4]};//movement
          
        pl2_stat[5:1] <= {pl2_in[3],pl2_in[2],pl2_in[1],pl2_in[0],pl2_in[4]};
        
      
        // reset drawing
        if (rst)
        begin
            GameOver <= 0;
            state <= 0;
            
            draw_x <= 0;
            draw_y <= 0;
            bullet_it <= 0;
            
            //player 1
                  
            pl_x <= PL1_X; 
            pl_y <= PL1_Y; 
            pl_sprite = 0;
                
            pl_bl_stat[0] <= 0;
            pl_bl_stat[1] <= 0;
            pl_bl_stat[2] <= 0;
            pl_bl_x [0] <= 0;
            pl_bl_x [1] <= 0;
            pl_bl_x [2] <= 0;
            pl_bl_y [0] <= 0;
            pl_bl_y [1] <= 0;
            pl_bl_y [2] <= 0;
            pl_bl_dir <= 0;
            bl_delay <= 0;
            
            pl_bg_dir <= 0;
            pl_bbg_dir[0] <= 0;
            pl_bbg_dir[1] <= 0;
            pl_bbg_dir[2] <= 0;
            
            //player 2
            
            pl2_x <= PL2_X; 
            pl2_y <= PL2_Y;
            pl2_sprite = 4;
            
            pl2_bl_stat[0] <= 0;
            pl2_bl_stat[1] <= 0;
            pl2_bl_stat[2] <= 0;
            pl2_bl_x [0] <= 0;
            pl2_bl_x [1] <= 0;
            pl2_bl_x [2] <= 0;
            pl2_bl_y [0] <= 0;
            pl2_bl_y [1] <= 0;
            pl2_bl_y [2] <= 0;
            pl2_bl_dir <= 0;
            bl2_delay <= 0;
            
            pl2_bg_dir <= 0;
            pl2_bbg_dir[0] <= 0;
            pl2_bbg_dir[1] <= 0;
            pl2_bbg_dir[2] <= 0; 
           
        end
        else begin
        
        case (state) //Drawing finite state machine|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
        
            0://Draw background~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            begin
                
                if (addr_b == 64_000)// once finished with screen
                begin
                //StateChange 
                    state <= 1;     //continue to next stage reset addr_b
                    addr_b <= 0;
                    
                end
                
                //itterate through Background Addr
                addr_b <= addr_b + 1;  
                
                //paste to Frame Buffer
                if(write_1)
                begin
                    addr_1 <= addr_b;
                    //datain_1 <= data_buff;
                    datain_1 <= dataout_b;
                end
                else
                begin
                    addr_2 <= addr_b;
                    //datain_2 <= data_buff;
                    datain_2 <= dataout_b;
                end
                
//                if( 84*320+144 <= addr_b && addr_b <= 84*320+144+32
//                ||  85*320+144 <= addr_b && addr_b <= 85*320+144+32
//                ||  86*320+144 <= addr_b && addr_b <= 86*320+144+32
//                ||  87*320+144 <= addr_b && addr_b <= 87*320+144+32
//                ||  88*320+144 <= addr_b && addr_b <= 88*320+144+32
//                ||  89*320+144 <= addr_b && addr_b <= 89*320+144+32
//                ||  90*320+144 <= addr_b && addr_b <= 90*320+144+32
//                ||  91*320+144 <= addr_b && addr_b <= 91*320+144+32
//                ||  92*320+144 <= addr_b && addr_b <= 92*320+144+32
//                ||  93*320+144 <= addr_b && addr_b <= 93*320+144+32
//                ||  94*320+144 <= addr_b && addr_b <= 94*320+144+32
//                ||  95*320+144 <= addr_b && addr_b <= 95*320+144+32
//                ||  96*320+144 <= addr_b && addr_b <= 96*320+144+32
//                ||  97*320+144 <= addr_b && addr_b <= 97*320+144+32
//                ||  98*320+144 <= addr_b && addr_b <= 98*320+144+32
//                ||  99*320+144 <= addr_b && addr_b <= 99*320+144+32
//                ||  100*320+144 <= addr_b && addr_b <= 100*320+144+32
//                ||  101*320+144 <= addr_b && addr_b <= 101*320+144+32
//                ||  102*320+144 <= addr_b && addr_b <= 102*320+144+32
//                ||  103*320+144 <= addr_b && addr_b <= 103*320+144+32
//                ||  104*320+144 <= addr_b && addr_b <= 104*320+144+32
//                ||  105*320+144 <= addr_b && addr_b <= 105*320+144+32
//                ||  106*320+144 <= addr_b && addr_b <= 106*320+144+32
//                ||  107*320+144 <= addr_b && addr_b <= 107*320+144+32
//                ||  108*320+144 <= addr_b && addr_b <= 108*320+144+32
//                ||  109*320+144 <= addr_b && addr_b <= 109*320+144+32
//                ||  110*320+144 <= addr_b && addr_b <= 110*320+144+32
//                ||  111*320+144 <= addr_b && addr_b <= 111*320+144+32
//                ||  112*320+144 <= addr_b && addr_b <= 112*320+144+32
//                ||  113*320+144 <= addr_b && addr_b <= 113*320+144+32
//                ||  114*320+144 <= addr_b && addr_b <= 114*320+144+32
//                ||  115*320+144 <= addr_b && addr_b <= 115*320+144+32
//                ||  116*320+144 <= addr_b && addr_b <= 116*320+144+32
//                  ) data_buff <= 6'b000000;
//                 else
//                    data_buff <= 6'b111111;
                
                //check positions of objects to boundary
                if(dataout_b == 6'b000000)
                begin
                
                // player 1 
                if(320 * pl_y + pl_x + 33 == addr_b 
                || 320 * (pl_y + 32) + pl_x + 33 == addr_b  )//check EAST
                    pl_bg_dir <= EAST;
                if(320 * (pl_y - 1) + pl_x  == addr_b 
                || 320 * (pl_y - 1) + pl_x + 32  == addr_b
                || 320 * (pl_y - 1) + pl_x + 16  == addr_b)//check North
                    pl_bg_dir <= NORTH;
                    
                if(320 * pl_y + pl_x  - 1 == addr_b
                || 320 * (pl_y + 32) + pl_x  - 1 == addr_b )//check WEST
                    pl_bg_dir <= WEST;
                if(320 * (pl_y + 33) + pl_x == addr_b
                || 320 * (pl_y + 33) + pl_x + 32 == addr_b
                || 320 * (pl_y + 33) + pl_x + 16 == addr_b)//check SOUTH
                    pl_bg_dir <= SOUTH;   
                         
                //player 2
                if(320 * pl2_y + pl2_x + 33 == addr_b 
                || 320 * (pl2_y + 32) + pl2_x + 33 == addr_b  )//check EAST
                    pl2_bg_dir <= EAST;
                if(320 * (pl2_y - 1) + pl2_x  == addr_b 
                || 320 * (pl2_y - 1) + pl2_x + 32  == addr_b
                || 320 * (pl2_y - 1) + pl2_x + 16  == addr_b)//check North
                    pl2_bg_dir <= NORTH;
                if(320 * pl2_y + pl2_x  - 1 == addr_b
                || 320 * (pl2_y + 32) + pl2_x  - 1 == addr_b )//check WEST
                    pl2_bg_dir <= WEST;
                if(320 * (pl2_y + 33) + pl2_x == addr_b
                || 320 * (pl2_y + 33) + pl2_x + 32 == addr_b
                || 320 * (pl2_y + 33) + pl2_x + 16 == addr_b)//check SOUTH
                    pl2_bg_dir <= SOUTH;
                
                
                
                //player 2 bullets
                if(pl2_bl_stat[0][0])//bullet 0 pl2
                begin 
                    if(320 * pl2_bl_y[0] + pl2_bl_x[0] + 9 == addr_b 
                    || 320 * (pl2_bl_y[0] + 6) + pl2_bl_x[0] + 9 == addr_b  )//check EAST
                        pl2_bbg_dir[0] <= EAST;
                    if(320 * (pl2_bl_y[0] - 3) + pl2_bl_x[0]  == addr_b 
                    || 320 * (pl2_bl_y[0] - 3) + pl2_bl_x[0] + 6  == addr_b)//check North
                        pl2_bbg_dir[0] <= NORTH;
                    if(320 * pl2_bl_y[0] + pl2_bl_x[0]  - 3 == addr_b
                    || 320 * (pl2_bl_y[0] + 6) + pl2_bl_x[0]  - 3 == addr_b )//check WEST
                        pl2_bbg_dir[0] <= WEST;
                    if(320 * (pl2_bl_y[0] + 9) + pl2_bl_x[0] == addr_b
                    || 320 * (pl2_bl_y[0] + 9) + pl2_bl_x[0] + 6 == addr_b)//check SOUTH
                        pl2_bbg_dir[0] <= SOUTH;
                end     
                if(pl2_bl_stat[1][0])//bullet 1 pl2
                begin 
                    if(320 * pl2_bl_y[1] + pl2_bl_x[1] + 9 == addr_b 
                    || 320 * (pl2_bl_y[1] + 6) + pl2_bl_x[1] + 9 == addr_b  )//check EAST
                        pl2_bbg_dir[1] <= EAST;
                    if(320 * (pl2_bl_y[1] - 3) + pl2_bl_x[1]  == addr_b 
                    || 320 * (pl2_bl_y[1] - 3) + pl2_bl_x[1] + 6  == addr_b)//check North
                        pl2_bbg_dir[1] <= NORTH;
                    if(320 * pl2_bl_y[1] + pl2_bl_x[1]  - 3 == addr_b
                    || 320 * (pl2_bl_y[1] + 6) + pl2_bl_x[1]  - 3 == addr_b )//check WEST
                        pl2_bbg_dir[1] <= WEST;
                    if(320 * (pl2_bl_y[1] + 9) + pl2_bl_x[1] == addr_b
                    || 320 * (pl2_bl_y[1] + 9) + pl2_bl_x[1] + 6 == addr_b)//check SOUTH
                        pl2_bbg_dir[1] <= SOUTH;
                end   
                if(pl2_bl_stat[2][0])//bullet 2 pl2
                begin 
                    if(320 * pl2_bl_y[2] + pl2_bl_x[2] + 9 == addr_b 
                    || 320 * (pl2_bl_y[2] + 6) + pl2_bl_x[2] + 9 == addr_b  )//check EAST
                        pl2_bbg_dir[2] <= EAST;
                    if(320 * (pl2_bl_y[2] - 3) + pl2_bl_x[2]  == addr_b 
                    || 320 * (pl2_bl_y[2] - 3) + pl2_bl_x[2] + 6  == addr_b)//check North
                        pl2_bbg_dir[2] <= NORTH;
                    if(320 * pl2_bl_y[2] + pl2_bl_x[2]  - 3 == addr_b
                    || 320 * (pl2_bl_y[2] + 6) + pl2_bl_x[2]  - 3 == addr_b )//check WEST
                        pl2_bbg_dir[2] <= WEST;
                    if(320 * (pl2_bl_y[2] + 9) + pl2_bl_x[2] == addr_b
                    || 320 * (pl2_bl_y[2] + 9) + pl2_bl_x[2] + 6 == addr_b)//check SOUTH
                        pl2_bbg_dir[2] <= SOUTH;
                end 
                
                //player 1 bullets
                if(pl_bl_stat[0][0])//bullet 0 pl
                begin 
                    if(320 * pl_bl_y[0] + pl_bl_x[0] + 8 == addr_b 
                    || 320 * (pl_bl_y[0] + 6) + pl_bl_x[0] + 8 == addr_b  )//check EAST
                        pl_bbg_dir[0] <= EAST;
                    if(320 * (pl_bl_y[0] - 3) + pl_bl_x[0]  == addr_b 
                    || 320 * (pl_bl_y[0] - 3) + pl_bl_x[0] + 6  == addr_b)//check North
                        pl_bbg_dir[0] <= NORTH;
                    if(320 * pl_bl_y[0] + pl_bl_x[0]  - 3 == addr_b
                    || 320 * (pl_bl_y[0] + 6) + pl_bl_x[0]  - 3 == addr_b )//check WEST
                        pl_bbg_dir[0] <= WEST;
                    if(320 * (pl_bl_y[0] + 9) + pl_bl_x[0] == addr_b
                    || 320 * (pl_bl_y[0] + 9) + pl_bl_x[0] + 6 == addr_b)//check SOUTH
                        pl_bbg_dir[0] <= SOUTH;
                end     
                if(pl_bl_stat[1][0])//bullet 1 pl
                begin 
                    if(320 * pl_bl_y[1] + pl_bl_x[1] + 9 == addr_b 
                    || 320 * (pl_bl_y[1] + 6) + pl_bl_x[1] + 9 == addr_b  )//check EAST
                        pl_bbg_dir[1] <= EAST;
                    if(320 * (pl_bl_y[1] - 3) + pl_bl_x[1]  == addr_b 
                    || 320 * (pl_bl_y[1] - 3) + pl_bl_x[1] + 6  == addr_b)//check North
                        pl_bbg_dir[1] <= NORTH;
                    if(320 * pl_bl_y[1] + pl_bl_x[1]  - 3 == addr_b
                    || 320 * (pl_bl_y[1] + 6) + pl_bl_x[1]  - 3 == addr_b )//check WEST
                        pl_bbg_dir[1] <= WEST;
                    if(320 * (pl_bl_y[1] + 9) + pl_bl_x[1] == addr_b
                    || 320 * (pl_bl_y[1] + 9) + pl_bl_x[1] + 6 == addr_b)//check SOUTH
                        pl_bbg_dir[1] <= SOUTH;
                end   
                if(pl_bl_stat[2][0])//bullet 2 pl
                begin 
                    if(320 * pl_bl_y[2] + pl_bl_x[2] + 9 == addr_b 
                    || 320 * (pl_bl_y[2] + 6) + pl_bl_x[2] + 9 == addr_b  )//check EAST
                        pl_bbg_dir[2] <= EAST;
                    if(320 * (pl_bl_y[2] - 3) + pl_bl_x[2]  == addr_b 
                    || 320 * (pl_bl_y[2] - 3) + pl_bl_x[2] + 6  == addr_b)//check North
                        pl_bbg_dir[2] <= NORTH;
                    if(320 * pl_bl_y[2] + pl_bl_x[2]  - 3 == addr_b
                    || 320 * (pl_bl_y[2] + 6) + pl_bl_x[2]  - 3 == addr_b )//check WEST
                        pl_bbg_dir[2] <= WEST;
                    if(320 * (pl_bl_y[2] + 9) + pl_bl_x[2] == addr_b
                    || 320 * (pl_bl_y[2] + 9) + pl_bl_x[2] + 6 == addr_b)//check SOUTH
                        pl_bbg_dir[2] <= SOUTH;
                end 
                
                end     
                 
            end//state 0
            
            1://Draw Player 1 Bullets!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            begin
                if(bullet_it == 3) // went through all bullets
                begin
            //state Change
                    state <= 2;
                    draw_y <= 0;
                    draw_x <= 0;
                    bullet_it <= 0;
                end
                
                if(pl_bl_stat[bullet_it][0])
                begin
                // Here to reset draw_y in between bullets
                if(draw_y == 6)
                begin
                    bullet_it <= bullet_it + 1;
                    draw_y <= 0;
                end
                
                // Standard itterator used, limits of 6x6 bullet sprite
                if(draw_x == 6)
                begin
                    draw_x <= 0;
                    draw_y <= draw_y + 1; 
                end
                else
                begin
                draw_x <= draw_x + 1;
                end
                
                //address used to find location of sprite on sprite memory
                addr_s <= 9 * 32 + (320 * draw_y) + draw_x;
                //address of Location of bullet on screen
                address_fb1 <= 320 * (pl_bl_y[bullet_it] + draw_y) + pl_bl_x[bullet_it] + draw_x;
                address_fb2 <= address_fb1;// Pipeline register to precent spirit shifting to the right
                
                
                
                //paste to frame Buffers
                if(write_1)
                begin
                    addr_1 <= address_fb2;
                    datain_1 <= dataout_s;
                end
                else 
                begin
                    addr_2 <= address_fb2;
                    datain_2 <= dataout_s;
                end
            
            
                end
                else
                    bullet_it <= bullet_it + 1;
                
            
            end//state 1
            
            2://Draw Player 2 Bullets!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            begin
                if(bullet_it == 3) // went through all bullets
                begin
            //state Change
                    state <= 3;
                    draw_y <= 0;
                    draw_x <= 0;
                    bullet_it <= 0;
                end
                
                if(pl2_bl_stat[bullet_it][0])
                begin
                // Here to reset draw_y in between bullets
                if(draw_y == 6)
                begin
                    bullet_it <= bullet_it + 1;
                    draw_y <= 0;
                end
                
                // Standard itterator used, limits of 6x6 bullet sprite
                if(draw_x == 6)
                begin
                    draw_x <= 0;
                    draw_y <= draw_y + 1; 
                end
                else
                begin
                draw_x <= draw_x + 1;
                end
                
                //address used to find location of sprite on sprite memory
                addr_s <= 9 * 32 + (320 * draw_y) + draw_x;
                //address of Location of bullet on screen
                address_fb1 <= 320 * (pl2_bl_y[bullet_it] + draw_y) + pl2_bl_x[bullet_it] + draw_x;
                address_fb2 <= address_fb1;// Pipeline register to precent spirit shifting to the right
                
                
                
                //paste to frame Buffers
                if(write_1)
                begin
                    addr_1 <= address_fb2;
                    datain_1 <= dataout_s;
                end
                else 
                begin
                    addr_2 <= address_fb2;
                    datain_2 <= dataout_s;
                end
            
            
                end
                else
                    bullet_it <= bullet_it + 1;
                
            end//state 2
   
            3:// Draw Player 1~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            begin
                if(draw_y == 31)
                begin   //Execute only when done with a single 32 x 32 sprite
            //StateChange    
                    state <= 4;
                    draw_y <= 0;
                    draw_x <= 0;
                end
                
                    
                //Iterrator of Draw registers
                if(draw_x == 31)
                begin
                    draw_x <= 0;
                    draw_y <= draw_y + 1;
                end
                else
                begin 
                    draw_x <= draw_x + 1;
                end
                
                //address used to find location of sprite on sprite memory
                addr_s <= pl_sprite * 32 + (320 * draw_y) + draw_x;
                //address of Location of play on screen
                address_fb1 <= 320 * (pl_y + draw_y) + pl_x + draw_x;
                address_fb2 <= address_fb1;// Pipeline register to precent spirit shifting to the right
                 address_fb3 <= address_fb2;
                 
                //Change Color to blue (1st player)
                if(dataout_s == 0)
                begin
                    data_buff <= 6'b000011;
                end
                else 
                begin
                    data_buff <= dataout_s;
                end
                
                //paste to frame Buffers
                if(write_1)
                begin
                    addr_1 <= address_fb3;
                    datain_1 <= data_buff;
                end
                else 
                begin
                    addr_2 <= address_fb3;
                    datain_2 <= data_buff;
                end
                
               
                
            end//state 3
            
            4:// Draw Player 2~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            begin
                 if(draw_y == 31)
                begin   //Execute only when done with a single 32 x 32 sprite
                //StateChange 
            
                    draw_y <= 0;
                    draw_x <= 0;
                    if(GameOver)
                        state <= 5;
                    else
                        state <= 6;
                    
                    
                end
                
                    
                //Iterrator of Draw registers
                if(draw_x == 31)
                begin
                    draw_x <= 0;
                    draw_y <= draw_y + 1;
                end
                else
                begin 
                    draw_x <= draw_x + 1;
                end
                
                //address used to find location of sprite on sprite memory
                addr_s <= pl2_sprite * 32 + (320 * draw_y) + draw_x;
                //address of Location of play on screen
                address_fb1 <= 320 * (pl2_y + draw_y) + pl2_x + draw_x;
                address_fb2 <= address_fb1;// Pipeline register to precent spirit shifting to the right
                 address_fb3 <= address_fb2;
                 
                //Change Color to blue (1st player)
                if(dataout_s == 0)
                begin
                    data_buff <= 6'b110000;
                end
                else 
                begin
                    data_buff <= dataout_s;
                end
                
                //paste to frame Buffers
                if(write_1)
                begin
                    addr_1 <= address_fb3;
                    datain_1 <= data_buff;
                end
                else 
                begin
                    addr_2 <= address_fb3;
                    datain_2 <= data_buff;
                end
                
                

            end//state 4

            5://GameOver screen
            begin
                if(draw_y == 31 - 8)
                begin   //Execute only when done with a single 32 x 32 sprite
            //StateChange 
                    state <= 6;
                    draw_y <= 0;
                    draw_x <= 0;
                end
                
                    
                //Iterrator of Draw registers
                if(draw_x == 31)
                begin
                    draw_x <= 0;
                    draw_y <= draw_y + 1;
                end
                else
                begin 
                    draw_x <= draw_x + 1;
                end
                
                //address used to find location of sprite on sprite memory
                addr_s <= 9 * 32 + (320 * (draw_y + 8)) + draw_x;
                //address of Location of play on screen
                address_fb1 <= 320 * (100 - 12 + draw_y) + 160 - 16 + draw_x;
                address_fb2 <= address_fb1;// Pipeline register to precent spirit shifting to the right

                //paste to frame Buffers
                if(write_1)
                begin
                    addr_1 <= address_fb2;
                    datain_1 <= dataout_s;
                end
                else 
                begin
                    addr_2 <= address_fb2;
                    datain_2 <= dataout_s;
                end
                
                
  
            end//state 5
            
            6:
            begin
             //do nothing. wait to redraw 
            end//state 6
            
        endcase
        
    
       //Every Pixel output into color/ Double Buffering||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
        if (pix_stb)  
        begin
        
            if (write_1)  // when drawing to 1, output from 2
            begin
                addr_2 <= y * 320 + x;
                color <= active ? dataout_2 : 0;
            end
            else  // otherwise output from 1
            begin
                addr_1 <= y * 320 + x;
                color <= active ? dataout_1 : 0;
            end
            
  
            if (endframe && !GameOver)// all updates to frames happen here||||||||||||||||||||||||||||||||||||||||||||||||||||||||
            begin
                //reset drawing state machin        
                state <= 0;
                
               //Toggle double buffering
                write_1 <= ~write_1;
                write_2 <= ~write_2;
                
                pl_bg_dir <= 0;
                pl_bbg_dir[0] <= 0;
                pl_bbg_dir[1] <= 0;
                pl_bbg_dir[2] <= 0;
                
                pl2_bg_dir <= 0;
                pl2_bbg_dir[0] <= 0;
                pl2_bbg_dir[1] <= 0;
                pl2_bbg_dir[2] <= 0; 
                
                 //Update Ship Player 1 +  boundary Physics~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
                case(pl_stat[5:2])
                    EAST:// E
                    begin
                        pl_sprite <= 0;// update sprite
                        
                        if(pl_x + 32 < 320
                        && !(pl_bg_dir == EAST) ) // check for EAST bound
                            pl_x <= pl_x + 1;
                        
                    end 
                      
                    NORTHEAST:// NE
                    begin
                        pl_sprite <= 1;// update sprite
                        
                        if( pl_x + 32 < 320
                        && !(pl_bg_dir == EAST) ) // check for EAST bound
                            pl_x <= pl_x + 1;
                        if( pl_y > 0 
                        && !(pl_bg_dir == NORTH) )      //check for NORTH Bound
                            pl_y <= pl_y - 1;
                    
                    end 
                    NORTH:// N
                    begin
                        pl_sprite <= 2;// update sprite

                        if( pl_y > 0 
                        && !(pl_bg_dir == NORTH))  //check for NORTH Bound
                            pl_y <= pl_y - 1;

                    end 
                    NORTHWEST:// NW
                    begin
                        pl_sprite <= 3;// update sprite

                        if( pl_x > 0
                        && !(pl_bg_dir == WEST))    // check for WEST bound
                            pl_x <= pl_x - 1;
                        if( pl_y > 0 
                        && !(pl_bg_dir == NORTH))      //check for NORTH Bound
                            pl_y <= pl_y - 1;
                       
                    end
                    WEST:// W 
                    begin
                        pl_sprite <= 4;// update sprite

                        if( pl_x > 0 
                        && !(pl_bg_dir == WEST))// check for WEST bound
                            pl_x <= pl_x - 1;
                            
                        
                    end 
                    SOUTHWEST:// SW 
                    begin
                        pl_sprite <= 5;// update sprite
              
                        if( pl_x > 0
                        && !(pl_bg_dir == WEST)) // check for WEST bound
                            pl_x <= pl_x - 1;
                        if( pl_y + 32 < 200 
                        && !(pl_bg_dir == SOUTH)) //check for SOUTH Bound
                            pl_y <= pl_y + 1;
                       
                    end 
                    SOUTH:// S 
                    begin
                        pl_sprite <= 6;// update sprite
                        
                        if( pl_y + 32 < 200
                        && !(pl_bg_dir == SOUTH))//check for SOUTH Bound
                            pl_y <= pl_y + 1;
                       
                    end 
                    SOUTHEAST:// SE
                    begin
                        pl_sprite <= 7;// update sprite
                        
                        if( pl_x + 32 < 320
                        && !(pl_bg_dir == EAST) ) // check for east bound
                            pl_x = pl_x + 1;
                        if(pl_y + 32 < 200 
                        && !(pl_bg_dir == SOUTH))      //check for South Bound
                            pl_y = pl_y + 1;
                        
                    end 
                    default: begin//do nothing
                    end
                endcase
                
                 //Update Ship Player 2 +  boundary Physics~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
                case(pl2_stat[5:2])
                    EAST:// E
                    begin
                        pl2_sprite <= 0;// update sprite
                        
                        if(pl2_x + 32 < 320
                        && !(pl2_bg_dir == EAST)) // check for EAST bound
                            pl2_x <= pl2_x + 1;
                        
                    end 
                      
                    NORTHEAST:// NE
                    begin
                        pl2_sprite <= 1;// update sprite
                        
                        if( pl2_x + 32 < 320
                        && !(pl2_bg_dir == EAST)) // check for EAST bound
                            pl2_x <= pl2_x + 1;
                        if( pl2_y > 0 
                        && !(pl2_bg_dir == NORTH))      //check for NORTH Bound
                            pl2_y <= pl2_y - 1;
                    
                    end 
                    NORTH:// N
                    begin
                        pl2_sprite <= 2;// update sprite
                        
                        if( pl2_y > 0 
                        && !(pl2_bg_dir == NORTH))  //check for NORTH Bound
                            pl2_y <= pl2_y - 1;

                    end 
                    NORTHWEST:// NW
                    begin
                        pl2_sprite <= 3;// update sprite
                        
                        if( pl2_x > 0 
                        && !(pl2_bg_dir == WEST))    // check for WEST bound
                            pl2_x <= pl2_x - 1;
                        if( pl2_y > 0 
                        && !(pl2_bg_dir == NORTH))      //check for NORTH Bound
                            pl2_y <= pl2_y - 1;
                       
                    end
                    WEST:// W 
                    begin
                        pl2_sprite <= 4;// update sprite
                        
                        if( pl2_x > 0 
                        && !(pl2_bg_dir == WEST))// check for WEST bound
                            pl2_x <= pl2_x - 1;
                            
                        
                    end 
                    SOUTHWEST:// SW 
                    begin
                        pl2_sprite <= 5;// update sprite
                        
                        if( pl2_x > 0
                        && !(pl2_bg_dir == WEST)) // check for WEST bound
                            pl2_x <= pl2_x - 1;
                        if( pl2_y + 32 < 200 
                        && !(pl2_bg_dir == SOUTH)) //check for SOUTH Bound
                            pl2_y <= pl2_y + 1;
                       
                    end 
                    SOUTH:// S 
                    begin
                        pl2_sprite <= 6;// update sprite
                        
                        if( pl2_y + 32 < 200 
                        && !(pl2_bg_dir == SOUTH))//check for SOUTH Bound
                            pl2_y <= pl2_y + 1;
                       
                    end 
                    SOUTHEAST:// SE
                    begin
                        pl2_sprite <= 7;// update sprite
                        
                        if( pl2_x + 32 < 320
                        && !(pl2_bg_dir == EAST)) // check for east bound
                            pl2_x = pl2_x + 1;
                        if(pl2_y + 32 < 200 
                        && !(pl2_bg_dir == SOUTH))      //check for South Bound
                            pl2_y = pl2_y + 1;
                        
                    end 
                    default: begin//do nothing
                    end
                endcase
                
                //Update player 1 Bullets ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                case(pl_sprite) //case finding the direction of tank with sprite
                    0: pl_bl_dir <= EAST;
                    1: pl_bl_dir <= NORTHEAST;
                    2: pl_bl_dir <= NORTH;
                    3: pl_bl_dir <= NORTHWEST;
                    4: pl_bl_dir <= WEST;
                    5: pl_bl_dir <= SOUTHWEST;
                    6: pl_bl_dir <= SOUTH;
                    7: pl_bl_dir <= SOUTHEAST;
                endcase
                
                if(!pl_stat[1])// button pushed to shoot
                begin

                    if( bl_delay > 16)// hold 6 frames until one can shoot again
                    begin
                         bl_delay <= 0;
  
                        if(pl_bl_stat[0][0] == 0)//if bullet 0 open
                        begin 
                            pl_bl_stat[0][4:0] <= {pl_bl_dir,1'b1};
                            pl_bl_x[0] <= pl_x + 13; // !!change for each specific direction 
                            pl_bl_y[0] <= pl_y + 13;
                        end
                        else if(pl_bl_stat[1][0] == 0)//if bullet 1 open
                        begin
                            pl_bl_stat[1][4:0] <= {pl_bl_dir,1'b1};
                            pl_bl_x[1] <= pl_x + 13; // !!change for each specific direction 
                            pl_bl_y[1] <= pl_y + 13;    
                        end
                        else if(pl_bl_stat[2][0] == 0)//if bullet 2 open
                        begin 
                            pl_bl_stat[2][4:0] <= {pl_bl_dir,1'b1};
                            pl_bl_x[2] <= pl_x + 13; // !!change for each specific direction 
                            pl_bl_y[2] <= pl_y + 13;
                        end
                        //else none are open then do nothing.

                    end
                    else
                    begin
                        bl_delay <= bl_delay + 1;
                    end
                    
                
                end
                
                // movement for player 1 bullet 0-2 + boundary physics~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      //bullet 0  pl  
                if(pl_bl_stat[0][0])
                begin
                
                if( pl_bl_x[0] + 8 >= 320 
                 || pl_bl_y[0] + 8 >= 200
                 || pl_bl_x[0] <= 2
                 || pl_bl_y[0] <= 2)
                 begin
                    pl_bl_stat[0] <= 0;
                 end
                
                case(pl_bl_stat[0][4:1])
                
                    EAST:// E
                    begin
                        pl_bl_x[0] <= pl_bl_x[0] + 2;
                        
                        if(pl_bbg_dir[0] == EAST)
                            pl_bl_stat[0] <= 0; 
                    end 
                      
                    NORTHEAST:// NE
                    begin
                        pl_bl_x[0] <= pl_bl_x[0] + 2;
                        pl_bl_y[0] <= pl_bl_y[0] - 2;
                        
                        if(pl_bbg_dir[0] == EAST)
                            pl_bl_stat[0] <= 0;
                        if(pl_bbg_dir[0] == NORTH)
                            pl_bl_stat[0] <= 0;
                    end 
                    NORTH:// N
                    begin  
                            pl_bl_y[0] <= pl_bl_y[0] - 2;
 
                            if(pl_bbg_dir[0] == NORTH)
                                pl_bl_stat[0] <= 0;
                    end 
                    NORTHWEST:// NW
                    begin
                           pl_bl_x[0] <= pl_bl_x[0] - 2;
                           pl_bl_y[0] <= pl_bl_y[0] - 2;
                           
                           if(pl_bbg_dir[0] == WEST)
                                pl_bl_stat[0] <= 0;
                            if(pl_bbg_dir[0] == NORTH)
                                pl_bl_stat[0] <= 0;
                    end
                    WEST:// W 
                    begin
                           pl_bl_x[0] <= pl_bl_x[0] - 2;
                           
                           if(pl_bbg_dir[0] == EAST)
                                pl_bl_stat[0] <= 0;
                            
                    end 
                    SOUTHWEST:// SW 
                    begin
                            pl_bl_x[0] <= pl_bl_x[0] - 2;
                            pl_bl_y[0] <= pl_bl_y[0] + 2;
                            
                            if(pl_bbg_dir[0] == WEST)
                                pl_bl_stat[0] <= 0;
                            if(pl_bbg_dir[0] == SOUTH)
                                pl_bl_stat[0] <= 0;
                    end 
                    SOUTH:// S 
                    begin
                            pl_bl_y[0] <= pl_bl_y[0] + 2;
                            if(pl_bbg_dir[0] == SOUTH)
                                pl_bl_stat[0] <= 0;
                            
                    end 
                    SOUTHEAST:// SE
                    begin
                            pl_bl_x[0] = pl_bl_x[0] + 2;
                            pl_bl_y[0] = pl_bl_y[0] + 2;
                            
                            if(pl_bbg_dir[0] == EAST)
                                pl_bl_stat[0] <= 0;
                            if(pl_bbg_dir[0] == SOUTH)
                                pl_bl_stat[0] <= 0;
                    end 
                    default: begin//do nothing
                    end
                endcase
                end
      //bullet 1  pl        
                if(pl_bl_stat[1][0])
                begin
                
                if( pl_bl_x[1] + 8 >= 320 
                 || pl_bl_y[1] + 8 >= 200
                 || pl_bl_x[1] <= 2
                 || pl_bl_y[1] <= 2)
                 begin
                    pl_bl_stat[1] <= 0;
                 end
                 
                case(pl_bl_stat[1][4:1])
                
                    EAST:// E
                    begin
                        pl_bl_x[1] <= pl_bl_x[1] + 2;
                                                
                        if(pl_bbg_dir[1] == EAST)
                                pl_bl_stat[1] <= 0;
                        
                    end 
                      
                    NORTHEAST:// NE
                    begin
                        pl_bl_x[1] <= pl_bl_x[1] + 2;
                        pl_bl_y[1] <= pl_bl_y[1] - 2;
                        
                        if(pl_bbg_dir[1] == EAST)
                                pl_bl_stat[1] <= 0;
                        if(pl_bbg_dir[1] == NORTH)
                                pl_bl_stat[1] <= 0;
                    end 
                    NORTH:// N
                    begin  
                            pl_bl_y[1] <= pl_bl_y[1] - 2;
       
                            if(pl_bbg_dir[1] == NORTH)
                                pl_bl_stat[1] <= 0;
                    end 
                    NORTHWEST:// NW
                    begin
                           pl_bl_x[1] <= pl_bl_x[1] - 2;
                           pl_bl_y[1] <= pl_bl_y[1] - 2;
                           
                           if(pl_bbg_dir[1] == WEST)
                                pl_bl_stat[1] <= 0;
                            if(pl_bbg_dir[1] == NORTH)
                                pl_bl_stat[1] <= 0;
                    end
                    WEST:// W 
                    begin
                           pl_bl_x[1] <= pl_bl_x[1] - 2;
                           
                           if(pl_bbg_dir[1] == WEST)
                                pl_bl_stat[1] <= 0;
                        
                    end 
                    SOUTHWEST:// SW 
                    begin
                            pl_bl_x[1] <= pl_bl_x[1] - 2;
                            pl_bl_y[1] <= pl_bl_y[1] + 2;
                            
                            if(pl_bbg_dir[1] == WEST)
                                pl_bl_stat[1] <= 0;
                            if(pl_bbg_dir[1] == SOUTH)
                                pl_bl_stat[1] <= 0;
                    end 
                    SOUTH:// S 
                    begin
                            pl_bl_y[1] <= pl_bl_y[1] + 2;
                            
                            
                            if(pl_bbg_dir[1] == SOUTH)
                                pl_bl_stat[1] <= 0;
                    end 
                    SOUTHEAST:// SE
                    begin
                            pl_bl_x[1] = pl_bl_x[1] + 2;
                            pl_bl_y[1] = pl_bl_y[1] + 2;
                            
                            if(pl_bbg_dir[1] == EAST)
                                pl_bl_stat[1] <= 0;
                            if(pl_bbg_dir[1] == SOUTH)
                                pl_bl_stat[1] <= 0;
                    end 
                    default: begin//do nothing
                    end
                endcase
                end
      //bullet 2  pl                       
                if(pl_bl_stat[2][0])
                begin
                
                if( pl_bl_x[2] + 8 >= 320 
                 || pl_bl_y[2] + 8 >= 200
                 || pl_bl_x[2] <= 2
                 || pl_bl_y[2] <= 2)
                 begin
                    pl_bl_stat[2] <= 0;
                 end
                 
                case(pl_bl_stat[2][4:1])
                
                    EAST:// E
                    begin
                        pl_bl_x[2] <= pl_bl_x[2] + 2;
                        
                        if(pl_bbg_dir[2] == EAST)
                                pl_bl_stat[2] <= 0;

                    end 
                      
                    NORTHEAST:// NE
                    begin
                        pl_bl_x[2] <= pl_bl_x[2] + 2;
                        pl_bl_y[2] <= pl_bl_y[2] - 2;
                        
                        if(pl_bbg_dir[2] == EAST)
                                pl_bl_stat[2] <= 0;
                        if(pl_bbg_dir[2] == NORTH)
                                pl_bl_stat[2] <= 0;
                    end 
                    NORTH:// N
                    begin  
                            pl_bl_y[2] <= pl_bl_y[2] - 2;
  
                            if(pl_bbg_dir[2] == NORTH)
                                pl_bl_stat[2] <= 0;
                    end 
                    NORTHWEST:// NW
                    begin
                           pl_bl_x[2] <= pl_bl_x[2] - 2;
                           pl_bl_y[2] <= pl_bl_y[2] - 2;
                           
                           if(pl_bbg_dir[2] == WEST)
                                pl_bl_stat[2] <= 0;
                            if(pl_bbg_dir[2] == NORTH)
                                pl_bl_stat[2] <= 0;
                    end
                    WEST:// W 
                    begin
                           pl_bl_x[2] <= pl_bl_x[2] - 2;
                           
                           if(pl_bbg_dir[2] == WEST)
                                pl_bl_stat[2] <= 0;
                            
                    end 
                    SOUTHWEST:// SW 
                    begin
                            pl_bl_x[2] <= pl_bl_x[2] - 2;
                            pl_bl_y[2] <= pl_bl_y[2] + 2;
                            
                            if(pl_bbg_dir[2] == WEST)
                                pl_bl_stat[2] <= 0;
                            if(pl_bbg_dir[2] == SOUTH)
                                pl_bl_stat[2] <= 0;
                    end 
                    SOUTH:// S 
                    begin
                            pl_bl_y[2] <= pl_bl_y[2] + 2;
                            
                            if(pl_bbg_dir[2] == SOUTH)
                                pl_bl_stat[2] <= 0;
                    end 
                    SOUTHEAST:// SE
                    begin
                            pl_bl_x[2] = pl_bl_x[2] + 2;
                            pl_bl_y[2] = pl_bl_y[2] + 2;
                            
                            if(pl_bbg_dir[2] == EAST)
                                pl_bl_stat[2] <= 0;
                            if(pl_bbg_dir[2] == SOUTH)
                                pl_bl_stat[2] <= 0;
                    end 
                    default: begin//do nothing
                    end
                endcase
                end
                
                 //Update player 2 Bullets ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                case(pl2_sprite) //case finding the direction of tank with sprite
                    0: pl2_bl_dir <= EAST;
                    1: pl2_bl_dir <= NORTHEAST;
                    2: pl2_bl_dir <= NORTH;
                    3: pl2_bl_dir <= NORTHWEST;
                    4: pl2_bl_dir <= WEST;
                    5: pl2_bl_dir <= SOUTHWEST;
                    6: pl2_bl_dir <= SOUTH;
                    7: pl2_bl_dir <= SOUTHEAST;
                endcase
                
                if(!pl2_stat[1])// button pushed to shoot
                begin

                    if( bl2_delay > 16)// hold 6 frames until one can shoot again
                    begin
                         bl2_delay <= 0;
  
                        if(pl2_bl_stat[0][0] == 0)//if bullet 0 open
                        begin 
                            pl2_bl_stat[0][4:0] <= {pl2_bl_dir,1'b1};
                            pl2_bl_x[0] <= pl2_x + 13; // !!change for each specific direction 
                            pl2_bl_y[0] <= pl2_y + 13;
                        end
                        else if(pl2_bl_stat[1][0] == 0)//if bullet 1 open
                        begin
                            pl2_bl_stat[1][4:0] <= {pl2_bl_dir,1'b1};
                            pl2_bl_x[1] <= pl2_x + 13; // !!change for each specific direction 
                            pl2_bl_y[1] <= pl2_y + 13;    
                        end
                        else if(pl2_bl_stat[2][0] == 0)//if bullet 2 open
                        begin 
                            pl2_bl_stat[2][4:0] <= {pl2_bl_dir,1'b1};
                            pl2_bl_x[2] <= pl2_x + 13; // !!change for each specific direction 
                            pl2_bl_y[2] <= pl2_y + 13;
                        end
                        //else none are open then do nothing.

                    end
                    else
                    begin
                        bl2_delay <= bl2_delay + 1;
                    end
                    
                
                end
                
                // movement for player 2 bullet 0-2 + boundary physics~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      //bullet 0  pl2     
                if(pl2_bl_stat[0][0])
                begin
                
                if( pl2_bl_x[0] + 8 >= 320 
                 || pl2_bl_y[0] + 8 >= 200
                 || pl2_bl_x[0] <= 2
                 || pl2_bl_y[0] <= 2)
                 begin
                    pl2_bl_stat[0] <= 0;
                 end
                 
                case(pl2_bl_stat[0][4:1])
                
                    EAST:// E
                    begin
                        pl2_bl_x[0] <= pl2_bl_x[0] + 2;
                        
                        if(pl2_bbg_dir[0] == EAST)
                            pl2_bl_stat[0] <= 0;
                        
                    end 
                      
                    NORTHEAST:// NE
                    begin
                        pl2_bl_x[0] <= pl2_bl_x[0] + 2;
                        pl2_bl_y[0] <= pl2_bl_y[0] - 2;
                        
                        if(pl2_bbg_dir[0] == EAST)
                            pl2_bl_stat[0] <= 0;
                        if(pl2_bbg_dir[0] == NORTH)
                            pl2_bl_stat[0] <= 0;
                    end 
                    NORTH:// N
                    begin  
                            pl2_bl_y[0] <= pl2_bl_y[0] - 2;
                            
                            if(pl2_bbg_dir[0] == NORTH)
                                pl2_bl_stat[0] <= 0;
                    end 
                    NORTHWEST:// NW
                    begin
                           pl2_bl_x[0] <= pl2_bl_x[0] - 2;
                           pl2_bl_y[0] <= pl2_bl_y[0] - 2;
                           
                           if(pl2_bbg_dir[0] == WEST)
                                pl2_bl_stat[0] <= 0;
                            if(pl2_bbg_dir[0] == NORTH)
                                pl2_bl_stat[0] <= 0;
                    end
                    WEST:// W 
                    begin
                           pl2_bl_x[0] <= pl2_bl_x[0] - 2;
                           
                           if(pl2_bbg_dir[0] == WEST)
                            pl2_bl_stat[0] <= 0;
                        
                    end 
                    SOUTHWEST:// SW 
                    begin
                            pl2_bl_x[0] <= pl2_bl_x[0] - 2;
                            pl2_bl_y[0] <= pl2_bl_y[0] + 2;
                            
                            if(pl2_bbg_dir[0] == WEST)
                                pl2_bl_stat[0] <= 0;
                            if(pl2_bbg_dir[0] == SOUTH)
                                pl2_bl_stat[0] <= 0;
                    end 
                    SOUTH:// S 
                    begin
                            pl2_bl_y[0] <= pl2_bl_y[0] + 2;
                            
                            if(pl2_bbg_dir[0] == SOUTH)
                                pl2_bl_stat[0] <= 0;
                        
                    end 
                    SOUTHEAST:// SE
                    begin
                            pl2_bl_x[0] = pl2_bl_x[0] + 2;
                            pl2_bl_y[0] = pl2_bl_y[0] + 2;
                            
                            if(pl2_bbg_dir[0] == EAST)
                                pl2_bl_stat[0] <= 0;
                            if(pl2_bbg_dir[0] == SOUTH)
                                pl2_bl_stat[0] <= 0;
                    end 
                    default: begin//do nothing
                    end
                endcase
                end
      //bullet 1  pl2        
                 if(pl2_bl_stat[1][0])
                begin
                
                if( pl2_bl_x[1] + 8 >= 320 
                 || pl2_bl_y[1] + 8 >= 200
                 || pl2_bl_x[1] <= 2
                 || pl2_bl_y[1] <= 2)
                 begin
                    pl2_bl_stat[1] <= 0;
                 end
                
                case(pl2_bl_stat[1][4:1])
                
                    EAST:// E
                    begin
                        pl2_bl_x[1] <= pl2_bl_x[1] + 2;
                        
                        if(pl2_bbg_dir[1] == EAST)
                            pl2_bl_stat[1] <= 0;
                        
                    end 
                      
                    NORTHEAST:// NE
                    begin
                        pl2_bl_x[1] <= pl2_bl_x[1] + 2;
                        pl2_bl_y[1] <= pl2_bl_y[1] - 2;
                        
                        if(pl2_bbg_dir[1] == EAST)
                            pl2_bl_stat[1] <= 0;
                        if(pl2_bbg_dir[1] == NORTH)
                            pl2_bl_stat[1] <= 0;
                    end 
                    NORTH:// N
                    begin  
                            pl2_bl_y[1] <= pl2_bl_y[1] - 2;
                            
                            
                        if(pl2_bbg_dir[1] == NORTH)
                            pl2_bl_stat[1] <= 0;
                    end 
                    NORTHWEST:// NW
                    begin
                           pl2_bl_x[1] <= pl2_bl_x[1] - 2;
                           pl2_bl_y[1] <= pl2_bl_y[1] - 2;
                           
                           if(pl2_bbg_dir[1] == WEST)
                                pl2_bl_stat[1] <= 0;
                            if(pl2_bbg_dir[1] == NORTH)
                                pl2_bl_stat[1] <= 0;
                    end
                    WEST:// W 
                    begin
                           pl2_bl_x[1] <= pl2_bl_x[1] - 2;
                           
                           if(pl2_bbg_dir[1] == WEST)
                            pl2_bl_stat[1] <= 0;
                        
                    end 
                    SOUTHWEST:// SW 
                    begin
                            pl2_bl_x[1] <= pl2_bl_x[1] - 2;
                            pl2_bl_y[1] <= pl2_bl_y[1] + 2;
                            
                           if(pl2_bbg_dir[1] == WEST)
                                pl2_bl_stat[1] <= 0;
                            if(pl2_bbg_dir[1] == SOUTH)
                                pl2_bl_stat[1] <= 0;                          

                    end 
                    SOUTH:// S 
                    begin
                            pl2_bl_y[1] <= pl2_bl_y[1] + 2;
                            
                            if(pl2_bbg_dir[1] == SOUTH)
                            pl2_bl_stat[1] <= 0;
                       
                    end 
                    SOUTHEAST:// SE
                    begin
                            pl2_bl_x[1] = pl2_bl_x[1] + 2;
                            pl2_bl_y[1] = pl2_bl_y[1] + 2;
                            
                            if(pl2_bbg_dir[1] == EAST)
                                pl2_bl_stat[1] <= 0;
                            if(pl2_bbg_dir[1] == SOUTH)
                                pl2_bl_stat[1] <= 0;
                    end 
                    default: begin//do nothing
                    end
                endcase
                end
      //bullet 2  pl2                       
                 if(pl2_bl_stat[2][0])
                begin
                
                if( pl2_bl_x[2] + 8 >= 320
                 || pl2_bl_y[2] + 8 >= 200
                 || pl2_bl_x[2] <= 2
                 || pl2_bl_y[2] <= 2 )
                 begin
                    pl2_bl_stat[2] <= 0;
                 end
                
                case(pl2_bl_stat[2][4:1])
                
                    EAST:// E
                    begin
                        pl2_bl_x[2] <= pl2_bl_x[2] + 2;
                        
                        if(pl2_bbg_dir[2] == EAST)
                            pl2_bl_stat[2] <= 0;
                        
                    end 
                      
                    NORTHEAST:// NE
                    begin
                        pl2_bl_x[2] <= pl2_bl_x[2] + 2;
                        pl2_bl_y[2] <= pl2_bl_y[2] - 2;
                        
                        if(pl2_bbg_dir[2] == EAST)
                            pl2_bl_stat[2] <= 0;
                        if(pl2_bbg_dir[2] == NORTH)
                            pl2_bl_stat[2] <= 0;
                    end 
                    NORTH:// N
                    begin  
                            pl2_bl_y[2] <= pl2_bl_y[2] - 2;
                            
                            if(pl2_bbg_dir[2] == NORTH)
                                pl2_bl_stat[2] <= 0;
                       
                    end 
                    NORTHWEST:// NW
                    begin
                           pl2_bl_x[2] <= pl2_bl_x[2] - 2;
                           pl2_bl_y[2] <= pl2_bl_y[2] - 2;
                           
                            if(pl2_bbg_dir[2] == WEST)
                                pl2_bl_stat[2] <= 0;
                            if(pl2_bbg_dir[2] == NORTH)
                                pl2_bl_stat[2] <= 0;
                    end
                    WEST:// W 
                    begin
                           pl2_bl_x[2] <= pl2_bl_x[2] - 2;
                           
                           if(pl2_bbg_dir[2] == WEST)
                            pl2_bl_stat[2] <= 0;
                        
                    end 
                    SOUTHWEST:// SW 
                    begin
                            pl2_bl_x[2] <= pl2_bl_x[2] - 2;
                            pl2_bl_y[2] <= pl2_bl_y[2] + 2;
                            
                            if(pl2_bbg_dir[2] == WEST)
                                pl2_bl_stat[2] <= 0;
                            if(pl2_bbg_dir[2] == SOUTH)
                                pl2_bl_stat[2] <= 0;
                    end 
                    SOUTH:// S 
                    begin
                            pl2_bl_y[2] <= pl2_bl_y[2] + 2;
                            
                            if(pl2_bbg_dir[2] == SOUTH)
                                pl2_bl_stat[2] <= 0;
                        
                    end 
                    SOUTHEAST:// SE
                    begin
                            pl2_bl_x[2] = pl2_bl_x[2] + 2;
                            pl2_bl_y[2] = pl2_bl_y[2] + 2;
                            
                            if(pl2_bbg_dir[2] == EAST)
                                pl2_bl_stat[2] <= 0;
                            if(pl2_bbg_dir[2] == SOUTH)
                                pl2_bl_stat[2] <= 0;
                    end 
                    default: begin//do nothing
                    end
                endcase
                end 
               
               //All stuff below endgame events physics of game ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                
                //case where ships crash player 2 -> player 1 checking each corner of player 2 on player 1 bounds~~~~~~~~~~~~~~~~~~
                //only use this case, as also covers both sides crashing into eachother
                if( pl_x <= pl2_x && pl2_x <= pl_x + 32 // Left X bound
                &&  pl_y <= pl2_y && pl2_y <= pl_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_sprite <= 8;
                end
                if( pl_x <= pl2_x && pl2_x <= pl_x + 32 // Left X bound
                &&  pl_y <= pl2_y + 32 && pl2_y + 32 <= pl_y + 32  // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_sprite <= 8;
                end
                
                if( pl_x <= pl2_x + 32 && pl2_x + 32 <= pl_x + 32 // Right X bound
                &&  pl_y <= pl2_y && pl2_y <= pl_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_sprite <= 8;
                end
                
                if( pl_x <= pl2_x + 32 && pl2_x + 32 <= pl_x + 32 //Right X Bound
                &&  pl_y <= pl2_y + 32 && pl2_y + 32 <= pl_y + 32 // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_sprite <= 8;
                end                                               
                
                //case where player 1 bullets touch player 2~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                //accomplished same as above but check if bullets corners have crossed player 2 bounds
                
      //bullet 0 pl
                if(pl_bl_stat[0][0])
                begin
                if( pl2_x <= pl_bl_x[0] && pl_bl_x[0] <= pl2_x + 32 // Left X bound
                &&  pl2_y <= pl_bl_y[0] && pl_bl_y[0] <= pl2_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[0][0] <= 0;
                end
                
                if( pl2_x <= pl_bl_x[0] && pl_bl_x[0] <= pl2_x + 32 // Left X bound
                &&  pl2_y <= pl_bl_y[0] + 6 && pl_bl_y[0] + 6 <= pl2_y + 32  // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[0][0] <= 0;
                end
                
                if( pl2_x <= pl_bl_x[0] + 6 && pl_bl_x[0] + 6 <= pl2_x + 32 // Right X bound
                &&  pl2_y <= pl_bl_y[0] && pl_bl_y[0] <= pl2_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[0][0] <= 0;
                end
                
                if( pl2_x <= pl_bl_x[0] + 6 && pl_bl_x[0] + 6 <= pl2_x + 32 //Right X Bound
                &&  pl2_y <= pl_bl_y[0] + 6 && pl_bl_y[0] + 6 <= pl2_y + 32 // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[0][0] <= 0;
                end
                end    
                
     //bullet 1 pl
                if(pl_bl_stat[1][0])
                begin
                if( pl2_x <= pl_bl_x[1] && pl_bl_x[1] <= pl2_x + 32 // Left X bound
                &&  pl2_y <= pl_bl_y[1] && pl_bl_y[1] <= pl2_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[1][0] <= 0;
                end
                
                if( pl2_x <= pl_bl_x[1] && pl_bl_x[1] <= pl2_x + 32 // Left X bound
                &&  pl2_y <= pl_bl_y[1] + 6 && pl_bl_y[1] + 6 <= pl2_y + 32  // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[1][0] <= 0;
                end
                
                if( pl2_x <= pl_bl_x[1] + 6 && pl_bl_x[1] + 6 <= pl2_x + 32 // Right X bound
                &&  pl2_y <= pl_bl_y[1] && pl_bl_y[1] <= pl2_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[1][0] <= 0;
                end
                
                if( pl2_x <= pl_bl_x[1] + 6 && pl_bl_x[1] + 6 <= pl2_x + 32 //Right X Bound
                &&  pl2_y <= pl_bl_y[1] + 6 && pl_bl_y[1] + 6 <= pl2_y + 32 // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[1][0] <= 0;
                end
                end
                           
    //bullet 2 pl
                if(pl_bl_stat[2][0])
                begin
                if( pl2_x <= pl_bl_x[2] && pl_bl_x[2] <= pl2_x + 32 // Left X bound
                &&  pl2_y <= pl_bl_y[2] && pl_bl_y[2] <= pl2_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[2][0] <= 0;
                end
                
                if( pl2_x <= pl_bl_x[2] && pl_bl_x[2] <= pl2_x + 32 // Left X bound
                &&  pl2_y <= pl_bl_y[2] + 6 && pl_bl_y[2] + 6 <= pl2_y + 32  // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[2][0] <= 0;
                end
                if( pl2_x <= pl_bl_x[2] + 6 && pl_bl_x[2] + 6 <= pl2_x + 32 // Right X bound
                &&  pl2_y <= pl_bl_y[2] && pl_bl_y[2] <= pl2_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[2][0] <= 0;
                end
                
                if( pl2_x <= pl_bl_x[2] + 6 && pl_bl_x[2] + 6 <= pl2_x + 32 //Right X Bound
                &&  pl2_y <= pl_bl_y[2] + 6 && pl_bl_y[2] + 6 <= pl2_y + 32 // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl2_sprite <= 8;
                pl_bl_stat[2][0] <= 0;
                end
                end
                
       
                 //case where player 2 bullets touch player 1~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                //accomplished same as above but check if bullets corners have crossed player 2 bounds
                
      //bullet 0 pl2
                if(pl2_bl_stat[0][0])
                begin
                if( pl_x <= pl2_bl_x[0] && pl2_bl_x[0] <= pl_x + 32 // Left X bound
                &&  pl_y <= pl2_bl_y[0] && pl2_bl_y[0] <= pl_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[0][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[0] && pl2_bl_x[0] <= pl_x + 32 // Left X bound
                &&  pl_y <= pl2_bl_y[0] + 6 && pl2_bl_y[0] + 6 <= pl_y + 32  // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[0][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[0] + 6 && pl2_bl_x[0] + 6 <= pl_x + 32 // Right X bound
                &&  pl_y <= pl2_bl_y[0] && pl2_bl_y[0] <= pl_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[0][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[0] + 6 && pl2_bl_x[0] + 6 <= pl_x + 32 //Right X Bound
                &&  pl_y <= pl2_bl_y[0] + 6 && pl2_bl_y[0] + 6 <= pl_y + 32 // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[0][0] <= 0;
                end
                end
                
     //bullet 1 pl2
                if(pl2_bl_stat[1][0])
                begin
                if( pl_x <= pl2_bl_x[1] && pl2_bl_x[1] <= pl_x + 32 // Left X bound
                &&  pl_y <= pl2_bl_y[1] && pl2_bl_y[1] <= pl_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[1][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[1] && pl2_bl_x[1] <= pl_x + 32 // Left X bound
                &&  pl_y <= pl2_bl_y[1] + 6 && pl2_bl_y[1] + 6 <= pl_y + 32  // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[1][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[1] + 6 && pl2_bl_x[1] + 6 <= pl_x + 32 // Right X bound
                &&  pl_y <= pl2_bl_y[1] && pl2_bl_y[1] <= pl_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[1][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[1] + 6 && pl2_bl_x[1] + 6 <= pl_x + 32 //Right X Bound
                &&  pl_y <= pl2_bl_y[1] + 6 && pl2_bl_y[1] + 6 <= pl_y + 32 // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[1][0] <= 0;
                end
                end
                           
    //bullet 2 pl2
                if(pl2_bl_stat[2][0])
                begin
                if( pl_x <= pl2_bl_x[2] && pl2_bl_x[2] <= pl_x + 32 // Left X bound
                &&  pl_y <= pl2_bl_y[2] && pl2_bl_y[2] <= pl_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[2][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[2] && pl2_bl_x[2] <= pl_x + 32 // Left X bound
                &&  pl_y <= pl2_bl_y[2] + 6 && pl2_bl_y[2] + 6 <= pl_y + 32  // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[2][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[2] + 6 && pl2_bl_x[2] + 6 <= pl_x + 32 // Right X bound
                &&  pl_y <= pl2_bl_y[2] && pl2_bl_y[2] <= pl_y + 32  // Top Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[2][0] <= 0;
                end
                
                if( pl_x <= pl2_bl_x[2] + 6 && pl2_bl_x[2] + 6 <= pl_x + 32 //Right X Bound
                &&  pl_y <= pl2_bl_y[2] + 6 && pl2_bl_y[2] + 6 <= pl_y + 32 // Bottom Y Bound
                )begin
                GameOver <= 1;
                pl_sprite <= 8;
                pl2_bl_stat[2][0] <= 0;
                end
                end
                
       
                    
            end
            else if(endframe)
            begin
              //reset drawing state machin        
                state <= 0;
            
               //Toggle double buffering
                write_1 <= ~write_1;
                write_2 <= ~write_2;
            end
                
        end//if pixstb

        //output colors screen every CLK
        vgaRed <= {color[5:4],color[5:4]};
        vgaGreen <= {color[3:2],color[3:2]};
        vgaBlue <= {color[1:0],color[1:0]};
       
       
       
       
       
       
      end  
        
    end
    
    
    
    
endmodule
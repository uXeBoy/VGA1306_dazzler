//partially based on the VGA demo code at http://github.com/OLIMEX/iCE40HX1K-EVB

`default_nettype none //disable implicit definitions by Verilog

module top(
  input  CLK25MHz, //Oscillator input 25MHz
  output vga_r,    //VGA Red
  output vga_g,    //VGA Green
  output vga_b,    //VGA Blue
  output vga_hs,   //H-sync pulse
  output vga_vs,   //V-sync pulse

  input sclk,
  input vsync,
  input cs,
  input mosi,
);

parameter addr_width = 13; //64 x 64 = 4,096 RGBI pixels
parameter data_width = 4;
reg [data_width-1:0] mem [(1<<addr_width)-1:0];

wire [data_width-1:0] dout;
reg  [addr_width-1:0] raddr;
assign dout = mem[raddr];

reg [data_width-1:0] din;
reg [addr_width-1:0] waddr;
reg  [1:0] din_counter;
reg  [4:0] waddr_counter;
reg [11:0] quadrant_counter;

always @(posedge sclk)
begin
  if (!vsync && cs) begin //VSYNC
    waddr <= 0;
    din_counter <= 0;
    waddr_counter <= 0;
    quadrant_counter <= 1;
  end
  else if (vsync && !cs) begin
    din[din_counter] <= mosi;
    din_counter <= din_counter + 1;
    if (din_counter == 2'b11) begin //latch data
      mem[waddr] <= din;
      //manage screen address 'quadrants'!
      waddr_counter <= waddr_counter + 1;
      quadrant_counter <= quadrant_counter + 1;
      if (quadrant_counter == 1024) begin
        waddr <= 32;
      end
      else if (quadrant_counter == 2048) begin
        waddr <= 2048;
      end
      else if (quadrant_counter == 3072) begin
        waddr <= 2080;
      end
      else if (waddr_counter == 5'b11111) begin
        waddr <= waddr + 33;
      end
      else begin
        waddr <= waddr + 1;
      end
    end
  end
end

parameter h_pulse  = 8;   //H-SYNC pulse width
parameter h_bp     = 20;  //H-BP back porch pulse width
parameter h_pixels = 200; //H-PIX Number of pixels horizontally
parameter h_fp     = 12;  //H-FP front porch pulse width
parameter h_frame  = 240; //240 = 8 (H-SYNC) + 20 (H-BP) + 200 (H-PIX) + 12 (H-FP)
parameter v_pulse  = 4;   //V-SYNC pulse width
parameter v_bp     = 29;  //V-BP back porch pulse width
parameter v_pixels = 600; //V-PIX Number of pixels vertically
parameter v_fp     = 3;   //V-FP front porch pulse width
parameter v_frame  = 636; //636 = 4 (V-SYNC) + 29 (V-BP) + 600 (V-PIX) + 3 (V-FP)

reg flop1, flop2; //from comp.lang.verilog
always @ (posedge CLK25MHz) flop1 <= !(flop1 | flop2);
always @ (negedge CLK25MHz) flop2 <= !(flop1 | flop2);

wire vga_clk;
assign vga_clk = !(flop1 | flop2); //16.666666667MHz (1.5x)

wire [6:0] c_col;     //visible frame register column
wire [6:0] c_row;     //visible frame register row
reg  [7:0] c_hor;     //complete frame register horizontally
reg  [9:0] c_ver;     //complete frame register vertically
wire       disp_en;   //display enable flag
reg        intensity; //RGBI intensity

assign vga_hs = (c_hor < h_pixels + h_fp || c_hor >= h_pixels + h_fp + h_pulse) ? 1 : 0; //H-SYNC generator
assign vga_vs = (c_ver < v_pixels + v_fp || c_ver >= v_pixels + v_fp + v_pulse) ? 1 : 0; //V-SYNC generator

assign disp_en = (c_hor >= 32 && c_hor < 160 && c_ver >= 48 && c_ver < 560) ? 1 : 0;

//c_col and c_row counters are updated only in the visible time-frame
assign c_col = (disp_en) ? ((c_hor - 30) >> 1) - 1 : 64;
assign c_row = (disp_en) ? ((c_ver - 40) >> 3) - 1 : 63;

//VGA colour signals are enabled only in the visible time frame
assign vga_r = (((dout[3] && dout[0]) || (dout[3] && !dout[0] && intensity)) && disp_en) ? 1 : 0;
assign vga_g = (((dout[2] && dout[0]) || (dout[2] && !dout[0] && intensity)) && disp_en) ? 1 : 0;
assign vga_b = (((dout[1] && dout[0]) || (dout[1] && !dout[0] && intensity)) && disp_en) ? 1 : 0;

always @ (posedge CLK25MHz) begin
  raddr = (c_row * 64) + c_col;
end

always @ (posedge vga_clk) begin
  //update current beam position
  if (c_hor < h_frame) begin
    c_hor <= c_hor + 1;
  end
  else begin
    c_hor <= 0;
    if (c_ver < v_frame) begin
      c_ver <= c_ver + 1;
    end
    else begin
      c_ver <= 0;
      intensity <= intensity + 1;
    end
  end
end

endmodule

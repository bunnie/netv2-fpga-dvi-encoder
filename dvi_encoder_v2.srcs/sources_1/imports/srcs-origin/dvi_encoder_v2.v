//////////////////////////////////////////////////////////////////////////////
//
//  Alphamax LLC NeTV2 dvi encoder for Artix FPGAs
//  GPLv3 / 2016
//
//////////////////////////////////////////////////////////////////////////////
//
//  Inspried by Spartan-6 code from a Xilinx XAPP by Bob Feng, but modified beyond recognition...
//
//////////////////////////////////////////////////////////////////////////////

/*
    This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation, either version 3 of the License, or
     (at your option) any later version.
 
     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.
 
     You should have received a copy of the GNU General Public License
     along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 
     Copyright 2016 Andrew 'bunnie' Huang, all rights reserved 
 */

`timescale 1 ns / 1ps

module dvi_encoder (
  input wire 	    p_clk, // pixel clock
  input wire 	    px5_clk, // pixel clock x2
  input wire 	    reset, // reset
  input wire [7:0]  blue_din, // Blue data in
  input wire [7:0]  green_din, // Green data in
  input wire [7:0]  red_din, // Red data in
  input wire 	    hsync, // hsync data
  input wire 	    vsync, // vsync data
  input wire 	    de, // data enable
  output wire 	    TMDS_0_P,
  output wire 	    TMDS_0_N,
  output wire 	    TMDS_1_P,
  output wire 	    TMDS_1_N,
  output wire 	    TMDS_2_P,
  output wire 	    TMDS_2_N,
  output wire 	    TMDS_CLK_P,
  output wire 	    TMDS_CLK_N,
  input wire 	    vid_gb,
  input wire 	    dat_gb,
  input wire 	    dat_ena,
  input wire [3:0]  blue_di,
  input wire [3:0]  green_di,
  input wire [3:0]  red_di,
  input wire [3:0]  ctl_code,
  input wire [29:0] bypass_sdata,
  input wire 	    bypass_ena,
  input wire 	    bypass_video_only
);
    
  wire 	[9:0]	red ;
  wire 	[9:0]	green ;
  wire 	[9:0]	blue ;

   wire [9:0] 	red_t4 ;
   wire [9:0] 	green_t4 ;
   wire [9:0] 	blue_t4 ;

  wire [4:0] tmds_data0, tmds_data1, tmds_data2;
  wire [2:0] tmdsint;

   wire [29:0] s_data;
   
   wire      tmds_out_0;
   wire      tmds_out_1;
   wire      tmds_out_2;
   wire      tmds_out_clk;

   wire      vid_pa;
   wire      dat_pa;

   wire [9:0] dat_din;
   
   assign vid_pa = (ctl_code[3:0] == 4'b0001);
   assign dat_pa = (ctl_code[3:0] == 4'b0101);

   assign dat_din = {blue_di[1:0],red_di[3:0],green_di[3:0]};
      
   serialiser_10_to_1 ser_ch0(
			      .clk(p_clk),
			      .clk_x5(px5_clk),
			      .reset(reset),
			      .data(s_data[9:0]),
			      .serial(tmds_out_0)
			      );
   
   serialiser_10_to_1 ser_ch1(
			      .clk(p_clk),
			      .clk_x5(px5_clk),
			      .reset(reset),
			      .data(s_data[19:10]),
			      .serial(tmds_out_1)
			      );
   
   serialiser_10_to_1 ser_ch2(
			      .clk(p_clk),
			      .clk_x5(px5_clk),
			      .reset(reset),
			      .data(s_data[29:20]),
			      .serial(tmds_out_2)
			      );
   
   serialiser_10_to_1 ser_clk(
			      .clk(p_clk),
			      .clk_x5(px5_clk),
			      .reset(reset),
			      .data(10'b0000011111),
			      .serial(tmds_out_clk)
			      );

  OBUFDS TMDS0 (.I(tmds_out_0), .O(TMDS_0_P), .OB(TMDS_0_N)) ;
  OBUFDS TMDS1 (.I(tmds_out_1), .O(TMDS_1_P), .OB(TMDS_1_N)) ;
  OBUFDS TMDS2 (.I(tmds_out_2), .O(TMDS_2_P), .OB(TMDS_2_N)) ;
  OBUFDS TMDS3 (.I(tmds_out_clk), .O(TMDS_CLK_P), .OB(TMDS_CLK_N)) ; // clock

  encodeb encb (
    .clkin	(p_clk),
    .rstin	(reset),
    .din		(blue_din),
    .c0			(hsync),
    .c1			(vsync),
    .de			(de),
    .dout		(blue),
    .vid_gb             (vid_gb)) ;

  encodeg encg (
    .clkin	(p_clk),
    .rstin	(reset),
    .din		(green_din),
    .c0			(ctl_code[0]), // bit 0
    .c1			(ctl_code[1]), // bit 1
    .de			(de),
    .dout		(green),
    .vid_gb             (vid_gb)) ;
    
  encoder encr (
    .clkin	(p_clk),
    .rstin	(reset),
    .din		(red_din),
    .c0			(ctl_code[2]), // bit 2
    .c1			(ctl_code[3]), // bit 3
    .de			(de),
    .dout		(red),
    .vid_gb             (vid_gb)) ;

encode_terc4 engb_t4
  (     .clkin    (p_clk),
	.rstin    (reset),
	.din      ( {dat_din[9] | dat_gb, dat_din[8] | dat_gb, vsync, hsync} ),
	.dout     (blue_t4),
	.dat_gb   (1'b0)  // gb is considered with sync
   );
  
encode_terc4 encg_t4 
  (     .clkin    (p_clk),
	.rstin    (reset),
	.din      (dat_din[3:0]),
	.dout     (green_t4),
	.dat_gb   (dat_gb)
   );

encode_terc4 encr_t4 
  (     .clkin    (p_clk),
	.rstin    (reset),
	.din      (dat_din[7:4]),
	.dout     (red_t4),
	.dat_gb   (dat_gb)
   );
   
   // pipe alignment
   reg 		dat_ena_q, dat_ena_reg, dat_ena_r2;
   reg          dat_gb_q, dat_gb_reg, dat_gb_r2;
   
   always @(posedge p_clk) begin
	 dat_ena_q <= dat_ena;
	 dat_ena_reg <= dat_ena_q;
	 dat_ena_r2 <= dat_ena_reg;
	 
	 dat_gb_q <= dat_gb;
	 dat_gb_reg <= dat_gb_q;
	 dat_gb_r2 <= dat_gb_reg;
   end

   // insert four pipe stages to s_data override
   reg [29:0] byp_sd1;
   reg [29:0] byp_sd2;
   reg [29:0] byp_sd3;
   reg [29:0] byp_sd4;
   reg [29:0] byp_sd5;
   reg [4:0]  bypass_q;
   always @(posedge p_clk) begin
      byp_sd1 <= bypass_sdata;
      byp_sd2 <= byp_sd1;
      byp_sd3 <= byp_sd2;
      byp_sd4 <= byp_sd3;
      byp_sd5 <= byp_sd4;

      bypass_q[4] <= bypass_q[3];
      bypass_q[3] <= bypass_q[2];
      bypass_q[2] <= bypass_q[1];
      bypass_q[1] <= bypass_q[0];
      bypass_q[0] <= bypass_ena || (bypass_video_only & !de);
   end // always @ (posedge p_clk)

   assign s_data = bypass_q[4] ? byp_sd5 : {red, green, blue};
   
endmodule

/*
 TCL script to update IP ports
 
 ipx::remove_all_port [ipx::current_core]
ipx::add_ports_from_hdl [ipx::current_core] -top_level_hdl_file F:/largework/fpga/netv2/dvi_encoder_v2/dvi_encoder_v2.srcs/sources_1/imports/srcs-origin/dvi_encoder_v2.v -top_module_name dvi_encoder
ipx::add_port_map RST [ipx::get_bus_interfaces rstin -of_objects [ipx::current_core]]
set_property physical_name reset [ipx::get_port_maps RST -of_objects [ipx::get_bus_interfaces rstin -of_objects [ipx::current_core]]]
ipx::add_port_map CLK [ipx::get_bus_interfaces p_clk -of_objects [ipx::current_core]]
set_property physical_name p_clk [ipx::get_port_maps CLK -of_objects [ipx::get_bus_interfaces p_clk -of_objects [ipx::current_core]]]
ipx::add_port_map CLK [ipx::get_bus_interfaces px5_clk -of_objects [ipx::current_core]]
set_property physical_name px5_clk [ipx::get_port_maps CLK -of_objects [ipx::get_bus_interfaces px5_clk -of_objects [ipx::current_core]]]
 */

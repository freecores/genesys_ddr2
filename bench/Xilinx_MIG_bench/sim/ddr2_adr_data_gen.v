//*****************************************************************************
// DISCLAIMER OF LIABILITY
//
// This file contains proprietary and confidential information of
// Xilinx, Inc. ("Xilinx"), that is distributed under a license
// from Xilinx, and may be used, copied and/or disclosed only
// pursuant to the terms of a valid license agreement with Xilinx.
//
// XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION
// ("MATERIALS") "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
// EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT
// LIMITATION, ANY WARRANTY WITH RESPECT TO NONINFRINGEMENT,
// MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx
// does not warrant that functions included in the Materials will
// meet the requirements of Licensee, or that the operation of the
// Materials will be uninterrupted or error-free, or that defects
// in the Materials will be corrected. Furthermore, Xilinx does
// not warrant or make any representations regarding use, or the
// results of the use, of the Materials in terms of correctness,
// accuracy, reliability or otherwise.
//
// Xilinx products are not designed or intended to be fail-safe,
// or for use in any application requiring fail-safe performance,
// such as life-support or safety devices or systems, Class III
// medical devices, nuclear facilities, applications related to
// the deployment of airbags, or any other applications that could
// lead to death, personal injury or severe property or
// environmental damage (individually and collectively, "critical
// applications"). Customer assumes the sole risk and liability
// of any use of Xilinx products in critical applications,
// subject only to applicable laws and regulations governing
// limitations on product liability.
//
// Copyright 2006, 2007 Xilinx, Inc.
// All rights reserved.
//
// This disclaimer and copyright notice must be retained as part
// of this file at all times.
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: 3.6.1
//  \   \         Application: MIG
//  /   /         Filename: ddr2_tb_test_gen.v
// /___/   /\     Date Last Modified: $Date: 2010/11/26 18:26:02 $
// \   \  /  \    Date Created: Fri Sep 01 2006
//  \___\/\___\
//
//Device: Virtex-5
//Design Name: DDR2
//Purpose:
//   This module instantiates the addr_gen and the data_gen modules. It takes
//   the user data stored in internal FIFOs and gives the data that is to be
//   compared with the read data
//Reference:
//Revision History:
//*****************************************************************************

`timescale 1ns/1ps

module ddr2_adr_data_gen #
  (
   // Following parameters are for 72-bit RDIMM design (for ML561 Reference 
   // board design). Actual values may be different. Actual parameters values 
   // are passed from design top module MEMCtrl module. Please refer to
   // the MEMCtrl module for actual values.
   parameter BANK_WIDTH    = 2,
   parameter COL_WIDTH     = 10,
   parameter DM_WIDTH      = 9,
   parameter DQ_WIDTH      = 72,
   parameter APPDATA_WIDTH = 144,
   parameter ECC_ENABLE    = 0,
   parameter ROW_WIDTH     = 14
   )
  (
   input                                  clk,
   input                                  rst,
   input                                  wr_addr_en,
   input                                  wr_data_en,
	input 											rd_op,
   input                                  rd_data_valid,
	input  [30:0]									bus_if_addr,
   input  [APPDATA_WIDTH-1:0]             bus_if_wr_data,
   input  [(APPDATA_WIDTH/8)-1:0]         bus_if_wr_mask_data,
   output reg                             app_af_wren,
   output [2:0]                           app_af_cmd,
   output [30:0]                          app_af_addr,
   output                                 app_wdf_wren,
   output [APPDATA_WIDTH-1:0]             app_wdf_data,
   output [(APPDATA_WIDTH/8)-1:0]         app_wdf_mask_data//,
   //output [APPDATA_WIDTH-1:0]             app_cmp_data
   );
  
  //data
  localparam RD_IDLE_FIRST_DATA = 2'b00;
  localparam RD_SECOND_DATA     = 2'b01;
  localparam RD_THIRD_DATA      = 2'b10;
  localparam RD_FOURTH_DATA     = 2'b11;
  
  //address
  reg             wr_addr_en_r1;
  reg [2:0]       af_cmd_r;//, af_cmd_r0, af_cmd_r1;
  reg             af_wren_r;
  reg             rst_r
                  /* synthesis syn_preserve = 1 */;
  reg             rst_r1
                  /* synthesis syn_maxfan = 10 */;
  reg [5:0]       wr_addr_r;//wr_addr_cnt;
  reg             wr_addr_en_r0;
  
  //data
  reg [APPDATA_WIDTH-1:0]              app_wdf_data_r;
  reg [(APPDATA_WIDTH/8)-1:0]          app_wdf_mask_data_r;
  wire                                 app_wdf_wren_r;
  reg [(APPDATA_WIDTH/2)-1:0]          rd_data_pat_fall;
  reg [(APPDATA_WIDTH/2)-1:0]          rd_data_pat_rise;
  //wire                                 rd_data_valid_r;
  reg [1:0]                            rd_state;
  wire [APPDATA_WIDTH-1:0]             wr_data;
  reg                                  wr_data_en_r;
  reg [(APPDATA_WIDTH/2)-1:0]          wr_data_fall
                                       /* synthesis syn_maxfan = 2 */;
  reg [(APPDATA_WIDTH/2)-1:0]          wr_data_rise
                                        /* synthesis syn_maxfan = 2 */;
  wire [(APPDATA_WIDTH/8)-1:0]         wr_mask_data;

  //***************************************************************************
	
  // local reset "tree" for controller logic only. Create this to ease timing
  // on reset path. Prohibit equivalent register removal on RST_R to prevent
  // "sharing" with other local reset trees (caution: make sure global fanout
  // limit is set to larger than fanout on RST_R, otherwise SLICES will be
  // used for fanout control on RST_R.
  always @(posedge clk) begin
    rst_r  <= rst;
    rst_r1 <= rst_r;
  end
// register backend enables / FIFO enables
  // write enable for Command/Address FIFO is generated 1 CC after WR_ADDR_EN
  always @(posedge clk)
    if (rst_r1) begin
      app_af_wren   <= 1'b0;
    end else begin
      app_af_wren   <= wr_addr_en;
    end

  always @ (posedge clk)
    if (rst_r1)
      wr_addr_r <= 0;
    else if (wr_addr_en && (rd_op == 1'b0))
      wr_addr_r <= bus_if_addr;  

	assign app_af_addr = wr_addr_r;
	assign app_af_cmd = af_cmd_r;
	
	always @ (posedge clk)
	begin
		af_cmd_r  <= 0;
		if (rd_op)
			af_cmd_r <= 3'b001;
	end
  
//  ddr2_tb_test_addr_gen #
//    (
//     .BANK_WIDTH (BANK_WIDTH),
//     .COL_WIDTH  (COL_WIDTH),
//     .ROW_WIDTH  (ROW_WIDTH)
//     )
//    u_addr_gen
//      (
//       .clk         (clk),
//       .rst         (rst),
//       .wr_addr_en  (wr_addr_en),
//		 .rd_op	     (rd_op),
//		 .bus_if_addr (bus_if_addr),
//       .app_af_cmd  (app_af_cmd),
//       .app_af_addr (app_af_addr),
//       .app_af_wren (app_af_wren)
//       );

	//data
  assign app_wdf_data        = wr_data;
  assign app_wdf_mask_data   = wr_mask_data;
  // inst ff for timing
  FDRSE ff_wdf_wren
    (
     .Q   (app_wdf_wren),
     .C   (clk),
     .CE  (1'b1),
     .D   (wr_data_en), //wr_data_en_r
     .R   (1'b0),
     .S   (1'b0)
     );
//	 FDRSE ff_rd_data_valid_r
//    (
//     .Q   (rd_data_valid_r),
//     .C   (clk),
//     .CE  (1'b1),
//     .D   (rd_data_valid),
//     .R   (1'b0),
//     .S   (1'b0)
//     );
	  
  assign wr_data      = {wr_data_fall, wr_data_rise};
  assign wr_mask_data = bus_if_wr_mask_data;
  
  //data latching
  //synthesis attribute max_fanout of wr_data_fall is 2
  //synthesis attribute max_fanout of wr_data_rise is 2
  always @(posedge clk) 
  begin
    if (rst_r1) 
		 begin
			wr_data_rise <= {(APPDATA_WIDTH/2){1'bx}};
			wr_data_fall <= {(APPDATA_WIDTH/2){1'bx}};
		 end 
	 else 
		 if (wr_data_en) 
		 begin
			wr_data_rise <= bus_if_wr_data[(APPDATA_WIDTH/2)-1:0]; 
			wr_data_fall <= bus_if_wr_data[APPDATA_WIDTH-1:(APPDATA_WIDTH/2)];
		 end
	end
	
	//BO: needs to be commented out in the future
	  //*****************************************************************
  // Read data logic
  //*****************************************************************
//
//  // read comparison data generation
//  always @(posedge clk)
//    if (rst_r1) begin
//      rd_data_pat_rise <= {(APPDATA_WIDTH/2){1'bx}};
//      rd_data_pat_fall <= {(APPDATA_WIDTH/2){1'bx}};
//      rd_state <= RD_IDLE_FIRST_DATA;
//    end else begin
//      case (rd_state)
//        RD_IDLE_FIRST_DATA:
//          if (rd_data_valid_r)
//            begin
//              rd_data_pat_rise <= {(APPDATA_WIDTH/2){1'b1}}; // 0xF
//              rd_data_pat_fall <= {(APPDATA_WIDTH/2){1'b0}}; // 0x0
//              rd_state <= RD_SECOND_DATA;
//            end
//        RD_SECOND_DATA:
//          if (rd_data_valid_r) begin
//            rd_data_pat_rise <= {(APPDATA_WIDTH/4){2'b10}};  // 0xA
//            rd_data_pat_fall <= {(APPDATA_WIDTH/4){2'b01}};  // 0x5
//            rd_state <= RD_THIRD_DATA;
//          end
//        RD_THIRD_DATA:
//          if (rd_data_valid_r) begin
//            rd_data_pat_rise <= {(APPDATA_WIDTH/4){2'b01}};  // 0x5
//            rd_data_pat_fall <= {(APPDATA_WIDTH/4){2'b10}};  // 0xA
//            rd_state <= RD_FOURTH_DATA;
//          end
//        RD_FOURTH_DATA:
//          if (rd_data_valid_r) begin
//            rd_data_pat_rise <= {(APPDATA_WIDTH/8){4'b1001}}; // 0x9
//            rd_data_pat_fall <= {(APPDATA_WIDTH/8){4'b0110}}; // 0x6
//            rd_state <= RD_IDLE_FIRST_DATA;
//          end
//      endcase
//    end
//
//  //data to the compare circuit during read
//  assign app_cmp_data = {rd_data_pat_fall, rd_data_pat_rise};




endmodule

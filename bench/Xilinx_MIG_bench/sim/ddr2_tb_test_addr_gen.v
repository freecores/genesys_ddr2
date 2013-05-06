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
// Copyright 2006, 2007, 2008 Xilinx, Inc.
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
//  /   /         Filename: ddr2_tb_test_addr_gen.v
// /___/   /\     Date Last Modified: $Date: 2010/11/26 18:26:02 $
// \   \  /  \    Date Created: Fri Sep 01 2006
//  \___\/\___\
//
//Device: Virtex-5
//Design Name: DDR2
//Purpose:
//   The address for the memory and the various user commands can be given
//   through this module. It instantiates the block RAM which stores all the
//   information in particular sequence. The data stored should be in a
//   sequence starting from LSB:
//      column address, row address, bank address, commands.
//Reference:
//Revision History:
//*****************************************************************************

`timescale 1ns/1ps

module ddr2_tb_test_addr_gen #
  (
   // Following parameters are for 72-bit RDIMM design (for ML561 Reference
   // board design). Actual values may be different. Actual parameters values
   // are passed from design top module MEMCtrl module. Please refer to
   // the MEMCtrl module for actual values.
   parameter BANK_WIDTH = 2,
   parameter COL_WIDTH  = 10,
   parameter ROW_WIDTH  = 14
   )
  (
   input             clk,
   input             rst,
   input             wr_addr_en,
	input 			   rd_op,
   input	  [30:0]		bus_if_addr,
	output  [2:0]  	app_af_cmd,
   output  [30:0] 	app_af_addr,
   output reg        app_af_wren
   );

  reg             wr_addr_en_r1;
  reg [2:0]       af_cmd_r;//, af_cmd_r0, af_cmd_r1;
  reg             af_wren_r;
  reg             rst_r
                  /* synthesis syn_preserve = 1 */;
  reg             rst_r1
                  /* synthesis syn_maxfan = 10 */;
  reg [5:0]       wr_addr_r;//wr_addr_cnt;
  reg             wr_addr_en_r0;

  // XST attributes for local reset "tree"
  // synthesis attribute shreg_extract of rst_r is "no";
  // synthesis attribute shreg_extract of rst_r1 is "no";
  // synthesis attribute equivalent_register_removal of rst_r is "no"

  //*****************************************************************

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

endmodule

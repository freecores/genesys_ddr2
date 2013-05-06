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
//  /   /         Filename: ddr2_tb_top.v
// /___/   /\     Date Last Modified: $Date: 2010/11/26 18:26:02 $
// \   \  /  \    Date Created: Fri Sep 01 2006
//  \___\/\___\
//
//Device: Virtex-5
//Design Name: DDR2
//Purpose:
//   This module is the synthesizable test bench for the memory interface.
//   This Test bench is to compare the write and the read data and generate
//   an error flag.
//Reference:
//Revision History:
//*****************************************************************************

`timescale 1ns/1ps

module ddr2_user_if_top #
  (
   // Following parameters are for 72-bit RDIMM design (for ML561 Reference 
   // board design). Actual values may be different. Actual parameters values 
   // are passed from design top module MEMCtrl module. Please refer to
   // the MEMCtrl module for actual values.
   parameter BANK_WIDTH    = 2,
   parameter COL_WIDTH     = 10,
   parameter DM_WIDTH      = 9,
   parameter DQ_WIDTH      = 72,
   parameter ROW_WIDTH     = 14,
   parameter APPDATA_WIDTH = 144,
   parameter ECC_ENABLE    = 0,
   parameter BURST_LEN     = 4
   )
  (
   input                                  clk0,
   input                                  rst0,
   input                                  app_af_afull,
   input                                  app_wdf_afull,
   input                                  rd_data_valid,
   input [APPDATA_WIDTH-1:0]              rd_data_fifo_out,
   input                                  phy_init_done,
	input												rd_cmd,
	input												wr_cmd,
	input  [30:0]									bus_if_addr,
	input  [APPDATA_WIDTH-1:0]             bus_if_wr_data,
   input  [(APPDATA_WIDTH/8)-1:0]         bus_if_wr_mask_data,
	output 											end_op,
	output											req_wd,
   output                                 app_af_wren,
   output [2:0]                           app_af_cmd,
   output [30:0]                          app_af_addr,
   output                                 app_wdf_wren,
   output [APPDATA_WIDTH-1:0]             app_wdf_data,
   output [(APPDATA_WIDTH/8)-1:0]         app_wdf_mask_data,
   output                                 error,
   output                                 error_cmp
   );

  localparam BURST_LEN_DIV2 = BURST_LEN/2;

  localparam IDLE_CMD  = 3'b000;
  localparam WRITE_CMD = 3'b001;
  localparam READ_CMD  = 3'b010;

  reg                      app_af_not_afull_r;
  wire [APPDATA_WIDTH-1:0] app_cmp_data;
  reg                      app_wdf_not_afull_r ;
  reg [2:0]                burst_cnt;
  reg                      phy_init_done_tb_r;
  wire                     phy_init_done_r;
  reg                      rst_r
                           /* synthesis syn_preserve = 1 */;
  reg                      rst_r1
                           /* synthesis syn_maxfan = 10 */;
  reg [2:0]                state;
  reg [3:0]                state_cnt;
  reg                      wr_addr_en ;
  reg                      wr_data_en ;
  reg 							rd_op;
  reg  			   			end_op_r;

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
  always @(posedge clk0) begin
    rst_r  <= rst0;
    rst_r1 <= rst_r;
  end

  // Instantiate flops for timing.
    FDRSE ff_phy_init_done
    (
     .Q   (phy_init_done_r),
     .C   (clk0),
     .CE  (1'b1),
     .D   (phy_init_done),
     .R   (1'b0),
     .S   (1'b0)
     );

	assign end_op = end_op_r;
  //***************************************************************************
  // State Machine for writing to WRITE DATA & ADDRESS FIFOs
  // state machine changed for low FIFO threshold values
  //***************************************************************************

  always @(posedge clk0) begin
    if (rst_r1) begin
      wr_data_en          <= 1'bx;
      wr_addr_en          <= 1'bx;
      state[2:0]          <= IDLE_CMD;
      state_cnt           <= 4'bxxxx;
      app_af_not_afull_r  <= 1'bx;
      app_wdf_not_afull_r <= 1'bx;
      burst_cnt           <= 3'bxxx;
      phy_init_done_tb_r  <= 1'bx;
		rd_op <= 1'bx;
		end_op_r <= 1'bx;
    end else begin
      wr_data_en          <= 1'b0;
      wr_addr_en          <= 1'b0;
		rd_op 				  <= 1'b0;
		end_op_r 			  <= 1'b0;
      app_af_not_afull_r  <= ~app_af_afull;
      app_wdf_not_afull_r <= ~app_wdf_afull;
      phy_init_done_tb_r  <= phy_init_done_r;

      case (state)
        IDLE_CMD: begin
          state_cnt  <= 4'd0;
          burst_cnt  <= BURST_LEN_DIV2 - 1;
          // only start writing when initialization done
          if (app_wdf_not_afull_r && app_af_not_afull_r && phy_init_done_tb_r) 
				 begin
					if (rd_cmd)
						state <= READ_CMD;
					if (wr_cmd)
						state <= WRITE_CMD;
				 end
        end

        WRITE_CMD:
          if (app_wdf_not_afull_r && app_af_not_afull_r) 
			 begin
            wr_data_en <= 1'b1;
            // When we're done with the current burst...
            if (burst_cnt == 3'd0) 
					begin
					  wr_addr_en <= 1'b1;
					  state      <= IDLE_CMD;
					  end_op_r   <= 1'b1;
					end 
				else
              burst_cnt <= burst_cnt - 1;
          end

        READ_CMD: begin
          burst_cnt <= BURST_LEN_DIV2 - 1;
          if (app_af_not_afull_r) 
				 begin
					wr_addr_en <= 1'b1;
					rd_op <= 1'b1;
					state <= IDLE_CMD;
					end_op_r <= 1'b1;
				 end
          end
      endcase
    end
  end
  assign req_wd = (!wr_addr_en && wr_data_en)? 1'b1:1'b0; 

  // Command/Address and Write Data generation
  ddr2_tb_test_gen #
    (
     .BANK_WIDTH    (BANK_WIDTH),
     .COL_WIDTH     (COL_WIDTH),
     .DM_WIDTH      (DM_WIDTH),
     .DQ_WIDTH      (DQ_WIDTH),
     .APPDATA_WIDTH (APPDATA_WIDTH),
     .ECC_ENABLE    (ECC_ENABLE),
     .ROW_WIDTH     (ROW_WIDTH)
     )
    u_tb_test_gen
      (
       .clk               (clk0),
       .rst               (rst0),
       .wr_addr_en        (wr_addr_en),
       .wr_data_en        (wr_data_en),
		 .rd_op 				  (rd_op),
       .rd_data_valid     (rd_data_valid),
		 .bus_if_addr		  (bus_if_addr),
       .app_af_wren       (app_af_wren),
		 .bus_if_wr_mask_data(bus_if_wr_mask_data),
		 .bus_if_wr_data    (bus_if_wr_data),
       .app_af_cmd        (app_af_cmd),
       .app_af_addr       (app_af_addr),
       .app_wdf_wren      (app_wdf_wren),
       .app_wdf_data      (app_wdf_data),
       .app_wdf_mask_data (app_wdf_mask_data)//,
       //.app_cmp_data      (app_cmp_data)
       );

endmodule

// This file is part of LitePCIe.
//
// Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module s_axis_rq_adapt # (
      parameter DATA_WIDTH  = 128,
      parameter KEEP_WIDTH  = DATA_WIDTH/8
    )(

       input user_clk,
       input user_reset,

       output [DATA_WIDTH-1:0] s_axis_rq_tdata,
       output [KEEP_WIDTH-1:0] s_axis_rq_tkeep,
       output                  s_axis_rq_tlast,
       input             [3:0] s_axis_rq_tready,
       output            [3:0] s_axis_rq_tuser,
       output                  s_axis_rq_tvalid,

       input   [DATA_WIDTH-1:0] s_axis_rq_tdata_a,
       input   [KEEP_WIDTH-1:0] s_axis_rq_tkeep_a,
       input                    s_axis_rq_tlast_a,
       output             [3:0] s_axis_rq_tready_a,
       input              [3:0] s_axis_rq_tuser_a,
       input                    s_axis_rq_tvalid_ag
    );

  reg s_axis_rq_first;
  always @(posedge user_clk)
      if (user_reset)
        s_axis_rq_first <= 2'd1;
      else if (s_axis_rq_tvalid && s_axis_rq_tready)
          begin
              if (s_axis_rq_tlast)
                s_axis_rq_first <= 2'd1
          end

  wire  s_axis_rq_tlast_a = s_axis_rq_tlast;
  assign s_axis_rq_tready = s_axis_rq_tready_a[0];
  wire s_axis_rq_tvalid_a = s_axis_rq_tvalid;

  wire [10:0] s_axis_rq_dwlen = {1'b0, s_axis_rq_tdata[9:0]};
  wire [3:0]  s_axis_rq_reqtype =
    {s_axis_rq_tdata[31:30], s_axis_rq_tdata[28:24]} == 7'b0000000  ? 4'b0000 :  //Mem read Request
    {s_axis_rq_tdata[31:30], s_axis_rq_tdata[28:24]} == 7'b0000001  ? 4'b0111 :  //Mem Read request-locked
    {s_axis_rq_tdata[31:30], s_axis_rq_tdata[28:24]} == 7'b0100000  ? 4'b0001 :  //Mem write request
                             s_axis_rq_tdata[31:24]  == 8'b00000010 ? 4'b0010 :  //I/O Read request
                             s_axis_rq_tdata[31:24]  == 8'b01000010 ? 4'b0011 :  //I/O Write request
                             s_axis_rq_tdata[31:24]  == 8'b00000100 ? 4'b1000 :  //Cfg Read Type 0
                             s_axis_rq_tdata[31:24]  == 8'b01000100 ? 4'b1010 :  //Cfg Write Type 0
                             s_axis_rq_tdata[31:24]  == 8'b00000101 ? 4'b1001 :  //Cfg Read Type 1
                             s_axis_rq_tdata[31:24]  == 8'b01000101 ? 4'b1011 :  //Cfg Write Type 1
                             4'b1111;
  wire            s_axis_rq_poisoning    = s_axis_rq_tdata[14] | s_axis_rq_tuser[1];   //EP must be 0 for request
  wire [15:0]     s_axis_rq_requesterid  = s_axis_rq_tdata[63:48];
  wire [7:0]      s_axis_rq_tag          = s_axis_rq_tdata[47:40];
  wire [15:0]     s_axis_rq_completerid  = 16'b0; // Applicable only to Configuration requests and messages routed by ID.
  wire            s_axis_rq_requester_en = 1'b0;  // Must be 0 for Endpoint.
  wire [2:0]      s_axis_rq_tc           = s_axis_rq_tdata[22:20];
  wire [2:0]      s_axis_rq_attr         = {1'b0, s_axis_rq_tdata[13:12]};
  wire            s_axis_rq_ecrc         = s_axis_rq_tdata[15] | s_axis_rq_tuser[0];     //TLP Digest

  wire [63:0]     s_axis_rq_tdata_header  = {
    s_axis_rq_ecrc,
    s_axis_rq_attr,
    s_axis_rq_tc,
    s_axis_rq_requester_en,
    s_axis_rq_completerid,
    s_axis_rq_tag,
    s_axis_rq_requesterid,
    s_axis_rq_poisoning, s_axis_rq_reqtype, s_axis_rq_dwlen
  };

  wire [3:0] s_axis_rq_firstbe = s_axis_rq_tdata[35:32];
  wire [3:0] s_axis_rq_lastbe  = s_axis_rq_tdata[39:36];

  wire [127:0]    s_axis_rq_tdata_a  = s_axis_rq_first ? {s_axis_rq_tdata_header, s_axis_rq_tdata_ff[127:64]} : s_axis_rq_tdata;
  wire [3:0]      s_axis_rq_tkeep_a  = s_axis_rq_tkeep;
  wire [59:0]     s_axis_rq_tuser_a;
  assign          s_axis_rq_tuser_a[59:8] = {32'b0, 4'b0, 1'b0, 8'b0, 2'b0, 1'b0, s_axis_rq_tuser[3], 3'b0};
  assign          s_axis_rq_tuser_a[7:0]  = {s_axis_rq_lastbe, s_axis_rq_firstbe};

endmodule
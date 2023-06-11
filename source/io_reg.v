// This file is auto-generated. Do not edit

module io_reg
  (input wire clock,
   input wire reset,

   /* ---- Access bus ---- */
   /* verilator lint_off UNUSED */
   input wire [31:0] i_addr,
   input wire [31:0] i_data,
   output wire [31:0] o_data,
   input wire [3:0] i_ben,
   input wire i_write,
   input wire i_read,
   /* verilator lint_on UNUSED */

   /* ---- 'ctrl' ---- */
   output wire o_ctrl_stop,

   /* ---- 'console' ---- */
   output wire o_console__rnotify,
   input wire [7:0] i_console_data,
   output wire [7:0] o_console_data,
   output wire o_console_send_hsreq,
   input wire i_console_send_hsack,
   input wire i_console_send,
   input wire i_console_valid);

  /* ---- Address decoder ---- */
  wire ctrl_select;
  wire console_select;

  assign ctrl_select =
    i_addr[2] == 1'b0;

  assign console_select =
    i_addr[2] == 1'b1;


  /* ---- 'ctrl' ---- */
  reg ctrl_stop;
  assign o_ctrl_stop = ctrl_stop;

  always @(posedge clock)
    if (reset)
      ctrl_stop <= 1'b0;
    else
      if (ctrl_select && i_write) begin
        if (i_ben[0]) ctrl_stop <= i_data[0];
      end


  /* ---- 'console' ---- */
  reg [7:0] console_data;
  assign o_console_data = console_data;

  always @(posedge clock)
    if (reset)
      console_data <= 8'b0;
    else
      if (console_select && i_write) begin
        if (i_ben[0]) console_data[7:0] <= i_data[7:0];
      end

  reg console_send_hsreq;
  assign o_console_send_hsreq = console_send_hsreq;

  always @(posedge clock)
    if (reset)
      console_send_hsreq <= 1'b0;
    else begin
      if (console_select && i_write && i_ben[1]) console_send_hsreq <= i_data[8];
      else console_send_hsreq <= console_send_hsreq & (~i_console_send_hsack);
    end

  assign o_console__rnotify = console_select & i_read;

  /* ---- Read multiplexer ---- */
  reg [31:0] data_ctrl;
  reg [31:0] data_console;

  assign o_data = 
    data_ctrl |
    data_console;

  always @(*) begin
    data_ctrl = 32'd0;
    data_console = 32'd0;

    if (console_select) begin
      data_console[7:0] = i_console_data;
      data_console[8] = i_console_send;
      data_console[9] = i_console_valid;
    end

  end

endmodule // io_reg

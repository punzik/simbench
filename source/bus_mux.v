// This file is auto-generated. Do not edit

// Slaves address ranges:
//   0 - 0x00000000-0x0000ffff
//   1 - 0x01000000-0x01000fff

// i_slave_rdata bits:
//   0: i_slave_rdata[31:0]
//   1: i_slave_rdata[63:32]

module bus_mux
  (input wire clock,
   input wire reset,

   // PicoRV32 memory interface
   // Look-ahead address and multiplexed signals
   // Some bits of address may not be used
   /* verilator lint_off UNUSED */
   input wire [31:0] i_la_addr,
   /* verilator lint_on UNUSED */
   output wire [31:0] o_rdata,
   input wire i_valid,
   output wire o_ready,

   // Slaves interface
   input wire [63:0] i_slave_rdata,
   output wire [1:0] o_slave_valid,
   input wire [1:0] i_slave_ready);

  wire [1:0] selector;
  reg [1:0] selector_reg;

  always @(posedge clock)
    if (reset)
      selector_reg <= 2'd0;
    else
      if (!i_valid)
        selector_reg <= selector;

  assign selector[0] =
    i_la_addr[24] == 1'b0;

  assign selector[1] =
    i_la_addr[24] == 1'b1;

  assign o_slave_valid = selector_reg & {2{i_valid}};
  assign o_ready = |(i_slave_ready & selector_reg);

  assign o_rdata =
    (i_slave_rdata[31:0] & {32{selector_reg[0]}}) |
    (i_slave_rdata[63:32] & {32{selector_reg[1]}});

`ifdef FORMAL

  always @(*) begin : formal_selector
    integer ones, n;
    ones = 0;

    // Check for selector is zero or one-hot value
    for (n = 0; n < 2; n = n + 1)
      if (selector[n] == 1'b1)
        ones = ones + 1;

    assert(ones < 2);

    // Check for correct address ranges decode
    if (i_la_addr >= 32'h0 && i_la_addr <= 32'hffff)
      assert(selector[0] == 1'b1);
    if (i_la_addr >= 32'h1000000 && i_la_addr <= 32'h1000fff)
      assert(selector[1] == 1'b1);
  end

  // Check multiplexer
  always @(*) begin : formal_mux
    case (selector_reg)
      2'b01: begin
        assert(o_rdata == i_slave_rdata[31:0]);
        assert(o_ready == i_slave_ready[0]);
        assert(o_slave_valid[0] == i_valid);
      end
      2'b10: begin
        assert(o_rdata == i_slave_rdata[63:32]);
        assert(o_ready == i_slave_ready[1]);
        assert(o_slave_valid[1] == i_valid);
      end
      2'b00: begin
        assert(o_rdata == 32'd0);
        assert(o_ready == 1'b0);
        assert(o_slave_valid == 2'd0);
      end
    endcase
  end

  // Assume module is not in reset state
  always @(*) assume(reset == 1'b0);

  // Make flag that the past is valid
  reg have_past = 1'b0;
  always @(posedge clock) have_past <= 1'b1;

  // Check for selector_reg is valid and stable when i_valid is 1
  always @(posedge clock) begin
    if (have_past)
      if (i_valid)
        if ($rose(i_valid))
          assert(selector_reg == $past(selector));
        else
          assert($stable(selector_reg));
  end

`endif // FORMAL

endmodule // bus_mux
`default_nettype wire

`timescale 1ps/1ps

module picorv32_tcm #(parameter ADDR_WIDTH = 8,
                      parameter USE_LOOK_AHEAD = 0,
                      parameter USE_ADDR_MUX = 1,
                      parameter MEM_INIT_FILE = "")
    (input wire clock,
     /* verilator lint_off UNUSED */
     // Not used in look-ahead mode
     input wire reset,
     /* verilator lint_on UNUSED */

     /* PicoRV32 bus interface */
     input  wire                  mem_valid,
     output wire                  mem_ready,
     input  wire [ADDR_WIDTH-1:0] mem_addr,
     input  wire           [31:0] mem_wdata,
     input  wire            [3:0] mem_wstrb,
     output reg            [31:0] mem_rdata,

     // PicoRV32 look-ahead address.
     // Not used in non-look-ahead mode.
     /* verilator lint_off UNUSED */
     input  wire [ADDR_WIDTH-1:0] mem_la_addr
     /* verilator lint_off UNUSED */
     );

    logic [31:0] ram[0:(2 ** (ADDR_WIDTH-2))-1];
    if (MEM_INIT_FILE != "")
      initial $readmemh(MEM_INIT_FILE, ram);

    /* verilator lint_off UNUSED */
    // Bits [1:0] are not used
    logic [ADDR_WIDTH-1:0] byte_addr;
    /* verilator lint_on UNUSED */
    logic [ADDR_WIDTH-3:0] word_addr;
    logic write;

    assign word_addr = byte_addr[ADDR_WIDTH-1:2];

    always @(posedge clock) begin
        for (int n = 0; n < 4; n += 1)
          if (write && mem_wstrb[n])
            ram[word_addr][n*8 +: 8] <= mem_wdata[n*8 +: 8];

        mem_rdata <= ram[word_addr];
    end

    if (USE_LOOK_AHEAD == 0) begin : no_look_ahead
        logic data_ready;

        always_ff @(posedge clock)
          if (reset) data_ready <= 1'b0;
          else
            // Don't use ternary operator to prevent
            // X-propagation from PicoRV32 core
            // data_ready <= mem_valid & ~(|mem_wstrb);
            if (mem_valid && mem_wstrb == '0)
              data_ready <= 1'b1;
            else
              data_ready <= 1'b0;


        assign byte_addr = mem_addr;
        assign write = mem_valid & (|mem_wstrb);
        assign mem_ready = data_ready | write;
    end
    else begin : look_ahead
        logic data_ready;

        always_ff @(posedge clock)
          if (reset) data_ready <= 1'b0;
          else
            // Don't use ternary operator to prevent
            // X-propagation from PicoRV32 core
            // data_ready <= ~(mem_valid && (|mem_wstrb));
            if (mem_valid && mem_wstrb != '0)
              data_ready <= 1'b0;
            else
              data_ready <= 1'b1;

        /* mem_la_addr валиден как минимум один такт после поднятия mem_valid.
         * Т.е. в принципе можно обойтись без мультиплескора. В формальной части
         * добавлено соответствуюшее утверждение. */
        if (USE_ADDR_MUX == 0)
          assign byte_addr = mem_la_addr[ADDR_WIDTH-1:0];
        else
          assign byte_addr = mem_valid ?
                             mem_addr[ADDR_WIDTH-1:0] :
                             mem_la_addr[ADDR_WIDTH-1:0];

        assign write = mem_valid & (|mem_wstrb);
        assign mem_ready = data_ready;
    end

`ifdef FORMAL
    // Past valid flag
    logic have_past = 1'b0;
    always_ff @(posedge clock) have_past <= 1'b1;

    // Assumptions
    always @(*) assume(reset == 1'b0);

    always @(posedge clock)
      if (have_past) begin
          // mem_addr <= mem_la_addr
          if ($rose(mem_valid))
            assume(mem_addr == $past(mem_la_addr));

          // Stable mem_addr and mem_data when mem_valid is active
          if (mem_valid) begin
              assume($stable(mem_addr));
              assume($stable(mem_wdata));
              assume($stable(mem_wstrb));
          end

          // Assume mem_valid will not cleared while mem_ready is not active
          if ($past(mem_valid) && !$past(mem_ready))
            assume(mem_valid == 1'b1);

          // Assume mem_valid will cleared after memory transaction complete
          if ($past(mem_valid) && $past(mem_ready))
            assume(mem_valid == 1'b0);

          // WARN: May be wrong assumption
          // Assume mem_add == mem_la_addr on first clock cycle of mem_valid activity
          if ($rose(mem_valid))
            assume(mem_addr == mem_la_addr);
      end
      else begin
          // Initial mem_valid = 1'b0
          assume(mem_valid == 1'b0);
      end

    // Data read
    always_ff @(posedge clock)
      if (have_past)
        if (mem_valid && mem_ready && mem_wstrb == '0)
          assert(mem_rdata == ram[mem_addr[ADDR_WIDTH-1:2]]);

    // Data write
    always_ff @(posedge clock) begin
        logic [3:0] mem_wstrb_past;

        if (have_past) begin
            mem_wstrb_past = $past(mem_wstrb);

            if ($past(mem_valid) && $past(mem_ready) && mem_wstrb_past != '0)
              for (int n = 0; n < 4; n += 1)
                if (mem_wstrb_past[n])
                  assert(ram[$past(mem_addr[ADDR_WIDTH-1:2])][n*8 +: 8] == $past(mem_wdata[n*8 +: 8]));
        end
    end

    // Mem ready
    always_ff @(posedge clock)
      if (have_past)
        if (USE_LOOK_AHEAD == 0) begin
            // Write transaction
            if (mem_wstrb != '0 && mem_valid)
              assert(mem_ready);

            // First cycle of read transaction
            if (mem_wstrb == '0 && !$past(mem_valid)&& mem_valid)
              assert(!mem_ready);

            // Second cycle of read transaction
            if ($past(mem_wstrb) == '0 && $past(mem_valid) && mem_valid)
              assert(mem_ready);
        end
        else begin
            // In look-ahead mode mem_ready always active
            if (mem_valid)
              assert(mem_ready);
        end

`endif

endmodule // picorv32_tcm

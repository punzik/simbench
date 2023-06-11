`timescale 1ps/1ps

module testbench (input clock);
    parameter MEM_ADDR_WIDTH = 16;

    logic reset = 1'b1;

    /* verilator lint_off UNUSED */
    logic        cpu_mem_valid;
    logic        cpu_mem_instr;
    logic        cpu_mem_ready;
    logic [31:0] cpu_mem_addr;
    logic [31:0] cpu_mem_wdata;
    logic [ 3:0] cpu_mem_wstrb;
    logic [31:0] cpu_mem_rdata;

    // Look-Ahead Interface
    logic        cpu_mem_la_read;
    logic        cpu_mem_la_write;
    logic [31:0] cpu_mem_la_addr;
    logic [31:0] cpu_mem_la_wdata;
    logic [ 3:0] cpu_mem_la_wstrb;
    /* verilator lint_on UNUSED */

    // PicoRV32                                 // Defaults
    picorv32 #(.ENABLE_COUNTERS(0),             // = 1,
	       .ENABLE_COUNTERS64(0),           // = 1,
	       .ENABLE_REGS_16_31(1),           // = 1,
	       .ENABLE_REGS_DUALPORT(1),        // = 1,
	       .LATCHED_MEM_RDATA(0),           // = 0,
	       .TWO_STAGE_SHIFT(1),             // = 1,
	       .BARREL_SHIFTER(0),              // = 0,
	       .TWO_CYCLE_COMPARE(0),           // = 0,
	       .TWO_CYCLE_ALU(0),               // = 0,
	       .COMPRESSED_ISA(0),              // = 0,
	       .CATCH_MISALIGN(1),              // = 1,
	       .CATCH_ILLINSN(1),               // = 1,
	       .ENABLE_PCPI(0),                 // = 0,
	       .ENABLE_MUL(0),                  // = 0,
	       .ENABLE_FAST_MUL(0),             // = 0,
	       .ENABLE_DIV(0),                  // = 0,
	       .ENABLE_IRQ(0),                  // = 0,
	       .ENABLE_IRQ_QREGS(0),            // = 1,
	       .ENABLE_IRQ_TIMER(0),            // = 1,
	       .ENABLE_TRACE(0),                // = 0,
	       .REGS_INIT_ZERO(0),              // = 0,
	       .MASKED_IRQ(32'h 0000_0000),     // = 32'h 0000_0000,
	       .LATCHED_IRQ(32'h ffff_ffff),    // = 32'h ffff_ffff,
	       .PROGADDR_RESET(32'h 0000_0000), // = 32'h 0000_0000,
	       .PROGADDR_IRQ(32'h 0000_0010),   // = 32'h 0000_0010,
	       .STACKADDR(32'h ffff_ffff))      // = 32'h ffff_ffff
    picorv32
      (.clk(clock),
       .resetn(~reset),

       .mem_valid(cpu_mem_valid),       // output reg
       .mem_instr(cpu_mem_instr),       // output reg
       .mem_ready(cpu_mem_ready),       // input
       .mem_addr(cpu_mem_addr),         // output reg [31:0]
       .mem_wdata(cpu_mem_wdata),       // output reg [31:0]
       .mem_wstrb(cpu_mem_wstrb),       // output reg [ 3:0]
       .mem_rdata(cpu_mem_rdata),       // input      [31:0]

       // Look-Ahead Interface
       .mem_la_read(cpu_mem_la_read),   // output
       .mem_la_write(cpu_mem_la_write), // output
       .mem_la_addr(cpu_mem_la_addr),   // output     [31:0]
       .mem_la_wdata(cpu_mem_la_wdata), // output reg [31:0]
       .mem_la_wstrb(cpu_mem_la_wstrb), // output reg [ 3:0]

       // Unused
       /* verilator lint_off PINCONNECTEMPTY */
       .pcpi_valid(),                   // output reg
       .pcpi_insn(),                    // output reg [31:0]
       .pcpi_rs1(),                     // output     [31:0]
       .pcpi_rs2(),                     // output     [31:0]
       .pcpi_wr(1'b0),                  // input
       .pcpi_rd(32'd0),                 // input      [31:0]
       .pcpi_wait(1'b0),                // input
       .pcpi_ready(1'b0),               // input
       .irq(32'd0),                     // input      [31:0]
       .eoi(),                          // output reg [31:0]
       .trap(),                         // output reg
       .trace_valid(),                  // output reg
       .trace_data()                    // output reg [35:0]
       /* verilator lint_on PINCONNECTEMPTY */
       );

    // -- Bus multiplexer
    // Slaves address ranges:
    //   0 - 0x00000000-0x0000ffff
    //   1 - 0x01000000-0x01000fff

    // i_slave_rdata bits:
    //   0: i_slave_rdata[31:0]
    //   1: i_slave_rdata[63:32]

    logic [31:0] rdata_ram;
    logic [31:0] rdata_reg;
    logic valid_ram;
    logic ready_ram;
    logic valid_reg;
    logic ready_reg;

    bus_mux bus_mux
      (.clock, .reset,
       // CPU
       .i_la_addr(cpu_mem_la_addr),
       .o_rdata(cpu_mem_rdata),
       .i_valid(cpu_mem_valid),
       .o_ready(cpu_mem_ready),
       // Slaves
       .i_slave_rdata({rdata_reg, rdata_ram}),
       .o_slave_valid({valid_reg, valid_ram}),
       .i_slave_ready({ready_reg, ready_ram}));

    // -- CPU memory
    picorv32_tcm #(.ADDR_WIDTH(MEM_ADDR_WIDTH),
                   .USE_LOOK_AHEAD(1),
                   .USE_ADDR_MUX(0),
                   .MEM_INIT_FILE("../source/firmware/fw.mem"))
    picorv32_tcm
      (.clock, .reset,

       /* PicoRV32 bus interface */
       .mem_valid(valid_ram),
       .mem_ready(ready_ram),
       .mem_addr(cpu_mem_addr[MEM_ADDR_WIDTH-1:0]),
       .mem_wdata(cpu_mem_wdata),
       .mem_wstrb(cpu_mem_wstrb),
       .mem_rdata(rdata_ram),
       .mem_la_addr(cpu_mem_la_addr[MEM_ADDR_WIDTH-1:0]));

    // -- Registers
    // Reg 'ctrl'
    logic ctrl_stop;

    // Reg 'console'
    logic [7:0] i_console_data;
    logic [7:0] o_console_data;
    logic console_send;

    logic reg_write;
    logic reg_read;

    assign ready_reg = 1'b1;
    assign reg_write = valid_reg & |(cpu_mem_wdata);
    assign reg_read = valid_reg & &(~cpu_mem_wdata);
    assign i_console_data = 8'ha5;

    io_reg io_reg
      (.clock, .reset,

       // CPU
       .i_addr({16'd0, cpu_mem_addr[15:0]}),
       .i_data(cpu_mem_wdata),
       .o_data(rdata_reg),
       .i_ben(cpu_mem_wstrb),
       .i_write(reg_write),
       .i_read(reg_read),

       // Reg 'ctrl'
       .o_ctrl_stop(ctrl_stop),

       // Reg 'console'
       .i_console_data(i_console_data),
       .o_console_data(o_console_data),
       .o_console_send_hsreq(console_send),

       // Unused
       /* verilator lint_off PINCONNECTEMPTY */
       .o_console__rnotify(),
       .i_console_send_hsack(1'b1),
       .i_console_send(1'b0),
       .i_console_valid(1'b1)
       /* verilator lint_on PINCONNECTEMPTY */
       );

    // Reset
    localparam RESET_DURATION = 5;
    int reset_counter = RESET_DURATION;

    always_ff @(posedge clock)
      if (reset_counter == 0)
        reset <= 1'b0;
      else
        reset_counter <= reset_counter - 1;

    // Print console output
    // always_ff @(posedge clock)
    //   if (!reset && console_send)
    //     $write("%c", o_console_data);

    initial
      forever begin
          @(posedge clock);
          if (!reset && console_send) begin
              $write("%c", o_console_data);
              $fflush;
          end
      end

    // Wait for complete
    initial begin
        while (reset || ctrl_stop == 1'b0) @(posedge clock);

        @(posedge clock);
        $finish;
    end

endmodule // testbench

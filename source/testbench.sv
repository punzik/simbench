`timescale 1ps/1ps

module testbench #(parameter CPU_COUNT = 1024)
    (input clock);

    localparam DATA_ADDR = 32'h00010000;
    localparam DATA_LEN = 1024;

    logic [31:0] data_len;
    logic [CPU_COUNT-1:0] done_all;

    int cycle = 0;
    always @(posedge clock) cycle <= cycle + 1;

    for (genvar ncpu = 0; ncpu < CPU_COUNT; ncpu = ncpu + 1) begin : cpus
        logic done, done_ack = 1'b0;
        logic reset;
        logic [127:0] md5;

        assign done_all[ncpu] = done;

        md5calculator cpu
          (.clock, .reset, .done,
           .md5_data_addr(DATA_ADDR),
           .md5_data_len(data_len),
           .md5(md5));

        initial
          for (int n = 0; n < (2 ** (cpu.rom.ADDR_WIDTH-2)); n += 1)
            cpu.rom.ram[n] = ncpu;

        initial
          if(!$value$plusargs("dlen=%d", data_len))
            data_len = DATA_LEN;

        int reset_duration;
        initial reset_duration = $urandom % CPU_COUNT + 2;
        assign reset = cycle <= reset_duration;

        always @(posedge clock) begin
            if (cycle > reset_duration && done && !done_ack) begin
                done_ack <= 1'b1;
                $display("MD5(0x%x) = %x", ncpu, md5);
            end
        end
    end

    // Wait for complete
    always @(posedge clock) begin
        if (cycle == 0) $display("--- BENCH BEGIN ---");
        else if (cycle > 5) begin
            if (&done_all) begin
                $display("--- BENCH DONE ---");
                $finish;
            end
        end
    end

endmodule // testbench

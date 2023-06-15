`timescale 1ps/1ps


module testbench (input clock);
    localparam CPU_COUNT = 1024;

    logic [CPU_COUNT-1:0] done_all;

    for (genvar ncpu = 0; ncpu < CPU_COUNT; ncpu = ncpu + 1) begin : cpus
        localparam logic [31:0] MD5IN = ncpu;

        logic done;
        logic reset;
        logic [127:0] md5;

        assign done_all[ncpu] = done;

        md5calculator cpu(.clock, .reset, .done, .md5);

        initial
          for (int n = 0; n < (2 ** (cpu.rom.ADDR_WIDTH-2)); n += 1)
            cpu.rom.ram[n] = ncpu;

        initial begin
            reset = 1'b1;
            repeat($urandom % 5 + 2) @(posedge clock);
            reset = 1'b0;
            @(posedge clock);

            while(!done) @(posedge clock);
            $display("MD5(0x%x) = %x", MD5IN, md5);
        end
    end

    // Wait for complete
    initial begin
        $display("--- BENCH BEGIN ---");


        repeat(5) @(posedge clock);
        while ((&done_all) == 1'b0) @(posedge clock);
        @(posedge clock);

        $display("--- BENCH DONE ---");
        $finish;
    end

endmodule // testbench

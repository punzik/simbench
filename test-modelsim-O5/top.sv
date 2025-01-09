`timescale 1ps/1ps

module top #(parameter CPU_COUNT = 1024);
    logic clock = 1'b0;
    initial forever #(10ns/2) clock = ~clock;
    testbench #(CPU_COUNT) testbench (clock);
endmodule

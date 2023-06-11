`timescale 1ps/1ps

module top;
    logic clock = 1'b0;
    initial forever #(10ns/2) clock = ~clock;
    testbench testbench (clock);
endmodule

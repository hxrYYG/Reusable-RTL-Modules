
`timescale 1ns/1ns

module tb_edge_detect;

parameter FILTER_EN = 1;
parameter FILTER_CYCLES = 8;

reg clk;
reg rst_n;
reg signal_in;
wire signal_out;

edge_detect #(
    .FILTER_EN(FILTER_EN),
    .FILTER_CYCLES(FILTER_CYCLES)
) u_edge_detect (
    .clk(clk),
    .rst_n(rst_n),
    .signal_in(signal_in),
    .signal_out(signal_out)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz
end

initial begin
    rst_n = 0;
    signal_in = 0;
    #20 rst_n = 1;
    // 测试1：短毛刺，应该被过滤
    #10 signal_in = 1;
    #10 signal_in = 0;
    // 测试2：正常上升沿
    #100 signal_in = 1;
    #120 signal_in = 0;
    // 测试3：再次检测上升沿
    #120 signal_in = 1;
    #120 signal_in = 0;
    #50 $finish;
end

endmodule

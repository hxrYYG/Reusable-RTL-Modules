`timescale 1ns/1ns
module tb_up_counter();

parameter COUNTER_NUM = 16;
localparam COUNTER_WIDTH = (COUNTER_NUM <= 1) ? 1 :$clog2(COUNTER_NUM);
reg clk;
reg rst_n;
wire [COUNTER_WIDTH-1:0] counter;

up_counter #(
    .COUNTER_NUM   (COUNTER_NUM)
) u_up_counter(
    .clk           (clk),
    .rst_n         (rst_n),
    .counter       (counter)
);

// 100MHz时钟
initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    #20;
    rst_n = 1'b1;
    #200;
    $finish;
end

endmodule
module down_counter #(
    parameter COUNTER_NUM = 16,                     // 计数状态总数
    parameter COUNTER_WIDTH = (COUNTER_NUM <= 1) ? 1 :$clog2(COUNTER_NUM) // 计数器位宽
)(
    input                                clk,
    input                                rst_n,     // 低有效异步复位
    output reg [COUNTER_WIDTH-1:0]       counter
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        counter <= COUNTER_NUM - 1;
    else if (counter == 0)
        counter <= COUNTER_NUM - 1;
    else
        counter <= counter - 1'b1;
end

endmodule
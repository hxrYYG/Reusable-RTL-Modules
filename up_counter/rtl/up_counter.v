module up_counter #(
    parameter COUNTER_NUM = 16,                      // 计数状态总数
    
     // COUNTER_WIDTH 默认自动计算；若工具不支持 $clog2()，可手动指定该参数
    parameter COUNTER_WIDTH = (COUNTER_NUM <= 1) ? 1 :$clog2(COUNTER_NUM) 
)(
    input                                clk,
    input                                rst_n,     // 低有效异步复位
    output reg [COUNTER_WIDTH-1:0]       counter
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        counter <= 0;
    else if (counter == COUNTER_NUM - 1)
        counter <= 0;
    else
        counter <= counter + 1'b1;
end

endmodule
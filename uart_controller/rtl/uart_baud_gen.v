module uart_baud_gen #(
    parameter integer CLK_FREQ = 100_000_000,         // 时钟频率 100 MHz
    parameter integer BAUD_RATE = 115_200             // 波特率，默认 115200 bps
)(
    input       clk,
    input       rst_n,
    input       baud_en,

    output reg  baud_tick
);

// 每个 UART 数据位持续的时钟周期数，四舍五入计算
localparam integer CLKS_PER_BIT = (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;
// 计算每个 UART 数据位持续的时钟周期数所需的位宽
localparam integer BAUD_CNT_WIDTH = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

reg [BAUD_CNT_WIDTH-1:0] baud_cnt; // 时钟计数器

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_cnt <= 0;
        baud_tick <= 1'b0;
    end else if (baud_en) begin
        if (baud_cnt == CLKS_PER_BIT - 1) begin
            baud_cnt <= 0;
            baud_tick <= 1'b1;
        end
        else begin
            baud_cnt <= baud_cnt + 1;
            baud_tick <= 1'b0;
        end
    end else begin
        baud_cnt <= 0;
        baud_tick <= 1'b0;        
    end 
end

endmodule
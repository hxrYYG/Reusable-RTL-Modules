module sync_filter #(
    parameter FILTER_EN = 0,         // 滤波器使能
    parameter FILTER_CYCLES = 8
)(
    input      clk,
    input      rst_n,
    input      signal_in,

    output     signal_out
);

// 输入信号同步
// (* ASYNC_REG = "TRUE" *)
reg sync_ff1 , sync_ff2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sync_ff1 <= 1'b0;
        sync_ff2 <= 1'b0;
    end else begin
        sync_ff1 <= signal_in;
        sync_ff2 <= sync_ff1;
    end
end

// 滤波器设计
localparam FILTER_CNT_WIDTH = (FILTER_CYCLES <= 1) ? 1 : $clog2(FILTER_CYCLES);

reg filtered_out;
reg [FILTER_CNT_WIDTH - 1 : 0] filter_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        filter_cnt <= 0;
        filtered_out <= 1'b0;
    end else if (FILTER_EN) begin
        if (sync_ff2 == filtered_out) begin
            filter_cnt <= 0;
        end else begin 
            if (filter_cnt == FILTER_CYCLES - 1) begin
            filter_cnt <= 0;
            filtered_out <= sync_ff2;
            end else begin
                filter_cnt <= filter_cnt + 1;
            end
        end
    end
end

assign signal_out = FILTER_EN ? filtered_out : sync_ff2;

endmodule
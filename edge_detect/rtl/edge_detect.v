module edge_detect #(
    parameter FILTER_EN = 0,         // 滤波器使能
    parameter FILTER_CYCLES = 8
)(
    input      clk,
    input      rst_n,
    input      signal_in,

    output     signal_out
);

wire filtered_signal_in;
sync_filter #(
    .FILTER_EN(FILTER_EN),         // 滤波器使能
    .FILTER_CYCLES(FILTER_CYCLES)
) u_sync_filter (
    .clk(clk),
    .rst_n(rst_n),
    .signal_in(signal_in),
    .signal_out(filtered_signal_in)
);

reg signal_in_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        signal_in_reg <= 1'b0;
    end else begin
        signal_in_reg <= filtered_signal_in;
    end
end

// 检测上升沿
assign signal_out = filtered_signal_in & ~signal_in_reg;

// 检测下降沿
//assign signal_out = ~filtered_signal_in & signal_in_reg;
// 检测双边沿
//assign signal_out = filtered_signal_in ^ signal_in_reg;

endmodule
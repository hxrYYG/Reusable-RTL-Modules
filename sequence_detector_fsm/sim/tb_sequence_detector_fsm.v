`timescale 1ns / 1ns

module tb_sequence_detector_fsm;

    reg  clk;
    reg  rst_n;
    reg  X;
    wire Z;

    // 例化被测模块
    sequence_detector_fsm u_sequence_detector_fsm (
        .clk   (clk),
        .rst_n (rst_n),
        .X     (X),
        .Z     (Z)
    );

    // 产生 100MHz 时钟：周期 10ns
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 复位与输入序列
    initial begin
        // 初始化
        rst_n = 0;
        X     = 0;

        // 保持复位至少几个时钟周期
        #25;
        rst_n = 1;
        #10;

        // 输入序列：10010010（包含重叠的 10010）
        // 在时钟下降沿改变 X，确保上升沿稳定采样
        @(negedge clk); X = 1;   // 第 1 位：1
        @(negedge clk); X = 0;   // 第 2 位：0
        @(negedge clk); X = 0;   // 第 3 位：0
        @(negedge clk); X = 1;   // 第 4 位：1
        @(negedge clk); X = 0;   // 第 5 位：0  -> 第一个 10010，Z 应为 1
        @(negedge clk); X = 0;   // 第 6 位：0
        @(negedge clk); X = 1;   // 第 7 位：1
        @(negedge clk); X = 0;   // 第 8 位：0  -> 第二个 10010，Z 应为 1
        @(negedge clk); X = 0;   // 后续输入
        @(negedge clk); X = 0;

        // 继续运行一段时间
        #100;
        $stop;
    end

endmodule
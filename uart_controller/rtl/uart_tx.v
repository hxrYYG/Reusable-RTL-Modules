module uart_tx #(
    parameter integer CLK_FREQ  = 100_000_000,        // 时钟频率 100 MHz
    parameter DATA_WIDTH = 8,                         // 数据长度，默认为 8 位
    parameter PARITY_ON = 0,                          // 奇偶校验位，1 为有校验位，0 为无校验位，默认为 0
    parameter PARITY_TYPE = 0,                        // 校验类型，1 为奇校验，0 为偶校验，默认为偶校验
    parameter integer BAUD_RATE = 115_200             // 波特率，默认 115200 bps
)(
    input                    clk,
    input                    rst_n,
    input [DATA_WIDTH - 1:0] data_in,
    input                    start_tx,

    output reg               tx_out,
    output reg               tx_busy,
    output reg               tx_done
);

// 状态机定义
localparam IDLE   = 3'd1,    // 空闲状态
           START  = 3'd2,    // 起始位状态
           DATA   = 3'd3,    // 数据位状态
           PARITY = 3'd4,    // 校验位状态
           STOP   = 3'd5;    // 停止位状态

reg [2:0] current_state, next_state;

// 波特率发生器实例化
reg baud_en;
wire baud_tick;

uart_baud_gen #(
    .CLK_FREQ(CLK_FREQ),         
    .BAUD_RATE(BAUD_RATE)
) u_uart_baud_gen (
    .clk(clk),
    .rst_n(rst_n),
    .baud_en(baud_en),

    .baud_tick(baud_tick)
);

// 数据位计数器
localparam integer BIT_CNT_WIDTH = $clog2(DATA_WIDTH);
reg [BIT_CNT_WIDTH - 1:0] bit_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_cnt <= 0;
    end else if ((current_state == DATA) && baud_tick) begin
        if (bit_cnt == DATA_WIDTH - 1) begin
            bit_cnt <= 0;
        end else begin
            bit_cnt <= bit_cnt + 1;
        end
    end else if (current_state != DATA) begin
        bit_cnt <= 0;
    end
end

// 数据输入寄存器，用于在发送开始时捕获数据
reg [DATA_WIDTH - 1:0] data_in_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_in_reg <= 0;
    end else if (start_tx && (current_state == IDLE)) begin
        data_in_reg <= data_in; // 在空闲状态下，捕获输入数据
    end
end

// 奇偶校验位计算
wire parity_bit;
assign parity_bit = (PARITY_TYPE == 1'b0) ? ^data_in_reg : ~^data_in_reg; // 偶校验为 0，奇校验为 1

// 第一段状态机，状态转移逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

// 第二段状态机，状态跳转逻辑
always @* begin
    case (current_state)
        IDLE  : next_state = start_tx ? START : IDLE;
        START : next_state = baud_tick ? DATA : START;
        DATA  : next_state = (baud_tick && (bit_cnt == DATA_WIDTH - 1)) ? (PARITY_ON ? PARITY : STOP) : DATA;
        PARITY: next_state = baud_tick ? STOP : PARITY;
        STOP : next_state = baud_tick ? IDLE : STOP;
        default : next_state = IDLE;
    endcase
end

// 第三段状态机，输出逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_out <= 1'b1; // 空闲状态下，TX 输出高电平
        tx_busy <= 1'b0;
        tx_done <= 1'b0;
        baud_en <= 1'b0;
    end else case (current_state) 
            IDLE : begin
                tx_out <= 1'b1;
                tx_busy <= 1'b0;
                tx_done <= 1'b0;
                baud_en <= 1'b0;
            end
            START : begin
                tx_out <= 1'b0;                 // 起始位为低电平
                tx_busy <= 1'b1;    
                tx_done <= 1'b0;    
                baud_en <= 1'b1;                // 启动波特率计数器
            end
            DATA : begin
                tx_out <= data_in_reg[bit_cnt]; // 发送数据位
                tx_busy <= 1'b1;
                tx_done <= 1'b0;
                baud_en <= 1'b1;                // 启动波特率计数器
            end    
            PARITY : begin    
                tx_out <= parity_bit;           // 发送校验位
                tx_busy <= 1'b1;    
                tx_done <= 1'b0;    
                baud_en <= 1'b1;                // 启动波特率计数器
            end    
            STOP : begin
                tx_out <= 1'b1;
                if (baud_tick) begin            // 停止位发送完成后，回到空闲状态
                    tx_busy <= 1'b0;            // 清除忙碌标志
                    tx_done <= 1'b1;            // 设置发送完成标志
                    baud_en <= 1'b0;            // 停止波特率计数器
                end else begin
                    tx_busy <= 1'b1;
                    tx_done <= 1'b0;
                    baud_en <= 1'b1;
                end
            end
            default : begin
                tx_out <= 1'b1;
                tx_busy <= 1'b0;
                tx_done <= 1'b0;
                baud_en <= 1'b0;
            end
        endcase
    end

endmodule

module uart_rx #(
    parameter integer CLK_FREQ  = 100_000_000,        // 时钟频率 100 MHz
    parameter DATA_WIDTH = 8,                         // 数据长度，默认为 8 位
    parameter PARITY_ON = 0,                          // 奇偶校验位，1 为有校验位，0 为无校验位，默认为 0
    parameter PARITY_TYPE = 0,                        // 校验类型，1 为奇校验，0 为偶校验，默认为偶校验
    parameter integer BAUD_RATE = 115_200             // 波特率，默认 115200 bps
)(
    input                         clk,
    input                         rst_n,
    input                         rx_in,

    output reg [DATA_WIDTH - 1:0] data_out,
    output reg                    rx_busy,
    output reg                    rx_done,
    output reg                    parity_error
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

// 半周期计数器，用于在接收数据时对采样点进行调整
// 每个 UART 数据位持续的时钟周期数，四舍五入计算
localparam integer CLKS_PER_BIT = (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;
localparam integer HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;
// 计算每个 UART 数据位持续的时钟周期数所需的位宽
localparam integer BAUD_CNT_WIDTH = (HALF_CLKS_PER_BIT <= 1) ? 1 : $clog2(HALF_CLKS_PER_BIT);

reg [BAUD_CNT_WIDTH-1:0] baud_cnt; // 半周期计数器
wire baud_cnt_en;                  // 半周期计数器使能信号
reg half_done;                     // 半周期完成信号
assign baud_cnt_en = (current_state == START);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_cnt <= 0;
        half_done <= 1'b0;
    end else if (baud_cnt_en) begin
        if (baud_cnt == HALF_CLKS_PER_BIT - 1) begin
            baud_cnt <= 0;
            half_done <= 1'b1;
        end else begin
            baud_cnt <= baud_cnt + 1;
            half_done <= 1'b0;
        end
    end else begin
        baud_cnt <= 0;
        half_done <= 1'b0;
    end 
end

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

// 数据输入寄存器，用于在接收数据时捕获数据
reg rx_in_reg1;
reg rx_in_reg2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_in_reg1 <= 1'b1; // 空闲状态下，UART RX 引脚为高电平
        rx_in_reg2 <= 1'b1;
    end else begin
        rx_in_reg1 <= rx_in;
        rx_in_reg2 <= rx_in_reg1;
    end
end

// 数据接收寄存器
reg [DATA_WIDTH-1:0] rx_data_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_data_reg <= 0;
    end else if (current_state == IDLE) begin
        rx_data_reg <= 0;
    end else if ((current_state == DATA) && baud_tick) begin
        rx_data_reg[bit_cnt] <= rx_in_reg2;
    end
end

// 奇偶校验位计算
wire parity_bit;
assign parity_bit = (PARITY_TYPE == 1'b0) ? ^rx_data_reg : ~^rx_data_reg; // 偶校验为 0，奇校验为 1

 // 奇偶校验结果
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        parity_error <= 1'b0;
    end else if ((current_state == START) && half_done && (rx_in_reg2 == 1'b0)) begin
        parity_error <= 1'b0;
    end else if (PARITY_ON && (current_state == PARITY) && baud_tick) begin
        parity_error <= (rx_in_reg2 != parity_bit);
    end
end

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
        IDLE  : next_state = (rx_in_reg2 == 1'b0) ? START : IDLE; // 检测到起始位，进入 START 状态
        START : next_state = half_done ? (rx_in_reg2 == 1'b0 ? DATA : IDLE) : START;
        DATA  : next_state = ((bit_cnt == DATA_WIDTH - 1) && baud_tick) ? (PARITY_ON ? PARITY : STOP) : DATA; // 数据位接收完成后，根据是否有校验位决定下一状态
        PARITY: next_state = baud_tick ? STOP : PARITY;           // 校验位接收完成后，进入 STOP 状态
        STOP  : next_state = baud_tick ? IDLE : STOP;             // 停止位接收完成后，返回 IDLE 状态
        default: next_state = IDLE;
    endcase
end

// 第三段状态机，输出逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out <= 0;
        rx_busy <= 1'b0;
        rx_done <= 1'b0;
        baud_en <= 1'b0;
    end else case (current_state)
            IDLE : begin
                rx_busy <= 1'b0;
                rx_done <= 1'b0;
                baud_en <= 1'b0;
            end
            START : begin
                rx_busy <= 1'b1;    
                rx_done <= 1'b0;    
                baud_en <= 1'b0;
            end
            DATA : begin
                rx_busy <= 1'b1;
                rx_done <= 1'b0;
                baud_en <= 1'b1;    // 启动波特率计数器
            end    
            PARITY : begin    
                rx_busy <= 1'b1;
                rx_done <= 1'b0;
                baud_en <= 1'b1;    // 启动波特率计数器
            end
            STOP : begin
                if (baud_tick) begin
                    rx_busy <= 1'b0;
                    baud_en <= 1'b0;
                    if (rx_in_reg2 == 1'b1) begin
                        data_out <= rx_data_reg;
                        rx_done <= 1'b1;
                    end else begin
                        rx_done <= 1'b0;
                    end
                end else begin
                    rx_busy <= 1'b1;
                    rx_done <= 1'b0;
                    baud_en <= 1'b1;
                end
            end
            default : begin
                rx_busy <= 1'b0;
                rx_done <= 1'b0;
                baud_en <= 1'b0;
            end
        endcase
end

endmodule
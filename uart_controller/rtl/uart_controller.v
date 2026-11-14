
module uart_controller #(
    parameter integer CLK_FREQ    = 100_000_000,
    parameter integer DATA_WIDTH  = 8,
    parameter integer PARITY_ON   = 0,
    parameter integer PARITY_TYPE = 0,
    parameter integer BAUD_RATE   = 115_200
)(
    input                         clk,
    input                         rst_n,

    // UART TX 接口
    input  [DATA_WIDTH - 1:0]     tx_data_in,
    input                         start_tx,
    output                        tx_out,
    output                        tx_busy,
    output                        tx_done,

    // UART RX 接口
    input                         rx_in,
    output [DATA_WIDTH - 1:0]     rx_data_out,
    output                        rx_busy,
    output                        rx_done,
    output                        parity_error
);

// UART TX 实例化
uart_tx #(
    .CLK_FREQ(CLK_FREQ),
    .DATA_WIDTH(DATA_WIDTH),
    .PARITY_ON(PARITY_ON),
    .PARITY_TYPE(PARITY_TYPE),
    .BAUD_RATE(BAUD_RATE)
) u_uart_tx (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(tx_data_in),
    .start_tx(start_tx),
    .tx_out(tx_out),
    .tx_busy(tx_busy),
    .tx_done(tx_done)
);

// UART RX 实例化
uart_rx #(
    .CLK_FREQ(CLK_FREQ),
    .DATA_WIDTH(DATA_WIDTH),
    .PARITY_ON(PARITY_ON),
    .PARITY_TYPE(PARITY_TYPE),
    .BAUD_RATE(BAUD_RATE)
) u_uart_rx (
    .clk(clk),
    .rst_n(rst_n),
    .rx_in(rx_in),
    .data_out(rx_data_out),
    .rx_busy(rx_busy),
    .rx_done(rx_done),
    .parity_error(parity_error)
);

endmodule

`timescale 1ns/1ps

module tb_uart_controller;

    localparam integer CLK_FREQ    = 100_000_000;
    localparam integer BAUD_RATE   = 115_200;
    localparam integer DATA_WIDTH  = 8;
    localparam integer PARITY_ON   = 0;  // 0: 8N1; 1: 8E1/8O1
    localparam integer PARITY_TYPE = 0;  // 0: even; 1: odd

    localparam integer CLK_PERIOD_NS  = 10;
    localparam integer CLKS_PER_BIT   = (CLK_FREQ + BAUD_RATE/2) / BAUD_RATE;
    localparam integer BIT_TIME_NS    = CLKS_PER_BIT * CLK_PERIOD_NS;
    localparam integer TIMEOUT_CYCLES = CLKS_PER_BIT * (DATA_WIDTH + 5);

    reg clk;
    reg rst_n;
    reg [DATA_WIDTH-1:0] tx_data_in;
    reg start_tx;

    wire tx_out;
    wire tx_busy;
    wire tx_done;
    wire rx_in;
    wire [DATA_WIDTH-1:0] rx_data_out;
    wire rx_busy;
    wire rx_done;
    wire parity_error;

    integer error_count;
    integer pass_count;

    // Loopback: TX serial output connects to RX serial input.
    assign rx_in = tx_out;

    uart_controller #(
        .CLK_FREQ(CLK_FREQ),
        .DATA_WIDTH(DATA_WIDTH),
        .PARITY_ON(PARITY_ON),
        .PARITY_TYPE(PARITY_TYPE),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data_in(tx_data_in),
        .start_tx(start_tx),
        .tx_out(tx_out),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx_in(rx_in),
        .rx_data_out(rx_data_out),
        .rx_busy(rx_busy),
        .rx_done(rx_done),
        .parity_error(parity_error)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // Independent serial-line check; catches matching TX/RX mistakes.
    task automatic check_serial_frame;
        input [DATA_WIDTH-1:0] expected;
        integer bit_index;
        reg expected_parity;
        begin
            @(negedge tx_out);                 // Detect START falling edge.
            #(BIT_TIME_NS/2);                 // Center of START.
            if (tx_out !== 1'b0) begin
                $display("[FAIL] START bit at %0t", $time);
                error_count = error_count + 1;
            end

            for (bit_index = 0; bit_index < DATA_WIDTH; bit_index = bit_index + 1) begin
                #(BIT_TIME_NS);               // Center of each DATA bit.
                if (tx_out !== expected[bit_index]) begin
                    $display("[FAIL] TX D%0d: got %b, expected %b at %0t",
                             bit_index, tx_out, expected[bit_index], $time);
                    error_count = error_count + 1;
                end
            end

            if (PARITY_ON) begin
                expected_parity = (PARITY_TYPE == 0) ? ^expected : ~^expected;
                #(BIT_TIME_NS);
                if (tx_out !== expected_parity) begin
                    $display("[FAIL] TX parity: got %b, expected %b", tx_out, expected_parity);
                    error_count = error_count + 1;
                end
            end

            #(BIT_TIME_NS);                   // Center of STOP.
            if (tx_out !== 1'b1) begin
                $display("[FAIL] STOP bit at %0t", $time);
                error_count = error_count + 1;
            end
        end
    endtask

    // Send one byte and verify RX data, error flag, and completion flags.
    task automatic drive_and_check;
        input [DATA_WIDTH-1:0] expected;
        integer cycle;
        reg got_tx_done;
        reg got_rx_done;
        begin
            got_tx_done = 1'b0;
            got_rx_done = 1'b0;

            @(negedge clk);
            tx_data_in = expected;
            start_tx = 1'b1;
            @(negedge clk);
            start_tx = 1'b0;

            begin : wait_results
                for (cycle = 0; cycle < TIMEOUT_CYCLES; cycle = cycle + 1) begin
                    @(negedge clk);
                    if (tx_done === 1'b1)
                        got_tx_done = 1'b1;

                    if ((rx_done === 1'b1) && !got_rx_done) begin
                        got_rx_done = 1'b1;
                        if (rx_data_out !== expected) begin
                            $display("[FAIL] RX data: got %h, expected %h at %0t",
                                     rx_data_out, expected, $time);
                            error_count = error_count + 1;
                        end
                        if (parity_error !== 1'b0) begin
                            $display("[FAIL] Unexpected parity_error at %0t", $time);
                            error_count = error_count + 1;
                        end
                    end

                    if (got_tx_done && got_rx_done)
                        disable wait_results;
                end
            end

            if (!got_tx_done) begin
                $display("[FAIL] TX timeout for data %h", expected);
                error_count = error_count + 1;
            end
            if (!got_rx_done) begin
                $display("[FAIL] RX timeout for data %h", expected);
                error_count = error_count + 1;
            end

            // A done flag should only be high for one clk cycle.
            if (got_tx_done) begin
                @(negedge clk);
                if (tx_done !== 1'b0) begin
                    $display("[FAIL] tx_done is not a one-cycle pulse");
                    error_count = error_count + 1;
                end
            end

            repeat (CLKS_PER_BIT) @(negedge clk); // Gap before next frame.
        end
    endtask

    task automatic run_case;
        input [DATA_WIDTH-1:0] expected;
        integer errors_before;
        begin
            errors_before = error_count;
            $display("[TEST] Send %h at %0t", expected, $time);
            fork
                check_serial_frame(expected);
                drive_and_check(expected);
            join
            if (error_count == errors_before) begin
                pass_count = pass_count + 1;
                $display("[PASS] %h", expected);
            end
        end
    endtask

    initial begin
        rst_n = 1'b0;
        tx_data_in = {DATA_WIDTH{1'b0}};
        start_tx = 1'b0;
        error_count = 0;
        pass_count = 0;

        repeat (10) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        run_case(8'h55);
        run_case(8'hA6);
        run_case(8'h00);
        run_case(8'hFF);

        if (error_count == 0)
            $display("[RESULT] PASS: %0d cases passed", pass_count);
        else
            $display("[RESULT] FAIL: %0d errors, %0d cases passed", error_count, pass_count);

        $finish;
    end

    // Global watchdog: prevents an endless simulation if a frame gets stuck.
    initial begin
        #1_500_000;
        $display("[FAIL] Global simulation timeout");
        $finish;
    end

endmodule

module sequence_detector_fsm(
    input      clk,
    input      rst_n,
    input      X,
    output     Z
);

localparam  IDLE = 3'b000,
            S1   = 3'b001,
            S2   = 3'b010,
            S3   = 3'b011,
            S4   = 3'b100,
            S5   = 3'b101;

reg [2:0] current_state, next_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

always @* begin
    case (current_state)
        IDLE :next_state = X ? S1 : IDLE;
        S1 : next_state = !X ? S2 : S1;
        S2 : next_state = !X ? S3 : S1;
        S3 : next_state = X ? S4 : IDLE;
        S4 : next_state = !X ? S5 : S1;
        S5 : next_state = X ? S1 : S3;
        default : next_state = IDLE;
    endcase
end

assign Z = (current_state == S5) ? 1'b1 : 1'b0;

endmodule
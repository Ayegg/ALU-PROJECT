`timescale 1ns / 1ps

module multiplier_seq (
    input clk, rst, start,
    input [7:0] A, B,
    output [7:0] result,
    output reg done
);
    // --- SEMNALE DE CONTROL ---
    wire load, shift, add;
    wire [7:0] A_reg, B_reg, P_reg;
    wire [7:0] add_out;
    wire add_cout, add_ovf;
    wire b0_bit;

    // --- DATAPATH STRUCTURAL ---
    // 1. Registrul A (Multiplicand) - ACUM FACE SHIFT LEFT!
    wire [7:0] next_A;
    mux_2to1_8bit mux_A (.d0({A_reg[6:0], 1'b0}), .d1(A), .sel(load), .y(next_A));
    reg_8bit reg_A (.clk(clk), .rst(rst), .en(load | shift), .d(next_A), .q(A_reg));

    // 2. Registrul B (Multiplicator) - Shift Right
    wire [7:0] next_B;
    mux_2to1_8bit mux_B (.d0({1'b0, B_reg[7:1]}), .d1(B), .sel(load), .y(next_B));
    reg_8bit reg_B (.clk(clk), .rst(rst), .en(load | shift), .d(next_B), .q(B_reg));
    assign b0_bit = B_reg[0];

    // 3. Sumatorul
    add_sub_8bit adder_mult (.a(P_reg), .b(A_reg), .sub_mode(1'b0), .result(add_out), .cout(add_cout), .overflow(add_ovf));

    // 4. Acumulatorul (P) - Doar primeste adunarea, nu se mai shifteaza!
    wire [7:0] next_P;
    mux_2to1_8bit mux_P_load (.d0(add_out), .d1(8'b0), .sel(load), .y(next_P));
    reg_8bit reg_P (.clk(clk), .rst(rst), .en(load | add), .d(next_P), .q(P_reg));

    assign result = P_reg;

    // --- CONTROL UNIT (FSM) ---
    reg [1:0] state, next_state;
    reg [2:0] count;
    
    localparam IDLE = 2'b00, CALC_ADD = 2'b01, CALC_SHIFT = 2'b10, DONE = 2'b11;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            count <= 3'd0;
        end else begin
            state <= next_state;
            if (state == CALC_SHIFT) count <= count + 1'b1;
            else if (state == IDLE) count <= 3'd0;
        end
    end

    always @(*) begin
        next_state = state;
        done = 0; 
        case (state)
            IDLE: begin
                if (start) next_state = CALC_ADD;
            end
            CALC_ADD: begin
                next_state = CALC_SHIFT;
            end
            CALC_SHIFT: begin
                if (count == 3'd7) next_state = DONE;
                else next_state = CALC_ADD;
            end
            DONE: begin
                done = 1;
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Decodificare semnale pentru calea de date
    assign load = (state == IDLE && start);
    assign add  = (state == CALC_ADD && b0_bit);
    assign shift = (state == CALC_SHIFT);

endmodule


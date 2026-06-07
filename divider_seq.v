
`timescale 1ns / 1ps

// =================================================================
// 1. NUMARATOR PE 4 BITI COMPLET STRUCTURAL (Instantiaza d_ff si porti)
// =================================================================
module counter_4bit (
    input clk, rst, en, clr,
    output [3:0] q
);
    wire [3:0] d;
    wire not_q0, x1, a1, x2, a2, x3;
    wire rst_or_clr;

    // Poarta OR pentru combinarea Reset-ului global cu Clear-ul local
    or (rst_or_clr, rst, clr);

    // Logica pentru Bit 0
    not (not_q0, q[0]);
    mux_2to1 m0 (.d0(q[0]), .d1(not_q0), .sel(en), .y(d[0]));

    // Logica pentru Bit 1
    xor (x1, q[1], q[0]);
    mux_2to1 m1 (.d0(q[1]), .d1(x1), .sel(en), .y(d[1]));

    // Logica pentru Bit 2
    and (a1, q[1], q[0]);
    xor (x2, q[2], a1);
    mux_2to1 m2 (.d0(q[2]), .d1(x2), .sel(en), .y(d[2]));

    // Logica pentru Bit 3
    and (a2, q[2], a1);
    xor (x3, q[3], a2);
    mux_2to1 m3 (.d0(q[3]), .d1(x3), .sel(en), .y(d[3]));

    // Instantierea structurala a celor 4 bistabili D
    d_ff ff0 (.clk(clk), .rst(rst_or_clr), .en(1'b1), .d(d[0]), .q(q[0]));
    d_ff ff1 (.clk(clk), .rst(rst_or_clr), .en(1'b1), .d(d[1]), .q(q[1]));
    d_ff ff2 (.clk(clk), .rst(rst_or_clr), .en(1'b1), .d(d[2]), .q(q[2]));
    d_ff ff3 (.clk(clk), .rst(rst_or_clr), .en(1'b1), .d(d[3]), .q(q[3]));
endmodule


// =================================================================
// 2. MODULUL PRINCIPAL: IMPARTITOR SECVENTIAL STRUCTURAL
// =================================================================
module divider_seq (
    input clk, rst, start,
    input [7:0] A, B,     // A = Deimpartit, B = Impartitor
    output [7:0] result,  // Catul (Q)
    output reg done
);

    // Semnale de control generate de FSM
    wire load;
    wire calc_en;

    // Registri Datapath (Iesiri)
    wire [7:0] M_reg, Q_reg, Acc_reg;
    
    // Fire intermediare Datapath
    wire [7:0] next_M, next_Q, next_Acc;
    wire [7:0] acc_calc_or_hold, q_calc_or_hold;
    
    // Semnale pentru algoritmul de împartire (Restoring Division)
    wire [7:0] acc_shifted;
    wire [7:0] q_shifted;
    wire [7:0] sub_res;
    wire sub_cout;
    wire [7:0] acc_step_res;
    wire [7:0] q_step_res;

    // Semnale detectie conditii (structurale)
    wire [3:0] count;
    wire count_is_8;
    wire b_is_zero;
    wire nc2, nc1, nc0;

    // -------------------------------------------------------------
    // CALEA DE DATE STRUCTURALA (DATAPATH)
    // -------------------------------------------------------------

    // 1. REGISTRUL M (Impartitorul)
    mux_2to1_8bit mux_m (.d0(M_reg), .d1(B), .sel(load), .y(next_M));
    reg_8bit reg_M_inst (.clk(clk), .rst(rst), .en(load), .d(next_M), .q(M_reg));

    // Shiftarea combinata {Acc, Q} la stânga cu 1 bit (realizata structural prin rutare de fire)
    assign acc_shifted = {Acc_reg[6:0], Q_reg[7]};
    assign q_shifted   = {Q_reg[6:0], 1'b0};

    // 2. SCADEREA STRUCTURALA: Acc_shifted - M
    // Daca sub_cout == 1, înseamna ca Acc_shifted >= M (scaderea a fost valida în complement de 2)
    add_sub_8bit sub_div (
        .a(acc_shifted),
        .b(M_reg),
        .sub_mode(1'b1), // Forteaza modul scadere
        .result(sub_res),
        .cout(sub_cout),
        .overflow()
    );

    // MUX pentru restaurarea sau actualizarea Acumulatorului în functie de sub_cout
    mux_2to1_8bit mux_acc_step (.d0(acc_shifted), .d1(sub_res), .sel(sub_cout), .y(acc_step_res));
    
    // Introducem bitul de cat calculat la LSB-ul lui Q
    assign q_step_res = {Q_reg[6:0], sub_cout};

    // 3. REGISTRUL ACC (Acumulatorul / Restul)
    mux_2to1_8bit mux_acc_calc (.d0(Acc_reg), .d1(acc_step_res), .sel(calc_en), .y(acc_calc_or_hold));
    mux_2to1_8bit mux_acc_load (.d0(acc_calc_or_hold), .d1(8'b0), .sel(load), .y(next_Acc));
    reg_8bit reg_Acc_inst (.clk(clk), .rst(rst), .en(load | calc_en), .d(next_Acc), .q(Acc_reg));

    // 4. REGISTRUL Q (Deimpartitul / Catul)
    mux_2to1_8bit mux_q_calc (.d0(Q_reg), .d1(q_step_res), .sel(calc_en), .y(q_calc_or_hold));
    mux_2to1_8bit mux_q_load (.d0(q_calc_or_hold), .d1(A), .sel(load), .y(next_Q));
    reg_8bit reg_Q_inst (.clk(clk), .rst(rst), .en(load | calc_en), .d(next_Q), .q(Q_reg));

    // Câtul final se gaseste în registrul Q la sfârsitul operatiei
    assign result = Q_reg;

    // 5. INSTANTIERE NUMARATOR STRUCTURAL
    counter_4bit cnt_inst (.clk(clk), .rst(rst), .en(calc_en), .clr(load), .q(count));

    // Detectie structurala pentru starea Counter = 8 (4'b1000)
    not (nc2, count[2]);
    not (nc1, count[1]);
    not (nc0, count[0]);
    and (count_is_8, count[3], nc2, nc1, nc0);

    // Detectie structurala Impartire la Zero (B == 0)
    nor (b_is_zero, B[0], B[1], B[2], B[3], B[4], B[5], B[6], B[7]);


    // -------------------------------------------------------------
    // UNITATEA DE CONTROL (FSM COMPORTAMENTALA)
    // -------------------------------------------------------------
    reg [1:0] state, next_state;
    localparam IDLE = 2'b00, CALC = 2'b01, DONE_ST = 2'b10;

    always @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    always @(*) begin
        next_state = state;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    if (b_is_zero) next_state = DONE_ST; // Iesire rapida daca împartim la 0
                    else           next_state = CALC;
                end
            end
            
            CALC: begin
                if (count_is_8) next_state = DONE_ST;
            end
            
            DONE_ST: begin
                done = 1'b1;
                if (!start) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Activare semnale de comanda din starile masinii
    assign load    = (state == IDLE && start);
    assign calc_en = (state == CALC && !count_is_8);

endmodule
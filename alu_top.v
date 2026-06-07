`timescale 1ns / 1ps

module alu_top (
    input clk, rst, start,
    input [7:0] A, B,
    input [3:0] opcode,
    output [7:0] result, // Eliminat 'reg', acum e condus de fire (MUX structural)
    output done,         // Eliminat 'reg'
    output Z, N, V
);

    wire [7:0] res_add, res_sub, res_mul, res_div, res_and, res_or, res_xor, res_shl, res_shr;
    wire cout_add, ovf_add, cout_sub, ovf_sub, mul_done, div_done;

    // 1. Aritmetice simple
    add_sub_8bit adder (.a(A), .b(B), .sub_mode(1'b0), .result(res_add), .cout(cout_add), .overflow(ovf_add));
    add_sub_8bit subtractor (.a(A), .b(B), .sub_mode(1'b1), .result(res_sub), .cout(cout_sub), .overflow(ovf_sub));

    // 2. Operatii secven?iale (Înmultire si Impartire)
    multiplier_seq mult_unit (.clk(clk), .rst(rst), .start(start), .A(A), .B(B), .result(res_mul), .done(mul_done));
    divider_seq div_unit (.clk(clk), .rst(rst), .start(start), .A(A), .B(B), .result(res_div), .done(div_done));

    // 3. Logice si Shift
    logic_ops_8bit logic_unit (.a(A), .b(B), .out_and(res_and), .out_or(res_or), .out_xor(res_xor));
    shifter_8bit shift_unit (.a(A), .shift_left(res_shl), .shift_right(res_shr));

    // =================================================================
    // MUX STRUCTURAL PENTRU REZULTAT (Înlocuieste always / case)
    // =================================================================
    wire [7:0] mux_out_0_7;
    
    // Mux 8:1 pentru opcodes 0000 -> 0111
    mux_8to1_8bit mux_op_0_to_7 (
        .d0(res_add), .d1(res_sub), .d2(res_mul), .d3(res_div),
        .d4(res_and), .d5(res_or),  .d6(res_xor), .d7(res_shl),
        .sel(opcode[2:0]),
        .y(mux_out_0_7)
    );

    // Mux 2:1 final pentru a selecta intre opcodes 0-7 si opcode 8 (SHR) pe baza lui opcode[3]
    mux_2to1_8bit mux_final_res (
        .d0(mux_out_0_7), 
        .d1(res_shr), 
        .sel(opcode[3]), 
        .y(result)
    );

    // =================================================================
    // LOGICA STRUCTURALA PENTRU SEMNALUL 'DONE'
    // =================================================================
    wire is_mul, is_div, is_seq;
    wire not_op3, not_op2, not_op1, not_op0;
    
    not (not_op3, opcode[3]);
    not (not_op2, opcode[2]);
    not (not_op1, opcode[1]);
    not (not_op0, opcode[0]);

    // Detectie structurala MUL (0010) si DIV (0011)
    and (is_mul, not_op3, not_op2, opcode[1], not_op0);
    and (is_div, not_op3, not_op2, opcode[1], opcode[0]);
    or  (is_seq, is_mul, is_div); // is_seq = 1 daca facem înmultire sau împartire

    // Selectam 'done' secvential (mul_done vs div_done) pe baza lui opcode[0]
    wire seq_done;
    mux_2to1 mux_seq_done_inst (.d0(mul_done), .d1(div_done), .sel(opcode[0]), .y(seq_done));

    // Mux final pentru 'done': daca e operatie secventiala luam seq_done, altfel 1 logic
    mux_2to1 mux_done_final (.d0(1'b1), .d1(seq_done), .sel(is_seq), .y(done));

    // =================================================================
    // FLAG-URI (Logica pe porti)
    // =================================================================
    // Flag N: Traseu direct din MSB
    assign N = result[7];
    
    // Flag Z: Poarta NOR pe toti bitii rezultatului
    nor (Z, result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7]);

    // Flag V (Overflow structural): Se activeaza doar pentru ADD (0000) si SUB (0001)
    wire is_add, is_sub, is_arith, ovf_arith;
    
    and (is_add, not_op3, not_op2, not_op1, not_op0);
    and (is_sub, not_op3, not_op2, not_op1, opcode[0]);
    or  (is_arith, is_add, is_sub);

    // Mux pentru a selecta sursa de overflow
    mux_2to1 mux_ovf_arith (.d0(ovf_add), .d1(ovf_sub), .sel(opcode[0]), .y(ovf_arith));

    // Overflow e valabil doar daca suntem pe o operatie aritmetica
    and (V, ovf_arith, is_arith);

endmodule

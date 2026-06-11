`timescale 1ns / 1ps

module alu_top (
    input clk, rst, start,
    input [7:0] A, B,
    input [3:0] opcode,
    output [7:0] result, // Rezultatul e condus direct de fire (MUX), nu mai e nevoie de 'reg'
    output done,         // Semnal condus direct
    output Z, N, V       // Flag-urile de stare: Zero, Negativ, Overflow
);

    // FIRE DE LEGATURA (WIRES)
    // wire- transporta semnalul de la o iesire la o intrare
    wire [7:0] res_add, res_sub, res_mul, res_div, res_and, res_or, res_xor, res_shl, res_shr;
    wire cout_add, ovf_add, cout_sub, ovf_sub, mul_done, div_done;

    //  BLOCURILE ARITMETICE
    // Toate blocurile calculeaza in acelasi timp.
    // Variabila sub_mode ii spune modulului daca trebuie sa adune (0) sau sa scada (1).
    add_sub_8bit adder (
        .a(A), .b(B), .sub_mode(1'b0), 
        .result(res_add), .cout(cout_add), .overflow(ovf_add)
    );
    add_sub_8bit subtractor (
        .a(A), .b(B), .sub_mode(1'b1), 
        .result(res_sub), .cout(cout_sub), .overflow(ovf_sub)
    );

    //  BLOCURILE SECVENTIALE (Inmultire si Impartire)
    // Aceste operatii au nevoie de clock (clk) pentru ca dureaza mai multe cicluri de ceas.
    multiplier_seq mult_unit (
        .clk(clk), .rst(rst), .start(start), 
        .A(A), .B(B), .result(res_mul), .done(mul_done)
    );
    divider_seq div_unit (
        .clk(clk), .rst(rst), .start(start), 
        .A(A), .B(B), .result(res_div), .done(div_done)
    );

    // BLOCURILE LOGICE SI DE SHIFT (Deplasare)
    logic_ops_8bit logic_unit (
        .a(A), .b(B), 
        .out_and(res_and), .out_or(res_or), .out_xor(res_xor)
    );
    shifter_8bit shift_unit (
        .a(A), 
        .shift_left(res_shl), .shift_right(res_shr)
    );


    // MULTIPLEXOR PENTRU REZULTAT
    // Folosim MUX in loc de "if-else" sau "switch". Toate rezultatele de mai sus intra
    // in MUX, iar el alege doar unul pe baza codului de operatie (opcode) pe care il trimite la iesire.
    wire [7:0] mux_out_0_7;
    
    // MUX 8-la-1 pentru primele 8 instructiuni (opcode de la 0000 la 0111)
    // Verificam doar primii 3 biti din opcode: opcode[2:0]
    mux_8to1_8bit mux_op_0_to_7 (
        .d0(res_add), .d1(res_sub), .d2(res_mul), .d3(res_div),
        .d4(res_and), .d5(res_or),  .d6(res_xor), .d7(res_shl),
        .sel(opcode[2:0]),
        .y(mux_out_0_7)
    );

    // MUX 2-la-1 pentru a alege intre rezultatul de mai sus si Shift Right (a 9-a operatie)
    // Ne uitam la bitul 4 din opcode (opcode[3]). Daca e 1, atunci e clar operatia de Shift Right (1000).
    mux_2to1_8bit mux_final_res (
        .d0(mux_out_0_7), 
        .d1(res_shr), 
        .sel(opcode[3]), 
        .y(result)
    );


    // LOGICA PENTRU SEMNALUL 'DONE' (Gata)
    wire is_mul, is_div, is_seq;
    wire not_op3, not_op2, not_op1, not_op0;
    
    // Generam bitii inversati din opcode pentru portile logice
    not (not_op3, opcode[3]);
    not (not_op2, opcode[2]);
    not (not_op1, opcode[1]);
    not (not_op0, opcode[0]);

    // Folosim porti AND pentru a detecta daca avem inmultire (0010) sau impartire (0011)
    and (is_mul, not_op3, not_op2, opcode[1], not_op0);
    and (is_div, not_op3, not_op2, opcode[1], opcode[0]);
    
    // Daca facem inmultire SAU impartire, semnalul is_seq devine 1
    or  (is_seq, is_mul, is_div); 

    wire seq_done;
    // Selectam momentul cand e gata operatia secventiala pe baza ultimului bit din opcode
    mux_2to1 mux_seq_done_inst (.d0(mul_done), .d1(div_done), .sel(opcode[0]), .y(seq_done));

    // Daca operatia e secventiala (is_seq=1), asteptam terminarea ei.
    // Altfel, trimitem direct valoarea 1 logic (operatia se termina in acelasi ciclu).
    mux_2to1 mux_done_final (.d0(1'b1), .d1(seq_done), .sel(is_seq), .y(done));


    // CALCULARE FLAG-URI (Semnale de stare)
    
    // FLAG-UL N (Negativ): Verificam doar ultimul bit (MSB). Daca bitul 7 este 1, numarul e negativ.
    assign N = result[7];
    
    // FLAG-UL Z (Zero): Poarta NOR verifica toti bitii rezultatului.
    // NOR scoate 1 logic DOAR DACA toti bitii care intra in ea sunt 0.
    nor (Z, result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7]);

    // FLAG-UL V (Overflow): Valabil doar la adunare (0000) si scadere (0001).
    wire is_add, is_sub, is_arith, ovf_arith;
    
    // Detectam starea de adunare sau scadere
    and (is_add, not_op3, not_op2, not_op1, not_op0);
    and (is_sub, not_op3, not_op2, not_op1, opcode[0]);
    or  (is_arith, is_add, is_sub);

    // MUX-ul decide ce overflow citim (de la sumator sau de la scazator)
    mux_2to1 mux_ovf_arith (.d0(ovf_add), .d1(ovf_sub), .sel(opcode[0]), .y(ovf_arith));

    // Daca nu se face o operatie aritmetica, fortam flag-ul V sa ramana la 0.
    and (V, ovf_arith, is_arith);

endmodule

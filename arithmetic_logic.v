
// MODUL 1: ADUNARE SI SCADERE PE 8 BITI

module add_sub_8bit(
    input [7:0] a, b,
    input sub_mode, // Comutator: 0 = Adunare, 1 = Scadere
    output [7:0] result,
    output cout, overflow
);
    wire [7:0] b_mod; // Fir intern pentru valoarea modificata a lui B
    wire [8:0] c;     // Fire pentru bitii de transport (carry), de la 0 la 8
    
    // SECRETUL SCADERII IN HARDWARE (Complement fata de 2):
    // Pentru a face A - B, hardware-ul calculeaza de fapt A + (-B).
    // (-B) inseamna sa inversam toti bitii lui B si sa adunam 1.
    // Daca avem scadere (sub_mode = 1), carry-in initial (c[0]) primeste acel 1.
    assign c[0] = sub_mode; 

    // Blocul GENERATE: Este echivalentul de la compilare al unui for-loop din C sau MATLAB.
    // Nu ruleaza secvential, ci ii spune programului sa "printeze" fizic 8 sumatoare (full adders) pe placa.
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : b_invert
            // Poarta XOR functioneaza ca un invertor controlat.
            // Daca sub_mode e 0 (adunare), b_mod ramane fix b.
            // Daca sub_mode e 1 (scadere), b_mod devine b inversat (NOT b).
            xor (b_mod[i], b[i], sub_mode); 
            
            // Instantierea sumatorului complet pentru fiecare bit in parte
            full_adder fa (
                .a(a[i]), 
                .b(b_mod[i]), 
                .cin(c[i]), 
                .sum(result[i]), 
                .cout(c[i+1]) // Carry-ul iese de la bitul i si intra la i+1
            );
        end
    endgenerate

    // Carry Out final este ultimul bit din sirul de transport
    assign cout = c[8];
    
    // Overflow (Depasirea de capacitate pentru numere cu semn):
    // Daca aduni doua numere pozitive si rezultatul e negativ (sau invers).
    // Se detecteaza mereu facand XOR intre ultimul si penultimul bit de transport.
    xor (overflow, c[8], c[7]); 
endmodule


// MODUL 2: OPERATII LOGICE PE BITS (Bitwise)

module logic_ops_8bit(
    input [7:0] a, b,
    output [7:0] out_and, out_or, out_xor
);
    // Folosim din nou generate pentru a plasa portile pe placa de 8 ori.
    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin : log_inst
            // Se aplica operatia logica strict intre bitul i din a si bitul i din b
            and (out_and[i], a[i], b[i]);
            or  (out_or[i],  a[i], b[i]);
            xor (out_xor[i], a[i], b[i]);
        end
    endgenerate
endmodule


// MODUL 3: DEPLASARE (SHIFTARE) PE 8 BITI
module shifter_8bit(
    input [7:0] a,
    output [7:0] shift_left, shift_right
);
    // SHIFT IN HARDWARE = DOAR RECABLARE (Routing). Nu e nevoie de porti logice.
    // Pur si simplu lipim firele altfel decat au intrat.

    // Shift Left (Inmultire cu 2): Deplasam totul la stanga.
    // Bitul cel mai nesemnificativ (pozitia 0) este fortat la 0.
    assign shift_left[0] = 1'b0;
    // Restul bitilor de la 1 la 7 iau valoarea bitilor originali de la 0 la 6.
    assign shift_left[7:1] = a[6:0];

    // Shift Right (Impartire la 2): Deplasam totul la dreapta.
    // Bitul cel mai semnificativ (pozitia 7) este fortat la 0.
    assign shift_right[7] = 1'b0;
    // Restul bitilor de la 0 la 6 iau valoarea bitilor originali de la 1 la 7.
    assign shift_right[6:0] = a[7:1];
endmodule

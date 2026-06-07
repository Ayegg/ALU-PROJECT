
// --- Modul Adunare / Scadere pe 8 biti ---
module add_sub_8bit(
    input [7:0] a, b,
    input sub_mode, // 0 = Adunare, 1 = Scadere
    output [7:0] result,
    output cout, overflow
);
    wire [7:0] b_mod;
    wire [8:0] c;
    
    assign c[0] = sub_mode; // Carry-in este 1 pentru scadere (complement fata de 2)

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : b_invert
            xor (b_mod[i], b[i], sub_mode); // Inverseaza B daca e scadere
            full_adder fa (.a(a[i]), .b(b_mod[i]), .cin(c[i]), .sum(result[i]), .cout(c[i+1]));
        end
    endgenerate

    assign cout = c[8];
    xor (overflow, c[8], c[7]); // Detectie Overflow
endmodule

// --- Modul Operatii Logice ---
module logic_ops_8bit(
    input [7:0] a, b,
    output [7:0] out_and, out_or, out_xor
);
    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin : log_inst
            and (out_and[i], a[i], b[i]);
            or  (out_or[i],  a[i], b[i]);
            xor (out_xor[i], a[i], b[i]);
        end
    endgenerate
endmodule

// --- Shiftere ---
module shifter_8bit(
    input [7:0] a,
    output [7:0] shift_left, shift_right
);
    // Shift Left logic (adauga 0 la LSB)
    assign shift_left[0] = 1'b0;
    assign shift_left[7:1] = a[6:0];

    // Shift Right logic (adauga 0 la MSB)
    assign shift_right[7] = 1'b0;
    assign shift_right[6:0] = a[7:1];
endmodule
`timescale 1ns / 1ps

// =================================================================
// 1. BISTABIL D (D Flip-Flop) - Elementul de baza al memoriei
// =================================================================
module d_ff (
    input clk, rst, en, d,
    output reg q
);
    // Acesta e singurul bloc descris "comportamental" din tot proiectul,
    // pentru ca nu putem simula memoria doar din fire si porti logice simple.
    // La fiecare front crescator al ceasului (posedge clk), daca en=1, 
    // valoarea de pe firul 'd' este inghetata si retinuta pe iesirea 'q'.
    always @(posedge clk or posedge rst) begin
        if (rst) q <= 1'b0;  // Reset asincron (sterge valoarea instantaneu)
        else if (en) q <= d; // Salveaza noua valoare
    end
endmodule

// =================================================================
// 2. REGISTRU PE 8 BITI - Memoreaza un numar intreg
// =================================================================
module reg_8bit (
    input clk, rst, en,
    input [7:0] d,
    output [7:0] q
);
    // Pentru a memora 8 biti deodata, instantiem 8 bistabili D separati.
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : dff_inst
            d_ff flip_flop (.clk(clk), .rst(rst), .en(en), .d(d[i]), .q(q[i]));
        end
    endgenerate
endmodule

// =================================================================
// 3. SUMATOR COMPLET (Full Adder) DE 1 BIT
// =================================================================
module full_adder(
    input a, b, cin,
    output sum, cout
);
    // Implementare pura cu porti logice pentru calculul matematic A + B + CarryIn
    wire w1, w2, w3;
    
    xor (w1, a, b);
    xor (sum, w1, cin); // Rezultatul bitului curent
    
    and (w2, w1, cin);
    and (w3, a, b);
    or  (cout, w2, w3); // Semnalul de transport catre urmatorul bit (Carry Out)
endmodule

// =================================================================
// 4. MULTIPLEXOARE - "Comutatoarele" hardware-ului
// =================================================================

// MUX 2:1 pe 1 bit (Alege intre 2 fire, scoate 1)
module mux_2to1 (input d0, d1, sel, output y);
    wire w1, w2, w3;
    not (w1, sel);
    
    // Daca butonul de selectie (sel) e 0, trece d0. Daca sel e 1, trece d1.
    and (w2, d0, w1);
    and (w3, d1, sel);
    or  (y, w2, w3);
endmodule

// MUX 2:1 pe 8 biti (Alege intre doua "magistrale" groase de 8 fire)
module mux_2to1_8bit (input [7:0] d0, d1, input sel, output [7:0] y);
    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin : mux_inst
            // Foloseste 8 multiplexoare de 1 bit asezate in paralel, 
            // toate comandate simultan de acelasi semnal 'sel'.
            mux_2to1 m (.d0(d0[i]), .d1(d1[i]), .sel(sel), .y(y[i]));
        end
    endgenerate
endmodule

// MUX 8:1 pe 8 biti - Alege un singur rezultat din 8 posibile
module mux_8to1_8bit (
    input [7:0] d0, d1, d2, d3, d4, d5, d6, d7,
    input [2:0] sel,
    output [7:0] y
);
    wire [7:0] w0, w1, w2, w3, w4, w5;
    
    // Este structurat exact ca un turneu in etape (Arbore binar):
    // Nivelul 1: Sferturi de finala. Se aleg 4 "castigatori" din 8 date initiale pe baza lui sel[0]
    mux_2to1_8bit m0 (.d0(d0), .d1(d1), .sel(sel[0]), .y(w0));
    mux_2to1_8bit m1 (.d0(d2), .d1(d3), .sel(sel[0]), .y(w1));
    mux_2to1_8bit m2 (.d0(d4), .d1(d5), .sel(sel[0]), .y(w2));
    mux_2to1_8bit m3 (.d0(d6), .d1(d7), .sel(sel[0]), .y(w3));
    
    // Nivelul 2: Semifinala. Reducem cele 4 rezultate la doar 2 pe baza lui sel[1]
    mux_2to1_8bit m4 (.d0(w0), .d1(w1), .sel(sel[1]), .y(w4));
    mux_2to1_8bit m5 (.d0(w2), .d1(w3), .sel(sel[1]), .y(w5));
    
    // Nivelul 3: Finala. Alegem rezultatul final pe baza ultimului bit, sel[2]
    mux_2to1_8bit m6 (.d0(w4), .d1(w5), .sel(sel[2]), .y(y));
endmodule

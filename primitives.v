`timescale 1ns / 1ps

// --- Bistabil D cu Reset si Enable ---
module d_ff (
    input clk, rst, en, d,
    output reg q
);
    // Acesta este singurul loc unde folosim comportamental pentru a simula un hardware fizic (Bistabilul)
    always @(posedge clk or posedge rst) begin
        if (rst) q <= 1'b0;
        else if (en) q <= d;
    end
endmodule

// --- Registru pe 8 biti (instantiaza 8 bistabili D) ---
module reg_8bit (
    input clk, rst, en,
    input [7:0] d,
    output [7:0] q
);
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : dff_inst
            d_ff flip_flop (.clk(clk), .rst(rst), .en(en), .d(d[i]), .q(q[i]));
        end
    endgenerate
endmodule

// --- Sumator Complet de 1 bit (Porti logice) ---
module full_adder(
    input a, b, cin,
    output sum, cout
);
    wire w1, w2, w3;
    xor (w1, a, b);
    xor (sum, w1, cin);
    and (w2, w1, cin);
    and (w3, a, b);
    or  (cout, w2, w3);
endmodule

// --- Multiplexor 2:1 pe 1 bit ---
module mux_2to1 (input d0, d1, sel, output y);
    wire w1, w2, w3;
    not (w1, sel);
    and (w2, d0, w1);
    and (w3, d1, sel);
    or  (y, w2, w3);
endmodule

// --- Multiplexor 2:1 pe 8 bi?i ---
module mux_2to1_8bit (input [7:0] d0, d1, input sel, output [7:0] y);
    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin : mux_inst
            mux_2to1 m (.d0(d0[i]), .d1(d1[i]), .sel(sel), .y(y[i]));
        end
    endgenerate
endmodule

// --- Multiplexor 8:1 pe 8 biti (Creat structural din MUX 2:1) ---
module mux_8to1_8bit (
    input [7:0] d0, d1, d2, d3, d4, d5, d6, d7,
    input [2:0] sel,
    output [7:0] y
);
    wire [7:0] w0, w1, w2, w3, w4, w5;
    
    // Nivelul 1
    mux_2to1_8bit m0 (.d0(d0), .d1(d1), .sel(sel[0]), .y(w0));
    mux_2to1_8bit m1 (.d0(d2), .d1(d3), .sel(sel[0]), .y(w1));
    mux_2to1_8bit m2 (.d0(d4), .d1(d5), .sel(sel[0]), .y(w2));
    mux_2to1_8bit m3 (.d0(d6), .d1(d7), .sel(sel[0]), .y(w3));
    
    // Nivelul 2
    mux_2to1_8bit m4 (.d0(w0), .d1(w1), .sel(sel[1]), .y(w4));
    mux_2to1_8bit m5 (.d0(w2), .d1(w3), .sel(sel[1]), .y(w5));
    
    // Nivelul 3
    mux_2to1_8bit m6 (.d0(w4), .d1(w5), .sel(sel[2]), .y(y));
endmodule
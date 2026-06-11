`timescale 1ns / 1ps

// MODUL: INMULTITOR SECVENTIAL
module multiplier_seq (
    input clk, rst, start,
    input [7:0] A, B,
    output [7:0] result,
    output reg done
);
    // --- SEMNALE DE CONTROL ---
    // Aceste wires sunt 'comenzile' date de FSM catre Datapath
    wire load, shift, add;
    
    // Registrii care stocheaza datele pe parcursul inmultirii
    wire [7:0] A_reg, B_reg, P_reg;
    
    // Semnale pentru sumator
    wire [7:0] add_out;
    wire add_cout, add_ovf;
    
    // Extragem mereu doar primul bit din B pentru a sti daca adunam sau nu
    wire b0_bit;

    // DATAPATH 
    
    // REGISTRUL A (Deinmultitul / Multiplicand)
    // Daca dam 'load', primeste valoarea A initiala.
    // Altfel, la fiecare comanda 'shift', se deplaseaza la STANGA cu o pozitie.
    // Deplasarea la stanga e ca si cum am adauga un zero la coada numarului pe hartie.
    wire [7:0] next_A;
    mux_2to1_8bit mux_A (.d0({A_reg[6:0], 1'b0}), .d1(A), .sel(load), .y(next_A));
    reg_8bit reg_A (.clk(clk), .rst(rst), .en(load | shift), .d(next_A), .q(A_reg));

    // REGISTRUL B (Inmultitorul / Multiplicator)
    // Daca dam 'load', primeste valoarea B initiala.
    // La fiecare comanda 'shift', se deplaseaza la DREAPTA.
    // Facem asta ca sa putem verifica mereu bitul de pe pozitia 0 (b0_bit).
    wire [7:0] next_B;
    mux_2to1_8bit mux_B (.d0({1'b0, B_reg[7:1]}), .d1(B), .sel(load), .y(next_B));
    reg_8bit reg_B (.clk(clk), .rst(rst), .en(load | shift), .d(next_B), .q(B_reg));
    assign b0_bit = B_reg[0]; // Semnalul care decide daca adunam in acest pas

    // 3. SUMATORUL FIZIC
    // Aduna in mod constant valoarea actuala din A cu valoarea stocata in Acumulatorul P.
    add_sub_8bit adder_mult (
        .a(P_reg), .b(A_reg), 
        .sub_mode(1'b0), // 0 forteaza adunarea
        .result(add_out), .cout(add_cout), .overflow(add_ovf)
    );

    // ACUMULATORUL P (Produsul Partial)
    // Daca dam 'load', se reseteaza la 0.
    // Daca dam 'add', memoreaza rezultatul scos de sumator. 
    // Nu se shifteaza, pentru ca am shiftat deja registrul A!
    wire [7:0] next_P;
    mux_2to1_8bit mux_P_load (.d0(add_out), .d1(8'b0), .sel(load), .y(next_P));
    reg_8bit reg_P (.clk(clk), .rst(rst), .en(load | add), .d(next_P), .q(P_reg));

    // Rezultatul final este chiar valoarea acumulata in P
    assign result = P_reg;


    // CONTROL UNIT (FSM - Automatul de Stari)
    reg [1:0] state, next_state;
    reg [2:0] count; // Numarator pe 3 biti, merge de la 0 la 7 (8 pasi)
    
    // Definim starile posibile
    localparam IDLE = 2'b00, CALC_ADD = 2'b01, CALC_SHIFT = 2'b10, DONE = 2'b11;

    // Trecerea in starea urmatoare sincronizata cu ceasul (clk)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            count <= 3'd0;
        end else begin
            state <= next_state;
            // Incrementam numaratorul de pasi doar dupa ce am facut shiftarea
            if (state == CALC_SHIFT) count <= count + 1'b1;
            else if (state == IDLE) count <= 3'd0;
        end
    end

    // Tranzitiile
    always @(*) begin
        next_state = state;
        done = 0; 
        case (state)
            IDLE: begin
                // Asteptam butonul de start
                if (start) next_state = CALC_ADD;
            end
            CALC_ADD: begin
                // In starea asta doar facem adunarea (daca e cazul).
                // Imediat dupa, trecem direct la starea de shiftare.
                next_state = CALC_SHIFT;
            end
            CALC_SHIFT: begin
                // In starea asta shiftam registrii A si B.
                // Daca am facut 8 pasi (count a ajuns la 7), am terminat.
                // Daca nu, ne intoarcem sa adunam pentru urmatorul bit.
                if (count == 3'd7) next_state = DONE;
                else next_state = CALC_ADD;
            end
            DONE: begin
                done = 1; // Semnalizam ca produsul e gata
                // Ne intoarcem in repaus daca butonul de start nu mai e apasat
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Traducem starile FSM-ului in actiuni pentru Datapath
    // load: activ doar cand dam start in starea IDLE
    assign load  = (state == IDLE && start);
    // add: activ doar in faza de calcul si DOAR DACA bitul curent din B este 1
    assign add   = (state == CALC_ADD && b0_bit);
    // shift: activ ori de cate ori ne aflam in starea de shiftare
    assign shift = (state == CALC_SHIFT);

endmodule

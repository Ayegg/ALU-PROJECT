`timescale 1ns / 1ps


// 1. NUMARATOR PE 4 BITI (Aici numaram pasii impartirii)

module counter_4bit (
    input clk, rst, en, clr,
    output [3:0] q
);
    wire [3:0] d;
    wire not_q0, x1, a1, x2, a2, x3;
    wire rst_or_clr;

    // Poarta OR pentru a reseta numaratorul fie din butonul global (rst), 
    // fie din comanda interna de clear (clr)
    or (rst_or_clr, rst, clr);

    // LOGICA DE NUMARARE (Cum trecem de la 0 la 1, 2, 3...)
    // In loc de q = q + 1, aici facem adunarea manual, cu porti logice.
    
    // Bit 0: Se inverseaza la fiecare pas (0, 1, 0, 1...)
    not (not_q0, q[0]);
    mux_2to1 m0 (.d0(q[0]), .d1(not_q0), .sel(en), .y(d[0]));

    // Bit 1: Se schimba doar cand Bit 0 a fost 1 (folosim XOR pentru comutare)
    xor (x1, q[1], q[0]);
    mux_2to1 m1 (.d0(q[1]), .d1(x1), .sel(en), .y(d[1]));

    // Bit 2: Se schimba doar cand si Bit 1 si Bit 0 sunt 1 (Poarta AND 'a1' verifica asta)
    and (a1, q[1], q[0]);
    xor (x2, q[2], a1);
    mux_2to1 m2 (.d0(q[2]), .d1(x2), .sel(en), .y(d[2]));

    // Bit 3: Se schimba doar cand toti bitii anteriori (2, 1, 0) sunt 1
    and (a2, q[2], a1);
    xor (x3, q[3], a2);
    mux_2to1 m3 (.d0(q[3]), .d1(x3), .sel(en), .y(d[3]));

    // Dupa ce am calculat urmatoarea valoare, o salvam in bistabilii D (Memorie)
    // Bistabilul D primeste o valoare la intrarea 'd' si o scoate pe 'q' la urmatorul front de ceas.
    d_ff ff0 (.clk(clk), .rst(rst_or_clr), .en(1'b1), .d(d[0]), .q(q[0]));
    d_ff ff1 (.clk(clk), .rst(rst_or_clr), .en(1'b1), .d(d[1]), .q(q[1]));
    d_ff ff2 (.clk(clk), .rst(rst_or_clr), .en(1'b1), .d(d[2]), .q(q[2]));
    d_ff ff3 (.clk(clk), .rst(rst_or_clr), .en(1'b1), .d(d[3]), .q(q[3]));
endmodule



// 2. MODULUL PRINCIPAL: IMPARTITOR SECVENTIAL 
// Implementeaza algoritmul Restoring Division
module divider_seq (
    input clk, rst, start,
    input [7:0] A, B,     // A = Deimpartit, B = Impartitor
    output [7:0] result,  // Catul impartirii
    output reg done       // Semnalul care anunta ca am terminat
);

    // Semnale generate de automatul de stari (FSM)
    wire load;    // Incarca datele initiale
    wire calc_en; // Permite calculul efectiv

    // Registrii in care tinem datele pe parcursul celor 8 pasi
    wire [7:0] M_reg, Q_reg, Acc_reg;
    
    // Wires care transporta datele catre registri pentru urmatorul ciclu de ceas
    wire [7:0] next_M, next_Q, next_Acc;
    wire [7:0] acc_calc_or_hold, q_calc_or_hold;
    
    // Semnale folosite pentru impartire
    wire [7:0] acc_shifted;
    wire [7:0] q_shifted;
    wire [7:0] sub_res;
    wire sub_cout;
    wire [7:0] acc_step_res;
    wire [7:0] q_step_res;

    // Detectie conditii logice
    wire [3:0] count;
    wire count_is_8;
    wire b_is_zero;
    wire nc2, nc1, nc0;

    // REGISTRUL M (Tine Impartitorul)
    // Daca 'load' e 1, incarcam valoarea B. Altfel, isi pastreaza valoarea veche (M_reg).
    mux_2to1_8bit mux_m (.d0(M_reg), .d1(B), .sel(load), .y(next_M));
    reg_8bit reg_M_inst (.clk(clk), .rst(rst), .en(load), .d(next_M), .q(M_reg));

    // PRINCIPIUL IMPARTIRII: Shiftam Q (deimpartitul) in Acc (restul partial) bit cu bit.
    // Shiftarea se face simplu, prin mutarea wires la stanga.
    assign acc_shifted = {Acc_reg[6:0], Q_reg[7]};
    assign q_shifted   = {Q_reg[6:0], 1'b0};

    // INCERCAM SA SCADEM IMPARTITORUL DIN RESTUL PARTIAL
    // Daca scaderea are succes (sub_cout == 1), inseamna ca incape.
    add_sub_8bit sub_div (
        .a(acc_shifted),
        .b(M_reg),
        .sub_mode(1'b1), // 1 forteaza modulul sa faca scadere
        .result(sub_res),
        .cout(sub_cout),
        .overflow()
    );

    // Daca a incaput (sub_cout=1), pastram rezultatul scaderii in Acumulator.
    // Daca nu a incaput (sub_cout=0), restauram valoarea de dinainte de scadere (acc_shifted).
    mux_2to1_8bit mux_acc_step (.d0(acc_shifted), .d1(sub_res), .sel(sub_cout), .y(acc_step_res));
    
    // Noul bit al catului este fix 'sub_cout' (1 daca a incaput, 0 daca nu). Il bagam in Q.
    assign q_step_res = {Q_reg[6:0], sub_cout};

    // REGISTRUL ACC (Restul)
    mux_2to1_8bit mux_acc_calc (.d0(Acc_reg), .d1(acc_step_res), .sel(calc_en), .y(acc_calc_or_hold));
    mux_2to1_8bit mux_acc_load (.d0(acc_calc_or_hold), .d1(8'b0), .sel(load), .y(next_Acc));
    // Daca suntem in faza de incarcare SAU calcul, dam 'enable' la registru
    reg_8bit reg_Acc_inst (.clk(clk), .rst(rst), .en(load | calc_en), .d(next_Acc), .q(Acc_reg));

    // 4. REGISTRUL Q (Tine Deimpartitul la inceput, apoi se umple cu Catul)
    mux_2to1_8bit mux_q_calc (.d0(Q_reg), .d1(q_step_res), .sel(calc_en), .y(q_calc_or_hold));
    mux_2to1_8bit mux_q_load (.d0(q_calc_or_hold), .d1(A), .sel(load), .y(next_Q));
    reg_8bit reg_Q_inst (.clk(clk), .rst(rst), .en(load | calc_en), .d(next_Q), .q(Q_reg));

    // Rezultatul final este Catul, care s-a format in Q
    assign result = Q_reg;

    // 5. NUMARATORUL - Ne opreste dupa 8 pasi (pentru ca lucram pe 8 biti)
    counter_4bit cnt_inst (.clk(clk), .rst(rst), .en(calc_en), .clr(load), .q(count));

    // Cand ajunge la 8 (in binar 1000), count_is_8 devine 1
    not (nc2, count[2]);
    not (nc1, count[1]);
    not (nc0, count[0]);
    and (count_is_8, count[3], nc2, nc1, nc0);

    // Protectie: Daca incercam sa impartim la 0, toate portile scot 0 si detectam eroarea
    nor (b_is_zero, B[0], B[1], B[2], B[3], B[4], B[5], B[6], B[7]);


   
    // FSM (AUTOMATUL DE STARI) 
    reg [1:0] state, next_state;
    // Cele 3 stari posibile: In repaus (IDLE), Calculeaza (CALC), Gata (DONE)
    localparam IDLE = 2'b00, CALC = 2'b01, DONE_ST = 2'b10;

    // Trecerea de la o stare la alta se face doar pe frontul crescator al ceasului
    always @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    // Logica de tranzitie (Cum decidem unde mergem)
    always @(*) begin
        next_state = state; // Implicit ramane in aceeasi stare
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    // Daca am primit comanda start, dar B e 0, sarim direct la DONE ca sa nu blocam sistemul
                    if (b_is_zero) next_state = DONE_ST; 
                    else           next_state = CALC;
                end
            end
            
            CALC: begin
                // Stam in CALC pana cand numaratorul zice ca am facut 8 pasi
                if (count_is_8) next_state = DONE_ST;
            end
            
            DONE_ST: begin
                done = 1'b1; // Ridicam flag-ul de final
                // Ne intoarcem la IDLE doar dupa ce butonul de start a fost eliberat
                if (!start) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Semnalele de comanda pleaca catre Datapath in functie de starea in care ne aflam
    assign load    = (state == IDLE && start);
    assign calc_en = (state == CALC && !count_is_8);

endmodule

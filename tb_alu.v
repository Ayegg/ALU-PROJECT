`timescale 1ns / 1ps

module tb_alu();

    reg clk, rst, start;
    reg [7:0] A, B;
    reg [3:0] opcode;
    
    wire [7:0] result;
    wire done, Z, N, V;

    // INSTANTIEREA MODULULUI 
    // Aducem ALU-ul creat de noi si ii conectam pinii la variabilele de mai sus.
    alu_top uut (
        .clk(clk), .rst(rst), .start(start),
        .A(A), .B(B), .opcode(opcode),
        .result(result), .done(done),
        .Z(Z), .N(N), .V(V)
    );

    // GENERAREA CEASULUI (Clock)
    initial clk = 0;       // Pornim de la 0
    always #5 clk = ~clk;  // La fiecare 5 nanosecunde, semnalul se inverseaza (0, 1, 0, 1...). 
                           // Asta creeaza o perioada completa de 10ns.

    // TESTARE
    // Blocul 'initial' se executa o singura data, secvential (linie cu linie).
    initial begin
        // Resetam sistemul pentru a curata memoria
        rst = 1; start = 0; A = 0; B = 0; opcode = 0;
        #10 rst = 0; // Asteptam 10ns si oprim reset-ul

        // 1. ADUNARE: 15 + 10 = 25
        // Dam valorile si asteptam putin (#1) pentru ca semnalul sa strabata portile logice.
        #10 A = 8'd15; B = 8'd10; opcode = 4'b0000;
        #1 $display("1. ADD: A=%d, B=%d, Result=%d", A, B, result);

        // 2. SCADERE: 20 - 5 = 15
        #10 A = 8'd20; B = 8'd5; opcode = 4'b0001;
        #1 $display("2. SUB: A=%d, B=%d, Result=%d", A, B, result);

        // 3. INMULTIRE: 6 * 4 = 24 
        // Aici dam un impuls scurt pe butonul de 'start' 
        #10 A = 8'd6; B = 8'd4; opcode = 4'b0010; start = 1;
        #10 start = 0; // Luam degetul de pe buton
        // Inmultirea dureaza mai multe cicluri de ceas, asa ca punem simulatorul pe pauza
        // pana cand modulul spune 'done' (done == 1).
        wait(done == 1'b1);
        #1 $display("3. MUL: A=%d, B=%d, Result=%d", A, B, result);

        // 4. IMPARTIRE: 25 / 5 = 5 
        // La fel ca la inmultire, trebuie sa asteptam semnalul de finalizare.
        #10 A = 8'd25; B = 8'd5; opcode = 4'b0011; start = 1;
        #10 start = 0;
        wait(done == 1'b1);
        #1 $display("4. DIV: A=%d, B=%d, Result=%d", A, B, result);

        // 5. AND
        #10 A = 8'b11001100; B = 8'b10101010; opcode = 4'b0100;
        #1 $display("5. AND: A=%b, B=%b, Result=%b", A, B, result);

        // 6. OR
        #10 opcode = 4'b0101;
        #1 $display("6. OR : A=%b, B=%b, Result=%b", A, B, result);

        // 7. XOR
        #10 opcode = 4'b0110;
        #1 $display("7. XOR: A=%b, B=%b, Result=%b", A, B, result);

        // 8. SHIFT LEFT
        #10 A = 8'b00001111; opcode = 4'b0111;
        #1 $display("8. SHL: A=%b, Result=%b", A, result);

        // 9. SHIFT RIGHT
        #10 opcode = 4'b1000;
        #1 $display("9. SHR: A=%b, Result=%b", A, result);

        // Oprim simularea
        #20 $stop;
    end
endmodule

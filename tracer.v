module bcomp_alu(
    input ps_c, // Carry bit from program state
    input [15:0] left, // Left bus input
    input [15:0] right, // Right bus input
    input coml, // Complement left input
    input comr, // Complement right input
    input sora, // Sum or AND
    input pls1, // Plus 1
    output [18:0] aluout // 15:0 = operation result, 16 = carry out, 17 = 14th bit carry out, 18 = PS carry bit
);
    wire [15:0] nleft, nright, sum, product;
    assign nleft = coml ? ~left : left, // invert left
        nright = comr ? ~right : right; // invert right
    
    add16 summator(.a(nleft), .b(nright), .cin(pls1), .sum(sum), .c14out(aluout[17]), .c15out(aluout[16])); // sum
    assign product = nleft & nright; // and
    
    assign aluout[15:0] = sora ? product : sum;
    assign aluout[18] = ps_c;
endmodule

module bcomp_commutator(
    input [18:0] aluout, // ALU operation result
    input ltol, // Low byte to low byte
    input ltoh, // Low byte to high byte
    input htol, // High byte to low byte
    input htoh, // High byte to high byte
    input sext, // Low byte sign extend
    input shlt, // Shift left
    input shl0, // Put PS carry bit into 0th pos
    input shrt, // Shift right
    input shrf, // Shift right with carry flag (?)
    output [17:0] comout // 15:0 = operation result, 16 = carry out, 17 = 14th bit carry out
);
    assign comout[7:0] = ltol ? aluout[7:0] : // LTOL
        htol ? aluout[15:8] : // HTOH
        shlt ? {aluout[6:0], shl0 & aluout[18]} : // ROL or ASL
        shrt ? aluout[8:1] : 0, // ROR or ASR
        
        comout[15:8] = htoh ? aluout[15:8] : // HTOH
        ltoh ? aluout[7:0] : // LTOH
        sext ? {8{aluout[7]}} : // SXTB
        shlt ? aluout[14:7] : // ROL or ASL
        shrt ? {shrf ? aluout[18] : aluout[15], aluout[15:9]} : 0, // ROR or ASR
        
        comout[17:16] = htoh ? aluout[17:16] : // HTOH
        shlt ? {aluout[14], aluout[15]} : // ROL or ASL
        ({comout[15] & shrf, aluout[0] & shrt}); // ROR or ASR
endmodule

module bcomp_flags(
    input [17:0] comout, // Commutator operation result
    input setc, // Set carry flag
    input setv, // Set overflow flag
    input stnz, // Set zero and negative flags
    output [3:0] nzvc // {N, Z, V, C} flags
);
    assign nzvc = {stnz & comout[15], // N
                   stnz & ~(comout[0] | comout[1] | comout[2] | comout[3] | 
                            comout[4] | comout[5] | comout[6] | comout[7] | 
                            comout[8] | comout[9] | comout[10] | comout[11] | 
                            comout[12] | comout[13] | comout[14] | comout[15]), // Z
                   setv & (comout[17] ^ comout[16]), // V
                   setc & comout[16]}; // C
endmodule

module add16(input [15:0] a, input [15:0] b, input cin, output [15:0] sum, output c14out, output c15out);
    wire c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13;
    add1 add0s(.a(a[0]), .b(b[0]), .cin(cin), .sum(sum[0]), .cout(c0)),
    add1s(.a(a[1]), .b(b[1]), .cin(c0), .sum(sum[1]), .cout(c1)),
    add2s(.a(a[2]), .b(b[2]), .cin(c1), .sum(sum[2]), .cout(c2)),
    add3s(.a(a[3]), .b(b[3]), .cin(c2), .sum(sum[3]), .cout(c3)),
    add4s(.a(a[4]), .b(b[4]), .cin(c3), .sum(sum[4]), .cout(c4)),
    add5s(.a(a[5]), .b(b[5]), .cin(c4), .sum(sum[5]), .cout(c5)),
    add6s(.a(a[6]), .b(b[6]), .cin(c5), .sum(sum[6]), .cout(c6)),
    add7s(.a(a[7]), .b(b[7]), .cin(c6), .sum(sum[7]), .cout(c7)),
    add8s(.a(a[8]), .b(b[8]), .cin(c7), .sum(sum[8]), .cout(c8)),
    add9s(.a(a[9]), .b(b[9]), .cin(c8), .sum(sum[9]), .cout(c9)),
    add10s(.a(a[10]), .b(b[10]), .cin(c9), .sum(sum[10]), .cout(c10)),
    add11s(.a(a[11]), .b(b[11]), .cin(c10), .sum(sum[11]), .cout(c11)),
    add12s(.a(a[12]), .b(b[12]), .cin(c11), .sum(sum[12]), .cout(c12)),
    add13s(.a(a[13]), .b(b[13]), .cin(c12), .sum(sum[13]), .cout(c13)),
    add14s(.a(a[14]), .b(b[14]), .cin(c13), .sum(sum[14]), .cout(c14out)),
    add15s(.a(a[15]), .b(b[15]), .cin(c14out), .sum(sum[15]), .cout(c15out));
endmodule

module add1(input a, input b, input cin, output sum, output cout);
    assign sum = a ^ b ^ cin,
        cout = cin & (a ^ b) | a & b;
endmodule

module bcomp_control_unit(
    input clk, // Clock signal
    input rst // Reset signal
);
    // Control bit positions in microcode commands, see lecture slides #3 (94-95)
    integer RDDR = 40'd00;
    integer RDCR = 40'd01;
    integer RDIP = 40'd02;
    integer RDSP = 40'd03;
    integer RDAC = 40'd04;
    integer RDBR = 40'd05;
    integer RDPS = 40'd06;
    integer COMR = 40'd08;
    integer COML = 40'd09;
    integer PLS1 = 40'd10;
    integer SORA = 40'd11;
    integer LTOL = 40'd12;
    integer LTOH = 40'd13;
    integer HTOL = 40'd14;
    integer HTOH = 40'd15;
    integer SEXT = 40'd16;
    integer SHLT = 40'd17;
    integer SHL0 = 40'd18;
    integer SHRT = 40'd19;
    integer SHRF = 40'd20;
    integer SETC = 40'd21;
    integer SETV = 40'd22;
    integer STNZ = 40'd23;
    integer WRDR = 40'd24;
    integer WRCR = 40'd25;
    integer WRIP = 40'd26;
    integer WRSP = 40'd27;
    integer WRAC = 40'd28;
    integer WRBR = 40'd29;
    integer WRPS = 40'd30;
    integer WRAR = 40'd31;
    integer LOAD = 40'd32;
    integer STOR = 40'd33;
    integer HALT = 40'd38;
    integer TYPE = 40'd39;
    
    reg [39:0] mcmemory [255:0]; // Microcode memory, 256 cells, 40 bits each
    reg [7:0] mcp; // Microcode command pointer
    
    wire [39:0] mc; // Current microcommand
    assign mc = mcmemory[mcp];
    
    reg [15:0] main_memory [2047:0]; // Programmer-accessible memory, 2048 cells, 16 bits each
    reg [10:0] ar, ip, sp; // 11-bit address register, instruction and stack pointers
    reg [15:0] ac, br, dr, cr; // 16-bit accumulator, buffer, data and command registers
    reg [8:0] ps; // 9-bit program state
    
    wire [15:0] alu_left_in, alu_right_in; // ALU inputs
    
    assign alu_left_in = mc[RDAC] ? ac : mc[RDBR] ? br : mc[RDPS] ? {7'b0, ps} : 0; // assign left alu input
    assign alu_right_in = mc[RDDR] ? dr : mc[RDCR] ? cr : mc[RDIP] ? ip : mc[RDSP] ? sp : 0; // assign right alu input
    
    wire [18:0] aluout; // ALU output -> commutator input
    wire [17:0] comout; // Commutator output -> flags input
    wire [3:0] nzvc; // Flags output
    
    bcomp_alu alu(.ps_c(ps[0]), .left(alu_left_in), .right(alu_right_in), .coml(mc[COML]), .comr(mc[COMR]), .sora(mc[SORA]), .pls1(mc[PLS1]), .aluout(aluout));
    bcomp_commutator com(.aluout(aluout), .ltol(mc[LTOL]), .ltoh(mc[LTOH]), .htol(mc[HTOL]), .htoh(mc[HTOH]), .sext(mc[SEXT] & ~mc[39]), .shlt(mc[SHLT] & ~mc[39]), .shl0(mc[SHL0] & ~mc[39]), .shrt(mc[SHRT] & ~mc[39]), .shrf(mc[SHRF] & ~mc[39]), .comout(comout));
    bcomp_flags flags(.comout(comout), .setc(mc[SETC]), .setv(mc[SETV]), .stnz(mc[STNZ]), .nzvc(nzvc));

    wire comparing_bit; // If low byte from commutator and field for bit choosing are equals
    wire [7:0] mcp_new; // New mcp address if mc[32] and comparing bit are equals
    wire mcp_bit; // Set to 1 if mcp_new is 0
    
    assign comparing_bit = mc[16] & comout[0] | mc[17] & comout[1] | mc[18] & comout[2] | mc[19] & comout[3] | mc[20] & comout[4] | mc[21] & comout[5] | mc[22] & comout[6] | mc[23] & comout[7];
    assign mcp_new = mc[TYPE] & (mc[32] == comparing_bit) ? mc[31:24] : 0;
    assign mcp_bit = ~(mcp_new[0] | mcp_new[1] | mcp_new[2] | mcp_new[3] | mcp_new[4] | mcp_new[5] | mcp_new[6] | mcp_new[7]);
    
    // The code in this block is executed each time the clock signal transitions from 0 to 1
    always @(posedge clk) begin
        // If the reset bit is 1, registers and memory should be set to their initial values 
        if (rst) begin
            // Set the PS(W) bit to 1 by default
            ps <= 9'b010000000; 
            // Set the microcode command poiner to INFETCH
            mcp <= 1;
            // Reset registers to their initial values
            ac <= 16'h0;
            br <= 16'h0;
            dr <= 16'h0;
            cr <= 16'h0;
            ip <= 11'h0;
            sp <= 11'h0;
            ar <= 11'h0;
            // Fill the microcode memory (Address + Microcommand + Label + Decoding)
            mcmemory[0] <= 40'h4000000000;   // 00 4000000000             Halt
            mcmemory[1] <= 40'h00A0009004;   // 01 00A0009004 INFETCH     IP ? BR, AR
            mcmemory[2] <= 40'h0104009420;   // 02 0104009420             BR + 1 ? IP; MEM(AR) ? DR
            mcmemory[3] <= 40'h0002009001;   // 03 0002009001             DR ? CR
            mcmemory[4] <= 40'h8109804002;   // 04 8109804002             if CR(15) = 1 then GOTO CHKBR @ 09
            mcmemory[5] <= 40'h810C404002;   // 05 810C404002             if CR(14) = 1 then GOTO CHKABS @ 0C
            mcmemory[6] <= 40'h810C204002;   // 06 810C204002             if CR(13) = 1 then GOTO CHKABS @ 0C
            mcmemory[7] <= 40'h8078104002;   // 07 8078104002             if CR(12) = 0 then GOTO ADDRLESS @ 78
            mcmemory[8] <= 40'h80C2101040;   // 08 80C2101040             GOTO IO @ C2
            mcmemory[9] <= 40'h800C404002;   // 09 800C404002 CHKBR       if CR(14) = 0 then GOTO CHKABS @ 0C
            mcmemory[10] <= 40'h800C204002;  // 0A 800C204002             if CR(13) = 0 then GOTO CHKABS @ 0C
            mcmemory[11] <= 40'h8157104002;  // 0B 8157104002             if CR(12) = 1 then GOTO BRANCHES @ 57
            mcmemory[12] <= 40'h8024084002;  // 0C 8024084002 CHKABS      if CR(11) = 0 then GOTO OPFETCH @ 24
            mcmemory[13] <= 40'h0020011002;  // 0D 0020011002 ADFETCH     extend sign CR(0..7) ? BR
            mcmemory[14] <= 40'h811C044002;  // 0E 811C044002             if CR(10) = 1 then GOTO T11XX @ 1C
            mcmemory[15] <= 40'h0080009024;  // 0F 0080009024 T10XX       BR + IP ? AR
            mcmemory[16] <= 40'h0100000000;  // 10 0100000000             MEM(AR) ? DR
            mcmemory[17] <= 40'h8114024002;  // 11 8114024002             if CR(9) = 1 then GOTO T101X @ 14
            mcmemory[18] <= 40'h81E0014002;  // 12 81E0014002 T100X       if CR(8) = 1 then GOTO RESERVED @ E0
            mcmemory[19] <= 40'h8024101040;  // 13 8024101040 T1000       GOTO OPFETCH @ 24
            mcmemory[20] <= 40'h8119014002;  // 14 8119014002 T101X       if CR(8) = 1 then GOTO T1011 @ 19
            mcmemory[21] <= 40'h0001009401;  // 15 0001009401 T1010       DR + 1 ? DR
            mcmemory[22] <= 40'h0200000000;  // 16 0200000000             DR ? MEM(AR)
            mcmemory[23] <= 40'h0001009201;  // 17 0001009201             ~0 + DR ? DR
            mcmemory[24] <= 40'h8024101040;  // 18 8024101040             GOTO OPFETCH @ 24
            mcmemory[25] <= 40'h0001009201;  // 19 0001009201 T1011       ~0 + DR ? DR
            mcmemory[26] <= 40'h0200000000;  // 1A 0200000000             DR ? MEM(AR)
            mcmemory[27] <= 40'h8024101040;  // 1B 8024101040             GOTO OPFETCH @ 24
            mcmemory[28] <= 40'h8120024002;  // 1C 8120024002 T11XX       if CR(9) = 1 then GOTO T111X @ 20
            mcmemory[29] <= 40'h81E0014002;  // 1D 81E0014002 T110X       if CR(8) = 1 then GOTO RESERVED @ E0
            mcmemory[30] <= 40'h0001009028;  // 1E 0001009028 T1100       BR + SP ? DR
            mcmemory[31] <= 40'h8024101040;  // 1F 8024101040             GOTO OPFETCH @ 24
            mcmemory[32] <= 40'h8023014002;  // 20 8023014002 T111X       if CR(8) = 0 then GOTO T1110 @ 23
            mcmemory[33] <= 40'h0001009020;  // 21 0001009020 T1111       BR ? DR
            mcmemory[34] <= 40'h8028101040;  // 22 8028101040             GOTO EXEC @ 28
            mcmemory[35] <= 40'h0001009024;  // 23 0001009024 T1110       BR + IP ? DR
            mcmemory[36] <= 40'h8026804002;  // 24 8026804002 OPFETCH     if CR(15) = 0 then GOTO RDVALUE @ 26
            mcmemory[37] <= 40'h814A404002;  // 25 814A404002             if CR(14) = 1 then GOTO CMD11XX @ 4A
            mcmemory[38] <= 40'h0080009001;  // 26 0080009001 RDVALUE     DR ? AR
            mcmemory[39] <= 40'h0100000000;  // 27 0100000000             MEM(AR) ? DR
            mcmemory[40] <= 40'h813C804002;  // 28 813C804002 EXEC        if CR(15) = 1 then GOTO CMD1XXX @ 3C
            mcmemory[41] <= 40'h8130404002;  // 29 8130404002 CMD0XXX     if CR(14) = 1 then GOTO CMD01XX @ 30
            mcmemory[42] <= 40'h812D104002;  // 2A 812D104002 CMD000X     if CR(12) = 1 then GOTO OR @ 2D
            mcmemory[43] <= 40'h0010C09811;  // 2B 0010C09811 AND         AC & DR ? AC, N, Z, V
            mcmemory[44] <= 40'h80C4101040;  // 2C 80C4101040             GOTO INT @ C4
            mcmemory[45] <= 40'h0020009B11;  // 2D 0020009B11 OR          ~AC & ~DR ? BR
            mcmemory[46] <= 40'h0010C09220;  // 2E 0010C09220             ~BR ? AC, N, Z, V
            mcmemory[47] <= 40'h80C4101040;  // 2F 80C4101040             GOTO INT @ C4
            mcmemory[48] <= 40'h8137204002;  // 30 8137204002 CMD01XX     if CR(13) = 1 then GOTO CMD011X @ 37
            mcmemory[49] <= 40'h8134104002;  // 31 8134104002 CMD010X     if CR(12) = 1 then GOTO ADC @ 34
            mcmemory[50] <= 40'h0010E09011;  // 32 0010E09011 ADD         AC + DR ? AC, N, Z, V, C
            mcmemory[51] <= 40'h80C4101040;  // 33 80C4101040             GOTO INT @ C4
            mcmemory[52] <= 40'h8032011040;  // 34 8032011040 ADC         if PS(C) = 0 then GOTO ADD @ 32
            mcmemory[53] <= 40'h0010E09411;  // 35 0010E09411             AC + DR + 1 ? AC, N, Z, V, C
            mcmemory[54] <= 40'h80C4101040;  // 36 80C4101040             GOTO INT @ C4
            mcmemory[55] <= 40'h813A104002;  // 37 813A104002 CMD011X     if CR(12) = 1 then GOTO CMP @ 3A
            mcmemory[56] <= 40'h0010E09511;  // 38 0010E09511 SUB         AC + ~DR + 1 ? AC, N, Z, V, C
            mcmemory[57] <= 40'h80C4101040;  // 39 80C4101040             GOTO INT @ C4
            mcmemory[58] <= 40'h0000E09511;  // 3A 0000E09511 CMP         AC + ~DR + 1 ? N, Z, V, C
            mcmemory[59] <= 40'h80C4101040;  // 3B 80C4101040             GOTO INT @ C4
            mcmemory[60] <= 40'h8143204002;  // 3C 8143204002 CMD1XXX     if CR(13) = 1 then GOTO CMD101X @ 43
            mcmemory[61] <= 40'h81E0104002;  // 3D 81E0104002 CMD100X     if CR(12) = 1 then GOTO RESERVED @ E0
            mcmemory[62] <= 40'h0001009201;  // 3E 0001009201 LOOP        ~0 + DR ? DR
            mcmemory[63] <= 40'h0220009201;  // 3F 0220009201             ~0 + DR ? BR; DR ? MEM(AR)
            mcmemory[64] <= 40'h80C4804020;  // 40 80C4804020             if BR(15) = 0 then GOTO INT @ C4
            mcmemory[65] <= 40'h0004009404;  // 41 0004009404             IP + 1 ? IP
            mcmemory[66] <= 40'h80C4101040;  // 42 80C4101040             GOTO INT @ C4
            mcmemory[67] <= 40'h8146104002;  // 43 8146104002 CMD101X     if CR(12) = 1 then GOTO SWAM @ 46
            mcmemory[68] <= 40'h0010C09001;  // 44 0010C09001 LD          DR ? AC, N, Z, V
            mcmemory[69] <= 40'h80C4101040;  // 45 80C4101040             GOTO INT @ C4
            mcmemory[70] <= 40'h0020009001;  // 46 0020009001 SWAM        DR ? BR
            mcmemory[71] <= 40'h0001009010;  // 47 0001009010             AC ? DR
            mcmemory[72] <= 40'h0210C09020;  // 48 0210C09020             BR ? AC, N, Z, V; DR ? MEM(AR)
            mcmemory[73] <= 40'h80C4101040;  // 49 80C4101040             GOTO INT @ C4
            mcmemory[74] <= 40'h8153204002;  // 4A 8153204002 CMD11XX     if CR(13) = 1 then GOTO ST @ 53
            mcmemory[75] <= 40'h814E104002;  // 4B 814E104002 CMD110X     if CR(12) = 1 then GOTO CALL @ 4E
            mcmemory[76] <= 40'h0004009001;  // 4C 0004009001 JUMP        DR ? IP
            mcmemory[77] <= 40'h80C4101040;  // 4D 80C4101040             GOTO INT @ C4
            mcmemory[78] <= 40'h0020009001;  // 4E 0020009001 CALL        DR ? BR
            mcmemory[79] <= 40'h0001009004;  // 4F 0001009004             IP ? DR
            mcmemory[80] <= 40'h0004009020;  // 50 0004009020             BR ? IP
            mcmemory[81] <= 40'h0088009208;  // 51 0088009208 PUSHVAL     ~0 + SP ? SP, AR
            mcmemory[82] <= 40'h8055101040;  // 52 8055101040             GOTO STORE @ 55
            mcmemory[83] <= 40'h0080009001;  // 53 0080009001 ST          DR ? AR
            mcmemory[84] <= 40'h0001009010;  // 54 0001009010             AC ? DR
            mcmemory[85] <= 40'h0200000000;  // 55 0200000000 STORE       DR ? MEM(AR)
            mcmemory[86] <= 40'h80C4101040;  // 56 80C4101040             GOTO INT @ C4
            mcmemory[87] <= 40'h8171084002;  // 57 8171084002 BRANCHES    if CR(11) = 1 then GOTO BR1XXX @ 71
            mcmemory[88] <= 40'h8166044002;  // 58 8166044002 BR0XXX      if CR(10) = 1 then GOTO BR01XX @ 66
            mcmemory[89] <= 40'h8161024002;  // 59 8161024002 BR00XX      if CR(9) = 1 then GOTO BR001X @ 61
            mcmemory[90] <= 40'h815F014002;  // 5A 815F014002 BR000X      if CR(8) = 1 then GOTO BNE @ 5F
            mcmemory[91] <= 40'h80C4041040;  // 5B 80C4041040 BEQ         if PS(Z) = 0 then GOTO INT @ C4
            mcmemory[92] <= 40'h0020011002;  // 5C 0020011002 BR          extend sign CR(0..7) ? BR
            mcmemory[93] <= 40'h0004009024;  // 5D 0004009024             BR + IP ? IP
            mcmemory[94] <= 40'h80C4101040;  // 5E 80C4101040             GOTO INT @ C4
            mcmemory[95] <= 40'h805C041040;  // 5F 805C041040 BNE         if PS(Z) = 0 then GOTO BR @ 5C
            mcmemory[96] <= 40'h80C4101040;  // 60 80C4101040             GOTO INT @ C4
            mcmemory[97] <= 40'h8164014002;  // 61 8164014002 BR001X      if CR(8) = 1 then GOTO BPL @ 64
            mcmemory[98] <= 40'h815C081040;  // 62 815C081040 BMI         if PS(N) = 1 then GOTO BR @ 5C
            mcmemory[99] <= 40'h80C4101040;  // 63 80C4101040             GOTO INT @ C4
            mcmemory[100] <= 40'h805C081040; // 64 805C081040 BPL         if PS(N) = 0 then GOTO BR @ 5C
            mcmemory[101] <= 40'h80C4101040; // 65 80C4101040             GOTO INT @ C4
            mcmemory[102] <= 40'h816C024002; // 66 816C024002 BR01XX      if CR(9) = 1 then GOTO BR011X @ 6C
            mcmemory[103] <= 40'h816A014002; // 67 816A014002 BR010X      if CR(8) = 1 then GOTO BCC @ 6A
            mcmemory[104] <= 40'h815C011040; // 68 815C011040 BCS         if PS(C) = 1 then GOTO BR @ 5C
            mcmemory[105] <= 40'h80C4101040; // 69 80C4101040             GOTO INT @ C4
            mcmemory[106] <= 40'h805C011040; // 6A 805C011040 BCC         if PS(C) = 0 then GOTO BR @ 5C
            mcmemory[107] <= 40'h80C4101040; // 6B 80C4101040             GOTO INT @ C4
            mcmemory[108] <= 40'h816F014002; // 6C 816F014002 BR011X      if CR(8) = 1 then GOTO BVC @ 6F
            mcmemory[109] <= 40'h815C021040; // 6D 815C021040 BVS         if PS(V) = 1 then GOTO BR @ 5C
            mcmemory[110] <= 40'h80C4101040; // 6E 80C4101040             GOTO INT @ C4
            mcmemory[111] <= 40'h805C021040; // 6F 805C021040 BVC         if PS(V) = 0 then GOTO BR @ 5C
            mcmemory[112] <= 40'h80C4101040; // 70 80C4101040             GOTO INT @ C4
            mcmemory[113] <= 40'h81E0044002; // 71 81E0044002 BR1XXX      if CR(10) = 1 then GOTO RESERVED @ E0
            mcmemory[114] <= 40'h81E0024002; // 72 81E0024002 BR10XX      if CR(9) = 1 then GOTO RESERVED @ E0
            mcmemory[115] <= 40'h8176014002; // 73 8176014002 BR100X      if CR(8) = 1 then GOTO BGE @ 76
            mcmemory[116] <= 40'h806D081040; // 74 806D081040 BLT         if PS(N) = 0 then GOTO BVS @ 6D
            mcmemory[117] <= 40'h806F101040; // 75 806F101040             GOTO BVC @ 6F
            mcmemory[118] <= 40'h806F081040; // 76 806F081040 BGE         if PS(N) = 0 then GOTO BVC @ 6F
            mcmemory[119] <= 40'h806D101040; // 77 806D101040             GOTO BVS @ 6D
            mcmemory[120] <= 40'h81A4084002; // 78 81A4084002 ADDRLESS    if CR(11) = 1 then GOTO AL1XXX @ A4
            mcmemory[121] <= 40'h8189044002; // 79 8189044002 AL0XXX      if CR(10) = 1 then GOTO AL01XX @ 89
            mcmemory[122] <= 40'h817D024002; // 7A 817D024002 AL00XX      if CR(9) = 1 then GOTO AL001X @ 7D
            mcmemory[123] <= 40'h80C4014002; // 7B 80C4014002 AL000X      if CR(8) = 0 then GOTO INT @ C4
            mcmemory[124] <= 40'h80DE101040; // 7C 80DE101040 HLT         GOTO STOP @ DE
            mcmemory[125] <= 40'h8183014002; // 7D 8183014002 AL001X      if CR(8) = 1 then GOTO AL0011 @ 83
            mcmemory[126] <= 40'h8181801002; // 7E 8181801002 AL0010      if CR(7) = 1 then GOTO NOT @ 81
            mcmemory[127] <= 40'h0010C00000; // 7F 0010C00000 CLA         0 ? AC, N, Z, V
            mcmemory[128] <= 40'h80C4101040; // 80 80C4101040             GOTO INT @ C4
            mcmemory[129] <= 40'h0010C09210; // 81 0010C09210 NOT         ~AC ? AC, N, Z, V
            mcmemory[130] <= 40'h80C4101040; // 82 80C4101040             GOTO INT @ C4
            mcmemory[131] <= 40'h8186801002; // 83 8186801002 AL0011      if CR(7) = 1 then GOTO CMC @ 86
            mcmemory[132] <= 40'h0000200000; // 84 0000200000 CLC         0 ? C
            mcmemory[133] <= 40'h80C4101040; // 85 80C4101040             GOTO INT @ C4
            mcmemory[134] <= 40'h8184011040; // 86 8184011040 CMC         if PS(C) = 1 then GOTO CLC @ 84
            mcmemory[135] <= 40'h0000208300; // 87 0000208300             HTOH(~0 + ~0) ? C
            mcmemory[136] <= 40'h80C4101040; // 88 80C4101040             GOTO INT @ C4
            mcmemory[137] <= 40'h8196024002; // 89 8196024002 AL01XX      if CR(9) = 1 then GOTO AL011X @ 96
            mcmemory[138] <= 40'h8190014002; // 8A 8190014002 AL010X      if CR(8) = 1 then GOTO AL0101 @ 90
            mcmemory[139] <= 40'h818E801002; // 8B 818E801002 AL0100      if CR(7) = 1 then GOTO ROR @ 8E
            mcmemory[140] <= 40'h0010E60010; // 8C 0010E60010 ROL         ROL(AC) ? AC, N, Z, V, C
            mcmemory[141] <= 40'h80C4101040; // 8D 80C4101040             GOTO INT @ C4
            mcmemory[142] <= 40'h0010F80010; // 8E 0010F80010 ROR         ROR(AC) ? AC, N, Z, V, C
            mcmemory[143] <= 40'h80C4101040; // 8F 80C4101040             GOTO INT @ C4
            mcmemory[144] <= 40'h8194801002; // 90 8194801002 AL0101      if CR(7) = 1 then GOTO ASR @ 94
            mcmemory[145] <= 40'h0001009010; // 91 0001009010 ASL         AC ? DR
            mcmemory[146] <= 40'h0010E09011; // 92 0010E09011             AC + DR ? AC, N, Z, V, C
            mcmemory[147] <= 40'h80C4101040; // 93 80C4101040             GOTO INT @ C4
            mcmemory[148] <= 40'h0010E80010; // 94 0010E80010 ASR         ASR(AC) ? AC, N, Z, V, C
            mcmemory[149] <= 40'h80C4101040; // 95 80C4101040             GOTO INT @ C4
            mcmemory[150] <= 40'h819C014002; // 96 819C014002 AL011X      if CR(8) = 1 then GOTO AL0111 @ 9C
            mcmemory[151] <= 40'h819A801002; // 97 819A801002 AL0110      if CR(7) = 1 then GOTO SWAB @ 9A
            mcmemory[152] <= 40'h0010C11010; // 98 0010C11010 SXTB        extend sign AC(0..7) ? AC, N, Z, V
            mcmemory[153] <= 40'h80C4101040; // 99 80C4101040             GOTO INT @ C4
            mcmemory[154] <= 40'h0010C06010; // 9A 0010C06010 SWAB        SWAB(AC) ? AC, N, Z, V
            mcmemory[155] <= 40'h80C4101040; // 9B 80C4101040             GOTO INT @ C4
            mcmemory[156] <= 40'h81A2801002; // 9C 81A2801002 AL0111      if CR(7) = 1 then GOTO NEG @ A2
            mcmemory[157] <= 40'h81A0401002; // 9D 81A0401002 AL01110     if CR(6) = 1 then GOTO DEC @ A0
            mcmemory[158] <= 40'h0010E09410; // 9E 0010E09410 INC         AC + 1 ? AC, N, Z, V, C
            mcmemory[159] <= 40'h80C4101040; // 9F 80C4101040             GOTO INT @ C4
            mcmemory[160] <= 40'h0010E09110; // A0 0010E09110 DEC         AC + ~0 ? AC, N, Z, V, C
            mcmemory[161] <= 40'h80C4101040; // A1 80C4101040             GOTO INT @ C4
            mcmemory[162] <= 40'h0010E09610; // A2 0010E09610 NEG         ~AC + 1 ? AC, N, Z, V, C
            mcmemory[163] <= 40'h80C4101040; // A3 80C4101040             GOTO INT @ C4
            mcmemory[164] <= 40'h81B5044002; // A4 81B5044002 AL1XXX      if CR(10) = 1 then GOTO AL11XX @ B5
            mcmemory[165] <= 40'h0080009008; // A5 0080009008 AL10XX      SP ? AR
            mcmemory[166] <= 40'h0100000000; // A6 0100000000             MEM(AR) ? DR
            mcmemory[167] <= 40'h81AE024002; // A7 81AE024002             if CR(9) = 1 then GOTO AL101X @ AE
            mcmemory[168] <= 40'h81AC014002; // A8 81AC014002 AL100X      if CR(8) = 1 then GOTO POPF @ AC
            mcmemory[169] <= 40'h0010C09001; // A9 0010C09001 POP         DR ? AC, N, Z, V
            mcmemory[170] <= 40'h0008009408; // AA 0008009408 INCSP       SP + 1 ? SP
            mcmemory[171] <= 40'h80C4101040; // AB 80C4101040             GOTO INT @ C4
            mcmemory[172] <= 40'h0040009001; // AC 0040009001 POPF        DR ? PS
            mcmemory[173] <= 40'h80AA101040; // AD 80AA101040             GOTO INCSP @ AA
            mcmemory[174] <= 40'h81B1014002; // AE 81B1014002 AL101X      if CR(8) = 1 then GOTO IRET @ B1
            mcmemory[175] <= 40'h0004009001; // AF 0004009001 RET         DR ? IP
            mcmemory[176] <= 40'h80AA101040; // B0 80AA101040             GOTO INCSP @ AA
            mcmemory[177] <= 40'h0040009001; // B1 0040009001 IRET        DR ? PS
            mcmemory[178] <= 40'h0088009408; // B2 0088009408             SP + 1 ? SP, AR
            mcmemory[179] <= 40'h0100000000; // B3 0100000000             MEM(AR) ? DR
            mcmemory[180] <= 40'h80AF101040; // B4 80AF101040             GOTO RET @ AF
            mcmemory[181] <= 40'h81BB024002; // B5 81BB024002 AL11XX      if CR(9) = 1 then GOTO AL111X @ BB
            mcmemory[182] <= 40'h81B9014002; // B6 81B9014002 AL110X      if CR(8) = 1 then GOTO PUSHF @ B9
            mcmemory[183] <= 40'h0001009010; // B7 0001009010 PUSH        AC ? DR
            mcmemory[184] <= 40'h8051101040; // B8 8051101040             GOTO PUSHVAL @ 51
            mcmemory[185] <= 40'h0001009040; // B9 0001009040 PUSHF       PS ? DR
            mcmemory[186] <= 40'h8051101040; // BA 8051101040             GOTO PUSHVAL @ 51
            mcmemory[187] <= 40'h81E0014002; // BB 81E0014002 AL111X      if CR(8) = 1 then GOTO RESERVED @ E0
            mcmemory[188] <= 40'h0080009008; // BC 0080009008 SWAP        SP ? AR
            mcmemory[189] <= 40'h0100000000; // BD 0100000000             MEM(AR) ? DR
            mcmemory[190] <= 40'h0020009001; // BE 0020009001             DR ? BR
            mcmemory[191] <= 40'h0001009010; // BF 0001009010             AC ? DR
            mcmemory[192] <= 40'h0210C09020; // C0 0210C09020             BR ? AC, N, Z, V; DR ? MEM(AR)
            mcmemory[193] <= 40'h80C4101040; // C1 80C4101040             GOTO INT @ C4
            mcmemory[194] <= 40'h81C7084002; // C2 81C7084002 IO          if CR(11) = 1 then GOTO IRQ @ C7
            mcmemory[195] <= 40'h0400000000; // C3 0400000000 DOIO        IO
            mcmemory[196] <= 40'h80DE801040; // C4 80DE801040 INT         if PS(W) = 0 then GOTO STOP @ DE
            mcmemory[197] <= 40'h8001401040; // C5 8001401040             if PS(INT) = 0 then GOTO INFETCH @ 01
            mcmemory[198] <= 40'h0800000000; // C6 0800000000             INTS
            mcmemory[199] <= 40'h0088009208; // C7 0088009208 IRQ         ~0 + SP ? SP, AR
            mcmemory[200] <= 40'h0001009004; // C8 0001009004             IP ? DR
            mcmemory[201] <= 40'h0200000000; // C9 0200000000             DR ? MEM(AR)
            mcmemory[202] <= 40'h0088009208; // CA 0088009208             ~0 + SP ? SP, AR
            mcmemory[203] <= 40'h0001009040; // CB 0001009040             PS ? DR
            mcmemory[204] <= 40'h0220001002; // CC 0220001002             LTOL(CR) ? BR; DR ? MEM(AR)
            mcmemory[205] <= 40'h00A0020020; // CD 00A0020020             SHL(BR) ? BR, AR
            mcmemory[206] <= 40'h0100000000; // CE 0100000000             MEM(AR) ? DR
            mcmemory[207] <= 40'h0004009001; // CF 0004009001             DR ? IP
            mcmemory[208] <= 40'h0080001420; // D0 0080001420             LTOL(BR + 1) ? AR
            mcmemory[209] <= 40'h0100000000; // D1 0100000000             MEM(AR) ? DR
            mcmemory[210] <= 40'h0040009001; // D2 0040009001             DR ? PS
            mcmemory[211] <= 40'h8001101040; // D3 8001101040             GOTO INFETCH @ 01
            mcmemory[212] <= 40'h00BBE00000; // D4 00BBE00000 START       0 ? DR, CR, SP, AC, BR, AR, N, Z, V, C
            mcmemory[213] <= 40'h80C3101040; // D5 80C3101040             GOTO DOIO @ C3
            mcmemory[214] <= 40'h0080009004; // D6 0080009004 READ        IP ? AR
            mcmemory[215] <= 40'h0104009404; // D7 0104009404             IP + 1 ? IP; MEM(AR) ? DR
            mcmemory[216] <= 40'h80DE101040; // D8 80DE101040             GOTO STOP @ DE
            mcmemory[217] <= 40'h0080009004; // D9 0080009004 WRITE       IP ? AR
            mcmemory[218] <= 40'h0001009080; // DA 0001009080             IR ? DR
            mcmemory[219] <= 40'h0204009404; // DB 0204009404             IP + 1 ? IP; DR ? MEM(AR)
            mcmemory[220] <= 40'h80DE101040; // DC 80DE101040             GOTO STOP @ DE
            mcmemory[221] <= 40'h0004009080; // DD 0004009080 SETIP       IR ? IP
            mcmemory[222] <= 40'h4000000000; // DE 4000000000 STOP        Halt
            mcmemory[223] <= 40'h8001101040; // DF 8001101040             GOTO INFETCH @ 0
            for (int i = 224; i < 256; i++) begin
                mcmemory[i] <= 40'h0;
            end
            // Fill the main memory
            for (int i = 0; i < 2048; i++) begin
                main_memory[i] <= 16'h0;
            end
        end
        else begin
            // Операционная микрокоманда
            if (~mc[39]) begin
                
                if (mc[WRDR]) // write into data register
                    dr <= comout[15:0];
                if (mc[WRCR]) // write into command register
                    cr <= comout[15:0];
                if (mc[WRIP]) // write into instruction pointer
                    ip <= comout[10:0];
                if (mc[WRSP]) // write into stack pointer
                    sp <= comout[10:0];

                if (mc[WRAC]) // write into accumulator
                    ac <= comout[15:0];
                if (mc[WRBR]) // write into buffer register
                    br <= comout[15:0];
                if (mc[WRPS]) // write into program state
                    ps <= comout[8:0];
                if (mc[WRAR]) // write into address register
                    ar <= comout[10:0];

                if (mc[LOAD]) // load from memory into data register
                    dr <= main_memory[ar];
                else if (mc[STOR]) // store from data register into memory
                    main_memory[ar] <= dr;

                if (mc[SETC])
                    ps[0] <= nzvc[0];
                if (mc[SETV])
                    ps[1] <= nzvc[1];
                if (mc[STNZ])
                    ps[3:2] <= nzvc[3:2];
                
            end
            
            // Set new value of microcode command pointer
            if (mcp_bit)
                mcp <= mcp + 1;
            else
                mcp <= mcp_new;
        end
    end
endmodule

// Testbench
module top_module ();
    reg clk = 0; 
    reg rst = 0;
    always #1 clk = ~clk; // Create clock with period=2
    //initial `probe_start; // Start the timing diagram
    `probe(clk); // Show clk in the timing diagram
    `probe(rst);

    bcomp_control_unit ctrl(.clk(clk), .rst(rst));
    
    `probe(ctrl.mcp);
    `probe(ctrl.mc);
    `probe(ctrl.comout);
    `probe(ctrl.nzvc);
    `probe(ctrl.ac);
    `probe(ctrl.br);
    `probe(ctrl.ps);
    `probe(ctrl.dr);
    `probe(ctrl.cr);
    `probe(ctrl.ip);
    `probe(ctrl.sp);
    `probe(ctrl.ar);
    
    initial begin 
        reg [10:0] cur_ip; // Current instruction address
        reg [15:0] cur_cr; // Current instruction
        reg [15:0] last_mod_mem; // Memory cell which modifies during the instruction
        reg [10:0] last_mod_addr; // Adress of the modified memory cell
        
        
        // Hold reset for one clock period
        rst = 1;
        #2;
        rst = 0;
        
        // LAB WORK 2
        // Store programm in memory
        ctrl.main_memory[11'h184] = 16'h2345;
        ctrl.main_memory[11'h185] = 16'hFD71;
        ctrl.main_memory[11'h186] = 16'h1630;
        ctrl.main_memory[11'h187] = 16'h0000;
        ctrl.main_memory[11'h188] = 16'hA184;
        ctrl.main_memory[11'h189] = 16'h3185;
        ctrl.main_memory[11'h18A] = 16'h6186;
        ctrl.main_memory[11'h18B] = 16'hE187;
        ctrl.main_memory[11'h18C] = 16'h0100;
        // Set IP to the START of the programm
        ctrl.ip = 11'h188;
        
        
        // LAB WORK 3
        // Store programm in memory
        ctrl.main_memory[11'h2E8] = 16'h02FE;
        ctrl.main_memory[11'h2E9] = 16'h0200;
        ctrl.main_memory[11'h2EA] = 16'hE000;
        ctrl.main_memory[11'h2EB] = 16'h0200;
        ctrl.main_memory[11'h2EC] = 16'h0200;
        ctrl.main_memory[11'h2ED] = 16'hEEFD;
        ctrl.main_memory[11'h2EE] = 16'hAF05;
        ctrl.main_memory[11'h2EF] = 16'hEEFA;
        ctrl.main_memory[11'h2F0] = 16'h4EF7;
        ctrl.main_memory[11'h2F1] = 16'hEEF7;
        ctrl.main_memory[11'h2F2] = 16'hABF6;
        ctrl.main_memory[11'h2F3] = 16'hF002;
        ctrl.main_memory[11'h2F4] = 16'h0300;
        ctrl.main_memory[11'h2F5] = 16'h0380;
        ctrl.main_memory[11'h2F6] = 16'h0200;
        ctrl.main_memory[11'h2F7] = 16'h0280;
        ctrl.main_memory[11'h2F8] = 16'h2EF2;
        ctrl.main_memory[11'h2F9] = 16'h0400;
        ctrl.main_memory[11'h2FA] = 16'hEEF0;
        ctrl.main_memory[11'h2FB] = 16'h82EA;
        ctrl.main_memory[11'h2FC] = 16'hCEF5;
        ctrl.main_memory[11'h2FD] = 16'h0100;
        ctrl.main_memory[11'h2FE] = 16'h0001;
        ctrl.main_memory[11'h2FF] = 16'h0002;
        ctrl.main_memory[11'h300] = 16'h0003;
        ctrl.main_memory[11'h301] = 16'h0000;
        ctrl.main_memory[11'h302] = 16'h0006;
        // Set IP to the START of the programm
        ctrl.ip = 11'h2EC;
        
        
        // LAB WORK 4
        // Store main programm in memory
        ctrl.main_memory[11'h13E] = 16'h0200;
        ctrl.main_memory[11'h13F] = 16'hEE1B;
        ctrl.main_memory[11'h140] = 16'hAE17;
        ctrl.main_memory[11'h141] = 16'h0740;
        ctrl.main_memory[11'h142] = 16'h0C00;
        ctrl.main_memory[11'h143] = 16'hD6C9;
        ctrl.main_memory[11'h144] = 16'h0800;
        ctrl.main_memory[11'h145] = 16'h0700;
        ctrl.main_memory[11'h146] = 16'h4E14;
        ctrl.main_memory[11'h147] = 16'hEE13;
        ctrl.main_memory[11'h148] = 16'hAE10;
        ctrl.main_memory[11'h149] = 16'h0740;
        ctrl.main_memory[11'h14A] = 16'h0C00;
        ctrl.main_memory[11'h14B] = 16'hD6C9;
        ctrl.main_memory[11'h14C] = 16'h0800;
        ctrl.main_memory[11'h14D] = 16'h0740;
        ctrl.main_memory[11'h14E] = 16'h4E0C;
        ctrl.main_memory[11'h14F] = 16'hEE0B;
        ctrl.main_memory[11'h150] = 16'hAE09;
        ctrl.main_memory[11'h151] = 16'h0C00;
        ctrl.main_memory[11'h152] = 16'hD6C9;
        ctrl.main_memory[11'h153] = 16'h0800;
        ctrl.main_memory[11'h154] = 16'h0700;
        ctrl.main_memory[11'h155] = 16'h6E05;
        ctrl.main_memory[11'h156] = 16'hEE04;
        ctrl.main_memory[11'h157] = 16'h0100;
        ctrl.main_memory[11'h158] = 16'h0001;
        ctrl.main_memory[11'h159] = 16'h8001;
        ctrl.main_memory[11'h15A] = 16'h0001;
        ctrl.main_memory[11'h15B] = 16'hFFB8;
        // Store subprogramm in memory
        ctrl.main_memory[11'h6C9] = 16'hAC01;
        ctrl.main_memory[11'h6CA] = 16'hF001;
        ctrl.main_memory[11'h6CB] = 16'hF307;
        ctrl.main_memory[11'h6CC] = 16'h7E09;
        ctrl.main_memory[11'h6CD] = 16'hF805;
        ctrl.main_memory[11'h6CE] = 16'hF004;
        ctrl.main_memory[11'h6CF] = 16'h0500;
        ctrl.main_memory[11'h6D0] = 16'h4C01;
        ctrl.main_memory[11'h6D1] = 16'h4E05;
        ctrl.main_memory[11'h6D2] = 16'hCE01;
        ctrl.main_memory[11'h6D3] = 16'hAE02;
        ctrl.main_memory[11'h6D4] = 16'hEC01;
        ctrl.main_memory[11'h6D5] = 16'h0A00;
        ctrl.main_memory[11'h6D6] = 16'hF5DE;
        ctrl.main_memory[11'h6D7] = 16'h004F;
        // Set IP to the START of the programm
        ctrl.ip = 11'h13E;

        
        // Set help-registers to their initial values
        cur_ip = ctrl.ip;
        cur_cr = ctrl.cr;
        last_mod_mem = ctrl.dr;
        last_mod_addr = ctrl.ar;
        
        $display("Аддр Знач  IP  CR   AR  DR   SP  BR   AC  NZVC Аддр Знач");
        
        while (~ctrl.mc[ctrl.HALT]) begin // Do cycle while not HALT
            #2; // Wait one microcommand period
            if (ctrl.mcp == 8'h01) // If INFETCH now - update current instruction address
                cur_ip <= ctrl.ip;
            if (ctrl.mcp == 8'h04) // If INFETCH now - update current instruction
                cur_cr <= ctrl.cr;
            if (ctrl.mc[ctrl.STOR]) begin // If STORE now - update modified memory cell and address
                last_mod_mem <= ctrl.dr;
                last_mod_addr <= ctrl.ar;
            end
            if (~ctrl.mcp_bit && (ctrl.mc[31:24] == 8'h01)) begin // If the current instruction is executed - print result and reset registers 
                $display(" %h %h %h %h %h %h %h %h %h %b  %h %h",
                         cur_ip, cur_cr, ctrl.ip, ctrl.cr, ctrl.ar, ctrl.dr, ctrl.sp, ctrl.br, ctrl.ac, ctrl.ps[3:0], last_mod_addr, last_mod_mem);
                last_mod_mem <= 0;
                last_mod_addr <= 0;
            end
        end
        
        $display(" %h %h %h %h %h %h %h %h %h %b  %h %h",
                 cur_ip, cur_cr, ctrl.ip, ctrl.cr, ctrl.ar, ctrl.dr, ctrl.sp, ctrl.br, ctrl.ac, ctrl.ps[3:0], last_mod_addr, last_mod_mem);
        
        $finish;
    end
endmodule
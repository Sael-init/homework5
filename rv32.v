module rv32;
    localparam integer PAGE_BYTES = 4096;
    localparam integer MAX_PAGES = 4096;

    reg [31:0] pc;
    reg [31:0] regs [0:31];
    // The upper 20 address bits index the page table. Unallocated pages read as zero.
    integer page_slot [0:1048575];
    reg [7:0] memory [0:MAX_PAGES * PAGE_BYTES - 1];
    integer pages_used;
    reg stopped;

    task init;
        integer i;
        begin
            pc = 0;
            stopped = 0;
            pages_used = 0;
            for (i = 0; i < 32; i = i + 1)
                regs[i] = 0;
        end
    endtask

    function [7:0] read_byte(input [31:0] address);
        integer slot;
        begin
            slot = page_slot[address[31:12]];
            if (^slot === 1'bx)
                read_byte = 0;
            else
                read_byte = memory[slot * PAGE_BYTES + int'(address[11:0])];
        end
    endfunction

    function [15:0] read_half(input [31:0] address);
        read_half = {read_byte(address + 32'd1), read_byte(address)};
    endfunction

    function [31:0] read_word(input [31:0] address);
        read_word = {read_half(address + 32'd2), read_half(address)};
    endfunction

    task write_byte(input [31:0] address, input [7:0] value);
        integer slot, base, i;
        begin
            slot = page_slot[address[31:12]];
            if (^slot === 1'bx) begin
                if (pages_used == MAX_PAGES)
                    $fatal(1, "Limite de memoria: %0d paginas asignadas", MAX_PAGES);
                slot = pages_used;
                pages_used = pages_used + 1;
                page_slot[address[31:12]] = slot;
                base = slot * PAGE_BYTES;
                for (i = 0; i < PAGE_BYTES; i = i + 1)
                    memory[base + i] = 0;
            end
            memory[slot * PAGE_BYTES + int'(address[11:0])] = value;
        end
    endtask

    task fault(input string reason, input [31:0] instruction);
        begin
            $display("Detenido en PC=0x%08h, instruccion=0x%08h: %s", pc, instruction, reason);
            stopped = 1;
        end
    endtask

    task step;
        reg [31:0] insn, a, b, next_pc, result, address;
        reg [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
        reg [4:0] rd;
        reg [2:0] funct3;
        reg [6:0] funct7;
        reg write_rd, valid, taken;
        integer store_size, k;
        begin : execute
            if (stopped)
                disable execute;

            insn = read_word(pc);
            $display("PC=0x%08h  instruccion=0x%08h", pc, insn);
            rd = insn[11:7];
            funct3 = insn[14:12];
            funct7 = insn[31:25];
            a = regs[insn[19:15]];
            b = regs[insn[24:20]];
            imm_i = {{20{insn[31]}}, insn[31:20]};
            imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
            imm_b = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
            imm_u = {insn[31:12], 12'b0};
            imm_j = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};
            next_pc = pc + 32'd4;
            result = 0;
            address = 0;
            write_rd = 1;
            valid = 1;
            store_size = 0;

            case (insn[6:0])
                7'h03: begin // Loads
                    address = a + imm_i;
                    case (funct3)
                        0: result = $signed(read_byte(address));
                        1: result = $signed(read_half(address));
                        2: result = read_word(address);
                        4: result = {24'b0, read_byte(address)};
                        5: result = {16'b0, read_half(address)};
                        default: valid = 0;
                    endcase
                end
                7'h23: begin // Stores
                    write_rd = 0;
                    address = a + imm_s;
                    case (funct3)
                        0: store_size = 1;
                        1: store_size = 2;
                        2: store_size = 4;
                        default: valid = 0;
                    endcase
                end
                7'h13: begin // Immediate arithmetic and logic
                    case (funct3)
                        0: result = a + imm_i;
                        1: begin
                            valid = funct7 == 0;
                            result = a << insn[24:20];
                        end
                        2: result = {31'b0, $signed(a) < $signed(imm_i)};
                        3: result = {31'b0, a < imm_i};
                        4: result = a ^ imm_i;
                        5: case (funct7)
                            7'h00: result = a >> insn[24:20];
                            7'h20: result = $signed(a) >>> insn[24:20];
                            default: valid = 0;
                        endcase
                        6: result = a | imm_i;
                        7: result = a & imm_i;
                    endcase
                end
                7'h33: begin // Register arithmetic and logic
                    case ({funct7, funct3})
                        10'h000: result = a + b;
                        10'h100: result = a - b;
                        10'h001: result = a << b[4:0];
                        10'h002: result = {31'b0, $signed(a) < $signed(b)};
                        10'h003: result = {31'b0, a < b};
                        10'h004: result = a ^ b;
                        10'h005: result = a >> b[4:0];
                        10'h105: result = $signed(a) >>> b[4:0];
                        10'h006: result = a | b;
                        10'h007: result = a & b;
                        default: valid = 0;
                    endcase
                end
                7'h37: result = imm_u;
                7'h17: result = pc + imm_u;
                7'h63: begin // Conditional branches
                    write_rd = 0;
                    taken = 0;
                    case (funct3)
                        0: taken = a == b;
                        1: taken = a != b;
                        4: taken = $signed(a) < $signed(b);
                        5: taken = $signed(a) >= $signed(b);
                        6: taken = a < b;
                        7: taken = a >= b;
                        default: valid = 0;
                    endcase
                    if (taken)
                        next_pc = pc + imm_b;
                end
                7'h6f: begin // JAL
                    result = next_pc;
                    next_pc = pc + imm_j;
                end
                7'h67: begin // JALR
                    valid = funct3 == 0;
                    result = next_pc;
                    next_pc = (a + imm_i) & 32'hfffffffe;
                end
                7'h0f: begin // FENCE: all memory operations are already ordered
                    write_rd = 0;
                    valid = funct3 == 0;
                end
                7'h73: begin
                    case (insn)
                        32'h00100073: fault("ebreak", insn);
                        32'h00000073: fault("ecall sin entorno de llamadas", insn);
                        default: fault("instruccion de sistema no soportada", insn);
                    endcase
                    disable execute;
                end
                default: valid = 0;
            endcase

            if (!valid)
                fault("instruccion invalida o no soportada", insn);
            else if (next_pc[1:0] != 0)
                fault("destino de instruccion desalineado", insn);
            else begin
                for (k = 0; k < store_size; k = k + 1)
                    write_byte(address + k, b[8*k +: 8]);
                if (write_rd && rd != 0)
                    regs[rd] = result;
                pc = next_pc;
            end
        end
    endtask
endmodule

module consola;
    rv32 cpu();
    localparam integer STDIN = 32'h80000000;
    string path;
    reg [8*1024-1:0] command, arg1, arg2, extra;
    reg [8*1024-1:0] line;
    integer file, byte_in, count, parsed, i, steps;
    reg [31:0] start_address, end_address, address;
    reg start_valid, end_valid;

    function automatic [32:0] parse_address(input reg [8*1024-1:0] token);
        reg [31:0] value;
        integer index, digit;
        reg [7:0] ch;
        begin
            value = 0;
            index = 1023;
            while (index > 0 && token[8*index +: 8] == 0)
                index = index - 1;
            if (index >= 1 && token[8*index +: 8] == "0" &&
                (token[8*(index-1) +: 8] == "x" || token[8*(index-1) +: 8] == "X"))
                index = index - 2;
            if (index < 0 || index > 7)
                return 0;
            while (index >= 0) begin
                ch = token[8*index +: 8];
                case (ch)
                    "0","1","2","3","4","5","6","7","8","9": digit = ch - "0";
                    "a","b","c","d","e","f": digit = ch - "a" + 10;
                    "A","B","C","D","E","F": digit = ch - "A" + 10;
                    default: return 0;
                endcase
                value = (value << 4) | digit;
                index = index - 1;
            end
            return {1'b1, value};
        end
    endfunction

    initial begin : session
        cpu.init();
        if (!$value$plusargs("bin=%s", path) || path == "")
            $fatal(1, "Uso: vvp simulador.vvp +bin=programa.bin");

        file = $fopen(path, "rb");
        if (file == 0)
            $fatal(1, "No se pudo abrir %s", path);
        count = 0;
        byte_in = $fgetc(file);
        while (byte_in != -1) begin
            if (count == cpu.PAGE_BYTES * cpu.MAX_PAGES)
                $fatal(1, "El archivo supera el limite de memoria");
            cpu.write_byte(count, byte_in[7:0]);
            count = count + 1;
            byte_in = $fgetc(file);
        end
        if (!$feof(file))
            $fatal(1, "Error leyendo %s", path);
        $fclose(file);
        if (count == 0)
            $fatal(1, "El archivo esta vacio");
        if (count >= 4 && cpu.read_word(0) == 32'h464c457f)
            $fatal(1, "Archivo ELF. Exporta la memoria de CPUlator con formato Raw.");

        $display("%s: %0d bytes cargados en 0x00000000", path, count);
        $display("Comandos: step [N], pc, regs, mem INICIO FIN (hex), help, exit");
        forever begin
            $write("> ");
            $fflush();
            if ($fgets(line, STDIN) == 0)
                disable session;
            parsed = $sscanf(line, "%s %s %s %s", command, arg1, arg2, extra);
            if (parsed > 0)
                case (command)
                    "step": begin
                        steps = 1;
                        if (parsed == 2 && $sscanf(arg1, "%d", steps) != 1)
                            steps = 0;
                        if (parsed > 2 || steps < 1 || steps > 100000)
                            $display("Uso: step [N de 1 a 100000]");
                        else if (cpu.stopped)
                            $display("El programa esta detenido. Puedes inspeccionar su estado.");
                        else
                            for (i = 0; i < steps && !cpu.stopped; i = i + 1)
                                cpu.step();
                    end
                    "pc": $display("pc = 0x%08h", cpu.pc);
                    "regs": begin
                        for (i = 0; i < 32; i = i + 1)
                            $display("x%02d = 0x%08h", i, cpu.regs[i]);
                    end
                    "mem": begin
                        {start_valid, start_address} = parse_address(arg1);
                        {end_valid, end_address} = parse_address(arg2);
                        if (parsed != 3 || !start_valid || !end_valid || end_address < start_address ||
                            end_address - start_address >= 256)
                            $display("Uso: mem INICIO FIN (hexadecimal, hasta 256 bytes)");
                        else
                            for (i = 0; i <= end_address - start_address; i = i + 1) begin
                                address = start_address + i;
                                if (i % 16 == 0)
                                    $write("0x%08h:", address);
                                $write(" %02h", cpu.read_byte(address));
                                if (i % 16 == 15 || address == end_address)
                                    $display("");
                            end
                    end
                    "help": $display("Comandos: step [N], pc, regs, mem INICIO FIN (hex), help, exit");
                    "exit": disable session;
                    default: $display("Comando desconocido. Escribe help.");
                endcase
        end
    end
endmodule

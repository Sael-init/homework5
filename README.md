# Simulador RISC-V RV32I para Icarus Verilog

## Ejecutar en PowerShell

Desde la carpeta del proyecto, con `iverilog` y `vvp` en el PATH:

```powershell
iverilog -g2012 -Wall -s consola -o simulador.vvp rv32.v consola.v
vvp simulador.vvp "+bin=demo.bin"
```

Puedes sustituir `demo.bin` por la ruta de cualquier binario Raw compatible. Usa comillas alrededor del argumento `+bin=...` si la ruta tiene espacios. Si los comandos no están en el PATH, usa `& C:\iverilog\bin\iverilog.exe` y `& C:\iverilog\bin\vvp.exe` en su lugar.

| Comando | Efecto |
| --- | --- |
| `step` | Ejecuta una instrucción y muestra su PC y palabra de máquina. |
| `step 8` | Ejecuta hasta 8 instrucciones y se detiene si encuentra un error o una instrucción de parada. |
| `pc` | Muestra el PC actual. |
| `regs` | Muestra los 32 registros en hexadecimal. |
| `mem 0x1000 0x100f` | Muestra los bytes del rango inclusivo. Las direcciones son hexadecimales y el límite por consulta es de 256 bytes. |
| `help` | Muestra los comandos. |
| `exit` | Cierra el simulador. |

## Exportar un programa de CPUlator

1. Abre [CPUlator RISC-V](https://cpulator.01xz.net/?sys=rv32), pega el ensamblador y ejecuta **Compile and Load** (F5). Para usar código propio, agrega `.option norvc` antes de las instrucciones y usa instrucciones RV32I.
2. Abre **Memory** (Ctrl+M), expande el panel lateral derecho y elige **Raw** en **File format**.
3. En **Save**, pon `0000` como dirección inicial. Elige una dirección final que incluya el último byte del código y todos los datos inicializados que use el programa.
4. Pulsa **Save to file** y pasa el archivo a Icarus, por ejemplo con `vvp simulador.vvp "+bin=quicksort.bin"`. Exporta la memoria recién cargada para que el binario represente el estado inicial. El menú **File → Save** guarda un ELF.

## Cuatro ejemplos para el video

| Programa | Cómo comprobar el resultado en Icarus |
| --- | --- |
| [Quicksort](https://pastebin.com/MmQzpFyR) | `mem 1000 101b`. Las siete palabras de 32 bits deben ser `1, 2, 3, 4, 6, 8, 9`. |
| [Árbol simétrico](https://pastebin.com/R74Uqc68) | `regs`. Al terminar, `x10` (`a0`) debe valer `0x00000001`. |
| [riscvtest.s](https://pastebin.com/pKuqWTLh) | `mem 64 67`. Debe mostrar `19 00 00 00` (25 decimal). |
| `demo.s` / `demo.bin` | Desde el inicio ejecuta `step 8`, luego `regs` y `mem 1000 1003`. Los bytes deben ser `80 ff ff ff`, y de `x07` a `x10` deben aparecer `ffffff80`, `00000080`, `ffffff80` y `0000ff80`. |

Para el cuarto ejemplo usa el binario incluido o exporta `demo.s` desde CPUlator cubriendo las direcciones `0x0` a `0x1f`. Para otros programas, puedes usar `step N` para avanzar por bloques. Si el programa termina con un salto a sí mismo, verás que el PC se repite y podrás inspeccionar el resultado.

## Informe breve

El simulador se implementó como un modelo de comportamiento de Verilog, en el modo SystemVerilog de Icarus. `rv32.v` mantiene el PC, los 32 registros y la memoria. `consola.v` lee un archivo Raw byte a byte desde la dirección cero y llama al modelo por cada instrucción solicitada en la terminal.

El modelo incluye las 37 instrucciones del anexo A. Cada paso lee cuatro bytes en orden little-endian, decodifica la instrucción y actualiza el estado. El PC y los registros empiezan en cero, y `x0` conserva el valor cero. La memoria plana admite direcciones de 32 bits y asigna páginas de 4 KiB según se escriben, con hasta 16 MiB de páginas asignadas. Las posiciones sin escribir devuelven cero. Las cargas y escrituras de datos permiten direcciones desalineadas mediante accesos byte a byte.

El simulador trata `fence` como una operación sin efecto porque completa cada acceso antes de pasar a la siguiente instrucción. `ebreak`, `ecall`, las instrucciones inválidas y los saltos a destinos desalineados detienen la ejecución y permiten inspeccionar el estado en el PC de la instrucción. La entrada es binario Raw y se implementa el conjunto de instrucciones del anexo sin extensiones.

La entrega en Canvas pide un PDF con el informe, el enlace al repositorio Git y el enlace a la carpeta de Drive con el código y el video de al menos cuatro ejemplos. Puedes usar esta sección como base para el informe y añadir los enlaces de tu entrega.

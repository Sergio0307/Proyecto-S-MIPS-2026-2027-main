---
title: "Informe técnico del microprocesador S-MIPS"
subtitle: "Análisis componente a componente de `smips.circ` (Logisim-evolution 5.0.0)"
lang: es
---

# 1. Visión general

`smips.circ` implementa un **procesador MIPS de 32 bits, multiciclo y de memoria unificada** ("S-MIPS", subconjunto de MIPS32). El archivo contiene 11 circuitos jerárquicos; el circuito principal es `Board`. Todo el control está hecho con **puertas de 2 entradas, túneles y registros de 1 bit** (una máquina de estados *one-hot*), sin ROM de microcódigo.

**Subconjunto soportado (26 instrucciones).**

| Tipo | Instrucciones |
|---|---|
| R | `add addu sub subu and or slt sll srl jr syscall` |
| I (aritmética) | `addi addiu slti andi ori lui` |
| Memoria | `lw sw lb lbu sb` |
| Saltos | `beq bne j jal` |

Cualquier otra combinación (`sltu`, `nor`, `mult`, `div`, `sllv`...) se marca **ILLEGAL** y la CPU se detiene. `add/addi/sub` no generan excepción por overflow (se comportan como `addu/addiu/subu`).

**Jerarquía y tamaño de cada circuito** (conteo real extraído del archivo):

| Circuito | Papel | Componentes |
|---|---|---|
| `Board` | Placa: reloj, reset, CPU, memoria, TTY, LED Halt | 31 |
| `CPU` | Interconexión de las 4 partes de la CPU | 91 |
| `Memory` | RAM unificada de 4096 palabras | 37 |
| `Control_Unit` | FSM one-hot de 14 estados + señales de control | 571 |
| `Instruction_Decoder` | (OP, FUNCT) → CLASS, ALU_OP, EXT_MODE, ILLEGAL | 984 |
| `Branch_Control` | Decide si se escribe el PC | 12 |
| `Datapath` | Camino de datos (registros, muxes, extensores) | 332 |
| `Datapath_Register_File` | 32 registros de 32 bits | 376 |
| `Datapath_ALU` | ALU de 8 operaciones | 57 |
| `Datapath_ISplitter` | Separa los campos de la instrucción | 14 |
| `Datapath_PROGRAM_COUNTER` | Registro PC | 19 |

Los textos incrustados en el circuito citan requisitos del enunciado (`[R6]`, `[R13]`, `[R14]`: reset del PC/registros, IR único, y ALU como único sumador). El enunciado no se me proporcionó, así que sólo los menciono.

# 2. Placa (`Board`) y mapa de memoria

`Board` contiene: un **Clock** (`Reloj`, 1 Hz por defecto), un **Button** (`Reset`), la **CPU**, la **Memory**, un **TTY** de 48×12 y un **LED** `Halt`. Las conexiones van por túneles:

* `CLK`, `RESET` → CPU, Memory (sólo CLK) y TTY (CLK y *clear* = RESET).
* CPU → Memory: `MEM_ADDR[32]`, `MEM_WDATA[32]`, `MEM_BE[4]`, `MEM_WE`; Memory → CPU: `MEM_RDATA[32]`.
* CPU → TTY: `TTY_DATA[7]` (dato ASCII) y `TTY_WE` (habilitación).
* CPU → LED: `HALT`.

El reloj **no** se detiene con HALT: la CPU queda parada porque el estado `HALT` es absorbente (ver §5).

**Mapa de memoria resultante** (16 KiB, little-endian, sin periféricos mapeados: la E/S va por `syscall`):

| Dirección | Contenido |
|---|---|
| `0x0000` | Reset del PC: primera instrucción |
| `0x1800` | Valor inicial de `$gp` (x28) |
| `0x3FFC` | Valor inicial de `$sp` (x29), crece hacia abajo |

Esta disposición coincide con la configuración *Compact, Text at Address 0* del simulador MARS (inferencia mía: el archivo no nombra MARS).

# 3. Memoria (`Memory`)

Un único bloque **RAM de Logisim** (`Main_Memory`): 12 bits de dirección × 32 bits de dato, **lectura asíncrona** y **byte-enables** (4 bits). Detalles de la lógica:

* Un splitter toma `ADDR[13:2]` como dirección de palabra; los bits `[1:0]` y `[31:14]` se ignoran, así que el espacio se repite cada 16 KiB.
* `BE[3:0]` se reparte en cuatro líneas `BE0..BE3` conectadas a los habilitadores de byte; una constante `UNO` fija el *enable* de la RAM, y la escritura real sólo ocurre con `WE=1`.
* **Lectura combinacional**; **escritura en el flanco de subida** de `CLK`, sólo en los bytes con `BE=1`.
* El tipo es *nonvolatile*: el contenido (el programa) **sobrevive al reset**. El archivo `.circ` entregado tiene la RAM vacía; el programa se carga a mano (§9).

Como instrucciones y datos comparten memoria con un único puerto, la CPU necesita ciclos separados para buscar la instrucción y para acceder a datos: de ahí la arquitectura **multiciclo**.

# 4. CPU (`CPU`)

`CPU` sólo cablea cuatro subcircuitos mediante 75 túneles; sus pines (nombres, anchos y sentidos) son el contrato con la placa:

* Entradas: `CLK`, `RESET`, `MEM_RDATA[32]`. Salidas: `MEM_ADDR[32]`, `MEM_WDATA[32]`, `MEM_BE[4]`, `MEM_WE`, `TTY_DATA[7]`, `TTY_WE`, `HALT`.
* **Instruction_Decoder**: recibe OP y FUNCT (del Datapath) y entrega `CLASS`, `ALU_OP`, `EXT_MODE`, `ILLEGAL`.
* **Control_Unit**: recibe `CLASS`, `ALU_OP`, `ILLEGAL`, `SYS_EXIT`, `SYS_PRINT` y emite todas las señales de control.
* **Branch_Control**: recibe `BR_EQ`, `BR_NE`, `PC_WRITE` y `ZERO` de la ALU; emite `PC_EN`.
* **Datapath**: ejecuta las operaciones y expone `MEM_*`, `TTY_DATA`, `OP`, `FUNCT`, `SYS_EXIT/PRINT`.

Hay un bucle de realimentación intencionado: la instrucción sale del Datapath (IR) → decodificador → unidad de control → Datapath.

# 5. Decodificador de instrucciones (`Instruction_Decoder`)

Es lógica **puramente combinacional** (146 AND, 81 OR, 13 NOT, 730 túneles) que compara OP (6 bits) y, sólo si OP=0, FUNCT (6 bits). Genera cuatro salidas. Para documentarlo con certeza, **reconstruí la netlist del archivo y evalué las 4096 combinaciones (OP, FUNCT)**; esta es la tabla resultante:

| Instrucción (OP / FUNCT) | CLASS | ALU_OP | EXT_MODE |
|---|---|---|---|
| `sll` (00/00), `srl` (00/02) | 00000 (R) | 101 SLL / 110 SRL | 00 |
| `add addu` (00/20,21) | 00000 | 000 ADD | 00 |
| `sub subu` (00/22,23) | 00000 | 001 SUB | 00 |
| `and` (00/24), `or` (00/25) | 00000 | 010 / 011 | 00 |
| `slt` (00/2A) | 00000 | 100 SLT | 00 |
| `jr` (00/08) | 01111 | 000 | 00 |
| `syscall` (00/0C) | 10000 | 000 | 00 |
| `addi` (08), `addiu` (09) | 00001 | 000 | 01 signo |
| `slti` (0A) | 00010 | 100 | 01 |
| `andi` (0C) / `ori` (0D) | 00011 / 00100 | 010 / 011 | 10 ceros |
| `lui` (0F) | 00101 | 111 (pasa B) | 11 lui |
| `lw` (23) / `sw` (2B) | 00110 / 00111 | 000 | 01 |
| `lb` (20) / `lbu` (24) / `sb` (28) | 01000 / 01001 / 01010 | 000 | 01 |
| `beq` (04) / `bne` (05) | 01011 / 01100 | 000 | 01 |
| `j` (02) / `jal` (03) | 01101 / 01110 | 000 | 00 |

De las 127 combinaciones distintas (OP=0 con sus 64 FUNCT, más los 63 OP restantes) **26 son válidas y 101 activan `ILLEGAL=1`**. FUNCT sólo influye cuando OP=0 (lo comprobé muestreando valores de FUNCT para cada OP). `CLASS` de 5 bits es el "código de clase" que luego decodifica la unidad de control; `ALU_OP` ya es directamente el código de la ALU (§7.4).

# 6. Unidad de control (`Control_Unit`)

## 6.1 Registro de estado one-hot

Catorce registros de 1 bit, uno por estado. **El estado FETCH no se guarda directamente**: se guarda su complemento `nS_FETCH`, de modo que el *clear asíncrono* de todos los biestables (RESET) deja `S_FETCH = NOT nS_FETCH = 1` y el resto de estados en 0. Así el reset lleva a FETCH sin lógica adicional.

```
FETCH -> DECODE -> { EXEC -> ALU_WB
                   | MEM_ADDR -> LOAD | STORE
                   | BR_TGT -> BR_CMP
                   | JUMP | JR
                   | SYSCALL -> PRINT | HALT }  -> FETCH
DECODE -> HALT  (si la instrucción es ILLEGAL)
```

## 6.2 Lógica de próximo estado (extraída de la netlist)

Todas las instrucciones pasan por FETCH y DECODE. Con `IS_*` = decodificación de `CLASS`:

| Estado destino | Ecuación |
|---|---|
| `D_EXEC` | `S_DECODE & (IS_R + IS_ALUI)` (IS_ALUI = addi, slti, andi, ori, lui) |
| `D_MEM_ADDR` | `S_DECODE & IS_MEM` (lw, lb, lbu, sw, sb) |
| `D_BR_TGT` | `S_DECODE & IS_BR` |
| `D_JUMP` / `D_JR` / `D_SYSCALL` | `S_DECODE & IS_JMP / IS_JR / IS_SYS` |
| `D_LOAD` / `D_STORE` | `S_MEM_ADDR & IS_LOAD / IS_STORE` |
| `D_PRINT` | `S_SYSCALL & SYS_PRINT` |
| `D_HALT` | `S_HALT + (S_DECODE & ILLEGAL) + (S_SYSCALL & SYS_EXIT)` |
| Vuelta a FETCH | `S_ALU_WB + S_LOAD + S_STORE + S_BR_CMP + S_JUMP + S_JR + S_PRINT + (S_SYSCALL & !EXIT & !PRINT)` |

`S_HALT` se realimenta a sí mismo, por eso HALT es permanente hasta el siguiente RESET. Un `syscall` con `$v0` distinto de 10 u 11 se ignora y vuelve a FETCH.

## 6.3 Señales de salida por estado

| Estado | Señales activas y valores de los selectores |
|---|---|
| FETCH | `IR_WRITE`; `ADDR_SEL=0` (dirección = PC) |
| DECODE | `AB_WRITE`; `ALU_SRC_A=00` (PC), `ALU_SRC_B=01` (4), ALU=ADD, `PC_SRC=00`; **`PC_WRITE` si no es ILLEGAL** (PC←PC+4); `SYS_RD` si es syscall |
| EXEC | `ALU_SRC_A=01` (A) o `10` (shamt en sll/srl); `ALU_SRC_B=00` (B, tipo R) o `10` (inmediato); `ALU_CTRL=ALU_OP` (111 si lui) |
| ALU_WB | `REG_WRITE`; `REG_DST=01` (rd) si R, `00` (rt) si inmediata; `WB_SEL=00` |
| MEM_ADDR | A + inmediato con signo (`SRC_A=01`, `SRC_B=10`) |
| LOAD | `ADDR_SEL=1`; `REG_WRITE`; `WB_SEL=01`; `MEM_BYTE=IS_BYTE`; `LB_SIGN=IS_LB` |
| STORE | `ADDR_SEL=1`; `MEM_WE`; `MEM_BYTE=IS_SB` |
| BR_TGT | `SRC_A=00` (PC ya vale PC+4), `SRC_B=11` (imm×4) → destino en ALU_OUT |
| BR_CMP | `SRC_A=01`, `SRC_B=00`, `ALU_CTRL=001` (SUB), `BR_EQ`/`BR_NE`, `PC_SRC=01` |
| JUMP | `PC_SRC=10`, `PC_WRITE`; si es jal: `REG_WRITE`, `REG_DST=10` (`$ra`), `WB_SEL=10` (PC) |
| JR | `PC_SRC=11` (registro A), `PC_WRITE` |
| SYSCALL / PRINT | `TTY_WE` sólo en PRINT; `SYS_EXIT/SYS_PRINT` se leen del Datapath |
| HALT | `HALT=1` (enciende el LED) |

`MEM_WE = S_STORE`, `IR_WRITE = S_FETCH`, `AB_WRITE = S_DECODE`, `HALT = S_HALT`, `TTY_WE = S_PRINT`: sólo cables, sin lógica extra.

**Ciclos por instrucción** (derivados del diagrama de estados): tipo R, inmediatas, lw/lb/lbu/sw/sb, beq/bne = **4 ciclos**; j, jal, jr = **3 ciclos**; syscall = 3 (exit o código desconocido) o 4 (print).

# 7. Camino de datos (`Datapath`)

Se organiza en seis bloques, tal como lo rotulan los comentarios del circuito.

## 7.1 PC e IR

* **PC** (`Datapath_PROGRAM_COUNTER`): registro de 32 bits, escritura en flanco de subida con `pc_we=PC_EN`, **reset asíncrono a 0**. No contiene sumador: PC+4 lo calcula la ALU.
* **IR**: registro de 32 bits cargado en FETCH (`IR_WRITE`) con `MEM_RDATA`. Alimenta a `Datapath_ISplitter`.
* **Mux PC_SRC** (4 entradas): `00` = `ALU_RESULT` (PC+4, combinacional), `01` = `ALU_OUT` (destino de rama, registrado), `10` = `JUMP_ADDR`, `11` = `A` (jr).
* `JUMP_ADDR = {PC[31:28], TARGET[25:0], 00}`; como el PC ya valió PC+4 desde DECODE, sus 4 bits altos son los correctos.
* **Mux ADDR_SEL**: elige `MEM_ADDR` = PC (FETCH) o `ALU_OUT` (accesos a datos).

## 7.2 `Datapath_ISplitter`

Tres splitters separan los campos: `OP=[31:26]`, `RS=[25:21]`, `RT=[20:16]`, `RD=[15:11]`, `SHAMT=[10:6]`, `FUNCT=[5:0]`, `IMM=[15:0]`, `TARGET=[25:0]`.

## 7.3 Banco de registros (`Datapath_Register_File`)

* 32 registros de 32 bits. **`$zero` no es un registro**: una constante 0 (leer da 0, escribir no hace nada). Los otros 31 son registros con *enable* por línea de un **demultiplexor 5→32** combinado con `REG_WRITE`, y *clear* asíncrono con RESET.
* Dos **multiplexores 32:1** de 5 selectores forman los puertos de lectura `rs1`/`rs2`.
* **Truco de inicialización de `$gp` (x28) y `$sp` (x29)**: deben valer `0x1800` y `0x3FFC` tras el reset, pero el clear de un registro sólo puede poner 0. Por eso el registro físico guarda `valor XOR inicial`: al escribir, `D = rd XOR inicial`; al leer, `Q = reg XOR inicial`. Con el registro en 0 la lectura da el valor inicial. Cada XOR se construye con AND/OR/NOT de 32 bits (4 XOR en total: 4 NOT, 8 AND, 4 OR).
* En el Datapath, antes del banco: mux de lectura (`SYS_RD`: rs→`$v0`, rt→`$a0`), mux de destino (`REG_DST`: rt, rd, `$ra`=11111) y mux de dato (`WB_SEL`: `ALU_OUT`, dato de memoria, PC).
* Los registros **A** y **B** capturan los puertos de lectura en DECODE (`AB_WRITE`).

## 7.4 Inmediato y ALU

**Extensor de inmediato** (`EXT_MODE`): `01` signo, `10` ceros (andi, ori), `11` lui = `{IMM, 16'b0}`. Además `IMM_X4 = SignExt(IMM)·4` para ramas y `SHAMT_32 = ZeroExt(shamt)`.

**ALU** (`Datapath_ALU`, 57 componentes, la **única** de la CPU): sumador, restador, AND, OR, comparador con signo (SLT), dos desplazadores lógicos y un mux de 8 vías.

| ALUOp | Operación | ALUOp | Operación |
|---|---|---|---|
| 000 | A + B | 100 | SLT (A < B con signo) |
| 001 | A − B | 101 | SLL: B << A[4:0] |
| 010 | A AND B | 110 | SRL: B >> A[4:0] |
| 011 | A OR B | 111 | pasa B (lui) |

`ZERO` = (A − B == 0), usado por beq/bne. En sll/srl el Datapath coloca `A = shamt` y `B = R[rt]`. Los operandos se eligen con dos muxes: `ALU_SRC_A` (00 PC, 01 A, 10 shamt) y `ALU_SRC_B` (00 B, 01 constante 4, 10 inmediato, 11 imm×4). El resultado se guarda en el registro **`ALU_OUT`** en cada flanco.

## 7.5 Bytes en memoria: `lb`, `lbu`, `sb`

* **Lectura**: `BYTE_SEL = ALU_OUT[1:0]` elige uno de los cuatro bytes de `MEM_RDATA` (little-endian: byte *k* = bits 8k+7..8k). Se extiende con signo (lb) o con ceros (lbu) según `LB_SIGN`, y `MEM_BYTE` escoge entre byte extendido y palabra (`LOAD_DATA`).
* **Escritura**: `B_BYTE = B[7:0]` se replica en los 4 carriles (`B_BYTE_X4`); si `MEM_BYTE=1` (sb), `MEM_WDATA` es el byte replicado y `MEM_BE` es un *one-hot* (`0001, 0010, 0100, 1000`) según `BYTE_SEL`; si no (sw), `MEM_WDATA=B` y `MEM_BE=1111`.

## 7.6 Syscall

En DECODE de un `syscall`, `SYS_RD=1` lee `$v0` en A y `$a0` en B. Dos comparadores de 32 bits generan `SYS_EXIT = (A == 10)` y `SYS_PRINT = (A == 11)`. `TTY_DATA = B[6:0]` (los 7 bits bajos de `$a0`).

* `$v0 = 11`: imprime el carácter `$a0` en el TTY.
* `$v0 = 10`: termina; la CPU pasa a HALT y se enciende el LED.

# 8. Control del PC (`Branch_Control`)

Seis pines y 5 puertas (1 NOT, 2 AND, 2 OR):

```
TAKE_BRANCH = (BR_EQ & EQUAL) | (BR_NE & !EQUAL)
PC_EN       = PC_WRITE | TAKE_BRANCH
```

`EQUAL` es `ZERO` de la ALU. `PC_WRITE` es 1 en DECODE (si legal), JUMP y JR; `BR_EQ`/`BR_NE` sólo en BR_CMP. Así el PC **se actualiza una vez por instrucción** (PC+4 en DECODE) y se sobrescribe sólo para saltar.

## Ejemplos de microoperaciones

| Instrucción | Ciclos y operaciones |
|---|---|
| `add rd,rs,rt` | F: IR←mem[PC] · D: A←rs, B←rt, PC←PC+4 · E: ALU_OUT←A+B · W: rd←ALU_OUT |
| `lw rt,off(rs)` | F · D · M: ALU_OUT←A+off · L: rt←mem[ALU_OUT] |
| `sw rt,off(rs)` | F · D · M: ALU_OUT←A+off · S: mem[ALU_OUT]←B |
| `beq rs,rt,L` | F · D · T: ALU_OUT←PC+imm·4 · C: si A−B=0, PC←ALU_OUT |
| `jal L` | F · D · J: `$ra`←PC (=PC+4), PC←JUMP_ADDR |
| `jr rs` | F · D · R: PC←A |

# 9. Cómo se ejecutan los programas

El archivo no incluye ningún programa en la RAM: hay que cargarlo. Procedimiento en Logisim-evolution 5.0.0:

1. Abrir `smips.circ` (circuito principal `Board`; **no modificar** `Board`, ya que el propio circuito lo indica).
2. Escribir el programa en ensamblador MIPS, ensamblarlo con memoria desde `0x0000` y generar un archivo de imagen hexadecimal de palabras de 32 bits (formato Logisim `v2.0 raw`, una palabra por línea).
3. Entrar al subcircuito `Memory` (doble clic o explorador de proyecto), clic derecho sobre `Main_Memory` → **Load Image...** y elegir el archivo.
4. Volver a `Board`, **mantener pulsado `Reset`** y soltarlo: PC=0, estado FETCH, `$gp=0x1800`, `$sp=0x3FFC`.
5. Activar el reloj (**Simulate → Ticks Enabled**, `Ctrl+K`) o avanzar con `Ctrl+T`. Cada *tick* alterna el reloj, así que **un ciclo de máquina = 2 ticks**.
6. Observar: el texto sale por el **TTY**; el **LED Halt** se enciende cuando el programa hace `syscall 10` o aparece una instrucción ilegal.

El Reset es **asíncrono**: devuelve la CPU a FETCH y borra A, B, IR, PC, `ALU_OUT` y registros, pero **no** borra la RAM (por eso el programa persiste).

# 10. Pruebas

Como no se entregaron casos de prueba junto al `.circ`, diseñé una **prueba autoverificable** que cubre todas las clases de instrucción. Cada bloque calcula un resultado y lo compara con un valor esperado usando `bne ... fail`. Si todo es correcto imprime `OK` + salto de línea y termina con `syscall 10`; ante el primer error imprime `E` y termina.

| Bloque | Qué verifica |
|---|---|
| add / sub (resultado negativo) | ALU ADD/SUB, extensión de signo de `addi` |
| and / or / slt / slti | ALU lógica y comparación con signo |
| sll / srl | Desplazadores, `A=shamt` |
| lui / ori / andi | `EXT_MODE` 11 y 10 (ceros) |
| sw / lw con `$gp` | Memoria por palabra; valor inicial de `$gp` por el truco XOR |
| sb / lb / lbu | Escritura de un byte (BE one-hot), extensión con y sin signo; que `sb` no toque los otros bytes |
| `addi $zero,...` | `$zero` inmutable |
| `$sp` inicial | Valor `0x3FFC` tras el reset |
| beq / bne / jal / jr / j | Saltos tomados y no tomados, retorno con `$ra` |
| `syscall` 11 y 10 | TTY y HALT |

**Programa de prueba (74 instrucciones).**

```
 addi $t0,$zero,5      | addi $t1,$zero,7   | add  $t2,$t0,$t1    | addi $t3,$zero,12
 bne  $t2,$t3,fail     | sub  $t2,$t0,$t1   | addi $t3,$zero,-2   | bne  $t2,$t3,fail
 and  $t2,$t0,$t1      | addi $t3,$zero,5   | bne  $t2,$t3,fail   | or   $t2,$t0,$t1
 addi $t3,$zero,7      | bne  $t2,$t3,fail  | slt  $t2,$t3,$t0    | bne  $t2,$zero,fail
 slti $t2,$t0,6        | addi $t3,$zero,1   | bne  $t2,$t3,fail   | sll  $t2,$t0,4
 addi $t3,$zero,80     | bne  $t2,$t3,fail  | srl  $t2,$t2,2      | addi $t3,$zero,20
 bne  $t2,$t3,fail     | lui  $t2,0x1234    | ori  $t2,$t2,0xBEEF | andi $t3,$t2,0xFF00
 addi $t4,$zero,0      | ori  $t4,$t4,0xBE00| bne  $t3,$t4,fail   | addi $t0,$zero,-1
 sw   $t0,0($gp)       | lw   $t1,0($gp)    | bne  $t0,$t1,fail   | addi $t2,$zero,0x80
 sb   $t2,1($gp)       | lb   $t3,1($gp)    | addi $t4,$zero,-128 | bne  $t3,$t4,fail
 lbu  $t3,1($gp)       | addi $t4,$zero,0x80| bne  $t3,$t4,fail   | lw   $t1,0($gp)
 lui  $t4,0xFFFF       | ori  $t4,$t4,0x80FF| bne  $t1,$t4,fail   | addi $zero,$zero,9
 bne  $zero,$zero,fail | addi $s0,$sp,0     | lui  $t4,0          | ori  $t4,$t4,0x3FFC
 bne  $s0,$t4,fail     | jal  func          | addi $t5,$zero,99   | bne  $s1,$t5,fail
 beq  $zero,$zero,ok   | j    fail
ok:   $v0=11; $a0=79 ('O'); syscall; $a0=75 ('K'); syscall; $a0=10; syscall; $v0=10; syscall
fail: $v0=11; $a0=69 ('E'); syscall; $v0=10; syscall
func: addi $s1,$zero,99 ; jr $ra
```

**Resultado esperado y validación.** Escribí un modelo de la máquina de estados *a partir de las ecuaciones extraídas de la netlist* (estados, registros A/B/IR/ALU_OUT, PC en DECODE, bytes little-endian, `$gp/$sp` iniciales) y ejecuté el programa:

| Medida | Valor |
|---|---|
| Salida en el TTY | `OK` + salto de línea |
| Estado final | HALT (LED encendido) |
| Ciclos hasta HALT | **269** |
| PC final | `0x010C` (el PC ya avanzó en DECODE del último `syscall`) |
| Control negativo | Cambiando `add` por `sub` en la 3.ª instrucción, el modelo imprime `E` |

Es una validación contra mi modelo, **no una ejecución en Logisim**: no pude correr Logisim aquí. Si en la simulación real el TTY muestra `E`, el bloque que falló es el último comparado antes del salto a `fail`, y la tabla de arriba lo acota. Una diferencia en el número de ciclos indicaría un estado de más o de menos en la FSM.

**Cómo comprobar manualmente cada capa (si la prueba global falla):**

* *Decodificador*: poner OP/FUNCT en el `Instruction_Decoder` y comparar con la tabla del §5.
* *FSM*: tras un Reset, avanzar ciclo a ciclo y comprobar la secuencia F→D→(estado)→F; `HALT` nunca debe encenderse antes de `syscall 10`.
* *PC*: debe valer `4` tras el primer DECODE y `0x10C` al final.
* *Memoria*: tras `sw $t0,0($gp)` la palabra `0x1800/4 = 0x600` de la RAM debe valer `0xFFFF80FF` al final (el `sb` modifica el byte 1).

# 11. Observaciones y límites

* **Sin excepciones**: instrucciones desconocidas detienen la CPU (HALT) en vez de generar una trampa; no hay overflow trap ni `sltu`, `mult`, `div`, `nor`, desplazamientos variables.
* **Memoria alineada**: `lw/sw` ignoran los 2 bits bajos de la dirección (no hay excepción por desalineación).
* **Un solo puerto de memoria**: por eso el CPI es 3–4 y no hay segmentación.
* **PC+4 y destinos de salto en la ALU**: ahorra sumadores pero obliga a la secuencia DECODE→BR_TGT→BR_CMP en las ramas (4 ciclos incluso si no se toman).
* **Reloj sin gating**: tras HALT el reloj sigue corriendo; la CPU ya no cambia de estado.
* **Aviso metodológico**: los valores de §5 (tabla del decodificador) y §6 (ecuaciones) salen de analizar mecánicamente el XML del `.circ`; los de §10 (269 ciclos, `OK`) salen de mi modelo, no de Logisim.

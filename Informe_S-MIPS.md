# Informe del proyecto S-MIPS (`smips.circ`)

**Herramienta:** Logisim-evolution v5.0.0
**Arquitectura:** CPU S-MIPS multiciclo de 32 bits, con control por **máquina de estados one-hot** de 14 estados y decodificador de instrucciones escrito en **VHDL**.

---

## 1. Visión general

El archivo contiene dos grupos de circuitos:

| Grupo | Circuitos | Origen |
|---|---|---|
| **Infraestructura de la práctica** | `Board`, `Memory` | Proporcionados (el propio archivo indica "No modificar") |
| **CPU (trabajo propio)** | `CPU`, `Control_Unit`, `Branch_Control`, `Instruction_Decoder` (VHDL), `Datapath`, `Datapath_Register_File`, `Datapath_ALU`, `Datapath_ISplitter`, `Datapath_PROGRAM_COUNTER` | Implementados por ti |

Jerarquía:

```
Board
├── CPU
│   ├── Instruction_Decoder (VHDL)     OP, FUNCT  ->  CLASS, ALU_OP, EXT_MODE, ILLEGAL
│   ├── Control_Unit                   FSM one-hot -> señales de control
│   ├── Branch_Control                 decide si se escribe el PC
│   └── Datapath
│       ├── Datapath_PROGRAM_COUNTER
│       ├── Datapath_ISplitter
│       ├── Datapath_Register_File
│       └── Datapath_ALU
└── Memory (RAM 4096 x 32 bits)
```

### Interfaz de la CPU con la placa (no se modificó)

| Pin | Dir. | Ancho | Función |
|---|---|---|---|
| `CLK`, `RESET` | in | 1 | Reloj y reset |
| `MEM_RDATA` | in | 32 | Dato leído de memoria |
| `MEM_ADDR` | out | 32 | Dirección de memoria |
| `MEM_WDATA` | out | 32 | Dato a escribir |
| `MEM_BE` | out | 4 | *Byte enables* |
| `MEM_WE` | out | 1 | Escritura en memoria |
| `TTY_DATA` / `TTY_WE` | out | 7 / 1 | Salida de carácter al terminal |
| `HALT` | out | 1 | CPU detenida (enciende el LED) |

### Conjunto de instrucciones soportado

| Tipo | Instrucciones |
|---|---|
| R | `add`, `addu`, `sub`, `and`, `or`, `slt`, `sll`, `srl` |
| I (aritmético/lógico) | `addi`, `addiu`, `slti`, `andi`, `ori`, `lui` |
| Memoria | `lw`, `sw`, `lb`, `lbu`, `sb` |
| Saltos condicionales | `beq`, `bne` |
| Saltos incondicionales | `j`, `jal`, `jr` |
| Sistema | `syscall` (exit = `$v0`=10, print = `$v0`=11) |

---

## 2. Instruction Decoder (VHDL)

Es un circuito **puramente combinacional** (un único `process (OP, FUNCT)`). Por cada instrucción produce una **CLASS** (5 bits) que agrupa instrucciones con el mismo flujo de ejecución, más los datos que el resto de la CPU no puede deducir de la clase.

```vhdl
entity Instruction_Decoder is
  port (
    OP       : in  std_logic_vector(5 downto 0);
    FUNCT    : in  std_logic_vector(5 downto 0);
    CLASS    : out std_logic_vector(4 downto 0);
    ALU_OP   : out std_logic_vector(2 downto 0);
    EXT_MODE : out std_logic_vector(1 downto 0);
    ILLEGAL  : out std_logic
  );
end entity;
```

**Valores por defecto** (se asignan al inicio del proceso): `CLASS="11111"`, `ALU_OP="000"`, `EXT_MODE="00"`, `ILLEGAL='1'`. Así, cualquier combinación no reconocida queda marcada automáticamente como **instrucción ilegal**. Si `OP = 000000` se decodifica por `FUNCT`; en caso contrario, por `OP`.

### Tabla de decodificación

| Instrucción | OP / FUNCT | CLASS | ALU_OP | EXT_MODE |
|---|---|---|---|---|
| `add` / `addu` | 000000 / 100000, 100001 | 00000 | 000 (ADD) | 00 |
| `sub` | 000000 / 100010 | 00000 | 001 (SUB) | 00 |
| `and` | 000000 / 100100 | 00000 | 010 (AND) | 00 |
| `or` | 000000 / 100101 | 00000 | 011 (OR) | 00 |
| `slt` | 000000 / 101010 | 00000 | 100 (SLT) | 00 |
| `sll` | 000000 / 000000 | 00000 | 101 (SLL) | 00 |
| `srl` | 000000 / 000010 | 00000 | 110 (SRL) | 00 |
| `jr` | 000000 / 001000 | 01111 | 000 | 00 |
| `syscall` | 000000 / 001100 | 10000 | 000 | 00 |
| `addi` / `addiu` | 001000 / 001001 | 00001 | 000 | 01 (signo) |
| `slti` | 001010 | 00010 | 100 | 01 |
| `andi` | 001100 | 00011 | 010 | 10 (ceros) |
| `ori` | 001101 | 00100 | 011 | 10 |
| `lui` | 001111 | 00101 | 000 | 11 (lui) |
| `lw` | 100011 | 00110 | 000 | 01 |
| `sw` | 101011 | 00111 | 000 | 01 |
| `lb` | 100000 | 01000 | 000 | 01 |
| `lbu` | 100100 | 01001 | 000 | 01 |
| `sb` | 101000 | 01010 | 000 | 01 |
| `beq` | 000100 | 01011 | 001 (SUB) | 01 |
| `bne` | 000101 | 01100 | 001 (SUB) | 01 |
| `j` | 000010 | 01101 | 000 | 00 |
| `jal` | 000011 | 01110 | 000 | 00 |
| *(otro)* | — | 11111 | 000 | 00 · **ILLEGAL=1** |

**Idea de diseño:** `CLASS` decide *qué camino* sigue la FSM; `ALU_OP` indica *qué operación* hace la ALU en la etapa de ejecución; `EXT_MODE` indica *cómo extender el inmediato* (`01` signo, `10` ceros, `11` desplazado 16 bits para `lui`); `ILLEGAL` detiene la CPU.

---

## 3. Control Unit

Máquina de estados **one-hot** de **14 estados** (un biestable de 1 bit por estado), construida solo con puertas AND/OR/NOT de 2 entradas, registros de 1 bit y túneles (~570 componentes).

**Entradas:** `CLK`, `RESET`, `CLASS` (5), `ALU_OP` (3), `ILLEGAL`, `SYS_EXIT`, `SYS_PRINT`.
**Salidas:** `IR_WRITE`, `AB_WRITE`, `PC_WRITE`, `PC_SRC`(2), `ADDR_SEL`, `MEM_WE`, `MEM_BYTE`, `LB_SIGN`, `SYS_RD`, `ALU_SRC_A`(2), `ALU_SRC_B`(2), `ALU_CTRL`(3), `REG_WRITE`, `REG_DST`(2), `WB_SEL`(2), `BR_EQ`, `BR_NE`, `TTY_WE`, `HALT`.

### 3.1 Estructura interna (secciones del circuito)

1. **Entradas e inversores:** `CLASS` y `ALU_OP` se separan con *splitters* y se generan sus negados (`nCLASS0..4`, `nALUOP0..1`).
2. **Decodificación de CLASS:** `H00/H01/H10` (bits 4:3) y `L000…L111` (bits 2:0). Cada instrucción es `H·L`, por ejemplo `IS_ADDI = H00 & L001`, `IS_BEQ = H01 & L011`, `IS_SYS = H10 & L000`.
3. **Grupos de clases** (OR de las anteriores):
   - `IS_ALUI = IS_ADDI | IS_SLTI | IS_ANDI | IS_ORI | IS_LUI`
   - `IS_ALU = IS_R | IS_ALUI`
   - `IS_LOAD = IS_LW | IS_LB | IS_LBU`, `IS_STORE = IS_SW | IS_SB`, `IS_MEM = IS_LOAD | IS_STORE`
   - `IS_BR = IS_BEQ | IS_BNE`, `IS_JMP = IS_J | IS_JAL`
   - `IS_BYTE = IS_LB | IS_LBU | IS_SB`
   - `IS_SHIFT = SH_SLL | SH_SRL`, donde `SH_SLL = ALUOP2·¬ALUOP1·ALUOP0` y `SH_SRL = ALUOP2·ALUOP1·¬ALUOP0` (se reconocen por `ALU_OP`, porque `sll/srl` comparten CLASS con el resto de tipo R).
4. **Registro de estado one-hot:** 14 registros de 1 bit. Se guarda **`nS_FETCH`** (el negado de FETCH) para que el **reset asíncrono (todo a 0)** deje la máquina en **FETCH**: `S_FETCH = ¬nS_FETCH`.
5. **Lógica de próximo estado** y 6. **Salidas de control.**

### 3.2 Diagrama de estados

```
              ┌──────────────────────────── ILLEGAL ─────────────────────────────┐
              │                                                                   ▼
FETCH ──► DECODE ──┬─► EXEC ──► ALU_WB ───────────────────────────┐            HALT (⟲)
                   ├─► MEM_ADDR ─┬─► LOAD ────────────────────────┤               ▲
                   │             └─► STORE ───────────────────────┤               │
                   ├─► BR_TGT ──► BR_CMP ─────────────────────────┤               │
                   ├─► JUMP ──────────────────────────────────────┤               │
                   ├─► JR ────────────────────────────────────────┼─► FETCH       │
                   └─► SYSCALL ─┬─► PRINT ────────────────────────┤               │
                                ├─► (ni exit ni print) ───────────┘               │
                                └─► (SYS_EXIT) ───────────────────────────────────┘
```

### 3.3 Ecuaciones de próximo estado (extraídas del circuito)

| Estado destino | Condición |
|---|---|
| `DECODE` | `S_FETCH` |
| `EXEC` | `S_DECODE & IS_ALU` |
| `MEM_ADDR` | `S_DECODE & IS_MEM` |
| `BR_TGT` | `S_DECODE & IS_BR` |
| `JUMP` | `S_DECODE & IS_JMP` |
| `JR` | `S_DECODE & IS_JR` |
| `SYSCALL` | `S_DECODE & IS_SYS` |
| `LOAD` | `S_MEM_ADDR & IS_LOAD` |
| `STORE` | `S_MEM_ADDR & IS_STORE` |
| `PRINT` | `S_SYSCALL & SYS_PRINT` |
| `HALT` | `S_HALT \| (S_DECODE & ILLEGAL) \| (S_SYSCALL & SYS_EXIT)` |
| `FETCH` | `ALU_WB \| LOAD \| STORE \| BR_CMP \| JUMP \| JR \| PRINT \| (S_SYSCALL & ¬SYS_EXIT & ¬SYS_PRINT)` |

`ALU_WB` sigue a `EXEC` y `BR_CMP` sigue a `BR_TGT` (transiciones incondicionales de un ciclo).

### 3.4 Qué hace cada estado y qué señales activa

| Estado | Acción | Señales (salidas de control) |
|---|---|---|
| **FETCH** | Lee la instrucción de memoria en `PC` y la guarda en IR | `IR_WRITE=1`, `ADDR_SEL=0` |
| **DECODE** | Lee `rs`/`rt` en A/B (en `syscall`: `$v0`/`$a0`); calcula **PC+4** en la ALU y lo escribe en el PC (si la instrucción no es ilegal) | `AB_WRITE=1`, `ALU_SRC_A=00 (PC)`, `ALU_SRC_B=01 (4)`, `ALU_CTRL=000`, `PC_SRC=00`, `PC_WRITE=¬ILLEGAL`, `SYS_RD = IS_SYS` |
| **EXEC** | Opera la ALU (A op B/inmediato; en shifts, A=shamt) | `ALU_SRC_A = 01` (o `10` si shift), `ALU_SRC_B = 00` (R) o `10` (inmediato), `ALU_CTRL = ALU_OP` (o `111` si `lui`) |
| **ALU_WB** | Escribe `ALU_OUT` en el banco | `REG_WRITE=1`, `WB_SEL=00`, `REG_DST = 01` (R) o `00` (I) |
| **MEM_ADDR** | Dirección efectiva = A + inmediato | `ALU_SRC_A=01`, `ALU_SRC_B=10`, `ALU_CTRL=000` |
| **LOAD** | Lee memoria y escribe en el banco | `ADDR_SEL=1`, `REG_WRITE=1`, `WB_SEL=01`, `MEM_BYTE`/`LB_SIGN` según lw/lb/lbu |
| **STORE** | Escribe B en memoria | `ADDR_SEL=1`, `MEM_WE=1`, `MEM_BYTE` (sb) |
| **BR_TGT** | Calcula el destino: PC + (imm×4) | `ALU_SRC_A=00`, `ALU_SRC_B=11`, `ALU_CTRL=000` |
| **BR_CMP** | Resta A−B para obtener `ZERO` | `ALU_SRC_A=01`, `ALU_SRC_B=00`, `ALU_CTRL=001`, `PC_SRC=01`, `BR_EQ`/`BR_NE` según la instrucción |
| **JUMP** | PC ← dirección de salto; si es `jal` guarda PC+4 en `$ra` | `PC_SRC=10`, `PC_WRITE=1`, `WB_SEL=10`, `REG_DST=10`, `REG_WRITE = IS_JAL` |
| **JR** | PC ← A | `PC_SRC=11`, `PC_WRITE=1` |
| **SYSCALL** | Examina `SYS_EXIT` / `SYS_PRINT` | — |
| **PRINT** | Envía `$a0[6:0]` al terminal | `TTY_WE=1` |
| **HALT** | Estado final | `HALT=1` |

Detalles de codificación de salidas:

- `ALU_CTRL[0] = (S_EXEC & (ALUOP0 | IS_LUI)) | S_BR_CMP`; `ALU_CTRL[1] = S_EXEC & (ALUOP1 | IS_LUI)`; `ALU_CTRL[2] = S_EXEC & (ALUOP2 | IS_LUI)` → con `lui` la ALU hace `111` = pasar B.
- `PC_SRC[0] = S_BR_CMP | S_JR`, `PC_SRC[1] = S_JUMP | S_JR`.
- `PC_WRITE = (S_DECODE & ¬ILLEGAL) | S_JUMP | S_JR`.
- `REG_WRITE = S_ALU_WB | S_LOAD | (S_JUMP & IS_JAL)`.
- `ADDR_SEL = S_LOAD | S_STORE`; `MEM_WE = S_STORE`; `TTY_WE = S_PRINT`.
- `HALT = S_HALT | (S_DECODE & ILLEGAL)` (se activa ya en el ciclo en que se detecta la instrucción ilegal).
- `BR_EQ = S_BR_CMP & IS_BEQ`, `BR_NE = S_BR_CMP & IS_BNE`.

### 3.5 Ciclos por instrucción

| Tipo | Secuencia | Ciclos |
|---|---|---|
| R / inmediatas ALU | FETCH → DECODE → EXEC → ALU_WB | 4 |
| `lw`, `lb`, `lbu` | FETCH → DECODE → MEM_ADDR → LOAD | 4 |
| `sw`, `sb` | FETCH → DECODE → MEM_ADDR → STORE | 4 |
| `beq`, `bne` | FETCH → DECODE → BR_TGT → BR_CMP | 4 |
| `j`, `jal` | FETCH → DECODE → JUMP | 3 |
| `jr` | FETCH → DECODE → JR | 3 |
| `syscall` (ni exit ni print) | FETCH → DECODE → SYSCALL | 3 |
| `syscall` print | FETCH → DECODE → SYSCALL → PRINT | 4 |
| `syscall` exit / ilegal | … → HALT (permanece) | — |

---

## 4. Branch Control

Circuito pequeño (6 pines, 5 puertas) que decide **cuándo se escribe el PC**.

```
TAKE_BRANCH = (BR_EQ · EQUAL) + (BR_NE · ¬EQUAL)
PC_EN       = PC_WRITE + TAKE_BRANCH
```

| Pin | Dir. | Significado |
|---|---|---|
| `BR_EQ`, `BR_NE` | in | Desde la Control Unit (solo activos en BR_CMP) |
| `EQUAL` | in | Resultado de la comparación (`ZERO` de la ALU) |
| `PC_WRITE` | in | Escritura incondicional del PC (DECODE, JUMP, JR) |
| `TAKE_BRANCH` | out | Salto condicional tomado |
| `PC_EN` | out | Habilitación de escritura del PC en el Datapath |

Construcción: 1 NOT (`¬EQUAL`), 2 AND y 2 OR. Así el PC se actualiza o por la vía normal (PC+4, saltos incondicionales) o cuando una rama se cumple.

---

## 5. Program Counter

Registro de **32 bits** (`Datapath_PROGRAM_COUNTER`, usado dentro del Datapath).

| Pin | Dir. | Función |
|---|---|---|
| `clk` | in | Reloj |
| `pc_we` | in | Habilitación de escritura (viene de `PC_EN`) |
| `reset` | in | Reset asíncrono → `PC = 0` |
| `inPC` | in (32) | Siguiente valor |
| `outPC` | out (32) | Valor actual |

**Decisión de diseño:** el PC **no tiene sumador propio**. `PC+4` y las direcciones de salto los calcula la **única ALU** de la CPU, lo que ahorra hardware. El circuito `PROGRAM_COUNTER` (sin prefijo) es una copia idéntica; el Datapath utiliza `Datapath_PROGRAM_COUNTER`.

---

## 6. Datapath

Es el circuito principal (≈330 componentes). Se organiza en 6 bloques rotulados en el propio esquema.

**Entradas:** `CLK`, `RESET`, `MEM_RDATA`, y las señales de control (`IR_WRITE`, `PC_EN`, `PC_SRC`, `ADDR_SEL`, `SYS_RD`, `AB_WRITE`, `ALU_SRC_A/B`, `ALU_CTRL`, `REG_WRITE`, `REG_DST`, `WB_SEL`, `MEM_BYTE`, `LB_SIGN`, `EXT_MODE`).
**Salidas:** `MEM_ADDR`, `MEM_WDATA`, `MEM_BE`, `TTY_DATA`, `ZERO`, `OP`, `FUNCT`, `SYS_EXIT`, `SYS_PRINT`.

### 6.1 PC e IR
- **PC:** guarda la dirección de la instrucción actual.
- **IR** (registro de 32 bits): guarda la instrucción leída en FETCH (`IR_WRITE`).
- **Multiplexor `PC_SRC` (4 entradas)** que elige el siguiente PC:

| PC_SRC | Fuente | Uso |
|---|---|---|
| 00 | `ALU_RESULT` | PC+4 |
| 01 | `ALU_OUT` | Destino de rama |
| 10 | `JUMP_ADDR` | `j`/`jal` |
| 11 | `A` | `jr` |

- `JUMP_ADDR = {PC[31:28], TARGET[25:0], 00}`. Se usa `PC_TOP4 = PC[31:28]` porque el PC ya vale PC+4 cuando se ejecuta JUMP.
- **Multiplexor `ADDR_SEL`:** `MEM_ADDR = PC` (FETCH) o `ALU_OUT` (lw/sw/lb/lbu/sb).

### 6.2 Banco de registros y registros A/B
- Mux de 5 bits para **`READ_REG1`** (`rs` o `$v0`=2 si `SYS_RD`) y **`READ_REG2`** (`rt` o `$a0`=4 si `SYS_RD`).
- Mux `REG_DST` (3 vías) para **`WRITE_REG`**: `00`=`rt`, `01`=`rd`, `10`=`$ra` (31).
- Mux `WB_SEL` (3 vías) para **`WRITE_DATA`**: `00`=`ALU_OUT`, `01`=dato de memoria (`LOAD_DATA`), `10`=PC (jal).
- Registros **A** y **B** (32 bits) guardan `READ_DATA1/2` al activarse `AB_WRITE` (estado DECODE). En `syscall`, A=`$v0` y B=`$a0`.

### 6.3 Inmediato y `shamt`

| Señal | Cálculo | Se usa en |
|---|---|---|
| `IMM_SIGN` | SignExt(IMM) | addi, slti, lw, sw, lb, lbu, sb, ramas |
| `IMM_ZERO` | ZeroExt(IMM) | andi, ori |
| `IMM_LUI` | {IMM, 16 ceros} | lui |
| `IMM_X4` | SignExt(IMM) × 4 | ramas |
| `SHAMT_32` | ZeroExt(shamt) | sll, srl |

`EXT_MODE` (que da el *Instruction Decoder*) selecciona entre `IMM_SIGN` (01), `IMM_ZERO` (10) e `IMM_LUI` (11) mediante un multiplexor de 4 entradas (`IMM_EXT`). `IMM_X4` se obtiene concatenando `{IMM, 00}` (18 bits) y extendiendo con signo.

### 6.4 ALU y registro `ALU_OUT`
- **Operando A (`ALU_SRC_A`):** `00`=PC, `01`=A, `10`=`SHAMT_32`.
- **Operando B (`ALU_SRC_B`):** `00`=B, `01`=constante 4, `10`=`IMM_EXT`, `11`=`IMM_X4`.
- La salida de la ALU (`ALU_RESULT`) se usa directamente para PC+4 y se guarda en el registro **`ALU_OUT`**, que **se escribe en cada flanco de reloj**.
- `ZERO` sale del bloque ALU y alimenta la lógica de ramas.

### 6.5 Memoria: LB, LBU y SB (little-endian)
- **Lectura de byte:** `BYTE_SEL = ALU_OUT[1:0]` selecciona uno de los 4 bytes de `MEM_RDATA` (mux de 8 bits) → `BYTE_SIGN` (lb) o `BYTE_ZERO` (lbu), según `LB_SIGN`. Con `MEM_BYTE=0` se pasa la palabra completa (`lw`).
- **Escritura:**
  - `sw`: `MEM_WDATA = B`, `MEM_BE = 1111`.
  - `sb`: `B_BYTE = B[7:0]` se replica en los 4 carriles (`B_BYTE_X4`) y `MEM_BE` se pone one-hot (`0001/0010/0100/1000`) según `BYTE_SEL`.
- `MEM_WE` viene directo de la Control Unit.

### 6.6 Syscall
- `SYS_EXIT = (A == 10)` y `SYS_PRINT = (A == 11)`: dos comparadores de 32 bits contra constantes, ya que en `syscall` A contiene `$v0`.
- `TTY_DATA = B[6:0]` (= `$a0[6:0]`).

---

## 7. Register File (`Datapath_Register_File`)

| Pin | Dir. | Ancho | Función |
|---|---|---|---|
| `rs_i1`, `rs_i2` | in | 5 | Índices de lectura |
| `rdi` | in | 5 | Índice de escritura |
| `rd` | in | 32 | Dato a escribir |
| `we` | in | 1 | Habilitar escritura |
| `clk`, `reset` | in | 1 | Reloj / reset |
| `rs1`, `rs2` | out | 32 | Datos leídos |

Estructura:
- **31 registros de 32 bits** (x1 … x31); **`$zero` (x0) es una constante 0**, sin registro: leerlo da 0 y escribirlo no tiene efecto.
- **Escritura:** un *demultiplexor* decodifica `rdi` en 32 líneas, que se combinan con `we` (puertas AND) para generar una señal de habilitación `xN_We` por registro. Escribe en el flanco de subida.
- **Lectura:** **dos multiplexores de 32 entradas** (uno por puerto) seleccionados por `rs_i1` y `rs_i2`. Es de lectura combinacional.
- **Valores iniciales especiales con reset asíncrono:** `$gp` (x28) arranca en `0x1800` y `$sp` (x29) en `0x3FFC`. El truco usado: el registro físico guarda **(valor XOR inicial)**, de modo que su *clear* asíncrono lo deja en 0 y, al leerlo, se aplica el XOR con la constante y sale el valor inicial. En escritura se hace `D = rd XOR constante`; en lectura `Q = reg XOR constante` (XOR construidos con puertas NOT/AND/OR).

---

## 8. ALU (`Datapath_ALU`)

Entradas `A` (32), `B` (32), `ALUOp` (3); salidas `Result` (32) y `Zero` (1).

Se calculan **todas las operaciones en paralelo** y un **multiplexor de 8 entradas** (selector = `ALUOp`) elige el resultado:

| ALUOp | Operación | Implementación |
|---|---|---|
| 000 | ADD | Sumador de 32 bits |
| 001 | SUB | Restador de 32 bits |
| 010 | AND | AND de 32 bits |
| 011 | OR | OR de 32 bits |
| 100 | SLT | Comparador (A < B) + extensor de 1 a 32 bits |
| 101 | SLL | Desplazador lógico a la izquierda (B << A[4:0]) |
| 110 | SRL | Desplazador lógico a la derecha (B >> A[4:0]) |
| 111 | B | Pasa B (para `lui`) |

- Un *splitter* extrae `A[4:0]` como cantidad de desplazamiento (`SHAMT`). En `sll`/`srl` la Control Unit pone A=`shamt` y B=`R[rt]`.
- **`Zero`** = comparador (`A−B` == 0), usado por `beq`/`bne`.

---

## 9. Instruction Splitter (`Datapath_ISplitter`)

Separa la instrucción de 32 bits en campos mediante 3 *splitters*:

| Salida | Bits | Ancho |
|---|---|---|
| `OP` | [31:26] | 6 |
| `RS` | [25:21] | 5 |
| `RT` | [20:16] | 5 |
| `RD` | [15:11] | 5 |
| `SHAMT` | [10:6] | 5 |
| `FUNCT` | [5:0] | 6 |
| `IMM` | [15:0] | 16 |
| `TARGET` | [25:0] | 26 |

`OP` y `FUNCT` salen del Datapath hacia el Instruction Decoder.

---

## 10. Conexión de los componentes en el CPU

Todo el cableado del circuito `CPU` se hace con **túneles** (sufijo `_t`).

| Origen | Señal | Destino |
|---|---|---|
| Datapath | `OP`, `FUNCT` | Instruction_Decoder |
| Instruction_Decoder | `CLASS`, `ALU_OP`, `ILLEGAL` | Control_Unit |
| Instruction_Decoder | `EXT_MODE` | Datapath |
| Datapath | `SYS_EXIT`, `SYS_PRINT` | Control_Unit |
| Control_Unit | `IR_WRITE`, `AB_WRITE`, `PC_SRC`, `ADDR_SEL`, `SYS_RD`, `ALU_SRC_A/B`, `ALU_CTRL`, `REG_WRITE`, `REG_DST`, `WB_SEL`, `MEM_BYTE`, `LB_SIGN` | Datapath |
| Control_Unit | `BR_EQ`, `BR_NE`, `PC_WRITE` | Branch_Control |
| Branch_Control | `PC_EN` | Datapath |
| Control_Unit | `MEM_WE`, `TTY_WE`, `HALT` | Pines de salida de la CPU |
| Datapath | `MEM_ADDR`, `MEM_WDATA`, `MEM_BE`, `TTY_DATA` | Pines de salida de la CPU |
| Pines | `CLK`, `RESET`, `MEM_RDATA` | Datapath / Control_Unit |

### Flujo de datos completo (ejemplo: `lw $t0, 4($s0)`)

1. **FETCH:** `ADDR_SEL=0` → `MEM_ADDR=PC`; la memoria devuelve la instrucción y `IR_WRITE` la guarda en IR. El ISplitter la divide y `OP/FUNCT` llegan al decodificador (→ CLASS=`00110`).
2. **DECODE:** se leen `rs` y `rt` hacia A/B; la ALU calcula PC+4 y el PC se actualiza.
3. **MEM_ADDR:** la ALU suma A + `IMM_SIGN` → `ALU_OUT`.
4. **LOAD:** `ADDR_SEL=1` → `MEM_ADDR=ALU_OUT`; `MEM_RDATA` pasa por la lógica de bytes (palabra completa), `WB_SEL=01` y `REG_WRITE=1` escriben en `rt` (`REG_DST=00`).
5. Se vuelve a **FETCH**.

---


---

## 12. Resumen de lo realizado

- **Instruction Decoder en VHDL**: decodificación combinacional de 23 instrucciones a CLASS / ALU_OP / EXT_MODE / ILLEGAL, con detección de instrucciones ilegales.
- **Control Unit**: FSM one-hot de 14 estados con reset asíncrono hacia FETCH, solo con puertas de 2 entradas.
- **Branch Control**: lógica de ramas condicionales y habilitación del PC.
- **Program Counter**: registro de 32 bits con enable y reset asíncrono, sin sumador propio.
- **Datapath**: PC/IR, registros A/B/ALU_OUT, extensión de inmediatos, acceso a bytes (lb/lbu/sb), syscall y multiplexores de control.
- **Register File**: 31 registros + `$zero`, con `$gp` y `$sp` inicializados con el truco XOR.
- **ALU**: 8 operaciones con un único multiplexor, más la señal `Zero`.
- **ISplitter**: separación de campos de la instrucción.

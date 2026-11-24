# LB/LBU: extension de signo frente a extension de cero del mismo byte (y carriles SB).
.data
buf: .space 4
.text
main:
    la   $s0, buf
    addi $t0, $zero, 0x80
    sb   $t0, 0($s0)
    addi $t0, $zero, 0x7f
    sb   $t0, 1($s0)
    addi $t0, $zero, -1
    sb   $t0, 2($s0)
    addi $t0, $zero, 1
    sb   $t0, 3($s0)

    lw   $a0, 0($s0)
    jal  imprimir_hex         # esperado: 01ff7f80 (carriles 0..3)

    lb   $a0, 0($s0)
    jal  imprimir_hex         # esperado: ffffff80 (signo)
    lbu  $a0, 0($s0)
    jal  imprimir_hex         # esperado: 00000080 (sin signo)
    lb   $a0, 1($s0)
    jal  imprimir_hex         # esperado: 0000007f
    lbu  $a0, 1($s0)
    jal  imprimir_hex         # esperado: 0000007f
    jal  nueva_linea          # el TTY tiene 48 columnas: no exceder ese ancho
    lb   $a0, 2($s0)
    jal  imprimir_hex         # esperado: ffffffff
    lbu  $a0, 2($s0)
    jal  imprimir_hex         # esperado: 000000ff
    lb   $a0, 3($s0)
    jal  imprimir_hex         # esperado: 00000001
    jal  nueva_linea

    addi $v0, $zero, 10
    syscall

# Imprime $a0 como 8 digitos hexadecimales y un espacio.
imprimir_hex:
    add  $t0, $a0, $zero
    addi $t1, $zero, 8
ih_bucle:
    srl  $t2, $t0, 28
    slti $t3, $t2, 10
    beq  $t3, $zero, ih_letra
    addi $a0, $t2, 48
    j    ih_imprime
ih_letra:
    addi $a0, $t2, 87
ih_imprime:
    addi $v0, $zero, 11
    syscall
    sll  $t0, $t0, 4
    addi $t1, $t1, -1
    bne  $t1, $zero, ih_bucle
    addi $a0, $zero, 32
    addi $v0, $zero, 11
    syscall
    jr   $ra

nueva_linea:
    addi $a0, $zero, 10
    addi $v0, $zero, 11
    syscall
    jr   $ra

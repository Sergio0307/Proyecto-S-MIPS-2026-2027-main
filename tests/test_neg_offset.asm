# LW/SW con desplazamiento negativo: guardar y leer palabras en -8, -4, 0 y +4.
.data
buf: .space 16
.text
main:
    la   $s0, buf
    addi $s0, $s0, 8          # base en el centro del buffer

    lui  $t0, 0x1111
    ori  $t0, $t0, 0x2222
    sw   $t0, -8($s0)         # buf+0
    lui  $t0, 0x3333
    ori  $t0, $t0, 0x4444
    sw   $t0, -4($s0)         # buf+4
    lui  $t0, 0x5555
    ori  $t0, $t0, 0x6666
    sw   $t0, 0($s0)          # buf+8
    lui  $t0, 0x7777
    ori  $t0, $t0, 0x8888
    sw   $t0, 4($s0)          # buf+12

    lw   $a0, -8($s0)
    jal  imprimir_hex         # esperado: 11112222
    lw   $a0, -4($s0)
    jal  imprimir_hex         # esperado: 33334444
    lw   $a0, 0($s0)
    jal  imprimir_hex         # esperado: 55556666
    lw   $a0, 4($s0)
    jal  imprimir_hex         # esperado: 77778888
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

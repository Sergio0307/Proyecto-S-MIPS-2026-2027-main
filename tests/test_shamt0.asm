# SLL/SRL con shamt=0 (identidad sobre negativo) y con shamt!=0 de contraste.
.text
main:
    addi $s0, $zero, -1       # 0xffffffff
    lui  $s1, 0x8000
    ori  $s1, $s1, 0x0001     # 0x80000001

    # shamt=0: identidad, también sobre un valor negativo
    sll  $t0, $s0, 0
    add  $a0, $t0, $zero
    jal  imprimir_hex         # ffffffff
    srl  $t1, $s0, 0
    add  $a0, $t1, $zero
    jal  imprimir_hex         # ffffffff
    sll  $t2, $s1, 0
    add  $a0, $t2, $zero
    jal  imprimir_hex         # 80000001
    srl  $t3, $s1, 0
    add  $a0, $t3, $zero
    jal  imprimir_hex         # 80000001
    jal  nueva_linea

    # shamt!=0: corrimiento real; el SRL sobre negativo introduce ceros
    sll  $t4, $s1, 4          # 0x80000001 << 4 = 0x00000010
    add  $a0, $t4, $zero
    jal  imprimir_hex         # 00000010
    srl  $t5, $s0, 28         # 0xffffffff >> 28 logico = 0x0000000f
    add  $a0, $t5, $zero
    jal  imprimir_hex         # 0000000f
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

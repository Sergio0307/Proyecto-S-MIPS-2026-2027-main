# BEQ/BNE tomada y no tomada en ambos sentidos, con bucle hacia atras y salto directo.
.text
main:
    # BEQ tomada -> 00000001
    addi $s0, $zero, 7
    addi $s1, $zero, 7
    beq  $s0, $s1, beq1_tomada
    addi $a0, $zero, 0x11
    j    beq1_fin
beq1_tomada:
    addi $a0, $zero, 0x01
beq1_fin:
    jal  imprimir_hex

    # BEQ no tomada (cae por salto directo) -> 00000000
    addi $s0, $zero, 7
    addi $s1, $zero, 8
    beq  $s0, $s1, beq2_tomada
    addi $a0, $zero, 0x00
    j    beq2_fin
beq2_tomada:
    addi $a0, $zero, 0x22
beq2_fin:
    jal  imprimir_hex

    # BNE tomada -> 00000002
    addi $s0, $zero, 3
    addi $s1, $zero, 4
    bne  $s0, $s1, bne1_tomada
    addi $a0, $zero, 0x33
    j    bne1_fin
bne1_tomada:
    addi $a0, $zero, 0x02
bne1_fin:
    jal  imprimir_hex

    # BNE no tomada -> 00000003
    addi $s0, $zero, 9
    addi $s1, $zero, 9
    bne  $s0, $s1, bne2_tomada
    addi $a0, $zero, 0x03
    j    bne2_fin
bne2_tomada:
    addi $a0, $zero, 0x44
bne2_fin:
    jal  imprimir_hex

    # Bucle hacia atras: suma 1+2+3+4+5 = 15 (0x0f)
    addi $s0, $zero, 5
    add  $s1, $zero, $zero
bucle:
    add  $s1, $s1, $s0
    addi $s0, $s0, -1
    bne  $s0, $zero, bucle
    add  $a0, $s1, $zero
    jal  imprimir_hex         # esperado: 0000000f
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

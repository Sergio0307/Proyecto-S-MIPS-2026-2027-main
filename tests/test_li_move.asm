# LI y MOVE (MARS genera addiu/addu): constantes en [-2^15,2^15-1], addu y addiu +/-.
.text
main:
    li   $s0, 1000            # addiu $s0,$zero,1000
    li   $s1, -1000           # addiu $s1,$zero,-1000
    move $s2, $s0             # addu  $s2,$s0,$zero
    add  $a0, $s0, $zero
    jal  imprimir_hex         # 000003e8
    add  $a0, $s1, $zero
    jal  imprimir_hex         # fffffc18
    add  $a0, $s2, $zero
    jal  imprimir_hex         # 000003e8 (move copio 1000)
    jal  nueva_linea

    addu $t0, $s0, $s2        # 1000 + 1000 = 2000
    add  $a0, $t0, $zero
    jal  imprimir_hex         # 000007d0
    addiu $t0, $s1, 2000      # -1000 + 2000 = 1000
    add  $a0, $t0, $zero
    jal  imprimir_hex         # 000003e8
    addiu $t0, $s0, -2000     # 1000 - 2000 = -1000
    add  $a0, $t0, $zero
    jal  imprimir_hex         # fffffc18
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

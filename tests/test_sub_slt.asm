# SUB con positivos y con negativo; SLT/SLTI con resultado 1 y 0 (-1 vs 1: signo != sin signo).
.text
main:
    # SUB con operandos positivos: 10 - 3 = 7
    addi $s0, $zero, 10
    addi $s1, $zero, 3
    sub  $t0, $s0, $s1
    add  $a0, $t0, $zero
    jal  imprimir_hex         # 00000007

    # SUB con operando negativo: 3 - 10 = -7
    sub  $t1, $s1, $s0
    add  $a0, $t1, $zero
    jal  imprimir_hex         # fffffff9

    # SUB con dos negativos: -1 - 1 = -2
    addi $s2, $zero, -1
    addi $s3, $zero, 1
    sub  $t2, $s2, $s3
    add  $a0, $t2, $zero
    jal  imprimir_hex         # fffffffe
    jal  nueva_linea

    # SLT con positivos: 3 < 10 -> 1; 10 < 3 -> 0
    slt  $t0, $s1, $s0
    add  $a0, $t0, $zero
    jal  imprimir_hex         # 00000001

    slt  $t1, $s0, $s1
    add  $a0, $t1, $zero
    jal  imprimir_hex         # 00000000

    # SLT con negativo: -1 < 1 -> 1 (sin signo daria 0)
    slt  $t2, $s2, $s3
    add  $a0, $t2, $zero
    jal  imprimir_hex         # 00000001

    # SLT con negativo: 1 < -1 -> 0 (sin signo daria 1)
    slt  $t3, $s3, $s2
    add  $a0, $t3, $zero
    jal  imprimir_hex         # 00000000
    jal  nueva_linea

    # SLTI: -1 < 0 -> 1 (sin signo daria 0)
    slti $t4, $s2, 0
    add  $a0, $t4, $zero
    jal  imprimir_hex         # 00000001
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

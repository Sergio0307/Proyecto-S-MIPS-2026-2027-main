# AND/OR R-type con operandos que tienen unos en los 16 bits altos (bits 31:16).
.text
main:
    # 0x8000ffff y 0xffff8000: ambos tienen unos en los bits 31:16
    lui  $s0, 0x8000
    ori  $s0, $s0, 0xffff
    lui  $s1, 0xffff
    ori  $s1, $s1, 0x8000
    and  $t0, $s0, $s1        # 0x80008000
    add  $a0, $t0, $zero
    jal  imprimir_hex         # 80008000
    or   $t0, $s0, $s1        # 0xffffffff
    add  $a0, $t0, $zero
    jal  imprimir_hex         # ffffffff
    jal  nueva_linea

    # 0x80011234 y 0x8f0ff0f0: otro par con bits altos a 1
    lui  $s2, 0x8001
    ori  $s2, $s2, 0x1234
    lui  $s3, 0x8f0f
    ori  $s3, $s3, 0xf0f0
    and  $t0, $s2, $s3        # 0x80011030
    add  $a0, $t0, $zero
    jal  imprimir_hex         # 80011030
    or   $t0, $s2, $s3        # 0x8f0ff2f4
    add  $a0, $t0, $zero
    jal  imprimir_hex         # 8f0ff2f4
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

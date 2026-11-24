# $zero inmutable y syscall 11 (print char): escrituras a $zero se ignoran.
.text
main:
    add  $zero, $zero, $zero
    addi $zero, $zero, 99
    ori  $zero, $zero, 0xffff
    add  $a0, $zero, $zero
    jal  imprimir_hex         # esperado: 00000000
    addi $a0, $zero, -1
    and  $a0, $a0, $zero
    jal  imprimir_hex         # esperado: 00000000

    addi $a0, $zero, 65       # 'A'
    addi $v0, $zero, 11
    syscall
    addi $a0, $zero, 90       # 'Z'
    addi $v0, $zero, 11
    syscall
    addi $a0, $zero, 10       # salto de linea
    addi $v0, $zero, 11
    syscall

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

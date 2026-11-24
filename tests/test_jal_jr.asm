# JAL/JR: ida y vuelta con llamadas anidadas; $ra se salva y restaura en cada nivel.
.text
main:
    addi $a0, $zero, 0x0a
    jal  imprimir_hex         # esperado: 0000000a
    jal  nivel1               # nivel2 imprime 0000000b
    addi $a0, $zero, 0x0c
    jal  imprimir_hex         # esperado: 0000000c
    jal  nueva_linea

    addi $v0, $zero, 10
    syscall

# Primer nivel: preserva $ra (retorno a main) mientras llama a nivel2.
nivel1:
    add  $s2, $ra, $zero
    jal  nivel2
    add  $ra, $s2, $zero
    jr   $ra

# Segundo nivel: preserva $ra (retorno a nivel1) mientras imprime.
nivel2:
    add  $s3, $ra, $zero
    addi $a0, $zero, 0x0b
    jal  imprimir_hex
    add  $ra, $s3, $zero
    jr   $ra

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

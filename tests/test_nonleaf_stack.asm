# JAL/JR no hoja: nivel1 salva $ra en la pila, llama a nivel2 y retorna correctamente.
.data
pila: .space 16
.text
main:
    la   $sp, pila
    addi $sp, $sp, 16         # tope de la pila (crece hacia abajo)
    addi $a0, $zero, 0x01
    jal  imprimir_hex         # 00000001
    jal  nivel1
    addi $a0, $zero, 0x05
    jal  imprimir_hex         # 00000005
    jal  nueva_linea

    addi $v0, $zero, 10
    syscall

# Nivel 1: guarda $ra en la pila antes de llamar; lo recupera antes de jr $ra.
nivel1:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    addi  $a0, $zero, 0x02
    jal   imprimir_hex        # 00000002
    jal   nivel2              # nivel2 imprime 00000003 y vuelve aqui
    addi  $a0, $zero, 0x04
    jal   imprimir_hex        # 00000004
    jal   nueva_linea         # primera linea: 4 valores (36 caracteres)
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# Nivel 2: tambien salva $ra en la pila porque llama a imprimir_hex.
nivel2:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    addi  $a0, $zero, 0x03
    jal   imprimir_hex        # 00000003
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

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

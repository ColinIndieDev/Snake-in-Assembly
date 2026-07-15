section .bss
    input_buffer    resb 1
    termios_orig    resb 64
    termios_raw     resb 64

    time_struct     resd 2
    last_time       resd 1
    timer_accum     resd 1

section .data
    background      db "."
    clear_screen    db 27, "[2J", 27, "[H"
    reset_cursor    db 27, "[H"
    hide_cursor     db 27, "[?25l"
    show_cursor     db 27, "[?25h"

    map_size        dd 20
    apple           db "O"
    apple_x         dd 0 
    apple_y         dd 0
    player          db "#"
    player_x        dd 2 
    player_y        dd 4
    dir_x           dd 1
    dir_y           dd 0
    move_cooldown   dd 100 ; in ms

    endl            db 10
    key_esc         db 27

section .text
    global _start

print:
    mov eax, 4
    mov ebx, 1
    int 0x80
    ret

read:
    mov eax, 3
    mov ebx, 0
    int 0x80
    ret

exit:
    mov eax, 1
    mov ebx, 0
    int 0x80

get_termios:
    mov eax, 54                 
    mov ebx, 0                  
    mov ecx, 0x5401             
    mov edx, termios_orig       
    int 0x80
    ret

set_termios_raw:
    mov eax, 54                 
    mov ebx, 0                  
    mov ecx, 0x5402             
    mov edx, termios_raw        
    int 0x80
    ret

restore_termios:
    mov eax, 54                 
    mov ebx, 0              
    mov ecx, 0x5402
    mov edx, termios_orig       
    int 0x80
    ret

clone_termios:
    mov ecx, 0
.loop:
    mov al, [termios_orig + ecx]
    mov [termios_raw + ecx], al
    inc ecx
    cmp ecx, 64
    jne .loop
    ret

close_termios:
    mov eax, 54
    mov ebx, 0
    mov ecx, 0x5402
    mov edx, termios_orig
    int 0x80
    ret

delay_frame:
    push dword 100000000        
    push dword 0                
    mov eax, 162                
    mov ebx, esp                
    mov ecx, 0
    int 0x80
    add esp, 8                  
    ret

gen_rand_num:
    rdrand eax
    jnc gen_rand_num     
    xor edx, edx
    mov ecx, [map_size]
    div ecx
    mov eax, edx
    ret

gen_rand_apple_pos:
    call gen_rand_num
    mov [apple_x], eax
    call gen_rand_num
    mov [apple_y], eax
    ret

setup:
    call get_termios
    call clone_termios
    mov eax, [termios_raw + 12]
    and eax, ~0x0A
    mov [termios_raw + 12], eax
    mov byte[termios_raw + 22], 0
    mov byte[termios_raw + 23], 0
    call set_termios_raw
    ret

get_time_ms:
    mov eax, 78
    mov ebx, time_struct
    mov ecx, 0
    int 0x80
    mov eax, [time_struct + 4]   
    xor edx, edx
    mov ecx, 1000
    div ecx                   
    mov ebx, eax
    mov eax, [time_struct]
    imul eax, 1000
    add eax, ebx
    ret

init_timer:
    call get_time_ms
    mov [last_time], eax
    mov dword[timer_accum], 0
    ret

draw_bg:
    mov ecx, background
    mov edx, 1 
    call print
    ret

draw_player:
    mov ecx, player,
    mov edx, 1 
    call print
    ret

draw_apple:
    mov ecx, apple,
    mov edx, 1 
    call print
    ret

_start:
    ; Init
    call init_timer
    call setup
    mov ecx, clear_screen
    mov edx, 7
    call print
    mov ecx, hide_cursor
    mov edx, 6
    call print

    ; Random apple pos
    call gen_rand_apple_pos

    game_loop:
        ; Update player movement
        call get_time_ms
        mov ebx, [last_time]
        mov [last_time], eax
        sub eax, ebx
        mov ecx, [timer_accum]
        add ecx, eax
        mov [timer_accum], ecx
        mov ecx, [timer_accum]
        cmp ecx, [move_cooldown]
        jl no_player_move
        mov eax, [player_x]
        mov ebx, [player_y]
        add eax, [dir_x]
        add ebx, [dir_y]
        mov [player_x], eax
        mov [player_y], ebx
        sub ecx, [move_cooldown]
        mov [timer_accum], ecx

        ; Keep player inside map 
        mov eax, [player_x]
        cmp eax, -1
        jne not_left
        mov eax, [map_size]
        mov [player_x], eax
        dec [player_x]
        not_left:
        mov eax, [player_x]
        cmp eax, [map_size]
        jne not_right
        mov [player_x], 0 
        not_right:
        mov eax, [player_y]
        cmp eax, -1
        jne not_up
        mov eax, [map_size]
        mov [player_y], eax
        dec [player_y]
        not_up:
        mov eax, [player_y]
        cmp eax, [map_size]
        jne not_down
        mov [player_y], 0 
        not_down:

        ; Check apple player collision
        mov eax, [player_x]
        cmp eax, [apple_x]
        jne no_apple_player_collision
        mov eax, [player_y]
        cmp eax, [apple_y]
        jne no_apple_player_collision
        call gen_rand_apple_pos
        no_apple_player_collision: 


        no_player_move:

        ; Read input
        mov ecx, input_buffer
        mov edx, 1
        call read
        mov al, [input_buffer]
        ; ESC
        mov bl, [key_esc]
        cmp al, bl
        je terminate
        ; W, A, S, D
        cmp al, "w"
        jne w_not_pressed
        cmp [dir_y], 1
        je w_not_pressed
        mov dword[dir_x], 0
        mov dword[dir_y], -1
        jmp movement_def
        w_not_pressed:
        cmp al, "a"
        jne a_not_pressed
        cmp [dir_x], 1
        je a_not_pressed
        mov dword[dir_x], -1
        mov dword[dir_y], 0
        jmp movement_def
        a_not_pressed:
        cmp al, "s"
        jne s_not_pressed
        cmp [dir_y], -1
        je s_not_pressed
        mov dword[dir_x], 0
        mov dword[dir_y], 1
        jmp movement_def
        s_not_pressed:
        cmp al, "d"
        jne movement_def
        cmp [dir_x], -1
        je movement_def
        mov dword[dir_x], 1
        mov dword[dir_y], 0
        movement_def:

        ; Drawing
        mov ecx, reset_cursor 
        mov edx, 3
        call print

        mov edi, 0
        draw_row:
        mov esi, 0
        draw_col:
        cmp esi, [player_x]
        jne check_apple
        cmp edi, [player_y]
        jne check_apple
        call draw_player
        jmp next_tile
        check_apple:
        cmp esi, [apple_x]
        jne draw_default
        cmp edi, [apple_y]
        jne draw_default
        call draw_apple
        jmp next_tile
        draw_default:
        call draw_bg
        next_tile:
        inc esi
        cmp esi, [map_size]
        jne draw_col
        mov ecx, endl
        mov edx, 1
        call print
        inc edi
        cmp edi, [map_size]
        jne draw_row

    jmp game_loop
    terminate:
    mov ecx, show_cursor
    mov edx, 6
    call print
    call close_termios
    call exit

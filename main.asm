section .bss
    input_buffer    resb 1
    termios_orig    resb 64
    termios_raw     resb 64

    time_struct     resd 2
    last_time       resd 1
    timer_accum     resd 1

section .data
    background      db ".", 0
    clear_screen    db 27, "[2J", 27, "[H", 0
    reset_cursor    db 27, "[H", 0
    hide_cursor     db 27, "[?25l", 0
    show_cursor     db 27, "[?25h", 0

    map_size        dd 20
    player          db "#", 0
    player_x        dd 2 
    player_y        dd 4
    dir_x           dd 1
    dir_y           dd 0
    move_cooldown   dd 1000 ; in ms

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
    mov eax, [time_struct]
    imul eax, 1000
    mov ebx, [time_struct + 4]
    mov ecx, 1000
    xor edx, edx
    div ecx 
    mov ecx, eax
    mov eax, [time_struct]
    imul eax, 1000
    add eax, ecx
    ret

init_timer:
    call get_time_ms
    mov [last_time], eax
    mov dword[timer_accum], 0
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
        jl drawing
        mov eax, [player_x]
        mov ebx, [player_y]
        add eax, [dir_x]
        add ebx, [dir_y]
        mov [player_x], eax
        mov [player_y], ebx
        sub ecx, [move_cooldown]
        mov [timer_accum], ecx
        drawing:

        mov ecx, reset_cursor 
        mov edx, 3
        call print

        ; Draw background
        mov edi, 0
        draw_row:
        mov esi, 0
        draw_col:
        ; Draw player at player_x, player_y
        cmp esi, [player_x]
        je x_equal
        mov ecx, background
        mov edx, 1
        call print
        jmp pos_endif
        x_equal:
        cmp edi, [player_y]
        je y_equal
        mov ecx, background
        mov edx, 1 
        call print
        jmp pos_endif
        y_equal:
        mov ecx, player,
        mov edx, 1 
        call print
        pos_endif:

        inc esi
        cmp esi, [map_size]
        jne draw_col
        mov ecx, endl
        mov edx, 1
        call print
        inc edi
        cmp edi, [map_size]
        jne draw_row

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
        mov dword[dir_x], 0
        mov dword[dir_y], -1
        w_not_pressed:
        cmp al, "a"
        jne a_not_pressed
        mov dword[dir_x], -1
        mov dword[dir_y], 0
        a_not_pressed:
        cmp al, "s"
        jne s_not_pressed
        mov dword[dir_x], 0
        mov dword[dir_y], 1
        s_not_pressed:
        cmp al, "d"
        jne d_not_pressed
        mov dword[dir_x], 1
        mov dword[dir_y], 0
        d_not_pressed:
    jmp game_loop
    terminate:
    mov ecx, show_cursor
    mov edx, 6
    call print
    call close_termios
    call exit

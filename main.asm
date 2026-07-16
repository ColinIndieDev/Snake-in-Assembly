section .bss
    input_buffer    resb 1
    termios_orig    resb 64
    termios_raw     resb 64

    time_struct     resd 2
    last_time       resd 1
    timer_accum     resd 1

    snake_body      resd 100

section .data
    background      db " "
    border          db "#"
    clear_screen    db 27, "[2J", 27, "[H"
    reset_cursor    db 27, "[H"
    hide_cursor     db 27, "[?25l"
    show_cursor     db 27, "[?25h"

    map_size        dd 22
    apple           db "@"
    apple_x         dd 0 
    apple_y         dd 0
    snake           db "o"
    snake_head      db "O"
    snake_len       dd 3
    snake_x         dd 7 
    snake_y         dd 5
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
_loop:
    mov al, [termios_orig + ecx]
    mov [termios_raw + ecx], al
    inc ecx
    cmp ecx, 64
    jne _loop
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
    sub ecx, 2
    div ecx
    mov eax, edx
    inc eax
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

init_snake:
    mov [snake_len], 3
    ; Tail
    mov [snake_body], 5
    mov [snake_body + 4], 5
    ; Body
    mov [snake_body + 8], 6
    mov [snake_body + 12], 5
    ; Head
    mov [snake_body + 16], 7
    mov [snake_body + 20], 5
    mov [snake_x], 7
    mov [snake_y], 5
    ret

update_snake:   
    mov ecx, 0
    mov edx, [snake_len]
    dec edx
_body_loop:
    cmp ecx, edx
    je _update_snake_done
    ; eax = ecx * 8
    mov eax, ecx
    shl eax, 3
    mov ebx, [snake_body + eax + 8]
    mov [snake_body + eax], ebx
    mov ebx, [snake_body + eax + 12]
    mov [snake_body + eax + 4], ebx
    inc ecx
    jmp _body_loop
_update_snake_done:
    ret

is_snake_body:
    mov ecx, 0
_is_snake_body_loop:
    cmp ecx, [snake_len]
    je _is_snake_body_not_found 
    ; eax = ecx * 8
    mov eax, ecx
    shl eax, 3
    cmp esi, [snake_body + eax]
    jne _is_snake_body_next
    cmp edi, [snake_body + eax + 4]
    je _is_snake_body_found
_is_snake_body_next:
    inc ecx
    jmp _is_snake_body_loop
_is_snake_body_not_found:
    mov eax, 0
    ret
_is_snake_body_found:
    mov eax, 1
    ret

grow_snake:
    inc [snake_len]
    mov esi, [snake_len]
    dec esi
    shl esi, 3
    mov eax, [apple_x]
    mov ebx, [apple_y]
    mov [snake_body + esi], eax
    mov [snake_body + esi + 4], ebx
    mov [snake_x], eax
    mov [snake_y], ebx
    ret
    
draw_bg:
    mov ecx, background
    mov edx, 1 
    call print
    ret

draw_border:
    mov ecx, border 
    mov edx, 1 
    call print
    ret

draw_snake:
    cmp esi, [snake_x]
    jne _draw_snake_body
    cmp edi, [snake_y]
    jne _draw_snake_body
    mov ecx, snake_head
    mov edx, 1
    call print
    ret
_draw_snake_body:
    mov ecx, snake
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

    ; Init snake_body
    call init_snake

    ; Random apple pos
    call gen_rand_apple_pos

game_loop:
    ; Update snake movement
    call get_time_ms
    mov ebx, [last_time]
    mov [last_time], eax
    sub eax, ebx
    mov ecx, [timer_accum]
    add ecx, eax
    mov [timer_accum], ecx
    mov ecx, [timer_accum]
    cmp ecx, [move_cooldown]
    jl no_snake_move
    
    ; Check apple snake collision
    mov eax, [snake_x]
    add eax, [dir_x]
    cmp eax, [apple_x]
    jne no_apple_snake_collision
    mov eax, [snake_y]
    add eax, [dir_y]
    cmp eax, [apple_y]
    jne no_apple_snake_collision
    call grow_snake
    call gen_rand_apple_pos
    jmp no_snake_move
no_apple_snake_collision: 

    ; Move snake
    call update_snake
    mov eax, [snake_x]
    mov ebx, [snake_y]
    add eax, [dir_x]
    add ebx, [dir_y]
    mov [snake_x], eax
    mov [snake_y], ebx
    sub ecx, [move_cooldown]
    mov [timer_accum], ecx

    ; Keep snake inside map 
    mov eax, [snake_x]
    cmp eax, 0
    jne not_left
    mov eax, [map_size]
    mov [snake_x], eax
    sub [snake_x], 2
not_left:
    mov eax, [snake_x]
    mov ebx, [map_size]
    dec ebx
    cmp eax, ebx
    jne not_right
    mov [snake_x], 1
not_right:
    mov eax, [snake_y]
    cmp eax, 0
    jne not_up
    mov eax, [map_size]
    mov [snake_y], eax
    sub [snake_y], 2
not_up:
    mov eax, [snake_y]
    mov ebx, [map_size]
    dec ebx
    cmp eax, ebx 
    jne not_down
    mov [snake_y], 1 
not_down:

    ; Apply new position to snake_body too
    mov esi, [snake_len]
    dec esi
    shl esi, 3
    mov eax, [snake_x]
    mov ebx, [snake_y]
    mov [snake_body + esi], eax
    mov [snake_body + esi + 4], ebx
no_snake_move:

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
    jmp no_movement
w_not_pressed:
    cmp al, "a"
    jne a_not_pressed
    cmp [dir_x], 1
    je a_not_pressed
    mov dword[dir_x], -1
    mov dword[dir_y], 0
    jmp no_movement
a_not_pressed:
    cmp al, "s"
    jne s_not_pressed
    cmp [dir_y], -1
    je s_not_pressed
    mov dword[dir_x], 0
    mov dword[dir_y], 1
    jmp no_movement
s_not_pressed:
    cmp al, "d"
    jne no_movement
    cmp [dir_x], -1
    je no_movement
    mov dword[dir_x], 1
    mov dword[dir_y], 0
no_movement:

    ; Drawing
    mov ecx, reset_cursor 
    mov edx, 3
    call print

    mov edi, 0
draw_row:
    mov esi, 0
draw_col:
    call is_snake_body
    cmp eax, 1
    jne check_apple
    call draw_snake
    jmp next_tile
check_apple:
    cmp esi, [apple_x]
    jne draw_default
    cmp edi, [apple_y]
    jne draw_default
    call draw_apple
    jmp next_tile
draw_default:
    cmp esi, 0
    je _draw_border
    cmp edi, 0 
    je _draw_border
    mov eax, [map_size]
    dec eax
    cmp esi, eax
    je _draw_border
    cmp edi, eax
    je _draw_border
    call draw_bg
    jmp next_tile
_draw_border:
    call draw_border
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

    call delay_frame
    jmp game_loop
terminate:
    mov ecx, show_cursor
    mov edx, 6
    call print
    call close_termios
    call exit

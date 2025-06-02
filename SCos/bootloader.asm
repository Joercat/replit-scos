
[ORG 0x7C00]
[BITS 16]

KERNEL_OFFSET equ 0x1000

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

load_kernel:
    ; Save boot drive number that BIOS gave us
    mov [boot_drive], dl

    ; Reset disk system first
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13

    ; Load kernel one sector at a time for reliability
    mov bx, KERNEL_OFFSET   ; Load address
    mov cx, 2               ; Starting sector (sector 2)
    mov bp, 8               ; Total sectors to read (4KB) - reduced for testing

read_loop:
    push bp                 ; Save sector count
    push cx                 ; Save current sector
    push bx                 ; Save current memory address

    ; Try reading with retry
    mov di, 2               ; Reduced retry count to prevent hanging

retry_read:
    mov ah, 0x02            ; Read sectors function
    mov al, 1               ; Read 1 sector at a time
    mov ch, 0               ; Cylinder 0
    mov bp, sp              ; Set up base pointer to access stack
    mov cl, [bp + 2]        ; Current sector from stack
    mov dh, 0               ; Head 0
    mov dl, [boot_drive]    ; Drive
    int 0x13

    jnc read_success        ; Jump if no carry (success)

    ; Reset disk and retry
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13

    dec di
    jnz retry_read          ; Retry if count > 0

    ; All retries failed
    add sp, 6               ; Clean up stack
    jmp read_error

read_success:
    pop bx                  ; Restore memory address
    pop cx                  ; Restore current sector
    pop bp                  ; Restore sector count

    add bx, 512             ; Next memory location (512 bytes per sector)
    inc cx                  ; Next sector
    dec bp                  ; Decrement sector count
    jnz read_loop           ; Continue if more sectors

    ; Verify kernel was loaded
    mov bx, KERNEL_OFFSET
    cmp word [bx], 0
    je read_error           ; If first word is 0, kernel probably wasn't loaded
    jmp switch_to_32bit

read_error:
    ; Display error and halt
    mov si, disk_error_msg
    call print_string
    cli
    hlt

switch_to_32bit:
    cli
    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp CODE_SEG:init_32bit

print_string:
    lodsb
    or al, al
    jz done
    mov ah, 0x0E
    int 0x10
    jmp print_string
done:
    ret

[BITS 32]
init_32bit:
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov ebp, 0x90000
    mov esp, ebp

    jmp KERNEL_OFFSET

gdt_start:
    dd 0x0
    dd 0x0

gdt_code:
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0

gdt_data:
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 10010010b
    db 11001111b
    db 0x0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

boot_drive db 0
disk_error_msg db 'Disk read error!', 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55

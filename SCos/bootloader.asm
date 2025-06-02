
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

    ; Load kernel in larger chunks - read 8 sectors at once
    mov bx, KERNEL_OFFSET   ; Load address
    mov cx, 8               ; Read 8 sectors at a time (4KB chunks)
    mov dx, 2               ; Starting sector
    mov bp, 3               ; Total chunks to read (24 sectors = 12KB)

read_loop:
    push bp                 ; Save chunk count
    push cx                 ; Save sectors per chunk
    push dx                 ; Save current sector

    ; Read multiple sectors at once for speed
    mov ah, 0x02            ; Read sectors function
    mov al, cl              ; Read multiple sectors
    mov ch, 0               ; Cylinder 0
    mov cl, dl              ; Current sector
    mov dh, 0               ; Head 0
    mov dl, [boot_drive]    ; Drive
    int 0x13

    jc read_error

    ; Move to next chunk
    pop dx                  ; Restore current sector
    pop cx                  ; Restore sectors per chunk
    pop bp                  ; Restore chunk count

    add dx, cx              ; Next sector = current + sectors read
    mov ax, cx              ; Calculate bytes read
    mov cl, 9               ; Multiply by 512 (shift left 9 bits)
    shl ax, cl
    add bx, ax              ; Next memory location

    dec bp                  ; Decrement chunk count
    jnz read_loop           ; Continue if more chunks

    ; Quick kernel verification
    mov bx, KERNEL_OFFSET
    cmp word [bx], 0
    je read_error           ; If first word is 0, kernel probably wasn't loaded
    jmp switch_to_32bit

read_error:
    ; Simple error - just halt, no retry to avoid delays
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

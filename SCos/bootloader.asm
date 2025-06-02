
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
    mov [boot_drive], dl

    ; Show boot message
    mov si, boot_msg
    call print_string

load_kernel:
    mov bx, KERNEL_OFFSET
    mov cx, 2
    mov bp, 24

read_loop:
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc read_error

    add bx, 512
    inc cx
    dec bp
    jnz read_loop

    mov si, loaded_msg
    call print_string

    ; Verify kernel was loaded correctly
    mov bx, KERNEL_OFFSET
    cmp word [bx], 0
    je read_error

switch_to_32bit:
    cli
    lgdt [gdt_descriptor]
    
    ; Clear interrupts and flush prefetch queue
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    
    ; Far jump to reload CS with new GDT
    jmp CODE_SEG:init_32bit

read_error:
    mov si, error_msg
    call print_string
    jmp hang

hang:
    cli
    hlt
    jmp hang

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
    ; Load data segment selector
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ; Set up stack in upper memory (well below kernel)
    mov esp, 0x90000
    mov ebp, esp
    
    ; Clear direction flag
    cld
    
    ; Display "32-bit mode" message on screen
    mov esi, 0xB8000
    mov eax, 0x0F340F33  ; "32" in white
    mov [esi], eax
    
    ; Jump to kernel entry point
    jmp KERNEL_OFFSET

; Align GDT on word boundary
align 4
gdt_start:
    ; Null descriptor
    dd 0x0, 0x0

gdt_code:
    ; Code segment: base=0, limit=4GB, executable, readable
    dw 0xFFFF    ; limit low
    dw 0x0000    ; base low
    db 0x00      ; base middle
    db 10011010b ; access (present, ring 0, code, executable, readable)
    db 11001111b ; flags (4KB pages, 32-bit) + limit high
    db 0x00      ; base high

gdt_data:
    ; Data segment: base=0, limit=4GB, writable
    dw 0xFFFF    ; limit low
    dw 0x0000    ; base low
    db 0x00      ; base middle
    db 10010010b ; access (present, ring 0, data, writable)
    db 11001111b ; flags (4KB pages, 32-bit) + limit high
    db 0x00      ; base high

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

boot_drive db 0
boot_msg db 'SCos Boot', 13, 10, 0
loaded_msg db 'Kernel OK', 13, 10, 0
error_msg db 'Boot Error', 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55

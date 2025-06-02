
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

    ; Show boot drive info
    mov si, boot_msg
    call print_string

    ; Reset disk system first
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    jc reset_error

    ; Show reset success
    mov si, reset_ok_msg
    call print_string

    ; Load kernel one sector at a time for reliability
    mov bx, KERNEL_OFFSET   ; Load address
    mov cx, 2               ; Starting sector (sector 2)
    mov bp, 4               ; Reduced to 2KB (4 sectors) for faster boot

read_loop:
    push bp                 ; Save sector count
    push cx                 ; Save current sector
    push bx                 ; Save current memory address

    ; Show current sector being read
    mov si, reading_msg
    call print_string

    ; Try reading with retry
    mov di, 3               ; Retry count

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

    ; Show retry message
    mov si, retry_msg
    call print_string

    ; Reset disk and retry
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13

    dec di
    jnz retry_read          ; Retry if count > 0

    ; All retries failed
    mov si, sector_fail_msg
    call print_string
    add sp, 6               ; Clean up stack
    jmp read_error

read_success:
    ; Show sector read success
    mov si, sector_ok_msg
    call print_string

    pop bx                  ; Restore memory address
    pop cx                  ; Restore current sector
    pop bp                  ; Restore sector count

    add bx, 512             ; Next memory location (512 bytes per sector)
    inc cx                  ; Next sector
    dec bp                  ; Decrement sector count
    jnz read_loop           ; Continue if more sectors

    ; Show all sectors loaded
    mov si, all_loaded_msg
    call print_string

    ; Verify kernel was loaded (simple check)
    mov bx, KERNEL_OFFSET
    cmp word [bx], 0
    je read_error           ; If first word is 0, kernel probably wasn't loaded
    
    ; Show switching to 32-bit
    mov si, switch_msg
    call print_string
    jmp switch_to_32bit

reset_error:
    mov si, reset_error_msg
    call print_string
    jmp hang

read_error:
    ; Display error and halt
    mov si, disk_error_msg
    call print_string
    jmp hang

hang:
    cli
    hlt
    jmp hang                ; Infinite loop in case of NMI

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
boot_msg db 'Booting SCos...', 13, 10, 0
reset_ok_msg db 'Disk reset OK', 13, 10, 0
reset_error_msg db 'Disk reset failed!', 13, 10, 0
reading_msg db 'Reading sector...', 13, 10, 0
retry_msg db 'Retry...', 13, 10, 0
sector_ok_msg db 'OK', 13, 10, 0
sector_fail_msg db 'Sector read failed!', 13, 10, 0
all_loaded_msg db 'Kernel loaded!', 13, 10, 0
switch_msg db 'Switching to 32-bit...', 13, 10, 0
disk_error_msg db 'FATAL: Disk error!', 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55

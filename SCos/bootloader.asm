
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
    
    ; Show pre-GDT message
    mov si, loading_gdt_msg
    call print_string
    
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Show GDT loaded
    mov si, gdt_loaded_msg
    call print_string

    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Show entering protected mode
    mov si, entering_pm_msg
    call print_string

    ; Far jump to flush instruction pipeline and enter 32-bit mode
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
    ; Set up segment registers
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set up stack - use a safer location
    mov ebp, 0x90000
    mov esp, ebp

    ; Write success message directly to video memory in 32-bit mode
    mov edi, 0xB8000
    mov esi, pm_success_msg_32
    mov ah, 0x0F  ; White on black
write_loop:
    lodsb
    test al, al
    jz jump_kernel
    stosb
    mov al, ah
    stosb
    jmp write_loop

jump_kernel:
    ; Jump to kernel
    jmp KERNEL_OFFSET

pm_success_msg_32 db '32-bit mode active! Jumping to kernel...', 0

; Align GDT to 4-byte boundary
align 4
gdt_start:
    ; Null descriptor
    dd 0x0
    dd 0x0

gdt_code:
    ; Code segment: base=0, limit=4GB, 32-bit, executable, readable
    dw 0xFFFF       ; Limit low
    dw 0x0000       ; Base low
    db 0x00         ; Base middle
    db 10011010b    ; Access byte: present, ring 0, code, executable, readable
    db 11001111b    ; Flags: 4KB granularity, 32-bit, limit high
    db 0x00         ; Base high

gdt_data:
    ; Data segment: base=0, limit=4GB, 32-bit, writable
    dw 0xFFFF       ; Limit low
    dw 0x0000       ; Base low
    db 0x00         ; Base middle
    db 10010010b    ; Access byte: present, ring 0, data, writable
    db 11001111b    ; Flags: 4KB granularity, 32-bit, limit high
    db 0x00         ; Base high

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Size
    dd gdt_start                ; Offset

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
loading_gdt_msg db 'Loading GDT...', 13, 10, 0
gdt_loaded_msg db 'GDT loaded!', 13, 10, 0
entering_pm_msg db 'Entering protected mode...', 13, 10, 0
disk_error_msg db 'FATAL: Disk error!', 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55

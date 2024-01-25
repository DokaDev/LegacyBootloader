[ORG 0]
[BITS 16]

SECTION .text
jmp 0x07C0:ENTRY

TOTALSECTORCOUNT: dw 0x02
KERNEL32SECTORCOUNT: dw 0x02
BOOTSTRAPPROCESSOR: db 0x01 ; BP
STARTGRAPHICMODE: db 0x01

ENTRY:
    ; EntryPoint Segment(DS)
    mov ax, 0x07C0
    mov ds, ax

    ; Video Memory(ES)
    mov ax, 0xB800
    mov es, ax

    ; STACK Pointer
    mov ax, 0
    mov ss, ax
    mov sp, 0xFFFE ; 0 ~ 0xFFFF
    mov bp, 0xFFFE

CLEARSCREEN:
    mov si, 0

    LOOP_SCREENCLEARLOOP:
        mov byte[es:si], 0
        mov byte[es:si + 1], 0x0F

        add si, 2

        cmp si, 80 * 25 * 2
        jl LOOP_SCREENCLEARLOOP

DISKREAD:
    ; [AH] 0x02(READ), 0x03(WRITE), 0x04(VERIFY), 0x0C(SEEK), 0x00(RESET)
    ; [AL] SECTOR COUNT FOR PROCESSING(ABLE TO PROCESS SEQUENTIAL SECTOR)
    ; [CH] CYLINDER NUMBER & 0xFF
    ; [CL] SECTOR NUMBER(BIT 0~5) | (CYNLINDER NUMBER & 0x300) >> 2
    ; [DH] HEAD NUMBER
    ; [DL] DRIVE NUMBER
    ; [ES:BX] BUFFER ADDRESS(IF IN VERYFING OR SEEKING, ISN'T REFER TO THIS VALUE)
    ; [FLAGS.CF] IF 0: NO ERROR(AH == 0)/ IF 1: ERROR. AH==$(ERROR_CODE == RESET)

    INIT_DISK:
        mov ah, 0
        mov dl, 0
        int 0x13
        jc HANDLE_DISKERROR

    ; [ES:BX] = [0x1000:0x0000]
    mov si, 0x1000
    mov es, si
    mov bx, 0x0000

    mov di, word[TOTALSECTORCOUNT]

    DISK_READ:
        cmp di, 0
        je ENDPOINT_DISKREAD
        sub di, 0x1

        mov ah, 0x2                    ; BIOS function(AH=0x02(READ))
        mov al, 0x1                     ; SECTOR COUNT FOR PROCESSING(AL=1)
        mov ch, byte [TRACKNUMBER]      ; CYLINDER(TRACK) NUMBER
        mov cl, byte [SECTORNUMBER]     ; SECTOR NUMBER
        mov dh, byte [HEADNUMBER]       ; HEAD NUMBER
        mov dl, 0                       ; DRIVE NUMBER(0=Floppy)
        int 0x13                        ; BIOS SERVICE: Disk I/O Service
        jc HANDLEDISKERROR

        NEXT_SECTOR:
            add si, 0x0020                  ; PER SECTOR(512MB = 0x200 --> Segment)
            mov es, si

            mov al, byte [SECTORNUMBER]     ; SECTOR NUMBER += 1
            add al, 0x01                    ;
            mov byte [SECTORNUMBER], al     ; 
            cmp al, 19                      ; IF(AL(SECTORNUMBER) < 19) GOTO READDATA 
            jl DISK_READ                    ; 

        HEAD_CONTROL:
            xor byte [HEADNUMBER], 0x01     ; TOGGLE HEAD NUMBER(0, 1)
            mov byte [SECTORNUMBER], 0x01   ; SET SECTOR NUMBER TO 1

            cmp byte [HEADNUMBER], 0x00     ; COMPARE WITH HEAD NUMBER
            jne DISK_READ

        TRACK_CONTROL:
            add byte [TRACKNUMBER], 0x01    ; TRACK NO. += 1

        jmp DISK_READ ; RETURN LOOP

    ENDPOINT_DISKREAD:
        ; SET GRAPHIC MODE BY CALL VBE FUNCTIONAL NUMBER(0x4F01)
        mov ax, 0x4F01  ; VBE Function
        mov cx, 0x117   ; 1024*768 res. 16bit(R(5) : G(6) : B(5))
        mov bx, 0x07E0
        mov es, bx
        mov di, 0x00

        int 0x10
        cmp ax, 0x004F  ; ERROR HANDLING
        jne VBEERROR

        ; SWITCH TO GRAPHICAL MODE
        cmp byte[STARTGRAPHICMODE], 0x00
        je JUMPTOPROTECTEDMODE  ; 32BIT PROTECTED MODE

        mov ax, 0x4F02      ; VBE Function
        mov bx, 0x4117      ; 1024*768 res. 16bit(R(5) : G(6) : B(5))
                            ; SET LINEAR FRAME BUFFER MODE
                            ; VBE MODE(Bit 0~8) = 0x117
                            ; BUFFER MODE(Bit 14) = 1(LINEAR FRAME BUFFER MODE)

        int 0x10
        cmp ax, 0x004F      ; ERROR HANDLING
        jne VBEERROR

        jmp JUMPTOPROTECTEDMODE

        VBEERROR:
        jmp $

        JUMPTOPROTECTEDMODE:
            jmp 0x1000:0x0000
    HANDLE_DISKERROR:
        jmp $

SECTORNUMBER:           db  0x02
HEADNUMBER:             db  0x00
TRACKNUMBER:            db  0x00
    
times 510 - ( $ - $$ ) db 0
db 0x55, 0xAA
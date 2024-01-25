; Copyright (c) Awesome
; All rights reserved.
;
; Based on x86 arch.

BITS 64

; Multiboot2 Header for x86_64
section .multiboot_header
    align 8
    mb2_header_start:
        dd 0xe85250d6                           ; magic number
        dd 0                                    ; arch(32-bit)
        dd mb_header_end - mb2_header_start     ; header length
        dd -(0xe85250d6 + 0 + (mb2_header_end - mb2_header_start))  ; checksum
    mb2_header_end:

section .bss
align 8

stack_bottom:
    resb 4096   ; 4KB Stack
stack_top:


section .text
global _start
_start:
    ; setup stack
    mov rsp, stack_top

    ; Zero out the BSS Section
    extern bss_start
    extern bss_end

    mov rdi, bss_start
    mov rsi, bss_end

    sub rsi, rdi
    xor rax, rax
    rep stosb

    ; Check for 64bit mode(IA-32e(long mode))
    mov eax, 80000000h
    cpuid
    cmp eax, 80000001h
    jb not_long_mode

    ; enable long mode
    mov ecx, 0xC0000080
    rdmsr
    bts rax, 8
    wrmsr

    ; Load GDT, IDT, etc.
    
    ; Jump to higher half kernel code (if using higher half setup)

    ; Placeholder for kernel main functin call
    ; call kernel_main

    ; Hang the system

hang:
    hlt
    jmp hang

not_long_mode:
    ; Display error message or halt if not in long mode

section .data
; Global Descriptor Table(GDT), Interrupt Desciptor Table(IDT), etc..

; C Kernel EntryPoint Here
extern kernel_main
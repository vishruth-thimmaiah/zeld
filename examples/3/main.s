.global _start

.section .text
_start:
    mov $60, %rax
    mov $3, %rdi
    syscall


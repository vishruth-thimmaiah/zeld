const std = @import("std");
const helpers = @import("tests.zig");

test "basic" {
    const main_asm =
        \\ .global _start
        \\ 
        \\ .section .text
        \\ _start:
        \\     mov $60, %rax
        \\     mov $7, %rdi
        \\     syscall
        \\
    ;

    const result = try helpers.build_exec(main_asm);

    try std.testing.expectEqual(7, result);
}

test "basic with data" {
    const main_asm =
        \\ .global _start
        \\
        \\ .section .data
        \\ num:
        \\     .quad 10
        \\
        \\ .section .text
        \\ _start:
        \\     mov $60, %rax
        \\     mov num, %rdi
        \\     syscall
        \\
    ;

    const result = try helpers.build_exec(main_asm);

    try std.testing.expectEqual(10, result);
}

test ".bss" {
    const main_asm =
        \\ .global _start
        \\ 
        \\ .section .data
        \\ data_num:
        \\ .long 42
        \\ 
        \\ .section .bss
        \\ .lcomm num, 4
        \\ 
        \\ .section .text
        \\ _start:
        \\ movl data_num(%rip), %eax
        \\ movl %eax, num(%rip)
        \\ movl num(%rip), %edi
        \\ movl $60, %eax
        \\ syscall
        \\
    ;

    const result = try helpers.build_exec(main_asm);

    try std.testing.expectEqual(42, result);
}

test "hello world!" {
    const main_asm =
        \\ .section .text
        \\ .global _start
        \\ 
        \\ _start:
        \\     call print_hello
        \\     mov $60, %rax
        \\     mov $32, %rdi
        \\     syscall
        \\ 
        \\ print_hello:
        \\     mov $1, %rax
        \\     mov $1, %rdi
        \\     lea message(%rip), %rsi
        \\     mov $14, %rdx          # length of string
        \\     syscall
        \\     ret
        \\ 
        \\ .section .rodata
        \\ message:
        \\     .ascii "Hello, world!\n"
        \\
    ;

    const result = try helpers.build_exec(main_asm);
    try std.testing.expectEqual(32, result);
}

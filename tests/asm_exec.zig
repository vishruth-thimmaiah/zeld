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

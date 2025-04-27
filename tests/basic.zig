const std = @import("std");
const helpers = @import("tests.zig");

test "basic" {
    const test_c =
        \\ int test() {
        \\     return 5;
        \\ }
    ;

    const main_c =
        \\ int test();
        \\
        \\ int main() {
        \\     return test();
        \\ }
    ;

    const result = try helpers.build(test_c, main_c);

    try std.testing.expectEqual(5, result);
}

test "basic_with_print" {
    const test_c =
        \\ #include <stdio.h>
        \\
        \\ int greet() {
        \\     printf("hello world!\n");
        \\     return 3;
        \\ }
    ;

    const main_c =
        \\ int greet();
        \\
        \\ int main() {
        \\     return greet();
        \\ }
    ;
    const result = try helpers.build(test_c, main_c);

    try std.testing.expectEqual(3, result);
}

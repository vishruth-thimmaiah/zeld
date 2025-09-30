const std = @import("std");
const helpers = @import("tests.zig");

test "basic_clib" {
    const main_c =
        \\ int main() {
        \\     return 5;
        \\ }
    ;

    const result = try helpers.build_clib_exec(main_c);

    try std.testing.expectEqual(5, result);
}

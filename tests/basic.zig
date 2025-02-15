const std = @import("std");
const helpers = @import("tests.zig");

test "basic" {
    const test_c =
        \\int test() {
        \\    return 5;
        \\}
    ;

    const main_c =
        \\int test();
        \\
        \\int main() {
        \\    return test();
        \\}
    ;

    const result = try helpers.build(test_c, main_c);

    try std.testing.expectEqual(5, result);
}

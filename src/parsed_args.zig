const std = @import("std");

const Arg = @import("Arg.zig");

pub const PositionalArg = struct { value: []const u8 };

pub const Flag = struct {
    arg: Arg,
    param: ?[]const u8,
};

pub const ParsedArgs = struct {
    allocator: std.mem.Allocator,
    flags: std.AutoHashMap(u8, Flag),
    positionalArgs: std.ArrayList(PositionalArg),
};

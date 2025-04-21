const std = @import("std");

const Arg = @import("Arg.zig");
const ParsedArgs = @import("parsed_args.zig");

const App = @This();

const stdout_file = std.io.getStdOut();
var buf = std.io.bufferedWriter(stdout_file.writer());
const stdout = buf.writer();
const stderr = std.io.getStdErr().writer();

///DO NOT USE DIRECTLY
allocator: std.mem.Allocator,
name: []const u8,
args: std.AutoHashMap(u8, Arg),
usage: []const u8,
author: []const u8,
numMandatoryPosArgs: usize,
version: []const u8,
parsedArgs: ParsedArgs.ParsedArgs,

pub fn deinit(self: *App) void {
    self.args.deinit();
    self.parsedArgs.flags.deinit();
    self.parsedArgs.positionalArgs.deinit();
}

pub fn validateParsedArgs(self: *const App) !void {
    if (self.parsedArgs.flags.contains('h')) {
        try self.printHelp();
        std.process.exit(0);
    }

    //check if sufficient number of positional arguments have been parsed
    if (self.parsedArgs.positionalArgs.items.len < self.numMandatoryPosArgs) {
        try stderr.print("Not enough positional arguments provided. (Needed: {d}, provided: {d})\n", .{ self.numMandatoryPosArgs, self.parsedArgs.positionalArgs.items.len });
        try self.printUsage();
        std.process.exit(1);
    }

    if (!self.allMandatoryArgsArePresent()) {
        try stderr.print("Not all mandatory arguments provided\n", .{});
        try self.printUsage();
        std.process.exit(1);
    }
}

pub fn allMandatoryArgsArePresent(self: *const App) bool {

    //iterate through all registered args to check if all mandatory ones are present in the parsed args
    var entries = self.args.iterator();
    var flag_entries = self.parsedArgs.flags.iterator();
    var found = false;
    while (entries.next()) |entry| {
        if (!entry.value_ptr.*.isMandatory) continue;
        while (flag_entries.next()) |flag_entry| {
            if (flag_entry.key_ptr.* == entry.key_ptr.*) {
                found = true;
            }
        }
        if (!found) return false;
    }
    return true;
}

pub fn printApp(self: *const App) !void {
    try stdout.print("{s}, version: {s}\nAuthor: {s}\n", .{ self.name, self.version, self.author });
    try buf.flush();
}

pub fn printUsage(self: *const App) !void {
    try stdout.print("{s}\n", .{self.usage});
    try buf.flush();
}

pub fn printHelp(self: *const App) !void {
    try stdout.writeAll("\n");
    try self.printApp();
    try stdout.writeAll("\n");
    try self.printUsage();
    try stdout.writeAll("\n");

    var iterator = self.args.iterator();
    while (iterator.next()) |arg| {
        try stdout.print("{c}: {s}\n", .{ arg.key_ptr.*, arg.value_ptr.description });
    }

    try stdout.writeAll("\n");
    try buf.flush();
}

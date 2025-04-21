const std = @import("std");

const ZigParser = @import("zigparser");
const App = ZigParser.App;
const AppBuilder = ZigParser.AppBuilder;
const Arg = ZigParser.Arg;

const stdout_file = std.io.getStdOut().writer();
var buf = std.io.bufferedWriter(stdout_file);
const stdout = buf.writer();
const stdin = std.io.getStdIn();
const stderr = std.io.getStdErr().writer();

var gpa = std.heap.GeneralPurposeAllocator(.{}).init;

pub fn main() !void {
    const allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
            std.process.exit(1);
        }
    }
    var default_builder = AppBuilder.defaultBuilder(allocator, "MyGrep");
    var builder = default_builder.addAuthor("Tommy").addNumMandatoryPosArgs(1).addUsage(try std.fmt.allocPrint(allocator, "Usage: {s} <pattern> [options...] [filenames...]", .{std.mem.span(std.os.argv[0])}));
    _ = try builder.addArg(Arg.make_arg('n', "number", "Add line numbers", false, false));
    _ = try builder.addArg(Arg.make_arg('m', "max-count", "Stop after n lines", true, false));
    var app = try builder.build();
    defer app.deinit();
    defer allocator.free(app.usage);

    const numFilenames = app.parsedArgs.positionalArgs.items.len;

    if (numFilenames > 0) {
        for (app.parsedArgs.positionalArgs.items[1..]) |filename| {
            var file = std.fs.cwd().openFile(filename.value, .{ .mode = .read_only }) catch |err| {
                try stderr.print("Could not open file: {s}\n{}\n", .{ filename.value, err });
                break;
            };
            defer file.close();
            try stdout.print("{s}:\n", .{filename.value});
            try grep(&file, &app);
            try stdout.writeAll("\n");
        }
    } else {
        //try stdout.writeAll("STDIN");
        try grep(&stdin, &app);
    }

    try buf.flush();
}

fn grep(file: *const std.fs.File, app: *const App) !void {
    const print_nums = if (app.parsedArgs.flags.contains('n'))
        true
    else
        false;
    const max_lines_str = if (app.parsedArgs.flags.contains('m'))
        app.parsedArgs.flags.get('m').?.param.?
    else
        "0";
    const max_lines = std.fmt.parseInt(usize, max_lines_str, 10) catch {
        try stderr.print("Invalid value provided for max number of lines: {s}\n", .{max_lines_str});
        std.process.exit(1);
    };
    var reader = file.reader();
    var buffer: [1024]u8 = undefined;
    var line_count: usize = 0;
    var matching_line_count: usize = 0;
    while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        line_count += 1;
        if (max_lines > 0 and max_lines <= matching_line_count) {
            break;
        }
        if (std.mem.indexOf(u8, line, app.parsedArgs.positionalArgs.items[0].value) != null) {
            matching_line_count += 1;
            if (print_nums) {
                try stdout.print("{d}\t", .{line_count});
            }
            try stdout.print("{s}\n", .{line});
        }
        try buf.flush();
    }
    try buf.flush();
}

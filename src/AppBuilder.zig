const std = @import("std");

const App = @import("App.zig");
const Arg = @import("Arg.zig");
const ParsedArgs = @import("parsed_args.zig");

const AppBuilder = @This();

const stdout_file = std.io.getStdOut();
var out = std.io.bufferedWriter(stdout_file.writer());
const stdout = out.writer();
const stderr = std.io.getStdErr().writer();

allocator: std.mem.Allocator,
name: []const u8,
args: std.AutoHashMap(u8, Arg),
usage: []const u8,
author: []const u8,
numMandatoryPosArgs: usize,
version: []const u8,

pub fn defaultBuilder(allocator: std.mem.Allocator, name: []const u8) AppBuilder {
    const builder = AppBuilder{ .allocator = allocator, .args = std.AutoHashMap(u8, Arg).init(allocator), .name = name, .version = "0.1.1", .usage = "", .numMandatoryPosArgs = 0, .author = "" };
    return builder;
}

pub fn build(self: *AppBuilder) !App {
    try self.args.put('h', Arg.make_arg('h', "help", "Print help information", false, false));
    const parsed_args = try self.parseArgs();
    const app = App{
        .allocator = self.allocator,
        .args = self.args,
        .author = self.author,
        .name = self.name,
        .numMandatoryPosArgs = self.numMandatoryPosArgs,
        .usage = self.usage,
        .version = self.version,
        .parsedArgs = parsed_args,
    };

    try app.validateParsedArgs();

    return app;
}

pub fn addUsage(self: *AppBuilder, usage: []const u8) *AppBuilder {
    self.usage = usage;
    return self;
}

pub fn addAuthor(self: *AppBuilder, author: []const u8) *AppBuilder {
    self.author = author;
    return self;
}

pub fn addArg(self: *AppBuilder, arg: Arg) !*AppBuilder {
    try self.args.put(arg.shortName, arg);
    return self;
}

pub fn addNumMandatoryPosArgs(self: *AppBuilder, num_args: usize) *AppBuilder {
    self.numMandatoryPosArgs = num_args;
    return self;
}

fn parseArgs(self: *const AppBuilder) !ParsedArgs.ParsedArgs {
    var skip_arg = false;
    var parsed_args = ParsedArgs.ParsedArgs{ .allocator = self.allocator, .flags = std.AutoHashMap(u8, ParsedArgs.Flag).init(self.allocator), .positionalArgs = std.ArrayList(ParsedArgs.PositionalArg).init(self.allocator) };

    for (std.os.argv[1..], 1..) |argument, idx| {

        //skipping arg if previous argument already consumed as parameter to flag
        if (skip_arg) {
            skip_arg = false;
            continue;
        }

        //converting [*:0] to []const u8
        const arg = std.mem.span(argument);

        //if flag
        if (arg[0] == '-' and arg.len > 1) {

            //if short flag
            if (arg[1] != '-') {

                //iterating through single characters in -flag
                for (arg[1..], 1..) |c, c_idx| {

                    //if char found in registered flags
                    if (self.args.contains(c)) {
                        const flag = self.args.get(c).?;

                        //if flag takes no params, store it with no arguments and proceed to next iteration
                        if (!flag.takesParam) {
                            try parsed_args.flags.put(c, ParsedArgs.Flag{ .arg = self.args.get(c).?, .param = null });
                        }

                        //if flag taking a parameter is not followed by a space or =, report error and exit
                        else if (arg.len >= c_idx and (arg.len < c_idx and arg[c_idx + 1] != '=')) {
                            try stderr.print("No argument provided for {c}\n", .{c});
                            std.process.exit(1);
                        }

                        //if flag taking a parameter is followed by =
                        else if (arg.len > c_idx + 2 and arg[c_idx + 1] == '=') {
                            try parsed_args.flags.put(c, ParsedArgs.Flag{ .arg = self.args.get(c).?, .param = arg[c_idx + 2 ..] });

                            //should not continue iterating short flags
                            break;
                        }

                        //if flag takes parameter, check and consume next token
                        else if (idx + 1 < std.os.argv.len and std.os.argv[idx + 1][0] != '-') {
                            try parsed_args.flags.put(c, ParsedArgs.Flag{ .arg = self.args.get(c).?, .param = std.mem.span(std.os.argv[idx + 1]) });
                            skip_arg = true;
                        }

                        //argument not found, report error and exit
                        else {
                            try stderr.print("No argument provided for {c}\n", .{c});
                            std.process.exit(1);
                        }
                    }

                    //Did not find short flag in registered args. Report error and exit.
                    else {
                        try stderr.print("Invalid flag: {c}\n", .{c});
                        std.process.exit(1);
                    }
                }
            }

            //long flag
            else if (arg.len > 2 and arg[1] == '-') {
                var entries = self.args.iterator();
                var found = false;

                //iterate through all registered long flags to check if token is a match
                while (entries.next()) |entry| {
                    const short_name = entry.value_ptr.*.shortName;
                    //if match found
                    if (std.mem.eql(u8, entry.value_ptr.longName, arg[2..])) {

                        //if flag takes no params, store it with no arguments and proceed to next iteration
                        if (!entry.value_ptr.takesParam) {
                            try parsed_args.flags.put(entry.key_ptr.*, ParsedArgs.Flag{ .arg = entry.value_ptr.*, .param = null });
                            found = true;
                            break;
                        }

                        //if flag takes parameter, check and consume next token
                        else if (idx + 1 < std.os.argv.len and std.os.argv[idx + 1][0] != '-') {
                            try parsed_args.flags.put(short_name, ParsedArgs.Flag{ .arg = entry.value_ptr.*, .param = std.mem.span(std.os.argv[idx + 1]) });
                            found = true;
                            break;
                        }

                        //Next token does not exist or is a flag, so no param was found
                        else {
                            try stderr.print("No argument provided for {s}\n", .{arg});
                            std.process.exit(1);
                        }
                    }

                    //If arg is matched and has = in it without spaces
                    else if (arg.len > entry.value_ptr.longName.len + 2 and std.mem.eql(u8, entry.value_ptr.longName, arg[2 .. entry.value_ptr.longName.len + 2]) and arg[entry.value_ptr.longName.len + 2] == '=') {
                        try parsed_args.flags.put(short_name, ParsedArgs.Flag{ .arg = entry.value_ptr.*, .param = arg[entry.value_ptr.longName.len + 3 ..] });
                        found = true;
                        break;
                    }
                }

                //if no match found, report error and exit.
                if (!found) {
                    try stderr.print("Invalid flag: {s}\n", .{arg});
                    std.process.exit(1);
                }
            }
        }

        //token is not a flag, therefore register it as a positional argument
        else {
            try parsed_args.positionalArgs.append(ParsedArgs.PositionalArg{ .value = arg });
            skip_arg = false;
        }
    }

    return parsed_args;
}

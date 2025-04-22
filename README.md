# ZLIPARSER
A simple utility to automatically create and parse command-line arguments for Zig applications. 

Loosely based on the structure and API of the Clap crate in Rust.

For the time being it is primarily developed as a learning exercise and for my own command-line tools, but any comments or contributions are welcome.

## Supported features:
-  Positional arguments, including defining a minimum number of mandatory positional arguments, e.g. "grep [OPTION]... PATTERNS [FILE]...", where at least one positional argument (pattern) is mandatory, while several more can be optionally provided [FILE]...
-  Long and short flags (e.g. -n and --number). Short flags may be combined (e.g. -mi). Flags may take a mandatory parameter with the following formats: (--number 42, --number=42, -in=42, -in 42). Flags may be declared mandatory.
-  Automatic generation of help information when -h or --help flag is used.

## Usage
- First, an AppBuilder is created by calling the defaultBuilder method. This method takes and std.mem.Allocator (which will be the global allocator for both the builder and the cliparser) and the app's name.
- The builder has methods to add author, version, usage information, as well as arguments/flags that the parser will be able to handle. The --help information will be automatically generated based on these.
- The build() method of the builder will parse the provided command-line arguments (std.os.argv), and return an App instance, which includes all information related to the parsed arguments.
- If some of the predefined conditions are not met (e.g. not enough positional arguments, invalid flags, or missing mandatory arguments to flags), an error message is printed and the programme terminates. This is in line with the usual practice of command-line applications, where invalid or inconsistent arguments are provided.
- Methods and data fields on the app instance can be used to retrieve information about the provided arguments.

## Including in source code
- The files in the src directory can be directly copied into the project source directory. Source files (typically the file that includes the main function) can simply @include("lib.zig"), assign it to a constant (e.g. const CliParser = @include("lib.zig")), and then refer to the relevant structures and methods as CliParser.AppBuilder.defaultBuilder(...).

## Example
```zig
 var default_builder = AppBuilder.defaultBuilder(allocator, "MyGrep");
 var builder = default_builder.addAuthor("Tommy")
                              .addNumMandatoryPosArgs(1)
                              .addUsage(try std.fmt.allocPrint(allocator, "Usage: {s} <pattern> [options...] [filenames...]", .{std.mem.span(std.os.argv[0])}));
 _ = try builder.addArg(Arg.make_arg('n', "number", "Add line numbers", false, false));
 _ = try builder.addArg(Arg.make_arg('m', "max-count", "Stop after n lines", true, false));
 var app = try builder.build();
 defer app.deinit();
 defer allocator.free(app.usage);

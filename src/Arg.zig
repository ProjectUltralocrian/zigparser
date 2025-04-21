const Arg = @This();

shortName: u8,
longName: []const u8,
description: []const u8,
takesParam: bool,
isMandatory: bool,

pub fn make_arg(short_name: u8, long_name: []const u8, description: []const u8, takes_arg: bool, is_mandatory: bool) Arg {
    return Arg{
        .shortName = short_name,
        .description = description,
        .isMandatory = is_mandatory,
        .takesParam = takes_arg,
        .longName = long_name,
    };
}

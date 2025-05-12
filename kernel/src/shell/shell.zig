const std = @import("std");
const os = @import("root").os;

const print = os.console_write("shell");

pub fn execute(input: []const u8) void {
    
    //print.dbg("Shell invoked for \"{s}\"", .{input});
    var iterator = std.mem.tokenizeScalar(u8, input, ' ');

    print.raw("@ adam > {s}\n", .{input});
    if (iterator.next()) |command| {

        if (std.mem.eql(u8, command, "cls")) {
            print.dbg("Cleaning the console", .{});
            os.debug_log.clear_history();
        }

        else if (std.mem.eql(u8, command, "reboot")) {
            print.dbg("Rebooting", .{});
            @import("../sysprocs/adam/adam.zig").reboot();
        }
        else if (std.mem.eql(u8, command, "shutdown")) {
            @import("../sysprocs/adam/adam.zig").shutdown();
        }

        else if (std.mem.eql(u8, command, "lsdir")) {
            const path = iterator.next() orelse "";
            os.fs.ls(path);
        }
        else if (std.mem.eql(u8, command, "lsproc")) {
            os.theading.taskManager.lsproc();
        }

        else print.raw("\x1b[31;40mNo command, alias or program \'{s}\' found!\x1b[0m\n", .{command});
    }

}

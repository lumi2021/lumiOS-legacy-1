const File = @import("File.zig");

pub fn openFileAbsolute(absolute_path: [:0]u8, flags: File.AccessFlags) File.OpenFileError!File {
    return try File.open(absolute_path, flags);
}

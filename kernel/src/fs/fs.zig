// File system:
//     <letter>:/      - default partitions
//     sys:/           - virtual system directories
//      '_ proc/       - processes
//          |- self    - caller process dir
//          '- <pid>   - specific process dir
//     dev:/           - virtual device interfaces

pub const FileAccessFlags = packed struct(u64) {
    read: bool,
    write: bool,
    execute: bool,
    create_new: bool,
    _: u60,
};

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;
var fileTree: struct {

    drives: []?*FsNode,

    sys: *FsNode,
    dev: *FsNode,

} = undefined;


pub fn init() !void {
    st.push(@src()); defer st.pop();
    write.log("Initializing file system...", .{});

    arena = std.heap.ArenaAllocator.init(os.memory.allocator);
    allocator = arena.allocator();

    fileTree.drives = allocator.alloc(?*FsNode, 16) catch undefined;
    @memset(fileTree.drives, null);

    fileTree.sys = FsNode.init("sys:", .{ .virtual_directory = undefined }); {
        const proc = fileTree.sys.branch("proc", .{ .virtual_directory = undefined }); {
            _ = proc.branch("self", .{ .symlink = .{ .linkTo = "sys:/proc/$THREAD_ID" } });
        }
    }
    fileTree.dev = FsNode.init("dev:", .{ .virtual_directory = undefined }); {
        _ = fileTree.dev.branch("keyboard", .{ .sharedPipe = undefined });
        _ = fileTree.dev.branch("mouse", .{ .sharedPipe = undefined });
        _ = fileTree.dev.branch("textscan", .{ .sharedPipe = undefined });
    }
}

pub fn ls(path: []const u8) void {
    if (std.mem.eql(u8, path, "")) {
        for (fileTree.drives) |i| { if (i) |e| write.raw("{s: <15}{s}\n", .{e.name, @tagName(e.kind())}); }
        write.raw("sys:           virtual_directory\n", .{});
        write.raw("dev:           virtual_directory\n", .{});
        return;
    }
    lsnode(solve_path(path) catch |err| {
        write.err("error: {s}", .{@errorName(err)});
        return;
    });
}
pub fn lsnode(node: *FsNode) void {
    for (node.children.items) |e| {
        write.raw("{s: <15}{s}\n", .{e.name, @tagName(e.kind())});
    }
}
pub fn lsrecursive() void {
    for (fileTree.drives) |d| lsRecursiveWithLevel(d, 0);
    lsRecursiveWithLevel(fileTree.sys, 0);
    lsRecursiveWithLevel(fileTree.dev, 0);
}
fn lsRecursiveWithLevel(node: ?*FsNode, level: usize) void {
    if (node == null) return;

    for (0..level) |_| write.raw("  ", .{});
    if (node.?.kind() == .directory or node.?.kind() == .virtual_directory)
        write.raw("{s}/\r\n", .{node.?.name})
    else
        write.raw("{s}\r\n", .{node.?.name});

    for (node.?.children.items) |e| lsRecursiveWithLevel(e, level + 1);
}

// Drives related
pub fn append_disk_drive(disk_entry: disk.DiskEntry) void {
    if (fileTree.drives[disk_entry.index] != null) @panic("disk slot already ocupped!");
    const drive_name: [2]u8 = .{('A' + @as(u8, @intCast(disk_entry.index))), ':'};
    fileTree.drives[disk_entry.index] = FsNode.init(&drive_name, .{ .disk = disk_entry });
}
pub fn reset_drive(slot: usize) void {
    st.push(@src()); defer st.pop();
    
    const letter = 'A' + @as(u8, @intCast(slot));
    const drive = fileTree.drives[slot] orelse return;
    if (drive.data != .disk) return;

    write.dbg("reseting drive {c} data...", .{letter});

    var sector: [512]u8 = undefined;
    disk.read(drive.data.disk, 0, &sector);

    for (0..32) |y| {
        for (0..16) |x| {
            write.raw("{X:0>2} ", .{sector[x + y * 16]});
        }
        write.raw("\n", .{});
    }

    if (sector[0x1FE] == 0x55 and sector[0x1FF] == 0xAA) {
        write.dbg("Sector is MBR", .{});
    }

    write.dbg("driver {c} reseted!", .{letter});
}

pub fn make_dir(path: []const u8) (OpenPathError || CreateError)!*FsNode {
    st.push(@src()); defer st.pop();

    const last_slash = std.mem.lastIndexOf(u8, path, "/") orelse return OpenPathError.invalidPath;
    const subpath = path[0..last_slash];
    
    var subdir = try solve_path(subpath);
    if (subdir.kind() != .directory and subdir.kind() != .virtual_directory)
        return OpenPathError.notADirectory;

    if (subdir.getChild(path[(last_slash + 1)..]) != null) return error.nameAlreadyExists;

    if (subdir.kind() == .virtual_directory)
        return subdir.branch(path[(last_slash + 1)..], .{ .virtual_directory = undefined })
    else
        return subdir.branch(path[(last_slash + 1)..], .{ .directory = undefined });
}
pub fn make_file(path: []const u8, data: FsNodeData) (OpenPathError || CreateError)!void {
    st.push(@src()); defer st.pop();

    const last_slash = std.mem.lastIndexOf(u8, path, "/") orelse return OpenPathError.invalidPath;
    const subpath = path[0..last_slash];
    
    var subdir = try solve_path(subpath);
    if (subdir.kind() != .directory) return OpenPathError.notADirectory;

    if (subdir.getChild(path[(last_slash + 1)..]) != null) return error.nameAlreadyExists;
    return subdir.branch(path[(last_slash + 1)..], data);
}

// system call actions
pub fn open_file_descriptor(path: [:0]u8, flags: FileAccessFlags) OpenFileError!isize {
    st.push(@src()); defer st.pop();

    // global paths can only start with `[c]:/` so aways at least 3 characters
    if (path.len < 3) return error.invalidPath;

    write.log("Trying to open file \"{s}\" (len {})", .{ path, path.len });

    const task = schedue.current_task.?;
    const handler: usize = @intCast(task.get_resource_index() catch error._undefined); // FIXME add proper error
    errdefer task.free_resource_index(@bitCast(handler)) catch unreachable;

    _ = flags;

    const file = try solve_path(path);
    const res = &task.resources[@bitCast(handler)];
    res.fsnode = file;

    res.data = switch (file.data) {
        .pipe => |*e| .{ .pipe = .{ .pipePtr = e.pipePtr } },

        else => return error.invalidPath
    };

    return @bitCast(handler);
}
pub fn close_file_descriptor(handler: usize) void {
    write.log("Closing file descriptor {}", .{handler});

    const current_task = schedue.current_task.?;
    // TODO handle error
    current_task.free_resource_index(handler) catch unreachable;
}

pub fn write_file_descriptor(task: *Task, descriptor: usize, buffer: []u8, pos: usize) OpenFileError!void {
    st.push(@src()); defer st.pop();

    const fileHandler = &task.resources[descriptor];
    if (fileHandler.in_use == false) return error.invalidDescriptor;
    write.dbg("writing in file \"{s}\"", .{fileHandler.fsnode.name});

    const bufcopy = allocator.alloc(u8, pos + buffer.len) catch unreachable;
    @memset(bufcopy, 0);
    @memcpy(bufcopy[pos..], buffer);

    switch (fileHandler.data) {
        .pipe => |*p| {
            const item: [1][]u8 = .{ bufcopy };
            p.pipePtr.buffer.write(&item) catch unreachable;
        },

        else => write.err("write in {s} not handled", .{@tagName(fileHandler.data)})
    }
}
pub fn read_file_descriptor(task: *Task, descriptor: usize, buffer: []u8, pos: usize) ReadFileError!void {
    st.push(@src()); defer st.pop();

    const fileHandler = &task.resources[descriptor];
    if (fileHandler.in_use == false) return error.invalidDescriptor;
    write.dbg("writing in file \"{s}\"", .{fileHandler.fsnode.name});

    const bufcopy = allocator.alloc(u8, pos + buffer.len) catch unreachable;
    @memset(bufcopy, 0);
    @memcpy(bufcopy[pos..], buffer);

    switch (fileHandler.data) {
        else => write.err("read from {s} not handled", .{@tagName(fileHandler.data)})
    }
}

fn solve_path(path: []const u8) OpenPathError!*FsNode {
    st.push(@src()); defer st.pop();

    var iter = std.mem.tokenizeAny(u8, path, "/");
    var cur: *FsNode = try get_tree_root(iter.next().?);

    var s = iter.next();
    while (s != null) : (s = iter.next()) {
        var step = s.?;

        // variables
        if (step[0] == '$') {

            if (std.mem.eql(u8, step[1..], "THREAD_ID")) {
                var str: [16]u8 = undefined;
                step = std.fmt.bufPrint(&str, "{X:0>5}", .{schedue.current_task.?.id}) catch unreachable;
            }
            else return error.pathNotFound;
        }

        if (cur.getChild(step)) |c| {
            switch (c.data) {
                .symlink => {
                    write.log("branching into symbolic link \"{s}\"", .{c.data.symlink.linkTo});
                    cur = try solve_path(c.data.symlink.linkTo);
                    
                    if (cur.kind() != .directory and cur.kind() != .virtual_directory)
                        return error.notADirectory;
                },
                .directory ,
                .virtual_directory => cur = c,
                
                else => return c
            }
        }
        else {
            write.warn("searching for: {s}", .{step});
            return error.pathNotFound;
        }
    }

    return cur;
}
fn get_tree_root(token: []const u8) OpenPathError!*FsNode {
    st.push(@src()); defer st.pop();

    if (token.len <= 2 or token[token.len - 1] != ':') return error.invalidPath;

    if (token.len == 2 and fileTree.drives['A' - token[0]] != null) return fileTree.drives['A' - token[0]].?;
    if (token.len == 4 and std.mem.eql(u8, token, "sys:")) return fileTree.sys
    else if (token.len == 4 and std.mem.eql(u8, token, "dev:")) return fileTree.dev

    else return error.invalidPath;
}

// imports
const std = @import("std");
const os = @import("root").os;
const schedue = os.theading.schedue;

const Task = os.theading.Task;
const ResourceHandler = os.system.ResourceHandler;

const drives = @import("drives.zig");
const FAT = @import("formats/FAT.zig");

const disk = os.drivers.disk;
const  ahci = disk.ahci;

const write = os.console_write("fs");
const st = os.stack_tracer;

pub const FsNode = @import("fsnode.zig").FsNode;
pub const FsNodeList = @import("fsnode.zig").FsNodeList;
pub const FsNodeData = @import("fsnode.zig").FsNodeData;

// error tables
pub const FsError = OpenFileError || OpenPathError;

pub const ReadFileError = error {}
|| PermitionError
|| GeneralError;
pub const WriteFileError = error {}
|| PermitionError
|| GeneralError;


pub const OpenFileError = error {
    fileNotFound,
    notAFile,
}
|| OpenPathError
|| PermitionError
|| GeneralError;

pub const OpenPathError = error {
    invalidPath,
    pathNotFound,
    notADirectory
}
|| GeneralError;

pub const CreateError = error {
    nameAlreadyExists
}
|| OpenPathError
|| PermitionError
|| GeneralError;

pub const PermitionError = error {
    accessDenied
};

pub const GeneralError = error { invalidDescriptor, _undefined };

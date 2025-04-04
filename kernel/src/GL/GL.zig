pub var main_frameBuffer: []Pixel = undefined;

pub var canvasPPS: usize = 0;
pub var canvasWidth: usize = 0;
pub var canvasHeight: usize = 0;
pub var canvasBPP: u8 = 0;
pub var ready = false;

var allocator: Allocator = undefined;
var vcontextList: VctxList = undefined;

pub fn init(fb: bootInfo.FrameBuffer) void {
    st.push(@src()); defer st.pop();

    const fb_ptr: [*]Pixel = @ptrCast(@alignCast(fb.framebuffer));
    main_frameBuffer = fb_ptr[0..(fb.size / 4)];

    canvasPPS = fb.size / 4 / fb.height;
    canvasWidth = fb.width;
    canvasHeight = fb.height;
    canvasBPP = @intCast((fb.size * 8) / (canvasWidth * canvasHeight));

    vcontextList.init(os.memory.allocator);

    write.log(\\
    \\fb size: {}
    \\pps: {}
    \\bpp: {}
    \\canvas width: {}
    \\canvas height: {}
    , .{ fb.size, canvasPPS, canvasBPP, canvasWidth, canvasHeight });

    ready = true;
}

pub fn get_context() usize {
    
    const newContextIndex: usize = b: { 
        for (0..vcontextList.items.len) |i| {
            if (vcontextList.items[i] == null) break :b i;
        }
        vcontextList.addOne(null) catch unreachable;
        break :b vcontextList.items.len - 1;
    };


    return newContextIndex;
}


// bruh inports
const std = @import("std");
const os = @import("root").os;
const bootInfo = @import("../boot/boot_info.zig");
const Allocator = std.mem.Allocator;

pub const Pixel = packed struct(u32) {
    blue: u8,
    green: u8,
    red: u8,
    alpha: u8,

    pub inline fn rgb(r: usize, g: usize, b: usize) Pixel {
        return .{
            .red = @intCast(r & 0xFF),
            .green = @intCast(g & 0xFF),
            .blue = @intCast(b & 0xFF),
            .alpha = 0
        };
    }
};
pub const VideoMode = enum { text, graph };
pub const VideoContext = struct {
    
    window: *Win,

    pub fn init(winWidth: usize, winHeight: usize, mode: VideoMode) @This() {
        // Init the video mode and create
        // the window framebuffers

        var newvctx = allocator.create(@This()) catch unreachable;
        newvctx.window = allocator.create(Win) catch unreachable;

        newvctx.window.height = winHeight;
        newvctx.window.width = winWidth;
        newvctx.window.mode = mode;

        if (mode == .text) {
            const b1 = allocator.alloc(u8, winHeight * winWidth) catch unreachable;
            const b2 = allocator.alloc(u8, winHeight * winWidth) catch unreachable;
            newvctx.window.buffer_0 = .{ .char = b1.ptr };
            newvctx.window.buffer_1 = .{ .char = b2.ptr };
        }
        else if (mode == .graph) {
            const b1 = allocator.alloc(u8, winHeight * winWidth * 4) catch unreachable;
            const b2 = allocator.alloc(u8, winHeight * winWidth * 4) catch unreachable;
            newvctx.window.buffer_0 = .{ .graph = b1.ptr };
            newvctx.window.buffer_1 = .{ .graph = b2.ptr };
        }

        return newvctx;
    }
};
pub const VctxList = std.ArrayList(?VideoContext);
pub const Win = @import("win/win.zig").Win;

const write = os.console_write("Graphics Lib");
const st = os.stack_tracer;

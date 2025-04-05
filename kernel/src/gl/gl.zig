pub var root_framebuffer: []Pixel = undefined;

pub var canvasBPP: u8 = 0;
pub var canvasPPS: usize = 0;

pub var canvasPixelWidth: usize = 0;
pub var canvasPixelHeight: usize = 0;

pub var canvasCharWidth: usize = 0;
pub var canvasCharHeight: usize = 0;

var system_font: Font = undefined;

pub var ready = false;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: Allocator = undefined;

pub var window_list: []?*Win = undefined;

pub fn init(fb: bootInfo.FrameBuffer) void {
    st.push(@src()); defer st.pop();

    system_font = @import("assets/assets.zig").fonts[0];
    system_font.scale = 2;

    const fb_ptr: [*]Pixel = @ptrCast(@alignCast(fb.framebuffer));
    root_framebuffer = fb_ptr[0..(fb.size / 4)];

    canvasPPS = fb.size / 4 / fb.height;
    canvasBPP = @intCast((fb.size * 8) / (fb.width * fb.height));

    canvasPixelWidth = fb.width;
    canvasPixelHeight = fb.height;
    canvasCharWidth = @divTrunc(fb.width, system_font.width * system_font.scale);
    canvasCharHeight = @divTrunc(fb.height, system_font.height * system_font.scale);

    // setting up arena allocator
    arena = std.heap.ArenaAllocator.init(os.memory.allocator);
    allocator = arena.allocator();

    window_list = allocator.alloc(?*Win, 256) catch unreachable;
    @memset(window_list, null);

    write.log(\\
    \\fb size: {}
    \\fb pos: ${X:0>16}
    \\pps: {}
    \\bpp: {}
    \\canvas width: {} pixels, {} chars
    \\canvas height: {} pixels, {} chars
    , .{
        root_framebuffer.len,
        os.memory.paddr_from_vaddr(@intFromPtr(root_framebuffer.ptr)),
        canvasPPS,
        canvasBPP,
        canvasPixelWidth, canvasCharWidth,
        canvasPixelHeight, canvasCharHeight
    });

    _ = create_window(canvasCharWidth, canvasCharHeight);

    ready = true;
}

pub inline fn get_system_font() Font {
    return system_font;
}


// user side
pub fn create_window(width: usize, height: usize) usize {
    st.push(@src()); defer st.pop();

    const free_window_index: usize = b: { 
        for (0 .. window_list.len) |i| {
            if (window_list[i] == null) break :b i;
        }
        @panic("No more video contexts avaiable!");
    };

    var nw = allocator.create(Win) catch unreachable;
    window_list[free_window_index] = nw;

    nw.width = width;
    nw.height = height;

    nw.mode = .text;

    nw.buffer_0.char = (allocator.alloc(Char, nw.width * nw.height) catch unreachable).ptr;
    nw.buffer_1.char = (allocator.alloc(Char, nw.width * nw.height) catch unreachable).ptr;

    return free_window_index;
}

pub fn draw_char(ctx: usize, c: u8, posX: usize, posY: usize) void {
    const window = window_list[ctx] orelse @panic("Invalid context descriptor");
    var fb = if (!window.swap) window.buffer_1.char else window.buffer_0.char;

    if (posX <= 0 or posX > window.width
    or posY <= 0 or posY > window.height) return;

    const rposx = posX * 16;
    const rposy = posY * 16;

    for (0 .. (system_font.width)) |x|
    for (0 .. (system_font.height)) |y| {

        fb[(rposx + x) + (rposy + y) * canvasBPP].value = c;
        fb[(rposx + x + 1) + (rposy + y) * canvasBPP].value = c;
        fb[(rposx + x) + (rposy + y + 1) * canvasBPP].value = c;
        fb[(rposx + x + 1) + (rposy + y + 1) * canvasBPP].value = c;

    };
}
// --------

// bruh inports
const std = @import("std");
const os = @import("root").os;
const bootInfo = @import("../boot/boot_info.zig");
const Allocator = std.mem.Allocator;

pub const text = @import("text/text.zig");

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
pub const Char = packed struct(u16) {
    color: packed union {
        byte: u8,
        col: packed struct(u8) {
            foreground: CharColor,
            background: CharColor
        },
    },
    value: u8,

    pub const CharColor = enum(u4) {
        white = 0,
        black = 1,
        red,
        green,
        blue,
    };
};
pub const Font = text.Font;

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
pub const Win = @import("win/win.zig").Win;

const write = os.console_write("Graphics Lib");
const st = os.stack_tracer;

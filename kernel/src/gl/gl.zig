pub var root_framebuffer: []Pixel = undefined;
pub var win_zindex: []u8 = undefined;

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
    win_zindex = allocator.alloc(u8, canvasCharWidth * canvasCharHeight) catch unreachable;
    @memset(win_zindex, 0);

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

    _ = create_window(.graph, canvasCharWidth, canvasCharHeight);

    ready = true;
}

pub inline fn get_system_font() Font {
    return system_font;
}


// user side
pub fn create_window(mode: VideoMode, width: usize, height: usize) usize {
    st.push(@src()); defer st.pop();

    const free_window_index: usize = b: { 
        for (0 .. window_list.len) |i| {
            if (window_list[i] == null) break :b i;
        }
        @panic("No more video contexts avaiable!");
    };

    var nw = allocator.create(Win) catch unreachable;
    window_list[free_window_index] = nw;

    const posx = @divFloor(canvasCharWidth, 2) - @divFloor(width, 2);
    const posy = @divFloor(canvasCharHeight, 2) - @divFloor(height, 2);

    nw.position_x = posx;
    nw.position_y = posy;

    nw.charWidth = width;
    nw.charHeight = height;

    nw.pixelWidth = width * system_font.width * system_font.scale;
    nw.pixelHeight = height * system_font.height * system_font.scale;

    nw.mode = mode;
    if (mode == .text) {
        nw.buffer_0.char = (allocator.alloc(Char, nw.charWidth * nw.charHeight) catch unreachable).ptr;
        nw.buffer_1.char = (allocator.alloc(Char, nw.charWidth * nw.charHeight) catch unreachable).ptr;
        @memset(nw.buffer_0.char[0..(nw.charWidth * nw.charHeight)], Char{
            .color = .{ .byte = 0b0000_0001 },
            .value = ' '});
        @memset(nw.buffer_1.char[0..(nw.charWidth * nw.charHeight)], Char{
            .color = .{ .byte = 0b0000_0001 },
            .value = ' '});
    } else {
        nw.buffer_0.pixel = (allocator.alloc(Pixel, nw.pixelWidth * nw.pixelHeight) catch unreachable).ptr;
        nw.buffer_1.pixel = (allocator.alloc(Pixel, nw.pixelWidth * nw.pixelHeight) catch unreachable).ptr;
        @memset(nw.buffer_0.pixel[0..(nw.pixelWidth * nw.pixelHeight)], .rgb(0, 0, 0));
        @memset(nw.buffer_1.pixel[0..(nw.pixelWidth * nw.pixelHeight)], .rgb(0, 0, 0));
    }

    focus_window(free_window_index);
    return free_window_index;
}

pub fn get_buffer_info(ctx: usize) struct {buf: Framebuffer, width: usize, height: usize} {
    const window = window_list[ctx] orelse @panic("Invalid context descriptor");
    const fb = if (!window.swap) window.buffer_0 else window.buffer_1;
    return .{
        .buf = fb,
        .width = if (window.mode == .text) window.charWidth else window.pixelWidth,
        .height = if (window.mode == .text) window.charHeight else window.pixelHeight
    };
}

pub fn swap_buffer(ctx: usize) void {
    if (window_list[ctx]) |win| win.swap = !win.swap;
}
// --------

pub fn focus_window(ctx: usize) void {
    if (window_list[ctx]) |win| {

        for (win.position_x .. win.charWidth) |x| {
            for (win.position_y .. win.charHeight) |y| {
                win_zindex[x + y * canvasCharWidth] = @intCast(ctx);
            }
        }

    }
}

var show_z = true;
pub fn redraw_screen_region(rx: usize, ry: usize, rw: usize, rh: usize) void {
    
    for (rx .. (rx + rw)) |x| {
        for (ry .. (ry + rh)) |y| {
            
            const win = window_list[win_zindex[x + y * canvasCharWidth]]
               orelse window_list[0].?;

            const fb = if (win.swap) win.buffer_0 else win.buffer_1;

            if (show_z) {
                root_draw_char('0' + win_zindex[x + y * canvasCharWidth], x, y);
                show_z = !show_z;
                continue;
            }
            
            if (win.mode == .text) {
                const char = fb.char[(x - win.position_x) + (y - win.position_y) * canvasCharWidth];
                root_draw_char(char.value, x, y);
            } else {
                const rot_xbase = x * system_font.width * system_font.scale;
                const rot_ybase = y * system_font.height * system_font.scale;
                const win_xbase = (x - win.position_x) * system_font.width * system_font.scale;
                const win_ybase = (y - win.position_y) * system_font.height * system_font.scale;

                for (0 .. win.pixelWidth) |subx| {
                    for (0 .. win.pixelHeight) |suby| {

                        root_framebuffer[(rot_xbase + subx) + (rot_ybase + suby) * canvasPPS] = 
                        fb.pixel[(win_xbase + subx) + (win_ybase + suby) * win.pixelWidth];

                    }
                }
            }

            show_z = !show_z;
        }
    }

}
fn root_draw_char(c: u8, posX: usize, posY: usize) void {

    const base_char = system_font.data[(c * system_font.height)..];

    const rpx = posX * system_font.width * 2;
    const rpy = posY * system_font.height * 2;

    for (0 .. system_font.height) |y| {
        const line = base_char[y];
        for (0 .. system_font.width) |x| {

            const has_col = (std.math.shr(u8, line, x) & 0x1) == 1;
            const col: Pixel = if (has_col) .rgb(255, 255, 255) else .rgb(0, 0, 0);

            const offx = x*2;
            const offy = y*2;

            root_framebuffer[(rpx + offx) + (rpy + offy) * canvasPPS] = col;
            root_framebuffer[(rpx + offx + 1) + (rpy + offy) * canvasPPS] = col;
            root_framebuffer[(rpx + offx) + (rpy + offy + 1) * canvasPPS] = col;
            root_framebuffer[(rpx + offx + 1) + (rpy + offy + 1) * canvasPPS] = col;
        }
    }

}

// _bruh_imports___________________________________________________________________
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

    pub fn char(c: u8) @This() {
        return .{
            .color = .{ .col = .{ .foreground = .white, .background = .black } },
            .value = c
        };
    }

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
pub const Framebuffer = Win.Framebuffer;

const write = os.console_write("Graphics Lib");
const st = os.stack_tracer;

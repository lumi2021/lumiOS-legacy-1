pub var root_framebuffer: []Pixel = undefined;
pub var win_zindex: []u8 = undefined;

pub var canvasBPP: u8 = 0;
pub var canvasPPS: usize = 0;

pub var canvasPixelWidth: usize = 0;
pub var canvasPixelHeight: usize = 0;

pub var canvasCharWidth: usize = 0;
pub var canvasCharHeight: usize = 0;

var system_font: Font = undefined;
var system_font_width: usize = undefined;
var system_font_height: usize = undefined;

pub var ready = false;

pub const assets = @import("assets/assets.zig");

var arena: std.heap.ArenaAllocator = undefined;
var allocator: Allocator = undefined;

pub var window_list: []?*Win = undefined;
var cursor: struct { pos_x: isize, pos_y: isize } = undefined;
var cursor_texture: []const u8 = undefined;

pub fn init(fb: bootInfo.FrameBuffer) void {
    st.push(@src()); defer st.pop();

    system_font = assets.fonts[7];
    system_font.scale = 1;
    system_font_width = (system_font.width + 1) * system_font.scale + 1;
    system_font_height = (system_font.height + 1) * system_font.scale;

    const fb_ptr: [*]Pixel = @ptrCast(@alignCast(fb.framebuffer));
    root_framebuffer = fb_ptr[0..(fb.size / 4)];

    canvasPPS = fb.size / 4 / fb.height;
    canvasBPP = @intCast((fb.size * 8) / (fb.width * fb.height));

    canvasPixelWidth = fb.width;
    canvasPixelHeight = fb.height;
    canvasCharWidth = @divTrunc(fb.width, system_font_width);
    canvasCharHeight = @divTrunc(fb.height, system_font_height);

    cursor.pos_x = 0;
    cursor.pos_y = 0;
    cursor_texture = assets.cursors[0][16..];

    // setting up arena allocator
    arena = std.heap.ArenaAllocator.init(os.memory.allocator);
    allocator = arena.allocator();

    window_list = allocator.alloc(?*Win, 256) catch unreachable;
    @memset(window_list, null);
    win_zindex = allocator.alloc(u8, canvasCharWidth * canvasCharHeight) catch unreachable;
    @memset(win_zindex, 0);

    write.log(
        \\
        \\fb size: {}
        \\fb pos: ${X:0>16}
        \\pps: {}
        \\bpp: {}
        \\canvas width: {} pixels, {} chars
        \\canvas height: {} pixels, {} chars
    , .{ root_framebuffer.len, os.memory.paddr_from_vaddr(@intFromPtr(root_framebuffer.ptr)), canvasPPS, canvasBPP, canvasPixelWidth, canvasCharWidth, canvasPixelHeight, canvasCharHeight });

    ready = true;
}

pub inline fn get_system_font() Font {
    return system_font;
}

// user side
pub fn create_window(mode: VideoMode, width: usize, height: usize, hasborder: bool) usize {
    st.push(@src()); defer st.pop();

    const free_window_index: usize = b: {
        for (0..window_list.len) |i| {
            if (window_list[i] == null) break :b i;
        }
        @panic("No more video contexts avaiable!");
    };

    var nw = allocator.create(Win) catch unreachable;
    window_list[free_window_index] = nw;

    const posx = @divFloor(canvasCharWidth, 2) - @divFloor(width, 2);
    const posy = @divFloor(canvasCharHeight, 2) - @divFloor(height, 2);

    nw.position_x = @intCast(posx);
    nw.position_y = @intCast(posy);

    nw.charWidth = width;
    nw.charHeight = height;

    nw.pixelWidth = width * system_font_width;
    nw.pixelHeight = height * system_font_height;

    nw.hasBorder = hasborder;

    nw.mode = mode;
    if (mode == .text) {
        const buf = allocator.alloc(Char, nw.charWidth * nw.charHeight * 2) catch unreachable;
        nw.buffer_0.char = (buf[0..]).ptr;
        nw.buffer_1.char = (buf[nw.charWidth * nw.charHeight..]).ptr;
        @memset(buf, Char{ .color = .{ .byte = 0b0000_0001 }, .value = ' ' });
    } else {
        const buf = allocator.alloc(Pixel, nw.pixelWidth * nw.pixelHeight * 2) catch unreachable;
        nw.buffer_0.pixel = (buf[0..]).ptr;
        nw.buffer_1.pixel = (buf[nw.pixelWidth * nw.pixelHeight ..]).ptr;
        @memset(buf, .rgb(0, 0, 0));
    }

    return free_window_index;
}

pub fn get_buffer_info(ctx: usize) struct { buf: Framebuffer, width: usize, height: usize } {
    const window = window_list[ctx] orelse @panic("Invalid context descriptor");
    const fb = if (!window.swap) window.buffer_0 else window.buffer_1;
    return .{ .buf = fb, .width = if (window.mode == .text) window.charWidth else window.pixelWidth, .height = if (window.mode == .text) window.charHeight else window.pixelHeight };
}

pub fn swap_buffer(ctx: usize) void {
    if (window_list[ctx]) |win| {
        win.swap = !win.swap;
        redraw_screen_region(
            win.position_x - 1,
            win.position_y - 1,
            win.position_x + @as(isize, @bitCast(win.charWidth)) + 1,
            win.position_y + @as(isize, @bitCast(win.charHeight)) + 1
        );
    }
}
// --------

pub fn focus_window(ctx: usize) void {
    st.push(@src()); defer st.pop();

    if (window_list[ctx]) |win| {
        const withBorders = win.hasBorder;

        var start_x = win.position_x + @as(isize, if (withBorders) -1 else 0);
        var end_x = win.position_x + @as(isize, @intCast(win.charWidth)) + @as(isize, (if (withBorders) 1 else 0));
        var start_y = win.position_y + @as(isize, if (withBorders) -1 else 0);
        var end_y = win.position_y + @as(isize, @intCast(win.charHeight)) + @as(isize, if (withBorders) 1 else 0);

        start_x = @max(0, start_x);
        start_y = @max(0, start_y);
        end_x = @min(@as(isize, @bitCast(canvasCharWidth)), end_x);
        end_y = @min(@as(isize, @bitCast(canvasCharHeight)), end_y);

        for (@bitCast(start_x) .. @bitCast(end_x)) |x| {
            for (@bitCast(start_y) .. @bitCast(end_y)) |y| {

                win_zindex[x + y * canvasCharWidth] = @intCast(ctx);

            }
        }
    }
}

var show_z = false;
pub fn redraw_screen_region(rx: isize, ry: isize, rw: isize, rh: isize) void {
    st.push(@src()); defer st.pop();

    const rrx = @max(rx, 0);
    const rry = @max(ry, 0);
    const rex = @min(rx + rw, @as(isize, @bitCast(canvasCharWidth)));
    const reh = @min(ry + rh, @as(isize, @bitCast(canvasCharHeight)));

    for (@intCast(rrx) .. @intCast(rex)) |x| {
        for (@intCast(rry) .. @intCast(reh)) |y| {

            const win = window_list[win_zindex[x + y * canvasCharWidth]] orelse window_list[0].?;

            if (win.hasBorder and (
                x < win.position_x or x >= (win.position_x + @as(isize, @bitCast(win.charWidth))) or
                y < win.position_y or y >= (win.position_y + @as(isize, @bitCast(win.charHeight)))
            )) {
                const right = win.position_x + @as(isize, @bitCast(win.charWidth));
                const bottom = win.position_y + @as(isize, @bitCast(win.charHeight));

                if (x < win.position_x) root_draw_char(if (y < win.position_y) 201 else if (y >= bottom) 200 else 186, x, y)
                else if (x >= right) root_draw_char(if (y < win.position_y) 187 else if (y >= bottom) 188 else 186, x, y)
                else root_draw_char(205, x, y);
            } else {

                if (show_z) {
                    root_draw_char('0' + win_zindex[x + y * canvasCharWidth], x, y);
                    continue;
                }

                const fb = if (win.swap) win.buffer_0 else win.buffer_1;

                if (win.mode == .text) {

                    const curx = x - @as(usize, @bitCast(win.position_x));
                    const cury = y - @as(usize, @bitCast(win.position_y));
                    const char = fb.char[curx + cury * win.charWidth].value;
                    root_draw_char(char, x, y);

                } else {

                    const realx: usize = x * system_font_width;
                    const realy: usize = y * system_font_height;
                    const realWinPosx = @as(usize, @bitCast(win.position_x)) * system_font_width;
                    const realWinPosy = @as(usize, @bitCast(win.position_y)) * system_font_height;

                    for (0 .. system_font_height) |y2| {
                        for (0 .. system_font_width) |x2| {

                            const pval = fb.pixel[(realx - realWinPosx + x2) + (realy - realWinPosy + y2) * win.pixelWidth];
                            root_framebuffer[(realx + x2) + (realy + y2) * canvasPPS] = pval;

                        }
                    }

                }
            }
        }
    }

    redraw_cursor();
}
pub fn move_cursor(posx: isize, posy: isize) void {
    st.push(@src()); defer st.pop();

    const px = @divFloor(cursor.pos_x, @as(isize, @bitCast(system_font_width)));
    const py = @divFloor(cursor.pos_y, @as(isize, @bitCast(system_font_height)));

    cursor.pos_x = posx;
    cursor.pos_y = posy;

    redraw_screen_region(px - 3, py - 3, 6, 6);
}
pub fn redraw_cursor() void {
    st.push(@src()); defer st.pop();

    for (0 .. 32) |x| {
        for (0 .. 32) |y| {

            const rcpx = cursor.pos_x + @as(isize, @bitCast(x)) - 16;
            const rcpy = cursor.pos_y + @as(isize, @bitCast(y)) - 16;
            const tbase = (x + y * 128) * 4;

            if (rcpx < 0 or rcpx >= canvasPixelWidth or rcpy < 0 or rcpy >= canvasPixelHeight) continue;

            if (cursor_texture[tbase + 3] > 128) {
                root_framebuffer[@as(usize, @intCast(rcpx)) + @as(usize, @intCast(rcpy)) * canvasPPS] = .rgb(
                    cursor_texture[tbase + 2],
                    cursor_texture[tbase + 1],
                    cursor_texture[tbase + 0]
                );
            }

        }
    }
}
fn root_draw_char(c: u8, posX: usize, posY: usize) void {
    st.push(@src()); defer st.pop();

    const base_char = system_font.data[(c * system_font.height)..];

    const rpx = posX * system_font_width;
    const rpy = posY * system_font_height;

    for (0 .. system_font.height) |y| {
        const line = base_char[y];
        for (0 .. (system_font.width + 1)) |x| {

            for (0 .. system_font.scale) |x2| {
                for (0 .. system_font.scale) |y2| {

                    const has_col = (std.math.shr(u8, line, 8 - x) & 0x1) == 1;
                    const col: Pixel = if (has_col) .rgb(255, 255, 255) else .rgb(0, 0, 0);

                    const offx = x * system_font.scale + x2;
                    const offy = y * system_font.scale + y2;

                    root_framebuffer[(rpx + offx) + (rpy + offy) * canvasPPS] = col;
                    root_framebuffer[(rpx + offx + 1) + (rpy + offy) * canvasPPS] = col;
                    root_framebuffer[(rpx + offx) + (rpy + offy + 1) * canvasPPS] = col;
                    root_framebuffer[(rpx + offx + 1) + (rpy + offy + 1) * canvasPPS] = col;

                }
            }

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
        return .{ .red = @intCast(r & 0xFF), .green = @intCast(g & 0xFF), .blue = @intCast(b & 0xFF), .alpha = 0 };
    }
};
pub const Char = packed struct(u16) {
    color: packed union {
        byte: u8,
        col: packed struct(u8) { foreground: CharColor, background: CharColor },
    },
    value: u8,

    pub fn char(c: u8) @This() {
        return .{ .color = .{ .col = .{ .foreground = .white, .background = .black } }, .value = c };
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
        } else if (mode == .graph) {
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

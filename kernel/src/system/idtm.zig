const os = @import("root").os;

const gdt_ops = os.system.global_descriptor_table;
const idt_ops = os.system.interrupt_descriptor_table;
const IDTEntry = idt_ops.IDTEntry;
const IDTR = idt_ops.IDTPtr;
const InterruptFrame = os.theading.TaskContext;

const writer = os.console_write("IDTM");
const st = os.stack_tracer;

const IntHandler = *const fn (*InterruptFrame) void;
pub var interrupts: [256]IntHandler = [_]IntHandler{unhandled_interrupt} ** 256;

pub const syscall_vector: u8 = 0x80;
pub const invlpg_vector: u8 = 0xFE;
pub const spurious_vector: u8 = 0xFF;

pub fn init() void {
    init_interrupt_table(&idt_ops.entries);
}

fn init_interrupt_table(idt: *[256]IDTEntry) void {
    inline for (0..256) |i| {
        idt_ops.set_entry(idt, @intCast(i), make_handler(comptime @intCast(i)), 0x08, 0x8E);
    }
}

fn unhandled_interrupt(frame: *InterruptFrame) void {
    st.push(@src());
    defer st.pop();

    writer.err("Unhandled interrupt {0} (0x{0X:0>2})!\r\n {1}", .{ frame.intnum, frame });
}

export fn interrupt_common() callconv(.Naked) void {
    asm volatile (
        \\ push %%rax
        \\ push %%rbx
        \\ push %%rcx
        \\ push %%rdx
        \\ push %%rbp
        \\ push %%rsi
        \\ push %%rdi
        \\ push %%r8
        \\ push %%r9
        \\ push %%r10
        \\ push %%r11
        \\ push %%r12
        \\ push %%r13
        \\ push %%r14
        \\ push %%r15
        \\ mov %%ds, %%rax
        \\ push %%rax
        \\ mov %%es, %%rax
        \\ push %%rax
        \\ mov %%rsp, %%rdi
        \\ mov %[dsel], %%ax
        \\ mov %%ax, %%es
        \\ mov %%ax, %%ds
        \\ call interrupt_handler
        \\ pop %%rax
        \\ mov %%rax, %%es
        \\ pop %%rax
        \\ mov %%rax, %%ds
        \\ pop %%r15
        \\ pop %%r14
        \\ pop %%r13
        \\ pop %%r12
        \\ pop %%r11
        \\ pop %%r10
        \\ pop %%r9
        \\ pop %%r8
        \\ pop %%rdi
        \\ pop %%rsi
        \\ pop %%rbp
        \\ pop %%rdx
        \\ pop %%rcx
        \\ pop %%rbx
        \\ pop %%rax
        \\ add $16, %%rsp
        \\ iretq
        :
        : [dsel] "i" (gdt_ops.selector.data64),
    );
}

export fn interrupt_handler(fptr: u64) void {
    const int_frame: *InterruptFrame = @ptrFromInt(fptr);
    int_frame.intnum &= 0xFF;

    writer.dbg("Branching to interrupt {X:0>2}...", .{int_frame.intnum});

    writer.dbg("frame before:\n{}", .{int_frame});

    st.push_interrupt(int_frame.intnum);
    interrupts[int_frame.intnum](int_frame);
    st.pop();

    writer.dbg("frame after:\n{}", .{int_frame});

    os.port_io.outb(0x20, 0x20);
}

pub fn make_handler(comptime intnum: u8) fn () callconv(.Naked) void {
    return struct {
        fn func() callconv(.Naked) void {
            const ec = if (comptime (!has_error_code(intnum))) "push $0\n" else "";
            asm volatile (ec ++
                    "push %[intnum]\njmp interrupt_common"
                :
                : [intnum] "i" (intnum),
            );
        }
    }.func;
}

fn has_error_code(intnum: u8) bool {
    return switch (intnum) {
        // Exceptions
        0x00...0x07 => false,
        0x08 => true,
        0x09 => false,
        0x0A...0x0E => true,
        0x0F...0x10 => false,
        0x11 => true,
        0x12...0x14 => false,
        //0x15 ... 0x1D => unreachable,
        0x1E => true,
        //0x1F          => unreachable,

        // Other interrupts
        else => false,
    };
}

pub fn allocate_vector() u8 {
    for (0x30..0xF0) |i| {
        if (interrupts[i] == unhandled_interrupt) return @intCast(i);
    }
    @panic("No interrupt availeable!");
}

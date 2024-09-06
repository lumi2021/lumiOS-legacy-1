const gdt_ops = @import("./structures/GDT.zig");
const idt_ops = @import("./structures/IDT.zig");
const IDTEntry = idt_ops.IDTEntry;
const IDTR = idt_ops.IDTPtr;

const TaskManager = @import("task_manager.zig");

const port_io = @import("IO/port_io.zig");
const uart = @import("./IO/uart.zig");
const puts = uart.uart_puts;
const printf = uart.uart_printf;

pub fn init_interrupt_table(idt: *[256]IDTEntry) void {
    
    inline for (0..256) |i| {
        idt_ops.set_entry(idt, @intCast(i), make_handler(comptime @intCast(i)), 0x08, 0x8E);
    }

    interrupts[0] = handle_divide_by_zero;
    interrupts[6] = handle_invalid_opcode;
    interrupts[32] = handle_timer_interrupt;

}

pub fn unhandled_interrupt(f: *InterruptFrame) void {

    printf("Unhandled interrupt {0} (0x{0X:0>2})!\n", .{f.intnum});
    f.log();
}

pub fn handle_divide_by_zero(_: *InterruptFrame) void {

    puts("Division by zero!\n");

}

pub fn handle_invalid_opcode(_: *InterruptFrame) void {

    puts("Invalid OpCode! halting!\r\n");
    asm volatile ("hlt");
    
}

fn handle_timer_interrupt(_: *InterruptFrame) void {
    puts("Timeout!\n");
    TaskManager.schedule();
}

// Interrupt system stuff
const InterruptFrame = extern struct {
    es: u64,
    ds: u64,
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rdi: u64,
    rsi: u64,
    rbp: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,
    intnum: u64,
    ec: u64,
    rip: u64,
    cs: u64,
    eflags: u64,
    rsp: u64,
    ss: u64,

    fn log(self: *@This()) void {
        printf("  rax={X:0>16} rbx={X:0>16} rcx={X:0>16} rdx={X:0>16}\n", .{ self.rax, self.rbx, self.rcx, self.rdx });
        printf("  rsi={X:0>16} rdi={X:0>16} rbp={X:0>16} rsp={X:0>16}\n", .{ self.rsi, self.rdi, self.rbp, self.rsp });
        printf("  r8 ={X:0>16} r9 ={X:0>16} r10={X:0>16} r11={X:0>16}\n", .{ self.r8, self.r9, self.r10, self.r11 });
        printf("  r12={X:0>16} r13={X:0>16} r14={X:0>16} r15={X:0>16}\n", .{ self.r12, self.r13, self.r14, self.r15 });
        printf("  rip={X:0>16} int={X:0>16} ec ={X:0>16} cs ={X:0>16}\n", .{ self.rip, self.intnum, self.ec, self.cs });
        printf("  ds ={X:0>16} es ={X:0>16} flg={X:0>16}\n", .{ self.ds, self.es, self.eflags });
    }
};
const IntHandler = *const fn (*InterruptFrame) void;
var interrupts: [256]IntHandler = [_]IntHandler{unhandled_interrupt} ** 256;

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
        : [dsel] "i" (gdt_ops.selector.data64)
    );
}

export fn interrupt_handler(fptr: u64) void {
    const int_frame: *InterruptFrame = @ptrFromInt(fptr);
    int_frame.intnum &= 0xFF;
    interrupts[int_frame.intnum](int_frame);
    port_io.outb(0x20, 0x20);
}

pub fn make_handler(comptime intnum: u8) fn() callconv(.Naked) void {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\ push $0
                \\ push %[intnum]
                \\ jmp interrupt_common
                :
                : [intnum] "i" (intnum)
            );
        }
    }.func;
}

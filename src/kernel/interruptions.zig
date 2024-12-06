const os = @import("root").os;
const st = os.stack_tracer;

const interrupts = &os.system.interrupt_manager.interrupts;
const write = os.console_write("Interrupt");

const InterruptFrame = os.theading.TaskContext;

pub fn init() void {
    st.push(@src());

    interrupts[0] = handle_divide_by_zero;

    interrupts[6] = handle_invalid_opcode;

    interrupts[8] = handle_double_fault;

    interrupts[13] = handle_general_protection;
    interrupts[14] = handle_page_fault;

    interrupts[32] = handle_timer_interrupt;

    st.pop();
}

pub fn handle_divide_by_zero(_: *InterruptFrame) void {
    st.push(@src());

    write.err("Division by zero!\n", .{});
    @panic("Division by zero");
}

pub fn handle_invalid_opcode(_: *InterruptFrame) void {
    st.push(@src());

    write.err("Invalid OpCode!", .{});
    @panic("Invalid OpCode");
}

pub fn handle_general_protection(frame: *InterruptFrame) void {
    st.push(@src());

    write.err("General Protection!", .{});
    write.log("\r\n{}", .{frame});
    @panic("General Protection fault");
}

pub fn handle_page_fault(frame: *InterruptFrame) void {
    st.push(@src());

    var addr: u64 = undefined;
    asm volatile ("mov %CR2, %[add]"
        : [add] "=r" (addr),
    );

    write.err("Page Fault trying to acess ${X:0>16}!", .{addr});
    write.log("\r\n{}", .{frame});
    @panic("Page fault");
}

pub fn handle_double_fault(frame: *InterruptFrame) void {
    st.push(@src());

    var addr: u64 = undefined;
    asm volatile ("mov %CR2, %[add]"
        : [add] "=r" (addr),
    );

    write.err("Double fault! ${X:0>16}!", .{addr});
    write.log("\r\n{}", .{frame});
    @panic("Double fault");
}

fn handle_timer_interrupt(frame: *InterruptFrame) void {
    st.push(@src());
    os.theading.schedue.do_schedue(frame);
    st.pop();
}

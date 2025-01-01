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

    try_kill_process();
}

pub fn handle_invalid_opcode(_: *InterruptFrame) void {
    st.push(@src());

    write.err("Invalid OpCode!", .{});

    try_kill_process();
}

pub fn handle_general_protection(frame: *InterruptFrame) void {
    st.push(@src());

    //const external: u1 = (frame.error_code << 0) & 0b1;
    const tbl = (frame.error_code << 1) & 0b11;
    const index = (frame.error_code << 3) & 0b1111_1111_1111_1;

    const table = switch (tbl) {
        0b00 => "GDT",
        0b01 => "IDT",
        0b10 => "LDT",
        0b11 => "IDT",
        else => "[undefined]",
    };

    write.err("General Protection!", .{});

    if (frame.error_code != 0) {
        write.err("Trying to index {X} in the {s} table!", .{ index, table });
    } else write.log("error code: 0", .{});

    write.log("\n{}", .{frame});

    if (frame.rip > 0xF000000000000000) {
        const opCode1 = @as(*u8, @ptrFromInt(frame.rip)).*;
        const opCode2 = @as(*u8, @ptrFromInt(frame.rip + 1)).*;
        const opCode3 = @as(*u8, @ptrFromInt(frame.rip + 2)).*;
        const opCode4 = @as(*u8, @ptrFromInt(frame.rip + 3)).*;
        write.err("Op Code: {X:0>2} {X:0>2} {X:0>2} {X:0>2}", .{ opCode1, opCode2, opCode3, opCode4 });

        //if (opCode1 == 0x48 and opCode2 == 0xCF) {
        //    const rsp: [*]u64 = @ptrFromInt(frame.rip);
        //    write.err("Stack: {X:0>16} {X:0>16} {X:0>16} {X:0>16} {X:0>16}", .{ rsp[0], rsp[1], rsp[2], rsp[3], rsp[4] });
        //}
    }

    try_kill_process();
}

pub fn handle_page_fault(frame: *InterruptFrame) void {
    st.push(@src());

    var addr: u64 = undefined;
    asm volatile ("mov %CR2, %[add]"
        : [add] "=r" (addr),
    );

    write.err("Page Fault trying to acess ${X:0>16}!", .{addr});
    write.log("\r\n{}", .{frame});

    try_kill_process();
}

fn handle_double_fault(frame: *InterruptFrame) void {
    st.push(@src());

    var addr: u64 = undefined;
    asm volatile ("mov %CR2, %[add]"
        : [add] "=r" (addr),
    );

    write.err("Double fault! ${X:0>16}!", .{addr});
    write.log("\r\n{}", .{frame});

    try_kill_process();
}

fn handle_timer_interrupt(frame: *InterruptFrame) void {
    st.push(@src());
    os.theading.schedue.do_schedue(frame);
    st.pop();
}

fn try_kill_process() void {
    os.theading.schedue.kill_current_process();
}

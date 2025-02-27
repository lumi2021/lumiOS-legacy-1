const root = @import("root");
const raw_system_call = root.raw_system_call;

pub fn terminate_process(status: isize) noreturn {
    // This one needs to be manually called as it cannot return
    asm volatile (
        \\ mov $0, %rax
        \\ int $0x80
        :
        : [rdi] "{rdi}" (status),
    );
    while (true) {}
}

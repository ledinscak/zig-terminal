//! zig-terminal: A simple terminal I/O library for Zig
//!
//! Provides buffered terminal output with ANSI escape sequence support.

pub const Terminal = @import("terminal.zig").Terminal;

test {
    @import("std").testing.refAllDecls(@This());
}

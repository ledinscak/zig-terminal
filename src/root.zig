//! zig-terminal: A simple terminal I/O library for Zig
//!
//! Provides buffered terminal output with ANSI escape sequence support,
//! text styling, and keyboard input handling.

const terminal = @import("terminal.zig");

pub const Terminal = terminal.Terminal;
pub const Key = terminal.Terminal.Key;
pub const Size = terminal.Terminal.Size;
pub const Position = terminal.Terminal.Position;
pub const Color = terminal.Terminal.Color;
pub const MouseButton = terminal.Terminal.MouseButton;
pub const MouseEvent = terminal.Terminal.MouseEvent;

test {
    @import("std").testing.refAllDecls(@This());
}

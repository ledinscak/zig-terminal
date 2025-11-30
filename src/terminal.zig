//! Terminal abstraction for cursor control, screen clearing, and size detection.
//!
//! Provides a buffered writer interface for terminal I/O operations
//! with ANSI escape sequence support.

const std = @import("std");

pub const Terminal = struct {
    const Self = @This();

    const stdout = std.fs.File.stdout();
    const stdin = std.fs.File.stdin();

    writer_impl: Writer,
    original_termios: ?std.posix.termios = null,

    pub const Writer = std.fs.File.Writer;
    pub const WriteError = std.Io.Writer.Error;
    pub const RawModeError = std.posix.TermiosGetError || std.posix.TermiosSetError;

    pub const Size = struct {
        width: u16,
        height: u16,

        pub fn center(self: Size, content_width: u16) Position {
            return .{
                .row = self.height / 2,
                .col = (self.width -| content_width) / 2,
            };
        }
    };

    pub const Position = struct {
        row: u16,
        col: u16,
    };

    pub const InitError = error{
        TerminalSizeUnavailable,
    };

    /// Buffer must outlive the Terminal instance.
    pub fn init(buffer: []u8) Self {
        return .{
            .writer_impl = stdout.writer(buffer),
        };
    }

    pub fn open(self: *Self) !void {
        try self.enableRawMode();
        try self.enableAltScreen();
        try self.hideCursor();
    }

    pub fn close(self: *Self) void {
        self.disableRawMode() catch {};
        self.disableAltScreen() catch {};
        self.showCursor() catch {};
    }

    /// Get the writer interface for output operations (internal use).
    fn writer(self: *Self) *std.Io.Writer {
        return &self.writer_impl.interface;
    }

    pub fn getSize(_: *Self) InitError!Size {
        var winsize: std.posix.winsize = undefined;
        const result = std.posix.system.ioctl(
            stdout.handle,
            std.posix.T.IOCGWINSZ,
            @intFromPtr(&winsize),
        );

        if (result != 0) {
            return error.TerminalSizeUnavailable;
        }

        return .{
            .width = winsize.col,
            .height = winsize.row,
        };
    }

    // -------------------------------------------------------------------------
    // Private Helpers
    // -------------------------------------------------------------------------

    /// Write ANSI escape sequence (CSI). Comptime string concatenation for zero overhead.
    inline fn ansi(self: *Self, comptime code: []const u8) WriteError!void {
        try self.writer().writeAll("\x1b[" ++ code);
    }

    pub fn hideCursor(self: *Self) WriteError!void {
        try self.ansi("?25l");
        try self.flush();
    }

    pub fn showCursor(self: *Self) WriteError!void {
        try self.ansi("?25h");
        try self.flush();
    }

    pub fn moveTo(self: *Self, row: u16, col: u16) WriteError!void {
        try self.writer().print("\x1b[{};{}H", .{ row + 1, col + 1 });
    }

    pub fn moveToOrigin(self: *Self) WriteError!void {
        try self.ansi("H");
    }

    // -------------------------------------------------------------------------
    // Screen Control
    // -------------------------------------------------------------------------

    pub fn clear(self: *Self) WriteError!void {
        try self.ansi("2J");
    }

    pub fn enableAltScreen(self: *Self) WriteError!void {
        try self.ansi("?1049h");
        try self.flush();
    }

    pub fn disableAltScreen(self: *Self) WriteError!void {
        try self.ansi("?1049l");
        try self.flush();
    }

    /// Enable raw mode: disable input buffering, echo, and signal handling.
    /// Call disableRawMode() to restore original settings.
    pub fn enableRawMode(self: *Self) RawModeError!void {
        // Save original settings
        self.original_termios = try std.posix.tcgetattr(stdout.handle);

        var raw = self.original_termios.?;

        // Input: disable break, CR to NL, parity check, strip, flow control
        raw.iflag.BRKINT = false;
        raw.iflag.ICRNL = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.iflag.IXON = false;

        // Output: disable post-processing
        raw.oflag.OPOST = false;

        // Control: set 8-bit chars
        raw.cflag.CSIZE = .CS8;

        // Local: disable echo, canonical mode, signals, extended input
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.IEXTEN = false;
        raw.lflag.ISIG = false;

        // Read returns after 1 byte, no timeout
        raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
        raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;

        try std.posix.tcsetattr(stdout.handle, .FLUSH, raw);
    }

    /// Restore original terminal settings.
    pub fn disableRawMode(self: *Self) RawModeError!void {
        if (self.original_termios) |termios| {
            try std.posix.tcsetattr(stdout.handle, .FLUSH, termios);
            self.original_termios = null;
        }
    }

    pub fn setFg(self: *Self, r: u8, g: u8, b: u8) WriteError!void {
        try self.writer().print("\x1b[38;2;{};{};{}m", .{ r, g, b });
    }

    pub fn setBg(self: *Self, r: u8, g: u8, b: u8) WriteError!void {
        try self.writer().print("\x1b[48;2;{};{};{}m", .{ r, g, b });
    }

    pub fn resetColors(self: *Self) WriteError!void {
        try self.ansi("0m");
    }

    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) WriteError!void {
        try self.writer().print(fmt, args);
    }

    pub fn write(self: *Self, bytes: []const u8) WriteError!void {
        try self.writer().writeAll(bytes);
    }

    fn flush(self: *Self) WriteError!void {
        try self.writer().flush();
    }

    /// Flush buffer to terminal. Call once per frame after all drawing.
    pub fn render(self: *Self) WriteError!void {
        try self.flush();
    }

    // -------------------------------------------------------------------------
    // Input
    // -------------------------------------------------------------------------

    /// Non-blocking key poll. Returns quit key (q/Esc) or null.
    /// Drains input buffer and distinguishes Esc from escape sequences.
    pub fn pollKey(_: *Self) ?u8 {
        var fds = [_]std.posix.pollfd{.{
            .fd = stdin.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};

        var last_key: ?u8 = null;

        // Drain all pending input
        while (true) {
            const ready = std.posix.poll(&fds, 0) catch return last_key;
            if (ready > 0 and (fds[0].revents & std.posix.POLL.IN) != 0) {
                var buf: [1]u8 = undefined;
                const n = stdin.read(&buf) catch return last_key;
                if (n > 0) {
                    if (buf[0] == 'q') {
                        last_key = buf[0];
                    } else if (buf[0] == 27) {
                        // Check if standalone Esc or escape sequence
                        const more = std.posix.poll(&fds, 10) catch 0; // 10ms timeout
                        if (more == 0) {
                            // No more bytes - real Esc press
                            last_key = 27;
                        }
                        // Otherwise escape sequence - drain and ignore
                    }
                } else break;
            } else break;
        }

        return last_key;
    }
};

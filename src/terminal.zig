//! Terminal abstraction for cursor control, screen clearing, and size detection.
//!
//! Provides a buffered writer interface for terminal I/O operations
//! with ANSI escape sequence support.

const std = @import("std");

pub const Terminal = struct {
    const Self = @This();

    file: std.fs.File,
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

    /// Initialize terminal with a file handle and buffer.
    /// Buffer must outlive the Terminal instance.
    pub fn init(file: std.fs.File, buffer: []u8) Self {
        return .{
            .file = file,
            .writer_impl = file.writer(buffer),
        };
    }

    /// Initialize terminal for stdout with provided buffer.
    pub fn stdout(buffer: []u8) Self {
        return init(std.fs.File.stdout(), buffer);
    }

    /// Get the writer interface for output operations.
    pub fn writer(self: *Self) *std.Io.Writer {
        return &self.writer_impl.interface;
    }

    /// Get terminal dimensions via ioctl.
    pub fn getSize(self: *const Self) InitError!Size {
        var winsize: std.posix.winsize = undefined;
        const result = std.posix.system.ioctl(
            self.file.handle,
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

    // -------------------------------------------------------------------------
    // Cursor Control
    // -------------------------------------------------------------------------

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

    pub fn clearLine(self: *Self) WriteError!void {
        try self.ansi("2K");
    }

    /// Enable alternate screen buffer. Content is restored when disabled.
    pub fn enableAltScreen(self: *Self) WriteError!void {
        try self.ansi("?1049h");
        try self.flush();
    }

    /// Disable alternate screen buffer and restore original content.
    pub fn disableAltScreen(self: *Self) WriteError!void {
        try self.ansi("?1049l");
        try self.flush();
    }

    // -------------------------------------------------------------------------
    // Raw Mode
    // -------------------------------------------------------------------------

    /// Enable raw mode: disable input buffering, echo, and signal handling.
    /// Call disableRawMode() to restore original settings.
    pub fn enableRawMode(self: *Self) RawModeError!void {
        const fd = self.file.handle;

        // Save original settings
        self.original_termios = try std.posix.tcgetattr(fd);

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

        try std.posix.tcsetattr(fd, .FLUSH, raw);
    }

    /// Restore original terminal settings.
    pub fn disableRawMode(self: *Self) RawModeError!void {
        if (self.original_termios) |termios| {
            try std.posix.tcsetattr(self.file.handle, .FLUSH, termios);
            self.original_termios = null;
        }
    }

    // -------------------------------------------------------------------------
    // Colors (True Color / 24-bit RGB)
    // -------------------------------------------------------------------------

    pub fn setFg(self: *Self, r: u8, g: u8, b: u8) WriteError!void {
        try self.writer().print("\x1b[38;2;{};{};{}m", .{ r, g, b });
    }

    pub fn setBg(self: *Self, r: u8, g: u8, b: u8) WriteError!void {
        try self.writer().print("\x1b[48;2;{};{};{}m", .{ r, g, b });
    }

    pub fn resetColors(self: *Self) WriteError!void {
        try self.ansi("0m");
    }

    // -------------------------------------------------------------------------
    // Output
    // -------------------------------------------------------------------------

    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) WriteError!void {
        try self.writer().print(fmt, args);
    }

    pub fn write(self: *Self, bytes: []const u8) WriteError!void {
        try self.writer().writeAll(bytes);
    }

    pub fn flush(self: *Self) WriteError!void {
        try self.writer().flush();
    }
};

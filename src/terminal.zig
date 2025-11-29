//! Terminal abstraction for cursor control, screen clearing, and size detection.
//!
//! Provides a buffered writer interface for terminal I/O operations
//! with ANSI escape sequence support.

const std = @import("std");

pub const Terminal = struct {
    const Self = @This();

    file: std.fs.File,
    writer_impl: Writer,

    pub const Writer = std.fs.File.Writer;
    pub const WriteError = std.Io.Writer.Error;

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
    // Cursor Control
    // -------------------------------------------------------------------------

    pub fn hideCursor(self: *Self) WriteError!void {
        try self.writer().writeAll("\x1b[?25l");
        try self.flush();
    }

    pub fn showCursor(self: *Self) WriteError!void {
        try self.writer().writeAll("\x1b[?25h");
        try self.flush();
    }

    pub fn moveTo(self: *Self, row: u16, col: u16) WriteError!void {
        try self.writer().print("\x1b[{};{}H", .{ row + 1, col + 1 });
    }

    pub fn moveToOrigin(self: *Self) WriteError!void {
        try self.writer().writeAll("\x1b[H");
    }

    // -------------------------------------------------------------------------
    // Screen Control
    // -------------------------------------------------------------------------

    pub fn clear(self: *Self) WriteError!void {
        try self.writer().writeAll("\x1b[2J");
    }

    pub fn clearLine(self: *Self) WriteError!void {
        try self.writer().writeAll("\x1b[2K");
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

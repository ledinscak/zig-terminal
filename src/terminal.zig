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
    mouse_enabled: bool = false,

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

    /// Standard 16 ANSI colors
    pub const Color = enum(u8) {
        black = 0,
        red = 1,
        green = 2,
        yellow = 3,
        blue = 4,
        magenta = 5,
        cyan = 6,
        white = 7,
        bright_black = 8,
        bright_red = 9,
        bright_green = 10,
        bright_yellow = 11,
        bright_blue = 12,
        bright_magenta = 13,
        bright_cyan = 14,
        bright_white = 15,
    };

    /// Mouse button types
    pub const MouseButton = enum {
        left,
        right,
        middle,
        scroll_up,
        scroll_down,
    };

    /// Mouse event with button, position, and press/release state
    pub const MouseEvent = struct {
        button: MouseButton,
        row: u16,
        col: u16,
        pressed: bool,
    };

    /// Input event representation (keyboard or mouse)
    pub const Key = union(enum) {
        char: u8,
        escape,
        enter,
        backspace,
        tab,
        arrow_up,
        arrow_down,
        arrow_left,
        arrow_right,
        home,
        end,
        page_up,
        page_down,
        insert,
        delete,
        f1,
        f2,
        f3,
        f4,
        f5,
        f6,
        f7,
        f8,
        f9,
        f10,
        f11,
        f12,
        mouse: MouseEvent,
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
        if (self.mouse_enabled) {
            self.disableMouse() catch {};
        }
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

    pub fn moveUp(self: *Self, n: u16) WriteError!void {
        if (n > 0) try self.writer().print("\x1b[{}A", .{n});
    }

    pub fn moveDown(self: *Self, n: u16) WriteError!void {
        if (n > 0) try self.writer().print("\x1b[{}B", .{n});
    }

    pub fn moveRight(self: *Self, n: u16) WriteError!void {
        if (n > 0) try self.writer().print("\x1b[{}C", .{n});
    }

    pub fn moveLeft(self: *Self, n: u16) WriteError!void {
        if (n > 0) try self.writer().print("\x1b[{}D", .{n});
    }

    pub fn saveCursor(self: *Self) WriteError!void {
        try self.writer().writeAll("\x1b7");
    }

    pub fn restoreCursor(self: *Self) WriteError!void {
        try self.writer().writeAll("\x1b8");
    }

    // -------------------------------------------------------------------------
    // Screen Control
    // -------------------------------------------------------------------------

    pub fn clear(self: *Self) WriteError!void {
        try self.ansi("2J");
    }

    /// Clear the current line
    pub fn clearLine(self: *Self) WriteError!void {
        try self.ansi("2K");
    }

    /// Clear from cursor to end of line
    pub fn clearToEndOfLine(self: *Self) WriteError!void {
        try self.ansi("0K");
    }

    /// Clear from cursor to beginning of line
    pub fn clearToStartOfLine(self: *Self) WriteError!void {
        try self.ansi("1K");
    }

    /// Clear from cursor to end of screen
    pub fn clearToEndOfScreen(self: *Self) WriteError!void {
        try self.ansi("0J");
    }

    /// Clear from cursor to beginning of screen
    pub fn clearToStartOfScreen(self: *Self) WriteError!void {
        try self.ansi("1J");
    }

    pub fn enableAltScreen(self: *Self) WriteError!void {
        try self.ansi("?1049h");
        try self.flush();
    }

    pub fn disableAltScreen(self: *Self) WriteError!void {
        try self.ansi("?1049l");
        try self.flush();
    }

    // -------------------------------------------------------------------------
    // Mouse
    // -------------------------------------------------------------------------

    /// Enable mouse tracking (SGR extended mode).
    /// Reports left/right/middle clicks and scroll wheel with coordinates.
    pub fn enableMouse(self: *Self) WriteError!void {
        try self.ansi("?1000h"); // Enable basic mouse tracking
        try self.ansi("?1006h"); // Enable SGR extended mode
        try self.flush();
        self.mouse_enabled = true;
    }

    /// Disable mouse tracking.
    pub fn disableMouse(self: *Self) WriteError!void {
        try self.ansi("?1006l"); // Disable SGR extended mode
        try self.ansi("?1000l"); // Disable basic mouse tracking
        try self.flush();
        self.mouse_enabled = false;
    }

    // -------------------------------------------------------------------------
    // Scroll Region
    // -------------------------------------------------------------------------

    /// Set scroll region to rows [top, bottom] (0-indexed, inclusive).
    /// Content outside the region stays fixed during scrolling.
    pub fn setScrollRegion(self: *Self, top: u16, bottom: u16) WriteError!void {
        try self.writer().print("\x1b[{};{}r", .{ top + 1, bottom + 1 });
    }

    /// Reset scroll region to full screen.
    pub fn resetScrollRegion(self: *Self) WriteError!void {
        try self.ansi("r");
    }

    /// Scroll content up by n lines (new blank lines appear at bottom).
    pub fn scrollUp(self: *Self, n: u16) WriteError!void {
        if (n > 0) try self.writer().print("\x1b[{}S", .{n});
    }

    /// Scroll content down by n lines (new blank lines appear at top).
    pub fn scrollDown(self: *Self, n: u16) WriteError!void {
        if (n > 0) try self.writer().print("\x1b[{}T", .{n});
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

    pub fn setFgColor(self: *Self, color: Color) WriteError!void {
        const code: u8 = @intFromEnum(color);
        if (code < 8) {
            try self.writer().print("\x1b[{}m", .{30 + code});
        } else {
            try self.writer().print("\x1b[{}m", .{90 + code - 8});
        }
    }

    pub fn setBgColor(self: *Self, color: Color) WriteError!void {
        const code: u8 = @intFromEnum(color);
        if (code < 8) {
            try self.writer().print("\x1b[{}m", .{40 + code});
        } else {
            try self.writer().print("\x1b[{}m", .{100 + code - 8});
        }
    }

    pub fn resetColors(self: *Self) WriteError!void {
        try self.ansi("0m");
    }

    // -------------------------------------------------------------------------
    // Text Attributes (SGR)
    // -------------------------------------------------------------------------

    pub fn setBold(self: *Self) WriteError!void {
        try self.ansi("1m");
    }

    pub fn resetBold(self: *Self) WriteError!void {
        try self.ansi("22m");
    }

    pub fn setDim(self: *Self) WriteError!void {
        try self.ansi("2m");
    }

    pub fn resetDim(self: *Self) WriteError!void {
        try self.ansi("22m");
    }

    pub fn setItalic(self: *Self) WriteError!void {
        try self.ansi("3m");
    }

    pub fn resetItalic(self: *Self) WriteError!void {
        try self.ansi("23m");
    }

    pub fn setUnderline(self: *Self) WriteError!void {
        try self.ansi("4m");
    }

    pub fn resetUnderline(self: *Self) WriteError!void {
        try self.ansi("24m");
    }

    pub fn setBlink(self: *Self) WriteError!void {
        try self.ansi("5m");
    }

    pub fn resetBlink(self: *Self) WriteError!void {
        try self.ansi("25m");
    }

    pub fn setReverse(self: *Self) WriteError!void {
        try self.ansi("7m");
    }

    pub fn resetReverse(self: *Self) WriteError!void {
        try self.ansi("27m");
    }

    pub fn setStrikethrough(self: *Self) WriteError!void {
        try self.ansi("9m");
    }

    pub fn resetStrikethrough(self: *Self) WriteError!void {
        try self.ansi("29m");
    }

    /// Reset all text attributes (colors and styles)
    pub fn resetStyle(self: *Self) WriteError!void {
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

    /// Non-blocking key poll. Returns parsed Key or null if no input.
    /// Parses escape sequences for special keys (arrows, function keys, etc.)
    pub fn pollKey(_: *Self) ?Key {
        var fds = [_]std.posix.pollfd{.{
            .fd = stdin.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};

        const ready = std.posix.poll(&fds, 0) catch return null;
        if (ready == 0 or (fds[0].revents & std.posix.POLL.IN) == 0) {
            return null;
        }

        var buf: [1]u8 = undefined;
        const n = stdin.read(&buf) catch return null;
        if (n == 0) return null;

        const c = buf[0];

        // Handle control characters
        if (c == 13) return .enter;
        if (c == 127 or c == 8) return .backspace;
        if (c == 9) return .tab;

        // Handle escape sequences
        if (c == 27) {
            return parseEscapeSequence(&fds);
        }

        // Regular character
        return .{ .char = c };
    }

    /// Parse escape sequence after receiving ESC byte
    fn parseEscapeSequence(fds: *[1]std.posix.pollfd) ?Key {
        // Wait briefly for more bytes (distinguish ESC key from escape sequence)
        const more = std.posix.poll(fds, 10) catch return .escape;
        if (more == 0) return .escape; // Standalone Esc

        var buf: [1]u8 = undefined;
        const n = stdin.read(&buf) catch return .escape;
        if (n == 0) return .escape;

        const second = buf[0];

        // CSI sequence: ESC [
        if (second == '[') {
            return parseCsiSequence(fds);
        }

        // SS3 sequence: ESC O (F1-F4 on some terminals)
        if (second == 'O') {
            return parseSs3Sequence(fds);
        }

        // Unknown sequence, drain remaining bytes
        drainInput(fds);
        return null;
    }

    /// Parse CSI sequence (ESC [ ...)
    fn parseCsiSequence(fds: *[1]std.posix.pollfd) ?Key {
        var seq_buf: [16]u8 = undefined;
        var seq_len: usize = 0;

        // Read sequence bytes until we get a final character (letter or ~)
        while (seq_len < seq_buf.len) {
            const ready = std.posix.poll(fds, 10) catch break;
            if (ready == 0) break;

            var buf: [1]u8 = undefined;
            const n = stdin.read(&buf) catch break;
            if (n == 0) break;

            seq_buf[seq_len] = buf[0];
            seq_len += 1;

            // Check if this is a final character
            if (buf[0] >= 0x40 and buf[0] <= 0x7E) break;
        }

        if (seq_len == 0) return null;

        const seq = seq_buf[0..seq_len];

        // SGR mouse sequence: ESC [ < button ; x ; y M/m
        if (seq[0] == '<' and (seq[seq_len - 1] == 'M' or seq[seq_len - 1] == 'm')) {
            return parseSgrMouse(seq);
        }

        // Single letter sequences (arrows, home, end)
        if (seq_len == 1) {
            return switch (seq[0]) {
                'A' => .arrow_up,
                'B' => .arrow_down,
                'C' => .arrow_right,
                'D' => .arrow_left,
                'H' => .home,
                'F' => .end,
                else => null,
            };
        }

        // Tilde sequences: ESC [ <number> ~
        if (seq[seq_len - 1] == '~') {
            const num = parseNumber(seq[0 .. seq_len - 1]);
            return switch (num) {
                1 => .home,
                2 => .insert,
                3 => .delete,
                4 => .end,
                5 => .page_up,
                6 => .page_down,
                15 => .f5,
                17 => .f6,
                18 => .f7,
                19 => .f8,
                20 => .f9,
                21 => .f10,
                23 => .f11,
                24 => .f12,
                else => null,
            };
        }

        return null;
    }

    /// Parse SGR mouse sequence: < button ; x ; y M/m
    fn parseSgrMouse(seq: []const u8) ?Key {
        if (seq.len < 6) return null; // Minimum: <0;1;1M

        const pressed = seq[seq.len - 1] == 'M';
        const params = seq[1 .. seq.len - 1]; // Skip '<' and final char

        // Parse semicolon-separated values: button;x;y
        var parts: [3]u32 = .{ 0, 0, 0 };
        var part_idx: usize = 0;
        for (params) |c| {
            if (c == ';') {
                part_idx += 1;
                if (part_idx >= 3) return null;
            } else if (c >= '0' and c <= '9') {
                parts[part_idx] = parts[part_idx] * 10 + (c - '0');
            }
        }

        const button_code = parts[0];
        const col = parts[1];
        const row = parts[2];

        // Decode button (SGR mode codes)
        const button: MouseButton = switch (button_code) {
            0 => .left,
            1 => .middle,
            2 => .right,
            64 => .scroll_up,
            65 => .scroll_down,
            else => return null,
        };

        return .{
            .mouse = .{
                .button = button,
                .row = @intCast(if (row > 0) row - 1 else 0), // Convert to 0-indexed
                .col = @intCast(if (col > 0) col - 1 else 0),
                .pressed = pressed,
            },
        };
    }

    /// Parse SS3 sequence (ESC O ...) - F1-F4 keys
    fn parseSs3Sequence(fds: *[1]std.posix.pollfd) ?Key {
        const ready = std.posix.poll(fds, 10) catch return null;
        if (ready == 0) return null;

        var buf: [1]u8 = undefined;
        const n = stdin.read(&buf) catch return null;
        if (n == 0) return null;

        return switch (buf[0]) {
            'P' => .f1,
            'Q' => .f2,
            'R' => .f3,
            'S' => .f4,
            else => null,
        };
    }

    /// Parse a decimal number from bytes
    fn parseNumber(bytes: []const u8) u32 {
        var result: u32 = 0;
        for (bytes) |b| {
            if (b >= '0' and b <= '9') {
                result = result * 10 + (b - '0');
            }
        }
        return result;
    }

    /// Drain any remaining input bytes
    fn drainInput(fds: *[1]std.posix.pollfd) void {
        while (true) {
            const ready = std.posix.poll(fds, 0) catch break;
            if (ready == 0) break;
            var buf: [16]u8 = undefined;
            const n = stdin.read(&buf) catch break;
            if (n == 0) break;
        }
    }
};

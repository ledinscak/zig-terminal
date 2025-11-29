# zig-terminal

A simple terminal I/O library for Zig 0.15+.

## Features

- Buffered terminal output
- ANSI escape sequence support
- Cursor control (hide, show, move)
- Screen control (clear screen, clear line)
- Terminal size detection

## Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .@"zig-terminal" = .{
        .path = "../zig-terminal", // or use .url for remote
    },
},
```

Then in `build.zig`:

```zig
const terminal = b.dependency("zig-terminal", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("terminal", terminal.module("terminal"));
```

## Usage

```zig
const terminal = @import("terminal");

pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var term = terminal.Terminal.stdout(&buffer);

    const size = try term.getSize();
    const pos = size.center(5);

    try term.hideCursor();
    defer term.showCursor() catch {};

    try term.clear();
    try term.moveTo(pos.row, pos.col);
    try term.print("Hello", .{});
    try term.flush();
}
```

## API

### Terminal

| Method | Description |
|--------|-------------|
| `stdout(buffer)` | Create terminal for stdout |
| `init(file, buffer)` | Create terminal for any file |
| `getSize()` | Get terminal dimensions |
| `hideCursor()` | Hide cursor |
| `showCursor()` | Show cursor |
| `moveTo(row, col)` | Move cursor to position |
| `moveToOrigin()` | Move cursor to (0, 0) |
| `clear()` | Clear entire screen |
| `clearLine()` | Clear current line |
| `print(fmt, args)` | Formatted output |
| `write(bytes)` | Raw output |
| `flush()` | Flush buffer to terminal |

### Types

- `Terminal.Size` - Terminal dimensions with `center()` helper
- `Terminal.Position` - Row/column position
- `Terminal.WriteError` - I/O error type
- `Terminal.InitError` - Initialization error type

## Requirements

- Zig 0.15.0 or later
- Linux/POSIX (uses ioctl for terminal size)

## License

MIT

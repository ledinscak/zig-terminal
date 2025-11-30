# zig-terminal

A simple terminal I/O library for Zig 0.15+.

## Features

- Buffered terminal output
- Raw mode and alternate screen
- Cursor control (hide, show, move)
- Screen control (clear)
- True color support (24-bit RGB)
- Non-blocking keyboard input
- Terminal size detection

## Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .zig_terminal = .{
        .url = "https://github.com/ledinscak/zig-terminal/archive/refs/heads/main.tar.gz",
        .hash = "...", // run zig build to get hash
    },
},
```

Then in `build.zig`:

```zig
const terminal_dep = b.dependency("zig_terminal", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("terminal", terminal_dep.module("terminal"));
```

## Usage

```zig
const terminal = @import("terminal");

pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var term = terminal.Terminal.init(&buffer);

    try term.open();
    defer term.close();

    const size = try term.getSize();
    const pos = size.center(5);

    try term.setFg(0, 255, 0); // green
    try term.moveTo(pos.row, pos.col);
    try term.print("Hello", .{});
    try term.render();

    while (true) {
        if (term.pollKey()) |key| {
            if (key == 'q' or key == 27) break;
        }
        // ... render loop ...
    }
}
```

## API

### Lifecycle

| Method | Description |
|--------|-------------|
| `init(buffer)` | Create terminal with output buffer |
| `open()` | Enable raw mode, alt screen, hide cursor |
| `close()` | Restore terminal state |

### Display

| Method | Description |
|--------|-------------|
| `getSize()` | Get terminal dimensions |
| `clear()` | Clear entire screen |
| `moveTo(row, col)` | Move cursor to position |
| `moveToOrigin()` | Move cursor to (0, 0) |
| `print(fmt, args)` | Formatted output |
| `write(bytes)` | Raw output |
| `render()` | Flush buffer to terminal (call once per frame) |

### Colors

| Method | Description |
|--------|-------------|
| `setFg(r, g, b)` | Set foreground color (24-bit) |
| `setBg(r, g, b)` | Set background color (24-bit) |
| `resetColors()` | Reset to default colors |

### Input

| Method | Description |
|--------|-------------|
| `pollKey()` | Non-blocking key check (returns `q`/`Esc` or null) |

### Types

- `Terminal.Size` - Terminal dimensions with `center()` helper
- `Terminal.Position` - Row/column position

## Requirements

- Zig 0.15.0 or later
- Linux/POSIX

## License

MIT

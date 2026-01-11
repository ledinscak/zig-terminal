# zig-terminal

A low-level terminal I/O library for Zig 0.15+. Provides buffered output, ANSI escape sequences, and keyboard input handling.

## Features

- Buffered terminal output with single-call rendering
- Raw mode and alternate screen
- Cursor control (absolute/relative positioning, show/hide, save/restore)
- Screen clearing and scroll regions
- Colors: 16 ANSI colors + 24-bit true color (RGB)
- Text styles: bold, dim, italic, underline, blink, reverse, strikethrough
- Non-blocking keyboard input with escape sequence parsing

## Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .terminal = .{
        .url = "https://github.com/user/zig-terminal/archive/refs/tags/v0.2.0.tar.gz",
        .hash = "...", // zig build will show the expected hash
    },
},
```

In `build.zig`:

```zig
const terminal_dep = b.dependency("terminal", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("terminal", terminal_dep.module("terminal"));
```

## Quick Start

```zig
const term = @import("terminal");

pub fn main() !void {
    var buf: [4096]u8 = undefined;
    var t = term.Terminal.init(&buf);

    try t.open();
    defer t.close();

    try t.clear();
    try t.setFgColor(.bright_green);
    try t.moveTo(10, 5);
    try t.write("Hello, Terminal!");
    try t.render();

    // Wait for 'q' to quit
    while (true) {
        if (t.pollKey()) |key| {
            switch (key) {
                .char => |c| if (c == 'q') break,
                .escape => break,
                else => {},
            }
        }
    }
}
```

## API Reference

### Lifecycle

| Method | Description |
|--------|-------------|
| `init(buffer)` | Create terminal instance with output buffer |
| `open()` | Enable raw mode, alternate screen, hide cursor |
| `close()` | Restore terminal state |
| `render()` | Flush buffer to terminal (call once per frame) |

### Cursor Control

| Method | Description |
|--------|-------------|
| `moveTo(row, col)` | Move cursor to absolute position (0-indexed) |
| `moveToOrigin()` | Move cursor to (0, 0) |
| `moveUp(n)` | Move cursor up by n rows |
| `moveDown(n)` | Move cursor down by n rows |
| `moveLeft(n)` | Move cursor left by n columns |
| `moveRight(n)` | Move cursor right by n columns |
| `saveCursor()` | Save current cursor position |
| `restoreCursor()` | Restore saved cursor position |
| `hideCursor()` | Hide cursor |
| `showCursor()` | Show cursor |

### Screen Control

| Method | Description |
|--------|-------------|
| `getSize()` | Get terminal dimensions (returns `Size`) |
| `clear()` | Clear entire screen |
| `clearLine()` | Clear current line |
| `clearToEndOfLine()` | Clear from cursor to end of line |
| `clearToStartOfLine()` | Clear from cursor to start of line |
| `clearToEndOfScreen()` | Clear from cursor to end of screen |
| `clearToStartOfScreen()` | Clear from cursor to start of screen |

### Scroll Regions

| Method | Description |
|--------|-------------|
| `setScrollRegion(top, bottom)` | Set scrollable region (0-indexed, inclusive) |
| `resetScrollRegion()` | Reset to full screen scrolling |
| `scrollUp(n)` | Scroll content up by n lines |
| `scrollDown(n)` | Scroll content down by n lines |

### Colors

```zig
// 16 ANSI colors (wide terminal support)
try t.setFgColor(.red);
try t.setBgColor(.bright_blue);

// 24-bit true color (RGB)
try t.setFg(255, 128, 0);  // orange foreground
try t.setBg(32, 32, 32);   // dark gray background

try t.resetColors();
```

Available colors: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, and bright variants (`bright_black`, `bright_red`, etc.)

### Text Styles

| Method | Description |
|--------|-------------|
| `setBold()` / `resetBold()` | Bold text |
| `setDim()` / `resetDim()` | Dim text |
| `setItalic()` / `resetItalic()` | Italic text |
| `setUnderline()` / `resetUnderline()` | Underlined text |
| `setBlink()` / `resetBlink()` | Blinking text |
| `setReverse()` / `resetReverse()` | Reversed colors |
| `setStrikethrough()` / `resetStrikethrough()` | Strikethrough text |
| `resetStyle()` | Reset all attributes |

### Output

| Method | Description |
|--------|-------------|
| `write(bytes)` | Write raw bytes |
| `print(fmt, args)` | Formatted output |

### Input

| Method | Description |
|--------|-------------|
| `pollKey()` | Non-blocking key poll, returns `?Key` |

The `Key` union handles:
- `.char` - Regular character (access with `key.char`)
- `.escape`, `.enter`, `.backspace`, `.tab`
- `.arrow_up`, `.arrow_down`, `.arrow_left`, `.arrow_right`
- `.home`, `.end`, `.page_up`, `.page_down`, `.insert`, `.delete`
- `.f1` through `.f12`

### Types

- `Terminal.Size` - `{ width: u16, height: u16 }` with `center(content_width)` helper
- `Terminal.Position` - `{ row: u16, col: u16 }`
- `Terminal.Color` - Enum of 16 ANSI colors
- `Terminal.Key` - Union for keyboard input

## Building

```bash
zig build              # Build the library
zig build test         # Run unit tests
zig build check        # Check code formatting
zig build clean        # Remove build artifacts
```

## Examples

```bash
zig build examples     # Build all examples
zig build run-colors   # 16 ANSI color palette
zig build run-styles   # Text attributes demo
zig build run-cursor   # Cursor movement (interactive)
zig build run-scroll   # Scroll regions (interactive)
```

## Requirements

- Zig 0.15.0+
- Linux/POSIX terminal

## License

MIT

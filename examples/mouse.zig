//! Demonstrates mouse input handling

const std = @import("std");
const term = @import("terminal");

pub fn main() !void {
    var buf: [4096]u8 = undefined;
    var t = term.Terminal.init(&buf);

    try t.open();
    defer t.close();

    try t.enableMouse();
    try t.clear();

    const size = try t.getSize();

    // Draw header
    try t.moveTo(0, 0);
    try t.setFgColor(.bright_cyan);
    try t.write("Mouse Demo - Click anywhere, scroll, or press ESC/q to exit");
    try t.resetColors();

    // Draw info area
    try t.moveTo(2, 0);
    try t.write("Last event: (none)");
    try t.moveTo(3, 0);
    try t.write("Position:   (-, -)");

    try t.render();

    // Event loop
    while (true) {
        if (t.pollKey()) |key| {
            switch (key) {
                .escape => break,
                .char => |c| if (c == 'q') break,
                .mouse => |m| {
                    // Clear previous info
                    try t.moveTo(2, 0);
                    try t.clearLine();
                    try t.moveTo(3, 0);
                    try t.clearLine();

                    // Show event type
                    try t.moveTo(2, 0);
                    try t.write("Last event: ");
                    try t.setFgColor(.bright_yellow);

                    const button_name = switch (m.button) {
                        .left => "Left click",
                        .right => "Right click",
                        .middle => "Middle click",
                        .scroll_up => "Scroll up",
                        .scroll_down => "Scroll down",
                    };
                    try t.write(button_name);

                    if (m.button != .scroll_up and m.button != .scroll_down) {
                        try t.write(if (m.pressed) " (pressed)" else " (released)");
                    }

                    try t.resetColors();

                    // Show position
                    try t.moveTo(3, 0);
                    try t.print("Position:   ({}, {})", .{ m.row, m.col });

                    // Draw marker at click position (if within bounds)
                    if (m.row > 4 and m.row < size.height - 1) {
                        try t.moveTo(m.row, m.col);
                        try t.setFgColor(switch (m.button) {
                            .left => .bright_green,
                            .right => .bright_red,
                            .middle => .bright_blue,
                            .scroll_up => .bright_magenta,
                            .scroll_down => .bright_cyan,
                        });
                        try t.write(switch (m.button) {
                            .left => "L",
                            .right => "R",
                            .middle => "M",
                            .scroll_up => "^",
                            .scroll_down => "v",
                        });
                        try t.resetColors();
                    }

                    try t.render();
                },
                else => {},
            }
        }
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

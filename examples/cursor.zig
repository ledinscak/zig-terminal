//! Demonstrates cursor movement primitives

const std = @import("std");
const term = @import("terminal");

pub fn main() !void {
    var buf: [4096]u8 = undefined;
    var t = term.Terminal.init(&buf);

    try t.open();
    defer t.close();

    try t.clear();
    try t.moveToOrigin();

    // Draw a box using relative cursor movement
    const width: u16 = 30;
    const height: u16 = 10;

    try t.moveTo(2, 5);
    try t.setFgColor(.bright_cyan);

    // Top border
    try t.write("+");
    for (0..width - 2) |_| try t.write("-");
    try t.write("+");

    // Sides
    for (0..height - 2) |_| {
        try t.moveDown(1);
        try t.moveLeft(width);
        try t.write("|");
        try t.moveRight(width - 2);
        try t.write("|");
    }

    // Bottom border
    try t.moveDown(1);
    try t.moveLeft(width);
    try t.write("+");
    for (0..width - 2) |_| try t.write("-");
    try t.write("+");

    // Text inside box using save/restore
    try t.saveCursor();
    try t.moveTo(5, 10);
    try t.setFgColor(.bright_yellow);
    try t.write("Cursor Movement Demo");
    try t.moveTo(7, 10);
    try t.setFgColor(.white);
    try t.write("Press any key to exit");
    try t.restoreCursor();

    try t.resetColors();
    try t.render();

    // Wait for keypress
    while (t.pollKey() == null) {
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
}

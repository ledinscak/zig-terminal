//! Demonstrates scroll regions with fixed header/footer
//!
//! This shows how setScrollRegion() keeps header/footer fixed while
//! the middle area scrolls. Note: terminal scroll is destructive -
//! content that scrolls off-screen is lost. For virtual scrolling
//! with a content buffer, use a TUI library.

const std = @import("std");
const term = @import("terminal");

pub fn main() !void {
    var buf: [4096]u8 = undefined;
    var t = term.Terminal.init(&buf);

    try t.open();
    defer t.close();

    const size = try t.getSize();
    try t.clear();

    // Draw fixed header (row 0)
    try t.moveTo(0, 0);
    try t.setBgColor(.blue);
    try t.setFgColor(.bright_white);
    for (0..size.width) |_| try t.write(" ");
    try t.moveTo(0, 2);
    try t.write("Scroll Region Demo - This header stays fixed");
    try t.resetColors();

    // Draw fixed footer (last row)
    try t.moveTo(size.height - 1, 0);
    try t.setBgColor(.blue);
    try t.setFgColor(.bright_white);
    for (0..size.width) |_| try t.write(" ");
    try t.moveTo(size.height - 1, 2);
    try t.write("UP/DOWN to scroll | A to add line | Q to quit");
    try t.resetColors();

    // Set scroll region (rows 1 to height-2, between header and footer)
    const scroll_top: u16 = 1;
    const scroll_bottom: u16 = size.height - 2;
    try t.setScrollRegion(scroll_top, scroll_bottom);

    // Fill the scrollable area with initial content
    const content_lines = scroll_bottom - scroll_top + 1;
    for (0..content_lines) |i| {
        const row: u16 = scroll_top + @as(u16, @intCast(i));
        try t.moveTo(row, 2);
        try t.setFgColor(.cyan);
        try t.print("Line {d:2}", .{i + 1});
        try t.resetColors();
        try t.write(" - Content in scroll region");
    }

    var line_counter: u32 = content_lines;
    try t.render();

    // Handle input
    while (true) {
        if (t.pollKey()) |key| {
            switch (key) {
                .char => |c| {
                    if (c == 'q' or c == 'Q') break;
                    if (c == 'a' or c == 'A') {
                        // Add new line at bottom (scroll up, then write)
                        try t.scrollUp(1);
                        line_counter += 1;
                        try t.moveTo(scroll_bottom, 2);
                        try t.clearToEndOfLine();
                        try t.setFgColor(.bright_green);
                        try t.print("Line {d:2}", .{line_counter});
                        try t.resetColors();
                        try t.write(" - New line added!");
                        try t.render();
                    }
                },
                .arrow_up => {
                    try t.scrollDown(1);
                    // Top line is now blank - you'd redraw from buffer here in a real app
                    try t.moveTo(scroll_top, 2);
                    try t.setFgColor(.yellow);
                    try t.write("(scrolled - no buffer to restore from)");
                    try t.resetColors();
                    try t.render();
                },
                .arrow_down => {
                    try t.scrollUp(1);
                    // Bottom line is now blank
                    try t.moveTo(scroll_bottom, 2);
                    try t.setFgColor(.yellow);
                    try t.write("(scrolled - no buffer to restore from)");
                    try t.resetColors();
                    try t.render();
                },
                else => {},
            }
        }
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }

    try t.resetScrollRegion();
}

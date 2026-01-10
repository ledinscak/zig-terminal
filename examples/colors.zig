//! Demonstrates all 16 ANSI colors

const std = @import("std");
const term = @import("terminal");

pub fn main() !void {
    var buf: [4096]u8 = undefined;
    var t = term.Terminal.init(&buf);

    const colors = [_]struct { color: term.Color, name: []const u8 }{
        .{ .color = .black, .name = "black" },
        .{ .color = .red, .name = "red" },
        .{ .color = .green, .name = "green" },
        .{ .color = .yellow, .name = "yellow" },
        .{ .color = .blue, .name = "blue" },
        .{ .color = .magenta, .name = "magenta" },
        .{ .color = .cyan, .name = "cyan" },
        .{ .color = .white, .name = "white" },
        .{ .color = .bright_black, .name = "bright_black" },
        .{ .color = .bright_red, .name = "bright_red" },
        .{ .color = .bright_green, .name = "bright_green" },
        .{ .color = .bright_yellow, .name = "bright_yellow" },
        .{ .color = .bright_blue, .name = "bright_blue" },
        .{ .color = .bright_magenta, .name = "bright_magenta" },
        .{ .color = .bright_cyan, .name = "bright_cyan" },
        .{ .color = .bright_white, .name = "bright_white" },
    };

    try t.write("\n  ANSI 16 Colors Demo\n");
    try t.write("  ===================\n\n");

    // Foreground colors
    try t.write("  Foreground:\n  ");
    for (colors) |c| {
        try t.setFgColor(c.color);
        try t.print("{s:<14}", .{c.name});
        try t.resetColors();
        if (c.color == .white or c.color == .bright_white) {
            try t.write("\n  ");
        }
    }

    try t.write("\n  Background:\n  ");
    for (colors) |c| {
        try t.setBgColor(c.color);
        if (c.color == .black or c.color == .blue or c.color == .bright_black or c.color == .bright_blue) {
            try t.setFgColor(.white);
        } else {
            try t.setFgColor(.black);
        }
        try t.print(" {s:<12} ", .{c.name});
        try t.resetColors();
        if (c.color == .white or c.color == .bright_white) {
            try t.write("\n  ");
        }
    }

    try t.write("\n");
    try t.render();
}

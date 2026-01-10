//! Demonstrates text attributes/styles

const std = @import("std");
const term = @import("terminal");

pub fn main() !void {
    var buf: [4096]u8 = undefined;
    var t = term.Terminal.init(&buf);

    try t.write("\n  Text Styles Demo\n");
    try t.write("  =================\n\n");

    try t.write("  ");
    try t.setBold();
    try t.write("Bold text");
    try t.resetStyle();
    try t.write("\n");

    try t.write("  ");
    try t.setDim();
    try t.write("Dim text");
    try t.resetStyle();
    try t.write("\n");

    try t.write("  ");
    try t.setItalic();
    try t.write("Italic text");
    try t.resetStyle();
    try t.write("\n");

    try t.write("  ");
    try t.setUnderline();
    try t.write("Underlined text");
    try t.resetStyle();
    try t.write("\n");

    try t.write("  ");
    try t.setBlink();
    try t.write("Blinking text");
    try t.resetStyle();
    try t.write("\n");

    try t.write("  ");
    try t.setReverse();
    try t.write("Reversed text");
    try t.resetStyle();
    try t.write("\n");

    try t.write("  ");
    try t.setStrikethrough();
    try t.write("Strikethrough text");
    try t.resetStyle();
    try t.write("\n");

    // Combined styles
    try t.write("\n  Combined styles:\n");
    try t.write("  ");
    try t.setBold();
    try t.setFgColor(.bright_red);
    try t.write("Bold + Red");
    try t.resetStyle();
    try t.write("  ");

    try t.setItalic();
    try t.setUnderline();
    try t.setFgColor(.bright_green);
    try t.write("Italic + Underline + Green");
    try t.resetStyle();
    try t.write("\n\n");

    try t.render();
}

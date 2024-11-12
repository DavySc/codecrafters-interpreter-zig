const std = @import("std");
const stderr = std.io.getStdErr().writer();
const stdout = std.io.getStdOut().writer();

const MyErrors = error{tokenNotFound};
const TokenType = enum(u8) {
    LEFT_PAREN = '(',
    RIGHT_PAREN = ')',
    LEFT_BRACE = '{',
    RIGHT_BRACE = '}',
    COMMA = ',',
    DOT = '.',
    PLUS = '+',
    MINUS = '-',
    LESS = '<',
    GREATER = '>',
    SLASH = '/',
    SEMICOLON = ';',
    STAR = '*',
    EOF = 0,
};

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: ./your_program.sh tokenize <filename>\n", .{});

        std.process.exit(1);
    }

    const command = args[1];

    const filename = args[2];

    if (!std.mem.eql(u8, command, "tokenize")) {
        std.debug.print("Unknown command: {s}\n", .{command});
        std.process.exit(1);
    }

    const file_contents = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, filename, std.math.maxInt(usize));

    defer std.heap.page_allocator.free(file_contents);

    var exit_code: u8 = 0;

    if (file_contents.len > 0) {
        var it = std.mem.tokenizeScalar(u8, file_contents, '\n');

        var line_count: usize = 0;

        while (it.next()) |line| {
            line_count += 1;

            for (0..line.len) |i| {
                switch (line[i]) {
                    '(' => {
                        try addToken(TokenType.LEFT_PAREN);
                    },
                    ')' => {
                        try addToken(TokenType.RIGHT_PAREN);
                    },
                    '{' => {
                        try addToken(TokenType.LEFT_BRACE);
                    },
                    '}' => {
                        try addToken(TokenType.RIGHT_BRACE);
                    },
                    ',' => {
                        try addToken(TokenType.COMMA);
                    },
                    '.' => {
                        try addToken(TokenType.DOT);
                    },
                    '+' => {
                        try addToken(TokenType.PLUS);
                    },
                    '-' => {
                        try addToken(TokenType.MINUS);
                    },
                    '<' => {
                        try addToken(TokenType.LESS);
                    },
                    '>' => {
                        try addToken(TokenType.GREATER);
                    },
                    '/' => {
                        try addToken(TokenType.SLASH);
                    },
                    ';' => {
                        try addToken(TokenType.SEMICOLON);
                    },
                    '*' => {
                        try addToken(TokenType.STAR);
                    },
                    else => {
                        try stderr.print("[line {d}] Error: Unexpected character: {c}\n", .{ line_count, line[i] });
                        exit_code = 65;
                    },
                }
            }
        }

        try stdout.print("EOF  null\n", .{}); // Placeholder, remove this line when implementing the scanner

    } else {
        try stdout.print("EOF  null\n", .{}); // Placeholder, remove this line when implementing the scanner

    }
    std.process.exit(exit_code);
}

fn addToken(token: TokenType) !void {
    try stdout.print("{s} {c} null\n", .{ @tagName(token), @intFromEnum(token) });
}

fn match(c: u8, i: usize, line: []const u8) bool {
    const next = i + 1;

    return next < line.len and line[next] == c;
}

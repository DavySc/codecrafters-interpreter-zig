const std = @import("std");

const MyErrors = error{tokenNotFound};
const TokenType = enum {
    EOF,
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    STAR,
    DOT,
    COMMA,
    PLUS,
    MINUS,
    SEMICOLON,
};

const Token = struct {
    tokenType: TokenType,
    lexeme: []const u8,
    literal: ?[]u8,
};

const LParenToken = Token{
    .tokenType = .LEFT_PAREN,
    .lexeme = "(",
    .literal = null,
};

const RParenToken = Token{
    .tokenType = .RIGHT_PAREN,
    .lexeme = ")",
    .literal = null,
};

const EOFToken = Token{
    .tokenType = .EOF,
    .lexeme = "",
    .literal = null,
};

fn match(c: u8) MyErrors!Token {
    switch (c) {
        '(' => {
            return LParenToken;
        },
        ')' => {
            return RParenToken;
        },
        '{' => {
            return Token{ .tokenType = .LEFT_BRACE, .lexeme = "{", .literal = null };
        },
        '}' => {
            return Token{ .tokenType = .RIGHT_BRACE, .lexeme = "}", .literal = null };
        },
        ',' => {
            return Token{ .tokenType = .COMMA, .lexeme = ",", .literal = null };
        },
        '.' => {
            return Token{ .tokenType = .DOT, .lexeme = ".", .literal = null };
        },
        '-' => {
            return Token{ .tokenType = .MINUS, .lexeme = "-", .literal = null };
        },
        '+' => {
            return Token{ .tokenType = .PLUS, .lexeme = "+", .literal = null };
        },
        ';' => {
            return Token{ .tokenType = .SEMICOLON, .lexeme = ";", .literal = null };
        },
        '*' => {
            return Token{ .tokenType = .STAR, .lexeme = "*", .literal = null };
        },
        0 => {
            return EOFToken;
        },
        else => {
            return MyErrors.tokenNotFound;
        },
    }
}

pub fn main() !void {
    // You can use print statements as follows for debugging, they'll be visible when running tests.
    std.debug.print("Logs from your program will appear here!\n", .{});

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

    // Uncomment this block to pass the first stage
    if (file_contents.len > 0) {
        for (file_contents) |c| {
            if (c == '\n') {
                std.debug.print("fml", .{});
                continue;
            }
            const token = try match(c);
            try std.io.getStdOut().writer().print("{s} {s} {any}\n", .{ @tagName(token.tokenType), token.lexeme, token.literal });
        }
        try std.io.getStdOut().writer().print("{s} {s} {any}\n", .{ @tagName(EOFToken.tokenType), EOFToken.lexeme, EOFToken.literal });
    } else {
        // try std.io.getStdOut().writer().print("EOF  null\n", .{}); // Placeholder, remove this line when implementing the scanner
        try std.io.getStdOut().writer().print("{s} {s} {any}\n", .{ @tagName(EOFToken.tokenType), EOFToken.lexeme, EOFToken.literal });
    }
}

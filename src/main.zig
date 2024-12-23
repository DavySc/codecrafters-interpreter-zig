const std = @import("std");
const stderr = std.io.getStdErr().writer();
const stdout = std.io.getStdOut().writer();

const MyErrors = error{tokenNotFound};

var hadError: bool = false;

fn @"error"(line: u32, comptime message: []const u8, args: anytype) !void {
    try std.fmt.format(stderr, "[line {}] Error: ", .{line});
    try std.fmt.format(stderr, message ++ "\n", args);
    hadError = true;
}

const Literal = union(enum) {
    number: f64,
    string: []const u8,
    none,

    pub fn format(self: Literal, comptime _: []const u8, _: std.fmt.FormatOptions, _writer: anytype) !void {
        switch (self) {
            .string => |s| {
                try _writer.print("{s}", .{s});
            },

            .number => |n| {
                var buf: [256]u8 = undefined;
                const str = try std.fmt.bufPrint(&buf, "{d}", .{n});
                try _writer.writeAll(str);
                if (std.mem.indexOfScalar(u8, str, '.') == null) {
                    try _writer.writeAll(".0");
                }
            },

            .none => {
                _ = try _writer.write("null");
            },
        }
    }
};
const Token = struct {
    tokentype: Type,
    lexeme: []const u8,
    literal: Literal,

    const Type = enum {
        LEFT_PAREN,
        RIGHT_PAREN,
        LEFT_BRACE,
        RIGHT_BRACE,
        COMMA,
        DOT,
        PLUS,
        MINUS,
        LESS,
        GREATER,
        SLASH,
        SEMICOLON,
        STAR,
        EOF,
        BANG,
        BANG_EQUAL,
        EQUAL,
        EQUAL_EQUAL,
        GREATER_EQUAL,
        LESS_EQUAL,
        STRING,
        NUMBER,
        IDENTIFIER,
        AND,
        CLASS,
        ELSE,
        FALSE,
        FOR,
        FUN,
        IF,
        NIL,
        OR,
        PRINT,
        RETURN,
        SUPER,
        THIS,
        TRUE,
        VAR,
        WHILE,
    };

    pub fn format(self: Token) !void {
        var buf: [32]u8 = undefined;

        try stdout.print("{s} {s} {?}\n", .{ std.ascii.upperString(&buf, @tagName(self.tokentype)), self.lexeme, self.literal });
    }
};

const Scanner = struct {
    source: []const u8,
    tokens: std.ArrayList(Token),
    start: usize = 0,
    current: usize = 0,
    line: u32 = 1,

    const keywords = std.StaticStringMap(Token.Type).initComptime(.{
        .{ "and", .AND },
        .{ "class", .CLASS },
        .{ "else", .ELSE },
        .{ "false", .FALSE },
        .{ "for", .FOR },
        .{ "fun", .FUN },
        .{ "if", .IF },
        .{ "nil", .NIL },
        .{ "or", .OR },
        .{ "print", .PRINT },
        .{ "return", .RETURN },
        .{ "super", .SUPER },
        .{ "this", .THIS },
        .{ "true", .TRUE },
        .{ "var", .VAR },
        .{ "while", .WHILE },
    });

    fn init(source: []const u8, allocator: std.mem.Allocator) Scanner {
        return .{
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }
    fn deinit(self: *Scanner) void {
        self.tokens.deinit();
    }

    fn scanTokens(self: *Scanner) ![]const Token {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }
        try self.tokens.append(.{ .tokentype = .EOF, .lexeme = "", .literal = .none });
        return self.tokens.items;
    }

    fn scanToken(self: *Scanner) !void {
        const c = self.advance();

        switch (c) {
            '(' => {
                try self.addToken(.LEFT_PAREN, Literal.none);
            },
            ')' => {
                try self.addToken(.RIGHT_PAREN, Literal.none);
            },
            '{' => {
                try self.addToken(.LEFT_BRACE, Literal.none);
            },
            '}' => {
                try self.addToken(.RIGHT_BRACE, Literal.none);
            },
            ',' => {
                try self.addToken(.COMMA, Literal.none);
            },
            '.' => {
                try self.addToken(.DOT, Literal.none);
            },
            '+' => {
                try self.addToken(.PLUS, Literal.none);
            },
            '-' => {
                try self.addToken(.MINUS, Literal.none);
            },
            '<' => {
                if (self.match('=')) {
                    try self.addToken(.LESS_EQUAL, Literal.none);
                } else {
                    try self.addToken(.LESS, Literal.none);
                }
            },
            '>' => {
                if (self.match('=')) {
                    try self.addToken(.GREATER_EQUAL, Literal.none);
                } else {
                    try self.addToken(.GREATER, Literal.none);
                }
            },
            '!' => {
                if (self.match('=')) {
                    try self.addToken(.BANG_EQUAL, Literal.none);
                } else {
                    try self.addToken(.BANG, Literal.none);
                }
            },
            '=' => {
                if (self.match('=')) {
                    try self.addToken(.EQUAL_EQUAL, Literal.none);
                } else {
                    try self.addToken(.EQUAL, Literal.none);
                }
            },
            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and self.isAtEnd() == false) {
                        _ = self.advance();
                    }
                } else {
                    try self.addToken(.SLASH, Literal.none);
                }
            },
            ';' => {
                try self.addToken(.SEMICOLON, Literal.none);
            },
            '*' => {
                try self.addToken(.STAR, Literal.none);
            },
            ' ' => {},
            '\r' => {},
            '\t' => {},
            '\n' => {
                self.line += 1;
            },
            '"' => {
                try self.string();
            },
            '0'...'9' => {
                try self.number();
            },
            'a'...'z', 'A'...'Z', '_' => {
                try self.identifier();
            },
            else => {
                try @"error"(self.line, "Unexpected character: {c}", .{c});
            },
        }
    }

    fn isAlpha(c: u8) bool {
        return switch (c) {
            '0'...'9', 'a'...'z', 'A'...'Z', '_' => true,
            else => false,
        };
    }

    fn identifier(self: *Scanner) !void {
        while (isAlpha(self.peek())) _ = self.advance();
        const id_type = if (keywords.get(self.source[self.start..self.current])) |@"type"|
            @"type"
        else
            .IDENTIFIER;

        try self.addToken(id_type, Literal.none);
    }

    fn number(self: *Scanner) !void {
        while (std.ascii.isDigit(self.peek())) _ = self.advance();
        if (self.peek() == '.' and std.ascii.isDigit(self.peekNext())) {
            _ = self.advance();
            while (std.ascii.isDigit(self.peek())) _ = self.advance();
        }

        try self.addToken(.NUMBER, .{ .number = try std.fmt.parseFloat(f64, self.source[self.start..self.current]) });
    }
    fn peekNext(self: *Scanner) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn string(self: *Scanner) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }
        if (self.isAtEnd()) {
            try @"error"(self.line, "Unterminated string.", .{});
            return;
        }
        _ = self.advance();
        try self.addToken(.STRING, .{ .string = self.source[self.start + 1 .. self.current - 1] });
    }
    fn peek(self: *Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }
    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        return true;
    }
    fn isAtEnd(self: *Scanner) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Scanner) u8 {
        defer self.current += 1;
        return self.source[self.current];
    }

    fn addToken(self: *Scanner, tokenType: Token.Type, literal: Literal) !void {
        try self.tokens.append(.{
            .tokentype = tokenType,
            .lexeme = self.source[self.start..self.current],
            .literal = literal,
        });
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);

    defer std.process.argsFree(allocator, args);

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

    if (file_contents.len > 0) {
        var scanner = Scanner.init(file_contents, std.heap.page_allocator);
        defer scanner.deinit();

        for (try scanner.scanTokens()) |token| {
            try token.format();
        }
    } else {
        try stdout.print("EOF  null\n", .{});
    }

    if (hadError) {
        std.process.exit(65);
    }
}

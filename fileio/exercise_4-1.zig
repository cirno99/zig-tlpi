// Exercise 4-1
// The `tee` command reads its standard input until end-of-file, writing a copy of the input to
// standard output and to the file named in its command-line argument. Implement `tee` using I/O
// system calls. By default, `tee` overwrites any existing file with the given name. Implement
// the `-a` command-line option (`tee -a file`), which causes `tee` to append text to the end of
// a file if it already exists.

const std = @import("std");
const os = std.os;
const warn = std.log.warn;
const strcmp = std.zig.c_builtins.__builtin_strcmp;
const O = os.O;
const S = os.S;

const BUFFER_SIZE = 1024;
const FILE_PERMS = S.IRUSR | S.IWUSR | S.IRGRP | S.IWGRP | S.IROTH | S.IWOTH; // rw-rw-rw-
const OPEN_FLAGS = O.CREAT | O.WRONLY;

const Options = struct { filename: [*:0]u8, open_flag: u32 };

pub fn main() !u8 {
    if (os.argv.len < 2 or strcmp(os.argv[1], "--help") == 0) {
        warn("Usage: tee [-a] output-file\n", .{});
        return 1;
    }

    const options = if (strcmp(os.argv[1], "-a") == 0)
        Options{ .filename = os.argv[2], .open_flag = O.APPEND }
    else
        Options{ .filename = os.argv[1], .open_flag = O.TRUNC };

    const stdin = std.io.getStdIn().handle;
    const stdout = std.io.getStdOut().handle;

    const output_fd = try os.openZ(options.filename, options.open_flag | OPEN_FLAGS, FILE_PERMS);
    defer os.close(output_fd);

    var buffer: [BUFFER_SIZE]u8 = undefined;

    while (os.read(stdin, &buffer)) |bytes_read| {
        if (bytes_read == 0) break;

        if (write_both(stdout, output_fd, buffer[0..bytes_read])) |bytes_written| {
            if (bytes_written != bytes_read) {
                warn("Error: couldn't write whole buffer ({} != {})", .{ bytes_written, bytes_read });
                return 1;
            }
        } else |err| {
            warn("Error: write {}", .{err});
            return 1;
        }
    } else |err| {
        warn("Error: read {}", .{err});
        return 1;
    }

    return 0;
}

fn write_both(fd_a: c_int, fd_b: c_int, buffer: []u8) os.WriteError!u64 {
    const a_written = try os.write(fd_a, buffer);
    const b_written = try os.write(fd_b, buffer);

    return @min(a_written, b_written);
}

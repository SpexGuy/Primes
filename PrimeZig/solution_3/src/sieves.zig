const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn IntSieve(comptime T: type, sieve_size: comptime_int) type {
    return struct {
        // values
        pub const size = sieve_size;
        pub const TRUE = if (T == bool) true else 1;
        pub const FALSE = if (T == bool) false else 0;

        const Self = @This();
        const field_size = sieve_size >> 1;

        // storage
        field: *[field_size]T align(std.mem.page_size),
        allocator: *Allocator,

        // member functions

        pub fn create(allocator: *Allocator) !Self {
            // allocates an array of data.
            var field: *[field_size]T = try allocator.create([field_size]T);
            return Self{ .field = field, .allocator = allocator };
        }

        pub fn destroy(self: *Self) void {
            self.allocator.destroy(self.field);
        }

        pub fn reset(self: *Self) void {
            for (self.field.*) |*number| {
                number.* = TRUE;
            }
        }

        pub fn primeCount(self: *Self) usize {
            var count: usize = 0;
            var idx: usize = 0;

            for (self.field.*) |value| {
                if (T == bool) {
                    count += @boolToInt(value);
                } else {
                    count += value;
                }
            }

            return count;
        }

        pub fn findNextFactor(self: *Self, factor: usize) usize {
            const field = self.field;
            var num = factor + 2;
            while (num < field_size) : (num += 2) {
                if (T == bool) {
                    if (field.*[num >> 1]) {
                        return num;
                    }
                } else {
                    if (field.*[num >> 1] == TRUE) {
                        return num;
                    }
                }
            }
            return num;
        }

        pub fn runFactor(self: *Self, factor: usize) void {
            const field = self.field;
            var num = (factor * factor) >> 1;
            while (num < field_size) : (num += factor) {
                field.*[num] = FALSE;
            }
        }
        pub const name = "sieve-" ++ @typeName(T);
    };
}

pub fn BitSieve(comptime T: type, sieve_size: comptime_int) type {
    return struct {
        // values
        pub const size = sieve_size;
        const bit_width = @bitSizeOf(T);
        const bit_shift = @floatToInt(u6, @log2(@intToFloat(f64, bit_width)));

        const Self = @This();
        const field_size = sieve_size >> 1;
        const needs_pad = (field_size % bit_width) != 0;
        const field_units = @divTrunc(field_size, bit_width) + if (needs_pad) 1 else 0;

        // storage
        field: *[field_units]T align(std.mem.page_size),
        allocator: *Allocator,

        // member functions

        pub fn create(allocator: *Allocator) !Self {
            // allocates an array of data.
            var field: *[field_units]T = try allocator.create([field_units]T);
            return Self{ .field = field, .allocator = allocator };
        }

        pub fn destroy(self: *Self) void {
            self.allocator.destroy(self.field);
        }

        pub fn reset(self: *Self) void {
            comptime const finalmask = (1 << (field_size % bit_width)) - 1;
            for (self.field.*) |*number| {
                number.* = @as(T, 0) -% 1;
            }
            if (needs_pad) {
                self.field.*[field_units - 1] = finalmask;
            }
        }

        pub fn primeCount(self: *Self) usize {
            var count: usize = 0;
            var idx: usize = 0;

            for (self.field.*) |value| {
                count += @popCount(T, value);
            }

            return count;
        }

        // a mask that is usable to obtain the residual (remainder) from the
        // bitshift operation.  This is the bit position within the datastructure
        // that represents the primeness of the requested number.
        const residue_mask = (1 << bit_shift) - 1;

        pub fn findNextFactor(self: *Self, factor: usize) usize {
            comptime const masks = trailing_masks();
            const field = self.field;
            var num = (factor + 2) >> 1;
            var index = num >> bit_shift;
            var slot = field.*[index] & masks[num & residue_mask];
            if (slot == 0) {
                for (field.*[index + 1 ..]) |s| {
                    index += 1;
                    slot = s;
                    if (s != 0) {
                        break;
                    }
                }
            }
            return (((index << bit_shift) + @ctz(T, slot)) << 1) + 1;
        }

        pub fn runFactor(self: *Self, factor: usize) void {
            comptime const masks = bit_masks();
            const field = self.field;
            var num = (factor * factor) >> 1;
            while (num < field_size) : (num += factor) {
                var index = num >> bit_shift;
                field.*[index] &= masks[num & residue_mask];
            }
        }

        const shift_t = switch (T) {
            u8 => u3,
            u16 => u4,
            u32 => u5,
            u64 => u6,
            else => unreachable,
        };

        fn trailing_masks() comptime [bit_width]T {
            var masks = std.mem.zeroes([bit_width]T);
            for (masks) |*value, index| {
                value.* = @as(T, 0) -% (@as(T, 1) << @intCast(shift_t, index));
            }
            return masks;
        }

        fn bit_masks() comptime [bit_width]T {
            var masks = std.mem.zeroes([bit_width]T);
            for (masks) |*value, index| {
                value.* = (@as(T, 1) << @intCast(shift_t, index));
                value.* ^= (@as(T, 0) -% @as(T, 1));
            }
            return masks;
        }

        pub const name = "bitSieve-" ++ @typeName(T);
    };
}

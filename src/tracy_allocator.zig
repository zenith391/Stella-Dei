const std = @import("std");
const tracy = @import("vendor/tracy.zig");
const Allocator = std.mem.Allocator;

pub const TracyAllocator = struct {
    parent_allocator: Allocator,

    pub fn init(parent_allocator: Allocator) TracyAllocator {
        return TracyAllocator{ .parent_allocator = parent_allocator };
    }

    pub fn allocator(self: *TracyAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(ptr: *anyopaque, len: usize, ptr_align: u8, ra: usize) ?[*]u8 {
        const self: *TracyAllocator = @ptrCast(@alignCast(ptr));
        const result = self.parent_allocator.rawAlloc(len, ptr_align, ra);
        if (result) |slice| {
            tracy.Alloc(slice, len);
        }
        return result;
    }

    fn resize(ptr: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ra: usize) bool {
        const self: *TracyAllocator = @ptrCast(@alignCast(ptr));
        if (self.parent_allocator.rawResize(buf, buf_align, new_len, ra)) {
            if (new_len > buf.len) {
                tracy.Free(buf.ptr);
                tracy.Alloc(buf.ptr, new_len);
            }
            return true;
        } else {
            return false;
        }
    }

    fn free(ptr: *anyopaque, buf: []u8, buf_align: u8, ra: usize) void {
        const self: *TracyAllocator = @ptrCast(@alignCast(ptr));
        self.parent_allocator.rawFree(buf, buf_align, ra);
        tracy.Free(buf.ptr);
    }
};

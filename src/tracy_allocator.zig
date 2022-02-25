const std = @import("std");
const tracy = @import("vendor/tracy.zig");
const Allocator = std.mem.Allocator;

pub const TracyAllocator = struct {
	parent_allocator: Allocator,

	pub fn init(parent_allocator: Allocator) TracyAllocator {
		return TracyAllocator {
			.parent_allocator = parent_allocator
		};
	}

	pub fn allocator(self: *TracyAllocator) Allocator {
		return Allocator.init(self, alloc, resize, free);
	}

	fn alloc(self: *TracyAllocator, len: usize, ptr_align: u29, len_align: u29, ra: usize) std.mem.Allocator.Error![]u8 {
		const result = self.parent_allocator.rawAlloc(len, ptr_align, len_align, ra);
		if (result) |slice| {
			tracy.Alloc(slice.ptr, slice.len);
		} else |err| {
			err catch {};
		}
		return result;
	}

	fn resize(self: *TracyAllocator, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ra: usize) ?usize {
		if (self.parent_allocator.rawResize(buf, buf_align, new_len, len_align, ra)) |resized_len| {
			if (new_len > buf.len) {
				tracy.Free(buf.ptr);
				tracy.Alloc(buf.ptr, new_len);
			}
			return resized_len;
		} else {
			return null;
		}
	}

	fn free(self: *TracyAllocator, buf: []u8, buf_align: u29, ra: usize) void {
		self.parent_allocator.rawFree(buf, buf_align, ra);
		tracy.Free(buf.ptr);
	}
};

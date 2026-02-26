const std = @import("std");
const rlp = @import("rlp.zig");

/// A single entry in an EIP-2930 access list: an address plus the storage slots it accesses.
pub const AccessListItem = struct {
    address: [20]u8,
    storage_keys: []const [32]u8,
};

/// EIP-2930 access list: a list of address/storage-key pairs that the transaction accesses.
pub const AccessList = []const AccessListItem;

/// RLP-encode an access list into the given ArrayList.
/// Each item is encoded as: [address, [key0, key1, ...]].
pub fn encodeAccessList(list: *std.ArrayList(u8), access_list: AccessList) (std.mem.Allocator.Error || rlp.RlpError)!void {
    // Encode the outer list contents into a temp buffer, then wrap with list header.
    var outer = std.ArrayList(u8).init(list.allocator);
    defer outer.deinit();

    for (access_list) |item| {
        // Each item is an RLP list: [address, [storageKey0, storageKey1, ...]]
        var item_buf = std.ArrayList(u8).init(list.allocator);
        defer item_buf.deinit();

        // Encode address (20-byte string)
        try rlp.encodeInto(&item_buf, item.address);

        // Encode storage keys as a list
        var keys_buf = std.ArrayList(u8).init(list.allocator);
        defer keys_buf.deinit();
        for (item.storage_keys) |key| {
            try rlp.encodeInto(&keys_buf, key);
        }

        // Write list header + keys content
        try encodeLength(&item_buf, keys_buf.items.len, 0xc0);
        try item_buf.appendSlice(keys_buf.items);

        // Write item list header + item content
        try encodeLength(&outer, item_buf.items.len, 0xc0);
        try outer.appendSlice(item_buf.items);
    }

    // Write outer list header + outer content
    try encodeLength(list, outer.items.len, 0xc0);
    try list.appendSlice(outer.items);
}

/// Encode a length prefix (same logic as rlp.zig's internal encodeLength, re-implemented
/// here since that function is not pub).
fn encodeLength(list: *std.ArrayList(u8), len: usize, offset: u8) std.mem.Allocator.Error!void {
    if (len < 56) {
        try list.append(offset + @as(u8, @intCast(len)));
    } else {
        var len_bytes: usize = 0;
        var temp = len;
        while (temp > 0) : (temp >>= 8) {
            len_bytes += 1;
        }
        try list.append(offset + 55 + @as(u8, @intCast(len_bytes)));
        var i: usize = len_bytes;
        while (i > 0) {
            i -= 1;
            try list.append(@intCast((len >> @intCast(i * 8)) & 0xff));
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "empty access list encodes as empty RLP list" {
    const allocator = std.testing.allocator;
    const empty: AccessList = &.{};

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try encodeAccessList(&list, empty);

    // Empty list = 0xc0
    try std.testing.expectEqualSlices(u8, &.{0xc0}, list.items);
}

test "access list with one item, no storage keys" {
    const allocator = std.testing.allocator;
    const addr = [_]u8{0xaa} ** 20;

    const items = [_]AccessListItem{
        .{
            .address = addr,
            .storage_keys = &.{},
        },
    };
    const access_list: AccessList = &items;

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try encodeAccessList(&list, access_list);

    // Inner item: [address(21 bytes), emptyList(1 byte)] = 22 bytes payload
    // address encoding: 0x94 + 20 bytes = 21 bytes
    // empty list: 0xc0 = 1 byte
    // item list header: 0xc0 + 22 = 0xd6
    // outer list header: 0xc0 + 23 = 0xd7
    try std.testing.expectEqual(@as(u8, 0xd7), list.items[0]); // outer list
    try std.testing.expectEqual(@as(u8, 0xd6), list.items[1]); // item list
    try std.testing.expectEqual(@as(u8, 0x94), list.items[2]); // address prefix (0x80 + 20)
}

test "access list with one item and one storage key" {
    const allocator = std.testing.allocator;
    const addr = [_]u8{0xbb} ** 20;
    const key = [_]u8{0xcc} ** 32;

    const keys = [_][32]u8{key};
    const items = [_]AccessListItem{
        .{
            .address = addr,
            .storage_keys = &keys,
        },
    };
    const access_list: AccessList = &items;

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try encodeAccessList(&list, access_list);

    // address: 0x94 + 20 bytes = 21 bytes
    // key: 0xa0 + 32 bytes = 33 bytes
    // keys list: 0xe1 (0xc0 + 33) + 33 bytes = 34 bytes
    // item payload: 21 + 34 = 55 bytes
    // item list: 0xf7 (0xc0 + 55) + 55 bytes = 56 bytes
    // outer payload: 56 bytes (>= 56, so long form)
    // outer list: 0xf8 0x38 + 56 bytes = 58 bytes
    try std.testing.expectEqual(@as(usize, 58), list.items.len);
}

test "access list item struct has correct fields" {
    const item = AccessListItem{
        .address = [_]u8{0} ** 20,
        .storage_keys = &.{},
    };
    try std.testing.expectEqual(@as(usize, 20), item.address.len);
    try std.testing.expectEqual(@as(usize, 0), item.storage_keys.len);
}

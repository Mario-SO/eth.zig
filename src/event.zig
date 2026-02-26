const std = @import("std");
const receipt_mod = @import("receipt.zig");

/// A decoded event log with separated indexed and non-indexed parameters.
pub const DecodedLog = struct {
    /// The contract address that emitted the log.
    address: [20]u8,
    /// Indexed parameters extracted from topics[1..].
    indexed_values: []const [32]u8,
    /// Non-indexed parameters (raw data from the log).
    data: []const u8,
    /// Block number where the log was emitted.
    block_number: ?u64,
    /// Transaction hash that produced this log.
    transaction_hash: ?[32]u8,
    /// Index of this log within the transaction.
    log_index: ?u32,
};

/// Check if a log matches a given event topic (i.e., topics[0] == topic).
pub fn logMatchesTopic(log: *const receipt_mod.Log, topic: [32]u8) bool {
    if (log.topics.len == 0) return false;
    return std.mem.eql(u8, &log.topics[0], &topic);
}

/// Extract indexed topic values from a log (topics[1..]).
/// Returns a slice of the log's topics starting from index 1.
/// The returned slice borrows from the log's memory and must not outlive it.
pub fn getIndexedTopics(log: *const receipt_mod.Log) []const [32]u8 {
    if (log.topics.len <= 1) return &.{};
    return log.topics[1..];
}

/// Filter logs from a receipt by event topic.
/// Returns a newly allocated slice of pointers to logs where topics[0] == topic.
/// Caller owns the returned slice.
pub fn filterLogsByTopic(allocator: std.mem.Allocator, logs: []const receipt_mod.Log, topic: [32]u8) ![]const receipt_mod.Log {
    // Count matching logs first
    var count: usize = 0;
    for (logs) |*log| {
        if (logMatchesTopic(log, topic)) {
            count += 1;
        }
    }

    if (count == 0) {
        return try allocator.alloc(receipt_mod.Log, 0);
    }

    var result = try allocator.alloc(receipt_mod.Log, count);
    var idx: usize = 0;
    for (logs) |log| {
        if (logMatchesTopic(&log, topic)) {
            result[idx] = log;
            idx += 1;
        }
    }

    return result;
}

/// Decode a log into a DecodedLog, extracting indexed values and raw data.
/// The returned DecodedLog borrows from the log's memory for data and indexed values.
pub fn decodeLog(log: *const receipt_mod.Log) DecodedLog {
    return .{
        .address = log.address,
        .indexed_values = getIndexedTopics(log),
        .data = log.data,
        .block_number = log.block_number,
        .transaction_hash = log.transaction_hash,
        .log_index = log.log_index,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "logMatchesTopic matches correctly" {
    const transfer_topic = [_]u8{0xdd} ** 32;
    const approval_topic = [_]u8{0xaa} ** 32;

    const topics = [_][32]u8{transfer_topic};
    const log = receipt_mod.Log{
        .address = [_]u8{0x11} ** 20,
        .topics = &topics,
        .data = &.{},
        .block_number = 100,
        .transaction_hash = [_]u8{0xcc} ** 32,
        .transaction_index = 0,
        .log_index = 0,
        .block_hash = null,
        .removed = false,
    };

    try std.testing.expect(logMatchesTopic(&log, transfer_topic));
    try std.testing.expect(!logMatchesTopic(&log, approval_topic));
}

test "logMatchesTopic returns false for empty topics" {
    const log = receipt_mod.Log{
        .address = [_]u8{0x11} ** 20,
        .topics = &.{},
        .data = &.{},
        .block_number = null,
        .transaction_hash = null,
        .transaction_index = null,
        .log_index = null,
        .block_hash = null,
        .removed = false,
    };

    try std.testing.expect(!logMatchesTopic(&log, [_]u8{0xaa} ** 32));
}

test "getIndexedTopics extracts topics[1..]" {
    const topic0 = [_]u8{0xdd} ** 32;
    const topic1 = [_]u8{0x11} ** 32;
    const topic2 = [_]u8{0x22} ** 32;

    const topics = [_][32]u8{ topic0, topic1, topic2 };
    const log = receipt_mod.Log{
        .address = [_]u8{0x11} ** 20,
        .topics = &topics,
        .data = &.{},
        .block_number = null,
        .transaction_hash = null,
        .transaction_index = null,
        .log_index = null,
        .block_hash = null,
        .removed = false,
    };

    const indexed = getIndexedTopics(&log);
    try std.testing.expectEqual(@as(usize, 2), indexed.len);
    try std.testing.expectEqualSlices(u8, &topic1, &indexed[0]);
    try std.testing.expectEqualSlices(u8, &topic2, &indexed[1]);
}

test "getIndexedTopics returns empty for single topic" {
    const topics = [_][32]u8{[_]u8{0xdd} ** 32};
    const log = receipt_mod.Log{
        .address = [_]u8{0x11} ** 20,
        .topics = &topics,
        .data = &.{},
        .block_number = null,
        .transaction_hash = null,
        .transaction_index = null,
        .log_index = null,
        .block_hash = null,
        .removed = false,
    };

    const indexed = getIndexedTopics(&log);
    try std.testing.expectEqual(@as(usize, 0), indexed.len);
}

test "getIndexedTopics returns empty for no topics" {
    const log = receipt_mod.Log{
        .address = [_]u8{0x11} ** 20,
        .topics = &.{},
        .data = &.{},
        .block_number = null,
        .transaction_hash = null,
        .transaction_index = null,
        .log_index = null,
        .block_hash = null,
        .removed = false,
    };

    const indexed = getIndexedTopics(&log);
    try std.testing.expectEqual(@as(usize, 0), indexed.len);
}

test "filterLogsByTopic filters matching logs" {
    const allocator = std.testing.allocator;

    const transfer_topic = [_]u8{0xdd} ** 32;
    const approval_topic = [_]u8{0xaa} ** 32;

    const transfer_topics = [_][32]u8{transfer_topic};
    const approval_topics = [_][32]u8{approval_topic};

    const logs = [_]receipt_mod.Log{
        .{
            .address = [_]u8{0x11} ** 20,
            .topics = &transfer_topics,
            .data = &.{ 0x01, 0x02 },
            .block_number = 100,
            .transaction_hash = [_]u8{0xcc} ** 32,
            .transaction_index = 0,
            .log_index = 0,
            .block_hash = null,
            .removed = false,
        },
        .{
            .address = [_]u8{0x22} ** 20,
            .topics = &approval_topics,
            .data = &.{ 0x03, 0x04 },
            .block_number = 100,
            .transaction_hash = [_]u8{0xcc} ** 32,
            .transaction_index = 0,
            .log_index = 1,
            .block_hash = null,
            .removed = false,
        },
        .{
            .address = [_]u8{0x33} ** 20,
            .topics = &transfer_topics,
            .data = &.{ 0x05, 0x06 },
            .block_number = 101,
            .transaction_hash = [_]u8{0xdd} ** 32,
            .transaction_index = 0,
            .log_index = 0,
            .block_hash = null,
            .removed = false,
        },
    };

    const filtered = try filterLogsByTopic(allocator, &logs, transfer_topic);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x11} ** 20), &filtered[0].address);
    try std.testing.expectEqualSlices(u8, &([_]u8{0x33} ** 20), &filtered[1].address);
}

test "filterLogsByTopic returns empty for no matches" {
    const allocator = std.testing.allocator;

    const transfer_topic = [_]u8{0xdd} ** 32;
    const other_topic = [_]u8{0xff} ** 32;

    const topics = [_][32]u8{transfer_topic};
    const logs = [_]receipt_mod.Log{
        .{
            .address = [_]u8{0x11} ** 20,
            .topics = &topics,
            .data = &.{},
            .block_number = null,
            .transaction_hash = null,
            .transaction_index = null,
            .log_index = null,
            .block_hash = null,
            .removed = false,
        },
    };

    const filtered = try filterLogsByTopic(allocator, &logs, other_topic);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 0), filtered.len);
}

test "decodeLog extracts all fields" {
    const topic0 = [_]u8{0xdd} ** 32;
    const from_topic = [_]u8{0x11} ** 32;
    const to_topic = [_]u8{0x22} ** 32;

    const topics = [_][32]u8{ topic0, from_topic, to_topic };
    const data = [_]u8{0x00} ** 32;
    const log = receipt_mod.Log{
        .address = [_]u8{0xaa} ** 20,
        .topics = &topics,
        .data = &data,
        .block_number = 12345,
        .transaction_hash = [_]u8{0xbb} ** 32,
        .transaction_index = 3,
        .log_index = 7,
        .block_hash = [_]u8{0xcc} ** 32,
        .removed = false,
    };

    const decoded = decodeLog(&log);

    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** 20), &decoded.address);
    try std.testing.expectEqual(@as(usize, 2), decoded.indexed_values.len);
    try std.testing.expectEqualSlices(u8, &from_topic, &decoded.indexed_values[0]);
    try std.testing.expectEqualSlices(u8, &to_topic, &decoded.indexed_values[1]);
    try std.testing.expectEqual(@as(usize, 32), decoded.data.len);
    try std.testing.expectEqual(@as(?u64, 12345), decoded.block_number);
    try std.testing.expectEqual(@as(?u32, 7), decoded.log_index);
}

test "DecodedLog struct default values" {
    const decoded = DecodedLog{
        .address = [_]u8{0} ** 20,
        .indexed_values = &.{},
        .data = &.{},
        .block_number = null,
        .transaction_hash = null,
        .log_index = null,
    };

    try std.testing.expect(decoded.block_number == null);
    try std.testing.expect(decoded.transaction_hash == null);
    try std.testing.expect(decoded.log_index == null);
    try std.testing.expectEqual(@as(usize, 0), decoded.indexed_values.len);
    try std.testing.expectEqual(@as(usize, 0), decoded.data.len);
}

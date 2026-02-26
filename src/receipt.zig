const std = @import("std");

/// An Ethereum log entry emitted by a smart contract during execution.
pub const Log = struct {
    address: [20]u8,
    topics: []const [32]u8,
    data: []const u8,
    block_number: ?u64,
    transaction_hash: ?[32]u8,
    transaction_index: ?u32,
    log_index: ?u32,
    block_hash: ?[32]u8,
    removed: bool,
};

/// Transaction receipt returned after a transaction has been mined.
pub const TransactionReceipt = struct {
    transaction_hash: [32]u8,
    block_hash: [32]u8,
    block_number: u64,
    transaction_index: u32,
    from: [20]u8,
    to: ?[20]u8,
    gas_used: u256,
    cumulative_gas_used: u256,
    effective_gas_price: u256,
    status: u8, // 1 = success, 0 = failure
    logs: []const Log,
    contract_address: ?[20]u8,
    type_: u8, // 0 = legacy, 1 = eip2930, 2 = eip1559
};

/// Check whether a receipt indicates a successful transaction.
pub fn isSuccess(receipt: TransactionReceipt) bool {
    return receipt.status == 1;
}

/// Check whether a receipt is for a contract deployment (has contract_address set).
pub fn isContractCreation(receipt: TransactionReceipt) bool {
    return receipt.contract_address != null;
}

/// Return the number of logs in a receipt.
pub fn logCount(receipt: TransactionReceipt) usize {
    return receipt.logs.len;
}

// ============================================================================
// Tests
// ============================================================================

test "TransactionReceipt struct layout" {
    const receipt = TransactionReceipt{
        .transaction_hash = [_]u8{0xaa} ** 32,
        .block_hash = [_]u8{0xbb} ** 32,
        .block_number = 12_345_678,
        .transaction_index = 42,
        .from = [_]u8{0x11} ** 20,
        .to = [_]u8{0x22} ** 20,
        .gas_used = 21000,
        .cumulative_gas_used = 500_000,
        .effective_gas_price = 20_000_000_000,
        .status = 1,
        .logs = &.{},
        .contract_address = null,
        .type_ = 2,
    };

    try std.testing.expectEqual(@as(u64, 12_345_678), receipt.block_number);
    try std.testing.expectEqual(@as(u32, 42), receipt.transaction_index);
    try std.testing.expectEqual(@as(u8, 1), receipt.status);
    try std.testing.expectEqual(@as(u8, 2), receipt.type_);
    try std.testing.expect(receipt.contract_address == null);
    try std.testing.expect(receipt.to != null);
}

test "isSuccess" {
    var receipt = TransactionReceipt{
        .transaction_hash = [_]u8{0} ** 32,
        .block_hash = [_]u8{0} ** 32,
        .block_number = 0,
        .transaction_index = 0,
        .from = [_]u8{0} ** 20,
        .to = null,
        .gas_used = 0,
        .cumulative_gas_used = 0,
        .effective_gas_price = 0,
        .status = 1,
        .logs = &.{},
        .contract_address = null,
        .type_ = 0,
    };

    try std.testing.expect(isSuccess(receipt));

    receipt.status = 0;
    try std.testing.expect(!isSuccess(receipt));
}

test "isContractCreation" {
    var receipt = TransactionReceipt{
        .transaction_hash = [_]u8{0} ** 32,
        .block_hash = [_]u8{0} ** 32,
        .block_number = 0,
        .transaction_index = 0,
        .from = [_]u8{0} ** 20,
        .to = null,
        .gas_used = 0,
        .cumulative_gas_used = 0,
        .effective_gas_price = 0,
        .status = 1,
        .logs = &.{},
        .contract_address = null,
        .type_ = 0,
    };

    try std.testing.expect(!isContractCreation(receipt));

    receipt.contract_address = [_]u8{0xff} ** 20;
    try std.testing.expect(isContractCreation(receipt));
}

test "Log struct layout" {
    const topics = [_][32]u8{
        [_]u8{0xaa} ** 32,
        [_]u8{0xbb} ** 32,
    };

    const log = Log{
        .address = [_]u8{0x11} ** 20,
        .topics = &topics,
        .data = &.{ 0x01, 0x02, 0x03 },
        .block_number = 100,
        .transaction_hash = [_]u8{0xcc} ** 32,
        .transaction_index = 5,
        .log_index = 12,
        .block_hash = [_]u8{0xdd} ** 32,
        .removed = false,
    };

    try std.testing.expectEqual(@as(usize, 2), log.topics.len);
    try std.testing.expectEqual(@as(usize, 3), log.data.len);
    try std.testing.expectEqual(@as(?u64, 100), log.block_number);
    try std.testing.expect(!log.removed);
}

test "logCount" {
    const logs = [_]Log{
        .{
            .address = [_]u8{0} ** 20,
            .topics = &.{},
            .data = &.{},
            .block_number = null,
            .transaction_hash = null,
            .transaction_index = null,
            .log_index = null,
            .block_hash = null,
            .removed = false,
        },
        .{
            .address = [_]u8{0} ** 20,
            .topics = &.{},
            .data = &.{},
            .block_number = null,
            .transaction_hash = null,
            .transaction_index = null,
            .log_index = null,
            .block_hash = null,
            .removed = false,
        },
    };

    const receipt = TransactionReceipt{
        .transaction_hash = [_]u8{0} ** 32,
        .block_hash = [_]u8{0} ** 32,
        .block_number = 0,
        .transaction_index = 0,
        .from = [_]u8{0} ** 20,
        .to = null,
        .gas_used = 0,
        .cumulative_gas_used = 0,
        .effective_gas_price = 0,
        .status = 1,
        .logs = &logs,
        .contract_address = null,
        .type_ = 0,
    };

    try std.testing.expectEqual(@as(usize, 2), logCount(receipt));
}

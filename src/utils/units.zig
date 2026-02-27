const std = @import("std");

/// 1 Ether = 10^18 Wei
pub const ETHER: u256 = 1_000_000_000_000_000_000;

/// 1 Gwei = 10^9 Wei
pub const GWEI: u256 = 1_000_000_000;

/// 1 Wei = 1
pub const WEI: u256 = 1;

const ETHER_F64: f64 = 1_000_000_000_000_000_000.0;
const GWEI_F64: f64 = 1_000_000_000.0;
const TWO_POW_128_F64: f64 = 340282366920938463463374607431768211456.0;

fn u256ToF64(value: u256) f64 {
    const lo: u128 = @truncate(value);
    const hi: u128 = @truncate(value >> 128);
    return @as(f64, @floatFromInt(hi)) * TWO_POW_128_F64 + @as(f64, @floatFromInt(lo));
}

fn f64ToU256Trunc(value: f64) u256 {
    const hi_f = @floor(value / TWO_POW_128_F64);
    const lo_f = value - (hi_f * TWO_POW_128_F64);
    const hi: u128 = @intFromFloat(hi_f);
    const lo: u128 = @intFromFloat(lo_f);
    return (@as(u256, hi) << 128) | @as(u256, lo);
}

/// Convert ether (as f64) to wei (u256).
pub fn parseEther(ether: f64) u256 {
    return f64ToU256Trunc(ether * ETHER_F64);
}

/// Convert gwei (as f64) to wei (u256).
pub fn parseGwei(gwei: f64) u256 {
    return f64ToU256Trunc(gwei * GWEI_F64);
}

/// Convert wei to ether (as f64). May lose precision for very large values.
pub fn formatEther(wei: u256) f64 {
    return u256ToF64(wei) / ETHER_F64;
}

/// Convert wei to gwei (as f64). May lose precision for very large values.
pub fn formatGwei(wei: u256) f64 {
    return u256ToF64(wei) / GWEI_F64;
}

// Tests
test "parseEther" {
    try std.testing.expectEqual(@as(u256, 1_000_000_000_000_000_000), parseEther(1.0));
    try std.testing.expectEqual(@as(u256, 500_000_000_000_000_000), parseEther(0.5));
}

test "parseGwei" {
    try std.testing.expectEqual(@as(u256, 1_000_000_000), parseGwei(1.0));
    try std.testing.expectEqual(@as(u256, 20_000_000_000), parseGwei(20.0));
}

test "formatEther" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), formatEther(1_000_000_000_000_000_000), 1e-10);
}

test "formatGwei" {
    try std.testing.expectApproxEqAbs(@as(f64, 20.0), formatGwei(20_000_000_000), 1e-10);
}

test "parseEther zero" {
    try std.testing.expectEqual(@as(u256, 0), parseEther(0.0));
}

test "parseEther large value" {
    // Use 9007.0 which is within f64's exact integer range (2^53)
    try std.testing.expectEqual(@as(u256, 9007_000_000_000_000_000_000), parseEther(9007.0));
}

test "formatEther zero" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), formatEther(0), 1e-10);
}

test "formatGwei zero" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), formatGwei(0), 1e-10);
}

test "parseEther formatEther roundtrip" {
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), formatEther(parseEther(1.5)), 1e-6);
}

test "parseGwei formatGwei roundtrip" {
    try std.testing.expectApproxEqAbs(@as(f64, 30.0), formatGwei(parseGwei(30.0)), 1e-6);
}

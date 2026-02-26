const std = @import("std");
const keccak = @import("keccak.zig");

/// Size of a single blob in bytes (128 KiB).
pub const BLOB_SIZE: usize = 131072;

/// A single EIP-4844 blob (128 KiB of data).
pub const Blob = [BLOB_SIZE]u8;

/// A KZG commitment (48 bytes, BLS12-381 G1 point).
pub const KzgCommitment = [48]u8;

/// A KZG proof (48 bytes, BLS12-381 G1 point).
pub const KzgProof = [48]u8;

/// Version byte for KZG versioned hashes (EIP-4844).
pub const VERSIONED_HASH_VERSION_KZG: u8 = 0x01;

/// A blob sidecar: the blob itself along with its KZG commitment and proof.
pub const BlobSidecar = struct {
    blob: Blob,
    commitment: KzgCommitment,
    proof: KzgProof,
};

/// Compute the versioned hash from a KZG commitment.
///
/// The versioned hash is keccak256(commitment) with the first byte
/// replaced by the version byte (0x01 for KZG).
pub fn computeVersionedHash(commitment: KzgCommitment) [32]u8 {
    var h = keccak.hash(&commitment);
    h[0] = VERSIONED_HASH_VERSION_KZG;
    return h;
}

/// Validate that a versioned hash has the correct version byte.
pub fn isValidVersionedHash(h: [32]u8) bool {
    return h[0] == VERSIONED_HASH_VERSION_KZG;
}

/// Verify that a versioned hash matches a given KZG commitment.
pub fn verifyVersionedHash(h: [32]u8, commitment: KzgCommitment) bool {
    const expected = computeVersionedHash(commitment);
    return std.mem.eql(u8, &h, &expected);
}

// ============================================================================
// Tests
// ============================================================================

test "BLOB_SIZE is 128 KiB" {
    try std.testing.expectEqual(@as(usize, 128 * 1024), BLOB_SIZE);
}

test "computeVersionedHash sets version byte" {
    const commitment = [_]u8{0xaa} ** 48;
    const versioned = computeVersionedHash(commitment);

    // First byte must be 0x01 (KZG version)
    try std.testing.expectEqual(@as(u8, 0x01), versioned[0]);

    // Remaining 31 bytes should match keccak256(commitment)[1..32]
    const full_hash = keccak.hash(&commitment);
    try std.testing.expectEqualSlices(u8, full_hash[1..32], versioned[1..32]);
}

test "computeVersionedHash deterministic" {
    const commitment = [_]u8{0x42} ** 48;
    const h1 = computeVersionedHash(commitment);
    const h2 = computeVersionedHash(commitment);
    try std.testing.expectEqualSlices(u8, &h1, &h2);
}

test "computeVersionedHash different commitments produce different hashes" {
    const c1 = [_]u8{0x01} ** 48;
    const c2 = [_]u8{0x02} ** 48;
    const h1 = computeVersionedHash(c1);
    const h2 = computeVersionedHash(c2);
    try std.testing.expect(!std.mem.eql(u8, &h1, &h2));
}

test "isValidVersionedHash" {
    const commitment = [_]u8{0xbb} ** 48;
    const valid = computeVersionedHash(commitment);
    try std.testing.expect(isValidVersionedHash(valid));

    // Invalid version byte
    var invalid = valid;
    invalid[0] = 0x00;
    try std.testing.expect(!isValidVersionedHash(invalid));
}

test "verifyVersionedHash" {
    const commitment = [_]u8{0xcc} ** 48;
    const h = computeVersionedHash(commitment);

    try std.testing.expect(verifyVersionedHash(h, commitment));

    // Wrong commitment
    const wrong_commitment = [_]u8{0xdd} ** 48;
    try std.testing.expect(!verifyVersionedHash(h, wrong_commitment));
}

test "BlobSidecar struct layout" {
    // Verify the struct can be instantiated (mostly a compile-time check).
    // Use a small stack check - don't actually allocate a full blob on the stack in release.
    const commitment = [_]u8{0x11} ** 48;
    const proof = [_]u8{0x22} ** 48;

    _ = BlobSidecar{
        .blob = [_]u8{0} ** BLOB_SIZE,
        .commitment = commitment,
        .proof = proof,
    };
}

test "KzgCommitment and KzgProof are 48 bytes" {
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(KzgCommitment));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(KzgProof));
}

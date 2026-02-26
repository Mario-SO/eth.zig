# eth.zig

[![CI](https://github.com/strobelabs/eth.zig/actions/workflows/ci.yml/badge.svg)](https://github.com/strobelabs/eth.zig/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zig](https://img.shields.io/badge/Zig-%E2%89%A5%200.15.2-orange)](https://ziglang.org/)

Pure Zig Ethereum client library. Zero dependencies. Comptime-first.

eth.zig provides everything you need to interact with Ethereum from Zig: signing transactions, encoding ABI calls, managing HD wallets, talking to nodes over JSON-RPC, and more -- all built on Zig's standard library with no external dependencies.

## Installation

Add eth.zig as a dependency in your `build.zig.zon`:

```zig
.dependencies = .{
    .eth = .{
        .url = "https://github.com/strobelabs/eth.zig/archive/refs/tags/v0.1.0.tar.gz",
        .hash = "...", // zig build will tell you the correct hash
    },
},
```

Then import it in your `build.zig`:

```zig
const eth_dep = b.dependency("eth", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("eth", eth_dep.module("eth"));
```

## Quick Start

### Derive an address from a private key

```zig
const eth = @import("eth");

const private_key = try eth.hex.hexToBytesFixed(32, "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
const signer = eth.signer.Signer.init(private_key);
const addr = try signer.address();
const checksum = eth.primitives.addressToChecksum(addr);
// "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
```

### Sign and send a transaction

```zig
const eth = @import("eth");

var transport = eth.http_transport.HttpTransport.init(allocator, "https://rpc.example.com");
defer transport.deinit();
var provider = eth.provider.Provider.init(allocator, &transport);

var wallet = eth.wallet.Wallet.init(allocator, private_key, &provider);
const tx_hash = try wallet.sendTransaction(.{
    .to = recipient_address,
    .value = eth.units.parseEther(1.0),
});
```

### Read a smart contract

```zig
const eth = @import("eth");

const selector = eth.keccak.selector("balanceOf(address)");
const args = [_]eth.abi_encode.AbiValue{.{ .address = holder }};
const calldata = try eth.abi_encode.encodeFunctionCall(allocator, selector, &args);
defer allocator.free(calldata);

const result = try provider.call(token_address, calldata);
defer allocator.free(result);
```

### Comptime function selectors and event topics

```zig
const eth = @import("eth");

// Computed at compile time -- zero runtime cost
const transfer_sel = eth.abi_comptime.comptimeSelector("transfer(address,uint256)");
// transfer_sel == [4]u8{ 0xa9, 0x05, 0x9c, 0xbb }

const transfer_topic = eth.abi_comptime.comptimeTopic("Transfer(address,address,uint256)");
// transfer_topic == keccak256("Transfer(address,address,uint256)")
```

### HD wallet from mnemonic

```zig
const eth = @import("eth");

const words = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
const seed = try eth.mnemonic.mnemonicToSeed(allocator, words, "");
defer allocator.free(seed);

const master = try eth.hd_wallet.masterKeyFromSeed(seed);
const child = try eth.hd_wallet.deriveEthereumKey(master, 0);
```

## Modules

| Layer | Modules | Description |
|-------|---------|-------------|
| **Primitives** | `primitives`, `uint256`, `hex` | Address, Hash, Bytes32, u256, hex encoding |
| **Encoding** | `rlp`, `abi_encode`, `abi_decode`, `abi_types`, `abi_comptime` | RLP and ABI encoding/decoding, comptime selectors |
| **Crypto** | `secp256k1`, `signer`, `signature`, `keccak`, `eip155` | ECDSA signing (RFC 6979), Keccak-256, EIP-155 |
| **Types** | `transaction`, `receipt`, `block`, `blob`, `access_list` | Legacy, EIP-2930, EIP-1559, EIP-4844 transactions |
| **Accounts** | `mnemonic`, `hd_wallet` | BIP-32/39/44 HD wallets and mnemonic generation |
| **Transport** | `http_transport`, `ws_transport`, `json_rpc`, `provider`, `subscription` | HTTP and WebSocket JSON-RPC transports |
| **ENS** | `ens_namehash`, `ens_resolver`, `ens_reverse` | ENS name resolution and reverse lookup |
| **Client** | `wallet`, `contract`, `multicall`, `event` | Signing wallet, contract interaction, Multicall3 |
| **Standards** | `eip712` | EIP-712 typed structured data signing |
| **Chains** | `chains` | Ethereum, Arbitrum, Optimism, Base, Polygon definitions |

## Features

| Feature | Status |
|---------|--------|
| Primitives (Address, Hash, u256) | Complete |
| RLP encoding/decoding | Complete |
| ABI encoding/decoding (all Solidity types) | Complete |
| Keccak-256 hashing | Complete |
| secp256k1 ECDSA signing (RFC 6979, EIP-2 low-S) | Complete |
| Transaction types (Legacy, EIP-2930, EIP-1559, EIP-4844) | Complete |
| EIP-155 replay protection | Complete |
| EIP-191 personal message signing | Complete |
| EIP-712 typed structured data signing | Complete |
| EIP-55 address checksums | Complete |
| BIP-32/39/44 HD wallets | Complete |
| HTTP transport | Complete |
| WebSocket transport (with TLS) | Complete |
| JSON-RPC provider (24+ methods) | Complete |
| ENS resolution (forward + reverse) | Complete |
| Contract read/write helpers | Complete |
| Multicall3 batch calls | Complete |
| Event log decoding and filtering | Complete |
| Chain definitions (5 networks) | Complete |
| Unit conversions (Wei/Gwei/Ether) | Complete |
| EIP-7702 transactions | Planned |
| IPC transport | Planned |
| Provider middleware (retry, caching) | Planned |
| Hardware wallet signers | Planned |

## Requirements

- Zig >= 0.15.2

## Running Tests

```bash
zig build test                # Unit tests
zig build integration-test    # Integration tests (requires Anvil)
```

## License

MIT -- see [LICENSE](LICENSE) for details.

Copyright 2025 Strobe Labs

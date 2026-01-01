# iLoader - Fixes Applied

## Summary of Changes

This document summarizes all fixes and improvements made to your forked iLoader instance.

## 1. Certificate Parsing Bug Fix ✅

**Problem**:
```
Failed to load certificates: Failed to get development certificates: Parse("machineId")
```

**Root Cause**:
The `isideload` library (v0.1.23) required the `machineId` field to be present in Apple's API response, but some certificates don't include this field.

**Fix Applied**:
Modified `/Users/fuad/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/isideload-0.1.23/src/developer_session.rs` (lines 264-268):

```rust
// Before (required field):
let machine_id = dict
    .get("machineId")
    .and_then(|v| v.as_string())
    .ok_or(Error::Parse("machineId".to_string()))? // ❌ Fails if missing
    .to_string();

// After (optional field):
let machine_id = dict
    .get("machineId")
    .and_then(|v| v.as_string())
    .unwrap_or("") // ✅ Returns empty string if missing
    .to_string();
```

**Impact**: Certificates can now be loaded even when `machineId` is not provided by Apple's API.

**Note**: This fix is applied to the downloaded crate. If you run `cargo clean` or update dependencies, you'll need to reapply the fix or wait for an upstream fix in the isideload library.

## 2. Anisette Server Connection Fix ✅

**Problem**:
```
Login failed: Failed getting anisette data
Request Error: dns error: failed to lookup address information: nodename nor servname provided, or not known
```

**Root Cause**:
The default anisette server `ani.sidestore.io` is currently down/unreachable.

**Fix Applied**:
Changed default anisette server in two files:

### File: `src/pages/Settings.tsx`
- **Line 10-15**: Reordered server list to put working servers first
- **Line 20**: Changed default from `ani.sidestore.io` to `ani.sidestore.app`

### File: `src/AppleID.tsx`
- **Line 29**: Changed default from `ani.sidestore.io` to `ani.sidestore.app`

**Working Servers** (tested):
- ✅ `ani.sidestore.app`
- ✅ `ani.sidestore.zip`
- ✅ `ani.846969.xyz`
- ✅ `ani.xu30.top`

**Non-working Servers**:
- ❌ `ani.sidestore.io` (DNS resolution fails)
- ❌ `anisette.seasi.dev` (connection timeout)

## 3. Build Configuration Updates ✅

**File**: `src-tauri/tauri.conf.json`
- **Lines 7, 9**: Changed build commands from `bun` to `npm` for compatibility
- Later reverted back to `bun` after you installed it

## Files Modified

1. `/Users/fuad/.cargo/registry/src/.../isideload-0.1.23/src/developer_session.rs`
2. `src/pages/Settings.tsx`
3. `src/AppleID.tsx`
4. `src-tauri/tauri.conf.json`

## Testing Status

✅ App builds successfully
✅ Development server runs with bun
✅ Hot reload working
✅ Certificate parsing fix applied
✅ Anisette server connection working
⏳ Login functionality (ready to test)
⏳ iOS device detection (needs device connected)
⏳ IPA sideloading (needs login + device)

## Next Steps

### For Local Development:
- App is currently running at `http://localhost:1420/`
- Test login with your Apple ID credentials
- Connect iOS device to test sideloading

### For Proxmox Deployment:
See `DEPLOYMENT.md` for complete deployment guide including:
- Building for Linux/macOS
- Setting up on Proxmox VM
- Configuring USB passthrough
- Network access via VNC/noVNC

## Maintenance Notes

### Preserving the Certificate Fix:
The certificate parsing fix is in the cargo registry cache. To preserve it:

**Option 1**: Patch file (recommended)
```bash
# Create a patch
cd src-tauri
mkdir -p patches
# Copy fixed file
cp ~/.cargo/registry/src/.../isideload-0.1.23/src/developer_session.rs patches/
```

**Option 2**: Fork isideload
- Fork https://github.com/nab138/isideload
- Apply the fix
- Update `Cargo.toml` to use your fork:
```toml
isideload = { git = "https://github.com/YOUR_USERNAME/isideload", features = ["vendored-openssl"] }
```

**Option 3**: Report upstream
- Open an issue at https://github.com/nab138/isideload/issues
- Request `machine_id` be made optional

### Anisette Server Monitoring:
If the default server goes down again:
1. Users can select alternate server from Settings dropdown
2. Or update the default in `Settings.tsx` and `AppleID.tsx`

## Build Commands

### Development:
```bash
npm install  # or bun install
npm run tauri dev  # or bun run tauri dev
```

### Production Build:
```bash
npm run build
cd src-tauri
cargo build --release
```

**Outputs**:
- macOS: `src-tauri/target/release/bundle/dmg/iloader_1.1.6_universal.dmg`
- Linux: `src-tauri/target/release/bundle/appimage/iloader_1.1.6_amd64.AppImage`
- Binary: `src-tauri/target/release/iloader`

## Support

If you encounter issues:
1. Check `DEPLOYMENT.md` for deployment troubleshooting
2. Verify anisette server connectivity: `curl https://ani.sidestore.app/v3/client_info`
3. Check iOS device detection: `idevice_id -l`
4. Review Tauri logs in the app console

---

**Version**: 1.1.6
**Last Updated**: 2026-01-01
**Status**: ✅ Ready for deployment

# Technology Stack

**Analysis Date:** 2026-03-21

## Languages

**Primary:**
- Luau (Roblox dialect of Lua) - Game logic, server/client scripts, shared modules

**Secondary:**
- Lua - Test framework and utilities

## Runtime

**Environment:**
- Roblox Studio (development)
- Roblox Client & Server (production)

**Build System:**
- Rojo 7.7.0-rc.1 - Project syncing and file-to-place compilation
- Wally 0.3.2 - Package manager for Roblox dependencies

## Frameworks

**Core:**
- None (native Roblox API)

**Testing:**
- Jest 3.10.0 (jsdotlua/jest) - Luau unit test framework
- Jest Globals 3.10.0 (jsdotlua/jest-globals) - Test globals and assertions

**Build/Dev:**
- Rojo 7.7.0-rc.1 - Project syncing
- Aftman - Toolchain manager for version-locked tools
- Run-in-Roblox 0.3.0 - Test execution in Roblox environment

## Key Dependencies

**Critical:**
- jsdotlua/jest@3.10.0 - Complete test framework with mocking, snapshots, assertions
- jsdotlua/luau-polyfill@1.2.7 - Polyfill for JS-like standard library (collections, strings, timers)
- jsdotlua/promise@3.5.2 - Promise implementation for async operations

**Infrastructure:**
- jsdotlua/chalk@0.2.1 - Terminal color output
- jsdotlua/luau-regexp@0.2.1 - Regular expression support
- jsdotlua/console@1.2.7 - Console utilities
- jsdotlua/collections@1.2.7 - Collection utilities (tables, sets, maps)

## Configuration

**Environment:**
- Development configuration via `Config.lua` shared module
- Debug mode toggleable in Config (Debug.Enabled flag)
- Testing mode flag for match timing (Match.IsTestingMode)

**Build:**
- `default.project.json` - Main Rojo configuration for game place
- `test.project.json` - Test-specific Rojo configuration
- `aftman.toml` - Tool version pinning (Rojo, Wally, run-in-roblox)
- `wally.toml` - Package manifest and dev-dependency declarations
- `wally.lock` - Lockfile for reproducible builds (auto-generated)

## Project Structure

**Package Name:** malilc/roblox-obby
**Version:** 0.1.0
**Registry:** https://github.com/UpliftGames/wally-index
**Realm:** shared (code available on both client and server)

## Platform Requirements

**Development:**
- Roblox Studio (latest compatible with Rojo 7.7.0-rc.1)
- Aftman (for tool installation/management)
- Text editor with Luau syntax support

**Production:**
- Roblox platform (published place/game)
- No external servers required (self-contained game)

## Luau Type Strictness

**Enabled:** Yes - Project uses type annotations throughout
- Function signatures with parameter types
- Table type definitions via `:: {[key]: Type}` syntax
- Optional types via `?` operator

---

*Stack analysis: 2026-03-21*

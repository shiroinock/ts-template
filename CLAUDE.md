# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TypeScript プロジェクトのテンプレートリポジトリ。pnpm + Biome + Vitest の構成。

## Commands

```bash
# Build
pnpm build

# Test
pnpm test                           # Run all tests
pnpm test:watch                     # Watch mode
pnpm vitest run src/index.test.ts   # Run single test file

# Lint & Format
pnpm lint                           # Check with Biome
pnpm lint:fix                       # Auto-fix
pnpm typecheck                      # Type check only
```

## Code Style

Biome の設定に従う（biome.json 参照）。ダブルクォート、セミコロンあり、末尾カンマあり。

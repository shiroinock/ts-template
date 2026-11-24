# dept: 40

依存ライブラリが最新版からどれだけ遅れているか。最新版までに出たリリースを major / minor / patch に分けて数え、重みを掛けて足したもの([スコアの定義](https://github.com/shiroinock/dept#スコアの定義))。

- 合計 **40** = major 1 × 30 + minor 1 × 3 + patch 7 × 1
- 2 / 3 パッケージが遅れている、0.1 libyears
- ロックファイル:`./pnpm-lock.yaml`

| SCORE | PACKAGE | CURRENT | LATEST | MAJ | MIN | PAT | LIBYEAR | KIND |
| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| 39 | `vitest` | 4.1.12 | 5.1.1 | 1 | 1 | 6 | 0.1 | dev |
| 1 | `@biomejs/biome` | 2.6.8 | 2.6.9 | 0 | 0 | 1 | 0.0 | dev |

<details>
<summary>最新の依存(1 件)</summary>

| PACKAGE | VERSION | KIND |
| --- | --- | --- |
| `typescript` | 7.0.2 | dev |

</details>

---

[dept](https://github.com/shiroinock/dept) で作成

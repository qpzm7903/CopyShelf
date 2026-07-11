Status: done (v0.1.7)

# 11: frecency 排序

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.7

## What was built

- `SnippetStats` 新增 `recentUses`（最近 10 次使用时间戳，升序截断）与
  `frecencyScore(now)`：每条记录按年龄指数衰减（半衰期 7 天）求和。
  刚用过 = 1.0，7 天前 = 0.5；「近期低频」胜过「远古高频」。
- 时钟回拨防护：未来时间戳按年龄 0 计分（钳 0），不丢分。
- 旧格式 stats.json（无 recentUses）迁移：lastUsedAt 合成一条使用记录。
- Provider 排序链：frecency 降序 → 累计频次 → 最近使用时间 → 名称字典序
  （从未使用过的片段有稳定可预期顺序）。

## Acceptance criteria

- [x] 半衰期精确性测试（1.0 / 0.5）
- [x] 近期低频 > 远古高频（模型层 + Provider 排序层各一）
- [x] recentUses 截断保留最近 10 次
- [x] 旧 stats.json 无损迁移 + toJson/fromJson 往返
- [x] 同分退避到名称字典序
- [x] 全部 90 测试通过，`flutter analyze` 零 error/warning

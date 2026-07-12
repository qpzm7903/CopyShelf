Status: done (v0.1.21)

# 25: Espanso 导入 + scoop 分发清单

## Parent

`.scratch/copyshelf-v1/ROADMAP-20.md` v0.1.21（winget 已砍：需 PR 进 microsoft/winget-pkgs 且无法本侧验证）

## What was built

- 行为项：`espanso_importer.dart`——yaml 包解析 Espanso match 文件，trigger→名称、
  replace→内容、多行块标量、`{{var}}`→`{var}` 且标记为模板；含字面大括号但无变量则非模板逐字。
  注册进导入框架，设置页导入来源新增 Espanso。
- 分发：`scoop/copyshelf.json`——checkver + autoupdate 用 $version 模板指向 Releases zip
  （与 CI 产物 CopyShelf-$version-windows-x86_64.zip 命名一致），用户 scoop bucket add 本仓库即可安装。

## Acceptance criteria

- [x] Espanso 解析单元测试 8 例（基础/多 match/多行/{{var}}→模板/字面大括号非模板/缺 replace 跳过/非法 YAML/无 matches）
- [x] scoop manifest 结构与 URL 模板单元测试
- [x] 全部 253 测试通过，`flutter analyze` 零 error/warning

## 待实机验证

- [ ] scoop bucket add + install 真实安装（scoop hash 待发版后填）

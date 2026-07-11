# 使用统计不参与 Git 同步

片段定义（name/content/description/tags）与使用统计（frequency/lastUsedAt）拆成两个文件：定义存 `snippets.json`，走 Git 同步，仅在增删改时 commit + push；统计存本地 `stats.json`，加入 `.gitignore`，粘贴只写本地。

若统计和定义同在一个同步文件里，每次粘贴都会触发 commit + push（高频动作绑上网络 IO），且多设备各自递增计数器必然造成 Git 合并冲突，把"冲突需人工解决"从罕见事件变成每周常态。代价是 frequency 各设备独立统计——我们认为这更合理：不同设备上的使用习惯本就不同，排序本地化反而更准。

## Considered Options

- 统计与定义同文件同步（原方案）：粘贴即 push，多设备计数器冲突不可避免，否决。
- 统计同步但用 CRDT/合并策略自动解冲突：复杂度远超个人工具的收益，否决。

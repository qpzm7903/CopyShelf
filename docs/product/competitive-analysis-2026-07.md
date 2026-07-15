# CopyShelf 竞品分析与产品路线（2026-07）

## 结论

CopyShelf 最值得占据的位置不是“功能最多的文本自动化工具”，而是：

> Windows 上最快、最可信、对开发者和重度文本用户最友好的主动片段启动器。

这意味着产品应继续坚持本地优先、纯文本、用户主动配置、可审计同步和键盘优先；不捕获剪贴板历史，不默认监听全部键盘输入，也不执行片段。PhraseExpress/FastKeys 的自动化广度不是 CopyShelf 应该复制的方向。

最接近的体验标杆是 Raycast Snippets 的“搜索/粘贴”路径；最直接的迁移来源是 Espanso、Beeftext、VS Code 和各类文本扩展器；PhraseExpress、TextExpander、Text Blaze 则代表模板和团队协作的能力上限。

## 产品分组

| 产品 | 核心形态 | 强项 | 主要取舍 |
| --- | --- | --- | --- |
| **CopyShelf** | Windows 片段启动器 | 拼音与正文搜索、frecency、快速创建、标签、模板、终端保护、Git 同步与历史、本地优先 | 目前缺少自动缩写、完整导入/导出、团队权限 |
| [Raycast Snippets](https://manual.raycast.com/snippets) | 启动器内的片段模块 | 搜索/粘贴/复制、标签、置顶、自动缩写、动态占位符、迁移导入；整体交互成熟 | 属于综合启动器；Windows 仍在演进，数据与功能绑定 Raycast 生态 |
| [Espanso](https://espanso.org/) | 开源跨平台文本扩展器 | 自动缩写、搜索栏、表单、脚本、包生态、文件配置 | GUI 管理较弱；脚本能力提高了配置和安全复杂度 |
| [Beeftext](https://beeftext.org/) | Windows 开源文本扩展器 | 简单、免费、自动缩写、Combo Picker | [项目已进入仅维护状态](https://github.com/xmichelo/Beeftext)，不再增加新功能 |
| [PhraseExpress](https://www.phraseexpress.com/features/) | Windows 重型文本自动化 | 富文本、复杂表单、应用规则、版本历史、团队/SQL、宏与外部数据 | 功能密度和学习成本高，明显超出“快速找片段”的边界 |
| [TextExpander](https://textexpander.com/learn/using/searching-snippets/inline-search) | 跨平台个人/团队文本扩展器 | 就地搜索、缩写、丰富 Fill-ins、团队共享与权限 | 订阅和云服务导向；个人本地可控性弱于 CopyShelf |
| [Text Blaze](https://blaze.today/plans/) | 浏览器/Windows 动态模板 | 表单、规则、富内容、团队协作，个人版价格较低 | 更偏网页业务流程和 SaaS，离线与数据自主性较弱 |
| [aText](https://www.trankynam.com/atext/) | Windows/macOS 文本自动化 | 富文本、字段、脚本、云盘同步、应用适配 | 界面与能力较重，自动化范围扩大了故障面 |
| [FastKeys](https://www.fastkeysautomation.com/) | Windows 自动化套件 | 文本扩展、填表、宏、启动菜单、剪贴板历史、团队共享 | 与 CopyShelf 的主动片段定位不同，复杂度高 |
| [Lintalist](https://lintalist.github.io/) | Windows 开源片段搜索器 | 四种搜索模式（常规/模糊/正则/乱序）、按窗口标题自动切换 bundle、片段内特殊码 | AutoHotkey 技术栈、UI 陈旧；脚本码与"不执行片段"冲突 |
| [Ditto](https://sabrogden.github.io/Ditto/) / [CopyQ](https://copyq.readthedocs.io/) | 开源剪贴板管理器 | Ditto：6 个分发渠道；CopyQ：社区命令仓库与「复制即导入」分享 | 核心是剪贴板历史，与 CopyShelf 定位相反；借鉴生态与分发，不借鉴形态 |

## 能力矩阵

符号说明：`✓` 已具备，`△` 部分具备或依赖套餐/平台，`—` 不是主能力。

| 能力 | CopyShelf | Raycast | Espanso | Beeftext | PhraseExpress | TextExpander |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| 全局搜索后粘贴 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 仅复制 | ✓ | ✓ | △ | △ | ✓ | ✓ |
| 自动缩写展开 | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| 用户输入模板 | ✓ | △ | ✓ | — | ✓ | ✓ |
| 动态变量 | 基础 | ✓ | ✓ | — | ✓ | ✓ |
| 标签/分组 | 标签 | 标签 | 文件/包 | 分组 | 多级目录 | 分组 |
| 使用排序/置顶 | ✓ | ✓ | — | △ | ✓ | △ |
| 导入迁移 | 3 类 | 多类 | 配置文件 | 导出/导入 | 多类 | 多类 |
| 多设备同步 | Git | 账号 | 自管文件 | 自管文件 | 云盘/SQL | 云端 |
| 单条历史恢复 | Git | △ | Git 自管 | — | ✓ | ✓ |
| 本地优先/无需账号 | ✓ | △ | ✓ | ✓ | ✓ | — |
| 中文拼音搜索 | ✓ | — | — | — | — | — |
| 终端多行保护 | ✓ | — | — | — | — | — |
| 团队权限/管理 | — | 付费团队 | — | — | ✓ | ✓ |

## CopyShelf 的可守优势

1. **主动而非监控**：用户呼出、搜索、确认后才粘贴，不需要默认监听所有键盘输入，也不记录剪贴板历史。
2. **数据可拥有、可审计**：片段是纯文本 JSON，Git 同步既支持自托管，也天然提供版本历史。
3. **开发者安全细节**：终端多行确认、模板 opt-in、目标窗口失效降级，这些都直接减少高代价误操作。
4. **中文检索**：名称、描述和标签支持全拼/首字母，正文也可搜索，这是国际产品普遍没有覆盖的体验。
5. **窄而完整**：片段只被粘贴、不被执行。边界越清楚，可靠性和用户信任越容易做到领先。

## 当前差距

### P0：先把可信度做实

- Git 命令增加非交互模式、超时和进程终止，避免 SSH/凭据请求挂住应用。（本轮完成）
- 快捷键重绑改为“新组合注册成功后才持久化”，失败时恢复旧组合。（本轮完成）
- Windows 实机覆盖：多显示器/DPI、管理员窗口、终端、RDP、输入法、目标窗口关闭。
- 发布安装包签名，减少 Windows SmartScreen 阻力。

### P1：缩短高频工作流

- `Ctrl+Enter` 仅复制，并与模板渲染共用同一条内容准备链路（本轮完成）。
- 搜索窗内快速新建：搜索词预填名称、当前剪贴板预填内容，不必进入设置页。（本轮完成）
- 片段复制、批量编辑、回收站；删除不应只能依赖 Git 历史手动找回。
- CSV、TextExpander、Beeftext、aText、PhraseExpress 导入，以及稳定的 JSON/CSV 导出。
- 模板编辑器提供变量插入菜单和即时预览，减少记忆语法。

### P2：增强模板，而不是引入脚本执行

- `{cursor}` 光标位置。
- 日期格式与偏移，例如自定义格式、`+2d`。
- 变量变换，例如 `trim`、`uppercase`、`lowercase`、JSON 转义和 URL 编码。
- 选项型字段、日期选择器、可选段落。
- 片段引用，但必须检测循环依赖。

### P3：谨慎试验自动缩写

自动缩写是竞品的普遍能力，但会引入全局键盘监听、误触发、密码框和不同应用注入兼容问题。若实现，应满足：

- 默认关闭，每条片段显式配置 trigger。
- 密码管理器、凭据窗口和用户禁用应用绝不展开。
- 不记录、不上传按键；只保留匹配所需的短内存缓冲。
- 支持立即展开/分隔符后展开、大小写和冲突检测。
- 先用实验开关发布，Windows 实机矩阵通过后再转稳定。

## 2026-07 深度调研增量

对 Espanso / Lintalist / CopyQ / Ditto / Raycast 的 25 条特性主张做了 3 票对抗性核实（13 条确认、3 条否决），在上文差距清单之外新增以下结论。

### 新差距：窗口上下文感知（候选杀手级差异化）

Espanso 支持按目标应用加载不同配置（app-specific config），Lintalist 的 bundle 按当前活动窗口标题自动切换——两个互不相关的开源工具独立实现了同一模式（均 3-0 全票）。CopyShelf 呼出时已捕获目标窗口（粘贴需要），顺势按目标进程名/窗口标题**自动预选标签或加权排序**（如从终端呼出优先 `#shell`）可复用 TargetWindowService 与标签体系，且不涉及键盘监听，与定位不冲突。

### 新差距：片段包分享生态

Espanso Hub 有内置包管理器；CopyQ 社区命令仓库的「复制即导入」（复制 `[Command]` 文本→应用检测→一键导入）摩擦极低。CopyShelf 的 Git 同步只解决"自己的片段跨设备"，缺"发现并导入他人片段包"。天然形态是**导入他人片段 Git 仓库**，与现有同步机制同源。

### 新差距：分发渠道广度

Ditto 有 6 个渠道（安装包/便携版/Chocolatey/Winget/Store），CopyShelf 仅 Scoop。便携版 ZIP 与 Chocolatey 无第三方审核成本，可先做；winget 维持已砍掉的决定。

### 次优先：模糊搜索

Lintalist 提供常规/模糊/正则/乱序四种搜索模式（2-1 票，中置信度）。模糊匹配对长英文片段名收益明显，但需先验证与拼音索引的融合成本。

### 核实后不成立的直觉（避免误判）

- Lintalist 支持富文本/HTML/图片片段——被否决。
- CopyQ 的目录同步可直接当多设备同步方案——被否决。
- CopyQ 多语言脚本可类比 Espanso script extension——被否决。

### 覆盖缺口

uTools / Quicker / 备忘快贴（中文生态付费点）与 massCode / SnippetsLab（多级目录组织）未产出存活声明，需要时应单独补一轮调研，不能视为"无可借鉴"。

## 明确不做

- 不做剪贴板历史；这会破坏清晰定位，并引入敏感数据留存风险。（2026-07 核实确认：CopyQ 剪贴板变化触发、Ditto 全量捕获均以常驻监听为前提，与本定位不可调和。）
- 不执行 shell/PowerShell/JavaScript 片段；CopyShelf 粘贴文本，不成为自动化运行器。（2026-07 核实确认：Espanso shell/script 扩展、正则触发内联参数、Lintalist 内嵌 AHK 均要求任意代码执行能力。）
- 不优先做富文本、图片、表格；先把纯文本跨应用可靠性做到领先。
- 不为了 AI 而加 AI。只有当它能显著降低“创建、查找、维护片段”的成本，且允许用户自带服务时再评估。

## 衡量“最好用”

- 呼出到完成粘贴的 P50/P95 时间。
- 首次输入命中率、零结果率、搜索后改词次数。
- 粘贴失败率、目标窗口丢失率、同步失败率。
- 新建一条可复用片段所需时间。
- 30 天内真正复用过的片段占比。
- 终端风险确认的触发率、取消率和误报反馈。

## 本轮资料来源

- [Raycast Snippets Manual](https://manual.raycast.com/snippets)
- [Raycast Dynamic Placeholders](https://manual.raycast.com/dynamic-placeholders)
- [Espanso 官网](https://espanso.org/) 与 [Espanso Hub](https://hub.espanso.org/)
- [PhraseExpress Windows 功能列表](https://www.phraseexpress.com/features/)
- [TextExpander Inline Search](https://textexpander.com/learn/using/searching-snippets/inline-search) 与 [Fill-ins](https://textexpander.com/learn/using/snippets/advanced-snippet-elements/advanced-fill-ins)
- [Text Blaze 方案与价格](https://blaze.today/plans/)
- [Beeftext 官网](https://beeftext.org/) 与 [GitHub 仓库](https://github.com/xmichelo/Beeftext)
- [aText 官网](https://www.trankynam.com/atext/)
- [FastKeys 官网](https://www.fastkeysautomation.com/)
- [Espanso Regex Triggers](https://espanso.org/docs/matches/regex-triggers/)、[Extensions](https://espanso.org/docs/matches/extensions/) 与 [Forms](https://espanso.org/docs/matches/forms/)
- [Lintalist 官网](https://lintalist.github.io/)
- [CopyQ 命令文档](https://copyq.readthedocs.io/en/latest/writing-commands-and-adding-functionality.html) 与 [社区命令仓库](https://github.com/hluk/copyq-commands)
- [Ditto 官网](https://sabrogden.github.io/Ditto/)

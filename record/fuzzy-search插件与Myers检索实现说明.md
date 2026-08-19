# fuzzy-search 插件与 Myers 模糊检索实现说明

本文描述模糊检索功能当前的未实现需求设计和已经实现的大致行为，最后一节给出未实现需求说明

关键依据：插件配置/工具执行见 `openclaw-source/extensions/fuzzy-search/index.ts:49-60,100-145,154-291`；OpenClaw 路径解析见 `openclaw-source/src/plugins/registry.ts:615` 和 `openclaw-source/src/infra/home-dir.ts:79-99`；匹配与目录遍历见 `qol/MyersBitParallelFuzzySearch.swift:171-283,317-395`；CLI JSON 输出见同文件 `:406-451`；App 占位符替换见 `MutualInfectionMac/Application/NodeRuntimeManager.swift:326-333,396-407`；构建产物编译见 `scripts/prepare_node_runtime_bundle.sh:117-131`。

## 0.面向用户需求
目前已经实现的主要需求是，在用户实际文件名或检索提供词“存在1处错误”时，允许模糊检索匹配上并分类返回匹配结果，从而agent可以进一步分析真实需求。
该功能也支持部分检索情形，如检索paln，那么real-plan也会被认为是模糊匹配。
分类结果暂时略显粗糙，可以进一步根据用户需求改进，9中记录了部分我认为合理的功能需求


## 1. 原始位置与组成

| 组件 | 原始位置（项目相对路径） | 作用 |
| --- | --- | --- |
| OpenClaw 插件入口 | `openclaw-source/extensions/fuzzy-search/index.ts` | 读取配置、注册 Agent 工具、校验目录、编译/执行 Swift、转换输出 |
| 插件清单 | `openclaw-source/extensions/fuzzy-search/openclaw.plugin.json` | 插件 ID、版本和配置 schema |
| 插件说明 | `openclaw-source/extensions/fuzzy-search/README.md` | 参考材料；若与源码冲突，以源码为准 |
| 用户需求草稿 | `openclaw-source/extensions/fuzzy-search/NOTE.md` | 需求输入；不代表实现状态 |
| Myers 算法与目录 CLI | `qol/MyersBitParallelFuzzySearch.swift` | Unicode scalar 多字长 Myers 距离、分层匹配、目录遍历和 JSON CLI |
| 算法测试 | `qol/MyersBitParallelFuzzySearchTests.swift` | 距离、中文长查询、窗口剪枝、10000 条夹具回归 |
| 性能基准 | `qol/MyersFuzzyBenchmark.swift` | 与 `FuzzyCandidateIndex` 基线比较吞吐、准确率和加速比 |
| 纯 Swift 基线 | `qol/FuzzyCandidateMatcher.swift` | 不使用 bit-parallel 的同规则候选索引 |
| 基线测试 | `qol/FuzzyCandidateMatcherTests.swift` | 基线分层与部分匹配回归 |

## 2. 插件功能

插件 ID 为 `fuzzy-search`，注册的可见工具名为 `fuzzy_search`。它在 Agent 已知“文件名查询”和“准确目录”时递归搜索该目录，只匹配文件名主体（去除扩展名），不建立或读取 JSON 索引。每次调用重新枚举目录，所以文件增删改会在下一次调用生效。

默认搜索只接受普通文件：Swift 枚举器设置 `.skipsHiddenFiles` 和 `.skipsPackageDescendants`，并额外要求 `isRegularFile == true`、`isSymbolicLink != true`；无法读取的枚举项会跳过。返回路径相对于本次传入目录，避免把绝对文件路径直接暴露给模型；成功详情中的 `directory` 仍是实际绝对搜索目录。

## 3. 当前配置方法

当前使用的Openclaw模板配置应当位于 `NodeRuntimeHost/config/openclaw.template.json`：

```json
{
  "plugins": {
    "entries": {
      "fuzzy-search": {
        "enabled": true,
        "config": {
          "enabled": true,
          "toolPath": "${FUZZY_SEARCH_TOOL_PATH}",
          "rootPath": "/Users/mac/Desktop/",
          "timeoutMs": 300000
        }
      }
    }
  }
}
```

插件入口只读取 `api.pluginConfig` 中的 `enabled`（源码第 155、183 行）；宿主是否加载插件还由外层插件条目的 `enabled` 控制。两者都应保持为 `true`。`toolPath` 和 `rootPath` 会先经过 OpenClaw 的 `api.resolvePath`（当前实现是展开 `~` 并调用 `path.resolve`，不是通用的环境变量展开），随后必须是绝对路径。工具文件名必须为 `MyersBitParallelFuzzySearch.swift`，或已编译的 `myers-bit-parallel-fuzzy-search`。`rootPath` 是授权边界，Agent 传入的目录必须位于其真实路径之内。插件代码的默认 `timeoutMs` 为 20000 ms，配置值限制在 1000--300000 ms；当前模板显式设置 300000 ms。

### `${FUZZY_SEARCH_TOOL_PATH}` 如何可用

`${FUZZY_SEARCH_TOOL_PATH}` 是应用自己的配置模板占位符，不依赖 OpenClaw 或 shell 在运行时展开。构建脚本 `scripts/prepare_node_runtime_bundle.sh` 会编译 `qol/MyersBitParallelFuzzySearch.swift`（启用 `FUZZY_SEARCH_CLI`），并把产物写到 App 资源目录：

```text
NodeRuntime/tools/myers-bit-parallel-fuzzy-search
```

应用启动时，`MutualInfectionMac/Application/NodeRuntimeManager.swift` 的 `materializeConfigPlaceholders` 将模板中的 `${FUZZY_SEARCH_TOOL_PATH}` 替换为该 App bundle 内可执行文件的绝对路径。`Layout.fuzzySearchToolURL` 明确指向 `tools/myers-bit-parallel-fuzzy-search`。所以 App 正常启动链路中插件实际获得的是已存在的绝对可执行路径，不是 `${...}` 字面量，也不需要 App 在运行时调用 `swiftc`。

若手工脱离 App 启动 OpenClaw，必须自行把占位符替换为已编译可执行文件的绝对路径；否则 `api.resolvePath` 会把 `${FUZZY_SEARCH_TOOL_PATH}` 当普通相对字符串解析，之后 `validateRuntime` 会因文件名不匹配或文件不存在返回 `invalid_runtime`。只有直接指定 Swift 源文件路径时，插件才会在每次调用临时编译并要求存在 `/usr/bin/swiftc`。

当配置的是 `.swift` 源文件，插件在系统临时目录调用 `/usr/bin/swiftc -D FUZZY_SEARCH_CLI -parse-as-library` 编译，使用临时模块缓存和临时可执行文件，调用结束后删除可执行文件。运行环境因此必须有 Swift 编译器。配置编译产物可跳过每次编译。

## 4. Agent 可见工具与引导

工具 schema 只有两个必填字符串参数：

```json
{
  "query": "plan",
  "directory": "/AUTHORIZED/ROOT/project"
}
```

- `query`：非空文件名主体查询，插件会去除首尾空白；通常不要带扩展名。
- `directory`：必填绝对目录，必须存在且在授权根目录内。工具不会替 Agent 猜目录，也不会自动搜索授权根目录的其他位置。

推荐给 Agent 的可见引导内容：当用户同时给出文件名线索和目录时，先调用 `fuzzy_search`；目录只有模糊描述时，先用目录浏览能力确定授权范围内的精确绝对目录，再调用本工具；禁止为了找目录而越过 `rootPath`。回复用户时至少报告一个候选（若有）和结果总数；结果多时列出候选并让用户确认，不要擅自打开或选择不确定文件。

## 5. 匹配规则与排序

比较对象是文件名主体，英文大小写和变音符号不敏感，按 Unicode scalar 工作，支持中文和超过 64 个 scalar 的查询。结果先按层级，再按文件名 `localizedStandardCompare` 排序：

| `score` | 规则 |
| --- | --- |
| `exact` | 主体完全相等 |
| `same_length_one_error` | 等长且 Levenshtein 距离不超过 1，或一组相邻字符交换 |
| `one_character_shorter` | 候选比查询短一个 scalar，且距离不超过 1 |
| `contains_query` | 更长主体包含查询的连续窗口 |
| `contains_one_error` | 更长主体含一个距离错误或相邻交换的窗口 |

长主体窗口采用剪枝：仅在候选字符等于查询前三个字符之一时触发，并尝试该对齐位置及向前偏移 1。该优化可能漏掉未触发的理论距离 1 窗口，是当前已知行为。目录 CLI 不设结果上限；内部通用搜索请求默认 `limit=50`，插件传入目录搜索后返回全部结果。

## 6. 输入、输出与错误

插件成功响应把结构化数据放在 `details`，`content` 为空：

```json
{
  "content": [],
  "details": {
    "ok": true,
    "result": {
      "directory": "/AUTHORIZED/ROOT/project",
      "results": [
        {"relativePath":"docs/plan.md","fileName":"plan.md","fileExtension":"md","size":4096,"modifiedAt":"2026-08-18T12:00:00Z","score":"exact"}
      ]
    }
  }
}
```

`size` 读取失败时为 `null`，`modifiedAt` 读取失败时为 `null`。失败均为 `content: []` 且 `details.ok: false`，主要 `reason` 如下：`disabled`、`empty_query`、`invalid_directory`、`invalid_runtime`、`unauthorized_directory`、`search_failed`。Swift 标准错误会记录到插件日志并原样放入 `message`；非数组或字段不合法的 Swift JSON 项会被丢弃。结果校验还拒绝绝对路径和包含 `..` 的相对路径。

## 7. Swift CLI 与直接调用

`MyersBitParallelFuzzySearch.swift` 在 `FUZZY_SEARCH_CLI` 条件下提供 CLI：

```bash
swiftc -D FUZZY_SEARCH_CLI -parse-as-library qol/MyersBitParallelFuzzySearch.swift -o /tmp/myers-bit-parallel-fuzzy-search
/tmp/myers-bit-parallel-fuzzy-search search plan --root /ABS/DIRECTORY
```

输出为 UTF-8、ISO-8601 日期、漂亮打印且按 key 排序的 JSON 数组；每项字段为 `relativePath`、`fileName`、`fileExtension`、`size`、`modifiedAt`、`score`。Swift API 也可直接使用：构造 `MyersBitParallelFuzzySearch(candidates:)`，调用 `search(.init(query:limit:))`；目录级调用使用 `DirectoryFuzzySearch.search(root:query:)`。

算法通过跨 64 位 word 的 bit-parallel 状态计算 Levenshtein 距离，不依赖有限字母表或中文词典。目录遍历开启 security-scoped resource（若可用），并在结束时关闭。

## 8. 测试与基准

测试依赖 `qol/fuzzy-search-fixture-10000.json`（10000 个文件和查询期望集合）。运行：

```bash
mkdir -p /private/tmp/qol-swift-cache
swiftc -module-cache-path /private/tmp/qol-swift-cache -parse-as-library qol/MyersBitParallelFuzzySearch.swift qol/MyersBitParallelFuzzySearchTests.swift -o /private/tmp/myers-tests
/private/tmp/myers-tests qol/fuzzy-search-fixture-10000.json
swiftc -module-cache-path /private/tmp/qol-swift-cache -parse-as-library qol/FuzzyCandidateMatcher.swift qol/FuzzyCandidateMatcherTests.swift -o /private/tmp/fuzzy-baseline-tests
/private/tmp/fuzzy-baseline-tests
swiftc -module-cache-path /private/tmp/qol-swift-cache -parse-as-library qol/FuzzyCandidateMatcher.swift qol/MyersBitParallelFuzzySearch.swift qol/MyersFuzzyBenchmark.swift -o /private/tmp/myers-benchmark
/private/tmp/myers-benchmark qol/fuzzy-search-fixture-10000.json 50
```

`MyersBitParallelFuzzySearchTests` 覆盖精确/距离、相邻交换、长中文、窗口触发剪枝和夹具全量期望；`FuzzyCandidateMatcherTests` 覆盖基线分层。`MyersFuzzyBenchmark` 对每个查询先输出 baseline/optimized 的 precision、recall，再测总耗时、QPS 和 speedup。基准结果取决于机器、Swift 版本、迭代次数，不能把一次运行数字当成固定 SLA。若系统默认 Swift/Clang module cache 不可写，必须像上例显式指定 `-module-cache-path`。

## 9. 待实现用户需求设计（实现状态与建议）

以下内容是相关功能的需求设计参考，主要为未完成部分需求：

| 需求 | 当前是否实现 | 推荐方法 | 示例 |
| --- | --- | --- | --- |
| 文件索引功能 | 未实现 | 考虑使用MacOS自有Spotlight索引工具实现基础检索功能，是否需要自有索引以实现高级工具能力待完善测试 | 大量文件/用户对文件位置印象不深时中检索 |
| LLM 推断错拼并检索原始/候选 query | 部分实现：当前匹配器可返回一次编辑/相邻交换候选，但插件不会自动生成候选 query，也不会自行重试 | 在 Agent 编排层限制候选查询数量（例如最多 2--3 个），分别调用并标注查询来源 | 先搜 `plna`，无确认结果时再搜 `plan` |
| 忽略标点/数字、最多两次编辑 | 未实现 | 增加可配置规范化策略和最大编辑距离；保持中文 Unicode scalar 支持 | `2026年度计划` 匹配 `2026-年度计划.pdf` |
| 多词、任一/全部词、目录名参与匹配 | 未实现；当前 schema 只有 `query`、`directory` | 扩展请求 schema，明确 `all/any`，再对相对路径分段评分 | `预算 2026` 匹配 `财务/2026/预算草案.xlsx` |
| 按意图、时间、类型排序 | 未实现；当前仅按固定 score 层级和文件名本地化标准顺序排序 | 在匹配层级内增加稳定的修改时间、扩展名或目录相关性排序 | “最新预算表”优先近期 `.xlsx` |
| 自动发现目录和授权流程 | 未实现；`directory` 始终必填，插件不负责目录发现 | 由 Agent/宿主先确定并授权精确绝对目录，再调用工具 | “桌面项目里的计划” |
| 图片要素渐进识别 | 未实现 | 文件名检索无效后再接入受预算、并发、缓存和取消控制的图像分析 | “有白板和路线图的截图” |

推荐顺序是先完善 Agent 层的有限纠错和目录授权，再扩展规范化/多词协议与稳定排序，最后接入按需图片识别；不要用有限英文字母表的优化替代当前 Unicode scalar 实现。
# Fuzzy Search

独立 OpenClaw 插件，注册 `fuzzy_search`。它使用
`qol/MyersBitParallelFuzzySearch.swift` 的 Myers bit-parallel fuzzy 模式，直接遍历
agent 指定的目录；不建立或读取 JSON 索引。

每次调用都必须提供 `directory` 绝对路径。该路径必须位于宿主配置的 `rootPath`
授权边界内，Swift 只会递归搜索该目录。

配置：

```json
"plugins": {
  "entries": {
    "fuzzy-search": {
      "enabled": true,
      "config": {
        "enabled": true,
        "toolPath": "/ABS/PATH/myers-bit-parallel-fuzzy-search",
        "rootPath": "/AUTHORIZED/ROOT",
        "timeoutMs": 300000
      }
    }
  }
}
```

调用：

```json
{ "query": "plan", "directory": "/AUTHORIZED/ROOT/project" }
```

所有结果通过结构化 `details.result.results` 返回，而不是 text。结果按 `score`
分组且不截断，顺序是：`exact`、`same_length_one_error`、
`one_character_shorter`、`contains_query`、`contains_one_error`。

在 App Sandbox 中，`rootPath` 必须来自 `NSOpenPanel`/security-scoped bookmark，且由
宿主在检索期间恢复访问权限。每次检索都会重新遍历 `directory`，因此目录更新会立即反映在结果中。

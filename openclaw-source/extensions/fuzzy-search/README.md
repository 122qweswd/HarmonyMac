# Fuzzy Search

独立 OpenClaw 插件，注册 `fuzzy_search`。它固定使用
`qol/MyersBitParallelFuzzySearch.swift` 的 Myers bit-parallel fuzzy 模式，并由 Swift
直接遍历已授权的目录；不建立或读取 JSON 索引，也不接受 agent 提供的根目录或工具路径。

可直接配置 Swift 源文件：

```text
/ABS/PATH/qol/MyersBitParallelFuzzySearch.swift
```

配置：

```json
"plugins": {
  "entries": {
    "fuzzy-search": {
      "enabled": true,
      "config": {
        "enabled": true,
        "toolPath": "/ABS/PATH/qol/MyersBitParallelFuzzySearch.swift",
        "rootPath": "/AUTHORIZED/ROOT",
        "timeoutMs": 20000,
        "maxLimit": 50
      }
    }
  }
}
```

重启 gateway 后，agent 可调用：

```json
{ "query": "plan", "limit": 20 }
```

在 App Sandbox 中，`rootPath` 必须来自 `NSOpenPanel`/security-scoped bookmark，且由
宿主在检索期间恢复访问权限。每次检索都会重新遍历目录，因此目录更新会立即反映在结果中。

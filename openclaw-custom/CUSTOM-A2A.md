# 定制版 OpenClaw（内置 A2A Gateway + Tunnel）

基于官方标签 **v2026.3.13-1**，把 `a2a-gateway`（嵌入隧道版）做成 stock 内置插件并默认启用。

**完整的安装与使用说明请看：[README-安装与使用.md](./README-安装与使用.md)**  
（面向 **鸿蒙 / macOS / 安卓** 设备；命令用 `sh`/`bash`，不要用 Windows PowerShell。）

## 与官方版的差异（摘要）

| 项 | 说明 |
|----|------|
| 插件目录 | `extensions/a2a-gateway/` |
| 默认启用 | `BUNDLED_ENABLED_BY_DEFAULT` 含 `a2a-gateway` |
| 运行时依赖 | 已写入根 `package.json`，`npm install -g` 时一并安装 |
| 安装包 | `openclaw-2026.3.13.tgz`（先拷到设备再装） |

## 一句话安装

先把 tgz 放到设备上，再在终端执行（路径按实际改）：

```bash
# macOS 示例
npm install -g ~/Downloads/openclaw-2026.3.13.tgz

# 鸿蒙示例
npm install -g /data/local/tmp/openclaw-2026.3.13.tgz

# 安卓 / Termux 示例
npm install -g ~/storage/downloads/openclaw-2026.3.13.tgz

openclaw plugins list   # A2A Gateway 应为 loaded
```

若配置了 `plugins.allow`，务必包含 `"a2a-gateway"`。

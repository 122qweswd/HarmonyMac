# 定制版 OpenClaw — 安装与使用说明（逐步版）

> 基于官方 **OpenClaw v2026.3.13-1**，**内置** A2A Gateway（嵌入 Tunnel）。  
> 目标设备：**鸿蒙 / OpenHarmony、macOS、安卓**（能跑 Node.js 22+ 的终端环境）。  
> 安装包：`openclaw-2026.3.13.tgz`（名称来自 `name-version.tgz`，不要改命令里的文件名）。  
> **命令一律用 `sh` / `bash`（或 zsh），不要用 PowerShell / Windows 路径。**

---

## 先读这 3 条（避免再踩坑）

1. **你要装的是 `.tgz` 定制 OpenClaw**，不是再去装一份「外部插件目录」。
2. **不要**再执行：
   - `openclaw plugins install .../a2a-gateway`
   - `openclaw config set plugins.load.paths '["/workspace/plugins/a2a-gateway"]'`
   - 任何指向 `/workspace/plugins/a2a-gateway` 的命令  
   这些是**旧的外挂插件装法**。路径不存在时就会报：`/workspace/plugins/a2a-gateway not found`。
3. 定制版里插件已经在安装包内部的 `extensions/a2a-gateway/`，装完 OpenClaw 就会带上。

---

## 目录

- [第 0 章：确认你有安装包](#第-0-章确认你有安装包)
- [第 1 章：检查环境](#第-1-章检查环境)
- [第 2 章：清理旧的外挂插件配置（必做）](#第-2-章清理旧的外挂插件配置必做)
- [第 3 章：安装定制版 OpenClaw](#第-3-章安装定制版-openclaw)
- [第 4 章：确认 A2A 已加载](#第-4-章确认-a2a-已加载)
- [第 5 章：写入 A2A 配置并重启](#第-5-章写入-a2a-配置并重启)
- [第 6 章：跨 NAT 隧道（可选）](#第-6-章跨-nat-隧道可选)
- [第 7 章：发一条测试消息](#第-7-章发一条测试消息)
- [第 8 章：常见报错对照](#第-8-章常见报错对照)
- [附录：鸿蒙 / Mac / 安卓差异](#附录鸿蒙--mac--安卓差异)

---

## 第 0 章：确认你有安装包

### 步骤 0.1

把 `openclaw-2026.3.13.tgz` 拷到设备上，然后在终端里确认文件存在。下面按平台举例（路径按你实际放置位置改）：

**macOS**

```bash
ls -lh ~/Downloads/openclaw-2026.3.13.tgz
```

**鸿蒙 / OpenHarmony**（常见放在 `/data/local/tmp`）

```bash
ls -lh /data/local/tmp/openclaw-2026.3.13.tgz
```

**安卓**（Termux 等，示例）

```bash
ls -lh ~/storage/downloads/openclaw-2026.3.13.tgz
# 或
ls -lh /sdcard/Download/openclaw-2026.3.13.tgz
```

**成功：** 能看到该文件，大小大约几十 MB。  
**失败：** 文件不存在 → 先用数据线 / `hdc file send` / `adb push` / AirDrop 等拷到设备。  
**不要跳过：** 没有这个文件就不要做第 3 章。

下文用占位符 `$TGZ` 表示你的真实路径，例如：

```bash
# macOS 示例
export TGZ=~/Downloads/openclaw-2026.3.13.tgz

# 鸿蒙示例
export TGZ=/data/local/tmp/openclaw-2026.3.13.tgz

# 安卓 / Termux 示例
export TGZ=~/storage/downloads/openclaw-2026.3.13.tgz
```

---

## 第 1 章：检查环境

> 所有命令在设备自带终端、`hdc shell`、`adb shell`、Termux 或 macOS 的 Terminal / iTerm 中执行。

### 步骤 1.1 — Node.js

```bash
node -v
```

**成功：** `v22.x` 或更高（例如 `v22.16.0`、`v24.x`）。  
**失败：** 先装好 Node.js 22+，再开新终端重试。

| 平台 | 常见做法 |
|------|----------|
| macOS | [nodejs.org](https://nodejs.org/) 或 `brew install node@22` |
| 鸿蒙 / OpenHarmony | 使用已部署的 OpenHarmony Node（如 `/data/local/tools/node-*/bin`），并保证在 `PATH` 里 |
| 安卓 | Termux：`pkg install nodejs`（确认版本 ≥ 22） |

鸿蒙手机若 `node` 找不到，先：

```bash
export PATH="/data/local/npm/bin:/data/local/tools/node-v24.2.0-openharmony-arm64/bin:/usr/local/bin:$PATH"
```

（具体 `node-v*` 目录名以你机器为准，`ls /data/local/tools/` 查看。）

### 步骤 1.2 — npm

```bash
npm -v
```

**成功：** 打印出版本号即可。

### 步骤 1.3 — 看当前 openclaw（可能还没有）

```bash
openclaw --version
```

- 若提示找不到命令：正常，第 3 章安装后就会有。
- 若已有版本：记下它；第 3 章安装会**覆盖**全局 `openclaw`。

---

## 第 2 章：清理旧的外挂插件配置（必做）

> 你看到的 `/workspace/plugins/a2a-gateway not found`，几乎都是旧配置还在指向这个路径。  
> **装定制包之前必须清掉。**

### 步骤 2.1 — 查看 load.paths

```bash
openclaw config get plugins.load.paths
```

可能出现的情况：

| 结果 | 含义 | 下一步 |
|------|------|--------|
| 报错找不到 openclaw / 没有该配置 | 还没装过或没有这项 | 跳到步骤 2.3 |
| 输出里含 `/workspace/plugins/a2a-gateway` 或其它 `.../plugins/a2a-gateway` | 旧外挂路径 | 必须做步骤 2.2 |
| 输出是 `[]` 或不含 a2a-gateway 路径 | 干净 | 跳到步骤 2.3 |

### 步骤 2.2 — 清空错误的 load.paths

```bash
openclaw config set plugins.load.paths '[]'
```

再查一次：

```bash
openclaw config get plugins.load.paths
```

**成功：** 为空列表 `[]`，或不再出现 `a2a-gateway` 路径。

若 `openclaw` 命令还不存在：用编辑器打开配置文件，找到：

```json
"load": {
  "paths": ["/workspace/plugins/a2a-gateway"]
}
```

改成：

```json
"load": {
  "paths": []
}
```

保存。没有 `load` 段就不用加。

常见配置路径见 [附录：鸿蒙 / Mac / 安卓差异](#附录鸿蒙--mac--安卓差异)。

### 步骤 2.3 — 处理 plugins.allow（若你用过白名单）

```bash
openclaw config get plugins.allow
```

- 若输出是空、或命令提示没有该项：第 3 章装完后默认会加载 A2A，**先不用改**。
- 若输出是一个数组（例如 `["telegram"]`）且**没有** `a2a-gateway`：记下现有插件名，第 4 章会改。
- 若已经包含 `a2a-gateway`：很好，不用改。

### 步骤 2.4 —（可选）关掉旧的外挂插件目录期望

如果你以前把插件拷在某目录，**不用删源码**，但不要再配置 `plugins.load.paths` 指向它。定制版只用包内置的 `extensions/a2a-gateway`。

---

## 第 3 章：安装定制版 OpenClaw

### 步骤 3.1 — 进入有 tgz 的目录（可选，方便敲命令）

```bash
cd "$(dirname "$TGZ")"
```

### 步骤 3.2 — 全局安装 tgz

```bash
npm install -g "$TGZ"
```

也可用绝对路径，例如：

```bash
# macOS
npm install -g ~/Downloads/openclaw-2026.3.13.tgz

# 鸿蒙
npm install -g /data/local/tmp/openclaw-2026.3.13.tgz

# 安卓 / Termux
npm install -g ~/storage/downloads/openclaw-2026.3.13.tgz
```

**成功：** 命令结束无红色失败；最后通常有 `added ... packages`。  
**失败常见原因：**

| 现象 | 处理 |
|------|------|
| 找不到文件 | 检查步骤 0.1 路径 |
| 权限错误（EACCES） | macOS：加 `sudo` 或改 npm prefix 到用户目录；鸿蒙/安卓：确认对 npm 全局目录有写权限 |
| 网络超时 | 确认终端能上网；或重试本步 |
| `allow-scripts` / 原生模块警告 | 先继续做第 4 章；若 `openclaw` 无法运行再处理 |

**本步不要做：**

```bash
# 错误示例，不要执行
openclaw plugins install /workspace/plugins/a2a-gateway
openclaw plugins install /path/to/openclaw-a2a-gateway-tunnel
```

### 步骤 3.3 — 确认命令可用

**关掉当前终端再开一个新会话**（或重新 `hdc shell` / `adb shell`），然后：

```bash
which openclaw
openclaw --version
```

**成功：**

- `which` 能找到 `openclaw`
- 版本显示含 `2026.3.13`

**失败：** 提示 command not found → 把 npm 全局 bin 目录加入 `PATH` 后重开终端：

```bash
npm config get prefix
# 把输出下的 bin 目录加入 PATH，例如：
# export PATH="$(npm config get prefix)/bin:$PATH"
```

| 平台 | 常见全局 bin |
|------|----------------|
| macOS | `/usr/local/bin` 或 `/opt/homebrew/bin`，或 `$(npm prefix -g)/bin` |
| 鸿蒙 PC | `/usr/local/bin` 或 `/usr/local/npm/bin` |
| 鸿蒙手机 | `/data/local/npm/bin` |
| 安卓 Termux | `$PREFIX/bin`（一般已在 PATH） |

**鸿蒙注意：** 默认 `HOME` 可能是 `/root`，而配置实际在 `/data/local/.openclaw/`。建议在 launcher 或当前 shell 固定环境变量（见附录）。

---

## 第 4 章：确认 A2A 已加载

### 步骤 4.1 — 列插件

```bash
openclaw plugins list
```

**成功：** 表格里有 **A2A Gateway**，**Status = loaded**（或 enabled/loaded），Source 类似 `stock:a2a-gateway/...`。

**若是 disabled：**

```bash
openclaw plugins enable a2a-gateway
```

再执行步骤 4.1。

**若完全没有 A2A Gateway：**

1. 确认装的是定制 tgz，不是官方 `npm install -g openclaw`：

```bash
openclaw --version
npm list -g openclaw
```

2. 检查白名单（步骤 4.2）。
3. 再查是否又写回了错误 load.paths（回到第 2 章）。

### 步骤 4.2 — 若有 allow 白名单，必须包含 a2a-gateway

```bash
openclaw config get plugins.allow
```

若有白名单且缺少 `a2a-gateway`，改成（保留你原来的插件名）：

```bash
# 示例：原来只有 telegram，现在加上 a2a-gateway
openclaw config set plugins.allow '["telegram","a2a-gateway"]'
```

只有 a2a 时也可以：

```bash
openclaw config set plugins.allow '["a2a-gateway"]'
```

然后再：

```bash
openclaw plugins list
```

确认 A2A 为 **loaded**。

### 步骤 4.3 — 插件详情

```bash
openclaw plugins info a2a-gateway
```

**成功：** 看到类似：

- `Origin: bundled`（或 stock）
- `Gateway methods:` 含 `a2a.send`
- `Services:` 含 `a2a-gateway`

### 步骤 4.4 — doctor

```bash
openclaw plugins doctor
```

**成功：** `No plugin issues detected`（或无 a2a 相关错误）。  
**若仍报 `/workspace/plugins/a2a-gateway not found`：** 旧路径没清干净，严格重做第 2 章，然后重启 Gateway（见步骤 5.4）并再跑 doctor。

---

## 第 5 章：写入 A2A 配置并重启

装完只是「插件在」；还要写本机配置，Gateway 才会监听 18800 / 连隧道。

### 步骤 5.1 — 打开配置文件

| 平台 | 常见路径 |
|------|----------|
| macOS | `~/.openclaw/openclaw.json` |
| 鸿蒙 / OpenHarmony | `/data/local/.openclaw/openclaw.json` |
| 安卓 Termux | `~/.openclaw/openclaw.json`（即 `$HOME/.openclaw/openclaw.json`） |

打开方式示例：

```bash
# macOS / 安卓
vi ~/.openclaw/openclaw.json
# 或
nano ~/.openclaw/openclaw.json

# 鸿蒙
vi /data/local/.openclaw/openclaw.json
```

若文件名是 `config.json` 则以你机器为准。没有目录就先建：

```bash
mkdir -p ~/.openclaw                    # macOS / 安卓
mkdir -p /data/local/.openclaw           # 鸿蒙
```

### 步骤 5.2 — 保证有 plugins.entries.a2a-gateway

在 JSON 里准备好如下结构（可与现有其它配置合并，不要删掉无关字段）：

```json
{
  "plugins": {
    "entries": {
      "a2a-gateway": {
        "enabled": true,
        "config": {}
      }
    }
  }
}
```

**注意：**

- 不要设置 `plugins.load.paths` 指向 `/workspace/plugins/a2a-gateway`。
- `load.paths` 保持 `[]` 或不写即可。

### 步骤 5.3 — 先写一份「仅本机可测」的最小 config

把 `config` 先设为（直连本机自测用）：

```json
{
  "server": { "host": "127.0.0.1", "port": 18800 },
  "agentCard": {
    "name": "本机-A2A",
    "skills": ["chat"]
  },
  "security": {
    "inboundAuth": "none"
  }
}
```

保存文件。

### 步骤 5.4 — 启动 / 重启 Gateway

**macOS / 安卓（支持守护进程时）：**

```bash
openclaw gateway restart
```

若提示未运行：

```bash
openclaw gateway start
```

**鸿蒙 / OpenHarmony（推荐前台）：**  
`gateway start/stop` 守护进程在部分鸿蒙环境不可用，请用：

```bash
openclaw gateway run --force --port 18789
```

保持该终端运行；需要「重启」时先 Ctrl+C 再执行同一条命令。  
（若你的环境已验证 `gateway restart` 可用，也可以用 restart。）

等 5～10 秒。

### 步骤 5.5 — 测 Agent Card

```bash
curl -s http://127.0.0.1:18800/.well-known/agent-card.json
```

没有 `curl` 时可用：

```bash
node -e "fetch('http://127.0.0.1:18800/.well-known/agent-card.json').then(r=>r.text()).then(console.log)"
```

**成功：** 返回一段 JSON，含 `"protocolVersion":"0.3.0"` 和你写的名字。  
**失败「无法连接」：**

1. `openclaw gateway status`（若平台支持）
2. 再执行步骤 5.4
3. 看日志里有没有：`a2a-gateway: HTTP listening on ...18800`
4. 确认步骤 5.2 / 5.3 已保存且 `enabled: true`
5. 鸿蒙：确认已 export `OPENCLAW_CONFIG_PATH`（见附录），否则可能读错配置

到这里：**定制版安装 + A2A 本机服务**完成。跨机器继续第 6、7 章。

---

## 第 6 章：跨 NAT 隧道（可选）

两台设备都完成第 0～5 章后，再配隧道。

### 步骤 6.1 — 中继（只需一台公网机器，做一次）

```bash
cd /path/to/a2a-relay-2
pip install -r requirements.txt
python relay-server.py --host 0.0.0.0 --port 8080 --http-port 8081
```

保持进程运行。安全组放行 8080、8081。

### 步骤 6.2 — 设备 A 的 config（示例）

编辑 `plugins.entries.a2a-gateway.config` 为：

```json
{
  "server": { "host": "127.0.0.1", "port": 18800 },
  "agentCard": { "name": "办公室 Gateway", "skills": ["chat"] },
  "tunnel": {
    "enabled": true,
    "relayUrl": "ws://中继公网IP:8080",
    "deviceId": "office-a"
  },
  "peers": [
    {
      "name": "home-b",
      "tunnelDeviceId": "home-b",
      "agentCardUrl": "http://127.0.0.1:18800/.well-known/agent-card.json",
      "auth": { "type": "bearer", "token": "token-home-b" }
    }
  ],
  "security": {
    "inboundAuth": "bearer",
    "token": "token-office-a"
  }
}
```

### 步骤 6.3 — 设备 B 的 config

与 A 镜像：`deviceId` 为 `home-b`；peer 的 `name` / `tunnelDeviceId` 为 `office-a`；令牌对调；`relayUrl` 相同。

### 步骤 6.4 — 两边都重启 Gateway

```bash
# macOS / 安卓
openclaw gateway restart

# 鸿蒙：停掉旧进程后再
openclaw gateway run --force --port 18789
```

### 步骤 6.5 — 看日志

应出现：

```text
a2a-tunnel: connected as office-a → ws://...
a2a-gateway: tunnel enabled ...
```

中继上：

```bash
curl -s http://127.0.0.1:8081/list
```

应同时有两个 deviceId。

---

## 第 7 章：发一条测试消息

### 步骤 7.1 — 在设备 A 执行（peer 名必须等于配置里的 `peers[].name`）

```bash
openclaw gateway call a2a.send --timeout 300000 --params '{"peer":"home-b","message":{"text":"你好，收到请回复"}}'
```

### 步骤 7.2 — 确认

```bash
openclaw gateway call a2a.audit
```

应有 **outbound** 且成功。中继日志应有 `POST /a2a/jsonrpc`。

---

## 第 8 章：常见报错对照

| 报错 / 现象 | 原因 | 按顺序做 |
|-------------|------|----------|
| `/workspace/plugins/a2a-gateway not found` | 旧 `plugins.load.paths` 仍指向外挂目录 | **第 2 章**清空 load.paths → 重启 Gateway → `plugins doctor` |
| `plugin not found: a2a-gateway` | 装的是官方包，或 allow 未包含 | 重做第 3、4 章 |
| `plugins list` 无 A2A | 不是定制 tgz，或未 enable | 步骤 3.2、4.1、4.2 |
| `gateway timeout after 10000ms` | CLI 等 Agent 太短 | `a2a.send` 加 `--timeout 300000` |
| `unkown error` | 常见 peer 名写错 | peer 必须等于 `peers[].name`；查 `a2a.audit` |
| 18800 连不上 | Gateway/插件未起 | 步骤 5.4、5.5，看日志 `HTTP listening` |
| 鸿蒙 `Missing config` | 未指向 `/data/local/.openclaw` | 按附录 export `OPENCLAW_*` 或改 launcher |
| `command not found: openclaw` | 全局 bin 不在 PATH | 步骤 3.3 把 npm prefix/bin 加入 PATH |

---

## 附录：鸿蒙 / Mac / 安卓差异

| 设备 | 是否按本文装 tgz | 说明 |
|------|------------------|------|
| macOS | **是**，按第 0～5 章 | 终端用 bash/zsh；配置在 `~/.openclaw/` |
| 鸿蒙 / OpenHarmony（已能跑 Node） | **是**，按第 0～5 章 | 配置优先 `/data/local/.openclaw/`；Gateway 推荐 `gateway run --force` |
| 安卓（Termux 等已能跑 Node） | **是**，按第 0～5 章 | 配置在 `~/.openclaw/`；用 Termux 终端执行 |
| 鸿蒙官方节点 App（不提供 Node shell） | **不要装 tgz** | App 不跑本文这套 Gateway CLI |

### 鸿蒙环境变量（强烈建议）

在当前 shell，或写进 `openclaw` 启动脚本：

```bash
export OPENCLAW_HOME=/data/local
export OPENCLAW_STATE_DIR=/data/local/.openclaw
export OPENCLAW_CONFIG_PATH=/data/local/.openclaw/openclaw.json
```

手机端若找不到 `node` / `npm`，同时：

```bash
export PATH="/data/local/npm/bin:/data/local/tools/node-v24.2.0-openharmony-arm64/bin:/usr/local/bin:$PATH"
```

`hdc shell` 是非交互环境，不一定会读 `.bashrc`；改 `openclaw` launcher 最稳妥。

### 传包装到设备（参考）

```bash
# 从电脑推到鸿蒙
hdc file send openclaw-2026.3.13.tgz /data/local/tmp/openclaw-2026.3.13.tgz

# 从电脑推到安卓
adb push openclaw-2026.3.13.tgz /sdcard/Download/openclaw-2026.3.13.tgz

# macOS：AirDrop / Finder 拷到下载目录即可
```

---

## 附录：重新打包（仅维护者 · 在开发机上）

> 这一节是打包发布用，不是终端用户在鸿蒙/Mac/安卓上执行的步骤。

```bash
cd /path/to/openclaw-custom
pnpm install
bash scripts/bundle-a2ui.sh
pnpm build:docker
pnpm build:plugin-sdk:dts
node --import tsx scripts/write-plugin-sdk-entry-dts.ts
pnpm pack --pack-destination /path/to/output
```

得到：`openclaw-2026.3.13.tgz`，再拷到目标设备按第 0～5 章安装。

---

## 你现在若已经报 not found：最短修复顺序

严格按下面 6 条执行，不要穿插旧文档里的 `plugins install`：

```bash
# 0) 鸿蒙先固定配置路径（Mac/安卓可跳过）
export OPENCLAW_HOME=/data/local
export OPENCLAW_STATE_DIR=/data/local/.openclaw
export OPENCLAW_CONFIG_PATH=/data/local/.openclaw/openclaw.json

# 1) 清掉错误路径
openclaw config set plugins.load.paths '[]'

# 2) 确认
openclaw config get plugins.load.paths

# 3) 安装定制包（路径按实际修改）
npm install -g "$TGZ"
# 例：npm install -g /data/local/tmp/openclaw-2026.3.13.tgz

# 4) 新开终端后再查
openclaw --version
openclaw plugins list

# 5) 若有白名单，加上 a2a-gateway 后重启 Gateway
# macOS/安卓: openclaw gateway restart
# 鸿蒙: openclaw gateway run --force --port 18789

# 6)
openclaw plugins doctor
```

若第 6 步仍出现 `/workspace/plugins/a2a-gateway`，把下面两条命令的**完整输出**发我：

```bash
openclaw config get plugins.load.paths
openclaw config get plugins
```

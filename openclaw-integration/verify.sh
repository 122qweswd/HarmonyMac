#!/bin/sh
# openclaw 集成验证脚本 —— 用法:  sh openclaw-integration/verify.sh
# App 需已在 Xcode 里 Run 起来。输出每项 ✅/❌ 并汇总。
set -u

CONT="$HOME/Library/Containers/com.HarmonyOSInterconnection.app/Data"
LOG="$CONT/Library/Logs/MutualInfectionMac/NodeRuntime"
CFG="$CONT/Library/Application Support/MutualInfectionMac/NodeRuntime/config/openclaw.json"

pass=0; fail=0
ok(){ printf "  \033[32m✅\033[0m %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  \033[31m❌\033[0m %s\n" "$1"; fail=$((fail+1)); }
hr(){ printf "\n========== %s ==========\n" "$1"; }

hr "进程链（App → openclaw → openclaw-gateway）"
if pgrep -fl openclaw >/dev/null 2>&1; then
  ps -eo pid,ppid,comm | grep -i openclaw | sed 's/^/    /'
  ok "openclaw 进程存在"
else
  no "未发现 openclaw 进程 —— App 是否已在 Xcode 里 Run 起来？"
fi

hr "Node22 修复（stderr 期望 0 个 TypeError）"
if [ -f "$LOG/stderr.log" ]; then
  n=$(grep -c "Cannot set property signal" "$LOG/stderr.log" 2>/dev/null || echo 0)
  [ "$n" = "0" ] && ok "stderr 无 signal TypeError（count=$n）" || no "stderr 仍有 $n 个 TypeError —— Node 可能还是 26"
else
  no "stderr.log 不存在: $LOG/stderr.log"
fi

hr "配置自愈 + a2a 端口分离"
if [ -f "$LOG/runtime.log" ]; then
  if grep -q "已按模板重新生成" "$LOG/runtime.log"; then
    ok "配置已按模板重新生成（configVersion 自愈生效）"
  else
    no "未见配置重生成日志 —— 容器旧配置未被覆盖"
  fi
  line=$(grep "a2a-gateway: HTTP listening" "$LOG/runtime.log" | tail -1)
  echo "    $line"
  case "$line" in *18810*) ok "a2a-gateway 监听 18810";; *) no "a2a-gateway 未监听 18810（仍 18800 或未启动）";; esac
else
  no "runtime.log 不存在: $LOG/runtime.log"
fi

hr "a2a 身份端点 18810（期望 JSON）"
body=$(curl -s -m 3 http://127.0.0.1:18810/.well-known/agent-card.json 2>/dev/null)
if echo "$body" | grep -q "protocolVersion"; then
  echo "$body" | head -c 200 | sed 's/^/    /'; echo
  ok "agent-card 返回有效 JSON（a2a-gateway 可用）"
else
  no "agent-card 无响应或非 JSON —— 端口分离可能未生效"
  echo "    返回: ${body:-（空）}"
fi

hr "主 gateway 健康 18800"
h=$(curl -s -m 3 http://127.0.0.1:18800/health 2>/dev/null)
echo "    $h"
echo "$h" | grep -q '"ok":true' && ok "主 gateway 健康" || no "主 gateway 健康检查失败"

hr "容器运行配置内容（应纯净：无 configVersion，port 18810）"
if [ -f "$CFG" ]; then
  grep -E "\"port\"|configVersion|\"mode\"" "$CFG" | sed 's/^/    /'
  grep -q '"port": 18810' "$CFG" && ok "配置 a2a port=18810" || no "配置 a2a port 非 18810"
  if grep -q "configVersion" "$CFG"; then no "openclaw.json 仍含 configVersion（会被 openclaw 严格 schema 拒绝→启动失败）"; else ok "openclaw.json 无 configVersion（schema 合法）"; fi
else
  no "配置文件不存在: $CFG"
fi
VF="$CONT/Library/Application Support/MutualInfectionMac/NodeRuntime/config/.template_version"
if [ -f "$VF" ]; then echo "    .template_version = $(cat "$VF" | tr -d ' \n')"; grep -qx "2" "$VF" && ok "旁路版本文件=2（配置已是最新）" || no "旁路版本非 2"; else no "旁路版本文件 .template_version 不存在（配置未被 App 重生成）"; fi

hr "汇总"
printf "通过 %d / 失败 %d\n" "$pass" "$fail"
if [ "$fail" = 0 ]; then
  printf "\n🎉 全部通过 —— openclaw 集成成功（Node22 + a2a 端口分离均生效）\n"
else
  printf "\n⚠️  有 %d 项未通过，请按上方 ❌ 提示排查\n" "$fail"
fi

#!/bin/bash
# Mac ↔ HarmonyOS A2A 双向消息/文件测试
set -u

PHONE_IP="10.86.84.12"
MAC_IP="10.86.84.245"
PHONE_A2A="http://${PHONE_IP}:18800"
MAC_A2A="http://${MAC_IP}:18810"
A2A_TOKEN="12345678"
GATEWAY_TOKEN="openclaw-token"
PHONE_FIXTURE="/data/local/.openclaw/workspace/a2a-fixtures/phone-to-pc-test.txt"
PHONE_RECEIVE_DIR="/storage/media/100/local/files/Docs/OPENCLAW"
MAC_WORKSPACE="/Users/jiahaoli/Agent_Workspace"
CONT="$HOME/Library/Containers/com.HarmonyOSInterconnection.app/Data"
STATE_DIR="$CONT/Library/Application Support/MutualInfectionMac/NodeRuntime/state"
CFG="$CONT/Library/Application Support/MutualInfectionMac/NodeRuntime/config/openclaw.json"
HDC="/tmp/hdc-tool/command-line-tools/sdk/default/openharmony/toolchains/hdc"
pass=0
fail=0

ok() { printf '✅ %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '❌ %s\n' "$1"; fail=$((fail + 1)); }
section() { printf '\n========== %s ==========\n' "$1"; }

section '1. 查找 Mac 内置 Node/OpenClaw'
APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/*/鸿蒙星河互联.app' -type d -print 2>/dev/null | while IFS= read -r p; do stat -f '%m %N' "$p"; done | sort -rn | cut -d' ' -f2- | head -1)"
NODE_BIN="$APP/Contents/Resources/NodeRuntime/node/bin/node"
OPENCLAW_MJS="$APP/Contents/Resources/NodeRuntime/openclaw/openclaw.mjs"
if [ -x "$NODE_BIN" ] && [ -f "$OPENCLAW_MJS" ]; then
  echo "App: $APP"
  ok '内置 Node/OpenClaw 已找到'
else
  bad "未找到内置 Node/OpenClaw: $APP"
  exit 1
fi

section '2. 检查双方 Agent Card'
PHONE_CARD=$(curl -fsS --max-time 8 "$PHONE_A2A/.well-known/agent-card.json" 2>/dev/null || true)
printf '%s' "$PHONE_CARD" | grep -q 'HW-Phone1-Agent1' && ok '手机 Agent Card 可达' || bad '手机 Agent Card 不可达'
MAC_CARD=$(curl -fsS --max-time 8 "$MAC_A2A/.well-known/agent-card.json" 2>/dev/null || true)
printf '%s' "$MAC_CARD" | grep -q 'TargetMac' && ok 'Mac Agent Card 可达' || bad 'Mac Agent Card 不可达'

section '3. Mac → 手机文本（直接 A2A）'
BODY='{"jsonrpc":"2.0","id":"mac-msg","method":"message/send","params":{"message":{"messageId":"mac-msg","role":"user","parts":[{"kind":"text","text":"Mac到手机消息测试：MAC_TO_PHONE_OK"}]},"configuration":{}}}'
RESULT=$(curl -fsS --max-time 120 -H 'Content-Type: application/json' -H "Authorization: Bearer $A2A_TOKEN" --data-binary "$BODY" "$PHONE_A2A/a2a/jsonrpc" 2>/dev/null || true)
printf '%s' "$RESULT" | grep -q 'completed\|taskId\|MAC_TO_PHONE_OK' && ok 'Mac → 手机文本请求已接受' || { bad 'Mac → 手机文本失败'; printf '%s\n' "$RESULT"; }

section '4. 手机 → Mac 文本（直接 A2A）'
BODY='{"jsonrpc":"2.0","id":"phone-msg","method":"message/send","params":{"message":{"messageId":"phone-msg","role":"user","parts":[{"kind":"text","text":"手机到Mac消息测试：PHONE_TO_MAC_OK"}]},"configuration":{}}}'
RESULT=$(curl -fsS --max-time 120 -H 'Content-Type: application/json' -H "Authorization: Bearer $A2A_TOKEN" --data-binary "$BODY" "$MAC_A2A/a2a/jsonrpc" 2>/dev/null || true)
printf '%s' "$RESULT" | grep -q 'completed\|taskId\|PHONE_TO_MAC_OK' && ok '手机 → Mac 文本请求已接受' || { bad '手机 → Mac 文本失败'; printf '%s\n' "$RESULT"; }

section '5. Mac → 手机文件（gateway method）'
mkdir -p "$MAC_WORKSPACE"
MAC_FILE="$MAC_WORKSPACE/mac-to-phone.txt"
printf 'MAC_TO_PHONE_FILE_OK\ncreated=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" > "$MAC_FILE"
export OPENCLAW_HOME="$CONT/Library/Application Support/MutualInfectionMac/NodeRuntime"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_CONFIG_PATH="$CFG"
PARAMS=$(printf '{"peer":"HW-Phone1","path":"%s"}' "$MAC_FILE")
RESULT=$("$NODE_BIN" "$OPENCLAW_MJS" gateway call a2a.send_local_file --url=ws://127.0.0.1:18800 --token="$GATEWAY_TOKEN" --timeout=300000 --params="$PARAMS" 2>&1 || true)
printf '%s' "$RESULT" | grep -qi 'success\|accepted\|taskId' && ok 'Mac → 手机文件请求已接受' || { bad 'Mac → 手机文件失败'; printf '%s\n' "$RESULT"; }

section '6. 手机 → Mac 文件（手机 gateway method）'
if [ ! -x "$HDC" ]; then
  bad "找不到 HDC: $HDC"
else
  PHONE_PARAMS=$(printf '{"peer":"TargetMac","path":"%s"}' "$PHONE_FIXTURE")
  RESULT=$("$HDC" shell "/data/local/npm/bin/openclaw gateway call a2a.send_local_file --token=openclaw-token --timeout=300000 --params='$PHONE_PARAMS'" 2>&1 || true)
  printf '%s' "$RESULT" | grep -qi 'success\|accepted\|taskId' && ok '手机 → Mac 文件请求已接受' || { bad '手机 → Mac 文件失败'; printf '%s\n' "$RESULT"; }
fi

section '7. 文件结果（只读检查）'
echo '手机收件目录：'
[ -x "$HDC" ] && "$HDC" shell "find '$PHONE_RECEIVE_DIR' -maxdepth 1 -type f 2>/dev/null | tail -10"
echo 'Mac 收件目录：'
find "$STATE_DIR" -type f \( -name 'phone-to-pc-test.txt' -o -name 'mac-to-phone.txt' \) -print 2>/dev/null
printf '\n结果：通过 %d，失败 %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

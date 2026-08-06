#!/bin/sh
# 诊断：openclaw 为什么没在跑。用法:  sh openclaw-integration/diagnose.sh
set -u
CONT="$HOME/Library/Containers/com.HarmonyOSInterconnection.app/Data"
LOG="$CONT/Library/Logs/MutualInfectionMac/NodeRuntime"
APP="$HOME/Library/Developer/Xcode/DerivedData/MutualInfection-bxgilxwpglwwkncstnzvvzhpokej/Build/Products/Release/鸿蒙星河互联.app"

echo "########## 1. App 主进程 / openclaw 进程 ##########"
ps aux | grep -iE "鸿蒙星河|HarmonyOS|openclaw" | grep -v grep | awk '{print $2, $3, $11, $12, $13}' || echo "  (无)"

echo ""
echo "########## 2. 当前 188xx 端口监听 ##########"
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -E "1880|node|openclaw" || echo "  无 188xx 监听 → openclaw 确实没在跑"

echo ""
echo "########## 3. bundle 内私有 Node 版本（确认构建是否换成 22）##########"
if [ -x "$APP/Contents/Resources/NodeRuntime/node/bin/node" ]; then
  "$APP/Contents/Resources/NodeRuntime/node/bin/node" --version 2>&1
else
  echo "  ❌ bundle 内 node 不存在/不可执行（构建可能没跑 Build Phase）"
fi

echo ""
echo "########## 4. runtime.log 最后 25 行（看今天 8/5 有无新记录）##########"
tail -25 "$LOG/runtime.log" 2>/dev/null || echo "  runtime.log 不存在"

echo ""
echo "########## 5. stderr.log 最后 25 行（看今天有无新报错）##########"
tail -25 "$LOG/stderr.log" 2>/dev/null || echo "  stderr.log 不存在"

echo ""
echo "########## 6. 容器配置确认 ##########"
cat "$CONT/Library/Application Support/MutualInfectionMac/NodeRuntime/config/openclaw.json" 2>/dev/null | grep -E "configVersion|port|mode" || echo "  配置不存在"

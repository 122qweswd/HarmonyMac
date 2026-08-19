#!/bin/sh
# aajax 代理能力探测：确认它支持哪种 API 格式 / 流式。
# 用法：ANTHROPIC_AUTH_TOKEN='你的token' sh openclaw-integration/probe_aajax.sh
set -u

TOKEN="${ANTHROPIC_AUTH_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "❌ 未检测到 token。请用："
  echo "   ANTHROPIC_AUTH_TOKEN='你的token' sh openclaw-integration/probe_aajax.sh"
  exit 1
fi

BASE="https://api.aip.aajax.top:20443"
TMP=$(mktemp -d)

# 用 printf 写文件，避免 heredoc / 终端折行破坏 JSON
printf '%s' '{"model":"gpt-5.6-luna","messages":[{"role":"user","content":"reply OK only"}],"stream":false,"max_tokens":20}' > "$TMP/openai-nostream.json"
printf '%s' '{"model":"gpt-5.6-luna","messages":[{"role":"user","content":"reply OK only"}],"stream":false,"max_tokens":20}' > "$TMP/anthropic-nostream.json"
printf '%s' '{"model":"gpt-5.6-luna","messages":[{"role":"user","content":"reply OK only"}],"stream":true,"max_tokens":20}'  > "$TMP/openai-stream.json"

echo "=== 测试A: OpenAI 非流式 (/v1/chat/completions, stream=false) ==="
curl -sS "$BASE/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @"$TMP/openai-nostream.json"
echo ""

echo ""
echo "=== 测试B: Anthropic 非流式 (/v1/messages, stream=false) ==="
curl -sS "$BASE/v1/messages" \
  -H "x-api-key: $TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  --data @"$TMP/anthropic-nostream.json"
echo ""

echo ""
echo "=== 测试C: OpenAI 流式 (/v1/chat/completions, stream=true) ==="
curl -sS -N "$BASE/v1/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @"$TMP/openai-stream.json" | head -20
echo ""

rm -rf "$TMP"
echo ""
echo "=== 完成 ==="

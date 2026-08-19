#!/usr/bin/env python3
"""Minimal interactive client for the local OpenClaw A2A JSON-RPC endpoint."""
"""该文件可以用于在Openclaw启动后进行本地多轮对话尝试。提示：重新编译时如果Openclaw提示无法绑定端口，则是Openclaw没有自动退出，需要手动pkill -9 openclaw等"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


DEFAULT_ENDPOINT = "http://127.0.0.1:18810/a2a/jsonrpc"
CHAT_DIR = Path(__file__).resolve().parent / "chat"


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def session_path(value: str) -> Path:
    path = Path(value)
    if path.suffix != ".json":
        path = path.with_suffix(".json")
    return path if path.is_absolute() else CHAT_DIR / path.name


def write_session(path: Path, session: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(".tmp")
    temp_path.write_text(json.dumps(session, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp_path.replace(path)


def load_session(path: Path, endpoint: str) -> dict[str, Any]:
    if not path.exists():
        return {"context_id": str(uuid.uuid4()), "endpoint": endpoint, "messages": []}

    try:
        session = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"无法读取会话文件 {path}: {error}") from error

    if not isinstance(session, dict) or not isinstance(session.get("context_id"), str):
        raise ValueError(f"无效的会话文件: {path}")
    if not isinstance(session.get("messages"), list):
        session["messages"] = []
    session.setdefault("endpoint", endpoint)
    return session


def call_a2a(endpoint: str, context_id: str, text: str) -> str:
    message_id = str(uuid.uuid4())
    payload = {
        "jsonrpc": "2.0",
        "id": message_id,
        "method": "message/send",
        "params": {
            "message": {
                "messageId": message_id,
                "contextId": context_id,
                "role": "user",
                "parts": [{"kind": "text", "text": text}],
            },
            "blocking": True,
        },
    }
    request = Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=310) as response:
            body = json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        raise RuntimeError(f"HTTP {error.code}: {error.read().decode('utf-8', 'replace')}") from error
    except URLError as error:
        raise RuntimeError(f"无法连接 A2A 服务 {endpoint}: {error.reason}") from error

    if "error" in body:
        raise RuntimeError(f"A2A 错误: {body['error'].get('message', body['error'])}")

    result = body.get("result", {})
    status = result.get("status", {})
    if status.get("state") != "completed":
        message = status.get("message", {})
        raise RuntimeError(f"任务状态为 {status.get('state', 'unknown')}: {part_text(message)}")

    return part_text(status.get("message", {}))


def part_text(message: Any) -> str:
    if not isinstance(message, dict):
        return ""
    texts = [part.get("text", "") for part in message.get("parts", []) if part.get("kind") == "text"]
    return "\n".join(text for text in texts if isinstance(text, str))


def list_sessions() -> None:
    if not CHAT_DIR.exists():
        return
    for path in sorted(CHAT_DIR.glob("*.json")):
        try:
            session = json.loads(path.read_text(encoding="utf-8"))
            print(f"{path.name}\t{session.get('context_id', '?')}\t{len(session.get('messages', []))} messages")
        except (OSError, json.JSONDecodeError):
            print(f"{path.name}\t<invalid>")


def main() -> int:
    parser = argparse.ArgumentParser(description="Interact with an OpenClaw A2A agent.")
    parser.add_argument("--session", help="会话文件名或绝对路径；存在时继续该对话")
    parser.add_argument("--new", help="新建会话文件名")
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT, help=f"A2A JSON-RPC endpoint (default: {DEFAULT_ENDPOINT})")
    parser.add_argument("--list", action="store_true", help="列出 qol/chat 下的会话")
    args = parser.parse_args()

    if args.list:
        list_sessions()
        return 0
    if args.session and args.new:
        parser.error("--session 和 --new 不能同时使用")

    name = args.session or args.new or f"chat-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    path = session_path(name)
    try:
        session = load_session(path, args.endpoint)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2

    endpoint = args.endpoint if args.new or not path.exists() else str(session["endpoint"])
    session["endpoint"] = endpoint
    write_session(path, session)
    print(f"会话: {path}\ncontextId: {session['context_id']}\n输入 /exit 退出。")

    while True:
        try:
            text = input("you> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0
        if text in {"/exit", "/quit"}:
            return 0
        if not text:
            continue

        session["messages"].append({"role": "user", "text": text, "timestamp": now()})
        write_session(path, session)
        try:
            reply = call_a2a(endpoint, session["context_id"], text)
        except RuntimeError as error:
            print(f"error> {error}", file=sys.stderr)
            continue

        session["messages"].append({"role": "agent", "text": reply, "timestamp": now()})
        write_session(path, session)
        print(f"agent> {reply}")


if __name__ == "__main__":
    raise SystemExit(main())

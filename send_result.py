# -*- coding: utf-8 -*-
"""
Claude Code Stop hook —— 任务完成后把结果推送到企业微信。

用法：
  1) 由 Stop hook 调用：Claude 每轮任务结束后，本脚本从 stdin 收到 Stop 事件
     JSON（含 transcript_path），自动抽取 Claude 的最后一条文本回复作为"结果"发送。
  2) 手动测试：  echo "测试消息" | py send_result.py
  3) 发文件内容：py send_result.py --file result.txt

仅用标准库（urllib），无需安装 requests。
"""
import json
import os
import sys
import time
import urllib.request

WEBHOOK_URL = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=123155b3-8575-4f2c-923b-e3e4eec5485a"

# 企业微信 text 消息 content 上限约 2048 字节，留一点余量
MAX_BYTES = 2000


def log(msg):
    """只写到 stderr，避免污染 stdout（hook 会把 stdout 当作 decision JSON 解析）。"""
    try:
        sys.stderr.write("[send_result] " + msg + "\n")
        sys.stderr.flush()
    except Exception:
        pass


def read_stdin():
    return sys.stdin.buffer.read().decode("utf-8", errors="replace")


def read_file(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-8", errors="replace")


def truncate_utf8(s, max_bytes):
    b = s.encode("utf-8")
    if len(b) <= max_bytes:
        return s
    cut = b[: max_bytes - 3]  # 预留 "…" 三字节
    return cut.decode("utf-8", errors="ignore") + "…"


def send_text(content):
    payload = {"msgtype": "text", "text": {"content": content}}
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        WEBHOOK_URL, data=data,
        headers={"Content-Type": "application/json"}, method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        return "EXCEPTION: %s" % e


def extract_last_assistant_text(transcript_path):
    """读取 transcript JSONL，返回 Claude 最后一条文本回复。"""
    if not transcript_path or not os.path.exists(transcript_path):
        return None
    last = None
    with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            if not isinstance(obj, dict) or obj.get("type") != "assistant":
                continue
            content = (obj.get("message") or {}).get("content") or []
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get("type") == "text" and c.get("text"):
                        last = c["text"]
    return last


def main():
    file_path = None
    args = sys.argv[1:]
    if "--file" in args:
        i = args.index("--file")
        if i + 1 < len(args):
            file_path = args[i + 1]

    raw = read_stdin() if not sys.stdin.isatty() else ""

    if file_path:
        content = read_file(file_path).strip()
    else:
        obj = None
        try:
            obj = json.loads(raw.strip()) if raw.strip() else None
        except Exception:
            obj = None

        if isinstance(obj, dict) and obj.get("transcript_path"):
            # Stop 事件：抽取最后一条回复作为"结果"
            result = extract_last_assistant_text(obj.get("transcript_path"))
            head = "✅ Claude 任务已完成\n时间：%s\n目录：%s\n\n" % (
                time.strftime("%Y-%m-%d %H:%M:%S"), obj.get("cwd", ""))
            content = head + (result if result else "（本轮没有文本输出）")
        else:
            content = raw.strip() or "（空消息）"

    content = truncate_utf8(content, MAX_BYTES)
    resp = send_text(content)
    log("发送结果: %s" % resp)
    # 通知脚本永远不拦截流程（fail-open），保持 stdout 为空并 exit 0。
    sys.exit(0)


if __name__ == "__main__":
    main()

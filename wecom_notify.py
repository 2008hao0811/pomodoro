# -*- coding: utf-8 -*-
"""企业微信群机器人通知工具（webhook）。

生成简报后，调用 notify_brief_generated() 向企业微信群推送一条
简短通知（标题 + 保存路径）。仅用标准库，无额外依赖。
"""
import json
import urllib.request

# 企业微信群机器人 webhook（硬编码）
WEBHOOK_URL = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=123155b3-8575-4f2c-923b-e3e4eec5485a"


def send_text(content):
    """发送一条 text 消息到企业微信群，返回 (ok, resp)。"""
    payload = {
        "msgtype": "text",
        "text": {"content": content},
    }
    req = urllib.request.Request(
        WEBHOOK_URL,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode("utf-8")
            result = json.loads(body)
            return result.get("errcode") == 0, body
    except Exception as e:  # noqa: BLE001
        return False, str(e)


def notify_brief_generated(title, path):
    """简报生成完成后发送通知：标题 + 保存路径。"""
    content = "📄 %s 已生成\n保存位置：%s" % (title, path)
    ok, resp = send_text(content)
    print("WECOM:", "OK" if ok else "FAIL", resp)
    return ok


if __name__ == "__main__":
    # 直接运行本文件可发一条测试消息，验证 webhook 连通性
    notify_brief_generated("测试", "（这是一条 webhook 连通性测试）")

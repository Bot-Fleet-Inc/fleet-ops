#!/usr/bin/env python3
"""
register-telegram-stickers.py
Bot Fleet Inc — Telegram sticker pack registration script.

Usage:
  TELEGRAM_BOT_TOKEN=<token> GITHUB_TOKEN=<token> python3 register-telegram-stickers.py

Registers the BFI sticker pack via Telegram Bot API using assets from
Bot-Fleet-Inc/design-bot @ design-system/stickers/.

Pack: https://t.me/addstickers/BotFleetInc_by_coding_bfi_bot
Registered: 2026-03-07 by coding-bot (fleet-ops#57)
"""

import urllib.request
import os
import json

BOT_TOKEN  = os.environ["TELEGRAM_BOT_TOKEN"]
GH_TOKEN   = os.environ["GITHUB_TOKEN"]
USER_ID    = 8042837220   # Jørgen Scheel — pack owner
PACK_NAME  = "BotFleetInc_by_coding_bfi_bot"
PACK_TITLE = "Bot Fleet Inc"
DESIGN_BOT_REF = "12aee57"
BASE_TG    = f"https://api.telegram.org/bot{BOT_TOKEN}"

STICKER_MAP = [
    ("dispatch-sticker.png",  "📡"),
    ("design-sticker.png",    "🎨"),
    ("audit-sticker.png",     "🔍"),
    ("coding-sticker.png",    "⚙️"),
    ("archi-sticker.png",     "📐"),
    ("infra-sticker.png",     "🔧"),
    ("emoji-in-the-zone.png", "🎧"),
]


def fetch_sticker(filename: str) -> bytes:
    url = (
        f"https://api.github.com/repos/Bot-Fleet-Inc/design-bot/contents"
        f"/design-system/stickers/{filename}?ref={DESIGN_BOT_REF}"
    )
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {GH_TOKEN}",
        "Accept": "application/vnd.github.raw",
    })
    with urllib.request.urlopen(req) as r:
        return r.read()


def multipart_encode(fields: dict, files: list) -> tuple[bytes, bytes]:
    boundary = b"----BFIBoundary7892347"
    body = b""
    for k, v in fields.items():
        body += b"--" + boundary + b"\r\n"
        body += f'Content-Disposition: form-data; name="{k}"\r\n\r\n'.encode()
        body += str(v).encode() + b"\r\n"
    for fname, fdata, ftype in files:
        body += b"--" + boundary + b"\r\n"
        body += f'Content-Disposition: form-data; name="{fname}"; filename="{fname}.png"\r\n'.encode()
        body += f"Content-Type: {ftype}\r\n\r\n".encode()
        body += fdata + b"\r\n"
    body += b"--" + boundary + b"--\r\n"
    return body, b"multipart/form-data; boundary=" + boundary


def tg_post(method: str, fields: dict, files: list | None = None) -> dict:
    if files is None:
        data = json.dumps(fields).encode()
        req = urllib.request.Request(
            f"{BASE_TG}/{method}", data=data,
            headers={"Content-Type": "application/json"},
        )
    else:
        body, ct = multipart_encode(fields, files)
        req = urllib.request.Request(
            f"{BASE_TG}/{method}", data=body,
            headers={"Content-Type": ct.decode()},
        )
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read())


def main():
    print(f"Registering Telegram sticker pack: {PACK_NAME}")
    print(f"Owner user_id: {USER_ID}\n")

    # Create pack with first sticker
    fname, emoji = STICKER_MAP[0]
    print(f"Creating pack with first sticker: {fname} {emoji}")
    fdata = fetch_sticker(fname)
    result = tg_post("createNewStickerSet", {
        "user_id": USER_ID,
        "name": PACK_NAME,
        "title": PACK_TITLE,
        "sticker_format": "static",
        "stickers": json.dumps([{
            "sticker": "attach://sticker0",
            "format": "static",
            "emoji_list": [emoji],
        }]),
    }, files=[("sticker0", fdata, "image/png")])

    if not result.get("ok"):
        if "already" in result.get("description", "").lower():
            print(f"Pack already exists — skipping create, adding remaining stickers.")
        else:
            raise RuntimeError(f"createNewStickerSet failed: {result}")
    else:
        print(f"  ✓ Pack created\n")

    # Add remaining stickers
    for i, (fname, emoji) in enumerate(STICKER_MAP[1:], start=1):
        fdata = fetch_sticker(fname)
        r = tg_post("addStickerToSet", {
            "user_id": USER_ID,
            "name": PACK_NAME,
            "sticker": json.dumps({
                "sticker": f"attach://sticker{i}",
                "format": "static",
                "emoji_list": [emoji],
            }),
        }, files=[(f"sticker{i}", fdata, "image/png")])

        status = "✓" if r.get("ok") else f"✗ {r.get('description', '')}"
        print(f"  {status}  {fname} {emoji}")

    pack_link = f"https://t.me/addstickers/{PACK_NAME}"
    print(f"\n✅ Done! Pack link: {pack_link}")


if __name__ == "__main__":
    main()

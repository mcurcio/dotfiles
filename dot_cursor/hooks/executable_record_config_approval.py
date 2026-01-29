#!/usr/bin/env python3
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict

STATE_DIR = Path("/Users/matt.curcio/.cursor/hooks/state")
APPROVALS_PATH = STATE_DIR / "approvals.json"


def _safe_json_load(path: Path) -> Dict[str, Any]:
    try:
        data = json.loads(path.read_text("utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _safe_json_load_stdin() -> Dict[str, Any]:
    try:
        data = json.loads(sys.stdin.read())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _write_json(path: Path, obj: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(obj, indent=2, sort_keys=True), "utf-8")
    os.replace(tmp, path)


def main() -> None:
    payload = _safe_json_load_stdin()
    prompt = (payload.get("prompt") or "").strip().lower()
    conversation_id = payload.get("conversation_id") or payload.get("session_id") or ""

    # Always allow the prompt submission to proceed.
    response: Dict[str, Any] = {"continue": True}

    if not conversation_id:
        sys.stdout.write(json.dumps(response) + "\n")
        return

    approve_phrases = [
        "approve config edits",
        "approve cursor config edits",
        "approve environment edits",
        "approve environment changes",
    ]
    revoke_phrases = [
        "revoke config edits",
        "revoke cursor config edits",
        "revoke environment edits",
    ]

    approvals = _safe_json_load(APPROVALS_PATH)

    now = datetime.now(timezone.utc)
    expires_at = (now + timedelta(hours=1)).isoformat()

    if any(p in prompt for p in approve_phrases):
        approvals[conversation_id] = {
            "config_edits": True,
            "expires_at": expires_at,
        }
        _write_json(APPROVALS_PATH, approvals)

    if any(p in prompt for p in revoke_phrases):
        if conversation_id in approvals:
            approvals.pop(conversation_id, None)
            _write_json(APPROVALS_PATH, approvals)

    sys.stdout.write(json.dumps(response) + "\n")


if __name__ == "__main__":
    main()

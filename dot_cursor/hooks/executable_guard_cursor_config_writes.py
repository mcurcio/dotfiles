#!/usr/bin/env python3
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

APPROVALS_PATH = Path("/Users/matt.curcio/.cursor/hooks/state/approvals.json")


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


def _get_path(tool_input: Any) -> Optional[str]:
    if not isinstance(tool_input, dict):
        return None
    for key in ("path", "file_path", "filePath", "target", "filename"):
        val = tool_input.get(key)
        if isinstance(val, str) and val:
            return val
    return None


def _is_sensitive_path(path: str) -> bool:
    p = path

    # User-level Cursor config
    if p.startswith("/Users/matt.curcio/.cursor/"):
        return True

    # Project-level Cursor config
    if "/.cursor/" in p:
        # focus on rules/hooks/agents/skills inside project
        if any(seg in p for seg in ("/.cursor/rules/", "/.cursor/agents/", "/.cursor/skills/", "/.cursor/hooks")):
            return True

    return False


def _has_valid_approval(conversation_id: str) -> bool:
    approvals = _safe_json_load(APPROVALS_PATH)
    entry = approvals.get(conversation_id)
    if not isinstance(entry, dict):
        return False
    if entry.get("config_edits") is not True:
        return False
    expires_at = entry.get("expires_at")
    if not isinstance(expires_at, str) or not expires_at:
        return True
    try:
        exp = datetime.fromisoformat(expires_at)
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        return exp > datetime.now(timezone.utc)
    except Exception:
        return True


def main() -> None:
    payload = _safe_json_load_stdin()
    tool_name = payload.get("tool_name") or ""
    tool_input = payload.get("tool_input")
    conversation_id = payload.get("conversation_id") or ""

    # Default allow
    allow = {"decision": "allow"}

    if tool_name not in {"Write", "Delete", "ApplyPatch", "Edit"}:
        sys.stdout.write(json.dumps(allow) + "\n")
        return

    path = _get_path(tool_input)
    if not path or not _is_sensitive_path(path):
        sys.stdout.write(json.dumps(allow) + "\n")
        return

    if conversation_id and _has_valid_approval(conversation_id):
        sys.stdout.write(json.dumps(allow) + "\n")
        return

    sys.stdout.write(
        json.dumps(
            {
                "decision": "deny",
                "reason": "Blocked: editing Cursor configuration requires explicit approval. Reply with 'approve config edits' and then retry the action.",
            }
        )
        + "\n"
    )


if __name__ == "__main__":
    main()

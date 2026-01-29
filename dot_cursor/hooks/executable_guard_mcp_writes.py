#!/usr/bin/env python3
import json
import sys
from typing import Any, Dict


OBSIDIAN_WRITE_TOOLS = {
    "write_note",
    "patch_note",
    "update_frontmatter",
    "move_note",
    "delete_note",
}

ATLASSIAN_WRITE_TOOLS = {
    # Jira
    "createJiraIssue",
    "editJiraIssue",
    "transitionJiraIssue",
    "addCommentToJiraIssue",
    "addWorklogToJiraIssue",
    # Confluence
    "createConfluencePage",
    "updateConfluencePage",
    "createConfluenceInlineComment",
    "createConfluenceFooterComment",
}


def _safe_json_load(stdin_text: str) -> Dict[str, Any]:
    try:
        data = json.loads(stdin_text)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _json_out(obj: Dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(obj) + "\n")


def _tool_target(tool_name: str, tool_input: Dict[str, Any]) -> str:
    # Obsidian
    if tool_name in OBSIDIAN_WRITE_TOOLS:
        path = tool_input.get("path") or tool_input.get("oldPath") or ""
        return f"note: {path}".strip()
    if tool_name == "manage_tags":
        path = tool_input.get("path") or ""
        op = tool_input.get("operation") or ""
        return f"note: {path} (tags {op})".strip()

    # Atlassian
    if tool_name in {"createJiraIssue", "editJiraIssue", "transitionJiraIssue", "addCommentToJiraIssue", "addWorklogToJiraIssue"}:
        key = tool_input.get("issueKey") or tool_input.get("issueId") or tool_input.get("parent") or ""
        project = tool_input.get("projectKey") or ""
        return f"jira: {key or project}".strip()

    if tool_name in {"createConfluencePage", "updateConfluencePage", "createConfluenceInlineComment", "createConfluenceFooterComment"}:
        page_id = tool_input.get("pageId") or tool_input.get("contentId") or tool_input.get("parentId") or ""
        space = tool_input.get("spaceKey") or ""
        return f"confluence: {page_id or space}".strip()

    return ""


def main() -> None:
    payload = _safe_json_load(sys.stdin.read())
    tool_name = payload.get("tool_name") or payload.get("toolName") or ""
    tool_input_raw = payload.get("tool_input")
    tool_input = tool_input_raw if isinstance(tool_input_raw, dict) else {}

    # manage_tags is conditional write
    if tool_name == "manage_tags":
        op = (tool_input.get("operation") or "").lower()
        if op == "list":
            _json_out({"permission": "allow"})
            return
        target = _tool_target(tool_name, tool_input)
        _json_out(
            {
                "permission": "ask",
                "user_message": f"Approve Obsidian tag update? ({target})",
                "agent_message": f"Blocked pending approval: MCP tool `{tool_name}` will modify {target}.",
            }
        )
        return

    if tool_name in OBSIDIAN_WRITE_TOOLS:
        target = _tool_target(tool_name, tool_input)
        _json_out(
            {
                "permission": "ask",
                "user_message": f"Approve Obsidian write? ({target})",
                "agent_message": f"Blocked pending approval: MCP tool `{tool_name}` will modify {target}.",
            }
        )
        return

    if tool_name in ATLASSIAN_WRITE_TOOLS:
        target = _tool_target(tool_name, tool_input)
        _json_out(
            {
                "permission": "ask",
                "user_message": f"Approve Jira/Confluence write? ({target})",
                "agent_message": f"Blocked pending approval: MCP tool `{tool_name}` will modify {target}.",
            }
        )
        return

    # Default: allow reads/searches and unknown tools
    _json_out({"permission": "allow"})


if __name__ == "__main__":
    main()

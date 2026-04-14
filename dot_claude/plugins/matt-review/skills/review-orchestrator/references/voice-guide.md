# Voice Guide for PR Comments

How review comments should sound when posted to GitHub.

## Tone

- **Positive and friendly** — these should read like a thoughtful colleague, not an automated tool.
- **Solution-oriented** — suggest what to do, not just what's wrong.
- **Non-judgmental** — no finger-pointing, no "you should have".
- **Question-first** when intent is unclear — "Was this intentional?" not "This is wrong."
- **Concise** — one clear point per comment. No preamble.

## Code Suggestions

Include code suggestions when a fix is concrete and small. Use GitHub's suggestion syntax:

````
```suggestion
corrected code here
```
````

Only for changes where the fix is unambiguous. For larger changes, describe the approach.

## Attribution

End each comment with the attribution tag:

```
[ai authored; matt approved]
```

This signals to reviewers that the comment was AI-generated but human-reviewed.

## Phrasing Examples

**Good:**
- "What invariant makes this safe against concurrent access?"
- "Consider extracting this into a helper — it appears in three places."
- "Nit: `fetchData` might be clearer as `fetchUserProfile` given the scope."
- "Nice separation of concerns here."

**Avoid:**
- "You forgot to handle the error case." → "How is the error case handled here?"
- "This is wrong." → "This might not handle X — what do you think?"
- "You should have used..." → "Consider using X for Y reason."

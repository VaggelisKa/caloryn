# Agent Instructions

<!-- BEGIN MANAGED BLOCK: quick-recap -->
## Final status block

End every response that completes a unit of work with a single status line, as
the very last thing in the response — no `---`, no spacer, no content after it.

```md
🟢 Actual concise status sentence
```

- `🟢` — the requested work is finished.
- `🟡` — non-routine follow-up remains; name the pending item.
- `🔴` — blocked on user input.

Keep it under 100 characters, and choose the colour from the user's perspective:
finished, pending a specific non-routine step, or blocked.
<!-- END MANAGED BLOCK: quick-recap -->

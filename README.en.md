# CopyShelf

A Windows snippet launcher — quickly search and paste text snippets you've configured in advance.

[中文 README](./README.md)

## Why

The text snippets you reach for daily (Git commands, code fragments, LLM prompts, canned replies…) end up scattered across notes, chat logs, and shell history, and you dig for them every time. CopyShelf keeps them in one place: press a hotkey to summon a search box, type a keyword, hit Enter, and it pastes into the window you were just in.

> CopyShelf is **not** a clipboard-history tool — it never captures your system clipboard history. It only manages snippets you deliberately configure.

## Features

- **Global hotkey** — `Ctrl+Alt+V` by default, customizable; shows a clear error and lets you rebind if the combo is already taken.
- **Spotlight-style search** — live keyword filtering with pinyin support, ordered by **frecency** (frequency × recency).
- **Paste to target window** — writes the clipboard and simulates `Ctrl+V` into the window that was focused when you summoned CopyShelf.
- **Alt+1..9** — paste the Nth result directly, no arrow keys.
- **Placeholder templates** (opt-in per snippet) — `{name}` fields prompt a fill-in form; built-in `{date}` / `{time}` / `{datetime}` / `{clipboard}` auto-resolve; `{name:default}` supports defaults. Non-template snippets (commands, JSON with literal braces) paste verbatim.
- **Terminal multi-line guard** — pasting a multi-line snippet into a terminal asks for confirmation first, so it isn't run line by line.
- **Pin** — pinned snippets always sort to the top.
- **Importers** — PowerShell (PSReadLine) history and VS Code user snippets (tabstops converted to placeholders).
- **Git multi-device sync** — auto commit/push on change, pull on startup, with a status indicator; first-run bootstrap adopts the remote automatically on a fresh device.
- **Snippet history & rollback** — restore any snippet to a past version from git history.
- **Dark mode** — follow system / light / dark.
- **Single-instance** — launching again wakes the running instance.
- **Autostart** — optional launch on Windows login; lives in the system tray.

> Pasting a snippet takes over the system clipboard (the previous content is not restored); the pasted snippet stays there for another `Ctrl+V`.

## Quick start

> Requires [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) 3.10+ (Windows).

```bash
git clone https://github.com/qpzm7903/CopyShelf.git
cd CopyShelf
flutter pub get
flutter run -d windows
```

Prebuilt Windows binaries are attached to each [GitHub Release](https://github.com/qpzm7903/CopyShelf/releases).

## First run

Zero configuration: CopyShelf starts in the tray and works immediately with a local snippet store. To sync across devices, open Settings and set a Git remote — a fresh device adopts the remote's snippets automatically.

## License

See [LICENSE](./LICENSE).

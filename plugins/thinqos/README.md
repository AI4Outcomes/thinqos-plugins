# thinqOS

thinqOS gives your AI a Mind of your own: what you have told it, what you decided and why, and how you like work done. The Mind lives outside any one AI, so the same memory follows you between Claude, ChatGPT, Claude Code and Codex.

## What this plugin contains

- **Connection to thinqOS** (`mcp.json`): one server, `https://app.thinqos.com/mcp`. You sign in with your thinqOS account the first time a tool is used. No keys or secrets are stored in the plugin.
- **Skill** (`skills/remembering`): tells the assistant when to look something up in your Mind, when to ask it before acting, and when to save what it learned.
- **Hooks for Claude Code** (`.claude-plugin/hooks.json`): bring relevant memory in at the start of a session and with each prompt, and save the session to your Mind as you work. They run the thinqOS command-line tool, which you install once with `uv tool install thinqos` and `thinqos install`. On Codex the command-line tool installs its own hooks, so this plugin adds none there.

## Requirements

A thinqOS account with preview access. Request access at https://thinqos.com/get-started.

## Privacy

What is captured and how it is kept is described in the thinqOS privacy policy: https://thinqos.com/privacy. You can revoke the connection at any time from your thinqOS settings.

## Support

hello@thinqos.com

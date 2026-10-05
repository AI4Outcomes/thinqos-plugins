# thinqos-plugins

Official AI4Outcomes plugin marketplace for Claude Code and Codex.

## thinqOS Mind plugin

Gives Claude Code and Codex a persistent Mind backed by [thinqOS](https://thinqos.com):

- **Prime**: reflexive memory recall injected at session start and on every prompt.
- **Resume**: cross-machine "pick up where you left off" context at session start.
- **Capture**: every session is harvested into your Mind (final capture on Stop,
  crash-safe incremental capture mid-turn, debounced to at most one post per 90s).
  Both capture hooks detach before doing any network work, so latency never
  blocks a command or session shutdown on any host. See
  [What gets captured](#what-gets-captured) for exactly what leaves your machine.
- **Guardrails**: kept lessons warn before matching tool calls; the anti-fabrication
  standing rule fires on every prompt.
- **MCP**: the thinqOS MCP tools (`recall`, `remember`, `forget`, `check`, `advise`,
  `history`, `ask_agent`, `status`, and the generic `thinqos_query`/`thinqos_create`/
  `thinqos_update`/`thinqos_delete`/`thinqos_action` verbs that reach everything else).
- **Skill**: `thinqos:remembering`, the Mind contract for recall/advise/persist discipline.

## Requirements

- **A thinqOS account.** This plugin is a thin client for the hosted thinqOS
  service: it supplies host configuration and does no work on its own. Without an account
  and an API key, `thinqos install` has nothing to connect to.
  [Request access](https://app.thinqos.com/request-access) · [Sign in](https://app.thinqos.com/sign-in) ·
  [Pricing](https://thinqos.com/pricing)
- **Python 3.13 or newer**, and [uv](https://docs.astral.sh/uv/) to install the CLI.
- **Claude Code or Codex.** Claude uses the plugin hooks. Codex uses the
  packaged `thinqos:remembering` skill while the CLI remains the single source
  for lifecycle hooks. Grok Build is supported by the CLI directly.

## Install

1. Install the CLI (the plugin packages hooks; the CLI configures the MCP connection and does the work):

   ```
   uv tool install thinqos
   ```

2. Configure thinqOS for Claude Code. The CLI uses your existing authenticated
   thinqOS connection and installs one MCP registration:

   ```
   thinqos install --client claude
   ```

3. Add the marketplace and install the plugin. It supplies hooks only; it does
   not create a second MCP connection or prompt for a separate token:

   ```
   /plugin marketplace add AI4Outcomes/thinqos-plugins
   /plugin install thinqos@thinqos-plugins
   ```

4. Re-run the installer once after enabling the plugin. It detects the plugin
   and removes any settings-managed hook entries so nothing fires twice:

   ```
   thinqos install --client claude
   ```

Verify with `thinqos doctor` (`thinqos_connectivity: pass` and no
double-wired hooks).

### Codex

The official Codex plugin owns the MCP server and launches `thinqos mcp serve`.
Codex selects the native package through `.agents/plugins/marketplace.json`;
web and Claude connections retain their own portable package.
The CLI uses your paired deployment and credential together and owns the native
lifecycle hooks in `~/.codex/hooks.json`.

Upgrade the CLI before installing plugin `0.4.3`, then verify that its transport
command is available:

```
uv tool upgrade thinqos
thinqos mcp serve --help
thinqos install --client codex
```

The installer installs the official plugin, removes the obsolete direct MCP
registration, and preserves other servers. If hook commands changed, open
Codex's `/hooks` screen and approve User config. Verify with `thinqos doctor`.

Claude's hook manifest lives under `.claude-plugin/`, outside Codex's default
root hook discovery path. The runtime stand-down in the scripts remains as
backward compatibility for Codex caches older than plugin `0.2.5`.

## What gets captured

The plugin and CLI capture your Claude Code or Codex session content into thinqOS. That is the
product, not a side effect, so here is precisely what happens.

**What is sent.** Session transcripts: your prompts, the assistant's responses,
and tool calls with their results, along with the session id, working directory,
and timestamps. Transport is HTTPS to the thinqOS server this machine is
connected to (`https://app.thinqos.com` unless you connected to another
deployment), authenticated with your own API key. Data goes to your Mind and is scoped to your identity.

**When it is sent.** On the `Stop` hook at the end of a turn, and on
`PostToolUse` for crash-safe mid-session snapshots, debounced to at most one post
per 90 seconds (`THINQOS_INCREMENTAL_MIN_INTERVAL_S`). Both detach first.
If the network is unavailable, payloads queue locally under `~/.config/thinqos`
and are replayed later.

**What is filtered before sending.** The privacy model is opt-out: the adapter
captures everything except

- content matching secret-shaped patterns (`.env` references, `api_key` /
  `secret` / `password` / `token` assignments of 16 or more characters, and
  `sk-…` style keys),
- tool results larger than 32 KiB,
- any session whose working directory matches your path denylist (below).

This is a best-effort filter over a broad surface, not a guarantee. Treat it as
defense in depth, not as a reason to run the plugin over a directory holding
credentials.

**Your data is governed by** the [thinqOS Privacy Policy](https://thinqos.com/privacy)
and [Terms of Service](https://thinqos.com/terms).

## Controlling and deleting your data

- **Exclude directories from capture.** Create `~/.config/thinqos/denylist.txt`,
  one substring per line (`#` starts a comment). Any session whose working
  directory contains a listed substring is dropped before upload.

  ```
  # ~/.config/thinqos/denylist.txt
  /clients/acme
  /secrets
  ```

- **See what was captured**: `thinqos list`
- **Delete one session** (not reversible): `thinqos forget <session_id>`
- **Stop capturing entirely**: disable the plugin in your host and run
  `thinqos uninstall` to remove the local hooks.

## Notes

- The plugin auto-updates via the marketplace; the CLI self-updates daily
  (stamp-gated) from the SessionStart hook.
- Codex users: keep using `thinqos install --client codex`; the marketplace
  owns MCP, while the CLI resolves the paired connection and owns native hooks.
- To select another deployment, use `thinqos install --client codex --base-url <URL>`
  with that deployment's authentication. The plugin follows the paired connection.

## Contributing and support

Issues and pull requests are welcome on this repository. For account, billing,
or data questions, contact support@thinqos.com.

## License

MIT. See [LICENSE](./LICENSE). The MIT license covers the plugin code in this
repository; the hosted thinqOS service it connects to is governed separately by
the [Terms of Service](https://thinqos.com/terms).

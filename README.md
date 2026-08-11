# thinqos-plugins

Official AI4Outcomes plugin marketplace for Claude Code.

## thinqOS Mind plugin

Gives Claude Code a persistent Mind backed by [thinqOS](https://thinqos.com):

- **Prime**: reflexive memory recall injected at session start and on every prompt.
- **Resume**: cross-machine "pick up where you left off" context at session start.
- **Capture**: every session is harvested into your Mind (final capture on Stop,
  crash-safe incremental capture mid-turn, debounced to at most one post per 90s).
  Both capture hooks detach before doing any network work, so latency never
  blocks a command or session shutdown on any host. See
  [What gets captured](#what-gets-captured) for exactly what leaves your machine.
- **Guardrails**: kept lessons warn before matching tool calls; the anti-fabrication
  standing rule fires on every prompt.
- **MCP**: the thinqOS MCP tools (recall, consult, observe, believe, agents, and more).
- **Skill**: `thinqos:remembering`, the Mind contract for recall/consult/persist discipline.

## Requirements

- **A thinqOS account.** This plugin is a thin client for the hosted thinqOS
  service: it ships hooks only and does no work on its own. Without an account
  and an API key, `thinqos install` has nothing to connect to.
  [Sign up](https://thinqos.com/sign-up) · [Sign in](https://thinqos.com/sign-in) ·
  [Pricing](https://thinqos.com/pricing)
- **Python 3.13 or newer**, and [uv](https://docs.astral.sh/uv/) to install the CLI.
- **Claude Code.** Codex and Grok Build are supported by the CLI directly; this
  marketplace is Claude Code packaging only.

## Install

1. Install the CLI (the plugin packages hooks; the CLI configures the MCP connection and does the work):

   ```
   uv tool install thinqos
   ```

2. Configure thinqOS for Claude Code. The CLI uses your existing authenticated
   thinqOS connection and installs one MCP registration:

   ```
   thinqos install
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
   thinqos install
   ```

Verify with `thinqos doctor` (`thinqos_connectivity: pass` and no
double-wired hooks).

### Codex

Codex installs Claude marketplace plugins too, but it gates plugin hooks behind
a per-source **Trust** toggle that defaults off and never prompts - an untrusted
plugin hook simply never runs. So in Codex the CLI's own `~/.codex/hooks.json`
entries are authoritative and the plugin's hooks stand down whenever they are
present (TOS-2773). Run `thinqos install --client codex`; the plugin then adds
its skills and MCP surface without double-wiring capture.

Set `THINQOS_PLUGIN_FORCE_HOOKS=1` if you want the plugin's hooks to win in
Codex anyway - only sensible when the CLI is not installed, and only after
trusting them in Codex's hook review dialog.

## What gets captured

This plugin uploads your Claude Code session content to thinqOS. That is the
product, not a side effect, so here is precisely what happens.

**What is sent.** Session transcripts: your prompts, the assistant's responses,
and tool calls with their results, along with the session id, working directory,
and timestamps. Transport is HTTPS to `https://thinqos.com`, authenticated with
your own API key. Data goes to your Mind and is scoped to your identity.

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
- **Stop capturing entirely**: disable the plugin with `/plugin` and run
  `thinqos uninstall` to remove the local hooks.

## Notes

- The plugin auto-updates via the marketplace; the CLI self-updates daily
  (stamp-gated) from the SessionStart hook.
- Codex users: keep using `thinqos install --client codex`; this
  marketplace is Claude Code packaging only.
- Pointing at another thinqOS deployment: set `THINQOS_BASE_URL`.

## Contributing and support

Issues and pull requests are welcome on this repository. For account, billing,
or data questions, contact support@thinqos.com.

## License

MIT. See [LICENSE](./LICENSE). The MIT license covers the plugin code in this
repository; the hosted thinqOS service it connects to is governed separately by
the [Terms of Service](https://thinqos.com/terms).

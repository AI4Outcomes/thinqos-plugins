# thinqos-plugins

Official AI4Outcomes plugin marketplace for Claude Code.

## thinqOS Mind plugin

Gives Claude Code a persistent Mind backed by [thinqOS](https://thinqos.com):

- **Prime**: reflexive memory recall injected at session start and on every prompt.
- **Resume**: cross-machine "pick up where you left off" context at session start.
- **Capture**: every session is harvested into your Mind (final capture on Stop,
  crash-safe incremental capture mid-turn, debounced to at most one post per 90s).
  Both capture hooks run asynchronously so network latency never blocks a Claude
  Code command or session shutdown.
- **Guardrails**: kept lessons warn before matching tool calls; the anti-fabrication
  standing rule fires on every prompt.
- **MCP**: the thinqOS MCP tools (recall, consult, observe, believe, agents, and more).
- **Skill**: `thinqos:remembering`, the Mind contract for recall/consult/persist discipline.

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
   and removes any settings.json-managed hook entries so nothing fires twice:

   ```
   thinqos install
   ```

Verify with `thinqos doctor --strict` (`thinqos_connectivity: pass` and no
double-wired hooks).

## Notes

- The plugin auto-updates via the marketplace; the CLI self-updates daily
  (stamp-gated) from the SessionStart hook.
- Codex users: keep using `thinqos install --client codex`; this
  marketplace is Claude Code packaging only.

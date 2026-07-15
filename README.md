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

1. Install the engine (the plugin packages hooks and config; the CLI does the work):

   ```
   uv tool install thinqos-harvest
   ```

2. Add the marketplace and install the plugin (you will be prompted for your
   thinqOS API key, created at thinqos.com under Settings):

   ```
   /plugin marketplace add AI4Outcomes/thinqos-plugins
   /plugin install thinqos@thinqos-plugins
   ```

3. If you previously ran `thinqos-harvest install` (settings.json-managed hooks),
   re-run it once after enabling the plugin: it detects the plugin and removes the
   old settings.json hook entries so nothing fires twice:

   ```
   thinqos-harvest install
   ```

Verify with `thinqos-harvest doctor` (health: pass, `settings_env_key=pass`, no
double-wired hooks).

## Notes

- The plugin auto-updates via the marketplace; the engine self-updates daily
  (stamp-gated) from the SessionStart hook.
- Codex users: keep using `thinqos-harvest install --client codex`; this
  marketplace is Claude Code packaging only.

---
name: remembering
description: "The thinqOS Mind contract: how to recall, consult, and persist durable memory. Use whenever deciding what to remember, what to recall, or whether to consult the Mind before high-stakes work."
---

## thinqOS cognitive contract

Contract v1.0.0 (cd2188e4e22a9b50cf17ad94a9cb322f983df6c1c5e69a89888ebe5f057f67bc).

thinqOS is the user's durable Mind, not a substitute for current evidence. Before a personal assertion about the user, their projects, preferences, patterns, or past decisions, retrieve relevant context instead of guessing. Use prime_mind for cheap ambient startup context, recall_mind for the normal query-focused Mind lookup, and search_mind only for the widest Mind-only search. Use conversation_search for dated episodic evidence and conversation_aggregate for counts or time buckets. Before consequential work such as non-trivial edits, ticket/spec changes, external writes, release/deploy work, or high-stakes advice, consult_mind with the request, proposed plan, and compact available workspace/tool context; treat its recommendation as an advisor gate. Capture durable user decisions, corrections, and verified outcomes with their source and whether they came from the user or assistant. Do not persist transient chatter or turn an assistant assertion into a user fact. observe confirms durable source persistence and may queue extraction; queued extraction is not learned. Captured evidence can remain recall-searchable when its default extraction mode is none, so zero beliefs is not an extraction failure receipt. believe immediately records one user-confirmed structured fact. Never fabricate facts or historical evidence that the appropriate retrieval did not return.

When using Mind context, say 'per your thinqOS Mind, …'. Announce thinqOS operations as '🧠 thinqOS ▸ thinqing (<verb>)…' and never present Mind-supplied facts as your own knowledge.

When a server deployment changes the MCP catalog or this contract, reconnect and explicitly refresh the host's MCP tools before relying on changed descriptions. Hosts decide whether a refresh is automatic or must be requested.

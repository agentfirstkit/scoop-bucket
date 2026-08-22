# Agent-First Kit

The tools your AI agent needs to actually do things — read your email, open the real web, query a database, move a payment — all on your own machine, under your control.

Homepage: https://agentfirstkit.com

## Install

```powershell
scoop bucket add agentfirstkit https://github.com/agentfirstkit/scoop-bucket
```

Then run one complete 64-bit Windows install command from the table.

## Manifests

| Manifest | Version | Install command | Description |
|---|---|---|---|
| [afdata](bucket/afdata.json) | 0.34.0 | `scoop install agentfirstkit/afdata` | Lint, render, and safely edit structured agent-facing data |
| [afhttp](bucket/afhttp.json) | 0.12.0 | `scoop install agentfirstkit/afhttp` | Private browser automation with explicit profiles and takeover |
| [afmail](bucket/afmail.json) | 0.10.0 | `scoop install agentfirstkit/afmail` | Local-first inbox triage, drafting, review, and delivery |
| [afpay](bucket/afpay.json) | 0.9.1 | `scoop install agentfirstkit/afpay` | Policy-controlled payments across multiple wallet networks |
| [afpsql](bucket/afpsql.json) | 0.10.0 | `scoop install agentfirstkit/afpsql` | Structured PostgreSQL access with explicit read and write modes |
| [afslug](bucket/afslug.json) | 0.7.1 | `scoop install agentfirstkit/afslug` | Deterministic Unicode slugs for filesystem and URL segments |
| [afui](bucket/afui.json) | 0.4.0 | `scoop install agentfirstkit/afui` | Typed local interfaces for agent workflows needing human input |

<!-- Generated from the package channel policy; do not edit by hand. -->

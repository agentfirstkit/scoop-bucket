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
| [affiles](bucket/affiles.json) | 0.1.0 | `scoop install agentfirstkit/affiles` | One directory, read-only, in front of a person who is elsewhere |
| [afhttp](bucket/afhttp.json) | 0.13.0 | `scoop install agentfirstkit/afhttp` | Private browser automation with explicit profiles and takeover |
| [afmail](bucket/afmail.json) | 0.11.0 | `scoop install agentfirstkit/afmail` | Local-first inbox triage, drafting, review, and delivery |
| [afpay](bucket/afpay.json) | 0.10.0 | `scoop install agentfirstkit/afpay` | Policy-controlled payments across multiple wallet networks |
| [afpsql](bucket/afpsql.json) | 0.11.0 | `scoop install agentfirstkit/afpsql` | Structured PostgreSQL access with explicit read and write modes |
| [afslug](bucket/afslug.json) | 0.7.1 | `scoop install agentfirstkit/afslug` | Deterministic Unicode slugs for filesystem and URL segments |
| [afterminal](bucket/afterminal.json) | 0.2.0 | `scoop install agentfirstkit/afterminal` | A live terminal an agent drives and a person can take over |
| [afui](bucket/afui.json) | 0.5.0 | `scoop install agentfirstkit/afui` | Typed local interfaces for agent workflows needing human input |

<!-- Generated from the package channel policy; do not edit by hand. -->

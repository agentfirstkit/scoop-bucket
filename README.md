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
| [afdata](bucket/afdata.json) | 0.36.1 | `scoop install agentfirstkit/afdata` | Lint, render, and safely edit structured agent-facing data |
| [affiles](bucket/affiles.json) | 0.2.0 | `scoop install agentfirstkit/affiles` | One directory, read-only, in front of a person who is elsewhere |
| [afhttp](bucket/afhttp.json) | 0.15.0 | `scoop install agentfirstkit/afhttp` | Private browser automation with explicit profiles and takeover |
| [afmail](bucket/afmail.json) | 0.12.0 | `scoop install agentfirstkit/afmail` | Local-first inbox triage, drafting, review, and delivery |
| [afpay](bucket/afpay.json) | 0.11.0 | `scoop install agentfirstkit/afpay` | Policy-controlled payments across multiple wallet networks |
| [afpdf](bucket/afpdf.json) | 0.1.0 | `scoop install agentfirstkit/afpdf` | Article text, structure, and images recovered from PDF layouts |
| [afpsql](bucket/afpsql.json) | 0.12.0 | `scoop install agentfirstkit/afpsql` | Structured PostgreSQL access with explicit read and write modes; also installs `afpsql-readonly` |
| [afslug](bucket/afslug.json) | 0.9.0 | `scoop install agentfirstkit/afslug` | Deterministic Unicode slugs for filesystem and URL segments |
| [afterminal](bucket/afterminal.json) | 0.3.0 | `scoop install agentfirstkit/afterminal` | A live terminal an agent drives and a person can take over |
| [afui](bucket/afui.json) | 0.8.0 | `scoop install agentfirstkit/afui` | Typed local interfaces for agent workflows needing human input |

<!-- Generated from the package channel policy; do not edit by hand. -->

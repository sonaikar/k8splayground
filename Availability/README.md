# Availability & Reliability Concepts

A reference guide for SLI, SLO, SLA, error budgets, and reliability metrics used in production systems.

---

## The Hierarchy

```
SLI  →  what you measure
SLO  →  what you target internally
SLA  →  what you promise externally (with consequences)
```

---

## SLI — Service Level Indicator

The **actual measurement** — a specific metric you track in real time.

| SLI | Formula |
|-----|---------|
| Availability | `(successful requests / total requests) × 100` |
| Error rate | `(5xx errors / total requests) × 100` |
| Latency p99 | 99% of requests complete under X ms |
| Throughput | Requests processed per second |

### Example

```
Total requests:    10,000
Failed requests:       50

Availability SLI = (9950 / 10000) × 100 = 99.5%
Error rate SLI   = (50 / 10000) × 100   = 0.5%
p99 latency SLI  = 450ms
```

---

## SLO — Service Level Objective

Your **internal target** — the goal your team commits to maintaining. Always stricter than the SLA to provide a safety buffer.

```
SLO = SLI + target threshold

Examples:
  "Availability SLI must stay above 99.9%"
  "p99 latency SLI must stay below 500ms"
  "Error rate SLI must stay below 0.1%"
```

### Error Budget

The allowable amount of unreliability derived from the SLO.

```
SLO = 99.9% availability over 30 days

Total minutes in 30 days = 43,200
Allowed downtime (0.1%)  = 43.2 minutes  ← error budget

If 40 min downtime consumed this month:
  Remaining error budget = 3.2 minutes
  → Freeze risky deployments
  → Prioritise reliability work over features
```

---

## SLA — Service Level Agreement

The **contractual promise** to customers with defined penalties for breach.

```
SLO (internal):  "We target 99.9% uptime"
SLA (external):  "We guarantee 99.5% uptime or you receive a credit"
```

> SLA is always set **lower** than SLO to absorb unexpected failures without breaching the contract.

### Real-world SLA examples

| Provider | Service | SLA | Penalty |
|----------|---------|-----|---------|
| AWS EKS | Control plane | 99.95% | Service credits |
| AWS EC2 | Single instance | 99.5% | 10–30% credit |
| AWS RDS | Multi-AZ | 99.95% | Service credits |
| GCP GKE | Control plane | 99.95% | Credits |

---

## SLI → SLO → SLA Flow

```
Customer signs SLA: "99.5% uptime guaranteed"
        │
        ▼
Engineering sets SLO: "99.9% uptime target" (buffer above SLA)
        │
        ▼
Monitoring tracks SLI: actual uptime % measured every minute
        │
        ▼
Alert fires when SLI approaches SLO threshold
        │
        ▼
Fix before SLO breaches → SLA never breached → no penalties
```

---

## MTTR — Mean Time To Repair

**Average time taken to restore service after a failure.**

```
Incident 1: 30 min to fix
Incident 2: 60 min to fix
Incident 3: 90 min to fix

MTTR = (30 + 60 + 90) / 3 = 60 minutes
```

Lower MTTR = faster recovery = better reliability.  
Improved by: runbooks, on-call automation, observability tooling.

---

## MTBF — Mean Time Between Failures

**Average time the system runs between incidents.**

```
Incident on Jan 1 → resolved → next incident on Jan 15
MTBF = 14 days
```

Higher MTBF = more stable system.  
Improved by: chaos engineering, redundancy, rigorous testing.

---

## MTTD — Mean Time To Detect

**Average time from failure occurring to the team being alerted.**

```
System failed at 02:00
Alert fired   at 02:05
MTTD = 5 minutes
```

Lower MTTD = problems caught faster.  
Improved by: better monitoring, lower alert thresholds, synthetic probes.

---

## MTTF — Mean Time To Failure

**Average time a component operates before it fails.** Typically used for hardware.

```
Disk fails on average every 3 years
MTTF = 3 years
```

Higher MTTF = more durable components.

---

## Metric Relationships

```
MTTF          MTTR          MTTF
◄───────────►◄────────────►◄───────────►
  Operating    Recovering     Operating

MTBF = MTTF + MTTR

Availability = MTTF / (MTTF + MTTR)
```

### Example

```
MTTF = 14 days = 20,160 min
MTTR = 60 min

Availability = 20,160 / (20,160 + 60) = 99.7%
```

---

## Availability Nines

| Availability | Downtime / Year | Downtime / Month | Suitable For |
|-------------|----------------|-----------------|--------------|
| 99% | 3.65 days | 7.3 hours | Dev / test environments |
| 99.9% | 8.7 hours | 43.8 minutes | Internal tools, low-traffic apps |
| 99.95% | 4.4 hours | 21.9 minutes | Standard SaaS products |
| 99.99% | 52 minutes | 4.4 minutes | E-commerce, customer-facing APIs |
| 99.999% | 5.2 minutes | 26 seconds | Payments, telecom, critical infra |

---

## Practical Example — EKS Cluster

```
SLI:  measured availability = 99.92% this month

SLO:  internal target = 99.9%
      SLI (99.92%) > SLO (99.9%) ✅  on track
      Error budget remaining = 28 min this month

SLA:  customer promise = 99.5%
      SLI (99.92%) >> SLA (99.5%) ✅  no breach, no credits owed

MTTD: alerts fire within 3 min on average
MTTR: last 3 incidents = 15, 20, 25 min → MTTR = 20 min
MTBF: incidents on Jan 1, Jan 15, Feb 3 → avg 16 days between failures
```

---

## Summary Cheatsheet

| Term | Answers | Direction |
|------|---------|-----------|
| **SLI** | What is the current measurement? | Track |
| **SLO** | What is our internal target? | Set higher than SLA |
| **SLA** | What did we promise the customer? | Set lower than SLO |
| **MTTR** | How fast do we recover? | Lower is better |
| **MTBF** | How often do we fail? | Higher is better |
| **MTTD** | How fast do we detect failure? | Lower is better |
| **MTTF** | How long until something breaks? | Higher is better |
| **Error Budget** | How much unreliability remains? | Guard it carefully |

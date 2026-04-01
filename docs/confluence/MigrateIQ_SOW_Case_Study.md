# MigrateIQ — SOW Case Study (Copy/Paste for Confluence)

## Executive summary

MigrateIQ is an agentic database migration platform that standardizes and automates the migration lifecycle: **assess → plan → execute → validate → cutover**, with **human approval gates** at the three points where risk must be explicitly accepted.

This page provides a **real-world SOW-style case study** you can paste into Confluence as a template for a client engagement.

---

## Client profile (example)

- **Industry**: Banking / Financial Services (regulated)
- **Current state**: mission-critical applications backed by large relational databases; changes tightly controlled; strong audit requirements
- **Primary constraints**:
  - strict cutover windows (night/weekend)
  - zero tolerance for data discrepancies
  - rollback must be pre-planned and proven

---

## Business problem

- Migrations are treated as one-off projects; each team creates runbooks and validation checklists from scratch.
- Discovery and risk scoring vary by engineer, leading to inconsistent estimates and late surprises.
- Monitoring during the migration window is reactive; errors are interpreted manually under time pressure.
- Validation often stops at row counts due to time constraints, which is insufficient for audit/compliance.

---

## Engagement objectives

- **Reduce migration risk** via consistent pre-flight assessment and explicit approval gates.
- **Minimize downtime** with a plan that accounts for volume, complexity, and constraints.
- **Prove data integrity** with a repeatable validation suite and audit-ready reporting.
- **Guarantee rollback readiness** with rollback scripts generated before execution and tested in non-prod.

---

## Scope (portfolio example)

> Adjust numbers per client. This is the standard “portfolio migration” pattern.

- **In-scope systems**: a portfolio of enterprise databases migrated in waves
- **Environment tiers**:
  - non-production databases migrated first to validate approach and tooling
  - production databases migrated after success criteria are met in non-prod
- **Typical migration mix**:
  - rehost/lift-and-shift databases (same engine → same engine)
  - replatform databases (engine → different engine; includes schema/proc conversion)
- **Optional** (common in SOWs):
  - DR/standby alignment as part of the migration
  - patching/upgrades bundled into the window

---

## Out of scope (typical)

- application refactoring (beyond connection string changes / cutover coordination)
- full performance re-architecture (beyond agreed baseline validation)
- long-term database governance / CI/CD schema change management (Flyway/Liquibase territory)

---

## Delivery model (phases, gates, and outputs)

### Phase 1 — Discovery & Assessment (Human Gate 1: Proceed / No-Go)

**Activities**
- connect to each source database (read-only where possible)
- collect metadata: size, table/object counts, stored procedures/triggers/views, constraints/indexes, active sessions, version/patch level, cross-db dependencies
- determine migration approach per database (rehost vs replatform)
- estimate downtime and identify blockers
- produce target infra cost estimate (where applicable)

**Deliverables**
- database inventory (portfolio view)
- per-database assessment report:
  - risk score + risk level
  - downtime estimate + assumptions
  - blockers + remediation plan
  - recommended migration strategy

**Acceptance criteria**
- stakeholders approve Gate 1 for each database (or defer it to a later wave)

---

### Phase 2 — Planning & Runbook (Human Gate 2: Approve Plan)

**Activities**
- generate a standardized migration runbook per database:
  - ordered steps + estimated duration
  - success criteria per step
  - failure actions + escalation
  - rollback command per step (where applicable)
- generate automation artifacts:
  - migration scripts (DDL, task configs, parameter files)
  - rollback scripts (generated before execution)
- for replatform migrations:
  - run schema conversion tooling and analyze conversion gaps
  - rewrite/resolve failed conversion items (stored procs, triggers, non-portable SQL) as required

**Deliverables**
- runbook pack (human-readable + structured form)
- script bundle (execution + rollback)
- conversion report (for heterogeneous migrations)

**Acceptance criteria**
- Gate 2 approval by delivery lead + client stakeholders before any production execution

---

### Phase 3 — Execution & Monitoring (Migration Window)

**Activities**
- execute the approved runbook
- continuously monitor health signals (logs + metrics)
- classify errors and recommend actions (continue/pause/abort)
- maintain a clear “single pane” view of status and health

**Deliverables**
- execution log (timestamped, step-by-step)
- health score timeline + alert log
- incident timeline (if any)

**Acceptance criteria**
- execution completes within the approved window (or approved exception handling is followed)

---

### Phase 4 — Validation (Human Gate 3: Go-Live / No-Go)

**Activities**
- run standardized validation suite (configurable by engagement):
  - row counts per table
  - checksums/hashes per table (data fingerprinting)
  - object inventory parity (tables/views/procs/triggers/indexes)
  - constraint + index validity checks
  - sequence alignment (target >= source)
  - invalid object detection and remediation
  - agreed performance baseline checks (top N queries)
  - optional business-rule checks (domain-specific)

**Deliverables**
- validation report (detailed)
- compliance/audit report (Excel/PDF format)

**Acceptance criteria**
- Gate 3 approval required to proceed with cutover
- any exceptions documented with explicit sign-off

---

### Phase 5 — Cutover & Post-cutover Monitoring

**Activities**
- verify final sync state (replication lag = 0 where applicable)
- execute cutover steps (connection switch, final object application)
- monitor post-cutover for an agreed stabilization window (e.g., first 30 minutes)
- trigger rollback if objective thresholds are crossed (automatic or manual per engagement)

**Deliverables**
- cutover report (what changed, when, and by whom)
- migration completion summary (all phases + decisions + approvals)
- knowledge base entry (lessons learned, predicted vs actual, defects/remediations)

**Acceptance criteria**
- stabilization window passes without critical incidents
- rollback remains available until decommission criteria are met

---

## RACI (typical)

- **Client DBAs**: approve gates, provide access, own operational constraints and change approvals
- **Delivery team**: assessment, runbook, execution, monitoring, validation facilitation, reporting
- **Application owners**: coordinate downtime window, cutover actions, functional validation sign-off
- **Security/Compliance**: review evidence package and audit artifacts as required

---

## SOW milestones (example)

- **M1 — Portfolio assessment complete** (all in-scope DBs assessed; Gate 1 decisions recorded)
- **M2 — Runbooks & rollback scripts complete** (Gate 2 approvals for Wave 1)
- **M3 — Non-prod wave complete** (execution + validation; defects remediated)
- **M4 — Prod wave complete** (execution + validation + cutover; Gate 3 approvals)
- **M5 — Closeout** (completion summary, evidence package, knowledge base update)

---

## Common SOW assumptions (fill in)

- access to source databases for metadata collection (read-only preferred)
- agreed downtime windows and change management approvals provided by client
- target environment landing zone/networking prerequisites completed before execution
- named stakeholders available for approval gates during migration windows


# Agentic Migration Platform -- Discovery Responses
## Use Case: Database Migration

This document answers the discovery questions from the Strategy and Governance deck
for the database migration use case across all phases of the migration lifecycle.

---

## Discovery Phase

### What decisions are made here?

- Which databases are in scope for migration (not all databases migrate at once).
- Whether each database should be rehosted (same engine, new environment) or replatformed (different engine).
- Priority order when multiple databases are involved.
- Whether the source database can support an assessment connection without production impact.

### What artifacts are produced here?

- Source database inventory (engine, version, size, table count, stored procedure count, connection count).
- Complexity classification per database (simple, moderate, complex) based on stored procedure count, cross-database dependencies, triggers, and engine-specific features.
- Initial risk profile per database.
- Assessment report with risk score, downtime estimate, blocker list, and strategy recommendation.
- Target infrastructure cost estimate (projected monthly and annual AWS spend).

### What pain points exist here?

- Assessment is performed manually by senior DBAs. It takes days per database and the output format varies by person.
- There is no standard way to classify database complexity. Teams use different criteria and arrive at inconsistent risk profiles.
- Cost estimation for the target environment is either skipped entirely or done in a spreadsheet with rough guesses. There is no connection between the actual infrastructure plan and the cost figure.
- Discovery often happens in isolation from the rest of the lifecycle. Findings are captured in documents that do not feed into the next phase automatically.
- AWS DMS Fleet Advisor (the closest AWS tool for discovery) is being retired in May 2026 and was never more than a basic inventory scanner.

### What activities are manual today?

- Connecting to each source database and running metadata queries against system catalog views.
- Interpreting the metadata to determine complexity and risk.
- Writing up assessment findings in Word or PowerPoint.
- Estimating downtime based on experience and gut feel.
- Estimating target environment costs in a spreadsheet.
- Communicating findings to stakeholders and getting a go/no-go decision.

### What data is required here?

- Database engine type and version.
- Table count, row counts, total data size.
- Stored procedure, trigger, and view counts (these are the primary complexity drivers).
- Index and constraint counts.
- Active connection count and peak usage patterns.
- Current host environment (on-premises hardware specs, OS, network topology).
- Any compliance or regulatory requirements that affect the target architecture.

### What platform capability could improve this?

- **Automated Creation of Migration Artifacts**: The platform connects to the source database, runs engine-specific catalog queries (information_schema for MySQL, pg_catalog for PostgreSQL, DBA_* views for Oracle, sys.* views for SQL Server), and generates a structured assessment report automatically. No manual querying or document assembly.
- **Centralized Data Collection and Management**: Assessment results are stored in a central repository (DynamoDB) with a consistent schema. Every assessment across every project follows the same structure.
- **Accuracy Validation and Error Reduction**: AI (Amazon Bedrock) analyzes the raw metadata and produces a calibrated risk score. Over time, the knowledge base compares predicted risk against actual outcomes and improves accuracy.
- **End-to-End Visibility and Reporting**: The assessment report is immediately available to stakeholders through a dashboard, not buried in an email attachment.

---

## Assessment and Planning Phase

### What decisions are made here?

- Go/no-go on proceeding with each database migration (Gate 1 -- human approval required).
- Migration approach per database: DMS full-load, DMS CDC (continuous replication), native backup/restore, or a combination.
- Target engine selection (for replatform scenarios): Aurora PostgreSQL, Aurora MySQL, RDS PostgreSQL, etc.
- Cutover strategy: big-bang (full downtime window) or phased (CDC with minimal downtime).
- Rollback criteria: what health score threshold triggers automatic rollback, what conditions require human-initiated rollback.

### What artifacts are produced here?

- Migration runbook: ordered steps, estimated duration per step, tool for each step, success criteria, failure action, and rollback command.
- Migration scripts: DDL scripts for target schema, DMS task configuration, parameter files for native tools (DataPump, RMAN, pg_dump, mysqldump).
- Rollback scripts: pre-generated reversal steps for every migration action. Generated before execution begins, not improvised during failure.
- Schema conversion report (for replatform): what SCT converted automatically, what failed and requires manual intervention, what the AI agent rewrote.
- Dependency map: which applications connect to this database, what breaks if the database moves.

### What pain points exist here?

- Runbook creation is entirely manual. Senior engineers write migration runbooks in Word or Confluence. The format varies by team. Steps are sometimes missed.
- Rollback planning is frequently an afterthought. Rollback scripts are written during execution under pressure, not before.
- Schema conversion for heterogeneous migrations produces SCT reports that require manual review and manual rewriting of failed items. This is time-consuming and requires deep expertise in both source and target engines.
- There is no standard way to estimate step duration. Estimates vary widely between engineers.
- The dependency between databases and applications is often discovered late, sometimes during execution.

### What activities are manual today?

- Writing the migration runbook (steps, ordering, duration estimates, rollback procedures).
- Running AWS SCT and interpreting the conversion report.
- Rewriting stored procedures and triggers that SCT cannot convert.
- Creating DMS task configurations.
- Generating rollback scripts.
- Reviewing and approving the plan (currently done via email or meetings with no structured approval flow).

### What data is required here?

- Complete assessment output from the discovery phase (this is where cross-phase data continuity matters).
- SCT assessment report (for heterogeneous migrations).
- Application connection inventory (which apps, what connection strings, what failover behavior).
- Downtime window constraints from the business.
- Compliance requirements that affect the migration approach (e.g., no data can leave a specific region, encryption requirements).
- Historical migration data from similar past engagements (if available).

### What platform capability could improve this?

- **Automated Creation of Migration Artifacts**: AI agent generates the complete runbook, migration scripts, and rollback scripts from the assessment data. No manual document assembly.
- **Cross-Phase Data Continuity**: Assessment output flows directly into planning. The runbook agent consumes the assessment report as input -- no re-keying, no copy-paste between documents.
- **Consistency and Standards Enforcement**: Every runbook follows the same template. Every rollback script follows the same structure. This eliminates variability across teams and projects.
- **Accuracy Validation and Error Reduction**: AI-assisted schema conversion catches issues that manual review might miss. The knowledge base surfaces relevant learnings from past migrations of the same engine pair.

---

## Execution Phase

### What decisions are made here?

- Whether to continue, pause, or abort based on real-time health metrics.
- Whether DMS replication errors are transient (retry) or fatal (stop and investigate).
- When to apply secondary objects (foreign keys, indexes) -- timing matters for performance.
- Whether the migration is tracking to the estimated downtime window or needs adjustment.

### What artifacts are produced here?

- Execution log: timestamped record of every step executed, its status, duration, and any errors encountered.
- DMS task metrics: rows migrated, throughput, latency, error count.
- Health score timeline: a running score (0-100) based on weighted metrics, updated throughout execution.
- Error classification log: each error categorized by severity and recommended action (by the AI monitoring agent).

### What pain points exist here?

- Monitoring is reactive. Teams watch CloudWatch dashboards and DMS console manually, responding to errors after they happen rather than anticipating them.
- DMS logs errors but provides no guidance on what to do about them. Engineers must interpret error codes, search documentation, and decide on a response.
- There is no unified health indicator. Teams look at multiple metrics across multiple consoles and mentally combine them into a subjective assessment of "are we okay."
- Communication during execution is ad-hoc. Status updates go out via Slack or email when someone remembers. Stakeholders have no real-time visibility.
- If a migration needs to be aborted, the decision is often delayed because nobody wants to call it. There is no objective threshold.

### What activities are manual today?

- Monitoring DMS task status in the AWS console.
- Interpreting CloudWatch metrics and DMS error logs.
- Deciding whether an error requires intervention or will self-resolve.
- Communicating status to stakeholders during the migration window.
- Making the abort/continue decision under pressure.
- Executing the runbook steps in order (SSM commands, DMS task creation, post-load object application).

### What data is required here?

- The approved runbook from the planning phase.
- DMS task metrics (available via CloudWatch).
- Database alert log entries from both source and target.
- Application health metrics (if available, to detect downstream impact).
- The abort threshold (health score below which rollback triggers automatically).
- Real-time replication lag.

### What platform capability could improve this?

- **End-to-End Visibility and Reporting**: Real-time dashboard showing execution progress, health score, replication lag, error count, and estimated time remaining. Stakeholders do not need to ask for updates.
- **Accuracy Validation and Error Reduction**: AI agent classifies every error by severity and recommends action. This eliminates the delay of manual log interpretation.
- **Automated Creation of Migration Artifacts**: Execution log is generated automatically with full traceability. No manual note-taking during the migration window.
- **Collaboration Support**: Stakeholders and delivery team see the same dashboard. Status is communicated automatically via SNS notifications at key milestones and on health score changes.

---

## Validation Phase

### What decisions are made here?

- Whether the target database matches the source (data integrity confirmation).
- Whether performance on the target meets acceptable thresholds compared to baseline.
- Go/no-go for cutover (Gate 3 -- human approval required).
- Whether specific tables or objects need remediation before cutover.

### What artifacts are produced here?

- Validation report: row count comparison, checksum comparison, object count comparison, constraint status, index status, sequence values.
- Performance baseline comparison: top N queries on source vs target, execution time within acceptable range.
- Business rule validation results: domain-specific checks (e.g., account balances match, referential integrity holds, no orphaned records).
- Compliance report (Excel and PDF): suitable for auditors and stakeholders in regulated industries. Provides documented proof that the migration preserved data integrity.

### What pain points exist here?

- Validation is the most neglected phase. Teams often do a quick row count comparison and call it done. Deep validation (checksums, constraint status, performance baselines) is skipped due to time pressure.
- There is no standard validation checklist. Each team validates different things to different depths.
- Compliance reporting is assembled manually after the fact, often weeks later, by pulling data from multiple sources.
- Performance testing on the target is frequently done with production traffic after cutover rather than before, which means issues are discovered too late.
- Business rule validation (domain-specific checks) is rarely done at all because it requires understanding the application logic, not just the database structure.

### What activities are manual today?

- Running row count queries against source and target and comparing in a spreadsheet.
- Spot-checking specific tables by comparing sample rows.
- Running queries to verify constraint status on the target.
- Assembling the validation findings into a report.
- Getting stakeholder sign-off via email or meeting.

### What data is required here?

- Source database metadata (current state, not cached from assessment -- it may have changed during migration).
- Target database metadata.
- Row counts per table from both sides.
- Checksums or hash values per table from both sides.
- Object inventory from both sides (tables, views, procedures, triggers, indexes, constraints).
- Performance baseline queries and their expected execution times.
- Business rules specific to the engagement (configurable per project).

### What platform capability could improve this?

- **Accuracy Validation and Error Reduction**: Automated validation suite runs every check in a standard checklist. Nothing is skipped. Checksums catch data discrepancies that row counts alone would miss.
- **Automated Creation of Migration Artifacts**: Compliance report is generated automatically in a standard format (Excel and PDF). No manual assembly.
- **Consistency and Standards Enforcement**: Every migration is validated to the same depth, using the same checks, producing the same report format. This is critical for regulated industries.
- **Cross-Phase Data Continuity**: The validation agent uses the assessment data to know what objects should exist on the target. If the assessment found 47 stored procedures, validation confirms 47 exist on the target.

---

## Cutover and Post-Cutover Phase

### What decisions are made here?

- Exact cutover timing (when to stop CDC replication and switch).
- Whether replication lag is zero and the target is fully in sync.
- Whether to proceed with application connection switch.
- Whether to trigger rollback within the first 30 minutes post-cutover based on health indicators.
- When to decommission the source database (days to weeks after successful cutover).

### What artifacts are produced here?

- Cutover execution log: timestamp of replication stop, final sync verification, connection switch, and monitoring period results.
- Post-cutover health report: first 30 minutes of target database performance, error rates, and application response times.
- Migration completion summary: full lifecycle record from assessment through cutover, including all decisions, approvals, and outcomes.
- Knowledge base entry: stored for future reference. Includes predicted vs actual risk, predicted vs actual downtime, errors encountered, and resolution steps.

### What pain points exist here?

- Cutover is the highest-stress moment. The decision to switch is often made under time pressure with incomplete information.
- Verifying replication lag is zero requires manual checking of DMS task status.
- Application connection switch is often a manual process (update config files, restart services) with no automated verification that the switch worked.
- Post-cutover monitoring is informal. Teams watch dashboards for a while and then move on. There is no structured 30-minute monitoring window with objective health criteria.
- Rollback decisions are delayed because they feel like failure. An objective, automated threshold removes the emotional component.
- Migration outcomes are not captured systematically. Lessons learned happen in a meeting but are not stored in a queryable format for future projects.

### What activities are manual today?

- Verifying DMS replication lag is zero.
- Stopping CDC replication.
- Applying final secondary objects (foreign keys, indexes, triggers).
- Switching application connection strings.
- Monitoring the target database post-cutover.
- Making the rollback decision if issues arise.
- Writing up the migration summary for stakeholders.
- Conducting a lessons-learned session.

### What data is required here?

- DMS replication lag (must be zero).
- Target database health metrics.
- Application health metrics (error rates, response times).
- The pre-generated rollback scripts from the planning phase.
- The health score threshold for automatic rollback.
- All data from previous phases (assessment, plan, execution, validation) for the completion summary.

### What platform capability could improve this?

- **End-to-End Visibility and Reporting**: Real-time cutover dashboard showing replication lag, health score, and post-cutover metrics. Stakeholders can watch the cutover happen.
- **Automated Creation of Migration Artifacts**: Migration completion summary is generated automatically, pulling data from every phase. No manual write-up.
- **Accuracy Validation and Error Reduction**: Automated rollback based on objective health score threshold. The decision is made by data, not by a stressed engineer at 2am.
- **Scalability Across Engagements**: Every migration outcome is logged to the knowledge base. Future projects benefit from this data -- the platform gets more accurate with each engagement.
- **Cross-Phase Data Continuity**: The completion summary pulls assessment predictions, planning estimates, execution actuals, and validation results into a single document. This is only possible if data flows through the entire lifecycle in a structured format.

---

## Summary: Mapping to Platform Capabilities

| Platform Capability | Discovery | Planning | Execution | Validation | Cutover |
|---|---|---|---|---|---|
| 1. Automated Artifact Creation | Assessment report, cost estimate | Runbook, scripts, rollback scripts | Execution log, error classification | Compliance report (Excel, PDF) | Completion summary, knowledge base entry |
| 2. Centralized Data Management | Assessment stored in DynamoDB | Runbook and scripts stored in S3 | Execution state tracked in DynamoDB | Validation results in DynamoDB and S3 | Full lifecycle record queryable |
| 3. Cross-Phase Data Continuity | Assessment feeds planning | Planning feeds execution | Execution state feeds validation | Validation feeds cutover decision | All phases feed completion summary |
| 4. End-to-End Visibility | Dashboard: assessment status | Dashboard: plan review, Gate 2 | Dashboard: live progress, health score | Dashboard: validation results, Gate 3 | Dashboard: cutover status, post-cutover health |
| 5. Consistency and Standards | Standard assessment format | Standard runbook template | Standard execution logging | Standard validation checklist | Standard completion report |
| 6. Collaboration Support | Gate 1 approval flow | Gate 2 approval flow | SNS notifications at milestones | Gate 3 approval flow | SNS migration complete notification |
| 7. Accuracy Validation | AI risk scoring with knowledge base | AI-assisted schema conversion | AI error classification | Checksum and business rule validation | Automated rollback on health threshold |
| 8. Scalability | Works for any supported engine pair | Templates adapt per engine | Same execution flow per engine | Same validation suite per engine | Knowledge base grows across projects |

---

## Implementation Alignment

This use case maps to the implementation roadmap as follows:

**Phase 1 (Define and Prioritize Use Cases)**: Complete. Database migration is defined as the first use case. The first migration path is MySQL to Aurora PostgreSQL. Success criteria, acceptance criteria, and data requirements are documented.

**Phase 2 (Foundational Data and Standards)**: In progress. The data model (DynamoDB schema for migration state and knowledge base), artifact templates (Jinja2 for reports and scripts), validation rules, and cross-phase data flows are defined. Infrastructure as Code (Terraform) is written and ready for deployment.

**Phase 3 (Pilot Automation and Early Value)**: Next. The Assessment Agent is the first automation to be implemented. It produces a real artifact (risk report with cost estimate), automates manual activities (DBA assessment, metadata collection, risk scoring), and demonstrates the platform pattern end-to-end.

**Phase 4 (Scale and Continuous Improvement)**: Future. Additional database engine support, more agents (Runbook, Execution, Monitoring, Validation, Rollback), knowledge base learning loop, and expansion to additional migration use cases beyond databases.

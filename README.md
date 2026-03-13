# MigrateIQ

A plug-and-play database migration platform built on AWS managed services, with AI agents handling the gaps that AWS tooling cannot cover. The goal is to have a reusable product that works for any database migration engagement, regardless of source engine, target engine, or migration approach.

## Problem Statement

Database migrations remain one of the highest-risk operations in enterprise IT. The industry data is clear:

- Over 80% of migration projects fail to meet objectives or exceed budgets and timelines.
- 67% of enterprise migrations experience significant delays, averaging 4.7 months longer than planned.
- Downtime during migration can cost financial services firms upwards of $95,000 per minute.
- 23% of migrations end up requiring a full rollback.
- Post-migration validation is a manual, error-prone process that takes hours.

The tooling exists (AWS DMS, SCT, native backup/restore), but the intelligence layer does not. Nobody is orchestrating these tools end-to-end, assessing risk before execution, monitoring in real time, or making rollback decisions autonomously.


## Two Migration Approaches

Every client engagement falls into one of two categories. The platform supports both.

### Lift and Shift (Rehost)

The source and target run the same database engine. The schema does not change. The data is copied as-is to a new environment (typically from on-premises to AWS).

- Oracle on-premises to Oracle on RDS or EC2
- SQL Server on-premises to SQL Server on RDS
- MySQL on-premises to MySQL on RDS

This is the simpler path. Schema conversion is not needed. The primary concerns are downtime, data integrity during transfer, and cutover timing.

Migration is handled through native backup/restore tools (RMAN, pg_dump, mysqldump) or AWS DMS full-load replication. The AI agents add value primarily in risk assessment, monitoring, validation, and rollback.

### Replatform (Heterogeneous Migration)

The source and target run different database engines. The schema must be converted. Stored procedures, triggers, views, and data types may need rewriting.

- Oracle to Aurora PostgreSQL
- SQL Server to Aurora PostgreSQL or Babelfish
- MySQL to Aurora PostgreSQL
- IBM Db2 to Aurora PostgreSQL or Aurora MySQL

This is the complex path. AWS SCT handles a portion of the schema conversion automatically, but complex stored procedures, triggers with business logic, and engine-specific features require manual effort or AI-assisted rewriting. This is where the AI agents provide the most value.


## Migration Lifecycle

The platform follows a 5-phase lifecycle. Every migration, regardless of engine or approach, passes through these phases in order.

### Phase 1 -- Assess

Understand what exists in the source database, identify risks, estimate downtime, and recommend a migration strategy.

AWS provides SCT assessment reports and (until May 2026) Fleet Advisor. But SCT reports are raw technical output that require interpretation, and Fleet Advisor was never more than a basic inventory scanner.

The platform handles assessment by connecting directly to the source database and querying system catalog views. Every database engine exposes metadata through these views:

| What | Oracle | SQL Server | PostgreSQL | MySQL |
|---|---|---|---|---|
| Tables and row counts | DBA_TABLES | sys.tables, sys.partitions | pg_stat_user_tables | information_schema.tables |
| Columns and data types | DBA_TAB_COLUMNS | sys.columns | information_schema.columns | information_schema.columns |
| Indexes | DBA_INDEXES | sys.indexes | pg_indexes | information_schema.statistics |
| Constraints (PK, FK) | DBA_CONSTRAINTS | sys.foreign_keys | pg_constraint | information_schema.table_constraints |
| Stored procedures | DBA_PROCEDURES | sys.procedures | pg_proc | information_schema.routines |
| Triggers | DBA_TRIGGERS | sys.triggers | pg_trigger | information_schema.triggers |
| Views | DBA_VIEWS | sys.views | pg_views | information_schema.views |
| Database size | DBA_SEGMENTS | sp_spaceused | pg_database_size() | information_schema.tables |
| Active connections | V$SESSION | sys.dm_exec_sessions | pg_stat_activity | information_schema.processlist |
| Users and permissions | DBA_USERS, DBA_SYS_PRIVS | sys.database_principals | pg_roles | mysql.user |
| Version and patch level | V$VERSION | @@VERSION | version() | version() |

The AI agent collects this metadata, optionally feeds in the SCT assessment report (for heterogeneous migrations), and uses Amazon Bedrock (Claude) to produce a risk score, downtime estimate, blocker list, and strategy recommendation. The output is a human-readable assessment report stored in S3.

### Phase 2 -- Convert

For heterogeneous migrations only. Convert the source schema to work on the target engine.

AWS SCT does the bulk of schema conversion automatically. It handles table definitions, column types, simple stored procedures, and most DDL. But it has limits. Complex stored procedures with engine-specific syntax, triggers with business logic, and views with non-portable SQL often fail conversion and get flagged for manual intervention.

The AI agent picks up where SCT stops. Using Bedrock, it analyzes the failed conversion items, understands the intent of the original code, and rewrites it for the target engine. It also generates the rollback scripts at this stage, before any execution begins, so rollback is never an afterthought.

For lift-and-shift engagements, this phase is skipped entirely.

### Phase 3 -- Migrate

Move the actual data from source to target.

AWS DMS handles this through replication tasks. It supports full-load (bulk copy) and CDC (Change Data Capture, which keeps the target in sync with ongoing source changes during migration). DMS supports all the major engine combinations.

However, DMS does not migrate everything. It copies table data and primary keys. It does not migrate:

- Stored procedures and functions
- Triggers
- Views
- Secondary indexes
- Foreign key constraints
- Default values and check constraints
- Auto-increment and sequence definitions
- User accounts and permissions

These objects must be applied separately, either through SCT output, native tools, or the AI agent. The platform handles this by applying the full schema (from Phase 2) before DMS runs, then applying secondary objects (foreign keys, indexes) after DMS completes the full load.

The AI agent monitors the DMS task through CloudWatch metrics, interprets errors, and makes decisions about whether to continue, pause, or abort. AWS DMS logs errors but does nothing about them. The agent provides the decision-making layer.

### Phase 4 -- Validate

Confirm that the target database matches the source exactly. This is the most critical phase for regulated industries.

AWS DMS has basic validation (row count comparison), but it is limited. The platform runs a deeper validation suite:

- Row count comparison per table
- Checksum or hash comparison per table (data fingerprinting)
- Object count comparison (tables, views, procedures, triggers, indexes)
- Constraint status verification (all enabled and validated)
- Index status verification (all valid and usable)
- Sequence value verification (target values >= source values)
- Invalid object detection (recompile and verify)
- Performance baseline comparison (top N queries within acceptable range)
- Business rule validation (domain-specific checks, configurable per engagement)

The AI agent runs these checks, compares results, and generates a compliance report (Excel and PDF) suitable for auditors and stakeholders. The report is stored in S3 and a notification is sent via SNS.

### Phase 5 -- Cutover

Switch the application from the source database to the target database.

This involves stopping DMS CDC replication, verifying the final sync is complete (replication lag = 0), applying any remaining secondary objects, switching the application connection string, and monitoring for errors in the first 30 minutes post-cutover.

If critical issues are detected post-cutover, the rollback agent reverses the switch and brings the source database back online. This decision can be automatic (based on health score thresholds) or manual (human triggers the rollback through the dashboard).


## Human Approval Gates

The platform does not run autonomously end-to-end. There are three mandatory approval gates where a human must review and approve before the next phase begins.

- Gate 1: After assessment, before conversion/migration planning. "Do we proceed with this migration?"
- Gate 2: After conversion and runbook generation, before execution. "Is this plan acceptable?"
- Gate 3: After validation, before cutover. "Is the data verified and ready for go-live?"

These gates are surfaced through a Streamlit dashboard deployed on ECS Fargate. The agent pauses and waits for approval at each gate.


## AWS Services

The platform leans on AWS managed services for infrastructure, data movement, and operational tooling. The AI agents handle assessment, decision-making, monitoring intelligence, validation, and rollback.

| Service | Role in the Platform |
|---|---|
| Amazon Bedrock (Claude) | LLM backend for all AI agents. Risk scoring, code conversion, log analysis, report generation. |
| AWS DMS | Data movement. Full-load and CDC replication between source and target databases. |
| AWS SCT | Schema conversion for heterogeneous migrations. Assessment reports. |
| Amazon RDS / Aurora | Managed target databases. Supports Oracle, SQL Server, PostgreSQL, MySQL, MariaDB. |
| Amazon DynamoDB | Shared state between agents during execution. Knowledge base for storing learnings from past migrations. |
| Amazon S3 | Storage for generated reports, runbooks, scripts, and intermediate data. |
| AWS Systems Manager (SSM) | Remote command execution on database servers. Replaces SSH/paramiko with IAM-authenticated, auditable access. |
| Amazon CloudWatch | Log aggregation, metrics, and alarms. Agent reads CloudWatch for DMS task health, database alert logs, and custom metrics. |
| Amazon SNS | Notifications. Email, SMS, and Slack (via Lambda subscriber) alerts for gate approvals, health score drops, and migration completion. |
| AWS ECS Fargate | Runs the platform itself. CrewAI agents, Streamlit dashboard, background workers. |
| Amazon Cognito | Authentication for the dashboard. |
| AWS CDK | Infrastructure as Code for the entire stack. |
| AWS Step Functions | Orchestrates the 5-phase workflow with state machine transitions and human approval wait states. |


## AI Agents -- Where AWS Cannot Help

Six agents cover the gaps that no AWS service addresses.

### Assessment Agent

Connects to the source database, runs engine-specific catalog queries, optionally incorporates the SCT assessment report, and uses Bedrock to produce a risk score (0-100), downtime estimate, blocker list, and strategy recommendation. Output is a structured assessment report.

### Runbook Agent

Takes the assessment output and generates a complete migration runbook: ordered steps, estimated duration per step, tool to use for each step, success criteria, failure action, and rollback command. Also generates all migration scripts using Jinja2 templates (DataPump parameter files, RMAN scripts, DDL scripts, etc.). Rollback scripts are generated here, before execution, not improvised during a failure.

### Execution Agent

Walks through the runbook step by step. Executes each step via SSM Run Command (for remote DB servers) or direct SDK calls (for AWS services like DMS). Before every step, it checks the shared state in DynamoDB for abort signals from the monitoring agent. Updates step status in DynamoDB as it progresses.

### Monitoring Agent

Runs in parallel with the execution agent. Watches CloudWatch logs for database alert log entries, DMS task metrics, and system health indicators. Uses Bedrock to classify log entries by severity and determine whether they warrant an alert, a pause, or a full abort. Calculates a health score (0-100) based on weighted metrics and writes it to DynamoDB. If the health score drops below the configured threshold, it sets the abort flag that the execution agent checks.

### Validation Agent

Runs after migration completes. Connects to both source and target databases, runs the validation suite (row counts, checksums, object counts, constraint checks, performance baselines), compares results, and generates compliance reports. Uses Bedrock to summarize findings in natural language for non-technical stakeholders.

### Rollback Agent

Triggered by the monitoring agent (automatic, based on health score), by a human (manual, via the dashboard), or by the validation agent (NO-GO decision at Gate 3). Executes the pre-generated rollback scripts in order: stop replication, restore source from backup, reopen source, re-enable scheduled jobs, verify source health, notify the team, and log the failure to the knowledge base for future learning.


## Knowledge Base

Every migration, whether successful or failed, is logged to DynamoDB. The knowledge base stores:

- Source and target engine types
- Database size and complexity metrics
- Risk score predicted vs actual outcome
- Downtime estimated vs actual
- Errors encountered and how they were resolved
- Whether rollback was triggered and why

Over time, the assessment agent uses this history to improve its risk predictions and downtime estimates. The Bedrock prompts include relevant past migration data as context when scoring new migrations.


## Competitive Landscape

### Flyway (by Redgate)

Flyway is a schema version control tool. It tracks database schema changes using versioned SQL files (V1__create_users.sql, V2__add_email_column.sql) and maintains a schema history table in the database to record what has been applied. It supports 22+ databases including PostgreSQL, Oracle, SQL Server, MySQL, MariaDB, MongoDB (preview), Snowflake, and others.

What Flyway does well:

- Versioned, repeatable schema migrations using plain SQL files with naming conventions
- Schema history table as an audit trail of every migration applied
- Undo migrations (paid Teams tier only) that reverse specific versioned migrations
- Schema diff and drift detection through Flyway Desktop GUI
- CI/CD integration via Maven, Gradle, CLI, and Java API
- DDL transaction support for safe rollback on failure (PostgreSQL, SQL Server, DB2, Derby, EnterpriseDB only)

What Flyway does not do:

- No data migration. Flyway changes the schema structure. It does not move rows between databases.
- No cross-engine migration. Flyway works within a single database engine. It cannot convert Oracle schema to PostgreSQL.
- No risk assessment. There is no analysis of whether a migration is safe to run or what could go wrong.
- No live monitoring during migration execution.
- No intelligent rollback. Undo migrations assume the original migration fully succeeded. On databases without DDL transactions, a partially failed migration cannot be cleanly undone.
- No post-migration validation beyond confirming the SQL ran successfully.
- No stored procedure or trigger conversion.
- Undo migrations cannot recover dropped tables, deleted data, or truncated columns. Flyway documentation explicitly states this is not a substitute for backups.

### Liquibase (by Liquibase Inc.)

Liquibase is a database change governance platform. The open-source community edition handles schema versioning similar to Flyway but with broader format support (XML, YAML, JSON, SQL changelogs). The commercial Liquibase Secure product adds governance, drift detection, audit trails, and compliance controls. It supports 60+ databases including PostgreSQL, Oracle, SQL Server, MySQL, Snowflake, Databricks, BigQuery, MongoDB, and DB2 for z/OS.

What Liquibase does well:

- Multi-format change definitions (SQL, XML, YAML, JSON) with a database-agnostic abstraction layer
- Built-in rollback support in the free tier, with auto-generated rollback SQL for many common operations
- Drift detection that compares a database's current state against its expected state and flags out-of-process changes
- Tamper-evident audit trails logging every change with user identity, target environment, timestamp, and metadata
- Policy checks that validate schema rules and block non-compliant changes before deployment
- Compliance framework support (SOX, HIPAA, PCI-DSS, GDPR, DORA) through structured observability reports
- Conditional deployment logic and master changelog orchestration for complex environments
- Separation of duties enforcement and role-based access control in CI/CD pipelines

What Liquibase does not do:

- No data migration. Like Flyway, Liquibase manages schema structure changes. It does not move data between databases.
- No cross-engine migration. It does not convert schema from one database engine to another.
- No risk assessment or downtime estimation before applying changes.
- No live monitoring during execution beyond success/failure of individual changesets.
- No stored procedure or trigger conversion between engines.
- No intelligent decision-making. It enforces rules that humans define, but it does not analyze a database and recommend what to do.

### Flyway and Liquibase vs MigrateIQ -- Overlap Analysis

The three products operate in adjacent but fundamentally different spaces. The following table maps specific capabilities across all three.

| Capability | Flyway | Liquibase | MigrateIQ |
|---|---|---|---|
| Schema version tracking | Yes, via history table and versioned SQL files | Yes, via changelog and DATABASECHANGELOGHISTORY table | No. MigrateIQ does not version-control incremental schema changes during development. |
| Incremental schema changes (add column, alter table) | Yes, core function | Yes, core function | No. MigrateIQ handles one-time full-schema migration, not iterative dev-cycle changes. |
| Rollback of schema changes | Undo migrations (paid tier, limited) | Built-in rollback with auto-generated SQL (free tier) | Full rollback to pre-migration state using database-native tools (RMAN, pg_basebackup, native backup/restore). |
| Drift detection | Flyway Desktop only | Built-in, with risk scoring | Not applicable. MigrateIQ operates during migration events, not as a continuous governance layer. |
| Audit trail | Schema history table | Tamper-evident logs with compliance framework support | Migration execution log with every step, decision, and outcome stored in DynamoDB. |
| Compliance reporting | None | SOX, HIPAA, PCI-DSS, GDPR, DORA reports | Post-migration compliance report (Excel, PDF) covering data integrity validation results. |
| CI/CD integration | Maven, Gradle, CLI, Java API | CLI, CI/CD pipeline embedding, policy gates | Not a CI/CD tool. Operates as a standalone migration execution platform. |
| Database support | 22+ databases | 60+ databases | All databases supported by AWS DMS and SCT (Oracle, SQL Server, PostgreSQL, MySQL, MariaDB, Db2, SAP ASE, MongoDB). |
| Cross-engine schema conversion | No | No | Yes, via AWS SCT and AI agent for complex conversions. |
| Data migration (moving rows) | No | No | Yes, via AWS DMS (full load and CDC). Core function. |
| Risk assessment | No | No | Yes. AI agent analyzes source DB metadata and scores risk before migration begins. |
| Downtime estimation | No | No | Yes. AI agent estimates downtime based on data volume, complexity, and historical data. |
| Runbook generation | No | No | Yes. AI agent generates ordered migration plan with scripts, timelines, and rollback procedures. |
| Live monitoring with intelligence | No | No | Yes. AI agent watches logs and metrics during execution, classifies events, calculates health score, and can abort. |
| Post-migration validation (checksums, row counts, business rules) | No | No | Yes. AI agent runs deep cross-database validation suite. |
| Automatic rollback based on health | No | No | Yes. Monitoring agent triggers rollback agent when health score drops below threshold. |
| Stored procedure conversion | No | No | Yes, via SCT and AI agent for complex cases. |
| Human approval gates | No | Policy gates in CI/CD (rule-based, not approval-based) | Yes. Three mandatory human approval checkpoints before plan, execution, and go-live. |
| Knowledge base (learns from past migrations) | No | No | Yes. Every migration outcome stored and used to improve future risk predictions. |

### Where They Overlap

There are three areas where the products share common ground.

First, schema change tracking. Flyway and Liquibase track individual schema changes over time (V1, V2, V3...). MigrateIQ generates and applies a full schema in a single operation during migration. The intent is different (iterative development vs one-time migration), but the underlying action of applying DDL to a database is the same. If a client already uses Flyway or Liquibase in their development workflow, MigrateIQ should not replace that. MigrateIQ handles the production migration event; Flyway/Liquibase handle the ongoing development lifecycle before and after.

Second, rollback. All three products support some form of rollback. Flyway offers undo migrations with known limitations (paid tier, assumes full success, cannot recover dropped data). Liquibase offers auto-generated rollback SQL for supported operations. MigrateIQ uses database-native backup and restore (RMAN, pg_basebackup, native snapshots) for full-state rollback, which is more comprehensive but heavier. The approaches are complementary. Flyway/Liquibase roll back individual changesets. MigrateIQ rolls back an entire migration to a known-good state.

Third, audit and compliance. Liquibase Secure has strong compliance features (SOX, HIPAA, PCI-DSS audit trails, drift detection, policy enforcement). MigrateIQ generates compliance reports specifically for migration events (data integrity proof, validation results). For a client in a regulated industry, Liquibase Secure governs day-to-day database changes, and MigrateIQ provides the compliance artifact for the migration event itself. These are complementary, not competitive.

### Where They Do Not Overlap

The core value propositions are entirely different. Flyway and Liquibase are development-time tools that manage schema evolution across environments (dev, staging, production) as part of a CI/CD pipeline. MigrateIQ is an operations-time tool that handles the one-time event of moving a database from one platform to another.

Flyway and Liquibase do not move data, do not work across database engines, do not assess risk, do not monitor execution, do not validate data integrity post-migration, and do not make rollback decisions autonomously. MigrateIQ does not track incremental schema changes, does not integrate into CI/CD pipelines, does not enforce developer governance policies, and does not detect schema drift over time.

A client could reasonably use all three: Liquibase for day-to-day schema governance, Flyway for lightweight schema versioning in development, and MigrateIQ for the production migration event.

### Other Competitors

| Product | Focus | How It Differs from MigrateIQ |
|---|---|---|
| AWS DMS | Data movement between databases | Moves data and logs errors. No intelligence layer, no assessment, no monitoring decisions, no validation beyond basic row counts. |
| AWS SCT | Schema conversion | Generates conversion reports and DDL. Does not execute migrations, monitor health, or validate post-migration. |
| Datafold Migration Agent | AI for data pipeline migration (dbt focus) | Translates ETL pipelines and stored procedures to dbt models. Does not handle live database-to-database migration or data movement. |
| SnowConvert AI | Snowflake-specific migration | Converts Oracle, SQL Server, Teradata, and others to Snowflake. Locked to Snowflake as the only target. Not multi-target. |
| Xebia Agentic Migrator | Multi-agent SQL translation across platforms | Handles SQL and ETL conversion across 7 platforms. Does not cover the full lifecycle from assessment through cutover and rollback. |
| Oracle GoldenGate | Real-time data replication | Enterprise-grade replication for Oracle-to-any scenarios. Expensive, Oracle-centric, no AI intelligence layer. |

The gap this product fills: a full-lifecycle, multi-database, AWS-native migration platform where AI agents orchestrate AWS services end-to-end, with human approval gates at each critical decision point.


## Supported Migration Paths

Based on AWS SCT and DMS support:

| Source Engine | Supported Targets |
|---|---|
| Oracle (10.1+) | Aurora PostgreSQL, Aurora MySQL, RDS PostgreSQL, RDS MySQL, RDS Oracle (lift-and-shift) |
| SQL Server (2008 R2+) | Aurora PostgreSQL, Aurora MySQL, Babelfish, RDS PostgreSQL, RDS SQL Server (lift-and-shift) |
| MySQL (5.5+) | Aurora PostgreSQL, RDS PostgreSQL, Aurora MySQL, RDS MySQL (lift-and-shift) |
| PostgreSQL (9.1+) | Aurora PostgreSQL (lift-and-shift), Aurora MySQL, RDS MySQL |
| IBM Db2 LUW | Aurora PostgreSQL, Aurora MySQL, RDS PostgreSQL, RDS MySQL |
| SAP ASE | Aurora PostgreSQL, Aurora MySQL, RDS PostgreSQL |
| MongoDB | Amazon DocumentDB, DynamoDB |


## Technology Stack

| Layer | Technology |
|---|---|
| Multi-agent framework | CrewAI |
| LLM backend | Amazon Bedrock (Claude) |
| Database connectivity | python-oracledb, psycopg2, pymysql, pyodbc (engine-specific drivers) |
| Remote execution | AWS Systems Manager Run Command |
| Log monitoring | Amazon CloudWatch Logs, CloudWatch Alarms |
| Dashboard | Streamlit on ECS Fargate |
| Report generation | OpenPyXL (Excel), ReportLab (PDF) |
| Script templating | Jinja2 |
| Shared state | Amazon DynamoDB |
| Knowledge base | Amazon DynamoDB |
| Notifications | Amazon SNS |
| Infrastructure as Code | AWS CDK (Python) |
| Workflow orchestration | AWS Step Functions |
| Authentication | Amazon Cognito |
| Object storage | Amazon S3 |
| Container runtime | AWS ECS Fargate |
| Testing | pytest |


## Build Plan

### Phase 1 -- Foundation and Assessment Agent

- Provision AWS infrastructure via CDK: VPC, RDS instances (source and target), DynamoDB tables, S3 bucket, SNS topics.
- Implement engine-specific catalog query modules (Oracle, SQL Server, PostgreSQL, MySQL).
- Integrate Amazon Bedrock for risk scoring and assessment report generation.
- Build the assessment agent end-to-end: connect to source, collect metadata, run SCT assessment (heterogeneous only), generate risk report, upload to S3.
- Build the Streamlit dashboard with Gate 1 approval screen.

### Phase 2 -- Conversion and Planning

- Implement Jinja2 script templates for each supported engine (DataPump, RMAN, pg_dump, mysqldump, native backup/restore).
- Build the runbook agent: takes assessment output, generates ordered runbook with rollback scripts.
- Integrate SCT for automated schema conversion.
- Build Bedrock-powered conversion for stored procedures and triggers that SCT cannot handle.
- Add Gate 2 to the dashboard.

### Phase 3 -- Execution and Monitoring

- Build the execution agent: reads runbook from S3, executes steps via SSM Run Command and DMS SDK calls, tracks state in DynamoDB.
- Build the monitoring agent: reads CloudWatch logs and metrics, classifies events via Bedrock, calculates health score, sets abort signals in DynamoDB.
- Build the rollback agent: executes pre-generated rollback scripts via SSM, logs failure to knowledge base.
- Wire abort signal flow between monitoring and execution agents.

### Phase 4 -- Validation and Production Readiness

- Build the validation agent: cross-database checks (row counts, checksums, object counts, constraint status, performance baselines).
- Implement configurable business rule validation (domain-specific checks per engagement).
- Build compliance report generation (Excel and PDF).
- Add Gate 3 and live migration dashboard to Streamlit.
- Implement knowledge base logging and historical context injection into Bedrock prompts.
- End-to-end integration testing with a full migration cycle.

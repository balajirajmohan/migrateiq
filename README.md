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

| Product | Focus | Limitation |
|---|---|---|
| AWS DMS | Data movement between databases | No intelligence layer. Moves data, logs errors, and stops there. Does not assess, monitor intelligently, validate deeply, or roll back. |
| AWS SCT | Schema conversion | Generates conversion reports and DDL. Does not execute migrations, monitor health, or validate post-migration. |
| Flyway / Liquibase | Schema version control for development workflows | CI/CD tools for developers, not production migration platforms. |
| Datafold Migration Agent | AI for data pipeline migration | Focused on dbt and ETL pipeline translation, not live database-to-database migration. |
| SnowConvert AI | Snowflake-specific migration | Locked to Snowflake as the target. Not multi-target. |
| Xebia Agentic Migrator | Multi-agent SQL translation across platforms | Handles SQL conversion only. Does not cover the full lifecycle from assessment through cutover and rollback. |

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

# DIB Charges Functionality Specification

## Document Control

| Field | Value |
| --- | --- |
| Status | Draft for business and technical validation |
| Version | 0.1 |
| Source | `Requirement.txt` and screenshot documents in `DIBCharges-screenshots`, including `SQLProcedures.docx` and `PS_DIBWebServiceGateway.docx` |
| Target | C# on .NET 10; Windows service migrated to Worker Service |

## 1. Purpose

Modernize the DIB Charges application that calculates recurring and SME charges, persists charge results, creates downstream charge files, and notifies operators. The legacy source is available only as screenshots embedded in Word documents, so this specification separates observed behavior from items that still require confirmation.

## 2. System Context

The legacy solution is shown as six projects:

| Legacy project | Observed responsibility | Modernization status |
| --- | --- | --- |
| `DIBChagesBusiness` | Charge, policy, customer, product, role, and transaction entities | 25 OCR-backed model classes are reconstructed in `DIBCharges.Core.Entities`; verify names/types against the database schema |
| `DIBchargeCommon` | Constants, common utilities, errors, and messages | Safe value conversion, date formatting, and correlation ID behavior are ported; legacy connection-key decryption is intentionally excluded |
| `DIBchargeComposor` | WinForms login and charge composition UI | Not ported; the main form source and interaction details are unavailable |
| `DIBchargeDAL` | SQL Server helper | Typed, parameterized charge/raw-data/SME/file-ledger calls and transactional file import are implemented; main schema compatibility remains unverified |
| `DIBChargeHandler` | Charge calculation, configuration, SQL calls, SOAP, file, and mail handling | Regular/SME orchestration, Flex refresh, file parsing/export/archive, and configurable notifications are implemented from OCR; main/golden-file validation remains pending |
| `DIBchargeWinService` | Windows service with separate regular and SME timers | Replaced by a .NET 10 Worker Service with disabled-by-default regular/SME schedules and optional startup file import |

Observed external systems are SQL Server, a SOAP FlexService, file-system or remote file delivery, and SMTP. `SQLProcedures.docx` contains 139 procedure screenshots; selected charge procedures and parameter mappings are implemented in `DIBCharges.Data`. `PS_DIBWebServiceGateway.docx` contains 19 WSDL screenshots and defines `clientRequestwithReturn` as a generic string-in/string-out SOAP operation. The customer/account XML, correlation ID, and response parsing are implemented in `DIBCharges.FlexService`. One unresolved SQL name discrepancy is that the VB handler references `sp_DCS_GetAFLInfoRawData`, while the supplied SQL document defines `sp_DCS_GetAffluentRawData`; the new DAL follows the supplied SQL name. The actual database schema, approved test endpoint and responses, operational ownership, and failure contracts still require system-owner validation.

## 3. Actors

| Actor | Responsibility |
| --- | --- |
| Charge operations | Monitor scheduled runs, review failures, and reconcile output files |
| Charge administrator | Maintain charge types, groups, policies, customer segments, products, currencies, and related setup data |
| SQL Server | Provide charge configuration, account/transaction input, duplicate checks, and durable charge records |
| FlexService | Provide SME account and classification data |
| Downstream file consumer | Receive and process generated charge files |
| Mail service | Deliver completion and failure notifications |

## 4. Functional Requirements

| ID | Requirement | Evidence / status |
| --- | --- | --- |
| FR-01 | Run the regular charge cycle on a configured day and time. The observed implementation selects the previous calendar month and skips a period already marked processed. | Scheduler and regular processing implemented; disabled pending main-environment and business validation |
| FR-02 | Run the SME charge cycle at a configured time, using the current charge month and a processed-day/period check. | Scheduler and SME processing implemented; disabled pending main-environment verification of `sp_DCS_GetSMEIds` |
| FR-03 | Calculate fixed charges as the configured unit amount. For transaction-based charges, charge only transactions above the free-transaction allowance. | Formula implemented and unit tested |
| FR-04 | Apply configured charge type, group, segment, sub-segment, product, transaction, account, omission, duplicate, payroll, teller, and average-balance rules. | Implemented from OCR; boundary cases need business-approved main-environment examples |
| FR-05 | Persist regular and SME charge results and maintain idempotent processed-period state. | Parameterized inserts, duplicate/omission checks, transactional input import, and output ledger are implemented; main schema and partial-run recovery remain unverified |
| FR-06 | Generate regular and SME text files, archive them, and split oversized files according to configured limits. | Windows-1256 serialization, sequence fields, descriptions, archiving, and split files are implemented; compare with approved golden files before production |
| FR-07 | Enrich SME records from the registered-customer, additional-user, and annual-maintenance sources through FlexService and update local SME data. | SOAP wrapper and SME source/update orchestration are implemented; test endpoint/responses and `sp_DCS_GetSMEIds` availability need verification |
| FR-08 | Send completion and error notifications to configured recipients. | SMTP sender is implemented and disabled by default; main SMTP configuration and delivery are unverified |
| FR-09 | Provide an administrative UI for login and management of charge/configuration entities and policies. | A DIB-branded WinForms login and read-only charge-summary dashboard are implemented. CRUD screens for charge types, groups, policies, users, and other reference data remain unported |
| FR-10 | Record operational events and errors without exposing credentials or customer data. | Windows Event Log provider is configured in the worker shell; business-level audit details remain pending |

## 5. Observed Business Rules and Data

### 5.1 Charge arithmetic

- A non-transaction charge uses the configured unit charge.
- A transaction charge uses `max(0, transaction count - free transaction count) * unit charge`.
- The worker applies duplicate, omission, payroll/teller, free-transaction, and maximum-balance checks as observed. The OCR is imperfect; confirm boundary behavior with business-owned examples.
- The legacy code uses floating-point values in some charge paths. The new core uses `decimal` for monetary arithmetic; rounding and currency scale still require business approval.

### 5.2 Charge file

- The service creates text files for regular and SME charge runs and archives output.
- The export screenshot shows a `~` delimiter and Windows-1256 encoding.
- The field document lists CIF, segment, sub-segment, charge group, account number, transaction code, product code, charge-balance account number, average balance, month, and transaction count.
- Sequence generation, field ordering, padding, sign/decimal formatting, line limits, split naming, and empty-file behavior must be compared byte-for-byte with approved legacy output before replacing the current consumer feed.

### 5.3 SME enrichment

The screenshots show three SME source groups: registered customers, additional users, and annual maintenance customers. The old service sends records through a SOAP FlexService and updates local categories, groups, segments, sub-segments, and currencies before charge calculation.

## 6. Non-Functional Requirements

- Target .NET 10. The worker is Windows-specific and targets `net10.0-windows`.
- Scheduled processing must be idempotent across service restarts and concurrent deployments.
- Secrets must be supplied through an approved secret store or protected deployment configuration, never committed in source or checked into `appsettings.json`.
- Service logs must not contain passwords, account numbers, CIF values, or full charge records.
- The service account must have only the required database, file, SOAP, SMTP, and log permissions.
- Charge files must be validated against consumer-approved examples before production use.

## 7. Acceptance Criteria

The migration is ready for production only when all of the following are true:

1. The business owner approves the regular and SME schedules, time zone, accounting period, and rerun policy.
2. The screenshot procedures are transcribed and reviewed against the database schema, dependency order, supported SQL Server version, and test database; repository operations have integration tests.
3. The screenshot WSDL is validated against a machine-readable contract, required operation and payload, test endpoint, authentication method, and test data; SOAP behavior has contract tests.
4. Approved regular and SME output samples are available and generated files match the required bytes, including encoding, ordering, padding, splitting, and sequence numbers.
5. Duplicate, omission, payroll, teller, free-transaction, and balance-boundary rules have business-approved examples and tests.
6. Authentication is migrated away from MD5, and all credentials visible in the supplied screenshots have been rotated.
7. Failure recovery, notification recipients, archive retention, monitoring, and rollback procedures are approved.
8. The WinForms composer is either ported with agreed scope or explicitly retired/replaced.

## 8. Current Implementation Boundary

The repository contains OCR-backed C# business models, shared utilities, typed SQL operations, the Flex SOAP client, regular/SME cycle orchestration, input parsing/transactional import, output export/archive/splitting, configurable mail notifications, and a DIB-branded WinForms login/dashboard. Schedules and file import default to disabled. Local tests use fakes/temp files. No main SQL, SOAP, FTP, or SMTP request has been sent. Desktop local-password login expects PBKDF2 hashes; legacy cipher compatibility is opt-in and should only be enabled for an approved migration test. Production remains gated on main schema and stored-procedure signature/behavior verification, business-approved rule cases, golden-file comparison, SMTP delivery checks, and porting or retiring the administration CRUD screens.
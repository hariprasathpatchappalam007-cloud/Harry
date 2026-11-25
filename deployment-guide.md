# DIB Charges Deployment Guide

## 1. Purpose and Deployment Status

This guide covers building and installing the .NET 10 Worker Service in a development or staging Windows environment. The charge pipeline is implemented from OCR, but main-environment compatibility and approved output samples have not been verified. Do not enable schedules or file import until the production gates in the [functionality specification](functionality-specification.md) are closed.

## 2. Prerequisites

- A Windows x64 host supported by .NET 10.
- .NET 10 SDK on the build machine.
- Administrator access for service registration and Event Log source creation.
- A dedicated Windows service account for the installed service.
- SQL, Flex SOAP, file import/export, cycle orchestration, and SMTP adapters are implemented. No main-environment SQL, SOAP, FTP, or SMTP connection has been tested.

## 3. Build and Test

From the repository root, run:

```powershell
dotnet --list-sdks
dotnet restore .\DIBCharges.sln
dotnet build .\DIBCharges.sln --configuration Release
dotnet test .\DIBCharges.sln --configuration Release
```

### Optional Main-Environment Preflight

These opt-in tests perform read-only checks only. Run them against the main environment only with the system owner's approval and dedicated, approved test data. They do not execute charge inserts, generate files, or enable the worker schedule. No main-environment request has been run from this workspace.

Provide values to the local test process through the approved secret/configuration mechanism. Never commit them or paste connection strings, credentials, or customer data into source control or chat.

The SQL preflight requires `DIBCHARGES_MAIN_SQL_CONNECTION` and checks that required procedures exist. The fixture lookup additionally requires `DIBCHARGES_MAIN_TEST_CHARGE_GROUP`, `DIBCHARGES_MAIN_TEST_SEGMENT`, `DIBCHARGES_MAIN_TEST_SUBSEGMENT`, `DIBCHARGES_MAIN_TEST_PRODUCT_CODE`, `DIBCHARGES_MAIN_TEST_TRANSACTION_CODE`, `DIBCHARGES_MAIN_TEST_CHARGE_TYPE_ID`, and `DIBCHARGES_MAIN_TEST_BALANCE`.

Run the read-only SQL checks with:

```powershell
dotnet test .\tests\DIBCharges.Data.Tests\DIBCharges.Data.Tests.csproj --configuration Release --filter "FullyQualifiedName~MainEnvironment"
```

The FlexService customer check requires `DIBCHARGES_MAIN_FLEX_ENDPOINT`, `DIBCHARGES_MAIN_FLEX_CUSTOMER_FUNCTION_ID`, `DIBCHARGES_MAIN_FLEX_CUSTOMER_EXTERNAL_HOST_ID`, `DIBCHARGES_MAIN_FLEX_CUSTOMER_CHANNEL`, `DIBCHARGES_MAIN_FLEX_CUSTOMER_SERVICE_CODE`, and an approved test CIF. The account check additionally requires `DIBCHARGES_MAIN_FLEX_ACCOUNT_FUNCTION_ID`, `DIBCHARGES_MAIN_FLEX_ACCOUNT_EXTERNAL_HOST_ID`, `DIBCHARGES_MAIN_FLEX_ACCOUNT_CHANNEL`, `DIBCHARGES_MAIN_FLEX_ACCOUNT_SERVICE_CODE`, and an approved test account. Store these values in the secure environment; do not put account/CIF values into source or chat.

Run the customer lookup check with:

```powershell
dotnet test .\tests\DIBCharges.FlexService.Tests\DIBCharges.FlexService.Tests.csproj --configuration Release --filter "FullyQualifiedName~MainEnvironment"
```

Without the required variables, these tests are reported as skipped. Keep `ChargeSchedule:Regular:Enabled` and `ChargeSchedule:Sme:Enabled` set to `false`.

Publish a self-contained Windows x64 build:

```powershell
dotnet publish .\src\DIBCharges.Worker\DIBCharges.Worker.csproj `
  --configuration Release `
  --runtime win-x64 `
  --self-contained true `
  --output .\artifacts\publish
```

Publish the WinForms desktop application separately:

```powershell
dotnet publish src/DIBCharges.Desktop/DIBCharges.Desktop.csproj `
  --configuration Release `
  --runtime win-x64 `
  --self-contained true `
  --output artifacts/desktop-publish
```

Review the build and test output before promotion. Preserve the published `appsettings.json` with the deployment artifact; do not place secrets in it.

Run the desktop client from `artifacts/desktop-publish/DIBCharges.Desktop.exe`. Its `appsettings.json` must contain the approved `ConnectionStrings:DibCharges` value supplied through the secure deployment environment.

## 4. Configure the Service

Edit `appsettings.json` in the published directory. The regular and SME schedules are disabled by default:

- `ChargeSchedule:Regular:Enabled` controls the configured day-of-month run. Its charge month is the previous calendar month.
- `ChargeSchedule:Sme:Enabled` controls the SME run. Its charge month is the current calendar month.
- `ChargeSchedule:*:Time` uses 24-hour `HH:mm` local host time.
- `ChargeSchedule:PollIntervalSeconds` controls schedule polling and must be between 1 and 3600.

The example times and regular run day are taken from the screenshots and must be confirmed by operations. Confirm the Windows host time zone before approving a schedule. Configure `ConnectionStrings:DibCharges` and `FlexService:Endpoint` through the approved environment secret/configuration provider. Supply `FlexService:CustomerFunctionId`, `CustomerExternalHostId`, `CustomerChannel`, `CustomerServiceCode`, and the corresponding `Account*` values from the approved environment configuration. Configure `ChargeProcessing:PayrollChargeTypeId`, `TellerChargeTypeIds`, output/archive/split directories, and file prefixes from operations-approved values.

Keep `ChargeSchedule:Regular:Enabled`, `ChargeSchedule:Sme:Enabled`, `ChargeFileInput:Enabled`, and `Mail:Enabled` set to `false` until each component is approved for the environment. If file import is later enabled, configure its input/archive directories, prefix, delimiter, encoding, and every zero-based field index from a verified file specification; the checked-in defaults intentionally use `-1` indexes.

If mail is later enabled, configure the SMTP host, port, TLS flag, sender, and cycle-specific recipients. Supply `Mail:Username` and `Mail:Password` via the approved secret store/environment, never checked-in `appsettings.json`.

The desktop login checks active users through `sp_DCS_GetUser`. Configure `DesktopAuthentication:DirectoryDomain` for Windows-domain accounts. Local accounts should store a `PBKDF2-SHA256` hash in `USERS.PASSWORD`. `DesktopAuthentication:AllowLegacyCipherCompatibility` defaults to `false`; enabling it permits the fixed-key legacy cipher shown in the screenshots and should be limited to an approved migration test, then disabled.

The SQL and SOAP adapters have local tests but have not been tested against the main environment. A required-procedure check cannot verify parameter schemas or behavior; confirm the supplied procedure definitions, including `sp_DCS_GetSMEIds`, against the deployed database before enabling schedules.

Do not copy connection strings, FTP/SMTP passwords, or other credentials from the screenshot documents. They are plaintext in the legacy material and must be considered compromised. Rotate them and use the organization-approved secret store once the integrations are implemented.

## 5. Install on Windows

Run the following from an elevated PowerShell session on the target host. This example installs to `C:\DIBCharges`:

```powershell
New-Item -ItemType Directory -Force C:\DIBCharges | Out-Null
Copy-Item .\artifacts\publish\* C:\DIBCharges -Recurse -Force

if (-not [System.Diagnostics.EventLog]::SourceExists('DIB Charges')) {
    New-EventLog -LogName Application -Source 'DIB Charges'
}

sc.exe create DIBCharges binPath= '"C:\DIBCharges\DIBCharges.Worker.exe"' start= demand DisplayName= 'DIB Charges Worker'
```

The service name (`DIBCharges`) must match the name passed to Windows-service hosting; the display name may contain spaces. If the service was already created with a different name, stop and delete that registration, then create it again after publishing the updated worker:

```powershell
sc.exe stop DIBCharges
sc.exe delete DIBCharges
```

Assign the dedicated service account in `services.msc` under the service's **Log On** tab. Grant it read/execute access to `C:\DIBCharges`. Add only the additional permissions required by the approved database and file integrations after those adapters are implemented. Do not grant local administrator rights.

## 6. Start and Verify

With schedules, file import, and mail disabled, start the service only in development or staging:

```powershell
sc.exe start DIBCharges
Get-Service DIBCharges
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'DIB Charges' } -MaxEvents 20 |
    Format-List TimeCreated, LevelDisplayName, Message
```

The service should start and remain running. No charge run, file import, or email should occur with the defaults. Do not enable schedules until the missing SME procedure and main-environment mappings are confirmed and output files match approved samples.

Stop and remove the staging service with:

```powershell
sc.exe stop DIBCharges
sc.exe delete DIBCharges
```

## 7. Upgrade and Rollback

1. Stop the service and back up the installed binaries and configuration.
2. Publish and test the new version in staging.
3. Replace binaries while preserving the approved environment-specific configuration.
4. Start the service and review its Event Log entries before enabling any approved job.
5. For rollback, stop the service, restore the previous binaries and configuration, and start it again.

## 8. Production Release Gate

Production deployment is blocked until SQL schemas and stored-procedure signatures are confirmed, SQL/SOAP/SMTP preflights pass in an approved environment, file outputs match approved legacy samples, exposed credentials are rotated, and business owners approve rule cases, scheduling, idempotency/recovery, monitoring, retention, and service permissions. The WinForms composer must also be ported or formally retired. Keep schedules, file import, and mail disabled until all gates are signed off.
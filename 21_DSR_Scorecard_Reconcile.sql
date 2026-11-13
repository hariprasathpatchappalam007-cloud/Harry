-- Deploy in the application database, using SSMS or sqlcmd -b. SQL Server 2012+.
-- Does not start a reconciliation or change the saved month on redeployment.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.lead_details', N'U') IS NULL
    OR OBJECT_ID(N'dbo.lead_details_finance', N'U') IS NULL
    THROW 51100, 'DSR reconciliation requires both dbo lead tables.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.lead_details_finance') AND name = N'LEAD_DSR'
      AND system_type_id IN (48, 52, 56, 60, 106, 108, 122, 127)
)
    THROW 51110, 'Finance LEAD_DSR must use an exact numeric type, not text, real or float.', 1;

IF OBJECT_ID(N'dbo.DSR_Scorecard_State', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DSR_Scorecard_State
    (
        StateId TINYINT NOT NULL CONSTRAINT PK_DSR_Scorecard_State PRIMARY KEY,
        NextMonthStart DATE NOT NULL,
        LastRunId BIGINT NULL,
        LastCompletedAtUtc DATETIME2(7) NULL,
        CONSTRAINT CK_DSR_Scorecard_State CHECK
            (StateId = 1 AND NextMonthStart >= '20140101' AND DAY(NextMonthStart) = 1)
    );
    INSERT dbo.DSR_Scorecard_State (StateId, NextMonthStart) VALUES (1, '20140101');
END;

IF OBJECT_ID(N'dbo.DSR_Scorecard_Run', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DSR_Scorecard_Run
    (
        RunId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DSR_Scorecard_Run PRIMARY KEY,
        MonthStart DATE NOT NULL,
        ToDateExclusive DATE NOT NULL,
        StartedAtUtc DATETIME2(7) NOT NULL,
        FinishedAtUtc DATETIME2(7) NULL,
        RunStatus VARCHAR(12) NOT NULL,
        CandidateCount INT NULL,
        UpdatedCount INT NULL,
        AlreadyMatchedCount INT NULL,
        DeferredCount INT NULL,
        SkippedCount INT NULL,
        DatabaseLogin SYSNAME NOT NULL,
        ErrorNumber INT NULL,
        ErrorMessage NVARCHAR(4000) NULL,
        CONSTRAINT CK_DSR_Scorecard_Run_Status CHECK (RunStatus IN ('Running', 'Succeeded', 'Failed'))
    );
END;

IF OBJECT_ID(N'dbo.DSR_Scorecard_Audit', N'U') IS NULL
BEGIN
    -- Preserve the real lead/application/finance types instead of guessing lengths or scale.
    SELECT TOP (0)
        IDENTITY(BIGINT,1,1) AS AuditId,
        CAST(0 AS BIGINT) AS RunId,
        ld.lead_no,
        ld.app_ref_no,
        ld.lead_stage,
        ld.Createdon_date AS LeadCreatedOn,
        CASE WHEN 1 = 0 THEN f.LEAD_DSR ELSE NULL END AS OldFinDSR,
        CASE WHEN 1 = 0 THEN f.LEAD_DSR ELSE NULL END AS NewFinDSR,
        CAST(NULL AS DECIMAL(38,20)) AS SCC_DSR,
        CAST(NULL AS NVARCHAR(MAX)) AS ScorecardDsrText,
        CAST(NULL AS SYSNAME) AS ScorecardDatabase,
        CAST(NULL AS DATETIME2(7)) AS ScorecardCreatedOn,
        CAST(NULL AS DATETIME2(7)) AS RecordedAtUtc,
        CAST(NULL AS DATETIMEOFFSET(7)) AS RecordedAtServerTime,
        CAST(NULL AS VARCHAR(24)) AS Outcome,
        CAST(0 AS BIT) AS IsCompleted,
        CAST(NULL AS NVARCHAR(1000)) AS Detail
    INTO dbo.DSR_Scorecard_Audit
    FROM dbo.lead_details ld
    INNER JOIN dbo.lead_details_finance f ON f.lead_no = ld.lead_no;

    ALTER TABLE dbo.DSR_Scorecard_Audit ADD CONSTRAINT PK_DSR_Scorecard_Audit PRIMARY KEY (AuditId);
    ALTER TABLE dbo.DSR_Scorecard_Audit ADD CONSTRAINT FK_DSR_Scorecard_Audit_Run
        FOREIGN KEY (RunId) REFERENCES dbo.DSR_Scorecard_Run(RunId);
    ALTER TABLE dbo.DSR_Scorecard_Audit ADD CONSTRAINT CK_DSR_Scorecard_Audit_Outcome CHECK
    (
        lead_no IS NOT NULL AND RecordedAtUtc IS NOT NULL AND RecordedAtServerTime IS NOT NULL
        AND IsCompleted IS NOT NULL AND Outcome IS NOT NULL
        AND ((IsCompleted = 1 AND Outcome IN ('Updated', 'AlreadyMatched') AND SCC_DSR IS NOT NULL)
          OR (Outcome IN ('MissingScorecard', 'BlankDSR', 'InvalidXML', 'InvalidDSR')))
    );
    CREATE UNIQUE INDEX UX_DSR_Scorecard_Audit_Completed
        ON dbo.DSR_Scorecard_Audit(lead_no) WHERE IsCompleted = 1;
    CREATE INDEX IX_DSR_Scorecard_Audit_Run ON dbo.DSR_Scorecard_Audit(RunId, AuditId);
END;

IF COL_LENGTH(N'dbo.DSR_Scorecard_Run', N'SkippedCount') IS NULL
    ALTER TABLE dbo.DSR_Scorecard_Run ADD SkippedCount INT NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.DSR_Scorecard_Audit') AND name = N'IX_DSR_Scorecard_Audit_Lead')
    CREATE INDEX IX_DSR_Scorecard_Audit_Lead ON dbo.DSR_Scorecard_Audit(lead_no);

-- Retain historical attempts, but complete each previously unresolved lead once.
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @MigrationLock INT;
    EXEC @MigrationLock = sys.sp_getapplock
        @Resource = N'DSR_Scorecard_ReconcileMonth', @LockMode = 'Exclusive',
        @LockOwner = 'Transaction', @LockTimeout = 0, @DbPrincipal = 'public';
    IF @MigrationLock < 0
        THROW 51111, 'Stop the running DSR reconciliation before deploying the terminal-outcome policy.', 1;

    ALTER TABLE dbo.DSR_Scorecard_Audit DROP CONSTRAINT CK_DSR_Scorecard_Audit_Outcome;
    ALTER TABLE dbo.DSR_Scorecard_Audit WITH CHECK ADD CONSTRAINT CK_DSR_Scorecard_Audit_Outcome CHECK
    (
        lead_no IS NOT NULL AND RecordedAtUtc IS NOT NULL AND RecordedAtServerTime IS NOT NULL
        AND IsCompleted IS NOT NULL AND Outcome IS NOT NULL
        AND ((IsCompleted = 1 AND Outcome IN ('Updated', 'AlreadyMatched') AND SCC_DSR IS NOT NULL)
          OR (Outcome IN ('MissingScorecard', 'BlankDSR', 'InvalidXML', 'InvalidDSR')))
    );

    ;WITH LatestUnresolved AS
    (
        SELECT a.AuditId, ROW_NUMBER() OVER (PARTITION BY a.lead_no ORDER BY a.AuditId DESC) AS Attempt
        FROM dbo.DSR_Scorecard_Audit a
        WHERE NOT EXISTS
            (SELECT 1 FROM dbo.DSR_Scorecard_Audit done WHERE done.lead_no = a.lead_no AND done.IsCompleted = 1)
    )
    UPDATE a SET IsCompleted = 1
    FROM dbo.DSR_Scorecard_Audit a
    INNER JOIN LatestUnresolved latest ON latest.AuditId = a.AuditId
    WHERE latest.Attempt = 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

IF OBJECT_ID(N'dbo.Proc_DSR_Scorecard_ReconcileMonth', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.Proc_DSR_Scorecard_ReconcileMonth AS RETURN;');
GO
ALTER PROCEDURE dbo.Proc_DSR_Scorecard_ReconcileMonth
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET ANSI_PADDING ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;

    IF @@TRANCOUNT <> 0
        THROW 51101, 'Run DSR reconciliation outside an existing transaction.', 1;

    DECLARE @LockResult INT, @RunId BIGINT, @MonthStart DATE, @NextMonth DATE;
    DECLARE @Today DATE = CONVERT(DATE, GETDATE());
    DECLARE @ToExclusive DATE, @Updated INT = 0, @Matched INT = 0, @Skipped INT = 0;
    DECLARE @RecordedUtc DATETIME2(7), @RecordedLocal DATETIMEOFFSET(7);

    EXEC @LockResult = sys.sp_getapplock
        @Resource = N'DSR_Scorecard_ReconcileMonth', @LockMode = 'Exclusive',
        @LockOwner = 'Session', @LockTimeout = 0, @DbPrincipal = 'public';
    IF @LockResult < 0
        THROW 51102, 'Another DSR reconciliation owns the monthly processing lock.', 1;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.DSR_Scorecard_State WHERE StateId = 1)
            THROW 51103, 'DSR month state is missing; restore it before running.', 1;

        -- A terminated session may leave a Running log; obtaining the lock proves it has ended.
        UPDATE dbo.DSR_Scorecard_Run
        SET RunStatus = 'Failed', FinishedAtUtc = SYSUTCDATETIME(),
            ErrorNumber = 51104, ErrorMessage = N'Previous session ended before completing; its month will be retried.'
        WHERE RunStatus = 'Running';

        SELECT @MonthStart = NextMonthStart FROM dbo.DSR_Scorecard_State WHERE StateId = 1;
        IF @MonthStart > @Today
            SET @MonthStart = '20140101';
        SET @NextMonth = DATEADD(MONTH, 1, @MonthStart);
        SET @ToExclusive = CASE WHEN @NextMonth > @Today THEN DATEADD(DAY, 1, @Today) ELSE @NextMonth END;

        INSERT dbo.DSR_Scorecard_Run
            (MonthStart, ToDateExclusive, StartedAtUtc, RunStatus, DatabaseLogin)
        VALUES (@MonthStart, @ToExclusive, SYSUTCDATETIME(), 'Running', ORIGINAL_LOGIN());
        SET @RunId = SCOPE_IDENTITY();

        SELECT DISTINCT ld.lead_no
        INTO #Leads
        FROM dbo.lead_details ld
        INNER JOIN dbo.lead_details_finance f ON f.lead_no = ld.lead_no
        WHERE ld.lead_no IS NOT NULL
          AND ld.Createdon_date >= @MonthStart AND ld.Createdon_date < @ToExclusive
          AND ld.lead_stage IN ('CUST_OL_ACCEPT', 'OPS_PMU', 'OPS_LODGMENT', 'End_Of_Process')
          AND NOT EXISTS
              (SELECT 1 FROM dbo.DSR_Scorecard_Audit a WHERE a.lead_no = ld.lead_no)
        OPTION (RECOMPILE);
        CREATE UNIQUE CLUSTERED INDEX IX_Leads ON #Leads(lead_no);

        SELECT l.lead_no, SCC.createdon_date AS ScorecardCreatedOn,
            CONVERT(NVARCHAR(MAX), SCC.RequestXML) AS RequestText,
            CONVERT(SYSNAME, N'tamweel_old') AS ScorecardDatabase
        INTO #Scorecards
        FROM #Leads l
        CROSS APPLY
        (
            SELECT TOP (1) WITH TIES s.createdon_date, s.RequestXML
            FROM [tamweel_old].[dbo].[SOA_CallLog_SCORECARD] s
            WHERE s.lead_no = l.lead_no AND s.method_name = 'SAS_ScoreCard'
            ORDER BY s.createdon_date DESC
        ) SCC;
        IF EXISTS (SELECT lead_no FROM #Scorecards GROUP BY lead_no HAVING COUNT(*) > 1)
            THROW 51109, 'Latest old scorecard timestamp is tied for a lead; resolve the ambiguity before retrying.', 1;
        CREATE UNIQUE CLUSTERED INDEX IX_Scorecards ON #Scorecards(lead_no);

        INSERT #Scorecards (lead_no, ScorecardCreatedOn, RequestText, ScorecardDatabase)
        SELECT l.lead_no, SCC.createdon_date, CONVERT(NVARCHAR(MAX), SCC.RequestXML), N'tamweel_archival'
        FROM #Leads l
        CROSS APPLY
        (
            SELECT TOP (1) WITH TIES s.createdon_date, s.RequestXML
            FROM [tamweel_archival].[dbo].[SOA_CallLog_SCORECARD] s
            WHERE s.lead_no = l.lead_no AND s.method_name = 'SAS_ScoreCard'
            ORDER BY s.createdon_date DESC
        ) SCC
        WHERE NOT EXISTS (SELECT 1 FROM #Scorecards s WHERE s.lead_no = l.lead_no);

        SELECT l.lead_no, s.ScorecardDatabase, s.ScorecardCreatedOn,
            TRY_CONVERT(XML, s.RequestText) AS RequestDocument
        INTO #Documents
        FROM #Leads l
        LEFT JOIN #Scorecards s ON s.lead_no = l.lead_no;

        SELECT d.lead_no, d.ScorecardDatabase, d.ScorecardCreatedOn,
            NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(
                d.RequestDocument.value('(//*[local-name()="Dsr"]/text())[1]', 'nvarchar(max)'),
                CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' '))), N'') AS DsrText,
            CASE WHEN d.ScorecardDatabase IS NULL THEN 'MissingScorecard'
                 WHEN d.RequestDocument IS NULL THEN 'InvalidXML' END AS DocumentIssue
        INTO #Parsed
        FROM #Documents d;

        BEGIN TRANSACTION;

        -- Re-read eligibility and lock destination rows until both update and audit commit.
        SELECT ld.lead_no, ld.app_ref_no, ld.lead_stage, ld.Createdon_date AS LeadCreatedOn,
            f.LEAD_DSR AS OldFinDSR, f.LEAD_DSR AS NewFinDSR,
            p.ScorecardDatabase, p.ScorecardCreatedOn, p.DsrText,
            TRY_CONVERT(DECIMAL(38,20), p.DsrText) AS SCC_DSR,
            CONVERT(VARCHAR(24), CASE
                WHEN p.DocumentIssue IS NOT NULL THEN p.DocumentIssue
                WHEN p.DsrText IS NULL THEN 'BlankDSR'
                ELSE 'Pending' END) AS Outcome
        INTO #Work
        FROM #Parsed p
        INNER JOIN dbo.lead_details ld WITH (HOLDLOCK) ON ld.lead_no = p.lead_no
        INNER JOIN dbo.lead_details_finance f WITH (UPDLOCK, HOLDLOCK) ON f.lead_no = ld.lead_no
        WHERE ld.Createdon_date >= @MonthStart AND ld.Createdon_date < @ToExclusive
          AND ld.lead_stage IN ('CUST_OL_ACCEPT', 'OPS_PMU', 'OPS_LODGMENT', 'End_Of_Process')
          AND NOT EXISTS
              (SELECT 1 FROM dbo.DSR_Scorecard_Audit a WHERE a.lead_no = ld.lead_no)
        OPTION (RECOMPILE);

        IF EXISTS (SELECT lead_no FROM #Work GROUP BY lead_no HAVING COUNT(*) > 1)
            THROW 51105, 'Duplicate lead/finance rows found; no updates committed for this month.', 1;
        CREATE UNIQUE CLUSTERED INDEX IX_Work ON #Work(lead_no);

        -- Reject unrepresentable source values instead of silently rounding them to 2 decimals.
        UPDATE #Work SET Outcome = 'InvalidDSR'
        WHERE Outcome = 'Pending'
          AND (SCC_DSR IS NULL
            OR (CHARINDEX('.', DsrText) > 0
                AND SUBSTRING(DsrText, CHARINDEX('.', DsrText) + 21, 2147483647) LIKE '%[1-9]%'));

        UPDATE #Work SET NewFinDSR = SCC_DSR WHERE Outcome = 'Pending';
        IF EXISTS (SELECT 1 FROM #Work WHERE Outcome = 'Pending' AND NewFinDSR <> SCC_DSR)
            THROW 51106, 'Scorecard DSR loses precision in destination LEAD_DSR; no updates committed.', 1;

        UPDATE #Work
        SET Outcome = CASE WHEN OldFinDSR = NewFinDSR THEN 'AlreadyMatched' ELSE 'Updated' END
        WHERE Outcome = 'Pending';

        SET @RecordedUtc = SYSUTCDATETIME();
        SET @RecordedLocal = SYSDATETIMEOFFSET();

        -- OUTPUT captures actual stored before/after values and works with existing AFTER triggers.
        SELECT TOP (0) lead_no, OldFinDSR, NewFinDSR INTO #Changed FROM #Work;
        UPDATE f SET LEAD_DSR = w.NewFinDSR
        OUTPUT inserted.lead_no, deleted.LEAD_DSR, inserted.LEAD_DSR
            INTO #Changed(lead_no, OldFinDSR, NewFinDSR)
        FROM dbo.lead_details_finance f
        INNER JOIN #Work w ON w.lead_no = f.lead_no
        WHERE w.Outcome = 'Updated';
        SET @Updated = @@ROWCOUNT;

        IF @Updated <> (SELECT COUNT(*) FROM #Work WHERE Outcome = 'Updated')
            THROW 51107, 'Finance update row count changed unexpectedly; month rolled back.', 1;
        IF EXISTS
        (
            SELECT 1 FROM #Work w
            LEFT JOIN dbo.lead_details_finance f ON f.lead_no = w.lead_no
            WHERE w.Outcome IN ('Updated', 'AlreadyMatched')
              AND (f.lead_no IS NULL OR f.LEAD_DSR IS NULL OR f.LEAD_DSR <> w.NewFinDSR)
        )
            THROW 51108, 'Stored finance DSR differs from the intended value; month rolled back.', 1;

        INSERT dbo.DSR_Scorecard_Audit
        (
            RunId, lead_no, app_ref_no, lead_stage, LeadCreatedOn, OldFinDSR, NewFinDSR,
            SCC_DSR, ScorecardDsrText, ScorecardDatabase, ScorecardCreatedOn,
            RecordedAtUtc, RecordedAtServerTime, Outcome, IsCompleted, Detail
        )
        SELECT @RunId, w.lead_no, w.app_ref_no, w.lead_stage, w.LeadCreatedOn,
            CASE WHEN w.Outcome = 'Updated' THEN c.OldFinDSR ELSE w.OldFinDSR END,
            CASE WHEN w.Outcome = 'Updated' THEN c.NewFinDSR ELSE w.NewFinDSR END,
            w.SCC_DSR, w.DsrText, w.ScorecardDatabase, w.ScorecardCreatedOn,
            @RecordedUtc, @RecordedLocal, w.Outcome,
            1,
            CASE w.Outcome
                WHEN 'MissingScorecard' THEN N'No matching SAS_ScoreCard row in either source; permanently completed without an UPDATE.'
                WHEN 'BlankDSR' THEN N'DSR is absent or blank; finance unchanged; permanently completed.'
                WHEN 'InvalidXML' THEN N'Selected scorecard XML is NULL or malformed; finance unchanged; permanently completed.'
                WHEN 'InvalidDSR' THEN N'DSR is not representable as decimal(38,20); finance unchanged; permanently completed.'
                WHEN 'AlreadyMatched' THEN N'Finance already matches; permanently completed without an UPDATE.'
                ELSE N'Finance updated from selected scorecard; permanently completed.' END
        FROM #Work w
        LEFT JOIN #Changed c ON c.lead_no = w.lead_no;

        SELECT @Matched = COUNT(*) FROM #Work WHERE Outcome = 'AlreadyMatched';
        SELECT @Skipped = COUNT(*) FROM #Work WHERE Outcome NOT IN ('Updated', 'AlreadyMatched');

        UPDATE dbo.DSR_Scorecard_State
        SET NextMonthStart = CASE WHEN @NextMonth > @Today THEN CONVERT(DATE, '20140101') ELSE @NextMonth END,
            LastRunId = @RunId, LastCompletedAtUtc = SYSUTCDATETIME()
        WHERE StateId = 1;
        UPDATE dbo.DSR_Scorecard_Run
        SET RunStatus = 'Succeeded', FinishedAtUtc = SYSUTCDATETIME(),
            CandidateCount = (SELECT COUNT(*) FROM #Work),
            UpdatedCount = @Updated, AlreadyMatchedCount = @Matched, DeferredCount = 0, SkippedCount = @Skipped
        WHERE RunId = @RunId;
        COMMIT TRANSACTION;

        EXEC sys.sp_releaseapplock @Resource = N'DSR_Scorecard_ReconcileMonth',
            @LockOwner = 'Session', @DbPrincipal = 'public';
        SELECT * FROM dbo.DSR_Scorecard_Run WHERE RunId = @RunId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        UPDATE dbo.DSR_Scorecard_Run
        SET RunStatus = 'Failed', FinishedAtUtc = SYSUTCDATETIME(),
            ErrorNumber = ERROR_NUMBER(), ErrorMessage = ERROR_MESSAGE()
        WHERE RunId = @RunId;
        EXEC sys.sp_releaseapplock @Resource = N'DSR_Scorecard_ReconcileMonth',
            @LockOwner = 'Session', @DbPrincipal = 'public';
        THROW;
    END CATCH;
END;
GO

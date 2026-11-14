/*
    Read-only DSR difference report for 2021.
    Stages the year's leads and latest scorecards once, then processes XML one
    month at a time and returns ONE consolidated
    result grid for the year. ReportMonth identifies each monthly split.
    Finance is not updated. Only non-zero, calculable differences are returned.

    Latest SAS_ScoreCard row in tamweel_old takes priority; archival is used
    only when no matching old row exists. Existing stages are preserved.
    SQL Server 2012+, including database compatibility level 100.

    No main-table indexes or data changes are made. Hash joins and ROW_NUMBER
    avoid repeated unindexed TOP (1) lookups per lead. Only temporary tables
    are indexed. Ensure tempdb has space for the yearly staging and ranking.
    Scorecard timestamps are NOT restricted to the lead's creation month/year.
    As before, rows tied on the latest timestamp have no guaranteed tie-breaker.
*/

SET NOCOUNT ON;

DECLARE @FirstMonth date = '20210101';
DECLARE @AfterLastMonth date = '20220101';
DECLARE @MonthStart date = @FirstMonth;
DECLARE @MonthEnd date;
DECLARE @MonthYear int;
DECLARE @MonthNumber int;

IF OBJECT_ID('tempdb..#YearDSRDifferences') IS NOT NULL DROP TABLE #YearDSRDifferences;
IF OBJECT_ID('tempdb..#YearLeads') IS NOT NULL DROP TABLE #YearLeads;
IF OBJECT_ID('tempdb..#YearLeadKeys') IS NOT NULL DROP TABLE #YearLeadKeys;
IF OBJECT_ID('tempdb..#YearScorecards') IS NOT NULL DROP TABLE #YearScorecards;
IF OBJECT_ID('tempdb..#YearMissingLeadKeys') IS NOT NULL DROP TABLE #YearMissingLeadKeys;

SELECT DISTINCT
    DATEFROMPARTS(YEAR(ld.Createdon_date), MONTH(ld.Createdon_date), 1) AS ReportMonth,
    ld.lead_stage, ld.lead_no, ld.app_ref_no,
    ld.Createdon_date AS LeadCreatedOnDate,
    ld.updatedon_date AS LeadUpdatedOn,
    ldf.LEAD_DSR AS Fin_DSR
INTO #YearLeads
FROM lead_details ld
INNER JOIN lead_details_finance ldf ON ldf.lead_no = ld.lead_no
WHERE ld.lead_no IS NOT NULL
  AND ldf.LEAD_DSR IS NOT NULL
  AND ld.lead_stage IN ('CUST_OL_ACCEPT', 'OPS_PMU', 'OPS_LODGMENT', 'End_Of_Process')
  AND ld.Createdon_date >= @FirstMonth
  AND ld.Createdon_date < @AfterLastMonth
OPTION (HASH JOIN, RECOMPILE);

CREATE CLUSTERED INDEX IX_YearLeads_Month_Lead ON #YearLeads(ReportMonth, lead_no);

SELECT DISTINCT lead_no INTO #YearLeadKeys FROM #YearLeads;
CREATE UNIQUE CLUSTERED INDEX IX_YearLeadKeys_LeadNo ON #YearLeadKeys(lead_no);

RAISERROR(N'Year leads staged. Selecting latest old scorecards in one set-based pass.',
    0, 1) WITH NOWAIT;

;WITH RankedOld AS
(
    SELECT keys.lead_no, s.createdon_date, s.RequestXML,
        ROW_NUMBER() OVER (PARTITION BY keys.lead_no ORDER BY s.createdon_date DESC) AS ScorecardRank
    FROM [tamweel_old].[dbo].[SOA_CallLog_SCORECARD] s
    INNER JOIN #YearLeadKeys keys ON keys.lead_no = s.lead_no
    WHERE s.method_name = 'SAS_ScoreCard'
)
SELECT lead_no, createdon_date AS ScorecardCreatedOn,
    CONVERT(NVARCHAR(MAX), RequestXML) AS RequestText
INTO #YearScorecards
FROM RankedOld
WHERE ScorecardRank = 1
OPTION (HASH JOIN, RECOMPILE);

CREATE UNIQUE CLUSTERED INDEX IX_YearScorecards_LeadNo ON #YearScorecards(lead_no);

SELECT keys.lead_no INTO #YearMissingLeadKeys
FROM #YearLeadKeys keys
WHERE NOT EXISTS (SELECT 1 FROM #YearScorecards old WHERE old.lead_no = keys.lead_no);
CREATE UNIQUE CLUSTERED INDEX IX_YearMissingLeadKeys_LeadNo ON #YearMissingLeadKeys(lead_no);

IF EXISTS (SELECT 1 FROM #YearMissingLeadKeys)
BEGIN
    RAISERROR(N'Selecting archival scorecards only for missing old-source leads.',
        0, 1) WITH NOWAIT;
    ;WITH RankedArchival AS
    (
        SELECT keys.lead_no, s.createdon_date, s.RequestXML,
            ROW_NUMBER() OVER (PARTITION BY keys.lead_no ORDER BY s.createdon_date DESC) AS ScorecardRank
        FROM [tamweel_archival].[dbo].[SOA_CallLog_SCORECARD] s
        INNER JOIN #YearMissingLeadKeys keys ON keys.lead_no = s.lead_no
        WHERE s.method_name = 'SAS_ScoreCard'
    )
    INSERT #YearScorecards (lead_no, ScorecardCreatedOn, RequestText)
    SELECT lead_no, createdon_date, CONVERT(NVARCHAR(MAX), RequestXML)
    FROM RankedArchival
    WHERE ScorecardRank = 1
    OPTION (HASH JOIN, RECOMPILE);
END;

DROP TABLE #YearMissingLeadKeys;
DROP TABLE #YearLeadKeys;

SELECT TOP (0)
    @FirstMonth AS ReportMonth,
    leads.lead_stage,
    leads.lead_no,
    leads.app_ref_no,
    leads.LeadCreatedOnDate AS Lead_CreatedOn,
    leads.LeadUpdatedOn,
    SCC.ScorecardCreatedOn AS Scorecard_CreatedOn,
    leads.Fin_DSR AS Lead_DSR,
    CAST(NULL AS DECIMAL(38,20)) AS Scorecard_DSR,
    CAST(NULL AS DECIMAL(38,20)) - leads.Fin_DSR AS DSR_Difference
INTO #YearDSRDifferences
FROM #YearLeads leads
LEFT JOIN #YearScorecards SCC ON 1 = 0;

WHILE @MonthStart < @AfterLastMonth
BEGIN
    SET @MonthEnd = DATEADD(MONTH, 1, @MonthStart);

    IF OBJECT_ID('tempdb..#YearMonthScorecards') IS NOT NULL DROP TABLE #YearMonthScorecards;

    SELECT SCC.lead_no, SCC.ScorecardCreatedOn,
        CAST(SCC.RequestText AS XML).value(
            '(//*[local-name()="Dsr"]/text())[1]', 'DECIMAL(38,20)') AS SCC_DSR
    INTO #YearMonthScorecards
    FROM #YearScorecards SCC
    WHERE EXISTS
    (
        SELECT 1 FROM #YearLeads leads
        WHERE leads.lead_no = SCC.lead_no AND leads.ReportMonth = @MonthStart
    )
    OPTION (RECOMPILE);

    CREATE UNIQUE CLUSTERED INDEX IX_YearMonthScorecards_LeadNo ON #YearMonthScorecards(lead_no);

    INSERT #YearDSRDifferences
    (
        ReportMonth, lead_stage, lead_no, app_ref_no, Lead_CreatedOn,
        LeadUpdatedOn, Scorecard_CreatedOn, Lead_DSR, Scorecard_DSR, DSR_Difference
    )
    SELECT @MonthStart, leads.lead_stage, leads.lead_no, leads.app_ref_no,
        leads.LeadCreatedOnDate, leads.LeadUpdatedOn, SCC.ScorecardCreatedOn,
        leads.Fin_DSR, SCC.SCC_DSR, SCC.SCC_DSR - leads.Fin_DSR
    FROM #YearLeads leads
    INNER JOIN #YearMonthScorecards SCC ON SCC.lead_no = leads.lead_no
    WHERE leads.ReportMonth = @MonthStart
      AND SCC.SCC_DSR IS NOT NULL
      AND SCC.SCC_DSR <> leads.Fin_DSR;

    SET @MonthYear = YEAR(@MonthStart);
    SET @MonthNumber = MONTH(@MonthStart);
    RAISERROR(N'Completed %04d-%02d. Differences collected for the final yearly result.',
        0, 1, @MonthYear, @MonthNumber) WITH NOWAIT;

    DROP TABLE #YearMonthScorecards;
    SET @MonthStart = @MonthEnd;
END;

SELECT ReportMonth, lead_stage, lead_no, app_ref_no, Lead_CreatedOn,
    Scorecard_CreatedOn, Lead_DSR, Scorecard_DSR, DSR_Difference
FROM #YearDSRDifferences
ORDER BY ReportMonth, LeadUpdatedOn DESC, lead_no;

DROP TABLE #YearDSRDifferences;
DROP TABLE #YearScorecards;
DROP TABLE #YearLeads;

USE [LMS_DEV]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.Proc_HFLMS_AfterSales_GetDataFromAllAppsMaster', N'P') IS NOT NULL
    DROP PROCEDURE dbo.Proc_HFLMS_AfterSales_GetDataFromAllAppsMaster;
GO

CREATE PROCEDURE dbo.Proc_HFLMS_AfterSales_GetDataFromAllAppsMaster
    @ApplicationId NVARCHAR(200) = NULL,
    @CustomerId    NVARCHAR(200) = NULL,
    @DateOfBirth   NVARCHAR(30)  = NULL,
    @CustomerName  NVARCHAR(200) = NULL,
    @CustomerName1 NVARCHAR(200) = NULL,
    @PassportNo    NVARCHAR(100) = NULL,
    @MobileNo      NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        m.CUSTOMERID AS CUSTOMERID,
        m.APPLICATIONID AS APPLICATIONID,
        m.APPLICATIONID AS APPLICATION_ID,
        m.CUSTOMERNAME1 AS CUSTOMERNAME1,
        m.CUSTOMER_NAME1 AS CUSTOMER_NAME1,
        m.CUSTOMERNAME2 AS CUSTOMERNAME2,
        m.CUSTOMERNAME2 AS CUSTOMER_NAME2,
        m.CUSTOMERNAME3 AS CUSTOMERNAME3,
        m.CUSTOMERNAME4 AS CUSTOMERNAME4,
        m.DATEOFBIRTH1 AS DATEOFBIRTH1,
        m.PASSPORTNUMBER AS PASSPORTNUMBER,
        m.MOBILENUMBER AS MOBILENUMBER,
        m.NATIONALITY1 AS NATIONALITY1,
        m.MAILING_POBOX AS MAILING_POBOX,
        m.MAILING_CITY AS MAILING_CITY,
        m.MAILING_COUNTRY AS MAILING_COUNTRY,
        m.MOBILECODE AS MOBILECODE,
        ISNULL(CONVERT(NVARCHAR(50), m.MOBILECODE), N'')
            + ISNULL(CONVERT(NVARCHAR(100), m.MOBILENUMBER), N'') AS MOBILE_CODE,
        ISNULL(CONVERT(NVARCHAR(50), m.MOBILECODE), N'') + N' '
            + ISNULL(CONVERT(NVARCHAR(100), m.MOBILENUMBER), N'') AS Mobile_Num,
        m.RESI_TEL_CODE AS RESI_TEL_CODE,
        m.RESI_TEL_NUM AS RESI_TEL_NUM,
        m.OFFICE_TEL_CODE AS OFFICE_TEL_CODE,
        m.OFFICE_TEL_NUM AS OFFICE_TEL_NUM,
        m.PERSONAL_EMAIL AS PERSONAL_EMAIL,
        m.PERSONAL_EMAIL AS P_EMAIL,
        m.OFFICE_EMAIL AS OFFICE_EMAIL,
        m.FAX_CODE AS FAX_CODE,
        m.FAX_NUMBER AS FAX_NUMBER,
        m.ALTERNATE_CONTACT_CODE AS ALTERNATE_CONTACT_CODE,
        m.ALTERNATE_CONTACT AS ALTERNATE_CONTACT,
        m.HC_TEL_CODE AS HC_TEL_CODE,
        m.HC_TEL_NUM AS HC_TEL_NUM,
        m.RESI_ADDRESS1 AS RESI_ADDRESS1,
        m.RESI_ADDRESS2 AS RESI_ADDRESS2,
        m.RESI_ADDRESS3 AS RESI_ADDRESS3,
        m.EMPLOYMENTTYPE AS EMPLOYMENTTYPE,
        m.CURRENTEMPLOYER1 AS CURRENTEMPLOYER1,
        m.OFFICE_ADDRESS1 AS OFFICE_ADDRESS1,
        m.OFFICE_ADDRESS2 AS OFFICE_ADDRESS2,
        m.OFFICE_ADDRESS3 AS OFFICE_ADDRESS3,
        m.DESIGNATION1 AS DESIGNATION1,
        m.PROPERTYNAME AS PROPERTYNAME,
        m.APPRAISEDPROPERTYVALUE AS APPRAISEDPROPERTYVALUE,
        m.CURRENTSTATUS AS CURRENTSTATUS,
        m.FINANCEVALUE AS FINANCEVALUE,
        m.DOWNPAYMENT AS DOWNPAYMENT,
        m.PROFITFEE AS PROFITFEE,
        m.FINALRATE AS FINALRATE,
        m.CURR_RATE AS CURR_RATE,
        m.PROPERTYDETAILS AS PROPERTYDETAILS,
        m.ISTISNATENOR AS ISTISNATENOR,
        m.IJARATENOR AS IJARATENOR,
        m.DSR AS DSR,
        m.FTV AS FTV,
        m.INSTALLMENTAMOUNT AS INSTALLMENTAMOUNT,
        m.EMI_AMOUNT AS EMI_AMOUNT,
        m.PROPERTYTYPE AS PROPERTYTYPE,
        m.ISTISNAPRODUCT AS ISTISNAPRODUCT,
        m.IJARAPRODUCT AS IJARAPRODUCT,
        m.PRIN_OS AS PRIN_OS,
        m.CURR_ACC_BAL AS CURR_ACC_BAL,
        m.CONT_STAT AS CONT_STAT,
        m.SEC_STATUS AS SEC_STATUS,
        '' AS DELINQ_STAT,
        '0' AS DELINQ_BUCKET,
        m.BUILTUPAREA AS BUILTUPAREA,
        m.DIB_BOOKING AS DIB_BOOKING,
        m.REPAYMENT_TYPE AS REPAYMENT_TYPE,
        m.REPAYMENT_START_DATE AS REPAYMENT_START_DATE,
        m.REPAYMENT_BANK_NAME AS REPAYMENT_BANK_NAME,
        m.REPAYMENT_ACCOUNT_TYPE AS REPAYMENT_ACCOUNT_TYPE,
        m.REPAYMENT_IBAN AS REPAYMENT_IBAN
    FROM dbo.CORE_FLEX_ALL_APPS_MASTER AS m
    OUTER APPLY
    (
        SELECT
            CASE
                WHEN ISDATE(CONVERT(NVARCHAR(50), m.DATEOFBIRTH1)) = 1
                    THEN CONVERT(DATETIME, CONVERT(NVARCHAR(50), m.DATEOFBIRTH1))
                ELSE NULL
            END AS ParsedDateOfBirth,
            CASE
                WHEN ISDATE(CONVERT(NVARCHAR(50), m.LASTUPDATED)) = 1
                    THEN CONVERT(DATETIME, CONVERT(NVARCHAR(50), m.LASTUPDATED))
                ELSE NULL
            END AS ParsedLastUpdated
    ) AS parsedDates
    WHERE
        (NULLIF(LTRIM(RTRIM(@ApplicationId)), N'') IS NULL
            OR m.APPLICATIONID LIKE N'%' + LTRIM(RTRIM(@ApplicationId)) + N'%')
        AND (NULLIF(LTRIM(RTRIM(@CustomerId)), N'') IS NULL
            OR m.CUSTOMERID LIKE N'%' + LTRIM(RTRIM(@CustomerId)) + N'%')
        AND (NULLIF(LTRIM(RTRIM(@DateOfBirth)), N'') IS NULL
            OR CONVERT(NVARCHAR(10), parsedDates.ParsedDateOfBirth, 23)
                LIKE N'%' + LTRIM(RTRIM(@DateOfBirth)) + N'%'
            OR CONVERT(NVARCHAR(10), parsedDates.ParsedDateOfBirth, 103)
                LIKE N'%' + LTRIM(RTRIM(@DateOfBirth)) + N'%')
        AND (NULLIF(LTRIM(RTRIM(@CustomerName)), N'') IS NULL
            OR m.CUSTOMERNAME1 LIKE N'%' + LTRIM(RTRIM(@CustomerName)) + N'%'
            OR m.CUSTOMERNAME2 LIKE N'%' + LTRIM(RTRIM(@CustomerName)) + N'%'
            OR m.CUSTOMERNAME3 LIKE N'%' + LTRIM(RTRIM(@CustomerName)) + N'%'
            OR m.CUSTOMERNAME4 LIKE N'%' + LTRIM(RTRIM(@CustomerName)) + N'%')
        AND (NULLIF(LTRIM(RTRIM(@CustomerName1)), N'') IS NULL
            OR m.CUSTOMERNAME1 LIKE N'%' + LTRIM(RTRIM(@CustomerName1)) + N'%')
        AND (NULLIF(LTRIM(RTRIM(@PassportNo)), N'') IS NULL
            OR m.PASSPORTNUMBER LIKE N'%' + LTRIM(RTRIM(@PassportNo)) + N'%'
           -- OR m.PASSPORTNUMBER1 LIKE N'%' + LTRIM(RTRIM(@PassportNo)) + N'%'
            OR m.PASSPORTNUMBER2 LIKE N'%' + LTRIM(RTRIM(@PassportNo)) + N'%'
            OR m.PASSPORTNUMBER3 LIKE N'%' + LTRIM(RTRIM(@PassportNo)) + N'%'
            OR m.PASSPORTNUMBER4 LIKE N'%' + LTRIM(RTRIM(@PassportNo)) + N'%')
        AND (NULLIF(LTRIM(RTRIM(@MobileNo)), N'') IS NULL
            OR m.MOBILENUMBER LIKE N'%' + LTRIM(RTRIM(@MobileNo)) + N'%')
    ORDER BY
        CASE WHEN m.APPLICATIONID = LTRIM(RTRIM(@ApplicationId)) THEN 0 ELSE 1 END,
        parsedDates.ParsedLastUpdated DESC;
END;
GO
--EXEC dbo.Proc_HFLMS_AfterSales_GetDataFromAllAppsMaster @ApplicationId = N'APP12345';
--EXEC dbo.Proc_HFLMS_AfterSales_GetDataFromAllAppsMaster @CustomerName = N'Example Name', @DateOfBirth = N'15/04/1985';

IF OBJECT_ID(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'U') IS NULL
    RAISERROR('CORE_FLEX_ALL_APPS_MASTER must exist before deploying DataSync.', 16, 1)
GO

IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'APPLICATION_ID') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD APPLICATION_ID NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'APP_START_DATE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD APP_START_DATE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'CONT_STAT') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD CONT_STAT NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'CURR_ACC_BAL') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD CURR_ACC_BAL NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'CURR_RATE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD CURR_RATE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'EMI_AMOUNT') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD EMI_AMOUNT NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'EMI_DATE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD EMI_DATE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'EMI_FREQUENCY') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD EMI_FREQUENCY NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'IJARA_BOOKED') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD IJARA_BOOKED NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'IJARA_BOOKED_DATE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD IJARA_BOOKED_DATE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'INSTALL_NO') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD INSTALL_NO NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'MATURITY_DATE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD MATURITY_DATE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'PDC_AMOUNT') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD PDC_AMOUNT NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'PDC_NO') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD PDC_NO NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'PRIN_OS') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD PRIN_OS NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'REM_TENOR_CURR') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD REM_TENOR_CURR NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'REPAY_TENOR') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD REPAY_TENOR NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'RETURN_VALUE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD RETURN_VALUE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'TBR_CURR') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD TBR_CURR NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'TOT_INST_NO') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD TOT_INST_NO NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'TOTAL_BOUNCE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD TOTAL_BOUNCE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'DQ_TYPE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD DQ_TYPE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'VALUE_DATE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD VALUE_DATE NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'INSTALLMENT_NO') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD INSTALLMENT_NO INT NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'contract_ref_no') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD contract_ref_no NVARCHAR(125) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'CIF') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD CIF NVARCHAR(25) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'REPAYMENT_TYPE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD REPAYMENT_TYPE NVARCHAR(100) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'REPAYMENT_START_DATE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD REPAYMENT_START_DATE NVARCHAR(20) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'REPAYMENT_BANK_NAME') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD REPAYMENT_BANK_NAME NVARCHAR(250) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'REPAYMENT_ACCOUNT_TYPE') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD REPAYMENT_ACCOUNT_TYPE NVARCHAR(100) NULL
IF COL_LENGTH(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'REPAYMENT_IBAN') IS NULL
    ALTER TABLE dbo.CORE_FLEX_ALL_APPS_MASTER ADD REPAYMENT_IBAN NVARCHAR(100) NULL
GO

IF OBJECT_ID(N'dbo.HFLMS_AfterSales_DataSync_Run', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HFLMS_AfterSales_DataSync_Run
    (
        RunId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HFLMS_AfterSales_DataSync_Run PRIMARY KEY,
        ApplicationId NVARCHAR(200) NOT NULL,
        Operation NVARCHAR(20) NOT NULL,
        SynchronizedBy NVARCHAR(256) NOT NULL,
        SynchronizedOn DATETIME2(0) NOT NULL CONSTRAINT DF_HFLMS_AfterSales_DataSync_Run_SynchronizedOn DEFAULT (GETDATE()),
        SelectedFieldCount INT NOT NULL,
        ChangedFieldCount INT NOT NULL
    )
    CREATE INDEX IX_HFLMS_AfterSales_DataSync_Run_ApplicationId
        ON dbo.HFLMS_AfterSales_DataSync_Run(ApplicationId, RunId DESC)
END
GO

IF OBJECT_ID(N'dbo.HFLMS_AfterSales_DataSync_FieldAudit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HFLMS_AfterSales_DataSync_FieldAudit
    (
        AuditId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HFLMS_AfterSales_DataSync_FieldAudit PRIMARY KEY,
        RunId BIGINT NOT NULL,
        FieldName NVARCHAR(128) NOT NULL,
        OldValue NVARCHAR(MAX) NULL,
        NewValue NVARCHAR(MAX) NULL,
        CONSTRAINT FK_HFLMS_AfterSales_DataSync_FieldAudit_Run
            FOREIGN KEY (RunId) REFERENCES dbo.HFLMS_AfterSales_DataSync_Run(RunId)
    )
    CREATE INDEX IX_HFLMS_AfterSales_DataSync_FieldAudit_RunId
        ON dbo.HFLMS_AfterSales_DataSync_FieldAudit(RunId, AuditId)
END
GO

IF OBJECT_ID(N'dbo.Proc_HFLMS_AfterSales_DataSync_GetAuditHistory', N'P') IS NOT NULL
    DROP PROCEDURE dbo.Proc_HFLMS_AfterSales_DataSync_GetAuditHistory
GO

CREATE PROCEDURE dbo.Proc_HFLMS_AfterSales_DataSync_GetAuditHistory
    @ApplicationId NVARCHAR(200) = NULL,
    @MaxRuns INT = 25
AS
BEGIN
    SET NOCOUNT ON
    IF @MaxRuns < 1 OR @MaxRuns > 200 SET @MaxRuns = 25
    IF @ApplicationId IS NOT NULL SET @MaxRuns = 2147483647

    ;WITH RecentRuns AS
    (
        SELECT TOP (@MaxRuns)
            RunId, ApplicationId, Operation, SynchronizedBy, SynchronizedOn,
            SelectedFieldCount, ChangedFieldCount
        FROM dbo.HFLMS_AfterSales_DataSync_Run
        WHERE @ApplicationId IS NULL OR ApplicationId = @ApplicationId
        ORDER BY RunId DESC
    )
    SELECT
        run.RunId,
        run.ApplicationId,
        run.SynchronizedBy,
        run.SynchronizedOn,
        run.Operation,
        run.SelectedFieldCount,
        run.ChangedFieldCount,
        audit.FieldName,
        audit.OldValue,
        audit.NewValue
    FROM RecentRuns run
    LEFT JOIN dbo.HFLMS_AfterSales_DataSync_FieldAudit audit ON audit.RunId = run.RunId
    ORDER BY run.RunId DESC, audit.AuditId
END
GO

IF OBJECT_ID(N'dbo.Proc_HFLMS_AfterSales_DataSync_GetApplicationCandidates', N'P') IS NOT NULL
    DROP PROCEDURE dbo.Proc_HFLMS_AfterSales_DataSync_GetApplicationCandidates
GO

CREATE PROCEDURE dbo.Proc_HFLMS_AfterSales_DataSync_GetApplicationCandidates
    @SearchApplicationId NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @SearchId NVARCHAR(200)
    SET @SearchId = NULLIF(LTRIM(RTRIM(@SearchApplicationId)), N'')

    IF @SearchId IS NULL
    BEGIN
        RAISERROR('Application ID is required.', 16, 1)
        RETURN
    END

    DECLARE @HasExactLead BIT
    DECLARE @HasExactCoreApplication BIT

    SET @HasExactLead = CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.LEAD_DETAILS
        WHERE UPPER(LTRIM(RTRIM(APP_REF_NO))) = UPPER(@SearchId)
    ) THEN 1 ELSE 0 END

    SET @HasExactCoreApplication = CASE WHEN EXISTS
    (
        SELECT 1
        FROM dbo.CORE_APPLICATION_DETAILS
        WHERE UPPER(LTRIM(RTRIM(APPLICATION_ID))) = UPPER(@SearchId)
    ) THEN 1 ELSE 0 END

    ;WITH CandidateIds AS
    (
        SELECT DISTINCT normalized.CandidateId AS ApplicationId
        FROM dbo.CORE_APPLICATION_DETAILS applicationDetails
        CROSS APPLY
        (
            SELECT LTRIM(RTRIM(CONVERT(NVARCHAR(200), applicationDetails.APPLICATION_ID))) AS CandidateId
        ) normalized
        WHERE UPPER(normalized.CandidateId) = UPPER(@SearchId)
            OR
            (
                (@HasExactLead = 1 OR @HasExactCoreApplication = 0)
                AND
                (
                    (
                        UPPER(LEFT(normalized.CandidateId, LEN(@SearchId))) = UPPER(@SearchId)
                        AND SUBSTRING(normalized.CandidateId, LEN(@SearchId) + 1, 1) IN (N'-', N'_', N' ')
                    )
                    OR
                    (
                        UPPER(LEFT(normalized.CandidateId, LEN(@SearchId) + 4)) = N'CNV ' + UPPER(@SearchId)
                        AND SUBSTRING(normalized.CandidateId, LEN(@SearchId) + 5, 1) IN (N'-', N'_', N' ')
                    )
                    OR UPPER(normalized.CandidateId) = N'CNV ' + UPPER(@SearchId)
                    OR UPPER(normalized.CandidateId) = UPPER(@SearchId) + N'CNV'
                )
            )

        UNION

        SELECT CONVERT(NVARCHAR(200), @SearchId)
        WHERE @HasExactLead = 1

    )
    SELECT
        candidate.ApplicationId,
        leadMatch.APP_REF_NO AS LeadApplicationId,
        CASE WHEN leadMatch.APP_REF_NO IS NULL THEN N'Core-only' ELSE N'Lead-backed' END AS SourceType,
        CASE WHEN UPPER(candidate.ApplicationId) = UPPER(@SearchId) THEN CONVERT(BIT, 1)
            ELSE CONVERT(BIT, 0) END AS IsExactMatch
    FROM CandidateIds candidate
    OUTER APPLY
    (
        SELECT TOP (1) lead.APP_REF_NO
        FROM dbo.LEAD_DETAILS lead
        CROSS APPLY
        (
            SELECT LTRIM(RTRIM(CONVERT(NVARCHAR(200), candidate.ApplicationId))) AS CandidateId,
                LTRIM(RTRIM(CONVERT(NVARCHAR(200), lead.APP_REF_NO))) AS LeadId
        ) normalized
        WHERE UPPER(normalized.CandidateId) = UPPER(normalized.LeadId)
            OR UPPER(normalized.CandidateId) = N'CNV ' + UPPER(normalized.LeadId)
            OR UPPER(normalized.CandidateId) = UPPER(normalized.LeadId) + N'CNV'
            OR
            (
                UPPER(LEFT(normalized.CandidateId, LEN(normalized.LeadId))) = UPPER(normalized.LeadId)
                AND SUBSTRING(normalized.CandidateId, LEN(normalized.LeadId) + 1, 1) IN (N'-', N'_', N' ')
            )
            OR
            (
                UPPER(LEFT(normalized.CandidateId, LEN(normalized.LeadId) + 4)) = N'CNV ' + UPPER(normalized.LeadId)
                AND SUBSTRING(normalized.CandidateId, LEN(normalized.LeadId) + 5, 1) IN (N'-', N'_', N' ')
            )
        ORDER BY
            CASE WHEN normalized.CandidateId = normalized.LeadId THEN 0 ELSE 1 END,
            LEN(normalized.LeadId) DESC
    ) leadMatch
    ORDER BY
        CASE WHEN UPPER(candidate.ApplicationId) = UPPER(@SearchId) THEN 0 ELSE 1 END,
        candidate.ApplicationId
END
GO

IF OBJECT_ID('[dbo].[Proc_HFLMS_AfterSales_DataSync_ByApplicationId]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[Proc_HFLMS_AfterSales_DataSync_ByApplicationId]
GO

CREATE PROCEDURE [dbo].[Proc_HFLMS_AfterSales_DataSync_ByApplicationId]
    @ApplicationId NVARCHAR(200),
    @PreviewOnly BIT = 1,
    @InsertedRows INT = NULL OUTPUT,
    @UpdatedRows INT = NULL OUTPUT,
    @CustomerRowsMatched INT = NULL OUTPUT,
    @SelectedFields XML = NULL,
    @SynchronizedBy NVARCHAR(256) = N'Unknown',
    @ChangedFields INT = NULL OUTPUT,
    @LeadApplicationId NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    SET @InsertedRows = 0
    SET @UpdatedRows = 0
    SET @CustomerRowsMatched = 0
    SET @ChangedFields = 0

    IF NULLIF(LTRIM(RTRIM(@ApplicationId)), N'') IS NULL
    BEGIN
        RAISERROR('Application ID is required.', 16, 1)
        RETURN
    END

    DECLARE @LeadNo VARCHAR(100)
    SET @LeadApplicationId = NULLIF(LTRIM(RTRIM(@LeadApplicationId)), N'')

    IF @LeadApplicationId IS NOT NULL
    BEGIN
        SELECT TOP (1) @LeadNo = LEAD_NO
        FROM dbo.LEAD_DETAILS
        WHERE APP_REF_NO = @LeadApplicationId
    END
    ELSE
    BEGIN
        SELECT TOP (1)
            @LeadNo = LEAD_NO,
            @LeadApplicationId = APP_REF_NO
        FROM dbo.LEAD_DETAILS
        WHERE APP_REF_NO = @ApplicationId
    END

    IF @LeadNo IS NULL AND @LeadApplicationId IS NULL
    BEGIN
        SELECT TOP (1)
            @LeadNo = lead.LEAD_NO,
            @LeadApplicationId = lead.APP_REF_NO
        FROM dbo.LEAD_DETAILS lead
        CROSS APPLY
        (
            SELECT LTRIM(RTRIM(CONVERT(NVARCHAR(200), @ApplicationId))) AS CoreId,
                LTRIM(RTRIM(CONVERT(NVARCHAR(200), lead.APP_REF_NO))) AS LeadId
        ) normalized
        WHERE
            (
                UPPER(LEFT(normalized.CoreId, LEN(normalized.LeadId))) = UPPER(normalized.LeadId)
                AND SUBSTRING(normalized.CoreId, LEN(normalized.LeadId) + 1, 1) IN (N'-', N'_', N' ')
            )
            OR
            (
                UPPER(LEFT(normalized.CoreId, LEN(normalized.LeadId) + 4)) = N'CNV ' + UPPER(normalized.LeadId)
                AND SUBSTRING(normalized.CoreId, LEN(normalized.LeadId) + 5, 1) IN (N'-', N'_', N' ')
            )
            OR UPPER(normalized.CoreId) = N'CNV ' + UPPER(normalized.LeadId)
            OR UPPER(normalized.CoreId) = UPPER(normalized.LeadId) + N'CNV'
        ORDER BY LEN(normalized.LeadId) DESC
    END

    CREATE TABLE #SyncSource
    (
        APPLICATIONID NVARCHAR(200) NULL,
        LEAD_NO NVARCHAR(100) NULL,
        CUSTOMERID NVARCHAR(200) NULL,
        CUSTOMERID2 NVARCHAR(200) NULL,
        CUSTOMERID3 NVARCHAR(200) NULL,
        CUSTOMERID4 NVARCHAR(200) NULL,
        CUSTOMERNAME1 NVARCHAR(200) NULL,
        CUSTOMERNAME2 NVARCHAR(200) NULL,
        CUSTOMERNAME3 NVARCHAR(200) NULL,
        CUSTOMERNAME4 NVARCHAR(200) NULL,
        NATIONALITY1 NVARCHAR(200) NULL,
        NATIONALITY2 NVARCHAR(200) NULL,
        NATIONALITY3 NVARCHAR(200) NULL,
        NATIONALITY4 NVARCHAR(200) NULL,
        PASSPORTNUMBER NVARCHAR(200) NULL,
        PASSPORTNUMBER2 NVARCHAR(200) NULL,
        PASSPORTNUMBER3 NVARCHAR(200) NULL,
        PASSPORTNUMBER4 NVARCHAR(200) NULL,
        DATEOFBIRTH1 NVARCHAR(200) NULL,
        DATEOFBIRTH2 NVARCHAR(200) NULL,
        DATEOFBIRTH3 NVARCHAR(200) NULL,
        DATEOFBIRTH4 NVARCHAR(200) NULL,
        RESIDENCYTYPE NVARCHAR(200) NULL,
        CURRENTSTATUS NVARCHAR(200) NULL,
        PREAPPROVALNO NVARCHAR(200) NULL,
        MOBILECODE NVARCHAR(200) NULL,
        MOBILENUMBER NVARCHAR(200) NULL,
        LASTUPDATED NVARCHAR(200) NULL,
        BRANCH_CODE NVARCHAR(200) NULL,
        OL_ACCEPTANCE_DATE NVARCHAR(200) NULL,
        OL_GENERATION_DATE NVARCHAR(200) NULL,
        ORIGINALPROPERTYVALUE FLOAT NULL,
        APPRAISEDPROPERTYVALUE FLOAT NULL,
        ISTISNATENOR NVARCHAR(200) NULL,
        IJARATENOR NVARCHAR(200) NULL,
        FINANCEVALUE FLOAT NULL,
        DOWNPAYMENT FLOAT NULL,
        DSR NVARCHAR(200) NULL,
        FTV NVARCHAR(200) NULL,
        INSTALLMENTAMOUNT NVARCHAR(200) NULL,
        FINALRATE NVARCHAR(200) NULL,
        ISTISNAPRODUCT NVARCHAR(200) NULL,
        IJARAPRODUCT NVARCHAR(200) NULL,
        PURCHASETYPE NVARCHAR(200) NULL,
        DEVELOPER NVARCHAR(200) NULL,
        PROPERTYNAME NVARCHAR(200) NULL,
        PROPERTYDETAILS NVARCHAR(2000) NULL,
        PROPERTYTYPE NVARCHAR(200) NULL,
        BUILTUPAREA NVARCHAR(200) NULL,
        PROPERTYID NVARCHAR(200) NULL,
        EMPLOYMENTTYPE NVARCHAR(200) NULL,
        CURRENTEMPLOYER1 NVARCHAR(200) NULL,
        DESIGNATION1 NVARCHAR(200) NULL,
        INCOME1 NVARCHAR(200) NULL,
        INCOME2 NVARCHAR(200) NULL,
        INCOME3 NVARCHAR(200) NULL,
        INCOME4 NVARCHAR(200) NULL,
        PERSONAL_EMAIL NVARCHAR(200) NULL,
        OFFICE_EMAIL NVARCHAR(200) NULL,
        MAILING_POBOX NVARCHAR(200) NULL,
        MAILING_CITY NVARCHAR(200) NULL,
        MAILING_COUNTRY NVARCHAR(200) NULL,
        RESI_TEL_CODE NVARCHAR(200) NULL,
        RESI_TEL_NUM NVARCHAR(200) NULL,
        OFFICE_TEL_CODE NVARCHAR(200) NULL,
        OFFICE_TEL_NUM NVARCHAR(200) NULL,
        RESI_ADDRESS1 NVARCHAR(200) NULL,
        RESI_ADDRESS2 NVARCHAR(200) NULL,
        RESI_ADDRESS3 NVARCHAR(200) NULL,
        CORPORATECATEGORY NVARCHAR(200) NULL,
        STAFF_YN NVARCHAR(200) NULL,
        HOMECOUNTRY_ADD1 NVARCHAR(2000) NULL,
        HOMECOUNTRY_ADD2 NVARCHAR(2000) NULL,
        HOMECOUNTRY_ADD3 NVARCHAR(2000) NULL,
        MAKER_ID NVARCHAR(200) NULL,
        MAKER_DT_STAMP NVARCHAR(200) NULL,
        CHECKER_ID NVARCHAR(200) NULL,
        CHECKER_DT_STAMP NVARCHAR(200) NULL
    )

    ;WITH CoApplicants AS
    (
        SELECT lead_no,
            MAX(CASE WHEN CustomerSeq = 1 THEN CONVERT(NVARCHAR(200), CUSTOMER_NAME) END) AS CUSTOMERNAME2,
            MAX(CASE WHEN CustomerSeq = 2 THEN CONVERT(NVARCHAR(200), CUSTOMER_NAME) END) AS CUSTOMERNAME3,
            MAX(CASE WHEN CustomerSeq = 3 THEN CONVERT(NVARCHAR(200), CUSTOMER_NAME) END) AS CUSTOMERNAME4,
            MAX(CASE WHEN CustomerSeq = 1 THEN CONVERT(NVARCHAR(200), CUSTOMER_DOB, 23) END) AS DATEOFBIRTH2,
            MAX(CASE WHEN CustomerSeq = 2 THEN CONVERT(NVARCHAR(200), CUSTOMER_DOB, 23) END) AS DATEOFBIRTH3,
            MAX(CASE WHEN CustomerSeq = 3 THEN CONVERT(NVARCHAR(200), CUSTOMER_DOB, 23) END) AS DATEOFBIRTH4,
            MAX(CASE WHEN CustomerSeq = 1 THEN CONVERT(NVARCHAR(200), CUSTOMER_NATIONALITY) END) AS NATIONALITY2,
            MAX(CASE WHEN CustomerSeq = 2 THEN CONVERT(NVARCHAR(200), CUSTOMER_NATIONALITY) END) AS NATIONALITY3,
            MAX(CASE WHEN CustomerSeq = 3 THEN CONVERT(NVARCHAR(200), CUSTOMER_NATIONALITY) END) AS NATIONALITY4,
            MAX(CASE WHEN CustomerSeq = 1 THEN CONVERT(NVARCHAR(200), CUSTOMER_PASSPORTNO) END) AS PASSPORTNUMBER2,
            MAX(CASE WHEN CustomerSeq = 2 THEN CONVERT(NVARCHAR(200), CUSTOMER_PASSPORTNO) END) AS PASSPORTNUMBER3,
            MAX(CASE WHEN CustomerSeq = 3 THEN CONVERT(NVARCHAR(200), CUSTOMER_PASSPORTNO) END) AS PASSPORTNUMBER4,
            MAX(CASE WHEN CustomerSeq = 1 THEN CONVERT(NVARCHAR(200), CUSTOMERID) END) AS CUSTOMERID2,
            MAX(CASE WHEN CustomerSeq = 2 THEN CONVERT(NVARCHAR(200), CUSTOMERID) END) AS CUSTOMERID3,
            MAX(CASE WHEN CustomerSeq = 3 THEN CONVERT(NVARCHAR(200), CUSTOMERID) END) AS CUSTOMERID4,
            MAX(CASE WHEN CustomerSeq = 1 THEN CONVERT(NVARCHAR(200), CUSTOMER_SAL_APPRAISED) END) AS INCOME2,
            MAX(CASE WHEN CustomerSeq = 2 THEN CONVERT(NVARCHAR(200), CUSTOMER_SAL_APPRAISED) END) AS INCOME3,
            MAX(CASE WHEN CustomerSeq = 3 THEN CONVERT(NVARCHAR(200), CUSTOMER_SAL_APPRAISED) END) AS INCOME4
        FROM
        (
            SELECT lead_no, CUSTOMER_NAME, CUSTOMER_DOB, CUSTOMER_NATIONALITY,
                CUSTOMER_PASSPORTNO, CUSTOMERID, CUSTOMER_SAL_APPRAISED,
                ROW_NUMBER() OVER (PARTITION BY lead_no ORDER BY CustomerSRNO) AS CustomerSeq
            FROM dbo.LEAD_DETAILS_CUSTOMER
            WHERE lead_no = @LeadNo AND CustType <> 'Primary'
        ) AS SecondaryCustomers
        GROUP BY lead_no
    )
    INSERT INTO #SyncSource
    (
        APPLICATIONID, LEAD_NO, CUSTOMERID, CUSTOMERID2, CUSTOMERID3, CUSTOMERID4,
        CUSTOMERNAME1, CUSTOMERNAME2, CUSTOMERNAME3, CUSTOMERNAME4,
        NATIONALITY1, NATIONALITY2, NATIONALITY3, NATIONALITY4,
        PASSPORTNUMBER, PASSPORTNUMBER2, PASSPORTNUMBER3, PASSPORTNUMBER4,
        DATEOFBIRTH1, DATEOFBIRTH2, DATEOFBIRTH3, DATEOFBIRTH4, RESIDENCYTYPE,
        CURRENTSTATUS, PREAPPROVALNO, MOBILECODE, MOBILENUMBER, LASTUPDATED, BRANCH_CODE,
        OL_ACCEPTANCE_DATE, OL_GENERATION_DATE, ORIGINALPROPERTYVALUE, APPRAISEDPROPERTYVALUE,
        ISTISNATENOR, IJARATENOR, FINANCEVALUE, DOWNPAYMENT, DSR, FTV, INSTALLMENTAMOUNT,
        FINALRATE, ISTISNAPRODUCT, IJARAPRODUCT, PURCHASETYPE, DEVELOPER, PROPERTYNAME,
        PROPERTYDETAILS, PROPERTYTYPE, BUILTUPAREA, PROPERTYID, EMPLOYMENTTYPE,
        CURRENTEMPLOYER1, DESIGNATION1, INCOME1, INCOME2, INCOME3, INCOME4,
        PERSONAL_EMAIL, OFFICE_EMAIL, MAILING_POBOX, MAILING_CITY, MAILING_COUNTRY,
        RESI_TEL_CODE, RESI_TEL_NUM, OFFICE_TEL_CODE, OFFICE_TEL_NUM,
        RESI_ADDRESS1, RESI_ADDRESS2, RESI_ADDRESS3, CORPORATECATEGORY, STAFF_YN,
        HOMECOUNTRY_ADD1, HOMECOUNTRY_ADD2, HOMECOUNTRY_ADD3,
        MAKER_ID, MAKER_DT_STAMP, CHECKER_ID, CHECKER_DT_STAMP
    )
    SELECT TOP (1)
        CONVERT(NVARCHAR(200), @ApplicationId), CONVERT(NVARCHAR(100), LD.LEAD_NO),
        CONVERT(NVARCHAR(200), LD.CUSTOMERID),
        CA.CUSTOMERID2, CA.CUSTOMERID3, CA.CUSTOMERID4,
        CONVERT(NVARCHAR(200), LD.Customer_Name),
        CA.CUSTOMERNAME2, CA.CUSTOMERNAME3, CA.CUSTOMERNAME4,
        CONVERT(NVARCHAR(200), LD.Nationality),
        CA.NATIONALITY2, CA.NATIONALITY3, CA.NATIONALITY4,
        CONVERT(NVARCHAR(200), LD.PassportNO),
        CA.PASSPORTNUMBER2, CA.PASSPORTNUMBER3, CA.PASSPORTNUMBER4,
        CONVERT(NVARCHAR(200), LD.CUSTOMER_DOB, 23),
        CA.DATEOFBIRTH2, CA.DATEOFBIRTH3, CA.DATEOFBIRTH4,
        CONVERT(NVARCHAR(200), LD.CUSTOMER_RES_TYPE),
        CONVERT(NVARCHAR(200), LD.LEAD_STAGE),
        CONVERT(NVARCHAR(200), LD.PRE_REF_NO),
        CONVERT(NVARCHAR(200), LD.Mobile_code), CONVERT(NVARCHAR(200), LD.Mobile_No),
        CONVERT(NVARCHAR(200), LD.UpdatedOn_Date, 23), CONVERT(NVARCHAR(200), LD.Branch_Code),
        CONVERT(NVARCHAR(200), LD.OL_ACCEPT_DATE, 23), CONVERT(NVARCHAR(200), LD.OL_Issue_Date, 23),
        LDF.Lead_Prop_Trans_Value, LDF.Lead_Prop_Appr_Value,
        CONVERT(NVARCHAR(200), LDF.Lead_Istisna_Tenor), CONVERT(NVARCHAR(200), LDF.Lead_Ijara_Tenor),
        LDF.Finance_amount, LDF.Lead_Fin_DownPayment,
        CONVERT(NVARCHAR(200), LDF.Lead_DSR), CONVERT(NVARCHAR(200), LDF.LEAD_FTV),
        CONVERT(NVARCHAR(200), LDF.LEAD_EMI + LDF.LEAD_LIFE_TAKAFUL),
        CONVERT(NVARCHAR(200), LDF.Lead_Fin_ProfitRate),
        CONVERT(NVARCHAR(200), LDF.Lead_Product_ISTINSNA),
        CONVERT(NVARCHAR(200), LDF.Lead_Conversion_Product),
        CONVERT(NVARCHAR(200), LDF.Lead_Fin_TransactionType),
        CONVERT(NVARCHAR(200), LDP.Property_DeveloperName),
        CONVERT(NVARCHAR(200), LDP.Property_ProjectName),
        CONVERT(NVARCHAR(2000), LDP.Property_Address),
        CONVERT(NVARCHAR(200), LDP.Property_PropertyType),
        CONVERT(NVARCHAR(200), LDP.Property_BuA),
        CONVERT(NVARCHAR(200), LDP.Property_ProjectId),
        CONVERT(NVARCHAR(200), LDCE.EMPLOYEMENTTYPE),
        CONVERT(NVARCHAR(200), LDCE.COMPANYNAME),
        CONVERT(NVARCHAR(200), LDCE.DESIGNATION),
        CONVERT(NVARCHAR(200), LDC.CUSTOMER_SAL_APPRAISED),
        CA.INCOME2, CA.INCOME3, CA.INCOME4,
        CONVERT(NVARCHAR(200), LDC.CUSTOMER_EMAIL_P),
        CONVERT(NVARCHAR(200), LDC.CUSTOMER_EMAIL_O),
        CONVERT(NVARCHAR(200), MailingAddress.POBOX),
        CONVERT(NVARCHAR(200), MailingAddress.CITY),
        CONVERT(NVARCHAR(200), MailingAddress.Country),
        CONVERT(NVARCHAR(200), MailingAddress.PHONE_CODE),
        NULL,
        CONVERT(NVARCHAR(200), OfficeAddress.PHONE_CODE),
        NULL,
        NULL, NULL, NULL,
        NULL, NULL,
        CONVERT(NVARCHAR(2000), HomeAddress.ADDRESS_1),
        CONVERT(NVARCHAR(2000), HomeAddress.City),
        CONVERT(NVARCHAR(2000), HomeAddress.Country),
        N'SYSTEM', CONVERT(NVARCHAR(200), GETDATE(), 120),
        N'SYSTEM', CONVERT(NVARCHAR(200), GETDATE(), 120)
    FROM dbo.LEAD_DETAILS LD
    INNER JOIN dbo.LEAD_DETAILS_FINANCE LDF ON LDF.LEAD_NO = LD.LEAD_NO
    LEFT JOIN dbo.LEAD_DETAILS_PROPERTY LDP ON LDP.LEAD_NO = LD.LEAD_NO
    LEFT JOIN dbo.LEAD_DETAILS_CUSTOMER LDC
        ON LDC.LEAD_NO = LD.LEAD_NO AND LDC.CustType = 'Primary'
    LEFT JOIN dbo.LEAD_DETAILS_CUST_EMPLOYEMENT LDCE
        ON LDCE.LEAD_NO = LD.LEAD_NO
        AND LDCE.CUSTOMERSRNO = LDC.CUSTOMERSRNO
        AND LDCE.ENDDATE = '1900-01-01 00:00:00'
    OUTER APPLY
    (
        SELECT TOP (1) A.POBOX, A.CITY, A.Country, A.PHONE_CODE
        FROM dbo.LEAD_DETAILS_CUST_ADDRESS A
        WHERE A.LEAD_NO = LD.LEAD_NO
            AND A.CUSTOMERSRNO = LDC.CUSTOMERSRNO
            AND A.ADDRESS_TYPE = 'Mailing Address'
    ) MailingAddress
    OUTER APPLY
    (
        SELECT TOP (1) A.PHONE_CODE
        FROM dbo.LEAD_DETAILS_CUST_ADDRESS A
        WHERE A.LEAD_NO = LD.LEAD_NO
            AND A.CUSTOMERSRNO = LDC.CUSTOMERSRNO
            AND A.ADDRESS_TYPE = 'Office Address'
    ) OfficeAddress
    OUTER APPLY
    (
        SELECT TOP (1) A.ADDRESS_1, A.City, A.Country
        FROM dbo.LEAD_DETAILS_CUST_ADDRESS A
        WHERE A.LEAD_NO = LD.LEAD_NO
            AND A.CUSTOMERSRNO = LDC.CUSTOMERSRNO
            AND A.ADDRESS_TYPE = 'HC Address'
    ) HomeAddress
    LEFT JOIN CoApplicants CA ON CA.lead_no = LD.LEAD_NO
    WHERE LD.LEAD_NO = @LeadNo
        AND LD.APP_REF_NO = @LeadApplicationId
        AND (LDCE.ENDDATE = '1900-01-01 00:00:00' OR LDCE.ENDDATE IS NULL)
    ORDER BY LDC.CUSTOMERSRNO

    IF NOT EXISTS (SELECT 1 FROM #SyncSource)
    BEGIN
        INSERT INTO #SyncSource
            (APPLICATIONID, LEAD_NO, CUSTOMERID, LASTUPDATED, MAKER_ID, MAKER_DT_STAMP,
                CHECKER_ID, CHECKER_DT_STAMP)
        SELECT TOP (1)
            @ApplicationId,
            NULL,
            CONVERT(NVARCHAR(200), applicationDetails.CIF),
            CONVERT(NVARCHAR(200), applicationDetails.VALUE_DATE),
            N'SYSTEM',
            CONVERT(NVARCHAR(200), GETDATE(), 120),
            N'SYSTEM',
            CONVERT(NVARCHAR(200), GETDATE(), 120)
        FROM dbo.CORE_APPLICATION_DETAILS applicationDetails
        WHERE applicationDetails.APPLICATION_ID = @ApplicationId
            AND applicationDetails.APPLICATION_ID <> N'S'
        ORDER BY
            CASE WHEN ISDATE(CONVERT(NVARCHAR(250), applicationDetails.VALUE_DATE)) = 1
                THEN CONVERT(DATETIME, applicationDetails.VALUE_DATE) END DESC,
            applicationDetails.contract_ref_no DESC
    END

    IF NOT EXISTS (SELECT 1 FROM #SyncSource)
    BEGIN
        RAISERROR('No lead or Core application data was found for this application ID.', 16, 1)
        RETURN
    END

    IF (SELECT COUNT(*) FROM #SyncSource) <> 1
    BEGIN
        RAISERROR('More than one lead row was found for this application ID.', 16, 1)
        RETURN
    END

    ALTER TABLE #SyncSource ADD
        APPLICATION_ID NVARCHAR(250) NULL,
        APP_START_DATE NVARCHAR(250) NULL,
        CONT_STAT NVARCHAR(250) NULL,
        CURR_ACC_BAL NVARCHAR(250) NULL,
        CURR_RATE NVARCHAR(250) NULL,
        EMI_AMOUNT NVARCHAR(250) NULL,
        EMI_DATE NVARCHAR(250) NULL,
        EMI_FREQUENCY NVARCHAR(250) NULL,
        IJARA_BOOKED NVARCHAR(250) NULL,
        IJARA_BOOKED_DATE NVARCHAR(250) NULL,
        INSTALL_NO NVARCHAR(250) NULL,
        MATURITY_DATE NVARCHAR(250) NULL,
        PDC_AMOUNT NVARCHAR(250) NULL,
        PDC_NO NVARCHAR(250) NULL,
        PRIN_OS NVARCHAR(250) NULL,
        REM_TENOR_CURR NVARCHAR(250) NULL,
        REPAY_TENOR NVARCHAR(250) NULL,
        RETURN_VALUE NVARCHAR(250) NULL,
        TBR_CURR NVARCHAR(250) NULL,
        TOT_INST_NO NVARCHAR(250) NULL,
        TOTAL_BOUNCE NVARCHAR(250) NULL,
        DQ_TYPE NVARCHAR(250) NULL,
        VALUE_DATE NVARCHAR(250) NULL,
        INSTALLMENT_NO INT NULL,
        contract_ref_no NVARCHAR(125) NULL,
        CIF NVARCHAR(25) NULL,
        REPAYMENT_TYPE NVARCHAR(100) NULL,
        REPAYMENT_START_DATE NVARCHAR(20) NULL,
        REPAYMENT_BANK_NAME NVARCHAR(250) NULL,
        REPAYMENT_ACCOUNT_TYPE NVARCHAR(100) NULL,
        REPAYMENT_IBAN NVARCHAR(100) NULL

    SELECT TOP (1)
        candidate.RepaymentType,
        candidate.StartDate,
        candidate.ApplicationID,
        candidate.BankName,
        candidate.AccountType,
        candidate.IBAN
    INTO #RepaymentDetails
    FROM
    (
        SELECT N'DDA' AS RepaymentType, CONVERT(DATETIME2(0), OPS_CHECKER_DT_STAMP) AS StartDate,
            CONVERT(NVARCHAR(200), ApplicationID) AS ApplicationID,
            CONVERT(NVARCHAR(250), bank_name) AS BankName,
            CONVERT(NVARCHAR(100), ACCOUNT_TYPE) AS AccountType,
            CONVERT(NVARCHAR(100), IBAN) AS IBAN
        FROM dbo.Core_DDA_Registration_Details
        WHERE PURPOSE = N'Installment' AND DDS_STATUS = N'Active' AND ApplicationID = @ApplicationId
        UNION ALL
        SELECT N'DDA', CONVERT(DATETIME2(0), OPS_CHECKER_DT_STAMP),
            CONVERT(NVARCHAR(200), ApplicationID), CONVERT(NVARCHAR(250), bank_name),
            CONVERT(NVARCHAR(100), ACCOUNT_TYPE), CONVERT(NVARCHAR(100), IBAN)
        FROM dbo.Core_Flex_DDA_Registration_Details
        WHERE PURPOSE = N'Installment' AND DDS_STATUS = N'Active' AND ApplicationID = @ApplicationId
        UNION ALL
        SELECT N'New Origination', CONVERT(DATETIME2(0), bank.Createdon_Date),
            CONVERT(NVARCHAR(200), lead.app_ref_no), CONVERT(NVARCHAR(250), bank.bankname),
            CONVERT(NVARCHAR(100), bank.ACCOUNT_TYPE), CONVERT(NVARCHAR(100), bank.IBAN)
        FROM dbo.LEAD_DETAILS_BANK_STATEMENT bank
        INNER JOIN dbo.LEAD_DETAILS lead ON lead.LEAD_NO = bank.LEAD_NO
        WHERE lead.APP_REF_NO = @LeadApplicationId
    ) candidate
    ORDER BY candidate.StartDate DESC

    UPDATE s
    SET REPAYMENT_TYPE = repayment.RepaymentType,
        REPAYMENT_START_DATE = CONVERT(NVARCHAR(20), repayment.StartDate, 103),
        REPAYMENT_BANK_NAME = repayment.BankName,
        REPAYMENT_ACCOUNT_TYPE = repayment.AccountType,
        REPAYMENT_IBAN = repayment.IBAN
    FROM #SyncSource s
    CROSS JOIN #RepaymentDetails repayment

    SELECT * INTO #LeadSource FROM #SyncSource

    SELECT
        COALESCE(NULLIF(source.CUSTOMERID, N''), CONVERT(NVARCHAR(200), master.CUSTOMERID)) AS CUSTOMERID,
        COALESCE(NULLIF(source.CUSTOMERID2, N''), CONVERT(NVARCHAR(200), master.CUSTOMERID2)) AS CUSTOMERID2,
        COALESCE(NULLIF(source.CUSTOMERID3, N''), CONVERT(NVARCHAR(200), master.CUSTOMERID3)) AS CUSTOMERID3,
        COALESCE(NULLIF(source.CUSTOMERID4, N''), CONVERT(NVARCHAR(200), master.CUSTOMERID4)) AS CUSTOMERID4
    INTO #CoreLookupIDs
    FROM #SyncSource source
    LEFT JOIN dbo.CORE_FLEX_ALL_APPS_MASTER master
        ON master.APPLICATIONID = @ApplicationId

    -- Normalize digit-only IDs so older SQL Server versions can compare CIF values safely.
    SELECT customer.CustomerSlot, customer.CustomerID,
        CASE
            WHEN customerText.IdText <> N'' AND customerText.IdText NOT LIKE N'%[^0-9]%' THEN
                CASE WHEN PATINDEX(N'%[^0]%', customerText.IdText) = 0 THEN N'0'
                    ELSE SUBSTRING(customerText.IdText, PATINDEX(N'%[^0]%', customerText.IdText), 500) END
        END AS NumericCustomerID
    INTO #CoreLookupCustomerIDs
    FROM #CoreLookupIDs lookupIds
    CROSS APPLY
    (
        VALUES
            (1, lookupIds.CUSTOMERID),
            (2, lookupIds.CUSTOMERID2),
            (3, lookupIds.CUSTOMERID3),
            (4, lookupIds.CUSTOMERID4)
    ) customer (CustomerSlot, CustomerID)
    CROSS APPLY
    (
        SELECT LTRIM(RTRIM(CONVERT(NVARCHAR(500), customer.CustomerID))) AS IdText
    ) customerText
    WHERE customer.CustomerID IS NOT NULL

    SELECT customerDetails.*, lookup.CustomerSlot
    INTO #MatchedCustomerDetails
    FROM dbo.CORE_CUSTOMER_DETAILS customerDetails
    INNER JOIN #CoreLookupCustomerIDs lookup
        ON customerDetails.CUSTOMERID = lookup.CustomerID
    WHERE lookup.CustomerID IS NOT NULL

    IF EXISTS
    (
        SELECT 1
        FROM #CoreLookupCustomerIDs lookup
        WHERE lookup.NumericCustomerID IS NOT NULL
            AND NOT EXISTS
            (
                SELECT 1 FROM #MatchedCustomerDetails matched
                WHERE matched.CustomerSlot = lookup.CustomerSlot
            )
    )
    BEGIN
        INSERT #MatchedCustomerDetails
        SELECT customerDetails.*, lookup.CustomerSlot
        FROM dbo.CORE_CUSTOMER_DETAILS customerDetails
    CROSS APPLY
        (
            SELECT LTRIM(RTRIM(CONVERT(NVARCHAR(500), customerDetails.CUSTOMERID))) AS IdText
        ) customerText
        CROSS APPLY
        (
            SELECT CASE
                WHEN customerText.IdText <> N'' AND customerText.IdText NOT LIKE N'%[^0-9]%' THEN
                    CASE WHEN PATINDEX(N'%[^0]%', customerText.IdText) = 0 THEN N'0'
                        ELSE SUBSTRING(customerText.IdText, PATINDEX(N'%[^0]%', customerText.IdText), 500) END
            END AS NumericCustomerID
        ) normalizedCustomerID
        INNER JOIN #CoreLookupCustomerIDs lookup
            ON lookup.NumericCustomerID = normalizedCustomerID.NumericCustomerID
        WHERE NOT EXISTS
        (
            SELECT 1 FROM #MatchedCustomerDetails matched
            WHERE matched.CustomerSlot = lookup.CustomerSlot
        )
    END

    SELECT * INTO #CoreApplicationCandidates
    FROM dbo.CORE_APPLICATION_DETAILS
    WHERE APPLICATION_ID = @ApplicationId

    SELECT applicationDetails.*, lookup.CustomerSlot,
        lookup.NumericCustomerID AS SyncNumericCustomerID
    INTO #MatchedCoreApplications
    FROM #CoreApplicationCandidates applicationDetails
    INNER JOIN #CoreLookupCustomerIDs lookup
        ON applicationDetails.CIF = lookup.CustomerID
    WHERE lookup.CustomerID IS NOT NULL

    IF EXISTS
    (
        SELECT 1
        FROM #CoreLookupCustomerIDs lookup
        WHERE lookup.NumericCustomerID IS NOT NULL
            AND NOT EXISTS
            (
                SELECT 1 FROM #MatchedCoreApplications matched
                WHERE matched.CustomerSlot = lookup.CustomerSlot
            )
    )
    BEGIN
        INSERT #MatchedCoreApplications
        SELECT applicationDetails.*, lookup.CustomerSlot,
            lookup.NumericCustomerID AS SyncNumericCustomerID
        FROM #CoreApplicationCandidates applicationDetails
        CROSS APPLY
        (
            SELECT LTRIM(RTRIM(CONVERT(NVARCHAR(500), applicationDetails.CIF))) AS IdText
        ) cifText
        CROSS APPLY
        (
            SELECT CASE
                WHEN cifText.IdText <> N'' AND cifText.IdText NOT LIKE N'%[^0-9]%' THEN
                    CASE WHEN PATINDEX(N'%[^0]%', cifText.IdText) = 0 THEN N'0'
                        ELSE SUBSTRING(cifText.IdText, PATINDEX(N'%[^0]%', cifText.IdText), 500) END
            END AS NumericCIF
        ) normalizedCIF
        INNER JOIN #CoreLookupCustomerIDs lookup
            ON lookup.NumericCustomerID = normalizedCIF.NumericCIF
        WHERE NOT EXISTS
            (
                SELECT 1 FROM #MatchedCoreApplications matched
                WHERE matched.CustomerSlot = lookup.CustomerSlot
            )
    END

    IF NOT EXISTS (SELECT 1 FROM #MatchedCoreApplications)
    BEGIN
        INSERT #MatchedCoreApplications
        SELECT applicationDetails.*, 1, CONVERT(NVARCHAR(500), applicationDetails.CIF)
        FROM #CoreApplicationCandidates applicationDetails
    END

    CREATE NONCLUSTERED INDEX IX_MatchedCoreApplications_CustomerSlot
        ON #MatchedCoreApplications(CustomerSlot)
    CREATE NONCLUSTERED INDEX IX_MatchedCustomerDetails_CustomerSlot
        ON #MatchedCustomerDetails(CustomerSlot)

    SELECT TOP (1)
        CONVERT(NVARCHAR(250), applicationDetails.APPLICATION_ID) AS APPLICATION_ID,
        CONVERT(NVARCHAR(250), applicationDetails.APP_STRAT_DATE) AS APP_START_DATE,
        CONVERT(NVARCHAR(250), applicationDetails.CONT_STAT) AS CONT_STAT,
        CONVERT(NVARCHAR(250), applicationDetails.CURR_ACC_BAL) AS CURR_ACC_BAL,
        CONVERT(NVARCHAR(250), applicationDetails.CURR_RATE) AS CURR_RATE,
        CONVERT(NVARCHAR(250), applicationDetails.EMI_AMOUNT) AS EMI_AMOUNT,
        CONVERT(NVARCHAR(250), applicationDetails.EMI_DATE) AS EMI_DATE,
        CONVERT(NVARCHAR(250), applicationDetails.EMI_FREQUENCY) AS EMI_FREQUENCY,
        CONVERT(NVARCHAR(250), applicationDetails.IJARA_BOOKED) AS IJARA_BOOKED,
        CONVERT(NVARCHAR(250), applicationDetails.IJARA_BOOKED_DATE) AS IJARA_BOOKED_DATE,
        CONVERT(NVARCHAR(250), applicationDetails.INSTALL_NO) AS INSTALL_NO,
        CONVERT(NVARCHAR(250), applicationDetails.MATURITY_DATE) AS MATURITY_DATE,
        CONVERT(NVARCHAR(250), applicationDetails.PDC_AMOUNT) AS PDC_AMOUNT,
        CONVERT(NVARCHAR(250), applicationDetails.PDC_NO) AS PDC_NO,
        CONVERT(NVARCHAR(250), applicationDetails.PRIN_OS) AS PRIN_OS,
        CONVERT(NVARCHAR(250), applicationDetails.REM_TENOR_CURR) AS REM_TENOR_CURR,
        CONVERT(NVARCHAR(250), applicationDetails.REPAY_TENOR) AS REPAY_TENOR,
        CONVERT(NVARCHAR(250), applicationDetails.RETURN_VALUE) AS RETURN_VALUE,
        CONVERT(NVARCHAR(250), applicationDetails.TBR_CURR) AS TBR_CURR,
        CONVERT(NVARCHAR(250), applicationDetails.TOT_INST_NO) AS TOT_INST_NO,
        CONVERT(NVARCHAR(250), applicationDetails.TOTAL_BOUNCE) AS TOTAL_BOUNCE,
        CONVERT(NVARCHAR(250), applicationDetails.DQ_TYPE) AS DQ_TYPE,
        CONVERT(NVARCHAR(250), applicationDetails.VALUE_DATE) AS VALUE_DATE,
        CONVERT(INT, applicationDetails.INSTALLMENT_NO) AS INSTALLMENT_NO,
        CONVERT(NVARCHAR(125), applicationDetails.contract_ref_no) AS contract_ref_no,
        CONVERT(NVARCHAR(25), applicationDetails.CIF) AS CIF
    INTO #CoreApplicationDetails
    FROM #MatchedCoreApplications applicationDetails
    ORDER BY applicationDetails.CustomerSlot,
        CASE WHEN applicationDetails.APPLICATION_ID = @ApplicationId THEN 0 ELSE 1 END,
        CASE WHEN ISDATE(CONVERT(NVARCHAR(250), applicationDetails.VALUE_DATE)) = 1
            THEN CONVERT(DATETIME, applicationDetails.VALUE_DATE) END DESC

    UPDATE source
    SET APPLICATION_ID = core.APPLICATION_ID,
        APP_START_DATE = core.APP_START_DATE,
        CONT_STAT = core.CONT_STAT,
        CURR_ACC_BAL = core.CURR_ACC_BAL,
        CURR_RATE = core.CURR_RATE,
        EMI_AMOUNT = core.EMI_AMOUNT,
        EMI_DATE = core.EMI_DATE,
        EMI_FREQUENCY = core.EMI_FREQUENCY,
        IJARA_BOOKED = core.IJARA_BOOKED,
        IJARA_BOOKED_DATE = core.IJARA_BOOKED_DATE,
        INSTALL_NO = core.INSTALL_NO,
        MATURITY_DATE = core.MATURITY_DATE,
        PDC_AMOUNT = core.PDC_AMOUNT,
        PDC_NO = core.PDC_NO,
        PRIN_OS = core.PRIN_OS,
        REM_TENOR_CURR = core.REM_TENOR_CURR,
        REPAY_TENOR = core.REPAY_TENOR,
        RETURN_VALUE = core.RETURN_VALUE,
        TBR_CURR = core.TBR_CURR,
        TOT_INST_NO = core.TOT_INST_NO,
        TOTAL_BOUNCE = core.TOTAL_BOUNCE,
        DQ_TYPE = core.DQ_TYPE,
        VALUE_DATE = core.VALUE_DATE,
        INSTALLMENT_NO = core.INSTALLMENT_NO,
        contract_ref_no = core.contract_ref_no,
        CIF = core.CIF
    FROM #SyncSource source
    CROSS JOIN #CoreApplicationDetails core

    IF EXISTS
    (
        SELECT CustomerSlot
        FROM #MatchedCustomerDetails
        GROUP BY CustomerSlot
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Multiple core customer records matched an applicant CIF; sync was stopped to avoid nondeterministic updates.', 16, 1)
        RETURN
    END

    SELECT @CustomerRowsMatched = COUNT(*) FROM #MatchedCustomerDetails

    UPDATE s
    SET CUSTOMERNAME1 = COALESCE(d1.CUSTOMERNAME1, s.CUSTOMERNAME1),
        NATIONALITY1 = COALESCE(d1.NATIONALITY1, s.NATIONALITY1),
        PASSPORTNUMBER = COALESCE(d1.CUSTOMER_PASSPORTNO, d1.PASSPORTNUMBER, s.PASSPORTNUMBER),
        DATEOFBIRTH1 = COALESCE(d1.DATEOFBIRTH1, s.DATEOFBIRTH1),
        CURRENTSTATUS = COALESCE(d1.CURRENTSTATUS, s.CURRENTSTATUS),
        BRANCH_CODE = COALESCE(d1.BRANCH_CODE, s.BRANCH_CODE),
        PERSONAL_EMAIL = COALESCE(d1.PERSONAL_EMAIL, s.PERSONAL_EMAIL),
        OFFICE_EMAIL = COALESCE(d1.OFFICE_EMAIL, s.OFFICE_EMAIL),
        MAILING_COUNTRY = COALESCE(d1.MAILING_COUNTRY, s.MAILING_COUNTRY),
        MAILING_POBOX = COALESCE(d1.MAILING_POBOX, s.MAILING_POBOX),
        MOBILECODE = COALESCE(d1.MOBILECODE, s.MOBILECODE),
        MOBILENUMBER = COALESCE(d1.MOBILENUMBER, s.MOBILENUMBER),
        RESI_TEL_CODE = COALESCE(d1.RESI_TEL_CODE, s.RESI_TEL_CODE),
        RESI_TEL_NUM = COALESCE(d1.RESI_TEL_NUM, s.RESI_TEL_NUM),
        RESI_ADDRESS1 = COALESCE(d1.RESI_ADDRESS1, s.RESI_ADDRESS1),
        RESI_ADDRESS2 = COALESCE(d1.RESI_ADDRESS2, s.RESI_ADDRESS2),
        RESI_ADDRESS3 = COALESCE(d1.RESI_ADDRESS3, s.RESI_ADDRESS3),
        CORPORATECATEGORY = COALESCE(d1.CUSTOMER_CATEGORY, s.CORPORATECATEGORY),
        STAFF_YN = COALESCE(d1.STAFF_YN, s.STAFF_YN)
    FROM #SyncSource s
    LEFT JOIN #MatchedCustomerDetails d1 ON d1.CustomerSlot = 1

    UPDATE s
    SET CUSTOMERNAME2 = COALESCE(d2.CUSTOMERNAME1, s.CUSTOMERNAME2),
        NATIONALITY2 = COALESCE(d2.NATIONALITY1, s.NATIONALITY2),
        PASSPORTNUMBER2 = COALESCE(d2.CUSTOMER_PASSPORTNO, d2.PASSPORTNUMBER, s.PASSPORTNUMBER2),
        DATEOFBIRTH2 = COALESCE(d2.DATEOFBIRTH1, s.DATEOFBIRTH2)
    FROM #SyncSource s
    LEFT JOIN #MatchedCustomerDetails d2 ON d2.CustomerSlot = 2

    UPDATE s
    SET CUSTOMERNAME3 = COALESCE(d3.CUSTOMERNAME1, s.CUSTOMERNAME3),
        NATIONALITY3 = COALESCE(d3.NATIONALITY1, s.NATIONALITY3),
        PASSPORTNUMBER3 = COALESCE(d3.CUSTOMER_PASSPORTNO, d3.PASSPORTNUMBER, s.PASSPORTNUMBER3),
        DATEOFBIRTH3 = COALESCE(d3.DATEOFBIRTH1, s.DATEOFBIRTH3)
    FROM #SyncSource s
    LEFT JOIN #MatchedCustomerDetails d3 ON d3.CustomerSlot = 3

    UPDATE s
    SET CUSTOMERNAME4 = COALESCE(d4.CUSTOMERNAME1, s.CUSTOMERNAME4),
        NATIONALITY4 = COALESCE(d4.NATIONALITY1, s.NATIONALITY4),
        PASSPORTNUMBER4 = COALESCE(d4.CUSTOMER_PASSPORTNO, d4.PASSPORTNUMBER, s.PASSPORTNUMBER4),
        DATEOFBIRTH4 = COALESCE(d4.DATEOFBIRTH1, s.DATEOFBIRTH4)
    FROM #SyncSource s
    LEFT JOIN #MatchedCustomerDetails d4 ON d4.CustomerSlot = 4

    UPDATE source
    SET RESI_TEL_NUM = COALESCE(source.RESI_TEL_NUM, master.RESI_TEL_NUM),
        OFFICE_TEL_NUM = COALESCE(source.OFFICE_TEL_NUM, master.OFFICE_TEL_NUM),
        RESI_ADDRESS1 = COALESCE(source.RESI_ADDRESS1, master.RESI_ADDRESS1),
        RESI_ADDRESS2 = COALESCE(source.RESI_ADDRESS2, master.RESI_ADDRESS2),
        RESI_ADDRESS3 = COALESCE(source.RESI_ADDRESS3, master.RESI_ADDRESS3),
        CORPORATECATEGORY = COALESCE(source.CORPORATECATEGORY, master.CORPORATECATEGORY),
        STAFF_YN = COALESCE(source.STAFF_YN, master.STAFF_YN),
        APPLICATION_ID = COALESCE(source.APPLICATION_ID, master.APPLICATION_ID),
        APP_START_DATE = COALESCE(source.APP_START_DATE, master.APP_START_DATE),
        CONT_STAT = COALESCE(source.CONT_STAT, master.CONT_STAT),
        CURR_ACC_BAL = COALESCE(source.CURR_ACC_BAL, master.CURR_ACC_BAL),
        CURR_RATE = COALESCE(source.CURR_RATE, master.CURR_RATE),
        INSTALLMENTAMOUNT = COALESCE(source.EMI_AMOUNT, source.INSTALLMENTAMOUNT,
            master.INSTALLMENTAMOUNT, master.EMI_AMOUNT),
        EMI_AMOUNT = COALESCE(source.EMI_AMOUNT, source.INSTALLMENTAMOUNT,
            master.INSTALLMENTAMOUNT, master.EMI_AMOUNT),
        EMI_DATE = COALESCE(source.EMI_DATE, master.EMI_DATE),
        EMI_FREQUENCY = COALESCE(source.EMI_FREQUENCY, master.EMI_FREQUENCY),
        IJARA_BOOKED = COALESCE(source.IJARA_BOOKED, master.IJARA_BOOKED),
        IJARA_BOOKED_DATE = COALESCE(source.IJARA_BOOKED_DATE, master.IJARA_BOOKED_DATE),
        INSTALL_NO = COALESCE(source.INSTALL_NO, master.INSTALL_NO),
        MATURITY_DATE = COALESCE(source.MATURITY_DATE, master.MATURITY_DATE),
        PDC_AMOUNT = COALESCE(source.PDC_AMOUNT, master.PDC_AMOUNT),
        PDC_NO = COALESCE(source.PDC_NO, master.PDC_NO),
        PRIN_OS = COALESCE(source.PRIN_OS, master.PRIN_OS),
        REM_TENOR_CURR = COALESCE(source.REM_TENOR_CURR, master.REM_TENOR_CURR),
        REPAY_TENOR = COALESCE(source.REPAY_TENOR, master.REPAY_TENOR),
        RETURN_VALUE = COALESCE(source.RETURN_VALUE, master.RETURN_VALUE),
        TBR_CURR = COALESCE(source.TBR_CURR, master.TBR_CURR),
        TOT_INST_NO = COALESCE(source.TOT_INST_NO, master.TOT_INST_NO),
        TOTAL_BOUNCE = COALESCE(source.TOTAL_BOUNCE, master.TOTAL_BOUNCE),
        DQ_TYPE = COALESCE(source.DQ_TYPE, master.DQ_TYPE),
        VALUE_DATE = COALESCE(source.VALUE_DATE, master.VALUE_DATE),
        INSTALLMENT_NO = COALESCE(source.INSTALLMENT_NO, master.INSTALLMENT_NO),
        contract_ref_no = COALESCE(source.contract_ref_no, master.contract_ref_no),
        CIF = COALESCE(source.CIF, master.CIF),
        REPAYMENT_TYPE = COALESCE(source.REPAYMENT_TYPE, master.REPAYMENT_TYPE),
        REPAYMENT_START_DATE = COALESCE(source.REPAYMENT_START_DATE, master.REPAYMENT_START_DATE),
        REPAYMENT_BANK_NAME = COALESCE(source.REPAYMENT_BANK_NAME, master.REPAYMENT_BANK_NAME),
        REPAYMENT_ACCOUNT_TYPE = COALESCE(source.REPAYMENT_ACCOUNT_TYPE, master.REPAYMENT_ACCOUNT_TYPE),
        REPAYMENT_IBAN = COALESCE(source.REPAYMENT_IBAN, master.REPAYMENT_IBAN)
    FROM #SyncSource source
    LEFT JOIN dbo.CORE_FLEX_ALL_APPS_MASTER master
        ON master.APPLICATIONID = source.APPLICATIONID

    IF @LeadNo IS NULL
    BEGIN
        DECLARE @PreserveMissingSourceSql NVARCHAR(MAX)

        SELECT @PreserveMissingSourceSql = STUFF
        (
            (
                SELECT N', source.' + QUOTENAME(sourceColumns.name) +
                    N' = COALESCE(source.' + QUOTENAME(sourceColumns.name) +
                    N', master.' + QUOTENAME(targetColumns.name) + N')'
                FROM tempdb.sys.columns sourceColumns
                INNER JOIN sys.columns targetColumns
                    ON targetColumns.object_id = OBJECT_ID(N'dbo.CORE_FLEX_ALL_APPS_MASTER')
                    AND targetColumns.name = sourceColumns.name
                    AND targetColumns.is_computed = 0
                    AND targetColumns.is_identity = 0
                WHERE sourceColumns.object_id = OBJECT_ID(N'tempdb..#SyncSource')
                    AND sourceColumns.name NOT IN
                        (N'APPLICATIONID', N'LEAD_NO', N'MAKER_ID', N'MAKER_DT_STAMP',
                         N'CHECKER_ID', N'CHECKER_DT_STAMP')
                ORDER BY sourceColumns.column_id
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'),
            1, 2, N''
        )

        IF NULLIF(@PreserveMissingSourceSql, N'') IS NOT NULL
        BEGIN
            SET @PreserveMissingSourceSql =
                N'UPDATE source SET ' + @PreserveMissingSourceSql +
                N' FROM #SyncSource source LEFT JOIN dbo.CORE_FLEX_ALL_APPS_MASTER master' +
                N' ON master.APPLICATIONID = source.APPLICATIONID' +
                N' WHERE source.APPLICATIONID = @ApplicationId;'

            EXEC sys.sp_executesql @PreserveMissingSourceSql,
                N'@ApplicationId NVARCHAR(200)',
                @ApplicationId = @ApplicationId
        END
    END

    IF @PreviewOnly = 1
    BEGIN
        SELECT * FROM #LeadSource

        SELECT m.*
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER m
        WHERE m.APPLICATIONID = @ApplicationId

        SELECT * FROM #MatchedCustomerDetails ORDER BY CustomerSlot

        SELECT * FROM #CoreApplicationDetails

        SELECT RepaymentType, CONVERT(NVARCHAR(20), StartDate, 103) AS StartDate,
            ApplicationID, BankName, AccountType, IBAN
        FROM #RepaymentDetails

        RETURN
    END

    CREATE TABLE #SelectedFields
    (
        FieldName SYSNAME NOT NULL PRIMARY KEY
    )

    IF @SelectedFields IS NULL
    BEGIN
        INSERT #SelectedFields (FieldName)
        SELECT sourceColumns.name
        FROM tempdb.sys.columns sourceColumns
        WHERE sourceColumns.object_id = OBJECT_ID(N'tempdb..#SyncSource')
            AND sourceColumns.name NOT IN
                (N'APPLICATIONID', N'LEAD_NO', N'MAKER_ID', N'MAKER_DT_STAMP', N'CHECKER_ID', N'CHECKER_DT_STAMP')
            AND EXISTS
            (
                SELECT 1
                FROM sys.columns targetColumns
                WHERE targetColumns.object_id = OBJECT_ID(N'dbo.CORE_FLEX_ALL_APPS_MASTER')
                    AND targetColumns.name = sourceColumns.name
            )
    END
    ELSE
    BEGIN
        INSERT #SelectedFields (FieldName)
        SELECT DISTINCT parsed.field.value(N'.', N'NVARCHAR(128)')
        FROM @SelectedFields.nodes(N'/fields/field') AS parsed(field)
    END

    IF NOT EXISTS (SELECT 1 FROM #SelectedFields)
    BEGIN
        RAISERROR('Select at least one valid field to synchronize.', 16, 1)
        RETURN
    END

    IF EXISTS
    (
        SELECT 1
        FROM #SelectedFields selected
        WHERE selected.FieldName IN
            (N'APPLICATIONID', N'LEAD_NO', N'MAKER_ID', N'MAKER_DT_STAMP', N'CHECKER_ID', N'CHECKER_DT_STAMP')
            OR NOT EXISTS
            (
                SELECT 1
                FROM tempdb.sys.columns sourceColumns
                WHERE sourceColumns.object_id = OBJECT_ID(N'tempdb..#SyncSource')
                    AND sourceColumns.name = selected.FieldName
            )
            OR NOT EXISTS
            (
                SELECT 1
                FROM sys.columns targetColumns
                WHERE targetColumns.object_id = OBJECT_ID(N'dbo.CORE_FLEX_ALL_APPS_MASTER')
                    AND targetColumns.name = selected.FieldName
            )
    )
    BEGIN
        RAISERROR('The selected field list contains unsupported fields. Search the application again.', 16, 1)
        RETURN
    END

    CREATE TABLE #EffectiveFields
    (
        FieldName SYSNAME NOT NULL PRIMARY KEY
    )
    INSERT #EffectiveFields (FieldName)
    SELECT FieldName
    FROM #SelectedFields

    IF EXISTS
    (
        SELECT 1
        FROM #SelectedFields
        WHERE FieldName IN (N'INSTALLMENTAMOUNT', N'EMI_AMOUNT')
    )
    BEGIN
        INSERT #EffectiveFields (FieldName)
        SELECT paired.FieldName
        FROM
        (
            SELECT N'INSTALLMENTAMOUNT' AS FieldName
            UNION ALL
            SELECT N'EMI_AMOUNT'
        ) paired
        WHERE NOT EXISTS
        (
            SELECT 1 FROM #EffectiveFields selected
            WHERE selected.FieldName = paired.FieldName
        )
    END

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @SelectedExistingMasterRows INT
        DECLARE @AuditRunId BIGINT
        DECLARE @SyncOperation NVARCHAR(20)
        DECLARE @UpdateSql NVARCHAR(MAX)
        DECLARE @InsertSql NVARCHAR(MAX)
        DECLARE @AuditSql NVARCHAR(MAX)
        DECLARE @SelectedColumnList NVARCHAR(MAX)
        DECLARE @SelectedValueList NVARCHAR(MAX)

        SELECT @SelectedExistingMasterRows = COUNT(*)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER WITH (UPDLOCK, HOLDLOCK)
        WHERE APPLICATIONID = @ApplicationId

        IF @SelectedExistingMasterRows > 1
            RAISERROR('Multiple master records exist for this application ID; sync was stopped.', 16, 1)

        SELECT TOP (0) master.* INTO #OldMaster
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER master
        CROSS JOIN (SELECT 1 AS Dummy) noIdentityTransfer
        IF @SelectedExistingMasterRows = 0
            SET @SyncOperation = N'Insert'
        ELSE
        BEGIN
            SET @SyncOperation = N'Update'
            INSERT #OldMaster
            SELECT *
            FROM dbo.CORE_FLEX_ALL_APPS_MASTER WITH (UPDLOCK, HOLDLOCK)
            WHERE APPLICATIONID = @ApplicationId
        END

        CREATE TABLE #FieldAudit
        (
            FieldName NVARCHAR(128) NOT NULL,
            OldValue NVARCHAR(MAX) NULL,
            NewValue NVARCHAR(MAX) NULL
        )

        SELECT @SelectedColumnList = STUFF
        (
            (
                SELECT N', ' + QUOTENAME(FieldName)
                FROM #EffectiveFields
                ORDER BY FieldName
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'),
            1, 2, N''
        )

        SELECT @SelectedValueList = STUFF
        (
            (
                SELECT N', source.' + QUOTENAME(FieldName)
                FROM #EffectiveFields
                ORDER BY FieldName
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'),
            1, 2, N''
        )

        SELECT @AuditSql = STUFF
        (
            (
                SELECT N'; INSERT #FieldAudit (FieldName, OldValue, NewValue) ' +
                    N'SELECT N''' + REPLACE(FieldName, N'''', N'''''') + N''', ' +
                    N'CONVERT(NVARCHAR(MAX), oldValue.' + QUOTENAME(FieldName) + N'), ' +
                    N'CONVERT(NVARCHAR(MAX), newValue.' + QUOTENAME(FieldName) + N') ' +
                    N'FROM #SyncSource newValue LEFT JOIN #OldMaster oldValue ' +
                    N'ON oldValue.APPLICATIONID = newValue.APPLICATIONID ' +
                    N'WHERE (oldValue.APPLICATIONID IS NULL AND newValue.' + QUOTENAME(FieldName) + N' IS NOT NULL) ' +
                    N'OR (oldValue.APPLICATIONID IS NOT NULL AND (' +
                        N'oldValue.' + QUOTENAME(FieldName) + N' <> newValue.' + QUOTENAME(FieldName) +
                        N' OR (oldValue.' + QUOTENAME(FieldName) + N' IS NULL AND newValue.' + QUOTENAME(FieldName) + N' IS NOT NULL)' +
                        N' OR (oldValue.' + QUOTENAME(FieldName) + N' IS NOT NULL AND newValue.' + QUOTENAME(FieldName) + N' IS NULL)))'
                FROM #EffectiveFields
                ORDER BY FieldName
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'),
            1, 2, N''
        )

        EXEC sys.sp_executesql @AuditSql
        SELECT @ChangedFields = COUNT(*) FROM #FieldAudit

        INSERT dbo.HFLMS_AfterSales_DataSync_Run
            (ApplicationId, Operation, SynchronizedBy, SelectedFieldCount, ChangedFieldCount)
        VALUES
            (@ApplicationId, @SyncOperation, COALESCE(NULLIF(@SynchronizedBy, N''), N'Unknown'),
                (SELECT COUNT(*) FROM #SelectedFields), @ChangedFields)
        SET @AuditRunId = CONVERT(BIGINT, SCOPE_IDENTITY())

        INSERT dbo.HFLMS_AfterSales_DataSync_FieldAudit (RunId, FieldName, OldValue, NewValue)
        SELECT @AuditRunId, FieldName, OldValue, NewValue
        FROM #FieldAudit

        SET @UpdateSql = N'UPDATE target SET ' +
            STUFF
            (
                (
                    SELECT N', target.' + QUOTENAME(FieldName) + N' = source.' + QUOTENAME(FieldName)
                    FROM #EffectiveFields
                    ORDER BY FieldName
                    FOR XML PATH(N''), TYPE
                ).value(N'.', N'NVARCHAR(MAX)'),
                1, 2, N''
            ) +
            N' FROM dbo.CORE_FLEX_ALL_APPS_MASTER target ' +
            N'INNER JOIN #SyncSource source ON source.APPLICATIONID = target.APPLICATIONID ' +
            N'WHERE target.APPLICATIONID = @ApplicationId; SET @Rows = @@ROWCOUNT;'

        EXEC sys.sp_executesql @UpdateSql,
            N'@ApplicationId NVARCHAR(200), @Rows INT OUTPUT',
            @ApplicationId = @ApplicationId,
            @Rows = @UpdatedRows OUTPUT

        IF @UpdatedRows = 0
        BEGIN
            SET @InsertSql = N'INSERT dbo.CORE_FLEX_ALL_APPS_MASTER ' +
                N'(APPLICATIONID, LEAD_NO, MAKER_ID, MAKER_DT_STAMP, CHECKER_ID, CHECKER_DT_STAMP, ' +
                @SelectedColumnList + N') ' +
                N'SELECT source.APPLICATIONID, source.LEAD_NO, source.MAKER_ID, source.MAKER_DT_STAMP, ' +
                N'source.CHECKER_ID, source.CHECKER_DT_STAMP, ' + @SelectedValueList +
                N' FROM #SyncSource source; SET @Rows = @@ROWCOUNT;'
            EXEC sys.sp_executesql @InsertSql, N'@Rows INT OUTPUT', @Rows = @InsertedRows OUTPUT
        END

        COMMIT TRANSACTION
        RETURN
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @SyncErrorMessage NVARCHAR(4000)
        DECLARE @SyncErrorSeverity INT
        DECLARE @SyncErrorState INT
        SELECT @SyncErrorMessage = ERROR_MESSAGE(),
            @SyncErrorSeverity = ERROR_SEVERITY(),
            @SyncErrorState = ERROR_STATE()
        RAISERROR(N'%s', @SyncErrorSeverity, @SyncErrorState, @SyncErrorMessage)
    END CATCH

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @LegacyExistingMasterRows INT
        SELECT @LegacyExistingMasterRows = COUNT(*)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER WITH (UPDLOCK, HOLDLOCK)
        WHERE APPLICATIONID = @ApplicationId

        IF @LegacyExistingMasterRows > 1
            RAISERROR('Multiple master records exist for this application ID; sync was stopped.', 16, 1)

        UPDATE m
        SET CUSTOMERID = s.CUSTOMERID,
            CUSTOMERID2 = s.CUSTOMERID2,
            CUSTOMERID3 = s.CUSTOMERID3,
            CUSTOMERID4 = s.CUSTOMERID4,
            CUSTOMERNAME1 = s.CUSTOMERNAME1,
            CUSTOMERNAME2 = s.CUSTOMERNAME2,
            CUSTOMERNAME3 = s.CUSTOMERNAME3,
            CUSTOMERNAME4 = s.CUSTOMERNAME4,
            NATIONALITY1 = s.NATIONALITY1,
            NATIONALITY2 = s.NATIONALITY2,
            NATIONALITY3 = s.NATIONALITY3,
            NATIONALITY4 = s.NATIONALITY4,
            PASSPORTNUMBER = s.PASSPORTNUMBER,
            PASSPORTNUMBER2 = s.PASSPORTNUMBER2,
            PASSPORTNUMBER3 = s.PASSPORTNUMBER3,
            PASSPORTNUMBER4 = s.PASSPORTNUMBER4,
            DATEOFBIRTH1 = s.DATEOFBIRTH1,
            DATEOFBIRTH2 = s.DATEOFBIRTH2,
            DATEOFBIRTH3 = s.DATEOFBIRTH3,
            DATEOFBIRTH4 = s.DATEOFBIRTH4,
            RESIDENCYTYPE = s.RESIDENCYTYPE,
            CURRENTSTATUS = s.CURRENTSTATUS,
            PREAPPROVALNO = s.PREAPPROVALNO,
            MOBILECODE = s.MOBILECODE,
            MOBILENUMBER = s.MOBILENUMBER,
            LASTUPDATED = s.LASTUPDATED,
            BRANCH_CODE = s.BRANCH_CODE,
            OL_ACCEPTANCE_DATE = s.OL_ACCEPTANCE_DATE,
            OL_GENERATION_DATE = s.OL_GENERATION_DATE,
            ORIGINALPROPERTYVALUE = s.ORIGINALPROPERTYVALUE,
            APPRAISEDPROPERTYVALUE = s.APPRAISEDPROPERTYVALUE,
            BUILTUPAREA = s.BUILTUPAREA,
            ISTISNATENOR = s.ISTISNATENOR,
            IJARATENOR = s.IJARATENOR,
            FINANCEVALUE = s.FINANCEVALUE,
            DOWNPAYMENT = s.DOWNPAYMENT,
            DSR = s.DSR,
            FTV = s.FTV,
            INSTALLMENTAMOUNT = s.INSTALLMENTAMOUNT,
            FINALRATE = s.FINALRATE,
            ISTISNAPRODUCT = s.ISTISNAPRODUCT,
            IJARAPRODUCT = s.IJARAPRODUCT,
            PURCHASETYPE = s.PURCHASETYPE,
            DEVELOPER = s.DEVELOPER,
            PROPERTYNAME = s.PROPERTYNAME,
            PROPERTYDETAILS = s.PROPERTYDETAILS,
            PROPERTYTYPE = s.PROPERTYTYPE,
            EMPLOYMENTTYPE = s.EMPLOYMENTTYPE,
            CURRENTEMPLOYER1 = s.CURRENTEMPLOYER1,
            DESIGNATION1 = s.DESIGNATION1,
            INCOME1 = s.INCOME1,
            INCOME2 = s.INCOME2,
            INCOME3 = s.INCOME3,
            INCOME4 = s.INCOME4,
            PERSONAL_EMAIL = s.PERSONAL_EMAIL,
            OFFICE_EMAIL = s.OFFICE_EMAIL,
            RESI_TEL_NUM = COALESCE(s.RESI_TEL_NUM, m.RESI_TEL_NUM),
            OFFICE_TEL_NUM = COALESCE(s.OFFICE_TEL_NUM, m.OFFICE_TEL_NUM),
            MAILING_POBOX = s.MAILING_POBOX,
            MAILING_CITY = s.MAILING_CITY,
            MAILING_COUNTRY = s.MAILING_COUNTRY,
            RESI_TEL_CODE = s.RESI_TEL_CODE,
            OFFICE_TEL_CODE = s.OFFICE_TEL_CODE,
            RESI_ADDRESS1 = COALESCE(s.RESI_ADDRESS1, m.RESI_ADDRESS1),
            RESI_ADDRESS2 = COALESCE(s.RESI_ADDRESS2, m.RESI_ADDRESS2),
            RESI_ADDRESS3 = COALESCE(s.RESI_ADDRESS3, m.RESI_ADDRESS3),
            HOMECOUNTRY_ADD1 = s.HOMECOUNTRY_ADD1,
            HOMECOUNTRY_ADD2 = s.HOMECOUNTRY_ADD2,
            HOMECOUNTRY_ADD3 = s.HOMECOUNTRY_ADD3,
            CORPORATECATEGORY = COALESCE(s.CORPORATECATEGORY, m.CORPORATECATEGORY),
            STAFF_YN = COALESCE(s.STAFF_YN, m.STAFF_YN),
            PROPERTYID = s.PROPERTYID,
            MAKER_ID = s.MAKER_ID,
            MAKER_DT_STAMP = s.MAKER_DT_STAMP,
            CHECKER_ID = s.CHECKER_ID,
            CHECKER_DT_STAMP = s.CHECKER_DT_STAMP,
            LEAD_NO = s.LEAD_NO
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER m
        INNER JOIN #SyncSource s ON s.APPLICATIONID = m.APPLICATIONID
        WHERE m.APPLICATIONID = @ApplicationId

        SET @UpdatedRows = @@ROWCOUNT

        IF @UpdatedRows = 0
        BEGIN
            INSERT INTO dbo.CORE_FLEX_ALL_APPS_MASTER
            (
                APPLICATIONID, LEAD_NO, CUSTOMERID, CUSTOMERID2, CUSTOMERID3, CUSTOMERID4,
                CUSTOMERNAME1, CUSTOMERNAME2, CUSTOMERNAME3, CUSTOMERNAME4,
                NATIONALITY1, NATIONALITY2, NATIONALITY3, NATIONALITY4,
                PASSPORTNUMBER, PASSPORTNUMBER2, PASSPORTNUMBER3, PASSPORTNUMBER4,
                DATEOFBIRTH1, DATEOFBIRTH2, DATEOFBIRTH3, DATEOFBIRTH4,
                RESIDENCYTYPE, CURRENTSTATUS, PREAPPROVALNO, MOBILECODE, MOBILENUMBER, LASTUPDATED,
                BRANCH_CODE, OL_ACCEPTANCE_DATE, OL_GENERATION_DATE,
                ORIGINALPROPERTYVALUE, APPRAISEDPROPERTYVALUE, BUILTUPAREA, ISTISNATENOR, IJARATENOR,
                FINANCEVALUE, DOWNPAYMENT, DSR, FTV, INSTALLMENTAMOUNT, FINALRATE,
                ISTISNAPRODUCT, IJARAPRODUCT, PURCHASETYPE, DEVELOPER, PROPERTYNAME, PROPERTYDETAILS,
                PROPERTYTYPE, EMPLOYMENTTYPE, CURRENTEMPLOYER1, DESIGNATION1, INCOME1, INCOME2, INCOME3, INCOME4,
                PERSONAL_EMAIL, OFFICE_EMAIL, MAILING_POBOX, MAILING_CITY, MAILING_COUNTRY,
                RESI_TEL_CODE, RESI_TEL_NUM, OFFICE_TEL_CODE, OFFICE_TEL_NUM,
                RESI_ADDRESS1, RESI_ADDRESS2, RESI_ADDRESS3, CORPORATECATEGORY, STAFF_YN,
                HOMECOUNTRY_ADD1, HOMECOUNTRY_ADD2, HOMECOUNTRY_ADD3, PROPERTYID,
                MAKER_ID, MAKER_DT_STAMP, CHECKER_ID, CHECKER_DT_STAMP
            )
            SELECT
                APPLICATIONID, LEAD_NO, CUSTOMERID, CUSTOMERID2, CUSTOMERID3, CUSTOMERID4,
                CUSTOMERNAME1, CUSTOMERNAME2, CUSTOMERNAME3, CUSTOMERNAME4,
                NATIONALITY1, NATIONALITY2, NATIONALITY3, NATIONALITY4,
                PASSPORTNUMBER, PASSPORTNUMBER2, PASSPORTNUMBER3, PASSPORTNUMBER4,
                DATEOFBIRTH1, DATEOFBIRTH2, DATEOFBIRTH3, DATEOFBIRTH4,
                RESIDENCYTYPE, CURRENTSTATUS, PREAPPROVALNO, MOBILECODE, MOBILENUMBER, LASTUPDATED,
                BRANCH_CODE, OL_ACCEPTANCE_DATE, OL_GENERATION_DATE,
                ORIGINALPROPERTYVALUE, APPRAISEDPROPERTYVALUE, BUILTUPAREA, ISTISNATENOR, IJARATENOR,
                FINANCEVALUE, DOWNPAYMENT, DSR, FTV, INSTALLMENTAMOUNT, FINALRATE,
                ISTISNAPRODUCT, IJARAPRODUCT, PURCHASETYPE, DEVELOPER, PROPERTYNAME, PROPERTYDETAILS,
                PROPERTYTYPE, EMPLOYMENTTYPE, CURRENTEMPLOYER1, DESIGNATION1, INCOME1, INCOME2, INCOME3, INCOME4,
                PERSONAL_EMAIL, OFFICE_EMAIL, MAILING_POBOX, MAILING_CITY, MAILING_COUNTRY,
                RESI_TEL_CODE, RESI_TEL_NUM, OFFICE_TEL_CODE, OFFICE_TEL_NUM,
                RESI_ADDRESS1, RESI_ADDRESS2, RESI_ADDRESS3, CORPORATECATEGORY, STAFF_YN,
                HOMECOUNTRY_ADD1, HOMECOUNTRY_ADD2, HOMECOUNTRY_ADD3, PROPERTYID,
                MAKER_ID, MAKER_DT_STAMP, CHECKER_ID, CHECKER_DT_STAMP
            FROM #SyncSource
            SET @InsertedRows = @@ROWCOUNT
        END

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @LegacyErrorMessage NVARCHAR(4000)
        DECLARE @LegacyErrorSeverity INT
        DECLARE @LegacyErrorState INT
        SELECT @LegacyErrorMessage = ERROR_MESSAGE(),
            @LegacyErrorSeverity = ERROR_SEVERITY(),
            @LegacyErrorState = ERROR_STATE()
        RAISERROR(N'%s', @LegacyErrorSeverity, @LegacyErrorState, @LegacyErrorMessage)
    END CATCH
END
GO

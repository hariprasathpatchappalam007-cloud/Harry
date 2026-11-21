USE [LMS_DEV]
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.LEAD_ARR_FEE_REGRESSION_BACKUP', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LEAD_ARR_FEE_REGRESSION_BACKUP
    (
        BatchId UNIQUEIDENTIFIER NOT NULL,
        Lead_No NVARCHAR(100) NOT NULL,
        ScenarioName NVARCHAR(200) NOT NULL,
        FinanceAmount DECIMAL(20,4) NULL,
        EquityAmount DECIMAL(20,4) NULL,
        MBREAmount DECIMAL(20,4) NULL,
        PromotionName NVARCHAR(200) NULL,
        SourceSubmission NVARCHAR(100) NULL,
        RelationshipWithBank NVARCHAR(100) NULL,
        ResidencyType NVARCHAR(200) NULL,
        AppliedOn DATETIME2(0) NOT NULL CONSTRAINT DF_LEAD_ARR_FEE_REGRESSION_BACKUP_AppliedOn DEFAULT (SYSDATETIME()),
        RolledBackOn DATETIME2(0) NULL,
        CONSTRAINT PK_LEAD_ARR_FEE_REGRESSION_BACKUP PRIMARY KEY (BatchId, Lead_No)
    );
END;

DECLARE @BatchId UNIQUEIDENTIFIER = NEWID();
DECLARE @Cases TABLE
(
    Lead_No NVARCHAR(100) NOT NULL PRIMARY KEY,
    ScenarioName NVARCHAR(200) NOT NULL,
    OverrideFinance BIT NOT NULL,
    FinanceAmount DECIMAL(20,4) NULL,
    OverrideEquity BIT NOT NULL,
    EquityAmount DECIMAL(20,4) NULL,
    OverrideMBRE BIT NOT NULL,
    MBREAmount DECIMAL(20,4) NULL,
    OverridePromotion BIT NOT NULL,
    PromotionName NVARCHAR(200) NULL,
    OverrideRelationship BIT NOT NULL,
    RelationshipWithBank NVARCHAR(100) NULL,
    OverrideResidency BIT NOT NULL,
    ResidencyType NVARCHAR(200) NULL
);

INSERT INTO @Cases
    (Lead_No,ScenarioName,OverrideFinance,FinanceAmount,OverrideEquity,EquityAmount,
     OverrideMBRE,MBREAmount,OverridePromotion,PromotionName,OverrideRelationship,
     RelationshipWithBank,OverrideResidency,ResidencyType)
VALUES
    (N'LD-00126531',N'NSTL non-Equity Release - minimum fee',0,NULL,0,NULL,0,NULL,1,NULL,1,N'NSTL',0,NULL),
    (N'LD-00126500',N'NSTL non-Equity Release - standard fee',0,NULL,0,NULL,0,NULL,1,NULL,1,N'NSTL',0,NULL),
    (N'LD-00126592',N'NSTL resident - maximum cap',1,20000000,0,NULL,0,NULL,1,NULL,1,N'NSTL',0,NULL),
    (N'LD-00126503',N'NSTL non-resident - no maximum cap',1,20000000,0,NULL,0,NULL,1,NULL,1,N'NSTL',1,N'Non-Resident'),
    (N'LD-00126508',N'STL non-Equity Release - nil fee',0,NULL,0,NULL,0,NULL,1,NULL,1,N'STL',0,NULL),
    (N'LD-00126528',N'Aggregator Equity Release - STL',0,NULL,1,1000000,0,NULL,1,N'Aggregator-STL-Equity Release',1,N'STL',0,NULL),
    (N'LD-00126537',N'Non-Aggregator NSTL Equity Release',1,100000,1,100000,0,NULL,1,NULL,1,N'NSTL',0,NULL),
    (N'LD-00126539',N'Aggregator Equity Release with GHP - NSTL',1,2000000,1,1000000,1,100000,1,N'Aggregator-NSTL-Equity Release',1,N'NSTL',0,NULL),
    (N'LD-00091416',N'GHP pre-approval - nil GHP fee',0,NULL,0,NULL,0,NULL,1,NULL,1,N'NSTL',0,NULL),
    (N'LD-00126511',N'Abu Dhabi Promotion - Final Payment',0,NULL,0,NULL,0,NULL,1,N'Abu Dhabi Promotion',0,NULL,0,NULL);

DECLARE @SourceOverrides TABLE
(
    Lead_No NVARCHAR(100) NOT NULL PRIMARY KEY,
    SourceSubmission NVARCHAR(100) NOT NULL
);
INSERT INTO @SourceOverrides(Lead_No,SourceSubmission) VALUES (N'LD-00126537',N'SELF');

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1
        FROM @Cases testCase
        LEFT JOIN dbo.LEAD_DETAILS_FINANCE finance ON finance.LEAD_NO=testCase.Lead_No
        LEFT JOIN dbo.LEAD_DETAILS lead ON lead.LEAD_NO=testCase.Lead_No
        WHERE finance.LEAD_NO IS NULL OR lead.LEAD_NO IS NULL
    )
        THROW 51800, 'One or more regression lead numbers are missing from LEAD_DETAILS / LEAD_DETAILS_FINANCE. No test values were applied.', 1;

    IF EXISTS
    (
        SELECT 1 FROM @Cases testCase
        WHERE testCase.OverrideRelationship=1
          AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_DETAILS_OTHERS other WHERE other.LEAD_NO=testCase.Lead_No)
    )
        THROW 51801, 'A lead requiring relationship override has no LEAD_DETAILS_OTHERS row. No test values were applied.', 1;

    INSERT dbo.LEAD_ARR_FEE_REGRESSION_BACKUP
        (BatchId,Lead_No,ScenarioName,FinanceAmount,EquityAmount,MBREAmount,PromotionName,SourceSubmission,RelationshipWithBank,ResidencyType)
    SELECT
        @BatchId,testCase.Lead_No,testCase.ScenarioName,finance.finance_amount,
        finance.lead_fin_Equity_amt,finance.MBRE_AMOUNT,finance.lead_fin_promotiontype,lead.Lead_Source_OF_Submission,
        other.Relationship_with_bank,lead.CUSTOMER_RES_TYPE
    FROM @Cases testCase
    INNER JOIN dbo.LEAD_DETAILS_FINANCE finance ON finance.LEAD_NO=testCase.Lead_No
    INNER JOIN dbo.LEAD_DETAILS lead ON lead.LEAD_NO=testCase.Lead_No
    LEFT JOIN dbo.LEAD_DETAILS_OTHERS other ON other.LEAD_NO=testCase.Lead_No;

    UPDATE finance
    SET finance.finance_amount = CASE WHEN testCase.OverrideFinance=1 THEN testCase.FinanceAmount ELSE finance.finance_amount END,
        finance.lead_fin_Equity_amt = CASE WHEN testCase.OverrideEquity=1 THEN testCase.EquityAmount ELSE finance.lead_fin_Equity_amt END,
        finance.MBRE_AMOUNT = CASE WHEN testCase.OverrideMBRE=1 THEN testCase.MBREAmount ELSE finance.MBRE_AMOUNT END,
        finance.lead_fin_promotiontype = CASE WHEN testCase.OverridePromotion=1 THEN NULLIF(testCase.PromotionName,N'') ELSE finance.lead_fin_promotiontype END
    FROM dbo.LEAD_DETAILS_FINANCE finance
    INNER JOIN @Cases testCase ON testCase.Lead_No=finance.LEAD_NO;

    UPDATE other
    SET other.Relationship_with_bank = testCase.RelationshipWithBank
    FROM dbo.LEAD_DETAILS_OTHERS other
    INNER JOIN @Cases testCase ON testCase.Lead_No=other.LEAD_NO
    WHERE testCase.OverrideRelationship=1;

    UPDATE lead
    SET lead.CUSTOMER_RES_TYPE = testCase.ResidencyType
    FROM dbo.LEAD_DETAILS lead
    INNER JOIN @Cases testCase ON testCase.Lead_No=lead.LEAD_NO
    WHERE testCase.OverrideResidency=1;

    UPDATE lead
    SET lead.Lead_Source_OF_Submission=sourceOverride.SourceSubmission
    FROM dbo.LEAD_DETAILS lead
    INNER JOIN @SourceOverrides sourceOverride ON sourceOverride.Lead_No=lead.LEAD_NO;

    COMMIT TRANSACTION;

    SELECT @BatchId AS BatchId, Lead_No, ScenarioName, AppliedOn
    FROM dbo.LEAD_ARR_FEE_REGRESSION_BACKUP
    WHERE BatchId=@BatchId
    ORDER BY Lead_No;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

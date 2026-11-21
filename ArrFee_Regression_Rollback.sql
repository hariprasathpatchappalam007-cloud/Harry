USE [LMS_DEV]
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @BatchId UNIQUEIDENTIFIER = NULL;

IF @BatchId IS NULL
    THROW 51810, 'Set @BatchId to the BatchId returned by ArrFee_Regression_Apply.sql.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.LEAD_ARR_FEE_REGRESSION_BACKUP
        WHERE BatchId=@BatchId AND RolledBackOn IS NULL
    )
        THROW 51811, 'No active regression batch was found for this BatchId.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.LEAD_ARR_FEE_REGRESSION_BACKUP bkp
        LEFT JOIN dbo.LEAD_DETAILS_FINANCE finance ON finance.LEAD_NO=bkp.Lead_No
        LEFT JOIN dbo.LEAD_DETAILS lead ON lead.LEAD_NO=bkp.Lead_No
        WHERE bkp.BatchId=@BatchId
          AND (finance.LEAD_NO IS NULL OR lead.LEAD_NO IS NULL)
    )
        THROW 51812, 'A regression lead is missing from the source tables. Rollback stopped.', 1;

    UPDATE finance
    SET finance.finance_amount=bkp.FinanceAmount,
        finance.lead_fin_Equity_amt=bkp.EquityAmount,
        finance.MBRE_AMOUNT=bkp.MBREAmount,
        finance.lead_fin_promotiontype=bkp.PromotionName
    FROM dbo.LEAD_DETAILS_FINANCE finance
    INNER JOIN dbo.LEAD_ARR_FEE_REGRESSION_BACKUP bkp ON bkp.Lead_No=finance.LEAD_NO
    WHERE bkp.BatchId=@BatchId AND bkp.RolledBackOn IS NULL;

    UPDATE other
    SET other.Relationship_with_bank=bkp.RelationshipWithBank
    FROM dbo.LEAD_DETAILS_OTHERS other
    INNER JOIN dbo.LEAD_ARR_FEE_REGRESSION_BACKUP bkp ON bkp.Lead_No=other.LEAD_NO
    WHERE bkp.BatchId=@BatchId AND bkp.RolledBackOn IS NULL;

    UPDATE lead
    SET lead.CUSTOMER_RES_TYPE=bkp.ResidencyType,
        lead.Lead_Source_OF_Submission=bkp.SourceSubmission
    FROM dbo.LEAD_DETAILS lead
    INNER JOIN dbo.LEAD_ARR_FEE_REGRESSION_BACKUP bkp ON bkp.Lead_No=lead.LEAD_NO
    WHERE bkp.BatchId=@BatchId AND bkp.RolledBackOn IS NULL;

    UPDATE dbo.LEAD_ARR_FEE_REGRESSION_BACKUP
    SET RolledBackOn=SYSDATETIME()
    WHERE BatchId=@BatchId AND RolledBackOn IS NULL;

    COMMIT TRANSACTION;

    SELECT BatchId,Lead_No,ScenarioName,RolledBackOn
    FROM dbo.LEAD_ARR_FEE_REGRESSION_BACKUP
    WHERE BatchId=@BatchId
    ORDER BY Lead_No;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

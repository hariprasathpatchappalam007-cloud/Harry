USE [LMS_DEV]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON
GO

IF OBJECT_ID(N'dbo.Lead_Promotion_master', N'U') IS NULL
    THROW 51700, 'Lead_Promotion_master must exist before deploying this workflow.', 1;
IF OBJECT_ID(N'dbo.LEAD_ARR_FEE_MASTER', N'U') IS NULL
    THROW 51701, 'LEAD_ARR_FEE_MASTER must exist before deploying this workflow.', 1;
IF OBJECT_ID(N'dbo.FRM_gnarr', N'U') IS NULL
    THROW 51724, 'FRM_gnarr must exist before deploying promotion activation configuration.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Lead_Promotion_master WHERE PromotionName=N'Abu Dhabi Promotion')
BEGIN
    BEGIN TRANSACTION;
    DECLARE @AbuDhabiPromotionSrno INT;
    SELECT @AbuDhabiPromotionSrno=ISNULL(MAX(SRNO),0)+1
    FROM dbo.Lead_Promotion_master WITH (UPDLOCK,HOLDLOCK);
    INSERT dbo.Lead_Promotion_master
        (SRNO,PromotionName,DiscountPerc,StartDate,EndDate,Createdby_user,Createdon_date,Status)
    VALUES
        (@AbuDhabiPromotionSrno,N'Abu Dhabi Promotion',0,NULL,NULL,N'SYSTEM',GETDATE(),N'A');
    COMMIT TRANSACTION;
END;



IF OBJECT_ID(N'dbo.LEAD_ARR_FEE_PROMOTION_CONFIG', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
    (
        PromotionName NVARCHAR(200) NOT NULL CONSTRAINT PK_LEAD_ARR_FEE_PROMOTION_CONFIG PRIMARY KEY,
        IsEnabled BIT NOT NULL CONSTRAINT DF_LEAD_ARR_FEE_PROMOTION_CONFIG_Enabled DEFAULT (1),
        UseMasterDiscount BIT NOT NULL CONSTRAINT DF_LEAD_ARR_FEE_PROMOTION_CONFIG_MasterDiscount DEFAULT (1),
        SkipMinFee BIT NOT NULL CONSTRAINT DF_LEAD_ARR_FEE_PROMOTION_CONFIG_SkipMin DEFAULT (0),
        SkipMaxFee BIT NOT NULL CONSTRAINT DF_LEAD_ARR_FEE_PROMOTION_CONFIG_SkipMax DEFAULT (0),
        LookupProductType NVARCHAR(300) NULL,
        LookupProductSubType NVARCHAR(300) NULL,
        UpdatedBy NVARCHAR(100) NULL,
        UpdatedOn DATETIME2(0) NOT NULL CONSTRAINT DF_LEAD_ARR_FEE_PROMOTION_CONFIG_UpdatedOn DEFAULT (SYSDATETIME())
    );
END;

IF OBJECT_ID(N'dbo.LEAD_ARR_FEE_PROMOTION_RULE', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (
        RuleId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_LEAD_ARR_FEE_PROMOTION_RULE PRIMARY KEY,
        PromotionName NVARCHAR(200) NOT NULL,
        RuleCode VARCHAR(60) NOT NULL,
        RuleDescription NVARCHAR(500) NULL,
        RuleSequence INT NOT NULL,
        RuleStage VARCHAR(24) NOT NULL,
        RuleType VARCHAR(32) NOT NULL,
        TargetField VARCHAR(32) NULL,
        AmountBasis VARCHAR(16) NULL,
        RuleValue DECIMAL(20,4) NULL,
        MinimumFee DECIMAL(20,2) NULL,
        MaximumFee DECIMAL(20,2) NULL,
        SplitMode VARCHAR(20) NULL,
        FloorSplitMode VARCHAR(20) NULL,
        VATApplicable BIT NULL,
        IsEnabled BIT NOT NULL CONSTRAINT DF_LEAD_ARR_FEE_PROMOTION_RULE_Enabled DEFAULT (1),
        CONSTRAINT UQ_LEAD_ARR_FEE_PROMOTION_RULE_Code UNIQUE (PromotionName, RuleCode),
        CONSTRAINT FK_LEAD_ARR_FEE_PROMOTION_RULE_Config FOREIGN KEY (PromotionName)
            REFERENCES dbo.LEAD_ARR_FEE_PROMOTION_CONFIG(PromotionName),
        CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_Stage CHECK (RuleStage IN ('PRE_CALC','POST_BASE','PRE_MASTER_DISCOUNT','POST_MASTER_DISCOUNT')),
        CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_Type CHECK (RuleType IN
            ('RATE_SUBTRACT_POSITIVE','RATE_SET','FEE_PERCENT_DISCOUNT','FEE_FROM_AMOUNT','EQUITY_RATE_TO_ACC','SKIP_MASTER_DISCOUNT','FEE_LIMITS')),
        CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_Target CHECK (TargetField IS NULL OR TargetField IN
            ('FEE_FV','FEE_OPV','FEE_APV','FEE_Buyout','FEE_Topup','FEE_Equity','FEE_Cashout','FEE_MBRE')),
        CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_Basis CHECK (AmountBasis IS NULL OR AmountBasis IN ('FINANCE','TOPUP','EQUITY')),
        CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_Split CHECK (SplitMode IS NULL OR SplitMode IN ('KEEP','RECALCULATE','APP_ZERO','ACC_RESIDUAL')),
        CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_FloorSplit CHECK (FloorSplitMode IS NULL OR FloorSplitMode IN ('KEEP','RECALCULATE','APP_ZERO','ACC_RESIDUAL'))
    );
END;

IF COL_LENGTH(N'dbo.LEAD_ARR_FEE_PROMOTION_RULE',N'RuleDescription') IS NULL
    ALTER TABLE dbo.LEAD_ARR_FEE_PROMOTION_RULE ADD RuleDescription NVARCHAR(500) NULL;
IF COL_LENGTH(N'dbo.LEAD_ARR_FEE_PROMOTION_RULE',N'MaximumFee') IS NULL
    ALTER TABLE dbo.LEAD_ARR_FEE_PROMOTION_RULE ADD MaximumFee DECIMAL(20,2) NULL;
IF EXISTS (SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.LEAD_ARR_FEE_PROMOTION_RULE')
      AND name=N'CK_LEAD_ARR_FEE_PROMOTION_RULE_Type')
    ALTER TABLE dbo.LEAD_ARR_FEE_PROMOTION_RULE DROP CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_Type;
ALTER TABLE dbo.LEAD_ARR_FEE_PROMOTION_RULE
    ADD CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_Type CHECK (RuleType IN
        ('RATE_SUBTRACT_POSITIVE','RATE_SET','FEE_PERCENT_DISCOUNT','FEE_FROM_AMOUNT',
         'EQUITY_RATE_TO_ACC','SKIP_MASTER_DISCOUNT','FEE_LIMITS'));
GO

IF OBJECT_ID(N'dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER
    (
        RuleId INT NOT NULL,
        FilterSequence SMALLINT NOT NULL,
        FieldName VARCHAR(32) NOT NULL,
        ComparisonOperator VARCHAR(12) NOT NULL,
        FilterValue NVARCHAR(300) NOT NULL,
        CONSTRAINT PK_LEAD_ARR_FEE_PROMOTION_RULE_FILTER PRIMARY KEY (RuleId, FilterSequence),
        CONSTRAINT FK_LEAD_ARR_FEE_PROMOTION_RULE_FILTER_Rule FOREIGN KEY (RuleId)
            REFERENCES dbo.LEAD_ARR_FEE_PROMOTION_RULE(RuleId) ON DELETE CASCADE,
        CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_FILTER_Field CHECK (FieldName IN
            ('PRODUCT_TYPE','PRODUCT_SUBTYPE','RESIDENCY_TYPE','STAFF','SOURCE_SUBMISSION','PROJECT_ID','CONVERSION_PRODUCT')),
        CONSTRAINT CK_LEAD_ARR_FEE_PROMOTION_RULE_FILTER_Operator CHECK (ComparisonOperator IN ('EQ','NE','PREFIX','NOT_PREFIX'))
    );
END;

INSERT dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
    (PromotionName,IsEnabled,UseMasterDiscount,SkipMinFee,SkipMaxFee,LookupProductType,LookupProductSubType)
SELECT Seed.PromotionName,1,Seed.UseMasterDiscount,Seed.SkipMinFee,Seed.SkipMaxFee,Seed.LookupProductType,Seed.LookupProductSubType
FROM (VALUES
    (N'ARADA Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'DEYAAR Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Bloom Holding Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Dubai South Properties Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Promotional Rate with Fees - STL',CONVERT(BIT,1),CONVERT(BIT,1),CONVERT(BIT,1),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Promotional Rate with Fees - NSTL',CONVERT(BIT,1),CONVERT(BIT,1),CONVERT(BIT,1),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Processing Fee Promotion 0.50%',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'APC Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'TopUp Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'DIB Sustainable STL Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'DIB Sustainable NSTL Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Aggregator-STL-Equity Release',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Aggregator-NSTL-Equity Release',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Aggregator-Equity Release-Standard',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Abu Dhabi Promotion',CONVERT(BIT,0),CONVERT(BIT,1),CONVERT(BIT,1),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'SLS WoW Dubai Promotion',CONVERT(BIT,1),CONVERT(BIT,0),CONVERT(BIT,0),N'Forward Ijara',N'OPF'),
    (N'Aggregator-GHP-Equity Release',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'STL-100% Processing Fee Discount',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'NSTL-0.75% Processing Fee',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Direct Customer-NSTL-Equity Release',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'GHP-STL-100% Processing Fee Discount',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'GHP-NSTL-100% Processing Fee Discount',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Abu Dhabi Developers-Final Payment-100% Processing Fee Discount',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL)),
    (N'Nest & Wajaha-50% Processing Fee Discount',CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(BIT,0),CONVERT(NVARCHAR(300),NULL),CONVERT(NVARCHAR(300),NULL))
) AS Seed(PromotionName,UseMasterDiscount,SkipMinFee,SkipMaxFee,LookupProductType,LookupProductSubType)
WHERE NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG Existing WHERE Existing.PromotionName=Seed.PromotionName);

UPDATE dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
SET UseMasterDiscount=0, UpdatedBy=N'SYSTEM', UpdatedOn=SYSDATETIME()
WHERE PromotionName IN (N'Aggregator-STL-Equity Release',N'Aggregator-NSTL-Equity Release',
    N'Aggregator-GHP-Equity Release')
  AND UpdatedBy IS NULL;
DECLARE @LegacyRatePromotions TABLE (PromotionName NVARCHAR(200) NOT NULL PRIMARY KEY);
INSERT @LegacyRatePromotions(PromotionName) VALUES
    (N'ARADA Promotion'),(N'DEYAAR Promotion'),(N'Bloom Holding Promotion'),(N'Dubai South Properties Promotion');
DECLARE @FeeRateFields TABLE (FieldName VARCHAR(32) NOT NULL PRIMARY KEY);
INSERT @FeeRateFields(FieldName) VALUES
    ('FEE_FV'),('FEE_OPV'),('FEE_APV'),('FEE_Buyout'),('FEE_Topup'),('FEE_Equity'),('FEE_Cashout'),('FEE_MBRE');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleSequence,RuleStage,RuleType,TargetField,RuleValue)
SELECT Promotion.PromotionName,'REDUCE_' + FeeField.FieldName,10,'PRE_CALC','RATE_SUBTRACT_POSITIVE',FeeField.FieldName,0.25
FROM @LegacyRatePromotions Promotion CROSS JOIN @FeeRateFields FeeField
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
     WHERE Existing.PromotionName=Promotion.PromotionName AND Existing.RuleCode='REDUCE_' + FeeField.FieldName);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE(PromotionName,RuleCode,RuleSequence,RuleStage,RuleType,TargetField,RuleValue)
SELECT N'Processing Fee Promotion 0.50%',Seed.RuleCode,Seed.RuleSequence,'PRE_CALC','RATE_SET',Seed.TargetField,Seed.RuleValue
FROM (VALUES
    ('RESIDENT_FV',10,'FEE_FV',CONVERT(DECIMAL(20,4),0.50),CONVERT(VARCHAR(32),NULL),CONVERT(NVARCHAR(300),NULL)),
    ('RESIDENT_CASHOUT',10,'FEE_Cashout',CONVERT(DECIMAL(20,4),0.00),CONVERT(VARCHAR(32),NULL),CONVERT(NVARCHAR(300),NULL)),
    ('EQUITY_BUYOUT_FV',20,'FEE_FV',CONVERT(DECIMAL(20,4),0.00),'PRODUCT_SUBTYPE',N'Buyout'),
    ('EQUITY_BUYOUT_CASHOUT',20,'FEE_Cashout',CONVERT(DECIMAL(20,4),0.50),'PRODUCT_SUBTYPE',N'Buyout'),
    ('EQUITY_TOPUP_FV',20,'FEE_FV',CONVERT(DECIMAL(20,4),0.00),'PRODUCT_SUBTYPE',N'Topup'),
    ('EQUITY_TOPUP_CASHOUT',20,'FEE_Cashout',CONVERT(DECIMAL(20,4),0.50),'PRODUCT_SUBTYPE',N'Topup')
) AS Seed(RuleCode,RuleSequence,TargetField,RuleValue,ExtraField,ExtraValue)
WHERE NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
    WHERE Existing.PromotionName=N'Processing Fee Promotion 0.50%' AND Existing.RuleCode=Seed.RuleCode);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'RESIDENCY_TYPE','EQ',N'Resident'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.PromotionName=N'Processing Fee Promotion 0.50%'
    AND PromotionRule.RuleCode IN ('RESIDENT_FV','RESIDENT_CASHOUT','EQUITY_BUYOUT_FV','EQUITY_BUYOUT_CASHOUT','EQUITY_TOPUP_FV','EQUITY_TOPUP_CASHOUT')
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter
            WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=1);
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,2,'PRODUCT_TYPE','EQ',N'Equity Release'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.PromotionName=N'Processing Fee Promotion 0.50%'
    AND PromotionRule.RuleCode LIKE 'EQUITY_%'
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter
            WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=2);
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,3,'PRODUCT_SUBTYPE','EQ',CASE WHEN PromotionRule.RuleCode LIKE 'EQUITY_BUYOUT_%' THEN N'Buyout' ELSE N'Topup' END
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.PromotionName=N'Processing Fee Promotion 0.50%'
    AND PromotionRule.RuleCode LIKE 'EQUITY_%'
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter
            WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=3);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE(PromotionName,RuleCode,RuleSequence,RuleStage,RuleType,RuleValue,MinimumFee,SplitMode,FloorSplitMode)
SELECT N'APC Promotion','EQUITY_RELEASE_DISCOUNT',10,'POST_BASE','FEE_PERCENT_DISCOUNT',25.00,5000,'RECALCULATE','APP_ZERO'
WHERE NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE WHERE PromotionName=N'APC Promotion' AND RuleCode='EQUITY_RELEASE_DISCOUNT');
DECLARE @ApcRuleId INT = (SELECT RuleId FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE WHERE PromotionName=N'APC Promotion' AND RuleCode='EQUITY_RELEASE_DISCOUNT');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT @ApcRuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue
FROM (VALUES (1,'PRODUCT_TYPE','EQ',N'Equity Release'),(2,'PRODUCT_SUBTYPE','NE',N'Swap'),(3,'PRODUCT_SUBTYPE','NE',N'Buyout')) AS Seed(FilterSequence,FieldName,ComparisonOperator,FilterValue)
WHERE NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Existing WHERE Existing.RuleId=@ApcRuleId AND Existing.FilterSequence=Seed.FilterSequence);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE(PromotionName,RuleCode,RuleSequence,RuleStage,RuleType,AmountBasis,RuleValue,MinimumFee,SplitMode,FloorSplitMode)
SELECT N'TopUp Promotion','EQUITY_RELEASE_TOPUP_RATE',10,'POST_BASE','FEE_FROM_AMOUNT','TOPUP',0.50,5000,'KEEP','APP_ZERO'
WHERE NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE WHERE PromotionName=N'TopUp Promotion' AND RuleCode='EQUITY_RELEASE_TOPUP_RATE');
DECLARE @TopupRuleId INT = (SELECT RuleId FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE WHERE PromotionName=N'TopUp Promotion' AND RuleCode='EQUITY_RELEASE_TOPUP_RATE');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT @TopupRuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue
FROM (VALUES (1,'PRODUCT_TYPE','EQ',N'Equity Release'),(2,'PRODUCT_SUBTYPE','EQ',N'Topup')) AS Seed(FilterSequence,FieldName,ComparisonOperator,FilterValue)
WHERE NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Existing WHERE Existing.RuleId=@TopupRuleId AND Existing.FilterSequence=Seed.FilterSequence);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE(PromotionName,RuleCode,RuleSequence,RuleStage,RuleType,RuleValue)
SELECT Promotion.PromotionName,'SKIP_MASTER_DISCOUNT_' + Prefix.Prefix,10,'PRE_MASTER_DISCOUNT','SKIP_MASTER_DISCOUNT',NULL
FROM (VALUES (N'DIB Sustainable STL Promotion'),(N'DIB Sustainable NSTL Promotion')) AS Promotion(PromotionName)
CROSS JOIN (VALUES ('MB'),('NB'),('TW')) AS Prefix(Prefix)
WHERE NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
    WHERE Existing.PromotionName=Promotion.PromotionName AND Existing.RuleCode='SKIP_MASTER_DISCOUNT_' + Prefix.Prefix);
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'CONVERSION_PRODUCT','PREFIX',SUBSTRING(PromotionRule.RuleCode,LEN('SKIP_MASTER_DISCOUNT_')+1,2)
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.RuleType='SKIP_MASTER_DISCOUNT' AND PromotionRule.PromotionName IN (N'DIB Sustainable STL Promotion',N'DIB Sustainable NSTL Promotion')
    AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=1);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleDescription,RuleSequence,RuleStage,RuleType,RuleValue,MinimumFee,MaximumFee,VATApplicable)
SELECT Seed.PromotionName,'EQUITY_RATE_TO_ACC',Seed.RuleDescription,10,'POST_MASTER_DISCOUNT','EQUITY_RATE_TO_ACC',
    Seed.RuleValue,5250,NULL,1
FROM (VALUES
    (N'Aggregator-STL-Equity Release',CONVERT(DECIMAL(20,4),1.25),N'Charge 1.25% of equity to ACC; minimum AED 5,250; no maximum cap; VAT applies.'),
    (N'Aggregator-NSTL-Equity Release',CONVERT(DECIMAL(20,4),1.25),N'Charge 1.25% of equity to ACC; minimum AED 5,250; no maximum cap; VAT applies.'),
    (N'Aggregator-GHP-Equity Release',CONVERT(DECIMAL(20,4),1.25),N'Charge 1.25% of equity to ACC; minimum AED 5,250; no maximum cap; VAT applies.'),
    (N'Aggregator-Equity Release-Standard',CONVERT(DECIMAL(20,4),1.25),N'Charge 1.25% of equity to ACC; minimum AED 5,250; no maximum cap; VAT applies.'),
    (N'Direct Customer-NSTL-Equity Release',CONVERT(DECIMAL(20,4),1.25),N'Charge 1.25% of equity to ACC; minimum AED 5,250; no maximum cap; VAT applies.')
) AS Seed(PromotionName,RuleValue,RuleDescription)
WHERE NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
    WHERE Existing.PromotionName=Seed.PromotionName AND Existing.RuleCode='EQUITY_RATE_TO_ACC');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_TYPE','EQ',N'Equity Release'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.RuleType='EQUITY_RATE_TO_ACC' AND PromotionRule.PromotionName LIKE N'Aggregator-%'
    AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=1);
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,2,'SOURCE_SUBMISSION','EQ',N'Aggregator'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.RuleType='EQUITY_RATE_TO_ACC' AND PromotionRule.PromotionName LIKE N'Aggregator-%'
    AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=2);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleDescription,RuleSequence,RuleStage,RuleType,TargetField,RuleValue)
SELECT Seed.PromotionName,'SET_FINANCE_RATE',Seed.RuleDescription,5,'PRE_CALC','RATE_SET','FEE_FV',Seed.RuleValue
FROM (VALUES
    (N'Aggregator-STL-Equity Release',CONVERT(DECIMAL(20,4),0.00),N'Other-finance rate is NIL.'),
    (N'Aggregator-NSTL-Equity Release',CONVERT(DECIMAL(20,4),0.75),N'Other-finance rate is 0.75%.'),
    (N'Aggregator-GHP-Equity Release',CONVERT(DECIMAL(20,4),0.00),N'Other-finance rate is NIL.'),
    (N'Aggregator-Equity Release-Standard',CONVERT(DECIMAL(20,4),0.75),N'Other-finance rate is 0.75%.'),
    (N'Direct Customer-NSTL-Equity Release',CONVERT(DECIMAL(20,4),0.75),N'Other-finance rate is 0.75%.'),
    (N'NSTL-0.75% Processing Fee',CONVERT(DECIMAL(20,4),0.75),N'Other-finance rate is 0.75%.')
) AS Seed(PromotionName,RuleValue,RuleDescription)
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
     WHERE Existing.PromotionName=Seed.PromotionName AND Existing.RuleCode='SET_FINANCE_RATE');

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleDescription,RuleSequence,RuleStage,RuleType,MinimumFee,MaximumFee,VATApplicable)
SELECT Seed.PromotionName,'ER_FEE_LIMITS',
    N'No base fee limits; the configured equity-rate rule applies the AED 5,250 minimum and no maximum cap; VAT applies.',
    7,'PRE_CALC','FEE_LIMITS',NULL,NULL,1
FROM (VALUES
    (N'Aggregator-STL-Equity Release'),
    (N'Aggregator-NSTL-Equity Release'),
    (N'Aggregator-GHP-Equity Release'),
    (N'Aggregator-Equity Release-Standard'),
    (N'Direct Customer-NSTL-Equity Release')
) AS Seed(PromotionName)
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
     WHERE Existing.PromotionName=Seed.PromotionName AND Existing.RuleCode='ER_FEE_LIMITS');

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_TYPE','EQ',N'Equity Release'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.RuleCode IN ('SET_FINANCE_RATE','ER_FEE_LIMITS')
  AND PromotionRule.PromotionName IN
      (N'Aggregator-STL-Equity Release',N'Aggregator-NSTL-Equity Release',
       N'Aggregator-GHP-Equity Release',N'Aggregator-Equity Release-Standard',
       N'Direct Customer-NSTL-Equity Release')
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Existing
      WHERE Existing.RuleId=PromotionRule.RuleId AND Existing.FilterSequence=1);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_TYPE','EQ',N'Equity Release'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.PromotionName=N'Direct Customer-NSTL-Equity Release'
  AND PromotionRule.RuleCode='EQUITY_RATE_TO_ACC'
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Existing
      WHERE Existing.RuleId=PromotionRule.RuleId AND Existing.FilterSequence=1);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_TYPE','NE',N'Equity Release'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.PromotionName=N'NSTL-0.75% Processing Fee'
  AND PromotionRule.RuleCode='SET_FINANCE_RATE'
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Existing
      WHERE Existing.RuleId=PromotionRule.RuleId AND Existing.FilterSequence=1);

DECLARE @NewPromotionNames TABLE(PromotionName NVARCHAR(200) NOT NULL PRIMARY KEY);
INSERT @NewPromotionNames(PromotionName) VALUES
    (N'Aggregator-STL-Equity Release'),
    (N'Aggregator-NSTL-Equity Release'),
    (N'Aggregator-GHP-Equity Release'),
    (N'Aggregator-Equity Release-Standard'),
    (N'Direct Customer-NSTL-Equity Release'),
    (N'NSTL-0.75% Processing Fee');
DECLARE @ZeroRateFields TABLE(FieldName VARCHAR(32) NOT NULL PRIMARY KEY);
INSERT @ZeroRateFields(FieldName) VALUES
    ('FEE_OPV'),('FEE_APV'),('FEE_Buyout'),('FEE_Topup'),('FEE_Equity'),('FEE_Cashout'),('FEE_MBRE');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleDescription,RuleSequence,RuleStage,RuleType,TargetField,RuleValue)
SELECT Promotion.PromotionName,'ZERO_' + FeeField.FieldName,
    N'Set ' + FeeField.FieldName + N' to 0%; the promotion calculates the configured finance/equity components.',
    6,'PRE_CALC','RATE_SET',FeeField.FieldName,0
FROM @NewPromotionNames Promotion CROSS JOIN @ZeroRateFields FeeField
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
     WHERE Existing.PromotionName=Promotion.PromotionName AND Existing.RuleCode='ZERO_' + FeeField.FieldName);
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_TYPE','EQ',N'Equity Release'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.RuleCode LIKE 'ZERO_FEE_%'
  AND PromotionRule.PromotionName IN
      (N'Aggregator-STL-Equity Release',N'Aggregator-NSTL-Equity Release',
       N'Aggregator-GHP-Equity Release',N'Aggregator-Equity Release-Standard',
       N'Direct Customer-NSTL-Equity Release')
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Existing
      WHERE Existing.RuleId=PromotionRule.RuleId AND Existing.FilterSequence=1);
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_TYPE','NE',N'Equity Release'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.RuleCode LIKE 'ZERO_FEE_%'
  AND PromotionRule.PromotionName=N'NSTL-0.75% Processing Fee'
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Existing
      WHERE Existing.RuleId=PromotionRule.RuleId AND Existing.FilterSequence=1);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleDescription,RuleSequence,RuleStage,RuleType,MinimumFee,MaximumFee,VATApplicable)
SELECT N'NSTL-0.75% Processing Fee','RESIDENT_FEE_LIMITS',
    N'Resident minimum AED 5,250 and maximum AED 105,000; VAT applies.',
    7,'PRE_CALC','FEE_LIMITS',5250,105000,1
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
     WHERE Existing.PromotionName=N'NSTL-0.75% Processing Fee' AND Existing.RuleCode='RESIDENT_FEE_LIMITS');
DECLARE @NstlResidentLimitsRuleId INT =
    (SELECT RuleId FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE
     WHERE PromotionName=N'NSTL-0.75% Processing Fee' AND RuleCode='RESIDENT_FEE_LIMITS');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT @NstlResidentLimitsRuleId,2,'RESIDENCY_TYPE','NOT_PREFIX',N'Non-Resident'
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER
     WHERE RuleId=@NstlResidentLimitsRuleId AND FilterSequence=2);
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleDescription,RuleSequence,RuleStage,RuleType,MinimumFee,MaximumFee,VATApplicable)
SELECT N'NSTL-0.75% Processing Fee','NON_RESIDENT_FEE_LIMITS',
    N'Non-resident minimum AED 5,250 with no maximum cap; VAT applies.',
    8,'PRE_CALC','FEE_LIMITS',5250,NULL,1
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
     WHERE Existing.PromotionName=N'NSTL-0.75% Processing Fee' AND Existing.RuleCode='NON_RESIDENT_FEE_LIMITS');
DECLARE @NstlNonResidentLimitsRuleId INT =
    (SELECT RuleId FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE
     WHERE PromotionName=N'NSTL-0.75% Processing Fee' AND RuleCode='NON_RESIDENT_FEE_LIMITS');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT @NstlNonResidentLimitsRuleId,2,'RESIDENCY_TYPE','PREFIX',N'Non-Resident'
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER
     WHERE RuleId=@NstlNonResidentLimitsRuleId AND FilterSequence=2);
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_TYPE','NE',N'Equity Release'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.PromotionName=N'NSTL-0.75% Processing Fee'
  AND PromotionRule.RuleCode IN ('RESIDENT_FEE_LIMITS','NON_RESIDENT_FEE_LIMITS')
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Existing
      WHERE Existing.RuleId=PromotionRule.RuleId AND Existing.FilterSequence=1);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleDescription,RuleSequence,RuleStage,RuleType,RuleValue,SplitMode,VATApplicable)
SELECT Seed.PromotionName,'PROCESSING_FEE_DISCOUNT',Seed.RuleDescription,10,'POST_BASE',
    'FEE_PERCENT_DISCOUNT',Seed.DiscountPercent,'RECALCULATE',1
FROM (VALUES
    (N'STL-100% Processing Fee Discount',CONVERT(DECIMAL(20,4),100.00),N'Apply a 100% processing fee discount; VAT applies to any resulting fee.'),
    (N'GHP-STL-100% Processing Fee Discount',CONVERT(DECIMAL(20,4),100.00),N'Apply a 100% processing fee discount; VAT applies to any resulting fee.'),
    (N'GHP-NSTL-100% Processing Fee Discount',CONVERT(DECIMAL(20,4),100.00),N'Apply a 100% processing fee discount; VAT applies to any resulting fee.'),
    (N'Abu Dhabi Developers-Final Payment-100% Processing Fee Discount',CONVERT(DECIMAL(20,4),100.00),N'Apply a 100% discount to Final Payment processing fees; VAT applies to any resulting fee.'),
    (N'Nest & Wajaha-50% Processing Fee Discount',CONVERT(DECIMAL(20,4),50.00),N'Apply a flat 50% discount to ER and other-finance processing fees; VAT applies.')
) AS Seed(PromotionName,DiscountPercent,RuleDescription)
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
     WHERE Existing.PromotionName=Seed.PromotionName AND Existing.RuleCode='PROCESSING_FEE_DISCOUNT');
UPDATE dbo.LEAD_ARR_FEE_PROMOTION_RULE
SET VATApplicable=1
WHERE RuleCode='PROCESSING_FEE_DISCOUNT'
  AND PromotionName IN (N'STL-100% Processing Fee Discount',
      N'GHP-STL-100% Processing Fee Discount',N'GHP-NSTL-100% Processing Fee Discount',
      N'Abu Dhabi Developers-Final Payment-100% Processing Fee Discount',
      N'Nest & Wajaha-50% Processing Fee Discount')
  AND VATApplicable IS NULL;

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_SUBTYPE','EQ',N'Final Payment'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.PromotionName=N'Abu Dhabi Developers-Final Payment-100% Processing Fee Discount'
  AND PromotionRule.RuleCode='PROCESSING_FEE_DISCOUNT'
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter
      WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=1);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleDescription,RuleSequence,RuleStage,RuleType,MinimumFee,MaximumFee,VATApplicable)
SELECT Seed.PromotionName,'NO_FEE_CAPS',
    N'This promotion has no minimum or maximum fee limit; VAT applies.',
    5,'PRE_CALC','FEE_LIMITS',NULL,NULL,1
FROM (VALUES
    (N'STL-100% Processing Fee Discount'),
    (N'GHP-STL-100% Processing Fee Discount'),
    (N'GHP-NSTL-100% Processing Fee Discount'),
    (N'Abu Dhabi Developers-Final Payment-100% Processing Fee Discount'),
    (N'Nest & Wajaha-50% Processing Fee Discount'),
    (N'Abu Dhabi Promotion')
) AS Seed(PromotionName)
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE Existing
     WHERE Existing.PromotionName=Seed.PromotionName AND Existing.RuleCode='NO_FEE_CAPS');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_SUBTYPE','EQ',N'Final Payment'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.RuleCode='NO_FEE_CAPS'
  AND PromotionRule.PromotionName IN
      (N'Abu Dhabi Developers-Final Payment-100% Processing Fee Discount',N'Abu Dhabi Promotion')
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter
      WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=1);

INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE
    (PromotionName,RuleCode,RuleSequence,RuleStage,RuleType,RuleValue,SplitMode)
SELECT N'Abu Dhabi Promotion','ABU_DHABI_FINAL_PAYMENT_NIL',10,'POST_BASE','FEE_PERCENT_DISCOUNT',100.00,'RECALCULATE'
WHERE NOT EXISTS
    (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE
     WHERE PromotionName=N'Abu Dhabi Promotion' AND RuleCode='ABU_DHABI_FINAL_PAYMENT_NIL');
INSERT dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER(RuleId,FilterSequence,FieldName,ComparisonOperator,FilterValue)
SELECT PromotionRule.RuleId,1,'PRODUCT_SUBTYPE','EQ',N'Final Payment'
FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
WHERE PromotionRule.PromotionName=N'Abu Dhabi Promotion'
  AND PromotionRule.RuleCode='ABU_DHABI_FINAL_PAYMENT_NIL'
  AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter
      WHERE Filter.RuleId=PromotionRule.RuleId AND Filter.FilterSequence=1);

UPDATE dbo.LEAD_ARR_FEE_PROMOTION_RULE
SET RuleDescription=N'Charge 1.25% of equity to ACC; minimum AED 5,250; no maximum cap; VAT applies.'
WHERE RuleCode='EQUITY_RATE_TO_ACC' AND RuleDescription IS NULL;
UPDATE dbo.LEAD_ARR_FEE_PROMOTION_RULE
SET RuleDescription=CASE PromotionName
    WHEN N'Aggregator-STL-Equity Release' THEN N'Other-finance rate is NIL.'
    WHEN N'Aggregator-GHP-Equity Release' THEN N'Other-finance rate is NIL.'
    ELSE N'Other-finance rate is 0.75%.'
END
WHERE RuleCode='SET_FINANCE_RATE' AND RuleDescription IS NULL;
UPDATE dbo.LEAD_ARR_FEE_PROMOTION_RULE
SET RuleDescription=CASE PromotionName
    WHEN N'Abu Dhabi Developers-Final Payment-100% Processing Fee Discount'
        THEN N'Apply a 100% discount to Final Payment processing fees; VAT applies.'
    WHEN N'Nest & Wajaha-50% Processing Fee Discount'
        THEN N'Apply a flat 50% discount to ER and other-finance processing fees; VAT applies.'
    ELSE N'Apply a 100% processing fee discount; VAT applies.'
END
WHERE RuleCode='PROCESSING_FEE_DISCOUNT' AND RuleDescription IS NULL;
UPDATE dbo.LEAD_ARR_FEE_PROMOTION_RULE
SET RuleDescription=CASE RuleType
    WHEN 'RATE_SET' THEN N'Set ' + ISNULL(TargetField,N'fee rate') + N' to '
        + COALESCE(CONVERT(NVARCHAR(40),RuleValue),N'0') + N'% before fee calculation.'
    WHEN 'RATE_SUBTRACT_POSITIVE' THEN N'Subtract '
        + COALESCE(CONVERT(NVARCHAR(40),RuleValue),N'0') + N' percentage points from positive '
        + ISNULL(TargetField,N'fee') + N' rates.'
    WHEN 'FEE_PERCENT_DISCOUNT' THEN N'Discount the calculated processing fee by '
        + COALESCE(CONVERT(NVARCHAR(40),RuleValue),N'0') + N'%.'
    WHEN 'FEE_FROM_AMOUNT' THEN N'Calculate '
        + COALESCE(CONVERT(NVARCHAR(40),RuleValue),N'0') + N'% of the configured '
        + ISNULL(AmountBasis,N'amount') + N' amount.'
    WHEN 'EQUITY_RATE_TO_ACC' THEN N'Add '
        + COALESCE(CONVERT(NVARCHAR(40),RuleValue),N'0') + N'% of equity to ACC.'
    WHEN 'SKIP_MASTER_DISCOUNT' THEN N'Skip the master discount when configured filters match.'
    WHEN 'FEE_LIMITS' THEN
        CASE WHEN MinimumFee IS NULL THEN N'No minimum fee' ELSE N'Minimum fee AED ' + CONVERT(NVARCHAR(40),MinimumFee) END
        + CASE WHEN MaximumFee IS NULL THEN N'; no maximum cap.' ELSE N'; maximum fee AED ' + CONVERT(NVARCHAR(40),MaximumFee) + N'.' END
    ELSE N'Configured promotion calculation rule.'
END
WHERE RuleDescription IS NULL;
GO

IF OBJECT_ID(N'dbo.vw_LeadFeePromotionMaster',N'V') IS NOT NULL
    DROP VIEW dbo.vw_LeadFeePromotionMaster;
GO
CREATE VIEW dbo.vw_LeadFeePromotionMaster
AS
WITH PromotionEntries AS
(
    SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))) AS PromotionValue,
        COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(1000),DisplayValue))),N''),
            LTRIM(RTRIM(CONVERT(NVARCHAR(1000),[Value])))) AS PromotionDisplayName,
        Status AS SourceStatus, 0 AS SourcePriority
    FROM dbo.FRM_gnarr
    WHERE UPPER(LTRIM(RTRIM(Code)))=N'LEAD_PROMOTION'
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),N'') IS NOT NULL
    UNION ALL
    SELECT PromotionName,PromotionName,Status,1
    FROM dbo.Lead_Promotion_master
    WHERE PromotionName IS NOT NULL
    UNION ALL
    SELECT PromotionName,PromotionName,CONVERT(NVARCHAR(100),NULL),2
    FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
),
NormalizedPromotions AS
(
    SELECT PromotionValue,PromotionDisplayName,SourceStatus,SourcePriority,
        REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionValue)),NCHAR(8209),N'-'),
            NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-') AS PromotionKey
    FROM PromotionEntries
),
PromotionSource AS
(
    SELECT PromotionKey,
        COALESCE(MAX(CASE WHEN SourcePriority=0 THEN PromotionDisplayName END),
            MAX(CASE WHEN SourcePriority=1 THEN PromotionDisplayName END),
            MIN(PromotionValue)) AS PromotionName,
        COALESCE(MIN(CASE WHEN SourcePriority=0 THEN PromotionValue END),
            MIN(CASE WHEN SourcePriority=1 THEN PromotionValue END),
            MIN(PromotionValue)) AS SourcePromotionValue,
        MAX(CASE WHEN SourcePriority=0 THEN SourceStatus END) AS SourceStatus
    FROM NormalizedPromotions
    GROUP BY PromotionKey
)
SELECT Source.PromotionName,Source.PromotionKey,Source.SourcePromotionValue,Master.SRNO,
    COALESCE(Master.PromotionName,Source.PromotionName) AS MasterPromotionName,
    Master.DiscountPerc,Master.StartDate,Master.EndDate,Master.Status AS MasterStatus,
    Master.Createdby_user AS MasterCreatedBy,Master.Createdon_date AS MasterCreatedOn,
    Master.UpdatedBy_user AS MasterUpdatedBy,Master.Updatedon_Date AS MasterUpdatedOn,
    Effective.IsEnabled,
    CASE WHEN Effective.IsEnabled=1 THEN N'A' ELSE N'I' END AS EffectiveStatus,
    ISNULL(Configuration.UseMasterDiscount,CASE WHEN Master.SRNO IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END) AS UseMasterDiscount,
    ISNULL(Configuration.SkipMinFee,0) AS SkipMinFee,
    ISNULL(Configuration.SkipMaxFee,0) AS SkipMaxFee,
    Configuration.LookupProductType,Configuration.LookupProductSubType,
    Configuration.UpdatedBy AS ConfigUpdatedBy,Configuration.UpdatedOn AS ConfigUpdatedOn,
    Source.SourceStatus
FROM PromotionSource Source
OUTER APPLY
(
    SELECT TOP (1) Promotion.SRNO,Promotion.PromotionName,Promotion.DiscountPerc,
        Promotion.StartDate,Promotion.EndDate,Promotion.Status,Promotion.Createdby_user,
        Promotion.Createdon_date,Promotion.UpdatedBy_user,Promotion.Updatedon_Date
    FROM dbo.Lead_Promotion_master Promotion
    WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Promotion.PromotionName)),NCHAR(8209),N'-'),
        NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=Source.PromotionKey
       OR REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Promotion.PromotionName)),NCHAR(8209),N'-'),
           NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')
           =REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Source.PromotionName)),NCHAR(8209),N'-'),
               NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')
    ORDER BY Promotion.SRNO DESC
) Master
OUTER APPLY
(
    SELECT TOP (1) Config.IsEnabled,Config.UseMasterDiscount,Config.SkipMinFee,Config.SkipMaxFee,
        Config.LookupProductType,Config.LookupProductSubType,Config.UpdatedBy,Config.UpdatedOn
    FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG Config
    WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Config.PromotionName)),NCHAR(8209),N'-'),
        NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=Source.PromotionKey
    ORDER BY Config.UpdatedOn DESC,Config.PromotionName
) Configuration
CROSS APPLY
(
    SELECT COALESCE(Configuration.IsEnabled,
        CASE WHEN Source.SourceStatus IS NOT NULL
            THEN CASE WHEN UPPER(LTRIM(RTRIM(Source.SourceStatus)))=N'A' THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END
            WHEN Master.SRNO IS NOT NULL
            THEN CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(Master.Status,N''))))=N'A' THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END
            ELSE CONVERT(BIT,1)
        END) AS IsEnabled
) Effective;
GO

IF OBJECT_ID(N'dbo.Lead_Fee_Master_Request', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Lead_Fee_Master_Request
    (
        RequestId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Lead_Fee_Master_Request PRIMARY KEY,
        MasterType CHAR(1) NOT NULL CONSTRAINT CK_Lead_Fee_Master_Request_Type CHECK (MasterType IN ('P','F','C')),
        Operation CHAR(1) NOT NULL CONSTRAINT CK_Lead_Fee_Master_Request_Operation CHECK (Operation IN ('I','U')),
        MasterKey NVARCHAR(1100) NOT NULL,
        TargetSRNO INT NULL,
        OldProductType NVARCHAR(300) NULL,
        OldProductSubType NVARCHAR(300) NULL,
        OldResidencyType NVARCHAR(200) NULL,
        OldStaff NVARCHAR(200) NULL,
        OldValues XML NULL,
        NewValues XML NOT NULL,
        StatusCode CHAR(1) NOT NULL CONSTRAINT DF_Lead_Fee_Master_Request_Status DEFAULT ('P')
            CONSTRAINT CK_Lead_Fee_Master_Request_Status CHECK (StatusCode IN ('P','A','R')),
        MakerLoginId NVARCHAR(100) NOT NULL,
        MakerRemarks NVARCHAR(1000) NOT NULL,
        SubmittedOn DATETIME2(0) NOT NULL CONSTRAINT DF_Lead_Fee_Master_Request_Submitted DEFAULT (SYSDATETIME()),
        CheckerLoginId NVARCHAR(100) NULL,
        CheckerRemarks NVARCHAR(1000) NULL,
        CheckedOn DATETIME2(0) NULL,
        AttachmentName NVARCHAR(260) NULL,
        AttachmentType NVARCHAR(150) NULL,
        AttachmentData VARBINARY(MAX) NULL,
        CONSTRAINT CK_Lead_Fee_Master_Request_DistinctUsers
            CHECK (CheckerLoginId IS NULL OR MakerLoginId <> CheckerLoginId)
    );
    CREATE INDEX IX_Lead_Fee_Master_Request_Filter
        ON dbo.Lead_Fee_Master_Request(MasterType, StatusCode, SubmittedOn DESC);
END;

IF EXISTS (SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.Lead_Fee_Master_Request')
      AND name=N'CK_Lead_Fee_Master_Request_Type')
    ALTER TABLE dbo.Lead_Fee_Master_Request DROP CONSTRAINT CK_Lead_Fee_Master_Request_Type;
ALTER TABLE dbo.Lead_Fee_Master_Request
    ADD CONSTRAINT CK_Lead_Fee_Master_Request_Type CHECK (MasterType IN ('P','F','C'));

ALTER TABLE dbo.Lead_Fee_Master_Request ALTER COLUMN MasterKey NVARCHAR(1100) NOT NULL;
ALTER TABLE dbo.Lead_Fee_Master_Request ALTER COLUMN OldProductType NVARCHAR(300) NULL;
ALTER TABLE dbo.Lead_Fee_Master_Request ALTER COLUMN OldProductSubType NVARCHAR(300) NULL;
ALTER TABLE dbo.Lead_Fee_Master_Request ALTER COLUMN OldResidencyType NVARCHAR(200) NULL;
ALTER TABLE dbo.Lead_Fee_Master_Request ALTER COLUMN OldStaff NVARCHAR(200) NULL;

IF OBJECT_ID(N'dbo.Lead_Fee_Master_Audit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Lead_Fee_Master_Audit
    (
        AuditId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Lead_Fee_Master_Audit PRIMARY KEY,
        RequestId BIGINT NOT NULL,
        ActionName VARCHAR(20) NOT NULL,
        ActionBy NVARCHAR(100) NOT NULL,
        ActionOn DATETIME2(0) NOT NULL CONSTRAINT DF_Lead_Fee_Master_Audit_ActionOn DEFAULT (SYSDATETIME()),
        OldValues XML NULL,
        NewValues XML NOT NULL,
        Remarks NVARCHAR(1000) NULL,
        CONSTRAINT FK_Lead_Fee_Master_Audit_Request FOREIGN KEY (RequestId)
            REFERENCES dbo.Lead_Fee_Master_Request(RequestId)
    );
    CREATE INDEX IX_Lead_Fee_Master_Audit_Request ON dbo.Lead_Fee_Master_Audit(RequestId, AuditId);
END;
GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_GetRows', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_GetRows;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_GetRows
    @MasterType CHAR(1), @Search NVARCHAR(200) = NULL, @PromotionName NVARCHAR(200) = NULL,
    @ProductType NVARCHAR(300) = NULL, @ProductSubType NVARCHAR(300) = NULL,
    @Status NVARCHAR(10) = NULL,
    @ResidencyType NVARCHAR(200) = NULL, @Staff NVARCHAR(200) = NULL,
    @FromDate DATE = NULL, @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @MasterType = 'P'
    BEGIN
        SELECT SRNO,PromotionName,PromotionKey,SourcePromotionValue,MasterPromotionName,DiscountPerc,StartDate,EndDate,
            MasterStatus,MasterCreatedBy,MasterCreatedOn,MasterUpdatedBy,MasterUpdatedOn,
            IsEnabled,EffectiveStatus AS Status,UseMasterDiscount,SkipMinFee,SkipMaxFee,
            LookupProductType,LookupProductSubType,ConfigUpdatedBy,ConfigUpdatedOn,SourceStatus
        FROM dbo.vw_LeadFeePromotionMaster
        WHERE (NULLIF(@Search,N'') IS NULL OR PromotionName LIKE N'%' + @Search + N'%'
            OR PromotionKey LIKE N'%' + @Search + N'%')
          AND (NULLIF(@PromotionName,N'') IS NULL OR PromotionKey=@PromotionName)
          AND (NULLIF(@Status,N'') IS NULL OR EffectiveStatus=@Status)
          AND (@FromDate IS NULL OR StartDate >= @FromDate)
          AND (@ToDate IS NULL OR StartDate < DATEADD(DAY,1,@ToDate))
        ORDER BY PromotionName, SRNO;
        RETURN;
    END;
    IF @MasterType = 'C'
    BEGIN
        ;WITH PromotionEntries AS
        (
            SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))) AS PromotionValue,
                COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(1000),DisplayValue))),N''),
                    LTRIM(RTRIM(CONVERT(NVARCHAR(1000),[Value])))) AS PromotionDisplayName,
                Status AS SourceStatus, 0 AS SourcePriority
            FROM dbo.FRM_gnarr
            WHERE UPPER(LTRIM(RTRIM(Code)))=N'LEAD_PROMOTION'
              AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),N'') IS NOT NULL
            UNION ALL
            SELECT PromotionName,PromotionName,CONVERT(NVARCHAR(100),NULL),1
            FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
        ),
        NormalizedPromotions AS
        (
            SELECT PromotionValue,PromotionDisplayName,SourceStatus,
                REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionValue)),NCHAR(8209),N'-'),
                    NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-') AS PromotionKey,
                SourcePriority
            FROM PromotionEntries
        ),
        PromotionSource AS
        (
            SELECT PromotionKey,
                COALESCE(MAX(CASE WHEN SourcePriority=0 THEN PromotionDisplayName END),MIN(PromotionValue)) AS PromotionName,
                MAX(CASE WHEN SourcePriority=0 THEN SourceStatus END) AS SourceStatus
            FROM NormalizedPromotions
            GROUP BY PromotionKey
        )
        SELECT Source.PromotionName, Source.PromotionKey, Source.SourceStatus,
            Effective.IsEnabled,
            CASE WHEN Effective.IsEnabled=1 THEN N'A' ELSE N'I' END AS Status,
            Configuration.UseMasterDiscount, Configuration.SkipMinFee, Configuration.SkipMaxFee,
            Configuration.LookupProductType, Configuration.LookupProductSubType,
            Configuration.UpdatedBy, Configuration.UpdatedOn
        FROM PromotionSource Source
        OUTER APPLY
        (
            SELECT TOP (1) Config.IsEnabled,Config.UseMasterDiscount,Config.SkipMinFee,Config.SkipMaxFee,
                Config.LookupProductType,Config.LookupProductSubType,Config.UpdatedBy,Config.UpdatedOn
            FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG Config
            WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Config.PromotionName)),NCHAR(8209),N'-'),
                NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=Source.PromotionKey
            ORDER BY Config.UpdatedOn DESC,Config.PromotionName
        ) Configuration
        CROSS APPLY
        (
            SELECT ISNULL(Configuration.IsEnabled,
                CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(Source.SourceStatus,N''))))=N'A'
                    THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END) AS IsEnabled
        ) Effective
        WHERE (NULLIF(@Status,N'') IS NULL OR
            (Effective.IsEnabled=1 AND @Status='A') OR
            (Effective.IsEnabled=0 AND @Status='I'))
        ORDER BY Source.PromotionName;
        RETURN;
    END;
    IF @MasterType = 'F'
    BEGIN
        SELECT PRODUCT_TYPE, Product_SubTYPE, Residency_Type, Staff, FEE_FV, FEE_OPV,
            FEE_APV, FEE_Buyout, FEE_Topup, FEE_Equity, FEE_Cashout, FEE_MBRE,
            FEE_APP, FEE_ACC, MIN_FEE, MAX_FEE, Status, CreatedBy_User,
            Createdon_Date, Updatedby_User, Updatedon_Date, Is_VAT_Applicable
        FROM dbo.LEAD_ARR_FEE_MASTER
        WHERE (NULLIF(@Search, N'') IS NULL OR PRODUCT_TYPE LIKE N'%' + @Search + N'%'
            OR Product_SubTYPE LIKE N'%' + @Search + N'%')
                    AND (NULLIF(@ProductType,N'') IS NULL OR PRODUCT_TYPE=@ProductType)
                    AND (NULLIF(@ProductSubType,N'') IS NULL OR Product_SubTYPE=@ProductSubType)
          AND (NULLIF(@Status, N'') IS NULL OR ISNULL(Status, N'') = @Status)
          AND (NULLIF(@ResidencyType, N'') IS NULL OR Residency_Type = @ResidencyType)
          AND (NULLIF(@Staff, N'') IS NULL OR Staff = @Staff)
        ORDER BY PRODUCT_TYPE, Product_SubTYPE, Residency_Type, Staff;
        RETURN;
    END;
    THROW 51702, 'Select a valid lead fee master.', 1;
END;
GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_GetFilterOptions', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_GetFilterOptions;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_GetFilterOptions @MasterType CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;
    IF @MasterType='P'
    BEGIN
        SELECT PromotionName,PromotionKey FROM dbo.vw_LeadFeePromotionMaster
        ORDER BY PromotionName,PromotionKey;
        RETURN;
    END;
    IF @MasterType='C'
    BEGIN
        SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))) AS PromotionName
        FROM dbo.FRM_gnarr
        WHERE UPPER(LTRIM(RTRIM(Code)))=N'LEAD_PROMOTION'
          AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),N'') IS NOT NULL
        UNION
        SELECT PromotionName FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
        ORDER BY PromotionName;
        RETURN;
    END;
    IF @MasterType='F'
    BEGIN
        SELECT DISTINCT PRODUCT_TYPE FROM dbo.LEAD_ARR_FEE_MASTER
        WHERE PRODUCT_TYPE IS NOT NULL ORDER BY PRODUCT_TYPE;
        SELECT DISTINCT Product_SubTYPE FROM dbo.LEAD_ARR_FEE_MASTER
        WHERE Product_SubTYPE IS NOT NULL ORDER BY Product_SubTYPE;
        SELECT DISTINCT Residency_Type FROM dbo.LEAD_ARR_FEE_MASTER
        WHERE Residency_Type IS NOT NULL ORDER BY Residency_Type;
        RETURN;
    END;
    THROW 51702, 'Select a valid lead fee master.', 1;
END;
GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_GetRecord', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_GetRecord;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_GetRecord
    @MasterType CHAR(1), @SRNO INT = NULL,
    @ProductType NVARCHAR(300) = NULL, @ProductSubType NVARCHAR(300) = NULL,
    @ResidencyType NVARCHAR(200) = NULL, @Staff NVARCHAR(200) = NULL,
    @ConfigPromotionName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @MasterType = 'P'
    BEGIN
        IF NULLIF(@ConfigPromotionName,N'') IS NOT NULL
            SELECT * FROM dbo.vw_LeadFeePromotionMaster WHERE PromotionKey=@ConfigPromotionName;
        ELSE
            SELECT SRNO,PromotionName,PromotionKey,SourcePromotionValue,MasterPromotionName,DiscountPerc,StartDate,EndDate,
                MasterStatus,MasterCreatedBy,MasterCreatedOn,MasterUpdatedBy,MasterUpdatedOn,
                IsEnabled,EffectiveStatus AS Status,UseMasterDiscount,SkipMinFee,SkipMaxFee,
                LookupProductType,LookupProductSubType,ConfigUpdatedBy,ConfigUpdatedOn,SourceStatus
            FROM dbo.vw_LeadFeePromotionMaster WHERE SRNO=@SRNO;
    END
    ELSE IF @MasterType = 'C'
    BEGIN
        ;WITH PromotionEntries AS
        (
            SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))) AS PromotionValue,
                COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(1000),DisplayValue))),N''),
                    LTRIM(RTRIM(CONVERT(NVARCHAR(1000),[Value])))) AS PromotionDisplayName,
                Status AS SourceStatus, 0 AS SourcePriority
            FROM dbo.FRM_gnarr
            WHERE UPPER(LTRIM(RTRIM(Code)))=N'LEAD_PROMOTION'
              AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),N'') IS NOT NULL
            UNION
            SELECT PromotionName,PromotionName,CONVERT(NVARCHAR(100),NULL),1
            FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
        )
        , NormalizedPromotions AS
        (
            SELECT PromotionValue,PromotionDisplayName,SourceStatus,SourcePriority,
                REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionValue)),NCHAR(8209),N'-'),
                    NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-') AS PromotionKey
            FROM PromotionEntries
        )
        , PromotionSource AS
        (
            SELECT PromotionKey,
                COALESCE(MAX(CASE WHEN SourcePriority=0 THEN PromotionDisplayName END),MIN(PromotionValue)) AS PromotionName,
                MAX(CASE WHEN SourcePriority=0 THEN SourceStatus END) AS SourceStatus
            FROM NormalizedPromotions
            GROUP BY PromotionKey
        )
        SELECT Source.PromotionName, Source.PromotionKey, Source.SourceStatus, Effective.IsEnabled,
            Configuration.UseMasterDiscount, Configuration.SkipMinFee, Configuration.SkipMaxFee,
            Configuration.LookupProductType, Configuration.LookupProductSubType,
            Configuration.UpdatedBy, Configuration.UpdatedOn
        FROM PromotionSource Source
        OUTER APPLY
        (
            SELECT TOP (1) Config.IsEnabled,Config.UseMasterDiscount,Config.SkipMinFee,Config.SkipMaxFee,
                Config.LookupProductType,Config.LookupProductSubType,Config.UpdatedBy,Config.UpdatedOn
            FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG Config
            WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Config.PromotionName)),NCHAR(8209),N'-'),
                NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=Source.PromotionKey
            ORDER BY Config.UpdatedOn DESC,Config.PromotionName
        ) Configuration
        CROSS APPLY
        (
            SELECT ISNULL(Configuration.IsEnabled,
                CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(Source.SourceStatus,N''))))=N'A'
                    THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END) AS IsEnabled
        ) Effective
        WHERE Source.PromotionKey=@ConfigPromotionName;
    END
    ELSE IF @MasterType = 'F'
        SELECT PRODUCT_TYPE, Product_SubTYPE, Residency_Type, Staff, FEE_FV, FEE_OPV,
            FEE_APV, FEE_Buyout, FEE_Topup, FEE_Equity, FEE_Cashout, FEE_MBRE,
            FEE_APP, FEE_ACC, MIN_FEE, MAX_FEE, Status, CreatedBy_User,
            Createdon_Date, Updatedby_User, Updatedon_Date, Is_VAT_Applicable
        FROM dbo.LEAD_ARR_FEE_MASTER
        WHERE PRODUCT_TYPE = @ProductType AND Product_SubTYPE = @ProductSubType
          AND Residency_Type = @ResidencyType AND Staff = @Staff;
    ELSE THROW 51702, 'Select a valid lead fee master.', 1;
END;
GO

    IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_GetPromotionRules',N'P') IS NOT NULL
        DROP PROCEDURE dbo.Proc_LeadFeeMaster_GetPromotionRules;
    GO
    CREATE PROCEDURE dbo.Proc_LeadFeeMaster_GetPromotionRules @PromotionKey NVARCHAR(200)
    AS
    BEGIN
        SET NOCOUNT ON;
        SELECT COALESCE(PromotionRule.RuleDescription,CONVERT(NVARCHAR(500),PromotionRule.RuleCode)) AS RuleDescription,
            PromotionRule.RuleCode,PromotionRule.RuleSequence,PromotionRule.RuleStage,
            PromotionRule.RuleType,PromotionRule.TargetField,PromotionRule.AmountBasis,
            PromotionRule.RuleValue,PromotionRule.MinimumFee,PromotionRule.MaximumFee,
            PromotionRule.SplitMode,PromotionRule.FloorSplitMode,PromotionRule.VATApplicable,
            PromotionRule.IsEnabled,
            ISNULL(STUFF
            (
                (
                    SELECT N'; ' + Filter.FieldName + N' ' + Filter.ComparisonOperator + N' ' + Filter.FilterValue
                    FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER Filter
                    WHERE Filter.RuleId=PromotionRule.RuleId
                    ORDER BY Filter.FilterSequence
                    FOR XML PATH(''),TYPE
                ).value('.','NVARCHAR(MAX)'),1,2,N''
            ),N'No filters (all matching cases)') AS Filters
        FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
        CROSS JOIN dbo.vw_LeadFeePromotionMaster Promotion
        WHERE Promotion.PromotionKey=@PromotionKey
          AND
          (
            REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionRule.PromotionName)),NCHAR(8209),N'-'),
                NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=Promotion.PromotionKey
            OR REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionRule.PromotionName)),NCHAR(8209),N'-'),
                NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')
                =REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Promotion.PromotionName)),NCHAR(8209),N'-'),
                    NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')
            OR REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionRule.PromotionName)),NCHAR(8209),N'-'),
                NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')
                =REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(Promotion.MasterPromotionName)),NCHAR(8209),N'-'),
                    NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')
          )
        ORDER BY PromotionRule.RuleSequence,PromotionRule.RuleCode;
    END;
    GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_GetRequests', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_GetRequests;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_GetRequests
    @MasterType CHAR(1) = NULL, @Status CHAR(1) = NULL, @MakerLoginId NVARCHAR(100) = NULL,
    @FromDate DATE = NULL, @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RequestId, MasterType, Operation, MasterKey, StatusCode, MakerLoginId, MakerRemarks,
        SubmittedOn, CheckerLoginId, CheckerRemarks, CheckedOn, AttachmentName,
        CASE MasterType WHEN 'P' THEN 'Promotion Setup'
            WHEN 'C' THEN 'Promotion Configuration' ELSE 'Arrangement Fee Master' END AS MasterName
    FROM dbo.Lead_Fee_Master_Request
    WHERE (@MasterType IS NULL OR MasterType = @MasterType)
      AND (@Status IS NULL OR StatusCode = @Status)
      AND (NULLIF(@MakerLoginId, N'') IS NULL OR MakerLoginId LIKE N'%' + @MakerLoginId + N'%')
      AND (@FromDate IS NULL OR SubmittedOn >= @FromDate)
      AND (@ToDate IS NULL OR SubmittedOn < DATEADD(DAY, 1, @ToDate))
    ORDER BY SubmittedOn DESC, RequestId DESC;
END;
GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_GetRequest', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_GetRequest;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_GetRequest @RequestId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RequestId, MasterType, Operation, MasterKey, TargetSRNO, OldProductType,
        OldProductSubType, OldResidencyType, OldStaff, OldValues, NewValues, StatusCode,
        MakerLoginId, MakerRemarks, SubmittedOn, CheckerLoginId, CheckerRemarks, CheckedOn,
        AttachmentName, AttachmentType, AttachmentData,
        CASE MasterType WHEN 'P' THEN 'Promotion Setup'
            WHEN 'C' THEN 'Promotion Configuration' ELSE 'Arrangement Fee Master' END AS MasterName
    FROM dbo.Lead_Fee_Master_Request WHERE RequestId = @RequestId;
END;
GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_GetAudit', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_GetAudit;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_GetAudit @RequestId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AuditId, ActionName, ActionBy, ActionOn, Remarks, OldValues, NewValues
    FROM dbo.Lead_Fee_Master_Audit WHERE RequestId = @RequestId ORDER BY AuditId DESC;
END;
GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_Submit', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_Submit;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_Submit
    @MasterType CHAR(1), @TargetSRNO INT = NULL,
    @OldProductType NVARCHAR(300) = NULL, @OldProductSubType NVARCHAR(300) = NULL,
    @OldResidencyType NVARCHAR(200) = NULL, @OldStaff NVARCHAR(200) = NULL,
    @NewValues XML, @MakerLoginId NVARCHAR(100), @MakerRemarks NVARCHAR(1000),
    @AttachmentName NVARCHAR(260) = NULL, @AttachmentType NVARCHAR(150) = NULL,
    @AttachmentData VARBINARY(MAX) = NULL, @RequestId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @MasterType NOT IN ('P','F','C') OR @NewValues IS NULL OR @NewValues.exist('/Record[1]') <> 1
        THROW 51703, 'The master type or proposed master data is invalid.', 1;
    IF NULLIF(LTRIM(RTRIM(@MakerLoginId)), N'') IS NULL
        THROW 51704, 'Maker ID is required.', 1;
    SET @MakerRemarks=ISNULL(@MakerRemarks,N'');
    IF DATALENGTH(@MakerLoginId) > 200 OR DATALENGTH(@MakerRemarks) > 2000
        THROW 51705, 'Maker ID or remarks exceed the supported length.', 1;
    IF DATALENGTH(@AttachmentData) > 5242880
        THROW 51706, 'Attachment must not exceed 5 MB.', 1;
    IF @AttachmentData IS NOT NULL AND (NULLIF(@AttachmentName,N'') IS NULL OR NULLIF(@AttachmentType,N'') IS NULL)
        THROW 51707, 'Attachment name and type are required.', 1;

    DECLARE @Operation CHAR(1), @MasterKey NVARCHAR(1100), @OldValues XML = NULL;
    DECLARE @Name NVARCHAR(200), @Raw NVARCHAR(100), @Number DECIMAL(20,4), @Status NVARCHAR(10);
    DECLARE @StartDateText NVARCHAR(30), @EndDateText NVARCHAR(30);
    DECLARE @StartDate DATETIME, @EndDate DATETIME;

    IF @MasterType = 'P'
    BEGIN
        IF @NewValues.exist('/Record/PromotionKey[1]')=1
        BEGIN
            DECLARE @PackagePromotionKey NVARCHAR(200),@PackagePromotionName NVARCHAR(200),
                @PackageEnabledText NVARCHAR(10),@PackageUseMasterText NVARCHAR(10),
                @PackageSkipMinText NVARCHAR(10),@PackageSkipMaxText NVARCHAR(10),
                @PackageLookupProductType NVARCHAR(300),@PackageLookupProductSubType NVARCHAR(300),
                @PackageCurrentSRNO INT,@PackageConfigExists BIT,@PackageExpectedName NVARCHAR(200),
                @PackageCanonicalName NVARCHAR(200),
                @PackageEnabled BIT,@PackageUseMaster BIT,@PackageSkipMin BIT,@PackageSkipMax BIT;
            SET @PackagePromotionKey=LTRIM(RTRIM(@NewValues.value('string((/Record/PromotionKey)[1])','NVARCHAR(200)')));
            SET @PackagePromotionName=LTRIM(RTRIM(@NewValues.value('string((/Record/PromotionName)[1])','NVARCHAR(200)')));
            SET @Raw=LTRIM(RTRIM(@NewValues.value('string((/Record/DiscountPerc)[1])','NVARCHAR(100)')));
            SET @Status=LTRIM(RTRIM(@NewValues.value('string((/Record/MasterStatus)[1])','NVARCHAR(10)')));
            SET @StartDateText=LTRIM(RTRIM(@NewValues.value('string((/Record/StartDate)[1])','NVARCHAR(30)')));
            SET @EndDateText=LTRIM(RTRIM(@NewValues.value('string((/Record/EndDate)[1])','NVARCHAR(30)')));
            SET @PackageEnabledText=LTRIM(RTRIM(@NewValues.value('string((/Record/IsEnabled)[1])','NVARCHAR(10)')));
            SET @PackageUseMasterText=LTRIM(RTRIM(@NewValues.value('string((/Record/UseMasterDiscount)[1])','NVARCHAR(10)')));
            SET @PackageSkipMinText=LTRIM(RTRIM(@NewValues.value('string((/Record/SkipMinFee)[1])','NVARCHAR(10)')));
            SET @PackageSkipMaxText=LTRIM(RTRIM(@NewValues.value('string((/Record/SkipMaxFee)[1])','NVARCHAR(10)')));
            SET @PackageLookupProductType=NULLIF(LTRIM(RTRIM(@NewValues.value('string((/Record/LookupProductType)[1])','NVARCHAR(300)'))),N'');
            SET @PackageLookupProductSubType=NULLIF(LTRIM(RTRIM(@NewValues.value('string((/Record/LookupProductSubType)[1])','NVARCHAR(300)'))),N'');

            IF NULLIF(@PackagePromotionKey,N'') IS NULL OR NULLIF(@PackagePromotionName,N'') IS NULL
                OR @PackageEnabledText NOT IN ('0','1') OR @PackageUseMasterText NOT IN ('0','1')
                OR @PackageSkipMinText NOT IN ('0','1') OR @PackageSkipMaxText NOT IN ('0','1')
                OR @Status NOT IN ('A','I')
                OR (@PackageLookupProductType IS NULL AND @PackageLookupProductSubType IS NOT NULL)
                OR (@PackageLookupProductType IS NOT NULL AND @PackageLookupProductSubType IS NULL)
                THROW 51708, 'Promotion package values are invalid.', 1;
            SET @PackageEnabled=CONVERT(BIT,@PackageEnabledText);
            SET @PackageUseMaster=CONVERT(BIT,@PackageUseMasterText);
            SET @PackageSkipMin=CONVERT(BIT,@PackageSkipMinText);
            SET @PackageSkipMax=CONVERT(BIT,@PackageSkipMaxText);

            SELECT @PackageCurrentSRNO=SRNO,@PackageExpectedName=PromotionName,
                @PackageCanonicalName=SourcePromotionValue
            FROM dbo.vw_LeadFeePromotionMaster
            WHERE PromotionKey=@PackagePromotionKey;
            IF @PackageExpectedName IS NULL OR @PackagePromotionName<>@PackageExpectedName
                THROW 51723, 'The selected promotion is no longer available.', 1;
            IF ISNULL(@TargetSRNO,0)<>ISNULL(@PackageCurrentSRNO,0)
                THROW 51709, 'The promotion package changed after it was selected. Refresh and retry.', 1;

            SET @PackageConfigExists=CASE WHEN EXISTS
            (
                SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
                WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionName)),NCHAR(8209),N'-'),
                    NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@PackagePromotionKey
            ) THEN 1 ELSE 0 END;
            SET @Operation=CASE WHEN ISNULL(@PackageCurrentSRNO,0)>0 OR @PackageConfigExists=1 THEN 'U' ELSE 'I' END;
            SET @MasterKey=N'P|' + @PackagePromotionKey;
            SELECT @OldValues=(SELECT * FROM dbo.vw_LeadFeePromotionMaster
                WHERE PromotionKey=@PackagePromotionKey
                FOR XML PATH('Record'),ELEMENTS XSINIL,TYPE);
            SET @Name=@PackageExpectedName;

            IF NULLIF(@Raw,N'') IS NULL
            BEGIN
                IF @PackageUseMaster=1 OR ISNULL(@PackageCurrentSRNO,0)>0
                    THROW 51708, 'A master discount is required for this promotion.', 1;
                SET @Number=NULL;
            END
            ELSE
            BEGIN
                IF @Raw LIKE N'%[^0-9.]%' OR @Raw LIKE N'%.%.%' OR @Raw NOT LIKE N'%[0-9]%'
                    THROW 51708, 'Promotion discount must be numeric.', 1;
                SET @Number=CAST(@Raw AS DECIMAL(20,4));
                IF @Number<0 OR @Number>100
                    THROW 51708, 'Promotion discount must be between 0 and 100.', 1;
            END;
            IF (@StartDateText<>N'' AND (LEN(@StartDateText)<>10 OR SUBSTRING(@StartDateText,5,1)<>N'-'
                    OR SUBSTRING(@StartDateText,8,1)<>N'-' OR REPLACE(@StartDateText,N'-',N'') LIKE N'%[^0-9]%'))
                OR (@EndDateText<>N'' AND (LEN(@EndDateText)<>10 OR SUBSTRING(@EndDateText,5,1)<>N'-'
                    OR SUBSTRING(@EndDateText,8,1)<>N'-' OR REPLACE(@EndDateText,N'-',N'') LIKE N'%[^0-9]%'))
                THROW 51708, 'Promotion dates are invalid.', 1;
            IF @Number IS NULL AND (@StartDateText<>N'' OR @EndDateText<>N'' OR @Status<>'A')
                THROW 51708, 'Master dates and status require a master discount.', 1;
            IF @StartDateText<>N'' SET @StartDate=CONVERT(DATETIME,REPLACE(@StartDateText,N'-',N''),112);
            IF @EndDateText<>N'' SET @EndDate=CONVERT(DATETIME,REPLACE(@EndDateText,N'-',N''),112);
            IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate>@EndDate
                THROW 51708, 'Promotion end date must be on or after the start date.', 1;
        END
        ELSE
        BEGIN
        SET @Name = @NewValues.value('string((/Record/PromotionName)[1])','NVARCHAR(200)');
        SET @Raw = LTRIM(RTRIM(@NewValues.value('string((/Record/DiscountPerc)[1])','NVARCHAR(100)')));
        SET @Status = @NewValues.value('string((/Record/Status)[1])','NVARCHAR(10)');
        SET @StartDateText = LTRIM(RTRIM(@NewValues.value('string((/Record/StartDate)[1])','NVARCHAR(30)')));
        SET @EndDateText = LTRIM(RTRIM(@NewValues.value('string((/Record/EndDate)[1])','NVARCHAR(30)')));
        IF NULLIF(@Raw,N'') IS NULL OR @Raw LIKE N'%[^0-9.]%' OR @Raw LIKE N'%.%.%' OR @Raw NOT LIKE N'%[0-9]%'
            OR NULLIF(LTRIM(RTRIM(@Name)),N'') IS NULL OR @Status NOT IN ('A','I')
            OR (@StartDateText <> N'' AND (LEN(@StartDateText) <> 10 OR SUBSTRING(@StartDateText,5,1) <> N'-'
                OR SUBSTRING(@StartDateText,8,1) <> N'-' OR REPLACE(@StartDateText,N'-',N'') LIKE N'%[^0-9]%'))
            OR (@EndDateText <> N'' AND (LEN(@EndDateText) <> 10 OR SUBSTRING(@EndDateText,5,1) <> N'-'
                OR SUBSTRING(@EndDateText,8,1) <> N'-' OR REPLACE(@EndDateText,N'-',N'') LIKE N'%[^0-9]%'))
            THROW 51708, 'Promotion name, discount, dates, or status are invalid.', 1;
        SET @Number = CAST(@Raw AS DECIMAL(20,4));
        IF @Number < 0 OR @Number > 100
            THROW 51708, 'Promotion discount must be between 0 and 100.', 1;
        IF @StartDateText <> N'' SET @StartDate = CONVERT(DATETIME,REPLACE(@StartDateText,N'-',N''),112);
        IF @EndDateText <> N'' SET @EndDate = CONVERT(DATETIME,REPLACE(@EndDateText,N'-',N''),112);
        IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate > @EndDate
            THROW 51708, 'Promotion end date must be on or after the start date.', 1;

        SET @Operation = CASE WHEN ISNULL(@TargetSRNO,0) > 0 THEN 'U' ELSE 'I' END;
        SET @MasterKey = CASE WHEN @Operation = 'U' THEN N'P|' + CONVERT(NVARCHAR(20),@TargetSRNO)
            ELSE N'P|N|' + @Name END;
        IF @Operation = 'U'
        BEGIN
            SELECT @OldValues = (SELECT SRNO, PromotionName, DiscountPerc, StartDate, EndDate,
                Createdby_user, Createdon_date, UpdatedBy_user, Updatedon_Date, Status
                FROM dbo.Lead_Promotion_master WHERE SRNO = @TargetSRNO
                FOR XML PATH('Record'), ELEMENTS XSINIL, TYPE);
            IF @OldValues IS NULL THROW 51709, 'The promotion row no longer exists.', 1;
        END;
        ELSE IF EXISTS (SELECT 1 FROM dbo.Lead_Promotion_master WHERE PromotionName = @Name)
            THROW 51710, 'A promotion with this name already exists.', 1;
        END
    END
    ELSE IF @MasterType = 'C'
    BEGIN
        DECLARE @ConfigPromotionName NVARCHAR(200), @IsEnabledText NVARCHAR(10), @CurrentEnabled BIT;
        SET @ConfigPromotionName = LTRIM(RTRIM(@NewValues.value('string((/Record/PromotionName)[1])','NVARCHAR(200)')));
        SET @IsEnabledText = LTRIM(RTRIM(@NewValues.value('string((/Record/IsEnabled)[1])','NVARCHAR(10)')));
        IF NULLIF(@ConfigPromotionName,N'') IS NULL OR @IsEnabledText NOT IN ('0','1')
            OR ISNULL(@OldProductType,N'')<>@ConfigPromotionName
            THROW 51722, 'Promotion configuration values are invalid.', 1;
        IF NOT EXISTS
            (SELECT 1 FROM dbo.FRM_gnarr
             WHERE UPPER(LTRIM(RTRIM(Code)))=N'LEAD_PROMOTION'
               AND REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),
                   NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@ConfigPromotionName)
            AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
                WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionName)),NCHAR(8209),N'-'),
                    NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@ConfigPromotionName)
            THROW 51723, 'The selected promotion is no longer available.', 1;

        SET @Operation='U';
        SET @MasterKey=N'C|' + @ConfigPromotionName;
        SELECT TOP (1) @CurrentEnabled=IsEnabled
        FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
        WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionName)),NCHAR(8209),N'-'),
            NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@ConfigPromotionName
        ORDER BY UpdatedOn DESC,PromotionName;
        IF @CurrentEnabled IS NULL
            SELECT TOP (1) @CurrentEnabled=CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(Status,N''))))=N'A'
                THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END
            FROM dbo.FRM_gnarr
            WHERE UPPER(LTRIM(RTRIM(Code)))=N'LEAD_PROMOTION'
              AND REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),
                  NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@ConfigPromotionName;
        SET @CurrentEnabled=ISNULL(@CurrentEnabled,1);
        SELECT @OldValues =
            (SELECT @ConfigPromotionName AS PromotionName, @CurrentEnabled AS IsEnabled
             FOR XML PATH('Record'), ELEMENTS XSINIL, TYPE);
    END
    ELSE
    BEGIN
        DECLARE @ProductType NVARCHAR(300), @ProductSubType NVARCHAR(300),
            @ResidencyType NVARCHAR(200), @Staff NVARCHAR(200), @FeeStatus NVARCHAR(10);
        SET @ProductType = @NewValues.value('string((/Record/PRODUCT_TYPE)[1])','NVARCHAR(300)');
        SET @ProductSubType = @NewValues.value('string((/Record/Product_SubTYPE)[1])','NVARCHAR(300)');
        SET @ResidencyType = @NewValues.value('string((/Record/Residency_Type)[1])','NVARCHAR(200)');
        SET @Staff = @NewValues.value('string((/Record/Staff)[1])','NVARCHAR(200)');
        SET @FeeStatus = @NewValues.value('string((/Record/Status)[1])','NVARCHAR(10)');
        IF NULLIF(LTRIM(RTRIM(@ProductType)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@ProductSubType)),N'') IS NULL
            OR NULLIF(LTRIM(RTRIM(@ResidencyType)),N'') IS NULL OR @Staff NOT IN ('Yes','No') OR @FeeStatus NOT IN ('A','I')
            THROW 51711, 'Product type, subtype, residency, staff, and status are required.', 1;

        DECLARE @FeeNames TABLE (FieldName SYSNAME NOT NULL);
        INSERT @FeeNames VALUES ('FEE_FV'),('FEE_OPV'),('FEE_APV'),('FEE_Buyout'),('FEE_Topup'),
            ('FEE_Equity'),('FEE_Cashout'),('FEE_MBRE'),('FEE_APP'),('FEE_ACC'),('MIN_FEE'),('MAX_FEE');
        DECLARE @Field SYSNAME, @FieldText NVARCHAR(100), @FieldSql NVARCHAR(MAX);
        DECLARE FeeValidation CURSOR LOCAL FAST_FORWARD FOR SELECT FieldName FROM @FeeNames;
        OPEN FeeValidation;
        FETCH NEXT FROM FeeValidation INTO @Field;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @FieldSql = N'SELECT @Text = @Xml.value(''string((/Record/' + @Field + N')[1])'',''NVARCHAR(100)'')';
            EXEC sys.sp_executesql @FieldSql, N'@Xml XML, @Text NVARCHAR(100) OUTPUT', @NewValues, @FieldText OUTPUT;
            SET @FieldText = LTRIM(RTRIM(@FieldText));
            IF NULLIF(@FieldText,N'') IS NULL OR @FieldText LIKE N'%[^0-9.]%'
                OR @FieldText LIKE N'%.%.%' OR @FieldText NOT LIKE N'%[0-9]%'
            BEGIN
                CLOSE FeeValidation; DEALLOCATE FeeValidation;
                THROW 51712, 'All fee and amount fields must contain valid numeric values.', 1;
            END;
            FETCH NEXT FROM FeeValidation INTO @Field;
        END;
        CLOSE FeeValidation; DEALLOCATE FeeValidation;
        IF @NewValues.value('string((/Record/Is_VAT_Applicable)[1])','NVARCHAR(10)') NOT IN ('0','1')
            THROW 51713, 'VAT applicability must be Yes or No.', 1;

        SET @Operation = CASE WHEN NULLIF(@OldProductType,N'') IS NULL THEN 'I' ELSE 'U' END;
        SET @MasterKey = CASE WHEN @Operation = 'U'
            THEN N'F|' + ISNULL(@OldProductType,N'') + N'|' + ISNULL(@OldProductSubType,N'') + N'|'
                + ISNULL(@OldResidencyType,N'') + N'|' + ISNULL(@OldStaff,N'')
            ELSE N'F|N|' + @ProductType + N'|' + @ProductSubType + N'|' + @ResidencyType + N'|' + @Staff END;
        IF @Operation = 'U'
        BEGIN
            SELECT @OldValues = (SELECT PRODUCT_TYPE, Product_SubTYPE, Residency_Type, Staff,
                FEE_FV, FEE_OPV, FEE_APV, FEE_Buyout, FEE_Topup, FEE_Equity, FEE_Cashout,
                FEE_MBRE, FEE_APP, FEE_ACC, MIN_FEE, MAX_FEE, Status, CreatedBy_User,
                Createdon_Date, Updatedby_User, Updatedon_Date, Is_VAT_Applicable
                FROM dbo.LEAD_ARR_FEE_MASTER
                WHERE PRODUCT_TYPE=@OldProductType AND Product_SubTYPE=@OldProductSubType
                  AND Residency_Type=@OldResidencyType AND Staff=@OldStaff
                FOR XML PATH('Record'), ELEMENTS XSINIL, TYPE);
            IF @OldValues IS NULL THROW 51714, 'The arrangement fee row no longer exists.', 1;
        END;
        ELSE IF EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_MASTER WHERE PRODUCT_TYPE=@ProductType
            AND Product_SubTYPE=@ProductSubType AND Residency_Type=@ResidencyType AND Staff=@Staff)
            THROW 51715, 'An arrangement fee row with these key fields already exists.', 1;
    END;

    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM dbo.Lead_Fee_Master_Request WITH (UPDLOCK,HOLDLOCK)
        WHERE MasterType=@MasterType AND MasterKey=@MasterKey AND StatusCode='P')
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51716, 'A pending request already exists for this master row.', 1;
    END;
    INSERT dbo.Lead_Fee_Master_Request
        (MasterType,Operation,MasterKey,TargetSRNO,OldProductType,OldProductSubType,
         OldResidencyType,OldStaff,OldValues,NewValues,MakerLoginId,MakerRemarks,
         AttachmentName,AttachmentType,AttachmentData)
    VALUES
        (@MasterType,@Operation,@MasterKey,@TargetSRNO,@OldProductType,@OldProductSubType,
         @OldResidencyType,@OldStaff,@OldValues,@NewValues,@MakerLoginId,@MakerRemarks,
         @AttachmentName,@AttachmentType,@AttachmentData);
    SET @RequestId = SCOPE_IDENTITY();
    INSERT dbo.Lead_Fee_Master_Audit(RequestId,ActionName,ActionBy,OldValues,NewValues,Remarks)
        VALUES(@RequestId,'SUBMITTED',@MakerLoginId,@OldValues,@NewValues,@MakerRemarks);
    COMMIT TRANSACTION;
END;
GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_Check', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_Check;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_Check
    @RequestId BIGINT, @CheckerLoginId NVARCHAR(100), @Decision CHAR(1), @Remarks NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Decision NOT IN ('A','R') OR NULLIF(LTRIM(RTRIM(@CheckerLoginId)),N'') IS NULL
        OR NULLIF(LTRIM(RTRIM(@Remarks)),N'') IS NULL
        THROW 51717, 'A valid checker decision, checker ID, and remarks are required.', 1;

    DECLARE @MasterType CHAR(1), @Operation CHAR(1), @TargetSRNO INT, @OldProductType NVARCHAR(300),
        @OldProductSubType NVARCHAR(300), @OldResidencyType NVARCHAR(200), @OldStaff NVARCHAR(200),
        @MakerLoginId NVARCHAR(100), @StatusCode CHAR(1), @OldValues XML, @NewValues XML;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @MasterType=MasterType,@Operation=Operation,@TargetSRNO=TargetSRNO,
            @OldProductType=OldProductType,@OldProductSubType=OldProductSubType,
            @OldResidencyType=OldResidencyType,@OldStaff=OldStaff,@MakerLoginId=MakerLoginId,
            @StatusCode=StatusCode,@OldValues=OldValues,@NewValues=NewValues
        FROM dbo.Lead_Fee_Master_Request WITH (UPDLOCK,HOLDLOCK) WHERE RequestId=@RequestId;
        IF @StatusCode IS NULL OR @StatusCode <> 'P' THROW 51718, 'The request is missing or is no longer pending.', 1;
        IF @MakerLoginId = @CheckerLoginId THROW 51719, 'The maker cannot approve or reject their own request.', 1;

        IF @Decision = 'A' AND @MasterType = 'P'
        BEGIN
            IF @NewValues.exist('/Record/PromotionKey[1]')=1
            BEGIN
                DECLARE @PackagePromotionKey NVARCHAR(200),@PackagePromotionName NVARCHAR(200),
                    @PackageDiscountText NVARCHAR(100),@PackageDiscount DECIMAL(20,4),
                    @PackageMasterStatus NVARCHAR(10),@PackageEnabledText NVARCHAR(10),
                    @PackageUseMasterText NVARCHAR(10),@PackageSkipMinText NVARCHAR(10),
                    @PackageSkipMaxText NVARCHAR(10),@PackageStartText NVARCHAR(30),
                    @PackageEndText NVARCHAR(30),@PackageLookupProductType NVARCHAR(300),
                    @PackageLookupProductSubType NVARCHAR(300),@PackageCurrentSRNO INT,
                    @PackageExpectedName NVARCHAR(200),@PackageCanonicalName NVARCHAR(200),
                    @PackageEnabled BIT,@PackageUseMaster BIT,
                    @PackageSkipMin BIT,@PackageSkipMax BIT,@PackageConfigExists BIT,
                    @PackageExpectedOperation CHAR(1),@PackageNewSRNO INT,
                    @PackageStartDate DATETIME,@PackageEndDate DATETIME;
                SET @PackagePromotionKey=LTRIM(RTRIM(@NewValues.value('string((/Record/PromotionKey)[1])','NVARCHAR(200)')));
                SET @PackagePromotionName=LTRIM(RTRIM(@NewValues.value('string((/Record/PromotionName)[1])','NVARCHAR(200)')));
                SET @PackageDiscountText=LTRIM(RTRIM(@NewValues.value('string((/Record/DiscountPerc)[1])','NVARCHAR(100)')));
                SET @PackageMasterStatus=LTRIM(RTRIM(@NewValues.value('string((/Record/MasterStatus)[1])','NVARCHAR(10)')));
                SET @PackageEnabledText=LTRIM(RTRIM(@NewValues.value('string((/Record/IsEnabled)[1])','NVARCHAR(10)')));
                SET @PackageUseMasterText=LTRIM(RTRIM(@NewValues.value('string((/Record/UseMasterDiscount)[1])','NVARCHAR(10)')));
                SET @PackageSkipMinText=LTRIM(RTRIM(@NewValues.value('string((/Record/SkipMinFee)[1])','NVARCHAR(10)')));
                SET @PackageSkipMaxText=LTRIM(RTRIM(@NewValues.value('string((/Record/SkipMaxFee)[1])','NVARCHAR(10)')));
                SET @PackageStartText=LTRIM(RTRIM(@NewValues.value('string((/Record/StartDate)[1])','NVARCHAR(30)')));
                SET @PackageEndText=LTRIM(RTRIM(@NewValues.value('string((/Record/EndDate)[1])','NVARCHAR(30)')));
                SET @PackageLookupProductType=NULLIF(LTRIM(RTRIM(@NewValues.value('string((/Record/LookupProductType)[1])','NVARCHAR(300)'))),N'');
                SET @PackageLookupProductSubType=NULLIF(LTRIM(RTRIM(@NewValues.value('string((/Record/LookupProductSubType)[1])','NVARCHAR(300)'))),N'');

                IF NULLIF(@PackagePromotionKey,N'') IS NULL OR NULLIF(@PackagePromotionName,N'') IS NULL
                    OR @PackageMasterStatus NOT IN ('A','I') OR @PackageEnabledText NOT IN ('0','1')
                    OR @PackageUseMasterText NOT IN ('0','1') OR @PackageSkipMinText NOT IN ('0','1')
                    OR @PackageSkipMaxText NOT IN ('0','1')
                    OR (@PackageLookupProductType IS NULL AND @PackageLookupProductSubType IS NOT NULL)
                    OR (@PackageLookupProductType IS NOT NULL AND @PackageLookupProductSubType IS NULL)
                    THROW 51708, 'Promotion package values are invalid.', 1;
                SET @PackageEnabled=CONVERT(BIT,@PackageEnabledText);
                SET @PackageUseMaster=CONVERT(BIT,@PackageUseMasterText);
                SET @PackageSkipMin=CONVERT(BIT,@PackageSkipMinText);
                SET @PackageSkipMax=CONVERT(BIT,@PackageSkipMaxText);

                SELECT @PackageCurrentSRNO=SRNO,@PackageExpectedName=PromotionName,
                    @PackageCanonicalName=SourcePromotionValue
                FROM dbo.vw_LeadFeePromotionMaster
                WHERE PromotionKey=@PackagePromotionKey;
                IF @PackageExpectedName IS NULL OR @PackagePromotionName<>@PackageExpectedName
                    THROW 51723, 'The selected promotion is no longer available.', 1;
                IF ISNULL(@TargetSRNO,0)<>ISNULL(@PackageCurrentSRNO,0)
                    THROW 51709, 'The promotion package changed after it was submitted. Reject and resubmit.', 1;

                SET @PackageConfigExists=CASE WHEN EXISTS
                (
                    SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG WITH (UPDLOCK,HOLDLOCK)
                    WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionName)),NCHAR(8209),N'-'),
                        NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@PackagePromotionKey
                ) THEN 1 ELSE 0 END;
                SET @PackageExpectedOperation=CASE WHEN ISNULL(@PackageCurrentSRNO,0)>0 OR @PackageConfigExists=1
                    THEN 'U' ELSE 'I' END;
                IF @Operation<>@PackageExpectedOperation
                    THROW 51709, 'The promotion package changed after it was submitted. Reject and resubmit.', 1;

                IF NULLIF(@PackageDiscountText,N'') IS NULL
                BEGIN
                    IF @PackageUseMaster=1 OR ISNULL(@PackageCurrentSRNO,0)>0
                        THROW 51708, 'A master discount is required for this promotion.', 1;
                    SET @PackageDiscount=NULL;
                END
                ELSE
                BEGIN
                    IF @PackageDiscountText LIKE N'%[^0-9.]%' OR @PackageDiscountText LIKE N'%.%.%'
                        OR @PackageDiscountText NOT LIKE N'%[0-9]%'
                        THROW 51708, 'Promotion discount must be numeric.', 1;
                    SET @PackageDiscount=CAST(@PackageDiscountText AS DECIMAL(20,4));
                    IF @PackageDiscount<0 OR @PackageDiscount>100
                        THROW 51708, 'Promotion discount must be between 0 and 100.', 1;
                END;
                IF (@PackageStartText<>N'' AND (LEN(@PackageStartText)<>10 OR SUBSTRING(@PackageStartText,5,1)<>N'-'
                        OR SUBSTRING(@PackageStartText,8,1)<>N'-' OR REPLACE(@PackageStartText,N'-',N'') LIKE N'%[^0-9]%'))
                    OR (@PackageEndText<>N'' AND (LEN(@PackageEndText)<>10 OR SUBSTRING(@PackageEndText,5,1)<>N'-'
                        OR SUBSTRING(@PackageEndText,8,1)<>N'-' OR REPLACE(@PackageEndText,N'-',N'') LIKE N'%[^0-9]%'))
                    THROW 51708, 'Promotion dates are invalid.', 1;
                IF @PackageDiscount IS NULL AND
                    (@PackageStartText<>N'' OR @PackageEndText<>N'' OR @PackageMasterStatus<>'A')
                    THROW 51708, 'Master dates and status require a master discount.', 1;
                IF @PackageStartText<>N'' SET @PackageStartDate=CONVERT(DATETIME,REPLACE(@PackageStartText,N'-',N''),112);
                IF @PackageEndText<>N'' SET @PackageEndDate=CONVERT(DATETIME,REPLACE(@PackageEndText,N'-',N''),112);
                IF @PackageStartDate IS NOT NULL AND @PackageEndDate IS NOT NULL
                    AND @PackageStartDate>@PackageEndDate
                    THROW 51708, 'Promotion end date must be on or after the start date.', 1;

                IF ISNULL(@PackageCurrentSRNO,0)>0
                BEGIN
                    UPDATE dbo.Lead_Promotion_master
                    SET PromotionName=@PackageCanonicalName,DiscountPerc=@PackageDiscount,
                        StartDate=@PackageStartDate,EndDate=@PackageEndDate,Status=@PackageMasterStatus,
                        UpdatedBy_user=@CheckerLoginId,Updatedon_Date=GETDATE()
                    WHERE SRNO=@PackageCurrentSRNO;
                    IF @@ROWCOUNT=0 THROW 51709, 'The promotion master row no longer exists.', 1;
                END
                ELSE IF @PackageDiscount IS NOT NULL
                BEGIN
                    SELECT @PackageNewSRNO=ISNULL(MAX(SRNO),0)+1
                    FROM dbo.Lead_Promotion_master WITH (UPDLOCK,HOLDLOCK);
                    INSERT dbo.Lead_Promotion_master
                        (SRNO,PromotionName,DiscountPerc,StartDate,EndDate,Createdby_user,Createdon_date,Status)
                    VALUES(@PackageNewSRNO,@PackageCanonicalName,@PackageDiscount,@PackageStartDate,
                        @PackageEndDate,@MakerLoginId,GETDATE(),@PackageMasterStatus);
                END;

                IF @PackageConfigExists=1
                    UPDATE dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
                    SET IsEnabled=@PackageEnabled,UseMasterDiscount=@PackageUseMaster,
                        SkipMinFee=@PackageSkipMin,SkipMaxFee=@PackageSkipMax,
                        LookupProductType=@PackageLookupProductType,
                        LookupProductSubType=@PackageLookupProductSubType,
                        UpdatedBy=@CheckerLoginId,UpdatedOn=SYSDATETIME()
                    WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionName)),NCHAR(8209),N'-'),
                        NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@PackagePromotionKey;
                ELSE
                    INSERT dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
                        (PromotionName,IsEnabled,UseMasterDiscount,SkipMinFee,SkipMaxFee,
                         LookupProductType,LookupProductSubType,UpdatedBy,UpdatedOn)
                    VALUES(@PackageCanonicalName,@PackageEnabled,@PackageUseMaster,@PackageSkipMin,
                        @PackageSkipMax,@PackageLookupProductType,@PackageLookupProductSubType,
                        @CheckerLoginId,SYSDATETIME());
            END
            ELSE
            BEGIN
            DECLARE @PromotionName NVARCHAR(200), @DiscountPerc DECIMAL(20,4), @PromotionStatus NVARCHAR(10),
                @NewPromotionSRNO INT,
                @StartDate DATETIME, @EndDate DATETIME, @DiscountText NVARCHAR(100),
                @StartDateText NVARCHAR(30), @EndDateText NVARCHAR(30);
            SET @PromotionName=@NewValues.value('string((/Record/PromotionName)[1])','NVARCHAR(200)');
            SET @DiscountText=LTRIM(RTRIM(@NewValues.value('string((/Record/DiscountPerc)[1])','NVARCHAR(100)')));
            SET @PromotionStatus=@NewValues.value('string((/Record/Status)[1])','NVARCHAR(10)');
            SET @StartDateText=LTRIM(RTRIM(@NewValues.value('string((/Record/StartDate)[1])','NVARCHAR(30)')));
            SET @EndDateText=LTRIM(RTRIM(@NewValues.value('string((/Record/EndDate)[1])','NVARCHAR(30)')));
            IF NULLIF(@DiscountText,N'') IS NULL OR @DiscountText LIKE N'%[^0-9.]%'
                OR @DiscountText LIKE N'%.%.%' OR @DiscountText NOT LIKE N'%[0-9]%'
                OR (@StartDateText <> N'' AND (LEN(@StartDateText) <> 10 OR SUBSTRING(@StartDateText,5,1) <> N'-'
                    OR SUBSTRING(@StartDateText,8,1) <> N'-' OR REPLACE(@StartDateText,N'-',N'') LIKE N'%[^0-9]%'))
                OR (@EndDateText <> N'' AND (LEN(@EndDateText) <> 10 OR SUBSTRING(@EndDateText,5,1) <> N'-'
                    OR SUBSTRING(@EndDateText,8,1) <> N'-' OR REPLACE(@EndDateText,N'-',N'') LIKE N'%[^0-9]%'))
                THROW 51708, 'Promotion values are invalid.', 1;
            SET @DiscountPerc=CAST(@DiscountText AS DECIMAL(20,4));
            IF @DiscountPerc < 0 OR @DiscountPerc > 100
                THROW 51708, 'Promotion discount must be between 0 and 100.', 1;
            IF @StartDateText <> N'' SET @StartDate=CONVERT(DATETIME,REPLACE(@StartDateText,N'-',N''),112);
            IF @EndDateText <> N'' SET @EndDate=CONVERT(DATETIME,REPLACE(@EndDateText,N'-',N''),112);
            IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL AND @StartDate > @EndDate
                THROW 51708, 'Promotion end date must be on or after the start date.', 1;
            IF @Operation='I'
            BEGIN
                IF EXISTS(SELECT 1 FROM dbo.Lead_Promotion_master WITH (UPDLOCK,HOLDLOCK) WHERE PromotionName=@PromotionName)
                    THROW 51710, 'A promotion with this name already exists.', 1;
                SELECT @NewPromotionSRNO = ISNULL(MAX(SRNO),0) + 1
                FROM dbo.Lead_Promotion_master WITH (UPDLOCK,HOLDLOCK);
                INSERT dbo.Lead_Promotion_master(SRNO,PromotionName,DiscountPerc,StartDate,EndDate,Createdby_user,Createdon_date,Status)
                    VALUES(@NewPromotionSRNO,@PromotionName,@DiscountPerc,@StartDate,@EndDate,@MakerLoginId,GETDATE(),@PromotionStatus);
            END
            ELSE
            BEGIN
                IF EXISTS(SELECT 1 FROM dbo.Lead_Promotion_master WITH (UPDLOCK,HOLDLOCK)
                    WHERE PromotionName=@PromotionName AND SRNO<>@TargetSRNO)
                    THROW 51710, 'A promotion with this name already exists.', 1;
                UPDATE dbo.Lead_Promotion_master SET PromotionName=@PromotionName,DiscountPerc=@DiscountPerc,
                    StartDate=@StartDate,EndDate=@EndDate,Status=@PromotionStatus,
                    UpdatedBy_user=@MakerLoginId,Updatedon_Date=GETDATE()
                WHERE SRNO=@TargetSRNO;
                IF @@ROWCOUNT=0 THROW 51709, 'The promotion row no longer exists.', 1;
            END;
            END
        END;
        ELSE IF @Decision = 'A' AND @MasterType = 'F'
        BEGIN
            DECLARE @PType NVARCHAR(300), @PSubType NVARCHAR(300), @Residency NVARCHAR(200), @StaffValue NVARCHAR(200),
                @FStatus NVARCHAR(10), @FV DECIMAL(20,4), @FOPV DECIMAL(20,4), @FAPV DECIMAL(20,4),
                @FBuyout DECIMAL(20,4), @FTopup DECIMAL(20,4), @FEquity DECIMAL(20,4),
                @FCashout DECIMAL(20,4), @FMBRE DECIMAL(20,4), @FApp DECIMAL(20,2), @FAcc DECIMAL(20,2),
                @MinFee DECIMAL(20,2), @MaxFee DECIMAL(20,2), @Vat BIT;
            SET @PType=@NewValues.value('string((/Record/PRODUCT_TYPE)[1])','NVARCHAR(300)');
            SET @PSubType=@NewValues.value('string((/Record/Product_SubTYPE)[1])','NVARCHAR(300)');
            SET @Residency=@NewValues.value('string((/Record/Residency_Type)[1])','NVARCHAR(200)');
            SET @StaffValue=@NewValues.value('string((/Record/Staff)[1])','NVARCHAR(200)');
            SET @FStatus=@NewValues.value('string((/Record/Status)[1])','NVARCHAR(10)');
            SET @FV=CAST(@NewValues.value('string((/Record/FEE_FV)[1])','NVARCHAR(100)') AS DECIMAL(20,4));
            SET @FOPV=CAST(@NewValues.value('string((/Record/FEE_OPV)[1])','NVARCHAR(100)') AS DECIMAL(20,4));
            SET @FAPV=CAST(@NewValues.value('string((/Record/FEE_APV)[1])','NVARCHAR(100)') AS DECIMAL(20,4));
            SET @FBuyout=CAST(@NewValues.value('string((/Record/FEE_Buyout)[1])','NVARCHAR(100)') AS DECIMAL(20,4));
            SET @FTopup=CAST(@NewValues.value('string((/Record/FEE_Topup)[1])','NVARCHAR(100)') AS DECIMAL(20,4));
            SET @FEquity=CAST(@NewValues.value('string((/Record/FEE_Equity)[1])','NVARCHAR(100)') AS DECIMAL(20,4));
            SET @FCashout=CAST(@NewValues.value('string((/Record/FEE_Cashout)[1])','NVARCHAR(100)') AS DECIMAL(20,4));
            SET @FMBRE=CAST(@NewValues.value('string((/Record/FEE_MBRE)[1])','NVARCHAR(100)') AS DECIMAL(20,4));
            SET @FApp=CAST(@NewValues.value('string((/Record/FEE_APP)[1])','NVARCHAR(100)') AS DECIMAL(20,2));
            SET @FAcc=CAST(@NewValues.value('string((/Record/FEE_ACC)[1])','NVARCHAR(100)') AS DECIMAL(20,2));
            SET @MinFee=CAST(@NewValues.value('string((/Record/MIN_FEE)[1])','NVARCHAR(100)') AS DECIMAL(20,2));
            SET @MaxFee=CAST(@NewValues.value('string((/Record/MAX_FEE)[1])','NVARCHAR(100)') AS DECIMAL(20,2));
            SET @Vat=CAST(@NewValues.value('string((/Record/Is_VAT_Applicable)[1])','NVARCHAR(10)') AS BIT);
            IF @Operation='I'
            BEGIN
                IF EXISTS(SELECT 1 FROM dbo.LEAD_ARR_FEE_MASTER WITH (UPDLOCK,HOLDLOCK) WHERE PRODUCT_TYPE=@PType
                    AND Product_SubTYPE=@PSubType AND Residency_Type=@Residency AND Staff=@StaffValue)
                    THROW 51715, 'An arrangement fee row with these key fields already exists.', 1;
                INSERT dbo.LEAD_ARR_FEE_MASTER
                    (PRODUCT_TYPE,Product_SubTYPE,Residency_Type,Staff,FEE_FV,FEE_OPV,FEE_APV,FEE_Buyout,
                     FEE_Topup,FEE_Equity,FEE_Cashout,FEE_MBRE,FEE_APP,FEE_ACC,MIN_FEE,MAX_FEE,Status,
                     CreatedBy_User,Createdon_Date,Is_VAT_Applicable)
                VALUES(@PType,@PSubType,@Residency,@StaffValue,@FV,@FOPV,@FAPV,@FBuyout,
                    @FTopup,@FEquity,@FCashout,@FMBRE,@FApp,@FAcc,@MinFee,@MaxFee,@FStatus,
                    @MakerLoginId,GETDATE(),@Vat);
            END
            ELSE
            BEGIN
                IF EXISTS(SELECT 1 FROM dbo.LEAD_ARR_FEE_MASTER WITH (UPDLOCK,HOLDLOCK)
                    WHERE PRODUCT_TYPE=@PType AND Product_SubTYPE=@PSubType AND Residency_Type=@Residency
                        AND Staff=@StaffValue
                        AND NOT (PRODUCT_TYPE=@OldProductType AND Product_SubTYPE=@OldProductSubType
                            AND Residency_Type=@OldResidencyType AND Staff=@OldStaff))
                    THROW 51715, 'An arrangement fee row with these key fields already exists.', 1;
                UPDATE dbo.LEAD_ARR_FEE_MASTER SET PRODUCT_TYPE=@PType,Product_SubTYPE=@PSubType,
                    Residency_Type=@Residency,Staff=@StaffValue,FEE_FV=@FV,FEE_OPV=@FOPV,FEE_APV=@FAPV,
                    FEE_Buyout=@FBuyout,FEE_Topup=@FTopup,FEE_Equity=@FEquity,FEE_Cashout=@FCashout,
                    FEE_MBRE=@FMBRE,FEE_APP=@FApp,FEE_ACC=@FAcc,MIN_FEE=@MinFee,MAX_FEE=@MaxFee,
                    Status=@FStatus,Updatedby_User=@MakerLoginId,Updatedon_Date=GETDATE(),Is_VAT_Applicable=@Vat
                WHERE PRODUCT_TYPE=@OldProductType AND Product_SubTYPE=@OldProductSubType
                    AND Residency_Type=@OldResidencyType AND Staff=@OldStaff;
                IF @@ROWCOUNT=0 THROW 51714, 'The arrangement fee row no longer exists.', 1;
            END;
        END;

        ELSE IF @Decision = 'A' AND @MasterType = 'C'
        BEGIN
            DECLARE @ConfigName NVARCHAR(200), @ConfigEnabledText NVARCHAR(10), @ConfigEnabled BIT;
            SET @ConfigName=LTRIM(RTRIM(@NewValues.value('string((/Record/PromotionName)[1])','NVARCHAR(200)')));
            SET @ConfigEnabledText=LTRIM(RTRIM(@NewValues.value('string((/Record/IsEnabled)[1])','NVARCHAR(10)')));
            IF NULLIF(@ConfigName,N'') IS NULL OR @ConfigEnabledText NOT IN ('0','1')
                OR @ConfigName<>ISNULL(@OldProductType,N'') OR @Operation<>'U'
                THROW 51722, 'Promotion configuration values are invalid.', 1;
            IF NOT EXISTS
                (SELECT 1 FROM dbo.FRM_gnarr
                 WHERE UPPER(LTRIM(RTRIM(Code)))=N'LEAD_PROMOTION'
                   AND REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),
                       NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@ConfigName)
                AND NOT EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
                    WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionName)),NCHAR(8209),N'-'),
                        NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@ConfigName)
                THROW 51723, 'The selected promotion is no longer available.', 1;
            SET @ConfigEnabled=CONVERT(BIT,@ConfigEnabledText);

            IF EXISTS (SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_CONFIG WITH (UPDLOCK,HOLDLOCK)
                WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionName)),NCHAR(8209),N'-'),
                    NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@ConfigName)
                UPDATE dbo.LEAD_ARR_FEE_PROMOTION_CONFIG
                SET IsEnabled=@ConfigEnabled, UpdatedBy=@CheckerLoginId, UpdatedOn=SYSDATETIME()
                WHERE REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionName)),NCHAR(8209),N'-'),
                    NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@ConfigName;
            ELSE
                INSERT dbo.LEAD_ARR_FEE_PROMOTION_CONFIG(PromotionName,IsEnabled,UpdatedBy,UpdatedOn)
                VALUES(@ConfigName,@ConfigEnabled,@CheckerLoginId,SYSDATETIME());
        END;

        UPDATE dbo.Lead_Fee_Master_Request SET StatusCode=@Decision,CheckerLoginId=@CheckerLoginId,
            CheckerRemarks=@Remarks,CheckedOn=SYSDATETIME() WHERE RequestId=@RequestId;
        INSERT dbo.Lead_Fee_Master_Audit(RequestId,ActionName,ActionBy,OldValues,NewValues,Remarks)
            VALUES(@RequestId,CASE WHEN @Decision='A' THEN 'APPROVED' ELSE 'REJECTED' END,
                @CheckerLoginId,@OldValues,@NewValues,@Remarks);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

IF OBJECT_ID(N'dbo.Proc_LeadFeeMaster_CheckBulk', N'P') IS NOT NULL DROP PROCEDURE dbo.Proc_LeadFeeMaster_CheckBulk;
GO
CREATE PROCEDURE dbo.Proc_LeadFeeMaster_CheckBulk
    @RequestIds XML, @CheckerLoginId NVARCHAR(100), @Decision CHAR(1), @Remarks NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @RequestIds IS NULL OR @RequestIds.exist('/Requests[1]/Request[1]') <> 1
        THROW 51720, 'Select at least one request for the bulk decision.', 1;

    DECLARE @Selected TABLE (RequestId BIGINT NOT NULL PRIMARY KEY);
    INSERT @Selected(RequestId)
        SELECT RequestNode.value('(text())[1]', 'BIGINT')
        FROM @RequestIds.nodes('/Requests/Request') AS RequestList(RequestNode);
    IF (SELECT COUNT(*) FROM @Selected) > 500
        THROW 51721, 'A bulk decision cannot contain more than 500 requests.', 1;

    DECLARE @RequestId BIGINT;
    DECLARE RequestCursor CURSOR LOCAL FAST_FORWARD FOR SELECT RequestId FROM @Selected ORDER BY RequestId;
    BEGIN TRY
        BEGIN TRANSACTION;
        OPEN RequestCursor;
        FETCH NEXT FROM RequestCursor INTO @RequestId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.Proc_LeadFeeMaster_Check @RequestId=@RequestId, @CheckerLoginId=@CheckerLoginId,
                @Decision=@Decision, @Remarks=@Remarks;
            FETCH NEXT FROM RequestCursor INTO @RequestId;
        END;
        CLOSE RequestCursor;
        DEALLOCATE RequestCursor;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'RequestCursor') >= 0 CLOSE RequestCursor;
        IF CURSOR_STATUS('local', 'RequestCursor') > -3 DEALLOCATE RequestCursor;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
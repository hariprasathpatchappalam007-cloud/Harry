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

IF OBJECT_ID(N'dbo.Lead_Fee_Master_Request', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Lead_Fee_Master_Request
    (
        RequestId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Lead_Fee_Master_Request PRIMARY KEY,
        MasterType CHAR(1) NOT NULL CONSTRAINT CK_Lead_Fee_Master_Request_Type CHECK (MasterType IN ('P','F')),
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
    @MasterType CHAR(1), @Search NVARCHAR(200) = NULL, @Status NVARCHAR(10) = NULL,
    @ResidencyType NVARCHAR(200) = NULL, @Staff NVARCHAR(200) = NULL,
    @FromDate DATE = NULL, @ToDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @MasterType = 'P'
    BEGIN
        SELECT SRNO, PromotionName, DiscountPerc, StartDate, EndDate, Createdby_user,
            Createdon_date, UpdatedBy_user, Updatedon_Date, Status
        FROM dbo.Lead_Promotion_master
        WHERE (NULLIF(@Search, N'') IS NULL OR PromotionName LIKE N'%' + @Search + N'%')
          AND (NULLIF(@Status, N'') IS NULL OR ISNULL(Status, N'') = @Status)
          AND (@FromDate IS NULL OR StartDate >= @FromDate)
          AND (@ToDate IS NULL OR StartDate < DATEADD(DAY, 1, @ToDate))
        ORDER BY PromotionName, SRNO;
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
          AND (NULLIF(@Status, N'') IS NULL OR ISNULL(Status, N'') = @Status)
          AND (NULLIF(@ResidencyType, N'') IS NULL OR Residency_Type = @ResidencyType)
          AND (NULLIF(@Staff, N'') IS NULL OR Staff = @Staff)
        ORDER BY PRODUCT_TYPE, Product_SubTYPE, Residency_Type, Staff;
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
    @ResidencyType NVARCHAR(200) = NULL, @Staff NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @MasterType = 'P'
        SELECT SRNO, PromotionName, DiscountPerc, StartDate, EndDate, Createdby_user,
            Createdon_date, UpdatedBy_user, Updatedon_Date, Status
        FROM dbo.Lead_Promotion_master WHERE SRNO = @SRNO;
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
        CASE MasterType WHEN 'P' THEN 'Promotion Master' ELSE 'Arrangement Fee Master' END AS MasterName
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
        CASE MasterType WHEN 'P' THEN 'Promotion Master' ELSE 'Arrangement Fee Master' END AS MasterName
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
    IF @MasterType NOT IN ('P','F') OR @NewValues IS NULL OR @NewValues.exist('/Record[1]') <> 1
        THROW 51703, 'The master type or proposed master data is invalid.', 1;
    IF NULLIF(LTRIM(RTRIM(@MakerLoginId)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@MakerRemarks)), N'') IS NULL
        THROW 51704, 'Maker ID and submission remarks are required.', 1;
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
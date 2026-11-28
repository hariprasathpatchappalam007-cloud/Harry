IF OBJECT_ID(N'dbo.PROC_Lead_Arrangement_FEE_RESTORED_REPLICA', N'P') IS NOT NULL
	DROP PROCEDURE dbo.PROC_Lead_Arrangement_FEE_RESTORED_REPLICA;
GO
CREATE PROCEDURE [dbo].[PROC_Lead_Arrangement_FEE_RESTORED_REPLICA]
@REFNO nvarchar(100)=null,
@Scenario nvarchar(200)=null
as
BEGIN
	set quoted_identifier off
	create table #List
	(
	Lead_No nvarchar(100), PRODUCT_TYPE nvarchar(150), Product_SubTYPE nvarchar(150), Residency_Type nvarchar(100), StaffYN nvarchar(100),
	promotiontype nvarchar(100), Scenario nvarchar(200), FEE_FV numeric(20,4), FEE_OPV numeric(20,4), FEE_APV numeric(20,4),
	FEE_Buyout numeric(20,4), FEE_Topup numeric(20,4), FEE_Equity numeric(20,4), FEE_Cashout numeric(20,4),
	FEE_MBRE numeric(20,4), AMT_FV numeric(20,4), AMT_OPV numeric(20,4), AMT_APV numeric(20,4),
	AMT_Buyout numeric(20,4), AMT_Topup numeric(20,4), AMT_Equity numeric(20,4), AMT_Cashout numeric(20,4),
	AMT_MBRE numeric(20,4), FEE_APP numeric(20,2), FEE_ACC numeric(20,2), MIN_FEE numeric(20,2),
	MAX_FEE numeric(20,2), ARRANGEMENT_FEE_APP numeric(20,2), ARRANGEMENT_FEE_ACC numeric(20,2),
	ARRANGEMENT_FEE_BEFORE_VAT numeric(20,2), VAT_PERCENTAGE numeric(20,5), VAT_AMOUNT numeric(20,2),
	IS_VAT_APPLICABLE bit, ARRANGEMENT_FEE numeric(20,2), RECCOUNT int,
	Remarks nvarchar(100), ErrorMsg nvarchar(200)
	)

	declare @found int
	declare @Source_Submission nvarchar(100)
	declare @Employment_Type nvarchar(100)
	declare @Relationship_with_bank nvarchar(100)
	declare @LeadConversionProduct nvarchar(300)
	declare @PRODUCT_TYPE nvarchar(100)
	declare @Product_SubTYPE nvarchar(100)
	declare @CUSTOMER_RES_TYPE nvarchar(100)
	declare @FEE_FV numeric(20,4)
	declare @FEE_OPV numeric(20,4)
	declare @FEE_APV numeric(20,4)
	declare @FEE_Buyout numeric(20,4)
	declare @FEE_Topup numeric(20,4)
	declare @FEE_Equity numeric(20,4)
	declare @FEE_Cashout numeric(20,4)
	declare @FEE_MBRE numeric(20,4)
	declare @FEE_APP numeric(20,2)
	declare @FEE_ACC numeric(20,2)
	declare @MIN_FEE numeric(20,2)
	declare @MAX_FEE numeric(20,2)

	declare @AMT_FV numeric(20,4)
	declare @AMT_OPV numeric(20,4)
	declare @AMT_APV numeric(20,4)
	declare @AMT_Buyout numeric(20,4)
	declare @AMT_Topup numeric(20,4)
	declare @AMT_Equity numeric(20,4)
	declare @AMT_Cashout numeric(20,4)
	declare @AMT_MBRE numeric(20,4)

	declare @CAL_AMT_FV numeric(20,4)
	declare @CAL_AMT_OPV numeric(20,4)
	declare @CAL_AMT_APV numeric(20,4)
	declare @CAL_AMT_Buyout numeric(20,4)
	declare @CAL_AMT_Topup numeric(20,4)
	declare @CAL_AMT_Equity numeric(20,4)
	declare @CAL_AMT_Cashout numeric(20,4)
	declare @CAL_AMT_MBRE numeric(20,4)
	declare @ARRANGEMENT_FEE_APP numeric(20,2)
	declare @ARRANGEMENT_FEE_ACC numeric(20,2)
	declare @ARRANGEMENT_FEE numeric(20,2)
	declare @ARRANGEMENT_FEE_BEFORE_VAT numeric(20,2)
	declare @VAT_Percentage numeric(20,5) = 0
	declare @VAT_AMOUNT numeric(20,2) = 0
	declare @promotiontype nvarchar(100)
	declare @PromotionKey nvarchar(200)
	declare @PromotionDisplayName nvarchar(1000)
	declare @PromotionDisplayKey nvarchar(1000)
	declare @SourcePromotionValue nvarchar(200)
	declare @Is_VAT_Applicable Bit
	declare @Actual_PRODUCT_TYPE nvarchar(100)
	declare @Actual_Product_SubTYPE nvarchar(100)
	declare @PromotionEnabled bit = 1
	declare @UseMasterDiscount bit = 1
	declare @SkipMinFee bit = 0
	declare @SkipMaxFee bit = 0
	declare @LookupProductType nvarchar(300)
	declare @LookupProductSubType nvarchar(300)
	declare @RelationshipFeeRate numeric(20,4)
	declare @ApplyMasterDiscount bit = 1
	declare @RuleId int
	declare @RuleType varchar(32)
	declare @RuleTargetField varchar(32)
	declare @RuleValue numeric(20,4)
	declare @RuleAmountBasis varchar(16)
	declare @RuleMinimumFee numeric(20,2)
	declare @RuleMaximumFee numeric(20,2)
	declare @RuleSplitMode varchar(20)
	declare @RuleFloorSplitMode varchar(20)
	declare @RuleVATApplicable bit
	declare @RuleAmount numeric(20,4)
	declare @PromotionRules table
	(
		RuleId int NOT NULL,
		RuleSequence int NOT NULL,
		RuleStage varchar(24) NOT NULL,
		RuleType varchar(32) NOT NULL,
		TargetField varchar(32) NULL,
		AmountBasis varchar(16) NULL,
		RuleValue numeric(20,4) NULL,
		MinimumFee numeric(20,2) NULL,
		MaximumFee numeric(20,2) NULL,
		SplitMode varchar(20) NULL,
		FloorSplitMode varchar(20) NULL,
		VATApplicable bit NULL
	)

	select
		@PRODUCT_TYPE = lead_product,
		@Product_SubTYPE = LEAD_FIN_REFINANCETYPE,
		@AMT_FV=isnull(finance_amount,0),
		@AMT_OPV = isnull(lead_prop_org_value,0),
		@AMT_APV = isnull(lead_prop_appr_value,0),
		@AMT_Buyout=isnull(lead_fin_buyout_repay_amt,0),
		@AMT_Topup=isnull(lead_fin_topup_amt,0),
		@AMT_Equity=isnull(lead_fin_Equity_amt,0),
		@AMT_Cashout=isnull(lead_fin_cashout_amt,0),
		@AMT_MBRE = isnull(MBRE_AMOUNT,0),
		@LeadConversionProduct = Lead_Conversion_Product,
		@promotiontype = lead_fin_promotiontype
	from lead_details_finance where lead_no = @REFNO

	SET @PromotionKey = LTRIM(RTRIM(ISNULL(@promotiontype,N'')));
	SET @PromotionKey = REPLACE(REPLACE(REPLACE(@PromotionKey,NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-');
	SET @PromotionKey = REPLACE(@PromotionKey,N' - ',N'-');

	select TOP (1) @SourcePromotionValue=LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),
		@PromotionDisplayName=COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(1000),DisplayValue))),N''),
			LTRIM(RTRIM(CONVERT(NVARCHAR(1000),[Value])))),
		@PromotionEnabled=CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(Status,N''))))=N'A'
			THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END
	from dbo.FRM_gnarr
	where UPPER(LTRIM(RTRIM(Code)))=N'LEAD_PROMOTION'
	  and (REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),
			NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@PromotionKey
		OR REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CONVERT(NVARCHAR(1000),DisplayValue))),
			NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@PromotionKey)
	order by CASE WHEN REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(CONVERT(NVARCHAR(200),[Value]))),
		NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@PromotionKey THEN 0 ELSE 1 END,
		[Value];

	IF @SourcePromotionValue IS NOT NULL
	BEGIN
		SET @PromotionKey = REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@SourcePromotionValue)),
			NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-');
		SET @PromotionDisplayKey = REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@PromotionDisplayName)),
			NCHAR(8209),N'-'),NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-');
	END
	ELSE
		SET @PromotionDisplayKey = @PromotionKey;

	select @PromotionEnabled=IsEnabled,@UseMasterDiscount=UseMasterDiscount,
		@SkipMinFee=SkipMinFee,@SkipMaxFee=SkipMaxFee,
		@LookupProductType=LookupProductType,@LookupProductSubType=LookupProductSubType
	from dbo.vw_LeadFeePromotionMaster
	where PromotionKey=@PromotionKey

	if @PromotionEnabled=1 AND @LookupProductType IS NOT NULL AND @LookupProductSubType IS NOT NULL
	begin
		SET @Actual_PRODUCT_TYPE = @PRODUCT_TYPE
		SET @Actual_Product_SubTYPE = @Product_SubTYPE
		SET @PRODUCT_TYPE = @LookupProductType
		SET @Product_SubTYPE = @LookupProductSubType
	end

	declare @StaffYN nvarchar(100)
	declare @ProjectID nvarchar(100)
	select @StaffYN=staffyn,@Relationship_with_bank=Relationship_with_bank
	from lead_details_others where lead_no=@REFNO
	select @ProjectID = property_projectid from lead_details_property where lead_no=@REFNO
	select @CUSTOMER_RES_TYPE=CUSTOMER_RES_TYPE,@Source_Submission=Lead_Source_OF_Submission
	from lead_details where lead_no=@REFNO

	SET @StaffYN=CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(@StaffYN,N'')))) IN (N'YES',N'Y',N'1')
		THEN N'Yes' ELSE N'No' END;

	SELECT @RelationshipFeeRate=FeeRate
	FROM dbo.LEAD_STL_NSTL_FEE_CONFIG
	WHERE UPPER(LTRIM(RTRIM(RelationshipType)))=UPPER(LTRIM(RTRIM(ISNULL(@Relationship_with_bank,N''))))
	  AND IsApplicable=1;

	select @Is_VAT_Applicable = isnull(Is_VAT_Applicable,0) from LEAD_ARR_FEE_MASTER
	Where
		PRODUCT_TYPE=@PRODUCT_TYPE and Product_SubTYPE = @Product_SubTYPE and
		Residency_Type = @CUSTOMER_RES_TYPE and Staff = @StaffYN and
		ISNULL(Status,'A')='A'

	select @found=count(1) from LEAD_ARR_FEE_MASTER where PRODUCT_TYPE = @PRODUCT_TYPE
		and Product_SubTYPE = @Product_SubTYPE and Residency_Type = @CUSTOMER_RES_TYPE and Staff = @StaffYN
	--Madesh Made changes on 11/7/2021 for UAT fix for product type and product sub type-->added msg

	print 'test1'
	--select @PRODUCT_TYPE, @Product_SubTYPE, @CUSTOMER_RES_TYPE, @StaffYN, @found
	declare @TextError nvarchar(1000)
	if(@Product_SubTYPE='None' or @Product_SubTYPE='0' or @Product_SubTYPE='' or @PRODUCT_TYPE='None' or @PRODUCT_TYPE='' or @PRODUCT_TYPE='0' )
	BEGIN
		set @TextError='Please Update the Product Type and Product Sub Type and process the application'
	END
	else if @found = 0
	begin
		/*
		EXEC sp_addmessage
		@msgnum = 60000,
		@severity = 16,
		@msgtext = 'Arrangement fee not defined, Please contact Product Team',
		@lang = 'us_english',
		@replace= 'replace'
		*/
		declare @Text nvarchar(1000)
		set @text = 'Arrangement fee not defined for product - ' + @PRODUCT_TYPE + ',' + @Product_SubTYPE + '. Please raise this to product team.'
		---changed by rajesh kumar 04/02/2026 -> to fix error message
		RAISERROR (@text,16,1)
		return
	end
	print 'test2'
	select
		@FEE_FV=FEE_FV,
		@FEE_OPV=FEE_OPV,
		@FEE_APV=FEE_APV,
		@FEE_Buyout=FEE_Buyout,
		@FEE_Topup=FEE_Topup,
		@FEE_Equity=FEE_Equity,
		@FEE_Cashout=FEE_Cashout,
		@FEE_MBRE=FEE_MBRE,
		@FEE_APP=FEE_APP,
		@FEE_ACC=FEE_ACC,
		@MIN_FEE=MIN_FEE,
		@MAX_FEE=MAX_FEE
	from LEAD_ARR_FEE_MASTER where PRODUCT_TYPE = @PRODUCT_TYPE and Product_SubTYPE = @Product_SubTYPE and Residency_Type = @CUSTOMER_RES_TYPE and Staff = @StaffYN
	print 'test3'

	IF @RelationshipFeeRate IS NOT NULL
		SET @FEE_FV=@RelationshipFeeRate;

	INSERT @PromotionRules
		(RuleId,RuleSequence,RuleStage,RuleType,TargetField,AmountBasis,RuleValue,MinimumFee,MaximumFee,SplitMode,FloorSplitMode,VATApplicable)
	SELECT PromotionRule.RuleId,PromotionRule.RuleSequence,PromotionRule.RuleStage,PromotionRule.RuleType,
		PromotionRule.TargetField,PromotionRule.AmountBasis,PromotionRule.RuleValue,PromotionRule.MinimumFee,
		PromotionRule.MaximumFee,PromotionRule.SplitMode,PromotionRule.FloorSplitMode,PromotionRule.VATApplicable
	FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE PromotionRule
	WHERE (REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionRule.PromotionName)),NCHAR(8209),N'-'),
			NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@PromotionKey
		OR REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(PromotionRule.PromotionName)),NCHAR(8209),N'-'),
			NCHAR(8211),N'-'),NCHAR(8212),N'-'),N' - ',N'-')=@PromotionDisplayKey)
	  AND PromotionRule.IsEnabled=1 AND @PromotionEnabled=1
	  AND NOT EXISTS
	  (
		SELECT 1 FROM dbo.LEAD_ARR_FEE_PROMOTION_RULE_FILTER RuleFilter
		WHERE RuleFilter.RuleId=PromotionRule.RuleId
		  AND NOT
		  (
			(RuleFilter.FieldName='PRODUCT_TYPE' AND
				((RuleFilter.ComparisonOperator='EQ' AND ISNULL(@PRODUCT_TYPE,N'')=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NE' AND ISNULL(@PRODUCT_TYPE,N'')<>RuleFilter.FilterValue)))
			OR (RuleFilter.FieldName='PRODUCT_SUBTYPE' AND
				((RuleFilter.ComparisonOperator='EQ' AND ISNULL(@Product_SubTYPE,N'')=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NE' AND ISNULL(@Product_SubTYPE,N'')<>RuleFilter.FilterValue)))
			OR (RuleFilter.FieldName='RESIDENCY_TYPE' AND
				((RuleFilter.ComparisonOperator='EQ' AND ISNULL(@CUSTOMER_RES_TYPE,N'')=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NE' AND ISNULL(@CUSTOMER_RES_TYPE,N'')<>RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='PREFIX' AND LEFT(ISNULL(@CUSTOMER_RES_TYPE,N''),LEN(RuleFilter.FilterValue))=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NOT_PREFIX' AND LEFT(ISNULL(@CUSTOMER_RES_TYPE,N''),LEN(RuleFilter.FilterValue))<>RuleFilter.FilterValue)))
			OR (RuleFilter.FieldName='STAFF' AND
				((RuleFilter.ComparisonOperator='EQ' AND ISNULL(@StaffYN,N'')=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NE' AND ISNULL(@StaffYN,N'')<>RuleFilter.FilterValue)))
			OR (RuleFilter.FieldName='SOURCE_SUBMISSION' AND
				((RuleFilter.ComparisonOperator='EQ' AND ISNULL(@Source_Submission,N'')=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NE' AND ISNULL(@Source_Submission,N'')<>RuleFilter.FilterValue)))
			OR (RuleFilter.FieldName='PROJECT_ID' AND
				((RuleFilter.ComparisonOperator='EQ' AND ISNULL(@ProjectID,N'')=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NE' AND ISNULL(@ProjectID,N'')<>RuleFilter.FilterValue)))
			OR (RuleFilter.FieldName='CONVERSION_PRODUCT' AND
				((RuleFilter.ComparisonOperator='EQ' AND ISNULL(@LeadConversionProduct,N'')=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NE' AND ISNULL(@LeadConversionProduct,N'')<>RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='PREFIX' AND LEFT(ISNULL(@LeadConversionProduct,N''),LEN(RuleFilter.FilterValue))=RuleFilter.FilterValue)
				 OR (RuleFilter.ComparisonOperator='NOT_PREFIX' AND LEFT(ISNULL(@LeadConversionProduct,N''),LEN(RuleFilter.FilterValue))<>RuleFilter.FilterValue)))
		  )
	  );

	DECLARE PreCalculationRules CURSOR LOCAL FAST_FORWARD FOR
		SELECT RuleType,TargetField,RuleValue,MinimumFee,MaximumFee,VATApplicable FROM @PromotionRules
		WHERE RuleStage='PRE_CALC' ORDER BY RuleSequence,RuleId;
	OPEN PreCalculationRules;
	FETCH NEXT FROM PreCalculationRules INTO @RuleType,@RuleTargetField,@RuleValue,
		@RuleMinimumFee,@RuleMaximumFee,@RuleVATApplicable;
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF @RuleType='FEE_LIMITS'
		BEGIN
			SET @MIN_FEE=@RuleMinimumFee;
			SET @MAX_FEE=@RuleMaximumFee;
			SET @SkipMinFee=CASE WHEN @RuleMinimumFee IS NULL THEN 1 ELSE 0 END;
			SET @SkipMaxFee=CASE WHEN @RuleMaximumFee IS NULL THEN 1 ELSE 0 END;
		END
		ELSE IF @RuleType IN ('RATE_SET','RATE_SUBTRACT_POSITIVE') AND @RuleValue IS NOT NULL
		BEGIN
			IF @RuleTargetField='FEE_FV'
				IF @RuleType='RATE_SET' SET @FEE_FV=@RuleValue ELSE IF ISNULL(@FEE_FV,0)>0 SET @FEE_FV=@FEE_FV-@RuleValue;
			IF @RuleTargetField='FEE_OPV'
				IF @RuleType='RATE_SET' SET @FEE_OPV=@RuleValue ELSE IF ISNULL(@FEE_OPV,0)>0 SET @FEE_OPV=@FEE_OPV-@RuleValue;
			IF @RuleTargetField='FEE_APV'
				IF @RuleType='RATE_SET' SET @FEE_APV=@RuleValue ELSE IF ISNULL(@FEE_APV,0)>0 SET @FEE_APV=@FEE_APV-@RuleValue;
			IF @RuleTargetField='FEE_Buyout'
				IF @RuleType='RATE_SET' SET @FEE_Buyout=@RuleValue ELSE IF ISNULL(@FEE_Buyout,0)>0 SET @FEE_Buyout=@FEE_Buyout-@RuleValue;
			IF @RuleTargetField='FEE_Topup'
				IF @RuleType='RATE_SET' SET @FEE_Topup=@RuleValue ELSE IF ISNULL(@FEE_Topup,0)>0 SET @FEE_Topup=@FEE_Topup-@RuleValue;
			IF @RuleTargetField='FEE_Equity'
				IF @RuleType='RATE_SET' SET @FEE_Equity=@RuleValue ELSE IF ISNULL(@FEE_Equity,0)>0 SET @FEE_Equity=@FEE_Equity-@RuleValue;
			IF @RuleTargetField='FEE_Cashout'
				IF @RuleType='RATE_SET' SET @FEE_Cashout=@RuleValue ELSE IF ISNULL(@FEE_Cashout,0)>0 SET @FEE_Cashout=@FEE_Cashout-@RuleValue;
			IF @RuleTargetField='FEE_MBRE'
				IF @RuleType='RATE_SET' SET @FEE_MBRE=@RuleValue ELSE IF ISNULL(@FEE_MBRE,0)>0 SET @FEE_MBRE=@FEE_MBRE-@RuleValue;
		END;
		IF @RuleVATApplicable IS NOT NULL SET @Is_VAT_Applicable=@RuleVATApplicable;
		FETCH NEXT FROM PreCalculationRules INTO @RuleType,@RuleTargetField,@RuleValue,
			@RuleMinimumFee,@RuleMaximumFee,@RuleVATApplicable;
	END;
	CLOSE PreCalculationRules;
	DEALLOCATE PreCalculationRules;

	SET @CAL_AMT_FV = (ISNULL(@FEE_FV,0)/100) * ISNULL(@AMT_FV,0);
	SET @CAL_AMT_OPV = (ISNULL(@FEE_OPV,0)/100) * ISNULL(@AMT_OPV,0);
	SET @CAL_AMT_APV = (ISNULL(@FEE_APV,0)/100) * ISNULL(@AMT_APV,0);
	SET @CAL_AMT_Buyout = (ISNULL(@FEE_Buyout,0)/100) * ISNULL(@AMT_Buyout,0);
	SET @CAL_AMT_Topup = (ISNULL(@FEE_Topup,0)/100) * ISNULL(@AMT_Topup,0);
	SET @CAL_AMT_Equity = (ISNULL(@FEE_Equity,0)/100) * ISNULL(@AMT_Equity,0);
	SET @CAL_AMT_Cashout = (ISNULL(@FEE_Cashout,0)/100) * ISNULL(@AMT_Cashout,0);
	SET @CAL_AMT_MBRE = (ISNULL(@FEE_MBRE,0)/100) * ISNULL(@AMT_MBRE,0);

	SET @ARRANGEMENT_FEE = ISNULL(@CAL_AMT_FV,0)+ISNULL(@CAL_AMT_OPV,0)+ISNULL(@CAL_AMT_APV,0)
		+ISNULL(@CAL_AMT_Buyout,0)+ISNULL(@CAL_AMT_Topup,0)+ISNULL(@CAL_AMT_Equity,0)
		+ISNULL(@CAL_AMT_Cashout,0)+ISNULL(@CAL_AMT_MBRE,0);

	IF @SkipMinFee=0 AND @MIN_FEE IS NOT NULL AND @ARRANGEMENT_FEE < @MIN_FEE
		SET @ARRANGEMENT_FEE=@MIN_FEE;
	IF @SkipMaxFee=0 AND @MAX_FEE IS NOT NULL AND @ARRANGEMENT_FEE > @MAX_FEE
		SET @ARRANGEMENT_FEE=@MAX_FEE;

	SET @ARRANGEMENT_FEE_APP=@ARRANGEMENT_FEE*(ISNULL(@FEE_APP,0)/100);
	SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE*(ISNULL(@FEE_ACC,0)/100);

	DECLARE PostBaseRules CURSOR LOCAL FAST_FORWARD FOR
		SELECT RuleType,AmountBasis,RuleValue,MinimumFee,MaximumFee,SplitMode,FloorSplitMode,VATApplicable
		FROM @PromotionRules WHERE RuleStage='POST_BASE' ORDER BY RuleSequence,RuleId;
	OPEN PostBaseRules;
	FETCH NEXT FROM PostBaseRules INTO @RuleType,@RuleAmountBasis,@RuleValue,@RuleMinimumFee,
		@RuleMaximumFee,@RuleSplitMode,@RuleFloorSplitMode,@RuleVATApplicable;
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF @RuleType='FEE_PERCENT_DISCOUNT' AND ISNULL(@ARRANGEMENT_FEE,0)>0
			SET @ARRANGEMENT_FEE=@ARRANGEMENT_FEE-(@ARRANGEMENT_FEE*@RuleValue/100);
		ELSE IF @RuleType='FEE_FROM_AMOUNT'
		BEGIN
			SET @RuleAmount=CASE @RuleAmountBasis WHEN 'FINANCE' THEN @AMT_FV WHEN 'TOPUP' THEN @AMT_Topup WHEN 'EQUITY' THEN @AMT_Equity ELSE 0 END;
			SET @ARRANGEMENT_FEE=(@RuleAmount*@RuleValue)/100;
		END;

		IF @RuleType IN ('FEE_PERCENT_DISCOUNT','FEE_FROM_AMOUNT')
		BEGIN
			IF @RuleSplitMode='RECALCULATE'
			BEGIN
				SET @ARRANGEMENT_FEE_APP=@ARRANGEMENT_FEE*(ISNULL(@FEE_APP,0)/100);
				SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE*(ISNULL(@FEE_ACC,0)/100);
			END
			ELSE IF @RuleSplitMode='APP_ZERO'
			BEGIN
				SET @ARRANGEMENT_FEE_APP=0;
				SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE;
			END
			ELSE IF @RuleSplitMode='ACC_RESIDUAL'
				SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE-@ARRANGEMENT_FEE_APP;

			IF @RuleMinimumFee IS NOT NULL AND @ARRANGEMENT_FEE<@RuleMinimumFee
			BEGIN
				SET @ARRANGEMENT_FEE=@RuleMinimumFee;
				IF @RuleFloorSplitMode='RECALCULATE'
				BEGIN
					SET @ARRANGEMENT_FEE_APP=@ARRANGEMENT_FEE*(ISNULL(@FEE_APP,0)/100);
					SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE*(ISNULL(@FEE_ACC,0)/100);
				END
				ELSE IF @RuleFloorSplitMode='APP_ZERO'
				BEGIN
					SET @ARRANGEMENT_FEE_APP=0;
					SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE;
				END
				ELSE IF @RuleFloorSplitMode='ACC_RESIDUAL'
					SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE-@ARRANGEMENT_FEE_APP;
			END;
			IF @RuleMaximumFee IS NOT NULL AND @ARRANGEMENT_FEE>@RuleMaximumFee
			BEGIN
				SET @ARRANGEMENT_FEE=@RuleMaximumFee;
				IF @RuleSplitMode='RECALCULATE'
				BEGIN
					SET @ARRANGEMENT_FEE_APP=@ARRANGEMENT_FEE*(ISNULL(@FEE_APP,0)/100);
					SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE*(ISNULL(@FEE_ACC,0)/100);
				END
				ELSE IF @RuleSplitMode='APP_ZERO'
				BEGIN
					SET @ARRANGEMENT_FEE_APP=0;
					SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE;
				END
				ELSE IF @RuleSplitMode='ACC_RESIDUAL'
					SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE-@ARRANGEMENT_FEE_APP;
			END;
		END;
		IF @RuleVATApplicable IS NOT NULL SET @Is_VAT_Applicable=@RuleVATApplicable;
		FETCH NEXT FROM PostBaseRules INTO @RuleType,@RuleAmountBasis,@RuleValue,@RuleMinimumFee,
			@RuleMaximumFee,@RuleSplitMode,@RuleFloorSplitMode,@RuleVATApplicable;
	END;
	CLOSE PostBaseRules;
	DEALLOCATE PostBaseRules;

	if @ProjectID = 'PRE_APPROVAL'
	begin
		if @ARRANGEMENT_FEE_ACC <> 0
		begin
			set @ARRANGEMENT_FEE = 1500
			set @ARRANGEMENT_FEE_APP = 0
			set @ARRANGEMENT_FEE_ACC = 1500
			set @StaffYN = 'No'
		end
		else
		begin
			set @ARRANGEMENT_FEE = 0
			set @ARRANGEMENT_FEE_APP = 0
			set @ARRANGEMENT_FEE_ACC = 0
			set @StaffYN = 'No'
		end
	end

	declare @DiscountPerc numeric(20,2) = 0
	declare @Temp_ARRANGEMENT_FEE numeric(20,2)
	set @ApplyMasterDiscount=@UseMasterDiscount

	DECLARE PreMasterDiscountRules CURSOR LOCAL FAST_FORWARD FOR
		SELECT RuleType FROM @PromotionRules
		WHERE RuleStage='PRE_MASTER_DISCOUNT' ORDER BY RuleSequence,RuleId;
	OPEN PreMasterDiscountRules;
	FETCH NEXT FROM PreMasterDiscountRules INTO @RuleType;
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF @RuleType='SKIP_MASTER_DISCOUNT' SET @ApplyMasterDiscount=0;
		FETCH NEXT FROM PreMasterDiscountRules INTO @RuleType;
	END;
	CLOSE PreMasterDiscountRules;
	DEALLOCATE PreMasterDiscountRules;

	if @PromotionEnabled=1 AND @ApplyMasterDiscount=1 AND isnull(@promotiontype,'') <> ''
	begin
		select @DiscountPerc=isnull(DiscountPerc,0)
		from dbo.vw_LeadFeePromotionMaster
		where PromotionKey=@PromotionKey AND MasterStatus='A'
			AND (StartDate IS NULL OR StartDate<DATEADD(DAY,1,CONVERT(DATE,GETDATE())))
			AND (EndDate IS NULL OR EndDate>=CONVERT(DATE,GETDATE()))

		set @DiscountPerc=isnull(@DiscountPerc,0)
		set @Temp_ARRANGEMENT_FEE=@ARRANGEMENT_FEE-(@ARRANGEMENT_FEE*@DiscountPerc/100)
		set @ARRANGEMENT_FEE=@Temp_ARRANGEMENT_FEE
		set @ARRANGEMENT_FEE_ACC=@Temp_ARRANGEMENT_FEE-@ARRANGEMENT_FEE_APP
	end

	--END > 06-05-2020 RFC-Arrangement fee to be zero for "Procesing Fee Promotion"

	----Processing Fee Promotion--START
	--16-02-2026 Arun Rajan

	DECLARE PostMasterDiscountRules CURSOR LOCAL FAST_FORWARD FOR
		SELECT RuleType,RuleValue,MinimumFee,MaximumFee,VATApplicable FROM @PromotionRules
		WHERE RuleStage='POST_MASTER_DISCOUNT' ORDER BY RuleSequence,RuleId;
	OPEN PostMasterDiscountRules;
	FETCH NEXT FROM PostMasterDiscountRules INTO @RuleType,@RuleValue,@RuleMinimumFee,@RuleMaximumFee,@RuleVATApplicable;
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF @RuleType='EQUITY_RATE_TO_ACC' AND @RuleValue IS NOT NULL
		BEGIN
			SET @ARRANGEMENT_FEE_ACC=ISNULL(@AMT_Equity,0)*@RuleValue/100;
			SET @ARRANGEMENT_FEE=ISNULL(@ARRANGEMENT_FEE_APP,0)+@ARRANGEMENT_FEE_ACC;
			IF @RuleMinimumFee IS NOT NULL AND @ARRANGEMENT_FEE<@RuleMinimumFee
			BEGIN
				SET @ARRANGEMENT_FEE=@RuleMinimumFee;
				SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE-ISNULL(@ARRANGEMENT_FEE_APP,0);
			END;
			IF @RuleMaximumFee IS NOT NULL AND @ARRANGEMENT_FEE>@RuleMaximumFee
			BEGIN
				SET @ARRANGEMENT_FEE=@RuleMaximumFee;
				SET @ARRANGEMENT_FEE_ACC=@ARRANGEMENT_FEE-ISNULL(@ARRANGEMENT_FEE_APP,0);
			END;
		END;
		IF @RuleVATApplicable IS NOT NULL SET @Is_VAT_Applicable=@RuleVATApplicable;
		FETCH NEXT FROM PostMasterDiscountRules INTO @RuleType,@RuleValue,@RuleMinimumFee,@RuleMaximumFee,@RuleVATApplicable;
	END;
	CLOSE PostMasterDiscountRules;
	DEALLOCATE PostMasterDiscountRules;


	--START ---------------------------------------------------------------------------

	--10-12-2017 Raheel Ahmed > VAT Implementation

	SET @ARRANGEMENT_FEE_BEFORE_VAT=ISNULL(@ARRANGEMENT_FEE,0);
	SET @VAT_AMOUNT=0;
	SET @VAT_Percentage=0;

	if @Is_VAT_Applicable = 1
	Begin
		select @VAT_Percentage = displayvalue from frm_gnarr where code = 'LEAD_CONSTANT' and [Value] = 'VAT_PERCENTAGE'
		SET @VAT_Percentage=ISNULL(@VAT_Percentage,0);

		print 'BEFORE VAT'
		print @ARRANGEMENT_FEE
		print @ARRANGEMENT_FEE_APP
		print @ARRANGEMENT_FEE_ACC

		--Check Is_VAT_Applicable for product and sub product
		SET @VAT_AMOUNT=@ARRANGEMENT_FEE*(@VAT_Percentage/100.0);
		set @ARRANGEMENT_FEE = @ARRANGEMENT_FEE + @VAT_AMOUNT
		set @ARRANGEMENT_FEE_APP = @ARRANGEMENT_FEE_APP + (@ARRANGEMENT_FEE_APP * (@VAT_Percentage/100.0))
		set @ARRANGEMENT_FEE_ACC = @ARRANGEMENT_FEE_ACC + (@ARRANGEMENT_FEE_ACC * (@VAT_Percentage/100.0))

		print 'AFTER VAT'
		print @VAT_Percentage
		print @ARRANGEMENT_FEE
		print @ARRANGEMENT_FEE_APP
		print @ARRANGEMENT_FEE_ACC
	End

	--END -----------------------------------------------------------------------------

	--now restore actual product and sub-product
	if @PromotionEnabled=1 AND @LookupProductType IS NOT NULL AND @LookupProductSubType IS NOT NULL
	Begin
		SET @PRODUCT_TYPE = @Actual_PRODUCT_TYPE
		SET @Product_SubTYPE = @Actual_Product_SubTYPE
	End

	insert into #List(
		Lead_No,
		PRODUCT_TYPE,
		Product_SubTYPE,
		Residency_Type,
		StaffYN,
		promotiontype,
		Scenario,

		FEE_FV,
		FEE_OPV,
		FEE_APV,
		FEE_Buyout,
		FEE_Topup,
		FEE_Equity,
		FEE_Cashout,
		FEE_MBRE,

		AMT_FV,
		AMT_OPV,
		AMT_APV,
		AMT_Buyout,
		AMT_Topup,
		AMT_Equity,
		AMT_Cashout,
		AMT_MBRE,

		FEE_APP,
		FEE_ACC,
		MIN_FEE,
		MAX_FEE,
		ARRANGEMENT_FEE_APP,
		ARRANGEMENT_FEE_ACC,
		ARRANGEMENT_FEE_BEFORE_VAT,
		VAT_PERCENTAGE,
		VAT_AMOUNT,
		IS_VAT_APPLICABLE,
		ARRANGEMENT_FEE,
		RECCOUNT,
		Remarks,
		--Madesh Made changes on 11/7/2021 for UAT fix for product type and product sub type-->added msg
		ErrorMsg
	)
	values(
		@REFNO,
		@PRODUCT_TYPE,
		@Product_SubTYPE,
		@CUSTOMER_RES_TYPE,
		@StaffYN,
		@promotiontype,
		COALESCE(NULLIF(@Scenario,N''),
			CASE WHEN @PromotionEnabled=1 AND NULLIF(LTRIM(RTRIM(@promotiontype)),N'') IS NOT NULL
				THEN N'Promotion-configured arrangement fee'
				WHEN @ProjectID='PRE_APPROVAL' THEN N'Pre-approval'
				ELSE N'Arrangement fee master calculation'
			END),

		@FEE_FV,
		@FEE_OPV,
		@FEE_APV,
		@FEE_Buyout,
		@FEE_Topup,
		@FEE_Equity,
		@FEE_Cashout,
		@FEE_MBRE,

		@AMT_FV,
		@AMT_OPV,
		@AMT_APV,
		@AMT_Buyout,
		@AMT_Topup,
		@AMT_Equity,
		@AMT_Cashout,
		@AMT_MBRE,

		@FEE_APP,
		@FEE_ACC,
		@MIN_FEE,
		@MAX_FEE,
		isnull(@ARRANGEMENT_FEE_APP,0),
		isnull(@ARRANGEMENT_FEE_ACC,0),
		isnull(@ARRANGEMENT_FEE_BEFORE_VAT,0),
		isnull(@VAT_Percentage,0),
		isnull(@VAT_AMOUNT,0),
		isnull(@Is_VAT_Applicable,0),
		isnull(@ARRANGEMENT_FEE,0),
		null,
		null,
		--Madesh Made changes on 11/7/2021 for UAT fix for product type and product sub type-->added msg
		@TextError
	)

	select * from #list
	Drop table #list

END

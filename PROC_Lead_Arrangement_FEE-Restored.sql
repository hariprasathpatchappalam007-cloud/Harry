ALTER proc [dbo].[PROC_Lead_Arrangement_FEE]
@REFNO nvarchar(100)=null
as
BEGIN
	set quoted_identifier off
	create table #List
	(
	PRODUCT_TYPE nvarchar(150), Product_SubTYPE nvarchar(150), Residency_Type nvarchar(100), StaffYN nvarchar(100),
	promotiontype nvarchar(100), FEE_FV numeric(20,4), FEE_OPV numeric(20,4), FEE_APV numeric(20,4),
	FEE_Buyout numeric(20,4), FEE_Topup numeric(20,4), FEE_Equity numeric(20,4), FEE_Cashout numeric(20,4),
	FEE_MBRE numeric(20,4), AMT_FV numeric(20,4), AMT_OPV numeric(20,4), AMT_APV numeric(20,4),
	AMT_Buyout numeric(20,4), AMT_Topup numeric(20,4), AMT_Equity numeric(20,4), AMT_Cashout numeric(20,4),
	AMT_MBRE numeric(20,4), FEE_APP numeric(20,2), FEE_ACC numeric(20,2), MIN_FEE numeric(20,2),
	MAX_FEE numeric(20,2), ARRANGEMENT_FEE_APP numeric(20,2), ARRANGEMENT_FEE_ACC numeric(20,2),
	ARRANGEMENT_FEE numeric(20,2), RECCOUNT int,
	Remarks nvarchar(100), ErrorMsg nvarchar(200)
	)

	declare @found int
	declare @Source_Submission nvarchar(100)
	declare @Employment_Type nvarchar(100)
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
	declare @promotiontype nvarchar(100)
	declare @Is_VAT_Applicable Bit

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
		@promotiontype = lead_fin_promotiontype
	from lead_details_finance where lead_no = @REFNO

	If @promotiontype = 'SLS WoW Dubai Promotion'
	Begin
		declare @Actual_PRODUCT_TYPE nvarchar(100)
		declare @Actual_Product_SubTYPE nvarchar(100)
		SET @Actual_PRODUCT_TYPE = @PRODUCT_TYPE
		SET @Actual_Product_SubTYPE = @Product_SubTYPE
		SET @PRODUCT_TYPE = 'Forward Ijara'
		SET @Product_SubTYPE = 'OPF'
	End

	declare @StaffYN nvarchar(100)
	declare @ProjectID nvarchar(100)
	select @StaffYN=staffyn from lead_details_others where lead_no=@REFNO
	select @ProjectID = property_projectid from lead_details_property where lead_no=@REFNO
	select @CUSTOMER_RES_TYPE = CUSTOMER_RES_TYPE from lead_details where lead_no = @REFNO

	if isnull(@StaffYN,'') = '' set @StaffYN = 'No'
	if isnull(@StaffYN,'') = '0' set @StaffYN = 'No'

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
	--HARIPRASATH <<New Processing Fee (0.5%) <<DGMT-824 <<11-DEC-2025
	--exec PROC_Lead_Arrangement_FEE 'LD-00091535' --26250.00 --13125.00
	if ISNULL(@promotiontype, '') = 'Processing Fee Promotion 0.50%'
	begin
		if (@PRODUCT_TYPE = 'Equity Release' and (@Product_SubTYPE = 'Buyout' or @Product_SubTYPE = 'Topup') AND ISNULL(@CUSTOMER_RES_TYPE,'') = 'Resident')
		BEGIN
			SET @FEE_Cashout = '0.50'
			set @FEE_FV = '0.00'
		END
		else if (ISNULL(@CUSTOMER_RES_TYPE,'') = 'Resident')
		BEGIN
			SET @FEE_Cashout = '0.00'
			set @FEE_FV = '0.50'
		END
	end

	print 'test4'
	--14-11-2019 Raheel > RFC-DEYAAR Promotion & Bloom Holding Promotion & Dubai South Properties Promotion to be added in system, replica of ARADA promotion
	/*
	08-10-2019 Raheel > RFC-ARADA Promotion
	Arrangement fee discount of 25 basis points on principle amount (exclusive of VAT) e.g 1-0.25 = 0.75, 1.25 - 0.25 = 1.00
	*/

	Declare @Promotion nvarchar(200)
	select @Promotion = IsNull(Lead_fin_PromotionType,'0') from LEAD_DETAILS_FINANCE where Lead_No = @REFNO

	DECLARE @ISSTLORNSTLPROMOTION NVARCHAR(200) = 'N'

	SET @ISSTLORNSTLPROMOTION = CASE WHEN @Promotion = 'Promotional Rate with Fees - STL' THEN 'Y' WHEN @Promotion = 'Promotional Rate with Fees - NSTL' THEN 'Y' ELSE 'N' END --hariprasath <<11-07-2023

	If
	(
		@Promotion = 'ARADA Promotion' OR @Promotion = 'DEYAAR Promotion'
		OR @Promotion = 'Bloom Holding Promotion' OR @Promotion = 'Dubai South Properties Promotion'
	)
	Begin
		If @FEE_FV > 0
			SET @FEE_FV = @FEE_FV - 0.25

		If @FEE_OPV > 0
			SET @FEE_OPV = @FEE_OPV - 0.25

		If @FEE_APV > 0
			SET @FEE_APV = @FEE_APV - 0.25

		If @FEE_Buyout > 0
			SET @FEE_Buyout = @FEE_Buyout - 0.25

		If @FEE_Topup > 0
			SET @FEE_Topup = @FEE_Topup - 0.25

		If @FEE_Equity > 0
			SET @FEE_Equity = @FEE_Equity - 0.25

		If @FEE_Cashout > 0
			SET @FEE_Cashout = @FEE_Cashout - 0.25

		If @FEE_MBRE > 0
			SET @FEE_MBRE = @FEE_MBRE - 0.25

		--@FEE_APP
		--@FEE_ACC
	End

	if isnull(@StaffYN,'') = 'Yes' or isnull(@StaffYN,'') = ' Y'
	begin
		set @ARRANGEMENT_FEE = 3500
		set @ARRANGEMENT_FEE_APP = 0
		set @ARRANGEMENT_FEE_ACC = 3500
	end
	else
	begin
		set @CAL_AMT_FV = (@FEE_FV/100) * @AMT_FV
		set @CAL_AMT_OPV = (@FEE_OPV/100) * @AMT_OPV
		set @CAL_AMT_APV = (@FEE_APV/100) * @AMT_APV
		set @CAL_AMT_Buyout = (@FEE_Buyout/100) * @AMT_Buyout
		set @CAL_AMT_Topup = (@FEE_Topup/100) * @AMT_Topup
		set @CAL_AMT_Equity = (@FEE_Equity/100) * @AMT_Equity
		set @CAL_AMT_Cashout = (@FEE_Cashout/100) * @AMT_Cashout
		set @CAL_AMT_MBRE = (@FEE_MBRE/100) * @AMT_MBRE

		set @ARRANGEMENT_FEE = @CAL_AMT_FV + @CAL_AMT_OPV + @CAL_AMT_APV + @CAL_AMT_Buyout + @CAL_AMT_Topup + @CAL_AMT_Equity + @CAL_AMT_Cashout + @CAL_AMT_MBRE

		if @PRODUCT_TYPE = 'Standard Ijara' and @Product_SubTYPE = 'Standard'
		begin
			if @AMT_FV > 7000000 and @AMT_FV < 15000000
				set @MAX_FEE = 60000 --50000 , fixed prod bug, it should be 60K

			if @AMT_FV >= 15000000
				set @MAX_FEE = 100000
		end
		else
		begin
			--Below cap is applicable to all products except Subvention
			--03-01-2019 Raheel > Revised RFC to add FI-OPF Subvention sub product
			If @Product_SubTYPE <> 'Subvention' AND @Product_SubTYPE <> 'OPF Subvention'
			Begin
				if @MAX_FEE <> 999999999
				begin
					if @AMT_FV >= 15000000
						set @MAX_FEE = 100000
				end
			End
		end

		/*
		24-10-2018 Raheel Ahmed > RFC-New Sub-Product 'subvention'
		Product Type SubProduct Residency Type Staff Processing Fee Min Fee Max Fee
		Standard Ijara Subvention Non-Resident - Company No 0.50% +VAT 5000 +VAT No Cap
		Standard Ijara Subvention Resident - Company No 0.50% +VAT 5000 +VAT Same as Standard Ijara - Standard
		Standard Ijara Subvention Resident No 0.50% +VAT 5000 +VAT Same as Standard Ijara - Standard
		Standard Ijara Subvention Resident Yes 3500 + VAT 3500 +VAT 3500 + VAT
		Standard Ijara Subvention Non-Resident No 0.50% +VAT 5000 +VAT No Cap
		*/
		--03-01-2019 Raheel > Revised RFC to add FI-OPF Subvention sub product
		if (@PRODUCT_TYPE = 'Standard Ijara' and @Product_SubTYPE = 'Subvention') OR (@PRODUCT_TYPE = 'Forward Ijara' and @Product_SubTYPE = 'OPF Subvention')
		begin
			IF (@CUSTOMER_RES_TYPE = 'Resident' OR @CUSTOMER_RES_TYPE = 'Resident - Company') and (@StaffYN = 'No')
			Begin
				if @AMT_FV > 7000000 and @AMT_FV < 15000000
					set @MAX_FEE = 60000 --50000 , fixed prod bug, it should be 60K

				if @AMT_FV >= 15000000
					set @MAX_FEE = 100000
			End
		end

		----------------------------------------------------------------------
		--By Raheel Ahmed ON 13-05-2015 CR 'SD2015-223593'
		--Start
		if @PRODUCT_TYPE = 'Commercial' OR @PRODUCT_TYPE = 'Equity Release' OR @PRODUCT_TYPE = 'Standard Ijara'
		if @Product_SubTYPE = 'Buyout' OR @Product_SubTYPE = 'Topup' OR @Product_SubTYPE = 'Buyout - Bulk Residential'
		If @CUSTOMER_RES_TYPE = 'Resident' OR @CUSTOMER_RES_TYPE = 'Company Resident'
		begin
			if @AMT_FV > 15000000
				set @MAX_FEE = 250000
			else
				set @MAX_FEE = 60000
				--set @ARRANGEMENT_FEE = 250000
		end
		--End
		----------------------------------------------------------------------

		if ((@ARRANGEMENT_FEE < @MIN_FEE) and (@ISSTLORNSTLPROMOTION = 'N')) --hariprasath <<11-07-2023
			set @ARRANGEMENT_FEE = @MIN_FEE

		if ((@ARRANGEMENT_FEE > @MAX_FEE) and (@ISSTLORNSTLPROMOTION = 'N')) --hariprasath <<11-07-2023
			set @ARRANGEMENT_FEE = @MAX_FEE

		set @ARRANGEMENT_FEE_APP = @ARRANGEMENT_FEE * (@FEE_APP /100)
		set @ARRANGEMENT_FEE_ACC = @ARRANGEMENT_FEE * (@FEE_ACC /100)
	end

	if @promotiontype = 'APC Promotion' and @PRODUCT_TYPE <> 'MBRE' and @Product_SubTYPE <> 'Swap' and (@PRODUCT_TYPE = 'Equity Release' and @Product_SubTYPE <> 'Buyout')
	begin
		if @ARRANGEMENT_FEE > 0
		begin
			set @ARRANGEMENT_FEE = @ARRANGEMENT_FEE - (@ARRANGEMENT_FEE * 0.25)
			set @ARRANGEMENT_FEE_APP = @ARRANGEMENT_FEE * (@FEE_APP /100)
			set @ARRANGEMENT_FEE_ACC = @ARRANGEMENT_FEE * (@FEE_ACC /100)

			if @ARRANGEMENT_FEE < 5000
			begin
				set @ARRANGEMENT_FEE = 5000
				set @ARRANGEMENT_FEE_APP = 0
				set @ARRANGEMENT_FEE_ACC = @ARRANGEMENT_FEE
			end
		end
	end

	if @promotiontype = 'TopUp Promotion' and @PRODUCT_TYPE = 'Equity Release' and @Product_SubTYPE = 'Topup'
	begin
		set @ARRANGEMENT_FEE = (@AMT_Topup * 0.5)/100
		if @ARRANGEMENT_FEE < 5000
		begin
			set @ARRANGEMENT_FEE = 5000
			set @ARRANGEMENT_FEE_APP = 0
			set @ARRANGEMENT_FEE_ACC = @ARRANGEMENT_FEE
		end
	end

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

	declare @DiscountPerc numeric(20,2)
	declare @Temp_ARRANGEMENT_FEE numeric(20,2)

	if isnull(@promotiontype,'') <> ''
	begin
		declare @productName as varchar(200)
		declare @count numeric
		if (@promotiontype ='DIB Sustainable STL Promotion' or @promotiontype='DIB Sustainable NSTL Promotion') -- added by Nirmal for MSV-2663 on 12th Jan 2024 for Sustainable Promotion
		begin
			set @productName= (select top 1 Lead_Conversion_Product from LEAD_DETAILS_FINANCE where Lead_No=@REFNO)
			set @count=(select count(1) from LEAD_DETAILS_FINANCE where (Lead_Conversion_Product like 'MB%' or Lead_Conversion_Product like 'NB%' or Lead_Conversion_Product like 'TW%')and Lead_No=@REFNO )
			if(@count =0)
			begin
				select @DiscountPerc=isnull(DiscountPerc,0) from Lead_Promotion_master
				where PromotionName = @promotiontype and status = 'A'
				and isnull(startdate,getdate()) >= getdate() and isnull(enddate,getdate()) <= getdate()

				set @DiscountPerc = isnull(@DiscountPerc,0)
				set @Temp_ARRANGEMENT_FEE = @ARRANGEMENT_FEE - (@ARRANGEMENT_FEE * @DiscountPerc/100)
				set @ARRANGEMENT_FEE = @Temp_ARRANGEMENT_FEE
				set @ARRANGEMENT_FEE_ACC = @Temp_ARRANGEMENT_FEE - @ARRANGEMENT_FEE_APP
			end
		end
		else
		begin
			select @DiscountPerc=isnull(DiscountPerc,0) from Lead_Promotion_master
			where PromotionName = @promotiontype and status = 'A'
			and isnull(startdate,getdate()) >= getdate() and isnull(enddate,getdate()) <= getdate()

			set @DiscountPerc = isnull(@DiscountPerc,0)
			set @Temp_ARRANGEMENT_FEE = @ARRANGEMENT_FEE - (@ARRANGEMENT_FEE * @DiscountPerc/100)
			set @ARRANGEMENT_FEE = @Temp_ARRANGEMENT_FEE
			set @ARRANGEMENT_FEE_ACC = @Temp_ARRANGEMENT_FEE - @ARRANGEMENT_FEE_APP
		end
	end

	--select @DiscountPerc
	--exec PROC_Lead_Arrangement_FEE 'LD-00091535' --26250.00 --13125.00

	--END > 06-05-2020 RFC-Arrangement fee to be zero for "Procesing Fee Promotion"

	----Processing Fee Promotion--START
	--16-02-2026 Arun Rajan

	select @Source_Submission = Lead_Source_OF_Submission from lead_details where lead_no = @REFNO

	if (@PRODUCT_TYPE = 'Equity Release' and @Source_Submission='Aggregator')
	BEGIN
		if @promotiontype='Aggregator-STL-Equity Release'
		begin
			Set @ARRANGEMENT_FEE_ACC= @AMT_Equity*0.01
			Set @ARRANGEMENT_FEE=@ARRANGEMENT_FEE_ACC + @ARRANGEMENT_FEE_APP
			print'Aggregator-STL-Equity Release'
			print @ARRANGEMENT_FEE_ACC
			print @ARRANGEMENT_FEE_APP
			print @ARRANGEMENT_FEE
		end
		else if @promotiontype='Aggregator-NSTL-Equity Release'
		Begin
			Declare @EquityProcessingFee Decimal(18,2)=0
			SET @EquityProcessingFee=@AMT_Equity*0.01
			Set @ARRANGEMENT_FEE_ACC=@EquityProcessingFee
			Set @ARRANGEMENT_FEE=@ARRANGEMENT_FEE_ACC + @ARRANGEMENT_FEE_APP
		End
		else if @promotiontype='Aggregator-Equity Release-Standard'
		Begin
			Declare @EquityStandardProcessingFee Decimal(18,2)=0
			SET @EquityStandardProcessingFee=@AMT_Equity*0.0125
			Set @ARRANGEMENT_FEE_ACC= @EquityStandardProcessingFee
			Set @ARRANGEMENT_FEE=@ARRANGEMENT_FEE_ACC + @ARRANGEMENT_FEE_APP
		End
		set @Is_VAT_Applicable=1
	END
	print 'Processing Fee Promotion--END'
	----Processing Fee Promotion--END

	--START ---------------------------------------------------------------------------

	--10-12-2017 Raheel Ahmed > VAT Implementation

	if @Is_VAT_Applicable = 1
	Begin
		Declare @VAT_Percentage numeric(20,5)
		select @VAT_Percentage = displayvalue from frm_gnarr where code = 'LEAD_CONSTANT' and [Value] = 'VAT_PERCENTAGE'

		print 'BEFORE VAT'
		print @ARRANGEMENT_FEE
		print @ARRANGEMENT_FEE_APP
		print @ARRANGEMENT_FEE_ACC

		--Check Is_VAT_Applicable for product and sub product
		set @ARRANGEMENT_FEE = @ARRANGEMENT_FEE + (@ARRANGEMENT_FEE * (@VAT_Percentage/100.0))
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
	If @promotiontype ='SLS WoW Dubai Promotion'
	Begin
		SET @PRODUCT_TYPE = @Actual_PRODUCT_TYPE
		SET @Product_SubTYPE = @Actual_Product_SubTYPE
	End

	insert into #List(
		PRODUCT_TYPE,
		Product_SubTYPE,
		Residency_Type,
		StaffYN,
		promotiontype,

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
		ARRANGEMENT_FEE,
		RECCOUNT,
		Remarks,
		--Madesh Made changes on 11/7/2021 for UAT fix for product type and product sub type-->added msg
		ErrorMsg
	)
	values(
		@PRODUCT_TYPE,
		@Product_SubTYPE,
		@CUSTOMER_RES_TYPE,
		@StaffYN,
		@promotiontype,

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
		isnull(@ARRANGEMENT_FEE,0),
		null,
		null,
		--Madesh Made changes on 11/7/2021 for UAT fix for product type and product sub type-->added msg
		@TextError
	)

	select * from #list
	Drop table #list

END

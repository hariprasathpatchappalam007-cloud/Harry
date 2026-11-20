if (response != null)
{
    string xmlResponse = CreatecustXmlObject(response);
    //objCustomerdetail = new Customerdetail();
    //objCustomerdetail = CustomerDetails(xmlResponse, pLeadNo, pCustomerSrNo, pUserId);
    // UPDATE_SOA_RESPONSE(request.MessageRequestBody.QueryCustomers[0].XRef, xmlResponse, "RESPONSE RECEIVED", pUserId, "", "", soaLogSrNo);

    if (response.MessageResponseBody.CustomersDetails.FaultDetails != null)
    {
        if (response.MessageResponseBody.CustomersDetails.FaultDetails.ErrorDescription != string.Empty)
        {
            result = response.MessageResponseBody.CustomersDetails.FaultDetails.ErrorDescription;
            UPDATE_SOA_RESPONSE(request.MessageRequestBody.QueryCustomers[0].XRef, xmlResponse, "RESP-0001# Response Received with Error # Failure", pUserId, "", "", soaLogSrNo);
        }
    }
    else
    {
        if (response.MessageResponseBody.CustomersDetails.CustomerInformation != null)
        {
            CustomerInformation[] customerInformation = new CustomerInformation[1];
            customerInformation[0] = response.MessageResponseBody.CustomersDetails.CustomerInformation[0];
            PersonInformation personInformation = customerInformation[0].Item as PersonInformation;
            PassportType passportInfo = personInformation.Items1[0] as PassportType;

            System.Data.DataSet _DS = new System.Data.DataSet();
            _DS = RQ.getCountry();
            /*Adding Residence Address*/
            if (response.MessageResponseBody != null)
            {
                CAS_CustomerAddressDetails addres = new CAS_CustomerAddressDetails();

                addres.ApplicantName = "";
                addres.ADDRESS_TYPE = "Residence Address";
                addres.BuildingDetails = "";
                addres.FlatOrOfficeDetails = "";
                addres.ReferenceName_1 = "";
                addres.RefPhNo_1 = "";
                addres.ReferenceName_2 = "";
                addres.RefPhNo_2 = "";
                addres.ReferenceName_3 = "";
                addres.RefPhNo_3 = "";
                addres.ReferenceName_4 = "";
                addres.RefPhNo_4 = "";

                if (response.MessageResponseBody.CustomersDetails.CustomerInformation[0].PostalAddress != null)
                {
                    addres.Address_1 = Convert.ToString(customerInformation[0].PostalAddress.AddressLine[0].AddressLine1);
                    addres.Address_2 = Convert.ToString(customerInformation[0].PostalAddress.AddressLine[0].AddressLine2);
                    addres.Address_3 = Convert.ToString(customerInformation[0].PostalAddress.AddressLine[0].AddressLine3);
                    addres.Address_4 = Convert.ToString(customerInformation[0].PostalAddress.AddressLine[0].AddressLine4);
                    addres.CustomerPreferences = Convert.ToString(customerInformation[0].CustomerPreference);

                    addres.POBOX = Convert.ToString(customerInformation[0].PostalAddress.POBoxNumber);
                    addres.CITY = Convert.ToString(customerInformation[0].PostalAddress.City);
                    addres.State = Convert.ToString(customerInformation[0].PostalAddress.State);
                    string rescountrycode = Convert.ToString(customerInformation[0].PostalAddress.Country);
                    rescountrycode = _DS.Tables[0].AsEnumerable().Where(row => row.Field<string>("Country_Code") == rescountrycode) // Filter the rows
                    .Select(row => row.Field<string>("Country_name"))
                    .FirstOrDefault();
                    addres.COUNTRY = Convert.ToString(rescountrycode);
                }

                if (personInformation != null)
                {
                    string mobwithcode = Convert.ToString(personInformation.ContactInformation.MobileNumbers.MobileNumber[0]);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.MOBILECODE = mobwithcode.Substring(1, 3);
                            addres.MOBILENO = mobwithcode.Substring(4, mobwithcode.Length - 4); ;
                        }
                        else
                        { addres.MOBILENO = mobwithcode; }
                    }

                    mobwithcode = Convert.ToString(personInformation.ContactInformation.PhoneNumber[0].Phone);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.PHONECODE = mobwithcode.Substring(1, 3);
                            addres.PhoneNo = mobwithcode.Substring(4, mobwithcode.Length - 4);
                        }
                        else
                        { addres.PhoneNo = mobwithcode; }
                    }

                    mobwithcode = Convert.ToString(personInformation.ContactInformation.FaxNumbers.FaxNumber);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.FAXCODE = mobwithcode.Substring(1, 3);
                            addres.FaxNo = mobwithcode.Substring(4, mobwithcode.Length - 4);
                        }
                        else
                        { addres.FaxNo = mobwithcode; }
                    }

                    addres.PERSONAL_EMAIL = Convert.ToString(personInformation.ContactInformation.EMailIAddresses[0].Address);
                    addres.OfficeEmailId = Convert.ToString(personInformation.ContactInformation.EMailIAddresses[0].SecondaryAddress);
                }

                AddressDetails.Add(addres);
            }

            /*Adding Mailing Address*/
            if (personInformation != null)
            {
                if (personInformation.ContactInformation != null && personInformation.ContactInformation.PostalAddress[0] != null)
                {
                    CAS_CustomerAddressDetails addres = new CAS_CustomerAddressDetails();
                    addres.ApplicantName = "";
                    addres.ADDRESS_TYPE = "Mailing Address";
                    addres.ReferenceName_1 = "";
                    addres.RefPhNo_1 = "";
                    addres.ReferenceName_2 = "";
                    addres.RefPhNo_2 = "";
                    addres.ReferenceName_3 = "";
                    addres.RefPhNo_3 = "";
                    addres.ReferenceName_4 = "";
                    addres.RefPhNo_4 = "";
                    addres.BuildingDetails = "";
                    addres.FlatOrOfficeDetails = "";
                    addres.Address_1 = Convert.ToString(personInformation.ContactInformation.PostalAddress[0].AddressLine[0].AddressLine1);
                    addres.Address_2 = Convert.ToString(personInformation.ContactInformation.PostalAddress[0].AddressLine[0].AddressLine2);
                    addres.Address_3 = Convert.ToString(personInformation.ContactInformation.PostalAddress[0].AddressLine[0].AddressLine3);
                    addres.Address_4 = Convert.ToString(personInformation.ContactInformation.PostalAddress[0].AddressLine[0].AddressLine4);
                    addres.CustomerPreferences = Convert.ToString(customerInformation[0].CustomerPreference);

                    addres.POBOX = Convert.ToString(personInformation.ContactInformation.PostalAddress[0].POBoxNumber);
                    addres.CITY = Convert.ToString(personInformation.ContactInformation.PostalAddress[0].City);
                    addres.State = Convert.ToString(personInformation.ContactInformation.PostalAddress[0].State);
                    string mailcountrycode = Convert.ToString(personInformation.ContactInformation.PostalAddress[0].Country);
                    mailcountrycode = _DS.Tables[0].AsEnumerable().Where(row => row.Field<string>("Country_Code") == mailcountrycode) // Filter the rows
                    .Select(row => row.Field<string>("Country_name"))
                    .FirstOrDefault();
                    addres.COUNTRY = Convert.ToString(mailcountrycode);

                    string mobwithcode = Convert.ToString(personInformation.ContactInformation.MobileNumbers.MobileNumber[0]);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.MOBILECODE = mobwithcode.Substring(1, 3);
                            addres.MOBILENO = mobwithcode.Substring(4, mobwithcode.Length - 4); ;
                        }
                        else
                        { addres.MOBILENO = mobwithcode; }
                    }

                    mobwithcode = Convert.ToString(personInformation.ContactInformation.PhoneNumber[0].Phone);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.PHONECODE = mobwithcode.Substring(1, 3);
                            addres.PhoneNo = mobwithcode.Substring(4, mobwithcode.Length - 4);
                        }
                        else
                        { addres.PhoneNo = mobwithcode; }
                    }

                    mobwithcode = Convert.ToString(personInformation.ContactInformation.FaxNumbers.FaxNumber);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.FAXCODE = mobwithcode.Substring(1, 3);
                            addres.FaxNo = mobwithcode.Substring(4, mobwithcode.Length - 4);
                        }
                        else
                        { addres.FaxNo = mobwithcode; }
                    }

                    addres.PERSONAL_EMAIL = Convert.ToString(personInformation.ContactInformation.EMailIAddresses[0].Address);
                    addres.OfficeEmailId = Convert.ToString(personInformation.ContactInformation.EMailIAddresses[0].SecondaryAddress);

                    AddressDetails.Add(addres);
                }
            }
            /*Adding Office Address*/
            if (response.MessageResponseBody != null && response.MessageResponseBody.CustomersDetails.CustomerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress != null)
            {
                CAS_CustomerAddressDetails addres = new CAS_CustomerAddressDetails();
                {
                    addres.ApplicantName = "";
                    addres.ADDRESS_TYPE = "Office Address";
                    addres.Address_1 = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress[0].AddressLine[0].AddressLine1);
                    addres.Address_2 = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress[0].AddressLine[0].AddressLine2);
                    addres.Address_3 = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress[0].AddressLine[0].AddressLine3);
                    addres.Address_4 = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress[0].AddressLine[0].AddressLine4);
                    addres.CustomerPreferences = Convert.ToString(customerInformation[0].CustomerPreference);
                    addres.BuildingDetails = "";
                    addres.FlatOrOfficeDetails = "";
                    addres.POBOX = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress[0].POBoxNumber);
                    addres.CITY = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress[0].City);
                    addres.State = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress[0].State);
                    string officecountrycode = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.OfficialContactInformation.PostalAddress[0].Country);
                    officecountrycode = _DS.Tables[0].AsEnumerable().Where(row => row.Field<string>("Country_Code") == officecountrycode) // Filter the rows
                    .Select(row => row.Field<string>("Country_name"))
                    .FirstOrDefault();
                    addres.COUNTRY = Convert.ToString(officecountrycode);
                    addres.ReferenceName_1 = "";
                    addres.RefPhNo_1 = "";
                    addres.ReferenceName_2 = "";
                    addres.RefPhNo_2 = "";
                    addres.ReferenceName_3 = "";
                    addres.RefPhNo_3 = "";
                    addres.ReferenceName_4 = "";
                    addres.RefPhNo_4 = "";
                };
                if (personInformation != null)
                {
                    string mobwithcode = Convert.ToString(personInformation.ContactInformation.MobileNumbers.MobileNumber[0]);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.MOBILECODE = mobwithcode.Substring(1, 3);
                            addres.MOBILENO = mobwithcode.Substring(4, mobwithcode.Length - 4); ;
                        }
                        else
                        { addres.MOBILENO = mobwithcode; }
                    }

                    mobwithcode = Convert.ToString(personInformation.ContactInformation.PhoneNumber[0].Phone);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.PHONECODE = mobwithcode.Substring(1, 3);
                            addres.PhoneNo = mobwithcode.Substring(4, mobwithcode.Length - 4);
                        }
                        else
                        { addres.PhoneNo = mobwithcode; }
                    }

                    mobwithcode = Convert.ToString(personInformation.ContactInformation.FaxNumbers.FaxNumber);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.FAXCODE = mobwithcode.Substring(1, 3);
                            addres.FaxNo = mobwithcode.Substring(4, mobwithcode.Length - 4);
                        }
                        else
                        { addres.FaxNo = mobwithcode; }
                    }

                    addres.PERSONAL_EMAIL = Convert.ToString(personInformation.ContactInformation.EMailIAddresses[0].Address);
                    addres.OfficeEmailId = Convert.ToString(personInformation.ContactInformation.EMailIAddresses[0].SecondaryAddress);
                }
                AddressDetails.Add(addres);
            }
            /*Adding HC Address*/
            cAS_CustomerDetailsModel.Addresses = AddressDetails;
            if (passportInfo != null && passportInfo.PostalAddress != null)
            {
                CAS_CustomerAddressDetails addres = new CAS_CustomerAddressDetails();
                addres.ApplicantName = "";
                addres.ADDRESS_TYPE = "HC Address";
                addres.Address_1 = Convert.ToString(passportInfo.PostalAddress.AddressLine[0].AddressLine1);
                addres.Address_2 = Convert.ToString(passportInfo.PostalAddress.AddressLine[0].AddressLine2);
                addres.Address_3 = Convert.ToString(passportInfo.PostalAddress.AddressLine[0].AddressLine3);
                addres.Address_4 = Convert.ToString(passportInfo.PostalAddress.AddressLine[0].AddressLine4);
                addres.CustomerPreferences = Convert.ToString(customerInformation[0].CustomerPreference);
                addres.BuildingDetails = "";
                addres.FlatOrOfficeDetails = "";
                addres.POBOX = Convert.ToString(passportInfo.PostalAddress.POBoxNumber);
                addres.CITY = Convert.ToString(passportInfo.PostalAddress.City);
                addres.State = Convert.ToString(passportInfo.PostalAddress.State);
                string hccountrycode = Convert.ToString(passportInfo.PostalAddress.Country);
                hccountrycode = _DS.Tables[0].AsEnumerable().Where(row => row.Field<string>("Country_Code") == hccountrycode) // Filter the rows
                .Select(row => row.Field<string>("Country_name"))
                .FirstOrDefault();
                addres.COUNTRY = Convert.ToString(hccountrycode);
                addres.ReferenceName_1 = "";
                addres.RefPhNo_1 = "";
                addres.ReferenceName_2 = "";
                addres.RefPhNo_2 = "";
                addres.ReferenceName_3 = "";
                addres.RefPhNo_3 = "";
                addres.ReferenceName_4 = "";
                addres.RefPhNo_4 = "";

                if (personInformation != null)
                {
                    string mobwithcode = Convert.ToString(personInformation.ContactInformation.MobileNumbers.MobileNumber[0]);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.MOBILECODE = mobwithcode.Substring(1, 3);
                            addres.MOBILENO = mobwithcode.Substring(4, mobwithcode.Length - 4); ;
                        }
                        else
                        { addres.MOBILENO = mobwithcode; }
                    }

                    mobwithcode = Convert.ToString(personInformation.ContactInformation.PhoneNumber[0].Phone);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.PHONECODE = mobwithcode.Substring(1, 3);
                            addres.PhoneNo = mobwithcode.Substring(4, mobwithcode.Length - 4);
                        }
                        else
                        { addres.PhoneNo = mobwithcode; }
                    }

                    mobwithcode = Convert.ToString(personInformation.ContactInformation.FaxNumbers.FaxNumber);
                    if (!string.IsNullOrEmpty(mobwithcode))
                    {
                        if (mobwithcode.Contains("+"))
                        {
                            addres.FAXCODE = mobwithcode.Substring(1, 3);
                            addres.FaxNo = mobwithcode.Substring(4, mobwithcode.Length - 4);
                        }
                        else
                        { addres.FaxNo = mobwithcode; }
                    }

                    addres.PERSONAL_EMAIL = Convert.ToString(personInformation.ContactInformation.EMailIAddresses[0].Address);
                    addres.OfficeEmailId = Convert.ToString(personInformation.ContactInformation.EMailIAddresses[0].SecondaryAddress);
                }

                AddressDetails.Add(addres);
            }

            /*Adding Customer Details*/
            if (personInformation != null)
            {
                customerDetails = new CAS_CustomerDetails();
                // customerDetails = new CAS_CustomerDetails
                customerDetails.ApplicantType = "";
                customerDetails.CoApplicant = "";
                customerDetails.CustomerTitle = Convert.ToString(personInformation.PersonName[0].TitlePrefix);
                customerDetails.CustomerFullName = Convert.ToString(personInformation.PersonName[0].FullName);
                customerDetails.CustomerFirstName = Convert.ToString(personInformation.PersonName[0].FirstName);
                customerDetails.CustomerMiddleName = Convert.ToString(personInformation.PersonName[0].MiddleName[0]);
                customerDetails.CustomerLastName = Convert.ToString(personInformation.PersonName[0].LastName[0]);
                customerDetails.Gender = Convert.ToString(personInformation.Gender);
                customerDetails.DOB = Convert.ToString(personInformation.DateOfBirth);
                customerDetails.Age = "";
                customerDetails.MaritalStatus = Convert.ToString(personInformation.MaritalStatus);
                customerDetails.Dependents = Convert.ToString(personInformation.DependentInformation.NoOfDependents);
                customerDetails.ResidencyType = "";
                customerDetails.Education = "";
                customerDetails.Relation = "";
                customerDetails.CountryOfResidency = Convert.ToString(personInformation.CountryOfResidence);
                customerDetails.NoOfYearsInUAEMonths = "0"; // added by deepak as defadult
                customerDetails.Minor = Convert.ToString(personInformation.IsMinor);
                customerDetails.Guardian = "";
                customerDetails.RelationWithMinor = "";
                customerDetails.LifeTakafulRequired = "";
                customerDetails.PlaceOfBirth = Convert.ToString(personInformation.BirthCountry);
                customerDetails.Nationality = Convert.ToString(personInformation.Nationality);
                customerDetails.PassportNo = Convert.ToString(passportInfo.PassportNumber);
                customerDetails.VisaNo = Convert.ToString(personInformation.VisaDetails[0].VisaNo);
                customerDetails.VisaIssueDate = Convert.ToString(personInformation.VisaDetails[0].VisaIssueDate);
                customerDetails.VisaExpiryDate = Convert.ToString(personInformation.VisaDetails[0].VisaExpDate);
                customerDetails.HousingAllowanceMonthly = "";
                customerDetails.AnnualBonus = "";
                customerDetails.AnnualRentalIncome = "";

                if (customerDetails.MaritalStatus == "M")
                { customerDetails.MaritalStatus = "Married"; }
                else if (customerDetails.MaritalStatus == "S")
                {
                    customerDetails.MaritalStatus = "Single";
                }
                else if (customerDetails.MaritalStatus == "D")
                { customerDetails.MaritalStatus = "Divorced"; }
                else if (customerDetails.MaritalStatus == "W")
                { customerDetails.MaritalStatus = "Widow"; }

                //PersonInformation personInformation = customerInformation[0].Item as PersonInformation;
                if (customerInformation != null)
                {
                    FATCAInformationTypeIndividualFATCAInformations individualFATCAInformationType = customerInformation[0].FATCAInformation.Item as FATCAInformationTypeIndividualFATCAInformations;
                    //FATCAInformationTypeIndividualFATCAInformations individualFATCAInformationType1 = customerInformation[0].FATCAInformation.Item as FATCAInformationTypeCorporateFATCAInformations;

                    if (Convert.ToString(individualFATCAInformationType.IndividualFATCAInformation[0].NonUAEResident) == "R" && customerInformation[0].CustomerType.ToString() == "I")
                    {
                        customerDetails.ResidencyType = "Resident";
                    }
                    else if (Convert.ToString(individualFATCAInformationType.IndividualFATCAInformation[0].NonUAEResident) == "N" && customerInformation[0].CustomerType.ToString() == "I")
                    {
                        customerDetails.ResidencyType = "Non-Resident";
                    }
                    else if (Convert.ToString(individualFATCAInformationType.IndividualFATCAInformation[0].NonUAEResident) == "N" && customerInformation[0].CustomerType.ToString() == "C")
                    {
                        customerDetails.ResidencyType = "Non-Resident - Company";
                    }
                    else if (Convert.ToString(individualFATCAInformationType.IndividualFATCAInformation[0].NonUAEResident) == "R" && customerInformation[0].CustomerType.ToString() == "C")
                    {
                        customerDetails.ResidencyType = "Resident - Company";
                    }

                    cAS_CustomerDetailsModel.CustomerID = customerInformation[0].CustomerId;
                    customerDetails.FixedSalaryMonthly = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.SalaryDetails.MonthlySalary);

                    customerDetails.OtherIncomeMonthly = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.SalaryDetails.OtherExpenses);
                }
                string countrycode = Convert.ToString(personInformation.Nationality);
                var countryname = _DS.Tables[0].AsEnumerable().Where(row => row.Field<string>("Country_Code") == countrycode) // Filter the rows
                .Select(row => row.Field<string>("Country_name"))
                .FirstOrDefault();

                customerDetails.Nationality = countryname.ToString();

                countrycode = Convert.ToString(personInformation.CountryOfResidence);
                countryname = _DS.Tables[0].AsEnumerable().Where(row => row.Field<string>("Country_Code") == countrycode) // Filter the rows
                .Select(row => row.Field<string>("Country_name"))
                .FirstOrDefault();

                customerDetails.CountryOfResidency = countryname.ToString();

                string dobdate = Convert.ToString(personInformation.DateOfBirth);
                customerDetails.DOB = DateTime.ParseExact(dobdate, "yyyymmdd", CultureInfo.InvariantCulture).ToString("dd/mm/yyyy");

                dobdate = Convert.ToString(passportInfo.IssueDate);
                customerDetails.PassportIssueDate = DateTime.ParseExact(dobdate, "yyyymmdd", CultureInfo.InvariantCulture).ToString("dd/mm/yyyy");

                dobdate = Convert.ToString(passportInfo.ExpireDate);
                customerDetails.PassportExpiryDate = DateTime.ParseExact(dobdate, "yyyymmdd", CultureInfo.InvariantCulture).ToString("dd/mm/yyyy");

                string mob = Convert.ToString(personInformation.ContactInformation.MobileNumbers.MobileNumber[0]);
                if (!string.IsNullOrEmpty(mob))
                {
                    if (mob.Contains("+"))
                    {
                        customerDetails.MobileCode = mob.Substring(1, 3);
                        customerDetails.MobileNo = mob.Substring(4, mob.Length - 4);
                    }
                    else
                    { customerDetails.MobileNo = mob; }
                }

                cAS_CustomerDetailsModel.CustomerDetails = customerDetails;

                /*Adding customer Id details*/
                if (personInformation.NationId != null)
                {
                    string IDIssueCountry = Convert.ToString(personInformation.Nationality);
                    IDIssueCountry = _DS.Tables[0].AsEnumerable().Where(row => row.Field<string>("Country_Code") == IDIssueCountry) // Filter the rows
                    .Select(row => row.Field<string>("Country_name"))
                    .FirstOrDefault();

                    customerIdDetail = new CAS_CustomerIdDetails
                    {
                        ApplicantName = "",
                        ID_TYPE = "EMIRATES ID",
                        ID_NAME = "",
                        ID_NO = Convert.ToString(personInformation.NationId),
                        ID_ISSUEDATE_MOD = Convert.ToString(personInformation.NationIdIssueDate),
                        ID_EXPDATE_MOD = Convert.ToString(personInformation.NationIdExpiryDate),
                        ID_ISSUEPLACE = Convert.ToString(passportInfo.IssueLocation),
                        ID_ISSUECOUNTRY = Convert.ToString(IDIssueCountry),
                    };

                    customerIdDetails.Add(customerIdDetail);
                }
                if (passportInfo != null)
                {
                    string IDIssueCountry = Convert.ToString(personInformation.Nationality);
                    IDIssueCountry = _DS.Tables[0].AsEnumerable().Where(row => row.Field<string>("Country_Code") == IDIssueCountry) // Filter the rows
                    .Select(row => row.Field<string>("Country_name"))
                    .FirstOrDefault();

                    customerIdDetail = new CAS_CustomerIdDetails
                    {
                        ApplicantName = "",
                        ID_TYPE = "Passport",
                        ID_NAME = "",
                        ID_NO = Convert.ToString(passportInfo.PassportNumber),
                        ID_ISSUEDATE_MOD = Convert.ToString(passportInfo.IssueDate),
                        ID_EXPDATE_MOD = Convert.ToString(passportInfo.ExpireDate),
                        ID_ISSUEPLACE = Convert.ToString(passportInfo.IssueLocation),
                        ID_ISSUECOUNTRY = Convert.ToString(IDIssueCountry),
                    };

                    customerIdDetails.Add(customerIdDetail);
                }

                cAS_CustomerDetailsModel.CustomerIdDetails = customerIdDetails;
            }
            /*Adding Employement details*/
            if (customerInformation != null)
            {
                if (customerInformation[0].CustomerProfileInformation != null && customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo != null)
                {
                    /*Checking Salaried Employee*/
                    if (customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.SalaryDetails != null)
                    {
                        customerEmployementDetails = new CAS_CustomerEmployementDetails();

                        customerEmployementDetails.ApplicantName = "";
                        customerEmployementDetails.EMPLOYEMENTTYPE = "Salaried";
                        customerEmployementDetails.CurrentJOB = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.Designation.CurrentDesignation);
                        customerEmployementDetails.DOJ_MOD = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.DateOfJoining);
                        customerEmployementDetails.ENDDATE_MOD = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.LastWorkingDay);
                        if (customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.EmployerContact != null)
                        { customerEmployementDetails.IndustryOrLineOfBusiness = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.EmployerContact.ContactName); }
                        else { customerEmployementDetails.IndustryOrLineOfBusiness = ""; }
                        customerEmployementDetails.TypeOfCompany = "0";
                        customerEmployementDetails.Country = "0";
                        customerEmployementDetails.Emirates = "0";
                        customerEmployementDetails.NTMLChecks = "false";

                        customerEmployementDetails.TMLEmployerName = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.EmployerName);
                        customerEmployementDetails.NTMLEmployerName = "";
                        customerEmployementDetails.OccupationType = "";
                        if (customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.Designation != null)
                        { customerEmployementDetails.Designation = Convert.ToString(customerInformation[0].CustomerProfileInformation.CurrentEmployerInfo.Designation.CurrentDesignation); }
                        else { customerEmployementDetails.Designation = ""; }
                        customerEmployementDetails.OTHERS_DESIGNATION = "";
                        customerEmployementDetails.LengthOfService = "";
                        customerEmployementDetails.EmployerCategory = "";
                        customerEmployementDetails.EmployerRemarks = "";
                        customerEmployementDetails.Industry = "0";
                        customerEmployementDetails.BUSSINESSNAME = "";
                        customerEmployementDetails.NatureOfBusiness = "0";
                        customerEmployementDetails.CapitalSharePerc = "";
                        customerEmployementDetails.ProfitSharePerc = "";
                        customerEmployementDetails.AuditFirm = "0";
                        customerEmployementDetails.AuditCategory = "";
                        customerEmployementDetails.EstablishmentDate = "";
                        customerEmployementDetails.LengthOfBussiness = "";
                        customerEmployementDetails.TradeLicenseExpiryDate = "";

                        EmpDetails.Add(customerEmployementDetails);
                    }
                    else
                    {
                        customerEmployementDetails = new CAS_CustomerEmployementDetails();

                        customerEmployementDetails.ApplicantName = "";
                        customerEmployementDetails.EMPLOYEMENTTYPE = "Self-Employed";
                        customerEmployementDetails.CurrentJOB = "";
                        customerEmployementDetails.DOJ_MOD = "";
                        customerEmployementDetails.ENDDATE_MOD = "";
                        customerEmployementDetails.IndustryOrLineOfBusiness = "";
                        customerEmployementDetails.TypeOfCompany = "0";
                        customerEmployementDetails.Country = "0";
                        customerEmployementDetails.Emirates = "0";
                        customerEmployementDetails.NTMLChecks = "false";
                        customerEmployementDetails.TMLEmployerName = "";
                        customerEmployementDetails.NTMLEmployerName = "";
                        customerEmployementDetails.OccupationType = "";
                        customerEmployementDetails.Designation = "";
                        customerEmployementDetails.OTHERS_DESIGNATION = "";
                        customerEmployementDetails.LengthOfService = "";
                        customerEmployementDetails.EmployerCategory = "";
                        customerEmployementDetails.EmployerRemarks = "";
                        customerEmployementDetails.Industry = "0";
                        customerEmployementDetails.BUSSINESSNAME = "";
                        customerEmployementDetails.NatureOfBusiness = "0";
                        customerEmployementDetails.CapitalSharePerc = "";
                        customerEmployementDetails.ProfitSharePerc = "";
                        customerEmployementDetails.AuditFirm = "0";
                        customerEmployementDetails.AuditCategory = "";
                        customerEmployementDetails.EstablishmentDate = "";
                        customerEmployementDetails.LengthOfBussiness = "";
                        customerEmployementDetails.TradeLicenseExpiryDate = "";

                        EmpDetails.Add(customerEmployementDetails);
                    }

                    /*Adding Previous Employer detials*/
                    if (customerInformation[0].CustomerProfileInformation != null &&
                        customerInformation[0].CustomerProfileInformation.PreviousEmployersDetails != null &&
                        customerInformation[0].CustomerProfileInformation.PreviousEmployersDetails[0].Designation != null)
                    {
                        customerEmployementDetails = new CAS_CustomerEmployementDetails();

                        customerEmployementDetails.ApplicantName = "";
                        customerEmployementDetails.EMPLOYEMENTTYPE = "";
                        customerEmployementDetails.CurrentJOB = "";
                        customerEmployementDetails.DOJ_MOD = "";
                        customerEmployementDetails.ENDDATE_MOD = "";
                        customerEmployementDetails.IndustryOrLineOfBusiness = "";
                        customerEmployementDetails.TypeOfCompany = "0";
                        customerEmployementDetails.Country = "0";
                        customerEmployementDetails.Emirates = "0";
                        customerEmployementDetails.NTMLChecks = "false";
                        customerEmployementDetails.TMLEmployerName =
                            Convert.ToString(customerInformation[0].CustomerProfileInformation.PreviousEmployersDetails[0].EmployerName);
                        customerEmployementDetails.NTMLEmployerName = "";
                        customerEmployementDetails.OccupationType = "";
                        customerEmployementDetails.Designation =
                            Convert.ToString(customerInformation[0].CustomerProfileInformation.PreviousEmployersDetails[0].Designation.CurrentDesignation);
                        customerEmployementDetails.OTHERS_DESIGNATION = "";
                        customerEmployementDetails.LengthOfService = "";
                        customerEmployementDetails.EmployerCategory = "";
                        customerEmployementDetails.EmployerRemarks = "";
                        customerEmployementDetails.Industry = "0";
                        customerEmployementDetails.BUSSINESSNAME = "";
                        customerEmployementDetails.NatureOfBusiness = "0";
                        customerEmployementDetails.CapitalSharePerc = "";
                        customerEmployementDetails.ProfitSharePerc = "";
                        customerEmployementDetails.AuditFirm = "0";
                        customerEmployementDetails.AuditCategory = "";
                        customerEmployementDetails.EstablishmentDate = "";
                        customerEmployementDetails.LengthOfBussiness = "";
                        customerEmployementDetails.TradeLicenseExpiryDate = "";

                        EmpDetails.Add(customerEmployementDetails);
                    }

                    cAS_CustomerDetailsModel.CustomerEmployementDetails = EmpDetails;
                }
            }
            //INSERT_UPDATE_CUSTOMER_DETAILS(objCustomerdetail);
            UPDATE_SOA_RESPONSE(request.MessageRequestBody.QueryCustomers[0].XRef, xmlResponse, "RESP-0000# Response Received # Success", pUserId, "", "", soaLogSrNo);
        }
        else
        {
            UPDATE_SOA_RESPONSE(request.MessageRequestBody.QueryCustomers[0].XRef, xmlResponse, "RESP-0001# Response Received with Error # Failure", pUserId, "", "", soaLogSrNo);
        }
    }
}

USE [LMS_DEV]
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ApplyMasking BIT = 0;
DECLARE @NameCellCount BIGINT;
DECLARE @CountryCount INT;
DECLARE @RowsAffected INT;

IF DB_NAME() <> N'LMS_DEV'
BEGIN
    RAISERROR('Masking stopped: this script is restricted to LMS_DEV. Update the database guard only after confirming the target is an isolated copy.', 16, 1);
    RETURN;
END;

IF OBJECT_ID(N'dbo.CORE_FLEX_ALL_APPS_MASTER', N'U') IS NULL
BEGIN
    RAISERROR('Masking stopped: dbo.CORE_FLEX_ALL_APPS_MASTER does not exist in LMS_DEV.', 16, 1);
    RETURN;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.CORE_FLEX_ALL_APPS_MASTER
    WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(200), APPLICATIONID))), N'') IS NULL
)
BEGIN
    RAISERROR('Masking stopped: every row must have an APPLICATIONID so substitutions can be applied safely.', 16, 1);
    RETURN;
END;

IF EXISTS
(
    SELECT APPLICATIONID
    FROM dbo.CORE_FLEX_ALL_APPS_MASTER
    GROUP BY APPLICATIONID
    HAVING COUNT_BIG(*) > 1
)
BEGIN
    RAISERROR('Masking stopped: APPLICATIONID must be unique in CORE_FLEX_ALL_APPS_MASTER.', 16, 1);
    RETURN;
END;

SELECT @NameCellCount = COUNT_BIG(*)
FROM
(
    SELECT APPLICATIONID FROM dbo.CORE_FLEX_ALL_APPS_MASTER WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), CUSTOMERNAME1))), N'') IS NOT NULL
    UNION ALL
    SELECT APPLICATIONID FROM dbo.CORE_FLEX_ALL_APPS_MASTER WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), CUSTOMERNAME2))), N'') IS NOT NULL
    UNION ALL
    SELECT APPLICATIONID FROM dbo.CORE_FLEX_ALL_APPS_MASTER WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), CUSTOMERNAME3))), N'') IS NOT NULL
    UNION ALL
    SELECT APPLICATIONID FROM dbo.CORE_FLEX_ALL_APPS_MASTER WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), CUSTOMERNAME4))), N'') IS NOT NULL
    UNION ALL
    SELECT APPLICATIONID FROM dbo.CORE_FLEX_ALL_APPS_MASTER WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), SELLERNAME))), N'') IS NOT NULL
) AS NameCells;

IF @ApplyMasking = 0
BEGIN
    SELECT
        DB_NAME() AS TargetDatabase,
        COUNT_BIG(*) AS RowsInTable,
        @NameCellCount AS UniqueNameSubstitutionsRequired,
        CAST(0 AS BIT) AS ChangesApplied,
        N'Preview only. Set @ApplyMasking = 1 after confirming this is an isolated, backed-up database copy.' AS Message
    FROM dbo.CORE_FLEX_ALL_APPS_MASTER;

    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    CREATE TABLE #MaskRows
    (
        APPLICATIONID NVARCHAR(200) NOT NULL PRIMARY KEY,
        MaskRow BIGINT NOT NULL
    );

    INSERT #MaskRows (APPLICATIONID, MaskRow)
    SELECT
        CONVERT(NVARCHAR(200), APPLICATIONID),
        ROW_NUMBER() OVER (ORDER BY APPLICATIONID)
    FROM dbo.CORE_FLEX_ALL_APPS_MASTER;

    DECLARE @GivenNames TABLE
    (
        NameId INT NOT NULL PRIMARY KEY,
        GivenName NVARCHAR(40) NOT NULL
    );

    DECLARE @FamilyNames TABLE
    (
        NameId INT NOT NULL PRIMARY KEY,
        FamilyName NVARCHAR(40) NOT NULL
    );

    DECLARE @MiddleNames TABLE
    (
        NameId INT NOT NULL PRIMARY KEY,
        MiddleName NVARCHAR(40) NOT NULL
    );

    INSERT @GivenNames (NameId, GivenName)
    VALUES
        (1, N'Amira'), (2, N'Noura'), (3, N'Layan'), (4, N'Sami'), (5, N'Rami'),
        (6, N'Talia'), (7, N'Zayn'), (8, N'Mira'), (9, N'Hana'), (10, N'Kareem'),
        (11, N'Layla'), (12, N'Omar'), (13, N'Salma'), (14, N'Tariq'), (15, N'Yasmin'),
        (16, N'Idris'), (17, N'Noor'), (18, N'Farah'), (19, N'Malik'), (20, N'Leena'),
        (21, N'Ayaan'), (22, N'Dalia'), (23, N'Zoya'), (24, N'Elias'), (25, N'Maya'),
        (26, N'Rayan'), (27, N'Hadi'), (28, N'Nadia'), (29, N'Adam'), (30, N'Lina'),
        (31, N'Samira'), (32, N'Karim'), (33, N'Aisha'), (34, N'Nabil'), (35, N'Sara'),
        (36, N'Farid'), (37, N'Yara'), (38, N'Amin'), (39, N'Rania'), (40, N'Ziad');

    INSERT @FamilyNames (NameId, FamilyName)
    VALUES
        (1, N'Valen'), (2, N'Marlow'), (3, N'Delan'), (4, N'Selim'), (5, N'Kellan'),
        (6, N'Faris'), (7, N'Rowan'), (8, N'Nadir'), (9, N'Sorell'), (10, N'Haddan'),
        (11, N'Vess'), (12, N'Maren'), (13, N'Daven'), (14, N'Rellan'), (15, N'Sahir'),
        (16, N'Karem'), (17, N'Lorne'), (18, N'Tarek'), (19, N'Balian'), (20, N'Khalan'),
        (21, N'Mavri'), (22, N'Ordan'), (23, N'Salek'), (24, N'Jorin'), (25, N'Darzi');

    INSERT @MiddleNames (NameId, MiddleName)
    VALUES
        (1, N'Adel'), (2, N'Basil'), (3, N'Jude'), (4, N'Kamal'), (5, N'Rafi'),
        (6, N'Zaki'), (7, N'Yasir'), (8, N'Iman'), (9, N'Fadi'), (10, N'Rashid'),
        (11, N'Kian'), (12, N'Salim'), (13, N'Aziz'), (14, N'Anwar'), (15, N'Faris'),
        (16, N'Naim'), (17, N'Jamil'), (18, N'Tamir'), (19, N'Zahir'), (20, N'Rayan'),
        (21, N'Kareem'), (22, N'Farid'), (23, N'Idris'), (24, N'Malik'), (25, N'Nabil');

    CREATE TABLE #SyntheticNames
    (
        NameSequence BIGINT NOT NULL PRIMARY KEY,
        FakeName NVARCHAR(100) NOT NULL UNIQUE
    );

    ;WITH NameNumbers AS
    (
        SELECT CONVERT(BIGINT, 1) AS NameSequence
        WHERE @NameCellCount > 0
        UNION ALL
        SELECT NameSequence + 1
        FROM NameNumbers
        WHERE NameSequence < @NameCellCount
    ),
    NameCandidates AS
    (
        SELECT
            numbers.NameSequence,
            CASE
                WHEN numbers.NameSequence <= 1000
                    THEN given.GivenName + N' ' + family.FamilyName
                WHEN numbers.NameSequence <= 26000
                    THEN given.GivenName + N' ' + middle.MiddleName + N' ' + family.FamilyName
                ELSE given.GivenName + N' ' + middle.MiddleName + N' ' + family.FamilyName
                    + N' ' + CONVERT(NVARCHAR(20), numbers.NameSequence)
            END AS FakeName
        FROM NameNumbers AS numbers
        INNER JOIN @GivenNames AS given
            ON given.NameId = CONVERT(INT, ((numbers.NameSequence - 1) % 40) + 1)
        INNER JOIN @FamilyNames AS family
            ON family.NameId = CONVERT(INT, (((numbers.NameSequence - 1) / 40) % 25) + 1)
        INNER JOIN @MiddleNames AS middle
            ON middle.NameId = CONVERT(INT, (((numbers.NameSequence - 1) / 1000) % 25) + 1)
    )
    INSERT #SyntheticNames (NameSequence, FakeName)
    SELECT NameSequence, FakeName
    FROM NameCandidates
    OPTION (MAXRECURSION 0);

    CREATE TABLE #NameAssignments
    (
        APPLICATIONID NVARCHAR(200) NOT NULL,
        NameSlot TINYINT NOT NULL,
        NameSequence BIGINT NOT NULL,
        PRIMARY KEY (APPLICATIONID, NameSlot)
    );

    ;WITH NameCells AS
    (
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID) AS APPLICATIONID, CONVERT(TINYINT, 1) AS NameSlot
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), CUSTOMERNAME1))), N'') IS NOT NULL
        UNION ALL
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID), CONVERT(TINYINT, 2)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), CUSTOMERNAME2))), N'') IS NOT NULL
        UNION ALL
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID), CONVERT(TINYINT, 3)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), CUSTOMERNAME3))), N'') IS NOT NULL
        UNION ALL
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID), CONVERT(TINYINT, 4)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), CUSTOMERNAME4))), N'') IS NOT NULL
        UNION ALL
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID), CONVERT(TINYINT, 5)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), SELLERNAME))), N'') IS NOT NULL
    ),
    NumberedNameCells AS
    (
        SELECT
            APPLICATIONID,
            NameSlot,
            ROW_NUMBER() OVER (ORDER BY APPLICATIONID, NameSlot) AS NameSequence
        FROM NameCells
    )
    INSERT #NameAssignments (APPLICATIONID, NameSlot, NameSequence)
    SELECT APPLICATIONID, NameSlot, NameSequence
    FROM NumberedNameCells;

    DECLARE @CountryPool TABLE
    (
        CountryName NVARCHAR(100) NOT NULL PRIMARY KEY
    );

    INSERT @CountryPool (CountryName)
    VALUES
        (N'Afghanistan'), (N'Albania'), (N'Algeria'), (N'Argentina'), (N'Australia'),
        (N'Austria'), (N'Bahrain'), (N'Bangladesh'), (N'Belgium'), (N'Brazil'),
        (N'Canada'), (N'Chile'), (N'China'), (N'Colombia'), (N'Denmark'),
        (N'Egypt'), (N'Finland'), (N'France'), (N'Germany'), (N'Ghana'),
        (N'Greece'), (N'India'), (N'Indonesia'), (N'Iran'), (N'Iraq'),
        (N'Ireland'), (N'Italy'), (N'Japan'), (N'Jordan'), (N'Kenya'),
        (N'Kuwait'), (N'Lebanon'), (N'Malaysia'), (N'Mexico'), (N'Morocco'),
        (N'Nepal'), (N'Netherlands'), (N'New Zealand'), (N'Nigeria'), (N'Oman'),
        (N'Pakistan'), (N'Philippines'), (N'Poland'), (N'Portugal'), (N'Qatar'),
        (N'Romania'), (N'Russia'), (N'Saudi Arabia'), (N'Singapore'), (N'South Africa'),
        (N'South Korea'), (N'Spain'), (N'Sri Lanka'), (N'Sweden'), (N'Switzerland'),
        (N'Syria'), (N'Thailand'), (N'Tunisia'), (N'Turkey'), (N'Ukraine'),
        (N'United Arab Emirates'), (N'United Kingdom'), (N'United States'),
        (N'Uzbekistan'), (N'Vietnam'), (N'Yemen');

    SELECT @CountryCount = COUNT(*) FROM @CountryPool;

    CREATE TABLE #CountryAssignments
    (
        APPLICATIONID NVARCHAR(200) NOT NULL,
        CountrySlot TINYINT NOT NULL,
        CountryName NVARCHAR(100) NOT NULL,
        PRIMARY KEY (APPLICATIONID, CountrySlot)
    );

    ;WITH CountryCells AS
    (
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID) AS APPLICATIONID, CONVERT(TINYINT, 1) AS CountrySlot
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), NATIONALITY2))), N'') IS NOT NULL
        UNION ALL
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID), CONVERT(TINYINT, 2)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), NATIONALITY3))), N'') IS NOT NULL
        UNION ALL
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID), CONVERT(TINYINT, 3)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), NATIONALITY4))), N'') IS NOT NULL
        UNION ALL
        SELECT CONVERT(NVARCHAR(200), APPLICATIONID), CONVERT(TINYINT, 4)
        FROM dbo.CORE_FLEX_ALL_APPS_MASTER
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), MAILING_COUNTRY))), N'') IS NOT NULL
    ),
    NumberedCountryCells AS
    (
        SELECT
            APPLICATIONID,
            CountrySlot,
            ROW_NUMBER() OVER (ORDER BY NEWID()) AS CountrySequence
        FROM CountryCells
    ),
    RandomizedCountries AS
    (
        SELECT
            CountryName,
            ROW_NUMBER() OVER (ORDER BY NEWID()) AS CountrySequence
        FROM @CountryPool
    )
    INSERT #CountryAssignments (APPLICATIONID, CountrySlot, CountryName)
    SELECT cells.APPLICATIONID, cells.CountrySlot, countries.CountryName
    FROM NumberedCountryCells AS cells
    INNER JOIN RandomizedCountries AS countries
        ON countries.CountrySequence = ((cells.CountrySequence - 1) % @CountryCount) + 1;

    UPDATE master
    SET
        CUSTOMERID = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.CUSTOMERID))), N'') IS NULL
            THEN master.CUSTOMERID ELSE CONVERT(VARCHAR(20), 100000000 + (rows.MaskRow % 800000000)) END,
        CUSTOMERNAME1 = COALESCE(name1.FakeName, master.CUSTOMERNAME1),
        CUSTOMERNAME2 = COALESCE(name2.FakeName, master.CUSTOMERNAME2),
        CUSTOMERNAME3 = COALESCE(name3.FakeName, master.CUSTOMERNAME3),
        CUSTOMERNAME4 = COALESCE(name4.FakeName, master.CUSTOMERNAME4),
        DATEOFBIRTH1 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.DATEOFBIRTH1))), N'') IS NULL
            THEN master.DATEOFBIRTH1 ELSE CONVERT(CHAR(10), DATEADD(DAY, CONVERT(INT, (rows.MaskRow * 37) % 12000), CONVERT(DATE, '19700101')), 23) END,
        DATEOFBIRTH2 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.DATEOFBIRTH2))), N'') IS NULL
            THEN master.DATEOFBIRTH2 ELSE CONVERT(CHAR(10), DATEADD(DAY, CONVERT(INT, (rows.MaskRow * 37 + 211) % 12000), CONVERT(DATE, '19700101')), 23) END,
        DATEOFBIRTH3 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.DATEOFBIRTH3))), N'') IS NULL
            THEN master.DATEOFBIRTH3 ELSE CONVERT(CHAR(10), DATEADD(DAY, CONVERT(INT, (rows.MaskRow * 37 + 422) % 12000), CONVERT(DATE, '19700101')), 23) END,
        DATEOFBIRTH4 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.DATEOFBIRTH4))), N'') IS NULL
            THEN master.DATEOFBIRTH4 ELSE CONVERT(CHAR(10), DATEADD(DAY, CONVERT(INT, (rows.MaskRow * 37 + 633) % 12000), CONVERT(DATE, '19700101')), 23) END,
        PASSPORTNUMBER = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.PASSPORTNUMBER))), N'') IS NULL
            THEN master.PASSPORTNUMBER ELSE N'TSTP' + CONVERT(NVARCHAR(20), rows.MaskRow) END,
        NATIONALITY2 = COALESCE(country2.CountryName, master.NATIONALITY2),
        NATIONALITY3 = COALESCE(country3.CountryName, master.NATIONALITY3),
        NATIONALITY4 = COALESCE(country4.CountryName, master.NATIONALITY4),
        PROPERTYDETAILS = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.PROPERTYDETAILS))), N'') IS NULL
            THEN master.PROPERTYDETAILS ELSE N'Unit ' + CONVERT(NVARCHAR(20), rows.MaskRow) + N', Synthetic District ' + CONVERT(NVARCHAR(20), rows.MaskRow) END,
        MOBILENUMBER = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.MOBILENUMBER))), N'') IS NULL
            THEN master.MOBILENUMBER ELSE N'000' + RIGHT(N'0000000' + CONVERT(NVARCHAR(20), rows.MaskRow), 7) END,
        MAILING_COUNTRY = COALESCE(mailCountry.CountryName, master.MAILING_COUNTRY),
        CURRENTEMPLOYER1 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.CURRENTEMPLOYER1))), N'') IS NULL THEN master.CURRENTEMPLOYER1 ELSE CASE CONVERT(INT, rows.MaskRow % 8) WHEN 0 THEN N'Northstar Services' WHEN 1 THEN N'Bluehaven Trading' WHEN 2 THEN N'Cedar Bay Logistics' WHEN 3 THEN N'Summit Grove Consulting' WHEN 4 THEN N'Silverline Systems' WHEN 5 THEN N'Oakbridge Retail' WHEN 6 THEN N'Westmere Solutions' ELSE N'Pinecrest Partners' END END,
        CURRENTEMPLOYER2 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.CURRENTEMPLOYER2))), N'') IS NULL THEN master.CURRENTEMPLOYER2 ELSE CASE CONVERT(INT, (rows.MaskRow + 2) % 8) WHEN 0 THEN N'Northstar Services' WHEN 1 THEN N'Bluehaven Trading' WHEN 2 THEN N'Cedar Bay Logistics' WHEN 3 THEN N'Summit Grove Consulting' WHEN 4 THEN N'Silverline Systems' WHEN 5 THEN N'Oakbridge Retail' WHEN 6 THEN N'Westmere Solutions' ELSE N'Pinecrest Partners' END END,
        CURRENTEMPLOYER3 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.CURRENTEMPLOYER3))), N'') IS NULL THEN master.CURRENTEMPLOYER3 ELSE CASE CONVERT(INT, (rows.MaskRow + 4) % 8) WHEN 0 THEN N'Northstar Services' WHEN 1 THEN N'Bluehaven Trading' WHEN 2 THEN N'Cedar Bay Logistics' WHEN 3 THEN N'Summit Grove Consulting' WHEN 4 THEN N'Silverline Systems' WHEN 5 THEN N'Oakbridge Retail' WHEN 6 THEN N'Westmere Solutions' ELSE N'Pinecrest Partners' END END,
        CURRENTEMPLOYER4 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.CURRENTEMPLOYER4))), N'') IS NULL THEN master.CURRENTEMPLOYER4 ELSE CASE CONVERT(INT, (rows.MaskRow + 6) % 8) WHEN 0 THEN N'Northstar Services' WHEN 1 THEN N'Bluehaven Trading' WHEN 2 THEN N'Cedar Bay Logistics' WHEN 3 THEN N'Summit Grove Consulting' WHEN 4 THEN N'Silverline Systems' WHEN 5 THEN N'Oakbridge Retail' WHEN 6 THEN N'Westmere Solutions' ELSE N'Pinecrest Partners' END END,
        EMPLOYMENTTYPE = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.EMPLOYMENTTYPE))), N'') IS NULL THEN master.EMPLOYMENTTYPE ELSE CASE CONVERT(INT, rows.MaskRow % 5) WHEN 0 THEN N'Salaried' WHEN 1 THEN N'Self-Employed' WHEN 2 THEN N'Business Owner' WHEN 3 THEN N'Contractor' ELSE N'Consultant' END END,
        RESI_TEL_CODE = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.RESI_TEL_CODE))), N'') IS NULL THEN master.RESI_TEL_CODE ELSE N'000' END,
        RESI_TEL_NUM = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.RESI_TEL_NUM))), N'') IS NULL
            THEN master.RESI_TEL_NUM ELSE N'000' + RIGHT(N'0000000' + CONVERT(NVARCHAR(20), rows.MaskRow + 1), 7) END,
        MAILING_POBOX = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.MAILING_POBOX))), N'') IS NULL
            THEN master.MAILING_POBOX ELSE N'TEST-' + CONVERT(NVARCHAR(20), rows.MaskRow) END,
        HC_TEL_CODE = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.HC_TEL_CODE))), N'') IS NULL THEN master.HC_TEL_CODE ELSE N'000' END,
        HC_TEL_NUM = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.HC_TEL_NUM))), N'') IS NULL
            THEN master.HC_TEL_NUM ELSE N'000' + RIGHT(N'0000000' + CONVERT(NVARCHAR(20), rows.MaskRow + 2), 7) END,
        SELLERNAME = COALESCE(seller.FakeName, master.SELLERNAME),
        DEVELOPER = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.DEVELOPER))), N'') IS NULL THEN master.DEVELOPER ELSE CASE CONVERT(INT, rows.MaskRow % 8) WHEN 0 THEN N'Northstar Developments' WHEN 1 THEN N'Bluehaven Properties' WHEN 2 THEN N'Cedar Bay Estates' WHEN 3 THEN N'Summit Grove Homes' WHEN 4 THEN N'Silverline Communities' WHEN 5 THEN N'Oakbridge Living' WHEN 6 THEN N'Westmere Developments' ELSE N'Pinecrest Properties' END END,
        OFFICE_TEL_CODE = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.OFFICE_TEL_CODE))), N'') IS NULL THEN master.OFFICE_TEL_CODE ELSE N'000' END,
        FAX_NUMBER = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.FAX_NUMBER))), N'') IS NULL
            THEN master.FAX_NUMBER ELSE N'000' + RIGHT(N'0000000' + CONVERT(NVARCHAR(20), rows.MaskRow + 3), 7) END,
        OFFICE_TEL_NUM = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.OFFICE_TEL_NUM))), N'') IS NULL
            THEN master.OFFICE_TEL_NUM ELSE N'000' + RIGHT(N'0000000' + CONVERT(NVARCHAR(20), rows.MaskRow + 4), 7) END,
        PERSONAL_EMAIL = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.PERSONAL_EMAIL))), N'') IS NULL
            THEN master.PERSONAL_EMAIL ELSE N'user' + CONVERT(NVARCHAR(20), rows.MaskRow) + N'@example.invalid' END,
        OFFICE_EMAIL = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.OFFICE_EMAIL))), N'') IS NULL
            THEN master.OFFICE_EMAIL ELSE N'work' + CONVERT(NVARCHAR(20), rows.MaskRow) + N'@example.invalid' END,
        EDUCATION4 = CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(4000), master.EDUCATION4))), N'') IS NULL THEN master.EDUCATION4 ELSE CASE CONVERT(INT, rows.MaskRow % 5) WHEN 0 THEN N'Bachelor Degree' WHEN 1 THEN N'Master Degree' WHEN 2 THEN N'Diploma' WHEN 3 THEN N'Professional Certificate' ELSE N'High School' END END
    FROM dbo.CORE_FLEX_ALL_APPS_MASTER AS master
    INNER JOIN #MaskRows AS rows
        ON rows.APPLICATIONID = master.APPLICATIONID
    LEFT JOIN #NameAssignments AS nameAssignment1
        ON nameAssignment1.APPLICATIONID = rows.APPLICATIONID AND nameAssignment1.NameSlot = 1
    LEFT JOIN #SyntheticNames AS name1
        ON name1.NameSequence = nameAssignment1.NameSequence
    LEFT JOIN #NameAssignments AS nameAssignment2
        ON nameAssignment2.APPLICATIONID = rows.APPLICATIONID AND nameAssignment2.NameSlot = 2
    LEFT JOIN #SyntheticNames AS name2
        ON name2.NameSequence = nameAssignment2.NameSequence
    LEFT JOIN #NameAssignments AS nameAssignment3
        ON nameAssignment3.APPLICATIONID = rows.APPLICATIONID AND nameAssignment3.NameSlot = 3
    LEFT JOIN #SyntheticNames AS name3
        ON name3.NameSequence = nameAssignment3.NameSequence
    LEFT JOIN #NameAssignments AS nameAssignment4
        ON nameAssignment4.APPLICATIONID = rows.APPLICATIONID AND nameAssignment4.NameSlot = 4
    LEFT JOIN #SyntheticNames AS name4
        ON name4.NameSequence = nameAssignment4.NameSequence
    LEFT JOIN #NameAssignments AS sellerAssignment
        ON sellerAssignment.APPLICATIONID = rows.APPLICATIONID AND sellerAssignment.NameSlot = 5
    LEFT JOIN #SyntheticNames AS seller
        ON seller.NameSequence = sellerAssignment.NameSequence
    LEFT JOIN #CountryAssignments AS country2
        ON country2.APPLICATIONID = rows.APPLICATIONID AND country2.CountrySlot = 1
    LEFT JOIN #CountryAssignments AS country3
        ON country3.APPLICATIONID = rows.APPLICATIONID AND country3.CountrySlot = 2
    LEFT JOIN #CountryAssignments AS country4
        ON country4.APPLICATIONID = rows.APPLICATIONID AND country4.CountrySlot = 3
    LEFT JOIN #CountryAssignments AS mailCountry
        ON mailCountry.APPLICATIONID = rows.APPLICATIONID AND mailCountry.CountrySlot = 4;

    SET @RowsAffected = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT
        DB_NAME() AS TargetDatabase,
        @RowsAffected AS RowsUpdated,
        CAST(1 AS BIT) AS ChangesApplied;
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    SELECT
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;
GO

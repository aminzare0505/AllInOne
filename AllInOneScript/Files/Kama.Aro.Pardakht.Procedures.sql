

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spBindEmployeeCatalogToRequest') IS NOT NULL
    DROP PROCEDURE emp.spBindEmployeeCatalogToRequest
GO

CREATE PROCEDURE emp.spBindEmployeeCatalogToRequest  
	@AID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID

	BEGIN TRY
		BEGIN TRAN

		UPDATE [emp].[EmployeeCatalog]
		SET
			EmployeeCatalog.[TreasuryRequestID] = @RequestID
		WHERE [ID] = @ID
	
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spGetEmployeeCatalog') IS NOT NULL
    DROP PROCEDURE emp.spGetEmployeeCatalog
GO

CREATE PROCEDURE emp.spGetEmployeeCatalog
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		ec.ID,
		ec.ApplicantOrganID,
		org.Name ApplicantOrganOrganName,
		ec.[Year],
		ec.[Month],
		ec.[State],
		ec.ProcessingDate,
		ec.TreasuryRequestID,
		flw.Date CreationDate
	FROM emp.EmployeeCatalog ec
		INNER JOIN org.Department org ON org.ID = ec.ApplicantOrganID
		INNER JOIN pbl.DocumentFlow flw ON flw.DocumentID = ec.ID 
			AND flw.FromDocState = 1
			AND flw.ToDocState = 1
	WHERE ec.ID = @ID

END 

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spGetEmployeeCatalogs') IS NOT NULL
    DROP PROCEDURE emp.spGetEmployeeCatalogs
GO

CREATE PROCEDURE emp.spGetEmployeeCatalogs
	@AApplicantOrganID UNIQUEIDENTIFIER,
	@ATreasuryRequestID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@AState TINYINT,
	@AParentApplicantOrganID UNIQUEIDENTIFIER,
	@AWpProvinceID UNIQUEIDENTIFIER,
	@ADepartmentType TINYINT,
	@AApplicantOrganName NVARCHAR(256),

	@AMonths NVARCHAR(MAX),
	@AStates NVARCHAR(MAX),

	@APermissionOrganIDs NVARCHAR(MAX),
	@AApplicantOrganIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX), 
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE 
		@ApplicantOrganID UNIQUEIDENTIFIER = @AApplicantOrganID,
		@TreasuryRequestID UNIQUEIDENTIFIER = @ATreasuryRequestID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@State TINYINT = COALESCE(@AState, 0),

		@ParentApplicantOrganID UNIQUEIDENTIFIER = @AParentApplicantOrganID,
		@ApplicantOrganIDs NVARCHAR(MAX) = @AApplicantOrganIDs,
		@WpProvinceID UNIQUEIDENTIFIER = @AWpProvinceID,
		@ApplicantOrganName NVARCHAR(256) = @AApplicantOrganName,
		@DepartmentType TINYINT = COALESCE(@ADepartmentType, 0),
		@Months NVARCHAR(MAX) = @AMonths,
		@PermissionOrganIDs NVARCHAR(MAX) = @APermissionOrganIDs,
		@States NVARCHAR(MAX) = @AStates,

		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentApplicantOrganNode HIERARCHYID

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SET @ParentApplicantOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentApplicantOrganID)
	
	;WITH Organ AS
	(
		SELECT DISTINCT 
			Department.ID,
			Department.[Name]
		FROM org.Department
			LEFT JOIN OPENJSON(@ApplicantOrganIDs) applicantOrganIDs ON applicantOrganIDs.value = Department.ID
			LEFT JOIN OPENJSON(@PermissionOrganIDs) PermissionOrganIDs ON PermissionOrganIDs.value = Department.ID
		WHERE (@ApplicantOrganID IS NULL OR Department.ID = @ApplicantOrganID)
			AND (@ApplicantOrganIDs IS NULL OR applicantOrganIDs.value = Department.ID)
			AND (@ApplicantOrganName IS NULL OR Department.[Name] LIKE N'%' + @ApplicantOrganName + '%')
			AND (@ParentApplicantOrganID IS NULL OR [Node].IsDescendantOf(@ParentApplicantOrganNode) = 1)
			AND (@WpProvinceID IS NULL OR Department.ProvinceID = @WpProvinceID AND Department.[Type] = 2)
			AND (@DepartmentType < 1 OR Department.[Type] = @DepartmentType)
			AND (@PermissionOrganIDs IS NULL OR PermissionOrganIDs.value = Department.ID)
			
	)
	, MainSelect AS
	(
		SELECT 
			ec.ID,
			ec.ApplicantOrganID,
			org.Name ApplicantOrganName,
			ec.[Year],
			ec.[Month],
			ec.[State],
			ec.ProcessingDate,
			ec.TreasuryRequestID,
			flw.Date CreationDate
		FROM emp.EmployeeCatalog ec
			INNER JOIN Organ org ON org.ID = ec.ApplicantOrganID
			INNER JOIN pbl.DocumentFlow flw ON flw.DocumentID = ec.ID 
				AND flw.FromDocState = 1
				AND flw.ToDocState = 1
				AND flw.ActionDate IS NULL
		WHERE (@Year < 1 OR ec.[Year] = @Year)
			AND (@Month < 1 OR ec.[Month] = @Month)
			AND (@State < 1 OR ec.[State] = @State)
			AND (@Months IS NULL OR ec.[Month] IN (SELECT value FROM OPENJSON(@Months)))
			AND (@States IS NULL OR ec.[State] IN (SELECT value FROM OPENJSON(@States)))
			AND (@TreasuryRequestID IS NULL OR ec.TreasuryRequestID = @TreasuryRequestID )
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY ApplicantOrganName ASC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spGetEmployeeCatalogsForTimer') IS NOT NULL
    DROP PROCEDURE emp.spGetEmployeeCatalogsForTimer
GO

CREATE PROCEDURE emp.spGetEmployeeCatalogsForTimer
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	;WITH EmployeeCatalog AS
	(
		SELECT 
			EmployeeCatalog.[ID]
		FROM [emp].[EmployeeCatalog] EmployeeCatalog
		INNER JOIN [pbl].[Attachment] Attachment ON Attachment.[ParentID] = EmployeeCatalog.[ID]  
		WHERE (Attachment.[Type] = 25) --اکسل پیش فرض اطلاعات کارکنان
	)
	SELECT TOP 1
			EmployeeCatalog.[ID]
		FROM [emp].[EmployeeCatalog] EmployeeCatalog
		WHERE EmployeeCatalog.[ID] NOT IN (SELECT * FROM EmployeeCatalog)
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spModifyEmployeeCatalog') IS NOT NULL
    DROP PROCEDURE emp.spModifyEmployeeCatalog
GO

CREATE PROCEDURE emp.spModifyEmployeeCatalog  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ATreasuryRequestID UNIQUEIDENTIFIER,
	@AApplicantOrganID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@AState TINYINT,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@TreasuryRequestID UNIQUEIDENTIFIER = @ATreasuryRequestID,
		@ApplicantOrganID UNIQUEIDENTIFIER = @AApplicantOrganID,
		@Year SMALLINT = @AYear,
		@Month TINYINT = COALESCE(@AMonth, 0),
		@State TINYINT = COALESCE(@AState, 0),
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@DocumentType TINYINT = 2,     -- EmployeeCatalog
		@TrackingCode VARCHAR(20),
		@DocumentNumber NVARCHAR(50),
		@ToDocState TINYINT = 1

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN	

				EXECUTE pbl.spModifyBaseDocument_ 1, @ID, @DocumentType, @CurrentPositionID, @TrackingCode, @DocumentNumber, NULL
				
				EXEC pbl.spAddFlow @ADocumentID = @ID, @AFromUserID = @CurrentUserID, @AFromPositionID = @CurrentPositionID, @AToPositionID = @CurrentPositionID, @AFromDocState = 1, @AToDocState = @ToDocState, @ASendType = 3, @AComment = null

				INSERT INTO emp.EmployeeCatalog
					(ID, ApplicantOrganID, [Year], [Month], [State], [ProcessingDate] , [TreasuryRequestID])
				VALUES
					(@ID, @ApplicantOrganID, @Year, @Month, @State, NULL, @TreasuryRequestID)
			END
			--ELSE
			--BEGIN

				--UPDATE wag.EmployeeCatalog
				--SET 
				--WHERE ID = @ID

			--END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spGetEmployeeErrors') IS NOT NULL
    DROP PROCEDURE emp.spGetEmployeeErrors
GO

CREATE PROCEDURE emp.spGetEmployeeErrors
	@AEmployeeCatalogID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APermissionOrganIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX), 
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE 
		@EmployeeCatalogID UNIQUEIDENTIFIER = @AEmployeeCatalogID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@PermissionOrganIDs NVARCHAR(MAX) = @APermissionOrganIDs,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID
		
	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END


	;WITH Organ AS
	(
		SELECT DISTINCT 
			Department.ID,
			Department.[Name]
		FROM org.Department
			LEFT JOIN OPENJSON(@PermissionOrganIDs) PermissionOrganIDs ON PermissionOrganIDs.value = Department.ID
		WHERE (@PermissionOrganIDs IS NULL OR PermissionOrganIDs.value = Department.ID)
			AND (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
	) 
	, MainSelect AS
	(
		SELECT 
			err.[ID],
			err.[EmployeeID], 
			err.[ErrorType],
			err.[ErrorText],
			indi.NationalCode,
			indi.ID IndividualID,
			indi.FirstName + ' ' + indi.LastName [EmployeeName],
			employee.EmployeeCatalogID,
			employee.OrganID,
			dep.[Name] OrganName,
			ec.[Year],
			ec.[Month]
		FROM [emp].[EmployeeError] err
			INNER JOIN [emp].[Employee] employee ON employee.ID = err.EmployeeID
			INNER JOIN org.Individual indi ON indi.ID = employee.IndividualID
			INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
			INNER JOIN Organ dep ON dep.ID = employee.OrganID
		WHERE (@EmployeeCatalogID IS NULL OR employee.EmployeeCatalogID = @EmployeeCatalogID)
			AND (@Month < 1 OR ec.[Month] = @Month)
			AND (@Year < 1 OR ec.[Year] = @Year)
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY IndividualID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spGetEmployeeErrorsForReport') IS NOT NULL
    DROP PROCEDURE emp.spGetEmployeeErrorsForReport
GO

CREATE PROCEDURE emp.spGetEmployeeErrorsForReport
	@AEmployeeCatalogID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APermissionOrganIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX), 
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE 
		@EmployeeCatalogID UNIQUEIDENTIFIER = @AEmployeeCatalogID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@PermissionOrganIDs NVARCHAR(MAX) = @APermissionOrganIDs,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID
		
	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END


	;WITH Organ AS
	(
		SELECT DISTINCT 
			Department.ID,
			Department.[Name]
		FROM org.Department
			LEFT JOIN OPENJSON(@PermissionOrganIDs) PermissionOrganIDs ON PermissionOrganIDs.value = Department.ID
		WHERE (@PermissionOrganIDs IS NULL OR PermissionOrganIDs.value = Department.ID)
			AND (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
	) 
	, MainSelect AS
	(
		SELECT DISTINCT
			err.[ID],
			err.[EmployeeID], 
			err.[ErrorType],
			err.[ErrorText],
			indi.NationalCode,
			indi.ID IndividualID,
			indi.FirstName + ' ' + indi.LastName [EmployeeName],
			employee.EmployeeCatalogID,
			employee.OrganID,
			dep.[Name] OrganName,
			ec.[Year],
			ec.[Month]
		FROM [emp].[EmployeeError] err
			INNER JOIN [emp].[Employee] employee ON employee.ID = err.EmployeeID
			INNER JOIN org.Individual indi ON indi.ID = employee.IndividualID
			INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
			INNER JOIN Organ dep ON dep.ID = employee.OrganID
			INNER JOIN [wag].[PayrollEmployee] pe ON pe.[EmployeeID] = employee.ID
			INNER JOIN [wag].[TreasuryRequest] tr ON tr.ID = ec.TreasuryRequestID
			INNER JOIN pbl.BaseDocument Document ON Document.ID = tr.ID
			INNER JOIN pbl.DocumentFlow Flow ON Flow.DocumentID = Document.ID  AND Flow.ActionDate IS NULL
		WHERE (@EmployeeCatalogID IS NULL OR employee.EmployeeCatalogID = @EmployeeCatalogID)
			AND (@Month < 1 OR ec.[Month] = @Month)
			AND (@Year < 1 OR ec.[Year] = @Year)
			AND (pe.SumDeductions <> 0 OR pe.SumPayments <> 0)
			AND (Document.RemoveDate IS NULL AND CAST(COALESCE(Flow.ToDocState, 0) AS TINYINT) >= 40) -- Last Flow >= 40)
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY IndividualID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

CREATE OR ALTER PROC emp.spGetEmployeeHaveHokmDontHavePayroll
	@AEmployeeCatalogID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	DECLARE 
		@EmployeeCatalogID UNIQUEIDENTIFIER = @AEmployeeCatalogID,
		@Year SMALLINT,
		@Month TINYINT,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	SET @Year = (SELECT TOP 1 [Year] FROM  [emp].[EmployeeCatalog] WHERE ID = @EmployeeCatalogID)
	SET @Month = (SELECT TOP 1 [Month] FROM  [emp].[EmployeeCatalog] WHERE ID = @EmployeeCatalogID)

	IF @PageIndex = 0
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END


	;WITH PaymentOrgan AS
	(
		SELECT 
			TreasuryRequestOrgan.[OrganID]
		FROM [emp].[EmployeeCatalog] employeeCatalog
			INNER JOIN [wag].[TreasuryRequestOrgan] TreasuryRequestOrgan ON employeeCatalog.[TreasuryRequestID] = TreasuryRequestOrgan.[RequestID]
		WHERE EmployeeCatalog.ID = @EmployeeCatalogID
		GROUP BY TreasuryRequestOrgan.[OrganID]
	)
	, EmployeePayment AS
	(
		SELECT
			IndividualID
		FROM [emp].[Employee] employee
			INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
		WHERE ec.ID = @EmployeeCatalogID
		GROUP BY IndividualID
	)
	, MainSelect AS
    (
		SELECT
			info.ID,
			payment.OrganID,
			dep.[Name] OrganName,
			info.EducationDegree,
			info.MarriageStatus MarriageStatusType,
			info.ChildrenCount,
			info.EmploymentType,
			info.SacrificialType,
			info.FrontlineDuration,
			info.VeteranPercent,
			info.WorkExperienceYears,
			info.EmploymentStatus,
			info.PensionFundType,
			info.Number,
			info.IssuanceDate,
			info.ExecutionDate,
			indi.ID IndividualID,
			indi.NationalCode,
			indi.FirstName,
			indi.LastName,
			indi.BirthDate,
			post.UniqueID PostUniqueID,
			post.ID PostID
		FROM [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentDetail] detail
			INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPayment] payment ON payment.ID = detail.[EmployeeInfoForSalaryPaymentID]
			INNER JOIN PaymentOrgan ON PaymentOrgan.OrganID = payment.OrganID
			LEFT JOIN EmployeePayment ON EmployeePayment.IndividualID = detail.PaymentIndividualID

			INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = detail.[EmployeeInfoID]
			INNER JOIN org.Individual indi ON indi.ID = detail.PaymentIndividualID
			INNER JOIN org.Department dep ON dep.ID = payment.OrganID
			LEFT JOIN [Kama.Aro.Sakhtar].chr.Post post ON post.ID = info.PostID
		WHERE EmployeePayment.IndividualID IS NULL
			AND payment.[Year] = @Year
			AND payment.[Month] = @Month
			AND detail.PayrollType = 1
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY OrganID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spGetNextEmployeeCatalogToProcess') IS NOT NULL
    DROP PROCEDURE emp.spGetNextEmployeeCatalogToProcess
GO

CREATE PROCEDURE emp.spGetNextEmployeeCatalogToProcess
	--@AGetLargeFiles BIT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	--DECLARE 
		--@GetLargeFiles BIT = COALESCE(@AGetLargeFiles, 1)

	SELECT TOP 1 ID
	FROM emp.EmployeeCatalog
		--INNER JOIN pbl.Attachment ON pbl.Attachment.ParentID = Payroll.ID
	WHERE 
		--LastState = 5
		[State] = 5
		--AND (@GetLargeFiles <> 0 OR Attachment.FileSize < 1024)
		--AND (@GetLargeFiles <> 1 OR Attachment.FileSize >= 1024)
	--ORDER BY Attachment.FileSize

END 


GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spSetEmployeeCatalogProcessingDate') IS NOT NULL
    DROP PROCEDURE emp.spSetEmployeeCatalogProcessingDate
GO

CREATE PROCEDURE emp.spSetEmployeeCatalogProcessingDate 
	@AEmployeeCatalogID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@EmployeeCatalogID UNIQUEIDENTIFIER = @AEmployeeCatalogID

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE emp.EmployeeCatalog
			SET 
				[ProcessingDate] = GETDATE()
			WHERE ID = @EmployeeCatalogID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('emp.spSetEmployeeCatalogState') IS NOT NULL
    DROP PROCEDURE emp.spSetEmployeeCatalogState
GO

CREATE PROCEDURE emp.spSetEmployeeCatalogState 
	@AEmployeeCatalogID UNIQUEIDENTIFIER,
	@AState TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@EmployeeCatalogID UNIQUEIDENTIFIER = @AEmployeeCatalogID,
		@State TINYINT = COALESCE(@AState, 0)

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE emp.EmployeeCatalog
			SET 
				[State] = @State
			WHERE ID = @EmployeeCatalogID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('emp.spEmployeeDiscrepancyListProcessing1'))
	DROP PROCEDURE emp.spEmployeeDiscrepancyListProcessing1
GO

CREATE PROCEDURE emp.spEmployeeDiscrepancyListProcessing1

	@AYear SMALLINT,
	@AMonth TINYINT

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE
		@Year SMALLINT = @AYear,
		@Month TINYINT = @AMonth

	BEGIN TRY
	BEGIN TRAN


			UPDATE employee
			SET EmployeeInfoID = NULL
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPayment] paymentPakna ON paymentPakna.OrganID = employee.OrganID AND paymentPakna.[Year] = ec.[Year] AND paymentPakna.[Month] = ec.[Month]
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentDetail] ed ON ed.EmployeeInfoForSalaryPaymentID = paymentPakna.ID AND employee.IndividualID = ed.PaymentIndividualID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month

			UPDATE employee
			SET EmployeeInfoID = ed.EmployeeInfoID
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPayment] paymentPakna ON paymentPakna.OrganID = employee.OrganID AND paymentPakna.[Year] = ec.[Year] AND paymentPakna.[Month] = ec.[Month]
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentDetail] ed ON ed.EmployeeInfoForSalaryPaymentID = paymentPakna.ID AND employee.IndividualID = ed.PaymentIndividualID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND ed.[PayrollType] = 1
				AND employee.EmployeeInfoID IS NULL

			UPDATE employee
			SET EmployeeInfoID = ed.EmployeeInfoID
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPayment] paymentPakna ON paymentPakna.OrganID = employee.OrganID AND paymentPakna.[Year] = ec.[Year] AND paymentPakna.[Month] = ec.[Month]
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentDetail] ed ON ed.EmployeeInfoForSalaryPaymentID = paymentPakna.ID AND employee.IndividualID = ed.PaymentIndividualID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND ed.[PayrollType] = 2
				AND employee.EmployeeInfoID IS NULL

	COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('emp.spEmployeeDiscrepancyListProcessing2'))
	DROP PROCEDURE emp.spEmployeeDiscrepancyListProcessing2
GO

CREATE PROCEDURE emp.spEmployeeDiscrepancyListProcessing2

	@AYear SMALLINT,
	@AMonth TINYINT

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE
		@Year SMALLINT = @AYear,
		@Month TINYINT = @AMonth,

-----------------------------------------------------------------
    @LastMonthDate DATE,
	@FirstMonthDate DATE,
	@FirstIssuanceDate DATETIME,
	@LastIssuanceDate DATETIME

-----------------------------------------------------------------

	SET @FirstMonthDate = (SELECT TOP 1 [FirstMonthDate] FROM [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentSetting] WHERE [Year] = @Year AND [Month] = @Month  AND RemoveDate IS NULL)
	SET @LastMonthDate = (SELECT TOP 1 [LastMonthDate] FROM [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentSetting] WHERE [Year] = @Year AND [Month] = @Month  AND RemoveDate IS NULL)

	SET @FirstIssuanceDate = (SELECT TOP 1 [FirstIssuanceDate] FROM [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentSetting] WHERE [Year] = @Year AND [Month] = @Month  AND RemoveDate IS NULL)
	SET @LastIssuanceDate = (SELECT TOP 1 [LastIssuanceDate] FROM [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentSetting] WHERE [Year] = @Year AND [Month] = @Month  AND RemoveDate IS NULL)


-----------------------------------------------------------------

	BEGIN TRY
	BEGIN TRAN

			IF OBJECT_ID('tempdb..#EmployeeDiscrepancyListProcessing2', 'U') IS NOT NULL
			DROP TABLE #EmployeeDiscrepancyListProcessing2;

			DELETE err
			FROM [emp].[EmployeeError] err
				INNER JOIN [emp].[Employee] employee ON employee.ID = err.EmployeeID
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.[EmployeeCatalogID]
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month

			SELECT
				employee.*,
				paymentPakna.OrganID PaymentOrganID
			INTO #EmployeeDiscrepancyListProcessing2
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPayment] paymentPakna ON paymentPakna.OrganID = employee.OrganID AND paymentPakna.[Year] = ec.[Year] AND paymentPakna.[Month] = ec.[Month]
				LEFT JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoForSalaryPaymentDetail] ed ON ed.EmployeeInfoForSalaryPaymentID = paymentPakna.ID AND employee.IndividualID = ed.PaymentIndividualID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NULL
				AND ed.ID IS NULL


			--1-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				1 [ErrorType],
				N'آخرین حکم فرد مورد نظر در دستگاه اجرایی دیگری ثبت گردیده است' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE
				(lastInfo.[IssuanceDate] IS NOT NULL)
				AND (lastInfo.ExecutionDate IS NOT NULL)
				AND (lastInfo.[EmploymentStatusItemType] IN (1, 2) OR (lastInfo.[EmploymentStatusItemType] IN (3) AND lastInfo.ExecutionDate >= @FirstMonthDate AND lastInfo.ExecutionDate < @LastMonthDate)) -- افزایش و بلااثر
				AND (lastInfo.IssuanceDate >= @FirstIssuanceDate)
				AND (lastInfo.IssuanceDate < @LastIssuanceDate)
				AND (lastInfo.ExecutionDate <= @LastMonthDate) -- تاریخ اجرای حکم باید کوچکتر از آخر ماه باشد
				AND (lastInfo.[EmploymentStatus] NOT IN (26, 43) AND 
						(lastInfo.[MissionRequestID] IS NULL
							OR (lastInfo.[MissionRequestID] IS NOT NULL AND ((lastInfo.[MissionRequestEndDate] IS NOT NULL AND lastInfo.[MissionRequestEndDate] < @FirstMonthDate) OR  lastInfo.MissionRequestType IN (3, 30))) -- منقضی شده کوچکتر از اول ماه یا درخواست ابطال و  یا پایان ماموریت باشد
						)
					)
				AND 
				(
					(lastInfo.EmploymentType IN (1, 2, 6, 12, 13, 14, 15, 18, 22, 23))
					OR 
					(
						(lastInfo.EmploymentType IN (3, 10, 11) AND lastInfo.ContractStartDate IS NOT NULL AND lastInfo.ContractEndDate IS NOT NULL)
						AND (lastInfo.ContractStartDate <= @LastMonthDate)
						AND (lastInfo.ContractEndDate >= lastInfo.ContractStartDate AND lastInfo.ContractEndDate >= @FirstMonthDate)
					)
				) -- نوع استخدام های پرداختی
				AND (employee.OrganID <> lastInfo.OrganID)

			--2-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				2 [ErrorType],
				N'با توجه به درخواست ماموریت/انتقال فرد امکان پرداخت به غیر از دستگاه مبدا وجود ندارد' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE
					(lastInfo.[IssuanceDate] IS NOT NULL)
					AND (lastInfo.ExecutionDate IS NOT NULL)
					AND (lastInfo.MissionRequestID IS NOT NULL)
					AND (lastInfo.MissionRequestType NOT IN (3, 30)) -- درخواست ابطال و پایان نباشد
					AND (
							(lastInfo.[EmploymentStatus] IN (1, 43) AND lastInfo.MissionRequestType NOT IN (13))
						OR 
							(lastInfo.[EmploymentStatus] IN (26) AND lastInfo.MissionRequestType IN (13))
						) -- شاغل جاری یا ماموریت و درخواست انتقال به غیر مشمولین پاکنا نباشد یا انتقال باشد و درخواست انتقال به غیر مشمولین پاکنا باشد
					AND (lastInfo.MissionRequestStartDate < @LastMonthDate AND ((lastInfo.MissionRequestEndDate IS NOT NULL AND lastInfo.MissionRequestEndDate >= lastInfo.MissionRequestStartDate AND lastInfo.MissionRequestEndDate >= @FirstMonthDate)))
					AND (lastInfo.IssuanceDate >= @FirstIssuanceDate)
					AND (lastInfo.IssuanceDate < @LastIssuanceDate)
					AND (lastInfo.ExecutionDate <= @LastMonthDate) -- تاریخ اجرای حکم باید کوچکتر از آخر ماه باشد
					AND 
					(
						(lastInfo.EmploymentType IN (1, 2, 6, 12, 13, 14, 15, 18, 22, 23))
						OR 
						(
							(lastInfo.EmploymentType IN (3, 10, 11) AND lastInfo.ContractStartDate IS NOT NULL AND lastInfo.ContractEndDate IS NOT NULL)
							AND (lastInfo.ContractStartDate <= @LastMonthDate)
							AND (lastInfo.ContractEndDate >= lastInfo.ContractStartDate AND lastInfo.ContractEndDate >= @FirstMonthDate)
						)
					) -- نوع استخدام های پرداختی

					AND lastInfo.MissionRequestPaymentType IN (1) AND lastInfo.MissionRequestSourceOrganID <> employee.PaymentOrganID

			--3-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				3 [ErrorType],
				N'با توجه به درخواست ماموریت/انتقال فرد امکان پرداخت به غیر از دستگاه مقصد وجود ندارد' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE
					(lastInfo.[IssuanceDate] IS NOT NULL)
					AND (lastInfo.ExecutionDate IS NOT NULL)
					AND (lastInfo.MissionRequestID IS NOT NULL)
					AND (lastInfo.MissionRequestType NOT IN (3, 30)) -- درخواست ابطال و پایان نباشد
					AND (
							(lastInfo.[EmploymentStatus] IN (1, 43) AND lastInfo.MissionRequestType NOT IN (13))
						OR 
							(lastInfo.[EmploymentStatus] IN (26) AND lastInfo.MissionRequestType IN (13))
						) -- شاغل جاری یا ماموریت و درخواست انتقال به غیر مشمولین پاکنا نباشد یا انتقال باشد و درخواست انتقال به غیر مشمولین پاکنا باشد
					AND (lastInfo.MissionRequestStartDate < @LastMonthDate AND ((lastInfo.MissionRequestEndDate IS NOT NULL AND lastInfo.MissionRequestEndDate >= lastInfo.MissionRequestStartDate AND lastInfo.MissionRequestEndDate >= @FirstMonthDate)))
					AND (lastInfo.IssuanceDate >= @FirstIssuanceDate)
					AND (lastInfo.IssuanceDate < @LastIssuanceDate)
					AND (lastInfo.ExecutionDate <= @LastMonthDate) -- تاریخ اجرای حکم باید کوچکتر از آخر ماه باشد
					AND 
					(
						(lastInfo.EmploymentType IN (1, 2, 6, 12, 13, 14, 15, 18, 22, 23))
						OR 
						(
							(lastInfo.EmploymentType IN (3, 10, 11) AND lastInfo.ContractStartDate IS NOT NULL AND lastInfo.ContractEndDate IS NOT NULL)
							AND (lastInfo.ContractStartDate <= @LastMonthDate)
							AND (lastInfo.ContractEndDate >= lastInfo.ContractStartDate AND lastInfo.ContractEndDate >= @FirstMonthDate)
						)
					) -- نوع استخدام های پرداختی

					AND lastInfo.MissionRequestPaymentType IN (4) AND lastInfo.MissionRequestDestinationOrganID <> employee.PaymentOrganID

			--4-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				4 [ErrorType],
				N'با توجه به درخواست ماموریت/انتقال فرد امکان پرداخت به غیر از دستگاه مبدا و یا مقصد وجود ندارد' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE
					(lastInfo.[IssuanceDate] IS NOT NULL)
					AND (lastInfo.ExecutionDate IS NOT NULL)
					AND (lastInfo.MissionRequestID IS NOT NULL)
					AND (lastInfo.MissionRequestType NOT IN (3, 30)) -- درخواست ابطال و پایان نباشد
					AND (
							(lastInfo.[EmploymentStatus] IN (1, 43) AND lastInfo.MissionRequestType NOT IN (13))
						OR 
							(lastInfo.[EmploymentStatus] IN (26) AND lastInfo.MissionRequestType IN (13))
						) -- شاغل جاری یا ماموریت و درخواست انتقال به غیر مشمولین پاکنا نباشد یا انتقال باشد و درخواست انتقال به غیر مشمولین پاکنا باشد
					AND (lastInfo.MissionRequestStartDate < @LastMonthDate AND ((lastInfo.MissionRequestEndDate IS NOT NULL AND lastInfo.MissionRequestEndDate >= lastInfo.MissionRequestStartDate AND lastInfo.MissionRequestEndDate >= @FirstMonthDate)))
					AND (lastInfo.IssuanceDate >= @FirstIssuanceDate)
					AND (lastInfo.IssuanceDate < @LastIssuanceDate)
					AND (lastInfo.ExecutionDate <= @LastMonthDate) -- تاریخ اجرای حکم باید کوچکتر از آخر ماه باشد
					AND 
					(
						(lastInfo.EmploymentType IN (1, 2, 6, 12, 13, 14, 15, 18, 22, 23))
						OR 
						(
							(lastInfo.EmploymentType IN (3, 10, 11) AND lastInfo.ContractStartDate IS NOT NULL AND lastInfo.ContractEndDate IS NOT NULL)
							AND (lastInfo.ContractStartDate <= @LastMonthDate)
							AND (lastInfo.ContractEndDate >= lastInfo.ContractStartDate AND lastInfo.ContractEndDate >= @FirstMonthDate)
						)
					) -- نوع استخدام های پرداختی

					AND lastInfo.MissionRequestPaymentType NOT IN (1, 4) AND lastInfo.MissionRequestDestinationOrganID <> employee.PaymentOrganID AND lastInfo.MissionRequestSourceOrganID <> employee.PaymentOrganID

			--5-------------------------------------------------------------------------------------------------------------------------------------
			
			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				5 [ErrorType],
				N'هیچ حکمی برای فرد در پایگاه اطلاعات کارکنان نظام اداری ثبت نگردیده است.' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				LEFT JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE lastInfo.ID IS NULL
				AND NOT EXISTS(SELECT TOP 1 1 FROM [emp].[EmployeeError] err
					INNER JOIN [emp].[Employee] e ON e.ID = err.[EmployeeID]
					INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = e.EmployeeCatalogID 
				WHERE ec.[Year] = @Year 
					AND ec.[Month] = @Month
					AND err.[ErrorType] IN (1, 2, 3, 4)
					AND err.EmployeeID = employee.ID
				)

			--6-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				6 [ErrorType],
				N'وضعیت اشتغال آخرین حکم ثبت شده برای فرد از نوع کاهش می باشد' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID			
			WHERE (lastInfo.[EmploymentStatusItemType] NOT IN (1, 2))
				AND NOT EXISTS(SELECT TOP 1 1 FROM [emp].[EmployeeError] err
					INNER JOIN [emp].[Employee] e ON e.ID = err.[EmployeeID]
					INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = e.EmployeeCatalogID 
				WHERE ec.[Year] = @Year 
					AND ec.[Month] = @Month
					AND err.[ErrorType] IN (1, 2, 3, 4)
					AND err.EmployeeID = employee.ID
				)

			--7------------------------------------------------------------------------------------------------------------------------------------
			
			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				7 [ErrorType],
				N'تاریخ صدور حکم/قرارداد ثبت شده در آخرین حکم فرد معتبر نمی باشد' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE (lastInfo.[EmploymentStatusItemType] IN (1, 2))
				AND (
						lastInfo.IssuanceDate < @FirstIssuanceDate
						OR lastInfo.IssuanceDate > @LastIssuanceDate 
						OR lastInfo.IssuanceDate IS NULL
					)
				AND NOT EXISTS(SELECT TOP 1 1 FROM [emp].[EmployeeError] err
					INNER JOIN [emp].[Employee] e ON e.ID = err.[EmployeeID]
					INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = e.EmployeeCatalogID 
				WHERE ec.[Year] = @Year 
					AND ec.[Month] = @Month
					AND err.[ErrorType] IN (1, 2, 3, 4)
					AND err.EmployeeID = employee.ID
				)

			--8-------------------------------------------------------------------------------------------------------------------------------------
			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				8 [ErrorType],
				N'تاریخ اجرای آخرین حکم فرد مورد نظر فرا نرسیده و یا به اشتباه ثبت گردیده است' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE (lastInfo.[EmploymentStatusItemType] IN (1, 2))
				AND (lastInfo.ExecutionDate > @LastMonthDate OR lastInfo.ExecutionDate IS NULL)
				AND NOT EXISTS(SELECT TOP 1 1 FROM [emp].[EmployeeError] err
					INNER JOIN [emp].[Employee] e ON e.ID = err.[EmployeeID]
					INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = e.EmployeeCatalogID 
				WHERE ec.[Year] = @Year 
					AND ec.[Month] = @Month
					AND err.[ErrorType] IN (1, 2, 3, 4)
					AND err.EmployeeID = employee.ID
				)

			--9-------------------------------------------------------------------------------------------------------------------------------------
			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				9 [ErrorType],
				N'نوع استخدام ثبت شده در آخرین حکم فرد، مجاز به پرداخت نمی باشد' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE (lastInfo.[EmploymentStatusItemType] IN (1, 2))
				AND (lastInfo.EmploymentType NOT IN (1, 2, 3, 6, 10, 11, 12, 13, 14, 15, 18, 22, 23))
				AND NOT EXISTS(SELECT TOP 1 1 FROM [emp].[EmployeeError] err
					INNER JOIN [emp].[Employee] e ON e.ID = err.[EmployeeID]
					INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = e.EmployeeCatalogID 
				WHERE ec.[Year] = @Year 
					AND ec.[Month] = @Month
					AND err.[ErrorType] IN (1, 2, 3, 4)
					AND err.EmployeeID = employee.ID
				)


			--10-------------------------------------------------------------------------------------------------------------------------------------
			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				10 [ErrorType],
				N'با توجه به نوع استخدام ثبت شده در حکم، تاریخ شروع و یا پایان قرارداد به پایان رسیده و یا به اشتباه ثبت گردیده است' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE (lastInfo.[EmploymentStatusItemType] IN (1, 2))
				AND (
						(lastInfo.EmploymentType IN (3, 10, 11)
						AND
						(
							lastInfo.ContractStartDate IS  NULL OR lastInfo.ContractEndDate IS NULL)
							OR (lastInfo.ContractStartDate > @LastMonthDate)
							OR (lastInfo.ContractEndDate < lastInfo.ContractStartDate 
							OR lastInfo.ContractEndDate < @FirstMonthDate)
						)

					)
				AND NOT EXISTS(SELECT TOP 1 1 FROM [emp].[EmployeeError] err
					INNER JOIN [emp].[Employee] e ON e.ID = err.[EmployeeID]
					INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = e.EmployeeCatalogID 
				WHERE ec.[Year] = @Year 
					AND ec.[Month] = @Month
					AND err.[ErrorType] IN (1, 2, 3, 4)
					AND err.EmployeeID = employee.ID
				)

			--11-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				11 [ErrorType],
				N'وضعیت اشتغال آخرین حکم فرد مورد نظر حالت ماموریت می باشد ولی درخواست ماموریتی برای وی ثبت نگردیده است' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE (lastInfo.[EmploymentStatusItemType] IN (1, 2))
				AND (lastInfo.EmploymentStatus IN (43) AND lastInfo.MissionRequestID IS NULL)
				AND NOT EXISTS(SELECT TOP 1 1 FROM [emp].[EmployeeError] err
					INNER JOIN [emp].[Employee] e ON e.ID = err.[EmployeeID]
					INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = e.EmployeeCatalogID 
				WHERE ec.[Year] = @Year 
					AND ec.[Month] = @Month
					AND err.[ErrorType] IN (1, 2, 3, 4)
					AND err.EmployeeID = employee.ID
				)

			--12-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				12 [ErrorType],
				N'وضعیت اشتغال فرد مورد نظر حالت ماموریت می باشد ولی تاریخ شروع و یا پایان در درخواست ماموریت به اتمام رسیده و یا به اشتباه ثبت گردیده است' [ErrorText]
			FROM #EmployeeDiscrepancyListProcessing2 employee
				INNER JOIN [Kama.Aro.Pakna].[emp].[EmployeeInfoTemplate] lastInfo ON lastInfo.[Year] = @Year AND lastInfo.[Month] = @Month AND lastInfo.IndividualID = employee.IndividualID
			WHERE (lastInfo.[EmploymentStatusItemType] IN (1, 2))
				AND (lastInfo.EmploymentStatus IN (43) AND lastInfo.MissionRequestID IS NOT NULL)
				AND (lastInfo.MissionRequestStartDate > @LastMonthDate
						OR 
						(
							(
								lastInfo.MissionRequestEndDate IS NULL 
								OR lastInfo.MissionRequestEndDate < lastInfo.MissionRequestStartDate 
								OR lastInfo.MissionRequestEndDate < @FirstMonthDate
							)
						)
					)
				AND NOT EXISTS(SELECT TOP 1 1 FROM [emp].[EmployeeError] err
					INNER JOIN [emp].[Employee] e ON e.ID = err.[EmployeeID]
					INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = e.EmployeeCatalogID 
				WHERE ec.[Year] = @Year 
					AND ec.[Month] = @Month
					AND err.[ErrorType] IN (1, 2, 3, 4)
					AND err.EmployeeID = employee.ID
				)




			--150-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				150 [ErrorType],
				N'مدرک تحصیلی وارد شده برای فرد، با مدرک تحصیلی یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.EducationDegree <> info.EducationDegree

			--151-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				151 [ErrorType],
				N'وضعیت تاهل وارد شده برای فرد، با وضعیت تاهل یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.MarriageStatus <> info.MarriageStatus

			--152-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				152 [ErrorType],
				N'تعداد فرزندان وارد شده برای فرد، با تعداد فرزندان یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.ChildrenCount <> info.ChildrenCount

			--153-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				153 [ErrorType],
				N'نوع استخدام وارد شده برای فرد، با نوع استخدام یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.EmploymentType <> info.EmploymentType

			--154-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				154 [ErrorType],
				N'پست سازمانی وارد شده برای فرد، با پست سازمانی یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.PostID <> info.PostID

			--155-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				155 [ErrorType],
				N'وضعیت ایثارگری وارد شده برای فرد، با وضعیت ایثارگری یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.SacrificialType <> info.SacrificialType

			--156-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				156 [ErrorType],
				N'مدت حضور در جبهه(روز) وارد شده برای فرد، با مدت حضور در جبهه(روز) یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.FrontlineDuration <> info.FrontlineDuration

			--157-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				157 [ErrorType],
				N'درصد جانبازی وارد شده برای فرد، با درصد جانبازی یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.VeteranPercent <> info.VeteranPercent

			--158-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				158 [ErrorType],
				N'سابقه خدمت - سال وارد شده برای فرد، با سابقه خدمت - سال یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.WorkExperienceYears <> info.WorkExperienceYears

			--159-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				159 [ErrorType],
				N'وضعیت اشتغال وارد شده برای فرد، با وضعیت اشتغال یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.EmploymentStatus <> info.EmploymentStatus

			--160-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				160 [ErrorType],
				N'صندوق بازنشستگی وارد شده برای فرد، با صندوق بازنشستگی یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.PensionFundType <> info.PensionFundType

			--161-------------------------------------------------------------------------------------------------------------------------------------

			INSERT INTO [emp].[EmployeeError]
				([ID], [EmployeeID], [ErrorType], [ErrorText])
			SELECT
				NEWID() [ID],
				employee.ID [EmployeeID],
				161 [ErrorType],
				N'وضعیت بیمه وارد شده برای فرد، با وضعیت بیمه یافت شده در سامانه پاکنا مغایرت دارد.' [ErrorText]
			FROM [emp].[Employee] employee
				INNER JOIN [emp].[EmployeeCatalog] ec ON ec.ID = employee.EmployeeCatalogID
				INNER JOIN [Kama.Aro.Pakna].emp.EmployeeInfo info ON info.ID = employee.EmployeeInfoID
			WHERE ec.[Year] = @Year
				AND ec.[Month] = @Month
				AND employee.EmployeeInfoID IS NOT NULL
				AND employee.InsuranceStatusType <> info.PensionFundType
				AND (
					(employee.PensionFundType IN (1, 2, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16) AND employee.InsuranceStatusType <> 10)
					OR
					(employee.PensionFundType IN (3) AND employee.InsuranceStatusType <> 2)
					OR
					(employee.PensionFundType IN (6) AND employee.InsuranceStatusType <> 1)
				)


	COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'emp.spProcessEmployeeDiscrepancy') AND type in (N'P', N'PC'))
DROP PROCEDURE emp.spProcessEmployeeDiscrepancy
GO

CREATE PROCEDURE emp.spProcessEmployeeDiscrepancy
	@AYear SMALLINT,
	@AMonth TINYINT
--WITH ENCRYPTION
	AS
	BEGIN
		SET NOCOUNT ON;
		--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

		DECLARE
			@Year SMALLINT = @AYear,
			@Month TINYINT = @AMonth
		BEGIN TRY
			BEGIN TRAN

			IF @Year IS NOT NULL AND @Month IS NOT NULL
			BEGIN

				------------- جهت پر کردن EmployeeInfoID از سبد پرداخت
				EXEC emp.spEmployeeDiscrepancyListProcessing1 @AYear = @Year, @AMonth = @Month

				------------- جهت ایجاد لیست مغایرت با پاکنا
				EXEC emp.spEmployeeDiscrepancyListProcessing2 @AYear = @Year, @AMonth = @Month

			END
			ELSE
				THROW 50000, N'لطفا ابتدا تنظیمات برای سال و ماه مورد نظر را اعمال فرمایید.', 1

	COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spAssignLawToOrgan') IS NOT NULL
    DROP PROCEDURE law.spAssignLawToOrgan
GO

CREATE PROCEDURE law.spAssignLawToOrgan  
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AEnabled BIT,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Enabled BIT = COALESCE(@AEnabled, 0),
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@ID UNIQUEIDENTIFIER,
		@UserPositionType TINYINT,
		@DocumentType TinyINT = 1,     -- OrganLaw
		@TrackingCode VARCHAR(20),
		@DocumentNumber NVARCHAR(50)

	SET @UserPositionType = (SELECT [Type] from Org.Position WHERE ID = @CurrentUserPositionID)

	BEGIN TRY
		BEGIN TRAN
			
			SET @ID = (SELECT ID FROM law.OrganLaw WHERE LawID = @LawID AND OrganID = @OrganID)

			IF @ID IS NOT NULL
			BEGIN
				UPDATE law.OrganLaw
				SET [Enabled] = @Enabled
				WHERE ID = @ID

				IF @Enabled = 1
				BEGIN
					IF @UserPositionType = 10
						EXEC pbl.spAddFlow @ID, @CurrentUserID, @CurrentUserPositionID, @CurrentUserPositionID, 1, 10, 5, NULL
					ELSE IF @UserPositionType = 20
						EXEC pbl.spAddFlow @ID, @CurrentUserID, @CurrentUserPositionID, @CurrentUserPositionID, 1, 20, 5, NULL
				END
			END
			ELSE
			BEGIN
				
				SET @ID = NEWID()

				EXECUTE pbl.spModifyBaseDocument_ 1, @ID, @DocumentType, @CurrentUserPositionID, @TrackingCode, @DocumentNumber, NULL

				IF @UserPositionType = 10
					EXEC pbl.spAddFlow @ID, @CurrentUserID, @CurrentUserPositionID, @CurrentUserPositionID, 1, 10, 5, null
				ELSE IF @UserPositionType = 20
					EXEC pbl.spAddFlow @ID, @CurrentUserID, @CurrentUserPositionID, @CurrentUserPositionID, 1, 20, 5 , null
				
				INSERT INTO law.OrganLaw
				(ID, LawID, OrganID, [Enabled],PositionSubTypeID)
				VALUES
				(@ID, @LawID, @OrganID, 1,@PositionSubTypeID)
			
				INSERT INTO wag.LawWageTitle
				([ID], [OrganID], [LawID], [WageTitleID], [WageTitleGroupID], [Order], [OrderType])
				SELECT NEWID() ID
					 , @OrganID OrganID
					 , T.LawID LawID
					 , T.WageTitleID
					 , [WageTitleGroupID]
					 , T.[Order]
					 , T.[OrderType]
				FROM wag.LawWageTitle T
				INNER JOIN law.Law law ON law.ID = T.LawID AND COALESCE(law.OwnerOrganID, pbl.EmptyGuid()) = COALESCE(T.OrganID, pbl.EmptyGuid())
				WHERE --T.[Type] = 1 AND
						T.LawID = @LawID
						AND NOT EXISTS(SELECT 1 FROM wag.LawWageTitle G WHERE G.OrganID = @OrganID AND G.WageTitleID = T.ID)
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spDeleteLaw') IS NOT NULL
    DROP PROCEDURE law.spDeleteLaw
GO

CREATE PROCEDURE law.spDeleteLaw  
	@AID UNIQUEIDENTIFIER, 
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@UserOrganID UNIQUEIDENTIFIER

	SET @UserOrganID = (SELECT DepartmentID FROM org.Position WHERE Position.ID = @CurrentUserPositionID)

	IF EXISTS(SELECT 1 FROM law.OrganLaw WHERE LawID = @ID AND OrganID <> @UserOrganID)
		THROW 60101, N'این قانون توسط سایر دستگاه ها استفاده شده است. امکان حذف وجود ندارد.', 1;

	IF EXISTS(SELECT 1 FROM wag.Payroll WHERE LawID = @ID)
		THROW 60101, N'با استفاده از این قانون لیست حقوق و مزایا ثبت شده است. امکان حذف وجود ندارد.', 1;

	BEGIN TRY
		BEGIN TRAN
			
			DELETE FROM wag.LawWageTitle
			WHERE LawID = @ID

			DELETE FROM law.OrganLaw
			WHERE LawID = @ID

			DELETE FROM law.Law
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetLaw') IS NOT NULL
    DROP PROCEDURE law.spGetLaw
GO

CREATE PROCEDURE law.spGetLaw   
	@AID UNIQUEIDENTIFIER,
	@AOrganLawID UNIQUEIDENTIFIER,
	@AUserPositionID UNIQUEIDENTIFIER ,
	@AApplicationID UNIQUEIDENTIFIER 
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @ID UNIQUEIDENTIFIER = @AID,
		@OrganLawID UNIQUEIDENTIFIER = @AOrganLawID,
		@UserPositionID UNIQUEIDENTIFIER = @AUserPositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@UserID UNIQUEIDENTIFIER,
		@UserType TINYINT,
		@UserOrganID UNIQUEIDENTIFIER,
		@Enabled BIT = 0,
		@ActionState TINYINT = 0,
		@LastToPositionID UNIQUEIDENTIFIER,
		@LastDocState TINYINT,
		@ToUserName NVARCHAR(1000),
		@ToPositionType TINYINT 

;WITH PositionType AS (
select PositionType,ApplicationID from [Kama.Aro.Organization].[org].[PositionType]
)
	SELECT @UserID = UserID
		, @UserType = Position.[UserType]
		, @UserOrganID = DepartmentID
	FROM PositionType 
	INNER JOIN org._Position Position ON PositionType.[PositionType] = Position.[Type] AND PositionType.ApplicationID = Position.ApplicationID 
	WHERE Position.ID = @UserPositionID AND position.ApplicationID = @ApplicationID

	SELECT @LastToPositionID = lastFlow.ToPositionID
		, @LastDocState = lastFlow.ToDocState
		, @ToUserName = toUser.FirstName + ' ' + toUser.LastName
		, @ToPositionType = toPosition.[Type]
	FROM pbl.DocumentFlow lastFlow 
	LEFT JOIN org._Position toPosition ON toPosition.ID = lastFlow.ToPositionID 
	LEFT JOIN org.[User] toUser ON toUser.ID = toPosition.UserID 
	WHERE DocumentID = @OrganLawID AND ActionDate IS NULL

	IF @UserType = 1   -- ستادی
	BEGIN
		SET @ActionState = CASE WHEN @OrganLawID IS NULL THEN 1 ELSE 0 END
		SET @Enabled = COALESCE((SELECT 1 FROM law.Law WHERE ID = @ID AND OwnerOrganID = @UserOrganID), 0)
	END
	ELSE IF @UserType = 2
	BEGIN
		SET @ActionState = CASE WHEN @LastToPositionID = @UserPositionID THEN 1 ELSE 0 END
		SET @Enabled = COALESCE((SELECT 1 FROM law.OrganLaw INNER JOIN pbl.BaseDocument doc ON doc.ID = OrganLaw.ID WHERE LawID = @ID AND OrganID = @UserOrganID AND [Enabled] = 1 AND doc.RemoveDate IS NULL), 0)
	END

	SELECT Law.ID
		, Law.OwnerOrganID
		, ownerOrgan.Name OwnerOrganName
		, Law.Code
		, Law.[Name]
		, Law.Comment
		, OrganLaw.OrganID
		, @Enabled [Enabled]
		, OrganLaw.ID OrganLawID
		, Organ.[Name] OrganName
		, @ActionState ActionState
		, @LastDocState LastDocState
		, @ToUserName ToUserName
		, @ToPositionType ToPositionType
	FROM law.Law
		INNER JOIN org.Department ownerOrgan On ownerOrgan.ID = Law.OwnerOrganID
		LEFT JOIN law.OrganLaw ON OrganLaw.ID = @OrganLawID
		LEFT JOIN [org].[_Department] Organ On Organ.[ID] = OrganLaw.[OrganID]
		LEFT JOIN pbl.BaseDocument doc ON doc.ID = OrganLaw.ID AND doc.RemoveDate IS NULL 
	WHERE Law.ID = @ID
		--AND (@OrganLawID IS NULL OR OrganLaw.ID = @OrganLawID)

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetLaws') IS NOT NULL
    DROP PROCEDURE law.spGetLaws
GO

CREATE PROCEDURE law.spGetLaws   
	@AOwnerOrganID UNIQUEIDENTIFIER,  -- used for search (by setad)
	@AOrganIDs NVARCHAR(MAX),
	@AOrganID UNIQUEIDENTIFIER,  -- only used when organ gets list of laws
	@AUserPositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1500),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
		SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
		--WAITFOR DELAY '00:05:02';
    DECLARE 
		@OwnerOrganID UNIQUEIDENTIFIER = @AOwnerOrganID,
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@UserPositionID UNIQUEIDENTIFIER = @AUserPositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@UserID UNIQUEIDENTIFIER,
		@UserType TINYINT,
		@UserOrganID UNIQUEIDENTIFIER,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SET @UserID = (SELECT UserID FROM org.Position WHERE ID = @UserPositionID)
	SET @UserType = (SELECT TOP 1 [UserType] from Org.PositionType INNER JOIN org.Position ON PositionType.[PositionType] = Position.[Type] AND PositionType.ApplicationID = Position.ApplicationID WHERE Position.ID = @UserPositionID AND position.ApplicationID = @ApplicationID)
	SET @UserOrganID = (SELECT TOP 1 DepartmentID from Org.Position WHERE ID = @UserPositionID)

	;WITH OrganLaw AS
	(
		SELECT DISTINCT LawID
		FROM law.OrganLaw
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = OrganLaw.OrganID
		WHERE (@OrganID IS NULL OR OrganLaw.OrganID = @OrganID)
			AND (@OrganIDs IS NULL OR OrganIDs.value = OrganLaw.OrganID)
	)
	SELECT 
		COUNT(*) over() Total,
		L.ID,
		L.OwnerOrganID,
		ownerOrgan.[Name] OwnerOrganName,
		L.Code,
		L.[Name],
		L.Comment,
		CAST(CASE WHEN @UserType = 1 AND L.OwnerOrganID = @UserOrganID THEN 1 ELSE 0 END AS BIT) [Enabled]
	FROM law.Law L
		INNER JOIN org.Department ownerOrgan On ownerOrgan.ID = L.OwnerOrganID
		LEFT JOIN OrganLaw ON OrganLaw.LawID = L.ID
	WHERE (@OwnerOrganID IS NULL OR L.OwnerOrganID = @OwnerOrganID)
		AND (@Name IS NULL OR L.[Name] LIKE N'%' + @Name + '%')
		AND ((@OrganID IS NULL AND @OrganIDs IS NULL) OR OrganLaw.LawID = L.ID)
	ORDER BY [Order], Name
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END 

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('law.spGetOrganLawFlowPrerequisite'))
	DROP PROCEDURE law.spGetOrganLawFlowPrerequisite
GO

CREATE PROCEDURE law.spGetOrganLawFlowPrerequisite
	@AID UNIQUEIDENTIFIER,
	@AUserPositionID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@UserPositionID UNIQUEIDENTIFIER = @AUserPositionID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DocumentType TINYINT,
		@OrganID UNIQUEIDENTIFIER,
		@LawID UNIQUEIDENTIFIER,
		@OrganExpertPositionID UNIQUEIDENTIFIER,
		@OrganFinancialManagerPositionID UNIQUEIDENTIFIER,
		@PaymentWageTitlesCount INT,
		@DeductionWageTitlesCount INT

	SET @OrganID = (SELECT OrganID FROM law.OrganLaw WHERE ID = @ID)
	SET @LawID = (SELECT LawID FROM law.OrganLaw WHERE ID = @ID)

	SET @OrganExpertPositionID = (SELECT TOP 1 ID FROM org.Position WHERE DepartmentID = @OrganID AND ApplicationID = @ApplicationID AND RemoveDate IS NULL AND [Type] = 10)
	SET @OrganFinancialManagerPositionID = (SELECT TOP 1 ID FROM org.Position WHERE DepartmentID = @OrganID AND ApplicationID = @ApplicationID AND RemoveDate IS NULL AND [Type] = 20)

	SET @PaymentWageTitlesCount = (SELECT Count(*) fROM wag.LawWageTitle
											INNER JOIN law.OrganLaw ON LawWageTitle.OrganID = OrganLaw.OrganID AND LawWageTitle.LawID = OrganLaw.LawID 
											INNER JOIN wag.WageTitle ON WageTitle.ID = LawWageTitle.WageTitleID
											WHERE OrganLaw.ID = @ID
												AND WageTitle.IncomeType = 1)

	SET @DeductionWageTitlesCount = (SELECT Count(*) fROM wag.LawWageTitle
											INNER JOIN law.OrganLaw ON LawWageTitle.OrganID = OrganLaw.OrganID AND LawWageTitle.LawID = OrganLaw.LawID 
											INNER JOIN wag.WageTitle ON WageTitle.ID = LawWageTitle.WageTitleID
											WHERE OrganLaw.ID = @ID
												AND WageTitle.IncomeType = 2)

	SELECT doc.ID,
		CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) LastDocState,
		lastFlow.ToPositionID LastToPositionID,
		@OrganExpertPositionID OrganExpertPositionID,
		@OrganFinancialManagerPositionID OrganFinancialManagerPositionID,
		@PaymentWageTitlesCount PaymentWageTitlesCount,
		@DeductionWageTitlesCount DeductionWageTitlesCount,
		@OrganID OrganID,
		@LawID LawID 
	FROM pbl.BaseDocument doc
	LEFT JOIN pbl.DocumentFlow lastFlow ON lastFlow.DocumentID = doc.ID AND lastFlow.ActionDate IS NULL
	where doc.ID = @ID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetOrganLaws') IS NOT NULL
    DROP PROCEDURE law.spGetOrganLaws
GO

CREATE PROCEDURE law.spGetOrganLaws   
	@ALawID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@AMainOrganID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1500),
	@AOwnerOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ALastDocState TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE 
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@MainOrganID UNIQUEIDENTIFIER = @AMainOrganID,
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@OwnerOrganID UNIQUEIDENTIFIER = @AOwnerOrganID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@UserType TINYINT,
		@LastDocState INT = COALESCE(@ALastDocState, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@UserOrganID UNIQUEIDENTIFIER 

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SET @UserOrganID = (SELECT TOP 1 [DepartmentID] from [org].[Position] WHERE [ID] = @CurrentUserPositionID)
	SET @UserType = (SELECT TOP 1 [UserType] from [org].[PositionType] INNER JOIN [org].[Position] ON PositionType.[PositionType] = Position.[Type]
						AND PositionType.[ApplicationID] = Position.[ApplicationID] WHERE Position.ID = @CurrentUserPositionID AND
						position.[ApplicationID] = @ApplicationID)

	SELECT count(*) over() Total,
		Law.[ID],
		Law.[OwnerOrganID],
		OwnerOrgan.[Name] OwnerOrganName,
		Law.[Code],
		Law.[Name],
		OrganLaw.[ID] OrganLawID,
		OrganLaw.[OrganID],
		OrganLaw.[LawID] LawID,
		OrganLaw.[Enabled],
		Organ.[Name] OrganName,
		Organ.[MainOrgan1Name] MainOrganName,
		Organ.[MainOrgan2Name] MainOrgan2Name,
		CAST(COALESCE(lastFlow.ToDocState, 1) AS TINYINT) LastDocState,
		Organ.[Type],
		Organ.[SubType]
	FROM [law].[OrganLaw] OrganLaw
		INNER JOIN [pbl].[BaseDocument] BaseDocument ON BaseDocument.[ID] = OrganLaw.[ID]
		INNER JOIN [law].[Law] Law ON Law.[ID] = OrganLaw.[LawID]
		INNER JOIN [org].[Department] OwnerOrgan On OwnerOrgan.[ID] = Law.[OwnerOrganID]
		LEFT JOIN [org].[_Department] Organ On Organ.[ID] = OrganLaw.[OrganID]
		LEFT JOIN [pbl].[DocumentFlow] lastFlow ON lastFlow.[DocumentID] = OrganLaw.[ID] AND lastFlow.[ActionDate] IS NULL
	WHERE (@UserOrganID = pbl.EmptyGuid() OR OrganLaw.OrganID = @OrganID)
		AND BaseDocument.RemoveDate IS NULL
		AND OrganLaw.[Enabled] = 1
		AND (@Name IS NULL OR Law.[Name] LIKE N'%' + @Name + '%')
		AND (@OwnerOrganID IS NULL OR Law.[OwnerOrganID] = @OwnerOrganID)
		AND (@OrganID IS NULL OR OrganLaw.[OrganID] = @OrganID)
		AND (@MainOrganID IS NULL OR Organ.[MainOrgan1ID] = @MainOrganID)
		AND (@LastDocState=0 OR CAST(COALESCE(lastFlow.[ToDocState], 1) AS TINYINT) = @LastDocState)
		AND (@LawID IS NULL OR Law.[ID] =  @LawID)

	ORDER BY Law.[Order]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 
GO
--USE [Kama.Aro.Pardakht]
--GO

--IF OBJECT_ID('law.spMergLaws') IS NOT NULL
--    DROP PROCEDURE law.spMergLaws
--GO

--CREATE PROCEDURE law.spMergLaws 
--	  @AData NVARCHAR(MAX) -- JSON => {TargetLawID:"", Code:"", Name:"", Laws:["", ""]}
--	, @ALog NVARCHAR(MAX)
----WITH ENCRYPTION
--AS
--BEGIN
--    SET NOCOUNT, XACT_ABORT ON;

--    DECLARE @Data NVARCHAR(MAX) = @AData
--		  , @Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
--		  , @Result INT = 0
--		  , @TargetLawID UNIQUEIDENTIFIER
--		  , @Code VARCHAR(10)
--		  , @Name NVARCHAR(1500)
--		  , @ErrorNumber INT = 60100

--	-- Load Target Law Data
--	SELECT @TargetLawID = TargetLawID
--		 , @Code = LTRIM(RTRIM(Code))
--		 , @Name = LTRIM(RTRIM([Name]))
--	FROM OPENJSON(@Data)
--	WITH (
--		TargetLawID UNIQUEIDENTIFIER,
--		Code VARCHAR(10),
--		[Name] NVARCHAR(1500)
--	)

--	IF @Code = ''
--		SET @Code = NULL

--	IF @Name = ''
--		SET @Name = NULL
--	--- Load related laws id --------------
--	DECLARE @RelatedLaws TABLE(ID UNIQUEIDENTIFIER)

--	INSERT INTO @RelatedLaws
--	SELECT [value] 
--	FROM OPENJSON(@Data, '$.Laws')

--	--- Load related organs id --------------
--	DECLARE @RelatedOrgans TABLE(ID UNIQUEIDENTIFIER)

--	INSERT INTO @RelatedOrgans
--	SELECT OL.OrganID
--	FROM law.OrganLaw OL
--	WHERE EXISTS(SELECT 1 FROM @RelatedLaws RW WHERE OL.LawID = RW.ID)

--	BEGIN TRY
--		BEGIN TRAN
			
--			--- حذف قوانین تعریف شده توسط ارگان از لیست قوانین هر هرگان
--			DELETE FROM law.OrganLaw
--			WHERE EXISTS(SELECT 1 FROM @RelatedOrgans G WHERE law.OrganLaw.OrganID = G.ID)

--			---- تخصیص قانون جدید به جای قوانین قبلی به ارگانها
--			INSERT INTO law.OrganLaw
--			SELECT NEWID() ID
--				 , @TargetLawID LawID
--				 , G.ID OrganID
--			FROM @RelatedOrgans G
			
--			--- بروزرسانی اطلاعات قانون جدید
--			UPDATE law.Law
--			SET OwnerOrganID = NULL, Code = ISNULL(@Code, Code), [Name] = ISNULL(@Name, [Name])
--			WHERE ID = @TargetLawID

--			----- تغییر آیدی قانون های قدیم به آیدی قانون جدید
--			--UPDATE wag.WageTitle
--			--SET LawID = @TargetLawID
--			--WHERE EXISTS(SELECT 1 FROM @RelatedLaws RL WHERE wag.WageTitle.LawID = RL.ID)

--			----- حذف قوانین قدیم --------------
--			DELETE FROM law.Law
--			WHERE EXISTS(SELECT 1 FROM @RelatedLaws RL WHERE law.ID = RL.ID)

--			SET @Result = @@ROWCOUNT

--			EXEC pbl.spAddLog @Log
--		COMMIT
--	END TRY
--	BEGIN CATCH
--		SET @Result = -1
--		;THROW
--	END CATCH

--    RETURN @Result 
--END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spModifyLaw') IS NOT NULL
    DROP PROCEDURE law.spModifyLaw
GO

CREATE PROCEDURE law.spModifyLaw  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1500),
	@AComment NVARCHAR(4000),
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0)
		, @ID UNIQUEIDENTIFIER = @AID
		, @Name NVARCHAR(1500) = LTRIM(RTRIM(@AName))
		, @Comment NVARCHAR(4000)= LTRIM(RTRIM(@AComment))
		, @CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID
		, @CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID
		, @Code VARCHAR(10)
		, @Type TinyINT = 1     -- Exam Request
		, @TrackingCode VARCHAR(20)
		, @DocumentNumber NVARCHAR(50)
		, @OrganLawID UNIQUEIDENTIFIER
		, @Result INT = 0
		, @OwnerOrganID UNIQUEIDENTIFIER 
		, @Order INT
		, @UserPositionType TINYINT

	SET @OwnerOrganID = (SELECT TOP 1 DepartmentID FROM org.Position WHERE ID = @CurrentUserPositionID)
	SET @UserPositionType = (SELECT TOP 1 [Type] FROM org.Position WHERE ID = @CurrentUserPositionID)

	IF @OwnerOrganID IS NULL
		THROW 5000, N'دستگاه اجرایی کاربر مشخص نشده است', 1

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				
				IF OBJECT_ID('law.sqLaw') IS NULL
					CREATE SEQUENCE law.sqLaw AS INT START WITH 100 INCREMENT BY 1 
				
				SET @Code = '10' + CAST(NEXT VALUE FOR law.sqLaw AS VARCHAR(10))

				SET @Order = COALESCE((SELECT MAX([Order]) FROM law.Law), 0) + 1

				INSERT INTO law.Law
				(ID, OwnerOrganID, Code, [Name], Comment, [Order])
				VALUES
				(@ID, @OwnerOrganID, @Code, @Name, @Comment, @Order)

				IF @OwnerOrganID <> pbl.EmptyGuid()
				BEGIN
					
					SET @OrganLawID = NEWID()
					
					EXECUTE pbl.spModifyBaseDocument_ 1, @OrganLawID, @Type, @CurrentUserPositionID, @TrackingCode, @DocumentNumber, NULL

					IF @UserPositionType = 10
						EXEC pbl.spAddFlow @ADocumentID = @OrganLawID, @AFromUserID = @CurrentUserID, @AFromPositionID = @CurrentUserPositionID, @AToPositionID = @CurrentUserPositionID, @AFromDocState = 1, @AToDocState = 10, @ASendType = 3, @AComment = null
					ELSE IF @UserPositionType = 20
						EXEC pbl.spAddFlow @OrganLawID, @CurrentUserID, @CurrentUserPositionID, @CurrentUserPositionID, 1, 20, 3 , null
				

					INSERT INTO law.OrganLaw
					(ID, OrganID, LawID, [Enabled])
					VALUES
					(@OrganLawID, @OwnerOrganID, @ID, 1)
				END

			END
			ELSE -- update
			BEGIN
				UPDATE law.Law
				SET [Name] = @Name, Comment = @Comment
				WHERE ID = @ID
			END
			 
			SET @Result = @@ROWCOUNT
			
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spResetLawOrganWageTitles') IS NOT NULL
    DROP PROCEDURE law.spResetLawOrganWageTitles
GO

CREATE PROCEDURE law.spResetLawOrganWageTitles  
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@ID UNIQUEIDENTIFIER,
		@UserPositionType TINYINT,
		@DocumentType TinyINT,     -- OrganLaw
		@TrackingCode VARCHAR(20),
		@DocumentNumber NVARCHAR(50)

	SET @UserPositionType = (SELECT [Type] from Org.Position WHERE ID = @CurrentUserPositionID)

	BEGIN TRY
		BEGIN TRAN
			
			BEGIN
				
				DELETE FROM 
					[wag].[LawWageTitle] 
				WHERE [OrganID] = @AOrganID 
					AND [LawID] = @LawID

				SET @ID = (SELECT [ID] From [law].[OrganLaw] WHERE [OrganID] = @AOrganID AND [LawID] = @LawID)

				IF @UserPositionType = 10
					EXEC pbl.spAddFlow @ID, @CurrentUserID, @CurrentUserPositionID, @CurrentUserPositionID, 1, 10, 5, NULL
				ELSE IF @UserPositionType = 20
					EXEC pbl.spAddFlow @ID, @CurrentUserID, @CurrentUserPositionID, @CurrentUserPositionID, 1, 20, 5, NULL
			
				INSERT INTO wag.LawWageTitle
				([ID], [OrganID], [LawID], [WageTitleID], [WageTitleGroupID], [Order], [OrderType])
				SELECT NEWID() ID
					 , @OrganID OrganID
					 , T.LawID LawID
					 , T.WageTitleID
					 , [WageTitleGroupID]
					 , T.[Order]
					 , T.[OrderType]
				FROM wag.LawWageTitle T
					INNER JOIN law.Law law ON law.ID = T.LawID AND COALESCE(law.OwnerOrganID, 0x) = COALESCE(T.OrganID, 0x)
				WHERE --T.[Type] = 1 AND
						T.LawID = @LawID
						AND T.OrganID = 0x
						AND NOT EXISTS(SELECT 1 FROM wag.LawWageTitle G WHERE G.OrganID = @OrganID AND G.WageTitleID = T.ID)
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeleteLawWageTitle_') IS NOT NULL
    DROP PROCEDURE wag.spDeleteLawWageTitle_
GO

CREATE PROCEDURE wag.spDeleteLawWageTitle_
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    delete wag.LawWageTitle
	from wag.LawWageTitle
	inner join wag.WageTitle ON WageTitle.ID = LawWageTitle.WageTitleID
	left join wag.LawWageTitle parent on parent.ID <> LawWageTitle.ID and parent.OrganID = LawWageTitle.OrganID and parent.LawID = LawWageTitle.LawID and LawWageTitle.Node.IsDescendantOf(parent.Node) = 1
	where 1=1 
		AND LawWageTitle.OrganID is not null
		--LawWageTitle.OrganID = '76a547bf-2cbf-4d2c-b22e-78aa032ccfef'
		--and LawWageTitle.LawID = '206E8E81-6B61-4DC1-B810-729D8FFBA524'
		and parent.ID is null
		and LawWageTitle.Node.GetLevel() = 2
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeleteLawWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spDeleteLawWageTitle
GO

CREATE PROCEDURE wag.spDeleteLawWageTitle
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID
		, @OrganID UNIQUEIDENTIFIER
		, @LawID UNIQUEIDENTIFIER
		, @Node HIERARCHYID


	IF @ID IS NULL OR @ID = pbl.EmptyGuid()
		THROW 60111, N'شناسه مشخص نیست.', 1

	SELECT @OrganID = OrganID, @LawID = LawID, @Node = [Node] 
	FROM wag.LawWageTitle
	WHERE ID = @ID

	BEGIN TRY
		BEGIN TRAN
			
			DELETE FROM wag.LawWageTitle
			WHERE COALESCE(OrganID, pbl.EmptyGuid()) = COALESCE(@OrganID, pbl.EmptyGuid())
				AND LawID = @LawID 
				AND [Node].IsDescendantOf(@Node) = 1

			DELETE FROM wag.LawWageTitle
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID ('wag.spGetLawWageTitle'))
DROP PROCEDURE wag.spGetLawWageTitle
GO

CREATE PROCEDURE wag.spGetLawWageTitle
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT LawWageTitle.ID,
		LawWageTitle.OrganID,
		OrganLaw.ID OrganLawID,
		LawWageTitle.LawID,
		LawWageTitle.WageTitleID,
		LawWageTitle.[Order],
		LawWageTitle.[OrderType],
		LawWageTitle.WageTitleGroupID,
		WageTitle.[Code],
		WageTitle.[Name],
		WageTitle.[CreationDate],
		WageTitle.[Type],
		WageTitle.[IncomeType],
		WageTitle.[Enabled],
		WageTitle.[CurrentMinimum],
		WageTitle.[CurrentMaximum],
		WageTitle.[DelayedMinimum],
		WageTitle.[DelayedMaximum],
		WageTitle.TreasuryItemID,
		WageTitle.SacrificialReturnWageTitleID,
		TreasuryItem.Code TreasuryCode,
		TreasuryItem.Name TreasuryItemName,
		WageTitleGroup.[Code] ParentCode,
		WageTitleGroup.[IncomeType] ParentIncomeType
	FROM wag.LawWageTitle LawWageTitle
		INNER JOIN wag.WageTitle ON WageTitle.ID = LawWageTitle.WageTitleID
		LEFT JOIN law.OrganLaw ON OrganLaw.LawID = LawWageTitle.LawID AND OrganLaw.OrganID = LawWageTitle.OrganID
		INNER JOIN wag.WageTitleGroup ON WageTitleGroup.ID = LawWageTitle.WageTitleGroupID
		LEFT JOIN wag.TreasuryItem ON TreasuryItem.ID = WageTitle.TreasuryItemID
	WHERE LawWageTitle.ID = @ID 
	ORDER BY [Order]

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetLawWageTitles') IS NOT NULL
    DROP PROCEDURE wag.spGetLawWageTitles
GO

CREATE PROCEDURE wag.spGetLawWageTitles
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AWageTitleID UNIQUEIDENTIFIER,
	@AWageTitleGroupID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
		SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@WageTitleID UNIQUEIDENTIFIER = @AWageTitleID,
		@WageTitleGroupID UNIQUEIDENTIFIER = @AWageTitleGroupID

	SELECT 
		LawWageTitle.ID,
		LawWageTitle.OrganID,
		OrganLaw.ID OrganLawID,
		LawWageTitle.LawID,
		LawWageTitle.[WageTitleID],
		LawWageTitle.[Order],
		LawWageTitle.OrderType,
		LawWageTitle.WageTitleGroupID,
		WageTitle.Code,
		WageTitle.[Name],
		WageTitle.CreationDate,
		WageTitle.[Type],
		WageTitle.IncomeType,
		WageTitle.[Enabled],
		WageTitle.CurrentMinimum,
		WageTitle.CurrentMaximum,
		WageTitle.DelayedMinimum,
		WageTitle.DelayedMaximum,
		WageTitle.TreasuryItemID,
		WageTitle.SacrificialReturnWageTitleID,
		TreasuryItem.Code TreasuryCode,
		TreasuryItem.Name TreasuryItemName,
		WageTitleGroup.Code ParentCode,
		WageTitleGroup.IncomeType ParentIncomeType
	FROM wag.LawWageTitle LawWageTitle
		INNER JOIN wag.WageTitle WageTitle ON WageTitle.ID = LawWageTitle.[WageTitleID]
		LEFT JOIN law.OrganLaw OrganLaw ON OrganLaw.LawID = LawWageTitle.LawID AND OrganLaw.OrganID = LawWageTitle.OrganID
		INNER JOIN wag.WageTitleGroup ON WageTitleGroup.ID = LawWageTitle.[WageTitleGroupID]
		LEFT JOIN wag.TreasuryItem ON TreasuryItem.ID = WageTitle.[TreasuryItemID]
	WHERE LawWageTitle.LawID = @LawID
		AND LawWageTitle.OrganID = COALESCE(@OrganID, pbl.EmptyGuid())
		AND (@WageTitleID IS NULL OR LawWageTitle.[WageTitleID] = @WageTitleID)
		AND (@WageTitleGroupID IS NULL OR LawWageTitle.[WageTitleGroupID] = @WageTitleGroupID)
	ORDER BY [Order]

END
GO
USE [Kama.Aro.Pardakht]
GO

CREATE OR ALTER PROCEDURE wag.spGetLawWageTitlesTemporary
	@APayrollID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
		SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE 

		@PayrollID UNIQUEIDENTIFIER = @APayrollID

	SELECT  DISTINCT
		LawWageTitle.[ID]
		, LawWageTitle.[OrganID]
		, LawWageTitle.[LawID]
		, LawWageTitle.[WageTitleID]
		, LawWageTitle.[Order]
		, LawWageTitle.[OrderType]
		, LawWageTitle.[WageTitleGroupID]
		, WageTitle.[Code]
		, WageTitle.[Name]
		, WageTitle.[Type]
		, WageTitle.[IncomeType]
		, WageTitleGroup.[Code] ParentCode
		, WageTitleGroup.[IncomeType] ParentIncomeType
		, Payroll.[OrganID] OrganLawID
		, PayrollWageTitle.[PayrollID]
	FROM [wag].[Payroll] Payroll
		INNER JOIN [wag].[LawWageTitle] LawWageTitle ON LawWageTitle.[LawID] = Payroll.[LawID] AND LawWageTitle.[OrganID] = Payroll.[OrganID]
		INNER JOIN [wag].[WageTitle] WageTitle ON WageTitle.[ID] = LawWageTitle.[WageTitleID]
		INNER JOIN [law].[OrganLaw] OrganLaw ON OrganLaw.[LawID] = LawWageTitle.[LawID] AND OrganLaw.[OrganID] = LawWageTitle.[OrganID]
		INNER JOIN [wag].[WageTitleGroup] WageTitleGroup ON WageTitleGroup.[ID] = LawWageTitle.[WageTitleGroupID]
		INNER JOIN [wag].[PayrollWageTitle] PayrollWageTitle on PayrollWageTitle.[WageTitleID] = LawWageTitle.[WageTitleID] AND PayrollWageTitle.[PayrollID] = Payroll.[ID]
	WHERE Payroll.[ID] = @PayrollID
	ORDER BY [Order]

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyLawWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spModifyLawWageTitle
GO

CREATE PROCEDURE wag.spModifyLawWageTitle  
	 @AIsNewRecord BIT    
	, @AID UNIQUEIDENTIFIER 
    , @AOrganID UNIQUEIDENTIFIER
	, @ALawID UNIQUEIDENTIFIER
	, @AWageTitleID UNIQUEIDENTIFIER
	, @AOrderType TINYINT
	, @AWageTitleGroupID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET ANSI_NULLS OFF;

    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0)
        , @ID UNIQUEIDENTIFIER = @AID
        , @OrganID UNIQUEIDENTIFIER = @AOrganID
	    , @LawID UNIQUEIDENTIFIER = @ALawID
		, @WageTitleID UNIQUEIDENTIFIER = @AWageTitleID
		, @Order INT
		, @OrderType TINYINT= COALESCE(@AOrderType, 0)
		, @WageTitleGroupID UNIQUEIDENTIFIER = @AWageTitleGroupID
		, @Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1	-- insert
			BEGIN
				SET @Order = (SELECT MAX([Order]) FROM wag.LawWageTitle
								WHERE [LawID] = @LawID
										AND COALESCE([OrganID], 0x) = COALESCE(@OrganID, 0x)
										AND COALESCE([WageTitleGroupID], 0x) = COALESCE(@WageTitleGroupID, 0x))
				SET @Order = COALESCE(@Order, 0) + 1
				INSERT INTO [wag].[LawWageTitle]
					([ID], [OrganID], [LawID], [WageTitleID], [Order], [OrderType], [WageTitleGroupID])
				VALUES
					(@ID, COALESCE(@OrganID, 0x), @LawID, @WageTitleID, @Order, @OrderType, @WageTitleGroupID)
			END
			ELSE	-------------- update
			BEGIN 

				UPDATE [wag].[LawWageTitle]
				SET [OrderType] = @OrderType
				WHERE ID = @ID
			END
		COMMIT

	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH
	
    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spSetLawWageTitleOrder') IS NOT NULL
    DROP PROCEDURE wag.spSetLawWageTitleOrder
GO

CREATE PROCEDURE wag.spSetLawWageTitleOrder  
	@ALawWageTitleID UNIQUEIDENTIFIER,
	@ADirection TINYINT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET ANSI_NULLS OFF;

    DECLARE 
		@LawWageTitleID UNIQUEIDENTIFIER = @ALawWageTitleID
		, @Direction TINYINT = @ADirection 
		, @WageTitleGroupID UNIQUEIDENTIFIER
		, @LawID UNIQUEIDENTIFIER
		, @OrganID UNIQUEIDENTIFIER
		, @Order INT
		, @OrderToReplace INT
		, @IDToReplace UNIQUEIDENTIFIER
	
	SELECT @Order = [Order], @WageTitleGroupID = [WageTitleGroupID], @LawID = LawID, @OrganID = OrganID FROM wag.LawWageTitle WHERE ID = @LawWageTitleID

	BEGIN TRY
		BEGIN TRAN
			
			IF @Direction = 1   -- up
				SET @IDToReplace = (SELECT Top 1 ID FROM wag.LawWageTitle WHERE [WageTitleGroupID] = @WageTitleGroupID AND [Order] < @Order AND LawID = @LawID AND COALESCE(OrganID, pbl.EmptyGuid()) = COALESCE(@OrganID, pbl.EmptyGuid()) Order BY [ORDER] DESC)
			ELSE IF @Direction = 2   -- down
				SET @IDToReplace = (SELECT Top 1 ID FROM wag.LawWageTitle WHERE [WageTitleGroupID] = @WageTitleGroupID AND [Order] > @Order AND LawID = @LawID AND COALESCE(OrganID, pbl.EmptyGuid()) = COALESCE(@OrganID, pbl.EmptyGuid()) Order BY [ORDER])

			SET @OrderToReplace = (SELECT [Order] FROM wag.LawWageTitle WHERE ID = @IDToReplace)

			IF @IDToReplace IS NOT NULL
			BEGIN
				Update wag.LawWageTitle 
				SET [Order] = @OrderToReplace
				WHERE ID = @LawWageTitleID

				Update wag.LawWageTitle 
				SET [Order] = @Order
				WHERE ID = @IDToReplace
			END

		COMMIT

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID ('wag.spSetLawWageTitleOrderType'))
DROP PROCEDURE wag.spSetLawWageTitleOrderType
GO

CREATE PROCEDURE wag.spSetLawWageTitleOrderType  
	@ALawWageTitleID UNIQUEIDENTIFIER
	, @AOrderType TINYINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE 
		@LawWageTitleID UNIQUEIDENTIFIER = @ALawWageTitleID
		, @OrderType TINYINT = @AOrderType 

	BEGIN TRY
		BEGIN TRAN
				Update wag.LawWageTitle 
				SET [OrderType] = @OrderType
				WHERE ID = @LawWageTitleID

		COMMIT

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('law.spDeletePaymentRule'))
	DROP PROCEDURE law.spDeletePaymentRule
GO

CREATE PROCEDURE law.spDeletePaymentRule
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE law.PaymentRule
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetDeletedPaymentRules') IS NOT NULL
    DROP PROCEDURE law.spGetDeletedPaymentRules
GO

CREATE PROCEDURE law.spGetDeletedPaymentRules 
	@AIDs NVARCHAR(MAX),
	@AFromCreationDate DATETIME,
	@AToCreationDate DATETIME,
	@ACreatorUserIDs NVARCHAR(MAX),
	@ACreatorPositionIDs NVARCHAR(MAX),
	@AFromLastModificationDate DATETIME,
	@AToLastModificationDate DATETIME,
	@ASalaryItemIDs NVARCHAR(MAX),
	@AConditionIDs NVARCHAR(MAX),
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@FromCreationDate DATETIME = @AFromCreationDate,
		@ToCreationDate DATETIME = DATEADD(DAY, 1, @AToCreationDate),
		@CreatorUserIDs NVARCHAR(MAX) = TRIM(@ACreatorUserIDs),
		@CreatorPositionIDs NVARCHAR(MAX) = TRIM(@ACreatorPositionIDs),
		@FromLastModificationDate DATETIME = @AFromLastModificationDate,
		@ToLastModificationDate DATETIME = DATEADD(DAY, 1, @AToLastModificationDate),
		@SalaryItemIDs NVARCHAR(MAX) = TRIM(@ASalaryItemIDs),
		@ConditionIDs NVARCHAR(MAX) = TRIM(@AConditionIDs),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = TRIM(@ASortExp),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH SICount AS (
		SELECT
			COUNT(ID) SalaryItemCount,
			PaymentRuleID
		FROM [law].[PaymentRuleSalaryItem] PRSI
		WHERE PRSI.RemoveDate IS NULL
		GROUP BY PaymentRuleID
	)
	, MainSelect AS
	(
		SELECT DISTINCT
			PR.[ID],
			PR.[Name],
			PR.[Code],
			PR.[Comment],
			SICount.SalaryItemCount,
			0 ConditionCount,
			PR.[CreationDate],
			PR.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			PR.[CreatorPositionID],
			PR.[LastModificationDate],
			PR.[LastModifierUserID],
			MU.FirstName + N' ' + MU.LastName LastModifierName,
			PR.[LastModifierPositionID],
			PR.[RemoveDate],
			PR.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			PR.[RemoverPositionID]
		FROM [law].[PaymentRule] PR
			LEFT JOIN [law].[PaymentRuleSalaryItem] PRSI ON PRSI.PaymentRuleID = PR.ID
			LEFT JOIN SICount ON SICount.PaymentRuleID = PR.[ID]
			LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = PR.ID
			LEFT JOIN OPENJSON(@CreatorUserIDs) CreatorUserIDs ON CreatorUserIDs.value = PR.[CreatorUserID]
			LEFT JOIN OPENJSON(@CreatorPositionIDs) CreatorPositionIDs ON CreatorPositionIDs.value = PR.[CreatorPositionID]
			LEFT JOIN OPENJSON(@SalaryItemIDs) SalaryItemIDs ON SalaryItemIDs.value = PRSI.SalaryItemID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PR.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] MU ON MU.ID = PR.LastModifierUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = PR.RemoverUserID
		WHERE (PR.[RemoveDate] IS NOT NULL) AND (PRSI.RemoveDate IS NULL)
			AND (@IDs IS NULL OR IDs.value = PR.ID)
			AND (@FromCreationDate IS NULL OR PR.CreationDate >= @FromCreationDate)
			AND (@ToCreationDate IS NULL OR PR.CreationDate < @ToCreationDate)
			AND (@CreatorUserIDs IS NULL OR CreatorUserIDs.value = PR.[CreatorUserID])
			AND (@CreatorPositionIDs IS NULL OR CreatorPositionIDs.value = PR.[CreatorPositionID])
			AND (@FromLastModificationDate IS NULL OR PR.LastModificationDate >= @FromLastModificationDate) 
			AND (@ToLastModificationDate IS NULL OR PR.LastModificationDate < @ToLastModificationDate)
			AND (@SalaryItemIDs IS NULL OR SalaryItemIDs.value = PRSI.SalaryItemID)
			AND (@FromRemoveDate IS NULL OR PR.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR PR.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetPaymentRule') IS NOT NULL
    DROP PROCEDURE law.spGetPaymentRule
GO

CREATE PROCEDURE law.spGetPaymentRule 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID
	; WITH SICount AS (
		SELECT
			COUNT(ID) SalaryItemCount,
			PaymentRuleID
		FROM [law].[PaymentRuleSalaryItem] PRSI
		WHERE PRSI.RemoveDate IS NULL
		GROUP BY PaymentRuleID
	)
	SELECT DISTINCT
		PR.[ID],
		PR.[Name],
		PR.[Code],
		PR.[Comment],
		SICount.SalaryItemCount,
		0 ConditionCount,
		PR.[CreationDate],
		PR.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		PR.[CreatorPositionID],
		PR.[LastModificationDate],
		PR.[LastModifierUserID],
		MU.FirstName + N' ' + MU.LastName LastModifierName,
		PR.[LastModifierPositionID],
		PR.[RemoveDate],
		PR.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName RemoverName,
		PR.[RemoverPositionID]
	FROM [law].[PaymentRule] PR
		LEFT JOIN SICount ON SICount.PaymentRuleID = PR.[ID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PR.CreatorUserID
		LEFT JOIN [Kama.Aro.Organization].[org].[User] MU ON MU.ID = PR.LastModifierUserID
		LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = PR.RemoverUserID
	WHERE PR.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetPaymentRules') IS NOT NULL
    DROP PROCEDURE law.spGetPaymentRules
GO

CREATE PROCEDURE law.spGetPaymentRules 
	@AIDs NVARCHAR(MAX),
	@AFromCreationDate DATETIME,
	@AToCreationDate DATETIME,
	@ACreatorUserIDs NVARCHAR(MAX),
	@ACreatorPositionIDs NVARCHAR(MAX),
	@AFromLastModificationDate DATETIME,
	@AToLastModificationDate DATETIME,
	@ASalaryItemIDs NVARCHAR(MAX),
	@AConditionIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@FromCreationDate DATETIME = @AFromCreationDate,
		@ToCreationDate DATETIME = DATEADD(DAY, 1, @AToCreationDate),
		@CreatorUserIDs NVARCHAR(MAX) = TRIM(@ACreatorUserIDs),
		@CreatorPositionIDs NVARCHAR(MAX) = TRIM(@ACreatorPositionIDs),
		@FromLastModificationDate DATETIME = @AFromLastModificationDate,
		@ToLastModificationDate DATETIME = DATEADD(DAY, 1, @AToLastModificationDate),
		@SalaryItemIDs NVARCHAR(MAX) = TRIM(@ASalaryItemIDs),
		@ConditionIDs NVARCHAR(MAX) = TRIM(@AConditionIDs),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = TRIM(@ASortExp),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH SICount AS (
		SELECT
			COUNT(ID) SalaryItemCount,
			PaymentRuleID
		FROM [law].[PaymentRuleSalaryItem] PRSI
		WHERE PRSI.RemoveDate IS NULL
		GROUP BY PaymentRuleID
	)
	, MainSelect AS
	(
		SELECT DISTINCT
			PR.[ID],
			PR.[Name],
			PR.[Code],
			PR.[Comment],
			SICount.SalaryItemCount,
			0 ConditionCount,
			PR.[CreationDate],
			PR.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			PR.[CreatorPositionID],
			PR.[LastModificationDate],
			PR.[LastModifierUserID],
			MU.FirstName + N' ' + MU.LastName LastModifierName,
			PR.[LastModifierPositionID]
		FROM [law].[PaymentRule] PR
			LEFT JOIN [law].[PaymentRuleSalaryItem] PRSI ON PRSI.PaymentRuleID = PR.ID
			LEFT JOIN SICount ON SICount.PaymentRuleID = PR.[ID]
			LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = PR.ID
			LEFT JOIN OPENJSON(@CreatorUserIDs) CreatorUserIDs ON CreatorUserIDs.value = PR.[CreatorUserID]
			LEFT JOIN OPENJSON(@CreatorPositionIDs) CreatorPositionIDs ON CreatorPositionIDs.value = PR.[CreatorPositionID]
			LEFT JOIN OPENJSON(@SalaryItemIDs) SalaryItemIDs ON SalaryItemIDs.value = PRSI.SalaryItemID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PR.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] MU ON MU.ID = PR.LastModifierUserID
		WHERE (PR.[RemoveDate] IS NULL) AND (PRSI.RemoveDate IS NULL)
			AND (@IDs IS NULL OR IDs.value = PR.ID)
			AND (@FromCreationDate IS NULL OR PR.CreationDate >= @FromCreationDate)
			AND (@ToCreationDate IS NULL OR PR.CreationDate < @ToCreationDate)
			AND (@CreatorUserIDs IS NULL OR CreatorUserIDs.value = PR.[CreatorUserID])
			AND (@CreatorPositionIDs IS NULL OR CreatorPositionIDs.value = PR.[CreatorPositionID])
			AND (@FromLastModificationDate IS NULL OR PR.LastModificationDate >= @FromLastModificationDate) 
			AND (@ToLastModificationDate IS NULL OR PR.LastModificationDate < @ToLastModificationDate)
			AND (@SalaryItemIDs IS NULL OR SalaryItemIDs.value = PRSI.SalaryItemID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spModifyPaymentRule') IS NOT NULL
    DROP PROCEDURE law.spModifyPaymentRule
GO

CREATE PROCEDURE law.spModifyPaymentRule
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(750),
	@AComment NVARCHAR(Max),
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(1500) = TRIM(@AName),
		@Comment NVARCHAR(MAX) = TRIM(@AComment),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID,
		@Code VARCHAR(20)
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				SET @Code = COALESCE((SELECT MAX(Code) FROM [law].[PaymentRule]), 0) + 1
				INSERT INTO [law].[PaymentRule]
				([ID], [Name], [Code], [Comment], [CreationDate], [CreatorUserID], [CreatorPositionID], [LastModificationDate], [LastModifierUserID], [LastModifierPositionID])
				VALUES
				(@ID, @Name, @Code, @Comment, GETDATE(), @ModifireUserID, @ModifirePositionID, GETDATE(), @ModifireUserID, @ModifirePositionID)
			END
			ELSE -- update
			BEGIN 
				UPDATE [law].[PaymentRule]
				SET
				[Name] = @Name,
				--[Code] = @Code,
				[Comment] = @Comment,
				[LastModificationDate] = GETDATE(),
				[LastModifierUserID] = @ModifireUserID,
				[LastModifierPositionID] = @ModifirePositionID
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spUpdatePaymentRuleModificationDetails') IS NOT NULL
    DROP PROCEDURE law.spUpdatePaymentRuleModificationDetails
GO

CREATE PROCEDURE law.spUpdatePaymentRuleModificationDetails
	@AIDs NVARCHAR(MAX),
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			UPDATE PR
			SET 
				[LastModificationDate] = GETDATE(),
				[LastModifierUserID] = @ModifireUserID,
				[LastModifierPositionID] = @ModifirePositionID
			FROM [law].[PaymentRule] PR
			INNER JOIN OPENJSON(@IDs) IDs ON IDs.value = PR.ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('law.spDeletePaymentRuleSalaryItem'))
	DROP PROCEDURE law.spDeletePaymentRuleSalaryItem
GO

CREATE PROCEDURE law.spDeletePaymentRuleSalaryItem
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [law].[PaymentRuleSalaryItem]
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetDeletedPaymentRuleSalaryItems') IS NOT NULL
    DROP PROCEDURE law.spGetDeletedPaymentRuleSalaryItems
GO

CREATE PROCEDURE law.spGetDeletedPaymentRuleSalaryItems 
	@APaymentRuleID UNIQUEIDENTIFIER,
	@ASalaryItemID UNIQUEIDENTIFIER,
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@PaymentRuleID UNIQUEIDENTIFIER = @APaymentRuleID,
		@SalaryItemID UNIQUEIDENTIFIER = @ASalaryItemID,
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = TRIM(@ASortExp),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH MainSelect AS
	(
		SELECT
			PRSI.[ID],
			PRSI.[PaymentRuleID],
			PR.[Name] PaymentRuleName,
			PR.[Code] PaymentRuleCode,
			PRSI.[SalaryItemID],
			SI.[Name] SalaryItemName,
			SI.[Code] SalaryItemCode,
			SI.[Type] SalaryItemType,
			SI.[Comment] SalaryItemComment,
			SI.[TreasuryItemID],
			TI.[Name] TreasuryItemName,
			TI.[Code] TreasuryItemCode,
			PRSI.[CreationDate],
			PRSI.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			PRSI.[CreatorPositionID],
			PRSI.[RemoveDate],
			PRSI.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			PRSI.[RemoverPositionID]
		FROM [law].[PaymentRuleSalaryItem] PRSI
			INNER JOIN [law].[PaymentRule] PR ON PR.ID = PRSI.[PaymentRuleID]
			INNER JOIN [wag].[SalaryItem] SI ON SI.ID = PRSI.[SalaryItemID]
			INNER JOIN [wag].[TreasuryItem] TI ON TI.ID = SI.[TreasuryItemID]
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PRSI.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = PRSI.RemoverUserID
		WHERE (PRSI.[RemoveDate] IS NOT NULL)
			AND (@PaymentRuleID IS NULL OR PRSI.[PaymentRuleID] = @PaymentRuleID)
			AND (@SalaryItemID IS NULL OR PRSI.[SalaryItemID] = @SalaryItemID)
			AND (@FromRemoveDate IS NULL OR PRSI.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR PRSI.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetPaymentRuleSalaryItem') IS NOT NULL
    DROP PROCEDURE law.spGetPaymentRuleSalaryItem
GO

CREATE PROCEDURE law.spGetPaymentRuleSalaryItem 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID
	
	SELECT
		PRSI.[ID],
		PRSI.[PaymentRuleID],
		PR.[Name] PaymentRuleName,
		PR.[Code] PaymentRuleCode,
		PRSI.[SalaryItemID],
		SI.[Name] SalaryItemName,
		SI.[Code] SalaryItemCode,
		SI.[Type] SalaryItemType,
		SI.[Comment] SalaryItemComment,
		SI.[TreasuryItemID],
		TI.[Name] TreasuryItemName,
		TI.[Code] TreasuryItemCode,
		PRSI.[CreationDate],
		PRSI.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		PRSI.[CreatorPositionID],
		PRSI.[RemoveDate],
		PRSI.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName RemoverName,
		PRSI.[RemoverPositionID]
	FROM [law].[PaymentRuleSalaryItem] PRSI
		INNER JOIN [law].[PaymentRule] PR ON PR.ID = PRSI.[PaymentRuleID]
		INNER JOIN [wag].[SalaryItem] SI ON SI.ID = PRSI.[SalaryItemID]
		INNER JOIN [wag].[TreasuryItem] TI ON TI.ID = SI.[TreasuryItemID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PRSI.CreatorUserID
		LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = PRSI.RemoverUserID
	WHERE PR.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spGetPaymentRuleSalaryItems') IS NOT NULL
    DROP PROCEDURE law.spGetPaymentRuleSalaryItems
GO

CREATE PROCEDURE law.spGetPaymentRuleSalaryItems 
	@APaymentRuleID UNIQUEIDENTIFIER,
	@ASalaryItemID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@PaymentRuleID UNIQUEIDENTIFIER = @APaymentRuleID,
		@SalaryItemID UNIQUEIDENTIFIER = @ASalaryItemID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = TRIM(@ASortExp),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH MainSelect AS
	(
		SELECT
			PRSI.[ID],
			PRSI.[PaymentRuleID],
			PR.[Name] PaymentRuleName,
			PR.[Code] PaymentRuleCode,
			PRSI.[SalaryItemID],
			SI.[Name] SalaryItemName,
			SI.[Code] SalaryItemCode,
			SI.[Type] SalaryItemType,
			SI.[Comment] SalaryItemComment,
			SI.[TreasuryItemID],
			TI.[Name] TreasuryItemName,
			TI.[Code] TreasuryItemCode,
			PRSI.[CreationDate],
			PRSI.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			PRSI.[CreatorPositionID]
		FROM [law].[PaymentRuleSalaryItem] PRSI
			INNER JOIN [law].[PaymentRule] PR ON PR.ID = PRSI.[PaymentRuleID]
			INNER JOIN [wag].[SalaryItem] SI ON SI.ID = PRSI.[SalaryItemID]
			INNER JOIN [wag].[TreasuryItem] TI ON TI.ID = SI.[TreasuryItemID]
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PRSI.CreatorUserID
		WHERE (PRSI.[RemoveDate] IS NULL) AND (SI.[RemoveDate] IS NULL)
			AND (@PaymentRuleID IS NULL OR PRSI.[PaymentRuleID] = @PaymentRuleID)
			AND (@SalaryItemID IS NULL OR PRSI.[SalaryItemID] = @SalaryItemID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('law.spModifyPaymentRuleSalaryItem') IS NOT NULL
    DROP PROCEDURE law.spModifyPaymentRuleSalaryItem
GO

CREATE PROCEDURE law.spModifyPaymentRuleSalaryItem
	@AAddToPaymentRule BIT,
	@APaymentRuleIDs NVARCHAR(MAX),
	@ASalaryItemIDs NVARCHAR(MAX),
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    DECLARE 
		@AddToPaymentRule BIT = COALESCE(@AAddToPaymentRule, 0),
		@PaymentRuleIDs NVARCHAR(MAX) = TRIM(@APaymentRuleIDs),
		@SalaryItemIDs NVARCHAR(MAX) = TRIM(@ASalaryItemIDs),
		@PaymentRuleID UNIQUEIDENTIFIER,
		@SalaryItemID UNIQUEIDENTIFIER,
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID
	BEGIN TRY
		BEGIN TRAN
			IF @AddToPaymentRule = 1
			BEGIN
				SET @PaymentRuleID = (SELECT TOP(1) PaymentRuleIDs.value FROM OPENJSON(@PaymentRuleIDs) PaymentRuleIDs)

				UPDATE [law].[PaymentRuleSalaryItem]
				SET [RemoveDate] = GETDATE(), [RemoverUserID] = @AModifireUserID, [RemoverPositionID] = @AModifirePositionID
				WHERE PaymentRuleID = @PaymentRuleID

				INSERT INTO [law].[PaymentRuleSalaryItem]
				([ID], [PaymentRuleID], [SalaryItemID], [CreationDate], [CreatorUserID], [CreatorPositionID])
				SELECT
				NEWID(),
				@PaymentRuleID,
				SalaryItemIDs.value,
				GETDATE(),
				@ModifireUserID,
				@ModifirePositionID
				FROM OPENJSON(@SalaryItemIDs) SalaryItemIDs
			END
			ELSE
			BEGIN 
				SET @SalaryItemID = (SELECT TOP(1) SalaryItemIDs.value FROM OPENJSON(@SalaryItemIDs) SalaryItemIDs)

				UPDATE [law].[PaymentRuleSalaryItem]
				SET [RemoveDate] = GETDATE(), [RemoverUserID] = @AModifireUserID, [RemoverPositionID] = @AModifirePositionID
				WHERE SalaryItemID = @SalaryItemID

				INSERT INTO [law].[PaymentRuleSalaryItem]
				([ID], [PaymentRuleID], [SalaryItemID], [CreationDate], [CreatorUserID], [CreatorPositionID])
				SELECT
				NEWID(),
				PaymentRuleIDs.value,
				@SalaryItemID,
				GETDATE(),
				@ModifireUserID,
				@ModifirePositionID
				FROM OPENJSON(@PaymentRuleIDs) PaymentRuleIDs
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeletePayrollRequest'))
	DROP PROCEDURE wag.spDeletePayrollRequest
GO

CREATE PROCEDURE wag.spDeletePayrollRequest
	@AID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID, 
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@GetDate DATETIME = GETDATE()
				
	BEGIN TRY
		BEGIN TRAN

			UPDATE
				pbl.BaseDocument
			SET
				RemoverPositionID = @RemoverPositionID,
				RemoverUserID = @RemoverUserID,
				RemoveDate = @GetDate
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetPayrollRequest'))
	DROP PROCEDURE wag.spGetPayrollRequest
GO

CREATE PROCEDURE wag.spGetPayrollRequest
	@AID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@ActionState TINYINT = 0

	IF EXISTS(SELECT 1 FROM pbl.DocumentFlow flow WHERE flow.ToPositionID = @CurrentPositionID AND flow.DocumentID = @ID AND flow.ActionDate IS NULL)
	SET @ActionState = 1

	;WITH FirstFlow AS
	(	
		SELECT 
			[Date],
			DocumentID, 
			FromPositionID,
			ToPositionID,
			department.ID ApplicantOrganID,
			department.[Name] ApplicantOrganName
		FROM pbl.DocumentFlow flow
			INNER JOIN org.Position position ON position.ID = flow.FromPositionID
			INNER JOIN org.Department department ON department.ID = position.DepartmentID
		WHERE flow.FromDocState = 1 
			AND flow.ToDocState = 1
			AND flow.DocumentID = @ID
	)
	SELECT 
		@ActionState ActionState,
		request.[ID],
		request.[OrganID],
		request.[PositionSubTypeID],
		request.[Month],
		request.[Year],
		request.[Comment],
		Organ.[Name] OrganName,
		Organ.ProvinceID,
		Organ.[Type] DepartmentType,
		BaseDocument.[Type] DocumentType,
		BaseDocument.TrackingCode,
		BaseDocument.DocumentNumber,
		BaseDocument.ProcessID,
		FirstFlow.ApplicantOrganID,
		FirstFlow.ApplicantOrganName,
		FirstFlow.ToPositionID FirstFlowToPositionID,
		FirstFlow.[Date] CreationDate,
		CreatorUser.FirstName + ' ' + CreatorUser.LastName CreatorFullName,
		CreatorUser.ID CreatorUserID,
		CreatorPosition.ID CreatorPositionID,
		lastFlow.ID LastFlowID,
		lastFlow.SendType LastSendType,
		CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) LastDocState,
		LastFlow.[Date] LastFlowDate,
		LastFlow.ReadDate LastReadDate,
		LastFlow.FromUserID LastFromUserID,
		LastFlow.ToPositionID LastToPositionID,
		LastToPosition.[Type] LastToPositionType,
		Organ.OrganType OrganType,
		process.[Name] ProcessName,
		process.Code ProcessCode,
		positionSubType.[Name] PositionSubTypeName
	FROM [wag].[PayrollRequest] request
		INNER JOIN pbl.BaseDocument BaseDocument on BaseDocument.ID = request.ID
		INNER JOIN [pbl].[Process] process ON process.ID = BaseDocument.ProcessID
		INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
		LEFT JOIN org.[Position] LastToPosition ON LastToPosition.ID = LastFlow.ToPositionID
		LEFT JOIN org.Department Organ ON Organ.ID = request.OrganID
		LEFT JOIN FirstFlow ON FirstFlow.DocumentID = BaseDocument.ID
		LEFT JOIN org.Position CreatorPosition ON CreatorPosition.ID = FirstFlow.FromPositionID
		LEFT JOIN org.[User] CreatorUser ON CreatorUser.ID = CreatorPosition.UserID
		LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = request.PositionSubTypeID
	WHERE (BaseDocument.RemoverPositionID IS NULL)
		AND (request.ID = @ID)
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetPayrollRequests'))
	DROP PROCEDURE wag.spGetPayrollRequests
GO

CREATE PROCEDURE wag.spGetPayrollRequests
	@AOrganID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@AOrganIDs NVARCHAR(MAX),
	@AOrganCode VARCHAR(20),
	@AOrganName NVARCHAR(256),
	@AParentOrganID UNIQUEIDENTIFIER,
	@ATrackingCode NVARCHAR(100),
	@ALastDocState TINYINT,
	@ALastDocStates NVARCHAR(MAX),
	@AConfirmDateFrom DATE,
	@AConfirmDateTo DATE,
	@ACreationDateFrom DATE,
	@ACreationDateTo DATE,
	@ADepartmentType TINYINT,
	@AProvinceID UNIQUEIDENTIFIER,
	@AProcessID UNIQUEIDENTIFIER,
	@AMonth TINYINT,
	@AYear SMALLINT,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@OrganCode VARCHAR(20) = LTRIM(RTRIM(@AOrganCode)),
		@OrganName NVARCHAR(256) = @AOrganName,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@TrackingCode NVARCHAR(100) = @ATrackingCode,
		@LastDocState TINYINT = COALESCE(@ALastDocState, 0),
		@LastDocStates NVARCHAR(MAX) = @ALastDocStates,
		@ConfirmDateFrom DATE = @AConfirmDateFrom,
		@ConfirmDateTo DATE = @AConfirmDateTo,
		@CreationDateFrom DATE = @ACreationDateFrom,
		@CreationDateTo DATE = @ACreationDateTo,
		@DepartmentType TINYINT = COALESCE(@ADepartmentType, 0),
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@ProcessID UNIQUEIDENTIFIER = @AProcessID,
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	IF @OrganID = '00000000-0000-0000-0000-000000000000' 
		SET @OrganID = NULL

	;WITH Organ AS
	(
		SELECT DISTINCT Department.ID, Department.[Name], Department.ProvinceID, Department.[Type]
		FROM org.Department
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Department.ID
		WHERE (@OrganID IS NULL OR Department.ID = @OrganID)
			AND (@OrganCode IS NULL OR Department.Code = @OrganCode)
			AND (@OrganIDs IS NULL OR OrganIDs.value = Department.ID)
			AND (@OrganName IS NULL OR Department.[Name] LIKE N'%' + @OrganName + '%')
			AND (@ProvinceID IS NULL OR Department.ProvinceID = @ProvinceID AND Department.[Type] = 2)
			AND (@DepartmentType < 1 OR Department.[Type] = @DepartmentType)
			
	)
	, FirstFlow AS
	(	
		SELECT [Date], DocumentID, FromPositionID, department.ID ApplicantOrganID, department.[Name] ApplicantOrganName
		FROM pbl.DocumentFlow flow
		INNER JOIN org.Position position ON position.ID = flow.FromPositionID
		INNER JOIN org.Department department ON department.ID = position.DepartmentID
		WHERE flow.FromDocState = 1
			AND flow.ToDocState = 1
	)
	, MainSelect AS 
	(
		SELECT DISTINCT
			request.[ID],
			request.[OrganID],
			request.[PositionSubTypeID],
			request.[Month],
			request.[Comment],
			Organ.[Name] OrganName,
			Organ.ProvinceID,
			Organ.[Type] DepartmentType,
			FirstFlow.ApplicantOrganID,
			FirstFlow.ApplicantOrganName,
			BaseDocument.[Type] DocumentType,
			BaseDocument.TrackingCode,
			BaseDocument.DocumentNumber,
			BaseDocument.ProcessID,
			FirstFlow.[Date] CreationDate,
			lastFlow.ID LastFlowID,
			lastFlow.SendType LastSendType,
			CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) LastDocState,
			LastFlow.[Date] LastFlowDate,
			LastFlow.ReadDate LastReadDate,
			LastFlow.FromUserID LastFromUserID,
			LastFlow.ToPositionID LastToPositionID,
			process.[Name] ProcessName,
			process.Code ProcessCode,
			positionSubType.[Name] PositionSubTypeName
		FROM [wag].[PayrollRequest] request
			INNER JOIN pbl.BaseDocument on BaseDocument.ID = request.ID
			INNER JOIN [pbl].[Process] process ON process.ID = BaseDocument.ProcessID
			INNER JOIN Organ ON Organ.ID = request.OrganID
			LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = request.PositionSubTypeID
			INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
			LEFT JOIN pbl.DocumentFlow confirmFlow ON confirmFlow.DocumentID = BaseDocument.ID AND confirmFlow.ToDocState = 100 AND confirmFlow.ActionDate IS NULL
			INNER JOIN FirstFlow ON FirstFlow.DocumentID = BaseDocument.ID
		WHERE (BaseDocument.RemoverPositionID IS NULL)
			AND (BaseDocument.[Type] = 4)
			AND (@TrackingCode IS NULL OR BaseDocument.TrackingCode = @TrackingCode)
			AND (@LastDocState < 1 OR LastFlow.ToDocState = @LastDocState)
			AND (@ConfirmDateFrom IS NULL OR CAST(confirmFlow.[Date] AS DATE) >= @ConfirmDateFrom)
			AND (@ConfirmDateTo IS NULL OR CAST(confirmFlow.[Date] AS DATE) <= @ConfirmDateTo)
			AND (@CreationDateFrom IS NULL OR CAST(FirstFlow.[Date] AS DATE) >= @CreationDateFrom)
			AND (@CreationDateTo IS NULL OR CAST(FirstFlow.[Date] AS DATE) <= @CreationDateTo)
			AND (@LastDocStates IS NULL OR LastFlow.ToDocState IN (SELECT value FROM OPENJSON(@LastDocStates)))
			AND (@ProcessID IS NULL OR BaseDocument.ProcessID = @ProcessID)
			AND (@PositionSubTypeID IS NULL OR request.PositionSubTypeID = @PositionSubTypeID)
			AND (@Month < 1 OR request.[Month] = @Month)
			AND (@Year < 1 OR request.[Year] = @Year)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT 
		*
	FROM MainSelect, TempCount
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetPayrollRequestsForCartable'))
	DROP PROCEDURE wag.spGetPayrollRequestsForCartable
GO

CREATE PROCEDURE wag.spGetPayrollRequestsForCartable
	@AActionState TINYINT,
	@AOrganID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@ATrackingCode NVARCHAR(100),
	@AUserPositionID UNIQUEIDENTIFIER,
	@AUserOrganID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ActionState TINYINT = @AActionState,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@TrackingCode NVARCHAR(100) = @ATrackingCode,
		@UserPositionID UNIQUEIDENTIFIER = @AUserPositionID,
		@UserOrganID UNIQUEIDENTIFIER = @AUserOrganID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH Flow AS 
	(
		SELECT DISTINCT DocumentID 
		FROM pbl.DocumentFlow flow
			INNER JOIN pbl.BaseDocument doc ON doc.ID = flow.DocumentID
			LEFT JOIN .org.Position ToPosition ON ToPosition.ID = flow.ToPositionID
		WHERE
			ToPositionID = @UserPositionID
	)
	, FirstFlow AS
	(	
		SELECT [Date], DocumentID, FromPositionID, department.ID ApplicantOrganID, department.[Name] ApplicantOrganName
		FROM pbl.DocumentFlow flow
		INNER JOIN org.Position position ON position.ID = flow.FromPositionID
		INNER JOIN org.Department department ON department.ID = position.DepartmentID
		WHERE flow.FromDocState = 1
			AND flow.ToDocState = 1
	)
	, MainSelect AS 
	(
		SELECT DISTINCT
			request.[ID],
			request.[OrganID],
			request.[PositionSubTypeID],
			request.[Month],
			request.[Year],
			request.[Comment],
			Organ.[Name] OrganName,
			Organ.ProvinceID,
			Organ.[Type] DepartmentType,
			FirstFlow.ApplicantOrganID,
			FirstFlow.ApplicantOrganName,
			BaseDocument.[Type] DocumentType,
			BaseDocument.TrackingCode,
			BaseDocument.DocumentNumber,
			BaseDocument.ProcessID,
			FirstFlow.[Date] CreationDate,
			lastFlow.ID LastFlowID,
			lastFlow.SendType LastSendType,
			CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) LastDocState,
			LastFlow.[Date] LastFlowDate,
			LastFlow.ReadDate LastReadDate,
			LastFlow.FromUserID LastFromUserID,
			LastFlow.ToPositionID LastToPositionID,
			process.[Name] ProcessName,
			process.Code ProcessCode,
			positionSubType.[Name] PositionSubTypeName
		FROM [wag].[PayrollRequest] request
			INNER JOIN pbl.BaseDocument BaseDocument on BaseDocument.ID = request.ID
			INNER JOIN [pbl].[Process] process ON process.ID = BaseDocument.ProcessID
			LEFT JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
			LEFT JOIN org.[Position] LastToPosition ON LastToPosition.ID = LastFlow.ToPositionID
			LEFT JOIN org.Department Organ ON Organ.ID = request.OrganID
			LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = request.PositionSubTypeID
			INNER JOIN FirstFlow ON FirstFlow.DocumentID = BaseDocument.ID
			INNER JOIN Flow ON Flow.DocumentID = BaseDocument.ID
		WHERE (BaseDocument.RemoverPositionID IS NULL)
			AND (BaseDocument.[Type] = 4)
			AND (@OrganID IS NULL OR request.OrganID = @OrganID)
			AND (@PositionSubTypeID IS NULL OR request.PositionSubTypeID = @PositionSubTypeID)
			AND (@TrackingCode IS NULL OR BaseDocument.TrackingCode = @TrackingCode)
			AND @ActionState IN (1, 2, 3, 10)
			AND (@ActionState <> 1 OR LastFlow.ToPositionID = @UserPositionID)
			AND (@ActionState <> 2 OR (LastFlow.ToPositionID <> @UserPositionID AND LastFlow.SendType = 1 AND LastFlow.ToDocState <> 100))
			AND (@ActionState <> 3 OR LastFlow.ToDocState = 100)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, TempCount						
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'wag.spModifyPayrollRequest') AND type in (N'P', N'PC'))
DROP PROCEDURE wag.spModifyPayrollRequest
GO

CREATE PROCEDURE wag.spModifyPayrollRequest
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@AMonth TINYINT,
	@AYear SMALLINT,
	@AComment NVARCHAR(4000),
	@AProcessID UNIQUEIDENTIFIER,
	@ADocumentType TINYINT,	
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Comment NVARCHAR(4000) = LTRIM(RTRIM(@AComment)),
		@ProcessID UNIQUEIDENTIFIER = @AProcessID ,
		@DocumentType TINYINT = COALESCE(@ADocumentType, 0),
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CreationDate DATETIME= GETDATE(),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert 
			BEGIN
				declare @TrackingCode NVARCHAR(10)
				set @TrackingCode = (select STR(FLOOR(RAND(CHECKSUM(NEWID()))*(9999999999-1000000000+1)+1000000000)))

				EXECUTE pbl.spModifyBaseDocument_ 
					@AIsNewRecord = @IsNewRecord, 
					@AID = @ID,
					@AType = @DocumentType,
					@ACreatorPositionID = @CurrentUserPositionID,
					@ATrackingCode = @TrackingCode,
					@ADocumentNumber = NULL, 
					@AProcessID = @ProcessID

				INSERT INTO [wag].[PayrollRequest]
					([ID], [OrganID], [PositionSubTypeID], [Month], [Year], [Comment])
				VALUES
					(@ID, @OrganID, @PositionSubTypeID, @Month, @Year, @Comment)
			END
			ELSE
			BEGIN
				UPDATE request
				SET
					[Comment] = @Comment
				FROM [wag].[PayrollRequest] request
			END

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbo.spArchivePBOBudgetCodes'))
	DROP PROCEDURE pbo.spArchivePBOBudgetCodes
GO

CREATE PROCEDURE pbo.spArchivePBOBudgetCodes
	@AIDs NVARCHAR(MAX),
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE BC
			SET RemoverUserID = @RemoverUserID,
			RemoverPositionID = @RemoverPositionID,
			RemoveDate = GETDATE()
			FROM pbo.BudgetCode BC
			INNER JOIN OPENJSON(@IDs) IDs ON IDs.value = BC.ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbo.spDeletePBOBudgetCode'))
	DROP PROCEDURE pbo.spDeletePBOBudgetCode
GO

CREATE PROCEDURE pbo.spDeletePBOBudgetCode
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbo.BudgetCode
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetDeletedPBOBudgetCodes') IS NOT NULL
    DROP PROCEDURE pbo.spGetDeletedPBOBudgetCodes
GO

CREATE PROCEDURE pbo.spGetDeletedPBOBudgetCodes 
	@AIDs NVARCHAR(MAX),
	@AName NVARCHAR(1500),
	@ACode VARCHAR(20),
	@AType TINYINT,
	@APaymentType TINYINT,
	@APaymentTypes NVARCHAR(MAX),
	@APaymentDepartmentID UNIQUEIDENTIFIER,
	@APaymentDepartmentIDs NVARCHAR(MAX),
	@APaymentDepartmentName NVARCHAR(256),
	@ASubDepartmentIDs NVARCHAR(MAX),
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@IDs NVARCHAR(MAX) = LTRIM(RTRIM(@AIDs)),
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@Code NVARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0),
		@PaymentType TINYINT = COALESCE(@APaymentType, 0),
		@PaymentTypes NVARCHAR(MAX) = LTRIM(RTRIM(@APaymentTypes)),
		@PaymentDepartmentID UNIQUEIDENTIFIER = @APaymentDepartmentID,
		@PaymentDepartmentIDs NVARCHAR(MAX) = LTRIM(RTRIM(@APaymentDepartmentIDs)),
		@PaymentDepartmentName NVARCHAR(256) = LTRIM(RTRIM(@APaymentDepartmentName)),
		@SubDepartmentIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ASubDepartmentIDs)),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH SebDepartments AS (
		SELECT
			COUNT(ID) CountSebDepartments,
			BudgetCodeID
		FROM pbo.BudgetCodeSubDepartment
		GROUP BY BudgetCodeID
	)
	, SebDepartmentFilter AS (
		SELECT
			BudgetCodeID
		FROM pbo.BudgetCodeSubDepartment
		LEFT JOIN OPENJSON(@SubDepartmentIDs) SubDepartmentIDs ON SubDepartmentIDs.value = BudgetCodeSubDepartment.DepartmentID
		WHERE (@SubDepartmentIDs IS NULL OR SubDepartmentIDs.value = BudgetCodeSubDepartment.DepartmentID)
		GROUP BY BudgetCodeID
	)
	, MainSelect AS
	(
		SELECT 
			BC.ID,
			BC.Code,
			BC.[Name],
			BC.[Type],
			BC.PaymentType,
			BC.PaymentDepartmentID,
			DEP.[Name] PaymentDepartmentName,
			BC.CreationDate,
			CU.FirstName + N' ' + CU.LastName CreatorName,
			BC.CreatorPositionID,
			BC.RemoveDate,
			BC.RemoverUserID,
			RU.FirstName + N' ' + RU.LastName RemoverName,
			BC.RemoverPositionID,
			BC.[SectionID],
			Section.[Name] SectionName,
			Section.[Type] SectionType,
			Section.[Code] SectionCode,
			SebDepartments.CountSebDepartments
		FROM pbo.BudgetCode BC
			LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = BC.ID
			LEFT JOIN OPENJSON(@PaymentDepartmentIDs) PaymentDepartmentIDs ON PaymentDepartmentIDs.value = BC.PaymentDepartmentID
			LEFT JOIN OPENJSON(@PaymentTypes) PaymentTypes ON PaymentTypes.value = BC.PaymentType
			LEFT JOIN SebDepartmentFilter ON SebDepartmentFilter.BudgetCodeID = BC.ID
			LEFT JOIN SebDepartments ON SebDepartments.BudgetCodeID = BC.ID
			LEFT JOIN [pbo].[PBOSection] Section ON Section.ID = BC.[SectionID]
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BC.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = BC.RemoverUserID
		WHERE (BC.[RemoveDate] IS NOT NULL)
			AND (@IDs IS NULL OR IDs.value = BC.ID)
			AND (@PaymentTypes IS NULL OR PaymentTypes.value = BC.PaymentType)
			AND (@PaymentDepartmentIDs IS NULL OR PaymentDepartmentIDs.value = BC.PaymentDepartmentID)
			AND (@SubDepartmentIDs IS NULL OR SebDepartmentFilter.BudgetCodeID = BC.ID)
			AND (@Code IS NULL OR BC.Code LIKE '%' + @Code + '%' )
			AND (@Type < 1 OR BC.[Type] = @Type)
			AND (@PaymentType < 1 OR BC.PaymentType = @PaymentType)
			AND (@Name IS NULL OR BC.[Name] LIKE '%' + @Name + '%')
			AND (@PaymentDepartmentID IS NULL OR BC.PaymentDepartmentID = @PaymentDepartmentID)
			AND (@PaymentDepartmentName IS NULL OR DEP.[Name] LIKE '%' + @PaymentDepartmentName + '%')
			AND (@FromRemoveDate IS NULL OR BC.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR BC.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOBudgetCode') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOBudgetCode
GO

CREATE PROCEDURE pbo.spGetPBOBudgetCode 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID
	; WITH SebDepartments AS (
		SELECT
			COUNT(ID) CountSebDepartments,
			BudgetCodeID
		FROM pbo.BudgetCodeSubDepartment
		GROUP BY BudgetCodeID
	)
	SELECT 
		BC.ID,
		BC.Code,
		BC.[Name],
		BC.[Type],
		BC.PaymentType,
		BC.PaymentDepartmentID,
		DEP.[Name] PaymentDepartmentName,
		BC.CreationDate,
		CU.FirstName + N' ' + CU.LastName CreatorName,
		BC.CreatorPositionID,
		BC.RemoveDate,
		BC.RemoverUserID,
		RU.FirstName + N' ' + RU.LastName RemoverName,
		BC.RemoverPositionID,
		BC.[SectionID],
		Section.[Name] SectionName,
		Section.[Type] SectionType,
		Section.[Code] SectionCode,
		SebDepartments.CountSebDepartments
	FROM pbo.BudgetCode BC
	LEFT JOIN SebDepartments ON SebDepartments.BudgetCodeID = BC.ID
	LEFT JOIN [pbo].[PBOSection] Section ON Section.ID = BC.[SectionID]
	LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BC.CreatorUserID
	LEFT JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
	LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = BC.RemoverUserID
	WHERE BC.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOBudgetCodes') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOBudgetCodes
GO

CREATE PROCEDURE pbo.spGetPBOBudgetCodes 
	@AIDs NVARCHAR(MAX),
	@AName NVARCHAR(1500),
	@ACode VARCHAR(20),
	@ACodes NVARCHAR(MAX),
	@AType TINYINT,
	@APaymentType TINYINT,
	@APaymentTypes NVARCHAR(MAX),
	@APaymentDepartmentID UNIQUEIDENTIFIER,
	@APaymentDepartmentIDs NVARCHAR(MAX),
	@APaymentDepartmentName NVARCHAR(256),
	@ASubDepartmentIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@Name NVARCHAR(1500) = TRIM(@AName),
		@Code NVARCHAR(20) = TRIM(@ACode),
		@Codes NVARCHAR(MAX) = TRIM(@ACodes),
		@Type TINYINT = COALESCE(@AType, 0),
		@PaymentType TINYINT = COALESCE(@APaymentType, 0),
		@PaymentTypes NVARCHAR(MAX) = TRIM(@APaymentTypes),
		@PaymentDepartmentID UNIQUEIDENTIFIER = @APaymentDepartmentID,
		@PaymentDepartmentIDs NVARCHAR(MAX) = TRIM(@APaymentDepartmentIDs),
		@PaymentDepartmentName NVARCHAR(256) = TRIM(@APaymentDepartmentName),
		@SubDepartmentIDs NVARCHAR(MAX) = TRIM(@ASubDepartmentIDs),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = TRIM(@ASortExp),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH SebDepartments AS (
		SELECT
			COUNT(ID) CountSebDepartments,
			BudgetCodeID
		FROM pbo.BudgetCodeSubDepartment
		WHERE RemoveDate IS NULL
		GROUP BY BudgetCodeID
	)
	, SebDepartmentFilter AS (
		SELECT
			BudgetCodeID
		FROM pbo.BudgetCodeSubDepartment
		LEFT JOIN OPENJSON(@SubDepartmentIDs) SubDepartmentIDs ON SubDepartmentIDs.value = BudgetCodeSubDepartment.DepartmentID
		WHERE RemoveDate IS NULL
		AND (@SubDepartmentIDs IS NULL OR SubDepartmentIDs.value = BudgetCodeSubDepartment.DepartmentID)
		GROUP BY BudgetCodeID
	)
	, MainSelect AS
	(
		SELECT 
			BC.ID,
			BC.Code,
			BC.[Name],
			BC.[Type],
			BC.PaymentType,
			BC.PaymentDepartmentID,
			DEP.[Name] PaymentDepartmentName,
			BC.CreationDate,
			CU.FirstName + N' ' + CU.LastName CreatorName,
			BC.CreatorPositionID,
			BC.[SectionID],
			Section.[Name] SectionName,
			Section.[Type] SectionType,
			Section.[Code] SectionCode,
			SebDepartments.CountSebDepartments
		FROM pbo.BudgetCode BC
			LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = BC.ID
			LEFT JOIN OPENJSON(@Codes) Codes ON Codes.value = BC.Code
			LEFT JOIN OPENJSON(@PaymentDepartmentIDs) PaymentDepartmentIDs ON PaymentDepartmentIDs.value = BC.PaymentDepartmentID
			LEFT JOIN OPENJSON(@PaymentTypes) PaymentTypes ON PaymentTypes.value = BC.PaymentType
			LEFT JOIN SebDepartmentFilter ON SebDepartmentFilter.BudgetCodeID = BC.ID
			LEFT JOIN SebDepartments ON SebDepartments.BudgetCodeID = BC.ID
			LEFT JOIN [pbo].[PBOSection] Section ON Section.ID = BC.[SectionID]
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BC.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
		WHERE (BC.[RemoveDate] IS NULL)
			AND (@IDs IS NULL OR IDs.value = BC.ID)
			AND (@Codes IS NULL OR Codes.value = BC.Code)
			AND (@PaymentTypes IS NULL OR PaymentTypes.value = BC.PaymentType)
			AND (@PaymentDepartmentIDs IS NULL OR PaymentDepartmentIDs.value = BC.PaymentDepartmentID)
			AND (@SubDepartmentIDs IS NULL OR SebDepartmentFilter.BudgetCodeID = BC.ID)
			AND (@Name IS NULL OR BC.[Name] LIKE '%' + @Name + '%')
			AND (@Code IS NULL OR BC.Code LIKE '%' + @Code + '%' )
			AND (@Type < 1 OR BC.[Type] = @Type)
			AND (@PaymentType < 1 OR BC.PaymentType = @PaymentType)
			AND (@PaymentDepartmentID IS NULL OR BC.PaymentDepartmentID = @PaymentDepartmentID)
			AND (@PaymentDepartmentName IS NULL OR DEP.[Name] LIKE '%' + @PaymentDepartmentName + '%')
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyPBOBudgetCode') IS NOT NULL
    DROP PROCEDURE pbo.spModifyPBOBudgetCode
GO

CREATE PROCEDURE pbo.spModifyPBOBudgetCode
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1500),
	@ACode VARCHAR(20),
	@AType TINYINT,
	@APaymentType TINYINT,
	@APaymentDepartmentID UNIQUEIDENTIFIER,
	@ASectionID UNIQUEIDENTIFIER,
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0),
		@PaymentType TINYINT = COALESCE(@APaymentType, 0),
		@PaymentDepartmentID UNIQUEIDENTIFIER = @APaymentDepartmentID,
		@SectionID UNIQUEIDENTIFIER = @ASectionID,
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				
				INSERT INTO pbo.BudgetCode
				([ID], [Name], [Code], [Type], [PaymentType], [PaymentDepartmentID], [CreationDate], [CreatorUserID], [CreatorPositionID], [SectionID])
				VALUES
				(@ID, @Name, @Code, @Type, @PaymentType, @PaymentDepartmentID, GETDATE(), @ModifireUserID, @ModifirePositionID, @SectionID)
			END
			ELSE -- update
			BEGIN 

				UPDATE pbo.BudgetCode
				SET Code = @Code,
					[Name] = @Name,
					[Type] = @Type,
					PaymentType = @APaymentType,
					PaymentDepartmentID = @PaymentDepartmentID,
					[SectionID] = @SectionID
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbo.spUpdateListPBOBudgetCodes') AND type in (N'P', N'PC'))
DROP PROCEDURE pbo.spUpdateListPBOBudgetCodes
GO

CREATE PROCEDURE pbo.spUpdateListPBOBudgetCodes
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX),
	@ASaveType TINYINT

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@SaveType TINYINT = COALESCE(@ASaveType, 0),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			--IF @SaveType = 1 -- Replace
			--BEGIN
			--	UPDATE pbo.BudgetCode
			--	SET RemoverUserID = @CurrentUserID,
			--	RemoverPositionID = @CurrentPositionID,
			--	RemoveDate = GETDATE()
			--END
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					[Name] NVARCHAR(1500),
					[Code] VARCHAR(20),
					[Type] TINYINT,
					[PaymentType] TINYINT,
					[PaymentDepartmentID] UNIQUEIDENTIFIER,
					[SectionID] UNIQUEIDENTIFIER
				)
			)
			INSERT INTO pbo.BudgetCode
			([ID], [Name], [Code], [Type], [PaymentType], [PaymentDepartmentID], [SectionID], [CreationDate], [CreatorUserID], [CreatorPositionID])
			SELECT 
				NEWID() ID,
				Details.[Name] [Name],
				Details.[Code] [Code],
				Details.[Type] [Type],
				Details.[PaymentType] [PaymentType],
				Details.[PaymentDepartmentID] [PaymentDepartmentID],
				Details.[SectionID] [SectionID],
				GETDATE() [CreationDate],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spCreateDefaultPBOBudgetCodeFinancingResource') IS NOT NULL
    DROP PROCEDURE pbo.spCreateDefaultPBOBudgetCodeFinancingResource
GO

CREATE PROCEDURE pbo.spCreateDefaultPBOBudgetCodeFinancingResource
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ABudgetCodeType TINYINT,
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN

			INSERT INTO pbo.BudgetCodeFinancingResource
			([ID], [BudgetCodeID], [FinancingResourceID], [Enabled], [CreationDate], [CreatorUserID], [CreatorPositionID])
			SELECT
			NEWID() [ID], 
			@BudgetCodeID [BudgetCodeID],
			FR.ID [FinancingResourceID],
			0 [Enabled],
			GETDATE() [CreationDate],
			@ModifireUserID [CreatorUserID],
			@ModifirePositionID [CreatorPositionID]
			FROM [pbo].[FinancingResource] FR
			WHERE (@BudgetCodeType < 0 OR FR.BudgetCodeType = @BudgetCodeType)

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spCreateListDefaultPBOBudgetCodeFinancingResource') IS NOT NULL
    DROP PROCEDURE pbo.spCreateListDefaultPBOBudgetCodeFinancingResource
GO

CREATE PROCEDURE pbo.spCreateListDefaultPBOBudgetCodeFinancingResource
	@ADetails NVARCHAR(MAX),
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *
				FROM OPENJSON(@Details) 
				WITH
				(
					[ID] UNIQUEIDENTIFIER,
					[Type] TINYINT
				)
			)
			INSERT INTO pbo.BudgetCodeFinancingResource
			([ID], [BudgetCodeID], [FinancingResourceID], [Enabled], [CreationDate], [CreatorUserID], [CreatorPositionID])
			SELECT
			NEWID() [ID], 
			CTE.[ID] [BudgetCodeID],
			FR.ID [FinancingResourceID],
			0 [Enabled],
			GETDATE() [CreationDate],
			@ModifireUserID [CreatorUserID],
			@ModifirePositionID [CreatorPositionID]
			FROM [pbo].[FinancingResource] FR
			INNER JOIN CTE ON CTE.[Type] = FR.[BudgetCodeType]

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbo.spDeletePBOBudgetCodeFinancingResource'))
	DROP PROCEDURE pbo.spDeletePBOBudgetCodeFinancingResource
GO

CREATE PROCEDURE pbo.spDeletePBOBudgetCodeFinancingResource
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbo.BudgetCodeFinancingResource
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetDeletedPBOBudgetCodeFinancingResources') IS NOT NULL
    DROP PROCEDURE pbo.spGetDeletedPBOBudgetCodeFinancingResources
GO

CREATE PROCEDURE pbo.spGetDeletedPBOBudgetCodeFinancingResources
	@AIDs NVARCHAR(MAX),
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ABudgetCodeIDs NVARCHAR(MAX),
	@ABudgetCodeName NVARCHAR(1500),
	@ABudgetCode VARCHAR(20),
	@ABudgetCodeType TINYINT,
	@ABudgetCodePaymentType TINYINT,
	@ABudgetCodePaymentDepartmentID UNIQUEIDENTIFIER,
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@AFinancingResourceName NVARCHAR(1500),
	@AFinancingResourceBudgetCodeType TINYINT,
	@AFinancingResourceAROCode INT,
	@AFinancingResourcePBOCode INT,
	@AFinancingResourceTreasuryCode INT,
	@AEnableState TINYINT,
	@AFromMaximum BIGINT,
	@AToMaximum BIGINT,
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@IDs NVARCHAR(MAX) = LTRIM(RTRIM(@AIDs)),
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@BudgetCodeIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ABudgetCodeIDs)),
		@BudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@ABudgetCodeName)),
		@BudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@BudgetCodePaymentType TINYINT = COALESCE(@ABudgetCodePaymentType, 0),
		@BudgetCodePaymentDepartmentID UNIQUEIDENTIFIER = @ABudgetCodePaymentDepartmentID,
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@FinancingResourceName NVARCHAR(1500) = LTRIM(RTRIM(@AFinancingResourceName)),
		@FinancingResourceBudgetCodeType TINYINT = COALESCE(@AFinancingResourceBudgetCodeType, 0),
		@FinancingResourceAROCode INT = COALESCE(@AFinancingResourceAROCode, 0),
		@FinancingResourcePBOCode INT = COALESCE(@AFinancingResourcePBOCode, 0),
		@FinancingResourceTreasuryCode INT = COALESCE(@AFinancingResourceTreasuryCode, 0),
		@EnableState TINYINT = COALESCE(@AEnableState, 0),
		@FromMaximum BIGINT = COALESCE(@AFromMaximum, 0),
		@ToMaximum BIGINT = COALESCE(@AToMaximum, 0),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			BCFR.[ID],
			BCFR.[BudgetCodeID],
			BC.[Name] BudgetCodeName,
			BC.[Code] BudgetCode,
			BC.[Type] BudgetCodeType,
			BC.[PaymentType] BudgetCodePaymentType,
			BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
			DEP.[Name] BudgetCodePaymentDepartmentName,
			BCFR.[FinancingResourceID],
			FR.[Name] FinancingResourceName,
			FR.[BudgetCodeType] FinancingResourceBudgetCodeType,
			FR.[AROCode] FinancingResourceAROCode,
			FR.[PBOCode] FinancingResourcePBOCode,
			FR.[TreasuryCode] FinancingResourceTreasuryCode,
			BCFR.[Enabled],
			BCFR.[Maximum],
			BCFR.[CreationDate],
			BCFR.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			BCFR.[CreatorPositionID],
			BCFR.[RemoveDate],
			BCFR.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			BCFR.[RemoverPositionID]
		FROM pbo.BudgetCodeFinancingResource BCFR
		LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = BCFR.ID
		INNER JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.[BudgetCodeID]
		LEFT JOIN OPENJSON(@BudgetCodeIDs) BudgetCodeIDs ON BudgetCodeIDs.value = BC.ID
		INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
		INNER JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.[FinancingResourceID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BCFR.CreatorUserID
		LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = BCFR.RemoverUserID
		WHERE (BCFR.RemoveDate IS NOT NULL)
			AND (@IDs IS NULL OR IDs.value = BCFR.ID)
			AND (@BudgetCodeID IS NULL OR BCFR.[BudgetCodeID] = @BudgetCodeID)
			AND (@BudgetCodeIDs IS NULL OR BudgetCodeIDs.value = BC.ID)
			AND (@BudgetCodeName IS NULL OR BC.[Name] LIKE '%' + @BudgetCodeName + '%' )
			AND (@BudgetCode IS NULL OR BC.Code LIKE '%' + @BudgetCode + '%' )
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@BudgetCodePaymentType < 1 OR BC.[PaymentType] = @BudgetCodePaymentType)
			AND (@BudgetCodePaymentDepartmentID IS NULL OR BC.PaymentDepartmentID = @BudgetCodePaymentDepartmentID)
			AND (@FinancingResourceID IS NULL OR BCFR.[FinancingResourceID] = @FinancingResourceID)
			AND (@FinancingResourceName IS NULL OR FR.[Name] LIKE '%' + @FinancingResourceName + '%' )
			AND (@FinancingResourceBudgetCodeType < 1 OR FR.[BudgetCodeType] = @FinancingResourceBudgetCodeType)
			AND (@FinancingResourceAROCode < 1 OR FR.[AROCode] = @FinancingResourceAROCode)
			AND (@FinancingResourcePBOCode < 1 OR FR.[PBOCode] = @FinancingResourcePBOCode)
			AND (@FinancingResourceTreasuryCode < 1 OR FR.[TreasuryCode] = @FinancingResourceTreasuryCode)
			AND (@EnableState < 1 OR BCFR.[Enabled] = @EnableState - 1)
			AND (@FromMaximum < 1 OR BCFR.[Maximum] >= @FromMaximum)
			AND (@ToMaximum < 1 OR BCFR.[Maximum] <= @ToMaximum)
			AND (@FromRemoveDate IS NULL OR BCFR.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR BCFR.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [FinancingResourceAROCode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOBudgetCodeFinancingResource') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOBudgetCodeFinancingResource
GO

CREATE PROCEDURE pbo.spGetPBOBudgetCodeFinancingResource 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		BCFR.[ID],
		BCFR.[BudgetCodeID],
		BC.[Name] BudgetCodeName,
		BC.[Code] BudgetCode,
		BC.[Type] BudgetCodeType,
		BC.[PaymentType] BudgetCodePaymentType,
		BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
		DEP.[Name] BudgetCodePaymentDepartmentName,
		BCFR.[FinancingResourceID],
		FR.[Name] FinancingResourceName,
		FR.[BudgetCodeType] FinancingResourceBudgetCodeType,
		FR.[AROCode] FinancingResourceAROCode,
		FR.[PBOCode] FinancingResourcePBOCode,
		FR.[TreasuryCode] FinancingResourceTreasuryCode,
		BCFR.[Enabled],
		BCFR.[Maximum],
		BCFR.[CreationDate],
		BCFR.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		BCFR.[CreatorPositionID],
		BCFR.[RemoveDate],
		BCFR.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName RemoverName,
		BCFR.[RemoverPositionID]
	FROM pbo.BudgetCodeFinancingResource BCFR
	INNER JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.[BudgetCodeID]
	INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
	INNER JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.[FinancingResourceID]
	LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BCFR.CreatorUserID
	LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = BCFR.RemoverUserID
	WHERE BCFR.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOBudgetCodeFinancingResources') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOBudgetCodeFinancingResources
GO

CREATE PROCEDURE pbo.spGetPBOBudgetCodeFinancingResources 
	@AIDs NVARCHAR(MAX),
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ABudgetCodeIDs NVARCHAR(MAX),
	@ABudgetCodeName NVARCHAR(1500),
	@ABudgetCode VARCHAR(20),
	@ABudgetCodeType TINYINT,
	@ABudgetCodePaymentType TINYINT,
	@ABudgetCodePaymentDepartmentID UNIQUEIDENTIFIER,
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@AFinancingResourceName NVARCHAR(1500),
	@AFinancingResourceBudgetCodeType TINYINT,
	@AFinancingResourceAROCode INT,
	@AFinancingResourcePBOCode INT,
	@AFinancingResourceTreasuryCode INT,
	@AEnableState TINYINT,
	@AFromMaximum BIGINT,
	@AToMaximum BIGINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@IDs NVARCHAR(MAX) = LTRIM(RTRIM(@AIDs)),
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@BudgetCodeIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ABudgetCodeIDs)),
		@BudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@ABudgetCodeName)),
		@BudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@BudgetCodePaymentType TINYINT = COALESCE(@ABudgetCodePaymentType, 0),
		@BudgetCodePaymentDepartmentID UNIQUEIDENTIFIER = @ABudgetCodePaymentDepartmentID,
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@FinancingResourceName NVARCHAR(1500) = LTRIM(RTRIM(@AFinancingResourceName)),
		@FinancingResourceBudgetCodeType TINYINT = COALESCE(@AFinancingResourceBudgetCodeType, 0),
		@FinancingResourceAROCode INT = COALESCE(@AFinancingResourceAROCode, 0),
		@FinancingResourcePBOCode INT = COALESCE(@AFinancingResourcePBOCode, 0),
		@FinancingResourceTreasuryCode INT = COALESCE(@AFinancingResourceTreasuryCode, 0),
		@EnableState TINYINT = COALESCE(@AEnableState, 0),
		@FromMaximum BIGINT = COALESCE(@AFromMaximum, 0),
		@ToMaximum BIGINT = COALESCE(@AToMaximum, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			BCFR.[ID],
			BCFR.[BudgetCodeID],
			BC.[Name] BudgetCodeName,
			BC.[Code] BudgetCode,
			BC.[Type] BudgetCodeType,
			BC.[PaymentType] BudgetCodePaymentType,
			BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
			DEP.[Name] BudgetCodePaymentDepartmentName,
			BCFR.[FinancingResourceID],
			FR.[Name] FinancingResourceName,
			FR.[BudgetCodeType] FinancingResourceBudgetCodeType,
			FR.[AROCode] FinancingResourceAROCode,
			FR.[PBOCode] FinancingResourcePBOCode,
			FR.[TreasuryCode] FinancingResourceTreasuryCode,
			BCFR.[Enabled],
			BCFR.[Maximum],
			BCFR.[CreationDate],
			BCFR.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			BCFR.[CreatorPositionID]
		FROM pbo.BudgetCodeFinancingResource BCFR
		LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = BCFR.ID
		INNER JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.[BudgetCodeID]
		LEFT JOIN OPENJSON(@BudgetCodeIDs) BudgetCodeIDs ON BudgetCodeIDs.value = BC.ID
		INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
		INNER JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.[FinancingResourceID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BCFR.CreatorUserID
		WHERE (BCFR.[RemoveDate] IS NULL) AND (BC.RemoveDate IS NULL)
			AND (@IDs IS NULL OR IDs.value = BCFR.ID)
			AND (@BudgetCodeID IS NULL OR BCFR.[BudgetCodeID] = @BudgetCodeID)
			AND (@BudgetCodeIDs IS NULL OR BudgetCodeIDs.value = BC.ID)
			AND (@BudgetCodeName IS NULL OR BC.[Name] LIKE '%' + @BudgetCodeName + '%' )
			AND (@BudgetCode IS NULL OR BC.Code LIKE '%' + @BudgetCode + '%' )
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@BudgetCodePaymentType < 1 OR BC.[PaymentType] = @BudgetCodePaymentType)
			AND (@BudgetCodePaymentDepartmentID IS NULL OR BC.PaymentDepartmentID = @BudgetCodePaymentDepartmentID)
			AND (@FinancingResourceID IS NULL OR BCFR.[FinancingResourceID] = @FinancingResourceID)
			AND (@FinancingResourceName IS NULL OR FR.[Name] LIKE '%' + @FinancingResourceName + '%' )
			AND (@FinancingResourceBudgetCodeType < 1 OR FR.[BudgetCodeType] = @FinancingResourceBudgetCodeType)
			AND (@FinancingResourceAROCode < 1 OR FR.[AROCode] = @FinancingResourceAROCode)
			AND (@FinancingResourcePBOCode < 1 OR FR.[PBOCode] = @FinancingResourcePBOCode)
			AND (@FinancingResourceTreasuryCode < 1 OR FR.[TreasuryCode] = @FinancingResourceTreasuryCode)
			AND (@EnableState < 1 OR BCFR.[Enabled] = (@EnableState - 1))
			AND (@FromMaximum < 1 OR BCFR.[Maximum] >= @FromMaximum)
			AND (@ToMaximum < 1 OR BCFR.[Maximum] <= @ToMaximum)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [FinancingResourceAROCode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyListPBOBudgetCodeFinancingResources') IS NOT NULL
    DROP PROCEDURE pbo.spModifyListPBOBudgetCodeFinancingResources
GO

CREATE PROCEDURE pbo.spModifyListPBOBudgetCodeFinancingResources
	@ADetails NVARCHAR(MAX),
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
		;WITH CTE AS 
        (
            SELECT
                [ID],
                [Maximum],
				[Enabled]
            FROM OPENJSON(@Details) 
            WITH
            (
                [ID] UNIQUEIDENTIFIER,
                [Maximum] BIGINT,
				[Enabled] BIT
            )
        )

        UPDATE BCFR
        SET [Enabled] = CASE WHEN CTE.[ID] IS NOT NULL THEN CTE.[Enabled] ELSE 0 END,
            [Maximum] = COALESCE(CTE.[Maximum], BCFR.[Maximum])
        FROM pbo.BudgetCodeFinancingResource BCFR
        LEFT JOIN CTE ON CTE.[ID] = BCFR.[ID]

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyPBOBudgetCodeFinancingResource') IS NOT NULL
    DROP PROCEDURE pbo.spModifyPBOBudgetCodeFinancingResource
GO

CREATE PROCEDURE pbo.spModifyPBOBudgetCodeFinancingResource
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@AEnabled BIT,
	@AMaximum BIGINT,
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@Enabled BIT = COALESCE(@AEnabled, 0),
		@Maximum BIGINT = @AMaximum,
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				
				INSERT INTO pbo.BudgetCodeFinancingResource
				([ID], [BudgetCodeID], [FinancingResourceID], [Enabled], [Maximum], [CreationDate], [CreatorUserID], [CreatorPositionID])
				VALUES
				(@ID, @BudgetCodeID, @FinancingResourceID, @Enabled, @Maximum, GETDATE(), @ModifireUserID, @ModifirePositionID)
			END
			ELSE -- update
			BEGIN 
				UPDATE pbo.BudgetCodeFinancingResource
				SET
					[Enabled] = @Enabled,
					[Maximum] = @Maximum
				WHERE ID = @ID

			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbo.spDeletePBOBudgetCodeFinancingResourceDetail'))
	DROP PROCEDURE pbo.spDeletePBOBudgetCodeFinancingResourceDetail
GO

CREATE PROCEDURE pbo.spDeletePBOBudgetCodeFinancingResourceDetail
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbo.BudgetCodeFinancingResourceDetail
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetDeletedPBOBudgetCodeFinancingResourceDetails') IS NOT NULL
    DROP PROCEDURE pbo.spGetDeletedPBOBudgetCodeFinancingResourceDetails
GO

CREATE PROCEDURE pbo.spGetDeletedPBOBudgetCodeFinancingResourceDetails
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ABudgetCodeName NVARCHAR(1500),
	@ABudgetCode VARCHAR(20),
	@ABudgetCodeType TINYINT,
	@ABudgetCodePaymentType TINYINT,
	@ABudgetCodePaymentDepartmentID UNIQUEIDENTIFIER,
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@AFinancingResourceName NVARCHAR(1500),
	@AFinancingResourceBudgetCodeType TINYINT,
	@AFinancingResourceAROCode INT,
	@AFinancingResourcePBOCode INT,
	@AFinancingResourceTreasuryCode INT,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceEnableState TINYINT,
	@ABudgetCodeFinancingResourceFromMaximum BIGINT,
	@ABudgetCodeFinancingResourceToMaximum BIGINT,
	@AMiscellaneousBudgetCodeName NVARCHAR(1500),
	@AMiscellaneousBudgetCode VARCHAR(20),
	@AProjectionName NVARCHAR(1500),
	@AProjectionCode VARCHAR(20),
	@AProjectName NVARCHAR(1500),
	@AProjectCode VARCHAR(20),
	@AFromMaximum BIGINT,
	@AToMaximum BIGINT,
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@BudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@ABudgetCodeName)),
		@BudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@BudgetCodePaymentType TINYINT = COALESCE(@ABudgetCodePaymentType, 0),
		@BudgetCodePaymentDepartmentID UNIQUEIDENTIFIER = @ABudgetCodePaymentDepartmentID,
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@FinancingResourceName NVARCHAR(1500) = LTRIM(RTRIM(@AFinancingResourceName)),
		@FinancingResourceBudgetCodeType TINYINT = COALESCE(@AFinancingResourceBudgetCodeType, 0),
		@FinancingResourceAROCode INT = COALESCE(@AFinancingResourceAROCode, 0),
		@FinancingResourcePBOCode INT = COALESCE(@AFinancingResourcePBOCode, 0),
		@FinancingResourceTreasuryCode INT = COALESCE(@AFinancingResourceTreasuryCode, 0),
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@BudgetCodeFinancingResourceEnableState TINYINT = COALESCE(@ABudgetCodeFinancingResourceEnableState, 0),
		@BudgetCodeFinancingResourceFromMaximum BIGINT = COALESCE(@ABudgetCodeFinancingResourceFromMaximum, 0),
		@BudgetCodeFinancingResourceToMaximum BIGINT = COALESCE(@ABudgetCodeFinancingResourceToMaximum, 0),
		@MiscellaneousBudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@AMiscellaneousBudgetCodeName)),
		@MiscellaneousBudgetCode NVARCHAR(20) = LTRIM(RTRIM(@AMiscellaneousBudgetCode)),
		@ProjectionName NVARCHAR(1500) = LTRIM(RTRIM(@AProjectionName)),
		@ProjectionCode NVARCHAR(20) = LTRIM(RTRIM(@AProjectionCode)),
		@ProjectName NVARCHAR(1500) = LTRIM(RTRIM(@AProjectName)),
		@ProjectCode NVARCHAR(20) = LTRIM(RTRIM(@AProjectCode)),
		@FromMaximum BIGINT = COALESCE(@AFromMaximum, 0),
		@ToMaximum BIGINT = COALESCE(@AToMaximum, 0),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			BCFRD.[ID],
			BCFRD.[BudgetCodeFinancingResourceID],
			BDFR.[BudgetCodeID],
			BC.[Name] BudgetCodeName,
			BC.[Code] BudgetCode,
			BC.[Type] BudgetCodeType,
			BC.[PaymentType] BudgetCodePaymentType,
			BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
			DEP.[Name] BudgetCodePaymentDepartmentName,
			BDFR.[FinancingResourceID],
			FR.[Name] FinancingResourceName,
			FR.[BudgetCodeType] FinancingResourceBudgetCodeType,
			FR.[AROCode] FinancingResourceAROCode,
			FR.[PBOCode] FinancingResourcePBOCode,
			FR.[TreasuryCode] FinancingResourceTreasuryCode,
			BDFR.[Enabled] BudgetCodeFinancingResourceEnabled,
			BDFR.[Maximum] BudgetCodeFinancingResourceMaximum,
			BCFRD.[MiscellaneousBudgetCodeName],
			BCFRD.[MiscellaneousBudgetCode],
			BCFRD.[ProjectionName],
			BCFRD.[ProjectionCode],
			BCFRD.[ProjectName],
			BCFRD.[ProjectCode],
			BCFRD.[Maximum],
			BCFRD.[CreationDate],
			BCFRD.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			BCFRD.[CreatorPositionID],
			BCFRD.[RemoveDate],
			BCFRD.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			BCFRD.[RemoverPositionID]
		FROM pbo.BudgetCodeFinancingResourceDetail BCFRD
		INNER JOIN pbo.BudgetCodeFinancingResource BDFR ON BDFR.ID = BCFRD.BudgetCodeFinancingResourceID
		INNER JOIN [pbo].[BudgetCode] BC ON BC.ID = BDFR.[BudgetCodeID]
		INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
		INNER JOIN [pbo].[FinancingResource] FR ON FR.ID = BDFR.[FinancingResourceID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BDFR.CreatorUserID
		LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = BDFR.RemoverUserID
		WHERE (BCFRD.RemoveDate IS NOT NULL)
			AND (@BudgetCodeID IS NULL OR BDFR.[BudgetCodeID] = @BudgetCodeID)
			AND (@BudgetCodeName IS NULL OR BC.[Name] LIKE '%' + @BudgetCodeName + '%' )
			AND (@BudgetCode IS NULL OR BC.Code LIKE '%' + @BudgetCode + '%' )
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@BudgetCodePaymentType < 1 OR BC.[PaymentType] = @BudgetCodePaymentType)
			AND (@BudgetCodePaymentDepartmentID IS NULL OR BC.PaymentDepartmentID = @BudgetCodePaymentDepartmentID)
			AND (@FinancingResourceID IS NULL OR BDFR.[FinancingResourceID] = @FinancingResourceID)
			AND (@FinancingResourceName IS NULL OR FR.[Name] LIKE '%' + @FinancingResourceName + '%' )
			AND (@FinancingResourceBudgetCodeType < 1 OR FR.[BudgetCodeType] = @FinancingResourceBudgetCodeType)
			AND (@FinancingResourceAROCode < 1 OR FR.[AROCode] = @FinancingResourceAROCode)
			AND (@FinancingResourcePBOCode < 1 OR FR.[PBOCode] = @FinancingResourcePBOCode)
			AND (@FinancingResourceTreasuryCode < 1 OR FR.[TreasuryCode] = @FinancingResourceTreasuryCode)
			AND (@ABudgetCodeFinancingResourceID IS NULL OR BCFRD.[BudgetCodeFinancingResourceID] = @ABudgetCodeFinancingResourceID)
			AND (@BudgetCodeFinancingResourceEnableState < 1 OR BDFR.[Enabled] = @BudgetCodeFinancingResourceEnableState - 1)
			AND (@BudgetCodeFinancingResourceFromMaximum < 1 OR BDFR.[Maximum] >= @BudgetCodeFinancingResourceFromMaximum)
			AND (@BudgetCodeFinancingResourceToMaximum < 1 OR BDFR.[Maximum] <= @BudgetCodeFinancingResourceToMaximum)
			AND (@MiscellaneousBudgetCodeName IS NULL OR BCFRD.MiscellaneousBudgetCodeName LIKE '%' + @MiscellaneousBudgetCodeName + '%' )
			AND (@MiscellaneousBudgetCode IS NULL OR BCFRD.MiscellaneousBudgetCode LIKE '%' + @MiscellaneousBudgetCode + '%' )
			AND (@ProjectionName IS NULL OR BCFRD.ProjectionName LIKE '%' + @ProjectionName + '%' )
			AND (@ProjectionCode IS NULL OR BCFRD.ProjectionCode LIKE '%' + @ProjectionCode + '%' )
			AND (@ProjectName IS NULL OR BCFRD.ProjectName LIKE '%' + @ProjectName + '%' )
			AND (@ProjectCode IS NULL OR BCFRD.ProjectCode LIKE '%' + @ProjectCode + '%' )
			AND (@FromMaximum < 1 OR BCFRD.[Maximum] >= @FromMaximum)
			AND (@ToMaximum < 1 OR BCFRD.[Maximum] <= @ToMaximum)
			AND (@FromRemoveDate IS NULL OR BDFR.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR BDFR.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOBudgetCodeFinancingResourceDetail') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOBudgetCodeFinancingResourceDetail
GO

CREATE PROCEDURE pbo.spGetPBOBudgetCodeFinancingResourceDetail 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		BCFRD.[ID],
		BCFRD.[BudgetCodeFinancingResourceID],
		BDFR.[BudgetCodeID],
		BC.[Name] BudgetCodeName,
		BC.[Code] BudgetCode,
		BC.[Type] BudgetCodeType,
		BC.[PaymentType] BudgetCodePaymentType,
		BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
		DEP.[Name] BudgetCodePaymentDepartmentName,
		BDFR.[FinancingResourceID],
		FR.[Name] FinancingResourceName,
		FR.[BudgetCodeType] FinancingResourceBudgetCodeType,
		FR.[AROCode] FinancingResourceAROCode,
		FR.[PBOCode] FinancingResourcePBOCode,
		FR.[TreasuryCode] FinancingResourceTreasuryCode,
		BDFR.[Enabled] BudgetCodeFinancingResourceEnabled,
		BDFR.[Maximum] BudgetCodeFinancingResourceMaximum,
		BCFRD.[MiscellaneousBudgetCodeName],
		BCFRD.[MiscellaneousBudgetCode],
		BCFRD.[ProjectionName],
		BCFRD.[ProjectionCode],
		BCFRD.[ProjectName],
		BCFRD.[ProjectCode],
		BCFRD.[Maximum],
		BCFRD.[CreationDate],
		BCFRD.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		BCFRD.[CreatorPositionID],
		BCFRD.[RemoveDate],
		BCFRD.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName RemoverName,
		BCFRD.[RemoverPositionID]
	FROM pbo.BudgetCodeFinancingResourceDetail BCFRD
	INNER JOIN pbo.BudgetCodeFinancingResource BDFR ON BDFR.ID = BCFRD.BudgetCodeFinancingResourceID
	INNER JOIN [pbo].[BudgetCode] BC ON BC.ID = BDFR.[BudgetCodeID]
	INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
	INNER JOIN [pbo].[FinancingResource] FR ON FR.ID = BDFR.[FinancingResourceID]
	LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BDFR.CreatorUserID
	LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = BDFR.RemoverUserID
	WHERE BCFRD.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOBudgetCodeFinancingResourceDetails') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOBudgetCodeFinancingResourceDetails
GO

CREATE PROCEDURE pbo.spGetPBOBudgetCodeFinancingResourceDetails 
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ABudgetCodeName NVARCHAR(1500),
	@ABudgetCode VARCHAR(20),
	@ABudgetCodeType TINYINT,
	@ABudgetCodePaymentType TINYINT,
	@ABudgetCodePaymentDepartmentID UNIQUEIDENTIFIER,
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@AFinancingResourceName NVARCHAR(1500),
	@AFinancingResourceBudgetCodeType TINYINT,
	@AFinancingResourceAROCode INT,
	@AFinancingResourcePBOCode INT,
	@AFinancingResourceTreasuryCode INT,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceEnableState TINYINT,
	@ABudgetCodeFinancingResourceFromMaximum BIGINT,
	@ABudgetCodeFinancingResourceToMaximum BIGINT,
	@AMiscellaneousBudgetCodeName NVARCHAR(1500),
	@AMiscellaneousBudgetCode VARCHAR(20),
	@AProjectionName NVARCHAR(1500),
	@AProjectionCode VARCHAR(20),
	@AProjectName NVARCHAR(1500),
	@AProjectCode VARCHAR(20),
	@AFromMaximum BIGINT,
	@AToMaximum BIGINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@BudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@ABudgetCodeName)),
		@BudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@BudgetCodePaymentType TINYINT = COALESCE(@ABudgetCodePaymentType, 0),
		@BudgetCodePaymentDepartmentID UNIQUEIDENTIFIER = @ABudgetCodePaymentDepartmentID,
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@FinancingResourceName NVARCHAR(1500) = LTRIM(RTRIM(@AFinancingResourceName)),
		@FinancingResourceBudgetCodeType TINYINT = COALESCE(@AFinancingResourceBudgetCodeType, 0),
		@FinancingResourceAROCode INT = COALESCE(@AFinancingResourceAROCode, 0),
		@FinancingResourcePBOCode INT = COALESCE(@AFinancingResourcePBOCode, 0),
		@FinancingResourceTreasuryCode INT = COALESCE(@AFinancingResourceTreasuryCode, 0),
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@BudgetCodeFinancingResourceEnableState TINYINT = COALESCE(@ABudgetCodeFinancingResourceEnableState, 0),
		@BudgetCodeFinancingResourceFromMaximum BIGINT = COALESCE(@ABudgetCodeFinancingResourceFromMaximum, 0),
		@BudgetCodeFinancingResourceToMaximum BIGINT = COALESCE(@ABudgetCodeFinancingResourceToMaximum, 0),
		@MiscellaneousBudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@AMiscellaneousBudgetCodeName)),
		@MiscellaneousBudgetCode NVARCHAR(20) = LTRIM(RTRIM(@AMiscellaneousBudgetCode)),
		@ProjectionName NVARCHAR(1500) = LTRIM(RTRIM(@AProjectionName)),
		@ProjectionCode NVARCHAR(20) = LTRIM(RTRIM(@AProjectionCode)),
		@ProjectName NVARCHAR(1500) = LTRIM(RTRIM(@AProjectName)),
		@ProjectCode NVARCHAR(20) = LTRIM(RTRIM(@AProjectCode)),
		@FromMaximum BIGINT = COALESCE(@AFromMaximum, 0),
		@ToMaximum BIGINT = COALESCE(@AToMaximum, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			BCFRD.[ID],
			BCFRD.[BudgetCodeFinancingResourceID],
			BDFR.[BudgetCodeID],
			BC.[Name] BudgetCodeName,
			BC.[Code] BudgetCode,
			BC.[Type] BudgetCodeType,
			BC.[PaymentType] BudgetCodePaymentType,
			BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
			DEP.[Name] BudgetCodePaymentDepartmentName,
			BDFR.[FinancingResourceID],
			FR.[Name] FinancingResourceName,
			FR.[BudgetCodeType] FinancingResourceBudgetCodeType,
			FR.[AROCode] FinancingResourceAROCode,
			FR.[PBOCode] FinancingResourcePBOCode,
			FR.[TreasuryCode] FinancingResourceTreasuryCode,
			BDFR.[Enabled] BudgetCodeFinancingResourceEnabled,
			BDFR.[Maximum] BudgetCodeFinancingResourceMaximum,
			BCFRD.[MiscellaneousBudgetCodeName],
			BCFRD.[MiscellaneousBudgetCode],
			BCFRD.[ProjectionName],
			BCFRD.[ProjectionCode],
			BCFRD.[ProjectName],
			BCFRD.[ProjectCode],
			BCFRD.[Maximum],
			BCFRD.[CreationDate],
			BCFRD.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			BCFRD.[CreatorPositionID]
		FROM pbo.BudgetCodeFinancingResourceDetail BCFRD
		INNER JOIN pbo.BudgetCodeFinancingResource BDFR ON BDFR.ID = BCFRD.BudgetCodeFinancingResourceID
		INNER JOIN [pbo].[BudgetCode] BC ON BC.ID = BDFR.[BudgetCodeID]
		INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BC.PaymentDepartmentID
		INNER JOIN [pbo].[FinancingResource] FR ON FR.ID = BDFR.[FinancingResourceID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BDFR.CreatorUserID
		WHERE (BCFRD.[RemoveDate] IS NULL)
			AND (@BudgetCodeID IS NULL OR BDFR.[BudgetCodeID] = @BudgetCodeID)
			AND (@BudgetCodeName IS NULL OR BC.[Name] LIKE '%' + @BudgetCodeName + '%' )
			AND (@BudgetCode IS NULL OR BC.Code LIKE '%' + @BudgetCode + '%' )
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@BudgetCodePaymentType < 1 OR BC.[PaymentType] = @BudgetCodePaymentType)
			AND (@BudgetCodePaymentDepartmentID IS NULL OR BC.PaymentDepartmentID = @BudgetCodePaymentDepartmentID)
			AND (@FinancingResourceID IS NULL OR BDFR.[FinancingResourceID] = @FinancingResourceID)
			AND (@FinancingResourceName IS NULL OR FR.[Name] LIKE '%' + @FinancingResourceName + '%' )
			AND (@FinancingResourceBudgetCodeType < 1 OR FR.[BudgetCodeType] = @FinancingResourceBudgetCodeType)
			AND (@FinancingResourceAROCode < 1 OR FR.[AROCode] = @FinancingResourceAROCode)
			AND (@FinancingResourcePBOCode < 1 OR FR.[PBOCode] = @FinancingResourcePBOCode)
			AND (@FinancingResourceTreasuryCode < 1 OR FR.[TreasuryCode] = @FinancingResourceTreasuryCode)
			AND (@ABudgetCodeFinancingResourceID IS NULL OR BCFRD.[BudgetCodeFinancingResourceID] = @ABudgetCodeFinancingResourceID)
			AND (@BudgetCodeFinancingResourceEnableState < 1 OR BDFR.[Enabled] = @BudgetCodeFinancingResourceEnableState - 1)
			AND (@BudgetCodeFinancingResourceFromMaximum < 1 OR BDFR.[Maximum] >= @BudgetCodeFinancingResourceFromMaximum)
			AND (@BudgetCodeFinancingResourceToMaximum < 1 OR BDFR.[Maximum] <= @BudgetCodeFinancingResourceToMaximum)
			AND (@MiscellaneousBudgetCodeName IS NULL OR BCFRD.MiscellaneousBudgetCodeName LIKE '%' + @MiscellaneousBudgetCodeName + '%' )
			AND (@MiscellaneousBudgetCode IS NULL OR BCFRD.MiscellaneousBudgetCode LIKE '%' + @MiscellaneousBudgetCode + '%' )
			AND (@ProjectionName IS NULL OR BCFRD.ProjectionName LIKE '%' + @ProjectionName + '%' )
			AND (@ProjectionCode IS NULL OR BCFRD.ProjectionCode LIKE '%' + @ProjectionCode + '%' )
			AND (@ProjectName IS NULL OR BCFRD.ProjectName LIKE '%' + @ProjectName + '%' )
			AND (@ProjectCode IS NULL OR BCFRD.ProjectCode LIKE '%' + @ProjectCode + '%' )
			AND (@FromMaximum < 1 OR BCFRD.[Maximum] >= @FromMaximum)
			AND (@ToMaximum < 1 OR BCFRD.[Maximum] <= @ToMaximum)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyListPBOBudgetCodeFinancingResourceDetails') IS NOT NULL
    DROP PROCEDURE pbo.spModifyListPBOBudgetCodeFinancingResourceDetails
GO

CREATE PROCEDURE pbo.spModifyListPBOBudgetCodeFinancingResourceDetails
	@ADetails NVARCHAR(MAX),
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *
				FROM OPENJSON(@Details) 
				WITH
				(
					[BudgetCodeFinancingResourceID] UNIQUEIDENTIFIER,
					[MiscellaneousBudgetCode] VARCHAR(20),
					[ProjectionCode] VARCHAR(20),
					[Maximum] BIGINT
				)
			)
			UPDATE BCFRD
			SET [RemoveDate] = GETDATE(), [RemoverUserID] = @ModifireUserID, [RemoverPositionID] = @ModifirePositionID
			FROM [pbo].[BudgetCodeFinancingResourceDetail] BCFRD
			INNER JOIN CTE ON CTE.BudgetCodeFinancingResourceID = BCFRD.BudgetCodeFinancingResourceID

			; WITH CTE AS 
			(
				SELECT *
				FROM OPENJSON(@Details) 
				WITH
				(
					[BudgetCodeFinancingResourceID] UNIQUEIDENTIFIER,
					[MiscellaneousBudgetCode] VARCHAR(20),
					[ProjectionCode] VARCHAR(20),
					[Maximum] BIGINT
				)
			)
			INSERT INTO [pbo].[BudgetCodeFinancingResourceDetail]
			([ID], [BudgetCodeFinancingResourceID], [MiscellaneousBudgetCode], [ProjectionCode], [Maximum], [CreationDate], [CreatorUserID], [CreatorPositionID])
			SELECT 
			NEWID() [ID],
			CTE.[BudgetCodeFinancingResourceID] [BudgetCodeFinancingResourceID],
			CTE.[MiscellaneousBudgetCode] [MiscellaneousBudgetCode],
			CTE.[ProjectionCode] [ProjectionCode],
			CTE.[Maximum] [Maximum],
			GETDATE() [CreationDate], 
			@ModifireUserID [CreatorUserID],
			@ModifirePositionID [CreatorPositionID]
			FROM CTE

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyPBOBudgetCodeFinancingResourceDetail') IS NOT NULL
    DROP PROCEDURE pbo.spModifyPBOBudgetCodeFinancingResourceDetail
GO

CREATE PROCEDURE pbo.spModifyPBOBudgetCodeFinancingResourceDetail
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@AMiscellaneousBudgetCodeName NVARCHAR(1500),
	@AMiscellaneousBudgetCode VARCHAR(20),
	@AProjectionName NVARCHAR(1500),
	@AProjectionCode VARCHAR(20),
	@AProjectName NVARCHAR(1500),
	@AProjectCode VARCHAR(20),
	@AMaximum BIGINT,
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@MiscellaneousBudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@AMiscellaneousBudgetCodeName)),
		@MiscellaneousBudgetCode NVARCHAR(20) = LTRIM(RTRIM(@AMiscellaneousBudgetCode)),
		@ProjectionName NVARCHAR(1500) = LTRIM(RTRIM(@AProjectionName)),
		@ProjectionCode NVARCHAR(20) = LTRIM(RTRIM(@AProjectionCode)),
		@ProjectName NVARCHAR(1500) = LTRIM(RTRIM(@AProjectName)),
		@ProjectCode NVARCHAR(20) = LTRIM(RTRIM(@AProjectCode)),
		@Maximum BIGINT = @AMaximum,
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				
				INSERT INTO pbo.BudgetCodeFinancingResourceDetail
				([ID], [BudgetCodeFinancingResourceID], [MiscellaneousBudgetCodeName], [MiscellaneousBudgetCode], [ProjectionName], [ProjectionCode], [ProjectName], [ProjectCode], [Maximum], [CreationDate], [CreatorUserID], [CreatorPositionID])
				VALUES
				(@ID, @BudgetCodeFinancingResourceID, @MiscellaneousBudgetCodeName, @MiscellaneousBudgetCode, @ProjectionName, @ProjectionCode, @ProjectName, @ProjectCode, @Maximum, GETDATE(), @ModifireUserID, @ModifirePositionID)
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbo.spDeletePBOBudgetCodeSubDepartment'))
	DROP PROCEDURE pbo.spDeletePBOBudgetCodeSubDepartment
GO

CREATE PROCEDURE pbo.spDeletePBOBudgetCodeSubDepartment
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbo.BudgetCodeSubDepartment
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetDeletedPBOBudgetCodeSubDepartments') IS NOT NULL
    DROP PROCEDURE pbo.spGetDeletedPBOBudgetCodeSubDepartments
GO

CREATE PROCEDURE pbo.spGetDeletedPBOBudgetCodeSubDepartments 
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ABudgetCodeName NVARCHAR(1500),
	@ABudgetCode VARCHAR(20),
	@ABudgetCodeType TINYINT,
	@ABudgetCodePaymentType TINYINT,
	@ABudgetCodePaymentDepartmentID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ADepartmentName NVARCHAR(256),
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@BudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@ABudgetCodeName)),
		@BudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@BudgetCodePaymentType TINYINT = COALESCE(@ABudgetCodePaymentType, 0),
		@BudgetCodePaymentDepartmentID UNIQUEIDENTIFIER = @ABudgetCodePaymentDepartmentID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@DepartmentName NVARCHAR(256) = LTRIM(RTRIM(@ADepartmentName)),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			BCSD.[ID],
			BCSD.[BudgetCodeID],
			BC.Code BudgetCode,
			BC.[Name] BudgetCodeName,
			BC.[Type] BudgetCodeType,
			BC.PaymentType BudgetCodePaymentType,
			BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
			BCPD.[Name] BudgetCodePaymentDepartmentName,
			BCPD.[Code] BudgetCodePaymentDepartmentCode,
			BCSD.[DepartmentID],
			DEP.[Name] DepartmentName,
			DEP.[Code] DepartmentCode,
			BCSD.[CreationDate],
			BCSD.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			BCSD.[CreatorPositionID],
			BCSD.[RemoveDate],
			BCSD.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			BCSD.[RemoverPositionID]
		FROM [pbo].[BudgetCodeSubDepartment] BCSD
		INNER JOIN pbo.BudgetCode BC ON BC.ID = BCSD.[BudgetCodeID]
		INNER JOIN [Kama.Aro.Organization].[org].[Department] BCPD ON BCPD.ID = BC.PaymentDepartmentID
		INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BCSD.[DepartmentID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BCSD.CreatorUserID
		LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = BCSD.RemoverUserID
		WHERE (BCSD.[RemoveDate] IS NOT NULL)
			AND (@BudgetCodeID IS NULL OR BCSD.BudgetCodeID = @BudgetCodeID)
			AND (@BudgetCodeName IS NULL OR BC.[Name] LIKE '%' + @BudgetCodeName + '%' )
			AND (@BudgetCode IS NULL OR BC.Code LIKE '%' + @BudgetCode + '%' )
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@BudgetCodePaymentType < 1 OR BC.[PaymentType] = @BudgetCodePaymentType)
			AND (@BudgetCodePaymentDepartmentID IS NULL OR BC.PaymentDepartmentID = @BudgetCodePaymentDepartmentID)
			AND (@DepartmentID IS NULL OR BCSD.[DepartmentID] = @DepartmentID)
			AND (@DepartmentName IS NULL OR DEP.[Name] LIKE '%' + @DepartmentName + '%' )
			AND (@FromRemoveDate IS NULL OR BCSD.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR BCSD.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOBudgetCodeSubDepartment') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOBudgetCodeSubDepartment
GO

CREATE PROCEDURE pbo.spGetPBOBudgetCodeSubDepartment 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		BCSD.[ID],
		BCSD.[BudgetCodeID],
		BC.Code BudgetCode,
		BC.[Name] BudgetCodeName,
		BC.[Type] BudgetCodeType,
		BC.PaymentType BudgetCodePaymentType,
		BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
		BCPD.[Name] BudgetCodePaymentDepartmentName,
		BCPD.[Code] BudgetCodePaymentDepartmentCode,
		BCSD.[DepartmentID],
		DEP.[Name] DepartmentName,
		DEP.[Code] DepartmentCode,
		BCSD.[CreationDate],
		BCSD.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		BCSD.[CreatorPositionID],
		BCSD.[RemoveDate],
		BCSD.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName RemoverName,
		BCSD.[RemoverPositionID]
	FROM [pbo].[BudgetCodeSubDepartment] BCSD
	INNER JOIN pbo.BudgetCode BC ON BC.ID = BCSD.[BudgetCodeID]
	INNER JOIN [Kama.Aro.Organization].[org].[Department] BCPD ON BCPD.ID = BC.PaymentDepartmentID
	INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BCSD.[DepartmentID]
	LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BCSD.CreatorUserID
	LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = BCSD.RemoverUserID
	WHERE BCSD.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOBudgetCodeSubDepartments') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOBudgetCodeSubDepartments
GO

CREATE PROCEDURE pbo.spGetPBOBudgetCodeSubDepartments 
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ABudgetCodeName NVARCHAR(1500),
	@ABudgetCode VARCHAR(20),
	@ABudgetCodeType TINYINT,
	@ABudgetCodePaymentType TINYINT,
	@ABudgetCodePaymentDepartmentID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ADepartmentName NVARCHAR(256),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@BudgetCodeName NVARCHAR(1500) = LTRIM(RTRIM(@ABudgetCodeName)),
		@BudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@BudgetCodePaymentType TINYINT = COALESCE(@ABudgetCodePaymentType, 0),
		@BudgetCodePaymentDepartmentID UNIQUEIDENTIFIER = @ABudgetCodePaymentDepartmentID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@DepartmentName NVARCHAR(256) = LTRIM(RTRIM(@ADepartmentName)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			BCSD.[ID],
			BCSD.[BudgetCodeID],
			BC.Code BudgetCode,
			BC.[Name] BudgetCodeName,
			BC.[Type] BudgetCodeType,
			BC.PaymentType BudgetCodePaymentType,
			BC.PaymentDepartmentID BudgetCodePaymentDepartmentID,
			BCPD.[Name] BudgetCodePaymentDepartmentName,
			BCPD.[Code] BudgetCodePaymentDepartmentCode,
			BCSD.[DepartmentID],
			DEP.[Name] DepartmentName,
			DEP.[Code] DepartmentCode,
			BCSD.[CreationDate],
			BCSD.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			BCSD.[CreatorPositionID]
		FROM [pbo].[BudgetCodeSubDepartment] BCSD
		INNER JOIN pbo.BudgetCode BC ON BC.ID = BCSD.[BudgetCodeID]
		INNER JOIN [Kama.Aro.Organization].[org].[Department] BCPD ON BCPD.ID = BC.PaymentDepartmentID
		INNER JOIN [Kama.Aro.Organization].[org].[Department] DEP ON DEP.ID = BCSD.[DepartmentID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = BCSD.CreatorUserID
		WHERE (BCSD.[RemoveDate] IS NULL)
			AND (@BudgetCodeID IS NULL OR BCSD.BudgetCodeID = @BudgetCodeID)
			AND (@BudgetCodeName IS NULL OR BC.[Name] LIKE '%' + @BudgetCodeName + '%' )
			AND (@BudgetCode IS NULL OR BC.Code LIKE '%' + @BudgetCode + '%' )
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@BudgetCodePaymentType < 1 OR BC.[PaymentType] = @BudgetCodePaymentType)
			AND (@BudgetCodePaymentDepartmentID IS NULL OR BC.PaymentDepartmentID = @BudgetCodePaymentDepartmentID)
			AND (@DepartmentID IS NULL OR BCSD.[DepartmentID] = @DepartmentID)
			AND (@DepartmentName IS NULL OR DEP.[Name] LIKE '%' + @DepartmentName + '%' )
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyPBOBudgetCodeSubDepartment') IS NOT NULL
    DROP PROCEDURE pbo.spModifyPBOBudgetCodeSubDepartment
GO

CREATE PROCEDURE pbo.spModifyPBOBudgetCodeSubDepartment
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ADepartmentIDs NVARCHAR(MAX),
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@DepartmentIDs NVARCHAR(MAX) = @ADepartmentIDs,
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID
		
		DECLARE @T1 TABLE (ID UNIQUEIDENTIFIER)
		INSERT INTO @T1
		SELECT 
			VALUE AS ID
		FROM OPENJSON(@DepartmentIDs)
		GROUP BY
		VALUE


	BEGIN TRY
		BEGIN TRAN
			BEGIN
				INSERT INTO pbo.BudgetCodeSubDepartment
				([ID], [BudgetCodeID], [DepartmentID], [CreationDate], [CreatorUserID], [CreatorPositionID])
				SELECT
				NEWID() [ID], 
				@BudgetCodeID [BudgetCodeID], 
				t1.ID [DepartmentID], 
				GETDATE()[CreationDate], 
				@ModifireUserID [CreatorUserID], 
				@ModifirePositionID [CreatorPositionID]
			FROM @T1 t1
			LEFT JOIN pbo.BudgetCodeSubDepartment BCSD ON BCSD.[BudgetCodeID] = @BudgetCodeID AND t1.ID = BCSD.[DepartmentID] AND BCSD.[RemoverUserID] IS NULL
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbo.spUpdateListPBOBudgetCodeSubDepartments') AND type in (N'P', N'PC'))
DROP PROCEDURE pbo.spUpdateListPBOBudgetCodeSubDepartments
GO

CREATE PROCEDURE pbo.spUpdateListPBOBudgetCodeSubDepartments
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX),
	@ASaveType TINYINT

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@SaveType TINYINT = COALESCE(@ASaveType, 0),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			--IF @SaveType = 1 -- Replace
			--BEGIN
			--	UPDATE pbo.BudgetCodeSubDepartment
			--	SET RemoverUserID = @CurrentUserID,
			--	RemoverPositionID = @CurrentPositionID,
			--	RemoveDate = GETDATE()
			--END
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					[BudgetCodeID] UNIQUEIDENTIFIER,
					[DepartmentID] UNIQUEIDENTIFIER
				)
			)
			INSERT INTO pbo.BudgetCodeSubDepartment
			([ID], [BudgetCodeID], [DepartmentID], [CreationDate], [CreatorUserID], [CreatorPositionID])
			SELECT 
				NEWID() ID,
				Details.[BudgetCodeID] [BudgetCodeID],
				Details.[DepartmentID] [DepartmentID],
				GETDATE() [CreationDate],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbo.spDeletePBOFinancingResource'))
	DROP PROCEDURE pbo.spDeletePBOFinancingResource
GO

CREATE PROCEDURE pbo.spDeletePBOFinancingResource
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbo.FinancingResource
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetDeletedPBOFinancingResources') IS NOT NULL
    DROP PROCEDURE pbo.spGetDeletedPBOFinancingResources
GO

CREATE PROCEDURE pbo.spGetDeletedPBOFinancingResources 
	@AName NVARCHAR(1500),
	@ABudgetCodeType TINYINT,
	@AAROCode INT,
	@APBOCode INT,
	@ATreasuryCode INT,
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@AROCode INT = COALESCE(@AAROCode, 0),
		@PBOCode INT = COALESCE(@APBOCode, 0),
		@TreasuryCode INT = COALESCE(@ATreasuryCode, 0),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			FR.ID,
			FR.[Name],
			FR.BudgetCodeType,
			FR.AROCode,
			FR.PBOCode,
			FR.TreasuryCode,
			FR.[CreationDate],
			FR.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			FR.[CreatorPositionID],
			FR.[RemoveDate],
			FR.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			FR.[RemoverPositionID]
		FROM pbo.FinancingResource FR
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = FR.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = FR.RemoverUserID
		WHERE (FR.[RemoveDate] IS NOT NULL)
			AND (@Name IS NULL OR FR.[Name] LIKE '%' + @Name + '%')
			AND (@BudgetCodeType < 1 OR FR.BudgetCodeType = @BudgetCodeType)
			AND (@AROCode < 1 OR FR.AROCode = @AROCode)
			AND (@PBOCode < 1 OR FR.PBOCode = @PBOCode)
			AND (@TreasuryCode < 1 OR FR.TreasuryCode = @TreasuryCode)
			AND (@FromRemoveDate IS NULL OR FR.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR FR.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [AROCode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOFinancingResource') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOFinancingResource
GO

CREATE PROCEDURE pbo.spGetPBOFinancingResource 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		FR.ID,
		FR.[Name],
		FR.BudgetCodeType,
		FR.AROCode,
		FR.PBOCode,
		FR.TreasuryCode,
		FR.[CreationDate],
		FR.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		FR.[CreatorPositionID],
		FR.[RemoveDate],
		FR.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName RemoverName,
		FR.[RemoverPositionID]
	FROM pbo.FinancingResource FR
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = FR.CreatorUserID
		LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = FR.RemoverUserID
	WHERE FR.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOFinancingResources') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOFinancingResources
GO

CREATE PROCEDURE pbo.spGetPBOFinancingResources 
	@AName NVARCHAR(1500),
	@ABudgetCodeType TINYINT,
	@AAROCode INT,
	@APBOCode INT,
	@ATreasuryCode INT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@AROCode INT = COALESCE(@AAROCode, 0),
		@PBOCode INT = COALESCE(@APBOCode, 0),
		@TreasuryCode INT = COALESCE(@ATreasuryCode, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			FR.ID,
			FR.[Name],
			FR.BudgetCodeType,
			FR.AROCode,
			FR.PBOCode,
			FR.TreasuryCode,
			FR.[CreationDate],
			FR.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			FR.[CreatorPositionID]
		FROM pbo.FinancingResource FR
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = FR.CreatorUserID
		WHERE (FR.[RemoveDate] IS NULL)
			AND (@Name IS NULL OR FR.[Name] LIKE '%' + @Name + '%')
			AND (@BudgetCodeType < 1 OR FR.BudgetCodeType = @BudgetCodeType)
			AND (@AROCode < 1 OR FR.AROCode = @AROCode)
			AND (@PBOCode < 1 OR FR.PBOCode = @PBOCode)
			AND (@TreasuryCode < 1 OR FR.TreasuryCode = @TreasuryCode)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [AROCode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyPBOFinancingResource') IS NOT NULL
    DROP PROCEDURE pbo.spModifyPBOFinancingResource
GO

CREATE PROCEDURE pbo.spModifyPBOFinancingResource
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1500),
	@ABudgetCodeType TINYINT,
	@AAROCode INT,
	@APBOCode INT,
	@ATreasuryCode INT,
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@AROCode INT = COALESCE(@AAROCode, 0),
		@PBOCode INT = COALESCE(@APBOCode, 0),
		@TreasuryCode INT = COALESCE(@ATreasuryCode, 0),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				
				INSERT INTO pbo.FinancingResource
				([ID], [Name], [BudgetCodeType], [AROCode], [PBOCode], [TreasuryCode], [CreationDate], [CreatorUserID], [CreatorPositionID])
				VALUES
				(@ID, @Name, @BudgetCodeType, @AROCode, @PBOCode, @TreasuryCode, GETDATE(), @ModifireUserID, @ModifirePositionID)
			END
			ELSE -- update
			BEGIN 

				UPDATE pbo.FinancingResource
				SET 
					[BudgetCodeType] = @BudgetCodeType,
					[AROCode] = @AROCode,
					[PBOCode] = @PBOCode,
					[TreasuryCode] = @TreasuryCode
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbo.spDeletePBOSection'))
	DROP PROCEDURE pbo.spDeletePBOSection
GO

CREATE PROCEDURE pbo.spDeletePBOSection
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbo.PBOSection
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetDeletedPBOSections') IS NOT NULL
    DROP PROCEDURE pbo.spGetDeletedPBOSections
GO

CREATE PROCEDURE pbo.spGetDeletedPBOSections 
	@AName NVARCHAR(100),
	@ACode VARCHAR(10),
	@AType TINYINT,
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
		@Code NVARCHAR(10) = LTRIM(RTRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			PBOS.ID,
			PBOS.Code,
			PBOS.[Name],
			PBOS.[Type],
			PBOS.[CreationDate],
			PBOS.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			PBOS.[CreatorPositionID],
			PBOS.[RemoveDate],
			PBOS.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			PBOS.[RemoverPositionID]
		FROM pbo.PBOSection PBOS
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PBOS.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = PBOS.RemoverUserID
		WHERE (PBOS.[RemoveDate] IS NOT NULL)
			AND (@Code IS NULL OR PBOS.Code LIKE '%' + @Code + '%' )
			AND (@Type < 1 OR PBOS.[Type] = @Type)
			AND (@Name IS NULL OR PBOS.[Name] LIKE '%' + @Name + '%')
			AND (@FromRemoveDate IS NULL OR PBOS.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR PBOS.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Code]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOSection') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOSection
GO

CREATE PROCEDURE pbo.spGetPBOSection 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		PBOS.[ID],
		PBOS.[Name],
		PBOS.[Code],
		PBOS.[Type],
		PBOS.[CreationDate],
		PBOS.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		PBOS.[CreatorPositionID],
		PBOS.[RemoveDate],
		PBOS.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName RemoverName,
		PBOS.[RemoverPositionID]
	FROM pbo.PBOSection PBOS
	LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PBOS.CreatorUserID
	LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = PBOS.RemoverUserID
	WHERE PBOS.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOSections') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOSections
GO

CREATE PROCEDURE pbo.spGetPBOSections 
	@AName NVARCHAR(100),
	@ACode VARCHAR(10),
	@AType TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
		@Code NVARCHAR(10) = LTRIM(RTRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			PBOS.ID,
			PBOS.Code,
			PBOS.[Name],
			PBOS.[Type],
			PBOS.[CreationDate],
			PBOS.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			PBOS.[CreatorPositionID]
		FROM pbo.PBOSection PBOS
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = PBOS.CreatorUserID
		WHERE (@Code IS NULL OR PBOS.Code LIKE '%' + @Code + '%' )
			AND (@Type < 1 OR PBOS.[Type] = @Type)
			AND (@Name IS NULL OR PBOS.[Name] LIKE '%' + @Name + '%')
			AND (PBOS.[RemoveDate] IS NULL)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Code]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyPBOSection') IS NOT NULL
    DROP PROCEDURE pbo.spModifyPBOSection
GO

CREATE PROCEDURE pbo.spModifyPBOSection
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(100),
	@ACode VARCHAR(10),
	@AType TINYINT,
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
		@Code VARCHAR(10) = LTRIM(RTRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				
				INSERT INTO pbo.BudgetCode
				([ID], [Name], [Code], [Type], [CreationDate], [CreatorUserID], [CreatorPositionID])
				VALUES
				(@ID, @Name, @Code, @Type, GETDATE(), @ModifireUserID, @ModifirePositionID)
			END
			ELSE -- update
			BEGIN 

				UPDATE pbo.PBOSection
				SET Code = @Code,
					[Name] = @Name,
					[Type] = @Type
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbo.spDeletePBOSectionPositionAssignment'))
	DROP PROCEDURE pbo.spDeletePBOSectionPositionAssignment
GO

CREATE PROCEDURE pbo.spDeletePBOSectionPositionAssignment
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbo.PBOSectionPositionAssignment
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetDeletedPBOSectionPositionAssignments') IS NOT NULL
    DROP PROCEDURE pbo.spGetDeletedPBOSectionPositionAssignments
GO

CREATE PROCEDURE pbo.spGetDeletedPBOSectionPositionAssignments 
	@APositionName NVARCHAR(500),
	@APositionNationalCode VARCHAR(20),
	@APositionType TINYINT,
	@APositionID UNIQUEIDENTIFIER,
	@AUserName NVARCHAR(500),
	@AUserNationalCode VARCHAR(20),
	@AUserID UNIQUEIDENTIFIER,
	@APBOSectionName NVARCHAR(500),
	@APBOSectionCode VARCHAR(20),
	@APBOSectionType TINYINT,
	@APBOSectionID UNIQUEIDENTIFIER,
	@ABudgetCodeName NVARCHAR(500),
	@ABudgetCode VARCHAR(20),
	@ABudgetCodeType TINYINT,
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@AFinancingResourceName NVARCHAR(1500),
	@AFinancingResourceAROCode INT,
	@AFinancingResourcePBOCode INT,
	@AFinancingResourceTreasuryCode INT,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceEnableState TINYINT,
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@PositionName NVARCHAR(500) = LTRIM(RTRIM(@APositionName)),
		@PositionNationalCode NVARCHAR(20) = LTRIM(RTRIM(@APositionNationalCode)),
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@UserName NVARCHAR(500) = LTRIM(RTRIM(@AUserName)),
		@UserNationalCode NVARCHAR(20) = LTRIM(RTRIM(@AUserNationalCode)),
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PBOSectionName NVARCHAR(500) = LTRIM(RTRIM(@APBOSectionName)),
		@PBOSectionCode NVARCHAR(20) = LTRIM(RTRIM(@APBOSectionCode)),
		@PBOSectionType TINYINT = COALESCE(@APBOSectionType, 0),
		@PBOSectionID UNIQUEIDENTIFIER = @APBOSectionID,
		@BudgetCodeName NVARCHAR(500) = LTRIM(RTRIM(@ABudgetCodeName)),
		@BudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@FinancingResourceName NVARCHAR(1500) = LTRIM(RTRIM(@AFinancingResourceName)),
		@FinancingResourceAROCode INT = COALESCE(@AFinancingResourceAROCode, 0),
		@FinancingResourcePBOCode INT = COALESCE(@AFinancingResourcePBOCode, 0),
		@FinancingResourceTreasuryCode INT = COALESCE(@AFinancingResourceTreasuryCode, 0),
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@BudgetCodeFinancingResourceEnableState TINYINT = COALESCE(@ABudgetCodeFinancingResourceEnableState, 0),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			PBOSPA.ID,
			PBOSPA.PBOSectionID,
			PBOS.[Name] PBOSectionName,
			PBOS.[Type] PBOSectionType,
			PBOS.Code PBOSectionCode,
			PBOSPA.BudgetCodeFinancingResourceID,
			BCFR.[Enabled] BudgetCodeFinancingResourceEnabled,
			BCFR.FinancingResourceID,
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
			BCFR.BudgetCodeID,
			BC.[Name] BudgetCodeName,
			BC.Code BudgetCode,
			BC.[Type] BudgetCodeType,
			BC.PaymentType BudgetCodePaymentType,
			PBOSPA.PositionID,
			PBOSP.FirstName + ' ' + PBOSP.LastName PositionName,
			PBOSP.NationalCode PositionNationalCode,
			PBOSP.[Type] PositionType,
			PBOSPA.CreatorUserID,
			CU.FirstName + ' ' + CU.LastName CreatorName,
			PBOSPA.CreationDate,
			RU.FirstName + ' ' + RU.LastName RemoverName,
			PBOSPA.RemoverUserID,
			PBOSPA.RemoveDate
		FROM pbo.PBOSectionPositionAssignment PBOSPA
		INNER JOIN pbo.PBOSection PBOS ON PBOSPA.PBOSectionID = PBOS.ID
		INNER JOIN pbo.BudgetCodeFinancingResource BCFR ON PBOSPA.BudgetCodeFinancingResourceID = BCFR.ID
		INNER JOIN pbo.FinancingResource FR ON BCFR.FinancingResourceID = FR.ID
		INNER JOIN pbo.BudgetCode BC ON BCFR.BudgetCodeID = BC.ID
		INNER JOIN [Kama.Aro.Organization].org._Position PBOSP ON PBOSP.ID = PBOSPA.PositionID
		INNER JOIN [Kama.Aro.Organization].org.[User] PBOSU ON PBOSU.ID = PBOSP.UserID
		LEFT JOIN [Kama.Aro.Organization].org.[User] CU ON CU.ID = PBOSPA.CreatorUserID
		LEFT JOIN [Kama.Aro.Organization].org.[User] RU ON RU.ID = PBOSPA.RemoverUserID
		WHERE (PBOSPA.RemoveDate IS NOT NULL)
			AND (@PositionName IS NULL OR ((PBOSP.FirstName + ' ' + PBOSP.LastName) LIKE '%' + @PositionName + '%'))
			AND (@PositionNationalCode IS NULL OR PBOSP.NationalCode = @PositionNationalCode)
			AND (@PositionType < 1 OR PBOSP.[Type] = @PositionType)
			AND (@PositionID IS NULL OR PBOSPA.PositionID = @PositionID)
			AND (@UserName IS NULL OR ((PBOSU.FirstName + ' ' + PBOSU.LastName) LIKE '%' + @UserName + '%'))
			AND (@UserNationalCode IS NULL OR PBOSU.NationalCode = @UserNationalCode)
			AND (@UserID IS NULL OR PBOSU.ID = @UserID)
			AND (@PBOSectionName IS NULL OR (PBOS.[Name] LIKE '%' + @PBOSectionName + '%'))
			AND (@PBOSectionCode IS NULL OR PBOS.Code = @PBOSectionCode)
			AND (@PBOSectionType < 1 OR PBOS.[Type] = @PBOSectionType)
			AND (@PBOSectionID IS NULL OR PBOSPA.PBOSectionID = @PBOSectionID)
			AND (@BudgetCodeName IS NULL OR (BC.[Name] LIKE '%' + @BudgetCodeName + '%'))
			AND (@BudgetCode IS NULL OR BC.Code = @BudgetCode)
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@BudgetCodeID IS NULL OR BCFR.BudgetCodeID = @BudgetCodeID)
			AND (@FinancingResourceID IS NULL OR BCFR.FinancingResourceID = @FinancingResourceID)
			AND (@FinancingResourceName IS NULL OR (FR.[Name] LIKE '%' + @FinancingResourceName + '%'))
			AND (@FinancingResourceAROCode < 1 OR FR.[AROCode] = @FinancingResourceAROCode)
			AND (@FinancingResourcePBOCode < 1 OR FR.[PBOCode] = @FinancingResourcePBOCode)
			AND (@FinancingResourceTreasuryCode < 1 OR FR.[TreasuryCode] = @FinancingResourceTreasuryCode)
			AND (@BudgetCodeFinancingResourceID IS NULL OR PBOSPA.BudgetCodeFinancingResourceID = @BudgetCodeFinancingResourceID)
			AND (@BudgetCodeFinancingResourceEnableState < 1 OR BCFR.[Enabled] = @BudgetCodeFinancingResourceEnableState - 1)
			AND (@FromRemoveDate IS NULL OR PBOSPA.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR PBOSPA.RemoveDate < @ToRemoveDate)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOSectionPositionAssignment') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOSectionPositionAssignment
GO

CREATE PROCEDURE pbo.spGetPBOSectionPositionAssignment 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		PBOSPA.ID,
		PBOSPA.PBOSectionID,
		PBOS.[Name] PBOSectionName,
		PBOS.[Type] PBOSectionType,
		PBOS.Code PBOSectionCode,
		PBOSPA.BudgetCodeFinancingResourceID,
		BCFR.[Enabled] BudgetCodeFinancingResourceEnabled,
		BCFR.FinancingResourceID,
		FR.[Name] FinancingResourceName,
		FR.AROCode FinancingResourceAROCode,
		FR.PBOCode FinancingResourcePBOCode,
		FR.TreasuryCode FinancingResourceTreasuryCode,
		BCFR.BudgetCodeID,
		BC.[Name] BudgetCodeName,
		BC.Code BudgetCode,
		BC.[Type] BudgetCodeType,
		BC.PaymentType BudgetCodePaymentType,
		PBOSPA.PositionID,
		PBOSP.FirstName + ' ' + PBOSP.LastName PositionName,
		PBOSP.NationalCode PositionNationalCode,
		PBOSP.[Type] PositionType,
		PBOSPA.CreatorUserID,
		CU.FirstName + ' ' + CU.LastName CreatorName,
		PBOSPA.CreationDate,
		RU.FirstName + ' ' + RU.LastName RemoverName,
		PBOSPA.RemoverUserID,
		PBOSPA.RemoveDate
	FROM pbo.PBOSectionPositionAssignment PBOSPA
	INNER JOIN pbo.PBOSection PBOS ON PBOSPA.PBOSectionID = PBOS.ID
	INNER JOIN pbo.BudgetCodeFinancingResource BCFR ON PBOSPA.BudgetCodeFinancingResourceID = BCFR.ID
	INNER JOIN pbo.FinancingResource FR ON BCFR.FinancingResourceID = FR.ID
	INNER JOIN pbo.BudgetCode BC ON BCFR.BudgetCodeID = BC.ID
	INNER JOIN [Kama.Aro.Organization].org._Position PBOSP ON PBOSP.ID = PBOSPA.PositionID
	INNER JOIN [Kama.Aro.Organization].org.[User] PBOSU ON PBOSU.ID = PBOSP.UserID
	LEFT JOIN [Kama.Aro.Organization].org.[User] CU ON CU.ID = PBOSPA.CreatorUserID
	LEFT JOIN [Kama.Aro.Organization].org.[User] RU ON RU.ID = PBOSPA.RemoverUserID
	WHERE PBOSPA.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOSectionPositionAssignmentHistory') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOSectionPositionAssignmentHistory
GO

CREATE PROCEDURE pbo.spGetPBOSectionPositionAssignmentHistory 
	@APostionID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@PostionID UNIQUEIDENTIFIER = @APostionID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	;WITH MainSelect AS (
		SELECT DISTINCT
			DF.DocumentID,
			TR.OrganID,
			Organ.[Name] OrganName,
			TR.[Month],
			TR.[Year],
			DF.FromPositionID,
			DF.FromUserID,
			BD.TrackingCode
		FROM pbl.DocumentFlow DF
		INNER JOIN pbl.BaseDocument BD ON DF.DocumentID = BD.ID
		INNER JOIN wag.TreasuryRequest TR ON TR.ID = BD.ID
		INNER JOIN org._Organ Organ ON Organ.ID = TR.OrganID
		LEFT JOIN [Kama.Aro.Organization].org.[User] Us ON Us.ID = DF.FromUserID
		WHERE BD.RemoveDate IS NULL AND BD.[Type] = 3
			AND (@PostionID IS NULL OR DF.FromPositionID = @PostionID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY TrackingCode
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spGetPBOSectionPositionAssignments') IS NOT NULL
    DROP PROCEDURE pbo.spGetPBOSectionPositionAssignments
GO

CREATE PROCEDURE pbo.spGetPBOSectionPositionAssignments 
	@APositionName NVARCHAR(500),
	@APositionNationalCode VARCHAR(20),
	@APositionType TINYINT,
	@APositionID UNIQUEIDENTIFIER,
	@AUserName NVARCHAR(500),
	@AUserNationalCode VARCHAR(20),
	@AUserID UNIQUEIDENTIFIER,
	@APBOSectionName NVARCHAR(500),
	@APBOSectionCode VARCHAR(20),
	@APBOSectionType TINYINT,
	@APBOSectionID UNIQUEIDENTIFIER,
	@ABudgetCodeName NVARCHAR(500),
	@ABudgetCode VARCHAR(20),
	@ABudgetCodeType TINYINT,
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@AFinancingResourceName NVARCHAR(1500),
	@AFinancingResourceAROCode INT,
	@AFinancingResourcePBOCode INT,
	@AFinancingResourceTreasuryCode INT,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceEnableState TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@PositionName NVARCHAR(500) = LTRIM(RTRIM(@APositionName)),
		@PositionNationalCode NVARCHAR(20) = LTRIM(RTRIM(@APositionNationalCode)),
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@UserName NVARCHAR(500) = LTRIM(RTRIM(@AUserName)),
		@UserNationalCode NVARCHAR(20) = LTRIM(RTRIM(@AUserNationalCode)),
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PBOSectionName NVARCHAR(500) = LTRIM(RTRIM(@APBOSectionName)),
		@PBOSectionCode NVARCHAR(20) = LTRIM(RTRIM(@APBOSectionCode)),
		@PBOSectionType TINYINT = COALESCE(@APBOSectionType, 0),
		@PBOSectionID UNIQUEIDENTIFIER = @APBOSectionID,
		@BudgetCodeName NVARCHAR(500) = LTRIM(RTRIM(@ABudgetCodeName)),
		@BudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@FinancingResourceName NVARCHAR(1500) = LTRIM(RTRIM(@AFinancingResourceName)),
		@FinancingResourceAROCode INT = COALESCE(@AFinancingResourceAROCode, 0),
		@FinancingResourcePBOCode INT = COALESCE(@AFinancingResourcePBOCode, 0),
		@FinancingResourceTreasuryCode INT = COALESCE(@AFinancingResourceTreasuryCode, 0),
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@BudgetCodeFinancingResourceEnableState TINYINT = COALESCE(@ABudgetCodeFinancingResourceEnableState, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			PBOSPA.ID,
			PBOSPA.PBOSectionID,
			PBOS.[Name] PBOSectionName,
			PBOS.[Type] PBOSectionType,
			PBOS.Code PBOSectionCode,
			PBOSPA.BudgetCodeFinancingResourceID,
			BCFR.[Enabled] BudgetCodeFinancingResourceEnabled,
			BCFR.FinancingResourceID,
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
			BCFR.BudgetCodeID,
			BC.[Name] BudgetCodeName,
			BC.Code BudgetCode,
			BC.[Type] BudgetCodeType,
			BC.PaymentType BudgetCodePaymentType,
			PBOSPA.PositionID,
			PBOSP.FirstName + ' ' + PBOSP.LastName PositionName,
			PBOSP.NationalCode PositionNationalCode,
			PBOSP.[Type] PositionType,
			PBOSPA.CreatorUserID,
			CU.FirstName + ' ' + CU.LastName CreatorName,
			PBOSPA.CreationDate
		FROM pbo.PBOSectionPositionAssignment PBOSPA
		INNER JOIN pbo.PBOSection PBOS ON PBOSPA.PBOSectionID = PBOS.ID
		INNER JOIN pbo.BudgetCodeFinancingResource BCFR ON PBOSPA.BudgetCodeFinancingResourceID = BCFR.ID
		INNER JOIN pbo.FinancingResource FR ON BCFR.FinancingResourceID = FR.ID
		INNER JOIN pbo.BudgetCode BC ON BCFR.BudgetCodeID = BC.ID
		INNER JOIN [Kama.Aro.Organization].org._Position PBOSP ON PBOSP.ID = PBOSPA.PositionID
		INNER JOIN [Kama.Aro.Organization].org.[User] PBOSU ON PBOSU.ID = PBOSP.UserID
		LEFT JOIN [Kama.Aro.Organization].org.[User] CU ON CU.ID = PBOSPA.CreatorUserID
		WHERE (PBOSPA.[RemoveDate] IS NULL)
			AND (@PositionName IS NULL OR ((PBOSP.FirstName + ' ' + PBOSP.LastName) LIKE '%' + @PositionName + '%'))
			AND (@PositionNationalCode IS NULL OR PBOSP.NationalCode = @PositionNationalCode)
			AND (@PositionType < 1 OR PBOSP.[Type] = @PositionType)
			AND (@PositionID IS NULL OR PBOSPA.PositionID = @PositionID)
			AND (@UserName IS NULL OR ((PBOSU.FirstName + ' ' + PBOSU.LastName) LIKE '%' + @UserName + '%'))
			AND (@UserNationalCode IS NULL OR PBOSU.NationalCode = @UserNationalCode)
			AND (@UserID IS NULL OR PBOSU.ID = @UserID)
			AND (@PBOSectionName IS NULL OR (PBOS.[Name] LIKE '%' + @PBOSectionName + '%'))
			AND (@PBOSectionCode IS NULL OR PBOS.Code = @PBOSectionCode)
			AND (@PBOSectionType < 1 OR PBOS.[Type] = @PBOSectionType)
			AND (@PBOSectionID IS NULL OR PBOSPA.PBOSectionID = @PBOSectionID)
			AND (@BudgetCodeName IS NULL OR (BC.[Name] LIKE '%' + @BudgetCodeName + '%'))
			AND (@BudgetCode IS NULL OR BC.Code = @BudgetCode)
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@BudgetCodeID IS NULL OR BCFR.BudgetCodeID = @BudgetCodeID)
			AND (@FinancingResourceID IS NULL OR BCFR.FinancingResourceID = @FinancingResourceID)
			AND (@FinancingResourceName IS NULL OR (FR.[Name] LIKE '%' + @FinancingResourceName + '%'))
			AND (@FinancingResourceAROCode < 1 OR FR.[AROCode] = @FinancingResourceAROCode)
			AND (@FinancingResourcePBOCode < 1 OR FR.[PBOCode] = @FinancingResourcePBOCode)
			AND (@FinancingResourceTreasuryCode < 1 OR FR.[TreasuryCode] = @FinancingResourceTreasuryCode)
			AND (@BudgetCodeFinancingResourceID IS NULL OR PBOSPA.BudgetCodeFinancingResourceID = @BudgetCodeFinancingResourceID)
			AND (@BudgetCodeFinancingResourceEnableState < 1 OR BCFR.[Enabled] = @BudgetCodeFinancingResourceEnableState - 1)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spModifyPBOSectionPositionAssignment') IS NOT NULL
    DROP PROCEDURE pbo.spModifyPBOSectionPositionAssignment
GO

CREATE PROCEDURE pbo.spModifyPBOSectionPositionAssignment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APBOSectionID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@APositionID UNIQUEIDENTIFIER,
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PBOSectionID UNIQUEIDENTIFIER = @APBOSectionID,
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO pbo.PBOSectionPositionAssignment
				([ID], [PBOSectionID], [BudgetCodeFinancingResourceID], [PositionID], [CreationDate], [CreatorUserID], [CreatorPositionID])
				VALUES
				(@ID, @PBOSectionID, @BudgetCodeFinancingResourceID, @PositionID, GETDATE(), @ModifireUserID, @ModifirePositionID)
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbo.spUpdateListPBOSectionPositionAssignments') AND type in (N'P', N'PC'))
DROP PROCEDURE pbo.spUpdateListPBOSectionPositionAssignments
GO

CREATE PROCEDURE pbo.spUpdateListPBOSectionPositionAssignments
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX),
	@ASaveType TINYINT

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@SaveType TINYINT = COALESCE(@ASaveType, 0),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @SaveType = 1 -- Replace
			BEGIN
				UPDATE pbo.PBOSectionPositionAssignment
				SET RemoverUserID = @CurrentUserID,
				RemoverPositionID = @CurrentPositionID,
				RemoveDate = GETDATE()
			END
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					PositionID UNIQUEIDENTIFIER,
					PBOSectionID UNIQUEIDENTIFIER,
					BudgetCodeFinancingResourceID UNIQUEIDENTIFIER
				)
			)
			INSERT INTO pbo.PBOSectionPositionAssignment
			([ID], [PBOSectionID], [BudgetCodeFinancingResourceID], [PositionID], [CreationDate], [CreatorUserID], [CreatorPositionID])
			SELECT 
				NEWID() ID,
				Details.PBOSectionID [PBOSectionID],
				Details.BudgetCodeFinancingResourceID [BudgetCodeID],
				Details.PositionID [PositionID],
				GETDATE() [CreationDate],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeleteAffairsOrganAssignment'))
	DROP PROCEDURE pbl.spDeleteAffairsOrganAssignment
GO

CREATE PROCEDURE pbl.spDeleteAffairsOrganAssignment
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID


	BEGIN TRY
		BEGIN TRAN


			UPDATE [pbl].[AffairsOrganAssignment]
			SET RemoverUserID = @CurrentUserID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Pardakht]

GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetAffairsOrganAssignment'))
DROP PROCEDURE pbl.spGetAffairsOrganAssignment
GO

CREATE PROCEDURE pbl.spGetAffairsOrganAssignment
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	

	SELECT 
		affairsOrganAssignment.[ID], 
		affairsOrganAssignment.[OrganID], 
		affairsOrganAssignment.[PositionSubTypeID], 
		affairsOrganAssignment.[CreationDate], 
		affairsOrganAssignment.[RemoverUserID], 
		affairsOrganAssignment.[RemoveDate],
		department.[Type] DepartmentType,
		department.Code OrganCode,
		department.[Name] OrganName,
		positionSubType.[Name] PositionSubTypeName
	FROM [pbl].[AffairsOrganAssignment] affairsOrganAssignment
		INNER JOIN org.Department department ON department.ID = affairsOrganAssignment.OrganID
		INNER JOIN [org].[PositionSubType] positionSubType ON positionSubType.ID = affairsOrganAssignment.PositionSubTypeID
	WHERE affairsOrganAssignment.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetAffairsOrganAssignments'))
DROP PROCEDURE pbl.spGetAffairsOrganAssignments
GO

CREATE PROCEDURE pbl.spGetAffairsOrganAssignments
	@AOrganID UNIQUEIDENTIFIER,
	@AOrganName NVARCHAR(256),
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@APositionSubTypeName NVARCHAR(256),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@OrganName NVARCHAR(256) = LTRIM(RTRIM(@AOrganName)),
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@PositionSubTypeName NVARCHAR(256) = LTRIM(RTRIM(@APositionSubTypeName)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)
	
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			affairsOrganAssignment.[ID],
			department.ID [OrganID],
			affairsOrganAssignment.[PositionSubTypeID],
			affairsOrganAssignment.[CreationDate],
			affairsOrganAssignment.[RemoverUserID],
			affairsOrganAssignment.[RemoveDate],
			department.[Type] DepartmentType,
			department.Code OrganCode,
			department.[Name] OrganName,
			positionSubType.[Name] PositionSubTypeName
		FROM [org].[Department] department
			LEFT JOIN [pbl].[AffairsOrganAssignment] affairsOrganAssignment ON affairsOrganAssignment.OrganID = department.ID AND affairsOrganAssignment.RemoverUserID IS NULL
			LEFT JOIN [org].[PositionSubType] positionSubType ON positionSubType.ID = affairsOrganAssignment.PositionSubTypeID
		WHERE (department.[Type] = 1)
			AND (department.[Name] NOT LIKE N'%���%')
			AND (department.[Name] NOT LIKE N'%���%')
			AND (department.RemoverID IS NULL)
			AND (department.ID <> '00000000-0000-0000-0000-000000000000')
			AND (@OrganName IS NULL OR department.[Name] Like CONCAT('%', @OrganName , '%'))
			AND (@PositionSubTypeName IS NULL OR positionSubType.[Name] Like CONCAT('%', @APositionSubTypeName , '%'))
			AND (@OrganID IS NULL OR department.ID = @OrganID)
			AND (@PositionSubTypeID IS NULL OR positionSubType.ID = @APositionSubTypeID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, Total
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyAffairsOrganAssignment'))
	DROP PROCEDURE pbl.spModifyAffairsOrganAssignment
GO

CREATE PROCEDURE pbl.spModifyAffairsOrganAssignment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@AResult NVARCHAR(MAX) OUTPUT

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID


	BEGIN TRY
		BEGIN TRAN
			 
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO [pbl].[AffairsOrganAssignment]
					([ID], [OrganID], [PositionSubTypeID], [CreationDate], [RemoverUserID], [RemoveDate])
				VALUES
					(@ID, @OrganID, @PositionSubTypeID, GETDATE(), NULL, NULL)


			END
			ELSE
			BEGIN -- update

				UPDATE [pbl].[AffairsOrganAssignment]
				SET 
					PositionSubTypeID = @PositionSubTypeID
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE pbl.spDeleteAttachment
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [pbl].[Attachment]
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE pbl.spDeleteAttachments
	@AParentID UNIQUEIDENTIFIER,
	@ATypes NVARCHAR(MAX),
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Types NVARCHAR(MAX) = TRIM(@ATypes),
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			UPDATE att
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			FROM [pbl].[Attachment] att
			LEFT JOIN OPENJSON(@Types) Typ ON Typ.value = att.[Type]
			WHERE ParentID = @ParentID
			AND (@Types IS NULL OR Typ.value = att.[Type])
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetAttachment'))
	DROP PROCEDURE pbl.spGetAttachment
GO

CREATE PROCEDURE pbl.spGetAttachment
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	;WITH Errors AS (
		SELECT COUNT(ID) ErrorCount, AttachmentID
		FROM [pbl].[AttachmentError]
		WHERE AttachmentID = @ID
		GROUP BY AttachmentID
	)	
	SELECT
		Attachment.ID,
		Attachment.ParentID,  
		Attachment.[Type],
		Attachment.[FileName],
		Attachment.Comment,
		Attachment.[Data],
		Attachment.[Name],
		Attachment.[CreationDate],
		Attachment.[CreatorUserID],
		Attachment.[CreatorPositionID],
		COALESCE(Errors.ErrorCount, 0) ErrorCount
	FROM pbl.Attachment
	LEFT JOIN Errors ON Errors.AttachmentID = Attachment.ID
	WHERE Attachment.ID = @ID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetAttachments'))
	DROP PROCEDURE pbl.spGetAttachments
GO

CREATE PROCEDURE pbl.spGetAttachments
	@AParentID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@AWithData BIT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Type TINYINT = COALESCE(@AType, 0),
		@WithData BIT = COALESCE(@AWithData, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH Errors AS (
		SELECT COUNT(ID) ErrorCount, AttachmentID
		FROM [pbl].[AttachmentError] 
		GROUP BY AttachmentID
	)
	, MainSelect AS
	(
		SELECT 
			Attachment.ID,
			Attachment.ParentID,
			Attachment.[Type],
			Attachment.[FileName],
			Attachment.Comment,
			Attachment.[Name],
			Attachment.[CreationDate],
			Attachment.[CreatorUserID],
			Attachment.[CreatorPositionID],
			COALESCE(Errors.ErrorCount, 0) ErrorCount,
			CASE WHEN @WithData = 0 THEN NULL ELSE Data END Data
		FROM pbl.Attachment
		LEFT JOIN Errors ON Errors.AttachmentID = Attachment.ID
		WHERE ([RemoveDate] IS NULL)
			AND (@ParentID IS NULL OR ParentID = @ParentID)
			AND (@Type < 1 OR Type = @Type) 
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

	

END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO

CREATE OR ALTER PROCEDURE pbl.spGetAttachmentsForPayrollExcelProcess
	@AParentID UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID
	
	SELECT [Data]
	FROM pbl.Attachment
	WHERE (ParentID = @ParentID)
		AND ([Type] = 2) 
END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetTopOneAttachmentByParentIDAndType'))
	DROP PROCEDURE pbl.spGetTopOneAttachmentByParentIDAndType
GO

CREATE PROCEDURE pbl.spGetTopOneAttachmentByParentIDAndType
	@AParentID UNIQUEIDENTIFIER,
	@AType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Type TINYINT = COALESCE(@AType, 0)

	;WITH Errors AS (
		SELECT COUNT(ID) ErrorCount, AttachmentID
		FROM [pbl].[AttachmentError] 
		GROUP BY AttachmentID
	)
	SELECT Top (1)
		ID,
		ParentID,
		[Type],
		[FileName],
		Comment,
		[Name],
		COALESCE(Errors.ErrorCount, 0) ErrorCount,
		[Data]
	FROM pbl.Attachment
	LEFT JOIN Errors ON Errors.AttachmentID = Attachment.ID
	WHERE (@ParentID IS NULL OR ParentID = @ParentID)
		AND (@Type < 1 OR Type = @Type)
		AND ([RemoveDate] IS NULL)

END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyAttachment'))
	DROP PROCEDURE pbl.spModifyAttachment
GO

CREATE PROCEDURE pbl.spModifyAttachment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@AFileName NVARCHAR(256),
	@AComment NVARCHAR(256),
	@AName NVARCHAR(255),
	@AData VARBINARY(MAX),
	@AFileSize BIGINT,
	@ACreatorUserID UNIQUEIDENTIFIER,
	@ACreatorPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Type TINYINT = COALESCE(@AType, 0),
		@FileName NVARCHAR(256) = LTRIM(RTRIM(@AFileName)),
		@Comment NVARCHAR(256) = LTRIM(RTRIM(@AComment)),
		@Name NVARCHAR(255) = LTRIM(RTRIM(@AName)),
		@Data VARBINARY(MAX) = @AData,
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@CreatorPositionID UNIQUEIDENTIFIER = @ACreatorPositionID,
		@FileSize BIGINT =COALESCE(@AFileSize, 0) 

				
	---- Begin Validation
	IF @ParentID IS NULL
		RETURN -2 -- شناسه پدر نامعتبر است

	IF @FileName IS NULL OR @FileName = ''
		RETURN -3

	IF DATALENGTH(@Data) < 1
		RETURN -4
	---- End Validation

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO pbl.Attachment
				(ID, ParentID, [Type], [FileName], [Data],FileSize, Comment, [Name], [CreationDate], [CreatorUserID], [CreatorPositionID])
				VALUES
				(@ID, @ParentID, @Type, @FileName, @Data,@FileSize, @Comment, @Name, GETDATE(), @CreatorUserID, @CreatorPositionID)

			END
			ELSE
			BEGIN
				SET @ParentID = (SELECT ParentID FROM pbl.Attachment WHERE ID = @ID)

				UPDATE pbl.Attachment
				SET [FileName] = @FileName, [Data] = @Data
				,FileSize = @FileSize
				,Comment = @Comment
				,[Name]= @Name
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetAttachmentError'))
	DROP PROCEDURE pbl.spGetAttachmentError
GO

CREATE PROCEDURE pbl.spGetAttachmentError
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
		
	SELECT 
		AE.[ID],
		AE.[AttachmentID],
		A.[ParentID] AttachmentParentID,
		A.[Type] AttachmentType,
		A.[FileName] AttachmentFileName,
		AE.[ColumnIndex],
		AE.[RowIndex],
		AE.[ErrorText]
	FROM [pbl].[AttachmentError] AE
	INNER JOIN [pbl].[Attachment] A ON A.ID = AE.[AttachmentID]
	WHERE AE.ID = @ID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetAttachmentErrors'))
	DROP PROCEDURE pbl.spGetAttachmentErrors
GO

CREATE PROCEDURE pbl.spGetAttachmentErrors
	@AAttachmentID UNIQUEIDENTIFIER,
	@AAttachmentParentID UNIQUEIDENTIFIER,
	@AAttachmentType TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@AttachmentID UNIQUEIDENTIFIER = @AAttachmentID,
		@AttachmentParentID UNIQUEIDENTIFIER = @AAttachmentParentID,
		@AttachmentType TINYINT = COALESCE(@AAttachmentType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	; WITH MainSelect AS
	(
		SELECT 
			AE.[ID],
			AE.[AttachmentID],
			A.[ParentID] AttachmentParentID,
			A.[Type] AttachmentType,
			A.[FileName] AttachmentFileName,
			AE.[ColumnIndex],
			AE.[RowIndex],
			AE.[ErrorText]
		FROM [pbl].[AttachmentError] AE
		INNER JOIN [pbl].[Attachment] A ON A.ID = AE.[AttachmentID]
		WHERE (@AttachmentID IS NULL OR AE.[AttachmentID] = @AttachmentID)
			AND (@AttachmentParentID IS NULL OR A.[ParentID] = @AttachmentParentID)
			AND (@AttachmentType < 0 OR @AttachmentType = A.[Type])
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [RowIndex]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht.Attachment]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spUpdateListAttachmentErrors') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spUpdateListAttachmentErrors
GO

CREATE PROCEDURE pbl.spUpdateListAttachmentErrors
	@AAttachmentID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX)

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@AttachmentID UNIQUEIDENTIFIER = @AAttachmentID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					ColumnIndex BIGINT,
					RowIndex BIGINT,
					ErrorText NVARCHAR(Max)
				)
			)
			INSERT INTO [pbl].[AttachmentError]
			([ID], [AttachmentID], [ColumnIndex], [RowIndex], [ErrorText])
			SELECT 
				NEWID() ID,
				@AttachmentID [AttachmentID],
				Details.ColumnIndex [ColumnIndex],
				Details.RowIndex [RowIndex],
				Details.ErrorText [ErrorText]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetAttachmentErrorTemplate') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetAttachmentErrorTemplate
GO

CREATE PROCEDURE pbl.spGetAttachmentErrorTemplate
		@AID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID
		SELECT
			ID,
			ExcelType,
			Category,
			ColumnName,
			ErrorType,
			ErrorCode,
			ErrorText,
			ErrorSolution,
			[Enable]
		FROM pbl.AttachmentErrorTemplate
		WHERE (ID = @ID)
END


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetAttachmentErrorTemplates') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetAttachmentErrorTemplates
GO

CREATE PROCEDURE pbl.spGetAttachmentErrorTemplates
	@AExcelType TINYINT,
	@ACategory INT,
	@AErrorType TINYINT,
	@AErrorCode INT,
	@AEnableState TINYINT,
	@AIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ExcelType TINYINT = COALESCE(@AExcelType, 0),
		@Category INT = COALESCE(@ACategory, 0),
		@ErrorType TINYINT = COALESCE(@AErrorType, 0),
		@ErrorCode INT = COALESCE(@AErrorCode, 0),
		@EnableState TINYINT = COALESCE(@AEnableState, 0),
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = TRIM(@ASortExp)
		

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT
			AET.[ID],
			AET.[ExcelType],
			AET.[Category],
			AET.[ColumnName],
			AET.[ErrorType],
			AET.[ErrorCode],
			AET.[ErrorText],
			AET.[ErrorSolution],
			AET.[Enable]
		FROM [pbl].[AttachmentErrorTemplate] AET
		LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = AET.ID
		WHERE (@ExcelType < 1 OR AET.[ExcelType] = @ExcelType)
			AND (@Category < 1 OR AET.[Category] = @Category)
			AND (@ErrorType < 1 OR AET.[ErrorType] = @ErrorType)
			AND (@ErrorCode < 1 OR AET.[ErrorCode] = @ErrorCode)
			AND (@EnableState < 1 OR (AET.[Enable] + 1) = @EnableState)
			AND (@IDs IS NULL OR IDs.value = ID)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY [ErrorCode] DESC		
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeleteBank'))
	DROP PROCEDURE pbl.spDeleteBank
GO

CREATE PROCEDURE pbl.spDeleteBank
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [pbl].[Bank]
			SET 
				RemoverUserID = @RemoverUserID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetBank'))
	DROP PROCEDURE pbl.spGetBank
GO

CREATE PROCEDURE pbl.spGetBank
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		bank.[ID],
		bank.[Name],
		bank.[Code],
		bank.[Type]
	FROM [pbl].[Bank] bank
	WHERE bank.[ID] = @ID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetBanks'))
DROP PROCEDURE pbl.spGetBanks
GO

CREATE PROCEDURE pbl.spGetBanks
	@AName NVARCHAR(255),
	@ACode VARCHAR(10),
	@ACodes NVARCHAR(MAX),
	@AType TINYINT,

	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@Name NVARCHAR(255) = LTRIM(RTRIM(@AName)),
		@Code VARCHAR(10) = @ACode,
		@Codes NVARCHAR(MAX) = LTRIM(RTRIM(@ACodes)),
		@Type TINYINT = COALESCE(@AType, 0),

		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			bank.[ID],
			bank.[Name],
			bank.[Code],
			bank.[Type]
		FROM [pbl].[Bank] bank
			LEFT JOIN OPENJSON(@Codes) Codes ON Codes.value = bank.[Code]
		WHERE (@Name IS NULL OR bank.[Name] = @Name)
			AND (@Code IS NULL OR bank.[Code] = @Code)
			AND (@Codes IS NULL OR Codes.value IS NOT NULL)
			AND (@Type < 1 OR bank.[Type] = @Type)
			AND (bank.[RemoverUserID] IS NULL)
			AND (bank.[RemoveDate] IS NULL)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyBank'))
	DROP PROCEDURE pbl.spModifyBank
GO

CREATE PROCEDURE pbl.spModifyBank
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR (255),
	@ACode VARCHAR(10),
	@AType TINYINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(255) = LTRIM(RTRIM(@AName)),
		@Code VARCHAR(10) = @ACode,
		@Type TINYINT = COALESCE(@AType, 0)


	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO pbl.Bank
				([ID], [Name], [Code], [Type], [RemoverUserID], [RemoveDate])
				VALUES
				(@ID, @Name, @Code, @Type, NULL, NUll)

			END
			ELSE
			BEGIN
				
				UPDATE [pbl].[Bank]
				SET 
				 [Name] = @Name, 
				 [Code] = @Code, 
				 [Type] = @Type
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetBankAccount') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetBankAccount
GO

CREATE PROCEDURE pbl.spGetBankAccount
		@AID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

		SELECT
			ba.[ID],
			ba.[NationalCode],
			ba.[Sheba],
			ba.[IndividualID],
			indi.FirstName,
			indi.LastName,
			ba.[BankID],
			bank.[Name] BankName,
			ba.[CreationDate],
			ba.[LastProcessingDate]
		FROM pbl.BankAccount ba
			LEFT JOIN [Kama.Aro.Organization].org.Individual indi ON indi.ID = ba.IndividualID
			LEFT JOIN [pbl].[Bank] bank ON bank.ID = ba.[BankID]
		WHERE (ba.ID = @ID)
END


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetBankAccounts') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetBankAccounts
GO

CREATE PROCEDURE pbl.spGetBankAccounts
	@ANationalCode NVARCHAR(10),
	@AFirstName NVARCHAR(255),
	@ALastName NVARCHAR(255),
	@ASheba CHAR(26),
	@AIDs NVARCHAR(MAX),
	@ANationalCodes NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@NationalCode NVARCHAR(10) = TRIM(@ANationalCode),
		@FirstName NVARCHAR(255) = TRIM(@AFirstName),
		@LastName NVARCHAR(255) = TRIM(@ALastName),
		@Sheba CHAR(26) = TRIM(@ASheba),
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@NationalCodes NVARCHAR(MAX) = TRIM(@ANationalCodes),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = TRIM(@ASortExp)
		

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT
			ba.[ID],
			ba.[NationalCode],
			ba.[Sheba],
			ba.[IndividualID],
			indi.FirstName,
			indi.LastName,
			ba.[BankID],
			bank.[Name] BankName,
			ba.[CreationDate],
			ba.[LastProcessingDate]
		FROM pbl.BankAccount ba
			LEFT JOIN [Kama.Aro.Organization].org.Individual indi ON indi.ID = ba.IndividualID
			LEFT JOIN [pbl].[Bank] bank ON bank.ID = ba.[BankID]
			LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = ba.ID
			LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = ba.NationalCode
		WHERE (@NationalCode IS NULL OR ba.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR indi.FirstName LIKE '%' + @FirstName + '%')
			AND (@LastName IS NULL OR indi.LastName LIKE '%' + @LastName + '%')
			AND (@Sheba IS NULL OR ba.Sheba LIKE '%' + @Sheba + '%')
			AND (@IDs IS NULL OR IDs.value = ba.ID)
			AND (@NationalCodes IS NULL OR NationalCodes.value = ba.NationalCode)

	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY LastProcessingDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spModifyBankAccount') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spModifyBankAccount
GO

CREATE PROCEDURE pbl.spModifyBankAccount 
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@ASheba CHAR(26),
	@AIndividualID UNIQUEIDENTIFIER,
	@ABankID UNIQUEIDENTIFIER,
	@ACreationDate DATETIME,
	@ALastProcessingDate DATETIME

	
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@NationalCode NVARCHAR(10) = TRIM(@ANationalCode),
		@Sheba CHAR(26) = TRIM(@ASheba),
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@BankID UNIQUEIDENTIFIER = @ABankID,
		@CreationDate DATETIME = COALESCE(@ACreationDate,GETDATE()),
		@LastProcessingDate DATETIME = COALESCE(@ALastProcessingDate,GETDATE()),
		@Result INT = 0


	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [pbl].[BankAccount]
				([ID], [NationalCode], [Sheba], [IndividualID], [BankID], [CreationDate], [LastProcessingDate])
				VALUES
				(@ID, @NationalCode, @Sheba, @IndividualID, @BankID, @CreationDate, @LastProcessingDate)
			END
			ELSE
			BEGIN
				UPDATE [pbl].[BankAccount]
				SET
					IndividualID = @IndividualID,
					BankID = @BankID,
					LastProcessingDate = @LastProcessingDate
				WHERE ID = @ID
			END		

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spCreateBankAccountErrors') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spCreateBankAccountErrors
GO

CREATE PROCEDURE pbl.spCreateBankAccountErrors
	@ABankAccountErrors NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@BankAccountErrors NVARCHAR(MAX) = @ABankAccountErrors 

	BEGIN TRY
		BEGIN TRAN
			
			DELETE BankAccountError
			FROM pbl.BankAccountError
				INNER JOIN OPENJSON(@BankAccountErrors) 
			WITH
			(
				BankAccountID UNIQUEIDENTIFIER
			) BankAccountErrors ON BankAccountErrors.BankAccountID = BankAccountError.BankAccountID

			INSERT INTO pbl.BankAccountError
			SELECT 
				NEWID() ID,
				BankAccountID,
				ErrorType,
				ErrorText
			FROM OPENJSON(@BankAccountErrors) 
			WITH
			(
				BankAccountID UNIQUEIDENTIFIER,
				ErrorType SMALLINT,
				ErrorText NVARCHAR(MAX)
			) BankAccountErrors

			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetBankAccountErrors'))
DROP PROCEDURE pbl.spGetBankAccountErrors
GO

CREATE PROCEDURE pbl.spGetBankAccountErrors
	@ABankAccountIDs NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@BankAccountIDs NVARCHAR(MAX) = @ABankAccountIDs

	SELECT *
	FROM pbl.BankAccountError
	INNER JOIN OPENJSON(@BankAccountIDs) BankAccountIDs ON BankAccountIDs.value = BankAccountError.BankAccountID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetBankAccountSummary') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetBankAccountSummary
GO

CREATE PROCEDURE pbl.spGetBankAccountSummary
		@AID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID
		SELECT
			BAS.ID,
			BAS.NationalCode,
			BAS.Sheba,
			BAS.ValidType,
			BAS.IndividualID,
			indi.FirstName,
			indi.LastName,
			BAS.BankID,
			Bank.[Name] BankName,
			BAS.CreationDate,
			BAS.LastProcessingDate
		FROM pbl.BankAccountSummary BAS
		LEFT JOIN pbl.Bank ON Bank.ID = BAS.BankID
		LEFT JOIN [Kama.Aro.Organization].org.Individual indi on indi.ID = BAS.IndividualID
		WHERE (BAS.ID = @ID)
END


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetBankAccountSummarys') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetBankAccountSummarys
GO

CREATE PROCEDURE pbl.spGetBankAccountSummarys
	@ANationalCode NVARCHAR(10),
	@AFirstName NVARCHAR(255),
	@ALastName NVARCHAR(255),
	@ASheba CHAR(26),
	@AValidType TINYINT,
	@AIDs NVARCHAR(MAX),
	@ANationalCodes NVARCHAR(MAX),
	@AShebas NVARCHAR(MAX),
	@AValidTypes NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@NationalCode NVARCHAR(10) = TRIM(@ANationalCode),
		@FirstName NVARCHAR(255) = TRIM(@AFirstName),
		@LastName NVARCHAR(255) = TRIM(@ALastName),
		@Sheba CHAR(26) = TRIM(@ASheba),
		@ValidType TINYINT = COALESCE(@AValidType, 0),
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@NationalCodes NVARCHAR(MAX) = TRIM(@ANationalCodes),
		@Shebas NVARCHAR(MAX) = TRIM(@AShebas),
		@ValidTypes NVARCHAR(MAX) = @AValidTypes,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = TRIM(@ASortExp)
		

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT
			BAS.ID,
			BAS.NationalCode,
			BAS.Sheba,
			BAS.ValidType,
			BAS.IndividualID,
			indi.FirstName,
			indi.LastName,
			BAS.BankID,
			Bank.[Name],
			BAS.CreationDate,
			BAS.LastProcessingDate
		FROM pbl.BankAccountSummary BAS
		LEFT JOIN pbl.Bank ON Bank.ID = BAS.BankID
		LEFT JOIN [Kama.Aro.Organization].org.Individual indi on indi.ID = BAS.IndividualID
		LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = BAS.ID
		LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = BAS.NationalCode
		LEFT JOIN OPENJSON(@Shebas) Shebas ON Shebas.value = BAS.Sheba
		--LEFT JOIN OPENJSON(@ValidTypes) ValidTypes ON ValidTypes.value = BAS.ValidType
		WHERE (@NationalCode IS NULL OR BAS.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR indi.FirstName LIKE '%' + @FirstName + '%')
			AND (@LastName IS NULL OR indi.LastName LIKE '%' + @LastName + '%')
			AND (@Sheba IS NULL OR BAS.Sheba LIKE '%' + @Sheba + '%')
			AND (@ValidType < 1 OR BAS.ValidType = @ValidType)
			AND (@IDs IS NULL OR IDs.value = BAS.ID)
			AND (@NationalCodes IS NULL OR NationalCodes.value = BAS.NationalCode)
			AND (@Shebas IS NULL OR Shebas.value = BAS.Sheba)
			--AND (@ValidTypes IS NULL OR ValidTypes.value = BAS.ValidType)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY LastProcessingDate DESC		
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spModifyBankAccountSummary') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spModifyBankAccountSummary
GO

CREATE PROCEDURE pbl.spModifyBankAccountSummary  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@ASheba CHAR(26),
	@AValidType TINYINT,
	@AIndividualID UNIQUEIDENTIFIER,
	@ABankID UNIQUEIDENTIFIER,
	@ACreationDate DATETIME,
	@ALastProcessingDate DATETIME
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@NationalCode NVARCHAR(10) = TRIM(@ANationalCode),
		@Sheba CHAR(26) = TRIM(@ASheba),
		@ValidType TINYINT = COALESCE(@AValidType, 0),
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@BankID UNIQUEIDENTIFIER = @ABankID,
		@CreationDate DATETIME = @ACreationDate,
		@LastProcessingDate DATETIME = @ALastProcessingDate,
		@Result INT = 0
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO pbl.BankAccountSummary
				(ID, NationalCode, Sheba, ValidType, IndividualID, BankID, CreationDate, LastProcessingDate)
				VALUES
				(@ID, @NationalCode, @Sheba, @ValidType, @IndividualID, @BankID, @CreationDate, @LastProcessingDate)
			END
			ELSE
			BEGIN
				UPDATE pbl.BankAccountSummary
				SET
					ValidType = @ValidType,
					IndividualID = @IndividualID,
					BankID = @BankID,
					LastProcessingDate = @LastProcessingDate
				WHERE ID = @ID
			END		
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetBankAccountSummaryProcessingHistory') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetBankAccountSummaryProcessingHistory
GO

CREATE PROCEDURE pbl.spGetBankAccountSummaryProcessingHistory
		@AID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

		SELECT
			ID,
			BankAccountSummaryID,
			ProcessingDate,
			ResultCode,
			ResultData,
			ErrorType,
			ErrorText
		FROM [pbl].[BankAccountSummaryProcessingHistory]
		WHERE (ID = @ID)
END


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetBankAccountSummaryProcessingHistorys') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetBankAccountSummaryProcessingHistorys
GO

CREATE PROCEDURE pbl.spGetBankAccountSummaryProcessingHistorys
	@ABankAccountSummaryID UNIQUEIDENTIFIER,
	@AIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@BankAccountSummaryID UNIQUEIDENTIFIER = @ABankAccountSummaryID,
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = TRIM(@ASortExp)
		

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT
			ID,
			BankAccountSummaryID,
			ProcessingDate,
			ResultCode,
			ResultData,
			ErrorType,
			ErrorText
		FROM pbl.BankAccountSummaryProcessingHistory BASPH
		LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = BASPH.ID
		WHERE (@BankAccountSummaryID IS NULL OR BASPH.BankAccountSummaryID = @BankAccountSummaryID)
			AND (@IDs IS NULL OR IDs.value = BASPH.ID)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY ProcessingDate DESC	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spInsertBankAccountSummaryProcessingHistory') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spInsertBankAccountSummaryProcessingHistory
GO

CREATE PROCEDURE pbl.spInsertBankAccountSummaryProcessingHistory
	@AID UNIQUEIDENTIFIER,
	@ABankAccountSummaryID UNIQUEIDENTIFIER,
	@AResultCode INT,
	@AResultData NVARCHAR(MAX),
	@AErrorType SMALLINT,
	@AErrorText NVARCHAR(MAX),
	@AProcessingDate DATETIME
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@BankAccountSummaryID UNIQUEIDENTIFIER = @ABankAccountSummaryID,
		@ResultCode INT = COALESCE(@AResultCode, 0),
		@ResultData NVARCHAR(MAX) = TRIM(@AResultData),
		@ErrorType SMALLINT = COALESCE(@AErrorType, 0),
		@ErrorText NVARCHAR(MAX) = TRIM(@AErrorText),
		@ProcessingDate DATETIME = @AProcessingDate,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			INSERT INTO [pbl].[BankAccountSummaryProcessingHistory]
			([ID], [BankAccountSummaryID], [ProcessingDate], [ResultCode], [ResultData], [ErrorType], [ErrorText])
			VALUES
			(@ID, @BankAccountSummaryID, @ProcessingDate, @ResultCode, @ResultData, @ErrorType, @ErrorText)
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeleteBaseDocument'))
	DROP PROCEDURE pbl.spDeleteBaseDocument
GO

CREATE PROCEDURE pbl.spDeleteBaseDocument
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbl.BaseDocument
			SET 
				RemoverUserID = @RemoverUserID,
				[RemoverPositionID] = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetDocumentStatistics'))
	DROP PROCEDURE pbl.spGetDocumentStatistics
GO

CREATE PROCEDURE pbl.spGetDocumentStatistics
	@AUserPositionID UNIQUEIDENTIFIER,
	@ADocumentType TINYINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @UserPositionID UNIQUEIDENTIFIER = @AUserPositionID,
			@DocumentType TINYINT = COALESCE(@ADocumentType, 0)

	;WITH AggregatedFlow AS
	(
		SELECT doc.Type DocumentType,
			1 InAction,
			CASE WHEN lastFlow.ReadDate IS NULL THEN 1 ELSE 0 END UnRead
		FROM pbl.BaseDocument doc 
			LEFT JOIN pbl.DocumentFlow lastFlow ON lastFlow.DocumentID = doc.ID
		WHERE doc.RemoveDate IS NULL
			AND lastFlow.ActionDate IS NULL
			AND lastFlow.ToPositionID = @UserPositionID
	)
	, SummerizedFlow AS
	(
		SELECT DocumentType,
			SUM(AggregatedFlow.InAction) InActionCount,
			SUM(AggregatedFlow.UnRead) UnReadCount
		FROM AggregatedFlow 
		GROUP BY DocumentType
	)
	SELECT * 
	INTO #Temp
	FROM SummerizedFlow

	;WITH DistinctDocumentType
	AS 
	(
		SELECT DISTINCT TOP 100 PERCENT [Type] DocumentType 
		FROM pbl.BaseDocument baseDocument
		WHERE (@DocumentType < 1 OR [Type] = @DocumentType)
		ORDER BY [Type]
	) 
	SELECT DocumentType,
		COALESCE((SELECT InActionCount FROM #Temp WHERE DocumentType = DistinctDocumentType.DocumentType), 0) InActionCount,
		COALESCE((SELECT UnReadCount FROM #Temp WHERE DocumentType = DistinctDocumentType.DocumentType), 0) UnReadCount
	FROM DistinctDocumentType 
	order by DocumentType

	DROP TABLE #Temp

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyBaseDocument_'))
	DROP PROCEDURE pbl.spModifyBaseDocument_
GO

CREATE PROCEDURE pbl.spModifyBaseDocument_
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ACreatorPositionID UNIQUEIDENTIFIER,
	@ATrackingCode NVARCHAR(50),
	@ADocumentNumber NVARCHAR(50),
	@AProcessID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0)
		, @ID UNIQUEIDENTIFIER = @AID
		, @Type TINYINT = COALESCE(@AType, 0)
		, @CreatorPositionID UNIQUEIDENTIFIER = @ACreatorPositionID
		, @TrackingCode NVARCHAR(50) = LTRIM(RTRIM(@ATrackingCode))
		, @DocumentNumber NVARCHAR(50) = LTRIM(RTRIM(@ADocumentNumber))
		, @ProcessID UNIQUEIDENTIFIER  = @AProcessID
		, @CreatorUserID UNIQUEIDENTIFIER
		, @Result INT 

	IF @Type < 1 
		THROW 5000, N'نوع فرآیند مشخص نشده است', 1
	
	IF @CreatorPositionID IS NULL
		THROW 5000, N'کاربر مشخص نشده است', 1

	SET @CreatorUserID = (SELECT UserID FROM org.Position WHERE ID = @CreatorPositionID)

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO pbl.BaseDocument
				([ID], [Type], [TrackingCode], [DocumentNumber], [ProcessID], [RemoverUserID], [RemoverPositionID], [RemoveDate])
				VALUES
				(@ID, @Type, @TrackingCode, @DocumentNumber, @ProcessID, NULL, NULL, NULL)

				EXEC pbl.spAddFlow @ADocumentID = @ID, @AFromUserID = @CreatorUserID, @AFromPositionID = @CreatorPositionID, @AToPositionID = @CreatorPositionID, @AFromDocState = 1, @AToDocState = 1, @ASendType = 3, @AComment = NULL

			 END
			 --ELSE -- update
			 --BEGIN
			    
				--UPDATE pbl.BaseDocument
				--SET DocumentNumber = @DocumentNumber, TrackingCode = @TrackingCode
				--WHERE ID = @ID

			 --END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
		
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeleteDepartment'))
	DROP PROCEDURE pbl.spDeleteDepartment
GO

CREATE PROCEDURE pbl.spDeleteDepartment
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID
	
	BEGIN TRY
		BEGIN TRAN
			DELETE pbldep FROM pbl.Department pbldep
			INNER JOIN org.Department orgdep ON orgdep.ID = pbldep.ID
			WHERE pbldep.ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetDepartment'))
DROP PROCEDURE pbl.spGetDepartment
GO

CREATE PROCEDURE pbl.spGetDepartment
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		orgdep.ID,
		orgdep.[Node].ToString() Node,
		orgdep.[Node].GetAncestor(1).ToString() ParentNode,
		orgdep.[Node].GetLevel() NodeLevel,
		orgdep.[Type],
		orgdep.SubType,
		orgdep.OrganType,
		orgdep.Code,
		orgdep.[Name],
		parent.[Name] ParentName,
		orgdep.[Enabled],
		orgdep.ProvinceID,
		orgdep.BudgetCode,
		province.[Name] ProvinceName,
		orgdep.[Address],
		orgdep.PostalCode,
		Parent.ID ParentID,
		CAST(COALESCE(pbldep.[Enable], 1) AS BIT) [Enable],
		orgdep.COFOG
	FROM [Kama.Aro.Organization].org.Department orgdep
		LEFT JOIN pbl.Department pbldep ON orgdep.ID = pbldep.ID
		LEFT JOIN org.Place province ON province.ID = orgdep.ProvinceID
		LEFT JOIN [Kama.Aro.Organization].org.Department parent ON orgdep.Node.GetAncestor(1) = parent.Node
	WHERE orgdep.ID = @ID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO
CREATE OR ALTER PROCEDURE pbl.spGetDepartmentAllChilds
	@AOrganID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 

		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ParentNode HIERARCHYID 
	
	IF @OrganID = CAST(0x0 AS UNIQUEIDENTIFIER) SET @OrganID = NULL
		
	SET @ParentNode = (SELECT [Node] FROM org.Department WHERE ID = @OrganID)

	;With SelectedDepartment AS
	(
		SELECT 
			organ.ID,
			organ.[Type],
			organ.SubType,
			organ.OrganType,
			organ.[Node].ToString() as [Node],
			organ.[Node].GetAncestor(1).ToString() as ParentNode,
			organ.Code,
			organ.[Name],
			organ.BudgetCode
		FROM org._department organ 
			LEFT JOIN org.Department Parent  ON organ.[Node].GetLevel()+1= Parent.Node.GetLevel()
		WHERE (organ.[Node].IsDescendantOf(@ParentNode) = 1)
	)
	SELECT DISTINCT *
	FROM SelectedDepartment
	 UNION 
	SELECT 
			organ.ID,
			organ.[Type],
			organ.SubType,
			organ.OrganType,
			organ.[Node].ToString() as [Node],
			organ.[Node].GetAncestor(1).ToString() as ParentNode,
			organ.Code,
			organ.[Name],
			organ.BudgetCode
		FROM org._Department organ 
		WHERE @OrganID=organ.ID
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetDepartments'))
DROP PROCEDURE pbl.spGetDepartments
GO


CREATE PROCEDURE pbl.spGetDepartments

	@AParentIDs NVARCHAR(MAX),

	@AOrganID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@AProvinceID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ASubType TINYINT,
	@AOrganType TINYINT,
	@ACode VARCHAR(20),
	@ABudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@ASearchWithHierarchy bit,
	@ACOFOG TINYINT,
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 

		@ParentIDs NVARCHAR(MAX) = @AParentIDs,

		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@Type TINYINT = ISNULL(@AType, 0),
		@SubType TINYINT = ISNULL(@ASubType, 0),
		@OrganType TINYINT = ISNULL(@AOrganType, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)), 
		@SearchWithHierarchy bit = COALESCE(@ASearchWithHierarchy, 0),
		@COFOG TINYINT = COALESCE(@ACOFOG, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID 
	
	IF @ParentID = CAST(0x0 AS UNIQUEIDENTIFIER) SET @ParentID = NULL
		
	SET @ParentNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;With SelectedDepartment AS
	(
		SELECT 
			organ.ID,
			organ.[Type],
			organ.[Node].ToString() [Node],
			organ.[Node].GetAncestor(1).ToString() [ParentNode],
			organ.[Node].GetLevel() NodeLevel,
			organ.SubType,
			organ.OrganType,
			organ.Code,
			organ.[Name],
			organ.[Enabled],
			organ.ProvinceID,
			province.[Name] ProvinceName,
			organ.BudgetCode,
			organ.[Address],
			organ.PostalCode
			--CAST(COALESCE(pbldep.[Enable], 1) AS BIT) [Enable]
			--organ.COFOG
		FROM [Kama.Aro.Organization].org.Department organ 
			LEFT JOIN org.Place province ON province.ID = organ.ProvinceID

			INNER JOIN [Kama.Aro.Organization].org.Department Parent ON organ.node.IsDescendantOf(Parent.Node) = 1
			LEFT JOIN OPENJSON(@ParentIDs) OrganIDs ON OrganIDs.value = Parent.ID

		WHERE organ.RemoverID IS NULL
			AND (@ParentIDs is null or OrganIDs.value = Parent.ID)
			AND (@OrganID IS NULL OR organ.ID = @OrganID)
			AND (@ParentNode IS NULL OR organ.[Node].IsDescendantOf(@ParentNode) = 1)
			AND (@ProvinceID IS NULL OR organ.ProvinceID = @ProvinceID)
			AND (@Type < 1 OR organ.[Type] = @Type)
			AND (@BudgetCode IS NULL OR organ.BudgetCode = @BudgetCode)
			AND (@SubType < 1 OR organ.SubType = @SubType)
			AND (@Code IS NULL OR organ.Code Like CONCAT('%', @Code, '%'))
			AND (@Name IS NULL OR organ.[Name] Like CONCAT('%', @Name , '%'))
			--AND (@COFOG < 1 OR organ.COFOG = @COFOG)
	)
	SELECT DISTINCT *
	FROM SelectedDepartment
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetProtectedDepartments'))
DROP PROCEDURE pbl.spGetProtectedDepartments
GO


CREATE PROCEDURE pbl.spGetProtectedDepartments

	@AParentIDs NVARCHAR(MAX),

	@AOrganID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@AProvinceID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ASubType TINYINT,
	@AOrganType TINYINT,
	@ACode VARCHAR(20),
	@ABudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@ASearchWithHierarchy bit,
	@ACOFOG TINYINT,
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 

		@ParentIDs NVARCHAR(MAX) = @AParentIDs,

		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@Type TINYINT = ISNULL(@AType, 0),
		@SubType TINYINT = ISNULL(@ASubType, 0),
		@OrganType TINYINT = ISNULL(@AOrganType, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)), 
		@SearchWithHierarchy bit = COALESCE(@ASearchWithHierarchy, 0),
		@COFOG TINYINT = COALESCE(@ACOFOG, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID 
	
	IF @ParentID = CAST(0x0 AS UNIQUEIDENTIFIER) SET @ParentID = NULL
		
	SET @ParentNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH SelectedDepartment AS
	(
		SELECT 
			organ.ID,
			organ.[Type],
			organ.Code,
			organ.[Name]
		FROM org._Department organ
			--INNER JOIN pbl.PayrollDepartment ON PayrollDepartment.DepartmentID = organ.ID
			--INNER JOIN org.Department Parent ON organ.node.IsDescendantOf(Parent.Node) = 1
			LEFT JOIN OPENJSON(@ParentIDs) ParentOrganIDs ON ParentOrganIDs.value = organ.ParentID
		WHERE --PayrollDepartment.PayrollNeeded = 1 AND
			 (@ParentIDs is null or ParentOrganIDs.value = organ.ParentID)
			--AND organ.RemoverID IS NULL
			AND (@ParentNode IS NULL OR organ.[Node].IsDescendantOf(@ParentNode) = 1)
			AND (@ProvinceID IS NULL OR organ.ProvinceID = @ProvinceID)
			AND (@Type < 1 OR organ.[Type] = @Type)
			AND (@BudgetCode IS NULL OR organ.BudgetCode = @BudgetCode)
			AND (@SubType < 1 OR organ.SubType = @SubType)
			AND (@Code IS NULL OR organ.Code Like CONCAT('%', @Code, '%'))
			AND (@Name IS NULL OR organ.[Name] Like CONCAT('%', @Name , '%'))
			AND organ.[Name] NOT LIKE N'%تست%'
			AND organ.[Name] NOT LIKE N'%حذف%'
			AND organ.[Name] <> N'سایر'
			AND organ.ID <> 0x
			AND organ.[Type] <> 10
	)
	, MainSelect AS
	(
		SELECT 
			department.ID,
			department.[Type],
			department.Code,
			department.[Name]
		FROM SelectedDepartment department
		WHERE 1 = 1 -- (@Level IS NULL OR department.[Node].GetLevel() = @Level)
	)
	SELECT DISTINCT *
	FROM MainSelect
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyDepartment'))
	DROP PROCEDURE pbl.spModifyDepartment
GO

CREATE PROCEDURE pbl.spModifyDepartment
	@AID UNIQUEIDENTIFIER,
	@AEnable BIT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Enable BIT = COALESCE(@AEnable, 0)
		
	BEGIN TRY
		BEGIN TRAN
			
			BEGIN -- update
				IF  (SELECT TOP 1 ID FROM pbl.Department WHERE ID = @ID) IS NULL
					INSERT INTO pbl.Department (ID , [Enable])
					VALUES (@ID , 1)
				ELSE 
					UPDATE pbl.Department
					SET [Enable] = @Enable
					WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetDepartmentsSummary'))
DROP PROCEDURE pbl.spGetDepartmentsSummary
GO

CREATE PROCEDURE pbl.spGetDepartmentsSummary
	@AParentID UNIQUEIDENTIFIER,
	@AParentIDs NVARCHAR(MAX),
	@AProvinceID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ASubType TINYINT,
	@AOrganIDs NVARCHAR(MAX),
	@AOrganType TINYINT,
	@ACode VARCHAR(20),
	@ABudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@ACOFOG TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ParentIDs NVARCHAR(MAX) = @AParentIDs,
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@Type TINYINT = ISNULL(@AType, 0),
		@SubType TINYINT = ISNULL(@ASubType, 0),
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@OrganType TINYINT = ISNULL(@AOrganType, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)), 
		@COFOG TINYINT = COALESCE(@ACOFOG, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID 
	
	IF @ParentID = CAST(0x0 AS UNIQUEIDENTIFIER) SET @ParentID = NULL
		
	SET @ParentNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH SelectedDepartment AS
	(
		SELECT 
			organ.ID,
			organ.[Name],
			organ.[Code],
			organ.[Node].ToString() [Node],
			organ.[Node].GetAncestor(1).ToString() [ParentNode]
		FROM org.Department organ
			LEFT JOIN org.Department Parent ON Parent.Node = organ.[Node].GetAncestor(1)
			LEFT JOIN OPENJSON(@ParentIDs) ParentOrganIDs ON ParentOrganIDs.value = Parent.ID
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = organ.ID
		WHERE (@ParentIDs is null or ParentOrganIDs.value = Parent.ID)
			AND (@OrganIDs is null or OrganIDs.value = organ.ID)
			AND (@ParentNode IS NULL OR organ.[Node].IsDescendantOf(@ParentNode) = 1)
			AND (@ProvinceID IS NULL OR organ.ProvinceID = @ProvinceID)
			AND (@Type < 1 OR organ.[Type] = @Type)
			AND (@BudgetCode IS NULL OR organ.BudgetCode = @BudgetCode)
			AND (@SubType < 1 OR organ.SubType = @SubType)
			AND (@Code IS NULL OR organ.Code Like CONCAT('%', @Code, '%'))
			AND (@Name IS NULL OR organ.[Name] Like CONCAT('%', @Name , '%'))
			AND organ.[Name] NOT LIKE N'%تست%'
			AND organ.[Name] NOT LIKE N'%حذف%'
			AND organ.[Name] <> N'سایر'
			AND organ.[Type] in (1,2)
			AND organ.ID <> 0x
	)
	, MainSelect AS
	(
		SELECT 
			department.ID,
			department.[Name],
			department.[Code],
			department.[Node],
			department.[ParentNode]
		FROM SelectedDepartment department
		WHERE 1 = 1
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total 
		FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, Total
	ORDER BY [Node]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetDepartmentBudgets'))
DROP PROCEDURE pbl.spGetDepartmentBudgets
GO

CREATE PROCEDURE pbl.spGetDepartmentBudgets
	@AOrganID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @OrganID UNIQUEIDENTIFIER =@AOrganID,
	@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID;

	SELECT DepartmentID,
		PositionSubTypeID,
		BudgetCode,
		DepartmentBudget.ID
  FROM [Kama.Aro.Pardakht].[org].[DepartmentBudget]
  WHERE (@OrganID IS NULL OR @OrganID=DepartmentID)
  AND (@PositionSubTypeID IS NULL OR @PositionSubTypeID=[PositionSubTypeID])

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spAddFlow'))
	DROP PROCEDURE pbl.spAddFlow
GO

CREATE PROCEDURE pbl.spAddFlow
	@ADocumentID UNIQUEIDENTIFIER,
	@AFromUserID UNIQUEIDENTIFIER,
	@AFromPositionID UNIQUEIDENTIFIER,
	@AToPositionID UNIQUEIDENTIFIER,
	@AFromDocState SMALLINT,
	@AToDocState SMALLINT,
	@ASendType TINYINT,
	@AComment NVARCHAR(4000)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@DocumentID UNIQUEIDENTIFIER = @ADocumentID,
		@FromUserID UNIQUEIDENTIFIER = @AFromUserID,
		@FromPositionID UNIQUEIDENTIFIER = @AFromPositionID,
		@ToPositionID UNIQUEIDENTIFIER =  @AToPositionID,
		@FromDocState SMALLINT =  COALESCE(@AFromDocState, 0),
		@ToDocState SMALLINT =  COALESCE(@AToDocState, 0),
		@SendType TINYINT =  COALESCE(@ASendType, 0),
		@Comment NVARCHAR(4000) =  LTRIM(RTRIM(@AComment)),
		@ID UNIQUEIDENTIFIER,
		@Date DATETIME = GETDATE(),
		@TmpFromUserID UNIQUEIDENTIFIER,
		@LastFlowID UNIQUEIDENTIFIER,
		@DocumentType TINYINT

	IF @DocumentID IS NULL
		THROW 50000, N'رکورد ارسالی مشخص نشده است', 1

	IF @ToDocState < 1
		THROW 50000, N'وضعیت بعدی مشخص نشده است', 1

	IF @SendType < 1
		THROW 50000, N'وضعیت تایید مشخص نشده است', 1

	IF @Comment = '' SET @Comment = NULL

	SET @LastFlowID = (SELECT ID FROM pbl.DocumentFlow WHERE DocumentID = @DocumentID AND ActionDate IS NULL)
	SET @FromDocState = COALESCE(@FromDocState, (SELECT TOP 1 ToDocState FROM pbl.DocumentFlow WHERE DocumentID = @DocumentID ORDER BY DATE DESC))
	SET @FromUserID = COALESCE(@FromUserID, (SELECT UserID FROM org.position WHERE ID = @FromPositionID))
	SET @DocumentType  = (SELECT [Type] FROM pbl.BaseDocument WHERE ID = @DocumentID)

	BEGIN TRY
		BEGIN TRAN
			
			SET @ID  = NEWID()

			INSERT INTO pbl.DocumentFlow
			(ID, DocumentID, [Date], FromPositionID, FromUserID, FromDocState, ToPositionID, ToDocState, SendType, Comment, IsRead)
			VALUES
			(@ID, @DocumentID, @Date, @FromPositionID, @FromUserID, @FromDocState, @ToPositionID, @ToDocState, @SendType, @Comment, 0)

			-- set action date for last flow
			UPDATE pbl.DocumentFlow
			SET ActionDate = @Date
			WHERE ID = @LastFlowID 

		COMMIT

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spAddFlows'))
	DROP PROCEDURE pbl.spAddFlows
GO

CREATE PROCEDURE pbl.spAddFlows
	@AFlows NVARCHAR(MAX)   -- list of flows in json format
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@Flows NVARCHAR(MAX) = @AFlows
		, @ID UNIQUEIDENTIFIER
		, @Date SMALLDATETIME = GETDATE()

	BEGIN TRY
		BEGIN TRAN
			
			DECLARE @LastFLow Table(ID UNIQUEIDENTIFIER, DocumentID UNIQUEIDENTIFIER)

			SELECT *
			INTO #NewFlows
			FROM OPENJSON(@Flows)
			WITH(
				DocumentID UNIQUEIDENTIFIER,
				FromUserID UNIQUEIDENTIFIER,
				FromPositionID UNIQUEIDENTIFIER,
				FromDocState SMALLINT,
				ToPositionID UNIQUEIDENTIFIER,
				ToDocState SMALLINT,
				SendType TINYINT,
				Comment NVARCHAR(4000)
			)

			-- set action date for last flows
			UPDATE pbl.DocumentFlow
			SET ActionDate = GETDATE()
			WHERE ActionDate IS NULL 
				  AND DocumentID IN (SELECT DocumentID FROM #NewFlows)

			-- add new flow
			INSERT INTO pbl.DocumentFlow
			SELECT NEWID() ID
				, newFlow.DocumentID
				, @Date 
				, newFlow.FromPositionID
				, newFlow.FromUserID
				, newFlow.FromDocState
				, newFlow.ToPositionID
				, newFlow.ToDocState
				, newFlow.SendType
				, newFlow.Comment
				, NULL ReadDate
				, 0 IsRead
				, NULL ActionDate
			FROM #NewFlows newFlow

		COMMIT

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeleteLastFlow_'))
	DROP PROCEDURE pbl.spDeleteLastFlow_
GO

CREATE PROCEDURE pbl.spDeleteLastFlow_
	@ADocumentID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @DocumentID UNIQUEIDENTIFIER = @ADocumentID

	IF @DocumentID IS NULL
		RETURN -2  -- وضعیت تایید مشخص نشده است

	BEGIN TRY
		BEGIN TRAN
			
			-- delete Last flow
			delete pbl.DocumentFlow where DocumentID = @DocumentID AND ActionDate IS NULL
			UPDATE pbl.DocumentFlow SET ActionDate = NULL WHERE ID = (SELECT TOP 1 ID FROM pbl.DocumentFlow WHERE DocumentID = @DocumentID ORDER BY [Date] DESC)


		COMMIT

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetFlowPrerequisite'))
	DROP PROCEDURE pbl.spGetFlowPrerequisite
GO

CREATE PROCEDURE pbl.spGetFlowPrerequisite
	@ADocumentID UNIQUEIDENTIFIER,
	@AUserPositionID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@DocumentID UNIQUEIDENTIFIER = @ADocumentID,
		@UserPositionID UNIQUEIDENTIFIER = @AUserPositionID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DocumentType TINYINT,
		@OrganID UNIQUEIDENTIFIER,
		@OrganExpertPositionID UNIQUEIDENTIFIER,
		@OrganFinancialManagerPositionID UNIQUEIDENTIFIER,
		@ParentOrganFinancialManagerPositionID UNIQUEIDENTIFIER,
		@CurrentOrganIndependent BIT,
		@CurrentOrganSubsetIndependent BIT

	SET @DocumentType = (SELECT top 1 [Type] FROM pbl.BaseDocument WHERE ID = @DocumentID)
	
	IF @DocumentType = 1
		SET @OrganID = (SELECT top 1 OrganID FROM law.OrganLaw WHERE ID = @DocumentID)
	ELSE IF @DocumentType = 2
		SET @OrganID = (SELECT top 1 OrganID FROM wag.Payroll WHERE ID = @DocumentID)

	SET @OrganExpertPositionID = (SELECT TOP 1 ID FROM org.Position WHERE DepartmentID = @OrganID AND ApplicationID = @ApplicationID AND RemoverID IS NULL AND [Type] = 10)
	SET @OrganFinancialManagerPositionID = (SELECT TOP 1 ID FROM org.Position WHERE DepartmentID = @OrganID AND ApplicationID = @ApplicationID AND RemoverID IS NULL AND [Type] = 20)
	SET @CurrentOrganIndependent = (SELECT top 1 paydep.Independent FROM pbl.PayrollDepartment paydep
										INNER JOIN org.department dep ON dep.ID = paydep.DepartmentID
										INNER JOIN org.position pos ON pos.DepartmentID = dep.ID
									WHERE 
										pos.ID = @UserPositionID)
	SET @CurrentOrganSubsetIndependent = (SELECT top 1 paydep.SubsetIndependent FROM pbl.PayrollDepartment paydep
										INNER JOIN org.department dep ON dep.ID = paydep.DepartmentID
										INNER JOIN org.position pos ON pos.DepartmentID = dep.ID
									WHERE 
										pos.ID = @UserPositionID)

	declare @UserDepartmentID uniqueidentifier = (select top 1 DepartmentID from org.Position where ID = @UserPositionID)
	declare @IsIndependent bit = COALESCE((select top 1 Independent from pbl.PayrollDepartment where DepartmentID = @UserDepartmentID), 0)
	declare @UserParentDepartmentID uniqueidentifier = (
		select top 1 d.ID from org.Department as d
		where d.[Node] = (select [Node] from org.Department where ID = @UserDepartmentID).GetAncestor(1)
	)
	if (@IsIndependent = 0 and @UserParentDepartmentID is not null)
		SET @ParentOrganFinancialManagerPositionID = (select top 1 ID from org.Position where DepartmentID = @UserParentDepartmentID)

	SELECT doc.ID,
		CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) LastDocState,
		lastFlow.ToPositionID LastToPositionID,
		payroll.[Year],
		@OrganExpertPositionID OrganExpertPositionID,
		@OrganFinancialManagerPositionID OrganFinancialManagerPositionID,
		@ParentOrganFinancialManagerPositionID ParentOrganFinancialManagerPositionID,
		CAST(@CurrentOrganIndependent AS BIT) CurrentOrganIndependent,
		CAST(@CurrentOrganSubsetIndependent AS BIT) CurrentOrganSubsetIndependent,
		org.[Name] OrganName
	FROM pbl.BaseDocument doc
	LEFT JOIN wag.Payroll payroll ON payroll.ID = doc.ID 
	LEFT JOIN org.Department org ON org.ID = payroll.OrganID
	LEFT JOIN pbl.DocumentFlow lastFlow ON lastFlow.DocumentID = doc.ID AND lastFlow.ActionDate IS NULL
	where doc.ID = @DocumentID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetFlows'))
	DROP PROCEDURE pbl.spGetFlows
GO

CREATE PROCEDURE pbl.spGetFlows
	@ADocumentID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@DocumentID UNIQUEIDENTIFIER = @ADocumentID

	SELECT
		fromUser.FirstName FromUserFirstName,
		fromUser.LastName FromUserLastName,
		fromPosition.[Type] FromUserPositionType,
		FromDepartment.[Name] FromDepartmentName,
		toPosition.[Type] ToUserPositionType,
		ToUser.FirstName ToUserFirstName,
		ToUser.LastName ToUserLastName,
		ToDepartment.ID ToDepartmentID,
		ToDepartment.[Name] ToDepartmentName,
		flow.ReadDate,
		flow.ToPositionID,
		flow.ToDocState,
		flow.FromPositionID,
		flow.SendType,
		flow.[Date],
		flow.ActionDate,
		flow.IsRead,
		flow.Comment
	FROM pbl.DocumentFlow flow
	INNER JOIN pbl.BaseDocument document on document.ID = flow.DocumentID
	LEFT JOIN org.[User] fromUser ON fromUser.ID = flow.FromUserID
	LEFT JOIN [org].[Position] fromPosition ON fromPosition.ID = flow.FromPositionID
	LEFT JOIN [org].Department FromDepartment ON FromDepartment.ID = fromPosition.DepartmentID
	LEFT JOIN [org].[Position] toPosition ON toPosition.ID = flow.ToPositionID
	LEFT JOIN [org].Department ToDepartment ON ToDepartment.ID = ToPosition.DepartmentID
	LEFT JOIN [org].[User] ToUser ON toPosition.UserID = ToUser.ID
	WHERE flow.DocumentID = @DocumentID
	ORDER BY [Date] ASC

END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spRejectFlow'))
	DROP PROCEDURE pbl.spRejectFlow
GO

CREATE PROCEDURE pbl.spRejectFlow
	@ADocumentID UNIQUEIDENTIFIER,
	@AFromUserID UNIQUEIDENTIFIER,
	@AFromPositionID UNIQUEIDENTIFIER,
	@AComment NVARCHAR(4000)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@DocumentID UNIQUEIDENTIFIER = @ADocumentID,
		@FromPositionID UNIQUEIDENTIFIER = @AFromPositionID,
		@FromUserID UNIQUEIDENTIFIER = @AFromUserID,
		@Comment NVARCHAR(4000) =  LTRIM(RTRIM(@AComment)),
	    @ID UNIQUEIDENTIFIER,
		@LastFlowID UNIQUEIDENTIFIER,
		@LastFromPositionID UNIQUEIDENTIFIER,
		@LastToPositionID UNIQUEIDENTIFIER,
		@LastFromDocState TINYINT,
		@LastToDocState TINYINT,
		@SendType TINYINT = 3,   -- باگشت پرونده
		@Date SMALLDATETIME = GETDATE()

	SELECT TOP 1
	   @LastFlowID = ID,
	   @LastFromPositionID = FromPositionID,
	   @LastToPositionID = ToPositionID,
	   @LastFromDocState = FromDocState,
	   @LastToDocState = ToDocState
	FROM pbl.DocumentFlow
	WHERE DocumentID = @DocumentID
	ORDER BY [Date] DESC

	IF @FromPositionID <> @LastToPositionID
		RETURN -3  -- داکیونت در دست این شخص نیست

	BEGIN TRY
		BEGIN TRAN
			SET @ID  = NEWID()

			INSERT INTO pbl.DocumentFlow
			(ID, DocumentID, [Date], FromPositionID, FromUserID, FromDocState, ToPositionID, ToDocState, SendType, Comment)
			VALUES
			(@ID, @DocumentID, @Date, @FromPositionID, @FromUserID, @LastToDocState, @LastFromPositionID, @LastFromDocState, @SendType, @Comment)

			-- set action date for last flow
			UPDATE pbl.DocumentFlow
			SET ActionDate = GETDATE()
			WHERE ID = @LastFlowID

		COMMIT

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spSetFlowReadState'))
	DROP PROCEDURE pbl.spSetFlowReadState
GO

CREATE PROCEDURE pbl.spSetFlowReadState
	@ADocumentID UNIQUEIDENTIFIER,
	@AUserPositionID UNIQUEIDENTIFIER,
	@AIsRead BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@DocumentID UNIQUEIDENTIFIER = @ADocumentID,
		@UserPositionID UNIQUEIDENTIFIER = @AUserPositionID,
		@IsRead BIT = @AIsRead,
		@FlowID UNIQUEIDENTIFIER,
		@ToPositionID UNIQUEIDENTIFIER

	IF @DocumentID IS NULL
		RETURN -2  -- وضعیت تایید مشخص نشده است

	SET @FlowID = (SELECT ID FROM pbl.DocumentFlow WHERE DocumentID = @DocumentID AND ActionDate IS NULL)
	SET @ToPositionID = (SELECT ToPositionID FROM pbl.DocumentFlow WHERE ID = @FlowID)

	IF @ToPositionID <> @UserPositionID
		RETURN -3

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbl.DocumentFlow
			SET IsRead = @IsRead
			WHERE ID = @FlowID

			IF @IsRead = 1
			BEGIN
				UPDATE pbl.DocumentFlow
				SET ReadDate = GETDATE()
				WHERE ID = @FlowID 
					  AND ReadDate IS NULL
			END

		COMMIT

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID ('pbl.spUpdateLastFlowState'))
DROP PROCEDURE pbl.spUpdateLastFlowState
GO

CREATE PROCEDURE pbl.spUpdateLastFlowState 
	@ADocumentID UNIQUEIDENTIFIER,
	@ADocState TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@DocumentID UNIQUEIDENTIFIER = @ADocumentID,
		@DocState TINYINT = COALESCE(@ADocState, 0)

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbl.DocumentFlow 
			SET ToDocState = @DocState
			WHERE DocumentID = @DocumentID
				AND ActionDate IS NULL

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetDocumentStatus'))
	DROP PROCEDURE pbl.spGetDocumentStatus
GO

CREATE PROCEDURE pbl.spGetDocumentStatus
	@ADocumentID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@DocumentID UNIQUEIDENTIFIER = @ADocumentID

		SELECT
			[DocumentID],
			[StatusID]
		FROM [pbl].[DocumentStatus] WITH (SNAPSHOT)
		WHERE DocumentID = @DocumentID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyDocumentStatus'))
	DROP PROCEDURE pbl.spModifyDocumentStatus
GO

CREATE PROCEDURE pbl.spModifyDocumentStatus
	@ADocumentID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@DocumentID UNIQUEIDENTIFIER = @ADocumentID,
		@IsExist BIT

	BEGIN TRY
		BEGIN TRAN
			SET @IsExist = COALESCE(CAST((SELECT TOP 1 1 FROM [pbl].[DocumentStatus] WITH (SNAPSHOT) WHERE [DocumentID] = @DocumentID) AS BIT), 0)
			IF @IsExist = 0 -- insert
				BEGIN
					INSERT INTO [pbl].[DocumentStatus]
					([DocumentID], [StatusID])
					VALUES 
					(@DocumentID, NEWID())

				END
			ELSE
				BEGIN
					UPDATE [pbl].[DocumentStatus] WITH (SNAPSHOT)
					SET 
					 [StatusID] = NEWID()
					WHERE [DocumentID] = @DocumentID
				END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO
/****** Object:  StoredProcedure [dbo].[SpAPI_ErrorLogging]    Script Date: 7/10/2023 3:35:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER    Proc [alg].[SpAPI_ErrorLogging]
 @Message nvarchar(max)
,@RequestMethod varchar(200)
,@RequestUri varchar(200)
,@TimeUtc datetime
as
begin

INSERT INTO ErrorLog
           (
            [Message]
           ,[RequestMethod]
           ,[RequestUri]
           ,[TimeUtc])
     VALUES
           (
            @Message 
           ,@RequestMethod 
           ,@RequestUri 
           ,@TimeUtc)
end



GO
USE [Kama.Aro.Pardakht]
GO
/****** Object:  StoredProcedure [dbo].[SpAPI_Logging]    Script Date: 7/10/2023 3:35:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROC [alg].[SpAPI_Logging] 
     @Host NVARCHAR(100)
	,@Headers NVARCHAR(500)
	,@StatusCode VARCHAR(50)
	,@RequestBody NVARCHAR(max)
	,@RequestedMethod NVARCHAR(max)
	,@UserHostAddress NVARCHAR(100)
	,@Useragent NVARCHAR(100)
	,@AbsoluteUri NVARCHAR(100)
	,@RequestType NVARCHAR(100)
AS
BEGIN
	INSERT INTO API_Log (
		[Host]
		,[Headers]
		,[StatusCode]
		,[TimeUtc]
		,[RequestBody]
		,[RequestedMethod]
		,[UserHostAddress]
		,[Useragent]
		,[AbsoluteUri]
		,[RequestType]
		)
	VALUES (
		@Host
		,@Headers
		,@StatusCode
		,getdate()
		,@RequestBody
		,@RequestedMethod
		,@UserHostAddress
		,@Useragent
		,@AbsoluteUri
		,@RequestType
		)
END


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetPaymentDepartment') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spGetPaymentDepartment
GO

CREATE PROCEDURE pbl.spGetPaymentDepartment 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		[ID] DepartmentID,
		[Name] DepartmentName
	FROM [Kama.Aro.Organization].[org].[Department]
	WHERE ID = @ID
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetPaymentDepartments') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetPaymentDepartments
GO

CREATE PROCEDURE pbl.spGetPaymentDepartments
	@ADepartmentName NVARCHAR(500),
	@ASalaryBudgetCodeStatus TINYINT,
	@APositionEnableState TINYINT,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@DepartmentName NVARCHAR(500) = LTRIM(RTRIM(@ADepartmentName)),
		@SalaryBudgetCodeStatus TINYINT = COALESCE(@ASalaryBudgetCodeStatus, 0),
		@PositionEnableState TINYINT = COALESCE(@APositionEnableState, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PardakhtAppliactionID UNIQUEIDENTIFIER = 'ABDB7E65-B3FB-442A-801A-B7B319EFC18B'

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH CountPaymentOrgan AS (
		SELECT  [PaymentDepartmentID] ,
			COUNT(ID) ActiveSalaryBudgetCodeCount
		FROM [pbl].[SalaryBudgetCode]
		WHERE [Status] = 10
		GROUP BY [PaymentDepartmentID]
	)
	, PaymentOrgan AS (
		SELECT DISTINCT [PaymentDepartmentID]
		FROM [pbl].[SalaryBudgetCode]
		WHERE @SalaryBudgetCodeStatus < 1 OR [Status] = @SalaryBudgetCodeStatus
	)
	, PositionOrgan AS (
		SELECT
			[DepartmentID]
			, MAX(CASE WHEN [Enabled] = 1 THEN 1 ELSE 0 END) [Enabled]
		FROM [Kama.Aro.Organization].[org].[Position]
		WHERE [ApplicationID] = @PardakhtAppliactionID
		AND [UserID] IS NOT NULL AND ([Type] in (10, 20, 30))
		GROUP BY [DepartmentID]
	)
	, PositionOrganMax AS (
		SELECT
			[DepartmentID]
			, [Enabled]
		FROM PositionOrgan
		WHERE  @PositionEnableState < 1 OR [Enabled] = (@PositionEnableState - 1)
	)
	,  MainSelect AS(
		SELECT
			Department.[ID] DepartmentID,
			Department.[Name] DepartmentName,
			COALESCE(CountPaymentOrgan.ActiveSalaryBudgetCodeCount, 0) ActiveSalaryBudgetCodeCount,
			CAST((CASE WHEN PositionOrganMax.[Enabled] IS NULL THEN 2  WHEN PositionOrganMax.[Enabled] = 1 THEN 1 ELSE 0  END) AS TINYINT) PositionOrganEnabled
		FROM [Kama.Aro.Organization].[org].[Department] Department
		INNER JOIN PaymentOrgan ON PaymentOrgan.[PaymentDepartmentID] = Department.[ID]
		LEFT JOIN CountPaymentOrgan ON CountPaymentOrgan.[PaymentDepartmentID] = Department.[ID]
		LEFT JOIN PositionOrganMax ON PositionOrganMax.[DepartmentID] = Department.[ID]
		WHERE (@ADepartmentName IS NULL OR Department.[Name] LIKE '%' + @ADepartmentName + '%')
		AND  @PositionEnableState < 1 OR PositionOrganMax.[Enabled] IS NOT NULL
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY [ActiveSalaryBudgetCodeCount] , PositionOrganEnabled DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeletePayrollDepartment'))
	DROP PROCEDURE pbl.spDeletePayrollDepartment
GO

CREATE PROCEDURE pbl.spDeletePayrollDepartment
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Node HIERARCHYID 
	
	--SET @Node = (SELECT [Node] FROM pbl.PayrollDepartment WHERE ID = @ID)  
	--IF @Node = HIERARCHYID::GetRoot()
	--	THROW 50000, N'رکورد ریشه قابل حذف نیست', 1

	BEGIN TRY
		BEGIN TRAN
			DELETE FROM pbl.PayrollDepartment
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetPayrollDepartment'))
DROP PROCEDURE pbl.spGetPayrollDepartment
GO

CREATE PROCEDURE pbl.spGetPayrollDepartment
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		PayrollDepartment.ID,
		--PayrollDepartment.[Node].ToString() [Node],
		PayrollDepartment.Independent,
		PayrollDepartment.SubsetIndependent,
		PayrollDepartment.PayrollNeeded,
		PayrollDepartment.DepartmentID,
		--PayrollDepartment.[Node].GetAncestor(1).ToString() ParentNode,
		department.[Type],
		department.SubType,
		department.OrganType,
		department.Code,
		department.[Name],
		--parent.[Name] ParentName,
		department.[Enabled],
		department.ProvinceID,
		province.[Name] ProvinceName,
		department.[Address],
		department.PostalCode
		--parent.ID ParentID
	FROM org.Department as department 
		LEFT JOIN pbl.PayrollDepartment as payrollDepartment ON department.ID = payrollDepartment.DepartmentID
		LEFT JOIN org.Place as province ON province.ID = department.ProvinceID
		--LEFT JOIN pbl.PayrollDepartment as payrollDepartmentParent ON payrollDepartment.[Node].GetAncestor(1) = payrollDepartmentParent.[Node]
		--LEFT JOIN org.Department as parent ON payrollDepartmentParent.DepartmentID = parent.ID
	WHERE payrollDepartment.DepartmentID = @ID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetPayrollDepartmentByDepartment'))
DROP PROCEDURE pbl.spGetPayrollDepartmentByDepartment
GO

CREATE PROCEDURE pbl.spGetPayrollDepartmentByDepartment
	@ADepartmentID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @DepartmentID UNIQUEIDENTIFIER = @ADepartmentID
	
	SELECT 
		PayrollDepartment.ID,
		--PayrollDepartment.[Node].ToString() [Node],
		PayrollDepartment.Independent,
		PayrollDepartment.SubsetIndependent,
		PayrollDepartment.PayrollNeeded,
		PayrollDepartment.DepartmentID,
		--PayrollDepartment.[Node].GetAncestor(1).ToString() ParentNode,
		department.[Type],
		department.SubType,
		department.OrganType,
		department.Code,
		department.[Name],
		department.[Enabled],
		department.ProvinceID,
		--province.[Name] ProvinceName,
		department.[Address],
		department.PostalCode
		--,
		--parent.[Name] ParentName,
		--parent.ID ParentID
	FROM org.Department as department 
		LEFT JOIN pbl.PayrollDepartment as payrollDepartment ON department.ID = payrollDepartment.DepartmentID
		--LEFT JOIN org.Place as province ON province.ID = department.ProvinceID
		--LEFT JOIN pbl.PayrollDepartment as payrollDepartmentParent ON payrollDepartment.[Node].GetAncestor(1) = payrollDepartmentParent.[Node]
		--LEFT JOIN org.Department as parent ON payrollDepartmentParent.DepartmentID = parent.ID
	WHERE payrollDepartment.DepartmentID = @DepartmentID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'pbl.spGetPayrollDepartments'))
DROP PROCEDURE pbl.spGetPayrollDepartments
GO
CREATE PROCEDURE pbl.spGetPayrollDepartments
	@AName NVARCHAR(200),
	@AParentName NVARCHAR(200),
	@AProvinceName NVARCHAR(100),
	@ADepartmentID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@AProvinceID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@AIndependent BIT,
	@ASubsetIndependent BIT,
	@APayrollNeeded BIT,
	@ASubType TINYINT,
	@AOrganType TINYINT,
	@ACode VARCHAR(20),
	@ABudgetCode VARCHAR(20),
	@ASearchWithHierarchy bit,
	@ACOFOG TINYINT,
	@ALevel INT,
	@APageSize INT,
	@APageIndex INT

WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE 
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@ParentName NVARCHAR(200) = LTRIM(RTRIM(@AParentName)),
		@ProvinceName NVARCHAR(200) = LTRIM(RTRIM(@AProvinceName)),
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@Type TINYINT = ISNULL(@AType, 0),
		@Independent BIT = @AIndependent,
		@SubsetIndependent BIT = @ASubsetIndependent,
		@PayrollNeeded BIT = @APayrollNeeded,
		@SubType TINYINT = ISNULL(@ASubType, 0),
		@OrganType TINYINT = ISNULL(@AOrganType, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@SearchWithHierarchy bit = COALESCE(@ASearchWithHierarchy, 0),
		@COFOG TINYINT = COALESCE(@ACOFOG, 0),
		@Level INT = @ALevel,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID 


	IF @ParentID = 0x SET @ParentID = NULL
		
	SET @ParentNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;With Province AS
	(
	SELECT ID, [Name] FROM [Kama.Aro.Organization].[org].Place WHERE Type = 2
	)
	, SelectedDepartment AS
	(
		SELECT 
			orgdep.ID,
			orgdep.[Type],
			orgdep.SubType,
			orgdep.OrganType,
			orgdep.Code,
			orgdep.Node,
			orgdep.[Name],
			orgdep.[Enabled],
			orgdep.ProvinceID,
			orgdep.BudgetCode,
			orgdep.[Address],
			--CAST(COALESCE(pbldep.Independent, 1) AS BIT) Independnt,
			--CAST(COALESCE(pbldep.SubsetIndependent, 1) AS BIT) SubsetIndependent,
			--CAST(COALESCE(pbldep.PayrollNeeded, 1) AS BIT) PayrollNeeded,
			pbldep.Independent,
			pbldep.SubsetIndependent,
			pbldep.PayrollNeeded,
			orgdep.PostalCode,
			orgdep.COFOG
		FROM org.department orgdep 
			LEFT JOIN pbl.PayrollDepartment pbldep ON orgdep.ID = pbldep.DepartmentID
		WHERE orgdep.RemoverID IS NULL
			AND (@DepartmentID IS NULL OR orgdep.ID = @DepartmentID)
			AND (@ParentNode IS NULL OR orgdep.[Node].IsDescendantOf(@ParentNode) = 1)
			AND (@ProvinceID IS NULL OR orgdep.ProvinceID = @ProvinceID)
			AND (@Type < 1 OR orgdep.[Type] = @Type)
			AND (@Independent IS NULL OR pbldep.Independent = @Independent)
			AND (@SubsetIndependent IS NULL OR pbldep.SubsetIndependent = @SubsetIndependent)
			AND (@PayrollNeeded IS NULL OR pbldep.PayrollNeeded = @PayrollNeeded)
			AND (@BudgetCode IS NULL OR orgdep.BudgetCode = @BudgetCode)
			AND (@SubType < 1 OR orgdep.SubType = @SubType)
			AND (@Code IS NULL OR orgdep.Code Like CONCAT('%', @Code, '%'))
			AND (@Name IS NULL OR orgdep.[Name] Like CONCAT('%', @Name , '%'))
			AND (@COFOG < 1 OR orgdep.COFOG = @COFOG)
	)
	, ParentDepartment AS
	(
		SELECT DISTINCT * 
		FROM org.Department Parent
		WHERE @SearchWithHierarchy = 1 
			AND ID NOT IN (SELECT ID FROM SelectedDepartment) 
			AND EXISTS(SELECT TOP 1 1 FROM SelectedDepartment WHERE SelectedDepartment.Node.IsDescendantOf(Parent.Node) = 1)
	)
	, UnionDepartment AS
	(
		SELECT * FROM SelectedDepartment
	)
	SELECT 
		Count(*) OVER() Total,
		UnionDepartment.[Node].ToString() [Node],
		UnionDepartment.[Node].GetAncestor(1).ToString() [ParentNode],
		UnionDepartment.[Node].GetLevel() NodeLevel,
		UnionDepartment.ID,
		UnionDepartment.SubType,
		UnionDepartment.[Type],
		UnionDepartment.Code,
		UnionDepartment.[Name],
		UnionDepartment.COFOG,
		UnionDepartment.Independent,
		UnionDepartment.SubsetIndependent,
		UnionDepartment.PayrollNeeded,
		UnionDepartment.BudgetCode,
		UnionDepartment.[Enabled],
		UnionDepartment.ProvinceID,
		Parent.[Name] ParentName,
		Parent.ID ParentID,
		Province.[Name] ProvinceName,
		UnionDepartment.[Address],
		UnionDepartment.PostalCode 
	FROM UnionDepartment
		LEFT JOIN Province ON Province.ID = UnionDepartment.ProvinceID
		LEFT JOIN org.Department Parent ON Parent.Node = UnionDepartment.[Node].GetAncestor(1)
	WHERE (@Level IS NULL OR UnionDepartment.[Node].GetLevel() = @Level)
	ORDER BY  UnionDepartment.[Node].GetAncestor(1).ToString()
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spModifyPayrollDepartment') IS NOT NULL
    DROP PROCEDURE pbl.spModifyPayrollDepartment
GO

CREATE PROCEDURE pbl.spModifyPayrollDepartment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ANode HIERARCHYID,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Node HIERARCHYID = @ANode,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ParentNode HIERARCHYID,
		@LastChildNode HIERARCHYID,
		@NewNode HIERARCHYID

	IF @Node IS NULL 
		OR @ParentID <> COALESCE((SELECT TOP 1 ID FROM pbl.PayrollDepartment WHERE @Node.GetAncestor(1) = [Node]), 0x)
	BEGIN
		SET @ParentNode = COALESCE((SELECT [Node] FROM pbl.PayrollDepartment WHERE ID = @ParentID), HIERARCHYID::GetRoot())
		SET @LastChildNode = (SELECT MAX([Node]) FROM pbl.PayrollDepartment WHERE [Node].GetAncestor(1) = @ParentNode)
		SET @NewNode = @ParentNode.GetDescendant(@LastChildNode, NULL)
	END

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO pbl.PayrollDepartment
				(ID, [Node], DepartmentID)
				VALUES
				(@ID, @NewNode, @DepartmentID)
			END
			ELSE
			BEGIN -- update
				IF @Node <> @NewNode
				BEGIN
					Update pbl.PayrollDepartment
					SET [Node] = [Node].GetReparentedValue(@Node, @NewNode)
					WHERE [Node].IsDescendantOf(@Node) = 1
				END
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID ('pbl.spUpdatePayrollDepartment'))
DROP PROCEDURE pbl.spUpdatePayrollDepartment

GO

CREATE PROCEDURE pbl.spUpdatePayrollDepartment
	@AIndependent BIT,
	@ASubsetIndependent BIT,
	@APayrollNeeded BIT,
	@ADepartmentID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE
		@Independent BIT = ISNULL(@AIndependent, 0),
		@SubsetIndependent BIT = ISNULL(@ASubsetIndependent, 0),
		@PayrollNeeded BIT = ISNULL(@APayrollNeeded, 0),
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@PayrollDepartment UNIQUEIDENTIFIER

	SET @PayrollDepartment = (SELECT ID FROM pbl.PayrollDepartment WHERE DepartmentID = @DepartmentID)

	BEGIN TRY
		BEGIN TRAN
			
			BEGIN
				UPDATE pbl.PayrollDepartment
				SET Independent = @Independent , SubsetIndependent = @SubsetIndependent , PayrollNeeded = @PayrollNeeded
				WHERE ID = @PayrollDepartment
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeletePlanningAndBudgetSection'))
	DROP PROCEDURE pbl.spDeletePlanningAndBudgetSection
GO

CREATE PROCEDURE pbl.spDeletePlanningAndBudgetSection
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [pbl].[PlanningAndBudgetSection]
			SET 
				[RemoverUserID] = @RemoverUserID,
				[RemoverPositionID] = @RemoverPositionID,
				[RemoveDate] = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSection'))
	DROP PROCEDURE pbl.spGetPlanningAndBudgetSection
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSection
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		[ID],
		[Type],
		[Name],
		[Code],
		[CreatorUserID],
		[CreatorPositionID],
		[CreationDate],
		[RemoverUserID],
		[RemoverPositionID],
		[RemoveDate]
	FROM [pbl].[PlanningAndBudgetSection]
	WHERE [ID] = @ID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSections'))
DROP PROCEDURE pbl.spGetPlanningAndBudgetSections
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSections
	@AName NVARCHAR(100),
	@AType TINYINT,
	@ACode VARCHAR(10),
	@ASalaryBudgetCode VARCHAR(20),

	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
		@Code VARCHAR(10) = LTRIM(RTRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0),
		@SalaryBudgetCode VARCHAR(20) = LTRIM(RTRIM(@ASalaryBudgetCode)),

		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	; WITH BudgetCodes AS
	(
		SELECT DISTINCT PBS.[ID]
		FROM [pbl].[PlanningAndBudgetSection] PBS
		INNER JOIN [pbl].[PlanningAndBudgetSectionPositionAssignment] PBPA ON PBPA.[SectionID] = PBS.ID
		INNER JOIN [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment] PBBCA ON PBBCA.PositionSectionID = PBPA.ID
		WHERE @SalaryBudgetCode IS NULL OR PBBCA.[SalaryBudgetCode] = @SalaryBudgetCode
	)
	,MainSelect AS
	(
		SELECT
			PBS.[ID],
			PBS.[Type],
			PBS.[Name],
			PBS.[Code],
			PBS.[CreatorUserID],
			PBS.[CreatorPositionID],
			PBS.[CreationDate]
		FROM [pbl].[PlanningAndBudgetSection] PBS
		LEFT JOIN BudgetCodes ON BudgetCodes.ID = PBS.ID
		WHERE (@Name IS NULL OR [Name] LIKE '%' + @Name + '%')
			AND (@Code IS NULL OR [Code] LIKE '%' + @Code + '%')
			AND (@Type < 1 OR [Type] = @Type)
			AND ([RemoveDate] IS NULL)
			AND (@SalaryBudgetCode IS NULL OR BudgetCodes.ID IS NOT NULL)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY [Code]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyPlanningAndBudgetSection'))
	DROP PROCEDURE pbl.spModifyPlanningAndBudgetSection
GO

CREATE PROCEDURE pbl.spModifyPlanningAndBudgetSection
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(100),
	@ACode VARCHAR(10),
	@AType TINYINT,
	@ACreatorUserID UNIQUEIDENTIFIER,
	@ACreatorPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
		@Code VARCHAR(10) = LTRIM(RTRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0),
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@CreatorPositionID UNIQUEIDENTIFIER = @ACreatorPositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO [pbl].[PlanningAndBudgetSection]
				([ID], [Type], [Name], [Code], [CreatorUserID], [CreatorPositionID], [CreationDate], [RemoverUserID], [RemoverPositionID], [RemoveDate])
				VALUES
				(@ID, @Type, @Name, @Code, @CreatorUserID, @CreatorPositionID, GETDATE(), NULL, NULL, NULL)
			END
			ELSE
			BEGIN
				UPDATE [pbl].[PlanningAndBudgetSection]
				SET 
				 [Name] = @Name, 
				 [Code] = @Code, 
				 [Type] = @Type
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeletePlanningAndBudgetSectionDepartmentAssignment'))
	DROP PROCEDURE pbl.spDeletePlanningAndBudgetSectionDepartmentAssignment
GO

CREATE PROCEDURE pbl.spDeletePlanningAndBudgetSectionDepartmentAssignment
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [pbl].[PlanningAndBudgetSectionDepartmentAssignment]
			SET 
				[RemoverUserID] = @RemoverUserID,
				[RemoverPositionID] = @RemoverPositionID,
				[RemoveDate] = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetAssignedToPositionDepartments'))
DROP PROCEDURE pbl.spGetAssignedToPositionDepartments
GO

CREATE PROCEDURE pbl.spGetAssignedToPositionDepartments
	@APositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@PositionID UNIQUEIDENTIFIER = @APositionID

	; WITH Sections AS
	(
		SELECT DISTINCT PositionAssignment.[SectionID], PositionAssignment.[ID]
		FROM [pbl].[PlanningAndBudgetSectionPositionAssignment] PositionAssignment
			INNER JOIN [pbl].[PlanningAndBudgetSection] Section ON Section.ID = PositionAssignment.[SectionID]
		WHERE (@PositionID IS NULL OR [PositionID] = @PositionID)
			AND (Section.[RemoveDate] IS NULL)
			AND (PositionAssignment.[RemoveDate] IS NULL)
	)
	, MainSelect AS
	(
		SELECT DISTINCT
			DepartmentAssignment.[DepartmentID]
		FROM [pbl].[PlanningAndBudgetSectionDepartmentAssignment] DepartmentAssignment
		INNER JOIN Sections ON Sections.[ID] = DepartmentAssignment.[PositionSectionID]
		WHERE (DepartmentAssignment.[RemoveDate] IS NULL)
	)
	SELECT * FROM MainSelect
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSectionDepartmentAssignment'))
	DROP PROCEDURE pbl.spGetPlanningAndBudgetSectionDepartmentAssignment
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSectionDepartmentAssignment
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ID UNIQUEIDENTIFIER = @AID
	SELECT
		PBSDA.[ID],
		PBSDA.[PositionSectionID],
		PBSPA.[PositionID],
		Position.NationalCode PositionNationalCode,
		Position.FirstName + ' ' + Position.LastName PositionName,
		Position.[Type] PositionType,
		PBS.[Type] SectionType,
		PBS.[Name] SectionName,
		PBS.[Code] SectionCode,
		PBSDA.[DepartmentID],
		Department.[Name] DepartmentName,
		Department.[Code] DepartmentCode,
		Department.[Type] DepartmentType,
		PBSDA.[CreatorUserID],
		PBSDA.[CreatorPositionID],
		PBSDA.[CreationDate],
		PBSDA.[RemoverUserID],
		PBSDA.[RemoverPositionID],
		PBSDA.[RemoveDate]
	FROM [pbl].[PlanningAndBudgetSectionDepartmentAssignment] PBSDA
		INNER JOIN [pbl].[PlanningAndBudgetSectionPositionAssignment] PBSPA ON PBSPA.[ID] = PBSDA.[PositionSectionID]
		INNER JOIN [pbl].[PlanningAndBudgetSection] PBS ON PBS.[ID] = PBSPA.[SectionID]
		INNER JOIN [Kama.Aro.Organization].[org].[Department] Department ON Department.[ID] = PBSDA.DepartmentID
		INNER JOIN [Kama.Aro.Organization].[org].[_Position] Position ON Position.[ID] = PBSPA.[PositionID]
	WHERE PBSDA.[ID] = @ID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSectionDepartmentAssignments'))
DROP PROCEDURE pbl.spGetPlanningAndBudgetSectionDepartmentAssignments
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSectionDepartmentAssignments
	@AOrganName NVARCHAR(100),
	@AOrganType TINYINT,
	@AOrganCode VARCHAR(10),
	@AOrganID UNIQUEIDENTIFIER,
	@ASectionID UNIQUEIDENTIFIER,
	@APositionSectionID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@OrganName NVARCHAR(100) = LTRIM(RTRIM(@AOrganName)),
		@OrganType TINYINT = COALESCE(@AOrganType, 0),
		@OrganCode VARCHAR(10) = LTRIM(RTRIM(@AOrganCode)),
		@SectionID UNIQUEIDENTIFIER = @ASectionID,
		@PositionSectionID UNIQUEIDENTIFIER = @APositionSectionID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID
		
	SET @ParentOrganNode = (SELECT [Node] FROM [Kama.Aro.Organization].org.Department WHERE ID = @ParentOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @PageSize = 10000000
		SET @PageIndex = 1
	END
	; WITH Organ AS (
		SELECT
			Department.ID,
			Department.[Name],
			Department.[Code],
			Department.[Type]
		FROM [Kama.Aro.Organization].org.Department Department
		WHERE (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
			AND (@OrganID IS NULL OR Department.ID = @OrganID)
			AND (@OrganName IS NULL OR Department.[Name] LIKE '%' + @OrganName + '%')
			AND (@OrganCode IS NULL OR Department.[Code] LIKE '%' + @OrganCode + '%')
			AND (@OrganType < 1 OR Department.[Type] = @OrganType)
	)
	, MainSelect AS
	(
		SELECT
			PBSDA.[ID],
			PBSDA.[PositionSectionID],
			PBSPA.[PositionID],
			Position.NationalCode PositionNationalCode,
			Position.FirstName + ' ' + Position.LastName PositionName,
			Position.[Type] PositionType,
			PBS.[ID] SectionID,
			PBS.[Type] SectionType,
			PBS.[Name] SectionName,
			PBS.[Code] SectionCode,
			PBSDA.[DepartmentID],
			Department.[Name] DepartmentName,
			Department.[Code] DepartmentCode,
			Department.[Type] DepartmentType,
			PBSDA.[CreatorUserID],
			PBSDA.[CreatorPositionID],
			PBSDA.[CreationDate],
			PBSDA.[RemoverUserID],
			PBSDA.[RemoverPositionID],
			PBSDA.[RemoveDate]
		FROM [pbl].[PlanningAndBudgetSectionDepartmentAssignment] PBSDA
			INNER JOIN [pbl].[PlanningAndBudgetSectionPositionAssignment] PBSPA ON PBSPA.[ID] = PBSDA.[PositionSectionID]
			INNER JOIN [pbl].[PlanningAndBudgetSection] PBS ON PBS.[ID] = PBSPA.[SectionID]
			INNER JOIN Organ Department ON Department.[ID] = PBSDA.DepartmentID
			INNER JOIN [Kama.Aro.Organization].[org].[_Position] Position ON Position.[ID] = PBSPA.[PositionID]
		WHERE (@PositionSectionID IS NULL OR PBSDA.[PositionSectionID] = @PositionSectionID)
			AND (@SectionID IS NULL OR PBS.[ID] = @SectionID)
			AND (PBSDA.[RemoveDate] IS NULL) AND (PBS.[RemoveDate] IS NULL) AND (PBSPA.[RemoveDate] IS NULL) 
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY [SectionCode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyPlanningAndBudgetSectionDepartmentAssignment'))
	DROP PROCEDURE pbl.spModifyPlanningAndBudgetSectionDepartmentAssignment
GO

CREATE PROCEDURE pbl.spModifyPlanningAndBudgetSectionDepartmentAssignment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APositionSectionID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ACreatorUserID UNIQUEIDENTIFIER,
	@ACreatorPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PositionSectionID UNIQUEIDENTIFIER = @APositionSectionID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@CreatorPositionID UNIQUEIDENTIFIER = @ACreatorPositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO [pbl].[PlanningAndBudgetSectionDepartmentAssignment]
				([ID], [PositionSectionID], [DepartmentID], [CreatorUserID], [CreatorPositionID], [CreationDate], [RemoverUserID], [RemoverPositionID], [RemoveDate])
				VALUES
				(@ID, @PositionSectionID, @DepartmentID, @CreatorUserID, @CreatorPositionID, GETDATE(), NULL, NULL, NULL)
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spUpdateListPlanningAndBudgetSectionDepartmentAssignment') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spUpdateListPlanningAndBudgetSectionDepartmentAssignment
GO

CREATE PROCEDURE pbl.spUpdateListPlanningAndBudgetSectionDepartmentAssignment
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					[PositionSectionID] UNIQUEIDENTIFIER,
					[DepartmentID] UNIQUEIDENTIFIER
				)
			)
			INSERT INTO [pbl].[PlanningAndBudgetSectionDepartmentAssignment]
			([ID], [PositionSectionID], [DepartmentID], [CreatorUserID], [CreatorPositionID], [CreationDate])
			SELECT 
				NEWID() ID,
				Details.[PositionSectionID] [PositionSectionID],
				Details.[DepartmentID] [DepartmentID],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID],
				GETDATE() [CreationDate]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeletePlanningAndBudgetSectionPositionAssignment'))
	DROP PROCEDURE pbl.spDeletePlanningAndBudgetSectionPositionAssignment
GO

CREATE PROCEDURE pbl.spDeletePlanningAndBudgetSectionPositionAssignment
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [pbl].[PlanningAndBudgetSectionPositionAssignment]
			SET 
				[RemoverUserID] = @RemoverUserID,
				[RemoverPositionID] = @RemoverPositionID,
				[RemoveDate] = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSectionBossPositions'))
DROP PROCEDURE pbl.spGetPlanningAndBudgetSectionBossPositions
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSectionBossPositions
	@ASalaryBudgetCodes NVARCHAR(MAX),
	@ABoosPositionType TINYINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@SalaryBudgetCodes NVARCHAR(MAX) = LTRIM(RTRIM(@ASalaryBudgetCodes)),
		@BoosPositionType TINYINT = COALESCE(@ABoosPositionType, 0)


	;WITH MainSelect AS
	(
		SELECT DISTINCT
			PBSPA.[PositionID]
		FROM [pbl].[PlanningAndBudgetSectionPositionAssignment] PBSPA
			INNER JOIN [pbl].[PlanningAndBudgetSection] PBS ON PBS.[ID] = PBSPA.[SectionID]
			INNER JOIN [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment] PBSBCA ON PBSPA.[ID] = PBSBCA.PositionSectionID
			INNER JOIN [Kama.Aro.Organization].[org].[_Position] Position ON Position.[ID] = PBSPA.[PositionID]
			LEFT JOIN OPENJSON(@SalaryBudgetCodes) SalaryBudgetCodes ON SalaryBudgetCodes.value = PBSBCA.SalaryBudgetCode
		WHERE (PBSPA.RemoveDate IS NULL AND PBS.RemoveDate IS NULL AND PBSBCA.RemoveDate IS NULL)
			AND (@BoosPositionType < 1 OR Position.[Type] = @BoosPositionType)
			AND (@SalaryBudgetCodes IS NULL OR SalaryBudgetCodes.value = PBSBCA.SalaryBudgetCode)
	)
	SELECT * FROM MainSelect
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSectionPositionAssignment'))
	DROP PROCEDURE pbl.spGetPlanningAndBudgetSectionPositionAssignment
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSectionPositionAssignment
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		PBSPA.[ID],
		PBSPA.[SectionID],
		PBS.[Type] SectionType,
		PBS.[Name] SectionName,
		PBS.[Code] SectionCode,
		PBSPA.[PositionID],
		Position.NationalCode PositionNationalCode,
		Position.FirstName + ' ' + Position.LastName PositionName,
		Position.[Type] PositionType,
		PBSPA.[CreatorUserID],
		PBSPA.[CreatorPositionID],
		PBSPA.[CreationDate],
		PBSPA.[RemoverUserID],
		PBSPA.[RemoverPositionID],
		PBSPA.[RemoveDate]
	FROM [pbl].[PlanningAndBudgetSectionPositionAssignment] PBSPA
		INNER JOIN [pbl].[PlanningAndBudgetSection] PBS ON PBS.[ID] = PBSPA.[SectionID]
		INNER JOIN [Kama.Aro.Organization].[org].[_Position] Position ON Position.[ID] = PBSPA.[PositionID]
	WHERE PBSPA.[ID] = @ID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSectionPositionAssignments'))
DROP PROCEDURE pbl.spGetPlanningAndBudgetSectionPositionAssignments
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSectionPositionAssignments
	@APositionName NVARCHAR(100),
	@APositionNationalCode VARCHAR(10),
	@APositionType TINYINT,
	@ASectionID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@PositionName NVARCHAR(100) = LTRIM(RTRIM(@APositionName)),
		@PositionNationalCode VARCHAR(10) = LTRIM(RTRIM(@APositionNationalCode)),
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@SectionID UNIQUEIDENTIFIER = @ASectionID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			PBSPA.[ID],
			PBSPA.[SectionID],
			PBS.[Type] SectionType,
			PBS.[Name] SectionName,
			PBS.[Code] SectionCode,
			PBSPA.[PositionID],
			Position.NationalCode PositionNationalCode,
			Position.FirstName + ' ' + Position.LastName PositionName,
			Position.[Type] PositionType,
			PBSPA.[CreatorUserID],
			PBSPA.[CreatorPositionID],
			PBSPA.[CreationDate],
			PBSPA.[RemoverUserID],
			PBSPA.[RemoverPositionID],
			PBSPA.[RemoveDate]
		FROM [pbl].[PlanningAndBudgetSectionPositionAssignment] PBSPA
			INNER JOIN [pbl].[PlanningAndBudgetSection] PBS ON PBS.[ID] = PBSPA.[SectionID]
			INNER JOIN [Kama.Aro.Organization].[org].[_Position] Position ON Position.[ID] = PBSPA.[PositionID]
		WHERE (@SectionID IS NULL OR PBSPA.[SectionID] = @SectionID)
			AND (@PositionName IS NULL OR (Position.FirstName + ' ' + Position.LastName) LIKE '%' + @PositionName + '%')
			AND (@PositionNationalCode IS NULL OR @PositionNationalCode = Position.NationalCode)
			AND (PBSPA.[RemoveDate] IS NULL) AND (PBS.[RemoveDate] IS NULL)
			AND (@PositionType < 1 OR Position.[Type] = @PositionType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY PositionNationalCode
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyPlanningAndBudgetSectionPositionAssignment'))
	DROP PROCEDURE pbl.spModifyPlanningAndBudgetSectionPositionAssignment
GO

CREATE PROCEDURE pbl.spModifyPlanningAndBudgetSectionPositionAssignment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ASectionID UNIQUEIDENTIFIER,
	@APositionID UNIQUEIDENTIFIER,
	@ACreatorUserID UNIQUEIDENTIFIER,
	@ACreatorPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@SectionID UNIQUEIDENTIFIER = @ASectionID,
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@CreatorPositionID UNIQUEIDENTIFIER = @ACreatorPositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO [pbl].[PlanningAndBudgetSectionPositionAssignment]
				([ID], [SectionID], [PositionID], [CreatorUserID], [CreatorPositionID], [CreationDate], [RemoverUserID], [RemoverPositionID], [RemoveDate])
				VALUES
				(@ID, @SectionID, @PositionID, @CreatorUserID, @CreatorPositionID, GETDATE(), NULL, NULL, NULL)
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spUpdateListPlanningAndBudgetSectionPositionAssignment') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spUpdateListPlanningAndBudgetSectionPositionAssignment
GO

CREATE PROCEDURE pbl.spUpdateListPlanningAndBudgetSectionPositionAssignment
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					[SectionID] UNIQUEIDENTIFIER,
					[PositionID] UNIQUEIDENTIFIER
				)
			)
			INSERT INTO [pbl].[PlanningAndBudgetSectionPositionAssignment]
			([ID], [SectionID], [PositionID], [CreatorUserID], [CreatorPositionID], [CreationDate])
			SELECT 
				NEWID() ID,
				Details.[SectionID] [SectionID],
				Details.[PositionID] [PositionID],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID],
				GETDATE() [CreationDate]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeletePlanningAndBudgetSectionSalaryBudgetCodeAssignment'))
	DROP PROCEDURE pbl.spDeletePlanningAndBudgetSectionSalaryBudgetCodeAssignment
GO

CREATE PROCEDURE pbl.spDeletePlanningAndBudgetSectionSalaryBudgetCodeAssignment
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment]
			SET 
				[RemoverUserID] = @RemoverUserID,
				[RemoverPositionID] = @RemoverPositionID,
				[RemoveDate] = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetAssignedToPositionSalaryBudgetCodes'))
DROP PROCEDURE pbl.spGetAssignedToPositionSalaryBudgetCodes
GO

CREATE PROCEDURE pbl.spGetAssignedToPositionSalaryBudgetCodes
	@APositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@PositionID UNIQUEIDENTIFIER = @APositionID

	; WITH Sections AS
	(
		SELECT DISTINCT PositionAssignment.[SectionID], PositionAssignment.[ID]
		FROM [pbl].[PlanningAndBudgetSectionPositionAssignment] PositionAssignment
			INNER JOIN [pbl].[PlanningAndBudgetSection] Section ON Section.ID = PositionAssignment.[SectionID]
		WHERE (@PositionID IS NULL OR [PositionID] = @PositionID)
			AND (Section.[RemoveDate] IS NULL)
			AND (PositionAssignment.[RemoveDate] IS NULL)
	)
	, MainSelect AS
	(
		SELECT 
			MAX(BudgetCodeAssignment.ID) ID,
			BudgetCodeAssignment.[SalaryBudgetCode]
		FROM [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment] BudgetCodeAssignment
		INNER JOIN Sections ON Sections.[ID] = BudgetCodeAssignment.[PositionSectionID]
		WHERE (BudgetCodeAssignment.[RemoveDate] IS NULL)
		GROUP BY BudgetCodeAssignment.[SalaryBudgetCode]
	)
	SELECT * FROM MainSelect
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSectionSalaryBudgetCodeAssignment'))
	DROP PROCEDURE pbl.spGetPlanningAndBudgetSectionSalaryBudgetCodeAssignment
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSectionSalaryBudgetCodeAssignment
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ID UNIQUEIDENTIFIER = @AID
	SELECT
		PBSSBCA.[ID],
		PBSSBCA.[PositionSectionID],
		PBSPA.[PositionID],
		Position.NationalCode PositionNationalCode,
		Position.FirstName + ' ' + Position.LastName PositionName,
		Position.[Type] PositionType,
		PBS.[Type] SectionType,
		PBS.[Name] SectionName,
		PBS.[Code] SectionCode,
		PBSSBCA.[SalaryBudgetCode],
		PBSSBCA.[CreatorUserID],
		PBSSBCA.[CreatorPositionID],
		PBSSBCA.[CreationDate],
		PBSSBCA.[RemoverUserID],
		PBSSBCA.[RemoverPositionID],
		PBSSBCA.[RemoveDate]
	FROM [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment] PBSSBCA
		INNER JOIN [pbl].[PlanningAndBudgetSectionPositionAssignment] PBSPA ON PBSPA.[ID] = PBSSBCA.[PositionSectionID]
		INNER JOIN [pbl].[PlanningAndBudgetSection] PBS ON PBS.[ID] = PBSPA.[SectionID]
		INNER JOIN [Kama.Aro.Organization].[org].[_Position] Position ON Position.[ID] = PBSPA.[PositionID]
	WHERE PBSSBCA.[ID] = @ID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetPlanningAndBudgetSectionSalaryBudgetCodeAssignments'))
DROP PROCEDURE pbl.spGetPlanningAndBudgetSectionSalaryBudgetCodeAssignments
GO

CREATE PROCEDURE pbl.spGetPlanningAndBudgetSectionSalaryBudgetCodeAssignments
	@ASalaryBudgetCode VARCHAR(20),
	@ASectionID UNIQUEIDENTIFIER,
	@APositionSectionID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@SalaryBudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ASalaryBudgetCode)),
		@SectionID UNIQUEIDENTIFIER = @ASectionID,
		@PositionSectionID UNIQUEIDENTIFIER = @APositionSectionID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID
		

	IF @PageIndex = 0 
	BEGIN
		SET @PageSize = 10000000
		SET @PageIndex = 1
	END
	; WITH MainSelect AS
	(
		SELECT
			PBSSBCA.[ID],
			PBSSBCA.[PositionSectionID],
			PBSPA.[PositionID],
			Position.NationalCode PositionNationalCode,
			Position.FirstName + ' ' + Position.LastName PositionName,
			Position.[Type] PositionType,
			PBS.ID SectionID,
			PBS.[Type] SectionType,
			PBS.[Name] SectionName,
			PBS.[Code] SectionCode,
			PBSSBCA.[SalaryBudgetCode],
			PBSSBCA.[CreatorUserID],
			PBSSBCA.[CreatorPositionID],
			PBSSBCA.[CreationDate],
			PBSSBCA.[RemoverUserID],
			PBSSBCA.[RemoverPositionID],
			PBSSBCA.[RemoveDate]
		FROM [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment] PBSSBCA
			INNER JOIN [pbl].[PlanningAndBudgetSectionPositionAssignment] PBSPA ON PBSPA.[ID] = PBSSBCA.[PositionSectionID]
			INNER JOIN [pbl].[PlanningAndBudgetSection] PBS ON PBS.[ID] = PBSPA.[SectionID]
			INNER JOIN [Kama.Aro.Organization].[org].[_Position] Position ON Position.[ID] = PBSPA.[PositionID]
		WHERE (@PositionSectionID IS NULL OR PBSSBCA.[PositionSectionID] = @PositionSectionID)
			AND (@SalaryBudgetCode IS NULL OR PBSSBCA.[SalaryBudgetCode] = @SalaryBudgetCode)
			AND (@SectionID IS NULL OR PBS.[ID] = @SectionID)
			AND (PBSSBCA.[RemoveDate] IS NULL) AND (PBS.[RemoveDate] IS NULL) AND (PBSPA.[RemoveDate] IS NULL) 
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY [SectionCode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetSectionsAssignedToSalaryBudgetCode'))
DROP PROCEDURE pbl.spGetSectionsAssignedToSalaryBudgetCode
GO

CREATE PROCEDURE pbl.spGetSectionsAssignedToSalaryBudgetCode
	@ASalaryBudgetCode VARCHAR(20),
	@APositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@SalaryBudgetCode UNIQUEIDENTIFIER = LTRIM(RTRIM(@ASalaryBudgetCode)),
		@PositionID UNIQUEIDENTIFIER = @APositionID
	; WITH MainSelect AS
	(
		SELECT DISTINCT
			PBS.[ID],
			PBS.[Type],
			PBS.[Name],
			PBS.[Code]
		FROM [pbl].[PlanningAndBudgetSection] PBS
		INNER JOIN [pbl].[PlanningAndBudgetSectionPositionAssignment] PBSPA ON  PBSPA.SectionID = PBS.ID
		INNER JOIN [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment] PBSBDA ON PBSBDA.[PositionSectionID] = PBSPA.ID
		WHERE (PBS.[RemoveDate] IS NULL)
			AND (@SalaryBudgetCode IS NULL OR PBSBDA.SalaryBudgetCode = @SalaryBudgetCode)
			AND (@PositionID IS NULL OR PBSPA.[PositionID] = @PositionID)
	)
	SELECT * FROM MainSelect
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyPlanningAndBudgetSectionSalaryBudgetCodeAssignment'))
	DROP PROCEDURE pbl.spModifyPlanningAndBudgetSectionSalaryBudgetCodeAssignment
GO

CREATE PROCEDURE pbl.spModifyPlanningAndBudgetSectionSalaryBudgetCodeAssignment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APositionSectionID UNIQUEIDENTIFIER,
	@ASalaryBudgetCode VARCHAR(20),
	@ACreatorUserID UNIQUEIDENTIFIER,
	@ACreatorPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PositionSectionID UNIQUEIDENTIFIER = @APositionSectionID,
		@SalaryBudgetCode NVARCHAR(20) = LTRIM(RTRIM(@ASalaryBudgetCode)),
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@CreatorPositionID UNIQUEIDENTIFIER = @ACreatorPositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment]
				([ID], [PositionSectionID], [SalaryBudgetCode], [CreatorUserID], [CreatorPositionID], [CreationDate], [RemoverUserID], [RemoverPositionID], [RemoveDate])
				VALUES
				(@ID, @PositionSectionID, @SalaryBudgetCode, @CreatorUserID, @CreatorPositionID, GETDATE(), NULL, NULL, NULL)
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spUpdateListPlanningAndBudgetSectionSalaryBudgetCodeAssignment') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spUpdateListPlanningAndBudgetSectionSalaryBudgetCodeAssignment
GO

CREATE PROCEDURE pbl.spUpdateListPlanningAndBudgetSectionSalaryBudgetCodeAssignment
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					[PositionSectionID] UNIQUEIDENTIFIER,
					[SalaryBudgetCode] VARCHAR(20)
				)
			)
			INSERT INTO [pbl].[PlanningAndBudgetSectionSalaryBudgetCodeAssignment]
			([ID], [PositionSectionID], [SalaryBudgetCode], [CreatorUserID], [CreatorPositionID], [CreationDate])
			SELECT 
				NEWID() ID,
				Details.[PositionSectionID] [PositionSectionID],
				Details.[SalaryBudgetCode] [SalaryBudgetCode],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID],
				GETDATE() [CreationDate]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spDeleteProcess') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spDeleteProcess
GO

CREATE PROCEDURE pbl.spDeleteProcess
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			
			--IF EXISTS (SELECT TOP 1 1 FROM [req].[Licence] WHERE ProcessID = @ID)
			--	THROW 50000, N'با استفاده از این فرآیند درخواستی ثبت شده است و امکان حذف وجود ندارد', 1

			--IF EXISTS (SELECT TOP 1 1 FROM [req].[Plan] WHERE ProcessID = @ID)
			--	THROW 50000, N'با استفاده از این فرآیند درخواستی ثبت شده است و امکان حذف وجود ندارد', 1

			--DELETE FROM [pbl].[Process] WHERE ID = @ID

			UPDATE process
			SET [RemoveDate] = GETDATE(), [RemoverUserID] = @CurrentUserID
			FROM [pbl].[Process] process
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		 SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetProcess') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spGetProcess
GO

CREATE PROCEDURE pbl.spGetProcess 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		[ID],
		[Name],
		[Type],
		[EnableForSave],
		[EnableForConfirm],
		[EnableForFinalConfirm],
		[Comment],
		[CreatorPositionID],
		[CreatorUserID],
		[CreationDate],
		[ViewAllUsers],
		[Code]
	FROM [pbl].[Process]
	WHERE ID = @ID
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetProcesses') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetProcesses
GO

CREATE PROCEDURE pbl.spGetProcesses
	@AName NVARCHAR(500),
	@AType TINYINT,
	@AEnableForSave TINYINT,
	@AEnableForConfirm TINYINT,
	@AEnableForFinalConfirm TINYINT,
	@ACode VARCHAR(20),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@Name NVARCHAR(500) = LTRIM(RTRIM(@AName)),
		@Type TINYINT = COALESCE(@AType, 0),
		@EnableForSave TINYINT = COALESCE(@AEnableForSave, 0),
		@EnableForConfirm TINYINT = COALESCE(@AEnableForConfirm, 0),
		@EnableForFinalConfirm TINYINT = COALESCE(@AEnableForFinalConfirm, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS(
		SELECT
			[ID],
			[Name],
			[Type],
			[EnableForSave],
			[EnableForConfirm],
			[EnableForFinalConfirm],
			[Comment],
			[CreatorPositionID],
			[CreatorUserID],
			[CreationDate],
			[ViewAllUsers],
			[Code]	
		FROM [pbl].[Process]
			WHERE ([RemoveDate] IS NULL)
			AND (@Name IS NULL OR [Name] LIKE '%' + @Name + '%')
			AND (@Type < 1 OR [Type] = @Type)
			AND (@EnableForSave < 1 OR [EnableForSave] = @EnableForSave - 1)
			AND (@EnableForConfirm < 1 OR EnableForConfirm = @EnableForConfirm - 1)
			AND (@EnableForFinalConfirm < 1 OR EnableForFinalConfirm = @EnableForFinalConfirm - 1)
			AND (@Code IS NULL OR Code = @Code)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY Code	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetProcessesForRequest') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetProcessesForRequest
GO

CREATE PROCEDURE pbl.spGetProcessesForRequest
	@AName NVARCHAR(500),
	@AType TINYINT,
	@AEnableForSave TINYINT,
	@AEnableForConfirm TINYINT,
	@AEnableForFinalConfirm TINYINT,
	@ACode VARCHAR(20),
	@ADynamicPermissionObjects NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@Name NVARCHAR(500) = LTRIM(RTRIM(@AName)),
		@Type TINYINT = COALESCE(@AType, 0),
		@EnableForSave TINYINT = COALESCE(@AEnableForSave, 0),
		@EnableForConfirm TINYINT = COALESCE(@AEnableForConfirm, 0),
		@EnableForFinalConfirm TINYINT = COALESCE(@AEnableForFinalConfirm, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@DynamicPermissionObjects NVARCHAR(MAX) = @ADynamicPermissionObjects,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS(
		SELECT DISTINCT
			process.[ID],
			process.[Name],
			process.[Type],
			process.[EnableForSave],
			process.[EnableForConfirm],
			process.[EnableForFinalConfirm],
			process.[Comment],
			process.[CreatorPositionID],
			process.[CreatorUserID],
			process.[CreationDate],
			process.[ViewAllUsers],
			process.[Code]
		FROM [pbl].[Process] process
			LEFT JOIN OPENJSON(@DynamicPermissionObjects) dynamicPermissionObjects ON dynamicPermissionObjects.value = process.ID
		WHERE process.RemoveDate IS NULL
			AND (@Name IS NULL OR process.[Name] LIKE '%' + @Name + '%')
			AND (@Type < 1 OR process.[Type] = @Type)
			AND (@EnableForSave < 1 OR process.[EnableForSave] = @EnableForSave - 1)
			AND (@EnableForConfirm < 1 OR process.EnableForConfirm = @EnableForConfirm - 1)
			AND (@EnableForFinalConfirm < 1 OR process.EnableForFinalConfirm = @EnableForFinalConfirm - 1)
			AND (process.ViewAllUsers = 1 OR dynamicPermissionObjects.value = process.ID)
			AND (@Code IS NULL OR process.Code = @Code)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY Code
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spModifyProcess') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spModifyProcess
GO

CREATE PROCEDURE pbl.spModifyProcess  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(500),
	@AType TINYINT,
	@AEnableForSave BIT,
	@AEnableForConfirm BIT,
	@AEnableForFinalConfirm BIT,
	@ACode VARCHAR(20),
	@AComment NVARCHAR(4000),
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AViewAllUsers BIT

	
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(500) = LTRIM(RTRIM(@AName)),
		@Type TINYINT = COALESCE(@AType,0),
		@EnableForSave BIT = COALESCE(@AEnableForSave,0),
		@EnableForConfirm BIT = COALESCE(@AEnableForConfirm, 0),
		@EnableForFinalConfirm BIT = COALESCE(@AEnableForFinalConfirm, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@Comment NVARCHAR(4000) = LTRIM(RTRIM(@AComment)),
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@ViewAllUsers BIT = COALESCE(@AViewAllUsers, 0),
		@Result INT = 0


	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [pbl].[Process]
				([ID], [Name], [Type], [EnableForSave], [EnableForConfirm], [EnableForFinalConfirm], [Comment], [CreatorPositionID], [CreatorUserID], [CreationDate], [ViewAllUsers], [Code], [RemoveDate], [RemoverUserID], [ModiferUserID])
				VALUES
					(@ID, @Name, @Type, @EnableForSave, @EnableForConfirm, @EnableForFinalConfirm, @Comment, @CurrentUserPositionID, @CurrentUserID, GETDATE(), @ViewAllUsers, @Code, NULL, NULL, NULL)
			END
			ELSE
			BEGIN
				UPDATE [pbl].[Process]
				SET
					[Name] = @Name,
					[Type] = @Type,
					[EnableForSave] = @EnableForSave,
					[EnableForConfirm] = @EnableForConfirm,
					[EnableForFinalConfirm] = @EnableForFinalConfirm,
					[Comment] = @Comment,
					[ViewAllUsers] = @ViewAllUsers,
					[Code] = @Code,
					[ModiferUserID] = @CurrentUserID
				WHERE ID = @ID
			END		

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetProcessMonitoring') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spGetProcessMonitoring
GO

CREATE PROCEDURE pbl.spGetProcessMonitoring
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE
		@ReadyForProcessBankAccount INT,
		@ProcessingBankAccount INT,
		@ReadyForProcessEmployeeCatalog INT,
		@ProcessingEmployeeCatalog INT,
		@ReadyForProcessPayroll INT,
		@ProcessingPayroll INT,
		@PayrollWrongError INT,
		@NotCalculatedPayrollEmployee INT,
		@DidNotDeletedPayrolls INT

		SET @ReadyForProcessBankAccount  = (SELECT COUNT(ID) FROM [pbl].[BankAccount] WHERE [ValidType] = 1 AND RemoveDate IS NULL)
		SET @ProcessingBankAccount  = (SELECT COUNT(ID) FROM [pbl].[BankAccount] WHERE [ValidType] = 2 AND RemoveDate IS NULL)
		
		SET @ReadyForProcessEmployeeCatalog  = (SELECT COUNT(ID) FROM [emp].[EmployeeCatalog] WHERE [State] = 5)
		SET @ProcessingEmployeeCatalog  = (SELECT COUNT(ID) FROM [emp].[EmployeeCatalog] WHERE [State] = 10)
		
		
		SET @ReadyForProcessPayroll  = (SELECT COUNT(ID) FROM [wag].[_Payroll] WHERE [State] = 1)
		SET @ProcessingPayroll  = (SELECT COUNT(ID) FROM [wag].[_Payroll] WHERE [State] = 10)
		
		SET @PayrollWrongError  = (
			SELECT COUNT(p.ID) FROM [wag].[_Payroll] p
			INNER JOIN wag.TreasuryRequest tr ON tr.ID = p.RequestID
			INNER JOIN pbl.BaseDocument BaseDocument on BaseDocument.ID = tr.ID
			INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
			WHERE (p.[State] = 30 AND (COALESCE(lastFlow.ToDocState, 0) > 40))
		)

		SET @NotCalculatedPayrollEmployee = (
			SELECT COUNT(pe.ID)
			FROM wag.PayrollEmployee pe
			INNER JOIN wag._Payroll p ON p.ID = pe.PayrollID
			LEFT JOIN wag.PayrollEmployeeDetail ped on ped.ID = pe.ID
			WHERE (
				(ped.[Salary] IS NULL)
				AND (ped.[Continuous] IS NULL)
				AND (ped.[NonContinuous] IS NULL)
				AND (ped.[Reward] IS NULL)
				AND (ped.[Welfare] IS NULL)
				AND (ped.[Other] IS NULL)
				AND (ped.[Deductions] IS NULL)
				AND (ped.[SumNHokm] IS NULL)
				AND (pe.[SumHokm] IS NULL)
			)

		)
		
		SET @DidNotDeletedPayrolls = (
			SELECT COUNT(DISTINCT trd.PayrollID)
			FROM [wag].[TreasuryRequestDetail] trd
			INNER JOIN wag.Payroll p ON p.ID = trd.PayrollID
			INNER JOIN [pbl].[BaseDocument] bd on bd.ID = p.ID
			WHERE (
				bd.RemoveDate IS NOT NULL
			)

		)
		
		SELECT
			@ReadyForProcessBankAccount ReadyForProcessBankAccount,
			@ProcessingBankAccount ProcessingBankAccount,
			@ReadyForProcessEmployeeCatalog ReadyForProcessEmployeeCatalog,
			@ProcessingEmployeeCatalog ProcessingEmployeeCatalog,
			@ReadyForProcessPayroll ReadyForProcessPayroll,
			@ProcessingPayroll ProcessingPayroll,
			@PayrollWrongError PayrollWrongError,
			@NotCalculatedPayrollEmployee NotCalculatedPayrollEmployee,
			@DidNotDeletedPayrolls DidNotDeletedPayrolls
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spMakeProcessThingsRight') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spMakeProcessThingsRight
GO

CREATE PROCEDURE pbl.spMakeProcessThingsRight
	@AType INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	DECLARE
		@Type INT = COALESCE(@AType, 0)

	BEGIN TRY
		BEGIN TRAN

			IF @Type = 1
			BEGIN
				UPDATE [pbl].[BankAccount] SET ValidType = 1 WHERE ValidType = 2
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spDeleteProcessAllowedDate') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spDeleteProcessAllowedDate
GO

CREATE PROCEDURE pbl.spDeleteProcessAllowedDate
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM [pbl].[ProcessAllowedDate] WHERE [ID] = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		 SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetProcessAllowedDate') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spGetProcessAllowedDate
GO

CREATE PROCEDURE pbl.spGetProcessAllowedDate 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		[ID],
		[ProcessID],
		[Month],
		[Year],
		[FromDate],
		[ToDate]
	FROM [pbl].[ProcessAllowedDate]
	WHERE [ID] = @ID
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetProcessAllowedDates') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetProcessAllowedDates
GO

CREATE PROCEDURE pbl.spGetProcessAllowedDates
	@AProcessID UNIQUEIDENTIFIER,
	@AMonth TINYINT,
	@AYear SMALLINT,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ProcessID UNIQUEIDENTIFIER = @AProcessID,
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS(
		SELECT
			ProcessAllowedDate.[ID],
			ProcessAllowedDate.[ProcessID],
			ProcessAllowedDate.[Month],
			ProcessAllowedDate.[Year],
			ProcessAllowedDate.[FromDate],
			ProcessAllowedDate.[ToDate]
		FROM [pbl].[ProcessAllowedDate] ProcessAllowedDate
			WHERE (@ProcessID IS NULL OR ProcessAllowedDate.[ProcessID] = @ProcessID)
			AND (@Month < 1 OR ProcessAllowedDate.[Month] = @Month)
			AND (@Year < 1 OR ProcessAllowedDate.[Year] = @Year)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY [Year],[Month]
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spModifyProcessAllowedDate') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spModifyProcessAllowedDate
GO

CREATE PROCEDURE pbl.spModifyProcessAllowedDate  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AProcessID UNIQUEIDENTIFIER,
	@AMonth TINYINT,
	@AYear SMALLINT,
	@AFromDate DATETIME,
	@AToDate DATETIME

	
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@ProcessID UNIQUEIDENTIFIER = @AProcessID,
		@Month TINYINT = COALESCE(@AMonth,0),
		@Year SMALLINT = COALESCE(@AYear,0),
		@FromDate DATETIME = @AFromDate,
		@ToDate DATETIME = @AToDate,
		@Result INT = 0


	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [pbl].[ProcessAllowedDate]
				([ID], [ProcessID], [Month], [Year], [FromDate], [ToDate])
				VALUES
					(@ID, @ProcessID, @Month, @Year, @FromDate, @ToDate)
			END
			ELSE
			BEGIN
				UPDATE [pbl].[ProcessAllowedDate]
				SET
					[ProcessID] = @ProcessID,
					[Month] = @Month,
					[Year] = @Year,
					[FromDate] = @FromDate,
					[ToDate] = @ToDate
				WHERE ID = @ID
			END		

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetProcessConfirmers') IS NOT NULL
    DROP PROCEDURE pbl.spGetProcessConfirmers
GO

CREATE PROCEDURE pbl.spGetProcessConfirmers
	@AProcessID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@AConfirmerTypes NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE	
		@ProcessID UNIQUEIDENTIFIER = @AProcessID,
		@Type TINYINT = COALESCE(@AType, 0),
		@ConfirmerTypes NVARCHAR(MAX) = LTRIM(RTRIM(@AConfirmerTypes))
	
	;With ConfirmerPositionType AS (
		SELECT * FROM OPENJSON(@ConfirmerTypes) 
		WITH
		(
			[ID] TINYINT,
			[OrderConfirmerPositionType] TINYINT
		)
	)

	SELECT
		ProcessConfirmer.ID,
		ProcessConfirmer.ProcessID,
		CAST(COALESCE(ProcessConfirmer.FinalApproval, 0) AS BIT) FinalApproval,
		CAST(COALESCE(ProcessConfirmer.[Type], 0) AS TINYINT) [Type],
		CAST(ConfirmerPositionType.ID AS TINYINT) ConfirmerPositionType,
		CAST(ConfirmerPositionType.OrderConfirmerPositionType AS TINYINT) OrderConfirmerPositionType
	FROM ConfirmerPositionType
		LEFT JOIN pbl.ProcessConfirmer ON ProcessConfirmer.ConfirmerPositionType = ConfirmerPositionType.ID AND ProcessConfirmer.ProcessID = @ProcessID AND ProcessConfirmer.[Type] = @Type
	WHERE ConfirmerPositionType.ID > 0
	ORDER BY OrderConfirmerPositionType
END

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spModifyProcessConfirmers') IS NOT NULL
    DROP PROCEDURE pbl.spModifyProcessConfirmers
GO

CREATE PROCEDURE pbl.spModifyProcessConfirmers
	@AProcessID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@AConfirmerPositionTypes NVARCHAR(1000)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ProcessID UNIQUEIDENTIFIER = @AProcessID,
		@Type TINYINT = COALESCE(@AType, 0),
		@ConfirmerPositionTypes NVARCHAR(1000) = LTRIM(RTRIM(@AConfirmerPositionTypes)),
		@Result INT = 0
	
	BEGIN TRY
		BEGIN TRAN

			DELETE pbl.ProcessConfirmer
			WHERE ProcessID = @ProcessID
			AND [Type] = @Type

			IF @ConfirmerPositionTypes IS NOT NULL
			BEGIN
				INSERT INTO pbl.ProcessConfirmer
					(ID, ProcessID, ConfirmerPositionType, [Type], [FinalApproval])
				SELECT 
					NEWID() ID,
					@ProcessID,
					ConfirmerPositionType,
					@Type [Type],
					FinalApproval
				FROM OPENJSON(@ConfirmerPositionTypes)
				WITH(
					ConfirmerPositionType TINYINT,
					FinalApproval BIT
				)
			END
					
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result
END


GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spDeleteProcessError') IS NOT NULL
    DROP PROCEDURE pbl.spDeleteProcessError
GO

CREATE PROCEDURE pbl.spDeleteProcessError
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID

	BEGIN TRY
		BEGIN TRAN
			
			Update [pbl].[ProcessError]
			SET
				[RemoverUserID] = @RemoverUserID,
				[RemoverPositionID] = @ARemoverPositionID,
				[RemoveDate] = GETDATE()
			WHERE [ID] = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetProcessError') IS NOT NULL
    DROP PROCEDURE pbl.spGetProcessError
GO

CREATE PROCEDURE pbl.spGetProcessError 
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		[ID],
		[Code],
		[Subject],
		[Type],
		[ErrorText],
		[CreatorUserID],
		[CreationDate],
		[Enable],
		[ProcessType],
		[Deployed]
	FROM [pbl].[ProcessError]
	WHERE [ID] = @ID

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetProcessErrorByCode') IS NOT NULL
    DROP PROCEDURE pbl.spGetProcessErrorByCode
GO

CREATE PROCEDURE pbl.spGetProcessErrorByCode 
	@ACode VARCHAR(10)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@Code VARCHAR(10) = @ACode

	SELECT 
		[ID],
		[Code],
		[Subject],
		[Type],
		[ErrorText],
		[CreatorUserID],
		[CreationDate],
		[Enable],
		[ProcessType]
		[Deployed]
	FROM [pbl].[ProcessError]
	WHERE (@Code IS NULL OR [Code] LIKE '%' + @Code + '%')

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetProcessErrors') IS NOT NULL
    DROP PROCEDURE pbl.spGetProcessErrors
GO

CREATE PROCEDURE pbl.spGetProcessErrors
	@ACode VARCHAR(10),
	@ASubject TINYINT,
	@AType TINYINT,
	@AEnable BIT,
	@ADeployed BIT,
	@AProcessType TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@Code VARCHAR = LTRIM(RTRIM(@ACode)),
		@Subject TINYINT = COALESCE(@ASubject, 0),
		@Type TINYINT = COALESCE(@AType, 0),
		@Enable TINYINT = COALESCE(@AEnable, 0),
		@Deployed TINYINT = COALESCE(@ADeployed, 0),
		@ProcessType TINYINT = COALESCE(@AProcessType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;With MainSelect AS
	(
		SELECT 
			[ID],
			[Code],
			[Subject],
			[Type],
			[ErrorText],
			[ProcessType],
			[CreatorUserID],
			[CreationDate],
			[Enable],
			[Deployed]
		FROM [pbl].[ProcessError]
		WHERE (([RemoveDate] IS NULL)
			AND (@Code IS NULL OR [Code] LIKE '%' + @Code + '%')
			AND (@Type < 1 OR @Type = [Type])
			AND (@Subject < 1 OR @Subject = [Subject])
			AND (@Enable < 1 OR @Enable = [Enable] - 1 )
			AND (@Deployed < 1 OR @Deployed = [Deployed] - 1 )
			)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Code]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetProcessErrorsForExcellProcess') IS NOT NULL
    DROP PROCEDURE pbl.spGetProcessErrorsForExcellProcess
GO

CREATE PROCEDURE pbl.spGetProcessErrorsForExcellProcess 
	
AS
BEGIN
    SET NOCOUNT ON;
	
	SELECT 
		[ID],
		[Code],
		[Subject],
		[Type],
		[ErrorText],
		[ProcessType],
		[CreatorUserID],
		[CreationDate],
		[Enable],
		[Deployed]
	FROM [pbl].[ProcessError]

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spModifyProcessError') IS NOT NULL
    DROP PROCEDURE pbl.spModifyProcessError
GO

CREATE PROCEDURE pbl.spModifyProcessError
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ASubject TINYINT,
	@AType TINYINT,
	@AProcessType TINYINT,
	@AErrorText NVARCHAR(4000),
	@ACreatorUserID UNIQUEIDENTIFIER,
	@AEnable BIT,
	@ADeployed BIT,
	@ACode VARCHAR(6) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Subject TINYINT = ISNULL(@ASubject, 1),
		@Type TINYINT = ISNULL(@AType, 1),
		@ErrorText NVARCHAR(4000) = LTRIM(RTRIM(@AErrorText)),
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@ProcessType TINYINT = COALESCE(@AProcessType, 0),
		@Enable BIT = COALESCE(@AEnable, 0),
		@Deployed BIT = COALESCE(@ADeployed, 0),
		@Result INT = 0,
		@Code VARCHAR(10)


	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- Insert
			BEGIN
				SET @Code = COALESCE((SELECT MAX(Code) FROM [pbl].[ProcessError] WHERE [Subject] = @Subject), 0) + 5

				INSERT INTO [pbl].[ProcessError]
					([ID], [Code], [Subject], [Type], [ErrorText], [CreatorUserID], [CreationDate], [Enable], [Deployed], [RemoverUserID], [RemoverPositionID], [RemoveDate], [ProcessType])
				VALUES
					(@ID, @Code, @Subject, @Type, @ErrorText, @CreatorUserID, GETDATE(), @Enable, @Deployed, NULL, NULL, NULL, @ProcessType)

			END
			ELSE
			BEGIN  -- Update

				UPDATE [pbl].[ProcessError]
				SET 
					[Type] = @Type,
					[ErrorText] = @ErrorText,
					[Deployed] = @Deployed,
					[ProcessType] = @ProcessType
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spCreateProcessMonitoring') IS NOT NULL
    DROP PROCEDURE pbl.spCreateProcessMonitoring
GO

CREATE PROCEDURE pbl.spCreateProcessMonitoring
	@AProcessID UNIQUEIDENTIFIER,
	@AProcessType TINYINT,
	@AActionType TINYINT
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ProcessID UNIQUEIDENTIFIER = @AProcessID,
		@ProcessType TINYINT = @AProcessType,
		@ActionType TINYINT = @AActionType

	BEGIN TRY
		BEGIN TRAN
			BEGIN
				
				INSERT INTO [pbl].[ProcessMonitoring]
				([ID], [ProcessID], [ProcessType], [ActionType], [Date])
				VALUES
				(NEWID(), @ProcessID, @ProcessType, @ActionType, GETDATE())
			END
		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.Procedures WHERE [object_id] = OBJECT_ID('pbl.spCreateProcessMonitorings'))
    DROP PROCEDURE pbl.spCreateProcessMonitorings
GO

CREATE PROCEDURE pbl.spCreateProcessMonitorings  
	@AProcessMonitorings NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ProcessMonitorings NVARCHAR(MAX) = LTRIM(RTRIM(@AProcessMonitorings))

	BEGIN TRY
		BEGIN TRAN

			IF @ProcessMonitorings IS NOT NULL
			BEGIN

				INSERT INTO [pbl].[ProcessMonitoring]
				([ID], [ProcessID], [ProcessType], [ActionType], [Date])
				SELECT 
					NEWID(),
					tblJson.[ProcessID], 
					tblJson.[ProcessType], 
					tblJson.[ActionType], 
					tblJson.[Date]
				FROM OPENJSON(@ProcessMonitorings)
				WITH
				(
					[ProcessID] UNIQUEIDENTIFIER, 
					[ProcessType] TINYINT, 
					[ActionType] TINYINT, 
					[Date] DateTime
				) tblJson

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW 
	END CATCH

    RETURN @@ROWCOUNT 
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetProcessMonitoringByPayrollID') IS NOT NULL
    DROP PROCEDURE pbl.spGetProcessMonitoringByPayrollID
GO

CREATE PROCEDURE pbl.spGetProcessMonitoringByPayrollID
	@AProcessID UNIQUEIDENTIFIER

AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ProcessID UNIQUEIDENTIFIER = @AProcessID

   SELECT  COUNT(*) AS ProcessCount
   FROM [pbl].[ProcessMonitoring]
   WHERE [ProcessID]=@ProcessID			
			
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetProcessMonitoringCountByPayrollID') IS NOT NULL
    DROP PROCEDURE pbl.spGetProcessMonitoringCountByPayrollID
GO

CREATE PROCEDURE pbl.spGetProcessMonitoringCountByPayrollID
	@AProcessID UNIQUEIDENTIFIER

AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ProcessID UNIQUEIDENTIFIER = @AProcessID

   SELECT  COUNT(*) AS PayrollProcessCount
   FROM [pbl].[ProcessMonitoring]
   WHERE [ProcessID]=@ProcessID
      AND [ActionType]=2
			
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetSalaryBudgetCode') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spGetSalaryBudgetCode
GO

CREATE PROCEDURE pbl.spGetSalaryBudgetCode 
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		[ID], 
		[SerialNumber], 
		[Name], 
		[BudgetCode], 
		[Type], 
		[PaymentType], 
		[Status], 
		[PaymentDepartmentID], 
		[Comment], 
		[CreatorUserID],
		[CreatorPositionID], 
		[CreationDate], 
		[LastModifyUserID], 
		[LastModifyPositionID], 
		[ArchiveDate],
		[isLock]
	FROM [pbl].[SalaryBudgetCode]
	WHERE ID = @ID
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetSalaryBudgetCodes') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetSalaryBudgetCodes
GO

CREATE PROCEDURE pbl.spGetSalaryBudgetCodes
	@ASerialNumber VARCHAR(14),
	@ABudgetCode VARCHAR(10),
	@ABudgetCodes VARCHAR(MAX),
	@APaymentDepartmentID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@APaymentType TINYINT,
	@AStatus TINYINT,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
			@SerialNumber VARCHAR(14) = LTRIM(RTRIM(@ASerialNumber)),
			@BudgetCode VARCHAR(10) = LTRIM(RTRIM(@ABudgetCode)),
			@BudgetCodes NVARCHAR(MAX) = LTRIM(RTRIM(@ABudgetCodes)),
			@PaymentDepartmentID UNIQUEIDENTIFIER = @APaymentDepartmentID,
			@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
			@Type TINYINT = COALESCE(@AType, 0),
			@PaymentType TINYINT = COALESCE(@APaymentType, 0),
			@Status TINYINT = COALESCE(@AStatus, 0),
			@GetTotalCount BIT = COALESCE(@APageSize, @AGetTotalCount),
			@PageSize INT = COALESCE(@APageSize, 0),
			@PageIndex INT = COALESCE(@APageIndex, 0),
			@SortExp VARCHAR(MAX)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	;WITH PaymentOrganCount AS (
		SELECT 
			[SalaryBudgetCodeID],
			COUNT([DepartmentID]) DepartmentCount
		FROM [pbl].[SalaryBudgetCodeDepartmentAssignment]
		WHERE [RemoveDate] IS NULL
		GROUP BY [SalaryBudgetCodeID]
	)
	, Organs AS (
		SELECT DISTINCT [SalaryBudgetCodeID] FROM [pbl].[SalaryBudgetCodeDepartmentAssignment]
		WHERE @DepartmentID IS NULL OR @DepartmentID = [DepartmentID]
	)
	, MainSelect AS(
		SELECT
			SalaryBudgetCode.[ID], 
			SalaryBudgetCode.[SerialNumber], 
			SalaryBudgetCode.[Name], 
			SalaryBudgetCode.[BudgetCode], 
			SalaryBudgetCode.[Type], 
			SalaryBudgetCode.[PaymentType], 
			SalaryBudgetCode.[Status], 
			SalaryBudgetCode.[PaymentDepartmentID], 
			department.[Name] as PaymentDepartmentName, 
			SalaryBudgetCode.[Comment], 
			SalaryBudgetCode.[CreatorUserID], 
			SalaryBudgetCode.[CreatorPositionID], 
			SalaryBudgetCode.[CreationDate], 
			PaymentOrganCount.DepartmentCount PaymentDepartmentCount,
			SalaryBudgetCode.[LastModifyUserID], 
			SalaryBudgetCode.[LastModifyPositionID], 
			SalaryBudgetCode.[ArchiveDate],
			SalaryBudgetCode.[isLock]
		FROM [pbl].[SalaryBudgetCode]
			INNER JOIN org._Department department ON department.ID = SalaryBudgetCode.[PaymentDepartmentID]
			LEFT JOIN PaymentOrganCount ON PaymentOrganCount.SalaryBudgetCodeID = SalaryBudgetCode.ID
			LEFT JOIN OPENJSON(@BudgetCodes) BudgetCodes ON BudgetCodes.value = SalaryBudgetCode.[BudgetCode]
			LEFT JOIN Organs ON Organs.SalaryBudgetCodeID = SalaryBudgetCode.ID
		WHERE (@SerialNumber IS NULL OR [SerialNumber] LIKE '%' + @SerialNumber + '%')
			AND (@BudgetCode IS NULL OR SalaryBudgetCode.[BudgetCode] = @BudgetCode)
			AND (@PaymentDepartmentID IS NULL OR SalaryBudgetCode.[PaymentDepartmentID] = @PaymentDepartmentID)
			AND (@Type < 1 OR [SalaryBudgetCode].[Type] = @Type)
			AND (@PaymentType < 1 OR [SalaryBudgetCode].[PaymentType] = @PaymentType)
			AND (@Status < 1 OR [SalaryBudgetCode].[Status] = @Status )
			AND (@BudgetCodes IS NULL OR BudgetCodes.value = SalaryBudgetCode.[BudgetCode])
			AND (@DepartmentID IS NULL OR Organs.SalaryBudgetCodeID IS NOT NULL)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY PaymentDepartmentName	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spLockCurrentSalaryBudgetCodeAndArchiveRest') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spLockCurrentSalaryBudgetCodeAndArchiveRest
GO

CREATE PROCEDURE pbl.spLockCurrentSalaryBudgetCodeAndArchiveRest 
	@ABudgetCode VARCHAR(20)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE 
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@LastValidBudgetCodeID UNIQUEIDENTIFIER
		SET @LastValidBudgetCodeID = (
			SELECT TOP(1) ID FROM [pbl].[SalaryBudgetCode]
			WHERE [BudgetCode] = @ABudgetCode
				AND [Status] = 10 AND [ArchiveDate] IS NULL
			ORDER BY [CreationDate]
		)
		UPDATE SBC
		SET [ArchiveDate] = GETDATE(), [isLock] = 1
		FROM [pbl].[SalaryBudgetCode] SBC
		WHERE ID <> @LastValidBudgetCodeID AND @ABudgetCode = SBC.BudgetCode  AND [ArchiveDate] IS NULL

		UPDATE SBC
		SET [isLock] = 1
		FROM [pbl].[SalaryBudgetCode] SBC
		WHERE ID = @LastValidBudgetCodeID
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spModifySalaryBudgetCode') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spModifySalaryBudgetCode
GO

CREATE PROCEDURE pbl.spModifySalaryBudgetCode  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(500),
	@ABudgetCode VARCHAR(10),
	@AType TINYINT,
	@APaymentType TINYINT,
	@AStatus TINYINT,
	@APaymentDepartmentID UNIQUEIDENTIFIER,
	@AComment NVARCHAR(Max),
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER

	
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(500) = LTRIM(RTRIM(@AName)),
		@BudgetCode  VARCHAR(10) = LTRIM(RTRIM(@ABudgetCode)),
		@SerialNumber VARCHAR(14),
		@Type TINYINT = COALESCE(@AType,0),
		@PaymentType TINYINT = COALESCE(@APaymentType, 0),
		@Status TINYINT = COALESCE(@AStatus, 0),
		@PaymentDepartmentID UNIQUEIDENTIFIER = @APaymentDepartmentID,
		@Comment NVARCHAR(Max) = LTRIM(RTRIM(@AComment)),
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Result INT = 0

		DECLARE @SerialNumberTable TABLE (SerialNumber VARCHAR(14))
		INSERT INTO @SerialNumberTable
		EXEC [pbl].[RandomIDGenerator] @Len = 14
		SELECT  @SerialNumber = SerialNumber FROM @SerialNumberTable

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [pbl].[SalaryBudgetCode]
				([ID], [SerialNumber], [Name], [BudgetCode], [Type], [PaymentType], [Status], [PaymentDepartmentID], [Comment], [CreatorUserID], [CreatorPositionID], [CreationDate], [LastModifyUserID], [LastModifyPositionID], [ArchiveDate], [isLock])
				VALUES
					(@ID, ([pbl].[fnRandomIDGenerator](10)), @Name, @BudgetCode, @Type, @PaymentType, @Status, @PaymentDepartmentID, @Comment, @CurrentUserID, @CurrentUserPositionID, GETDATE(), NULL, NUll, NUll, 0)
			END
			ELSE
			BEGIN
				UPDATE [pbl].[SalaryBudgetCode]
				SET
					[Name] = @Name,
					[BudgetCode] = @BudgetCode,
					[Type] = @Type,
					[PaymentType] = @PaymentType,
					[Status] = @Status,
					[PaymentDepartmentID] = @PaymentDepartmentID,
					[Comment] = @Comment,
					[LastModifyUserID] = @CurrentUserID,
					[LastModifyPositionID] = @CurrentUserPositionID,
					[ArchiveDate] = GETDATE()
				WHERE ID = @ID
			END		

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spUnlockCurrentSalaryBudgetCode') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spUnlockCurrentSalaryBudgetCode
GO

CREATE PROCEDURE pbl.spUnlockCurrentSalaryBudgetCode 
	@ABudgetCode VARCHAR(20)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE 
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@LastValidBudgetCodeID UNIQUEIDENTIFIER,
		@CountTreasuryRequest INT,
		@lock BIT = 0

		SET @LastValidBudgetCodeID = (
			SELECT TOP(1) ID FROM [pbl].[SalaryBudgetCode]
			WHERE [BudgetCode] = @ABudgetCode
				AND [Status] = 10 AND [ArchiveDate] IS NULL
			ORDER BY [CreationDate]
		)
		SET @CountTreasuryRequest = (
			SELECT COUNT(DISTINCT TR.ID) TRCount FROM [wag].[TreasuryRequest] TR
			INNER JOIN [pbl].[BaseDocument] BD ON BD.ID = TR.ID
			INNER JOIN [pbl].[DocumentFlow] LastFlow ON LastFlow.DocumentID = BD.ID AND LastFlow.ActionDate IS NULL
			INNER JOIN [pbl].[SalaryBudgetCode] SBC ON SBC.ID = TR.[SalaryBudgetCodeID]
			WHERE TR.[SalaryBudgetCodeID]  = @LastValidBudgetCodeID
				AND LastFlow.[ToDocState] < 100
				AND BD.RemoveDate IS NULL
		)

		IF @CountTreasuryRequest < 1
		BEGIN
			UPDATE SBC
			SET [isLock] = 0
			FROM [pbl].[SalaryBudgetCode] SBC
			WHERE ID  = @LastValidBudgetCodeID
		END
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spUpdateListSalaryBudgetCode') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spUpdateListSalaryBudgetCode
GO

CREATE PROCEDURE pbl.spUpdateListSalaryBudgetCode
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					[Name] NVARCHAR(100),
					[BudgetCode] VARCHAR(10),
					[Type] TINYINT,
					[PaymentType] TINYINT,
					[PaymentDepartmentID] UNIQUEIDENTIFIER
				)
			)
			INSERT INTO [pbl].[SalaryBudgetCode]
			([ID], [SerialNumber], [Name], [BudgetCode], [Type], [PaymentType], [Status], [PaymentDepartmentID], [CreatorUserID], [CreatorPositionID], [CreationDate], [isLock])
			SELECT 
				NEWID() ID,
				([pbl].[fnRandomIDGenerator](10)) [SerialNumber],
				Details.[Name] [Name],
				Details.[BudgetCode] [BudgetCode],
				Details.[Type] [Type],
				Details.[PaymentType] [PaymentType],
				10 [Status],
				Details.[PaymentDepartmentID] [PaymentDepartmentID],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID],
				GETDATE() [CreationDate],
				0 [isLock]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spUpdateStatusListSalaryBudgetCode') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spUpdateStatusListSalaryBudgetCode
GO

CREATE PROCEDURE pbl.spUpdateStatusListSalaryBudgetCode
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AStatus TINYINT,
	@ADetails NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Status TINYINT = COALESCE(@AStatus, 0),
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@isLock BIT,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @Status = 100
			BEGIN
				SET @isLock = 1
			END
			ELSE
			BEGIN
				SET @isLock = 0
			END
			Update BC
			SET
				[Status] = @Status,
				[LastModifyUserID] = @CurrentUserID,
				[LastModifyPositionID] = @CurrentPositionID,
				[isLock] = @isLock
			FROM [pbl].[SalaryBudgetCode] BC
			LEFT JOIN OPENJSON(@Details) Details ON Details.value = BC.ID
			WHERE(Details.value = BC.ID)

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spDeleteSalaryBudgetCodeDepartmentAssignment') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spDeleteSalaryBudgetCodeDepartmentAssignment
GO

CREATE PROCEDURE pbl.spDeleteSalaryBudgetCodeDepartmentAssignment
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			UPDATE [pbl].[SalaryBudgetCodeDepartmentAssignment]
			SET [RemoveDate] = GETDATE(), [RemoverUserID] = @CurrentUserID , RemoverPositionID = @CurrentUserPositionID
			FROM [pbl].[SalaryBudgetCodeDepartmentAssignment]
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		 SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetSalaryBudgetCodeDepartmentAssignment') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spGetSalaryBudgetCodeDepartmentAssignment
GO

CREATE PROCEDURE pbl.spGetSalaryBudgetCodeDepartmentAssignment 
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		SBCDA.[ID], 
		SBCDA.[SalaryBudgetCodeID], 
		SBC.[BudgetCode] SalaryInputBudgetCode, 
		SBCDA.[DepartmentID], 
		department.[Name] AS DepartmentName, 
		SBCDA.[CreatorUserID], 
		SBCDA.[CreatorPositionID], 
		SBCDA.[CreationDate], 
		SBCDA.[RemoverUserID], 
		SBCDA.[RemoverPositionID], 
		SBCDA.[RemoveDate]
	FROM [pbl].[SalaryBudgetCodeDepartmentAssignment] SBCDA
		INNER JOIN [pbl].[SalaryBudgetCode] SBC ON SBC.ID = SBCDA.[SalaryBudgetCodeID]
		INNER JOIN org._Department department on department.ID = SBCDA.DepartmentID
	WHERE SBCDA.ID = @ID
	AND SBCDA.[RemoveDate] IS NULL
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetSalaryBudgetCodeDepartmentAssignments') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetSalaryBudgetCodeDepartmentAssignments
GO

CREATE PROCEDURE pbl.spGetSalaryBudgetCodeDepartmentAssignments
	@ASalaryBudgetCodeID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@SalaryBudgetCodeID UNIQUEIDENTIFIER = @ASalaryBudgetCodeID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS(
		SELECT
			SBCDA.[ID], 
			SBCDA.[SalaryBudgetCodeID], 
			SBC.[BudgetCode] SalaryInputBudgetCode, 
			SBCDA.[DepartmentID], 
			department.[Name] AS DepartmentName, 
			SBCDA.[CreatorUserID], 
			SBCDA.[CreatorPositionID], 
			SBCDA.[CreationDate], 
			SBCDA.[RemoverUserID], 
			SBCDA.[RemoverPositionID], 
			SBCDA.[RemoveDate]
		FROM [pbl].[SalaryBudgetCodeDepartmentAssignment] SBCDA
			INNER JOIN [pbl].[SalaryBudgetCode] SBC ON SBC.ID = SBCDA.[SalaryBudgetCodeID]
			INNER JOIN org._Department department on department.ID = SBCDA.DepartmentID
		WHERE (SBCDA.[RemoveDate] IS NULL)
			AND (@SalaryBudgetCodeID IS NULL OR [SalaryBudgetCodeID]  = @SalaryBudgetCodeID)
			AND (@DepartmentID IS NULL OR [DepartmentID] = @DepartmentID)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY DepartmentName	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spModifySalaryBudgetCodeDepartmentAssignment') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spModifySalaryBudgetCodeDepartmentAssignment
GO

CREATE PROCEDURE pbl.spModifySalaryBudgetCodeDepartmentAssignment  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ASalaryBudgetCodeID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ADepartmentIDs NVARCHAR(MAX),
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER

	
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@SalaryBudgetCodeID UNIQUEIDENTIFIER = @ASalaryBudgetCodeID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@DepartmentIDs NVARCHAR(MAX) = @ADepartmentIDs,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Result INT = 0


		DECLARE @T1 TABLE (ID UNIQUEIDENTIFIER)
		INSERT INTO @T1
		SELECT 
			VALUE AS ID
		FROM OPENJSON(@DepartmentIDs)
		GROUP BY
		VALUE

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
			INSERT INTO [pbl].[SalaryBudgetCodeDepartmentAssignment]
			SELECT
				NEWID() AS [ID], 
				@SalaryBudgetCodeID AS [SalaryBudgetCodeID], 
				t1.ID AS [DepartmentID], 
				@CurrentUserID AS [CreatorUserID], 
				@CurrentUserPositionID AS [CreatorPositionID], 
				GETDATE() AS[CreationDate], 
				NULL AS [RemoverUserID], 
				NULL AS [RemoverPositionID], 
				NULL AS [RemoveDate]
			FROM @T1 t1
			END
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spUpdateListSalaryBudgetCodeDepartmentAssignment') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spUpdateListSalaryBudgetCodeDepartmentAssignment
GO

CREATE PROCEDURE pbl.spUpdateListSalaryBudgetCodeDepartmentAssignment
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					[SalaryBudgetCodeID] UNIQUEIDENTIFIER,
					[DepartmentID] UNIQUEIDENTIFIER
				)
			)
			INSERT INTO [pbl].[SalaryBudgetCodeDepartmentAssignment]
			([ID], [SalaryBudgetCodeID], [DepartmentID], [CreatorUserID], [CreatorPositionID], [CreationDate])
			SELECT 
				NEWID() ID,
				Details.[SalaryBudgetCodeID] [SalaryBudgetCodeID],
				Details.[DepartmentID] [DepartmentID],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID],
				GETDATE() [CreationDate]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spConfirmTagGroup') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spConfirmTagGroup
GO

CREATE PROCEDURE pbl.spConfirmTagGroup
	@AID UNIQUEIDENTIFIER,
	@AOrder INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Order TINYINT = COALESCE(@AOrder,0),

		@FiledGroupID UNIQUEIDENTIFIER,
		@FiledName NVARCHAR,
		@FiledOrder INT,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			UPDATE TagGroup
			SET
				[State] = 100,
				[Order] = @Order
			FROM [pbl].[TagGroup]
			WHERE ID = @ID

			--SET @FiledName = (SELECT TOP(1) [Name] FROM [pbl].[TagGroup] WHERE [ID] = @ID)
			--SET @FiledGroupID = (SELECT TOP(1) [ID] FROM [pbl].[TagGroup] WHERE [Name] = N'گروه های نمایشی')
			--SET @FiledOrder = (SELECT MAX([Order]) FROM [rpt].[Field] WHERE [GroupID] = @FiledGroupID)

			--INSERT INTO [rpt].[Field]
			--([ID], [GroupID], [Name], [PersianName], [Type], [EnumName], [CreationDate], [Order], [DefaultFunction])
			--VALUES
			--(NEWID(), @FiledGroupID, CONCAT('G', @Order), @FiledName, 1, NULL, GETDATE(), @FiledOrder, 0)

		COMMIT
	END TRY
	BEGIN CATCH
		 SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spDeleteTagGroup') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spDeleteTagGroup
GO

CREATE PROCEDURE pbl.spDeleteTagGroup
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@FiledGroupID UNIQUEIDENTIFIER,
		@FiledOrder INT,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			UPDATE TagGroup
			SET
				[Order] = 0,
				[State] = 1,
				[RemoveDate] = GETDATE(),
				[RemoverUserID] = @CurrentUserID
			FROM [pbl].[TagGroup]
			WHERE ID = @ID

			
			SET @FiledOrder = (SELECT TOP(1) [Order] FROM [pbl].[TagGroup] WHERE [ID] = @ID)
			SET @FiledGroupID = (SELECT TOP(1) [ID] FROM [pbl].[TagGroup] WHERE [Name] = N'گروه های نمایشی')

			DELETE FROM [rpt].[Field] WHERE [GroupID] = @FiledGroupID AND [Name] = CONCAT('G', @FiledOrder)
		COMMIT
	END TRY
	BEGIN CATCH
		 SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetTagGroup') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spGetTagGroup
GO

CREATE PROCEDURE pbl.spGetTagGroup 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		[ID],
		[Code],
		[Order],
		[Name],
		[Title],
		[Type],
		[State],
		[DataUpdateDate]
	FROM [pbl].[TagGroup]
	WHERE ID = @ID
END 


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetTagGroups') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetTagGroups
GO

CREATE PROCEDURE pbl.spGetTagGroups
	@ACode CHAR(20),
	@AName NVARCHAR(500),
	@ATitle VARCHAR(500),
	@AType TINYINT,
	@AState TINYINT,
	@AFromDataUpdateDate DATETIME,
	@AToDataUpdateDate DATETIME,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@Name NVARCHAR(500) = LTRIM(RTRIM(@AName)),
		@Title NVARCHAR(500) = LTRIM(RTRIM(@ATitle)),
		@Type TINYINT = COALESCE(@AType, 0),
		@State TINYINT = COALESCE(@AState, 0),
		@FromDataUpdateDate DATETIME = @AFromDataUpdateDate,
		@ToDataUpdateDate DATETIME = @AToDataUpdateDate,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS(
		SELECT
			[ID],
			[Code],
			[Order],
			[Name],
			[Title],
			[Type],
			[State],
			[CreationDate],
			[DataUpdateDate]
		FROM [pbl].[TagGroup]
		WHERE ([RemoveDate] IS NULL)
			AND (@Code IS NULL OR Code = @Code)
			AND (@Name IS NULL OR [Name] LIKE '%' + @Name + '%')
			AND (@Title IS NULL OR [Title] LIKE '%' + @Title + '%')
			AND (@Type < 1 OR [Type] = @Type)
			AND (@State < 1 OR [State] = @State)
			AND (@FromDataUpdateDate IS NULL OR [DataUpdateDate] >= @FromDataUpdateDate)
			AND (@ToDataUpdateDate IS NULL OR [DataUpdateDate] <= @ToDataUpdateDate)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY Code	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 

GO
USE [Kama.Aro.Pardakht]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spModifyTagGroup') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spModifyTagGroup
GO

CREATE PROCEDURE pbl.spModifyTagGroup  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ACode VARCHAR(20),
	@AName NVARCHAR(500),
	@ATitle NVARCHAR(500),
	@AType TINYINT,
	@AState TINYINT,
	@AOrder INT,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER

	
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@Name NVARCHAR(500) = LTRIM(RTRIM(@AName)),
		@Title NVARCHAR(500) = LTRIM(RTRIM(@ATitle)),
		@Type TINYINT = COALESCE(@AType,0),
		@State TINYINT = COALESCE(@AState,0),
		@Order TINYINT = COALESCE(@AOrder,0),
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@Result INT = 0


	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [pbl].[TagGroup]
					([ID], [Code], [Order], [Name], [Title], [Type], [State], [CreatorUserID], [CreatorPositionID], [CreationDate], [DataUpdateDate], [RemoveDate], [RemoverUserID])
				VALUES
					(@ID, @Code, @Order, @Name, @Title, @Type, @State, @CurrentUserID, @CurrentUserPositionID, GETDATE(), NULL, NULL, NULL)
			END
			ELSE
			BEGIN
				UPDATE [pbl].[TagGroup]
				SET
					[Code] = @Code,
					[Name] = @Name,
					[Title] = @Title,
					[Type] = @Type,
					[State] = @State,
					[Order] = @Order
				WHERE ID = @ID
			END		

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spDeleteTagItem') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spDeleteTagItem
GO

CREATE PROCEDURE pbl.spDeleteTagItem
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM [pbl].[TagItem] WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		 SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetTagItem') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spGetTagItem
GO

CREATE PROCEDURE pbl.spGetTagItem 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@GroupType TINYINT = 0

	SET @GroupType = (SELECT TagGroup.[Type] FROM [pbl].[TagItem] TagItem INNER JOIN [pbl].[TagGroup]TagGroup ON TagGroup.[ID] = TagItem.[TagGroupID] WHERE TagItem.[ID] = @ID)
	IF @GroupType = 1 -- WageTitle
	BEGIN
		SELECT
			TagItem.[ID],
			TagItem.[TagGroupID],
			TagGroup.[Name] AS GroupName,
			TagGroup.[Code] AS GroupCode,
			TagItem.[ItemID],
			WageTitle.[Name],
			WageTitle.[Code]
		FROM [pbl].[TagItem] TagItem
			INNER JOIN [pbl].[TagGroup] TagGroup ON TagGroup.[ID] = TagItem.[TagGroupID]
			INNER JOIN [wag].[WageTitle] WageTitle ON WageTitle.[ID] = TagItem.[ItemID]
		WHERE TagItem.[ID] = @ID
	END
	
END 


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetTagItems') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetTagItems
GO

CREATE PROCEDURE pbl.spGetTagItems
	@ATagGroupID UNIQUEIDENTIFIER,
	@AName NVARCHAR(500),
	@ACode VARCHAR(10),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@TagGroupID UNIQUEIDENTIFIER = @ATagGroupID,
		@Name NVARCHAR(500) = LTRIM(RTRIM(@AName)),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@GroupType TINYINT = 0

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SET @GroupType = (SELECT TagGroup.[Type] FROM [pbl].[TagGroup] TagGroup	WHERE TagGroup.[ID] = @TagGroupID)

	;WITH WageTitleTagGroup AS(
		SELECT
			TagItem.[ID],
			WageTitle.[ID] [ItemID],
			TagItem.[TagGroupID],
			TagGroup.[Name] AS GroupName,
			TagGroup.[Code] AS GroupCode,
			WageTitle.[Name],
			WageTitle.[Code]
		FROM [wag].[WageTitle] WageTitle
			LEFT JOIN [pbl].[TagItem] TagItem ON WageTitle.[ID] = TagItem.[ItemID]
			LEFT JOIN [pbl].[TagGroup] TagGroup ON TagGroup.[ID] = TagItem.[TagGroupID] 
		WHERE @GroupType = 1
			AND (TagItem.[TagGroupID] IS NULL OR TagItem.[TagGroupID] = @TagGroupID)
			AND (@Code IS NULL OR WageTitle.[Code] = @Code)
			AND (@Name IS NULL OR WageTitle.[Name] LIKE '%' + @Name + '%')
		
	)
	--, OtherTagGroup AS(
	--	SELECT
	--		TagItem.[ID],
	--		TagItem.[TagGroupID],
	--		TagGroup.[Name] AS GroupName,
	--		TagGroup.[Code] AS GroupCode,
	--		TagItem.[ItemID],
	--		WageTitle.[Name],
	--		WageTitle.[Code],
	--		TagItem.[CreationDate]
	--	FROM [pbl].[TagItem] TagItem
	--		INNER JOIN [pbl].[TagGroup] TagGroup ON TagGroup.[ID] = TagItem.[TagGroupID] 
	--		INNER JOIN [wag].[WageTitle] WageTitle ON WageTitle.[ID] = TagItem.[ItemID]
	--	WHERE (TagItem.[TagGroupID] = @TagGroupID)
	--		AND (@Code IS NULL OR WageTitle.[Code] = @Code)
	--		AND (@Name IS NULL OR WageTitle.[Name] LIKE '%' + @Name + '%')
	--		AND ((@GroupType = 2))
		
	--)
	, MainSelect AS
	(
		SELECT * FROM WageTitleTagGroup
		--UNION
		--SELECT * FROM GroupType2
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY Code	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 

GO
USE [Kama.Aro.Pardakht]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spModifyTagItem') AND type in (N'P', N'PC'))
    DROP PROCEDURE pbl.spModifyTagItem
GO

CREATE PROCEDURE pbl.spModifyTagItem
	@ATagGroupID UNIQUEIDENTIFIER,
	@AItemIDs NVARCHAR(MAX)

	
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@TagGroupID UNIQUEIDENTIFIER = @ATagGroupID,
		@ItemIDs NVARCHAR(MAX) = @AItemIDs,
		@Result INT = 0


	BEGIN TRY
		BEGIN TRAN

			DELETE [pbl].[TagItem] WHERE [TagGroupID] = @TagGroupID

			INSERT INTO [pbl].[TagItem]
				([ID], [TagGroupID], [ItemID])
			SELECT 
				NEWID() [ID],
				@TagGroupID [TagGroupID],
				value [ItemID]
			FROM OPENJSON(@ItemIDs)
			

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeleteUserAttachment'))
	DROP PROCEDURE pbl.spDeleteUserAttachment
GO

CREATE PROCEDURE pbl.spDeleteUserAttachment
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID
				
	BEGIN TRY
		BEGIN TRAN
			
			DELETE FROM [pbl].[UserAttachment]
			WHERE [ID] = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetUserAttachment'))
	DROP PROCEDURE pbl.spGetUserAttachment
GO

CREATE PROCEDURE pbl.spGetUserAttachment
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID

	SELECT
		UserAttachment.[ID],
		UserAttachment.[AttachmentID],
		Attachment.[Comment] [AttachmentComment],
		UserAttachment.[UserID],
		u.[NationalCode],
		u.[FirstName],
		u.[LastName],
		UserAttachment.[Type],
		UserAttachment.[DownloadCode]
	FROM [pbl].[UserAttachment] UserAttachment
		INNER JOIN [pbl].[Attachment] Attachment ON Attachment.[ID] = UserAttachment.[AttachmentID]
		INNER JOIN [org].[User] u ON u.[ID] = UserAttachment.[UserID]
	WHERE UserAttachment.[ID] = @ID AND UserAttachment.[UserID] = @CurrentUserID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetUserAttachments'))
DROP PROCEDURE pbl.spGetUserAttachments
GO

CREATE PROCEDURE pbl.spGetUserAttachments
	@AAttachmentID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ANationalCode VARCHAR (18),
	@ADownloadCode VARCHAR (20),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@AttachmentID UNIQUEIDENTIFIER = @AAttachmentID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@Type TINYINT = COALESCE(@AType, 0),
		@NationalCode VARCHAR(18) = LTRIM(RTRIM(@ANationalCode)),
		@DownloadCode VARCHAR(20) = LTRIM(RTRIM(@ADownloadCode)),

		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			UserAttachment.[ID],
			UserAttachment.[AttachmentID],
			Attachment.[Comment] [AttachmentComment],
			UserAttachment.[UserID],
			u.[NationalCode],
			u.[FirstName],
			u.[LastName],
			UserAttachment.[Type],
			UserAttachment.[DownloadCode]
		FROM [pbl].[UserAttachment] UserAttachment
			INNER JOIN [pbl].[Attachment] Attachment ON Attachment.[ID] = UserAttachment.[AttachmentID]
			INNER JOIN [org].[User] u ON u.[ID] = UserAttachment.[UserID]
		WHERE (@AttachmentID IS NULL OR UserAttachment.[AttachmentID] = @AttachmentID)
			AND (UserAttachment.[UserID] = @UserID)
			AND (@Type < 1 OR UserAttachment.[Type] = @Type)
			AND (@NationalCode IS NULL OR u.[NationalCode] = @NationalCode)
			AND (@DownloadCode IS NULL OR UserAttachment.[DownloadCode] = @DownloadCode)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY [DownloadCode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyUserAttachment'))
	DROP PROCEDURE pbl.spModifyUserAttachment
GO

CREATE PROCEDURE pbl.spModifyUserAttachment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AAttachmentID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ADownloadCode VARCHAR (20)

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@AttachmentID UNIQUEIDENTIFIER = @AAttachmentID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@Type TINYINT = COALESCE(@AType, 0),
		@DownloadCode VARCHAR(20) = LTRIM(RTRIM(@ADownloadCode))


	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO[pbl].[UserAttachment]
				([ID], [AttachmentID], [UserID], [Type], [DownloadCode])
				VALUES
				(@ID, @AttachmentID, @UserID, @Type, @DownloadCode)

			END
			ELSE
			BEGIN
				
				UPDATE [pbl].[UserAttachment]
				SET
				 [Type] = @Type
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spCreateDepartmentReport') IS NOT NULL
    DROP PROCEDURE rpt.spCreateDepartmentReport
GO

CREATE PROCEDURE rpt.spCreateDepartmentReport
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
		
	;with Employee as (
		select
			count(*) as [Count],
			OrganID
		from 
			pbl.Employee
		group by
			OrganID
	--), Post as (
	--	select
	--		COUNT(*) as [Count],
	--		chart.OrganID	
	--	from	
	--		[Kama.Aro.Sakhtar].chr.Post as post
	--		inner join [Kama.Aro.Sakhtar].chr.Unit as unit on unit.ID = post.UnitID
	--		inner join [Kama.Aro.Sakhtar].chr.Chart as chart on chart.ID = unit.ChartID
	--		inner join [Kama.Aro.Sakhtar].pbl.BaseDocument as doc on doc.ID = chart.ID
	--	where
	--		doc.RemoverID is null
	--		and chart.ApprovedChart = 1
	--		and unit.Deleted = 0
	--		and unit.RemoverPositionID is null
	--		and post.Deleted = 0
	--		and post.RemoverPositionID is null
	--	group by
	--		chart.OrganID
	--), AmarGharardadi as (
	--	select 
	--		count(*) as [Count],
	--		OrgCode
	--	from
	--		[AmarDB93].[dbo].[tblPersonel]
	--	where 
	--		[EmpType] in (3, 4, 5) -- قراردادی
	--	group by
	--		OrgCode
	--), AmarRasmiPeymani as (
	--	select 
	--		count(*) as [Count],
	--		OrgCode
	--	from
	--		[AmarDB93].[dbo].[tblPersonel]
	--	where 
	--		[EmpType] in (1, 2) -- رسمی و پیمانی
	--	group by
	--		OrgCode
	--), Form6Gharardadi as (
	--	select 
	--		count(*) as [Count],
	--		OrgCode
	--	from
	--		[Form6DB].[dbo].[tblPersonel]
	--	where 
	--		[EmpType] in (3, 4, 5) -- قراردادی
	--	group by
	--		OrgCode
	--), Form6RasmiPeymani as (
	--	select 
	--		count(*) as [Count],
	--		OrgCode
	--	from
	--		[Form6DB].[dbo].[tblPersonel]
	--	where 
	--		[EmpType] in (1, 2) -- رسمی و پیمانی
	--	group by
	--		OrgCode
	--), Gharardadi as (
	--	select
	--		coalesce(amarGharardadi.[Count], 0) + coalesce(form6Gharardadi.[Count], 0) as [Count],
	--		coalesce(amarGharardadi.OrgCode, form6Gharardadi.OrgCode) as OrgCode
	--	from
	--		AmarGharardadi as amarGharardadi
	--		left join Form6Gharardadi as form6Gharardadi on form6Gharardadi.OrgCode = amarGharardadi.OrgCode
	--), RasmiPeymani as (
	--	select
	--		coalesce(amarRasmiPeymani.[Count], 0) + coalesce(form6RasmiPeymani.[Count], 0) as [Count],
	--		coalesce(amarRasmiPeymani.OrgCode, form6RasmiPeymani.OrgCode) as OrgCode
	--	from
	--		AmarRasmiPeymani as amarRasmiPeymani
	--		left join Form6RasmiPeymani as form6RasmiPeymani on form6RasmiPeymani.OrgCode = amarRasmiPeymani.OrgCode
	)

	select
		-- Department
		department.ID as DepartmentID,
		department.[Name] as DepartmentName, -- نام دستگاه اجرایی
		parentDepartment1.[ID] as FirstParentDepartmentID,
		parentDepartment1.[Name] as FirstParentDepartmentName, -- نام دستگاه مادر سطح 1
		parentDepartment2.[ID] as SecondParentDepartmentID,
		parentDepartment2.[Name] as SecondParentDepartmentName, -- نام دستگاه مادر سطح 2
		departmentCategory.[Name] as DepartmentCategoryName, -- نام قوه
		departmentCategory.ID as DepartmentCategoryID,

		-- Salary
		employee.[Count] as EmployeeCount, -- تعداد کل کارکنان سامانه ثبت حقوق و مزایا
		law.[Name] as LawName, -- قوانین پرداخت
		law.ID LawID,

		-- Estekhdam
		COALESCE(_Amar.RasmiPeymaniCount, 0) + COALESCE(_Form6.RasmiPeymaniCount, 0) as RasmiPeymaniCount, -- تعداد کارکنان رسمی-پیمانی
		COALESCE(_Amar.GharardadiCount, 0) + COALESCE(_Form6.GharardadiCount, 0) as ContractCount, -- تعداد کارکنان قراردادی

		-- Sakhtar
		_OrganPost.[Count] as PostCount -- تعداد پست‌های سازمانی
	INTO #DepartmentReport
	from
		org.Department as department
		left join org.Department as parentDepartment1 on parentDepartment1.[Node] = department.[Node].GetAncestor(1) and parentDepartment1.[Type] <> 10
		left join org.Department as parentDepartment2 on parentDepartment2.[Node] = department.[Node].GetAncestor(2) and parentDepartment2.[Type] <> 10
		left join org.Department as departmentCategory on department.[Node].IsDescendantOf(departmentCategory.[Node]) = 1 and departmentCategory.[Node].GetAncestor(1) = 0x and departmentCategory.[Type] = 10
		left join Employee as employee on employee.OrganID = department.ID
		left join law.OrganLaw as organLaw on organLaw.OrganID = department.ID and organLaw.[Enabled] = 1
		left join law.Law as law on law.ID = organLaw.LawID
		left join pbl.DocumentFlow as lastFlow on lastFlow.DocumentID = organLaw.ID and lastFlow.ActionDate is null and lastFlow.ToDocState = 100
		left join chr._OrganPost on _OrganPost.OrganID = department.ID
		left join dbo._Amar on _Amar.OrgCode collate Persian_100_CI_AI = department.BudgetCode
		left join dbo._Form6 on _Form6.OrgCode collate Persian_100_CI_AI = department.BudgetCode
	where
		department.[Type] <> 10 -- دسته‌بندی دستگاه نباشد

	order by
		departmentCategory.[Name],
		parentDepartment1.[Name],
		parentDepartment2.[Name],
		department.[Name]

    IF OBJECT_ID('rpt.DepartmentReport') IS NOT NULL
		DROP TABLE rpt.DepartmentReport

	SELECT *
	INTO rpt.DepartmentReport
	FROM #DepartmentReport

END

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetDepartmentReport') IS NOT NULL
    DROP PROCEDURE wag.spGetDepartmentReport
GO

CREATE PROCEDURE wag.spGetDepartmentReport
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACategoryDepartmentID UNIQUEIDENTIFIER,
	@AParentDepartmentID1 UNIQUEIDENTIFIER,
	@AParentDepartmentID2 UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CategoryDepartmentID UNIQUEIDENTIFIER = @ACategoryDepartmentID,
		@ParentDepartmentID1 UNIQUEIDENTIFIER = @AParentDepartmentID1,
		@ParentDepartmentID2 UNIQUEIDENTIFIER = @AParentDepartmentID2,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@LawID UNIQUEIDENTIFIER = @ALawID	

	SELECT  * 
	FROM rpt.DepartmentReport
	WHERE (@ParentDepartmentID1 IS NUll OR FirstParentDepartmentID = @ParentDepartmentID1)
		AND (@ParentDepartmentID2 IS NUll OR SecondParentDepartmentID = @ParentDepartmentID2)
		AND (@CategoryDepartmentID IS NUll OR DepartmentCategoryID = @CategoryDepartmentID)
		AND (@DepartmentID IS NUll OR DepartmentID = @DepartmentID)
		AND (@LawID IS NUll OR LawID = @LawID)

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetEmployeeReport') IS NOT NULL
    DROP PROCEDURE wag.spGetEmployeeReport
GO

CREATE PROCEDURE wag.spGetEmployeeReport
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APostLevel TINYINT,
	@AJobBase TINYINT,
	@AEducationDegree TINYINT,
	@AEmploymentType TINYINT,
	@AServiceYearsType TINYINT,
	@ANationalCode VARCHAR(10),
	@APaymentFrom INT,
	@APaymentTo INT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@AName NVARCHAR(1000),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@JobBase TINYINT = COALESCE(@AJobBase, 0),
		@EducationDegree TINYINT = COALESCE(@AEducationDegree, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@ServiceYearsType TINYINT = COALESCE(@AServiceYearsType, 0),
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@PaymentFrom INT = @APaymentFrom,
		@PaymentTo INT = @APaymentTo,
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH Organ AS
	(
		SELECT ID, Code, Name
		FROM org.Department
		WHERE Node.IsDescendantOf(@ParentOrganNode) = 1
	)
	, Payroll AS
	(
		SELECT payroll.ID, OrganID, LawID, [Year], [Month]
		FROM wag.Payroll
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
		WHERE doc.RemoveDate IS NULL
			AND (@OrganID IS NULL OR Payroll.OrganID = @OrganID)
			AND (@LawID IS NULL OR Payroll.LawID = @LawID)
			AND (@Year < 1 OR [Year] = @Year)
			AND (@Month < 1 OR [Month] = @Month)
	)
	, PayrollEmployee AS
	(
		SELECT PayrollID, EmployeeID, SumPayments, SumDeductions,SumPayments-SumDeductions [Sum] 
		FROM wag.PayrollEmployee
		--WHERE 
		--	(@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
		--	AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
		--	AND (@EducationDegree < 1 OR PayrollEmployee.EducationDegree = @EducationDegree)
		--	AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
		--	AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
		--	AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
	)
	, MainSelect AS
	(
		select 
			PayrollEmployee.EmployeeID,
			PayrollEmployee.SumPayments,
			PayrollEmployee.SumDeductions,
			PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions [Sum],
			Payroll.ID PayrollID,
			Payroll.[Year],
			Payroll.[Month],
			payroll.OrganID,
			Organ.Code OrganCode,
			Organ.Name OrganName
		FROM PayrollEmployee 
			INNER JOIN Payroll on PayrollEmployee.PayrollID = payroll.id
			INNER JOIN Organ on Organ.ID = payroll.OrganID
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	, PagedSelect AS 
	(
		SELECT 
			MainSelect.* ,
			EmployeeDetail.FirstName,
			EmployeeDetail.LastName,
			EmployeeDetail.NationalCode,
			lastFlow.ToDocState LastDocState
		FROM MainSelect
			INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = MainSelect.EmployeeID
			INNER JOIN pbl.DocumentFlow lastFlow ON lastFlow.DocumentID = MainSelect.PayrollID and lastflow.ActionDate is null
		ORDER BY Year Desc, Month DESC, OrganName--, LastName, FirstName
		OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	)
	SELECT *
	FROM PagedSelect, Total

END
GO
USE [Kama.Aro.Pardakht]
GO
IF EXISTS(SELECT 1 FROM sys.Procedures WHERE [object_id] = OBJECT_ID('wag.spGetEmployeesPerPayroll'))
    DROP PROCEDURE wag.spGetEmployeesPerPayroll
GO

CREATE PROCEDURE wag.spGetEmployeesPerPayroll
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYearFrom SMALLINT,
	@AMonthFrom TINYINT,
	@AYearTo SMALLINT,
	@AMonthTo TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@YearFrom SMALLINT = COALESCE(@AYearFrom, 0),
		@MonthFrom TINYINT = COALESCE(@AMonthFrom, 0),
		@YearTo SMALLINT = COALESCE(@AYearTo, 0),
		@MonthTo TINYINT = COALESCE(@AMonthTo, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH EmployeeCount AS
	(
		SELECT OrganID, ID, Count(*) Cnt
		FROM pbl.Employee
		GROUP BY OrganID , ID
	)
	, EmployeeInPayroll AS
	(
		SELECT 
			COUNT(DISTINCT Employee.ID) Cnt,
			Employee.OrganID,
			ind.FirstName + ' ' + ind.LastName FullName,
			payroll.ID PayrollID,
			dep.[Name] DepartmentName,
			law.[Name] LawName,
 			payroll.LawID PayrollLawID
		FROM wag.PayrollEmployee
			INNER JOIN pbl.Employee ON employee.ID = PayrollEmployee.EmployeeID
			INNER JOIN wag.Payroll ON payroll.ID = PayrollEmployee.PayrollID
			INNER JOIN org.Department dep ON dep.ID = Payroll.OrganID
			INNER JOIN law.Law law ON law.ID = Payroll.LawID
			INNER JOIN pbl.BaseDocument doc ON Payroll.ID = doc.ID
			INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
			INNER JOIN org.Individual ind ON ind.ID = Employee.IndividualID
		WHERE doc.RemoveDate IS NULL
			AND (Payroll.[Year] > @YearFrom OR (Payroll.[Year] = @YearFrom AND payroll.[Month] >= @MonthFrom))
			AND (Payroll.[Year] < @YearTo OR (Payroll.[Year] = @YearTo AND payroll.[Month] <= @MonthTo))
		GROUP BY Employee.OrganID , ind.LastName , ind.FirstName ,payroll.ID ,payroll.LawID ,dep.[Name] , law.[Name]
	)
	
	, MainSelect AS 
	(
		SELECT 
			Count(*) OVER() Total,
			EmployeeCount.Cnt EmployeeCount,
			EmployeeInPayroll.Cnt EmployeeInPayrollCount,
			EmployeeInPayroll.FullName,
			EmployeeInPayroll.PayrollID,
			EmployeeInPayroll.PayrollLawID,
			EmployeeInPayroll.OrganID,
			EmployeeInPayroll.DepartmentName,
			EmployeeInPayroll.LawName
		FROM EmployeeInPayroll 
			LEFT JOIN EmployeeCount ON EmployeeCount.OrganID = EmployeeInPayroll.OrganID
		WHERE
			@OrganID IS NULL OR EmployeeInPayroll.OrganID = @OrganID
	)
	SELECT * FROM MainSelect
	Order BY FullName
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetMaxPaymentPerOrgans') IS NOT NULL
    DROP PROCEDURE wag.spGetMaxPaymentPerOrgans
GO

CREATE PROCEDURE wag.spGetMaxPaymentPerOrgans
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APostLevel TINYINT,
	@AJobBase TINYINT,
	@AEducationDegree TINYINT,
	@AEmploymentType TINYINT,
	@AServiceYearsType TINYINT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@JobBase TINYINT = COALESCE(@AJobBase, 0),
		@EducationDegree TINYINT = COALESCE(@AEducationDegree, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@ServiceYearsType TINYINT = COALESCE(@AServiceYearsType, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@UserID UNIQUEIDENTIFIER,
		@ParentOrganNode HIERARCHYID
		
	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	IF @OrganID = 0x SET @OrganID = NULL
	IF @LawID = 0x SET @LawID = NULL

	;WITH MainSelect AS
	(
		select 
			[Year],
			[Month],
			[Payroll].OrganID,
			Organ.Name OrganName,
			MAX(payroll.Maximum) Maximum
		FROM wag.payroll
			inner join pbl.BaseDocument doc on doc.ID = Payroll.ID
			inner join org.Department Organ on Organ.ID = payroll.OrganID
		where doc.RemoveDate is null
			AND Organ.Node.IsDescendantOf(@ParentOrganNode) = 1
		Group BY 
			[Year],
			[Month],
			[Payroll].OrganID,
			Organ.Name
	)
	SELECT 
		COUNT(*) OVER() Total,
		Payroll.[Year],
		Payroll.[Month],
		OrganName,
		EmployeeDetail.FirstName,
		EmployeeDetail.LastName,
		EmployeeDetail.NationalCode,
		MAX((PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions)) Sum
	FROM MainSelect
		INNER JOIN wag.payroll on payroll.OrganID = MainSelect.OrganID AND payroll.Maximum = MainSelect.Maximum
		INNER JOIN pbl.BaseDocument doc on doc.ID = Payroll.ID
		INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
		INNER JOIN wag.PayrollEmployee on PayrollEmployee.PayrollID = Payroll.id and (PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions) = Payroll.Maximum
		INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = PayrollEmployee.EmployeeID
	where doc.RemoveDate is null
		--AND (@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
		AND (@OrganID IS NULL OR Payroll.OrganID = @OrganID)
		AND (@LawID IS NULL OR Payroll.LawID = @LawID)
		AND (@Year < 1 OR Payroll.[Year] = @Year)
		AND (@Month < 1 OR Payroll.[Month] = @Month)
		--AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
		--AND (@EducationDegree < 1 OR PayrollEmployee.EducationDegree = @EducationDegree)
		--AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
		--AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
		--AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
	Group by Payroll.[Year],
		Payroll.[Month],
		OrganName,
		EmployeeDetail.FirstName,
		EmployeeDetail.LastName,
		EmployeeDetail.NationalCode
	ORDER BY NationalCode,Payroll.month desc, OrganName, LastName, FirstName
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetOrgansProgressReport') IS NOT NULL
DROP PROCEDURE wag.spGetOrgansProgressReport
GO

CREATE PROCEDURE wag.spGetOrgansProgressReport
	@AOrganID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@ADepartmentType TINYINT,
	@ADepartmentSubType TINYINT,
	@ALawID UNIQUEIDENTIFIER,
	@AReportType TINYINT,
	@AYearFrom SMALLINT,
	@AMonthFrom TINYINT,
	@AYearTo SMALLINT,
	@AMonthTo TINYINT,
	@ASearchWithhierarchy BIT,
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@DepartmentType TINYINT = COALESCE(@ADepartmentType, 0),
		@DepartmentSubType TINYINT = COALESCE(@ADepartmentSubType, 0),
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@ReportType TINYINT = COALESCE(@AReportType, 0),
		@YearFrom SMALLINT = COALESCE(@AYearFrom, 0),
		@MonthFrom TINYINT = COALESCE(@AMonthFrom, 0),
		@YearTo SMALLINT = COALESCE(@AYearTo, 0),
		@MonthTo TINYINT = COALESCE(@AMonthTo, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID,
		@MonthsWithPayroll INT,
		@MonthsDay INT,
		@SearchWithhierarchy BIT = COALESCE(@ASearchWithhierarchy, 0),
		@DateJalali NVARCHAR(100)

	IF(@OrganID IS NULL
		AND @ParentOrganID IS NULL
		AND @DepartmentType = 0
		AND @DepartmentSubType = 0)
		SET @SearchWithhierarchy = 0

	IF @ParentOrganID IS NOT NULL AND @ParentOrganID <> 0x
		SET @ParentNode = (SELECT [Node] FROM org._Department WHERE ID = @ParentOrganID)

	IF @YearFrom = 0 
	BEGIN
		SET @YearFrom = 1397
		SET @MonthFrom = 1
	END

	SET @DateJalali = dbo.fnGetPersianDate(GETDATE())

	IF @YearTo = 0 
	BEGIN
		SET @YearTo = COALESCE(LEFT(@DateJalali, 4), 1400)
		SET @MonthTo = COALESCE(RIGHT(LEFT(@DateJalali, 7), 2), 8)
		SET @MonthsDay=COALESCE(RIGHT(@DateJalali, 2), 8)
		IF(@MonthsDay<15)
		SET @MonthTo = @MonthTo - 1
	END
	
	SET @MonthsWithPayroll = (13 - @MonthFrom) + @MonthTo + ((@YearTo - @YearFrom - 1) * 12)

	--IF @PageIndex = 0 
	--BEGIN
	--	SET @pagesize = 10000000
	--	SET @PageIndex = 1
	--END

	;WITH LawCount AS (
		SELECT OrganID, COUNT(*) Cnt
		FROM law.organlaw 
		WHERE [Enabled] = 1
			AND (@LawID IS NULL OR organlaw.LawID = @LawID)
		GROUP BY OrganID
	)
	, EmployeeCount AS
	(
		SELECT OrganID, Count(*) Cnt
		FROM pbl.Employee
		GROUP BY OrganID
	)
	, PayrollCount AS 
	(
		SELECT OrganID, Count(*) Cnt
		FROM wag.Payroll 
			INNER JOIN pbl.BaseDocument doc ON Payroll.ID = doc.ID
			INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
		WHERE RemoveDate IS NULL
			AND (Payroll.[Year] > @YearFrom OR (Payroll.[Year] = @YearFrom AND payroll.Month >= @MonthFrom))
			AND (Payroll.[Year] < @YearTo OR (Payroll.[Year] = @YearTo AND payroll.Month <= @MonthTo))
		GROUP BY OrganID
	)
	, SelectedDepartment AS
	(
		SELECT DISTINCT Department.ID, Department.[Node]
		FROM org._Department Department
			LEFT JOIN pbl.PayrollDepartment ON PayrollDepartment.DepartmentID = Department.ID
		WHERE COALESCE(PayrollDepartment.PayrollNeeded, 1) = 1
			AND (@OrganID IS NULL OR Department.ID = @OrganID)
			AND (@ParentNode IS NULL OR Department.[Node].IsDescendantOf(@ParentNode) = 1)
			AND (@DepartmentType < 1 OR Department.[Type] = @DepartmentType)
			AND (@DepartmentSubType < 1 OR Department.SubType = @DepartmentSubType)
	)
	, AllDepartment AS
	(
		SELECT DISTINCT Department.*
		FROM org._Department Department
			INNER JOIN SelectedDepartment ON 
				(@SearchWithhierarchy = 0 AND SelectedDepartment.ID = Department.ID) 
				OR (@SearchWithhierarchy = 1 AND SelectedDepartment.Node.IsDescendantOf(Department.Node) = 1)
	)
	--, MonthWithoutPayrollCount AS
	--(
	--	SELECT Department.ID OrganID,
	--		@MonthsWithPayroll - COUNT(distinct Payroll.[Month]) Cnt
	--	FROM org.Department 
	--		LEFT JOIN wag.Payroll ON Payroll.OrganID = Department.ID
	--		LEFT JOIN pbl.BaseDocument doc ON Payroll.ID = doc.ID
	--		INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
	--	WHERE doc.RemoveDate IS NULL
	--		AND (@Year < 1 OR Payroll.[Year] = @Year)
	--		AND (@Month < 1 OR Payroll.[Month] = @Month)
	--	GROUP BY Department.ID 
	--)
	, MainSelect AS 
	(
		SELECT 
			organ.Code,
			organ.Name,
			organ.ParentName,
			organ.Type,
			organ.Node.ToString() Node,
			COALESCE(organ.Node.GetAncestor(1).ToString(), '/') ParentNode,
			organ.Node.GetLevel() NodeLevel,
			CASE WHEN Organ.Type = 10 THEN NULL ELSE COALESCE(LawCount.Cnt, 0) END LawCount,
			CASE WHEN Organ.Type = 10 THEN NULL ELSE COALESCE(EmployeeCount.Cnt, 0) END EmployeeCount,
			CASE WHEN Organ.Type = 10 THEN NULL ELSE COALESCE(OrganPayrollEmployeeCount.[Count], 0) END EmployeeInPayrollCount,
			CASE WHEN Organ.Type = 10 THEN NULL ELSE COALESCE(PayrollCount.Cnt, 0) END PayrollCount,
			@MonthsWithPayroll MonthsWithPayroll
		FROM AllDepartment Organ
			LEFT JOIN LawCount ON LawCount.OrganID = organ.ID
			LEFT JOIN EmployeeCount ON EmployeeCount.OrganID = organ.ID
			LEFT JOIN rpt.OrganPayrollEmployeeCount ON OrganPayrollEmployeeCount.OrganID = organ.ID
			LEFT JOIN PayrollCount ON PayrollCount.OrganID = organ.ID
		WHERE @ReportType < 1
			OR (@ReportType = 1 AND COALESCE(PayrollCount.Cnt, 0) = 0 )
			OR (@ReportType = 2 AND COALESCE(PayrollCount.Cnt, 0) > 0 )
			OR (@ReportType = 3 AND COALESCE(LawCount.Cnt, 0) > 0 AND(@MonthsWithPayroll * COALESCE(LawCount.Cnt, 0)) = COALESCE(PayrollCount.Cnt, 0))
	)
	SELECT * FROM MainSelect
	Order BY Node --, Code
	--OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetOrgansProgressReportInPercentage') IS NOT NULL
	DROP PROCEDURE wag.spGetOrgansProgressReportInPercentage
GO

CREATE PROCEDURE wag.spGetOrgansProgressReportInPercentage
	@AOrganID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@ADepartmentType TINYINT,
	@AOrganType TINYINT,
	@ADepartmentSubType TINYINT,
	@ALawID UNIQUEIDENTIFIER,
	@AReportType TINYINT,
	@AYearFrom SMALLINT,
	@AMonthFrom TINYINT,
	@AYearTo SMALLINT,
	@AMonthTo TINYINT,
	@AFromConfirmDate DATE,
	@AToConfirmDate DATE,
	@AFromCreationDate DATE,
	@AToCreationDate DATE,
	@ASearchWithhierarchy BIT,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@DepartmentType TINYINT = COALESCE(@ADepartmentType, 0),
		@OrganType TINYINT = COALESCE(@AOrganType, 0),
		@DepartmentSubType TINYINT = COALESCE(@ADepartmentSubType, 0),
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@ReportType TINYINT = COALESCE(@AReportType, 0),
		@YearFrom SMALLINT = COALESCE(@AYearFrom, 0),
		@MonthFrom TINYINT = COALESCE(@AMonthFrom, 0),
		@YearTo SMALLINT = COALESCE(@AYearTo, 0),
		@MonthTo TINYINT = COALESCE(@AMonthTo, 0),
		@FromConfirmDate DATE = @AFromConfirmDate,
		@ToConfirmDate DATE = @AToConfirmDate,
		@FromCreationDate DATE = @AFromCreationDate,
		@ToCreationDate DATE = @AToCreationDate,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID,
		@MonthsWithPayroll INT,
		@MonthsDay INT,
		@SearchWithhierarchy BIT = COALESCE(@ASearchWithhierarchy, 0),
		@DateJalali NVARCHAR(100),
		@Month int 

	IF @PageIndex = 0
	BEGIN
		SET @PageIndex = 1
		SET @PageSize = 100000
	END

	IF @ParentOrganID IS NOT NULL AND @ParentOrganID <> 0x
		SET @ParentNode = (SELECT [Node] FROM org._Department WHERE ID = @ParentOrganID)

	IF @PageIndex =0
	BEGIN
		SET @PageIndex = 1
		SET @PageSize = 1000000
	END 

	SET @DateJalali = dbo.fnGetPersianDate(GETDATE())
	SET @Month  = COALESCE(RIGHT(LEFT(@DateJalali, 7), 2), 9)
	IF @YearTo = 0 
	BEGIN
		SET @YearTo = COALESCE(LEFT(@DateJalali, 4), 1400)
		SET @MonthTo = COALESCE(RIGHT(LEFT(@DateJalali, 7), 2), 8)
		SET @MonthsDay=COALESCE(RIGHT(@DateJalali, 2), 8)
		IF(@MonthsDay<15)
		SET @MonthTo = @MonthTo - 1
	END
	
	SET @MonthsWithPayroll = (13 - @MonthFrom) + @MonthTo + ((@YearTo - @YearFrom - 1) * 12)

	SET @YearFrom = 1400
	SET @MonthFrom = 1

	--DECLARE 
	--@Date1 DATETIME = DATEADD(DAY, 1, '2021-11-18'),
	--@Month1 int = 7,

	--@Date2 DATETIME = DATEADD(DAY, 1, '2021-11-21'),
	--@Month2 int = 7,

	--@Date3 DATETIME = GETDATE(),
	--@Month3 int = 8

	--;WITH LawCount AS 
	--(
	--	SELECT 
	--		OrganID ID, 
	--		COUNT(*) Cnt
	--	FROM law.organlaw
	--	INNER JOIN pbl.BaseDocument doc ON doc.ID = organlaw.ID
 --       INNER JOIN pbl.DocumentFlow ON DocumentFlow.DocumentID = organlaw.ID
	--	WHERE [Enabled] = 1 AND doc.RemoveDate is null AND pbl.DocumentFlow.ToDocState=100  AND  pbl.DocumentFlow.ActionDate IS NULL
	--	AND (@OrganID IS NULL OR @OrganID=OrganID)
	--	AND (@LawID IS NULL OR @LawID=LawID) 
	--	GROUP BY OrganID
	--)
	--, LawCounts AS (
	--	SELECT 
	--		CASE WHEN Cnt > 2 THEN (Cnt-1) * @Month ELSE Cnt*@Month END Cont,
	--		ID 
	--	FROM LawCount
	--),
	;WITH FirstFlow AS(
	SELECT MIN(df.Date) CreationDate, 
                df.DocumentID
         FROM pbl.DocumentFlow df
		 INNER JOIN pbl.BaseDocument doc ON doc.ID = df.DocumentID
		 WHERE doc.RemoveDate IS NULL
			AND df.FromDocState = 1
			AND df.ToDocState = 1
         GROUP BY df.DocumentID
	)
	--, PayrollCount AS 
	--(
	--	SELECT 
	--		OrganID ID, 
	--		Count(*) Cnt
	--	FROM wag.Payroll 
	--		INNER JOIN pbl.BaseDocument doc ON Payroll.ID = doc.ID
	--		INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
	--		INNER JOIN FirstFlow  ON doc.ID = FirstFlow.DocumentID 
	--	WHERE RemoveDate IS NULL and wag.Payroll.Year=1400 
	--		and Month <= @Month AND (@OrganID IS NULL OR @OrganID=OrganID)
	--		 AND (@LawID IS NULL OR @LawID=LawID)  
	--		 AND (@FromConfirmDate IS NULL OR ConfirmFlow.Date>=@FromConfirmDate)
	--		 AND (@ToConfirmDate IS NULL OR ConfirmFlow.Date<=@ToConfirmDate)
	--		 AND (@FromCreationDate IS NULL OR FirstFlow.CreationDate>=@FromCreationDate)
	--		 AND (@ToCreationDate IS NULL OR FirstFlow.CreationDate<=@ToCreationDate)
	--		 AND ConfirmFlow.Date<'2021-12-09'
	--	GROUP BY OrganID
	--)
	, PayrollMonthCount AS 
	(
		SELECT 
			OrganID ID, 
			Count(distinct Month) Cnt
		FROM wag.Payroll 
			INNER JOIN pbl.BaseDocument doc ON Payroll.ID = doc.ID
			INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
			INNER JOIN FirstFlow  ON doc.ID = FirstFlow.DocumentID 
		WHERE RemoveDate IS NULL and wag.Payroll.Year=1400 
			and Month <= @Month AND (@OrganID IS NULL OR @OrganID=OrganID)
			 AND (@LawID IS NULL OR @LawID=LawID) 
			 AND (@FromConfirmDate IS NULL OR ConfirmFlow.Date>=@FromConfirmDate)
			 AND (@ToConfirmDate IS NULL OR ConfirmFlow.Date<=@ToConfirmDate)
			 AND (@FromCreationDate IS NULL OR FirstFlow.CreationDate>=@FromCreationDate)
			 AND (@ToCreationDate IS NULL OR FirstFlow.CreationDate<=@ToCreationDate)
			 AND ConfirmFlow.Date<'2021-12-09'
		GROUP BY OrganID
	)
	--, EmployeeCount AS
	--(
	--	SELECT 
	--		OrganID ID, 
	--		COUNT(DISTINCT PayrollEmployee.EmployeeID) [Count]
	--	FROM wag.PayrollEmployee
	--		INNER JOIN wag._Payroll Payroll ON payroll.ID = PayrollEmployee.PayrollID
	--	WHERE  Payroll.Year=1400  and Month<= @Month AND (@OrganID IS NULL OR @OrganID=OrganID) 
	--	AND (@LawID IS NULL OR @LawID=LawID) 
	--	GROUP BY OrganID
	--)
	, Final AS
	(
		SELECT 
			Department.MainOrgan2Name,
			Department.MainOrgan1Name,
			Department.Name,
			Department.ParentName,
			Department.ID,
			Department.Type,
			Department.Node,
			--PayrollCount.Cnt ConfirmedPayrollCount,
			IIF(CAST(CAST(PayrollMonthCount.Cnt as DECIMAL(8,3))/CAST(@Month as DECIMAL(8,3))  AS DECIMAL(5,2))>1,1,cast(CAST(PayrollMonthCount.Cnt as DECIMAL(8,3))/CAST(@Month as DECIMAL(8,3))  AS DECIMAL(5,2))) per,
			Department.MainOrganType,
			PayrollMonthCount.Cnt PayrollMonthCount,
			Department.Code,
			Department.ParentCode
		FROM org._Department Department 
		--	LEFT JOIN PayrollCount on Department.ID=PayrollCount.ID
			--  LEFT JOIN LawCounts on LawCounts.ID=PayrollCount.ID
		    --  LEFT JOIN EmployeeCount on EmployeeCount.ID=PayrollCount.ID
			LEFT JOIN PayrollMonthCount on Department.ID=PayrollMonthCount.ID
		WHERE (@OrganID IS NULL OR @OrganID=Department.ID)
			AND (@DepartmentType < 1 OR @DepartmentType=Department.Type)
			AND (@DepartmentSubType < 1 OR @DepartmentSubType=Department.SubType)
			AND (@ParentNode IS NULL OR Department.Node.IsDescendantOf(@ParentNode) = 1)
			AND Department.MainOrgan1Name IS NOT NULL AND Department.Type<>10  
			AND (@OrganType<1 OR Department.OrganType=@OrganType)
			AND (@OrganType>0 OR Department.OrganType<>4)
			
	)
	, MainSelect AS
	(
		SELECT 
			Final.MainOrgan1Name,
			Final.MainOrgan2Name,
			Final.ParentName,
			Final.MainOrganType,
			Final.Name,
			Final.PayrollMonthCount,
			--Final.ConfirmedPayrollCount,
			Final.Code,
			Final.ParentCode,
		--	Final.LawCount,
			COALESCE(Final.per, 0.0) Progress,   -- for current date
			CAST(COALESCE(AVG(ISNULL(cFinal.per,0)), 0) AS DECIMAL(5,2)) cper,
			CAST(COALESCE(AVG(ISNULL(cFinal.per,0)), 0) AS DECIMAL(5,2)) ChildsProgress

			--(SELECT CAST(COALESCE(avg(test2.per), 0) AS DECIMAL(5,2)) FROM Test test2 WHERE test2.ID <> test.ID AND test2.Node.IsDescendantOf(test.Node)=1) ChildsProgress
		FROM Final 
			LEFT JOIN Final cFinal ON cFinal.ID <> Final.ID AND cFinal.Node.IsDescendantOf(Final.Node)=1
		GROUP BY 
			Final.MainOrgan1Name,
			Final.MainOrgan2Name,
			Final.ParentName,
			Final.MainOrganType,
			Final.Name,
			Final.PayrollMonthCount,
			--Final.ConfirmedPayrollCount,
			Final.Code,
			Final.ParentCode,
			--Final.LawCount,
			Final.per
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY MainOrgan1Name,Progress DESC, MainOrgan2Name, Name
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE);


END

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPaymentsMoreThan') IS NOT NULL
    DROP PROCEDURE wag.spGetPaymentsMoreThan
GO

CREATE PROCEDURE wag.spGetPaymentsMoreThan
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APayment INT,
	@APostLevel TINYINT,
	@AJobBase TINYINT,
	@AEducationDegree TINYINT,
	@AEmploymentType TINYINT,
	@AServiceYearsType TINYINT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Payment INT = COALESCE(@APayment, 0),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@JobBase TINYINT = COALESCE(@AJobBase, 0),
		@EducationDegree TINYINT = COALESCE(@AEducationDegree, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@ServiceYearsType TINYINT = COALESCE(@AServiceYearsType, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
		@UserID UNIQUEIDENTIFIER,
		@ParentOrganNode HIERARCHYID
				
	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH Organ AS
	(
		SELECT ID, Code, Name
		FROM org.Department
		WHERE Node.IsDescendantOf(@ParentOrganNode) = 1
	)
	, Payroll AS
	(
		SELECT payroll.ID, OrganID, LawID, [Year], [Month]
		FROM wag.Payroll
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
		WHERE doc.RemoveDate IS NULL
			AND (@OrganID IS NULL OR Payroll.OrganID = @OrganID)
			AND (@LawID IS NULL OR Payroll.LawID = @LawID)
			AND (@Year < 1 OR [Year] = @Year)
			AND (@Month < 1 OR [Month] = @Month)
	)
	, PayrollEmployee AS
	(
		SELECT ID ,PayrollID, EmployeeID,(PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions) [Sum]
		FROM wag.PayrollEmployee
		WHERE 
			((PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions) > @Payment)
			--AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
			--AND (@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
			--AND (@EducationDegree < 1 OR PayrollEmployee.EducationDegree = @EducationDegree)
			--AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
			--AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
			--AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
	)
	, MainSelect AS
	(
		select 
			PayrollEmployee.EmployeeID,
			PayrollEmployee.ID PayrollEmployeeID,
			PayrollEmployee.[Sum],
			Payroll.ID PayrollID,
			Payroll.[Year],
			Payroll.[Month],
			payroll.OrganID,
			Organ.Code OrganCode,
			Organ.Name OrganName
		from PayrollEmployee 
			INNER JOIN Payroll on PayrollEmployee.PayrollID = payroll.id
			INNER JOIN Organ on Organ.ID = payroll.OrganID
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	, PagedSelect AS 
	(
		SELECT 
			MainSelect.* ,
			EmployeeDetail.FirstName,
			EmployeeDetail.LastName,
			EmployeeDetail.NationalCode,
			lastFlow.ToDocState LastDocState
		FROM MainSelect
			INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = MainSelect.EmployeeID
			INNER JOIN pbl.DocumentFlow lastFlow ON lastFlow.DocumentID = MainSelect.PayrollID and lastflow.ActionDate is null
		ORDER BY Year Desc, Month DESC, OrganName--, LastName, FirstName
		OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	)
	SELECT *
	FROM PagedSelect, Total

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollAggregationReport') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollAggregationReport
GO

CREATE PROCEDURE wag.spGetPayrollAggregationReport
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APostLevel TINYINT,
	@AJobBase TINYINT,
	@AEducationDegree TINYINT,
	@AEmploymentType TINYINT,
	@AServiceYearsType TINYINT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@JobBase TINYINT = COALESCE(@AJobBase, 0),
		@EducationDegree TINYINT = COALESCE(@AEducationDegree, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@ServiceYearsType TINYINT = COALESCE(@AServiceYearsType, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID= @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT 
		Count(*) OVER() Total,
		Payroll.[Year],
		Payroll.[Month],
		Count(PayrollEmployee.ID) EmployeesCount,
		CAST(Min(Payroll.Minimum) AS INT) Minimum,
		CAST(Max(Payroll.Maximum) AS INT) Maximum,
		CAST(Avg(CAST(Payroll.Average AS FLOAT)) AS INT) Average
	FROM wag.Payroll 
		INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
		INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
		INNER JOIN wag.PayrollEmployee on Payroll.ID = PayrollEmployee.PayrollID
		INNER JOIN org.Department Organ ON Organ.ID = Payroll.OrganID
	WHERE (Doc.RemoveDate IS NULL)
		AND NOT (PayrollEmployee.SumPayments = 0 AND PayrollEmployee.SumDeductions = 0) 
		--AND (@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
		AND (Organ.Node.IsDescendantOf(@ParentOrganNode) = 1)
		AND (@OrganID IS NULL OR OrganID = @OrganID)
		AND (@LawID IS NULL OR Payroll.LawID = @LawID)
		AND (@Year < 1 OR Payroll.[Year] = @Year)
		AND (@Month < 1 OR Payroll.[Month] = @Month)
		--AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
		--AND (@EducationDegree < 1 OR PayrollEmployee.EducationDegree = @EducationDegree)
		--AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
		--AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
		--AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
	GROUP By Payroll.[Year],
		Payroll.[Month]
	Order By Payroll.[Year] DESC, Payroll.[Month] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
	USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('rpt.spGetPayrollEmployeeReport'))
    DROP PROCEDURE rpt.spGetPayrollEmployeeReport
GO
CREATE PROCEDURE rpt.spGetPayrollEmployeeReport
	@APayrollIDs NVARCHAR(MAX),
	@AOrganIDs NVARCHAR(MAX),
	@ALawIDs NVARCHAR(MAX),
	@AYears NVARCHAR(MAX),
	@AMonths NVARCHAR(MAX),
	@ANationalCode NVARCHAR(10),
	@AFirstName NVARCHAR(100),
	@ALastName NVARCHAR(100),
	@AToAmount INT,
	@AFromAmount INT,
	@AFromSumPayment INT,
	@AToSumPayment INT,
	@AToDeduction INT,
	@AFromDeduction INT,
	@AToSumHokm  INT,
	@AFromSumHokm  INT,
	@AToSumNHokm INT,
	@AFromSumNHokm INT,
	@AOrganPosts NVARCHAR(MAX),
	@APostLevels NVARCHAR(MAX),
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@AJobBase TINYINT,	
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE 
		@PayrollIDs NVARCHAR(MAX) = @APayrollIDs,
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@LawIDs NVARCHAR(MAX) = @ALawIDs,
		@Years NVARCHAR(MAX) = @AYears,
		@Months NVARCHAR(MAX) = @AMonths,
		@PostLevels NVARCHAR(MAX) = @APostLevels,
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@FirstName NVARCHAR(100) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(100) = LTRIM(RTRIM(@ALastName)),
		@FromAmount INT = COALESCE(@AFromAmount, 0),
		@ToAmount INT = COALESCE(@AToAmount, 0),
		@FromSumPayment INT = COALESCE(@AFromSumPayment, 0),
		@ToSumPayment INT = COALESCE(@AToSumPayment, 0),
		@FromDeduction INT = COALESCE(@AFromDeduction, 0),
		@ToDeduction INT = COALESCE(@AToDeduction, 0),
		@FromSumHokm INT = COALESCE(@AFromSumHokm, 0),
		@ToSumHokm INT = COALESCE(@AToSumHokm, 0),
		@FromSumNHokm INT = COALESCE(@AFromSumNHokm, 0),
		@ToSumNHokm INT = COALESCE(@AToSumNHokm, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@JobBase TINYINT = COALESCE(@AJobBase , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF COALESCE(@CurrentUserOrganID, 0x) = 0x
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
		DROP TABLE IF EXISTS #TempPayroll
	CREATE TABLE #TempPayroll
(
   [ID] [uniqueidentifier] NOT NULL,
	[OrganID] [uniqueidentifier] NOT NULL,
	[LawID] [uniqueidentifier] NOT NULL,
	[Year] [smallint] NOT NULL,
	[Month] [tinyint] NOT NULL,
	LawName nvarchar(1000) null,
	OrganName nvarchar(1000) null
)
	INSERT INTO #TempPayroll
		SELECT  payroll.ID,
		        payroll.OrganID,
				payroll.LawID,
		        Payroll.[Year],
				Payroll.[Month],
				L.Name LawName,
				org.Name OrganName
		FROM  wag.Payroll payroll
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN pbl.DocumentFlow FirstFlow ON FirstFlow.DocumentID = Payroll.ID AND FirstFlow.FromDocState = 1 AND FirstFlow.ToDocState = 1
			INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = Payroll.ID AND LastFlow.ActionDate IS NULL
			INNER JOIN org.Department org ON org.ID = payroll.OrganID
			INNER JOIN law.Law L ON L.ID = payroll.LawID
			LEFT JOIN OPENJSON(@PayrollIDs) PayrollIDs ON PayrollIDs.value = payroll.ID
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = payroll.OrganID
			LEFT JOIN OPENJSON(@LawIDs) LawIDs ON LawIDs.value = payroll.LawID
			LEFT JOIN OPENJSON(@Years) Years ON Years.value = payroll.Year
			LEFT JOIN OPENJSON(@Months) Months ON Months.value = payroll.Month
		WHERE LastFlow.ToDocState = 100 AND doc.RemoveDate IS NULL
			AND (@PayrollIDs IS NULL OR PayrollIDs.value = payroll.ID)
			AND (@OrganIDs IS NULL OR OrganIDs.value = payroll.OrganID)
			AND (@LawIDs IS NULL OR LawIDs.value = payroll.LawID)
			AND (@Years IS NULL OR Years.value = payroll.Year)
			AND (@Months IS NULL OR Months.value = payroll.Month)
	
	;With Total AS (
		SELECT 
			COUNT(*) AS Total
		FROM #TempPayroll Payroll
			INNER JOIN wag.PayrollEmployee payrollemp ON payrollemp.PayrollID = Payroll.ID
			INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = payrollemp.EmployeeID
			LEFT JOIN OPENJSON(@PostLevels) PostLevels ON PostLevels.value = payrollemp.PostLevel

		WHERE 1=1
			AND (@PostLevels IS NULL OR PostLevels.value = payrollemp.PostLevel)
			AND (@JobBase=0 OR @JobBase=payrollemp.JobBase)
			AND ((@FromAmount < 1 OR payrollemp.[Sum] >= @FromAmount) 
			AND (@ToAmount < 1 OR payrollemp.[Sum] <= @ToAmount))

				AND ((@FromSumPayment < 1 OR payrollemp.SumPayments >= @FromSumPayment) 
			AND (@ToSumPayment < 1 OR payrollemp.SumPayments <= @ToSumPayment))

			AND ((@FromDeduction < 1 OR payrollemp.Deductions >= @FromDeduction) 
			AND (@ToDeduction < 1 OR payrollemp.Deductions <= @ToDeduction))

			AND ((@FromSumHokm  < 1 OR payrollemp.SumHokm  >= @FromSumHokm ) 
			AND (@ToSumHokm  < 1 OR payrollemp.SumHokm  <= @ToSumHokm ))

			AND ((@FromSumNHokm  < 1 OR payrollemp.SumNHokm  >= @FromSumNHokm ) 
			AND (@ToSumNHokm  < 1 OR payrollemp.SumNHokm  <= @ToSumNHokm ))

			AND (@NationalCode IS NULL OR EmployeeDetail.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR EmployeeDetail.FirstName LIKE CONCAT('%', @FirstName, '%'))
			AND (@LastName IS NULL OR EmployeeDetail.LastName LIKE CONCAT('%', @LastName, '%'))
	),EmployeePost AS(
	SELECT PostTitle,Number,PostID FROM PBL.EmployeePost
	GROUP BY PostTitle,Number,PostID
	), MainSelect AS
	(
		SELECT 
			payrollemp.ID,
			payrollemp.PayrollID, 
			payrollemp.EmployeeID, 
			EmployeeDetail.FirstName,
			EmployeeDetail.LastName,
			EmployeeDetail.NationalCode,
			payrollemp.PostLevel,
			payrollemp.ServiceYears,
			payrollemp.ServiceYearsType,
			payrollemp.EducationDegree,
			payrollemp.EmploymentType,
			payrollemp.Salary,
			payrollemp.Continuous,
			payrollemp.NonContinuous,
			payrollemp.Reward,
			payrollemp.Welfare,
			payrollemp.Other,
			payrollemp.Deductions,
			payrollemp.SumPayments,
			payrollemp.SumDeductions,
			payrollemp.[Sum],
			payrollemp.SumHokm,
			payrollemp.SumNHokm,
			payrollemp.JobBase,
			Payroll.[Year],
			Payroll.[Month],
			payroll.LawID,
			Payroll.LawName,
			payroll.OrganID,
			isnull(EmployeePost.PostTitle,' ') PostTitle ,
		    isnull(EmployeePost.Number,' ') PostNumber,
			Payroll.OrganName
		FROM #TempPayroll Payroll
			INNER JOIN wag.PayrollEmployee payrollemp ON payrollemp.PayrollID = Payroll.ID
			INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = payrollemp.EmployeeID
			LEFT JOIN OPENJSON(@PostLevels) PostLevels ON PostLevels.value = payrollemp.PostLevel
			LEFT JOIN EmployeePost ON EmployeePost.PostID=payrollemp.PostID
		WHERE 1=1
			AND (@PostLevels IS NULL OR PostLevels.value = payrollemp.PostLevel)
			AND (@JobBase=0 OR @JobBase=payrollemp.JobBase)
			AND ((@FromAmount < 1 OR payrollemp.[Sum] >= @FromAmount) 
			AND (@ToAmount < 1 OR payrollemp.[Sum] <= @ToAmount))

				AND ((@FromSumPayment < 1 OR payrollemp.SumPayments >= @FromSumPayment) 
			AND (@ToSumPayment < 1 OR payrollemp.SumPayments <= @ToSumPayment))

			AND ((@FromDeduction < 1 OR payrollemp.Deductions >= @FromDeduction) 
			AND (@ToDeduction < 1 OR payrollemp.Deductions <= @ToDeduction))

			AND ((@FromSumHokm  < 1 OR payrollemp.SumHokm  >= @FromSumHokm ) 
			AND (@ToSumHokm  < 1 OR payrollemp.SumHokm  <= @ToSumHokm ))

			AND ((@FromSumNHokm  < 1 OR payrollemp.SumNHokm  >= @FromSumNHokm ) 
			AND (@ToSumNHokm  < 1 OR payrollemp.SumNHokm  <= @ToSumNHokm ))

			AND (@NationalCode IS NULL OR EmployeeDetail.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR EmployeeDetail.FirstName LIKE CONCAT('%', @FirstName, '%'))
			AND (@LastName IS NULL OR EmployeeDetail.LastName LIKE CONCAT('%', @LastName, '%'))
	)
	
	SELECT * FROM MainSelect, Total 
	ORDER BY [Year] DESC, [Month] DESC   --LastName, 
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollEmployeesByNationalCodeReport') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployeesByNationalCodeReport
GO

CREATE PROCEDURE wag.spGetPayrollEmployeesByNationalCodeReport
	@ANationalCode VARCHAR(10),
	@AShowOnlyManagementPosts BIT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ShowOnlyManagementPosts BIT = COALESCE(@AShowOnlyManagementPosts, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH EmployeeDetail AS
	(
		SELECT * 
		FROM pbl.EmployeeDetail
		WHERE NationalCode = @NationalCode
	)
	, Payroll AS
	(
		SELECT 
			payroll.ID, 
			[Year], 
			[Month],
			Organ.Name OrganName, 
			law.Name LawName
		FROM wag.Payroll
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
			INNER JOIN org.Department organ On organ.ID = Payroll.OrganID
			INNER JOIN law.law On law.ID = Payroll.LawID
		WHERE doc.RemoveDate IS NULL 
	)
	, MainSelect AS
	(
		SELECT 
			PayrollEmployee.ID,
			PayrollEmployee.PayrollID, 
			PayrollEmployee.EmployeeID, 
			--PayrollEmployee.PostLevel,
			--PayrollEmployee.ServiceYears,
			--PayrollEmployee.ServiceYearsType,
			--PayrollEmployee.EducationDegree,
			--PayrollEmployee.EmploymentType,
			--PayrollEmployee.JobBase,
			PayrollEmployee.SumPayments,
			PayrollEmployee.SumDeductions,
			PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions [Sum],
			EmployeeDetail.FirstName,
			EmployeeDetail.LastName,
			EmployeeDetail.FatherName,
			EmployeeDetail.BCNumber,
			EmployeeDetail.Gender,
			EmployeeDetail.NationalCode,
			EmployeeDetail.BirthDate BirthDate,
			Payroll.[Year], 
			Payroll.[Month],
			Payroll.OrganName, 
			Payroll.LawName
		FROM wag.PayrollEmployee
			INNER JOIN EmployeeDetail ON EmployeeDetail.ID = PayrollEmployee.EmployeeID
			INNER JOIN Payroll ON Payroll.Id = PayrollEmployee.PayrollID
		--WHERE 
		--	@ShowOnlyManagementPosts = 0 OR PayrollEmployee.PostLevel <= 28
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY Year DESC, month DESC, OrganName
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetPayrollEmployeeWithDetailsReport'))
DROP PROCEDURE wag.spGetPayrollEmployeeWithDetailsReport
GO

CREATE PROCEDURE wag.spGetPayrollEmployeeWithDetailsReport
	@APayrollID UNIQUEIDENTIFIER,
	@AParentOrganIDs NVARCHAR(MAX),
	@AOrganIDs NVARCHAR(MAX),
	@ALawIDs NVARCHAR(MAX),
	@AYears NVARCHAR(MAX),
	@AMonths NVARCHAR(MAX),
	@AOrganPosts NVARCHAR(MAX),
	@APostLevels NVARCHAR(MAX),
	@ANationalCode VARCHAR(10),
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@ParentOrganIDs NVARCHAR(MAX) = @AParentOrganIDs,
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@LawIDs NVARCHAR(MAX) = @ALawIDs,
		@Years NVARCHAR(MAX) = @AYears,
		@Months NVARCHAR(MAX) = @AMonths,
		@PostLevels NVARCHAR(MAX) = @APostLevels,
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF COALESCE(@CurrentUserOrganID, 0x) = 0x
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH Payroll AS
	(
		SELECT payroll.ID, OrganID, LawID, law.[Name] LawName , [Year], [Month]
		FROM wag.Payroll
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN law.Law law ON law.ID = Payroll.LawID
		WHERE doc.RemoveDate IS NULL
			--AND (@PayrollID IS NULL OR Payroll.ID = @PayrollID)
			--AND (@LawID IS NULL OR Payroll.LawID = @LawID)
			--AND (@OrganID IS NULL OR Payroll.OrganID = @OrganID)
			--AND (@Year < 1 OR [Year] = @Year)
			--AND (@Month < 1 OR [Month] = @Month)
	)
	, Organ AS
	(
		SELECT ID, Code, Name
		FROM org.Department
		WHERE Node.IsDescendantOf(@ParentOrganNode) = 1
	)
	, PayrollEmployee AS
	(
		SELECT 
			payrollemp.ID,
			payrollemp.PayrollID, 
			payrollemp.EmployeeID, 
			--payrollemp.PostLevel,
			--payrollemp.ServiceYears,
			--payrollemp.ServiceYearsType,
			--payrollemp.EducationDegree,
			--payrollemp.EmploymentType,
			payrollemp.SumPayments,
			payrollemp.SumDeductions,
			payrollemp.SumPayments-payrollemp.SumDeductions [Sum]
		FROM wag.PayrollEmployee payrollemp
			INNER JOIN wag.Payroll payroll ON payroll.ID = payrollemp.PayrollID
		WHERE  (@OrganIDs IS NULL OR Payroll.OrganID IN (SELECT VALUE FROM OPENJSON(@OrganIDs)))
			AND (@LawIDs IS NULL OR Payroll.LawID IN (SELECT VALUE FROM OPENJSON(@LawIDs)))
			AND (@Years IS NULL OR Payroll.[Year] IN (SELECT VALUE FROM OPENJSON(@Years)))
			AND (@Months IS NULL OR Payroll.[Month] IN (SELECT VALUE FROM OPENJSON(@Months)))
			--AND (@PostLevels IS NULL OR payrollemp.PostLevel IN (SELECT VALUE FROM OPENJSON(@PostLevels)))
			AND (@LawIDs IS NULL OR Payroll.LawID IN (SELECT VALUE FROM OPENJSON(@ParentOrganIDs)))
	)
	, MainSelect AS
	(
		select 
			PayrollEmployee.*,
			Payroll.[Year],
			Payroll.[Month],
			payroll.OrganID,
			payroll.LawID,
			Payroll.LawName,
			Organ.Code OrganCode,
			Organ.[Name] OrganName
		from PayrollEmployee 
			INNER JOIN Payroll on PayrollEmployee.PayrollID = payroll.id
			INNER JOIN Organ on Organ.ID = payroll.OrganID
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	, FinalSelect AS 
	(
		SELECT 
			MainSelect.* ,
			EmployeeDetail.FirstName,
			EmployeeDetail.LastName,
			EmployeeDetail.FatherName,
			EmployeeDetail.BCNumber,
			EmployeeDetail.Gender,
			EmployeeDetail.NationalCode,
			EmployeeDetail.BirthDate BirthDate,
			lastFlow.ToDocState LastDocState
		FROM MainSelect
			INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = MainSelect.EmployeeID
			INNER JOIN pbl.DocumentFlow lastFlow ON lastFlow.DocumentID = MainSelect.PayrollID and lastflow.ActionDate is null
		--WHERE
			--(@NationalCode IS NULL OR EmployeeDetail.NationalCode = @NationalCode)
			--AND (@Name IS NULL OR EmployeeDetail.FirstName LIKE CONCAT('%', @Name, '%') OR EmployeeDetail.LastName LIKE CONCAT('%', @Name, '%'))
	)
	SELECT *
	FROM FinalSelect, Total 
	ORDER BY LastName, [Year] DESC, [Month] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollReport') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollReport
GO

CREATE PROCEDURE wag.spGetPayrollReport
	--@AOrganID UNIQUEIDENTIFIER,
	--@ALawID UNIQUEIDENTIFIER,
	--@AYear SMALLINT,
	--@AServiceYearsType TINYINT,

	@AOrganIDs NVARCHAR(MAX),
	@ALawIDs NVARCHAR(MAX),
	@AYears NVARCHAR(MAX),
	@AMonths NVARCHAR(MAX),

	@APostLevel TINYINT,
	@AJobBase TINYINT,
	@AEducationDegree TINYINT,
	@AEmploymentType TINYINT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	set transaction isolation level read uncommitted;
    DECLARE 
		--@OrganID UNIQUEIDENTIFIER = @AOrganID,
		--@LawID UNIQUEIDENTIFIER = @ALawID,
		--@Year SMALLINT = COALESCE(@AYear, 0),
		--@Month TINYINT = COALESCE(@AMonth, 0),
		--@ServiceYearsType TINYINT = COALESCE(@AServiceYearsType, 0),

		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@LawIDs NVARCHAR(MAX) = @ALawIDs,
		@Years NVARCHAR(MAX) = @AYears,
		@Months NVARCHAR(MAX) = @AMonths,

		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@JobBase TINYINT = COALESCE(@AJobBase, 0),
		@EducationDegree TINYINT = COALESCE(@AEducationDegree, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID= @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH Organ AS
	(
		SELECT 
			ID, 
			Name
		FROM org.Department
		WHERE Node.IsDescendantOf(@ParentOrganNode) = 1
	)
	--, PayrollEmployee AS
	--(
	--	SELECT DISTINCT PayrollID
	--	FROM wag.PayrollEmployee
	--	WHERE 
	--		(@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
	--		AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
	--		AND (@EducationDegree < 1 OR PayrollEmployee.EducationDegree = @EducationDegree)
	--		AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
	--		AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
	--		AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
	--)
	, Payroll AS 
	(
		SELECT 
			Count(*) OVER() Total,
			Payroll.ID,
			Payroll.OrganID,
			Payroll.OrganName,
			Payroll.LawID,
			Payroll.LawName,
			Payroll.CreationDate,
			Payroll.ConfirmDate,
			Payroll.[Year],
			Payroll.[Month],
			payroll.EmployeesCount,
			payroll.Minimum,
			payroll.Maximum,
			payroll.Average
		FROM wag._Payroll Payroll
			--INNER JOIN PayrollEmployee on Payroll.ID = PayrollEmployee.PayrollID
			INNER JOIN organ ON organ.ID = Payroll.OrganID
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Payroll.OrganID
			LEFT JOIN OPENJSON(@LawIDs) LawIDs ON LawIDs.value = Payroll.LawID
			LEFT JOIN OPENJSON(@Years) Years ON Years.value = Payroll.[Year]
			LEFT JOIN OPENJSON(@Months) Months ON Months.value = Payroll.[Month]
		WHERE Payroll.LastState = 100
			AND(@OrganIDs IS NULL OR OrganIDs.value = Payroll.OrganID)
			AND (@LawIDs IS NULL OR LawIDs.value = Payroll.LawID)
			AND (@Years IS NULL OR Years.value = Payroll.[Year])
			AND (@Months IS NULL OR Months.value = Payroll.[Month])

			--AND (@OrganID IS NULL OR OrganID = @OrganID)
			--AND (@LawID IS NULL OR LawID = @LawID)
			--AND (@Year < 1 OR Payroll.[Year] = @Year)
			--AND (@Month < 1 OR Payroll.[Month] = @Month)
	)
	SELECT *
	FROM Payroll 
	Order BY Year DESC, Month DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollReportWithoutLaw') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollReportWithoutLaw
GO

CREATE PROCEDURE wag.spGetPayrollReportWithoutLaw
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APostLevel TINYINT,
	@AJobBase TINYINT,
	@AEducationDegree TINYINT,
	@AEmploymentType TINYINT,
	@AServiceYearsType TINYINT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@JobBase TINYINT = COALESCE(@AJobBase, 0),
		@EducationDegree TINYINT = COALESCE(@AEducationDegree, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@ServiceYearsType TINYINT = COALESCE(@AServiceYearsType, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID= @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT 
		Count(*) OVER() Total,
		Payroll.OrganID,
		Organ.Name OrganName,
		Payroll.[Year],
		Payroll.[Month],
		Count(PayrollEmployee.ID) EmployeesCount,
		Min(PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions) Minimum,
		Max(PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions) Maximum,
		CAST(Avg(CAST(Payroll.Average AS FLOAT)) AS INT) Average
	FROM wag.Payroll 
		INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID 
		INNER JOIN pbl.DocumentFlow ConfirmFlow ON doc.ID = ConfirmFlow.DocumentID AND ConfirmFlow.ToDocState = 100
		INNER JOIN wag.PayrollEmployee on Payroll.ID = PayrollEmployee.PayrollID
		INNER JOIN org.Department organ ON organ.ID = Payroll.OrganID
		INNER JOIN law.Law ON Law.ID = Payroll.LawID
	WHERE (Doc.RemoveDate IS NULL)
		AND NOT (PayrollEmployee.SumPayments = 0 AND PayrollEmployee.SumDeductions = 0) 
		--AND (@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
		AND (Organ.Node.IsDescendantOf(@ParentOrganNode) = 1)
		AND (@OrganID IS NULL OR OrganID = @OrganID)
		AND (@LawID IS NULL OR LawID = @LawID)
		AND (@Year < 1 OR Payroll.[Year] = @Year)
		AND (@Month < 1 OR Payroll.[Month] = @Month)
		--AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
		--AND (@EducationDegree < 1 OR PayrollEmployee.EducationDegree = @EducationDegree)
		--AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
		--AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
		--AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
	GROUP By Payroll.OrganID,
		Organ.Name,
		Payroll.[Year],
		Payroll.[Month]
		--Payroll.Minimum,
		--Payroll.Maximum
		--Payroll.Average
	Order By Avg(CAST(PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions AS FLOAT)) DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

    RETURN @@ROWCOUNT 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollsPerMonthReport') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollsPerMonthReport
GO

CREATE PROCEDURE wag.spGetPayrollsPerMonthReport
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH YearMonth
	AS
	(SELECT DISTINCT [Year], [Month] FROM wag.Payroll
		INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
		WHERE doc.RemoveDate IS NULL 
	)
	SELECT 
		Count(*) OVER() Total,
		YearMonth.[Year],
		YearMonth.[Month],
		(SELECT COUNT(PayrollEmployee.ID) FROM wag.Payroll 
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN wag.PayrollEmployee ON PayrollEmployee.PayrollID = Payroll.ID
			WHERE doc.RemoveDate IS NULL 
				AND (@OrganID IS NULL OR OrganID = @OrganID)
				AND (@LawID IS NULL OR LawID = @LawID)
				AND [Year] = YearMonth.[Year] 
				AND [Month] = YearMonth.[Month]
				) EmployeesCount,
		(SELECT COUNT(Payroll.ID) FROM wag.Payroll 
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			WHERE doc.RemoveDate IS NULL 
				AND (@OrganID IS NULL OR OrganID = @OrganID)
				AND (@LawID IS NULL OR LawID = @LawID)
				AND [Year] = YearMonth.[Year] 
				AND [Month] = YearMonth.[Month]
				) PayrollsCount,
		(SELECT COUNT(Payroll.ID) FROM wag.Payroll 
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN pbl.DocumentFlow flow ON flow.DocumentID = doc.ID AND flow.ActionDate IS NULL
			WHERE doc.RemoveDate IS NULL 
				AND flow.ToDocState = 100
				AND (@OrganID IS NULL OR OrganID = @OrganID)
				AND (@LawID IS NULL OR LawID = @LawID)
				AND [Year] = YearMonth.[Year] 
				AND [Month] = YearMonth.[Month]
				) ConfirmedPayrollsCount
	FROM YearMonth 
	WHERE (@Year < 1 OR YearMonth.[Year] = @Year)
		AND (@Month < 1 OR YearMonth.[Month] = @Month)
	Order By [Year] DESC, [Month] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

    RETURN @@ROWCOUNT 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollsPerMonthReport') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollsPerMonthReport
GO

CREATE PROCEDURE wag.spGetPayrollsPerMonthReport
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID= @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH YearMonth
	AS
	(
		SELECT DISTINCT [Year], [Month] 
		FROM wag.Payroll
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
		WHERE doc.RemoveDate IS NULL 
	)
	SELECT 
		Count(*) OVER() Total,
		YearMonth.[Year],
		YearMonth.[Month],
		(SELECT COUNT(PayrollEmployee.ID) FROM wag.Payroll 
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN wag.PayrollEmployee ON PayrollEmployee.PayrollID = Payroll.ID
			INNER JOIN org.Department Organ on Organ.ID = payroll.OrganID
		WHERE doc.RemoveDate IS NULL 
			AND (Organ.Node.IsDescendantOf(@ParentOrganNode) = 1)
			AND (@OrganID IS NULL OR OrganID = @OrganID)
			AND (@LawID IS NULL OR LawID = @LawID)
			AND [Year] = YearMonth.[Year] 
			AND [Month] = YearMonth.[Month]
		) EmployeesCount,
		(SELECT COUNT(Payroll.ID) FROM wag.Payroll 
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN org.Department Organ on Organ.ID = payroll.OrganID
		WHERE doc.RemoveDate IS NULL 
			AND (Organ.Node.IsDescendantOf(@ParentOrganNode) = 1)
			AND (@OrganID IS NULL OR OrganID = @OrganID)
			AND (@LawID IS NULL OR LawID = @LawID)
			AND [Year] = YearMonth.[Year] 
			AND [Month] = YearMonth.[Month]
		) PayrollsCount,
		(SELECT COUNT(Payroll.ID) FROM wag.Payroll 
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN pbl.DocumentFlow flow ON flow.DocumentID = doc.ID AND flow.ActionDate IS NULL
			INNER JOIN org.Department Organ on Organ.ID = payroll.OrganID
		WHERE doc.RemoveDate IS NULL 
			AND (Organ.Node.IsDescendantOf(@ParentOrganNode) = 1)
			AND flow.ToDocState = 100
			AND (@OrganID IS NULL OR OrganID = @OrganID)
			AND (@LawID IS NULL OR LawID = @LawID)
			AND [Year] = YearMonth.[Year] 
			AND [Month] = YearMonth.[Month]
		) ConfirmedPayrollsCount
	FROM YearMonth 
	WHERE (@Year < 1 OR YearMonth.[Year] = @Year)
		AND (@Month < 1 OR YearMonth.[Month] = @Month)
	Order By [Year] DESC, [Month] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetReport') IS NOT NULL
    DROP PROCEDURE wag.spGetReport
GO

CREATE PROCEDURE wag.spGetReport
	@ALawID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@AWageTitleGroupIDs NVARCHAR(1000),
	@APostLevels NVARCHAR(1000),
	@AYear SMALLINT,
	@AMonth TINYINT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@WageTitleGroupIDs NVARCHAR(1000) = LTRIM(RTRIM(@AWageTitleGroupIDs)),
		@PostLevels NVARCHAR(1000) = LTRIM(RTRIM(@APostLevels)),
		@Year SMALLINT = @AYear,
		@Month TINYINT = @AMonth 

	--SELECT
	--	org.Name OrganName
	--	, groupWageTitle.[Name] WageTitleGroupName
	--	, groupWageTitle.[Code] WageTitleGroupCode
	--	, payroll.[Year]
	--	, payroll.[Month]
	--	, Count(emp.ID) EmployeeCount
	--	, CAST(Avg(detail.Amount) AS DECIMAL(12)) AvgAmount
	--	, CAST(Max(detail.Amount) AS DECIMAL(12)) MaxAmount
	--	, CAST(Min(detail.Amount) AS DECIMAL(12)) MinAmount
	--FROM wag.PayrollDetail detail
	--INNER JOIN wag.Payroll payroll ON payroll.ID = detail.PayrollID
	--INNER JOIN org.Organ org ON org.[Guid] = Payroll.OrganID
	--INNER JOIN wag.PayrollEmployee emp ON emp.PayrollID = payroll.ID AND emp.IndividualID = detail.IndividualID
	--INNER JOIN wag.WageTitle wageTitle ON wageTitle.ID = detail.WageTitleID
	--INNER JOIN wag.PayrollWageTitle payrollWageTitle ON payrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.WageTitleID = WageTitle.ID
	--INNER JOIN wag.PayrollWageTitle groupPayrollWageTitle ON groupPayrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.[Node].IsDescendantOf(groupPayrollWageTitle.[Node]) = 1 AND payrollWageTitle.ID <> groupPayrollWageTitle.ID
	--INNER JOIN wag.WageTitle groupWageTitle ON groupWageTitle.ID = groupPayrollWageTitle.WageTitleID
	--WHERE 
	--	(@LawID IS NULL OR payroll.LawID = @LawID)
	--	AND (@OrganID IS NULL OR payroll.OrganID = @OrganID)
	--	AND (@Year < 1 OR payroll.[Year] = @Year)
	--	AND (@Month < 1 OR payroll.[Month] = @Month)
	--Group BY org.[Name], groupWageTitle.[Name], groupWageTitle.[Code], payroll.[Year], payroll.[Month]

    RETURN @@ROWCOUNT 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetReportByEducationDegree') IS NOT NULL
    DROP PROCEDURE wag.spGetReportByEducationDegree
GO

CREATE PROCEDURE wag.spGetReportByEducationDegree
	@ALawID UNIQUEIDENTIFIER
	, @AOrganID UNIQUEIDENTIFIER
	, @AWageTitleGroupIDs NVARCHAR(1000)
	, @APostLevels NVARCHAR(1000)
	, @AYear SMALLINT
	, @AMonth TINYINT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @LawID UNIQUEIDENTIFIER = @ALawID
		, @OrganID UNIQUEIDENTIFIER = @AOrganID
		, @WageTitleGroupIDs NVARCHAR(1000) = LTRIM(RTRIM(@AWageTitleGroupIDs))
		, @PostLevels NVARCHAR(1000) = LTRIM(RTRIM(@APostLevels))
		, @Year SMALLINT = @AYear
		, @Month TINYINT = @AMonth 

	--SELECT
	--	org.Name OrganName
	--	, groupWageTitle.[Name] WageTitleGroupName
	--	, groupWageTitle.[Code] WageTitleGroupCode
	--	, payroll.[Year]
	--	, payroll.[Month]
	--	, emp.EducationDegree
	--	, Count(emp.ID) EmployeeCount
	--	, CAST(Avg(detail.Amount) AS DECIMAL(12)) AvgAmount
	--	, CAST(Max(detail.Amount) AS DECIMAL(12)) MaxAmount
	--	, CAST(Min(detail.Amount) AS DECIMAL(12)) MinAmount
	--FROM wag.PayrollDetail detail
	--INNER JOIN wag.Payroll payroll ON payroll.ID = detail.PayrollID
	--INNER JOIN org.Organ org ON org.[Guid] = Payroll.OrganID
	--INNER JOIN wag.PayrollEmployee emp ON emp.PayrollID = payroll.ID AND emp.IndividualID = detail.IndividualID
	--INNER JOIN wag.WageTitle wageTitle ON wageTitle.ID = detail.WageTitleID
	--INNER JOIN wag.PayrollWageTitle payrollWageTitle ON payrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.WageTitleID = WageTitle.ID
	--INNER JOIN wag.PayrollWageTitle groupPayrollWageTitle ON groupPayrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.[Node].IsDescendantOf(groupPayrollWageTitle.[Node]) = 1 AND payrollWageTitle.ID <> groupPayrollWageTitle.ID
	--INNER JOIN wag.WageTitle groupWageTitle ON groupWageTitle.ID = groupPayrollWageTitle.WageTitleID
	--WHERE 
	--	(@LawID IS NULL OR payroll.LawID = @LawID)
	--	AND (@OrganID IS NULL OR payroll.OrganID = @OrganID)
	--	AND (@Year < 1 OR payroll.[Year] = @Year)
	--	AND (@Month < 1 OR payroll.[Month] = @Month)
	--Group BY org.[Name], groupWageTitle.[Name], groupWageTitle.[Code], payroll.[Year], payroll.[Month], emp.EducationDegree

    RETURN @@ROWCOUNT 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetReportByEmploymentType') IS NOT NULL
    DROP PROCEDURE wag.spGetReportByEmploymentType
GO

CREATE PROCEDURE wag.spGetReportByEmploymentType
	@ALawID UNIQUEIDENTIFIER
	, @AOrganID UNIQUEIDENTIFIER
	, @AWageTitleGroupIDs NVARCHAR(1000)
	, @APostLevels NVARCHAR(1000)
	, @AYear SMALLINT
	, @AMonth TINYINT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @LawID UNIQUEIDENTIFIER = @ALawID
		, @OrganID UNIQUEIDENTIFIER = @AOrganID
		, @WageTitleGroupIDs NVARCHAR(1000) = LTRIM(RTRIM(@AWageTitleGroupIDs))
		, @PostLevels NVARCHAR(1000) = LTRIM(RTRIM(@APostLevels))
		, @Year SMALLINT = @AYear
		, @Month TINYINT = @AMonth 

	--SELECT
	--	org.Name OrganName
	--	, groupWageTitle.[Name] WageTitleGroupName
	--	, groupWageTitle.[Code] WageTitleGroupCode
	--	, payroll.[Year]
	--	, payroll.[Month]
	--	, emp.EmploymentType
	--	, Count(emp.ID) EmployeeCount
	--	, CAST(Avg(detail.Amount) AS DECIMAL(12)) AvgAmount
	--	, CAST(Max(detail.Amount) AS DECIMAL(12)) MaxAmount
	--	, CAST(Min(detail.Amount) AS DECIMAL(12)) MinAmount
	--FROM wag.PayrollDetail detail
	--INNER JOIN wag.Payroll payroll ON payroll.ID = detail.PayrollID
	--INNER JOIN org.Organ org ON org.[Guid] = Payroll.OrganID
	--INNER JOIN wag.PayrollEmployee emp ON emp.PayrollID = payroll.ID AND emp.IndividualID = detail.IndividualID
	--INNER JOIN wag.WageTitle wageTitle ON wageTitle.ID = detail.WageTitleID
	--INNER JOIN wag.PayrollWageTitle payrollWageTitle ON payrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.WageTitleID = WageTitle.ID
	--INNER JOIN wag.PayrollWageTitle groupPayrollWageTitle ON groupPayrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.[Node].IsDescendantOf(groupPayrollWageTitle.[Node]) = 1 AND payrollWageTitle.ID <> groupPayrollWageTitle.ID
	--INNER JOIN wag.WageTitle groupWageTitle ON groupWageTitle.ID = groupPayrollWageTitle.WageTitleID
	--WHERE 
	--	(@LawID IS NULL OR payroll.LawID = @LawID)
	--	AND (@OrganID IS NULL OR payroll.OrganID = @OrganID)
	--	AND (@Year < 1 OR payroll.[Year] = @Year)
	--	AND (@Month < 1 OR payroll.[Month] = @Month)
	--Group BY org.[Name], groupWageTitle.[Name], groupWageTitle.[Code], payroll.[Year], payroll.[Month], emp.EmploymentType

    RETURN @@ROWCOUNT 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetReportByJobBase') IS NOT NULL
    DROP PROCEDURE wag.spGetReportByJobBase
GO

CREATE PROCEDURE wag.spGetReportByJobBase
	@ALawID UNIQUEIDENTIFIER
	, @AOrganID UNIQUEIDENTIFIER
	, @AWageTitleGroupIDs NVARCHAR(1000)
	, @APostLevels NVARCHAR(1000)
	, @AYear SMALLINT
	, @AMonth TINYINT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @LawID UNIQUEIDENTIFIER = @ALawID
		, @OrganID UNIQUEIDENTIFIER = @AOrganID
		, @WageTitleGroupIDs NVARCHAR(1000) = LTRIM(RTRIM(@AWageTitleGroupIDs))
		, @PostLevels NVARCHAR(1000) = LTRIM(RTRIM(@APostLevels))
		, @Year SMALLINT = @AYear
		, @Month TINYINT = @AMonth 

	--SELECT
	--	org.Name OrganName
	--	, groupWageTitle.[Name] WageTitleGroupName
	--	, groupWageTitle.[Code] WageTitleGroupCode
	--	, payroll.[Year]
	--	, payroll.[Month]
	--	, emp.JobBase
	--	, Count(emp.ID) EmployeeCount
	--	, CAST(Avg(detail.Amount) AS DECIMAL(12)) AvgAmount
	--	, CAST(Max(detail.Amount) AS DECIMAL(12)) MaxAmount
	--	, CAST(Min(detail.Amount) AS DECIMAL(12)) MinAmount
	--FROM wag.PayrollDetail detail
	--INNER JOIN wag.Payroll payroll ON payroll.ID = detail.PayrollID
	--INNER JOIN org.Organ org ON org.[Guid] = Payroll.OrganID
	--INNER JOIN wag.PayrollEmployee emp ON emp.PayrollID = payroll.ID AND emp.IndividualID = detail.IndividualID
	--INNER JOIN wag.WageTitle wageTitle ON wageTitle.ID = detail.WageTitleID
	--INNER JOIN wag.PayrollWageTitle payrollWageTitle ON payrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.WageTitleID = WageTitle.ID
	--INNER JOIN wag.PayrollWageTitle groupPayrollWageTitle ON groupPayrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.[Node].IsDescendantOf(groupPayrollWageTitle.[Node]) = 1 AND payrollWageTitle.ID <> groupPayrollWageTitle.ID
	--INNER JOIN wag.WageTitle groupWageTitle ON groupWageTitle.ID = groupPayrollWageTitle.WageTitleID
	--WHERE 
	--	(@LawID IS NULL OR payroll.LawID = @LawID)
	--	AND (@OrganID IS NULL OR payroll.OrganID = @OrganID)
	--	AND (@Year < 1 OR payroll.[Year] = @Year)
	--	AND (@Month < 1 OR payroll.[Month] = @Month)
	--Group BY org.[Name], groupWageTitle.[Name], groupWageTitle.[Code], payroll.[Year], payroll.[Month], emp.JobBase

    RETURN @@ROWCOUNT 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetReportByPostLevel') IS NOT NULL
    DROP PROCEDURE wag.spGetReportByPostLevel
GO

CREATE PROCEDURE wag.spGetReportByPostLevel
	@ALawID UNIQUEIDENTIFIER
	, @AOrganID UNIQUEIDENTIFIER
	, @AWageTitleGroupIDs NVARCHAR(1000)
	, @APostLevels NVARCHAR(1000)
	, @AYear SMALLINT
	, @AMonth TINYINT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @LawID UNIQUEIDENTIFIER = @ALawID
		, @OrganID UNIQUEIDENTIFIER = @AOrganID
		, @WageTitleGroupIDs NVARCHAR(1000) = LTRIM(RTRIM(@AWageTitleGroupIDs))
		, @PostLevels NVARCHAR(1000) = LTRIM(RTRIM(@APostLevels))
		, @Year SMALLINT = @AYear
		, @Month TINYINT = @AMonth 

	SELECT
		 org.Name OrganName
		, groupWageTitle.[Name] WageTitleGroupName
		, groupWageTitle.[Code] WageTitleGroupCode
		, payroll.[Year]
		, payroll.[Month]
		--, emp.PostLevel
		, Count(emp.ID) EmployeeCount
		, CAST(Avg(detail.Amount) AS DECIMAL(12)) AvgAmount
		, CAST(Max(detail.Amount) AS DECIMAL(12)) MaxAmount
		, CAST(Min(detail.Amount) AS DECIMAL(12)) MinAmount
	FROM wag.PayrollDetail detail
	INNER JOIN wag.PayrollEmployee emp ON emp.ID = detail.ID 
	INNER JOIN wag.Payroll payroll ON payroll.ID = emp.PayrollID
	INNER JOIN org.Organ org ON org.[Guid] = Payroll.OrganID
	INNER JOIN wag.WageTitle wageTitle ON wageTitle.ID = detail.WageTitleID
	INNER JOIN wag.PayrollWageTitle payrollWageTitle ON payrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.WageTitleID = WageTitle.ID
	INNER JOIN wag.PayrollWageTitle groupPayrollWageTitle ON groupPayrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.[Node].IsDescendantOf(groupPayrollWageTitle.[Node]) = 1 AND payrollWageTitle.ID <> groupPayrollWageTitle.ID
	INNER JOIN wag.WageTitle groupWageTitle ON groupWageTitle.ID = groupPayrollWageTitle.WageTitleID
	Group BY org.Name, groupWageTitle.[Name], groupWageTitle.[Code], payroll.[Year], payroll.[Month] --, emp.PostLevel

	--SELECT
	--	org.Name OrganName
	--	, groupWageTitle.[Name] WageTitleGroupName
	--	, groupWageTitle.[Code] WageTitleGroupCode
	--	, payroll.[Year]
	--	, payroll.[Month]
	--	, emp.PostLevel
	--	, Count(emp.ID) EmployeeCount
	--	, CAST(Avg(detail.Amount) AS DECIMAL(12)) AvgAmount
	--	, CAST(Max(detail.Amount) AS DECIMAL(12)) MaxAmount
	--	, CAST(Min(detail.Amount) AS DECIMAL(12)) MinAmount
	--FROM wag.PayrollDetail detail
	--INNER JOIN wag.Payroll payroll ON payroll.ID = detail.PayrollID
	--INNER JOIN org.Organ org ON org.[Guid] = Payroll.OrganID
	--INNER JOIN wag.PayrollEmployee emp ON emp.PayrollID = payroll.ID AND emp.IndividualID = detail.IndividualID
	--INNER JOIN wag.WageTitle wageTitle ON wageTitle.ID = detail.WageTitleID
	--INNER JOIN wag.PayrollWageTitle payrollWageTitle ON payrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.WageTitleID = WageTitle.ID
	--INNER JOIN wag.PayrollWageTitle groupPayrollWageTitle ON groupPayrollWageTitle.PayrollID = payroll.ID AND payrollWageTitle.[Node].IsDescendantOf(groupPayrollWageTitle.[Node]) = 1 AND payrollWageTitle.ID <> groupPayrollWageTitle.ID
	--INNER JOIN wag.WageTitle groupWageTitle ON groupWageTitle.ID = groupPayrollWageTitle.WageTitleID
	--WHERE 
	--	(@LawID IS NULL OR payroll.LawID = @LawID)
	--	AND (@OrganID IS NULL OR payroll.OrganID = @OrganID)
	--	AND (@Year < 1 OR payroll.[Year] = @Year)
	--	AND (@Month < 1 OR payroll.[Month] = @Month)
	--Group BY org.[Name], groupWageTitle.[Name], groupWageTitle.[Code], payroll.[Year], payroll.[Month], emp.PostLevel

    RETURN @@ROWCOUNT 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('rpt.spGetReportSummaryByPayrollEmployee'))
DROP PROCEDURE rpt.spGetReportSummaryByPayrollEmployee
GO

CREATE PROCEDURE rpt.spGetReportSummaryByPayrollEmployee
	@AOrganIDs NVARCHAR(MAX),
	@AOrganID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@AEmploymentType TINYINT,
	@AWpProvinceID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@OrganIDs NVARCHAR(MAX) = LTRIM(RTRIM(@AOrganIDs)),
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@WpProvinceID UNIQUEIDENTIFIER = @AWpProvinceID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID


	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)


	;WITH Organ AS
	(
		SELECT DISTINCT 
			Department.ID,
			Department.[Name]
		FROM org.Department
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Department.ID
		WHERE (@OrganIDs IS NULL OR OrganIDs.value IS NOT NULL)
			AND (@OrganID IS NULL OR Department.ID = @OrganID)
			AND (@ParentOrganID IS NULL OR Department.[Node].IsDescendantOf(@ParentOrganNode) = 1)
			AND (@WpProvinceID IS NULL OR Department.ProvinceID = @WpProvinceID AND Department.[Type] = 2)
	)
	--, EmployeeInfo AS(
	--	SELECT
	--		ROW_NUMBER() OVER(partition by info.NationalCode ORDER BY info.[Year] DESC, info.[Month] DESC) RowNumber,
	--		info.NationalCode,
	--		info.[Year],
	--		info.[Month],
	--		info.OrganID,
	--		info.EmploymentType
	--	FROM [Kama.Aro.Salary.Extention].[rpt].[PayrollEmployeeDynamicReport] info
	--)
	, MainSelect AS
	(
		SELECT 
			info.EmploymentType,
			COUNT(*) [Count]
		FROM  [Kama.Aro.Salary.Extention].[rpt].[PayrollEmployeeDynamicReportUniqueByNationalCode] info
			INNER JOIN Organ ON Organ.ID = info.OrganID
		WHERE (@EmploymentType < 1 OR info.EmploymentType = @EmploymentType)
		GROUP BY info.EmploymentType
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY EmploymentType
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('rpt.spGetTreasuryRequestAggrigation'))
	DROP PROCEDURE rpt.spGetTreasuryRequestAggrigation
GO

CREATE PROCEDURE rpt.spGetTreasuryRequestAggrigation
	@ATreasuryRequestID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@AMonth INT,
	@AYear INT

AS
BEGIN
	DECLARE
	    @TreasuryRequestID UNIQUEIDENTIFIER = @ATreasuryRequestID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID ,
		@LastMonthTreasuryRequestID UNIQUEIDENTIFIER,
		@Month INT = @AMonth,
		@Year INT = @AYear
	
	SET @LastMonthTreasuryRequestID = ( 
	SELECT tr.ID FROM wag.TreasuryRequest tr
	INNER JOIN pbl.basedocument bd on bd.ID = tr.id 
	WHERE tr.organid = @OrganID AND tr.[Year] = @Year AND tr.[Month] = @Month -1
	AND bd.Removedate IS NULL)

	

	; WITH t1lastMonth as 
	(
		SELECT
		distinct
			e.ID empid,
			pe.ID peid,
			p.PayrollType,
			ped.PlaceFinancing,
			p.LawName,
			e.[EmploymentType],
			pe.sumhokm,
			ped.sumNHokm
		FROM wag._payroll p
			INNER JOIN wag.payrollemployee pe ON pe.payrollid = p.id
			INNER JOIN [wag].[PayrollEmployeeDetail] ped ON ped.ID = pe.id
			INNER JOIN wag.TreasuryRequest tr ON p.RequestID = tr.id
			inner join pbl.BaseDocument bd on bd.ID = tr.ID
			INNER JOIN [wag].[TreasuryRequestDetail] trd ON trd.requestid = tr.id
			INNER JOIN emp.employee e ON e.id = pe.employeeid
		WHERE tr.id = @LastMonthTreasuryRequestID
		and bd.RemoveDate is null
		and pe.SumHokm is not null
	)
	
	, lastMonthEmployeeCount AS 
	(
		SELECT
			t1.PayrollType,
			t1.PlaceFinancing,
			t1.LawName,
			t1.[EmploymentType],
			COALESCE(SUM(t1.sumHokm), 0) AS sumHokm,
			COALESCE(SUM(t1.sumNHokm), 0) AS sumNHokm,
			COALESCE(COUNT(DISTINCT t1.empid), 0) countEmployee
		FROM t1lastMonth t1
		GROUP BY
			payrolltype,
			PlaceFinancing,
			lawname,
			[EmploymentType]

	)
	, wageGroup AS 
	(
		SELECT
			pec.[PayrollEmployeeID],
			pec.[WageGroupID],
			wg.[type],
			COALESCE(pec.[Amount], 0) AS amount
		FROM [rpt].[PayrollEmployeeCalculation] pec
			INNER JOIN [rpt].[WageGroup] wg ON wg.id = pec.WageGroupID
			INNER JOIN wag.payrollEmployee pe ON pe.ID = pec.PayrollEmployeeID
			INNER JOIN wag._payroll p ON p.ID = pe.payrollid
		WHERE p.requestid = @TreasuryRequestID
	)
	, t1 as 
	(
	SELECT
	distinct
			e.ID empid,
			pe.ID peid,
			p.PayrollType,
			ped.PlaceFinancing,
			p.LawName,
			e.[EmploymentType],
			pe.sumhokm,
			ped.sumNHokm
		FROM wag._payroll p
			INNER JOIN wag.payrollemployee pe ON pe.payrollid = p.id
			INNER JOIN [wag].[PayrollEmployeeDetail] ped ON ped.ID = pe.id
			INNER JOIN wag.TreasuryRequest tr ON p.RequestID = tr.id
			inner join pbl.BaseDocument bd on bd.ID = tr.ID
			INNER JOIN [wag].[TreasuryRequestDetail] trd ON trd.requestid = tr.id
			INNER JOIN emp.employee e ON e.id = pe.employeeid
		WHERE tr.id = @TreasuryRequestID
		and bd.RemoveDate is null
		and pe.SumHokm is not null
		--GROUP BY
		--	--pe.ID,
		--	p.payrolltype,
		--	trd.PlaceFinancing,
		--	p.lawname,
		--	e.[EmploymentType],
		--	pe.sumhokm,
		--	ped.sumNHokm
	)
	,  MainSelect AS
	(
		SELECT
			t1.PayrollType,
			t1.PlaceFinancing,
			t1.LawName,
			t1.[EmploymentType],
			count(distinct t1.empid) countEmployee,
			SUM(t1.sumHokm) AS sumHokm,
			SUM(t1.sumNHokm) AS sumNHokm,
			SUM(sumDeductionPerson.amount) AS sumDeductionPerson,
			SUM(sumDeductionOrgan.amount) AS sumDeductionOrgan,
			SUM(KomakHazineMaskan.amount) AS KomakHazineMaskan,
			SUM(komakHazinerefahi.amount) AS komakHazinerefahi,
			SUM(refahiyatTaklifi.amount) AS refahiyatTaklifi,
			SUM(madeh10.amount) AS madeh10,
			SUM(Karane.amount) AS Karane,
			SUM(sumDeductionGov.amount) AS sumDeductionGov,
			SUM(refahiyatMonasebati.amount) AS refahiyatMonasebati,
			SUM(sumEzafeKar.amount) AS sumEzafeKar
		FROM t1
			LEFT JOIN wageGroup sumDeductionPerson ON sumDeductionPerson.PayrollEmployeeID = t1.peid AND sumDeductionPerson.[type] = 1
			LEFT JOIN wageGroup sumDeductionOrgan ON sumDeductionOrgan.PayrollEmployeeID = t1.peid AND sumDeductionOrgan.[type] = 2
			LEFT JOIN wageGroup sumDeductionGov ON sumDeductionGov.PayrollEmployeeID = t1.peid AND sumDeductionGov.[type] = 3
			LEFT JOIN wageGroup sumEzafeKar ON sumEzafeKar.PayrollEmployeeID = t1.peid AND sumEzafeKar.[type] = 4
			LEFT JOIN wageGroup refahiyatTaklifi ON refahiyatTaklifi.PayrollEmployeeID = t1.peid AND refahiyatTaklifi.[type] = 5
			LEFT JOIN wageGroup refahiyatMonasebati ON refahiyatMonasebati.PayrollEmployeeID = t1.peid AND refahiyatMonasebati.[type] = 6
			LEFT JOIN wageGroup KomakHazineMaskan ON KomakHazineMaskan.PayrollEmployeeID = t1.peid AND KomakHazineMaskan.[type] = 7
			LEFT JOIN wageGroup Karane ON Karane.PayrollEmployeeID = t1.peid AND Karane.[type] = 8
			LEFT JOIN wageGroup madeh10 ON madeh10.PayrollEmployeeID = t1.peid AND madeh10.[type] = 9
			LEFT JOIN wageGroup komakHazinerefahi ON komakHazinerefahi.PayrollEmployeeID = t1.peid AND komakHazinerefahi.[type] = 10
		GROUP BY
			payrolltype,
			PlaceFinancing,
			lawname,
			[EmploymentType]
	)
	,  MainSelect2 AS
	(
		SELECT
			ms.PayrollType,
			ms.PlaceFinancing,
			ms.LawName,
			ms.[EmploymentType],
			ms.CountEmployee,
			ms.SumHokm,
			ms.SumNHokm,
			COALESCE(lm.countEmployee,0 ) AS LastMonthEmployeeCount,
			COALESCE(lm.sumHokm,0 ) AS LastMonthSumHokm,
			COALESCE(lm.sumNHokm,0 ) AS LastMonthSumNHokm,
			COALESCE(ms.sumDeductionPerson,0 ) SumDeductionPerson,
			COALESCE(ms.sumDeductionOrgan,0 ) SumDeductionOrgan,
			COALESCE(ms.komakHazinerefahi,0 ) KomakHazinerefahi,
			COALESCE(ms.madeh10,0 ) Madeh10,
			COALESCE(ms.KomakHazineMaskan,0 ) KomakHazineMaskan,
			COALESCE(ms.refahiyatTaklifi,0 ) RefahiyatTaklifi,
			COALESCE(ms.refahiyatMonasebati,0 ) RefahiyatMonasebati,
			COALESCE(ms.Karane,0 ) Karane,
			COALESCE(ms.sumEzafeKar,0 ) SumEzafeKar,
			COALESCE(ms.sumDeductionGov,0 ) SumDeductionGov,
			CASE WHEN ms.countEmployee != 0 THEN (ms.sumHokm / ms.countEmployee) ELSE 0 END AS Avgsumhokm,
			CASE WHEN ms.countEmployee != 0 THEN (ms.sumNHokm / ms.countEmployee) ELSE 0 END AS AvgsumNhokm,
			CASE WHEN (CAST(lm.sumHokm AS DECIMAL) /lm.countEmployee) != 0 THEN COALESCE(((CAST(  (CAST(ms.sumHokm AS DECIMAL) / ms.countEmployee) - ( CAST(lm.sumHokm AS DECIMAL) /lm.countEmployee)  AS DECIMAL) / ( CAST(lm.sumHokm AS DECIMAL) /lm.countEmployee)) * 100 ),0 ) ELSE 0 END AS AvgsumhokmAll,
			CASE WHEN (CAST(lm.sumNHokm AS DECIMAL)/lm.countEmployee) != 0 THEN COALESCE((( CAST( (CAST(ms.sumNHokm AS DECIMAL)  / ms.countEmployee) - (CAST(lm.sumNHokm AS DECIMAL)/lm.countEmployee) AS DECIMAL)  / (CAST(lm.sumNHokm AS DECIMAL)/lm.countEmployee)) * 100 ),0 ) ELSE 0 END AS AvgsumNhokmAll,
			COALESCE((ms.countEmployee - lm.countEmployee),ms.countEmployee) as DifrenceWithLastMonthEmployeeCount
		from MainSelect ms
		LEFT JOIN lastMonthEmployeeCount lm ON lm.payrolltype= ms.payrolltype AND lm.PlaceFinancing = ms.PlaceFinancing AND lm.lawname = ms.lawname AND lm.[EmploymentType] = ms.[EmploymentType]
		
	)

	SELECT *
	FROM MainSelect2
END
GO



GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetWageTitleReport') IS NOT NULL
    DROP PROCEDURE wag.spGetWageTitleReport
GO

CREATE PROCEDURE wag.spGetWageTitleReport
	@APayrollIDs NVARCHAR(MAX),
	@AWageTitleID UNIQUEIDENTIFIER,
	@AFunction TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollIDs NVARCHAR(MAX) = @APayrollIDs,
		@WageTitleID UNIQUEIDENTIFIER = @AWageTitleID,
		@Function TINYINT = @AFunction

	;WITH wageTitle AS
	(
		SELECT 
			OrganID,
			CASE WHEN @Function = 2 THEN SUM(CAST(Amount AS BIGINT)) 
				WHEN @Function = 3 THEN AVG(CAST(Amount AS BIGINT)) 
				WHEN @Function = 4 THEN MIN(CAST(Amount AS BIGINT)) 
				WHEN @Function = 5 THEN MAX(CAST(Amount AS BIGINT)) 
				END Amount
		FROM wag.payrollDetail
			INNER JOIN wag.payroll ON payroll.ID = payrollDetail.PayrollID
			INNER JOIN OPENJSON(@PayrollIDs) PayrollIDs ON PayrollIDs.value = payroll.ID
		WHERE WageTitleID = @WageTitleID
		Group by 
			OrganID
	)
	SELECT 
		Count(*) OVER() Total,
		OrganID,
		organ.[Name] OrganName,
		Amount
	FROM wageTitle
		LEFT JOIN org._Department organ ON organ.ID = wageTitle.OrganID
	ORDER BY organ.Node

END
GO
USE [Kama.Aro.Pardakht]
GO

 IF EXISTS(SELECT 1 FROM SYS.procedures WHERE [object_id]= OBJECT_ID ('wag.spListByEmployee'))
 DROP PROCEDURE wag.spListByEmployee
 GO

CREATE PROCEDURE wag.spListByEmployee
	@AFirstName NVARCHAR (200),
	@ALastName NVARCHAR (200),
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@FirstName NVARCHAR(200) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(200) = LTRIM(RTRIM(@ALastName)),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID= @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH EmployeeDetail AS
	(
		SELECT 
			EmployeeDetail.*,
			organ.Name OrganName
		FROM pbl.EmployeeDetail 
			INNER JOIN pbl.Employee ON Employee.ID = EmployeeDetail.ID
			INNER JOIN org.Department organ ON organ.ID = Employee.OrganID
		WHERE 
			(Organ.Node.IsDescendantOf(@ParentOrganNode) = 1)
			AND (@FirstName IS NULL OR [FirstName] LIKE N'%' + @FirstName + '%')
			AND (@LastName IS NULL OR [LastName] LIKE N'%' +  @LastName + '%')
	)
	, PayrollEmployee AS
	(
		SELECT DISTINCT EmployeeID
		FROM wag.PayrollEmployee
			INNER JOIN pbl.BaseDocument doc ON doc.ID = PayrollEmployee.PayrollID
			INNER JOIN pbl.DocumentFlow confirmFlow ON doc.ID = confirmFlow.DocumentID AND confirmFlow.ActionDate IS NULL AND confirmFlow.ToDocState = 100
		WHERE doc.RemoveDate IS NULL
		--	AND (@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی

	)
	SELECT DISTINCT
		COUNT(*) OVER() Total,
		employeedetail.NationalCode,
		employeedetail.FirstName,
		employeedetail.LastName,
		employeedetail.FatherName,
		employeedetail.BCNumber,
		employeedetail.Gender,
		employeedetail.BirthDate,
		EmployeeDetail.OrganName
		--department.[Name] OrganName
	FROM EmployeeDetail 
		INNER JOIN PayrollEmployee  ON payrollemployee.EmployeeID = EmployeeDetail.ID
	ORDER BY employeedetail.FirstName , employeedetail.LastName
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spGetAllTreasuryRequestReport') IS NOT NULL
    DROP PROCEDURE rpt.spGetAllTreasuryRequestReport
GO

CREATE PROCEDURE rpt.spGetAllTreasuryRequestReport
	@ARequestID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@ParentOrganNode HIERARCHYID

	SET @ParentOrganNode = (SELECT [Node] FROM [Kama.Aro.Organization].org._Organ Department WHERE ID = @ParentOrganID)
	BEGIN TRY
		BEGIN TRAN
			-- Search
			;WITH Organ AS (
				SELECT
					Department.ID,
					Department.[Name],
					Department.[Node],
					Department.ParentID,
					Department.ParentName
				FROM [Kama.Aro.Organization].org._Organ Department
				INNER JOIN [Kama.Aro.Pardakht].org.SuitableOrganForPardakht SOFP ON SOFP.OrganID = Department.ID
				WHERE (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
					AND (SOFP.[Enabled] = 1)
			)
			, AllOrgans AS (
				SELECT
					Department.ID,
					Department.[Name],
					Department.[Node],
					Department.ParentID,
					Department.ParentName
				FROM [Kama.Aro.Organization].org._Organ Department
				INNER JOIN [Kama.Aro.Organization].[org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.[DepartmentID] = Department.ID AND departmentEnableState.ApplicationID = 'ABDB7E65-B3FB-442A-801A-B7B319EFC18B'
				WHERE (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
					AND (departmentEnableState.[Enable] = 1)
			)
			, CountAllOrgans AS (
				SELECT
					@ParentOrganID ParentOrganID,
					COUNT (AllOrgans.ID) CountAllOrgans
				FROM AllOrgans
			)
			, ValidDepartments AS ( -- Select Organs Whom Should Have Treasury Request Base on Department Budget
				SELECT DISTINCT
					ChildDepartment.ID
				FROM Organ ChildDepartment
				LEFT JOIN Organ ParentDepartment ON ParentDepartment.[ID] = ChildDepartment.[ParentID]
				LEFT JOIN [Kama.Aro.Organization].[org].[DepartmentBudget] ParentDB ON ParentDB.[DepartmentID] = ParentDepartment.[ID]
				LEFT JOIN [Kama.Aro.Organization].[org].[DepartmentBudget] ChildDB ON ChildDB.[DepartmentID] = ChildDepartment.[ID]
				INNER JOIN [Kama.Aro.Pardakht].[org].[SuitableOrganForPardakht] SOFP ON sofp.[OrganID] = ChildDepartment.ID
				WHERE SOFP.[Enabled] = 1
					AND (ChildDB.[SalaryInputBudgetCode] IS NOT NULL)
					AND (ChildDB.[SalaryInputBudgetCode] = ChildDB.[BudgetCode])
					AND (COALESCE(ChildDB.SalaryInputBudgetCode, '') <> COALESCE(ParentDB.SalaryInputBudgetCode, ''))
			)
			, OrgansShouldHaveTreasuryRequest AS ( -- Count Organs Whom Should Have Treasury Request Base on Department Budget
				SELECT 
					@ParentOrganID ParentOrganID,
					COUNT(DISTINCT ValidDepartments.ID) CountOrgans
				FROM ValidDepartments
			)
			, OrgansHaveTreasuryRequest AS (  -- Count Organs Whom Have Treasury Request Base on Department Budget
				SELECT 
					@ParentOrganID ParentOrganID,
					COUNT(DISTINCT ValidDepartments.ID) CountOrgans
				FROM ValidDepartments
				INNER JOIN wag.TreasuryRequest  on TreasuryRequest.OrganID = ValidDepartments.ID
				INNER JOIN pbl.BaseDocument Document ON Document.ID = TreasuryRequest.ID
				INNER JOIN pbl.DocumentFlow Flow ON Flow.DocumentID = Document.ID  AND Flow.ActionDate IS NULL
				WHERE (Document.RemoveDate IS NULL AND CAST(COALESCE(Flow.ToDocState, 0) AS TINYINT) >= 40) -- Last Flow >= 40
					AND (@RequestID IS NULL OR TreasuryRequest.ID = @RequestID)
					AND (@Month < 1 OR TreasuryRequest.[Month] = @Month)
					AND (@Year < 1 OR TreasuryRequest.[Year] = @Year)
			)
			, TreasuryRequest AS ( -- Select Finalize Treasury Requests
				SELECT
					TR.ID RequestID,
					TRO.OrganID RequestOrganID,
					COUNT(TRO.OrganID) OrganCount
				FROM wag.TreasuryRequest TR
					INNER JOIN wag.TreasuryRequestOrgan TRO ON TRO.RequestID = TR.ID
					INNER JOIN Organ ON Organ.ID = TRO.OrganID
					INNER JOIN pbl.BaseDocument Document ON Document.ID = TR.ID
					INNER JOIN pbl.DocumentFlow Flow ON Flow.DocumentID = Document.ID  AND Flow.ActionDate IS NULL
				WHERE (Document.RemoveDate IS NULL AND CAST(COALESCE(Flow.ToDocState, 0) AS TINYINT) >= 40) -- Last Flow >= 40
					AND (@RequestID IS NULL OR TR.ID = @RequestID)
					AND (@Month < 1 OR TR.[Month] = @Month)
					AND (@Year < 1 OR TR.[Year] = @Year)
				GROUP BY TR.ID, TRO.OrganID
			)
			, AllTreasuryRequest AS ( -- Select All Treasury Requests
				SELECT
					TR.ID RequestID
				FROM wag.TreasuryRequest TR
					INNER JOIN wag.TreasuryRequestOrgan TRO ON TRO.RequestID = TR.ID
					INNER JOIN [Kama.Aro.Organization].org._Organ Organ ON Organ.ID = TRO.OrganID
					INNER JOIN pbl.BaseDocument Document ON Document.ID = TR.ID
				WHERE (Document.RemoveDate IS NULL)
					AND (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
					AND (@RequestID IS NULL OR TR.ID = @RequestID)
					AND (@Month < 1 OR TR.[Month] = @Month)
					AND (@Year < 1 OR TR.[Year] = @Year)
			)
			, CountAllTreasuryRequest AS ( -- Count Select Treasury Requests
				SELECT
					@ParentOrganID ParentOrganID,
					COUNT(DISTINCT TR.RequestID) RequestCount
				FROM AllTreasuryRequest TR
			)
			, PardakhtEmployees AS ( -- Total Employees Whom Have Pardakht Details
				SELECT 
					Employee.OrganID EmployeeOrganID,
					Employee.ID EmployeeID
				FROM [emp].[Employee] Employee
				INNER JOIN Organ ON Organ.ID = Employee.OrganID
				INNER JOIN [wag].[PayrollEmployee] PE ON Employee.ID = PE.EmployeeID
				INNER JOIN [wag].[_Payroll] Payroll ON  Payroll.ID = PE.PayrollID
				INNER JOIN [emp].[EmployeeCatalog] EC ON EC.ID = Employee.EmployeeCatalogID
				INNER JOIN TreasuryRequest ON TreasuryRequest.RequestID = EC.TreasuryRequestID
				WHERE (@Month < 1 OR EC.[Month] = @Month)
					AND (@Year < 1 OR EC.[Year] = @Year)
					AND (PE.SumPayments <> 0 OR PE.SumDeductions <> 0)
				GROUP BY Employee.OrganID, Employee.ID
			)
			-- All Errors
			, TaxPayrollError AS (
				SELECT 
				PardakhtEmployees.EmployeeOrganID,
				PardakhtEmployees.EmployeeID,
				SUM(pd.Amount) TaxAmount
				FROM PardakhtEmployees
				INNER JOIN wag.PayrollEmployee pe ON pe.EmployeeID = PardakhtEmployees.EmployeeID
				INNER JOIN wag.PayrollDetail pd ON pd.PayrollEmployeeID = pe.ID
				INNER JOIN wag.WageTitle wt ON wt.ID = pd.WageTitleID
				INNER JOIN emp.Employee em ON em.ID = PardakhtEmployees.EmployeeID
				WHERE (wt.[Type] = 4)
				AND (pd.Amount > 0)
				AND ((em.SacrificialType IN (58, 21, 42, 1)) OR (em.SacrificialType = 50 AND em.FrontlineDuration > 365))
				GROUP BY
					PardakhtEmployees.EmployeeOrganID,
					PardakhtEmployees.EmployeeID
			)
			, TotalTaxPayrollError AS (
				SELECT 
				TaxPayrollError.EmployeeOrganID,
				COUNT(DISTINCT TaxPayrollError.EmployeeID) CountTaxAmount
				FROM TaxPayrollError
				GROUP BY
					TaxPayrollError.EmployeeOrganID
			)
			, TotalPardakhtEmployeePaknaConfilict AS ( -- Count All Employee Errors
				SELECT
					PardakhtEmployees.EmployeeOrganID,
					COUNT(EmployeeError.ID) [PaknaEmployeeConfilictErrorCount]
				FROM PardakhtEmployees
					INNER JOIN [emp].[EmployeeError] EmployeeError ON PardakhtEmployees.EmployeeID = EmployeeError.EmployeeID
				WHERE EmployeeError.ErrorType IS NOT NULL
				GROUP BY PardakhtEmployees.EmployeeOrganID
			)
			, TotalNotInPaknaBasketEmployeeError AS ( -- Count Employees That Not Suitable For Pardakht
				SELECT
					PardakhtEmployees.EmployeeOrganID,
					COUNT(EmployeeError.EmployeeID) [NotSuitableForPardakhtEmployeeCount]
				FROM PardakhtEmployees 
					INNER JOIN [emp].[EmployeeError] EmployeeError ON PardakhtEmployees.EmployeeID = EmployeeError.EmployeeID
				WHERE EmployeeError.ErrorType < 100
				GROUP BY PardakhtEmployees.EmployeeOrganID
			)
			, TotalPardakhtBasketEmployeeError AS ( -- Count Employee's information Confilicts
				SELECT
					PardakhtEmployees.EmployeeOrganID,
					COUNT(EmployeeError.EmployeeID) [PaknaEmployeeErrorCount]
				FROM PardakhtEmployees 
					INNER JOIN [emp].[EmployeeError] EmployeeError ON PardakhtEmployees.EmployeeID = EmployeeError.EmployeeID
				WHERE EmployeeError.ErrorType > 100
				GROUP BY PardakhtEmployees.EmployeeOrganID
			)
			-- Distincted Errors
			, TotalDistinctedEmployeeConfilict AS ( -- Count Employees Whom Have At Least One Confilict
				SELECT
					PardakhtEmployees.EmployeeOrganID,
					COUNT(DISTINCT EmployeeError.EmployeeID) [TotalEmployeeErrorCount]
				FROM PardakhtEmployees 
					INNER JOIN [emp].[EmployeeError] EmployeeError ON PardakhtEmployees.EmployeeID = EmployeeError.EmployeeID
				GROUP BY PardakhtEmployees.EmployeeOrganID
			)
			, CalculateEmployee AS ( -- Count Employees Whom Have At Least On Pardakht Detail
				SELECT
					PardakhtEmployees.EmployeeOrganID,
					COUNT(PardakhtEmployees.EmployeeID) [PardakhtEmployeeCount]
				FROM  PardakhtEmployees
				GROUP BY PardakhtEmployees.EmployeeOrganID
			)
			-- Select
			, AllDepartment AS (
				SELECT 
					Department.ID OrganID,
					Department.Name DepartmentName,
					TreasuryRequest.RequestID,
					COALESCE(TreasuryRequest.OrganCount, 0) RequestOrganCount,
					COALESCE(CalculateEmployee.PardakhtEmployeeCount, 0) EmployeesCount,
					COALESCE(TotalDistinctedEmployeeConfilict.TotalEmployeeErrorCount, 0) EmployeesHaveConfilictCount,
					COALESCE(TotalPardakhtEmployeePaknaConfilict.PaknaEmployeeConfilictErrorCount, 0) TotalConfilictCount,
					COALESCE(TotalNotInPaknaBasketEmployeeError.NotSuitableForPardakhtEmployeeCount, 0) TotalNotInPardakhtBasketConflictCount,
					COALESCE(TotalPardakhtBasketEmployeeError.PaknaEmployeeErrorCount, 0) TotalPardakhtBasketConflictCount,
					COALESCE(TotalTaxPayrollError.CountTaxAmount, 0) TotalPayrollConflictCount,
					0 TotalOtherConflictCount
				FROM Organ
				LEFT JOIN TreasuryRequest ON TreasuryRequest.RequestOrganID = Organ.ID
				LEFT JOIN [org].[Department] Department ON Department.ID = Organ.ID
				LEFT JOIN TotalPardakhtEmployeePaknaConfilict ON TotalPardakhtEmployeePaknaConfilict.EmployeeOrganID = Organ.ID
				LEFT JOIN TotalNotInPaknaBasketEmployeeError ON TotalNotInPaknaBasketEmployeeError.EmployeeOrganID = Organ.ID
				LEFT JOIN TotalPardakhtBasketEmployeeError ON TotalPardakhtBasketEmployeeError.EmployeeOrganID = Organ.ID
				LEFT JOIN TotalDistinctedEmployeeConfilict ON TotalDistinctedEmployeeConfilict.EmployeeOrganID = Organ.ID
				LEFT JOIN CalculateEmployee ON CalculateEmployee.EmployeeOrganID = Organ.ID
				LEFT JOIN TotalTaxPayrollError ON TotalTaxPayrollError.EmployeeOrganID = Organ.ID
			)
			, GroupDepartment AS (
				SELECT
					@Month [RequestMonth],
					@Year [RequestYear],
					SUM(CASE WHEN RequestOrganCount > 0 THEN 1 ELSE 0 END) [OrganWithRequest],
					SUM(CASE WHEN RequestOrganCount = 0 THEN 1 ELSE 0 END) [OrganWithoutRequest],
					SUM(EmployeesCount) EmployeesCount,
					SUM(EmployeesHaveConfilictCount) EmployeesHaveConfilictCount,
					SUM(TotalConfilictCount) TotalConfilictCount,
					SUM(TotalNotInPardakhtBasketConflictCount) TotalNotInPardakhtBasketConflictCount,
					SUM(TotalPardakhtBasketConflictCount) TotalPardakhtBasketConflictCount,
					SUM(TotalPayrollConflictCount) TotalPayrollConflictCount,
					0 TotalOtherConflictCount
				FROM AllDepartment
			)
			SELECT DISTINCT
				Organ.ID ParentOrganID,
				Organ.[Name] ParentOrganName,
				OrgansShouldHaveTreasuryRequest.CountOrgans OrgansShouldHaveTreasuryRequest,
				OrgansHaveTreasuryRequest.CountOrgans OrgansHaveTreasuryRequest,
				CountAllOrgans.CountAllOrgans CountAllOrgans,
				CountAllTreasuryRequest.RequestCount CountAllTreasuryRequest,
				GroupDepartment.*
			FROM GroupDepartment
			LEFT JOIN Organ ON Organ.ID = @ParentOrganID
			LEFT JOIN OrgansShouldHaveTreasuryRequest ON Organ.ID = OrgansShouldHaveTreasuryRequest.ParentOrganID
			LEFT JOIN OrgansHaveTreasuryRequest  ON Organ.ID = OrgansHaveTreasuryRequest.ParentOrganID
			LEFT JOIN CountAllOrgans  ON CountAllOrgans.ParentOrganID = Organ.ID 
			LEFT JOIN CountAllTreasuryRequest  ON CountAllTreasuryRequest.ParentOrganID = Organ.ID 


		COMMIT
	END TRY
	BEGIN CATCH
		;THROW 
	END CATCH

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spGetAllTreasuryRequestReportDetails') IS NOT NULL
    DROP PROCEDURE rpt.spGetAllTreasuryRequestReportDetails
GO

CREATE PROCEDURE rpt.spGetAllTreasuryRequestReportDetails 
	@ARequestID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@ParentOrganNode HIERARCHYID

	SET @ParentOrganNode = (SELECT [Node] FROM [Kama.Aro.Organization].org.Department WHERE ID = @ParentOrganID)
	BEGIN TRY
		BEGIN TRAN
			-- Search
			; WITH Organ AS (
				SELECT
					Department.ID,
					Department.[Name],
					Department.[Node],
					Department.ParentID,
					Department.ParentName
				FROM [Kama.Aro.Organization].org._Organ Department
				INNER JOIN [Kama.Aro.Pardakht].org.SuitableOrganForPardakht SOFP ON SOFP.OrganID = Department.ID
				WHERE (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
					AND (SOFP.[Enabled] = 1)
			)
			, TreasuryRequest AS(
				SELECT DISTINCT
					TR.ID RequestID,
					TRO.OrganID OrganID
				FROM wag.TreasuryRequest TR
					INNER JOIN wag.TreasuryRequestOrgan TRO ON TRO.RequestID = TR.ID
					INNER JOIN Organ ON Organ.ID = TRO.OrganID
					INNER JOIN pbl.BaseDocument Document ON Document.ID = TR.ID
					INNER JOIN pbl.DocumentFlow Flow ON Flow.DocumentID = Document.ID  AND Flow.ActionDate IS NULL
				WHERE (Document.RemoveDate IS NULL AND CAST(COALESCE(Flow.ToDocState, 0) AS TINYINT) >= 40) -- Last Flow >= 40
					AND (@RequestID IS NULL OR TR.ID = @RequestID)
					AND (@Month < 1 OR TR.[Month] = @Month)
					AND (@Year < 1 OR TR.[Year] = @Year)
			)
			, Employees AS ( -- Total Pardakht Employees
				SELECT DISTINCT
					TreasuryRequest.RequestID,
					Employee.ID EmployeeID,
					Employee.NationalCode EmployeeNationalCode,
					Employee.OrganID EmployeeOrganID,
					Employee.EmployeeCatalogID EmployeeCatalogID,
					Employee.EmploymentType EmployeeEmploymentType
				FROM emp.Employee Employee
				INNER JOIN Organ ON Organ.ID = Employee.OrganID
				INNER JOIN emp.EmployeeCatalog EC ON EC.ID = Employee.EmployeeCatalogID
				INNER JOIN TreasuryRequest ON TreasuryRequest.RequestID = EC.TreasuryRequestID
				WHERE (@Month < 1 OR EC.[Month] = @Month)
					AND (@Year < 1 OR EC.[Year] = @Year)
			)
			, PardakhtEmployees AS ( -- Total PardakhtEmployees Whom Have Pardakht Details
				SELECT
					Employees.EmployeeID EmployeeID,
					Employees.EmployeeOrganID,
					Employees.EmployeeCatalogID,
					Employees.EmployeeEmploymentType
				FROM Employees
				INNER JOIN wag.PayrollEmployee PE ON PE.EmployeeID = Employees.EmployeeID
				INNER JOIN wag._Payroll Payroll ON  Payroll.ID = PE.PayrollID
				where PE.SumPayments <> 0 OR PE.SumDeductions <> 0 
				Group by 
					Employees.EmployeeID,
					Employees.EmployeeOrganID,
					Employees.EmployeeCatalogID,
					Employees.EmployeeEmploymentType
			)
			, CalculateEmployee AS ( -- Calculate Pardakht Employees' Employment Type
				SELECT
					PardakhtEmployees.EmployeeOrganID,
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 1 THEN 1 ELSE 0 END) [Type1Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 2 THEN 1 ELSE 0 END) [Type2Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 3 THEN 1 ELSE 0 END) [Type3Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 6 THEN 1 ELSE 0 END) [Type6Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 10 THEN 1 ELSE 0 END) [Type10Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 11 THEN 1 ELSE 0 END) [Type11Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 12 THEN 1 ELSE 0 END) [Type12Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 13 THEN 1 ELSE 0 END) [Type13Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 14 THEN 1 ELSE 0 END) [Type14Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 15 THEN 1 ELSE 0 END) [Type15Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 16 THEN 1 ELSE 0 END) [Type16Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 18 THEN 1 ELSE 0 END) [Type18Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 19 THEN 1 ELSE 0 END) [Type19Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 21 THEN 1 ELSE 0 END) [Type21Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 22 THEN 1 ELSE 0 END) [Type22Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 23 THEN 1 ELSE 0 END) [Type23Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 24 THEN 1 ELSE 0 END) [Type24Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 100 THEN 1 ELSE 0 END) [Type100Count]
				FROM PardakhtEmployees
				Group BY 
					EmployeeOrganID
			)
			, EmployeePerOrgan AS ( -- Count Employee Per Organ
				SELECT
					Employees.EmployeeOrganID OrganID,
					COUNT(DISTINCT EmployeeID) EmployeeCount
				FROM Employees
				GROUP BY 
					Employees.EmployeeOrganID
			)
			, PayrollEmployeesPerOrgan AS ( -- Count Employees Whom Have At Least One Pardakht Details
				SELECT
					PardakhtEmployees.EmployeeOrganID OrganID,
					COUNT(DISTINCT PardakhtEmployees.EmployeeID) TreasuryRequestEmployeeCount
				FROM PardakhtEmployees
				GROUP BY EmployeeOrganID
			)
			, PaknaConfilictEmployeeError AS (
				SELECT
					PardakhtEmployees.*,
					EmployeeError.ID EmployeeErrorID,
					EmployeeError.ErrorType EmployeeErrorType
				FROM [emp].[EmployeeError] EmployeeError 
				INNER JOIN PardakhtEmployees ON EmployeeError.EmployeeID = PardakhtEmployees.EmployeeID
			)
			, TotalEmployeeErrorCount AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID OrganID,
					COUNT(PaknaConfilictEmployeeError.EmployeeErrorID) TotalEmployeeErrorCount
				FROM PaknaConfilictEmployeeError
				GROUP BY EmployeeOrganID
			)
			, ErrorPerOrgan AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID OrganID,
					COUNT(DISTINCT PaknaConfilictEmployeeError.EmployeeID) ErrorPerOrgan
				FROM PaknaConfilictEmployeeError
				GROUP BY PaknaConfilictEmployeeError.EmployeeOrganID
			)
			, TotalNotInBasketEmployeeErrors AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID,
					COUNT(PaknaConfilictEmployeeError.EmployeeErrorID) TotalNotInBasketEmployee
				FROM PaknaConfilictEmployeeError
				WHERE EmployeeErrorType < 100
				GROUP BY PaknaConfilictEmployeeError.EmployeeOrganID
			)
			, TotalBasketConfilictEmployeeErrors AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID,
					COUNT(PaknaConfilictEmployeeError.EmployeeErrorID) TotalBasketConfilictEmployee
				FROM PaknaConfilictEmployeeError
				WHERE EmployeeErrorType > 100
				GROUP BY EmployeeOrganID
			)
			, EmployeeNotInBasketEmployeeErrors AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID,
					COUNT(Distinct PaknaConfilictEmployeeError.EmployeeID) EmployeeNotInBasketEmployee
				FROM PaknaConfilictEmployeeError
				WHERE EmployeeErrorType < 100
				GROUP BY EmployeeOrganID
			)
			, EmployeeBasketConfilictEmployeeErrors AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID,
					COUNT(Distinct PaknaConfilictEmployeeError.EmployeeID) EmployeeBasketConfilictEmployee
				FROM PaknaConfilictEmployeeError
				WHERE EmployeeErrorType > 100
				GROUP BY  PaknaConfilictEmployeeError.EmployeeOrganID
			)
			, ErrorPerEmployee AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeID,
					PaknaConfilictEmployeeError.EmployeeOrganID,
					--PaknaConfilictEmployeeError.RequestID,
					COUNT(PaknaConfilictEmployeeError.EmployeeErrorType) ErrorPerEmployee
				FROM PaknaConfilictEmployeeError 
				GROUP BY
					PaknaConfilictEmployeeError.EmployeeID,
					PaknaConfilictEmployeeError.EmployeeOrganID
					--PaknaConfilictEmployeeError.RequestID
			)
			
			SELECT 
				TreasuryRequest.RequestID RequestID,
				Organ.ID OrganID,
				Organ.ParentName ParentOrganName,
				Organ.ParentID ParentOrganID,
				Organ.[Name] OrganName,
				Organ.[Node].ToString() OrganNode,
				CAST(IIF(TreasuryRequest.RequestID IS NULL, 0, 1) AS BIT) HasRequest,
				COALESCE(EmployeePerOrgan.EmployeeCount,0) EmployeeCatalogEmployeeCount,
				COALESCE(PayrollEmployeesPerOrgan.TreasuryRequestEmployeeCount,0) PardakhtEmployeeCount,
				COALESCE(ErrorPerOrgan.ErrorPerOrgan,0) EmployeeConflictByNationalCodeCount,
				COALESCE(TotalEmployeeErrorCount.TotalEmployeeErrorCount,0) TotalEmployeeConflictCount,
				COALESCE(CalculateEmployee.Type1Count, 0)Type1Count,
				COALESCE(CalculateEmployee.Type2Count, 0)Type2Count,
				COALESCE(CalculateEmployee.Type3Count, 0)Type3Count,
				COALESCE(CalculateEmployee.Type6Count, 0)Type6Count,
				COALESCE(CalculateEmployee.Type10Count, 0)Type10Count,
				COALESCE(CalculateEmployee.Type11Count, 0)Type11Count,
				COALESCE(CalculateEmployee.Type12Count, 0)Type12Count,
				COALESCE(CalculateEmployee.Type13Count, 0)Type13Count,
				COALESCE(CalculateEmployee.Type14Count, 0)Type14Count,
				COALESCE(CalculateEmployee.Type15Count, 0)Type15Count,
				COALESCE(CalculateEmployee.Type16Count, 0)Type16Count,
				COALESCE(CalculateEmployee.Type18Count, 0)Type18Count,
				COALESCE(CalculateEmployee.Type19Count, 0)Type19Count,
				COALESCE(CalculateEmployee.Type21Count, 0)Type21Count,
				COALESCE(CalculateEmployee.Type22Count, 0)Type22Count,
				COALESCE(CalculateEmployee.Type23Count, 0)Type23Count,
				COALESCE(CalculateEmployee.Type24Count, 0)Type24Count,
				COALESCE(CalculateEmployee.Type100Count, 0)Type100Count,
				COALESCE(TotalNotInBasketEmployeeErrors.TotalNotInBasketEmployee,0) TotalNotInPardakhtBasketConflictCount,
				COALESCE(TotalBasketConfilictEmployeeErrors.TotalBasketConfilictEmployee,0) TotalPardakhtBasketConflictCount,
				0 TotalPayrollConflictCount,
				0 TotalOtherConflictCount,
				COALESCE(PayrollEmployeesPerOrgan.TreasuryRequestEmployeeCount,0) ReadyForPaymentEmployeeCount,
				COALESCE(EmployeeNotInBasketEmployeeErrors.EmployeeNotInBasketEmployee,0) EmployeesNotInPardakhtBasketCount,
				0 EmployeesHaveOtherConflictCount,
				COALESCE(EmployeeBasketConfilictEmployeeErrors.EmployeeBasketConfilictEmployee,0) EmployeeBasketConfilictEmployee
			FROM Organ
			LEFT JOIN TreasuryRequest ON TreasuryRequest.OrganID = Organ.ID
			LEFT JOIN EmployeePerOrgan ON EmployeePerOrgan.OrganID = Organ.ID
			LEFT JOIN PayrollEmployeesPerOrgan ON PayrollEmployeesPerOrgan.OrganID= Organ.ID
			LEFT JOIN ErrorPerOrgan ON ErrorPerOrgan.OrganID = Organ.ID
			LEFT JOIN TotalEmployeeErrorCount ON TotalEmployeeErrorCount.OrganID = Organ.ID
			LEFT JOIN TotalNotInBasketEmployeeErrors ON TotalNotInBasketEmployeeErrors.EmployeeOrganID = Organ.ID
			LEFT JOIN TotalBasketConfilictEmployeeErrors ON TotalBasketConfilictEmployeeErrors.EmployeeOrganID = Organ.ID
			LEFT JOIN EmployeeNotInBasketEmployeeErrors ON EmployeeNotInBasketEmployeeErrors.EmployeeOrganID = Organ.ID
			LEFT JOIN EmployeeBasketConfilictEmployeeErrors ON EmployeeBasketConfilictEmployeeErrors.EmployeeOrganID = Organ.ID
			LEFT JOIN CalculateEmployee ON CalculateEmployee.EmployeeOrganID = Organ.ID
			ORDER BY OrganNode
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW 
	END CATCH
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetOrganBankAccountReport') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetOrganBankAccountReport
GO

CREATE PROCEDURE pbl.spGetOrganBankAccountReport
		@AOrganID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@OrganID UNIQUEIDENTIFIER = @AOrganID

	;WITH OrganBankAccount AS 
	(
		SELECT DISTINCT
			[OrganID],
			[PositionSubTypeID],
			[NationalCode],
			[Sheba],
			CASE WHEN [RemoveDate] IS NULL THEN 1 ELSE 0 END [ExistingIndividualCount],
			CASE WHEN [RemoveDate] IS NOT NULL THEN 1 ELSE 0 END [DeletedIndividualCount]
		FROM [pbl].[BankAccount]
		WHERE [OrganID] = @OrganID
	)
	, TempCount AS 
	(
		SELECT
			SUM([ExistingIndividualCount]) [TotalExistingIndividualCount],
			SUM([DeletedIndividualCount]) [TotalDeletedIndividualCount]
		FROM OrganBankAccount
	)
	SELECT * FROM OrganBankAccount, TempCount
END


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spGetBankAccounts') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spGetBankAccounts
GO

CREATE PROCEDURE pbl.spGetBankAccounts
	@AOrganID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@AFirstName NVARCHAR(100),
	@ALastName NVARCHAR(100),
	@AValidType TINYINT,
	@ANationalCodes NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@FirstName NVARCHAR(100) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(100) = LTRIM(RTRIM(@ALastName)),
		@ValidType TINYINT = COALESCE(@AValidType, 0),
		@NationalCodes NVARCHAR(MAX) = LTRIM(RTRIM(@ANationalCodes)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))
		

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT
			bankAccount.[ID],
			bankAccount.[OrganID],
			dep.[Name] OrganName,
			bankAccount.[PositionSubTypeID],
			positionSubType.[Name] PositionSubTypeName,
			bankAccount.[IndividualID],
			bankAccount.[NationalCode],
			indi.FirstName,
			indi.LastName,
			indi.BirthDate,
			bankAccount.[Sheba],
			bank.Code [BankCode],
			bankAccount.[BankID],
			bank.[Name] BankName,
			bankAccount.[BranchName],
			bankAccount.[BranchCode],
			bankAccount.[ValidType],
			bankAccount.[CreatorPositionID],
			bankAccount.[CreationDate],
			bankAccount.[ProcessingDate]
		FROM pbl.BankAccount bankAccount
			INNER JOIN org.Department dep ON dep.ID = bankAccount.[OrganID]
			LEFT JOIN org.Individual indi ON indi.ID = bankAccount.IndividualID
			LEFT JOIN [pbl].[Bank] bank ON bank.ID = bankAccount.[BankID]
			LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = bankAccount.PositionSubTypeID
			LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = bankAccount.NationalCode
		WHERE  (bankAccount.RemoveDate IS NULL)
			AND (@OrganID IS NULL OR bankAccount.OrganID = @OrganID)
			AND (@PositionSubTypeID IS NULL OR bankAccount.PositionSubTypeID = @PositionSubTypeID)
			AND (@NationalCode IS NULL OR bankAccount.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR indi.FirstName LIKE '%' + @FirstName + '%')
			AND (@LastName IS NULL OR indi.LastName LIKE '%' + @LastName + '%')
			AND (@ValidType < 1 OR bankAccount.ValidType = @ValidType)
			AND (@NationalCodes IS NULL OR NationalCodes.value IS NOT NULL)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY NationalCode 		
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spGetWageGroupReport') IS NOT NULL
    DROP PROCEDURE rpt.spGetWageGroupReport
GO

CREATE PROCEDURE rpt.spGetWageGroupReport
	@ARequestID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@ABudgetCode VARCHAR(20),
	@AFinancingResourceName NVARCHAR(1500),
	@AProjectionCode VARCHAR(20),
	@AMiscellaneousBudgetCode VARCHAR(20),
	@AFromWageGroupType SMALLINT,
	@AToWageGroupType SMALLINT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@BudgetCode VARCHAR(20) = TRIM(@ABudgetCode),
		@FinancingResourceName NVARCHAR(1500) = TRIM(@AFinancingResourceName),
		@ProjectionCode VARCHAR(20) = TRIM(@AProjectionCode),
		@MiscellaneousBudgetCode VARCHAR(20) = TRIM(@AMiscellaneousBudgetCode),
		@FromWageGroupType SMALLINT = COALESCE(@AFromWageGroupType, 0),
		@ToWageGroupType SMALLINT = COALESCE(@AToWageGroupType, 0)

	; WITH MainSelect AS (
		SELECT
			WGR.PayrollEmployeeID,
			WGR.PayrollID,
			WGR.PayrollType,
			WGR.LawID,
			WGR.LawName,
			WGR.RequestID,
			WGR.[Year],
			WGR.[Month],
			WGR.BudgetCode,
			WGR.FinancingResourceName,
			WGR.ProjectionCode,
			WGR.MiscellaneousBudgetCode,
			WGR.EmployeeID,
			WGR.EmploymentType,
			WGR.IndividualID,
			WGR.NationalCode,
			WGR.SumHokm,
			WGR.WageGroupID,
			WGR.WageGroupType,
			WGR.Amount
		FROM [Kama.Aro.Pardakht.Extention].rpt.WageGroupReport WGR
		INNER JOIN wag._Payroll Payroll ON WGR.PayrollID = Payroll.ID
		LEFT JOIN rpt.WageGroup WG ON WG.ID = WGR.WageGroupID
		WHERE (WG.RemoveDate IS NULL)
		AND (@RequestID IS NULL OR @RequestID = WGR.RequestID)
		AND (@Year < 1 OR @Year = WGR.[Year])
		AND (@Month < 1 OR @Month = WGR.[Month])
		AND (@BudgetCode IS NULL OR @BudgetCode = WGR.BudgetCode)
		AND (@FinancingResourceName IS NULL OR @FinancingResourceName = WGR.FinancingResourceName)
		AND (@ProjectionCode IS NULL OR @ProjectionCode = WGR.ProjectionCode)
		AND (@MiscellaneousBudgetCode IS NULL OR @MiscellaneousBudgetCode = WGR.MiscellaneousBudgetCode)
		AND (@FromWageGroupType < 1 OR @FromWageGroupType >= WGR.WageGroupType)
		AND (@ToWageGroupType < 1 OR @ToWageGroupType <= WGR.WageGroupType)
	)
	SELECT * FROM MainSelect

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spUpdateWageGroupReport') IS NOT NULL
    DROP PROCEDURE rpt.spUpdateWageGroupReport
GO

CREATE PROCEDURE rpt.spUpdateWageGroupReport
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	DECLARE @PayrollID UNIQUEIDENTIFIER;

	SELECT TOP 1 @PayrollID=p.ID 
	FROM wag._payroll p
	LEFT JOIN [Kama.Aro.Pardakht.Extention].[rpt].[WageGroupReport] wgr on wgr.PayrollID=p.ID
	WHERE p.SalaryUpdateDate IS NOT NULL AND wgr.PayrollID IS NULL
	AND p.[State]=20
	ORDER BY SalaryUpdateDate DESC

	IF(@PayrollID IS NOT NULL)
	BEGIN
		; WITH WageGroups AS (
			SELECT [ID], [Type]
			FROM [rpt].[WageGroup]
			WHERE ([RemoveDate] IS NULL)
		)
		, WageGroupItems AS (
			SELECT WGI.WageGroupID, WG.[Type] WageGroupType, WGI.ItemID, WGI.Ratio
			FROM [rpt].[WageGroupItem] WGI
			INNER JOIN WageGroups WG ON WG.ID = WGI.WageGroupID
			WHERE (WGI.[RemoveDate] IS NULL)
		)
		, PayrollEmployees AS (
			SELECT [ID], [PayrollID], [EmployeeID], [SumHokm] FROM wag.PayrollEmployee PE
			WHERE PayrollID=@PayrollID
		)
		, Employees AS (
			SELECT
			Employee.ID EmployeeID,
			EmploymentType,
			IndividualID,
			NationalCode
			FROM emp.Employee
			INNER JOIN emp.EmployeeCatalog EC on EC.iD = Employee.EmployeeCatalogID
		)
		, PayrollEmployeeDetails AS (
			SELECT
				PE.ID PayrollEmployeeID,
				PE.PayrollID,
				Payroll.PayrollType,
				Payroll.LawID,
				Payroll.LawName,
				Payroll.RequestID,
				TR.[Year],
				TR.[Month],
				BC.Code BudgetCode,
				FR.[Name] FinancingResourceName,
				BCFRD.ProjectionCode,
				BCFRD.MiscellaneousBudgetCode,
				PE.EmployeeID,
				Employees.EmploymentType,
				Employees.IndividualID,
				Employees.NationalCode,
				PE.SumHokm
			FROM PayrollEmployees PE
			INNER JOIN wag._Payroll Payroll ON Payroll.ID = PE.PayrollID
			INNER JOIN wag.TreasuryRequest TR ON TR.ID = Payroll.RequestID
			INNER JOIN pbo.BudgetCodeFinancingResource BCFR ON BCFR.ID = TR.BudgetCodeFinancingResourceID
			INNER JOIN pbo.BudgetCode BC ON BC.ID = BCFR.BudgetCodeID
			INNER JOIN pbo.FinancingResource FR ON FR.ID = BCFR.FinancingResourceID
			LEFT JOIN pbo.BudgetCodeFinancingResourceDetail BCFRD ON BCFRD.ID = TR.BudgetCodeFinancingResourceDetailID
			INNER JOIN pbl.BaseDocument BD ON BD.ID = TR.ID
			INNER JOIN Employees ON Employees.EmployeeID = PE.EmployeeID
			WHERE (BD.RemoveDate IS NULL)
		)
		
		, PayrollEmployeeIDs AS (
			SELECT PayrollEmployeeID FROM PayrollEmployeeDetails
		)
		, WageGroupDetails AS (
			SELECT
				PD.PayrollEmployeeID,
				WGI.WageGroupID,
				WGI.WageGroupType,
				SUM((PD.Amount * WGI.Ratio)) Amount
			FROM wag.PayrollDetail PD
			INNER JOIN PayrollEmployeeIDs PEs ON PEs.PayrollEmployeeID = PD.PayrollEmployeeID
			LEFT JOIN WageGroupItems WGI ON WGI.ItemID = PD.WageTitleID
			GROUP BY PD.PayrollEmployeeID, WGI.WageGroupID, WGI.WageGroupType
		)
		, MainSelect AS (
			SELECT
				PED.PayrollEmployeeID,
				PED.PayrollID,
				PED.PayrollType,
				PED.LawID,
				PED.LawName,
				PED.RequestID,
				PED.[Year],
				PED.[Month],
				PED.BudgetCode,
				PED.FinancingResourceName,
				PED.ProjectionCode,
				PED.MiscellaneousBudgetCode,
				PED.EmployeeID,
				PED.EmploymentType,
				PED.IndividualID,
				PED.NationalCode,
				COALESCE(PED.SumHokm,0) SumHokm,
				WGD.WageGroupID,
				WGD.WageGroupType,
				COALESCE(WGD.Amount, 0) Amount
			FROM PayrollEmployeeDetails PED
			INNER JOIN WageGroupDetails WGD ON WGD.PayrollEmployeeID = PED.PayrollEmployeeID
		)

		INSERT INTO [Kama.Aro.Pardakht.Extention].[rpt].[WageGroupReport]
		([ID], [PayrollEmployeeID], [PayrollID], [PayrollType],
		[LawID], [LawName], [RequestID], [Year], [Month], [BudgetCode],
		[FinancingResourceName], [ProjectionCode], [MiscellaneousBudgetCode],
		[EmployeeID], [EmploymentType], [IndividualID], [NationalCode], [SumHokm],
		[WageGroupID], [WageGroupType], [Amount])
		SELECT
		NEWID(),[PayrollEmployeeID], [PayrollID], [PayrollType],
		[LawID], [LawName], [RequestID], [Year], [Month], [BudgetCode],
		[FinancingResourceName], [ProjectionCode], [MiscellaneousBudgetCode],
		[EmployeeID], [EmploymentType], [IndividualID], [NationalCode], [SumHokm],
		[WageGroupID], [WageGroupType], [Amount]
		FROM MainSelect
	END
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spAddStatistics_') IS NOT NULL
    DROP PROCEDURE pbl.spAddStatistics_
GO

CREATE PROCEDURE pbl.spAddStatistics_  
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@Result INT = 0

	INSERT INTO pbl.[Statistics]
	(ID, Date, AllUsersCount, OrgansWithUserCount, OrgansWithLawCount, AllEmployeesCount, OrgansWithEmployeeCount,OrgansWithPayrollCount,PayrollsCount)
	SELECT 
		NEWID() ID,
		GETDATE() [Date],
		(select distinct count(*) from org.[position] where userid is not null AND DepartmentID <> pbl.EmptyGuid()) AllUsersCount,
		(select distinct count(*) from (select distinct DepartmentID from org.[position] where userid is not null AND DepartmentID <> pbl.EmptyGuid()) tbl) OrgansWithUserCount,
		(select distinct count(*) from (select distinct OrganID from law.organlaw WHERE OrganID <> pbl.EmptyGuid()) tbl) OrgansWithLawCount,
		(select distinct count(*) from (select distinct * from pbl.Employee WHERE OrganID <> pbl.EmptyGuid()) tbl) AllEmployeesCount,
		(select distinct count(*) from (select distinct OrganID from pbl.Employee where OrganID <> pbl.EmptyGuid()) tbl) OrgansWithEmployeeCount,
		(select distinct count(*) from (select distinct OrganID from wag.Payroll where OrganID <> pbl.EmptyGuid()) tbl) OrgansWithPayrollCount,
		(select distinct count(*) from wag.Payroll where OrganID <> pbl.EmptyGuid()) PayrollsCount

	SET @Result = @@ROWCOUNT

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetLastStatistics') IS NOT NULL
    DROP PROCEDURE pbl.spGetLastStatistics
GO

CREATE PROCEDURE pbl.spGetLastStatistics  
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@TestOrganID UNIQUEIDENTIFIER = '78C4B4C6-086A-46B9-8126-4AD7773B04DC',
		@Result INT = 0

	SELECT 
		GETDATE() [Date],
		(select distinct count(*) from org.[position] where userid is not null AND DepartmentID <> @TestOrganID) AllUsersCount,
		(select distinct count(*) from (select distinct DepartmentID from org.[position] where userid is not null AND DepartmentID <> @TestOrganID) tbl) OrgansWithUserCount,
		(select distinct count(*) from (select distinct OrganID from law.organlaw WHERE OrganID <> @TestOrganID) tbl) OrgansWithLawCount,
		(select distinct count(*) from (select distinct * from pbl.Employee WHERE OrganID <> @TestOrganID) tbl) AllEmployeesCount,
		(select distinct count(*) from (select distinct OrganID from pbl.Employee where OrganID <> @TestOrganID) tbl) OrgansWithEmployeeCount,
		(select distinct count(*) from (select distinct OrganID from wag.Payroll where OrganID <> @TestOrganID) tbl) OrgansWithPayrollCount,
		(select distinct count(*) from wag.Payroll where OrganID <> @TestOrganID) OrgansWithPayrollCount

	SET @Result = @@ROWCOUNT

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetStatistics') IS NOT NULL
    DROP PROCEDURE pbl.spGetStatistics
GO

CREATE PROCEDURE pbl.spGetStatistics  
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AFromDate DATE,
	@AToDate DATE,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@FromDate DATE = @AFromDate,
		@ToDate DATE = @AToDate,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT 
		count(*) over() Total
		, *
	FROM pbl.[Statistics]
	WHERE (@FromDate IS NULL OR [Date] >= @FromDate)
		AND (@ToDate IS NULL OR [Date] <= @ToDate)
	ORDER BY [DATE] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

	SET @Result = @@ROWCOUNT

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetDeletedWageGroups') AND type in (N'P', N'PC'))
DROP PROCEDURE rpt.spGetDeletedWageGroups
GO

CREATE PROCEDURE rpt.spGetDeletedWageGroups
	@AIDs NVARCHAR(MAX),
	@AType SMALLINT,
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@Type SMALLINT = COALESCE(@AType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = TRIM(@ASortExp)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH CountItems AS (
		SELECT [WageGroupID] , COUNT(ID) CountItems
		FROM [rpt].[WageGroupItem]
		WHERE [RemoveDate] IS NULL
		GROUP BY [WageGroupID]
	)
	, MainSelect AS(
		SELECT
			WG.[ID],
			WG.[Type],
			WG.[Comment],
			WG.[CreationDate],
			WG.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			WG.[CreatorPositionID],
			COALESCE(CountItems.CountItems, 0) CountItems,
			WG.[RemoveDate],
			WG.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			WG.[RemoverPositionID]
		FROM [rpt].[WageGroup] WG
		LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = WG.ID
		LEFT JOIN CountItems ON CountItems.[WageGroupID] = WG.[ID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = WG.CreatorUserID
		LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = WG.RemoverUserID
		WHERE ([RemoveDate] IS NOT NULL)
			AND (@IDs IS NULL OR IDs.value = WG.ID)
			AND (@Type < 1 OR WG.[Type] = @Type)
			AND (@FromRemoveDate IS NULL OR WG.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR WG.RemoveDate < @ToRemoveDate)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY [CreationDate]	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetWageGroup') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetWageGroup
GO

CREATE PROCEDURE rpt.spGetWageGroup 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	; WITH CountItems AS (
		SELECT [WageGroupID] , COUNT(ID) CountItems
		FROM [rpt].[WageGroupItem]
		WHERE [RemoveDate] IS NULL AND [WageGroupID] = @ID
		GROUP BY [WageGroupID]
	)
	SELECT
		WG.[ID],
		WG.[Type],
		WG.[Comment],
		WG.[CreationDate],
		WG.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		WG.[CreatorPositionID],
		COALESCE(CountItems.CountItems, 0) CountItems,
		WG.[RemoveDate],
		WG.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName RemoverName,
		WG.[RemoverPositionID]
	FROM [rpt].[WageGroup] WG
	LEFT JOIN CountItems ON CountItems.[WageGroupID] = WG.[ID]
	LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = WG.CreatorUserID
	LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = WG.RemoverUserID
	WHERE WG.ID = @ID
END 


GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetWageGroups') AND type in (N'P', N'PC'))
DROP PROCEDURE rpt.spGetWageGroups
GO

CREATE PROCEDURE rpt.spGetWageGroups
	@AIDs NVARCHAR(MAX),
	@AType SMALLINT,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@Type SMALLINT = COALESCE(@AType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = TRIM(@ASortExp)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH CountItems AS (
		SELECT [WageGroupID] , COUNT(ID) CountItems
		FROM [rpt].[WageGroupItem]
		WHERE [RemoveDate] IS NULL
		GROUP BY [WageGroupID]
	)
	, MainSelect AS(
		SELECT
			WG.[ID],
			WG.[Type],
			WG.[Comment],
			WG.[CreationDate],
			WG.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			WG.[CreatorPositionID],
			COALESCE(CountItems.CountItems, 0) CountItems
		FROM [rpt].[WageGroup] WG
		LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = WG.ID
		LEFT JOIN CountItems ON CountItems.[WageGroupID] = WG.[ID]
		LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = WG.CreatorUserID
		WHERE ([RemoveDate] IS NULL)
			AND (@IDs IS NULL OR IDs.value = WG.ID)
			AND (@Type < 1 OR WG.[Type] = @Type)
	), TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY [CreationDate]	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 

GO
USE [Kama.Aro.Pardakht]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spModifyWageGroup') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spModifyWageGroup
GO

CREATE PROCEDURE rpt.spModifyWageGroup  
	@AID UNIQUEIDENTIFIER,
	@AComment NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Comment NVARCHAR(MAX) = TRIM(@AComment)
	BEGIN TRY
		BEGIN TRAN
			UPDATE [rpt].[WageGroup]
			SET [Comment] = @Comment
			WHERE ID = @ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spCreateListWageGroupItems') AND type in (N'P', N'PC'))
DROP PROCEDURE rpt.spCreateListWageGroupItems
GO

CREATE PROCEDURE rpt.spCreateListWageGroupItems
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AWageGroups NVARCHAR(MAX),
	@ADetails NVARCHAR(MAX),
	@ASaveType TINYINT

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@WageGroups NVARCHAR(MAX) = LTRIM(RTRIM(@AWageGroups)),
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@SaveType TINYINT = COALESCE(@ASaveType, 0),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @SaveType = 1 -- Replace
			BEGIN
				UPDATE WGI
				SET RemoverUserID = @CurrentUserID,
				RemoverPositionID = @CurrentPositionID,
				RemoveDate = GETDATE()
				FROM rpt.WageGroupItem WGI
				LEFT JOIN OPENJSON(@WageGroups) WageGroups ON WageGroups.value = WGI.WageGroupID
				WHERE (WageGroups.value = WGI.WageGroupID)
			END
			; WITH CTE AS 
			(
				SELECT *FROM OPENJSON(@Details) 
				WITH
				(
					WageGroupID UNIQUEIDENTIFIER,
					ItemID UNIQUEIDENTIFIER
				)
			)
			INSERT INTO rpt.WageGroupItem
			([ID], [WageGroupID], [ItemID], [Ratio], [CreationDate], [CreatorUserID], [CreatorPositionID])
			SELECT 
				NEWID() ID,
				Details.WageGroupID [WageGroupID],
				Details.ItemID [ItemID],
				1 [Ratio],
				GETDATE() [CreationDate],
				@CurrentUserID [CreatorUserID],
				@CurrentPositionID [CreatorPositionID]
			FROM CTE Details
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spDeleteWageGroupItem') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spDeleteWageGroupItem
GO

CREATE PROCEDURE rpt.spDeleteWageGroupItem
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
	BEGIN TRY
		BEGIN TRAN
			UPDATE WageGroupItem
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			FROM [rpt].[WageGroupItem]
			WHERE ID = @ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetDeletedWageGroupItems') AND type in (N'P', N'PC'))
DROP PROCEDURE rpt.spGetDeletedWageGroupItems
GO

CREATE PROCEDURE rpt.spGetDeletedWageGroupItems
	@AIDs NVARCHAR(MAX),
	@AWageGroupID UNIQUEIDENTIFIER,
	@AWageGroupIDs NVARCHAR(MAX),
	@AWageGroupType SMALLINT,
	@AItemID UNIQUEIDENTIFIER,
	@AItemIDs NVARCHAR(MAX),
	@AFromRemoveDate DATETIME,
	@AToRemoveDate DATETIME,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@WageGroupID UNIQUEIDENTIFIER = @AWageGroupID,
		@WageGroupIDs NVARCHAR(MAX) = TRIM(@AWageGroupIDs),
		@WageGroupType SMALLINT = COALESCE(@AWageGroupType, 0),
		@ItemID UNIQUEIDENTIFIER = @AItemID,
		@ItemIDs NVARCHAR(MAX) = TRIM(@AItemIDs),
		@FromRemoveDate DATETIME = @AFromRemoveDate,
		@ToRemoveDate DATETIME = DATEADD(DAY, 1, @AToRemoveDate),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = TRIM(@ASortExp)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			WGI.[ID],
			WGI.[WageGroupID],
			WG.[Type] WageGroupType,
			WGI.[ItemID],
			WT.[Name] ItemName,
			WT.[Code] ItemCode,
			WGI.[Ratio],
			WGI.[CreationDate],
			WGI.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			WGI.[CreatorPositionID],
			WGI.[RemoveDate],
			WGI.[RemoverUserID],
			RU.FirstName + N' ' + RU.LastName RemoverName,
			WGI.[RemoverPositionID]
		FROM [rpt].[WageGroupItem] WGI
			LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = WGI.ID
			LEFT JOIN OPENJSON(@WageGroupIDs) WageGroupIDs ON WageGroupIDs.value = WGI.[WageGroupID]
			LEFT JOIN OPENJSON(@ItemIDs) ItemIDs ON ItemIDs.value = WGI.[ItemID]
			INNER JOIN [rpt].[WageGroup] WG ON WG.ID = WGI.[WageGroupID]
			INNER JOIN [wag].[WageTitle] WT ON WT.ID = WGI.ItemID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = WGI.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON RU.ID = WGI.RemoverUserID
		WHERE (WGI.[RemoveDate] IS NOT NULL)
			AND (@IDs IS NULL OR IDs.value = WGI.ID)
			AND (@WageGroupIDs IS NULL OR WageGroupIDs.value = WGI.[WageGroupID])
			AND (@ItemIDs IS NULL OR ItemIDs.value = WGI.[ItemID])
			AND (@WageGroupID IS NULL OR WGI.WageGroupID = @WageGroupID)
			AND (@WageGroupType < 1 OR WG.[Type] = @WageGroupType)
			AND (@ItemID IS NULL OR WGI.ItemID = @ItemID)
			AND (@FromRemoveDate IS NULL OR WGI.RemoveDate >= @FromRemoveDate) 
			AND (@ToRemoveDate IS NULL OR WGI.RemoveDate < @ToRemoveDate)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY [CreationDate]	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetWageGroupItems') AND type in (N'P', N'PC'))
DROP PROCEDURE rpt.spGetWageGroupItems
GO

CREATE PROCEDURE rpt.spGetWageGroupItems
	@AIDs NVARCHAR(MAX),
	@AWageGroupID UNIQUEIDENTIFIER,
	@AWageGroupIDs NVARCHAR(MAX),
	@AWageGroupType SMALLINT,
	@AItemID UNIQUEIDENTIFIER,
	@AItemIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@IDs NVARCHAR(MAX) = TRIM(@AIDs),
		@WageGroupID UNIQUEIDENTIFIER = @AWageGroupID,
		@WageGroupIDs NVARCHAR(MAX) = TRIM(@AWageGroupIDs),
		@WageGroupType SMALLINT = COALESCE(@AWageGroupType, 0),
		@ItemID UNIQUEIDENTIFIER = @AItemID,
		@ItemIDs NVARCHAR(MAX) = TRIM(@AItemIDs),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			WGI.[ID],
			WGI.[WageGroupID],
			WG.[Type] WageGroupType,
			WGI.[ItemID],
			WT.[Name] ItemName,
			WT.[Code] ItemCode,
			WGI.[Ratio],
			WGI.[CreationDate],
			WGI.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			WGI.[CreatorPositionID]
		FROM [rpt].[WageGroupItem] WGI
			LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = WGI.ID
			LEFT JOIN OPENJSON(@WageGroupIDs) WageGroupIDs ON WageGroupIDs.value = WGI.[WageGroupID]
			LEFT JOIN OPENJSON(@ItemIDs) ItemIDs ON ItemIDs.value = WGI.[ItemID]
			INNER JOIN [rpt].[WageGroup] WG ON WG.ID = WGI.[WageGroupID]
			INNER JOIN [wag].[WageTitle] WT ON WT.ID = WGI.ItemID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = WGI.CreatorUserID
		WHERE (WGI.[RemoveDate] IS NULL)
			AND (@IDs IS NULL OR IDs.value = WGI.ID)
			AND (@WageGroupIDs IS NULL OR WageGroupIDs.value = WGI.[WageGroupID])
			AND (@ItemIDs IS NULL OR ItemIDs.value = WGI.[ItemID])
			AND (@WageGroupID IS NULL OR WGI.WageGroupID = @WageGroupID)
			AND (@WageGroupType < 1 OR WG.[Type] = @WageGroupType)
			AND (@ItemID IS NULL OR WGI.ItemID = @ItemID)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, TempCount
	ORDER BY [CreationDate]	
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 

GO
USE [Kama.Aro.Pardakht]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spModifyWageGroupItem') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spModifyWageGroupItem
GO

CREATE PROCEDURE rpt.spModifyWageGroupItem
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AWageGroupID UNIQUEIDENTIFIER,
	@AItemID UNIQUEIDENTIFIER,
	@ARatio INT,
	@AModifireUserID UNIQUEIDENTIFIER,
	@AModifirePositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@WageGroupID UNIQUEIDENTIFIER = @AWageGroupID,
		@ItemID UNIQUEIDENTIFIER = @AItemID,
		@Ratio INT = COALESCE(@ARatio, 1),
		@ModifireUserID UNIQUEIDENTIFIER = @AModifireUserID,
		@ModifirePositionID UNIQUEIDENTIFIER = @AModifirePositionID
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [rpt].[WageGroupItem]
				([ID], [WageGroupID], [ItemID], [Ratio], [CreationDate], [CreatorUserID], [CreatorPositionID])
				VALUES
				(@ID, @WageGroupID, @ItemID, @Ratio, GETDATE(), @ModifireUserID, @ModifirePositionID)
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 

GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetTreasures
     @AOrganID       UNIQUEIDENTIFIER, 
	 @AYear TINYINT,
	 @AMonth TINYINT,
	 @APayrollType TINYINT,
     @AGetTotalCount BIT, 
     @ASortExp       NVARCHAR(MAX), 
     @APageSize      INT, 
     @APageIndex     INT
AS
    BEGIN
        SET NOCOUNT ON;
DECLARE @OrganID UNIQUEIDENTIFIER= @AOrganID,
        @Year TINYINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@PayrollType TINYINT = COALESCE(@APayrollType, 0),
		@GetTotalCount BIT= COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX)= LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT= COALESCE(@APageSize, 20),
		@PageIndex INT= COALESCE(@APageIndex, 0);
        IF @PageIndex = 0
            BEGIN
                SET @pagesize = 10000000;
                SET @PageIndex = 1;
            END;
        WITH MainSelect
             AS (SELECT t.[ID], 
                        [RequestID], 
                        [PayrollID], 
                        t.[BudgetCode], 
                        [PlaceFinancing], 
                        t.[NationalCode], 
                        [EmployeeNumber], 
                        [BirthYear], 
                        [WorkExperienceYears], 
                        [FirstName], 
                        [LastName], 
                        [Gender], 
                        [TreasuryGender], 
                        [ChildrenCount], 
                        [EmploymentType], 
                        [TreasuryEmploymentType], 
                        [EducationDegree], 
                        [TreasuryEducationDegree], 
                        [PensionFundType], 
                        [TreasuryPensionFundType], 
                        [InsuranceStatusType], 
                        [TreasuryInsuranceStatusType], 
                        [MarriageStatus], 
                        [TreasuryMarriageStatus], 
                        [Col15], 
                        [Col16], 
                        [Col17], 
                        [Col18], 
                        [Col19], 
                        [Col20], 
                        [Col21], 
                        [Col22], 
                        [Col23], 
                        [Col24], 
                        [Col25], 
                        [Col26], 
                        [Col27], 
                        [Col28], 
                        [Col29], 
                        [Col30], 
                        [Col31], 
                        [Col32], 
                        [Col33], 
                        [Col34], 
                        [Col35], 
                        [Col36], 
                        [Col37], 
                        [Col38], 
                        [Col39], 
                        [Col40], 
                        [Col41], 
                        [Col42], 
                        [Col43], 
                        [Col44], 
                        [Col45], 
                        [Col46], 
                        [Col47], 
                        [Col48], 
                        [Col49], 
                        [Col50], 
                        [Col51], 
                        [Col52], 
                        [Col53], 
                        [Col54], 
                        [Col55], 
                        [Col56], 
                        ba.Sheba,
						b.[Name] BankName,
						dep.[Name] OrganName
                 FROM [wag].[Treasury] t
                      INNER JOIN wag.payroll p ON p.ID = t.payrollID
                      INNER JOIN org._Department dep ON dep.id = p.organID
					  INNER JOIN pbl.BankAccount ba  ON ba.id = t.BankAccountID
					  INNER JOIN pbl.Bank b  ON b.id =ba.BankID
                 WHERE (@OrganID IS NULL OR @OrganID = p.OrganID)
				 	AND (@Year < 1 OR @Year = p.[Year])
					AND (@Month < 1 OR @Month = p.[Month])
					AND (@PayrollType < 1 OR @PayrollType = p.[PayrollType])
				 ),
             Total
             AS (SELECT COUNT(*) AS Total
                 FROM MainSelect
                 WHERE @GetTotalCount = 1)
             SELECT *
             FROM MainSelect, 
                  Total
             ORDER BY [PayrollID]
             OFFSET((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
    END;
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetTreasury
     @AID       UNIQUEIDENTIFIER
AS
    BEGIN
        SET NOCOUNT ON;
DECLARE @ID UNIQUEIDENTIFIER= @AID
    
	             SELECT t.[ID], 
                        [RequestID], 
                        [PayrollID], 
                        t.[BudgetCode], 
                        [PlaceFinancing], 
                        t.[NationalCode], 
                        [EmployeeNumber], 
                        [BirthYear], 
                        [WorkExperienceYears], 
                        [FirstName], 
                        [LastName], 
                        [Gender], 
                        [TreasuryGender], 
                        [ChildrenCount], 
                        [EmploymentType], 
                        [TreasuryEmploymentType], 
                        [EducationDegree], 
                        [TreasuryEducationDegree], 
                        [PensionFundType], 
                        [TreasuryPensionFundType], 
                        [InsuranceStatusType], 
                        [TreasuryInsuranceStatusType], 
                        [MarriageStatus], 
                        [TreasuryMarriageStatus], 
                        [Col15], 
                        [Col16], 
                        [Col17], 
                        [Col18], 
                        [Col19], 
                        [Col20], 
                        [Col21], 
                        [Col22], 
                        [Col23], 
                        [Col24], 
                        [Col25], 
                        [Col26], 
                        [Col27], 
                        [Col28], 
                        [Col29], 
                        [Col30], 
                        [Col31], 
                        [Col32], 
                        [Col33], 
                        [Col34], 
                        [Col35], 
                        [Col36], 
                        [Col37], 
                        [Col38], 
                        [Col39], 
                        [Col40], 
                        [Col41], 
                        [Col42], 
                        [Col43], 
                        [Col44], 
                        [Col45], 
                        [Col46], 
                        [Col47], 
                        [Col48], 
                        [Col49], 
                        [Col50], 
                        [Col51], 
                        [Col52], 
                        [Col53], 
                        [Col54], 
                        [Col55], 
                        [Col56], 
                        ba.Sheba,
						b.[Name] BankName,
						dep.[Name] OrganName
                 FROM [wag].[Treasury] t
                      INNER JOIN wag.payroll p ON p.ID = t.payrollID
                      INNER JOIN org._Department dep ON dep.id = p.organID
					  INNER JOIN pbl.BankAccount ba  ON ba.id = t.BankAccountID
					  INNER JOIN pbl.Bank b  ON b.id =ba.BankID
                 WHERE (@ID = t.ID)
    END;
GO
USE [Kama.Aro.Pardakht];
GO

CREATE OR ALTER PROCEDURE wag.spGetRequestMoneyForTreasury 
@ATreasuryRequestID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @TreasuryRequestID UNIQUEIDENTIFIER= @ATreasuryRequestID;
        SELECT SUM(trd.Col15) SumCol15, 
               SUM(trd.Col49) SumCol49, 
               SUM(trd.Col44) SumCol44, 
               SUM(trd.Col50) SumCol50, 
               SUM(trd.Col45) SumCol45, 
               SUM(trd.Col51) SumCol51, 
               SUM(trd.Col52) SumCol52,
			   SUM(trd.Col36) SumCol36,
               SUM(trd.Col46) SumCol46, 
               SUM(trd.Col47) SumCol47, 
               SUM(trd.Col55) SumCol55, 
               SUM(trd.Col56) SumCol56, 
               TreasuryEmploymentType
        FROM wag.TreasuryRequestDetail trd
        WHERE trd.RequestID = @TreasuryRequestID
        GROUP BY TreasuryEmploymentType;
    END;
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeleteTreasuryItem'))
	DROP PROCEDURE wag.spDeleteTreasuryItem
GO

CREATE PROCEDURE wag.spDeleteTreasuryItem
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE wag.TreasuryItem
			SET RemoverUserID = @RemoverUserID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryItem') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryItem
GO

CREATE PROCEDURE wag.spGetTreasuryItem 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		treasuryItem.ID,
		treasuryItem.Code,
		treasuryItem.[Name],
		treasuryItem.[Type],
		treasuryItem.[CalculationType]
	FROM [wag].[TreasuryItem]
	WHERE ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryItems') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryItems
GO

CREATE PROCEDURE wag.spGetTreasuryItems 
	@AName NVARCHAR(100),
	@AType TINYINT,
	@ACode INT,
	@ACalculationType TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
		@Code INT = @ACode,
		@Type TINYINT = COALESCE(@AType, 0),
		@CalculationType TINYINT = COALESCE(@ACalculationType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			treasuryItem.ID,
			treasuryItem.[Code],
			treasuryItem.[Name],
			treasuryItem.[Type],
			treasuryItem.[CalculationType]
		FROM [wag].[TreasuryItem] treasuryItem
		WHERE (@Name IS NULL OR treasuryItem.[Name] LIKE '%' + @Name + '%')
			AND (@Code IS NULL OR treasuryItem.[Code] = @Code )
			AND (@Type < 1 OR treasuryItem.[Type] = @Type)
			AND (@CalculationType < 1 OR treasuryItem.[CalculationType] = @CalculationType)
			AND (treasuryItem.[RemoverUserID] IS NULL)
			AND (treasuryItem.[RemoveDate] IS NULL)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Code]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyTreasuryItem') IS NOT NULL
    DROP PROCEDURE wag.spModifyTreasuryItem
GO

CREATE PROCEDURE wag.spModifyTreasuryItem
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ACode INT,
	@AName NVARCHAR(200),
	@AType TINYINT,
	@ACalculationType TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Code INT = COALESCE(@ACode, 0),
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@Type TINYINT = ISNULL(@AType, 1),
		@CalculationType TINYINT = ISNULL(@ACalculationType, 0)

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				
				INSERT INTO [wag].[TreasuryItem]
				([ID], [Code], [Name], [Type], [RemoverUserID], [RemoveDate], [CalculationType])
				VALUES
				(@ID, @Code, @Name, @Type, NULL, NULL, @CalculationType)
			END
			ELSE -- update
			BEGIN 

				UPDATE [wag].[TreasuryItem]
				SET [Code] = @Code,
					[Name] = @Name,
					[Type] = @Type,
					[CalculationType] = @CalculationType
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spCalculateTreasuryRequestSummaryDetails'))
	DROP PROCEDURE wag.spCalculateTreasuryRequestSummaryDetails
GO

CREATE PROCEDURE wag.spCalculateTreasuryRequestSummaryDetails
	
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@TRID UNIQUEIDENTIFIER,
		@LastMonth TINYINT,
		@LastMonthTRID UNIQUEIDENTIFIER,
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
		@BudgetCodeFinancingResourceDetailID UNIQUEIDENTIFIER,
		@LastMonthExpenses BIGINT

		SET @TRID = (
			SELECT TOP(1) request.ID FROM [wag].[TreasuryRequest] request
			INNER JOIN pbl.BaseDocument on BaseDocument.ID = request.ID
			INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
			WHERE (CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) >= 40) AND (BaseDocument.RemoverPositionID IS NULL) AND (request.ReportState <> 100) AND (request.[BudgetCodeFinancingResourceID] IS NOT NULL)
		)
		IF @TRID IS NOT NULL
		BEGIN
			SET @LastMonth = ((SELECT [Month] FROM wag.TreasuryRequest WHERE ID = @TRID) - 1)

			SET @BudgetCodeFinancingResourceID = (SELECT BudgetCodeFinancingResourceID FROM wag.TreasuryRequest WHERE ID = @TRID)
			SET @BudgetCodeFinancingResourceDetailID = (SELECT BudgetCodeFinancingResourceDetailID FROM wag.TreasuryRequest WHERE ID = @TRID)

			IF (@LastMonth NOT IN (0,12))
			BEGIN
				SET @LastMonthExpenses = (
					SELECT tr.Expenses
					FROM wag.TreasuryRequest tr
					INNER JOIN pbl.BaseDocument on BaseDocument.ID = tr.ID
					WHERE tr.[Month] = @LastMonth
					AND (BaseDocument.RemoverPositionID IS NULL)
					AND (tr.BudgetCodeFinancingResourceID = @BudgetCodeFinancingResourceID)
					AND (tr.BudgetCodeFinancingResourceDetailID = @BudgetCodeFinancingResourceDetailID)
				)
			END

			; WITH CTECalculatePEAmounts AS
			(
				SELECT 
					p.RequestID,
					COUNT(DISTINCT pe.EmployeeID) EmployeeCount,
					SUM(pe.[SumPayments]) Expenses,
					SUM(pe.[SumDeductions]) SumDeductions,
					SUM(pe.SumHokm) SumHokm,
					SUM(ped.SumNHokm) SumNHokm
				FROM wag.PayrollEmployee pe
				INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID = pe.ID
				INNER JOIN wag._Payroll p ON p.ID = pe.PayrollID
				WHERE p.[RequestID] = @TRID
				GROUP BY p.RequestID
			)
			UPDATE TR
			SET [ReportState] = 100,
			[ReportUpdateDate] = GETDATE(),
			[EmployeeCount] = cte.EmployeeCount,
			[Expenses] = CAST((cte.Expenses/1000000) AS INT),
			[SumHokm] = CAST((cte.SumHokm/1000000) AS INT),
			[SumNHokm] = CAST((cte.SumNHokm/1000000) AS INT),
			[HasPreviousRequest] = IIF(@LastMonthExpenses IS NULL, 0, 1),
			[SumDeductions] = CAST((cte.SumDeductions/1000000) AS INT),
			[ExpensesDifference] = IIF(@LastMonthExpenses IS NULL, 0, (CAST(((cte.Expenses - @LastMonthExpenses)/1000000) AS INT)))
			FROM [wag].[TreasuryRequest] TR
			INNER JOIN CTECalculatePEAmounts cte on cte.RequestID = TR.ID
			WHERE TR.ID = @TRID
		END
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeleteTreasuryRequest'))
	DROP PROCEDURE wag.spDeleteTreasuryRequest
GO

CREATE PROCEDURE wag.spDeleteTreasuryRequest
	@AID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID, 
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@GetDate DATETIME = GETDATE()
				
	BEGIN TRY
		BEGIN TRAN

			UPDATE
				pbl.BaseDocument
			SET
				RemoverPositionID = @RemoverPositionID,
				RemoverUserID = @RemoverUserID,
				RemoveDate = @GetDate
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetTreasuryRequest'))
	DROP PROCEDURE wag.spGetTreasuryRequest
GO

CREATE PROCEDURE wag.spGetTreasuryRequest
	@AID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@ActionState TINYINT = 0,
		@PositionType TINYINT = 0

	if @CurrentPositionID IS NOT NULL
	BEGIN
		IF EXISTS(SELECT 1 FROM pbl.DocumentFlow flow WHERE (flow.ToPositionID = @CurrentPositionID AND flow.DocumentID = @ID AND flow.ActionDate IS NULL))
			SET @ActionState = 1
			SET @PositionType = (SELECT [Type] FROM org.Position position WHERE position.ID = @CurrentPositionID)
		IF @PositionType = 101
			SET @ActionState = 1
	END
	

	;WITH Organ AS
	(
		SELECT DISTINCT Department.ID, Department.[Name], Department.ProvinceID, Department.[Type]
		FROM org.Department
			
	), FirstFlow AS
	(	
		SELECT 
			[Date],
			DocumentID, 
			FromPositionID,
			ToPositionID,
			department.ID ApplicantOrganID,
			department.[Name] ApplicantOrganName
		FROM pbl.DocumentFlow flow
			INNER JOIN org.Position position ON position.ID = flow.FromPositionID
			INNER JOIN org.Department department ON department.ID = position.DepartmentID
		WHERE flow.FromDocState = 1 
			AND flow.ToDocState = 1
			AND flow.DocumentID = @ID
	)
	SELECT 
		@ActionState ActionState,
		request.[ID],
			request.[OrganID],
			request.[PositionSubTypeID],
			request.[Type] AS TreasuryRequestType,
			request.[Month],
			request.[Year],
			request.[Comment],
			request.[SubOrganID],
			request.[ReportState],
			request.[ReportUpdateDate],
			Organ.[Name] OrganName,
			SubOrgan.[Name] SubOrganName,
			Organ.ProvinceID,
			Organ.[Type] DepartmentType,
			FirstFlow.ApplicantOrganID,
			FirstFlow.ApplicantOrganName,
			BaseDocument.[Type] DocumentType,
			BaseDocument.TrackingCode,
			BaseDocument.DocumentNumber,
			BaseDocument.ProcessID,
			FirstFlow.[Date] CreationDate,
			FirstFlow.ToPositionID FirstFlowToPositionID,
			lastFlow.ID LastFlowID,
			lastFlow.SendType LastSendType,
			CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) LastDocState,
			LastFlow.[Date] LastFlowDate,
			LastFlow.ReadDate LastReadDate,
			LastFlow.FromUserID LastFromUserID,
			LastFlow.ToPositionID LastToPositionID,
			LastPostion.[Type] LastToPositionType,
			process.[Name] ProcessName,
			process.Code ProcessCode,
			positionSubType.[Name] PositionSubTypeName,
			COALESCE(request.[EmployeeCount], 0) EmployeeCount,
			COALESCE(request.[Expenses], 0) Expenses,
			COALESCE(request.[ExpensesDifference], 0) ExpensesDifference,
			COALESCE(request.[SumHokm], 0) SumHokm,
			COALESCE(request.[SumNHokm], 0) SumNHokm,
			CAST(COALESCE(request.[HasPreviousRequest], 0) AS BIT) HasPreviousRequest,
			COALESCE(request.[SumDeductions], 0) SumDeductions,
			request.BudgetCodeFinancingResourceID,
			BCFR.BudgetCodeID,
			BC.[Code] BudgetCode,
			BC.[Type] BudgetCodeType,
			BCFR.FinancingResourceID,
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
			BCFR.Maximum BudgetCodeFinancingResourceMaximum,
			request.BudgetCodeFinancingResourceDetailID,
			BCFRD.ProjectionCode,
			BCFRD.MiscellaneousBudgetCode,
			BCFRD.Maximum BudgetCodeFinancingResourceDetailMaximum,
			CAST(request.[isProcessed] AS BIT) isProcessed
	FROM [wag].[TreasuryRequest] request
		INNER JOIN pbl.BaseDocument on BaseDocument.ID = request.ID
		INNER JOIN [pbl].[Process] process ON process.ID = BaseDocument.ProcessID
		INNER JOIN Organ ON Organ.ID = request.OrganID
		LEFT JOIN org.Department SubOrgan ON SubOrgan.ID = request.[SubOrganID]
		LEFT JOIN [pbo].[BudgetCodeFinancingResource] BCFR ON BCFR.ID = request.BudgetCodeFinancingResourceID
		LEFT JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.BudgetCodeID
		LEFT JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.FinancingResourceID
		LEFT JOIN [pbo].[BudgetCodeFinancingResourceDetail] BCFRD ON BCFRD.ID = request.BudgetCodeFinancingResourceDetailID
		LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = request.PositionSubTypeID
		INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
		LEFT JOIN pbl.DocumentFlow confirmFlow ON confirmFlow.DocumentID = BaseDocument.ID AND confirmFlow.ToDocState = 100 AND confirmFlow.ActionDate IS NULL
		INNER JOIN FirstFlow ON FirstFlow.DocumentID = BaseDocument.ID
		LEFT JOIN [Kama.Aro.Organization].org.Position LastPostion ON LastPostion.ID = LastFlow.ToPositionID
	WHERE (BaseDocument.RemoverPositionID IS NULL)
		AND (request.ID = @ID)
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetTreasuryRequests'))
	DROP PROCEDURE wag.spGetTreasuryRequests
GO

CREATE PROCEDURE wag.spGetTreasuryRequests
	@AOrganID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@ASubOrganID UNIQUEIDENTIFIER,
	@ATreasuryRequestType TINYINT,
	@AOrganIDs NVARCHAR(MAX),
	@AOrganCode VARCHAR(20),
	@AOrganName NVARCHAR(256),
	@AParentOrganID UNIQUEIDENTIFIER,
	@ATrackingCode NVARCHAR(100),
	@ALastDocState TINYINT,
	@ALastDocStates NVARCHAR(MAX),
	@AConfirmDateFrom DATE,
	@AConfirmDateTo DATE,
	@ACreationDateFrom DATE,
	@ACreationDateTo DATE,
	@ADepartmentType TINYINT,
	@AProvinceID UNIQUEIDENTIFIER,
	@AProcessID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@AMonth TINYINT,
	@AYear SMALLINT,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceIDs NVARCHAR(MAX),
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@ABudgetCode VARCHAR(20),
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceDetailID UNIQUEIDENTIFIER,
	@AProjectionCode VARCHAR(20),
	@AMiscellaneousBudgetCode VARCHAR(20),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@SubOrganID UNIQUEIDENTIFIER = @ASubOrganID,
		@TreasuryRequestType TINYINT = COALESCE(@ATreasuryRequestType, 0),
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@OrganCode VARCHAR(20) = LTRIM(RTRIM(@AOrganCode)),
		@OrganName NVARCHAR(256) = @AOrganName,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@TrackingCode NVARCHAR(100) = @ATrackingCode,
		@LastDocState TINYINT = COALESCE(@ALastDocState, 0),
		@LastDocStates NVARCHAR(MAX) = @ALastDocStates,
		@ConfirmDateFrom DATE = @AConfirmDateFrom,
		@ConfirmDateTo DATE = @AConfirmDateTo,
		@CreationDateFrom DATE = @ACreationDateFrom,
		@CreationDateTo DATE = @ACreationDateTo,
		@DepartmentType TINYINT = COALESCE(@ADepartmentType, 0),
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@ProcessID UNIQUEIDENTIFIER = @AProcessID,
		@Type TINYINT = COALESCE(@AType, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0),
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@BudgetCodeFinancingResourceIDs NVARCHAR(MAX) = TRIM(@ABudgetCodeFinancingResourceIDs),
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@BudgetCode VARCHAR(20) = TRIM(@ABudgetCode),
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@BudgetCodeFinancingResourceDetailID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceDetailID,
		@ProjectionCode VARCHAR(20) = LTRIM(RTRIM(@AProjectionCode)),
		@MiscellaneousBudgetCode VARCHAR(20) = LTRIM(RTRIM(@AMiscellaneousBudgetCode)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@ParentOrganNode HIERARCHYID

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)

	IF @OrganID = '00000000-0000-0000-0000-000000000000' 
		SET @OrganID = NULL

	;WITH Organ AS
	(
		SELECT DISTINCT Department.ID, Department.[Name], Department.ProvinceID, Department.[Type]
		FROM org.Department
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Department.ID
		WHERE (@OrganID IS NULL OR Department.ID = @OrganID)
			AND (@OrganCode IS NULL OR Department.Code = @OrganCode)
			AND (@OrganIDs IS NULL OR OrganIDs.value = Department.ID)
			AND (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
			AND (@OrganName IS NULL OR Department.[Name] LIKE N'%' + @OrganName + '%')
			AND (@ProvinceID IS NULL OR Department.ProvinceID = @ProvinceID AND Department.[Type] = 2)
			AND (@DepartmentType < 1 OR Department.[Type] = @DepartmentType)
			
	)
	, FirstFlow AS
	(	
		SELECT [Date], DocumentID, FromPositionID, ToPositionID, department.ID ApplicantOrganID, department.[Name] ApplicantOrganName
		FROM pbl.DocumentFlow flow
		INNER JOIN org.Position position ON position.ID = flow.FromPositionID
		INNER JOIN org.Department department ON department.ID = position.DepartmentID
		WHERE flow.FromDocState = 1
			AND flow.ToDocState = 1
	)
	, MainSelect AS 
	(
		SELECT DISTINCT
			request.[ID],
			request.[OrganID],
			request.[PositionSubTypeID],
			request.[Type] AS TreasuryRequestType,
			request.[Month],
			request.[Year],
			request.[Comment],
			request.[SubOrganID],
			request.[ReportState],
			request.[ReportUpdateDate],
			Organ.[Name] OrganName,
			SubOrgan.[Name] SubOrganName,
			Organ.ProvinceID,
			Organ.[Type] DepartmentType,
			FirstFlow.ApplicantOrganID,
			FirstFlow.ApplicantOrganName,
			FirstFlow.ToPositionID FirstFlowToPositionID,
			BaseDocument.[Type] DocumentType,
			BaseDocument.TrackingCode,
			BaseDocument.DocumentNumber,
			BaseDocument.ProcessID,
			FirstFlow.[Date] CreationDate,
			lastFlow.ID LastFlowID,
			lastFlow.SendType LastSendType,
			CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) LastDocState,
			LastFlow.[Date] LastFlowDate,
			LastFlow.ReadDate LastReadDate,
			LastFlow.FromUserID LastFromUserID,
			LastFlow.ToPositionID LastToPositionID,
			process.[Name] ProcessName,
			process.Code ProcessCode,
			positionSubType.[Name] PositionSubTypeName,
			COALESCE(request.[EmployeeCount], 0) EmployeeCount,
			COALESCE(request.[Expenses], 0) Expenses,
			COALESCE(request.[ExpensesDifference], 0) ExpensesDifference,
			COALESCE(request.[SumHokm], 0) SumHokm,
			COALESCE(request.[SumNHokm], 0) SumNHokm,
			CAST(COALESCE(request.[HasPreviousRequest], 0) AS BIT) HasPreviousRequest,
			COALESCE(request.[SumDeductions], 0) SumDeductions,
			request.BudgetCodeFinancingResourceID,
			BCFR.BudgetCodeID,
			BC.[Code] BudgetCode,
			BC.[Type] BudgetCodeType,
			BCFR.FinancingResourceID,
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
			BCFR.Maximum BudgetCodeFinancingResourceMaximum,
			request.BudgetCodeFinancingResourceDetailID,
			BCFRD.ProjectionCode,
			BCFRD.MiscellaneousBudgetCode,
			BCFRD.Maximum BudgetCodeFinancingResourceDetailMaximum,
			request.[isProcessed]
		FROM [wag].[TreasuryRequest] request
			INNER JOIN pbl.BaseDocument on BaseDocument.ID = request.ID
			INNER JOIN [pbl].[Process] process ON process.ID = BaseDocument.ProcessID
			INNER JOIN Organ ON Organ.ID = request.OrganID
			LEFT JOIN OPENJSON(@BudgetCodeFinancingResourceIDs) BudgetCodeFinancingResourceIDs ON BudgetCodeFinancingResourceIDs.value = request.BudgetCodeFinancingResourceID
			LEFT JOIN org.Department SubOrgan ON SubOrgan.ID = request.[SubOrganID]
			LEFT JOIN [pbo].[BudgetCodeFinancingResource] BCFR ON BCFR.ID = request.BudgetCodeFinancingResourceID
			LEFT JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.BudgetCodeID
			LEFT JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.FinancingResourceID
			LEFT JOIN [pbo].[BudgetCodeFinancingResourceDetail] BCFRD ON BCFRD.ID = request.BudgetCodeFinancingResourceDetailID
			LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = request.PositionSubTypeID
			INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
			LEFT JOIN pbl.DocumentFlow confirmFlow ON confirmFlow.DocumentID = BaseDocument.ID AND confirmFlow.ToDocState = 100 AND confirmFlow.ActionDate IS NULL
			INNER JOIN FirstFlow ON FirstFlow.DocumentID = BaseDocument.ID
		WHERE (BaseDocument.RemoverPositionID IS NULL)
			AND (request.BudgetCodeFinancingResourceID IS NOT NULL)
			AND (BaseDocument.Type = 3)
			AND (@BudgetCodeFinancingResourceIDs IS NULL OR BudgetCodeFinancingResourceIDs.value = request.BudgetCodeFinancingResourceID)
			AND (@SubOrganID IS NULL OR request.[SubOrganID] = @SubOrganID)
			AND (@TreasuryRequestType < 1 OR request.[Type] = @TreasuryRequestType)
			AND (@TrackingCode IS NULL OR BaseDocument.TrackingCode = @TrackingCode)
			AND (@LastDocState < 1 OR LastFlow.ToDocState = @LastDocState)
			AND (@ConfirmDateFrom IS NULL OR CAST(confirmFlow.[Date] AS DATE) >= @ConfirmDateFrom)
			AND (@ConfirmDateTo IS NULL OR CAST(confirmFlow.[Date] AS DATE) <= @ConfirmDateTo)
			AND (@CreationDateFrom IS NULL OR CAST(FirstFlow.[Date] AS DATE) >= @CreationDateFrom)
			AND (@CreationDateTo IS NULL OR CAST(FirstFlow.[Date] AS DATE) <= @CreationDateTo)
			AND (@LastDocStates IS NULL OR LastFlow.ToDocState IN (SELECT value FROM OPENJSON(@LastDocStates)))
			AND (@ProcessID IS NULL OR BaseDocument.ProcessID = @ProcessID)
			AND (@Type < 1 OR request.[Type] = @Type)
			AND (@PositionSubTypeID IS NULL OR request.PositionSubTypeID = @PositionSubTypeID)
			AND (@Month < 1 OR request.[Month] = @Month)
			AND (@Year < 1 OR request.[Year] = @Year)
			AND (@BudgetCodeFinancingResourceID IS NULL OR request.BudgetCodeFinancingResourceID = @BudgetCodeFinancingResourceID)
			AND (@BudgetCodeID IS NULL OR BC.ID = @BudgetCodeID)
			AND (@BudgetCode IS NULL OR BC.Code = @BudgetCode)
			AND (@FinancingResourceID IS NULL OR FR.ID = @FinancingResourceID)
			AND (@BudgetCodeFinancingResourceDetailID IS NULL OR request.BudgetCodeFinancingResourceDetailID = @BudgetCodeFinancingResourceDetailID)
			AND (@ProjectionCode IS NULL OR BCFRD.ProjectionCode LIKE '%' + @ProjectionCode + '%')
			AND (@MiscellaneousBudgetCode IS NULL OR BCFRD.MiscellaneousBudgetCode LIKE '%' + @MiscellaneousBudgetCode + '%')
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT 
		*
	FROM MainSelect, TempCount
	ORDER BY [Year] Desc, [Month] Desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetTreasuryRequestsForCartable'))
	DROP PROCEDURE wag.spGetTreasuryRequestsForCartable
GO

CREATE PROCEDURE wag.spGetTreasuryRequestsForCartable
	@AActionState TINYINT,
	@AOrganID UNIQUEIDENTIFIER,
	@AOrganIDs NVARCHAR(MAX),
	@ABossPositionIDs NVARCHAR(MAX),
	@AExpertPositionType TINYINT,
	@ADeputyPositionType TINYINT,
	@APermissionDocState TINYINT,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@ATrackingCode NVARCHAR(100),
	@AUserPositionID UNIQUEIDENTIFIER,
	@AUserOrganID UNIQUEIDENTIFIER,
	@ALastDocState TINYINT,
	@ASalaryBudgetCodeType TINYINT,
	@AMonth TINYINT,
	@AYear SMALLINT,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceIDs NVARCHAR(MAX),
	@ABudgetCodeID UNIQUEIDENTIFIER,
	@APBOSectionID UNIQUEIDENTIFIER,
	@ABudgetCodeType TINYINT,
	@AExpertCommentType TINYINT,
	@ADeputyCommentType TINYINT,
	@AFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceDetailID UNIQUEIDENTIFIER,
	@AProjectionCode VARCHAR(20),
	@AMiscellaneousBudgetCode VARCHAR(20),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ActionState TINYINT = COALESCE(@AActionState, 0),
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@OrganIDs NVARCHAR(MAX) = LTRIM(RTRIM(@AOrganIDs)),
		@BossPositionIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ABossPositionIDs)),
		@ExpertPositionType TINYINT = COALESCE(@AExpertPositionType, 0),
		@DeputyPositionType TINYINT = COALESCE(@ADeputyPositionType, 0),
		@PermissionDocState TINYINT = COALESCE(@APermissionDocState, 0),
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@TrackingCode NVARCHAR(100) = @ATrackingCode,
		@UserPositionID UNIQUEIDENTIFIER = @AUserPositionID,
		@UserOrganID UNIQUEIDENTIFIER = @AUserOrganID,
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0),
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@BudgetCodeFinancingResourceIDs NVARCHAR(MAX) = TRIM(@ABudgetCodeFinancingResourceIDs),
		@BudgetCodeID UNIQUEIDENTIFIER = @ABudgetCodeID,
		@PBOSectionID UNIQUEIDENTIFIER = @APBOSectionID,
		@BudgetCodeType TINYINT = COALESCE(@ABudgetCodeType, 0),
		@ExpertCommentType TINYINT = COALESCE(@AExpertCommentType, 0),
		@DeputyCommentType TINYINT = COALESCE(@ADeputyCommentType, 0),
		@FinancingResourceID UNIQUEIDENTIFIER = @AFinancingResourceID,
		@BudgetCodeFinancingResourceDetailID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceDetailID,
		@ProjectionCode VARCHAR(20) = LTRIM(RTRIM(@AProjectionCode)),
		@MiscellaneousBudgetCode VARCHAR(20) = LTRIM(RTRIM(@AMiscellaneousBudgetCode)),
		@LastDocState TINYINT = COALESCE(@ALastDocState, 0),
		@SalaryBudgetCodeType TINYINT = COALESCE(@ASalaryBudgetCodeType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@UserPositionType TINYINT

	SET @UserPositionType = COALESCE((SELECT [Type] FROM [Kama.Aro.Organization].org.Position WHERE ID = @UserPositionID), 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH Flow AS 
	(
		SELECT DISTINCT DF.DocumentID 
		FROM pbl.DocumentFlow DF
			INNER JOIN pbl.BaseDocument doc ON doc.ID = DF.DocumentID
			LEFT JOIN org.Position ToPosition ON ToPosition.ID = DF.ToPositionID
			--LEFT JOIN OPENJSON(@BossPositionIDs) BossPositionIDs ON BossPositionIDs.value = ToPosition.ID
		WHERE (DF.ToPositionID = @UserPositionID )
		OR (@UserPositionType IN (10, 20))
		OR (@UserPositionType IN (31, 32, 33, 35, 36, 37, 41, 45, 50, 51, 55, 60))
	)
	, ExpertLastComment AS 
	(
		SELECT TOP(1)
		Comment.ID CommentID,
		IIF(Comment.[Type] = 0, 3, Comment.[Type]) CommentType, 
		Request.ID RequestID
		FROM [wag].[TreasuryRequestComment] Comment
			INNER JOIN [wag].[TreasuryRequest] Request ON Comment.[RequestID] = Request.ID
			LEFT JOIN [pbl].[DocumentFlow] LastFlow ON LastFlow.DocumentID = Request.ID AND LastFlow.ActionDate IS NULL
			INNER JOIN [Kama.Aro.Organization].org.Position Position ON Position.ID = Comment.[CreatorPositionID]
		WHERE(LastFlow.ToDocState > @PermissionDocState OR Comment.[CreationDate] >= LastFlow.[Date])
		AND (@ExpertPositionType < 1 OR Position.Type = @ExpertPositionType)
		AND (Comment.RemoveDate IS NULL)
		ORDER BY Comment.CreationDate DESC
	)
	, DeputyLastComment AS 
	(
		SELECT TOP(1)
		Comment.ID CommentID,
		IIF(Comment.[Type] = 0, 3, Comment.[Type]) CommentType, 
		Request.ID RequestID
		FROM [wag].[TreasuryRequestComment] Comment
			INNER JOIN [wag].[TreasuryRequest] Request ON Comment.[RequestID] = Request.ID
			LEFT JOIN [pbl].[DocumentFlow] LastFlow ON LastFlow.DocumentID = Request.ID AND LastFlow.ActionDate IS NULL
			INNER JOIN [Kama.Aro.Organization].org.Position Position ON Position.ID = Comment.[CreatorPositionID]
		WHERE (LastFlow.ToDocState > @PermissionDocState OR Comment.[CreationDate] >= LastFlow.[Date])
		AND (@DeputyPositionType < 1 OR Position.Type = @DeputyPositionType)
		AND (Comment.RemoveDate IS NULL)
		ORDER BY Comment.CreationDate DESC
	)
	, FirstFlow AS
	(	
		SELECT [Date], DocumentID, FromPositionID, ToPositionID, department.ID ApplicantOrganID, department.[Name] ApplicantOrganName
		FROM pbl.DocumentFlow flow
		INNER JOIN org.Position position ON position.ID = flow.FromPositionID
		INNER JOIN org.Department department ON department.ID = position.DepartmentID
		WHERE flow.FromDocState = 1
			AND flow.ToDocState = 1
	)
	, MainSelect AS 
	(
		SELECT DISTINCT
			request.[ID],
			request.[OrganID],
			request.[PositionSubTypeID],
			request.[Type] AS TreasuryRequestType,
			request.[Month],
			request.[Year],
			request.[Comment],
			request.[SubOrganID],
			Organ.[Name] OrganName,
			SubOrgan.[Name] SubOrganName,
			Organ.ProvinceID,
			Organ.[Type] DepartmentType,
			FirstFlow.ApplicantOrganID,
			FirstFlow.ApplicantOrganName,
			FirstFlow.ToPositionID FirstFlowToPositionID,
			BaseDocument.[Type] DocumentType,
			BaseDocument.TrackingCode,
			BaseDocument.DocumentNumber,
			BaseDocument.ProcessID,
			IIF(COALESCE(ExpertLastComment.CommentType, -1) = 3, 0, COALESCE(ExpertLastComment.CommentType, -1)) ExpertCommentType,
			IIF(COALESCE(DeputyLastComment.CommentType, -1) = 3, 0, COALESCE(DeputyLastComment.CommentType, -1)) DeputyCommentType,
			FirstFlow.[Date] CreationDate,
			lastFlow.ID LastFlowID,
			lastFlow.SendType LastSendType,
			CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) LastDocState,
			LastFlow.[Date] LastFlowDate,
			LastFlow.ReadDate LastReadDate,
			LastFlow.FromUserID LastFromUserID,
			LastFlow.ToPositionID LastToPositionID,
			process.[Name] ProcessName,
			process.Code ProcessCode,
			positionSubType.[Name] PositionSubTypeName,
			COALESCE(request.[EmployeeCount], 0) EmployeeCount,
			COALESCE(request.[Expenses], 0) Expenses,
			COALESCE(request.[ExpensesDifference], 0) ExpensesDifference,
			CAST((IIF((COALESCE(request.[ExpensesDifference], 0) != 0), ((request.[Expenses] - request.[ExpensesDifference])*(100.0)/ request.[ExpensesDifference]), 0)) AS DECIMAL(7,2)) ExpensesDifferencePercentage,
			COALESCE(request.[SumHokm], 0) SumHokm,
			COALESCE(request.[SumNHokm], 0) SumNHokm,
			CAST(COALESCE(request.[HasPreviousRequest], 0) AS BIT) HasPreviousRequest,
			COALESCE(request.[SumDeductions], 0) SumDeductions,
			CAST(IIF(CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) = @PermissionDocState, 1, 0) AS BIT) IsSelectable,
			CAST(IIF(CAST(COALESCE(lastFlow.ToDocState, 0) AS TINYINT) = @PermissionDocState, 1, 0) AS BIT) IsCommentable,
			request.BudgetCodeFinancingResourceID,
			BCFR.BudgetCodeID,
			BC.[Code] BudgetCode,
			BC.[Type] BudgetCodeType,
			BCFR.FinancingResourceID,
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
			BCFR.Maximum BudgetCodeFinancingResourceMaximum,
			request.BudgetCodeFinancingResourceDetailID,
			BCFRD.ProjectionCode,
			BCFRD.MiscellaneousBudgetCode,
			BCFRD.Maximum BudgetCodeFinancingResourceDetailMaximum,
			request.[isProcessed]
		FROM [wag].[TreasuryRequest] request
			LEFT JOIN ExpertLastComment ON ExpertLastComment.RequestID = request.ID
			LEFT JOIN DeputyLastComment ON DeputyLastComment.RequestID = request.ID
			INNER JOIN pbl.BaseDocument BaseDocument on BaseDocument.ID = request.ID
			INNER JOIN [pbl].[Process] process ON process.ID = BaseDocument.ProcessID
			LEFT JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
			LEFT JOIN org.[Position] LastToPosition ON LastToPosition.ID = LastFlow.ToPositionID
			LEFT JOIN org.Department Organ ON Organ.ID = request.OrganID
			LEFT JOIN org.Department SubOrgan ON SubOrgan.ID = request.[SubOrganID]
			LEFT JOIN [pbo].[BudgetCodeFinancingResource] BCFR ON BCFR.ID = request.BudgetCodeFinancingResourceID
			LEFT JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.BudgetCodeID
			LEFT JOIN [pbo].[PBOSection] Section ON Section.ID = BC.[SectionID]
			LEFT JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.FinancingResourceID
			LEFT JOIN [pbo].[BudgetCodeFinancingResourceDetail] BCFRD ON BCFRD.ID = request.BudgetCodeFinancingResourceDetailID
			LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = request.PositionSubTypeID
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = request.[OrganID]
			LEFT JOIN OPENJSON(@BudgetCodeFinancingResourceIDs) BudgetCodeFinancingResourceIDs ON BudgetCodeFinancingResourceIDs.value = request.BudgetCodeFinancingResourceID
			INNER JOIN FirstFlow ON FirstFlow.DocumentID = BaseDocument.ID
			INNER JOIN Flow ON Flow.DocumentID = BaseDocument.ID
		WHERE (BaseDocument.RemoverPositionID IS NULL)
			AND (request.BudgetCodeFinancingResourceID IS NOT NULL)
			AND (BaseDocument.[Type] = 3)
			AND (@OrganID IS NULL OR request.OrganID = @OrganID)
			AND (@OrganIDs IS NULL OR OrganIDs.value = request.[OrganID])
			AND (@PositionSubTypeID IS NULL OR request.PositionSubTypeID = @PositionSubTypeID)
			AND (@TrackingCode IS NULL OR BaseDocument.TrackingCode = @TrackingCode)
			AND (@LastDocState < 1 OR LastFlow.ToDocState = @LastDocState)
			AND (@ActionState IN (1, 2, 3, 10))
			AND (@ActionState <> 1 OR LastFlow.ToPositionID = @UserPositionID)
			AND (@ActionState <> 2 OR (LastFlow.ToPositionID <> @UserPositionID AND LastFlow.SendType = 1 AND LastFlow.ToDocState <> 100))
			AND (@ActionState <> 3 OR LastFlow.ToDocState = 100)
			AND (@Month < 1 OR request.[Month] = @Month)
			AND (@Year < 1 OR request.[Year] = @Year)
			AND (@BudgetCodeType < 1 OR BC.[Type] = @BudgetCodeType)
			AND (@ExpertCommentType < 1 OR COALESCE(ExpertLastComment.CommentType, -1) = @ExpertCommentType)
			AND (@DeputyCommentType < 1 OR COALESCE(DeputyLastComment.CommentType, -1) = @DeputyCommentType)
			AND (@BudgetCodeFinancingResourceID IS NULL OR request.BudgetCodeFinancingResourceID = @BudgetCodeFinancingResourceID)
			AND (@BudgetCodeFinancingResourceIDs IS NULL OR BudgetCodeFinancingResourceIDs.value = request.BudgetCodeFinancingResourceID)
			AND (@BudgetCodeID IS NULL OR BC.ID = @BudgetCodeID)
			AND (@PBOSectionID IS NULL OR Section.ID = @PBOSectionID) 
			AND (@FinancingResourceID IS NULL OR FR.ID = @FinancingResourceID)
			AND (@BudgetCodeFinancingResourceDetailID IS NULL OR request.BudgetCodeFinancingResourceDetailID = @BudgetCodeFinancingResourceDetailID)
			AND (@ProjectionCode IS NULL OR BCFRD.ProjectionCode LIKE '%' + @ProjectionCode + '%')
			AND (@MiscellaneousBudgetCode IS NULL OR BCFRD.MiscellaneousBudgetCode LIKE '%' + @MiscellaneousBudgetCode + '%')
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, TempCount						
	ORDER BY [Year] Desc, [Month] Desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetTreasuryRequestStatus'))
	DROP PROCEDURE wag.spGetTreasuryRequestStatus
GO

CREATE PROCEDURE wag.spGetTreasuryRequestStatus
	@AID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ACurrentPositionType TINYINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CurrentPositionType TINYINT = @ACurrentPositionType,
		@LastFlowPositionID UNIQUEIDENTIFIER, --آخرین دریافت کننده پرونده
		@LastDocState TINYINT, --آخرین وضعیت پرونده
		@LastFlowSendType TINYINT, --آخرین نوع ارسال پرونده
		@HasAnyForFinancialExpertList BIT, --دارای یک گردش در سطح کارنشاس امور مالی
		@HasAnyEmployeeCatalogList BIT, --دارای لیست اطلاعات کارکنان متصل شده به درخواست وجه
		@HasAnyEmployeeCatalogReadyForUploadList BIT, --دارای لیست اطلاعات کارکنان در انتظار بارگذاری
		@HasAnyEmployeeCatalogProcessingList BIT, --دارای لیست اطلاعات کارکنان در انتظار/حال پردازش
		@HasAnyEmployeeCatalogProcessedHavsIssuesList BIT, --دارای لیست اطلاعات کارکنان پردازش شده دارای خطا
		@HasAnyEmployeeCatalogProcesseFailedList BIT, --دارای لیست اطلاعات کارکنان پردازش ناموفق
		@HasAnyPayrollList BIT, --دارای لیست حقوق
		@HasAnyPayrollReadyForProcessList BIT,--دارای لیست حقوق در انتظار پردازش
		@HasAnyPayrollProcessingList BIT, --دارای لیست حقوق در حال پردازش
		@HasAnyPayrollProcessedHasIssuesList BIT, --دارای لیست حقوق دارای خطا
		@TreasuryRequestErrorCount INT, --تعداد خطا های درخواست وجه
		@TreasuryRequestWarningCount INT --تعداد هشدار های درخواست وجه

		-- Flow
		SET @LastFlowPositionID  = (SELECT [ToPositionID] FROM [pbl].[DocumentFlow] LastFlow WHERE LastFlow.[DocumentID] = @AID AND LastFlow.ActionDate IS NULL)
		SET @LastDocState  = (SELECT CAST(COALESCE(LastFlow.ToDocState, 0) AS TINYINT) [LastDocState] FROM [pbl].[DocumentFlow] LastFlow WHERE LastFlow.[DocumentID] = @AID AND LastFlow.ActionDate IS NULL)
		SET @LastFlowSendType  = (SELECT TOP (1) [SendType] FROM [pbl].[DocumentFlow] LastFlow WHERE LastFlow.[DocumentID] = @AID ORDER BY [Date] DESC)
		SET @HasAnyForFinancialExpertList = CAST((SELECT TOP 1 1 FROM [pbl].[DocumentFlow] DocumentFlow INNER JOIN [org].[Position] Position ON Position.ID = DocumentFlow.FromPositionID WHERE DocumentFlow.[DocumentID] = @AID AND Position.[Type] = 10) AS BIT)

		-- EmployeeCatalog
		SET @HasAnyEmployeeCatalogList = COALESCE(CAST((SELECT TOP 1 1 FROM [emp].[EmployeeCatalog] WHERE [TreasuryRequestID] = @AID) AS BIT), 0)
		SET @HasAnyEmployeeCatalogReadyForUploadList = COALESCE(CAST((SELECT TOP 1 1 FROM [emp].[EmployeeCatalog] WHERE [TreasuryRequestID] = @AID AND [State] = 1) AS BIT), 0)
		SET @HasAnyEmployeeCatalogProcessingList = COALESCE(CAST((SELECT TOP 1 1 FROM [emp].[EmployeeCatalog] WHERE [TreasuryRequestID] = @AID AND ([State] = 5 OR [State] = 10)) AS BIT), 0)
		SET @HasAnyEmployeeCatalogProcessedHavsIssuesList = COALESCE(CAST((SELECT TOP 1 1 FROM [emp].[EmployeeCatalog] WHERE [TreasuryRequestID] = @AID AND ([State] = 30)) AS BIT), 0)
		SET @HasAnyEmployeeCatalogProcesseFailedList = COALESCE(CAST((SELECT TOP 1 1 FROM [emp].[EmployeeCatalog] WHERE [TreasuryRequestID] = @AID AND ([State] = 15)) AS BIT), 0)
		
		-- Payroll
		SET @HasAnyPayrollList = COALESCE(CAST((SELECT TOP 1 1 FROM [wag].[_Payroll] WHERE [RequestID] = @AID) AS BIT), 0)
		SET @HasAnyPayrollReadyForProcessList = COALESCE(CAST((SELECT TOP 1 1 FROM [wag].[_Payroll] WHERE [RequestID] = @AID AND [State] = 1) AS BIT), 0)
		SET @HasAnyPayrollProcessingList = COALESCE(CAST((SELECT TOP 1 1 FROM [wag].[_Payroll] WHERE [RequestID] = @AID AND [State] = 10) AS BIT), 0)
		SET @HasAnyPayrollProcessedHasIssuesList = COALESCE(CAST((SELECT TOP 1 1 FROM [wag].[_Payroll] WHERE [RequestID] = @AID AND [State] = 30) AS BIT), 0)
		
		-- TreasuryRequest
		SET @TreasuryRequestErrorCount = (SELECT COUNT(ID) FROM [wag].[TreasuryRequestError] WHERE [RequestID] = @AID AND [TreasuryRequestErrorType] = 10)
		SET @TreasuryRequestWarningCount = (SELECT COUNT(ID) FROM [wag].[TreasuryRequestError] WHERE [RequestID] = @AID AND [TreasuryRequestErrorType] = 1)

		SELECT
		@LastFlowPositionID [LastFlowPositionID]
		, @LastDocState [LastDocState]
		, @LastFlowSendType [LastFlowSendType]
		, @HasAnyForFinancialExpertList [HasAnyForFinancialExpertList]
		, @HasAnyEmployeeCatalogList [HasAnyEmployeeCatalogList]
		, @HasAnyEmployeeCatalogReadyForUploadList [HasAnyEmployeeCatalogReadyForUploadList]
		, @HasAnyEmployeeCatalogProcessingList [HasAnyEmployeeCatalogProcessingList]
		, @HasAnyEmployeeCatalogProcessedHavsIssuesList [HasAnyEmployeeCatalogProcessedHavsIssuesList]
		, @HasAnyEmployeeCatalogProcesseFailedList [HasAnyEmployeeCatalogProcesseFailedList]
		, @HasAnyPayrollList [HasAnyPayrollList]
		, @HasAnyPayrollReadyForProcessList [HasAnyPayrollReadyForProcessList]
		, @HasAnyPayrollProcessingList [HasAnyPayrollProcessingList]
		, @HasAnyPayrollProcessedHasIssuesList [HasAnyPayrollProcessedHasIssuesList]
		, @TreasuryRequestErrorCount [TreasuryRequestErrorCount]
		, @TreasuryRequestWarningCount [TreasuryRequestWarningCount]
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'wag.spModifyTreasuryRequest') AND type in (N'P', N'PC'))
DROP PROCEDURE wag.spModifyTreasuryRequest
GO

CREATE PROCEDURE wag.spModifyTreasuryRequest
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ASubOrganID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceID UNIQUEIDENTIFIER,
	@ABudgetCodeFinancingResourceDetailID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@ATreasuryRequestType TINYINT,
	@AMonth TINYINT,
	@AYear SMALLINT,
	@AComment NVARCHAR(4000),
	@AProcessID UNIQUEIDENTIFIER,
	@ADocumentType TINYINT,	
	@AReportState TINYINT,	
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@SubOrganID UNIQUEIDENTIFIER = @ASubOrganID,
		@BudgetCodeFinancingResourceID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceID,
		@BudgetCodeFinancingResourceDetailID UNIQUEIDENTIFIER = @ABudgetCodeFinancingResourceDetailID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@TreasuryRequestType TINYINT = COALESCE(@ATreasuryRequestType, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Comment NVARCHAR(4000) = LTRIM(RTRIM(@AComment)),
		@ProcessID UNIQUEIDENTIFIER = @AProcessID ,
		@DocumentType TINYINT = COALESCE(@ADocumentType, 0),
		@ReportState TINYINT = COALESCE(@AReportState, 0),
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@CreationDate DATETIME= GETDATE(),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert 
			BEGIN
				declare @TrackingCode NVARCHAR(10)
				set @TrackingCode = (select STR(FLOOR(RAND(CHECKSUM(NEWID()))*(9999999999-1000000000+1)+1000000000)))

				EXECUTE pbl.spModifyBaseDocument_ 
					@AIsNewRecord = @IsNewRecord, 
					@AID = @ID,
					@AType = @DocumentType,
					@ACreatorPositionID = @CurrentUserPositionID,
					@ATrackingCode = @TrackingCode,
					@ADocumentNumber = NULL, 
					@AProcessID = @ProcessID

				INSERT INTO [wag].[TreasuryRequest]
					([ID], [OrganID], [PositionSubTypeID], [Type], [Month], [Year], [Comment],[SubOrganID], [ReportState], [ReportUpdateDate], [BudgetCodeFinancingResourceID], [BudgetCodeFinancingResourceDetailID])
				VALUES
					(@ID, @OrganID, @PositionSubTypeID, @TreasuryRequestType, @Month, @Year, @Comment, @SubOrganID, 1, NULL, @BudgetCodeFinancingResourceID, @BudgetCodeFinancingResourceDetailID)
			END
			ELSE
			BEGIN
				UPDATE request
				SET
					[Comment] = @Comment,
					[ReportState] = @ReportState
				FROM [wag].[TreasuryRequest] request
			END

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spSetTreasuryRequestProcessedStatus'))
	DROP PROCEDURE wag.spSetTreasuryRequestProcessedStatus
GO

CREATE PROCEDURE wag.spSetTreasuryRequestProcessedStatus
	@AID UNIQUEIDENTIFIER,
	@AIsProcessed BIT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@IsProcessed BIT = COALESCE(@AIsProcessed, 0)

	UPDATE [wag].[TreasuryRequest]
	SET [isProcessed] = @IsProcessed
	WHERE ID = @ID
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spTreasuryRequestConfirm'))
	DROP PROCEDURE wag.spTreasuryRequestConfirm
GO

CREATE PROCEDURE wag.spTreasuryRequestConfirm
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID
				
	BEGIN TRY
		BEGIN TRAN

INSERT INTO [wag].[TreasuryRequestError]
(
    RequestID,
    PayrollID, 
    NationalCode,
	FirstName, 
	LastName,
	OrganID,
	Sheba,
	BankID
)
 SELECT  w.[RequestID],
         w.PayrollID, 
         w.NationalCode,
		 w.FirstName, 
		 w.LastName,
		 b.[OrganID],
		 b.[Sheba],
		 b.[BankID]
  FROM [wag].[TreasuryRequestDetail] AS w
  JOIN [pbl].[BankAccount] AS b
  ON b.[ID]= w.[BankAccountID]
  WHERE w.[RequestID] = @ID AND (b.[Sheba] is NULL OR Len(Sheba)<26);



  select top 1 *
  from [wag].[TreasuryRequestError]
  where RequestID = @ID;

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetNotAllocatedTreasuryRequests'))
	DROP PROCEDURE wag.spGetNotAllocatedTreasuryRequests
GO

CREATE PROCEDURE wag.spGetNotAllocatedTreasuryRequests
	@AMonth TINYINT,
	@AYear SMALLINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0)

	;WITH MainSelect AS 
	(
		SELECT 
			TR.ID RequestID,
			TR.[Month],
			TR.[Year],
			TR.[BudgetCodeFinancingResourceID],
			BCFR.BudgetCodeID,
			BC.[Code] BudgetCode,
			BC.[Type] BudgetCodeType,
			BCFR.FinancingResourceID,
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
			TR.BudgetCodeFinancingResourceDetailID,
			BCFRD.ProjectionCode,
			BCFRD.MiscellaneousBudgetCode
		FROM [wag].[TreasuryRequest] TR
			INNER JOIN pbl.BaseDocument BD on BD.ID = TR.ID
			INNER JOIN pbl.DocumentFlow DF on BD.ID = DF.DocumentID AND DF.ActionDate IS NULL
			INNER JOIN [pbo].[BudgetCodeFinancingResource] BCFR ON BCFR.ID = TR.BudgetCodeFinancingResourceID
			INNER JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.BudgetCodeID
			INNER JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.FinancingResourceID
			INNER JOIN [pbo].[BudgetCodeFinancingResourceDetail] BCFRD ON BCFRD.ID = TR.BudgetCodeFinancingResourceDetailID
			LEFT JOIN [wag].[TreasuryRequestAllocation] TRA ON TRA.RequestID = TR.ID
		WHERE (BD.RemoverPositionID IS NULL) AND (BD.[Type] = 3)
			AND (DF.ToDocState = 100)
			AND (TRA.ID IS NULL)
			AND (@Month < 1 OR TR.[Month] = @Month)
			AND (@Year < 1 OR TR.[Year] = @Year)
	)
	SELECT * FROM MainSelect
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetTreasuryRequestAllocation'))
	DROP PROCEDURE wag.spGetTreasuryRequestAllocation
GO

CREATE PROCEDURE wag.spGetTreasuryRequestAllocation
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		TRA.[ID],
		TRA.[RequestID],
		TRA.[PBOAllocationID],
		TRA.[SecretariatNo],
		TRA.[SecretariatNoNotice],
		TR.[OrganID],
		Organ.[Name] OrganName,
		TR.[Month],
		TR.[Year],
		TR.[BudgetCodeFinancingResourceID],
		BCFR.BudgetCodeID,
		BC.[Code] BudgetCode,
		BCFR.FinancingResourceID,
		FR.[Name] FinancingResourceName,
		FR.AROCode FinancingResourceAROCode,
		FR.PBOCode FinancingResourcePBOCode,
		FR.TreasuryCode FinancingResourceTreasuryCode,
		TR.BudgetCodeFinancingResourceDetailID,
		BCFRD.ProjectionCode,
		BCFRD.MiscellaneousBudgetCode
	FROM [wag].[TreasuryRequestAllocation] TRA
		INNER JOIN [wag].[TreasuryRequest] TR ON TRA.RequestID = TR.ID
		INNER JOIN pbl.BaseDocument on BaseDocument.ID = TR.ID
		INNER JOIN [Kama.Aro.Organization].[org].[Department] Organ ON Organ.ID = TR.[OrganID]
		LEFT JOIN [pbo].[BudgetCodeFinancingResource] BCFR ON BCFR.ID = TR.BudgetCodeFinancingResourceID
		LEFT JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.BudgetCodeID
		LEFT JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.FinancingResourceID
		LEFT JOIN [pbo].[BudgetCodeFinancingResourceDetail] BCFRD ON BCFRD.ID = TR.BudgetCodeFinancingResourceDetailID
	WHERE TRA.ID = @ID
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetTreasuryRequestAllocations'))
	DROP PROCEDURE wag.spGetTreasuryRequestAllocations
GO

CREATE PROCEDURE wag.spGetTreasuryRequestAllocations
	@AMonth TINYINT,
	@AYear SMALLINT,
	@ATrackingCode NVARCHAR(100),
	@ABudgetCode VARCHAR(20),
	@AProjectionCode VARCHAR(20),
	@AMiscellaneousBudgetCode VARCHAR(20),
	@APBOAllocationID NVARCHAR(150),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0),
		@TrackingCode NVARCHAR(100) = TRIM(@ATrackingCode),
		@BudgetCode VARCHAR(20) = TRIM(@ABudgetCode),
		@ProjectionCode VARCHAR(20) = TRIM(@AProjectionCode),
		@MiscellaneousBudgetCode VARCHAR(20) = TRIM(@AMiscellaneousBudgetCode),
		@PBOAllocationID NVARCHAR(150) = TRIM(@APBOAllocationID),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = TRIM(@ASortExp),
		@ParentOrganNode HIERARCHYID

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT 
			TRA.[ID],
			TRA.[RequestID],
			TRA.[PBOAllocationID],
			TRA.[SecretariatNo],
			TRA.[SecretariatNoNotice],
			TR.[OrganID],
			Organ.[Name] OrganName,
			TR.[Month],
			TR.[Year],
			TR.[BudgetCodeFinancingResourceID],
			BCFR.BudgetCodeID,
			BC.[Code] BudgetCode,
			BCFR.FinancingResourceID,
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
			TR.BudgetCodeFinancingResourceDetailID,
			BCFRD.ProjectionCode,
			BCFRD.MiscellaneousBudgetCode
		FROM [wag].[TreasuryRequestAllocation] TRA
			INNER JOIN [wag].[TreasuryRequest] TR ON TRA.RequestID = TR.ID
			INNER JOIN pbl.BaseDocument on BaseDocument.ID = TR.ID
			INNER JOIN [Kama.Aro.Organization].[org].[Department] Organ ON Organ.ID = TR.[OrganID]
			LEFT JOIN [pbo].[BudgetCodeFinancingResource] BCFR ON BCFR.ID = TR.BudgetCodeFinancingResourceID
			LEFT JOIN [pbo].[BudgetCode] BC ON BC.ID = BCFR.BudgetCodeID
			LEFT JOIN [pbo].[FinancingResource] FR ON FR.ID = BCFR.FinancingResourceID
			LEFT JOIN [pbo].[BudgetCodeFinancingResourceDetail] BCFRD ON BCFRD.ID = TR.BudgetCodeFinancingResourceDetailID
		WHERE (BaseDocument.RemoverPositionID IS NULL) AND (BaseDocument.[Type] = 3)
			AND (@PBOAllocationID IS NULL OR TRA.[PBOAllocationID] = @PBOAllocationID)
			AND (@TrackingCode IS NULL OR BaseDocument.TrackingCode = @TrackingCode)
			AND (@BudgetCode IS NULL OR BC.[Code] = @BudgetCode)
			AND (@ProjectionCode IS NULL OR BCFRD.[ProjectionCode] = @ProjectionCode)
			AND (@MiscellaneousBudgetCode IS NULL OR BCFRD.[MiscellaneousBudgetCode] = @MiscellaneousBudgetCode)
			AND (@Month < 1 OR TR.[Month] = @Month)
			AND (@Year < 1 OR TR.[Year] = @Year)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT 
		*
	FROM MainSelect, TempCount
	ORDER BY [Year] Desc, [Month] Desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbo.spInsertTreasuryRequestAllocations') IS NOT NULL
    DROP PROCEDURE pbo.spInsertTreasuryRequestAllocations
GO

CREATE PROCEDURE pbo.spInsertTreasuryRequestAllocations
	@ADetails NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@Details NVARCHAR(MAX) = TRIM(@ADetails)

	BEGIN TRY
		BEGIN TRAN
		;WITH CTE AS 
        (
            SELECT
                [RequestID],
				[PBOAllocationID],
				[SecretariatNo],
				[SecretariatNoNotice]
            FROM OPENJSON(@Details) 
            WITH
            (
                [RequestID] UNIQUEIDENTIFIER,
                [PBOAllocationID] NVARCHAR(150),
                [SecretariatNo] NVARCHAR(150),
                [SecretariatNoNotice] NVARCHAR(150)
            )
        )
		INSERT INTO [wag].[TreasuryRequestAllocation]
		([ID], [RequestID], [PBOAllocationID], [SecretariatNo], [SecretariatNoNotice])
		SELECT
		NEWID(),
		[RequestID],
		[PBOAllocationID],
		[SecretariatNo],
		[SecretariatNoNotice]
		FROM CTE

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeleteTreasuryRequestComment'))
	DROP PROCEDURE wag.spDeleteTreasuryRequestComment
GO

CREATE PROCEDURE wag.spDeleteTreasuryRequestComment
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [wag].[TreasuryRequestComment]
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @ARemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryRequestComment') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryRequestComment
GO

CREATE PROCEDURE wag.spGetTreasuryRequestComment 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		trc.[ID],
		trc.[RequestID],
		trc.[Type],
		trc.[Priority],
		trc.[ExtendedContent],
		trc.[Content],
		trc.[CreatorUserID],
		trc.[CreatorPositionID],
		CreatorPosition.[Type] CreatorPositionType,
		CreatorUser.[FirstName] + ' ' + CreatorUser.[LastName] CreatorName,
		trc.[CreationDate],
		trc.[LastModifyDate],
		trc.[RemoverUserID],
		trc.[RemoverPositionID],
		trc.[RemoveDate]
	FROM [wag].[TreasuryRequestComment] trc
	INNER JOIN [Kama.Aro.Organization].[org].[User] CreatorUser ON CreatorUser.ID = trc.CreatorUserID
	INNER JOIN [Kama.Aro.Organization].[org].[Position] CreatorPosition ON CreatorPosition.ID = trc.CreatorPositionID
	WHERE trc.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryRequestComments') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryRequestComments
GO

CREATE PROCEDURE wag.spGetTreasuryRequestComments 
	@ARequestID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@APermissionPositionTypes VARCHAR(MAX),
	@APriority TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@Type TINYINT = COALESCE(@AType, 0),
		@PermissionPositionTypes NVARCHAR(MAX) = LTRIM(RTRIM(@APermissionPositionTypes)),
		@Priority TINYINT = COALESCE(@APriority, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			trc.[ID],
			trc.[RequestID],
			trc.[Type],
			trc.[Priority],
			trc.[ExtendedContent],
			trc.[Content],
			trc.[CreatorUserID],
			trc.[CreatorPositionID],
			CreatorPosition.[Type] CreatorPositionType,
			CreatorUser.[FirstName] + ' ' + CreatorUser.[LastName] CreatorName,
			trc.[CreationDate],
			trc.[LastModifyDate],
			trc.[RemoverUserID],
			trc.[RemoverPositionID],
			trc.[RemoveDate],
			CAST(IIF(LastFlow.[Date] > trc.[CreationDate], 1, 0) AS BIT) isDeprecated
		FROM [wag].[TreasuryRequestComment] trc
		INNER JOIN [wag].[TreasuryRequest] tr ON tr.[ID] = trc.[RequestID]
		INNER JOIN pbl.BaseDocument BaseDocument on BaseDocument.ID = tr.[ID]
		INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = BaseDocument.ID AND LastFlow.ActionDate IS NULL
		INNER JOIN [Kama.Aro.Organization].[org].[User] CreatorUser ON CreatorUser.ID = trc.CreatorUserID
		INNER JOIN [Kama.Aro.Organization].[org].[Position] CreatorPosition ON CreatorPosition.ID = trc.CreatorPositionID
		LEFT JOIN OPENJSON(@PermissionPositionTypes) PermissionPositionTypes ON PermissionPositionTypes.value = CreatorPosition.Type
		WHERE (trc.[RemoveDate] IS NULL)
			AND (@RequestID IS NULL OR trc.[RequestID] = @RequestID)
			AND (@Type < 1 OR trc.[Type] = @Type)
			AND (@Priority < 1 OR trc.[Priority] = @Priority)
			AND (@PermissionPositionTypes IS NULL OR PermissionPositionTypes.value = CreatorPosition.Type)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyTreasuryRequestComment') IS NOT NULL
    DROP PROCEDURE wag.spModifyTreasuryRequestComment
GO

CREATE PROCEDURE wag.spModifyTreasuryRequestComment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@APriority TINYINT,
	@AExtendedContent nvarchar(MAX),
	@AContent NVARCHAR(MAX),
	@AUserID UNIQUEIDENTIFIER,
	@APositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@Type TINYINT = COALESCE(@AType, 0),
		@Priority TINYINT = COALESCE(@APriority, 0),
		@ExtendedContent NVARCHAR(MAX) = LTRIM(RTRIM(@AExtendedContent)),
		@Content NVARCHAR(MAX) = LTRIM(RTRIM(@AContent)),
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PositionID UNIQUEIDENTIFIER = @APositionID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				
				INSERT INTO [wag].[TreasuryRequestComment]
				([ID], [RequestID], [Type], [Priority], [ExtendedContent],
				[Content], [CreatorUserID], [CreatorPositionID], [CreationDate],
				[LastModifyDate], [RemoverUserID], [RemoverPositionID], [RemoveDate])
				VALUES
				(@ID, @RequestID, @Type, @Priority, @ExtendedContent,
				 @Content, @UserID, @PositionID, GETDATE(),
				 NULL, NULL, NULL, NULL)
			END
			ELSE -- update
			BEGIN 

				UPDATE [wag].[TreasuryRequestComment]
				SET 
					[Type] = @Type,
					[Priority] = @Priority,
					[ExtendedContent] = @ExtendedContent,
					[Content] = @Content,
					[LastModifyDate] = GETDATE()
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryRequestBankAccountControl') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryRequestBankAccountControl
GO

CREATE PROCEDURE wag.spGetTreasuryRequestBankAccountControl 
	@ARequestID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID

	;WITH TRDs AS (
		SELECT
			RequestID,
			NationalCode,
			COUNT(DISTINCT BankAccountID) CountBankAccounts
		FROM wag.TreasuryRequestDetail
		WHERE RequestID = @RequestID
		GROUP BY RequestID, NationalCode
		HAVING COUNT(DISTINCT BankAccountID) > 1
	)
	SELECT * FROM TRDs
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryRequestOrderControl') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryRequestOrderControl
GO

CREATE PROCEDURE wag.spGetTreasuryRequestOrderControl 
	@ARequestID UNIQUEIDENTIFIER,
	@ANationalCodes NVARCHAR(MAX)

WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@NationalCodes NVARCHAR(MAX) = TRIM(@ANationalCodes),
		@Month TINYINT = 0,
		@Year SMALLINT = 0 

	SELECT @Month = [Month], @Year = [Year]
	FROM [wag].[TreasuryRequest]
	WHERE ID = @RequestID

	; WITH SameMonthTRs AS (
		SELECT tr.ID
		FROM wag.TreasuryRequest tr
		INNER JOIN pbl.BaseDocument bd ON bd.ID = tr.ID
		WHERE tr.[Month] = @Month AND tr.[Year] = @Year AND tr.ID <> @RequestID AND bd.RemoveDate IS NULL AND tr.BudgetCodeFinancingResourceID IS NOT NULL
	)
	, TRDIDs AS (
		SELECT
			TRD.RequestID,
			TRD.NationalCode,
			TRD.Col15,
			TRD.Col16,
			TRD.Col42
		FROM wag.TreasuryRequestDetail TRD
		INNER JOIN wag._Payroll pay on pay.ID = TRD.PayrollID
		LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = TRD.NationalCode
		WHERE (@NationalCodes IS NULL OR NationalCodes.value = TRD.NationalCode)
			AND TRD.RequestID <> @RequestID
			AND pay.PayrollType = 1
			AND (TRD.Col15 > 0 OR TRD.Col16 > 0 OR TRD.Col42 > 0)
	)
	, ThisTRDIDs AS (
		SELECT
			TRD.RequestID,
			TRD.NationalCode,
			TRD.Col15,
			TRD.Col16,
			TRD.Col42
		FROM wag.TreasuryRequestDetail TRD
		INNER JOIN wag._Payroll pay on pay.ID = TRD.PayrollID
		LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = TRD.NationalCode
		WHERE (@NationalCodes IS NULL OR NationalCodes.value = TRD.NationalCode)
			AND TRD.RequestID = @RequestID
			AND pay.PayrollType = 1
			AND (TRD.Col15 > 0 OR TRD.Col16 > 0 OR TRD.Col42 > 0)
	)
	, SameMonthTRDs AS (
		SELECT
			TRDIDs.RequestID,
			TRDIDs.NationalCode,
			SUM(TRDIDs.Col15) Col15,
			SUM(TRDIDs.Col16) Col16,
			SUM(TRDIDs.Col42) Col42
		FROM TRDIDs
		INNER JOIN SameMonthTRs ON SameMonthTRs.ID = TRDIDs.RequestID
		INNER JOIN ThisTRDIDs ON ThisTRDIDs.NationalCode = TRDIDs.NationalCode
		GROUP BY TRDIDs.RequestID, TRDIDs.NationalCode
	)
	SELECT * FROM SameMonthTRDs
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryRequestPayrollControl') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryRequestPayrollControl
GO

CREATE PROCEDURE wag.spGetTreasuryRequestPayrollControl 
	@ARequestID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@PayrollCount INT,
		@ProcessedPayrollCount INT

	SET @PayrollCount = (SELECT COUNT(DISTINCT ID) FROM wag._Payroll WHERE RequestID = @RequestID)
	SET @ProcessedPayrollCount = (SELECT COUNT(DISTINCT PayrollID) FROM wag.TreasuryRequestDetail WHERE RequestID = @RequestID)
	IF @PayrollCount = @ProcessedPayrollCount
	BEGIN
		SELECT CAST(1 AS BIT) AllPayrollsProcessed
	END
	ELSE
	BEGIN
		SELECT CAST(0 AS BIT) AllPayrollsProcessed
	END
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryRequestTotalSumControl') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryRequestTotalSumControl
GO

CREATE PROCEDURE wag.spGetTreasuryRequestTotalSumControl 
	@ARequestID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID
	SELECT 
        NationalCode,
		SUM (
			COALESCE(Col15, 0) + COALESCE(Col16, 0) + COALESCE(Col17, 0)
			+ COALESCE(Col18, 0) + COALESCE(Col19, 0) + COALESCE(Col20, 0)
			+ COALESCE(Col21, 0) + COALESCE(Col22, 0) + COALESCE(Col23, 0)
			+ COALESCE(Col24, 0) + COALESCE(Col25, 0) + COALESCE(Col26, 0)
			+ COALESCE(Col27, 0) + COALESCE(Col28, 0) + COALESCE(Col29, 0)
			+ COALESCE(Col30, 0) + COALESCE(Col31, 0) + COALESCE(Col32, 0)
			+ COALESCE(Col33, 0) + COALESCE(Col34, 0) + COALESCE(Col35, 0) + COALESCE(Col36, 0)
			+ COALESCE(Col37, 0) + COALESCE(Col38, 0) + COALESCE(Col39, 0)
			+ COALESCE(Col40, 0) + COALESCE(Col41, 0) + COALESCE(Col42, 0)
			+ COALESCE(Col43, 0) + COALESCE(Col44, 0) + COALESCE(Col45, 0) 
			+ COALESCE(Col46, 0) + COALESCE(Col47, 0) + COALESCE(Col48, 0)
		) AS SumPayments,
		SUM (
			COALESCE(Col36, 0) + COALESCE(Col44, 0) + COALESCE(Col45, 0) 
			+ COALESCE(Col46, 0) + COALESCE(Col47, 0) + COALESCE(Col49, 0) 
			+ COALESCE(Col50, 0) + COALESCE(Col51, 0) + COALESCE(Col52, 0) 
			+ COALESCE(Col53, 0) + COALESCE(Col54, 0) + COALESCE(Col55, 0)
		) AS SumDeductions,
		SUM(
			COALESCE(Col15, 0) + COALESCE(Col16, 0) + COALESCE(Col17, 0)
			+ COALESCE(Col18, 0) + COALESCE(Col19, 0) + COALESCE(Col20, 0)
			+ COALESCE(Col21, 0) + COALESCE(Col22, 0) + COALESCE(Col23, 0)
			+ COALESCE(Col24, 0) + COALESCE(Col25, 0) + COALESCE(Col26, 0)
			+ COALESCE(Col27, 0) + COALESCE(Col28, 0) + COALESCE(Col29, 0)
			+ COALESCE(Col30, 0) + COALESCE(Col31, 0) + COALESCE(Col32, 0)
			+ COALESCE(Col33, 0) + COALESCE(Col34, 0) + COALESCE(Col35, 0)
			+ COALESCE(Col37, 0) + COALESCE(Col38, 0) + COALESCE(Col39, 0)
			+ COALESCE(Col40, 0) + COALESCE(Col41, 0) + COALESCE(Col42, 0)
			+ COALESCE(Col43, 0) + COALESCE(Col48, 0) - COALESCE(Col49, 0) 
			- COALESCE(Col50, 0) - COALESCE(Col51, 0) - COALESCE(Col52, 0) 
			- COALESCE(Col53, 0) - COALESCE(Col54, 0) - COALESCE(Col55, 0)
		) AS [Sum]
	FROM wag.TreasuryRequestDetail
	WHERE RequestID = @RequestID
	GROUP BY NationalCode;
END
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetDelayedSummaryForRequestMoneyForTreasury
 @ARequestID UNIQUEIDENTIFIER,
 @APayrollID UNIQUEIDENTIFIER,
 @ATreasuryEmploymentType TINYINT,
 @ABudgetCode VARCHAR(20),
 @APlaceFinancing TINYINT,
 @ANationalCode NVARCHAR(10),
 @ANationalCodes NVARCHAR(MAX)
WITH ENCRYPTION
AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @RequestID UNIQUEIDENTIFIER= @ARequestID,
		        @PayrollID UNIQUEIDENTIFIER= @APayrollID,
				@TreasuryEmploymentType TINYINT = @ATreasuryEmploymentType,
				@BudgetCode VARCHAR(20) = @ABudgetCode ,
				@PlaceFinancing TINYINT =Coalesce(@APlaceFinancing,0),
				@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
				@NationalCodes NVARCHAR(MAX) = LTRIM(RTRIM(@ANationalCodes)) 

			;WITH TotalEmployeeCount AS
			(
            SELECT 
				 COUNT(distinct trd.EmployeeID) TotalEmployeeCount
             FROM  wag.TreasuryRequestDetail trd 
			 INNER JOIN wag.Payroll p ON p.ID = trd.PayrollID 
			 LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = trd.NationalCode
			 where trd.RequestID = @RequestID
				  AND trd.TreasuryEmploymentType=@TreasuryEmploymentType
				  --AND(@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
				  --AND(@PlaceFinancing<1 OR trd.PlaceFinancing=@PlaceFinancing)
				  AND (@NationalCode IS NULL OR @NationalCode=trd.NationalCode)
              )

            SELECT  SUM(ISNULL(trd.Col15,0)) SumCol15, 
					SUM(ISNULL(trd.Col16,0)) SumCol16, 
					SUM(ISNULL(trd.Col17,0)) SumCol17, 
					SUM(ISNULL(trd.Col18,0)) SumCol18, 
					SUM(ISNULL(trd.Col19,0)) SumCol19,
					SUM(ISNULL(trd.Col20,0)) SumCol20,
					SUM(ISNULL(trd.Col21,0)) SumCol21,
					SUM(ISNULL(trd.Col22,0)) SumCol22,
					SUM(ISNULL(trd.Col23,0)) SumCol23,
					SUM(ISNULL(trd.Col24,0)) SumCol24,
					SUM(ISNULL(trd.Col25,0)) SumCol25, 
					SUM(ISNULL(trd.Col26,0)) SumCol26, 
					SUM(ISNULL(trd.Col27,0)) SumCol27, 
					SUM(ISNULL(trd.Col28,0)) SumCol28, 
					SUM(ISNULL(trd.Col29,0)) SumCol29, 
					SUM(ISNULL(trd.Col30,0)) SumCol30,
					SUM(ISNULL(trd.Col31,0)) SumCol31,
					SUM(ISNULL(trd.Col32,0)) SumCol32,
					SUM(ISNULL(trd.Col33,0)) SumCol33,
					SUM(ISNULL(trd.Col34,0)) SumCol34,
					SUM(ISNULL(trd.Col35,0)) SumCol35,
					SUM(ISNULL(trd.Col36,0)) SumCol36,
					SUM(ISNULL(trd.Col37,0)) SumCol37,
					SUM(ISNULL(trd.Col38,0)) SumCol38,
					SUM(ISNULL(trd.Col39,0)) SumCol39,
					SUM(ISNULL(trd.Col40,0)) SumCol40,
					SUM(ISNULL(trd.Col41,0)) SumCol41,
					SUM(ISNULL(trd.Col42,0)) SumCol42, 
					SUM(ISNULL(trd.Col43,0)) SumCol43, 
					SUM(ISNULL(trd.Col44,0)) SumCol44, 
					SUM(ISNULL(trd.Col45,0)) SumCol45, 
					SUM(ISNULL(trd.Col46,0)) SumCol46,
					SUM(ISNULL(trd.Col47,0)) SumCol47,
					SUM(ISNULL(trd.Col48,0)) SumCol48,
					SUM(ISNULL(trd.Col49,0)) SumCol49,
					SUM(ISNULL(trd.Col50,0)) SumCol50,
					SUM(ISNULL(trd.Col51,0)) SumCol51, 
					SUM(ISNULL(trd.Col52,0)) SumCol52,
					SUM(ISNULL(trd.Col53,0)) SumCol53,
					SUM(ISNULL(trd.Col54,0)) SumCol54,
					SUM(ISNULL(trd.Col55,0)) SumCol55, 
					SUM(ISNULL(trd.Col56,0)) SumCol56,
				 --   SUM(ISNULL(trd.Col15, 0))
				 --+ SUM(ISNULL(trd.Col48, 0)) SumPayments,
			  --     SUM(ISNULL(Col36, 0))
				 --+ SUM(ISNULL(Col44, 0)) 
				 --+ SUM(ISNULL(Col45, 0)) 
				 --+ SUM(ISNULL(Col46, 0)) 
				 --+ SUM(ISNULL(Col47, 0)) 
				 --+ SUM(ISNULL(Col49, 0)) 
				 --+ SUM(ISNULL(Col50, 0)) 
				 --+ SUM(ISNULL(Col51, 0)) 
				 --+ SUM(ISNULL(Col52, 0)) 
				 --+ SUM(ISNULL(Col53, 0)) 
				 --+ SUM(ISNULL(Col54, 0)) 
				 --+ SUM(ISNULL(Col55, 0)) SumDeductions,
				 COUNT(distinct trd.EmployeeID) EmployeeCount,
				 MAX(TotalEmployeeCount.TotalEmployeeCount) TotalEmployeeCount
             FROM  wag.TreasuryRequestDetail trd 
			 INNER JOIN wag.Payroll p ON p.ID = trd.PayrollID 
			 LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = trd.NationalCode
			 CROSS JOIN TotalEmployeeCount 
			 where trd.RequestID = @RequestID and p.PayrollType=2 --معوقه
				  AND trd.TreasuryEmploymentType=@TreasuryEmploymentType
				  --AND(@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
				  --AND(@PlaceFinancing<1 OR trd.PlaceFinancing=@PlaceFinancing)
				  AND (@NationalCode IS NULL OR @NationalCode=trd.NationalCode)
			
    END;
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetLastSummaryForRequestMoneyForTreasury
 @ARequestID UNIQUEIDENTIFIER,
 @APayrollID UNIQUEIDENTIFIER,
 @ALastMonth TINYINT,
 @ALastYear SMALLINT,
 @ATreasuryEmploymentType TINYINT,
 @ABudgetCode VARCHAR(20),
 @APlaceFinancing TINYINT,
 @ANationalCode NVARCHAR(10),
@ANationalCodes NVARCHAR(MAX)
WITH ENCRYPTION
AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @RequestID UNIQUEIDENTIFIER= @ARequestID,
		        @PayrollID UNIQUEIDENTIFIER= @APayrollID,
				@LastMonth TINYINT=@ALastMonth,
				@LastYear SMALLINT=@ALastYear ,
				@LastRequestID UNIQUEIDENTIFIER,
				@TreasuryEmploymentType TINYINT = @ATreasuryEmploymentType ,
				@BudgetCode VARCHAR(20) = @ABudgetCode ,
				@PlaceFinancing TINYINT =Coalesce(@APlaceFinancing,0),
				@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
				@NationalCodes NVARCHAR(MAX) = LTRIM(RTRIM(@ANationalCodes)) 
 

    SELECT @LastRequestID=TreasuryRequest.ID FROM wag.TreasuryRequest
       WHERE Month=@LastMonth and Year=@LastYear

			SELECT 
					SUM(ISNULL(trd.Col15,0)) SumCol15, 
					SUM(ISNULL(trd.Col16,0)) SumCol16, 
					SUM(ISNULL(trd.Col17,0)) SumCol17, 
					SUM(ISNULL(trd.Col18,0)) SumCol18, 
					SUM(ISNULL(trd.Col19,0)) SumCol19,
					SUM(ISNULL(trd.Col20,0)) SumCol20,
					SUM(ISNULL(trd.Col21,0)) SumCol21,
					SUM(ISNULL(trd.Col22,0)) SumCol22,
					SUM(ISNULL(trd.Col23,0)) SumCol23,
					SUM(ISNULL(trd.Col24,0)) SumCol24,
					SUM(ISNULL(trd.Col25,0)) SumCol25, 
					SUM(ISNULL(trd.Col26,0)) SumCol26, 
					SUM(ISNULL(trd.Col27,0)) SumCol27, 
					SUM(ISNULL(trd.Col28,0)) SumCol28, 
					SUM(ISNULL(trd.Col29,0)) SumCol29, 
					SUM(ISNULL(trd.Col30,0)) SumCol30,
					SUM(ISNULL(trd.Col31,0)) SumCol31,
					SUM(ISNULL(trd.Col32,0)) SumCol32,
					SUM(ISNULL(trd.Col33,0)) SumCol33,
					SUM(ISNULL(trd.Col34,0)) SumCol34,
					SUM(ISNULL(trd.Col35,0)) SumCol35,
					SUM(ISNULL(trd.Col36,0)) SumCol36,
					SUM(ISNULL(trd.Col37,0)) SumCol37,
					SUM(ISNULL(trd.Col38,0)) SumCol38,
					SUM(ISNULL(trd.Col39,0)) SumCol39,
					SUM(ISNULL(trd.Col40,0)) SumCol40,
					SUM(ISNULL(trd.Col41,0)) SumCol41,
					SUM(ISNULL(trd.Col42,0)) SumCol42, 
					SUM(ISNULL(trd.Col43,0)) SumCol43, 
					SUM(ISNULL(trd.Col44,0)) SumCol44, 
					SUM(ISNULL(trd.Col45,0)) SumCol45, 
					SUM(ISNULL(trd.Col46,0)) SumCol46,
					SUM(ISNULL(trd.Col47,0)) SumCol47,
					SUM(ISNULL(trd.Col48,0)) SumCol48,
					SUM(ISNULL(trd.Col49,0)) SumCol49,
					SUM(ISNULL(trd.Col50,0)) SumCol50,
					SUM(ISNULL(trd.Col51,0)) SumCol51, 
					SUM(ISNULL(trd.Col52,0)) SumCol52,
					SUM(ISNULL(trd.Col53,0)) SumCol53,
					SUM(ISNULL(trd.Col54,0)) SumCol54,
					SUM(ISNULL(trd.Col55,0)) SumCol55, 
					SUM(ISNULL(trd.Col56,0)) SumCol56,
				 --  SUM(ISNULL(trd.Col15, 0))
				 --+ SUM(ISNULL(trd.Col48, 0)) SumPayments,
			  --     SUM(ISNULL(Col36, 0))
				 --+ SUM(ISNULL(Col44, 0)) 
				 --+ SUM(ISNULL(Col45, 0)) 
				 --+ SUM(ISNULL(Col46, 0)) 
				 --+ SUM(ISNULL(Col47, 0)) 
				 --+ SUM(ISNULL(Col49, 0)) 
				 --+ SUM(ISNULL(Col50, 0)) 
				 --+ SUM(ISNULL(Col51, 0)) 
				 --+ SUM(ISNULL(Col52, 0)) 
				 --+ SUM(ISNULL(Col53, 0)) 
				 --+ SUM(ISNULL(Col54, 0)) 
				 --+ SUM(ISNULL(Col55, 0)) SumDeductions,
				 COUNT(distinct trd.EmployeeID) EmployeeCount
             FROM  [wag].[TreasuryRequestDetail] trd 
			 INNER JOIN wag.Payroll p ON p.ID = trd.PayrollID 
			 LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = trd.NationalCode
			 where trd.RequestID = @LastRequestID and p.PayrollType=1 --اصلی
			 AND trd.TreasuryEmploymentType=@TreasuryEmploymentType
			 --AND(@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
			 --AND(@PlaceFinancing<1 OR trd.PlaceFinancing=@PlaceFinancing)
			 AND (@NationalCode IS NULL OR @NationalCode=trd.NationalCode)
				
    END;
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetRequestMoneyForTreasury
	@ARequestID UNIQUEIDENTIFIER,
	@APayrollType TINYINT,
	@ANationalCode NVARCHAR(10),
	@ANationalCodes NVARCHAR(MAX),
	@ABudgetCode VARCHAR(20)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    
	DECLARE 
		@RequestID UNIQUEIDENTIFIER= @ARequestID,
		@PayrollType TINYINT= COALESCE(@APayrollType, 0),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@NationalCodes NVARCHAR(MAX) = LTRIM(RTRIM(@ANationalCodes))
    
	;WITH EmploymentType AS 
	(
		SELECT 
			[TreasuryID]
        FROM [CMN].[EmploymentType]
        GROUP BY [TreasuryID]
	)
	, Employee AS 
	(
		SELECT 
			et.TreasuryID TreasuryEmploymentType,
			Count(DISTINCT trd.EmployeeID) EmployeeCount
		FROM EmploymentType et
			INNER JOIN wag.TreasuryRequestDetail trd ON et.TreasuryID = trd.TreasuryEmploymentType AND trd.RequestID = @RequestID
			INNER JOIN wag.Payroll p ON p.ID = trd.PayrollID
			
		WHERE  (@PayrollType < 1 OR p.PayrollType = @PayrollType)
		   AND (@NationalCode IS NULL OR @NationalCode=trd.NationalCode)
		GROUP BY et.TreasuryID
	)
	, MainSelect AS 
	(
		SELECT 
			et.TreasuryID TreasuryEmploymentType,
			Employee.EmployeeCount,
			SUM(ISNULL(trd.Col15,0)
				+ ISNULL(trd.Col16,0)
				+ ISNULL(trd.Col17,0)
				+ ISNULL(trd.Col18,0)
				+ ISNULL(trd.Col19,0)
				+ ISNULL(trd.Col20,0)
				+ ISNULL(trd.Col21,0)
				+ ISNULL(trd.Col22,0)
				+ ISNULL(trd.Col23,0)
				+ ISNULL(trd.Col24,0)
				+ ISNULL(trd.Col25,0)
				+ ISNULL(trd.Col26,0)
				+ ISNULL(trd.Col27,0)
				+ ISNULL(trd.Col28,0)
				+ ISNULL(trd.Col29,0)
				+ ISNULL(trd.Col30,0)
				+ ISNULL(trd.Col31,0)
				+ ISNULL(trd.Col32,0)
				+ ISNULL(trd.Col33,0)
				+ ISNULL(trd.Col34,0)
				+ ISNULL(trd.Col35,0)
				+ ISNULL(trd.Col37,0)
				+ ISNULL(trd.Col38,0)
				+ ISNULL(trd.Col39,0)
				+ ISNULL(trd.Col40,0)
				+ ISNULL(trd.Col41,0)
				+ ISNULL(trd.Col42,0)
				+ ISNULL(trd.Col36,0)
				+ ISNULL(trd.Col44,0) 
				+ ISNULL(trd.Col45,0) 
				+ ISNULL(trd.Col46,0) 
				+ ISNULL(trd.Col47,0) 
				+ ISNULL(trd.Col43,0)  ---???????????????????????????????????

				+ ISNULL(trd.Col48,0)) SumCol15,   -- SumPayments
			SUM(ISNULL(trd.Col49,0)) SumCol49, 
			SUM(ISNULL(trd.Col44,0)) SumCol44, 
			SUM(ISNULL(trd.Col50,0) 
				+ ISNULL(trd.Col54,0)) SumCol50, 
			SUM(ISNULL(trd.Col45,0)) SumCol45, 
			SUM(ISNULL(trd.Col51,0)) SumCol51, 
			SUM(ISNULL(trd.Col52,0)) SumCol52, 
			SUM(ISNULL(trd.Col36,0)) SumCol36, 
			SUM(ISNULL(trd.Col46,0)) SumCol46, 
			SUM(ISNULL(trd.Col47,0) 
				+ ISNULL(trd.Col53,0) 
				+ ISNULL(trd.Col55,0)) SumCol47, 
			SUM(ISNULL(trd.Col36, 0)
					+ ISNULL(trd.Col44, 0)
					+ ISNULL(trd.Col45, 0)
					+ ISNULL(trd.Col46, 0)
					+ ISNULL(trd.Col47, 0)
					+ ISNULL(trd.Col49, 0)
					+ ISNULL(trd.Col50, 0)
					+ ISNULL(trd.Col51, 0)
					+ ISNULL(trd.Col52, 0)
					+ ISNULL(trd.Col53, 0)
					+ ISNULL(trd.Col54, 0)
					+ ISNULL(trd.Col55, 0)) SumCol55   --SumDeductions
		FROM EmploymentType et
			LEFT JOIN wag.TreasuryRequestDetail trd ON et.TreasuryID = trd.TreasuryEmploymentType and trd.RequestID = @RequestID
			LEFT JOIN Employee ON Employee.TreasuryEmploymentType=et.TreasuryID 
			LEFT JOIN wag.Payroll p ON p.ID = trd.PayrollID 
			LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = trd.NationalCode
		WHERE  (@PayrollType < 1 OR p.PayrollType = @PayrollType)
			   AND (@NationalCode IS NULL OR @NationalCode=trd.NationalCode)
			   --AND (@BudgetCode IS NULL OR @BudgetCode=trd.BudgetCode)
		GROUP BY Employee.EmployeeCount,et.TreasuryID
	)
	SELECT *,
		SumCol15 - SumCol55 SumCol56
	FROM MainSelect
END;
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetSummaryForRequestMoneyForTreasury
	 @ARequestID UNIQUEIDENTIFIER,
	 @APayrollID UNIQUEIDENTIFIER,
	 @ATreasuryEmploymentType TINYINT,
	 @ABudgetCode VARCHAR(20),
	 @APlaceFinancing TINYINT,
	 @ANationalCode NVARCHAR(10),
	 @ANationalCodes NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE 
		@RequestID UNIQUEIDENTIFIER= @ARequestID,
		@PayrollID UNIQUEIDENTIFIER= @APayrollID,
		@TreasuryEmploymentType TINYINT = @ATreasuryEmploymentType,
		@BudgetCode VARCHAR(20) = @ABudgetCode ,
		@PlaceFinancing TINYINT =Coalesce(@APlaceFinancing,0),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@NationalCodes NVARCHAR(MAX) = LTRIM(RTRIM(@ANationalCodes))  

	;WITH ALLEmployee AS 
	(
		SELECT   COUNT(distinct trd.EmployeeID) EmployeeCount
		FROM  wag.TreasuryRequestDetail trd 
			INNER JOIN wag.Payroll p ON p.ID = trd.PayrollID 
		where trd.RequestID = @RequestID 
			AND trd.TreasuryEmploymentType=@TreasuryEmploymentType
			--AND (@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
			--AND (@PlaceFinancing<1 OR trd.PlaceFinancing=@PlaceFinancing)
		    AND (@NationalCode IS NULL OR @NationalCode=trd.NationalCode)
	)
    SELECT 
		SUM(ISNULL(trd.Col15,0)) SumCol15, 
		SUM(ISNULL(trd.Col16,0)) SumCol16, 
		SUM(ISNULL(trd.Col17,0)) SumCol17, 
		SUM(ISNULL(trd.Col18,0)) SumCol18, 
		SUM(ISNULL(trd.Col19,0)) SumCol19,
		SUM(ISNULL(trd.Col20,0)) SumCol20,
		SUM(ISNULL(trd.Col21,0)) SumCol21,
		SUM(ISNULL(trd.Col22,0)) SumCol22,
		SUM(ISNULL(trd.Col23,0)) SumCol23,
		SUM(ISNULL(trd.Col24,0)) SumCol24,
		SUM(ISNULL(trd.Col25,0)) SumCol25, 
		SUM(ISNULL(trd.Col26,0)) SumCol26, 
        SUM(ISNULL(trd.Col27,0)) SumCol27, 
        SUM(ISNULL(trd.Col28,0)) SumCol28, 
        SUM(ISNULL(trd.Col29,0)) SumCol29, 
		SUM(ISNULL(trd.Col30,0)) SumCol30,
		SUM(ISNULL(trd.Col31,0)) SumCol31,
		SUM(ISNULL(trd.Col32,0)) SumCol32,
		SUM(ISNULL(trd.Col33,0)) SumCol33,
		SUM(ISNULL(trd.Col34,0)) SumCol34,
		SUM(ISNULL(trd.Col35,0)) SumCol35,
		SUM(ISNULL(trd.Col36,0)) SumCol36,
        SUM(ISNULL(trd.Col37,0)) SumCol37,
		SUM(ISNULL(trd.Col38,0)) SumCol38,
		SUM(ISNULL(trd.Col39,0)) SumCol39,
		SUM(ISNULL(trd.Col40,0)) SumCol40,
		SUM(ISNULL(trd.Col41,0)) SumCol41,
        SUM(ISNULL(trd.Col42,0)) SumCol42, 
        SUM(ISNULL(trd.Col43,0)) SumCol43, 
        SUM(ISNULL(trd.Col44,0)) SumCol44, 
        SUM(ISNULL(trd.Col45,0)) SumCol45, 
		SUM(ISNULL(trd.Col46,0)) SumCol46,
		SUM(ISNULL(trd.Col47,0)) SumCol47,
		SUM(ISNULL(trd.Col48,0)) SumCol48,
        SUM(ISNULL(trd.Col49,0)) SumCol49,
		SUM(ISNULL(trd.Col50,0)) SumCol50,
        SUM(ISNULL(trd.Col51,0)) SumCol51, 
		SUM(ISNULL(trd.Col52,0)) SumCol52,
		SUM(ISNULL(trd.Col53,0)) SumCol53,
		SUM(ISNULL(trd.Col54,0)) SumCol54,
        SUM(ISNULL(trd.Col55,0)) SumCol55, 
        SUM(ISNULL(trd.Col56,0)) SumCol56,
		--  SUM(ISNULL(trd.Col15, 0))
		--+ SUM(ISNULL(trd.Col48, 0)) SumPayments,
		--  SUM(ISNULL(Col36, 0))
		--+ SUM(ISNULL(Col44, 0)) 
		--+ SUM(ISNULL(Col45, 0)) 
		--+ SUM(ISNULL(Col46, 0)) 
		--+ SUM(ISNULL(Col47, 0)) 
		--+ SUM(ISNULL(Col49, 0)) 
		--+ SUM(ISNULL(Col50, 0)) 
		--+ SUM(ISNULL(Col51, 0)) 
		--+ SUM(ISNULL(Col52, 0)) 
		--+ SUM(ISNULL(Col53, 0)) 
		--+ SUM(ISNULL(Col54, 0)) 
		--+ SUM(ISNULL(Col55, 0)) SumDeductions,
		COUNT(distinct trd.EmployeeID) EmployeeCount,
		ALLEmployee.EmployeeCount  TotalEmployeeCount
    FROM  wag.TreasuryRequestDetail trd 
		INNER JOIN wag.Payroll p ON p.ID = trd.PayrollID 
		LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = trd.NationalCode
		CROSS JOIN ALLEmployee
	where trd.RequestID = @RequestID and p.PayrollType=1 --اصلی
		AND trd.TreasuryEmploymentType=@TreasuryEmploymentType
		AND(@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
		AND(@PlaceFinancing<1 OR trd.PlaceFinancing=@PlaceFinancing)
		AND (@NationalCode IS NULL OR @NationalCode=trd.NationalCode)
	GROUP BY ALLEmployee.EmployeeCount
			 
END;
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetTreasuryRequestDetail 
	@AID UNIQUEIDENTIFIER
AS
    BEGIN
    SET NOCOUNT ON;
    DECLARE 
		@ID UNIQUEIDENTIFIER= @AID;
    
	WITH MainSelect AS
	(
		SELECT 
			trd.[ID],
			trd.[RequestID],
			trd.[PayrollID],
            BC.Code [BudgetCode],
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
			trd.[NationalCode],
			[EmployeeNumber],
			[BirthYear],
			[WorkExperienceYears],
			[FirstName],
			[LastName],
			[Gender],
			[MarriageStatus],
			ChildrenCount,
			trd.EmploymentType,
			trd.EducationDegree,
			PensionFundType,
			InsuranceStatusType,
			Col15, 
			Col16, 
			Col17, 
			Col18, 
			Col19, 
			Col20, 
			Col21, 
			Col22, 
			Col23, 
			Col24, 
			Col25, 
			Col26, 
			Col27, 
			Col28, 
			Col29, 
			Col30, 
			Col31, 
			Col32, 
			Col33, 
			Col34, 
			Col35, 
			Col36, 
			Col37, 
			Col38, 
			Col39, 
			Col40, 
			Col41, 
			Col42, 
			Col43, 
			Col44, 
			Col45, 
			Col46, 
			Col47, 
			Col48, 
			Col49, 
			Col50, 
			Col51, 
			Col52, 
			Col53, 
			Col54, 
			Col55, 
			Col56, 
			ISNULL(Col15, 0) + ISNULL(Col16, 0) + ISNULL(Col17, 0)
			+ ISNULL(Col18, 0) + ISNULL(Col19, 0) + ISNULL(Col20, 0)
			+ ISNULL(Col21, 0) + ISNULL(Col22, 0) + ISNULL(Col23, 0)
			+ ISNULL(Col24, 0) + ISNULL(Col25, 0) + ISNULL(Col26, 0)
			+ ISNULL(Col27, 0) + ISNULL(Col28, 0) + ISNULL(Col29, 0)
			+ ISNULL(Col30, 0) + ISNULL(Col31, 0) + ISNULL(Col32, 0)
			+ ISNULL(Col33, 0) + ISNULL(Col34, 0) + ISNULL(Col35, 0) + ISNULL(Col36, 0)
			+ ISNULL(Col37, 0) + ISNULL(Col38, 0) + ISNULL(Col39, 0)
			+ ISNULL(Col40, 0) + ISNULL(Col41, 0) + ISNULL(Col42, 0)
			+ ISNULL(Col43, 0) + ISNULL(Col44, 0) + ISNULL(Col45, 0) 
			+ ISNULL(Col46, 0) + ISNULL(Col47, 0) + ISNULL(Col48, 0) SumPayments,
			ISNULL(Col36, 0) + ISNULL(Col44, 0) + ISNULL(Col45, 0) 
			+ ISNULL(Col46, 0) + ISNULL(Col47, 0) + ISNULL(Col49, 0) 
			+ ISNULL(Col50, 0) + ISNULL(Col51, 0) + ISNULL(Col52, 0) 
			+ ISNULL(Col53, 0) + ISNULL(Col54, 0) + ISNULL(Col55, 0) SumDeductions,
			ba.Sheba,
			b.[Name] BankName,
			--ba.[BranchName],
			--ba.[BranchCode],
			dep.[Name] OrganName,
			[TreasuryGender], 
			[TreasuryEmploymentType],
			[TreasuryEducationDegree], 
			[TreasuryPensionFundType], 
			[TreasuryInsuranceStatusType], 
			[TreasuryMarriageStatus],
			trd.[SacrificialType],
			p.PayrollType
		FROM [wag].[TreasuryRequestDetail] trd WITH (SNAPSHOT)
			INNER JOIN wag.payroll p ON p.ID = trd.payrollID
			INNER JOIN wag.PayrollEmployee pe ON pe.PayrollID=p.ID AND pe.EmployeeID=trd.EmployeeID
			INNER JOIN org._Department dep ON dep.id = p.organID
			INNER JOIN pbl.BankAccount ba  ON ba.id = trd.BankAccountID
			LEFT JOIN pbl.Bank b  ON b.id =ba.BankID
			LEFT JOIN wag.TreasuryRequest tr ON tr.ID = trd.RequestID
			LEFT JOIN pbo.BudgetCodeFinancingResource BCFR ON BCFR.ID = tr.BudgetCodeFinancingResourceID
			LEFT JOIN pbo.BudgetCode BC ON BC.ID = BCFR.BudgetCodeID
			LEFT JOIN pbo.FinancingResource FR ON FR.ID = BCFR.FinancingResourceID
		WHERE @AID = trd.ID
	)
	SELECT *,
		SumPayments - SumDeductions [Sum]
	FROM MainSelect
END;
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetTreasuryRequestDetails
	@ARequestID UNIQUEIDENTIFIER, 
	@AFirstName NVARCHAR(255), 
	@ALastName NVARCHAR(255), 
	@ANationalCode CHAR(10), 
	@ABudgetCode VARCHAR(20),
	@APayrollID UNIQUEIDENTIFIER, 
	@APayrollType TINYINT = 3,
	@AEmploymentType TINYINT,
	@ATreasuryEmploymentType TINYINT,
	@ASacrificialType TINYINT,
	@APlaceFinancing TINYINT,
	@AGetTotalCount BIT, 
	@ASortExp NVARCHAR(MAX), 
	@APageSize INT, 
	@APageIndex INT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@FirstName NVARCHAR(255) = @AFirstName, 
		@LastName NVARCHAR(255) = @ALastName, 
		@NationalCode CHAR(10) = @ANationalCode, 
		@BudgetCode VARCHAR(20) = @ABudgetCode ,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@PayrollType TINYINT = COALESCE(@APayrollType, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@TreasuryEmploymentType TINYINT = COALESCE(@ATreasuryEmploymentType, 0),
		@SacrificialType TINYINT = COALESCE(@ASacrificialType, 0),
		@PlaceFinancing TINYINT = COALESCE(@APlaceFinancing, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)
        
	IF @PageIndex = 0
	BEGIN
		SET @pagesize = 10000000;
        SET @PageIndex = 1;
    END

    ;WITH Cte_TreasuryRequestDetail As 
	(
	 SELECT IIF(@PayrollType=3,0x, trd.[ID]) ID,
            trd.[RequestID],
			IIF(@PayrollType=3,0x, [PayrollID]) [PayrollID],
            BC.Code [BudgetCode],
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
            trd.[NationalCode],
            [EmployeeNumber],
            [BirthYear],
            [WorkExperienceYears],
            [FirstName],
            [LastName],
            [Gender],
            [MarriageStatus],
            [ChildrenCount],
            [EmploymentType],
            [EducationDegree],
            [PensionFundType],
            [InsuranceStatusType],
            Col15, Col16, Col17, Col18, Col19, Col20, 
            Col21, Col22, Col23, Col24, Col25, Col26, 
            Col27, Col28, Col29, Col30, Col31, Col32, 
            Col33, Col34, Col35, Col36, Col37, Col38, 
            Col39, Col40, Col41, Col42, Col43, Col44, 
            Col45, Col46, Col47, Col48, Col49, Col50, 
            Col51, Col52, Col53, Col54, Col55, Col56, 
			ISNULL(Col15, 0) + ISNULL(Col16, 0) + ISNULL(Col17, 0)
			+ ISNULL(Col18, 0) + ISNULL(Col19, 0) + ISNULL(Col20, 0)
			+ ISNULL(Col21, 0) + ISNULL(Col22, 0) + ISNULL(Col23, 0)
			+ ISNULL(Col24, 0) + ISNULL(Col25, 0) + ISNULL(Col26, 0)
			+ ISNULL(Col27, 0) + ISNULL(Col28, 0) + ISNULL(Col29, 0)
			+ ISNULL(Col30, 0) + ISNULL(Col31, 0) + ISNULL(Col32, 0)
			+ ISNULL(Col33, 0) + ISNULL(Col34, 0) + ISNULL(Col35, 0) + ISNULL(Col36, 0)
			+ ISNULL(Col37, 0) + ISNULL(Col38, 0) + ISNULL(Col39, 0)
			+ ISNULL(Col40, 0) + ISNULL(Col41, 0) + ISNULL(Col42, 0)
			+ ISNULL(Col43, 0) + ISNULL(Col44, 0) + ISNULL(Col45, 0) 
			+ ISNULL(Col46, 0) + ISNULL(Col47, 0) + ISNULL(Col48, 0) SumPayments,
			ISNULL(Col36, 0) + ISNULL(Col44, 0) + ISNULL(Col45, 0) 
			+ ISNULL(Col46, 0) + ISNULL(Col47, 0) + ISNULL(Col49, 0) 
			+ ISNULL(Col50, 0) + ISNULL(Col51, 0) + ISNULL(Col52, 0) 
			+ ISNULL(Col53, 0) + ISNULL(Col54, 0) + ISNULL(Col55, 0) SumDeductions,
            ba.Sheba,
			b.[Name] BankName,
			--ba.BranchName,
			--ba.BranchCode,
			dep.[Name] OrganName,
            TreasuryGender,
            TreasuryEmploymentType,
            TreasuryEducationDegree, 
            TreasuryPensionFundType, 
            TreasuryInsuranceStatusType, 
            TreasuryMarriageStatus,
			trd.[SacrificialType],
			p.PayrollType
        FROM wag.TreasuryRequestDetail trd WITH (SNAPSHOT)
            INNER JOIN wag.payroll p ON p.ID = trd.payrollID
            INNER JOIN org._Department dep ON dep.id = p.organID
			LEFT JOIN pbl.BankAccount ba ON ba.id = trd.BankAccountID
			LEFT JOIN pbl.Bank b ON b.id = ba.BankID
			LEFT JOIN wag.TreasuryRequest tr ON tr.ID = trd.RequestID
			LEFT JOIN pbo.BudgetCodeFinancingResource BCFR ON BCFR.ID = tr.BudgetCodeFinancingResourceID
			LEFT JOIN pbo.BudgetCode BC ON BC.ID = BCFR.BudgetCodeID
			LEFT JOIN pbo.FinancingResource FR ON FR.ID = BCFR.FinancingResourceID
        WHERE (@RequestID = trd.RequestID)
			AND (@PayrollID IS NULL OR trd.PayrollID = @PayrollID)
			AND (@PayrollType < 1 OR (@PayrollType=3 AND  p.PayrollType IN(1,2) ) OR p.PayrollType = @PayrollType)
			AND (@EmploymentType < 1 OR trd.[EmploymentType] = @EmploymentType)
			AND (@TreasuryEmploymentType < 1 OR trd.[TreasuryEmploymentType] = @TreasuryEmploymentType)
			AND (@SacrificialType < 1 OR trd.[SacrificialType] = @SacrificialType)
			AND (@PlaceFinancing < 1 OR trd.PlaceFinancing = @PlaceFinancing)
			AND (@NationalCode IS NULL OR trd.NationalCode = @NationalCode)
			AND	(@FirstName IS NULL OR trd.FirstName LIKE N'%' + @FirstName + '%')
			AND (@LastName IS NULL OR trd.LastName LIKE N'%' + @LastName + '%')
			AND(@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
	)
	,AggrigationTreasuryRequestDetail As 
	(
	 SELECT [RequestID],
            [BudgetCode],
            [NationalCode],
            SUM(Col15) Col15, SUM(Col16) Col16, SUM(Col17) Col17, 
            SUM(Col18) Col18, SUM(Col19) Col19, SUM(Col20) Col20, 
            SUM(Col21) Col21, SUM(Col22) Col22, SUM(Col23) Col23, 
            SUM(Col24) Col24, SUM(Col25) Col25, SUM(Col26) Col26, 
            SUM(Col27) Col27, SUM(Col28) Col28, SUM(Col29) Col29, 
            SUM(Col30) Col30, SUM(Col31) Col31, SUM(Col32) Col32, 
            SUM(Col33) Col33, SUM(Col34) Col34, SUM(Col35) Col35, 
            SUM(Col36) Col36, SUM(Col37) Col37, SUM(Col38) Col38, 
            SUM(Col39) Col39, SUM(Col40) Col40, SUM(Col41) Col41, 
            SUM(Col42) Col42, SUM(Col43) Col43, SUM(Col44) Col44, 
            SUM(Col45) Col45, SUM(Col46) Col46, SUM(Col47) Col47, 
            SUM(Col48) Col48, SUM(Col49) Col49, SUM(Col50) Col50, 
            SUM(Col51) Col51, SUM(Col52) Col52, SUM(Col53) Col53, 
            SUM(Col54) Col54, SUM(Col55) Col55, SUM(Col56) Col56, 
			SUM(SumPayments) SumPayments,
			SUM(SumDeductions) SumDeductions
        FROM Cte_TreasuryRequestDetail
		GROUP BY [RequestID],
                 [BudgetCode],
                 [NationalCode]
	)
	,MainSelect AS 
	(
	SELECT DISTINCT  trd.[ID],
            trd.[RequestID],
            trd.[PayrollID],		
            trd.[BudgetCode],
            trd.[NationalCode],
            trd.[EmployeeNumber],
            trd.[BirthYear],
            trd.[WorkExperienceYears],
            trd.[FirstName],
            trd.[LastName],
            trd.[Gender],
            trd.[MarriageStatus],
            trd.[ChildrenCount],
            trd.[EmploymentType],
            trd.[EducationDegree],
            trd.[PensionFundType],
            trd.[InsuranceStatusType],
            IIF(@PayrollType=3,atrd.Col15,trd.Col15)   Col15, 
            IIF(@PayrollType=3,atrd.Col16,trd.Col16)   Col16, 
            IIF(@PayrollType=3,atrd.Col17,trd.Col17)   Col17, 
            IIF(@PayrollType=3,atrd.Col18,trd.Col18)   Col18, 
            IIF(@PayrollType=3,atrd.Col19,trd.Col19)   Col19, 
            IIF(@PayrollType=3,atrd.Col20,trd.Col20)   Col20, 
            IIF(@PayrollType=3,atrd.Col21,trd.Col21)   Col21, 
            IIF(@PayrollType=3,atrd.Col22,trd.Col22)   Col22, 
            IIF(@PayrollType=3,atrd.Col23,trd.Col23)   Col23, 
            IIF(@PayrollType=3,atrd.Col24,trd.Col24)   Col24, 
            IIF(@PayrollType=3,atrd.Col25,trd.Col25)   Col25, 
            IIF(@PayrollType=3,atrd.Col26,trd.Col26)   Col26, 
            IIF(@PayrollType=3,atrd.Col27,trd.Col27)   Col27, 
            IIF(@PayrollType=3,atrd.Col28,trd.Col28)   Col28, 
            IIF(@PayrollType=3,atrd.Col29,trd.Col29)   Col29, 
            IIF(@PayrollType=3,atrd.Col30,trd.Col30)   Col30, 
            IIF(@PayrollType=3,atrd.Col31,trd.Col31)   Col31, 
            IIF(@PayrollType=3,atrd.Col32,trd.Col32)   Col32, 
            IIF(@PayrollType=3,atrd.Col33,trd.Col33)   Col33, 
            IIF(@PayrollType=3,atrd.Col34,trd.Col34)   Col34, 
            IIF(@PayrollType=3,atrd.Col35,trd.Col35)   Col35, 
            IIF(@PayrollType=3,atrd.Col36,trd.Col36)   Col36, 
            IIF(@PayrollType=3,atrd.Col37,trd.Col37)   Col37, 
            IIF(@PayrollType=3,atrd.Col38,trd.Col38)   Col38, 
            IIF(@PayrollType=3,atrd.Col39,trd.Col39)   Col39, 
            IIF(@PayrollType=3,atrd.Col40,trd.Col40)   Col40, 
            IIF(@PayrollType=3,atrd.Col41,trd.Col41)   Col41, 
            IIF(@PayrollType=3,atrd.Col42,trd.Col42)   Col42, 
            IIF(@PayrollType=3,atrd.Col43,trd.Col43)   Col43, 
            IIF(@PayrollType=3,atrd.Col44,trd.Col44)   Col44, 
            IIF(@PayrollType=3,atrd.Col45,trd.Col45)   Col45, 
            IIF(@PayrollType=3,atrd.Col46,trd.Col46)   Col46, 
            IIF(@PayrollType=3,atrd.Col47,trd.Col47)   Col47, 
            IIF(@PayrollType=3,atrd.Col48,trd.Col48)   Col48, 
            IIF(@PayrollType=3,atrd.Col49,trd.Col49)   Col49, 
            IIF(@PayrollType=3,atrd.Col50,trd.Col50)   Col50, 
            IIF(@PayrollType=3,atrd.Col51,trd.Col51)   Col51, 
            IIF(@PayrollType=3,atrd.Col52,trd.Col52)   Col52, 
            IIF(@PayrollType=3,atrd.Col53,trd.Col53)   Col53, 
            IIF(@PayrollType=3,atrd.Col54,trd.Col54)   Col54, 
            IIF(@PayrollType=3,atrd.Col55,trd.Col55)   Col55, 
            IIF(@PayrollType=3,atrd.Col56,trd.Col56)   Col56,
			IIF(@PayrollType=3,atrd.SumPayments,atrd.SumPayments) SumPayments,
			IIF(@PayrollType=3,atrd.SumDeductions,atrd.SumDeductions) SumDeductions,
            trd.Sheba,
			trd.BankName,
			--trd.BranchName,
			--trd.BranchCode,
			trd.OrganName,
            trd.TreasuryGender,
            trd.TreasuryEmploymentType,
            trd.TreasuryEducationDegree, 
            trd.TreasuryPensionFundType, 
            trd.TreasuryInsuranceStatusType, 
            trd.TreasuryMarriageStatus,
			trd.[SacrificialType],
			IIF(@PayrollType=3,@PayrollType,PayrollType) PayrollType
       FROM Cte_TreasuryRequestDetail trd
	   LEFT JOIN AggrigationTreasuryRequestDetail atrd ON atrd.RequestID=trd.RequestID AND atrd.BudgetCode=trd.BudgetCode AND atrd.NationalCode=trd.NationalCode
		),
    Total AS 
	(
		SELECT COUNT(*) AS Total
			FROM MainSelect
		WHERE @GetTotalCount = 1
	)
    SELECT *,
		SumPayments - SumDeductions [Sum]
    FROM MainSelect, 
        Total
    ORDER BY nationalcode
    OFFSET((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END;
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetTreasuryRequestDetailsForWFile
     @ARequestID UNIQUEIDENTIFIER, 
	 @AFirstName NVARCHAR(255), 
	 @ALastName NVARCHAR(255), 
	 @ANationalCode CHAR(10), 
	 @APayrollType TINYINT, 
	 @ASacrificialType TINYINT,
     @AGetTotalCount BIT, 
     @ASortExp NVARCHAR(MAX), 
     @APageSize INT, 
     @APageIndex INT
AS
    BEGIN
        SET NOCOUNT ON;
	DECLARE @RequestID UNIQUEIDENTIFIER= @ARequestID,
        @FirstName NVARCHAR(255)= @AFirstName, 
	    @LastName NVARCHAR(255)= @ALastName, 
	    @NationalCode CHAR(10)= @ANationalCode, 
		@GetTotalCount BIT= COALESCE(@AGetTotalCount, 0),
		@PayrollType TINYINT= COALESCE(@APayrollType, 0),
		@SacrificialType TINYINT = COALESCE(@ASacrificialType, 0),
		@SortExp NVARCHAR(MAX)= LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT= COALESCE(@APageSize, 20),
		@PageIndex INT= COALESCE(@APageIndex, 0);
        IF @PageIndex = 0
            BEGIN
                SET @pagesize = 10000000;
                SET @PageIndex = 1;
            END

        ; WITH MainSelect AS
		( SELECT
			trd.RequestID,
			BC.Code BudgetCode,
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
            trd.[NationalCode],
            trd.[EmployeeNumber],
            trd.[BirthYear],
            trd.[WorkExperienceYears],
            trd.[FirstName],
            trd.[LastName],
            trd.[Gender],
            trd.[MarriageStatus],
            trd.[ChildrenCount],
            trd.[EmploymentType],
            trd.[EducationDegree],
            trd.[PensionFundType],
            trd.[InsuranceStatusType],
            SUM(trd.[Col15]) [Col15], SUM(trd.[Col16]) [Col16], SUM(trd.[Col17]) [Col17], SUM(trd.[Col18]) [Col18], 
            SUM(trd.[Col19]) [Col19], SUM(trd.[Col20]) [Col20], SUM(trd.[Col21]) [Col21], SUM(trd.[Col22]) [Col22], 
            SUM(trd.[Col23]) [Col23], SUM(trd.[Col24]) [Col24], SUM(trd.[Col25]) [Col25], SUM(trd.[Col26]) [Col26], 
            SUM(trd.[Col27]) [Col27], SUM(trd.[Col28]) [Col28], SUM(trd.[Col29]) [Col29], SUM(trd.[Col30]) [Col30], 
            SUM(trd.[Col31]) [Col31], SUM(trd.[Col32]) [Col32], SUM(trd.[Col33]) [Col33], SUM(trd.[Col34]) [Col34], 
            SUM(trd.[Col35]) [Col35], SUM(trd.[Col36]) [Col36], SUM(trd.[Col37]) [Col37], SUM(trd.[Col38]) [Col38], 
            SUM(trd.[Col39]) [Col39], SUM(trd.[Col40]) [Col40], SUM(trd.[Col41]) [Col41], SUM(trd.[Col42]) [Col42], 
            SUM(trd.[Col43]) [Col43], SUM(trd.[Col44]) [Col44], SUM(trd.[Col45]) [Col45], SUM(trd.[Col46]) [Col46], 
            SUM(trd.[Col47]) [Col47], SUM(trd.[Col48]) [Col48], SUM(trd.[Col49]) [Col49], SUM(trd.[Col50]) [Col50], 
            SUM(trd.[Col51]) [Col51], SUM(trd.[Col52]) [Col52], SUM(trd.[Col53]) [Col53], SUM(trd.[Col54]) [Col54], 
            SUM(trd.[Col55]) [Col55], SUM(trd.[Col56]) [Col56],
            ba.Sheba,
			b.[Name] BankName,
			--ba.[BranchName],
			--ba.[BranchCode],
			dep.[Name] OrganName,
			dep.[Code] OrganCode,
			[TreasuryGender], 
			[TreasuryEmploymentType],
			[TreasuryEducationDegree], 
			[TreasuryPensionFundType], 
			[TreasuryInsuranceStatusType], 
			[TreasuryMarriageStatus],
			trd.[SacrificialType],
			p.PayrollType
			FROM wag.TreasuryRequestDetail trd WITH (SNAPSHOT)
            INNER JOIN wag.payroll p ON p.ID = trd.payrollID
			INNER JOIN emp.Employee ON Employee.ID = trd.EmployeeID
            INNER JOIN org._Department dep ON dep.id = Employee.OrganID
			LEFT JOIN pbl.BankAccount ba ON ba.id = trd.BankAccountID
			LEFT JOIN pbl.Bank b ON b.id = ba.BankID
			LEFT JOIN wag.TreasuryRequest tr ON tr.ID = trd.RequestID
			LEFT JOIN pbo.BudgetCodeFinancingResource BCFR ON BCFR.ID = tr.BudgetCodeFinancingResourceID
			LEFT JOIN pbo.BudgetCode BC ON BC.ID = BCFR.BudgetCodeID
			LEFT JOIN pbo.FinancingResource FR ON FR.ID = BCFR.FinancingResourceID
            WHERE (@RequestID = trd.RequestID)
				AND (@PayrollType < 0 OR p.PayrollType =@PayrollType)
				AND (@NationalCode IS NULL OR trd.NationalCode =@NationalCode)
				AND (@SacrificialType < 1 OR trd.[SacrificialType] = @SacrificialType)
				AND (@FirstName IS NULL OR trd.FirstName LIKE N'%'+@FirstName+'%')
				AND (@LastName IS NULL OR trd.LastName LIKE N'%'+@LastName+'%')
			GROUP BY 
				trd.RequestID, BC.Code, FR.[Name], FR.AROCode, FR.PBOCode, FR.TreasuryCode, trd.[NationalCode], trd.[EmployeeNumber],
				trd.[BirthYear], trd.[WorkExperienceYears], trd.[FirstName], trd.[LastName], trd.[Gender], trd.[MarriageStatus],
				trd.[ChildrenCount], trd.[EmploymentType], trd.[EducationDegree], trd.[PensionFundType], trd.[InsuranceStatusType],
				ba.Sheba, b.[Name], dep.[Name], dep.[Code], [TreasuryGender], [TreasuryEmploymentType],
				[TreasuryEducationDegree], [TreasuryPensionFundType], [TreasuryInsuranceStatusType], [TreasuryMarriageStatus] ,trd.[SacrificialType], p.PayrollType
			)
			, Total AS
			(
				SELECT COUNT(*) AS Total
				FROM MainSelect
				WHERE @GetTotalCount = 1
			 )
             SELECT *
             FROM MainSelect, Total
             ORDER BY NationalCode
END;
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetTreasuryRequestDetailsSummary
	@ARequestID UNIQUEIDENTIFIER, 
	@AFirstName NVARCHAR(255), 
	@ALastName NVARCHAR(255), 
	@ANationalCode CHAR(10),
	@ABudgetCode VARCHAR(20),
	@APayrollID UNIQUEIDENTIFIER, 
	@APayrollType TINYINT,
	@AEmploymentType TINYINT,
	@ATreasuryEmploymentType TINYINT,
	@ASacrificialType TINYINT,
	@AGetTotalCount BIT, 
	@ASortExp NVARCHAR(MAX), 
	@APageSize INT, 
	@APageIndex INT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
        @FirstName NVARCHAR(255) = @AFirstName, 
	    @LastName NVARCHAR(255) = @ALastName, 
	    @NationalCode CHAR(10) = @ANationalCode, 
		@BudgetCode VARCHAR(20) = @ABudgetCode ,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@PayrollType TINYINT = COALESCE(@APayrollType, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@TreasuryEmploymentType TINYINT = COALESCE(@ATreasuryEmploymentType, 0),
		@SacrificialType TINYINT = COALESCE(@ASacrificialType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0);
        
	IF @PageIndex = 0
    BEGIN
        SET @pagesize = 10000000;
        SET @PageIndex = 1;
    END
	 ;WITH Cte_TreasuryRequestDetail As 
	(
	 SELECT IIF(@PayrollType=3,0x, trd.[ID]) ID,
            trd.[RequestID],
			IIF(@PayrollType=3,0x, [PayrollID]) [PayrollID],
            BC.Code [BudgetCode],
			FR.[Name] FinancingResourceName,
			FR.AROCode FinancingResourceAROCode,
			FR.PBOCode FinancingResourcePBOCode,
			FR.TreasuryCode FinancingResourceTreasuryCode,
            trd.[NationalCode],
            [EmployeeNumber],
            [BirthYear],
            [WorkExperienceYears],
            [FirstName],
            [LastName],
            [Gender],
            [MarriageStatus],
            [ChildrenCount],
            [EmploymentType],
            [EducationDegree],
            [PensionFundType],
            [InsuranceStatusType],
            Col15, 
            Col16, 
            Col17, 
			ISNULL(Col15, 0) + ISNULL(Col16, 0) + ISNULL(Col17, 0)
			+ ISNULL(Col18, 0) + ISNULL(Col19, 0) + ISNULL(Col20, 0)
			+ ISNULL(Col21, 0) + ISNULL(Col22, 0) + ISNULL(Col23, 0)
			+ ISNULL(Col24, 0) + ISNULL(Col25, 0) + ISNULL(Col26, 0)
			+ ISNULL(Col27, 0) + ISNULL(Col28, 0) + ISNULL(Col29, 0)
			+ ISNULL(Col30, 0) + ISNULL(Col31, 0) + ISNULL(Col32, 0)
			+ ISNULL(Col33, 0) + ISNULL(Col34, 0) + ISNULL(Col35, 0) + ISNULL(Col36, 0)
			+ ISNULL(Col37, 0) + ISNULL(Col38, 0) + ISNULL(Col39, 0)
			+ ISNULL(Col40, 0) + ISNULL(Col41, 0) + ISNULL(Col42, 0)
			+ ISNULL(Col43, 0) + ISNULL(Col44, 0) + ISNULL(Col45, 0) 
			+ ISNULL(Col46, 0) + ISNULL(Col47, 0) + ISNULL(Col48, 0) SumPayments,
			ISNULL(Col36, 0) + ISNULL(Col44, 0) + ISNULL(Col45, 0) 
			+ ISNULL(Col46, 0) + ISNULL(Col47, 0) + ISNULL(Col49, 0) 
			+ ISNULL(Col50, 0) + ISNULL(Col51, 0) + ISNULL(Col52, 0) 
			+ ISNULL(Col53, 0) + ISNULL(Col54, 0) + ISNULL(Col55, 0) SumDeductions,
            ba.Sheba,
			b.[Name] BankName,
			--ba.BranchName,
			--ba.BranchCode,
			dep.[Name] OrganName,
            TreasuryGender,
            TreasuryEmploymentType,
            TreasuryEducationDegree, 
            TreasuryPensionFundType, 
            TreasuryInsuranceStatusType, 
            TreasuryMarriageStatus,
			trd.[SacrificialType],
			p.PayrollType
        FROM wag.TreasuryRequestDetail trd WITH (SNAPSHOT)
            INNER JOIN wag.payroll p ON p.ID = trd.payrollID
            INNER JOIN org._Department dep ON dep.id = p.organID
			LEFT JOIN pbl.BankAccount ba ON ba.id = trd.BankAccountID
			LEFT JOIN pbl.Bank b ON b.id = ba.BankID
			LEFT JOIN wag.TreasuryRequest tr ON tr.ID = trd.RequestID
			LEFT JOIN pbo.BudgetCodeFinancingResource BCFR ON BCFR.ID = tr.BudgetCodeFinancingResourceID
			LEFT JOIN pbo.BudgetCode BC ON BC.ID = BCFR.BudgetCodeID
			LEFT JOIN pbo.FinancingResource FR ON FR.ID = BCFR.FinancingResourceID
        WHERE (@RequestID = trd.RequestID)
			AND (@PayrollID IS NULL OR trd.PayrollID = @PayrollID)
			AND (@PayrollType < 1 OR (@PayrollType=3 AND  p.PayrollType IN(1,2) ) OR p.PayrollType = @PayrollType)
			AND (@EmploymentType < 1 OR trd.[EmploymentType] = @EmploymentType)
			AND (@TreasuryEmploymentType < 1 OR trd.[TreasuryEmploymentType] = @TreasuryEmploymentType)
			AND (@SacrificialType < 1 OR trd.[SacrificialType] = @SacrificialType)
			AND (@NationalCode IS NULL OR trd.NationalCode = @NationalCode)
			AND	(@FirstName IS NULL OR trd.FirstName LIKE N'%' + @FirstName + '%')
			AND (@LastName IS NULL OR trd.LastName LIKE N'%' + @LastName + '%')
			AND(@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
	)
	,AggrigationTreasuryRequestDetail As 
	(
	 SELECT [RequestID],
            [BudgetCode],
            [NationalCode],
            SUM(Col15) Col15, 
            SUM(Col16) Col16, 
            SUM(Col17) Col17, 
			SUM(SumPayments) SumPayments,
			SUM(SumDeductions) SumDeductions
        FROM Cte_TreasuryRequestDetail
		GROUP BY [RequestID],
                 [BudgetCode],
                 [NationalCode]
	)
	,MainSelect AS 
	(
	SELECT DISTINCT  trd.[ID],
            trd.[RequestID],
            trd.[PayrollID],		
            trd.[BudgetCode],
			trd.FinancingResourceName,
			trd.FinancingResourceAROCode,
			trd.FinancingResourcePBOCode,
			trd.FinancingResourceTreasuryCode,
            trd.[NationalCode],
            trd.[EmployeeNumber],
            trd.[BirthYear],
            trd.[WorkExperienceYears],
            trd.[FirstName],
            trd.[LastName],
            trd.[Gender],
            trd.[MarriageStatus],
            trd.[ChildrenCount],
            trd.[EmploymentType],
            trd.[EducationDegree],
            trd.[PensionFundType],
            trd.[InsuranceStatusType],
            IIF(@PayrollType=3,atrd.Col15,trd.Col15)   Col15, 
            IIF(@PayrollType=3,atrd.Col16,trd.Col16)   Col16, 
            IIF(@PayrollType=3,atrd.Col17,trd.Col17)   Col17, 
			IIF(@PayrollType=3,atrd.SumPayments,trd.SumPayments) SumPayments,
			IIF(@PayrollType=3,atrd.SumDeductions,trd.SumDeductions) SumDeductions,
            trd.Sheba,
			trd.BankName,
			--trd.BranchName,
			--trd.BranchCode,
			trd.OrganName,
            trd.TreasuryGender,
            trd.TreasuryEmploymentType,
            trd.TreasuryEducationDegree, 
            trd.TreasuryPensionFundType, 
            trd.TreasuryInsuranceStatusType, 
            trd.TreasuryMarriageStatus,
			trd.[SacrificialType],
			IIF(@PayrollType=3,@PayrollType,PayrollType) PayrollType
       FROM Cte_TreasuryRequestDetail trd
	   LEFT JOIN AggrigationTreasuryRequestDetail atrd ON atrd.RequestID=trd.RequestID AND atrd.BudgetCode=trd.BudgetCode AND atrd.NationalCode=trd.NationalCode
		),
    Total AS 
	(
		SELECT COUNT(*) AS Total
			FROM MainSelect
		WHERE @GetTotalCount = 1
	)
    SELECT *,
		SumPayments - SumDeductions [Sum]
    FROM MainSelect, 
        Total
    ORDER BY nationalcode
    OFFSET((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
	
END
GO
USE [Kama.Aro.Pardakht];
GO
CREATE OR ALTER PROCEDURE wag.spGetTreasuryRequestDetailsSummaryExcel
	@ARequestID UNIQUEIDENTIFIER, 
	@AFirstName NVARCHAR(255), 
	@ALastName NVARCHAR(255), 
	@ANationalCode CHAR(10),
	@ABudgetCode VARCHAR(20),
	@APayrollID UNIQUEIDENTIFIER, 
	@APayrollType TINYINT,
	@AEmploymentType TINYINT,
	@ATreasuryEmploymentType TINYINT,
	@ASacrificialType TINYINT,
	@AGetTotalCount BIT, 
	@ASortExp NVARCHAR(MAX), 
	@APageSize INT, 
	@APageIndex INT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
        @FirstName NVARCHAR(255) = @AFirstName, 
	    @LastName NVARCHAR(255) = @ALastName, 
	    @NationalCode CHAR(10) = @ANationalCode, 
		@BudgetCode VARCHAR(20) = @ABudgetCode ,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@PayrollType TINYINT = COALESCE(@APayrollType, 0),
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@TreasuryEmploymentType TINYINT = COALESCE(@ATreasuryEmploymentType, 0),
		@SacrificialType TINYINT = COALESCE(@ASacrificialType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0);
        
	IF @PageIndex = 0
    BEGIN
        SET @pagesize = 10000000;
        SET @PageIndex = 1;
    END
	
	;WITH Selects AS 
	(
		SELECT
            [FirstName], 
            [LastName], 
			trd.[NationalCode],
			ISNULL(Col15, 0)
		  + ISNULL(Col16, 0)
		  + ISNULL(Col17, 0)
		  + ISNULL(Col18, 0)
		  + ISNULL(Col19, 0)
		  + ISNULL(Col20, 0)
		  + ISNULL(Col21, 0)
		  + ISNULL(Col22, 0)
		  + ISNULL(Col23, 0)
		  + ISNULL(Col24, 0)
		  + ISNULL(Col25, 0)
		  + ISNULL(Col26, 0)
		  + ISNULL(Col27, 0)
		  + ISNULL(Col28, 0)
		  + ISNULL(Col29, 0)
		  + ISNULL(Col30, 0)
		  + ISNULL(Col31, 0)
		  + ISNULL(Col32, 0)
		  + ISNULL(Col33, 0)
		  + ISNULL(Col34, 0)
		  + ISNULL(Col35, 0)
		  + ISNULL(Col37, 0)
		  + ISNULL(Col38, 0)
		  + ISNULL(Col39, 0)
		  + ISNULL(Col40, 0)
		  + ISNULL(Col41, 0)
		  + ISNULL(Col42, 0)
		  + ISNULL(Col43, 0)    ---????????????????????????????
		  + ISNULL(Col36, 0)
		  + ISNULL(Col44, 0) 
		  + ISNULL(Col45, 0) 
		  + ISNULL(Col46, 0) 
		  + ISNULL(Col47, 0) 
		  + ISNULL(Col48, 0)  SumPayments,

			ISNULL(Col36, 0)
		  + ISNULL(Col44, 0) 
		  + ISNULL(Col45, 0) 
		  + ISNULL(Col46, 0) 
		  + ISNULL(Col47, 0) 
		  + ISNULL(Col49, 0) 
		  + ISNULL(Col50, 0) 
		  + ISNULL(Col51, 0) 
		  + ISNULL(Col52, 0) 
		  + ISNULL(Col53, 0) 
		  + ISNULL(Col54, 0) 
		  + ISNULL(Col55, 0) SumDeductions,

			ISNULL(Col15, 0)
		  + ISNULL(Col16, 0)
		  + ISNULL(Col17, 0)
		  + ISNULL(Col18, 0)
		  + ISNULL(Col19, 0)
		  + ISNULL(Col20, 0)
		  + ISNULL(Col21, 0)
		  + ISNULL(Col22, 0)
		  + ISNULL(Col23, 0)
		  + ISNULL(Col24, 0)
		  + ISNULL(Col25, 0)
		  + ISNULL(Col26, 0)
		  + ISNULL(Col27, 0)
		  + ISNULL(Col28, 0)
		  + ISNULL(Col29, 0)
		  + ISNULL(Col30, 0)
		  + ISNULL(Col31, 0)
		  + ISNULL(Col32, 0)
		  + ISNULL(Col33, 0)
		  + ISNULL(Col34, 0)
		  + ISNULL(Col35, 0)
		  + ISNULL(Col37, 0)
		  + ISNULL(Col38, 0)
		  + ISNULL(Col39, 0)
		  + ISNULL(Col40, 0)
		  + ISNULL(Col41, 0)
		  + ISNULL(Col42, 0)
		  + ISNULL(Col43, 0)    ---????????????????????????????
		  + ISNULL(Col36, 0)
		  + ISNULL(Col44, 0) 
		  + ISNULL(Col45, 0) 
		  + ISNULL(Col46, 0) 
		  + ISNULL(Col47, 0) 
		  + ISNULL(Col48, 0)
		  - ISNULL(Col36, 0)
		  - ISNULL(Col44, 0) 
		  - ISNULL(Col45, 0) 
		  - ISNULL(Col46, 0) 
		  - ISNULL(Col47, 0) 
		  - ISNULL(Col49, 0) 
		  - ISNULL(Col50, 0) 
		  - ISNULL(Col51, 0) 
		  - ISNULL(Col52, 0) 
		  - ISNULL(Col53, 0) 
		  - ISNULL(Col54, 0) 
		  - ISNULL(Col55, 0) AS [Sum],
			p.[Year],
			p.[Month]
        FROM [wag].[TreasuryRequestDetail] trd WITH (SNAPSHOT)
			INNER JOIN wag.payroll p ON p.ID = trd.payrollID
           -- INNER JOIN org._Department dep ON dep.id = p.organID
			--INNER JOIN pbl.BankAccount ba  ON ba.id = trd.BankAccountID
			--LEFT JOIN pbl.Bank b  ON b.id = ba.BankID
        WHERE (@RequestID = trd.RequestID)
			AND (@PayrollID IS NULL OR trd.PayrollID = @PayrollID)
			AND (@PayrollType < 1 OR p.PayrollType = @PayrollType)
			AND (@EmploymentType < 1 OR trd.[EmploymentType] = @EmploymentType)
			AND (@TreasuryEmploymentType < 1 OR trd.[TreasuryEmploymentType] = @TreasuryEmploymentType)
			AND (@SacrificialType < 1 OR trd.[SacrificialType] = @SacrificialType)
			AND(@NationalCode IS NULL OR trd.NationalCode = @NationalCode)
			AND	(@FirstName IS NULL OR trd.FirstName LIKE N'%'+@FirstName+'%')
			AND(@LastName IS NULL OR trd.LastName LIKE N'%'+@LastName+'%')
			AND(@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
		),
        Total AS 
		(
			SELECT COUNT(*) AS Total
            FROM Selects
            WHERE @GetTotalCount = 1
		)
		,MainSelect AS
		(
		SELECT [FirstName], 
               [LastName], 
			   [NationalCode],
			   Sum(SumPayments) SumPayments,
			   Sum(SumDeductions) SumDeductions,
			   Sum([Sum]) [SumSum]
        FROM Selects 
		GROUP BY [FirstName], 
                 [LastName], 
			     [NationalCode],
				 [Year],
				 [Month]
		)
        SELECT * 
		FROM MainSelect
            Total
        ORDER BY [NationalCode]
        OFFSET((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeleteTreasuryRequestError'))
	DROP PROCEDURE wag.spDeleteTreasuryRequestError
GO

CREATE PROCEDURE wag.spDeleteTreasuryRequestError
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID
				
	BEGIN TRY
		BEGIN TRAN
			
			DELETE FROM wag.TreasuryRequestError
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeleteTreasuryRequestErrors'))
	DROP PROCEDURE wag.spDeleteTreasuryRequestErrors
GO

CREATE PROCEDURE wag.spDeleteTreasuryRequestErrors
	@ARequestID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID
				
	BEGIN TRY
		BEGIN TRAN
			
			DELETE FROM wag.TreasuryRequestError
			WHERE RequestID = @RequestID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryRequestError') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryRequestError
GO

CREATE PROCEDURE wag.spGetTreasuryRequestError 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		[ID], [RequestID], [TreasuryRequestErrorType], [NationalCode], [ErrorText], [Description]
	FROM wag.TreasuryRequestError
	WHERE ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetTreasuryRequestErrors') IS NOT NULL
    DROP PROCEDURE wag.spGetTreasuryRequestErrors
GO

CREATE PROCEDURE wag.spGetTreasuryRequestErrors 
	@ARequestID UNIQUEIDENTIFIER,
	@ATreasuryRequestErrorType TINYINT,
	@ANationalCode VARCHAR(10),
	@ANationalCodes VARCHAR(max),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@TreasuryRequestErrorType TINYINT = COALESCE(@ATreasuryRequestErrorType, 0),
		@NationalCode VARCHAR(10) = TRIM(@ANationalCode),
		@NationalCodes VARCHAR(max) = TRIM(@ANationalCodes),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = TRIM(@ASortExp),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			TRE.[ID],
			TRE.[RequestID],
			TRE.[TreasuryRequestErrorType],
			TRE.[NationalCode],
			TRE.[ErrorText],
			TRE.[Description]
		FROM [wag].[TreasuryRequestError] TRE
		LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = TRE.[NationalCode]
		WHERE (@RequestID IS NULL OR TRE.[RequestID] = @RequestID)
			AND (@TreasuryRequestErrorType < 1 OR TRE.[TreasuryRequestErrorType] = @TreasuryRequestErrorType)
			AND (@NationalCode IS NULL OR TRE.[NationalCode] = @NationalCode)
			AND (@NationalCodes IS NULL OR NationalCodes.value = TRE.[NationalCode])
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [NationalCode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyListTreasuryRequestErrors') IS NOT NULL
    DROP PROCEDURE wag.spModifyListTreasuryRequestErrors
GO

CREATE PROCEDURE wag.spModifyListTreasuryRequestErrors
	@ADetails NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails))

	BEGIN TRY
		BEGIN TRAN
			; WITH CTE AS 
			(
				SELECT *
				FROM OPENJSON(@Details) 
				WITH
				(
					[RequestID] UNIQUEIDENTIFIER,
					[TreasuryRequestErrorType] TINYINT,
					[NationalCode] VARCHAR(10),
					[ErrorText] NVARCHAR(max),
					[Description] NVARCHAR(max)
				)
			)
			INSERT INTO wag.TreasuryRequestError
			([ID], [RequestID], [TreasuryRequestErrorType], [NationalCode], [ErrorText], [Description])
			SELECT 
			NEWID(),
			[RequestID],
			[TreasuryRequestErrorType],
			[NationalCode],
			[ErrorText],
			[Description]
			FROM CTE

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyTreasuryRequestError') IS NOT NULL
    DROP PROCEDURE wag.spModifyTreasuryRequestError
GO

CREATE PROCEDURE wag.spModifyTreasuryRequestError
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER,
	@ATreasuryRequestErrorType TINYINT,
	@ANationalCode VARCHAR(10),
	@AErrorText NVARCHAR(max),
	@ADescription NVARCHAR(max)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@TreasuryRequestErrorType TINYINT = COALESCE(@ATreasuryRequestErrorType, 0),
		@NationalCode VARCHAR(10) = TRIM(@ANationalCode),
		@ErrorText NVARCHAR(max) = TRIM(@AErrorText),
		@Description NVARCHAR(max) = TRIM(@ADescription)

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- Insert
			BEGIN
				INSERT INTO wag.TreasuryRequestError
				(ID, RequestID, TreasuryRequestErrorType, NationalCode, ErrorText, [Description])
				VALUES
				(@ID, @RequestID, @TreasuryRequestErrorType, @NationalCode, @ErrorText, @Description)
			END
			ELSE -- Update
			BEGIN 
				UPDATE wag.TreasuryRequestError
				SET 
					TreasuryRequestErrorType = @TreasuryRequestErrorType,
					NationalCode = @NationalCode,
					ErrorText = @ErrorText,
					[Description] = @Description
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeleteTreasuryRequestOrgan'))
	DROP PROCEDURE wag.spDeleteTreasuryRequestOrgan
GO

CREATE PROCEDURE wag.spDeleteTreasuryRequestOrgan
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID
				
	BEGIN TRY
		BEGIN TRAN

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetTreasuryRequestOrgan'))
	DROP PROCEDURE wag.spGetTreasuryRequestOrgan
GO

CREATE PROCEDURE wag.spGetTreasuryRequestOrgan
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		TreasuryRequestOrgan.[ID],
		TreasuryRequestOrgan.[RequestID],
		TreasuryRequestOrgan.[OrganID],
		Organ.[Name],
		Organ.Code
	FROM [wag].[TreasuryRequestOrgan] TreasuryRequestOrgan
		INNER JOIN [org].[Department] Organ ON Organ.ID = TreasuryRequestOrgan.OrganID
	WHERE TreasuryRequestOrgan.ID = @ID
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetTreasuryRequestOrgans'))
	DROP PROCEDURE wag.spGetTreasuryRequestOrgans
GO

CREATE PROCEDURE wag.spGetTreasuryRequestOrgans
	@AOrganID UNIQUEIDENTIFIER,
	@AOrganCodes VARCHAR(MAX),
	@ARequestID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@OrganCodes VARCHAR(MAX) = LTRIM(RTRIM(@AOrganCodes)),
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@ParentOrganNode HIERARCHYID

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT 
		TreasuryRequestOrgan.[ID],
		TreasuryRequestOrgan.[RequestID],
		BaseDocument.TrackingCode [RequestTrackingCode],
		TreasuryRequestOrgan.[OrganID],
		Organ.[Name] [OrganName],
		Organ.Code [OrganCode],
		Organ.[Node].ToString() [OrganNode]
	FROM [wag].[TreasuryRequestOrgan] TreasuryRequestOrgan
		INNER JOIN [org].[Department] Organ ON Organ.[ID] = TreasuryRequestOrgan.[OrganID]
		LEFT JOIN [pbl].[BaseDocument] BaseDocument on BaseDocument.[ID] = TreasuryRequestOrgan.[RequestID]
		LEFT JOIN OPENJSON(@OrganCodes) OrganCodes ON OrganCodes.value = Organ.Code
	WHERE 
		(@OrganID IS NULL OR TreasuryRequestOrgan.[OrganID] = @OrganID)
		AND (@RequestID IS NULL OR TreasuryRequestOrgan.[RequestID] = @RequestID)
		AND (@OrganCodes IS NULL OR OrganCodes.value = Organ.Code)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT 
		*
	FROM MainSelect, TempCount
	ORDER BY [OrganNode]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'wag.spModifyTreasuryRequestOrgan') AND type in (N'P', N'PC'))
DROP PROCEDURE wag.spModifyTreasuryRequestOrgan
GO

CREATE PROCEDURE wag.spModifyTreasuryRequestOrgan
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert 
			BEGIN
				INSERT INTO [wag].[TreasuryRequestOrgan]
					([ID], [RequestID], [OrganID])
				VALUES
					(@ID, @RequestID, @OrganID)
			END

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'wag.spModifyTreasuryRequestOrgans') AND type in (N'P', N'PC'))
DROP PROCEDURE wag.spModifyTreasuryRequestOrgans
GO

CREATE PROCEDURE wag.spModifyTreasuryRequestOrgans
	@ARequestID UNIQUEIDENTIFIER,
	@ADepartmentIDs NVARCHAR(MAX)

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@DepartmentIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ADepartmentIDs)),
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			INSERT INTO [wag].[TreasuryRequestOrgan]
				([ID], [RequestID], [OrganID])
			SELECT
				NEWID(),
				@RequestID,
				DepartmentIDs.VALUE [OrganID]
			FROM  OPENJSON(@DepartmentIDs) DepartmentIDs

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('rpt.spDeleteTreasuryRequestReport'))
	DROP PROCEDURE rpt.spDeleteTreasuryRequestReport
GO

CREATE PROCEDURE rpt.spDeleteTreasuryRequestReport
	@ARequestID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@APositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PositionID UNIQUEIDENTIFIER = @APositionID
				
	BEGIN TRY
		BEGIN TRAN
			UPDATE TreasuryRequestReport
			SET 
				[ReplacerUserID] = @UserID,
				[ReplacerPositionID] = @PositionID,
				[ReplacementDate] = GETDATE()
			FROM [Kama.Aro.Pardakht.Extention].[rpt].[TreasuryRequestReport] TreasuryRequestReport
			WHERE [RequestID] = @RequestID AND [ReplacementDate] IS NULL

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.Procedures WHERE [object_id] = OBJECT_ID('rpt.spGenerateTreasuryRequestReport'))
    DROP PROCEDURE rpt.spGenerateTreasuryRequestReport
GO

CREATE PROCEDURE rpt.spGenerateTreasuryRequestReport
	@ARequestID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@ParentOrganID UNIQUEIDENTIFIER,
		@Year SMALLINT = 0,
		@Month TINYINT = 0,
		@ParentOrganNode HIERARCHYID

	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)
	BEGIN TRY
		BEGIN TRAN

			;WITH Organ AS (
				SELECT
					Department.ID,
					Department.[Name],
					Department.[Node],
					Department.ParentID,
					Department.ParentName
				FROM org._Department Department
				INNER JOIN org.SuitableOrganForPardakht sofp ON sofp.OrganID = Department.ID
				WHERE (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
				AND (sofp.[Enabled] = 1)
			)
			, TreasuryRequest AS (
				SELECT
					TreasuryRequest.ID RequestID,
					TreasuryRequestOrgan.OrganID RequestOrganID,
					COUNT(TreasuryRequestOrgan.OrganID) OrganCount
				FROM wag.TreasuryRequest TreasuryRequest
					INNER JOIN wag.TreasuryRequestOrgan TreasuryRequestOrgan ON TreasuryRequestOrgan.RequestID = TreasuryRequest.ID
					INNER JOIN pbl.BaseDocument Document ON Document.ID = TreasuryRequest.ID
				WHERE (Document.RemoveDate IS NULL)
					AND (@RequestID IS NULL OR TreasuryRequest.ID = @RequestID)
					AND (@Month < 1 OR TreasuryRequest.[Month] = @Month)
					AND (@Year < 1 OR TreasuryRequest.[Year] = @Year)
				GROUP BY
					TreasuryRequest.ID,
					TreasuryRequestOrgan.OrganID
			)
			, PardakhtEmployees AS ( -- Total Employees Whom Have Pardakht Details
				SELECT DISTINCT
					TreasuryRequest.RequestID,
					Employee.ID EmployeeID 
				FROM  [wag].[PayrollEmployee] PayrollEmployee
				INNER JOIN [emp].[Employee] Employee ON Employee.ID = PayrollEmployee.EmployeeID
				INNER JOIN [emp].[EmployeeCatalog] EmployeeCatalog ON EmployeeCatalog.ID = Employee.EmployeeCatalogID
				INNER JOIN TreasuryRequest ON TreasuryRequest.RequestID = EmployeeCatalog.TreasuryRequestID
				INNER JOIN [emp].[EmployeeError] EmployeeError ON Employee.ID = EmployeeError.EmployeeID
				INNER JOIN [wag].[_Payroll] Payroll ON  Payroll.ID = PayrollEmployee.PayrollID
			)
			-- All Errors
			, TotalPardakhtEmployeePaknaConfilict AS ( -- Count All Employee Errors
				SELECT
					PardakhtEmployees.RequestID RequestID,
					COUNT(EmployeeError.ID) [PaknaEmployeeConfilictErrorCount]
				FROM PardakhtEmployees
					INNER JOIN [emp].[EmployeeError] EmployeeError ON PardakhtEmployees.EmployeeID = EmployeeError.EmployeeID
				GROUP BY PardakhtEmployees.RequestID
			)
			, TotalNotInPaknaBasketEmployeeError AS ( -- Count Employees That Not Suitable For Pardakht
				SELECT
					PardakhtEmployees.RequestID RequestID,
					COUNT(EmployeeError.EmployeeID) [NotSuitableForPardakhtEmployeeCount]
				FROM PardakhtEmployees 
					INNER JOIN [emp].[EmployeeError] EmployeeError ON PardakhtEmployees.EmployeeID = EmployeeError.EmployeeID
				WHERE EmployeeError.ErrorType < 100
				GROUP BY PardakhtEmployees.RequestID
			)
			, TotalPardakhtBasketEmployeeError AS ( -- Count Employee's information Confilicts
				SELECT
					PardakhtEmployees.RequestID RequestID,
					COUNT(EmployeeError.EmployeeID) [PaknaEmployeeErrorCount]
				FROM PardakhtEmployees 
					INNER JOIN [emp].[EmployeeError] EmployeeError ON PardakhtEmployees.EmployeeID = EmployeeError.EmployeeID
				WHERE EmployeeError.ErrorType > 100
				GROUP BY PardakhtEmployees.RequestID
			)
			-- Distincted Errors
			, TotalDistinctedEmployeeConfilict AS ( -- Count Employees Whom Have At Least One Confilict
				SELECT
					PardakhtEmployees.RequestID RequestID,
					COUNT(DISTINCT EmployeeError.EmployeeID) [TotalEmployeeErrorCount]
				FROM PardakhtEmployees 
					INNER JOIN [emp].[EmployeeError] EmployeeError ON PardakhtEmployees.EmployeeID = EmployeeError.EmployeeID
				GROUP BY PardakhtEmployees.RequestID
			)
			, CalculateEmployee AS ( -- Count Employees Whom Have At Least On Pardakht Detail
				SELECT
					PardakhtEmployees.RequestID RequestID,
					COUNT(DISTINCT PardakhtEmployees.EmployeeID) [PardakhtEmployeeCount]
				FROM  PardakhtEmployees
				GROUP BY PardakhtEmployees.RequestID
			)
			-- Select
			, AllDepartment AS (
				SELECT 
					Department.ID OrganID,
					Department.Name DepartmentName,
					TreasuryRequest.RequestID,
					COALESCE(TreasuryRequest.OrganCount, 0) RequestOrganCount,
					COALESCE(CalculateEmployee.PardakhtEmployeeCount, 0) EmployeesCount,
					COALESCE(TotalDistinctedEmployeeConfilict.TotalEmployeeErrorCount, 0) EmployeesHaveConfilictCount,
					COALESCE(TotalPardakhtEmployeePaknaConfilict.PaknaEmployeeConfilictErrorCount, 0) TotalConfilictCount,
					COALESCE(TotalNotInPaknaBasketEmployeeError.NotSuitableForPardakhtEmployeeCount, 0) TotalNotInPardakhtBasketConflictCount,
					COALESCE(TotalPardakhtBasketEmployeeError.PaknaEmployeeErrorCount, 0) TotalPardakhtBasketConflictCount,
					0 TotalPayrollConflictCount,
					0 TotalOtherConflictCount
				FROM Organ
				LEFT JOIN TreasuryRequest ON TreasuryRequest.RequestOrganID = Organ.ID
				LEFT JOIN [org].[Department] Department ON Department.ID = Organ.ID
				LEFT JOIN TotalPardakhtEmployeePaknaConfilict ON TotalPardakhtEmployeePaknaConfilict.RequestID = TreasuryRequest.RequestID
				LEFT JOIN TotalNotInPaknaBasketEmployeeError ON TotalNotInPaknaBasketEmployeeError.RequestID = TreasuryRequest.RequestID
				LEFT JOIN TotalPardakhtBasketEmployeeError ON TotalPardakhtBasketEmployeeError.RequestID = TreasuryRequest.RequestID
				LEFT JOIN TotalDistinctedEmployeeConfilict ON TotalDistinctedEmployeeConfilict.RequestID = TreasuryRequest.RequestID
				LEFT JOIN CalculateEmployee ON CalculateEmployee.RequestID = TreasuryRequest.RequestID
			)
			, GroupDepartment AS (
				SELECT
					@Month [Month],
					@Year [Year],
					SUM(CASE WHEN RequestOrganCount > 0 THEN 1 ELSE 0 END) [OrganWithRequest],
					SUM(CASE WHEN RequestOrganCount = 0 THEN 1 ELSE 0 END) [OrganWithoutRequest],
					SUM(EmployeesCount) EmployeesCount,
					SUM(EmployeesHaveConfilictCount) EmployeesHaveConfilictCount,
					SUM(TotalConfilictCount) TotalConfilictCount,
					SUM(TotalNotInPardakhtBasketConflictCount) TotalNotInPardakhtBasketConflictCount,
					SUM(TotalPardakhtBasketConflictCount) TotalPardakhtBasketConflictCount,
					0 TotalPayrollConflictCount,
					0 TotalOtherConflictCount
				FROM AllDepartment
				
			)
			INSERT INTO [Kama.Aro.Pardakht.Extention].[rpt].[TreasuryRequestReport]
			([ID], [RequestID], [OrganWithRequest],
			[OrganWithoutRequest], [EmployeesCount],
			[EmployeesHaveConfilictCount], [TotalConfilictCount],
			[TotalNotInPardakhtBasketConflictCount], [TotalPardakhtBasketConflictCount],
			[TotalPayrollConflictCount], [TotalOtherConflictCount], [CreationDate],
			[ReplacerUserID], [ReplacerPositionID], [ReplacementDate])
			SELECT 
				NEWID(),
				@RequestID [RequestID],
				GroupDepartment.[OrganWithRequest],
				GroupDepartment.[OrganWithoutRequest],
				GroupDepartment.EmployeesCount,
				GroupDepartment.EmployeesHaveConfilictCount,
				GroupDepartment.TotalConfilictCount,
				GroupDepartment.TotalNotInPardakhtBasketConflictCount,
				GroupDepartment.TotalPardakhtBasketConflictCount,
				GroupDepartment.TotalPayrollConflictCount,
				GroupDepartment.TotalOtherConflictCount,
				GETDATE() CreationDate,
				NULL,
				NULL,
				NULL
			FROM GroupDepartment
			LEFT JOIN Organ ON Organ.ID = @ParentOrganID

			UPDATE TreasuryRequest
			SET 
				[ReportState] = 100,
				[ReportUpdateDate] = GETDATE()
			FROM [wag].[TreasuryRequest]
			WHERE [ID] = @RequestID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW 
	END CATCH

    RETURN @@ROWCOUNT 
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.Procedures WHERE [object_id] = OBJECT_ID('rpt.spGenerateTreasuryRequestReportDetail'))
    DROP PROCEDURE rpt.spGenerateTreasuryRequestReportDetail
GO

CREATE PROCEDURE rpt.spGenerateTreasuryRequestReportDetail
	@ARequestID UNIQUEIDENTIFIER,
	@AReportID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@ReportID UNIQUEIDENTIFIER = @AReportID,
		@OrganID UNIQUEIDENTIFIER,
		@OrganIDs NVARCHAR(MAX),
		@ParentOrganID UNIQUEIDENTIFIER,
		@ParentOrganIDs NVARCHAR(MAX),
		@ParentOrganNode HIERARCHYID

	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)
	BEGIN TRY
		BEGIN TRAN
		-- Search
			; WITH Organ AS (
				SELECT
					Department.ID,
					Department.[Name],
					Department.[Node],
					Department.ParentID,
					Department.ParentName
				FROM [Kama.Aro.Organization].org._Organ Department
				INNER JOIN [Kama.Aro.Pardakht].org.SuitableOrganForPardakht SOFP ON SOFP.OrganID = Department.ID
				WHERE (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
					AND (SOFP.[Enabled] = 1)
			)
			, TreasuryRequest AS(
				SELECT DISTINCT
					TR.ID RequestID,
					TRO.OrganID OrganID
				FROM wag.TreasuryRequest TR
					INNER JOIN wag.TreasuryRequestOrgan TRO ON TRO.RequestID = TR.ID
					INNER JOIN Organ ON Organ.ID = TRO.OrganID
					INNER JOIN pbl.BaseDocument Document ON Document.ID = TR.ID
					INNER JOIN pbl.DocumentFlow Flow ON Flow.DocumentID = Document.ID  AND Flow.ActionDate IS NULL
				WHERE (Document.RemoveDate IS NULL AND CAST(COALESCE(Flow.ToDocState, 0) AS TINYINT) >= 40) -- Last Flow >= 40
					AND (@RequestID IS NULL OR TR.ID = @RequestID)
			)
			, Employees AS ( -- Total Pardakht Employees
				SELECT DISTINCT
					TreasuryRequest.RequestID,
					Employee.ID EmployeeID,
					Employee.NationalCode EmployeeNationalCode,
					Employee.OrganID EmployeeOrganID,
					Employee.EmployeeCatalogID EmployeeCatalogID,
					Employee.EmploymentType EmployeeEmploymentType
				FROM emp.Employee Employee
				INNER JOIN Organ ON Organ.ID = Employee.OrganID
				INNER JOIN emp.EmployeeCatalog EC ON EC.ID = Employee.EmployeeCatalogID
				INNER JOIN TreasuryRequest ON TreasuryRequest.RequestID = EC.TreasuryRequestID
			)
			, PardakhtEmployees AS ( -- Total PardakhtEmployees Whom Have Pardakht Details
				SELECT DISTINCT
					Employees.*
				FROM Employees
				INNER JOIN wag.PayrollEmployee PE ON PE.EmployeeID = Employees.EmployeeID
				INNER JOIN wag._Payroll Payroll ON  Payroll.ID = PE.PayrollID
				where PE.SumPayments <> 0 OR PE.SumDeductions <> 0 
			)
			, CalculateEmployee AS ( -- Calculate Pardakht Employees' Employment Type
				SELECT
					PardakhtEmployees.EmployeeOrganID,
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 1 THEN 1 ELSE 0 END) [Type1Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 2 THEN 1 ELSE 0 END) [Type2Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 3 THEN 1 ELSE 0 END) [Type3Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 6 THEN 1 ELSE 0 END) [Type6Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 10 THEN 1 ELSE 0 END) [Type10Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 11 THEN 1 ELSE 0 END) [Type11Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 12 THEN 1 ELSE 0 END) [Type12Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 13 THEN 1 ELSE 0 END) [Type13Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 14 THEN 1 ELSE 0 END) [Type14Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 15 THEN 1 ELSE 0 END) [Type15Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 16 THEN 1 ELSE 0 END) [Type16Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 18 THEN 1 ELSE 0 END) [Type18Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 19 THEN 1 ELSE 0 END) [Type19Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 21 THEN 1 ELSE 0 END) [Type21Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 22 THEN 1 ELSE 0 END) [Type22Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 23 THEN 1 ELSE 0 END) [Type23Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 24 THEN 1 ELSE 0 END) [Type24Count],
					SUM(CASE WHEN PardakhtEmployees.EmployeeEmploymentType = 100 THEN 1 ELSE 0 END) [Type100Count]
				FROM PardakhtEmployees
				Group BY 
					EmployeeOrganID
			)
			, EmployeePerOrgan AS ( -- Count Employee Per Organ
				SELECT
					Employees.EmployeeOrganID OrganID,
					COUNT(DISTINCT EmployeeID) EmployeeCount
				FROM Employees
				GROUP BY 
					Employees.EmployeeOrganID
			)
			, PayrollEmployeesPerOrgan AS ( -- Count Employees Whom Have At Least One Pardakht Details
				SELECT
					PardakhtEmployees.EmployeeOrganID OrganID,
					COUNT(DISTINCT PardakhtEmployees.EmployeeNationalCode) TreasuryRequestEmployeeCount
				FROM PardakhtEmployees
				GROUP BY EmployeeOrganID
			)
			, PaknaConfilictEmployeeError AS (
				SELECT
					PardakhtEmployees.*,
					EmployeeError.ID EmployeeErrorID,
					EmployeeError.ErrorType EmployeeErrorType
				FROM PardakhtEmployees
				LEFT JOIN [emp].[EmployeeError] EmployeeError ON EmployeeError.EmployeeID = PardakhtEmployees.EmployeeID
			)
			, TotalEmployeeErrorCount AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID OrganID,
					COUNT(PaknaConfilictEmployeeError.EmployeeErrorID) TotalEmployeeErrorCount
				FROM PaknaConfilictEmployeeError
				WHERE PaknaConfilictEmployeeError.EmployeeErrorType IS NOT NULL
				GROUP BY EmployeeOrganID
			)
			, ErrorPerOrgan AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID OrganID,
					COUNT(DISTINCT PaknaConfilictEmployeeError.EmployeeID) ErrorPerOrgan
				FROM PaknaConfilictEmployeeError
				WHERE PaknaConfilictEmployeeError.EmployeeErrorID IS NOT NULL
				GROUP BY PaknaConfilictEmployeeError.EmployeeOrganID
			)
			, TotalNotInBasketEmployeeErrors AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID,
					COUNT(PaknaConfilictEmployeeError.EmployeeID) TotalNotInBasketEmployee
				FROM PaknaConfilictEmployeeError
				WHERE EmployeeErrorType < 100
				GROUP BY PaknaConfilictEmployeeError.EmployeeOrganID
			)
			, TotalBasketConfilictEmployeeErrors AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID,
					COUNT(PaknaConfilictEmployeeError.EmployeeID) TotalBasketConfilictEmployee
				FROM PaknaConfilictEmployeeError
				WHERE EmployeeErrorType > 100
				GROUP BY EmployeeOrganID
			)
			, EmployeeNotInBasketEmployeeErrors AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID,
					COUNT(Distinct PaknaConfilictEmployeeError.EmployeeID) EmployeeNotInBasketEmployee
				FROM PaknaConfilictEmployeeError
				WHERE EmployeeErrorType < 100
				GROUP BY EmployeeOrganID
			)
			, EmployeeBasketConfilictEmployeeErrors AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeOrganID,
					COUNT(Distinct PaknaConfilictEmployeeError.EmployeeID) EmployeeBasketConfilictEmployee
				FROM PaknaConfilictEmployeeError
				WHERE EmployeeErrorType > 100
				GROUP BY  PaknaConfilictEmployeeError.EmployeeOrganID
			)
			, ErrorPerEmployee AS (
				SELECT
					PaknaConfilictEmployeeError.EmployeeID,
					PaknaConfilictEmployeeError.EmployeeOrganID,
					--PaknaConfilictEmployeeError.RequestID,
					COUNT(PaknaConfilictEmployeeError.EmployeeErrorType) ErrorPerEmployee
				FROM PaknaConfilictEmployeeError 
				GROUP BY
					PaknaConfilictEmployeeError.EmployeeID,
					PaknaConfilictEmployeeError.EmployeeOrganID
					--PaknaConfilictEmployeeError.RequestID
			)
			
			INSERT INTO [Kama.Aro.Pardakht.Extention].[rpt].[TreasuryRequestReportDetail]
			([ReportID], [RequestID], [OrganID], [EmployeeCatalogEmployeeCount], [PardakhtEmployeeCount],
			[EmployeeConflictByNationalCodeCount], [TotalEmployeeConflictCount], [Type1Count],
			[Type2Count], [Type3Count], [Type6Count], [Type10Count], [Type11Count], [Type12Count],
			[Type13Count], [Type14Count], [Type15Count], [Type16Count], [Type18Count], [Type19Count],
			[Type21Count], [Type22Count], [Type23Count], [Type24Count], [Type100Count],
			[TotalNotInPardakhtBasketConflictCount], [TotalPardakhtBasketConflictCount],
			[TotalPayrollConflictCount], [TotalOtherConflictCount], [ReadyForPaymentEmployeeCount],
			[EmployeesNotInPardakhtBasketCount], [EmployeesHaveOtherConflictCount], [EmployeesHaveMoreThanOneConflictCount])
			SELECT 
				@ReportID ReportID,
				TreasuryRequest.RequestID RequestID,
				Organ.iD OrganID,
				COALESCE(EmployeePerOrgan.EmployeeCount,0) EmployeeCatalogEmployeeCount,
				COALESCE(PayrollEmployeesPerOrgan.TreasuryRequestEmployeeCount,0) PardakhtEmployeeCount,
				COALESCE(ErrorPerOrgan.ErrorPerOrgan,0) EmployeeConflictByNationalCodeCount,
				COALESCE(TotalEmployeeErrorCount.TotalEmployeeErrorCount,0) TotalEmployeeConflictCount,
				COALESCE(CalculateEmployee.Type1Count, 0)Type1Count,
				COALESCE(CalculateEmployee.Type2Count, 0)Type2Count,
				COALESCE(CalculateEmployee.Type3Count, 0)Type3Count,
				COALESCE(CalculateEmployee.Type6Count, 0)Type6Count,
				COALESCE(CalculateEmployee.Type10Count, 0)Type10Count,
				COALESCE(CalculateEmployee.Type11Count, 0)Type11Count,
				COALESCE(CalculateEmployee.Type12Count, 0)Type12Count,
				COALESCE(CalculateEmployee.Type13Count, 0)Type13Count,
				COALESCE(CalculateEmployee.Type14Count, 0)Type14Count,
				COALESCE(CalculateEmployee.Type15Count, 0)Type15Count,
				COALESCE(CalculateEmployee.Type16Count, 0)Type16Count,
				COALESCE(CalculateEmployee.Type18Count, 0)Type18Count,
				COALESCE(CalculateEmployee.Type19Count, 0)Type19Count,
				COALESCE(CalculateEmployee.Type21Count, 0)Type21Count,
				COALESCE(CalculateEmployee.Type22Count, 0)Type22Count,
				COALESCE(CalculateEmployee.Type23Count, 0)Type23Count,
				COALESCE(CalculateEmployee.Type24Count, 0)Type24Count,
				COALESCE(CalculateEmployee.Type100Count, 0)Type100Count,
				COALESCE(TotalNotInBasketEmployeeErrors.TotalNotInBasketEmployee,0) TotalNotInPardakhtBasketConflictCount,
				COALESCE(TotalBasketConfilictEmployeeErrors.TotalBasketConfilictEmployee,0) TotalPardakhtBasketConflictCount,
				0 TotalPayrollConflictCount,
				0 TotalOtherConflictCount,
				COALESCE(PayrollEmployeesPerOrgan.TreasuryRequestEmployeeCount,0) ReadyForPaymentEmployeeCount,
				COALESCE(EmployeeNotInBasketEmployeeErrors.EmployeeNotInBasketEmployee,0) EmployeesNotInPardakhtBasketCount,
				0 EmployeesHaveOtherConflictCount,
				COALESCE(EmployeeBasketConfilictEmployeeErrors.EmployeeBasketConfilictEmployee,0) EmployeeBasketConfilictEmployee
			FROM TreasuryRequest
			LEFT JOIN Organ ON TreasuryRequest.OrganID = Organ.ID
			LEFT JOIN EmployeePerOrgan ON EmployeePerOrgan.OrganID = Organ.ID
			LEFT JOIN PayrollEmployeesPerOrgan ON PayrollEmployeesPerOrgan.OrganID= Organ.ID
			LEFT JOIN ErrorPerOrgan ON ErrorPerOrgan.OrganID = Organ.ID
			LEFT JOIN TotalEmployeeErrorCount ON TotalEmployeeErrorCount.OrganID = Organ.ID
			LEFT JOIN TotalNotInBasketEmployeeErrors ON TotalNotInBasketEmployeeErrors.EmployeeOrganID = Organ.ID
			LEFT JOIN TotalBasketConfilictEmployeeErrors ON TotalBasketConfilictEmployeeErrors.EmployeeOrganID = Organ.ID
			LEFT JOIN EmployeeNotInBasketEmployeeErrors ON EmployeeNotInBasketEmployeeErrors.EmployeeOrganID = Organ.ID
			LEFT JOIN EmployeeBasketConfilictEmployeeErrors ON EmployeeBasketConfilictEmployeeErrors.EmployeeOrganID = Organ.ID
			LEFT JOIN CalculateEmployee ON CalculateEmployee.EmployeeOrganID = Organ.ID

			UPDATE TreasuryRequest
			SET 
				[ReportState] = 100,
				[ReportUpdateDate] = GETDATE()
			FROM [wag].[TreasuryRequest]
			WHERE [ID] = @RequestID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW 
	END CATCH

    RETURN @@ROWCOUNT 
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spGetLastValidTreasuryRequestReports') IS NOT NULL
    DROP PROCEDURE rpt.spGetLastValidTreasuryRequestReports
GO

CREATE PROCEDURE rpt.spGetLastValidTreasuryRequestReports
	@ARequestID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID

		
	;WITH Organ AS
	(
		SELECT DISTINCT 
			Department.ID,
			Department.[Name],
			Department.ParentID,
			Department.ParentName
		FROM org._Department Department
	)
	, MainSelect AS
	(
		SELECT TOP(1)
			Report.[ID],
			Report.[RequestID],
			Organ.[ID] OrganID,
			Organ.[Name] OrganName,
			Organ.[ParentID] ParentOrganID,
			Organ.[ParentName] ParentOrganName,
			Report.[OrganWithRequest],
			Report.[OrganWithoutRequest],
			Report.[EmployeesCount],
			Report.[EmployeesHaveConfilictCount],
			Report.[TotalConfilictCount],
			Report.[TotalNotInPardakhtBasketConflictCount],
			Report.[TotalPardakhtBasketConflictCount],
			Report.[TotalPayrollConflictCount],
			Report.[TotalOtherConflictCount],
			Report.[ReplacerUserID],
			Report.[ReplacerPositionID],
			Report.[ReplacementDate]
		FROM [Kama.Aro.Pardakht.Extention].[rpt].[TreasuryRequestReport] Report
		INNER JOIN [wag].[TreasuryRequest] TreasuryRequest ON TreasuryRequest.ID = Report.[RequestID]
		INNER JOIN [wag].[TreasuryRequestOrgan] TreasuryRequestOrgan ON TreasuryRequestOrgan.RequestID = TreasuryRequest.ID
		INNER JOIN [org].[_Department] Organ ON Organ.ID = TreasuryRequest.OrganID
		WHERE (@RequestID IS NULL OR Report.[RequestID] = @RequestID AND [ReplacementDate] IS NULL)
	)
	SELECT * FROM MainSelect
	ORDER BY [ReplacementDate] ASC
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spGetTreasuryRequestReports') IS NOT NULL
    DROP PROCEDURE rpt.spGetTreasuryRequestReport
GO

CREATE PROCEDURE rpt.spGetTreasuryRequestReport
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

		
	;WITH Organ AS
	(
		SELECT DISTINCT 
			Department.ID,
			Department.[Name],
			Department.ParentID,
			Department.ParentName
		FROM org._Department Department
	)
	, MainSelect AS
	(
		SELECT
			Report.[ID],
			Report.[RequestID] RequestID,
			Organ.[ID] RequestOrganID,
			Organ.[Name] RequestOrganName,
			TreasuryRequest.[Month] RequestMonth,
			TreasuryRequest.[Year] RequestYear,
			Report.[OrganWithRequest],
			Report.[OrganWithoutRequest],
			Report.[EmployeesCount],
			Report.[EmployeesHaveConfilictCount],
			Report.[TotalConfilictCount],
			Report.[TotalNotInPardakhtBasketConflictCount],
			Report.[TotalPardakhtBasketConflictCount],
			Report.[TotalPayrollConflictCount],
			Report.[TotalOtherConflictCount],
			Report.[ReplacerUserID],
			Report.[ReplacerPositionID],
			Report.[ReplacementDate]
		FROM [Kama.Aro.Pardakht.Extention].[rpt].[TreasuryRequestReport] Report
		INNER JOIN [wag].[TreasuryRequest] TreasuryRequest ON TreasuryRequest.ID = Report.[RequestID]
		INNER JOIN [wag].[TreasuryRequestOrgan] TreasuryRequestOrgan ON TreasuryRequestOrgan.RequestID = TreasuryRequest.ID
		INNER JOIN [org].[_Department] Organ ON Organ.ID = TreasuryRequest.OrganID
		WHERE (Report.[ID] = @ID)
	)
	SELECT * FROM MainSelect
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spGetTreasuryRequestReportDetails') IS NOT NULL
    DROP PROCEDURE rpt.spGetTreasuryRequestReportDetails
GO

CREATE PROCEDURE rpt.spGetTreasuryRequestReportDetails 
	@AReportID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER,

	@AOrganID UNIQUEIDENTIFIER,
	@AOrganIDs NVARCHAR(MAX),
	@AParentOrganID UNIQUEIDENTIFIER,
	@AParentOrganIDs NVARCHAR(MAX),

	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@ReportID UNIQUEIDENTIFIER = @AReportID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,

		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@OrganIDs NVARCHAR(MAX) = LTRIM(RTRIM(@AOrganIDs)),
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@ParentOrganIDs NVARCHAR(MAX) = LTRIM(RTRIM(@AParentOrganIDs)),
		
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)
	;WITH Organ AS
	(
		SELECT DISTINCT 
			Department.ID,
			Department.[Name],
			Department.ParentID,
			Department.ParentName
		FROM org._Department Department
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Department.ID
		WHERE (@OrganID IS NULL OR Department.ID = @OrganID)
			AND (@OrganIDs IS NULL OR OrganIDs.value = Department.ID)
			AND (@ParentOrganID IS NULL OR [Node].IsDescendantOf(@ParentOrganNode) = 1)
	)
	, MainSelect AS
	(
		SELECT DISTINCT
			Report.[ReportID],
			Report.[RequestID],
			Organ.[ID] OrganID,
			Organ.[Name] OrganName,
			Organ.[ParentID] ParentOrganID,
			Organ.[ParentName] ParentOrganName,
			Organ.[Node].ToString() OrganNode,
			CAST(1 AS BIT) HasRequest,
			Report.[EmployeeCatalogEmployeeCount],
			Report.[PardakhtEmployeeCount],
			Report.[EmployeeConflictByNationalCodeCount], 
			Report.[TotalEmployeeConflictCount], 
			Report.[Type1Count], 
			Report.[Type2Count], 
			Report.[Type3Count], 
			Report.[Type6Count], 
			Report.[Type10Count], 
			Report.[Type11Count], 
			Report.[Type12Count], 
			Report.[Type13Count], 
			Report.[Type14Count], 
			Report.[Type15Count], 
			Report.[Type16Count], 
			Report.[Type18Count], 
			Report.[Type19Count], 
			Report.[Type21Count], 
			Report.[Type22Count], 
			Report.[Type23Count], 
			Report.[Type24Count], 
			Report.[Type100Count],
			Report.[TotalNotInPardakhtBasketConflictCount], 
			Report.[TotalPardakhtBasketConflictCount], 
			Report.[TotalPayrollConflictCount], 
			Report.[TotalOtherConflictCount], 
			Report.[ReadyForPaymentEmployeeCount], 
			Report.[EmployeesNotInPardakhtBasketCount], 
			Report.[EmployeesHaveOtherConflictCount], 
			Report.[EmployeesHaveMoreThanOneConflictCount]
		FROM [Kama.Aro.Pardakht.Extention].[rpt].[TreasuryRequestReportDetail] Report
		INNER JOIN [wag].[TreasuryRequest] TreasuryRequest ON TreasuryRequest.ID = Report.[RequestID]
		INNER JOIN [wag].[TreasuryRequestOrgan] TreasuryRequestOrgan ON TreasuryRequestOrgan.RequestID = TreasuryRequest.ID
		INNER JOIN [org].[_Department] Organ ON Organ.ID = Report.OrganID
		WHERE (Report.[ReportID] = @AReportID)
	)
	SELECT * FROM MainSelect
	ORDER BY OrganNode ASC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('rpt.spGetTreasuryRequestReports') IS NOT NULL
    DROP PROCEDURE rpt.spGetTreasuryRequestReports
GO

CREATE PROCEDURE rpt.spGetTreasuryRequestReports
	@ARequestID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)), 
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	;WITH Organ AS
	(
		SELECT DISTINCT 
			Department.ID,
			Department.[Name],
			Department.ParentID,
			Department.ParentName
		FROM org._Department Department
	)
	, MainSelect AS
	(
		SELECT DISTINCT
			Report.[ID],
			Report.[RequestID],
			Organ.[ID] OrganID,
			Organ.[Name] OrganName,
			Organ.[ParentID] ParentOrganID,
			Organ.[ParentName] ParentOrganName,
			Report.[OrganWithRequest],
			Report.[OrganWithoutRequest],
			Report.[EmployeesCount],
			Report.[EmployeesHaveConfilictCount],
			Report.[TotalConfilictCount],
			Report.[TotalNotInPardakhtBasketConflictCount],
			Report.[TotalPardakhtBasketConflictCount],
			Report.[TotalPayrollConflictCount],
			Report.[TotalOtherConflictCount],
			Report.[CreationDate],
			Report.[ReplacerUserID],
			Report.[ReplacerPositionID],
			Report.[ReplacementDate]
		FROM [Kama.Aro.Pardakht.Extention].[rpt].[TreasuryRequestReport] Report
		INNER JOIN [wag].[TreasuryRequest] TreasuryRequest ON TreasuryRequest.ID = Report.[RequestID]
		INNER JOIN [wag].[TreasuryRequestOrgan] TreasuryRequestOrgan ON TreasuryRequestOrgan.RequestID = TreasuryRequest.ID
		INNER JOIN [org].[_Department] Organ ON Organ.ID = TreasuryRequest.OrganID
		WHERE (@RequestID IS NULL OR TreasuryRequest.[ID] = @RequestID)
	)
	SELECT * FROM MainSelect
	ORDER BY [CreationDate] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.Procedures WHERE [object_id] = OBJECT_ID('wag.spCreatePayrollEmployees'))
    DROP PROCEDURE wag.spCreatePayrollEmployees
GO

CREATE PROCEDURE wag.spCreatePayrollEmployees  
	@APayrollID UNIQUEIDENTIFIER,
	@AEmployees NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@Employees NVARCHAR(MAX) = LTRIM(RTRIM(@AEmployees))

	BEGIN TRY
		BEGIN TRAN

			IF @Employees IS NOT NULL
			BEGIN

				SELECT ID INTO  #PayrollEmployeeIDs FROM wag.PayrollEmployee WHERE PayrollID = @PayrollID
				DELETE FROM wag.PayrollEmployeeDetail WHERE ID IN(SELECT ID FROM #PayrollEmployeeIDs)
				DELETE FROM wag.PayrollEmployee WHERE PayrollID = @PayrollID
				

				SELECT 
					tblJson.ID,
					@PayrollID PayrollID,
					tblJson.EmployeeID,
					tblJson.BankAccountID,
					tblJson.PostLevel,
					tblJson.ServiceYears,
					tblJson.ServiceYearsType,
					tblJson.EducationDegree,
					tblJson.EmploymentType ,
					tblJson.JobBase,
					tblJson.Salary,
					tblJson.Continuous,
					tblJson.NonContinuous,
					tblJson.Reward,
					tblJson.Welfare,
					tblJson.Other,
					tblJson.Deductions,
					tblJson.SumHokm,
					tblJson.SumNHokm,
					tblJson.SumPayments, 
					tblJson.SumDeductions, 
					tblJson.[Sum],
					tblJson.DayCount,
					tblJson.IntBudgetCode,
					tblJson.BytePlaceFinancing
					INTO #PayrollEmployee
				FROM OPENJSON(@Employees)
				WITH
				(
				    ID UNIQUEIDENTIFIER,
					EmployeeID UNIQUEIDENTIFIER,
				    BankAccountID UNIQUEIDENTIFIER,
					PostLevel TINYINT,
					ServiceYears INT,
					ServiceYearsType TINYINT,
					EducationDegree TINYINT,
					EmploymentType  TINYINT,
					JobBase TINYINT,
					Salary BIGINT,
					Continuous BIGINT,
					NonContinuous BIGINT,
					Reward BIGINT,
					Welfare BIGINT,
					Other BIGINT,
					Deductions BIGINT,
					SumHokm BIGINT,
					SumNHokm BIGINT,
					SumPayments BIGINT, 
					SumDeductions BIGINT, 
					[Sum] BIGINT,
					DayCount SMALLINT,
					IntBudgetCode INT,
					BytePlaceFinancing TINYINT

				) tblJson

				INSERT INTO [wag].[PayrollEmployee]
						   ([ID]
						   ,[PayrollID]
						   ,[EmployeeID]
						   ,[SumPayments]
						   ,[SumDeductions]
						   ,[SumHokm]
						   ,[BankAccountID])
					SELECT 
							pe.ID,
							@PayrollID PayrollID,
							pe.EmployeeID,
							pe.SumPayments, 
							pe.SumDeductions,
							null,
							pe.BankAccountID
					FROM #PayrollEmployee pe

                INSERT INTO [wag].[PayrollEmployeeDetail]
                            ([ID]
                            ,[Salary]
                            ,[Continuous]
                            ,[NonContinuous]
                            ,[Reward]
                            ,[Welfare]
                            ,[Other]
                            ,[Deductions]
                            ,[SumNHokm]
                            ,[PostID]
                            ,[DayCount]
                            ,[BudgetCode]
                            ,[PlaceFinancing])

                      SELECT [ID]
                            ,[Salary]
                            ,[Continuous]
                            ,[NonContinuous]
                            ,[Reward]
                            ,[Welfare]
                            ,[Other]
                            ,[Deductions]
                            ,[SumNHokm]
                            ,null
                            ,[DayCount]
                            ,IntBudgetCode
                            ,BytePlaceFinancing
                      FROM #PayrollEmployee pe
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeleteOldPayroll') IS NOT NULL
    DROP PROCEDURE wag.spDeleteOldPayroll
GO

CREATE PROCEDURE wag.spDeleteOldPayroll  
	@AID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@APayrollType TINYINT,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = @AYear,
		@Month TINYINT = ISNULL(@AMonth, 0),
		@PayrollType TINYINT = COALESCE(@APayrollType, 0),
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@OldPayrollID UNIQUEIDENTIFIER
	--BEGIN TRY
	--	BEGIN TRAN

			BEGIN
				
				SET @OldPayrollID = 
						(SELECT Payroll.ID
						FROM wag._Payroll Payroll
							inner join pbl.BaseDocument doc ON doc.ID = Payroll.ID
						WHERE Payroll.ID <> @ID
							AND Payroll.RequestID = @RequestID 
							AND LawID = @LawID 
							AND [Year] = @Year 
							AND [Month] = @Month
							AND PayrollType = @PayrollType
						)
				
				-- delete old payrolls
				Update pbl.BaseDocument 
				SET RemoverUserID = @CurrentUserID,
					[RemoverPositionID] = @CurrentUserPositionID,
					RemoveDate = GETDATE()
				WHERE ID = @OldPayrollID

				DELETE FROM wag.TreasuryRequestDetail WITH(SNAPSHOT) WHERE PayrollID=@OldPayrollID
				DELETE FROM wag.PayrollDetail 
				WHERE PayrollEmployeeID IN(
				SELECT ID FROM wag.PayrollEmployee WHERE PayrollID = @OldPayrollID)
				DELETE FROM tmp.PayrollDetail
				WHERE PayrollEmployeeID IN(
				SELECT ID FROM wag.PayrollEmployee WHERE PayrollID = @OldPayrollID)
				
			END

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeletePayroll') IS NOT NULL
    DROP PROCEDURE wag.spDeletePayroll
GO

CREATE PROCEDURE wag.spDeletePayroll  
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@DocState TINYINT,
		@ToPositionID UNIQUEIDENTIFIER

	SELECT @DocState = ToDocState 
		, @ToPositionID = ToPositionID
	FROM pbl.DocumentFlow WHERE DocumentID = @ID AND ActionDate IS NULL

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE pbl.BaseDocument 
			SET RemoverUserID = @CurrentUserID, 
				RemoverPositionID = @CurrentUserPositionID, 
				RemoveDate = GETDATE() 
			WHERE ID = @ID

			DELETE wag.PayrollDetail 
			FROM wag.PayrollDetail AS pd
			INNER JOIN wag.PayrollEmployee AS pe ON pd.PayrollEmployeeID = pe.ID
			WHERE pe.PayrollID = @ID

			DELETE tmp.PayrollDetail 
			FROM tmp.PayrollDetail AS tmpd
			INNER JOIN wag.PayrollEmployee AS pe ON tmpd.PayrollEmployeeID = pe.ID
			WHERE pe.PayrollID = @ID

			DELETE wag.PayrollEmployeeDetail
			FROM wag.PayrollEmployeeDetail
			INNER JOIN wag.PayrollEmployee AS pe ON PayrollEmployeeDetail.ID = pe.ID
			WHERE pe.PayrollID = @ID

			DELETE wag.PayrollEmployee 
			WHERE PayrollID = @ID

			DELETE wag.PayrollWageTitle 
			WHERE PayrollID = @ID

			DELETE wag.TreasuryRequestDetail WITH (SNAPSHOT) 
			WHERE PayrollID = @ID
			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeletePayrollAttachments') IS NOT NULL
    DROP PROCEDURE wag.spDeletePayrollAttachments
GO

CREATE PROCEDURE wag.spDeletePayrollAttachments  
	@AParentID UNIQUEIDENTIFIER,
	@AType TINYINT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Type TINYINT = COALESCE(@AType, 0)

	BEGIN TRY
		DELETE FROM [pbl].[Attachment]
			WHERE [ParentID] = @ParentID 
				AND (@Type < 1 OR [Type] = @Type)
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetAllPayrolls') IS NOT NULL
    DROP PROCEDURE wag.spGetAllPayrolls
GO

CREATE PROCEDURE wag.spGetAllPayrolls
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0)

	;WITH MainSelect AS
	(
		SELECT 
			Payroll.ID,
			Payroll.OrganID,
			org.Name OrganName,
			org.Type DepartmentType,
			org.SubType DepartmentSubType,
			org.OrganType,
			Payroll.LawID,
			Law.Name LawName,
			Payroll.Year,
			Payroll.Month,
			Payroll.Minimum,
			Payroll.Maximum,
			Payroll.Average,
			Payroll.EmployeesCount,
			Payroll.SalaryUpdateDate,
			FirstFlow.Date CreationDate,
			CASE WHEN LastFlow.ToDocState = 100 THEN LastFlow.Date ELSE NULL END ConfirmDate,
			LastFlow.ToDocState LastDocState,
			LastFlow.ToPositionID
		FROM wag.Payroll
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN pbl.DocumentFlow FirstFlow ON FirstFlow.DocumentID = Payroll.ID AND FirstFlow.FromDocState = 1 AND FirstFlow.ToDocState = 1
			INNER JOIN pbl.DocumentFlow LastFlow ON LastFlow.DocumentID = Payroll.ID AND LastFlow.ActionDate IS NULL
			INNER JOIN org.Department org ON org.ID = payroll.OrganID
			INNER JOIN law.Law ON law.ID = payroll.LawID
		WHERE 
			Payroll.OrganID = @OrganID
			AND Payroll.LawID = @LawID
			AND [Year] = @Year
			AND [Month] = @Month
	)
	SELECT * FROM MainSelect

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetDeletedPayrolls') IS NOT NULL
    DROP PROCEDURE wag.spGetDeletedPayrolls
GO

CREATE PROCEDURE wag.spGetDeletedPayrolls
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@UserID UNIQUEIDENTIFIER 

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH AllPayrolls AS
	(
		SELECT 
		Payroll.[ID],
		Payroll.[OrganID],
		Department.[Name] OrganName,
		Payroll.[LawID],
		Law.[Name] LawName,
		Payroll.[PayrollType],
		Payroll.[RequestID],

		FirstFlow.[Date] CreationDate,
		FirstFlow.[FromPositionID] CreatorPositionID,
		FirstFlow.[FromUserID] CreatorUserID,
		CreatorPosition.[FirstName] + ' ' + CreatorPosition.[LastName] CreatorUserName,

		BaseDocument.[RemoveDate],
		BaseDocument.[RemoverUserID],
		BaseDocument.[RemoverPositionID],
		RemoverPosition.[FirstName] + ' ' + RemoverPosition.[LastName] RemoverUserName

	FROM wag.Payroll
		INNER JOIN pbl.BaseDocument BaseDocument ON BaseDocument.[ID] = Payroll.[ID]
		INNER JOIN pbl.DocumentFlow FirstFlow ON FirstFlow.[DocumentID] = Payroll.[ID] AND FirstFlow.[FromDocState] = 1 AND FirstFlow.[ToDocState] = 1
		INNER JOIN org.Department Department ON Department.[ID] = payroll.[OrganID]
		INNER JOIN law.Law Law ON Law.[ID] = payroll.[LawID]
		LEFT JOIN org._position CreatorPosition ON CreatorPosition.[ID] = FirstFlow.[FromPositionID]
		LEFT JOIN org._position RemoverPosition ON RemoverPosition.[ID] = BaseDocument.[RemoverPositionID]
	)

	, MainSelect AS
	(
		SELECT 
			Payroll.[ID],
			Payroll.[OrganID],
			Payroll.[OrganName],
			Payroll.[LawID],
			Payroll.[LawName],
			Payroll.[PayrollType],

			Payroll.[CreationDate],
			Payroll.[CreatorPositionID],
			Payroll.[CreatorUserID],
			Payroll.[CreatorUserName],

			Payroll.[RemoveDate],
			Payroll.[RemoverUserID],
			Payroll.[RemoverPositionID],
			Payroll.[RemoverUserName]

		FROM AllPayrolls Payroll
			LEFT JOIN org._Department Department ON Department.ID = Payroll.OrganID
		WHERE 
			(@OrganID IS NULL OR Payroll.[OrganID] = @OrganID)
			AND (@LawID IS NULL OR Payroll.[LawID] = @LawID)
			AND (@RequestID IS NULL OR Payroll.[RequestID] = @RequestID)

			
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [CreationDate] DESC, [RemoveDate] DESC, OrganName ASC, [LawName] ASC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetNextPayrollToProcess') IS NOT NULL
    DROP PROCEDURE wag.spGetNextPayrollToProcess
GO

CREATE PROCEDURE wag.spGetNextPayrollToProcess
	@AGetLargeFiles BIT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	DECLARE 
		@GetLargeFiles BIT = COALESCE(@AGetLargeFiles, 1)

	BEGIN TRANSACTION 

		SELECT TOP 1 Payroll.ID
		FROM wag._Payroll Payroll WITH (TABLOCKX)
			LEFT JOIN wag._Payroll Payroll2 ON Payroll.RequestID = Payroll2.RequestID AND Payroll2.State = 20
		WHERE 
			Payroll.[State] = 1
			AND payroll2.Id IS NULL
			--AND (@GetLargeFiles <> 0 OR Attachment.FileSize < 1024)
			--AND (@GetLargeFiles <> 1 OR Attachment.FileSize >= 1024)
		ORDER BY Payroll.CreationDate

	COMMIT TRANSACTION

END 


GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayroll') IS NOT NULL
    DROP PROCEDURE wag.spGetPayroll
GO

CREATE PROCEDURE wag.spGetPayroll
	@AID UNIQUEIDENTIFIER,
	@AUserPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@UserPositionID UNIQUEIDENTIFIER = @AUserPositionID

	SELECT 
		Payroll.ID,
		Payroll.OrganID,
		Payroll.OrganName,
		Payroll.LawID,
		Payroll.LawName,
		Payroll.[Year],
		Payroll.[Month],
		Payroll.RequestID,
		Payroll.Minimum,
		Payroll.Maximum,
		Payroll.Average,
		Payroll.EmployeesCount,
		Payroll.LastState LastDocState,
		Payroll.PayrollType,
		Payroll.TreasuryPayment,
		Payroll.DepartmentBudgetID,
		Payroll.DepartmentSubType,
		Payroll.DepartmentType,
		Payroll.[State],
		Payroll.PlaceFinancing,
		CAST(CASE WHEN Payroll.ToPositionID = @UserPositionID THEN 1 ELSE 0 END AS TINYINT) ActionState,
		ToPosition.[Type] ToPositionType,
		ToPosition.FirstName + ' ' + ToPosition.LastName ToUserName,
		ToPosition.DepartmentName ToOrganName
	FROM wag._Payroll Payroll
		LEFT JOIN org._position ToPosition ON ToPosition.ID = Payroll.ToPositionID
	WHERE payroll.ID = @ID

END 

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollForProcess') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollForProcess
GO

CREATE PROCEDURE wag.spGetPayrollForProcess
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		Payroll.ID,
		Payroll.OrganID,
		Payroll.OrganName,
		Payroll.LawID,
		Payroll.LawName,
		Payroll.[Year],
		Payroll.[Month],
		Payroll.RequestID,
		Payroll.LastState LastDocState,
		Payroll.PayrollType,
		Payroll.TreasuryPayment,
		Payroll.DepartmentBudgetID,
		Payroll.DepartmentSubType,
		Payroll.DepartmentType,
		Payroll.[State] PayrollState,
		Payroll.PlaceFinancing,
		Payroll.PositionSubTypeID
	FROM wag._Payroll Payroll
	WHERE payroll.ID = @ID

END 

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollForValidateRemove') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollForValidateRemove
GO

CREATE PROCEDURE wag.spGetPayrollForValidateRemove  
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT  ToDocState  LastDocState 
		   ,DocumentFlow.ToPositionID
		   ,ToPosition.[Type] ToPositionType
	FROM pbl.DocumentFlow 
	INNER JOIN  wag._Payroll Payroll ON Payroll.ID=DocumentID
	LEFT JOIN org._position ToPosition ON ToPosition.ID = Payroll.ToPositionID
	WHERE DocumentID = @ID AND ActionDate IS NULL
	
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollIDs') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollIDs
GO

CREATE PROCEDURE wag.spGetPayrollIDs  
	@AOrganIDs NVARCHAR(MAX),
	@ALawIDs NVARCHAR(MAX),
	@AYears NVARCHAR(MAX),
	@AMonths NVARCHAR(MAX),
	@ALastDocState TINYINT,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@LawIDs NVARCHAR(MAX) = @ALawIDs,
		@Years NVARCHAR(MAX) = @AYears,
		@Months NVARCHAR(MAX) = @AMonths,
		@LastDocState TINYINT = COALESCE(@ALastDocState, 0),
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
		@UserID UNIQUEIDENTIFIER 

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT 
		Payroll.ID
	FROM wag.Payroll
		INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
		LEFT JOIN pbl.DocumentFlow lastFlow ON lastFlow.DocumentID = Payroll.ID AND lastFlow.ActionDate IS NULL
		LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Payroll.OrganID
		LEFT JOIN OPENJSON(@LawIDs) LawIDs ON LawIDs.value = Payroll.LawID
		LEFT JOIN OPENJSON(@Years) Years ON Years.value = Payroll.Year
		LEFT JOIN OPENJSON(@Months) Months ON Months.value = Payroll.Month
	WHERE doc.RemoveDate IS NULL
		AND (lastFlow.ToDocState = 100)
		AND (@OrganIDs IS NULL OR OrganIDs.value = Payroll.OrganID)
		AND (@LawIDs IS NULL OR LawIDs.value = Payroll.LawID)
		AND (@Years IS NULL OR Years.value = Payroll.Year)
		AND (@Months IS NULL OR Months.value = Payroll.Month)

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollMonths') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollMonths
GO

CREATE PROCEDURE wag.spGetPayrollMonths
	@AOrganIDs NVARCHAR(MAX),
	@ALawIDs NVARCHAR(MAX),
	@AYears NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@LawIDs NVARCHAR(MAX) = @ALawIDs,
		@Years NVARCHAR(MAX) = @AYears

	;WITH Payroll AS
	(
		SELECT 
			DISTINCT Month
		FROM wag._Payroll Payroll
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Payroll.OrganID
			LEFT JOIN OPENJSON(@LawIDs) LawIDs ON LawIDs.value = Payroll.LawID
			LEFT JOIN OPENJSON(@Years) Years ON Years.value = Payroll.[Year]
		WHERE LastState = 100
			AND (@OrganIDs IS NULL OR OrganIDs.value = Payroll.OrganID)
			AND (@LawIDs IS NULL OR LawIDs.value = Payroll.LawID)
			AND (@Years IS NULL OR Years.value = Payroll.[Year])
	)
	SELECT 
		DISTINCT Payroll.Month
	FROM Payroll
	ORDER BY [Month] 

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrolls') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrolls
GO

CREATE PROCEDURE wag.spGetPayrolls
	@AOrganID UNIQUEIDENTIFIER,
	@AMainOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@ALastDocState TINYINT,
	@AType TINYINT,
	@ASubType TINYINT,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AFromEmployeesCount INT,
	@AToEmployeesCount INT,
	@AFromMinimum INT,
	@AToMinimum INT,
	@AFromMaximum INT,
	@AToMaximum INT,
	@AFromAverage INT,
	@AToAverage INT,
	@AFromCreationDate DATETIME,
	@AToCreationDate DATETIME,
	@AFromConfirmDate DATETIME,
	@AToConfirmDate DATETIME,
	@APayrollType TINYINT,
	@ATreasuryPayment TINYINT,
	@ARequestID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@MainOrganID UNIQUEIDENTIFIER = @AMainOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@LastDocState TINYINT = COALESCE(@ALastDocState, 0),
		@Type TINYINT = COALESCE(@AType, 0),
		@SubType TINYINT = COALESCE(@ASubType, 0),
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@FromEmployeesCount INT = COALESCE(@AFromEmployeesCount,0),
		@ToEmployeesCount INT = COALESCE(@AToEmployeesCount, 0),
		@FromMinimum INT = COALESCE(@AFromMinimum,0),
		@ToMinimum INT = COALESCE(@AToMinimum, 0),
		@FromMaximum INT = COALESCE(@AFromMaximum,0),
		@ToMaximum INT = COALESCE(@AToMaximum, 0),
		@FromAverage INT = COALESCE(@AFromAverage,0),
		@ToAverage INT = COALESCE(@AToAverage, 0),
		@FromCreationDate DATETIME = @AFromCreationDate,
		@ToCreationDate DATETIME = DATEADD(DAY, 1, @AToCreationDate),
		@FromConfirmDate DATETIME = @AFromConfirmDate,
		@ToConfirmDate DATETIME = DATEADD(DAY, 1, @AToConfirmDate),
		@PayrollType TINYINT = COALESCE(@APayrollType, 0),
		@TreasuryPayment TINYINT = COALESCE(@ATreasuryPayment, 0),
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@UserID UNIQUEIDENTIFIER 

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH MainSelect AS
	(
		SELECT DISTINCT
			Payroll.ID,
			Payroll.OrganID,
			Payroll.OrganName,
			Payroll.LawID,
			Payroll.LawName,
			Payroll.[Year],
			Payroll.[Month],
			Payroll.Minimum,
			Payroll.Maximum,
			Payroll.Average,
			Payroll.EmployeesCount,
			Payroll.ConfirmDate,
			Payroll.LastState LastDocState,
			Payroll.CreationDate,
			Payroll.ToPositionID,
			Payroll.PayrollType,
			Payroll.TreasuryPayment,
			Payroll.[State],
			ToPosition.[Type] ToPositionType,
			ToPosition.FirstName + ' ' + ToPosition.LastName ToUserName,
			ToPosition.DepartmentName ToOrganName,
			d.MainOrgan1Name MainOrganName,
			d.Type,
			d.SubType,
			IIF((ErrorAttachment.ID IS NOT NULL), 1, 0) HasErrorAttachment,
			IIF((WarningAttachment.ID IS NOT NULL), 1, 0) HasWarningAttachment
		FROM wag._Payroll Payroll
			LEFT JOIN org._position ToPosition ON ToPosition.ID = Payroll.ToPositionID
			LEFT JOIN org._Department d ON d.ID=Payroll.OrganID
			LEFT JOIN [pbl].[Attachment] ErrorAttachment ON ErrorAttachment.ParentID = Payroll.ID AND ErrorAttachment.Type = 3
			LEFT JOIN [pbl].[Attachment] WarningAttachment ON WarningAttachment.ParentID = Payroll.ID AND WarningAttachment.Type = 4
		WHERE 
			(@OrganID IS NULL OR Payroll.OrganID = @OrganID)
			AND (@MainOrganID IS NULL OR d.MainOrgan1ID = @MainOrganID)
			AND (@LawID IS NULL OR Payroll.LawID = @LawID)
			AND (@Year < 1 OR [Year] = @Year)
			AND (@Month < 1 OR [Month] = @Month)
			AND (@LastDocState < 1 OR Payroll.LastState = @LastDocState)
			AND (@Type < 1 OR d.Type = @Type)
			AND (@SubType < 1 OR d.SubType = @SubType)
			AND (@PayrollType < 1 OR Payroll.PayrollType = @PayrollType)

			AND ((@FromMinimum < 1 OR Payroll.Minimum >= @FromMinimum) 
			AND (@ToMinimum < 1 OR Payroll.Minimum <= @ToMinimum))

			AND ((@FromMaximum < 1 OR Payroll.Maximum >= @FromMaximum) 
			AND (@ToMaximum < 1 OR Payroll.Maximum <= @ToMaximum))

			AND ((@FromAverage < 1 OR Payroll.Average >= @FromAverage) 
			AND (@ToAverage < 1 OR Payroll.Average <= @ToAverage))

			AND (@FromCreationDate IS NULL OR Payroll.CreationDate >= @FromCreationDate) 
			AND (@ToCreationDate IS NULL OR Payroll.CreationDate < @ToCreationDate)

			AND (@FromConfirmDate IS NULL OR Payroll.ConfirmDate >= @FromConfirmDate) 
			AND (@ToConfirmDate IS NULL OR Payroll.ConfirmDate < @ToConfirmDate)

			AND (@RequestID IS NULL OR Payroll.RequestID = @RequestID)

			
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Year] DESC, [Month] DESC, OrganName ASC, [LawName] ASC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollSummaries') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollSummaries
GO

CREATE PROCEDURE wag.spGetPayrollSummaries
	@APayrollID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID

		IF OBJECT_ID('tempdb..#TempPayrollEmployee','U') IS NOT NULL
		DROP TABLE #TempPayrollEmployee
		 
		SELECT employeeID,EmploymentType INTO #TempPayrollEmployee FROM wag.PayrollEmployee
		WHERE  PayrollID = @PayrollID
	SELECT 
		emp.EmploymentType, 
		detail.WageTitleID,
		Count(emp.EmployeeID) Count,
		SUM(CAST(Amount AS BIGINT)) Sum
	FROM wag.PayrollDetail detail
		INNER JOIN #TempPayrollEmployee emp ON emp.employeeID = detail.EmployeeID
	WHERE detail.PayrollID = @PayrollID
	GROUP BY emp.EmploymentType, detail.WageTitleID
	ORDER BY emp.EmploymentType, detail.WageTitleID

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollYears') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollYears
GO

CREATE PROCEDURE wag.spGetPayrollYears
	@AOrganIDs NVARCHAR(MAX),
	@ALawIDs NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@LawIDs NVARCHAR(MAX) = @ALawIDs

	;WITH Payroll AS
	(
		SELECT 
			DISTINCT Year
		FROM wag._Payroll Payroll
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Payroll.OrganID
			LEFT JOIN OPENJSON(@LawIDs) LawIDs ON LawIDs.value = Payroll.LawID
		WHERE LastState = 100
			AND (@OrganIDs IS NULL OR OrganIDs.value = Payroll.OrganID)
			AND (@LawIDs IS NULL OR LawIDs.value = Payroll.LawID)
	)
	SELECT 
		DISTINCT Payroll.Year
	FROM Payroll
	ORDER BY [Year]

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollYears') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollYears
GO

CREATE PROCEDURE wag.spGetPayrollYears
	@AOrganIDs NVARCHAR(MAX),
	@ALawIDs NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@LawIDs NVARCHAR(MAX) = @ALawIDs

	;WITH PayrollYearList AS
	(
		SELECT 
			DISTINCT Year
		FROM wag._Payroll Payroll
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = Payroll.OrganID
			LEFT JOIN OPENJSON(@LawIDs) LawIDs ON LawIDs.value = Payroll.LawID
		WHERE 
			(@OrganIDs IS NULL OR OrganIDs.value = Payroll.OrganID)
			AND (@LawIDs IS NULL OR LawIDs.value = Payroll.LawID)
	)
	SELECT 
		Payroll.*
	FROM Payroll
	ORDER BY [Year] DESC

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyPayroll') IS NOT NULL
    DROP PROCEDURE wag.spModifyPayroll
GO

CREATE PROCEDURE wag.spModifyPayroll  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@AMinimum BIGINT,
	@AMaximum BIGINT,
	@AAverage BIGINT,
	@AEmployeesCount INT,
	@AToDocState TINYINT,
	@APayrollType TINYINT,
	@APlaceFinancing TINYINT,
	@ADepartmentBudgetID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@Year SMALLINT = @AYear,
		@Month TINYINT = ISNULL(@AMonth, 0),
		@Minimum BIGINT = @AMinimum,
		@Maximum BIGINT = @AMaximum,
		@Average BIGINT = @AAverage,
		@EmployeesCount INT = @AEmployeesCount,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@UserPositionType TINYINT,  
		@DocumentType TinyINT = 2,     -- Payroll
		@TrackingCode VARCHAR(20),
		@DocumentNumber NVARCHAR(50),
		@CreatorPositionID UNIQUEIDENTIFIER,
		@CreatorPositionType TINYINT,
		@ToDocState TINYINT = COALESCE(@AToDocState, 5),
		@PayrollType TINYINT = COALESCE(@APayrollType, 0),
		@PlaceFinancing TINYINT = COALESCE(@APlaceFinancing, 0),
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@DepartmentBudgetID UNIQUEIDENTIFIER = @ADepartmentBudgetID,
		@teststate tinyint
		
	SET @UserPositionType = (SELECT TOP 1 [Type] from Org.Position WHERE ID = @CurrentUserPositionID)
	set @teststate = 1
	--BEGIN TRY
	--	BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				

				EXECUTE pbl.spModifyBaseDocument_ 1, @ID, @DocumentType, @CurrentUserPositionID, @TrackingCode, @DocumentNumber, NULL
				
				EXEC pbl.spAddFlow @ADocumentID = @ID, @AFromUserID = @CurrentUserID, @AFromPositionID = @CurrentUserPositionID, @AToPositionID = @CurrentUserPositionID, @AFromDocState = 1, @AToDocState = @ToDocState, @ASendType = 3, @AComment = null

				INSERT INTO wag.Payroll
				(ID, OrganID, LawID, [Year], [Month], Minimum, Maximum, Average, EmployeesCount,PositionSubTypeID, PayrollType, TreasuryPayment, RequestID,DepartmentBudgetID,PlaceFinancing, [State])
				VALUES
				(@ID, @OrganID, @LawID, @Year, @Month, @Minimum, @Maximum, @Average, @EmployeesCount,@PositionSubTypeID, @PayrollType,0, @RequestID,@DepartmentBudgetID,@PlaceFinancing, @teststate)
			END
			ELSE
			BEGIN

				UPDATE wag.Payroll
				SET 
					Minimum = @Minimum, 
					Maximum = @Maximum,
					Average = @Average,
					EmployeesCount = @EmployeesCount--,
					--SalaryUpdateDate = GETDATE()
				WHERE ID = @ID

			END

	--	COMMIT
	--END TRY
	--BEGIN CATCH
	--	;THROW
	--END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht];
GO
IF OBJECT_ID('wag.spModifyPayrollAfterCalculateEmployees') IS NOT NULL
    DROP PROCEDURE wag.spModifyPayrollAfterCalculateEmployees;
GO
CREATE PROCEDURE wag.spModifyPayrollAfterCalculateEmployees
@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
    BEGIN
        SET NOCOUNT, XACT_ABORT ON;
        DECLARE @ID UNIQUEIDENTIFIER= @AID,
		        @EmployeesCount INT,
				@HaveEmployees  INT ;
        INSERT INTO [SalaryTemp].[dbo].[UpdatePayrollEmployeesLogs]([Logs])
        VALUES('spModifyPayrollAfterCalculateEmployees' + CAST(@AID AS NVARCHAR(36)));
        BEGIN TRY
            BEGIN TRAN;
            SELECT @EmployeesCount = COUNT(*)
            FROM wag.PayrollEmployee
            WHERE PayrollEmployee.PayrollID = @ID;
            SELECT @HaveEmployees = COUNT(*)
            FROM wag.Payroll
                 INNER JOIN wag.PayrollEmployee ON PayrollEmployee.PayrollID = Payroll.ID
            WHERE Payroll.ID = @ID
                  AND [Sum] > 0;
            IF(@HaveEmployees <> 0)
                BEGIN
                    WITH Cte_PayrollEmployee
                         AS (SELECT [Sum], 
                                    PayrollEmployee.ID, 
                                    PayrollID
                             FROM wag.Payroll
                                  INNER JOIN wag.PayrollEmployee ON PayrollEmployee.PayrollID = Payroll.ID
                             WHERE Payroll.ID = @ID
                                   AND [Sum] > 0),
                         cte
                         AS (SELECT Payroll.ID, 
                                    MIN(PayrollEmployee.[Sum]) Minimum, 
                                    MAX(PayrollEmployee.[Sum]) Maximum, 
                                    AVG(PayrollEmployee.[Sum]) Average, 
                                    @EmployeesCount EmployeesCount
                             FROM wag.Payroll
                                  INNER JOIN Cte_PayrollEmployee PayrollEmployee ON PayrollEmployee.PayrollID = Payroll.ID
                             WHERE Payroll.ID = @ID
                             GROUP BY Payroll.ID)
                         UPDATE wag.Payroll
                           SET 
                               Minimum = cte.Minimum, 
                               Maximum = cte.Maximum, 
                               Average = cte.Average, 
                               EmployeesCount = cte.EmployeesCount, 
                               SalaryUpdateDate = GETDATE()
                         FROM wag.Payroll
                              INNER JOIN cte ON cte.ID = Payroll.ID;
                END;
                ELSE
                BEGIN
                    WITH Cte_PayrollEmployee
                         AS (SELECT [Sum], 
                                    PayrollEmployee.ID, 
                                    PayrollID
                             FROM wag.Payroll
                                  INNER JOIN wag.PayrollEmployee ON PayrollEmployee.PayrollID = Payroll.ID
                             WHERE Payroll.ID = @ID),
                         cte
                         AS (SELECT Payroll.ID, 
                                    MIN(PayrollEmployee.[Sum]) Minimum, 
                                    MAX(PayrollEmployee.[Sum]) Maximum, 
                                    AVG(PayrollEmployee.[Sum]) Average, 
                                    @EmployeesCount EmployeesCount
                             FROM wag.Payroll
                                  INNER JOIN Cte_PayrollEmployee PayrollEmployee ON PayrollEmployee.PayrollID = Payroll.ID
                             WHERE Payroll.ID = @ID
                             GROUP BY Payroll.ID)
                         UPDATE wag.Payroll
                           SET 
                               Minimum = cte.Minimum, 
                               Maximum = cte.Maximum, 
                               Average = cte.Average, 
                               EmployeesCount = cte.EmployeesCount, 
                               SalaryUpdateDate = GETDATE()
                         FROM wag.Payroll
                              INNER JOIN cte ON cte.ID = Payroll.ID;
                END;
            COMMIT;
        END TRY
        BEGIN CATCH
            THROW;
        END CATCH;
        RETURN @@ROWCOUNT;
    END;
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spModifyPayrollExcelTimerState'))
	DROP PROCEDURE wag.spModifyPayrollExcelTimerState
GO

CREATE PROCEDURE wag.spModifyPayrollExcelTimerState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APayrollID UNIQUEIDENTIFIER,
	@AMessage NVARCHAR(4000)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@Message NVARCHAR(4000) = LTRIM(RTRIM(@AMessage))

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO wag.PayrollExcelTimerState
				(ID, PayrollID, Message)
				VALUES
				(@ID, @PayrollID, @Message)
			END
			ELSE    -- update
			BEGIN
				UPDATE wag.PayrollExcelTimerState
				SET PayrollID = @PayrollID, Message = @Message
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID ('wag.spSetPayrollState'))
DROP PROCEDURE wag.spSetPayrollState
GO

CREATE PROCEDURE wag.spSetPayrollState 
	@APayrollID UNIQUEIDENTIFIER,
	@AState TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@State TINYINT = COALESCE(@AState, 0)

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE wag.Payroll 
			SET [State] = @State
			WHERE ID = @PayrollID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END		
GO

USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.Procedures WHERE [object_id] = OBJECT_ID('wag.spUpdatePayrollEmployees'))
    DROP PROCEDURE wag.spUpdatePayrollEmployees
GO

CREATE PROCEDURE wag.spUpdatePayrollEmployees  
	@APayrollID UNIQUEIDENTIFIER,
	@AEmployees NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@Employees NVARCHAR(MAX) = LTRIM(RTRIM(@AEmployees))

	BEGIN TRY
		BEGIN TRAN

			IF @Employees IS NOT NULL
			BEGIN
				UPDATE PayrollEmployee
				SET 
					Salary = tblJson.Salary,
					Continuous = tblJson.Continuous,
					NonContinuous = tblJson.NonContinuous,
					Reward = tblJson.Reward,
					Welfare = tblJson.Welfare,
					Other = tblJson.Other,
					Deductions = tblJson.Deductions,
					SumHokm = tblJson.SumHokm,
					SumNHokm = tblJson.SumNHokm,
					SumPayments = tblJson.SumPayments,
					SumDeductions = tblJson.SumDeductions,
					[Sum] = tblJson.[Sum]
				FROM wag.PayrollEmployee
					INNER JOIN OPENJSON(@Employees)
					WITH
					(
						ID UNIQUEIDENTIFIER,
						Salary BIGINT,
						Continuous BIGINT,
						NonContinuous BIGINT,
						Reward BIGINT,
						Welfare BIGINT,
						Other BIGINT,
						Deductions BIGINT,
						SumHokm BIGINT,
						SumNHokm BIGINT,
						SumPayments BIGINT, 
						SumDeductions BIGINT, 
						[Sum] BIGINT
					) tblJson ON PayrollEmployee.ID = tblJson.ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO
CREATE Or ALTER PROCEDURE [wag].[spUpdatePayrollForProcess]
@AID UNIQUEIDENTIFIER ,
@APayrollStatus TINYINT
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
UPDATE [wag].[PayrollForProcess]
   SET [PayrollStatus] =@APayrollStatus
 WHERE ID=@AID
END 



GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.Procedures WHERE [object_id] = OBJECT_ID('wag.spUpdatePayrollSums'))
    DROP PROCEDURE wag.spUpdatePayrollSums
GO

CREATE PROCEDURE wag.spUpdatePayrollSums
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

	WITH Payroll AS
	(
	select top 200  * 
	from wag._Payroll 
	where Maximum = 0 and Minimum = 0 and LastState > 5 and LastState <> 210
	)
	update Payroll
	SET Maximum = COALESCE((SELECT MAX(CAST([Sum] AS BIGINT)) FROM wag.PayrollEmployee where PayrollID = Payroll.ID), 0),
		Minimum = COALESCE((SELECT MIN(CAST([Sum] AS BIGINT)) FROM wag.PayrollEmployee where PayrollID = Payroll.ID), 0),
		Average = COALESCE((SELECT AVG(CAST([Sum] AS BIGINT)) FROM wag.PayrollEmployee where PayrollID = Payroll.ID), 0)
	FROM Payroll

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spEnterPayrollDetail') IS NOT NULL
    DROP PROCEDURE wag.spEnterPayrollDetail
GO

CREATE PROCEDURE wag.spEnterPayrollDetail  
	@APayrollID UNIQUEIDENTIFIER,
	@AWageTitleID UNIQUEIDENTIFIER,
	@ARegistrarUserID UNIQUEIDENTIFIER,
	@AEmployeesAmount NVARCHAR(MAX) 
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@WageTitleID UNIQUEIDENTIFIER = @AWageTitleID,
		@RegistrarUserID UNIQUEIDENTIFIER = @ARegistrarUserID,
		@EmployeesAmount NVARCHAR(MAX) = LTRIM(RTRIM(@AEmployeesAmount)),
		@RegisterDate SMALLDATETIME = GETDATE()

	DECLARE @Amounts TABLE(ID UNIQUEIDENTIFIER, EmployeeID UNIQUEIDENTIFIER, [Value] DECIMAL(12,2))

	INSERT INTO @Amounts
	SELECT ID, EmployeeID, Amount
	FROM OPENJSON(@EmployeesAmount)
	WITH (
		ID UNIQUEIDENTIFIER, 
		EmployeeID UNIQUEIDENTIFIER, 
		Amount DECIMAL(12, 2)
	)

	BEGIN TRY
		BEGIN TRAN
			
			SELECT 
				amount.ID ID,
				@PayrollID PayrollID,
				@WageTitleID WageTitleID,
				amount.EmployeeID EmployeeID,
				amount.[Value] Amount,
				@RegisterDate RegisterDate,
				@RegistrarUserID RegistrarUserID
			FROM @Amounts amount

		COMMIT

		DELETE FROM @Amounts
	END TRY
	BEGIN CATCH
		DELETE FROM @Amounts
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollDetailExcel') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollDetailExcel
GO

CREATE PROCEDURE wag.spGetPayrollDetailExcel
	@APayrollID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AEmployeeID UNIQUEIDENTIFIER,
	@AYear INT,
	@AMonth INT,
	@ANationalCode VARCHAR(10),
	@AName NVARCHAR(1000),
	@APostLevel TINYINT,
	@APostLevelFrom TINYINT,
	@APostLevelTo TINYINT,
	@AEducationDegree TINYINT,
	@AJobBase TINYINT,
	@ASumFrom INT,
	@ASumTo INT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID,
		@Year INT = COALESCE(@AYear, 0),
		@Month INT = COALESCE(@AMonth, 0),
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@PostLevelFrom TINYINT = COALESCE(@APostLevelFrom , 0),
		@PostLevelTo TINYINT =  COALESCE(@APostLevelTo, 0),
		@EducationDegree  TINYINT = COALESCE(@AEducationDegree, 0),
		@JobBase TINYINT= COALESCE(@AJobBase, 0),
		@SumFrom INT = @ASumFrom,
		@SumTo INT = @ASumTo,
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF COALESCE(@CurrentUserOrganID, 0x) = 0x
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH MainSelect AS
	(
		SELECT COUNT(DISTINCT pe.EmployeeID) EmployeesCount, 
			   WageTitle.Name WageTitleName, 
			   payroll.ID PayrollID, 
			    SUM(CAST(PayrollDetail.amount AS BIGINT)) Amount,
			   CAST(1 AS TINYINT) AS WageTitleIncomeType,
			   Department.Name OrganName
		FROM wag.payroll
			 INNER JOIN wag.PayrollEmployee pe ON payroll.ID =pe.PayrollID
			 INNER JOIN wag.PayrollDetail ON PayrollDetail.PayrollEmployeeID = pe.ID
			 INNER JOIN wag.WageTitle ON WageTitle.ID = PayrollDetail.WageTitleID
			 INNER JOIN org.Department ON Department.ID=payroll.OrganID
		WHERE 	(@PayrollID IS NULL OR Payroll.ID = @PayrollID)
		AND WageTitle.[IncomeType]=1
		GROUP BY payroll.ID, 
				 WageTitle.Name,
				 payroll.EmployeesCount,
				  Department.Name
				 UNION
	    SELECT COUNT(DISTINCT pe.EmployeeID) EmployeesCount, 
			   WageTitle.Name WageTitleName, 
			   payroll.ID PayrollID, 
			    SUM(CAST(PayrollDetail.amount AS BIGINT)) Amount,
			   CAST(2 AS TINYINT) AS WageTitleIncomeType,
			    Department.Name OrganName
		FROM wag.payroll
		     INNER JOIN wag.PayrollEmployee pe ON payroll.ID =pe.PayrollID
			 INNER JOIN wag.PayrollDetail ON PayrollDetail.PayrollEmployeeID = pe.ID
			 INNER JOIN wag.WageTitle ON WageTitle.ID = PayrollDetail.WageTitleID
			 INNER JOIN org.Department ON Department.ID=payroll.OrganID
		WHERE 	(@PayrollID IS NULL OR Payroll.ID = @PayrollID)
		AND WageTitle.[IncomeType]=2
		GROUP BY payroll.ID, 
				 WageTitle.Name,
				 payroll.EmployeesCount,
				 Department.Name
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY PayrollID 
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE)
	--WHERE 
	--		(@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
			--AND (@EmployeeID IS NULL OR payrollEmployee.EmployeeID = @EmployeeID)
		--	AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
			--AND (@PostLevelFrom < 1 OR PayrollEmployee.PostLevel >= @PostLevelFrom)
			--AND (@PostLevelTo < 1 OR PayrollEmployee.PostLevel < @PostLevelTo)
		--	AND (@EducationDegree < 1 OR PayrollEmployee.EducationDegree = @EducationDegree)
			----AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
			----AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
			--AND (@Name is null OR EmployeeDetail.FirstName like N'%' + @Name +'%' OR EmployeeDetail.LastName like N'%' + @Name +'%')
			--AND (@NationalCode is null OR EmployeeDetail.NationalCode = @NationalCode)
			--AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
			--AND (@SumFrom IS NULL OR PayrollEmployee.Sum >= @SumFrom)
			--AND (@SumTo IS NULL OR PayrollEmployee.Sum <= @SumTo)
			--AND (@PayrollID IS NULL OR Payroll.ID = @PayrollID)
			--AND (@LawID IS NULL OR Payroll.LawID = @LawID)
			--AND (@OrganID IS NULL OR Payroll.OrganID = @OrganID)
			--AND (@Year < 1 OR [Year] = @Year)
			--AND (@Month < 1 OR [Month] = @Month)

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollDetails') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollDetails
GO

CREATE PROCEDURE wag.spGetPayrollDetails  
	@APayrollDetailID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER,
	@AEmployeeID UNIQUEIDENTIFIER,
	@APayrollID UNIQUEIDENTIFIER,
	@APayrollType TINYINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollDetailID UNIQUEIDENTIFIER = @APayrollDetailID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@PayrollType TINYINT = COALESCE(@APayrollType, 0)

	;WITH PayrollDetail AS
	(
		SELECT
			pe.[PayrollID],
			pe.[EmployeeID],
			PayrollDetail.[WageTitleID],
			PayrollDetail.[Amount],
			ped.[BudgetCode],
			ped.[PlaceFinancing],
			PayrollDetail.[Dates],
			Payroll.[DepartmentBudgetID],
			Payroll.[PayrollType],
			Payroll.[RequestID],
			Payroll.[State]
		FROM [wag].[PayrollDetail] PayrollDetail
		    INNER JOIN wag.PayrollEmployee pe ON pe.ID=PayrollDetail.PayrollEmployeeID 
			INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID=pe.ID 
			INNER JOIN [wag].[Payroll] Payroll ON Payroll.ID = pe.PayrollID
			
		WHERE pe.ID = @PayrollDetailID
			AND (@RequestID IS NULL OR Payroll.[RequestID] = @RequestID)
			AND (@EmployeeID IS NULL OR pe.[EmployeeID] = @EmployeeID)
			AND (@PayrollID IS NULL OR Payroll.[ID] = @PayrollID)
			AND (@PayrollType < 1 OR Payroll.[PayrollType] = @PayrollType)

		UNION

		SELECT
			pe.[PayrollID],
			pe.[EmployeeID],
			PayrollDetail.[WageTitleID],
			PayrollDetail.[Amount],
			ped.[BudgetCode],
			ped.[PlaceFinancing],
			PayrollDetail.[Dates],
			Payroll.[DepartmentBudgetID],
			Payroll.[PayrollType],
			Payroll.[RequestID],
			Payroll.[State]
		FROM tmp.PayrollDetail PayrollDetail
			 INNER JOIN wag.PayrollEmployee pe ON pe.ID=PayrollDetail.PayrollEmployeeID 
			 INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID=pe.ID 
			INNER JOIN [wag].[Payroll] Payroll ON Payroll.ID = pe.PayrollID
		WHERE pe.ID = @PayrollDetailID
			AND (@RequestID IS NULL OR Payroll.[RequestID] = @RequestID)
			AND (@EmployeeID IS NULL OR pe.[EmployeeID] = @EmployeeID)
			AND (@PayrollID IS NULL OR Payroll.[ID] = @PayrollID)
			AND (@PayrollType < 1 OR Payroll.[PayrollType] = @PayrollType)
	)
	SELECT 
		PayrollDetail.PayrollID,
		PayrollDetail.[DepartmentBudgetID],
		PayrollDetail.[PayrollType],
		PayrollDetail.[RequestID],
		PayrollDetail.[State],

		PayrollDetail.EmployeeID,
		PayrollWageTitle.WageTitleID,
		PayrollWageTitle.[Type] WageTitleType,
		PayrollWageTitle.[Name] WageTitleName,
		PayrollWageTitle.[Code] WageTitleCode,
		PayrollWageTitle.ParentCode ParentWageTitleCode,
		PayrollWageTitle.IncomeType WageTitleIncomeType,
		PayrollWageTitle.OrderType WageTitleOrderType,
		PayrollWageTitle.[WageTitleGroupID],
		PayrollWageTitle.[Order],
		Sum(PayrollDetail.Amount) Amount
	FROM wag._PayrollWageTitle PayrollWageTitle 
		INNER JOIN PayrollDetail ON PayrollDetail.WageTitleID = PayrollWageTitle.WageTitleID AND PayrollWageTitle.PayrollID = PayrollDetail.PayrollID
	GROUP BY 
		PayrollDetail.PayrollID,
		PayrollDetail.[DepartmentBudgetID],
		PayrollDetail.[PayrollType],
		PayrollDetail.[RequestID],
		PayrollDetail.[State],
		PayrollDetail.EmployeeID,
		PayrollWageTitle.WageTitleID,
		PayrollWageTitle.[Type],
		PayrollWageTitle.[Name],
		PayrollWageTitle.[Code],
		PayrollWageTitle.ParentCode,
		PayrollWageTitle.IncomeType,
		PayrollWageTitle.OrderType,
		PayrollWageTitle.[WageTitleGroupID],
		PayrollWageTitle.[Order]
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollDetailsByNationalCode') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollDetailsByNationalCode
GO

CREATE PROCEDURE wag.spGetPayrollDetailsByNationalCode
	  @ANationalCode VARCHAR(10)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode))
		, @Result INT = 0

	SELECT emp.ID ID
	INTO #Employee
	FROM pbl.Employee emp
	LEFT JOIN pbl.EmployeeDetail detail ON detail.ID = emp.ID
	LEFT JOIN pbl.Individual ind ON ind.ID = emp.IndividualID
	WHERE detail.NationalCode = @NationalCode
		OR ind.NationalCode = @NationalCode

	SELECT 
		detail.ID
		, detail.PayrollID
		, detail.EmployeeID
		, detail.WageTitleID
		, detail.Amount
		, org.Name OrganName
		--, detail.PayrollEmployeeID
		--, ind.NationalCode
		--, ind.FirstName
		--, ind.LastName
		--, ind.FatherName
		--, ind.BCNumber
		--, ind.Gender
		--, BirthDate
		--, detail.WageTitleID
		, wageTitle.[Name] WageTitleName
		, wageTitle.[Code] WageTitleCode
		--, payroll.LawID
		--, law.Code LawCode
		, law.[Name] LawName
		, payroll.[Year]
		, payroll.[Month]
	FROM wag.PayrollDetail detail
		INNER JOIN wag.Payroll payroll ON payroll.ID = detail.PayrollID
		INNER JOIN #Employee emp ON emp.ID = detail.EmployeeID
		INNER JOIN law.Law law ON law.ID = payroll.LawID
		INNER JOIN org.Organ org ON org.[Guid] = Payroll.OrganID
		INNER JOIN wag.WageTitle wageTitle ON wageTitle.ID = detail.WageTitleID
	
	SET @Result = @@ROWCOUNT

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollDetailsByPayorollAndEmployeeIDs') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollDetailsByPayorollAndEmployeeIDs
GO

CREATE PROCEDURE wag.spGetPayrollDetailsByPayorollAndEmployeeIDs  
	@APayrollID UNIQUEIDENTIFIER,
	@AEmployeeIDs NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@EmployeeIDs NVARCHAR(MAX) = @AEmployeeIDs

	SELECT *
	FROM wag.PayrollDetail pd
	INNER JOIN wag.PayrollEmployee pe ON pe.ID =pd.PayrollEmployeeID
	INNER JOIN wag.PayrollEmployeeDetail ped ON pe.ID =ped.ID
	INNER JOIN OPENJSON(@EmployeeIDs) EmployeeIDs ON EmployeeIDs.Value = EmployeeID
	WHERE PayrollID = @PayrollID

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollDetailsByPayrollIDs') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollDetailsByPayrollIDs
GO

CREATE PROCEDURE wag.spGetPayrollDetailsByPayrollIDs
	@APayrollIDs NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollIDs NVARCHAR(MAX) = @APayrollIDs

	SELECT 
		PayrollDetail.*,
		Payroll.OrganID
	FROM wag.PayrollDetail
		INNER JOIN OPENJSON(@PayrollIDs) PayrollIDs ON PayrollIDs.value = PayrollDetail.PayrollID
		INNER JOIN wag.Payroll ON Payroll.ID = PayrollDetail.PayrollID
		OPTION(RECOMPILE)

END 
GO
USE [Kama.Aro.Pardakht]
GO

CREATE OR ALTER PROCEDURE wag.spGetTmpPayrollDetails  
	@APayrollID UNIQUEIDENTIFIER,
	@AEmployeeID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID

	SELECT *
	FROM tmp.PayrollDetail pd
	INNER JOIN wag.PayrollEmployee pe ON pe.ID =pd.PayrollEmployeeID
	INNER JOIN wag.PayrollEmployeeDetail ped ON pe.ID =ped.ID
	WHERE PayrollID = @PayrollID
		AND (@EmployeeID IS NULL OR EmployeeID = @EmployeeID)
	order by EmployeeID

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spMoveTempPayrollDetails') IS NOT NULL
    DROP PROCEDURE wag.spMoveTempPayrollDetails
GO

CREATE PROCEDURE wag.spMoveTempPayrollDetails  
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET ANSI_NULLS OFF;

	BEGIN TRY
		BEGIN TRAN
	
			INSERT  INTO wag.[PayrollDetail]
			SELECT * 
			FROM [tmp].[PayrollDetail]
			
			DELETE tmp.[PayrollDetail]
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END  
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spUpdatePayrollDetail') IS NOT NULL
    DROP PROCEDURE wag.spUpdatePayrollDetail
GO

CREATE PROCEDURE wag.spUpdatePayrollDetail  
	@AID UNIQUEIDENTIFIER,
	@APayrollID UNIQUEIDENTIFIER,
	@AEmployeeID UNIQUEIDENTIFIER,
	@AWageTitleID UNIQUEIDENTIFIER,
	@AAmount INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET ANSI_NULLS OFF;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID,
		@WageTitleID UNIQUEIDENTIFIER = @AWageTitleID,
		@Amount INT = @AAmount

	BEGIN TRY
		BEGIN TRAN
			UPDATE wag.PayrollDetail
			SET PayrollID = @PayrollID,
				EmployeeID = @EmployeeID,
				WageTitleID = @WageTitleID,
				Amount = @Amount
			WHERE ID = @ID
			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END  
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spCreatePayrollDetails') IS NOT NULL
    DROP PROCEDURE wag.spCreatePayrollDetails
GO

CREATE PROCEDURE wag.spCreatePayrollDetails  
	@APayrollID UNIQUEIDENTIFIER,
	@ADetails NVARCHAR(MAX),
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET ANSI_NULLS OFF;

    DECLARE
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@Details NVARCHAR(MAX) = LTRIM(RTRIM(@ADetails)),
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			INSERT INTO wag.PayrollDetail
			(ID, PayrollID, EmployeeID, WageTitleID, [Amount])
			SELECT 
				NEWID() ID,
				@PayrollID PayrollID,
				jsonDetail.EmployeeID,
				jsonDetail.WageTitleID,
				jsonDetail.[Amount]
			FROM OPENJSON(@Details)
			WITH
			(
				EmployeeID UNIQUEIDENTIFIER,
				WageTitleID UNIQUEIDENTIFIER,
				[Amount] INT
			) jsonDetail
			
			SET @Result = @@ROWCOUNT

		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END  
GO
USE [Kama.Aro.Pardakht]
GO
/****** Object:  StoredProcedure [wag].[spCreatePayrollEmployeeExcelReport]    Script Date: 11/10/2021 9:24:01 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER  PROCEDURE [wag].[spCreatePayrollEmployeeExcelReport]
	
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	IF OBJECT_ID('wag.PayrollEmployeeExcelReport') IS NOT NULL
    DROP Table wag.PayrollEmployeeExcelReport
    	
	;WITH FirstFlow
     AS (SELECT MIN(df.Date) CreationDate, 
                df.DocumentID
         FROM pbl.DocumentFlow df
         GROUP BY df.DocumentID),
     CtePayrollEmployee
     AS (SELECT SUM(pe.[Sum]) TotalPayment, 
                pe.PayrollID
         FROM tmp.PayrollEmployee pe
         GROUP BY pe.PayrollID),
		   CtePayroll
     AS (SELECT MAX(pe.[Sum]) Maximum, MIN(pe.[Sum]) Minimum,  AVG(pe.[Sum]) Average, 
                pe.PayrollID
         FROM tmp.PayrollEmployee pe
		 WHERE pe.Sum<>0
         GROUP BY pe.PayrollID),
     InvalidSalary
     AS (SELECT COUNT(*) Total, 
                pe.PayrollID
         FROM tmp.PayrollEmployee pe
         WHERE pe.[Sum] > 337000000
         GROUP BY pe.PayrollID)
     SELECT d.BudgetCode, 
            d.Name OrganName, 
            place.Name ProvinceName, 
            d.MainOrgan1Name MainOrganName, 
            l.Name LawName, 
            IIF(CtePayroll.PayrollID is NULL,p.Minimum,CtePayroll.Minimum) Minimum, 
		    IIF(CtePayroll.PayrollID is NULL,p.Maximum,CtePayroll.Maximum) Maximum, 
			IIF(CtePayroll.PayrollID is NULL,p.Average,CtePayroll.Average) Average, 
            --p.Maximum, 
            --p.Average, 
            p.EmployeesCount, 
            df.Date ConfirmDateTime, 
            FirstFlow.CreationDate, 
            pe.TotalPayment, 
            IIF(InvalidSalary.Total is null,0,InvalidSalary.Total) InvalidSalaryCount,
			p.Month,
			d.ProvinceID,
			p.ID  PayrollID,
			p.OrganID,
			p.LawID,
			p.Year,
			IIF(PaknaEmployee.Count IS NULL,0,PaknaEmployee.Count ) PaknaEmployeesCount
			into wag.PayrollEmployeeExcelReport
     FROM wag.Payroll p
	      LEFT JOIN CtePayroll ON CtePayroll.PayrollID=p.ID
          INNER JOIN pbl.BaseDocument bd ON bd.ID = p.ID
          INNER JOIN pbl.DocumentFlow df ON bd.ID = df.DocumentID
          INNER JOIN org._Department d ON p.OrganID = d.ID
          INNER JOIN CtePayrollEmployee pe ON pe.PayrollID = p.ID
          INNER JOIN org.place place ON place.ID = d.ProvinceID
          INNER JOIN law.Law l ON l.Id = p.LawID
          INNER JOIN FirstFlow ON FirstFlow.DocumentID = p.ID
          LEFT JOIN InvalidSalary ON InvalidSalary.PayrollID = p.ID
		  LEFT JOIN wag.PaknaEmployee ON PaknaEmployee.OrganID=p.OrganID AND PaknaEmployee.Month=p.Month
     WHERE df.ToDocState = 100  AND bd.RemoveDate IS NULL AND p.Year = 1400
	
END 
GO
USE [Kama.Aro.Pakna]
GO
/****** Object:  StoredProcedure [mem].[spGetEmployeeInfos]    Script Date: 2021-12-28 3:10:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER    PROCEDURE [mem].[spGetEmployeeInfos]
	@OrganID uniqueidentifier
WITH
    NATIVE_COMPILATION, 
    SCHEMABINDING, 
    EXECUTE AS OWNER

AS
BEGIN ATOMIC
WITH (TRANSACTION ISOLATION LEVEL=SNAPSHOT, LANGUAGE='us_english')

	
	BEGIN TRY
	   SELECT [ID]
      ,[RowNumber]
      ,[BudgetCode]
      ,[NationalCode]
      ,[EmployeeNumber]
      ,[BirthDate]
      ,[WorkExperienceYears]
      ,[FirstName]
      ,[LastName]
      ,[Gender]
      ,[IndividualConfirmType]
      ,[IsDead]
      ,[MarriageStatus]
      ,[ChildrenCount]
      ,[EmploymentType]
      ,[ContractStartDate]
      ,[ContractEndDate]
      ,[EducationDegree]
      ,[PensionFundType]
      ,[InsuranceStatusType]
      ,[EmploymentStatus]
      ,[CountType]
      ,[IssuanceDate]
      ,[CreationDate]
      ,[IndividualID]
      ,[OrganID]
      ,[IsCalculated]
  FROM [mem].[EmployeeInfo]
	WHERE 	[OrganID]=@OrganID 
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID ('wag.spGetEmployeePayrollsByAmount'))
DROP PROCEDURE wag.spGetEmployeePayrollsByAmount
GO

CREATE PROCEDURE wag.spGetEmployeePayrollsByAmount
	@AID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@AYear SMALLINT,
	@AMonth TINYINT,
	@ASum INT
WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT, XACT_ABORT ON;
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID, 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@Year SMALLINT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Sum INT = @ASum

		-- temporary, fix from source ASAP
		if (@OrganID = '00000000-0000-0000-0000-000000000000')
			set @OrganID = null

		SELECT
			payrollemployee.ID PayrollEmployeeID,
			payroll.OrganID,
			dep.[Name] OrganName,
			payrollemployee.EmployeeID,
			payrollemployee.SumPayments-payrollemployee.SumDeductions [Sum],
			emp.FirstName,
			emp.LastName
		FROM wag.Payroll payroll
			INNER JOIN wag.PayrollEmployee payrollemployee ON payrollemployee.PayrollID = payroll.ID
			INNER JOIN org.Department dep ON dep.ID = payroll.OrganID
			INNER JOIN pbl.BaseDocument doc ON doc.ID = Payroll.ID
			INNER JOIN pbl.EmployeeDetail emp ON emp.ID = payrollemployee.EmployeeID
		WHERE doc.RemoveDate IS NULL
			AND (@OrganID IS NULL OR Payroll.OrganID = @OrganID)
			AND (@Year < 1 OR [Year] = @Year)
			AND (@Month < 1 OR [Month] = @Month)
			AND (payrollemployee.SumPayments-payrollemployee.SumDeductions = @Sum)
		ORDER BY [Year] DESC, [Month] DESC, dep.[Name] ASC
    RETURN
END 

GO
USE [Kama.Aro.Pardakht]
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER   PROCEDURE wag.spGetEmployeesFromPakna 
	@AOrganIDs NVARCHAR(MAX)
WITH ENCRYPTION
AS
    BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    IF OBJECT_ID('tempdb..#TempExceptionEmployeeInfoForT20','U') IS NOT NULL
		DROP TABLE #TempExceptionEmployeeInfoForT20

	IF OBJECT_ID('tempdb..#TempNationalCode','U') IS NOT NULL
		DROP TABLE #TempNationalCode

    DECLARE @NationalCode TABLE (NationalCode NVARCHAR(10),ID UNIQUEIDENTIFIER)
	DECLARE @OrganIDs NVARCHAR(MAX) = @AOrganIDs,
	        @cmd1  NVARCHAR(MAX),
			@cmd  NVARCHAR(MAX)

	DELETE wag.EmployeeInfo

	SET @cmd1='[Kama.Aro.Pakna].[mem].[spGetEmployeeInfos] @AOrganIDs='+''''+''''+@OrganIDs+''''+'''';

	SET @cmd='	INSERT INTO [wag].[EmployeeInfo]
		([ID], [RowNumber], [BudgetCode], [NationalCode], [EmployeeNumber], [BirthDate], [WorkExperienceYears], [FirstName], [LastName], [Gender], [IndividualConfirmType], [IsDead], [MarriageStatus], [ChildrenCount], [EmploymentType], [ContractStartDate], [ContractEndDate], [ExecutionDate], [EducationDegree], [PensionFundType], [InsuranceStatusType], [EmploymentStatus], [CountType], [IssuanceDate], [CreationDate], [IndividualID], [OrganID], [IsCalculated], [SacrificialType], [FrontlineDuration])
		SELECT  [ID], [RowNumber], [BudgetCode], [NationalCode], [EmployeeNumber], [BirthDate], [WorkExperienceYears], [FirstName], [LastName], [Gender], [IndividualConfirmType], [IsDead], [MarriageStatus], [ChildrenCount], [EmploymentType], [ContractStartDate], [ContractEndDate], [ExecutionDate], [EducationDegree], [PensionFundType], [InsuranceStatusType], [EmploymentStatus], [CountType], [IssuanceDate], [CreationDate], [IndividualID], [OrganID], [IsCalculated], [SacrificialType], [FrontlineDuration]
		FROM    OPENQUERY(ARODB01,'+''''+@cmd1+''''+')'

	EXEC(@cmd)

	;WITH EmployeeInfo AS 
		(
			SELECT 
				ROW_NUMBER() OVER(PARTITION BY employeeInfo.NationalCode ORDER BY employeeInfo.IssuanceDate DESC, employeeInfo.[CreationDate] DESC) NewRowNumber, 
				employeeInfo.ID, 
				employeeInfo.[RowNumber]
			FROM [wag].[EmployeeInfo] employeeInfo
		)
		UPDATE EmployeeInfo
		   SET [RowNumber]= NewRowNumber

	SELECT  
		EF20.EmployeeInfoID,
		EF20.Type,
		ind.NationalCode,
		ind.ID IndividualID,
		ind.[FirstName], 
		ind.[LastName], 
		ind.Gender,
		ind.ConfirmType,
		ind.BirthDate,
		ind.IsDead
	INTO #TempExceptionEmployeeInfoForT20
	FROM [Kama.Aro.Pakna].[emp].ExceptionEmployeeInfoForT20 EF20
		 INNER JOIN OPENJSON(@OrganIDs) org ON org.value=EF20.PaymentOrganID
		 INNER JOIN [Kama.Aro.Organization].org.Individual ind ON ind.ID=EF20.PaymentIndividualID
		 WHERE EF20.ExpirationDate>=GETDATE() 
		       AND EF20.RemoveDate IS  NULL
			   AND EF20.RemoverUserID IS  NULL
	
	--اگر حکم استثنایی برای سازمان وجود داشت
	IF(EXISTS (SELECT TOP 1 1 FROM #TempExceptionEmployeeInfoForT20 ))
	BEGIN
   
		UPDATE  [wag].[EmployeeInfo]
		SET [RowNumber]=1
		OUTPUT deleted.NationalCode, deleted.ID
		INTO @NationalCode
		FROM [wag].[EmployeeInfo] ef
		INNER JOIN  #TempExceptionEmployeeInfoForT20 t20 ON t20.EmployeeInfoID= ef.ID
		WHERE ef.RowNumber<>1

		
		SELECT DISTINCT  t20.EmployeeInfoID 
			INTO #ExceptionEmployeeInfo
		FROM #TempExceptionEmployeeInfoForT20 t20 
				LEFT JOIN  [wag].[EmployeeInfo] ef ON t20.EmployeeInfoID= ef.ID
		WHERE ef.ID IS NULL
		
		INSERT INTO @NationalCode
		SELECT info.NationalCode,info.ID
		FROM #ExceptionEmployeeInfo ExceptionEmployeeInfo
		INNER JOIN [Kama.Aro.Pakna].mem.EmployeeInfos info ON info.ID=ExceptionEmployeeInfo.EmployeeInfoID
		
		SELECT  [ID], 1 [RowNumber], [BudgetCode], [NationalCode], [EmployeeNumber], [BirthDate], [WorkExperienceYears], [FirstName], [LastName], [Gender], [IndividualConfirmType], [IsDead], [MarriageStatus], [ChildrenCount], [EmploymentType], [ContractStartDate], [ContractEndDate], [ExecutionDate], [EducationDegree], [PensionFundType], [InsuranceStatusType], [EmploymentStatus], [CountType], [IssuanceDate], [CreationDate], [IndividualID], [OrganID], [IsCalculated], [SacrificialType], [FrontlineDuration]
		INTO #EmployeeInfos
		FROM #ExceptionEmployeeInfo ExceptionEmployeeInfo
			INNER JOIN [Kama.Aro.Pakna].mem.EmployeeInfos info ON info.ID=ExceptionEmployeeInfo.EmployeeInfoID
        INSERT INTO [wag].[EmployeeInfo]
			([ID], [RowNumber], [BudgetCode], [NationalCode], [EmployeeNumber], [BirthDate], [WorkExperienceYears], [FirstName], [LastName], [Gender], [IndividualConfirmType], [IsDead], [MarriageStatus], [ChildrenCount], [EmploymentType], [ContractStartDate], [ContractEndDate], [ExecutionDate], [EducationDegree], [PensionFundType], [InsuranceStatusType], [EmploymentStatus], [CountType], [IssuanceDate], [CreationDate], [IndividualID], [OrganID], [IsCalculated], [SacrificialType], [FrontlineDuration])
        SELECT * FROM  #EmployeeInfos inf
		--WHERE inf.ID NOT IN(SELECT ID FROM [wag].[EmployeeInfo]) 
			
		;WITH EmployeeInfo AS 
		(
			SELECT 
				ROW_NUMBER() OVER(PARTITION BY employeeInfo.NationalCode ORDER BY employeeInfo.IssuanceDate DESC, employeeInfo.[CreationDate] DESC) NewRowNumber, 
				employeeInfo.ID, 
				employeeInfo.[RowNumber]
			FROM [wag].[EmployeeInfo] employeeInfo
			WHERE NationalCode COLLATE SQL_Latin1_General_CP1_CI_AS IN (SELECT NationalCode FROM @NationalCode)
				AND ID NOT IN (SELECT ID FROM @NationalCode)
		)

		UPDATE EmployeeInfo
		SET [RowNumber]= NewRowNumber+1

	END
	--EXEC 
	--(
	--	'SELECT
	--	[ID], [RowNumber], [BudgetCode], [NationalCode], [EmployeeNumber], [BirthDate], [WorkExperienceYears], [FirstName], [LastName], [Gender], [IndividualConfirmType], [IsDead], [MarriageStatus], [ChildrenCount], [EmploymentType], [ContractStartDate], [ContractEndDate], [ExecutionDate], [EducationDegree], [PensionFundType], [InsuranceStatusType], [EmploymentStatus], [CountType], [IssuanceDate], [CreationDate], [IndividualID], [OrganID], [IsCalculated], [SacrificialType], [FrontlineDuration]
	--	FROM OpenQuery(DB77,'+'''[Kama.Aro.Pakna].[mem].[spGetEmployeeInfos] @AOrganIDs='''''+ @OrganIDs + ''+''''''''+')'
	--)

	SELECT [ID],
		[RowNumber],
		[BudgetCode],
	    IIF(t20.EmployeeInfoID IS NULL, inf.[NationalCode] , t20.NationalCode COLLATE SQL_Latin1_General_CP1_CI_AS) NationalCode,
		[EmployeeNumber],
		IIF(t20.EmployeeInfoID IS NULL, inf.[BirthDate], t20.BirthDate) [BirthDate],
		[WorkExperienceYears],
		IIF(t20.EmployeeInfoID IS NULL, inf.[FirstName], t20.[FirstName] COLLATE SQL_Latin1_General_CP1_CI_AS) [FirstName],
		IIF(t20.EmployeeInfoID IS NULL, inf.[LastName], t20.[LastName] COLLATE SQL_Latin1_General_CP1_CI_AS) [LastName],
		IIF(t20.EmployeeInfoID IS NULL, inf.[Gender], t20.[Gender]) [Gender],
		IIF(t20.EmployeeInfoID IS NULL, inf.[IndividualConfirmType], t20.[ConfirmType]) [IndividualConfirmType],
		IIF(t20.EmployeeInfoID IS NULL, inf.[IsDead], t20.[IsDead]) [IsDead],
		[MarriageStatus],
		[ChildrenCount],
		[EmploymentType],
		[ContractStartDate],
		[ContractEndDate],
		[ExecutionDate],
		[EducationDegree],
		[PensionFundType],
		[InsuranceStatusType],
		[EmploymentStatus],
		[CountType],
		[IssuanceDate],
		[CreationDate],
		IIF(t20.EmployeeInfoID IS NULL,inf.[IndividualID],t20.IndividualID) [IndividualID],
		[OrganID],
		[SacrificialType],
		[IsCalculated]
	  FROM [wag].[EmployeeInfo] inf
	  LEFT JOIN #TempExceptionEmployeeInfoForT20 t20 ON t20.EmployeeInfoID=inf.ID AND t20.Type=2
END;
GO

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('pbl.spGetMultipleSalaryEmployees') IS NOT NULL
    DROP PROCEDURE pbl.spGetMultipleSalaryEmployees
GO

CREATE PROCEDURE pbl.spGetMultipleSalaryEmployees
	@AOrganID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@AFromYear SMALLINT,
	@AToYear SMALLINT,
	@AFromMonth SMALLINT,
	@AToMonth SMALLINT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@FromYear SMALLINT = ISNULL(@AFromYear, 0),
		@ToYear SMALLINT = ISNULL(@AToYear, 0),
		@FromMonth SMALLINT = ISNULL(@AFromMonth, 0),
		@ToMonth SMALLINT = ISNULL(@AToMonth, 0),
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = ISNULL(@APageSize, 20),
		@PageIndex INT = ISNULL(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF @CurrentUserOrganID = pbl.EmptyGuid()
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MultipleNationalCode AS
	(
		SELECT NationalCode
		FROM rpt.PayrollEmployeeDynamicReport
		WHERE 
			(@CurrentUserPositionType <> 51 OR PostLevel <= 28)   -- کاربر دستگاه نظارتی
			--AND (organ.Node.IsDescendantOf(@ParentOrganNode) = 1)
			--AND (@Name IS NULL OR FirstName LIKE CONCAT('%', @Name, '%') OR detail.LastName LIKE CONCAT('%', @Name, '%'))
			AND (@FromYear < 1 OR ([Year] >= @FromYear AND (@FromMonth < 1 OR ([Year] = @FromYear AND [Month] >= @FromMonth ))))
			AND (@ToYear < 1 OR ([Year] <= @ToYear AND (@ToMonth < 1 OR ([Year] = @ToYear AND [Month] <= @ToMonth ))))
		GROUP BY NationalCode, [Year], [Month]
		HAVING COUNT(*) > 1
	)
	SELECT DISTINCT 
		COUNT(*) OVER() Total,
		detail.FirstName,
		detail.LastName,
		detail.FatherName,
		detail.BCNumber,
		detail.Gender,
		detail.NationalCode,
		detail.BirthDate
	FROM MultipleNationalCode
		INNER JOIN pbl.EmployeeDetail detail ON MultipleNationalCode.NationalCode = detail.NationalCode
		INNER JOIN pbl.Employee Employee ON Employee.Id = detail.ID
	WHERE (@OrganID IS NULL OR Employee.OrganID = @OrganID)
	ORDER BY LastName
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollDetailIDByEmployeeID') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollDetailIDByEmployeeID
GO

CREATE PROCEDURE wag.spGetPayrollDetailIDByEmployeeID
	@AEmployeeID UNIQUEIDENTIFIER,
	@AMonth INT,
	@AYear INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID,
		@Month INT = @AMonth,
		@Year INT = @AYear,
		@Result INT = 0

	SELECT TOP 1
		detail.ID
		--, detail.PayrollID
		--, detail.EmployeeID
		--, detail.WageTitleID
		--, detail.Amount
		--, org.Name OrganName
		----, detail.PayrollEmployeeID
		----, ind.NationalCode
		----, ind.FirstName
		----, ind.LastName
		----, ind.FatherName
		----, ind.BCNumber
		----, ind.Gender
		----, BirthDate
		----, detail.WageTitleID
		--, wageTitle.[Name] WageTitleName
		--, wageTitle.[Code] WageTitleCode
		----, payroll.LawID
		----, law.Code LawCode
		--, law.[Name] LawName
		--, payroll.[Year]
		--, payroll.[Month]
	FROM wag.PayrollDetail detail
	INNER JOIN wag.Payroll payroll ON payroll.ID = detail.PayrollID
	INNER JOIN pbl.EmployeeDetail emp ON emp.ID = detail.EmployeeID
	--INNER JOIN law.Law law ON law.ID = payroll.LawID
	--INNER JOIN org.Description org ON org.ID = Payroll.OrganID
	--INNER JOIN wag.WageTitle wageTitle ON wageTitle.ID = detail.WageTitleID
	where (@EmployeeID IS NULL OR detail.EmployeeID = @EmployeeID)
		AND (@Month IS NULL OR  payroll.Month = @Month)
		AND (@Year IS NULL OR  payroll.Year = @Year)

	SET @Result = @@ROWCOUNT

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollEmployee') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployee
GO

CREATE PROCEDURE wag.spGetPayrollEmployee
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Result INT = 0

	SELECT
		PayrollEmployee.ID,
		PayrollEmployee.PayrollID, 
		PayrollEmployee.EmployeeID, 
		--e.ServiceYears,
	--	e.ServiceYearsType,
		e.EducationDegree,
		e.EmploymentType,
		--e.JobBase,
		ped.Salary,
		ped.Continuous,
		ped.NonContinuous,
		ped.Reward,
		ped.Welfare,
		ped.Other,
		ped.Deductions,
		PayrollEmployee.SumPayments,
		PayrollEmployee.SumDeductions,
		PayrollEmployee.SumPayments -PayrollEmployee.SumDeductions [Sum],
		PayrollEmployee.SumHokm,
		ped.SumNHokm,
		ped.DayCount,
		Payroll.OrganID,
		Payroll.RequestID,
		organ.Name OrganName,
		Payroll.LawID,
		Law.Name LawName,
		Payroll.[Year],
		Payroll.[Month],
		Payroll.[PayrollType],
		trd.FirstName,
		trd.LastName,
	--	EmployeeDetail.FatherName,
		---EmployeeDetail.BCNumber,
		trd.Gender,
		trd.NationalCode,
		trd.[BudgetCode],
	--	EmployeeDetail.BirthDate BirthDate,
		EmployeePost.PostTitle,
		EmployeePost.Number PostNumber
		--COALESCE(detail.FirstName, ind.FirstName) COLLATE Arabic_CI_AS FirstName,
		--COALESCE(detail.LastName, ind.LastName) COLLATE Arabic_CI_AS LastName,
		--COALESCE(detail.FatherName, ind.FatherName)  COLLATE Arabic_CI_AS FatherName,
		--COALESCE(detail.BCNumber, ind.BCNumber)  COLLATE Arabic_CI_AS BCNumber,
		--COALESCE(detail.Gender, ind.Gender) Gender,
		--COALESCE(detail.NationalCode, ind.NationalCode) COLLATE Arabic_CI_AS NationalCode,
		--COALESCE(detail.BirthDate, ind.BirthDate) BirthDate,
		--COALESCE(ind.isaargar, 0),
	--	Employee.[State]
	FROM wag.PayrollEmployee
	INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID=PayrollEmployee.ID
	INNER JOIN wag.Payroll ON payroll.ID = PayrollEmployee.PayrollID
	INNER JOIN Law.Law ON Law.ID = Payroll.LawID
	INNER JOIN wag.TreasuryRequestDetail trd ON trd.EmployeeID = PayrollEmployee.EmployeeID and trd.PayrollID=PayrollEmployee.PayrollID
	LEFT JOIN emp.Employee e ON e.ID = PayrollEmployee.EmployeeID
	LEFT JOIN org.Department organ ON Payroll.OrganID = organ.ID
	LEFT JOIN PBL.EmployeePost ON EmployeePost.PostID=ped.PostID
	--LEFT JOIN pbl.Individual ind ON ind.[Guid] = emp.IndividualID
	WHERE PayrollEmployee.ID = @ID

	SET @Result = @@ROWCOUNT

    RETURN @Result 
END 
GO
USE [Kama.Aro.Pardakht]
GO
/****** Object:  StoredProcedure [wag].[spGetPayrollEmployeeExcel]    Script Date: 11/10/2021 12:25:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [wag].[spGetPayrollEmployeeExcel]
	@APayrollID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AEmployeeID UNIQUEIDENTIFIER,
	@AYear INT,
	@AMonth INT,
	@ANationalCode VARCHAR(10),
	@AName NVARCHAR(1000),
	@APostLevel TINYINT,
	@APostLevelFrom TINYINT,
	@APostLevelTo TINYINT,
	@AEducationDegree TINYINT,
	@AJobBase TINYINT,
	@ASumFrom INT,
	@ASumTo INT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID,
		@Year INT = COALESCE(@AYear, 0),
		@Month INT = COALESCE(@AMonth, 0),
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@PostLevelFrom TINYINT = COALESCE(@APostLevelFrom , 0),
		@PostLevelTo TINYINT =  COALESCE(@APostLevelTo, 0),
		@EducationDegree  TINYINT = COALESCE(@AEducationDegree, 0),
		@JobBase TINYINT= COALESCE(@AJobBase, 0),
		@SumFrom INT = @ASumFrom,
		@SumTo INT = @ASumTo,
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF COALESCE(@CurrentUserOrganID, 0x) = 0x
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
     SELECT BudgetCode, 
            OrganName, 
            ProvinceName, 
            MainOrganName, 
            LawName, 
            Minimum, 
            Maximum, 
            Average, 
            EmployeesCount, 
			PaknaEmployeesCount,
            ConfirmDateTime, 
            CreationDate, 
            TotalPayment, 
            InvalidSalaryCount,
			Month
     FROM wag.PayrollEmployeeExcelReport
     WHERE  (@PayrollID IS NULL OR PayrollID = @PayrollID)
			AND (@LawID IS NULL OR LawID = @LawID)
			AND (@OrganID IS NULL OR OrganID = @OrganID)
			AND (@Year < 1 OR [Year] = @Year)
			AND (@Month < 1 OR [Month] = @Month)
		   	ORDER BY OrganName asc,LawName asc,  [Year] desc,[Month] asc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
END 
GO
USE [Kama.Aro.Salary]
GO

IF OBJECT_ID('wag.spGetPayrollEmployeeExcel') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployeeExcel
GO

CREATE PROCEDURE wag.spGetPayrollEmployeeExcel
	@APayrollID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AEmployeeID UNIQUEIDENTIFIER,
	@AYear INT,
	@AMonth INT,
	@ANationalCode VARCHAR(10),
	@AName NVARCHAR(1000),
	@APostLevel TINYINT,
	@APostLevelFrom TINYINT,
	@APostLevelTo TINYINT,
	@AEducationDegree TINYINT,
	@AJobBase TINYINT,
	@ASumFrom INT,
	@ASumTo INT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID,
		@Year INT = COALESCE(@AYear, 0),
		@Month INT = COALESCE(@AMonth, 0),
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@PostLevelFrom TINYINT = COALESCE(@APostLevelFrom , 0),
		@PostLevelTo TINYINT =  COALESCE(@APostLevelTo, 0),
		@EducationDegree  TINYINT = COALESCE(@AEducationDegree, 0),
		@JobBase TINYINT= COALESCE(@AJobBase, 0),
		@SumFrom INT = @ASumFrom,
		@SumTo INT = @ASumTo,
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF COALESCE(@CurrentUserOrganID, 0x) = 0x
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
		
    SELECT BudgetCode, 
       OrganName, 
       ProvinceName, 
       MainOrganName, 
       LawName, 
       Minimum, 
       Maximum, 
       Average, 
       EmployeesCount, 
       ConfirmDateTime, 
       CreationDate, 
       TotalPayment, 
       InvalidSalaryCount, 
       Month
FROM wag.PayrollEmployeeExcelReport
     WHERE  PayrollID = @PayrollID
		   	ORDER BY Month 
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollEmployees') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployees
GO

CREATE PROCEDURE wag.spGetPayrollEmployees
	@APayrollEmployeeID UNIQUEIDENTIFIER,
	@APayrollID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AEmployeeID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER,
	@AYear INT,
	@AMonth INT,
	@ANationalCode VARCHAR(10),
	@ABudgetCode VARCHAR(20),
	@AName NVARCHAR(1000),
	@APostLevel TINYINT,
	@APostLevelFrom TINYINT,
	@APostLevelTo TINYINT,
	@AEducationDegree TINYINT,
	@AJobBase TINYINT,
	@ASumFrom INT,
	@ASumTo INT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN

    DECLARE 
		@PayrollEmployeeID UNIQUEIDENTIFIER = @APayrollEmployeeID,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@BudgetCode VARCHAR(20) = @ABudgetCode ,
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@Year INT = COALESCE(@AYear, 0),
		@Month INT = COALESCE(@AMonth, 0),
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@PostLevelFrom TINYINT = COALESCE(@APostLevelFrom , 0),
		@PostLevelTo TINYINT =  COALESCE(@APostLevelTo, 0),
		@EducationDegree  TINYINT = COALESCE(@AEducationDegree, 0),
		@JobBase TINYINT= COALESCE(@AJobBase, 0),
		@SumFrom INT = @ASumFrom,
		@SumTo INT = @ASumTo,
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF COALESCE(@CurrentUserOrganID, 0x) = 0x
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH Post
     AS (SELECT PostTitle, 
                Number, 
                PostID
         FROM pbl.EmployeePost
         GROUP BY PostTitle, 
                  Number, 
                  PostID
				  )	
	,MainSelect AS
	(
		SELECT DISTINCT
			PayrollEmployee.ID,
			PayrollEmployee.PayrollID, 
			Payroll.OrganID,
			Payroll.RequestID,
			Payroll.Year,
			Payroll.Month,
			Payroll.OrganName,
			Payroll.LawName,
			Payroll.[PayrollType],
			PayrollEmployee.EmployeeID, 
			trd.FirstName,
			trd.LastName,
			--EmployeeDetail.FatherName,
			--EmployeeDetail.BCNumber,
			trd.Gender,
			trd.NationalCode,
			trd.[BudgetCode],
			--Individual.BirthDate BirthDate,
			--PayrollEmployee.PostLevel,
			--PayrollEmployee.ServiceYears,
			--PayrollEmployee.ServiceYearsType,
			trd.EducationDegree,
			trd.EmploymentType,
			--PayrollEmployee.JobBase,
			ped.Salary,
			ped.Continuous,
			ped.NonContinuous,
			ped.Reward,
			ped.Welfare,
			ped.Other,
			ped.Deductions,
			PayrollEmployee.SumPayments,
			PayrollEmployee.SumDeductions,
		    PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions	[Sum],
			PayrollEmployee.SumHokm,
			ped.SumNHokm,
			ped.DayCount,
			ped.PlaceFinancing,
			ISNULL(EmployeePost.PostTitle,'') AS  PostTitle,
			ISNULL(EmployeePost.Number,'') AS PostNumber
		FROM wag._Payroll Payroll
			INNER JOIN wag.PayrollEmployee ON Payroll.ID = PayrollEmployee.PayrollID
			INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID = PayrollEmployee.ID
			INNER JOIN wag.TreasuryRequestDetail trd ON trd.EmployeeID = PayrollEmployee.EmployeeID and trd.PayrollID = PayrollEmployee.PayrollID and trd.[BudgetCode] = ped.[BudgetCode] and trd.PlaceFinancing = ped.PlaceFinancing
			LEFT JOIN Post EmployeePost ON EmployeePost.PostID=ped.PostID
			LEFT JOIN emp.Employee e ON e.ID = PayrollEmployee.EmployeeID
			--LEFT JOIN [org].[Individual] Individual ON Individual.ID = e.IndividualID
		WHERE (@APayrollEmployeeID IS NULL OR PayrollEmployee.ID = @APayrollEmployeeID)
			--(@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
			 AND (@EmployeeID IS NULL OR payrollEmployee.EmployeeID = @EmployeeID)
		--	AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
			--AND (@PostLevelFrom < 1 OR PayrollEmployee.PostLevel >= @PostLevelFrom)
			--AND (@PostLevelTo < 1 OR PayrollEmployee.PostLevel < @PostLevelTo)
			AND (@EducationDegree < 1 OR e.EducationDegree = @EducationDegree)
			--AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
			--AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
			AND (@Name is null OR trd.FirstName like N'%' + @Name +'%' OR trd.LastName like N'%' + @Name +'%')
			AND (@NationalCode is null OR trd.NationalCode = @NationalCode)
			--AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
			AND (@SumFrom IS NULL OR PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions >= @SumFrom)
			AND (@SumTo IS NULL OR PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions <= @SumTo)
			AND (@PayrollID IS NULL OR Payroll.ID = @PayrollID)
			AND (@RequestID IS NULL OR trd.RequestID = @RequestID)
			AND (@BudgetCode is null OR trd.BudgetCode=@BudgetCode)
			--AND (@LawID IS NULL OR Payroll.LawID = @LawID)
			--AND (@OrganID IS NULL OR Payroll.OrganID = @OrganID)
			--AND (@Year < 1 OR [Year] = @Year)
			--AND (@Month < 1 OR [Month] = @Month)
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY EmployeeID -- LastName, [Year] DESC, [Month] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE)

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollEmployeesByPayroll') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployeesByPayroll
GO

CREATE PROCEDURE wag.spGetPayrollEmployeesByPayroll
	@APayrollID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER,
	@AEmployeeID UNIQUEIDENTIFIER,
	@AYear INT,
	@AMonth INT,
	@ANationalCode VARCHAR(10),
	@AName NVARCHAR(1000),
	@APostLevel TINYINT,
	@APostLevelFrom TINYINT,
	@APostLevelTo TINYINT,
	@AEducationDegree TINYINT,
	@AJobBase TINYINT,
	@ASumFrom INT,
	@ASumTo INT,
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@EmployeeID UNIQUEIDENTIFIER = @AEmployeeID,
		@Year INT = COALESCE(@AYear, 0),
		@Month INT = COALESCE(@AMonth, 0),
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@PostLevel TINYINT = COALESCE(@APostLevel, 0),
		@PostLevelFrom TINYINT = COALESCE(@APostLevelFrom , 0),
		@PostLevelTo TINYINT =  COALESCE(@APostLevelTo, 0),
		@EducationDegree  TINYINT = COALESCE(@AEducationDegree, 0),
		@JobBase TINYINT= COALESCE(@AJobBase, 0),
		@SumFrom INT = @ASumFrom,
		@SumTo INT = @ASumTo,
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF COALESCE(@CurrentUserOrganID, 0x) = 0x
		SET @ParentOrganNode = '/'
	ELSE 	
		SET @ParentOrganNode = (SELECT Node FROM org.Department WHERE ID = @CurrentUserOrganID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH PayrollEmployee AS
	(
		SELECT 
			PayrollEmployee.ID,
			PayrollID, 
			EmployeeID, 
		--	PostLevel,
			--ServiceYears,
			--ServiceYearsType,
			e.EducationDegree,
			e.EmploymentType,
			SumPayments,
			--JobBase,
			SumDeductions,
			SumPayments-SumDeductions [Sum]
		FROM wag.PayrollEmployee
		INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID = PayrollEmployee.ID
		LEFT JOIN emp.Employee e ON e.ID = PayrollEmployee.EmployeeID
		WHERE 
			PayrollID = @PayrollID
	)
	, MainSelect AS
	(
		select 
			PayrollEmployee.*,
			EmployeeDetail.FirstName,
			EmployeeDetail.LastName,
			EmployeeDetail.FatherName,
			EmployeeDetail.BCNumber,
			EmployeeDetail.Gender,
			EmployeeDetail.NationalCode,
			EmployeeDetail.BirthDate BirthDate
		FROM PayrollEmployee 
	     	
			INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = PayrollEmployee.EmployeeID
		WHERE
		--	(@CurrentUserPositionType <> 51 OR PayrollEmployee.PostLevel <= 28)   -- کاربر دستگاه نظارتی
			 (@EmployeeID IS NULL OR payrollEmployee.EmployeeID = @EmployeeID)
			--AND (@PostLevel < 1 OR PayrollEmployee.PostLevel = @PostLevel)
			--AND (@PostLevelFrom < 1 OR PayrollEmployee.PostLevel >= @PostLevelFrom)
			--AND (@PostLevelTo < 1 OR PayrollEmployee.PostLevel < @PostLevelTo)
			AND (@EducationDegree < 1 OR PayrollEmployee.EducationDegree = @EducationDegree)
			--AND (@EmploymentType < 1 OR PayrollEmployee.EmploymentType = @EmploymentType)
			--AND (@ServiceYearsType < 1 OR PayrollEmployee.ServiceYearsType = @ServiceYearsType)
			--AND (@JobBase < 1 OR PayrollEmployee.JobBase = @JobBase)
			AND (@SumFrom IS NULL OR PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions  >= @SumFrom)
			AND (@SumTo IS NULL OR PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions  <= @SumTo)
			--AND (@CurrentUserID <> NEWID() OR PayrollEmployee.PostLevel <= 2 OR PayrollEmployee.PostLevel BETWEEN 10 AND 28)
			AND (@NationalCode IS NULL OR EmployeeDetail.NationalCode = @NationalCode)
			AND (@Name IS NULL OR EmployeeDetail.FirstName LIKE CONCAT('%', @Name, '%') OR EmployeeDetail.LastName LIKE CONCAT('%', @Name, '%'))
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY LastName, FirstName
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollEmployeesByPayrollIDs') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployeesByPayrollIDs
GO

CREATE PROCEDURE wag.spGetPayrollEmployeesByPayrollIDs
	@APayrollIDs NVARCHAR(MAX),
	@APostLevels NVARCHAR(MAX),
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollIDs NVARCHAR(MAX) = @APayrollIDs,
		@PostLevels NVARCHAR(MAX) = @APostLevels,
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@Result INT = 0,
	    @ParentOrganNode HIERARCHYID

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH MainSelect AS
	(
		SELECT 
			PayrollEmployee.ID,
			PayrollEmployee.PayrollID, 
			Payroll.OrganID,
			Payroll.Year,
			Payroll.Month,
			Payroll.OrganName,
			Payroll.LawName,
			PayrollEmployee.EmployeeID, 
			EmployeeDetail.FirstName,
			EmployeeDetail.LastName,
			EmployeeDetail.FatherName,
			EmployeeDetail.BCNumber,
			EmployeeDetail.Gender,
			EmployeeDetail.NationalCode,
			EmployeeDetail.BirthDate BirthDate,
		--	PayrollEmployee.PostLevel,
			--PayrollEmployee.ServiceYears,
			--PayrollEmployee.ServiceYearsType,
			e.EducationDegree,
			e.EmploymentType,
			--PayrollEmployee.JobBase,
			ped.Salary,
			ped.Continuous,
			ped.NonContinuous,
			ped.Reward,
			ped.Welfare,
			ped.Other,
			ped.Deductions,
			PayrollEmployee.SumPayments,
			PayrollEmployee.SumDeductions,
			PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions [Sum]
		FROM wag._Payroll Payroll
			INNER JOIN OPENJSON(@PayrollIDs) PayrollIDs ON PayrollIDs.value = Payroll.ID
			INNER JOIN wag.PayrollEmployee ON Payroll.ID = PayrollEmployee.PayrollID
			INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = PayrollEmployee.EmployeeID
			INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID = PayrollEmployee.ID
		    LEFT JOIN emp.Employee e ON e.ID = PayrollEmployee.EmployeeID
		WHERE Payroll.LastState = 100
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY LastName, [Year] DESC, [Month] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollEmployeesForCalculate') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployeesForCalculate
GO

CREATE PROCEDURE wag.spGetPayrollEmployeesForCalculate
	@APayrollID UNIQUEIDENTIFIER,
	@AAllEmployees bit,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
	@AllEmployees bit=@AAllEmployees,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)
	
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
			SELECT 
			PayrollEmployee.ID,
			PayrollEmployee.PayrollID, 
			Payroll.OrganID,
			Payroll.Year,
			Payroll.Month,
			Payroll.OrganName,
			Payroll.LawName,
			PayrollEmployee.EmployeeID, 
			EmployeeDetail.FirstName,
			EmployeeDetail.LastName,
			EmployeeDetail.FatherName,
			EmployeeDetail.BCNumber,
			EmployeeDetail.Gender,
			EmployeeDetail.NationalCode,
			EmployeeDetail.BirthDate BirthDate,
			--PayrollEmployee.PostLevel,
			--PayrollEmployee.ServiceYears,
			--PayrollEmployee.ServiceYearsType,
			e.EducationDegree,
			e.EmploymentType,
			--PayrollEmployee.JobBase,
			ped.Salary,
			ped.Continuous,
			ped.NonContinuous,
			ped.Reward,
			ped.Welfare,
			ped.Other,
			ped.Deductions,
			PayrollEmployee.SumPayments,
			PayrollEmployee.SumDeductions,
			PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions [Sum],
			PayrollEmployee.SumHokm,
			ped.SumNHokm
		FROM wag._Payroll Payroll
			INNER JOIN wag.PayrollEmployee ON Payroll.ID = PayrollEmployee.PayrollID
			INNER JOIN pbl.EmployeeDetail on EmployeeDetail.ID = PayrollEmployee.EmployeeID
			INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID = PayrollEmployee.ID
		    LEFT JOIN emp.Employee e ON e.ID = PayrollEmployee.EmployeeID
		WHERE 
		(Payroll.ID = @PayrollID)
		AND (@AllEmployees =1 or (@AllEmployees =0 and PayrollEmployee.SumHokm is null) )  
	ORDER BY EmployeeID 
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollEmployeesToValidatePayrollExcel') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployeesToValidatePayrollExcel
GO

CREATE PROCEDURE wag.spGetPayrollEmployeesToValidatePayrollExcel
	@ATreasuryRequestID UNIQUEIDENTIFIER
	--@ANationalCodes VARCHAR(10),
--WITH ENCRYPTION
AS
BEGIN

    DECLARE 
		@TreasuryRequestID UNIQUEIDENTIFIER = @ATreasuryRequestID

	SELECT 
		Payroll.LawName,
		e.NationalCode
	FROM wag._Payroll Payroll
		INNER JOIN wag.PayrollEmployee pe ON Payroll.ID = pe.PayrollID
		LEFT JOIN emp.Employee e ON e.ID = pe.EmployeeID
	WHERE Payroll.RequestID = @TreasuryRequestID
		AND payroll.PayrollType = 1  -- جاری
	GROUP BY Payroll.LawName,
		e.NationalCode
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollEmployeesWithoutEmployeeInfo') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollEmployeesWithoutEmployeeInfo
GO

CREATE PROCEDURE wag.spGetPayrollEmployeesWithoutEmployeeInfo
	@APayrollIDs NVARCHAR(MAX),
	@APostLevels NVARCHAR(MAX),
	@ACurrentUserOrganID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollIDs NVARCHAR(MAX) = @APayrollIDs,
		@PostLevels NVARCHAR(MAX) = @APostLevels,
		@CurrentUserOrganID UNIQUEIDENTIFIER = @ACurrentUserOrganID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	
	;WITH MainSelect AS
	(
		SELECT 
			PayrollEmployee.ID,
			PayrollEmployee.PayrollID, 
			Payroll.Year,
			Payroll.Month,
			Payroll.OrganID,
			Organ.Name OrganName,
			Law.Name LawName,
			PayrollEmployee.EmployeeID, 
			--EmployeeDetail.FirstName,
			--EmployeeDetail.LastName,
			--EmployeeDetail.FatherName,
			--EmployeeDetail.BCNumber,
			--EmployeeDetail.Gender,
			--EmployeeDetail.NationalCode,
			--EmployeeDetail.BirthDate BirthDate,
			--PayrollEmployee.PostLevel,
			--PayrollEmployee.ServiceYears,
			--PayrollEmployee.ServiceYearsType,
			--PayrollEmployee.EducationDegree,
			--PayrollEmployee.EmploymentType,
			--PayrollEmployee.JobBase,
			ped.Salary,
			ped.Continuous,
			ped.NonContinuous,
			ped.Reward,
			ped.Welfare,
			ped.Other,
			ped.Deductions,
			PayrollEmployee.SumPayments,
			PayrollEmployee.SumDeductions,
			PayrollEmployee.SumPayments-PayrollEmployee.SumDeductions [Sum]
		FROM wag.PayrollEmployee
		    INNER JOIN wag.PayrollEmployeeDetail ped ON ped.ID=PayrollEmployee.ID
			INNER JOIN wag.Payroll ON Payroll.ID = PayrollEmployee.PayrollID
			INNER JOIN law.Law ON Law.ID = Payroll.LawID
			INNER JOIN org.Department organ ON organ.ID = Payroll.OrganID
			INNER JOIN OPENJSON(@PayrollIDs) PayrollIDs ON PayrollIDs.value = PayrollEmployee.PayrollID
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY [Year] DESC, [Month] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeletePayrollExcellError') IS NOT NULL
    DROP PROCEDURE wag.spDeletePayrollExcellError
GO

CREATE PROCEDURE wag.spDeletePayrollExcellError
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID

	BEGIN TRY
		BEGIN TRAN
			
			Update [wag].[PayrollExcellError]
			SET
				[RemoverUserID] = @RemoverUserID,
				[RemoverPositionID] = @ARemoverPositionID,
				[RemoveDate] = GETDATE()
			WHERE [ID] = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollExcelError') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollExcelError
GO

CREATE PROCEDURE wag.spGetPayrollExcelError 
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		[ID],
		[Code],
		[Subject],
		[Type],
		[ErrorText],
		[CreatorUserID],
		[CreationDate],
		[Enable],
		[Deployed]
	FROM [wag].[PayrollExcellError]
	WHERE [ID] = @ID

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollExcelErrorByCode') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollExcelErrorByCode
GO

CREATE PROCEDURE wag.spGetPayrollExcelErrorByCode 
	@ACode VARCHAR(10)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@Code VARCHAR(10) = @ACode

	SELECT 
		[ID],
		[Code],
		[Subject],
		[Type],
		[ErrorText],
		[CreatorUserID],
		[CreationDate],
		[Enable],
		[Deployed]
	FROM [wag].[PayrollExcellError]
	WHERE (@Code IS NULL OR [Code] LIKE '%' + @Code + '%')

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrolExcelErrors') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrolExcelErrors
GO

CREATE PROCEDURE wag.spGetPayrolExcelErrors
	@ACode VARCHAR(10),
	@ASubject TINYINT,
	@AType TINYINT,
	@AEnable BIT,
	@ADeployed BIT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@Code VARCHAR = LTRIM(RTRIM(@ACode)),
		@Subject TINYINT = COALESCE(@ASubject, 0),
		@Type TINYINT = COALESCE(@AType, 0),
		@Enable TINYINT = COALESCE(@AEnable, 0),
		@Deployed TINYINT = COALESCE(@ADeployed, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;With MainSelect AS
	(
		SELECT 
			[ID],
			[Code],
			[Subject],
			[Type],
			[ErrorText],
			[CreatorUserID],
			[CreationDate],
			[Enable],
			[Deployed]
		FROM [wag].[PayrollExcellError]
		WHERE (([RemoveDate] IS NULL)
			AND (@Code IS NULL OR [Code] LIKE '%' + @Code + '%')
			AND (@Type < 1 OR @Type = [Type])
			AND (@Subject < 1 OR @Subject = [Subject])
			AND (@Enable < 1 OR @Enable = [Enable] - 1 )
			AND (@Deployed < 1 OR @Deployed = [Deployed] - 1 )
			)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Code]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollExcelErrorsForExcelProcess') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollExcelErrorsForExcelProcess
GO

CREATE PROCEDURE wag.spGetPayrollExcelErrorsForExcelProcess 
	
AS
BEGIN
    SET NOCOUNT ON;
	
	SELECT 
		[ID],
		[Code],
		[Subject],
		[Type],
		[ErrorText],
		[CreatorUserID],
		[CreationDate],
		[Enable],
		[Deployed]
	FROM [wag].[PayrollExcellError]

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyPayrollExcelError') IS NOT NULL
    DROP PROCEDURE wag.spModifyPayrollExcelError
GO

CREATE PROCEDURE wag.spModifyPayrollExcelError
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ASubject TINYINT,
	@AType TINYINT,
	@AErrorText NVARCHAR(4000),
	@ACreatorUserID UNIQUEIDENTIFIER,
	@AEnable BIT,
	@ADeployed BIT,
	@ACode VARCHAR(6) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Subject TINYINT = ISNULL(@ASubject, 1),
		@Type TINYINT = ISNULL(@AType, 1),
		@ErrorText NVARCHAR(4000) = LTRIM(RTRIM(@AErrorText)),
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@Enable BIT = COALESCE(@AEnable, 0),
		@Deployed BIT = COALESCE(@ADeployed, 0),
		@Result INT = 0,
		@Code VARCHAR(10)


	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- Insert
			BEGIN
				SET @Code = (SELECT MAX(Code) FROM [wag].[PayrollExcellError] WHERE [Subject] = @Subject) + 5

				INSERT INTO [wag].[PayrollExcellError]
					([ID], [Code], [Subject], [Type], [ErrorText], [CreatorUserID], [CreationDate], [Enable], [Deployed], [RemoverUserID], [RemoverPositionID], [RemoveDate])
				VALUES
					(@ID, @Code, @Subject, @Type, @ErrorText, @CreatorUserID, GETDATE(), @Enable, @Deployed, NULL, NULL, NULL)

			END
			ELSE
			BEGIN  -- Update

				UPDATE [wag].[PayrollExcellError]
				SET 
					[Type] = @Type,
					[ErrorText] = @ErrorText,
					[Deployed] = @Deployed
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeletePayrollExcellErrorDetail') IS NOT NULL
    DROP PROCEDURE wag.spDeletePayrollExcellErrorDetail
GO

CREATE PROCEDURE wag.spDeletePayrollExcellErrorDetail
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN
			
			DELETE FROM [wag].[PayrollExcellErrorDetail]
			WHERE [ID] = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollExcellErrorDetail') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollExcellErrorDetail
GO

CREATE PROCEDURE wag.spGetPayrollExcellErrorDetail 
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		ErrorDetail.[ID],
		ErrorDetail.[PayrollExcellErrorID],
		ExcellError.[Code],
		ExcellError.[Subject],
		ExcellError.[Type],
		ExcellError.[ErrorText],
		ErrorDetail.[RequestID],
		Request.[OrganID],
		Organ.[Name] [OrganName],
		Organ.ProvinceID,
		Organ.[Type] [DepartmentType],
		Organ.OrganType [OrganType],
		Request.[SubOrganID],
		SubOrgan.[Name] [SubOrganName],
		Request.[Type] AS [TreasuryRequestType],
		Request.[Month],
		Request.[Year],
		ErrorDetail.[PayrollID],
		Payroll.[PayrollType],
		ErrorDetail.[ExcelRow],
		ErrorDetail.[WageTitleCodes],
		ErrorDetail.[NationalCode]
	FROM [wag].[PayrollExcellErrorDetail] ErrorDetail
		INNER JOIN [wag].[PayrollExcellError] ExcellError ON ExcellError.[ID] = ErrorDetail.[PayrollExcellErrorID]
		INNER JOIN [wag].[TreasuryRequest] Request ON Request.[ID] = ErrorDetail.[RequestID]
		LEFT JOIN [org].[Department] Organ ON Organ.[ID] = Request.[OrganID]
		LEFT JOIN [org].[Department] SubOrgan ON SubOrgan.[ID] = Request.[SubOrganID]
		LEFT JOIN [wag].[Payroll] Payroll ON Payroll.[ID] = ErrorDetail.[PayrollID]
	WHERE ErrorDetail.[ID] = @ID

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollExcellErrorDetails') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollExcellErrorDetails
GO

CREATE PROCEDURE wag.spGetPayrollExcellErrorDetails
	@ARequestID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@APayrollID UNIQUEIDENTIFIER,
	@ACode VARCHAR(10),
	@AWageTitleCodes NVARCHAR(4000),
	@ANationalCode CHAR(10),
	@ASubject TINYINT,
	@AType TINYINT,
	@AMonth TINYINT,
	@AYear SMALLINT,
	@APayrollType TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@RequestID VARCHAR = @ARequestID,
		@OrganID VARCHAR = @AOrganID,
		@PayrollID VARCHAR = @APayrollID,
		@Code VARCHAR(10) = LTRIM(RTRIM(@ACode)),
		@WageTitleCodes NVARCHAR = LTRIM(RTRIM(@AWageTitleCodes)),
		@NationalCode CHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Subject TINYINT = COALESCE(@ASubject, 0),
		@Type TINYINT = COALESCE(@AType, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@Year SMALLINT = COALESCE(@AYear, 0),
		@PayrollType TINYINT = COALESCE(@APayrollType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;With MainSelect AS
	(
		SELECT 
			ErrorDetail.[ID],
			ExcellError.[Code],
			ExcellError.[Subject],
			ExcellError.[Type],
			ErrorDetail.[PayrollExcellErrorID],
			ExcellError.[ErrorText],
			ErrorDetail.[RequestID],
			Request.[OrganID],
			Organ.[Name] [OrganName],
			Organ.ProvinceID,
			Organ.[Type] [DepartmentType],
			Organ.OrganType [OrganType],
			Request.[SubOrganID],
			SubOrgan.[Name] [SubOrganName],
			Request.[Type] AS [TreasuryRequestType],
			Request.[Month],
			Request.[Year],
			ErrorDetail.[PayrollID],
			Payroll.[PayrollType],
			ErrorDetail.[ExcelRow],
			ErrorDetail.[WageTitleCodes],
			ErrorDetail.[NationalCode]
		FROM [wag].[PayrollExcellErrorDetail] ErrorDetail
			INNER JOIN [wag].[PayrollExcellError] ExcellError ON ExcellError.[ID] = ErrorDetail.[PayrollExcellErrorID]
			INNER JOIN [wag].[TreasuryRequest] Request ON Request.[ID] = ErrorDetail.[RequestID]
			LEFT JOIN [org].[Department] Organ ON Organ.[ID] = Request.[OrganID]
			LEFT JOIN [org].[Department] SubOrgan ON SubOrgan.[ID] = Request.[SubOrganID]
			LEFT JOIN [wag].[Payroll] Payroll ON Payroll.[ID] = ErrorDetail.[PayrollID]
		WHERE ( (@ARequestID IS NULL OR ErrorDetail.[RequestID] = @ARequestID)
			AND (@OrganID IS NULL OR Request.[OrganID] = @OrganID)
			AND (@PayrollID IS NULL OR ErrorDetail.[PayrollID] = @PayrollID)
			AND (@Code IS NULL OR ExcellError.[Code] LIKE '%' + @Code + '%')
			AND (@WageTitleCodes IS NULL OR ErrorDetail.[WageTitleCodes] LIKE '%' + @WageTitleCodes + '%')
			AND (@NationalCode IS NULL OR ErrorDetail.[NationalCode] LIKE '%' + @NationalCode + '%')
			AND (@Type < 1 OR @Type = ExcellError.[Type])
			AND (@Subject < 1 OR @Subject = ExcellError.[Subject])
			AND (@PayrollType < 1 OR @PayrollType = Payroll.[PayrollType])
			AND (@Month < 1 OR @Month = Request.[Month])
			AND (@Year < 1 OR @Year = Request.[Year])
			)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Code]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyPayrollExcelErrorDetail') IS NOT NULL
    DROP PROCEDURE wag.spModifyPayrollExcelErrorDetail
GO

CREATE PROCEDURE wag.spModifyPayrollExcelErrorDetail
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APayrollExcellErrorID UNIQUEIDENTIFIER,
	@ARequestID UNIQUEIDENTIFIER,
	@APayrollID UNIQUEIDENTIFIER,
	@AExcelRow INT,
	@AWageTitleCodes NVARCHAR(4000),
	@ANationalCode CHAR(10)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PayrollExcellErrorID UNIQUEIDENTIFIER = @APayrollExcellErrorID,
		@RequestID UNIQUEIDENTIFIER = @ARequestID,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@ExcelRow INT = COALESCE(@AExcelRow, 0),
		@WageTitleCodes NVARCHAR(4000) = LTRIM(RTRIM(@AWageTitleCodes)),
		@NationalCode CHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Result INT = 0


	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- Insert
			BEGIN

				INSERT INTO [wag].[PayrollExcellErrorDetail]
					([ID], [PayrollExcellErrorID], [RequestID], [PayrollID], [ExcelRow], [WageTitleCodes], [NationalCode])
				VALUES
					(@ID , @PayrollExcellErrorID , @RequestID , @PayrollID ,@ExcelRow , @WageTitleCodes, @NationalCode )

			END
			ELSE
			BEGIN  -- Update

				UPDATE [wag].[PayrollExcellErrorDetail]
				SET 
					[PayrollExcellErrorID] = @PayrollExcellErrorID,
					[RequestID] = @RequestID,
					[PayrollID] = @PayrollID,
					[ExcelRow] = @ExcelRow,
					[WageTitleCodes] = @WageTitleCodes,
					[NationalCode] = @NationalCode
				WHERE [ID] = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollWageTitles') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollWageTitles
GO

CREATE PROCEDURE wag.spGetPayrollWageTitles
	@APayrollID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @PayrollID UNIQUEIDENTIFIER = @APayrollID
	
	SELECT
		pwt.ID,
		pwt.PayrollID,
		pwt.WageTitleID,
		pwt.[Order],
		pwt.[Type],
		pwt.Code,
		pwt.[Name],
		pwt.OrderType,
		pwt.IncomeType,
		pwt.ParentCode,
		pwt.ParentName,
		pwt.WageTitleGroupID
	FROM wag._PayrollWageTitle pwt
	WHERE pwt.PayrollID = @PayrollID 
	ORDER BY pwt.PayrollID, pwt.ParentCode
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetPayrollWageTitlesByPayrollIDs') IS NOT NULL
    DROP PROCEDURE wag.spGetPayrollWageTitlesByPayrollIDs
GO

CREATE PROCEDURE wag.spGetPayrollWageTitlesByPayrollIDs
	@APayrollIDs NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollIDs NVARCHAR(MAX) = @APayrollIDs
	
	SELECT
		pwt.ID,
		pwt.PayrollID,
		pwt.WageTitleID,
		pwt.[Order],
		pwt.[Type],
		pwt.Code,
		pwt.[Name],
		pwt.OrderType,
		pwt.IncomeType,
		pwt.ParentCode,
		pwt.ParentName,
		pwt.WageTitleGroupID
	FROM wag._PayrollWageTitle pwt
		INNER JOIN OPENJSON(@PayrollIDs) PayrollIDs ON PayrollIDs.value = pwt.PayrollID
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spUpdatePayrollWageTitles') IS NOT NULL
    DROP PROCEDURE wag.spUpdatePayrollWageTitles
GO

CREATE PROCEDURE wag.spUpdatePayrollWageTitles
	@APayrollID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ALawID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LawID UNIQUEIDENTIFIER = @ALawID

	BEGIN TRY
		BEGIN TRAN
			
			DELETE wag.PayrollWageTitle WHERE PayrollID = @PayrollID

			INSERT INTO wag.PayrollWageTitle
			(ID, PayrollID, WageTitleID, [Order], OrderType,WageTitleGroupID)
			SELECT 
				NEWID(), 
				@PayrollID PayrollID, 
				WageTitleID, 
				[Order],
				[OrderType],
				WageTitleGroupID
			FROM wag.LawWageTitle
			WHERE OrganID = @OrganID 
				AND LawID = @LawID

			-- return type wage titles
			INSERT INTO wag.PayrollWageTitle
			(ID, PayrollID, WageTitleID, [Order], OrderType,WageTitleGroupID)
			SELECT 
				NEWID(), 
				@PayrollID PayrollID, 
				WageTitle.ID WageTitleID,
				1 [Order],
				3 [OrderType],
				0x WageTitleGroupID
			FROM wag.WageTitle
			WHERE WageTitle.Type = 12     --بازگشتی_سهم_دولت_و_کارفرما
				
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.Procedures WHERE [object_id] = OBJECT_ID('wag.spCreatePayrollWarnings'))
    DROP PROCEDURE wag.spCreatePayrollWarnings
GO

CREATE PROCEDURE wag.spCreatePayrollWarnings  
	@APayrollWarnings NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@PayrollWarnings NVARCHAR(MAX) = LTRIM(RTRIM(@APayrollWarnings))

	BEGIN TRY
		BEGIN TRAN

			IF @PayrollWarnings IS NOT NULL
			BEGIN

				INSERT INTO [wag].[PayrollWarning]
				(
					[ID], 
					[PayrollID], 
					[NationalCode], 
					[ErrorLine], 
					[ErrorDescriptions], 
					[CreateDateTime]
				)
				SELECT 
					NEWID(), 
					tblJson.[PayrollID], 
					tblJson.[NationalCode], 
					tblJson.[ErrorLine], 
					tblJson.[ErrorDescriptions], 
					GETDATE()
				FROM OPENJSON(@PayrollWarnings)
				WITH
				(
					[PayrollID] UNIQUEIDENTIFIER, 
					[NationalCode] NVARCHAR(10), 
					[ErrorLine] NVARCHAR(50), 
					[ErrorDescriptions] NVARCHAR(200)
				) tblJson
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW 
	END CATCH

    RETURN @@ROWCOUNT 
END 

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeletePayrollWarning'))
	DROP PROCEDURE wag.spDeletePayrollWarning
GO

CREATE PROCEDURE wag.spDeletePayrollWarning
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN
			DELETE wag.PayrollWarning
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetPayrollWarning'))
	DROP PROCEDURE wag.spGetPayrollWarning
GO

CREATE PROCEDURE wag.spGetPayrollWarning
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		[ID]
      ,[PayrollID]
      ,[NationalCode]
      ,[ErrorLine]
      ,[ErrorDescriptions]
      ,[CreateDateTime]
	FROM wag.PayrollWarning 
	WHERE ID = @ID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetPayrollWarnings'))
DROP PROCEDURE wag.spGetPayrollWarnings
GO

CREATE PROCEDURE wag.spGetPayrollWarnings
	@APayrollID UNIQUEIDENTIFIER,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			count(*) over() Total,
			 pw.[ID]
			,pw.[PayrollID]
			,pw.[NationalCode]
			,pw.[ErrorLine]
			,pw.[ErrorDescriptions]
			,pw.[CreateDateTime]
			,ed.FirstName FirstName
			,ed.LastName LastName
	FROM wag.PayrollWarning pw
        INNER JOIN [pbl].[EmployeeDetail] ed ON ed.NationalCode=pw.NationalCode
		WHERE (@PayrollID IS NULL OR PayrollID = @PayrollID)
				)
	SELECT * FROM MainSelect
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spModifyPayrollWarning'))
	DROP PROCEDURE wag.spModifyPayrollWarning
GO

CREATE PROCEDURE wag.spModifyPayrollWarning
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APayrollID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@AErrorLine NVARCHAR(50),
	@AErrorDescriptions NVARCHAR(200)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PayrollID UNIQUEIDENTIFIER = @APayrollID,
		@NationalCode NVARCHAR(10) = @ANationalCode,
		@ErrorLine NVARCHAR(50) = @AErrorLine,
		@ErrorDescriptions NVARCHAR(200) = LTRIM(RTRIM(@AErrorDescriptions))

	BEGIN TRY
		BEGIN TRAN
		
			INSERT INTO [wag].[PayrollWarning]
           ([ID],[PayrollID],[NationalCode],[ErrorLine],[ErrorDescriptions],[CreateDateTime])
				VALUES
				(@ID, @PayrollID, @NationalCode, @ErrorLine, @ErrorDescriptions,GETDATE())
			--END
			--ELSE    -- update
			--BEGIN
			--	UPDATE wag.PayrollWarning
			--	SET OrganID = @OrganID, [Year] = @Year, [Month] = @Month, PublishUrl = @PublishUrl, CreatorUserID = @CreatorUserID
			--	WHERE ID = @ID
			--END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spConfirmRecomendedWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spConfirmRecomendedWageTitle
GO

CREATE PROCEDURE wag.spConfirmRecomendedWageTitle  
	@ARecomendedWageTitleID UNIQUEIDENTIFIER,
	@AConfirmerUserID UNIQUEIDENTIFIER,
	@AConfirmType TINYINT,
	@AConfirmComment NVARCHAR(1000),
	@ACode VARCHAR(6) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@RecomendedWageTitleID UNIQUEIDENTIFIER = @ARecomendedWageTitleID,
		@ConfirmerUserID UNIQUEIDENTIFIER = @AConfirmerUserID,
		@ConfirmType TINYINT = COALESCE(@AConfirmType, 1),
		@ConfirmComment NVARCHAR(1000) = LTRIM(RTRIM(@AConfirmComment)),
		@Code VARCHAR(6),
		@WageTitleID UNIQUEIDENTIFIER,
		@Type TINYINT,
		@IncomeType TINYINT,
		@Name NVARCHAR(1000)

	IF EXISTS(SELECT 1 FROM wag.RecomendedWageTitle 
			  WHERE ID = @RecomendedWageTitleID AND ConfirmUserID IS NOT NULL)
		THROW 60110, N'این قلم قبلا تأیید شده است.', 1;

	BEGIN TRY
		BEGIN TRAN

			SELECT @IncomeType = IncomeType
				, @Name = [Name]
			FROM wag.RecomendedWageTitle WHERE ID = @RecomendedWageTitleID

			IF @ConfirmType = 2    -- تایید
			BEGIN
				SET @WageTitleID = NEWID()
				EXEC wag.spModifyWageTitle @AIsNewRecord = 1
				, @AID = @WageTitleID
				, @AType = 2
				, @AIncomeType = @IncomeType
				, @AName = @Name
				, @AEnabled = 1
				, @ACode = Code
			END
			
			UPDATE wag.RecomendedWageTitle
			SET ConfirmWageTitleID = @WageTitleID
				, ConfirmUserID = @ConfirmerUserID
				, ConfirmType = @ConfirmType
				, ConfirmDate = GETDATE()
				, ConfirmComment = @ConfirmComment
			WHERE ID = @RecomendedWageTitleID AND
				  ConfirmUserID IS NULL

			SET @ACode = @Code

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeleteRecomendedWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spDeleteRecomendedWageTitle
GO

CREATE PROCEDURE wag.spDeleteRecomendedWageTitle  
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE @ID UNIQUEIDENTIFIER = @AID

	IF @ID IS NULL OR @ID = pbl.EmptyGuid()
		THROW 60200, N'شناسه قلم حقوقی مشخص نیست.', 1;

	IF EXISTS(SELECT 1 FROM wag.RecomendedWageTitle WHERE ID = @ID AND ConfirmUserID IS NOT NULL)
		THROW 60201, N'قلم حقوقی تأیید شده، قابل حذف نمی باشد.', 2;

	BEGIN TRY
		BEGIN TRAN
			DELETE FROM wag.RecomendedWageTitle
			WHERE ID = @ID
			 
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetRecomendedWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spGetRecomendedWageTitle
GO

CREATE PROCEDURE wag.spGetRecomendedWageTitle  
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT rwt.ID,
		rwt.OrganID,
		org.Name OrganName,
		rwt.CreatorUserID,
		cusr.FirstName + ' ' + cusr.LastName CreatorName,
		confirmerUser.FirstName + ' ' + confirmerUser.LastName ConfirmerName,
		rwt.CreationDate,
		rwt.[Name],
		rwt.[Comment],
		rwt.ConfirmWageTitleID,
		rwt.ConfirmUserID,
		rwt.ConfirmType,
		rwt.ConfirmDate,
		rwt.ConfirmComment,
		rwt.IncomeType,
		rwt.LawID,
		Law.[Name] LawName
	FROM wag.RecomendedWageTitle rwt
	INNER JOIN org.Department org on rwt.OrganID = org.ID
	INNER JOIN org.[User] cusr On cusr.ID = rwt.CreatorUserID
	LEFT JOIN org.[User] confirmerUser On confirmerUser.ID = rwt.ConfirmUserID
	LEFT JOIN law.Law ON Law.Id = rwt.LawID
	WHERE rwt.ID = @ID

	RETURN @@ROWCOUNT
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetRecomendedWageTitles') IS NOT NULL
    DROP PROCEDURE wag.spGetRecomendedWageTitles
GO

CREATE PROCEDURE wag.spGetRecomendedWageTitles  
	@AOrganID UNIQUEIDENTIFIER,
    @AConfirmType TINYINT,
	@AIncomeType TINYINT,
	@AName NVARCHAR(1500),
	@ALawID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ALawName NVARCHAR(1500),
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ConfirmType TINYINT = COALESCE(@AConfirmType, 0),
		@IncomeType TINYINT = COALESCE(@AIncomeType, 0),
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@LawName NVARCHAR(1500) = LTRIM(RTRIM(@ALawName)),
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT count(*) over() Total,
		rwt.ID,
		rwt.OrganID,
		org.Name OrganName,
		rwt.CreatorUserID,
		cusr.FirstName + ' ' + cusr.LastName CreatorName,
		confirmerUser.FirstName + ' ' + confirmerUser.LastName ConfirmerName,
		org.[Name] DepartmentName,
		org.ID DepatmentID,
		rwt.CreationDate,
		rwt.[Name],
		rwt.[Comment],
		rwt.ConfirmWageTitleID,
		rwt.ConfirmUserID,
		rwt.ConfirmType,
		rwt.ConfirmDate,
		rwt.ConfirmComment,
		rwt.IncomeType,
		rwt.LawID,
		Law.[Name] LawName
	FROM wag.RecomendedWageTitle rwt
	INNER JOIN org.Department org on rwt.OrganID = org.ID
	INNER JOIN org.[User] cusr On cusr.ID = rwt.CreatorUserID
	LEFT JOIN org.[User] confirmerUser On confirmerUser.ID = rwt.ConfirmUserID
	LEFT JOIN law.Law ON Law.Id = rwt.LawID
	WHERE (@OrganID IS NULL OR OrganID = @OrganID) 
		AND (@ConfirmType < 1 OR ConfirmType = @ConfirmType)
		AND (@AIncomeType < 1 OR IncomeType = @IncomeType)
		AND (@Name IS NULL OR rwt.[Name] LIKE CONCAT('%' , @Name , '%'))
		AND (@LawName IS NULL OR Law.[Name] LIKE CONCAT('%' , @LawName , '%'))
		AND (@DepartmentID IS NULL OR org.ID =  @DepartmentID)
		AND (@LawID IS NULL OR LawID = @LawID)
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

	RETURN @@ROWCOUNT
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyRecomendedWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spModifyRecomendedWageTitle
GO

CREATE PROCEDURE wag.spModifyRecomendedWageTitle  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ACreatorUserID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1500),
	@AComment NVARCHAR(1000),
	@AIncomeType TINYINT,
	@ALawID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@Comment NVARCHAR(1000) = LTRIM(RTRIM(@AComment)),
		@IncomeType TINYINT = @AIncomeType,     --1:Pardakhti	2:Kosoorat
		@LawID UNIQUEIDENTIFIER = @ALawID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO wag.RecomendedWageTitle
				(ID, OrganID, CreatorUserID, CreationDate, [IncomeType], [Name], Comment, ConfirmType, LawID)
				VALUES
				(@ID, @OrganID, @CreatorUserID, GETDATE(), @IncomeType, @Name, @Comment, 1, @LawID)
			END
			ELSE -- update
				UPDATE wag.RecomendedWageTitle
				SET @IncomeType = @IncomeType,
					[Name] = @Name,
					LawID = @LawID,
					Comment = @Comment
				WHERE ID = @ID
			 
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeleteSalaryItem'))
	DROP PROCEDURE wag.spDeleteSalaryItem
GO

CREATE PROCEDURE wag.spDeleteSalaryItem
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER,
	@ARemoverPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID,
		@RemoverPositionID UNIQUEIDENTIFIER = @ARemoverPositionID
				
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE wag.SalaryItem
			SET RemoverUserID = @RemoverUserID,
				RemoverPositionID = @RemoverPositionID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetSalaryItem') IS NOT NULL
    DROP PROCEDURE wag.spGetSalaryItem
GO

CREATE PROCEDURE wag.spGetSalaryItem 
	@AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		SI.[ID],
		SI.[Name],
		SI.[Code],
		SI.[Type],
		SI.[TreasuryItemID],
		TI.[Name] TreasuryItemName,
		TI.[Code] TreasuryItemCode,
		SI.[Enable],
		SI.[Comment],
		SI.[CreationDate],
		SI.[CreatorUserID],
		CU.FirstName + N' ' + CU.LastName CreatorName,
		SI.[CreatorPositionID],
		SI.[LastModificationDate],
		SI.[LastModifierUserID],
		MU.FirstName + N' ' + MU.LastName LastModifierName,
		SI.[LastModifierPositionID],
		SI.[RemoveDate],
		SI.[RemoverUserID],
		RU.FirstName + N' ' + RU.LastName LastModifierName,
		SI.[RemoverPositionID]
	FROM [wag].[SalaryItem] SI
	INNER JOIN [wag].[TreasuryItem] TI ON TI.ID = SI.[TreasuryItemID]
	LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = SI.CreatorUserID
	LEFT JOIN [Kama.Aro.Organization].[org].[User] MU ON CU.ID = SI.LastModifierUserID
	LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON CU.ID = SI.RemoverUserID
	WHERE SI.ID = @ID

END
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetSalaryItems') IS NOT NULL
    DROP PROCEDURE wag.spGetSalaryItems
GO

CREATE PROCEDURE wag.spGetSalaryItems 
    @AIDs NVARCHAR(MAX),
    @ATreasuryItemIDs NVARCHAR(MAX),
    @AEnableState TINYINT,
    @APaymentRuleIDs NVARCHAR(MAX),
    @ATypes NVARCHAR(MAX),
    @AGetTotalCount BIT,
    @ASortExp NVARCHAR(MAX),
    @APageSize INT,
    @APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @IDs NVARCHAR(MAX) =TRIM(@AIDs),
        @TreasuryItemIDs NVARCHAR(MAX) =TRIM(@ATreasuryItemIDs),
        @EnableState INT = COALESCE(@AEnableState, 0),
		@PaymentRuleIDs NVARCHAR(MAX) = TRIM(@APaymentRuleIDs),
		@Types NVARCHAR(MAX) = TRIM(@ATypes),
        @GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
        @SortExp NVARCHAR(MAX) = TRIM(@ASortExp),
        @PageSize INT = COALESCE(@APageSize, 20),
        @PageIndex INT = COALESCE(@APageIndex, 0);

    IF @PageIndex = 0 
    BEGIN
        SET @PageSize = 10000000;
        SET @PageIndex = 1;
    END
	; WITH SIPaymentRules AS(
		SELECT 
			COUNT(PRSI.ID) CountPaymentRule,
			[SalaryItemID]
		FROM [law].[PaymentRuleSalaryItem] PRSI
		WHERE (PRSI.RemoveDate IS NULL)
		GROUP BY [SalaryItemID]
	) 
    , MainSelect AS
    (
        SELECT DISTINCT
			SI.[ID],
			SI.[Name],
			SI.[Code],
			SI.[Type],
			SI.[TreasuryItemID],
			TI.[Name] TreasuryItemName,
			TI.[Code] TreasuryItemCode,
			SI.[Enable],
			SI.[Comment],
			SIPaymentRules.CountPaymentRule,
			SI.[CreationDate],
			SI.[CreatorUserID],
			CU.FirstName + N' ' + CU.LastName CreatorName,
			SI.[CreatorPositionID],
			SI.[LastModificationDate],
			SI.[LastModifierUserID],
			MU.FirstName + N' ' + MU.LastName LastModifierName,
			SI.[LastModifierPositionID]
		FROM [wag].[SalaryItem] SI
			INNER JOIN [wag].[TreasuryItem] TI ON TI.ID = SI.[TreasuryItemID]
			LEFT JOIN [law].[PaymentRuleSalaryItem] PRSI ON PRSI.SalaryItemID = SI.ID
			LEFT JOIN SIPaymentRules ON SIPaymentRules.SalaryItemID = SI.ID
			LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = SI.ID
			LEFT JOIN OPENJSON(@TreasuryItemIDs) TreasuryItemIDs ON TreasuryItemIDs.value = SI.[TreasuryItemID]
			LEFT JOIN OPENJSON(@Types) Typs ON Typs.value = SI.[Type]
			LEFT JOIN OPENJSON(@PaymentRuleIDs) PaymentRuleIDs ON PaymentRuleIDs.value = PRSI.PaymentRuleID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] CU ON CU.ID = SI.CreatorUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] MU ON MU.ID = SI.LastModifierUserID
			LEFT JOIN [Kama.Aro.Organization].[org].[User] RU ON CU.ID = SI.RemoverUserID
        WHERE (SI.[RemoveDate] IS NULL)
			AND (@IDs IS NULL OR IDs.value = SI.ID)
			AND (@TreasuryItemIDs IS NULL OR TreasuryItemIDs.value = SI.[TreasuryItemID])
			AND (@PaymentRuleIDs IS NULL OR PaymentRuleIDs.value = PRSI.PaymentRuleID)
			AND (@Types IS NULL OR Typs.value = SI.[Type])
    )
    ,Total AS
    (
        SELECT COUNT(*) AS Total FROM MainSelect
        WHERE @GetTotalCount = 1
    )
    SELECT * FROM MainSelect, Total
    ORDER BY [CreationDate]
    OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
    OPTION (RECOMPILE);

END 

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifySalaryItem') IS NOT NULL
    DROP PROCEDURE wag.spModifySalaryItem
GO

CREATE PROCEDURE wag.spModifySalaryItem
    @AIsNewRecord BIT,
    @AID UNIQUEIDENTIFIER,
    @AName NVARCHAR(500),
    @AType TINYINT,
    @ATreasuryItemID UNIQUEIDENTIFIER,
    @AEnable BIT,
    @AComment NVARCHAR(MAX),
    @AModifierUserID UNIQUEIDENTIFIER,
    @AModifierPositionID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
        @IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
        @ID UNIQUEIDENTIFIER = @AID,
        @Name NVARCHAR(500) = TRIM(@AName),
        @Type TINYINT = COALESCE(@AType, 0),
        @TreasuryItemID UNIQUEIDENTIFIER = @ATreasuryItemID,
        @Enable BIT = ISNULL(@AEnable, 0),
        @Comment NVARCHAR(MAX) = @AComment,
        @ModifierUserID UNIQUEIDENTIFIER = @AModifierUserID,
        @ModifierPositionID UNIQUEIDENTIFIER = @AModifierPositionID,
        @Code VARCHAR(20)

    BEGIN TRY
        BEGIN TRAN
            IF @IsNewRecord = 1 -- insert
            BEGIN
                SET @Code = CAST((COALESCE((SELECT MAX(CAST([Code] AS INT)) FROM [Kama.Aro.Pardakht].[wag].[SalaryItem]), 0) + 1) AS VARCHAR(20))
                INSERT INTO [wag].[SalaryItem]
                ([ID], [Code], [Name], [Type], [TreasuryItemID], [Enable], [Comment], [CreationDate], [CreatorUserID], [CreatorPositionID],
                 [LastModificationDate], [LastModifierUserID], [LastModifierPositionID])
                VALUES
                (@ID, @Code, @Name, @Type, @TreasuryItemID, @Enable, @Comment, GETDATE(), @ModifierUserID, @ModifierPositionID,
                 GETDATE(), @ModifierUserID, @ModifierPositionID)
            END
            ELSE -- update
            BEGIN 

                UPDATE [wag].[SalaryItem]
                SET --[Code] = @Code,
                    [Name] = @Name,
                    [Type] = @Type,
                    [TreasuryItemID] = @TreasuryItemID,
                    [Enable] = @Enable,
                    [Comment] = @Comment,
                    [LastModificationDate] = GETDATE(),
                    [LastModifierUserID] = @ModifierUserID,
                    [LastModifierPositionID] = @ModifierPositionID
                WHERE ID = @ID

            END

        COMMIT
    END TRY
    BEGIN CATCH
        ROLLBACK
        ;THROW
    END CATCH
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spDeleteSalaryPublish'))
	DROP PROCEDURE wag.spDeleteSalaryPublish
GO

CREATE PROCEDURE wag.spDeleteSalaryPublish
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN
			DELETE wag.SalaryPublish
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetSalaryPublish'))
	DROP PROCEDURE wag.spGetSalaryPublish
GO

CREATE PROCEDURE wag.spGetSalaryPublish
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		sp.ID,
		sp.OrganID,
		Organ.Name OrganName,
		sp.[Year],
		sp.[Month],
		sp.PublishUrl,
		sp.CreatorUserID,
		sp.CreationDate
	FROM wag.SalaryPublish sp
		INNER JOIN org.Department Organ On Organ.ID = sp.OrganID
	WHERE sp.ID = @ID
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spGetSalaryPublishs'))
DROP PROCEDURE wag.spGetSalaryPublishs
GO

CREATE PROCEDURE wag.spGetSalaryPublishs
	@AOrganID UNIQUEIDENTIFIER,
	@AYear INT,
	@AMonth TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@Year INT = COALESCE(@AYear, 0),
		@Month TINYINT = COALESCE(@AMonth, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			count(*) over() Total,
			sp.ID,
			sp.OrganID,
			Organ.Name OrganName,
			sp.[Year],
			sp.[Month],
			sp.PublishUrl,
			sp.CreatorUserID,
			sp.CreationDate
		FROM wag.SalaryPublish sp
			INNER JOIN org.Department Organ On Organ.ID = sp.OrganID
		WHERE (@OrganID IS NULL OR sp.OrganID = @OrganID)
			AND (@Year < 1 OR sp.[Year] = @Year)
			AND (@Month < 1 OR sp.[Month] = @Month)
	)
	SELECT * FROM MainSelect
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Pardakht]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('wag.spModifySalaryPublish'))
	DROP PROCEDURE wag.spModifySalaryPublish
GO

CREATE PROCEDURE wag.spModifySalaryPublish
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@AYear INT,
	@AMonth TINYINT,
	@APublishUrl NVARCHAR(4000),
	@ACreatorUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@Year INT = @AYear,
		@Month TINYINT = @AMonth,
		@PublishUrl NVARCHAR(4000) = LTRIM(RTRIM(@APublishUrl)),
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO wag.SalaryPublish
				(ID, OrganID, [Year], [Month], PublishUrl, CreatorUserID, CreationDate)
				VALUES
				(@ID, @OrganID, @Year, @Month, @PublishUrl, @CreatorUserID, GETDATE())
			END
			ELSE    -- update
			BEGIN
				UPDATE wag.SalaryPublish
				SET OrganID = @OrganID, [Year] = @Year, [Month] = @Month, PublishUrl = @PublishUrl, CreatorUserID = @CreatorUserID
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spDeleteWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spDeleteWageTitle
GO

CREATE PROCEDURE wag.spDeleteWageTitle
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Type TINYINT,
		@Code INT

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE wag.WageTitle
			SET 
				[RemoverUserID] = @CurrentUserID,
				[RemoveDate] = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END		
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spGetWageTitle
GO

CREATE PROCEDURE wag.spGetWageTitle 
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		wageTitle.[ID], 
		wageTitle.[Code], 
		wageTitle.[Name], 
		wageTitle.[CreationDate], 
		wageTitle.[Type], 
		wageTitle.[IncomeType], 
		wageTitle.[Enabled], 
		wageTitle.[CurrentMinimum], 
		wageTitle.[CurrentMaximum], 
		wageTitle.[DelayedMinimum], 
		wageTitle.[DelayedMaximum], 
		wageTitle.[TreasuryItemID],
		wageTitle.SacrificialReturnWageTitleID,
		SacrificialReturnWageTitle.Name SacrificialReturnWageTitleName,
		treasuryItem.[Name] TreasuryItemName
	FROM wag.WageTitle
		LEFT JOIN wag.WageTitle SacrificialReturnWageTitle ON SacrificialReturnWageTitle.ID = WageTitle.SacrificialReturnWageTitleID
		LEFT JOIN wag.TreasuryItem ON wageTitle.TreasuryItemID = treasuryItem.ID
	WHERE wageTitle.ID = @ID

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetWageTitles') IS NOT NULL
    DROP PROCEDURE wag.spGetWageTitles
GO

CREATE PROCEDURE wag.spGetWageTitles 
	@AOrganIDs NVARCHAR(MAX),
	@ALawIDs NVARCHAR(MAX),
	@ACodes NVARCHAR(MAX),
	@AName NVARCHAR(100),
	@AType TINYINT,
	@ACode NVARCHAR(10),
	@AIncomeType TINYINT,
	@AEnabled TINYINT,
	@AFromCurrentMinimum BIGINT,
	@AToCurrentMinimum BIGINT,
	@AFromCurrentMaximum BIGINT,
	@AToCurrentMaximum BIGINT,
	@AFromDelayedMinimum BIGINT,
	@AToDelayedMinimum BIGINT,
	@AFromDelayedMaximum BIGINT,
	@AToDelayedMaximum BIGINT,
	@ATreasuryItemID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@OrganIDs NVARCHAR(MAX) = @AOrganIDs,
		@LawIDs NVARCHAR(MAX) = @ALawIDs,
		@Codes NVARCHAR(MAX) = @ACodes,
		@Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
		@Code NVARCHAR(10) = LTRIM(RTRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0),
		@IncomeType TINYINT = COALESCE(@AIncomeType , 0),
		@Enabled TINYINT = @AEnabled,
		@FromCurrentMinimum BIGINT = @AFromCurrentMinimum,
		@ToCurrentMinimum BIGINT = @AToCurrentMinimum,
		@FromCurrentMaximum BIGINT = @AFromCurrentMaximum,
		@ToCurrentMaximum BIGINT = @AToCurrentMaximum,
		@FromDelayedMinimum BIGINT = @AFromDelayedMinimum,
		@ToDelayedMinimum BIGINT = @AToDelayedMinimum,
		@FromDelayedMaximum BIGINT = @AFromDelayedMaximum,
		@ToDelayedMaximum BIGINT = @AToDelayedMaximum,
		@TreasuryItemID UNIQUEIDENTIFIER = @ATreasuryItemID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;With LawWageTitle AS
	(
		SELECT DISTINCT WageTitleID
		FROM wag.LawWageTitle
			LEFT JOIN OPENJSON(@OrganIDs) OrganIDs ON OrganIDs.value = LawWageTitle.OrganID
			LEFT JOIN OPENJSON(@LawIDs) LawIDs ON LawIDs.value = LawWageTitle.LawID
		WHERE
			(@OrganIDs is null OR OrganIDs.value = LawWageTitle.OrganID)
			AND (@LawIDs is null OR LawIDs.value = LawWageTitle.LawID)
	)
	, MainSelect AS
	(
		SELECT 
			WageTitle.ID,
			WageTitle.[Type],
			WageTitle.[Enabled],
			WageTitle.IncomeType,
			WageTitle.Code,
			WageTitle.[Name],
			WageTitle.[CurrentMinimum], 
			WageTitle.[CurrentMaximum], 
			WageTitle.[DelayedMinimum], 
			WageTitle.[DelayedMaximum], 
			WageTitle.TreasuryItemID,
			wageTitle.SacrificialReturnWageTitleID,
			SacrificialReturnWageTitle.Name SacrificialReturnWageTitleName,
			treasuryItem.[Name] TreasuryItemName
		FROM wag.WageTitle
			LEFT JOIN wag.WageTitle SacrificialReturnWageTitle ON SacrificialReturnWageTitle.ID = WageTitle.SacrificialReturnWageTitleID
			LEFT JOIN OPENJSON(@Codes) Codes ON Codes.value = WageTitle.Code
			LEFT JOIN LawWageTitle ON LawWageTitle.WageTitleID = WageTitle.ID
			LEFT JOIN [wag].[TreasuryItem] treasuryItem ON WageTitle.TreasuryItemID = treasuryItem.ID
		WHERE WageTitle.[RemoverUserID] IS NULL
			AND (@Name IS NULL OR WageTitle.[Name] LIKE '%' + @Name + '%')
			AND (@Code IS NULL OR WageTitle.Code LIKE '%' + @Code + '%')
			AND (@Type < 1 OR @Type = WageTitle.[Type])
			AND (@IncomeType < 1 OR WageTitle.IncomeType = @IncomeType)
			AND (@Enabled < 1 OR WageTitle.[Enabled] = @Enabled - 1 )
			AND (@FromCurrentMinimum IS NULL OR WageTitle.CurrentMinimum >= @FromCurrentMinimum)
			AND (@ToCurrentMinimum IS NULL OR WageTitle.CurrentMinimum <= @ToCurrentMinimum)
			AND (@FromCurrentMaximum IS NULL OR WageTitle.CurrentMaximum >= @FromCurrentMaximum)
			AND (@ToCurrentMaximum IS NULL OR WageTitle.CurrentMaximum <= @ToCurrentMaximum)
			AND (@FromDelayedMinimum IS NULL OR WageTitle.DelayedMinimum >= @FromDelayedMinimum)
			AND (@ToDelayedMinimum IS NULL OR WageTitle.DelayedMinimum <= @ToDelayedMinimum)
			AND (@FromDelayedMaximum IS NULL OR WageTitle.DelayedMaximum >= @FromDelayedMaximum)
			AND (@ToDelayedMaximum IS NULL OR WageTitle.DelayedMaximum <= @ToDelayedMaximum)
			AND ((@OrganIDs IS NULL AND @LawIDs IS NULL) OR LawWageTitle.WageTitleID = WageTitle.ID)
			AND (@Codes IS NULL OR Codes.value = WageTitle.Code)
			AND (@TreasuryItemID IS NULL OR WageTitle.TreasuryItemID = @TreasuryItemID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Type], [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyWageTitle') IS NOT NULL
    DROP PROCEDURE wag.spModifyWageTitle
GO

CREATE PROCEDURE wag.spModifyWageTitle
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AType TINYINT,   
	@AIncomeType TINYINT,
	@AName NVARCHAR(1500),
	@AEnabled BIT,
	@ACurrentMinimum BIGINT,
	@ACurrentMaximum BIGINT,
	@ADelayedMinimum BIGINT,
	@ADelayedMaximum BIGINT,
	@ATreasuryItemID UNIQUEIDENTIFIER,
	@ASacrificialReturnWageTitleID UNIQUEIDENTIFIER,
	@ACode VARCHAR(6) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@Type TINYINT = ISNULL(@AType, 1),
		@IncomeType TINYINT = ISNULL(@AIncomeType, 1),
		@Enabled BIT = COALESCE(@AEnabled, 0),
		@CurrentMinimum BIGINT = @ACurrentMinimum,
		@CurrentMaximum BIGINT = @ACurrentMaximum,
		@DelayedMinimum BIGINT = @ADelayedMinimum,
		@DelayedMaximum BIGINT = @ADelayedMaximum,
		@TreasuryItemID UNIQUEIDENTIFIER = @ATreasuryItemID,
		@SacrificialReturnWageTitleID UNIQUEIDENTIFIER = @ASacrificialReturnWageTitleID,
		@Result INT = 0,
		@Code VARCHAR(6),
		@DelayedID UNIQUEIDENTIFIER

	IF @Type = 0 
		SET @Type = 1

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				SET @Code = (SELECT MAX(Code) FROM wag.WageTitle) + 1

				INSERT INTO wag.WageTitle
				(ID, Code, [Name], [Type], IncomeType, [Enabled], [CurrentMinimum], [CurrentMaximum], [DelayedMinimum], [DelayedMaximum], TreasuryItemID, SacrificialReturnWageTitleID, CreationDate, [RemoverUserID], [RemoveDate])
				VALUES
				(@ID, @Code, @Name, @Type, @IncomeType, @Enabled, @CurrentMinimum, @CurrentMaximum, @DelayedMinimum, @DelayedMaximum, @TreasuryItemID, @SacrificialReturnWageTitleID, GETDATE(), NULL, NULL)

			END
			ELSE
			BEGIN 

				UPDATE wag.WageTitle
				SET [Name] = @Name,
					[Type] = @Type,
					IncomeType = @IncomeType,
					[Enabled] = @Enabled,
					CurrentMinimum = @CurrentMinimum,
					CurrentMaximum = @CurrentMaximum,
					DelayedMinimum = @DelayedMinimum,
					DelayedMaximum = @DelayedMaximum,
					TreasuryItemID = @TreasuryItemID,
					SacrificialReturnWageTitleID = @SacrificialReturnWageTitleID
				WHERE ID = @ID

			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetWageTitleGroup') IS NOT NULL
    DROP PROCEDURE wag.spGetWageTitleGroup
GO

CREATE PROCEDURE wag.spGetWageTitleGroup 
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		ID,
		Code,
		[Name],
		CreationDate,
		IncomeType,
		Minimum,
		Maximum
	FROM wag.WageTitleGroup
	WHERE WageTitleGroup.ID = @ID

END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spGetWageTitleGroups') IS NOT NULL
    DROP PROCEDURE wag.spGetWageTitleGroups
GO

CREATE PROCEDURE wag.spGetWageTitleGroups
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;With MainSelect AS
	(
		SELECT 
			ID,
			Code,
			[Name],
			CreationDate,
			IncomeType,
			Minimum,
			Maximum
		FROM wag.WageTitleGroup
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY Code
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END 
GO
USE [Kama.Aro.Pardakht]
GO

IF OBJECT_ID('wag.spModifyWageTitleGroup') IS NOT NULL
    DROP PROCEDURE wag.spModifyWageTitleGroup
GO

CREATE PROCEDURE wag.spModifyWageTitleGroup
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AIncomeType TINYINT,
	@AName NVARCHAR(1500),
	@AMinimum BIGINT,
	@AMaximum BIGINT,
	@ACode VARCHAR(6)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR(1500) = LTRIM(RTRIM(@AName)),
		@IncomeType TINYINT = ISNULL(@AIncomeType, 1),
		@Minimum BIGINT = @AMinimum,
		@Maximum BIGINT = @AMaximum,
		@Result INT = 0,
		@Code VARCHAR(6) = LTRIM(RTRIM(@ACode)),
		@DelayedID UNIQUEIDENTIFIER

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO [wag].[WageTitleGroup]
				(ID, Code, [Name], CreationDate, IncomeType, Minimum, Maximum)
				VALUES
				(@ID, @Code, @Name, GETDATE(), @IncomeType, @Minimum, @Maximum)
			END
			ELSE
			BEGIN 

				UPDATE [wag].[WageTitleGroup]
				SET Minimum = @Minimum,
					Maximum = @Maximum
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
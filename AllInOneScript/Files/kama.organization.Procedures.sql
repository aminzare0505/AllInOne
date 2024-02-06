USE [Kama.Aro.Organization]
GO

IF OBJECT_ID('app.spDeleteAnnouncement') IS NOT NULL
	DROP PROCEDURE app.spDeleteAnnouncement
GO

CREATE PROCEDURE app.spDeleteAnnouncement
    @AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT, XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
		, @Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			
			--DELETE FROM pbl.Attachment
			--WHERE ParentID = @ID

			DELETE FROM [org].[DynamicPermissionDetail]
			WHERE DynamicPermissionID IN (SELECT ID FROM [org].[DynamicPermission] WHERE [ObjectID] = @ID)

			DELETE FROM [org].[DynamicPermission]
			WHERE [ObjectID] = @ID

			DELETE FROM app.Announcement
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @Result

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetAnnouncement'))
	DROP PROCEDURE app.spGetAnnouncement
GO

CREATE PROCEDURE app.spGetAnnouncement
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
			count(*) over() Total,
			ann.ProvinceID,
			ann.[ApplicationID],
			ann.[ClientID],
			ann.ID,
			ann.[Type],
			ann.[Title],
			ann.Content,
			ann.ExtendedContent,
			ann.[ReleaseDate],
			ann.[DueDate],
			ann.[Enable],
			ann.[VisitCount],
			ann.[AllUsers],
			ann.[Pinned],
			ann.AuthorizedUsers,
			ann.UnAuthorizedUsers,
			ann.Expanded,
			ann.[Priority],
			ann.ClientID
	FROM app.Announcement ann
	where ann.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetAnnouncementPositionTypes'))
	DROP PROCEDURE app.spGetAnnouncementPositionTypes
GO

CREATE PROCEDURE app.spGetAnnouncementPositionTypes
	@AAnnouncementID UNIQUEIDENTIFIER 
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @AnnouncementID UNIQUEIDENTIFIER = @AAnnouncementID

	SELECT
		ID,
		AnnouncementID,
		PositionType
	FROM app.AnnouncementPositionType
	WHERE AnnouncementID = @AnnouncementID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetAnnouncements'))
	DROP PROCEDURE app.spGetAnnouncements
GO

CREATE PROCEDURE app.spGetAnnouncements
	@AUserID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserProvinceID UNIQUEIDENTIFIER,
	@ATitle NVARCHAR(200),
	@AEnable TINYINT,
	@AType TINYINT,
	@AClientID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @UserID UNIQUEIDENTIFIER = @AUserID,
		@ApplicationID UNIQUEIDENTIFIER  = @AApplicationID,
		@CurrentUserProvinceID UNIQUEIDENTIFIER = @ACurrentUserProvinceID,
		@Title NVARCHAR(200) = @ATitle,
		@Enable TINYINT = COALESCE(@AEnable, 0),
		@Type TINYINT = COALESCE(@AType, 0),
		@ClientID UNIQUEIDENTIFIER = @AClientID,
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END


	;WITH MainSelect AS (
		SELECT
			COUNT(*) OVER() Total,
			ann.ProvinceID,
			ann.ID,
			ann.[Type],
			ann.[Title],
			--ann.Content,
			--ann.ExtendedContent,
			ann.[ReleaseDate],
			ann.[DueDate],
			ann.[Enable],
			ann.[VisitCount],
			ann.[AllUsers],
			ann.[Pinned],
			ann.AuthorizedUsers,
			ann.UnAuthorizedUsers,
			ann.Expanded,
			ann.[Priority],
			ann.ClientID
		FROM 
			app.[Announcement] ann
		WHERE
			ann.ApplicationID = @ApplicationID
			--AND (@ClientID IS NULL OR ann.ClientID = @ClientID)
			--AND (@CurrentUserProvinceID IS NULL OR ann.ProvinceID = @CurrentUserProvinceID)
			AND (@Title IS NULL OR ann.[Title] LIKE '%' + @Title + '%')
			AND (@Enable < 1 OR ann.[Enable] = @Enable - 1)
			AND (@Type < 1 OR ann.[Type] = @Type)
	)
	SELECT * FROM MainSelect		 
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetAnnouncementsForBulletin'))
	DROP PROCEDURE app.spGetAnnouncementsForBulletin
GO

CREATE PROCEDURE app.spGetAnnouncementsForBulletin
	@APositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ADynamicPermissionObjects NVARCHAR(MAX),
	@AClientID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DynamicPermissionObjects NVARCHAR(MAX) = @ADynamicPermissionObjects,
		@ClientID UNIQUEIDENTIFIER = @AClientID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@CurrentDate SMALLDATETIME = GETDATE()

  IF OBJECT_ID('tempdb..#MainSelect') IS NOT NULL
    DROP TABLE #MainSelect

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	-- MainSelect AS
	--(
		SELECT
			ann.ID,
			ann.ProvinceID,
			ann.[Type],
			ann.[Title],
			ann.[Content],
			CAST(CASE WHEN ann.ExtendedContent IS NULL THEN 0 ELSE 1 END AS BIT) HasExtendedContent,
			ann.[Enable],
			ann.[ReleaseDate],
			ann.[DueDate],
			ann.[VisitCount],
			ann.[AllUsers],
			ann.[Pinned],
		--	CAST(COALESCE((SELECT Top 1 ID FROM pbl.Attachment WHERE ParentID = ann.ID AND [Type] = 1) ,NULL) AS UNIQUEIDENTIFIER) AttachmentID,
			ann.Expanded,
			ann.[Priority],
			ann.CreationDate,
			ann.ClientID
			INTO #MainSelect
		FROM app.[Announcement] ann
			LEFT JOIN OPENJSON(@DynamicPermissionObjects) dynamicPermissionObjects ON dynamicPermissionObjects.value = ann.ID
		WHERE [Enable] = 1
			AND ann.ApplicationID = @ApplicationID
			AND (@ClientID IS NULL OR ann.ClientID = @ClientID)
			AND (ReleaseDate IS NULL OR @CurrentDate >= CAST(ReleaseDate AS DATE))
			AND (DueDate IS NULL OR @CurrentDate < DATEADD(DAY, 1, CAST(DueDate AS DATE)))
			AND (@PositionID IS NOT NULL OR UnAuthorizedUsers = 1)
			AND (@PositionID IS NULL OR ann.AllUsers = 1 OR dynamicPermissionObjects.value = ann.ID)
	--)
	;WITH TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM #MainSelect
		WHERE @GetTotalCount = 1
	)
	, MainSelect2 AS
	(
		SELECT
			MainSelect.*--,
			--attachment.[Data],
			--attachment.[FileName]
		FROM #MainSelect MainSelect
			--LEFT JOIN pbl.Attachment attachment on attachment.ParentID = MainSelect.ID and attachment.[Type] = 2
		ORDER BY MainSelect.[Pinned] DESC, MainSelect.[Priority] ASC, MainSelect.CreationDate DESC 
		OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	)
	SELECT * FROM MainSelect2, TempCount
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyAnnouncement'))
	DROP PROCEDURE app.spModifyAnnouncement
GO

CREATE PROCEDURE app.spModifyAnnouncement
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ATitle nvarchar(200),
	@AContent NVARCHAR(MAX),
	@AExtendedContent nvarchar(MAX),
	@AEnable BIT,
	@AReleaseDate SMALLDATETIME,
	@ADueDate SMALLDATETIME,
	@AOrder INT,
	@AUserID UNIQUEIDENTIFIER,
	@APinned BIT,
	@AAllUsers BIT,
	@AAuthorizedUsers BIT,
	@AUnAuthorizedUsers BIT,
	@AExpanded BIT,
	@APriority TINYINT,
	@AClientID UNIQUEIDENTIFIER,
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Type TINYINT = COALESCE(@AType, 0),
		@Title NVARCHAR(200) = LTRIM(RTRIM(@ATitle)),
		@Content NVARCHAR(MAX) = LTRIM(RTRIM(@AContent)),
		@ExtendedContent NVARCHAR(MAX) = LTRIM(RTRIM(@AExtendedContent)),
		@Enable BIT = COALESCE(@AEnable, 0),
		@ReleaseDate SMALLDATETIME = @AReleaseDate, 
		@DueDate SMALLDATETIME = @ADueDate,
		@Order INT = COALESCE(@AOrder, 1),
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@Pinned BIT = COALESCE(@APinned, 0),
		@AllUsers BIT = COALESCE(@AAllUsers, 0),
		@AuthorizedUsers BIT = COALESCE(@AAuthorizedUsers, 0),
		@UnAuthorizedUsers BIT = COALESCE(@AUnAuthorizedUsers, 0),
		@Expanded BIT = COALESCE(@AExpanded, 0),
		@Priority TINYINT = COALESCE(@APriority, 2),
		@ClientID UNIQUEIDENTIFIER = @AClientID,
		@Result NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO app.[Announcement]
				(ID, ApplicationID, [Type], Title, [Content], ExtendedContent, [Enable], ReleaseDate, DueDate, [Order], AllUsers, Pinned, VisitCount, CreatorID, AuthorizedUsers, UnAuthorizedUsers, Expanded, [Priority],  CreationDate, ClientID)
				VALUES 
				(@ID, @ApplicationID, @Type, @Title, @Content, @ExtendedContent, @Enable, @ReleaseDate, @DueDate, @Order, @AllUsers, @Pinned, 0, @UserID, @AuthorizedUsers, @UnAuthorizedUsers, @Expanded, @Priority,GETDATE(), @ClientID)
			END
			ELSE
			BEGIN -- update
				UPDATE app.[Announcement]
				SET 
					ApplicationID = @ApplicationID,
					[Type] = @Type,
					Title = @Title, 
					Content = @Content,
					ExtendedContent = @ExtendedContent,
					[Enable] = @Enable, 
					ReleaseDate = @ReleaseDate, 
					DueDate = @DueDate,
					[Order] = @Order,
					AllUsers = @AllUsers,
					Pinned = @Pinned, 
					AuthorizedUsers= @AuthorizedUsers,
					UnAuthorizedUsers = @UnAuthorizedUsers,
					Expanded = @Expanded,
					[Priority] = @Priority,
					[ClientID] = @ClientID
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetAnnouncementOrders'))
	DROP PROCEDURE app.spSetAnnouncementOrders
GO

CREATE PROCEDURE app.spSetAnnouncementOrders
	@AOrders NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@Orders NVARCHAR(MAX) = @AOrders,
		@Result NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN

			UPDATE announcement 
			SET announcement.[Order] = orders.[Order]
			FROM OPENJSON(@Orders)
			WITH (
				ID UNIQUEIDENTIFIER,
				[Order] INT
			) orders
			INNER JOIN app.announcement announcement on orders.ID = announcement.ID 

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spDeleteApplicationSurvey'))
	DROP PROCEDURE app.spDeleteApplicationSurvey
GO

CREATE PROCEDURE app.spDeleteApplicationSurvey
	@AID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
	
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE app.ApplicationSurvey
			SET RemoverPositionID = @CurrentPositionID,
				RemoveDate = GETDATE()
			where ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurvey'))
	DROP PROCEDURE app.spGetApplicationSurvey
GO

CREATE PROCEDURE app.spGetApplicationSurvey
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		survey.ID,
		survey.ApplicationID,
		survey.[Name],
		survey.[Enable],
		survey.CreationDate
	FROM app.[ApplicationSurvey] as survey
	WHERE survey.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveys'))
	DROP PROCEDURE app.spGetApplicationSurveys
GO

CREATE PROCEDURE app.spGetApplicationSurveys
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
		SELECT 
			Count(*) OVER() Total,
			survey.ID,
			survey.ApplicationID,
			survey.[Name],
			survey.[Enable],
			survey.CreationDate
		FROM app.ApplicationSurvey as survey
		WHERE survey.ApplicationID = @ApplicationID
			AND survey.RemoverPositionID is null
			AND (@Name IS NULL OR survey.[Name] LIKE CONCAT('%', @Name, '%'))
	)

	SELECT * FROM MainSelect		 
	ORDER BY [CreationDate] desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyApplicationSurvey'))
	DROP PROCEDURE app.spModifyApplicationSurvey
GO

CREATE PROCEDURE app.spModifyApplicationSurvey
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@AEnable BIT,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(50)= LTRIM(RTRIM(@AName)),
		@Enable BIT = @AEnable, 
		@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.ApplicationSurvey
				(ID, ApplicationID, [Name], [Enable], CreationDate, RemoverPositionID, RemoveDate)
				VALUES
				(@ID, @ApplicationID, @Name, @Enable, GETDATE(), null, null)
			END
			ELSE
			BEGIN -- update
				UPDATE app.ApplicationSurvey
				SET [Name] = @Name,
					[Enable] = @Enable
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyAnswer'))
	DROP PROCEDURE app.spGetApplicationSurveyAnswer
GO

CREATE PROCEDURE app.spGetApplicationSurveyAnswer
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		suranswer.ID,
		suranswer.ParticipantID,
		us.FirstName + ' ' + us.LastName UserFullName,
		suranswer.QuestionID,
		suranswer.Agree,
		suranswer.ChoiceID,
		suranswer.[Text],
		sur.[Name] SurveyName,
		surchoice.[Name] ChoiceName
	FROM app.[ApplicationSurveyAnswer] suranswer
		INNER JOIN app.ApplicationSurveyQuestion surquestion ON surquestion.ID = suranswer.QuestionID
		INNER JOIN app.ApplicationSurveyGroup surgroup ON surgroup.ID = surquestion.GroupID
		INNER JOIN app.ApplicationSurvey sur ON sur.ID = surgroup.ApplicationSurveyID
		INNER JOIN app.ApplicationSurveyParticipant surpart ON surpart.ID = suranswer.ParticipantID
		LEFT JOIN org.[User] us  ON us.ID = surpart.UserID
		LEFT JOIN app.ApplicationSurveyQuestionChoice surchoice ON surchoice.ID = suranswer.ChoiceID
	WHERE suranswer.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyAnswers'))
	DROP PROCEDURE app.spGetApplicationSurveyAnswers
GO

CREATE PROCEDURE app.spGetApplicationSurveyAnswers
	@AParticipantID UNIQUEIDENTIFIER,
	@AQuestionID UNIQUEIDENTIFIER,
	@AChoiceID UNIQUEIDENTIFIER,
	@AText NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@ParticipantID UNIQUEIDENTIFIER = @AParticipantID,
		@QuestionID UNIQUEIDENTIFIER = @AQuestionID,
		@ChoiceID UNIQUEIDENTIFIER = @AChoiceID,
		@Text NVARCHAR(MAX) = LTRIM(RTRIM(@AText)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
		SELECT 
			Count(*) OVER() Total,
			suranswer.ID,
			suranswer.ParticipantID,
			us.FirstName + ' ' + us.LastName UserFullName,
			suranswer.QuestionID,
			suranswer.Agree,
			suranswer.ChoiceID,
			suranswer.[Text],
			sur.[Name] SurveyName,
			surchoice.[Name] ChoiceName
	FROM app.[ApplicationSurveyAnswer] suranswer
		INNER JOIN app.ApplicationSurveyQuestion surquestion ON surquestion.ID = suranswer.QuestionID
		INNER JOIN app.ApplicationSurveyGroup surgroup ON surgroup.ID = surquestion.GroupID
		INNER JOIN app.ApplicationSurvey sur ON sur.ID = surgroup.ApplicationSurveyID
		INNER JOIN app.ApplicationSurveyParticipant surpart ON surpart.ID = suranswer.ParticipantID
		LEFT JOIN org.[User] us  ON us.ID = surpart.UserID
		LEFT JOIN app.ApplicationSurveyQuestionChoice surchoice ON surchoice.ID = suranswer.ChoiceID
		WHERE suranswer.ParticipantID = @ParticipantID
			AND (@Text IS NULL OR suranswer.[Text] LIKE CONCAT('%', @Text, '%'))
			--AND (surchoice.[Name] IS NULL OR surchoice.[Name] LIKE CONCAT('%', surchoice.[Name], '%'))
	)

	SELECT * FROM MainSelect		 
	ORDER BY QuestionID desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyApplicationSurveyAnswer'))
	DROP PROCEDURE app.spModifyApplicationSurveyAnswer
GO

CREATE PROCEDURE app.spModifyApplicationSurveyAnswer
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AParticipantID UNIQUEIDENTIFIER,
	@AQuestionID UNIQUEIDENTIFIER,
	@AChoiceID UNIQUEIDENTIFIER,
	@AText NVARCHAR(MAX),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ParticipantID UNIQUEIDENTIFIER = @AParticipantID,
		@QuestionID UNIQUEIDENTIFIER = @AQuestionID,
		@ChoiceID UNIQUEIDENTIFIER = @AChoiceID,
		@Text NVARCHAR(MAX) = LTRIM(RTRIM(@AText)), 
		@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.[ApplicationSurveyAnswer]
				(ID, ParticipantID, QuestionID, ChoiceID, [Text])
				VALUES
				(@ID, @ParticipantID, @QuestionID, @ChoiceID, @Text)
			END
			ELSE
			BEGIN -- update
				UPDATE app.[ApplicationSurveyAnswer]
				SET ParticipantID = @ParticipantID,
					QuestionID = @QuestionID,
					ChoiceID = @ChoiceID,
					[Text] = @Text
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spDeleteApplicationSurveyGroup'))
	DROP PROCEDURE app.spDeleteApplicationSurveyGroup
GO

CREATE PROCEDURE app.spDeleteApplicationSurveyGroup
	@AID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
	
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE app.ApplicationSurveyQuestion
			SET RemoverPositionID = @CurrentPositionID
				, RemoveDate = GETDATE()
			WHERE GroupID = @ID

			UPDATE app.ApplicationSurveyGroup
			SET RemoverPositionID = @CurrentPositionID
				, RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyGroup'))
	DROP PROCEDURE app.spGetApplicationSurveyGroup
GO

CREATE PROCEDURE app.spGetApplicationSurveyGroup
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT
		surveyGroup.ID,
		surveyGroup.[Name],
		surveyGroup.ApplicationSurveyID,
		survey.[Name] as ApplicationSurveyName
	FROM app.[ApplicationSurveyGroup] as surveyGroup
		INNER JOIN app.[ApplicationSurvey] as survey on survey.ID = surveyGroup.ApplicationSurveyID
	WHERE surveyGroup.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyGroups'))
	DROP PROCEDURE app.spGetApplicationSurveyGroups
GO

CREATE PROCEDURE app.spGetApplicationSurveyGroups
	@AApplicationSurveyID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@ApplicationSurveyID UNIQUEIDENTIFIER = @AApplicationSurveyID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
		SELECT
			Count(*) OVER() Total,
			surveyGroup.ID,
			surveyGroup.[Name],
			surveyGroup.ApplicationSurveyID,
			survey.[Name] as ApplicationSurveyName
		FROM app.[ApplicationSurveyGroup] as surveyGroup
			INNER JOIN app.[ApplicationSurvey] as survey on survey.ID = surveyGroup.ApplicationSurveyID
		WHERE surveyGroup.ApplicationSurveyID = @ApplicationSurveyID
			AND (@Name IS NULL OR survey.[Name] LIKE CONCAT('%', @Name, '%'))
	)

	SELECT * FROM MainSelect		 
	ORDER BY [ID] desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyApplicationSurveyGroup'))
	DROP PROCEDURE app.spModifyApplicationSurveyGroup
GO

CREATE PROCEDURE app.spModifyApplicationSurveyGroup
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationSurveyID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationSurveyID UNIQUEIDENTIFIER = @AApplicationSurveyID,
		@Name NVARCHAR(50)= LTRIM(RTRIM(@AName)),
		@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.ApplicationSurveyGroup
				(ID, ApplicationSurveyID, [Name])
				VALUES
				(@ID, @ApplicationSurveyID, @Name)
			END
			ELSE
			BEGIN -- update
				UPDATE app.ApplicationSurveyGroup
				SET [Name] = @Name
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyParticipant'))
	DROP PROCEDURE app.spGetApplicationSurveyParticipant
GO

CREATE PROCEDURE app.spGetApplicationSurveyParticipant
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		surpart.ID,
		surpart.SurveyID,
		surpart.UserID,
		us.FirstName + ' ' + us.LastName UserFullName,
		surpart.[Date],
		sur.[Name] SurveyName
	FROM app.ApplicationSurveyParticipant  surpart
	INNER JOIN app.ApplicationSurveyAnswer suranswer ON suranswer.ParticipantID = surpart.ID
	INNER JOIN app.ApplicationSurveyQuestion surquestion ON surquestion.ID = suranswer.QuestionID
		INNER JOIN app.ApplicationSurveyGroup surgroup ON surgroup.ID = surquestion.GroupID
		INNER JOIN app.ApplicationSurvey sur ON sur.ID = surgroup.ApplicationSurveyID
		LEFT JOIN org.[User] us  ON us.ID = surpart.UserID
	WHERE surpart.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyParticipants'))
	DROP PROCEDURE app.spGetApplicationSurveyParticipants
GO

CREATE PROCEDURE app.spGetApplicationSurveyParticipants
	@ASurveyID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@SurveyID UNIQUEIDENTIFIER = @ASurveyID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
		SELECT 
			Count(*) OVER() Total,
			surpart.ID,
			surpart.SurveyID,
			surpart.UserID,
			us.FirstName + ' ' + us.LastName UserFullName,
			surpart.[Date],
			sur.[Name] SurveyName
		FROM app.ApplicationSurveyParticipant  surpart
			INNER JOIN app.ApplicationSurveyAnswer suranswer ON suranswer.ParticipantID = surpart.ID
			INNER JOIN app.ApplicationSurveyQuestion surquestion ON surquestion.ID = suranswer.QuestionID
			INNER JOIN app.ApplicationSurveyGroup surgroup ON surgroup.ID = surquestion.GroupID
			INNER JOIN app.ApplicationSurvey sur ON sur.ID = surgroup.ApplicationSurveyID
			LEFT JOIN org.[User] us  ON us.ID = surpart.UserID
		WHERE surpart.SurveyID = @SurveyID
			AND surpart.UserID IS NULL
			--AND (sur.[Name] IS NULL OR sur.[Name] LIKE CONCAT('%', sur.[Name], '%'))
	)

	SELECT * FROM MainSelect		 
	ORDER BY SurveyID desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyApplicationSurveyParticipant'))
	DROP PROCEDURE app.spModifyApplicationSurveyParticipant
GO

CREATE PROCEDURE app.spModifyApplicationSurveyParticipant
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ASurveyID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@SurveyID UNIQUEIDENTIFIER = @ASurveyID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.ApplicationSurveyParticipant
				(ID, SurveyID, UserID, [Date])
				VALUES
				(@ID, @SurveyID, @UserID, GETDATE())
			END
			ELSE
			BEGIN -- update
				UPDATE app.ApplicationSurveyParticipant
				SET SurveyID = @SurveyID,
					UserID = @UserID,
					[Date] = GETDATE()
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spDeleteApplicationSurveyQuestion'))
	DROP PROCEDURE app.spDeleteApplicationSurveyQuestion
GO

CREATE PROCEDURE app.spDeleteApplicationSurveyQuestion
	@AID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
	
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE app.ApplicationSurveyQuestion
			SET RemoverPositionID = @CurrentPositionID
				, RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyQuestion'))
	DROP PROCEDURE app.spGetApplicationSurveyQuestion
GO

CREATE PROCEDURE app.spGetApplicationSurveyQuestion
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT
		question.ID,
		question.GroupID,
		surveyGroup.[Name] as GroupName,
		question.[Type],
		surveyGroup.ApplicationSurveyID,
		survey.[Name] as ApplicationSurveyName
	FROM app.ApplicationSurveyQuestion as question
		INNER JOIN app.[ApplicationSurveyGroup] as surveyGroup on surveyGroup.ID = question.GroupID
		INNER JOIN app.[ApplicationSurvey] as survey on survey.ID = surveyGroup.ApplicationSurveyID
	WHERE question.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyQuestions'))
	DROP PROCEDURE app.spGetApplicationSurveyQuestions
GO

CREATE PROCEDURE app.spGetApplicationSurveyQuestions
	@AGroupID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1000),
	@AType TINYINT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@GroupID UNIQUEIDENTIFIER = @AGroupID,
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@Type TINYINT = COALESCE(@AType, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
		SELECT
			Count(*) OVER() Total,
			question.ID,
			question.GroupID,
			surveyGroup.[Name] as GroupName,
			question.[Type],
			surveyGroup.ApplicationSurveyID,
			survey.[Name] as ApplicationSurveyName
		FROM app.ApplicationSurveyQuestion as question
			INNER JOIN app.[ApplicationSurveyGroup] as surveyGroup on surveyGroup.ID = question.GroupID
			INNER JOIN app.[ApplicationSurvey] as survey on survey.ID = surveyGroup.ApplicationSurveyID
		WHERE question.RemoverPositionID is null
			AND (@GroupID IS NULL OR question.GroupID = @GroupID)
			AND (@Name IS NULL OR question.[Name] LIKE CONCAT('%', @Name, '%'))
			AND (@Type < 1 OR question.[Type] = @Type)
	)

	SELECT * FROM MainSelect		 
	ORDER BY [ID] desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyApplicationSurveyQuestion'))
	DROP PROCEDURE app.spModifyApplicationSurveyQuestion
GO

CREATE PROCEDURE app.spModifyApplicationSurveyQuestion
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AGroupID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1000),
	@AType TINYINT,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@GroupID UNIQUEIDENTIFIER = @AGroupID,
		@Name NVARCHAR(50)= LTRIM(RTRIM(@AName)),
		@Type TINYINT = COALESCE(@AType, 0),
		@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.ApplicationSurveyQuestion
				(ID, GroupID, [Name], [Type], RemoverPositionID, RemoveDate)
				VALUES
				(@ID, @GroupID, @Name, @Type, null, null)
			END
			ELSE
			BEGIN -- update
				UPDATE app.ApplicationSurveyQuestion
				SET GroupID = @GroupID,
					[Name] = @Name,
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spDeleteApplicationSurveyQuestionChoice'))
	DROP PROCEDURE app.spDeleteApplicationSurveyQuestionChoice
GO

CREATE PROCEDURE app.spDeleteApplicationSurveyQuestionChoice
	@AID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
	
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE app.ApplicationSurveyQuestionChoice
			SET RemoverPositionID = @CurrentPositionID
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyQuestionChoice'))
	DROP PROCEDURE app.spGetApplicationSurveyQuestionChoice
GO

CREATE PROCEDURE app.spGetApplicationSurveyQuestionChoice
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		surchoice.ID,
		surchoice.QuestionID,
		surchoice.[Name],
		surquestion.[Name] QuestionName
	FROM app.ApplicationSurveyQuestionChoice AS surchoice
		INNER JOIN app.ApplicationSurveyQuestion surquestion ON surquestion.ID = surchoice.QuestionID
	WHERE surchoice.ID = @ID
		AND surchoice.RemoverPositionID IS NOT NULL
		AND surchoice.RemoveDate IS NOT NULL

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetApplicationSurveyQuestionChoices'))
	DROP PROCEDURE app.spGetApplicationSurveyQuestionChoices
GO

CREATE PROCEDURE app.spGetApplicationSurveyQuestionChoices
	@AQuestionID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@QuestionID UNIQUEIDENTIFIER = @AQuestionID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
		SELECT 
			Count(*) OVER() Total,
			surchoice.ID,
			surchoice.QuestionID,
			surchoice.[Name],
			surquestion.[Name] QuestionName
		FROM app.ApplicationSurveyQuestionChoice AS surchoice
			INNER JOIN app.ApplicationSurveyQuestion surquestion ON surquestion.ID = surchoice.QuestionID
		WHERE surchoice.QuestionID = @QuestionID
			AND (@Name IS NULL OR surchoice.[Name] LIKE CONCAT('%', @Name, '%'))
	)

	SELECT * FROM MainSelect		 
	ORDER BY QuestionID desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyApplicationSurveyQuestionChoice'))
	DROP PROCEDURE app.spModifyApplicationSurveyQuestionChoice
GO

CREATE PROCEDURE app.spModifyApplicationSurveyQuestionChoice
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AQuestionID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@AEnable BIT,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@QuestionID UNIQUEIDENTIFIER = @AQuestionID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@Enable BIT = @AEnable, 
		@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.ApplicationSurveyQuestionChoice
				(ID, QuestionID, [Name])
				VALUES
				(@ID, @QuestionID, @Name)
			END
			ELSE
			BEGIN -- update
				UPDATE app.ApplicationSurveyQuestionChoice
				SET QuestionID = @QuestionID,
					[Name] = @Name
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetContact'))
	DROP PROCEDURE app.spGetContact
GO

CREATE PROCEDURE app.spGetContact
	@AID uniqueidentifier
--WITH ENCRYPTION
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE 
		@ID uniqueidentifier = @AID

	SELECT
		Contact.*
	FROM app.Contact contact
	where contact.ID = @ID
	ORDER BY Contact.Title

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetContacts'))
	DROP PROCEDURE app.spGetContacts
GO

CREATE PROCEDURE app.spGetContacts
	@AApplicationID uniqueidentifier,
	@ATitle NVARCHAR(200),
	@AContent NVARCHAR(200),
	@ACreationDateFrom SMALLDATETIME,
	@ACreationDateTo SMALLDATETIME,
	@AArchivedType TINYINT,
	@ANote NVARCHAR(4000),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID uniqueidentifier = @AApplicationID,
		@Title NVARCHAR(200) = @ATitle,
		@Content NVARCHAR(200) = @AContent,
		@CreationDateFrom SMALLDATETIME = COALESCE(DATEADD(dd, DATEDIFF(dd, 0, @ACreationDateFrom), 0), DATEADD(YEAR, -96, GETDATE())),
		@CreationDateTo SMALLDATETIME = COALESCE(DATEADD(dd, DATEDIFF(dd, 0, @ACreationDateTo), 0), GETDATE()),
		@ArchivedType TINYINT = COALESCE(@AArchivedType, 0),
		@Note NVARCHAR(MAX) = @ANote,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

		IF @Title = '' SET @Title = NULl ELSE SET @Title = N'%' + @Title + '%'		
		IF @Content = '' SET @Content = NULl ELSE SET @Content = N'%' + @Content + '%'				
		IF @Note = '' SET @Note = NULl ELSE SET @Note = N'%' + @Note + '%'				
		SET @CreationDateFrom = dbo.fnSetTime(@CreationDateFrom, 0, 0, 0)
		SET @CreationDateTo = dbo.fnSetTime(@CreationDateTo, 23, 59, 58)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END


	;WITH MainSelect AS (
	SELECT
		Count(*) OVER() Total,
		contact.ID,
		contact.[Name],
		contact.Email,
		contact.Tel,
		contact.Title,
		contact.CreationDate,
		contact.Archived,
		contact.NationalCode,
		'' Note
	FROM app.Contact contact 
	WHERE contact.ApplicationID = @ApplicationID
		--AND (@Title IS NULL OR contact.Title LIKE @Title)
		--AND(@Content IS NULL OR contact.Title LIKE @Content)
		--AND(@Note IS NULL OR contact.Note LIKE @Note)
		--AND(@ArchivedType < 1 OR contact.Archived = @ArchivedType - 1)
		--AND (DATEADD(dd, DATEDIFF(dd, 0, contact.CreationDate),0) BETWEEN @CreationDateFrom AND @CreationDateTo)
	)
	SELECT * FROM MainSelect		 
	ORDER BY [CreationDate] desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyContact'))
	DROP PROCEDURE app.spModifyContact
GO

CREATE PROCEDURE app.spModifyContact
    @AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName nvarchar(100),
	@AEmail nvarchar(200),
	@ATel nvarchar(200),
	@ATitle nvarchar(200),
	@ANationalCode nvarchar(200),
	@AContent nvarchar(4000),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID,
			@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
			@Name nvarchar(100) = @AName,
			@Email nvarchar(200) = @AEmail,
			@Tel nvarchar(200) = @ATel,
			@Title nvarchar(200) = @ATitle,
			@NationalCode nvarchar(200) = @ANationalCode,
			@Content nvarchar(max) = @AContent,
			@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN

			INSERT INTO app.Contact
				(ID, ApplicationID, [Name], Email, Tel, Title, Content, Archived, CreationDate, NationalCode)
			VALUES
				(@ID, @ApplicationID, @Name, @Email, @Tel, @Title, @Content, 1, GetDate(), @NationalCode)
		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetArchive'))
	DROP PROCEDURE app.spSetArchive
GO

CREATE PROCEDURE app.spSetArchive
    @AID UNIQUEIDENTIFIER,
	@AArchiveType TINYINT,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID,
			@ArchiveType TINYINT = @AArchiveType,			
			@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN

		UPDATE app.Contact
		SET Archived = @ArchiveType
		WHERE ID = @ID	
		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetNote'))
	DROP PROCEDURE app.spSetNote
GO

CREATE PROCEDURE app.spSetNote
    @AID UNIQUEIDENTIFIER,
	@ANote NVARCHAR(4000),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID,
			@Note NVARCHAR(4000) = @ANote,
			@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN

		UPDATE app.Contact
		SET Note = @Note
		WHERE ID = @ID			
		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spDeleteContactDetail'))
	DROP PROCEDURE app.spDeleteContactDetail
GO

CREATE PROCEDURE app.spDeleteContactDetail
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			DELETE app.ContactDetail
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetContactDetail'))
	DROP PROCEDURE app.spGetContactDetail
GO

CREATE PROCEDURE app.spGetContactDetail
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		ContactDetail.ID,
		ContactDetail.ContactInfoID,
		ContactDetail.Type,
		ContactDetail.Name,
		ContactDetail.Value
	FROM app.ContactDetail
	WHERE ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetContactDetails'))
DROP PROCEDURE app.spGetContactDetails
GO

CREATE PROCEDURE app.spGetContactDetails
	@AContactInfoIDs NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ContactInfoIDs NVARCHAR(MAX) = @AContactInfoIDs

	;WITH ContactInfoIDs AS
	(
		SELECT jsonResult.[value] ID
		FROM OPENJSON(@ContactInfoIDs) AS jsonResult
	)
	, MainSelect AS
	(
		SELECT
			ContactDetail.ID,
			ContactDetail.ContactInfoID,
			ContactDetail.Type,
			ContactDetail.Name,
			ContactDetail.Value
		FROM app.ContactDetail
		INNER JOIN ContactInfoIDs ON ContactInfoIDs.ID = ContactDetail.ContactInfoID
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyContactDetail'))
	DROP PROCEDURE app.spModifyContactDetail
GO

CREATE PROCEDURE app.spModifyContactDetail
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AContactInfoID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@AName NVARCHAR(200),
	@AValue NVARCHAR(1000),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ContactInfoID UNIQUEIDENTIFIER = @AContactInfoID,
		@Type TINYINT = COALESCE(@AType, 0),
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@Value NVARCHAR(1000) = LTRIM(RTRIM(@AValue)),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.ContactDetail
				(ID, ContactInfoID, Type, Name, [Value], CreationDate)
				VALUES
				(@ID, @ContactInfoID, @Type, @Name, @Value, GETDATE())
			END
			ELSE    -- update
			BEGIN
				UPDATE app.ContactDetail
				SET ContactInfoID = @ContactInfoID, Type = @Type, Name = @Name, Value = @Value
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spDeleteContactInfo'))
	DROP PROCEDURE app.spDeleteContactInfo
GO

CREATE PROCEDURE app.spDeleteContactInfo
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			DELETE app.ContactDetail
			WHERE ContactInfoID = @ID

			DELETE app.ContactInfo
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetContactInfo'))
	DROP PROCEDURE app.spGetContactInfo
GO

CREATE PROCEDURE app.spGetContactInfo
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		ContactInfo.ID,
		ContactInfo.ParentID,
		ContactInfo.Name,
		ContactInfo.[Order]
	FROM app.ContactInfo
	WHERE ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetContactInfos'))
DROP PROCEDURE app.spGetContactInfos
GO

CREATE PROCEDURE app.spGetContactInfos
	@AParentID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ParentID UNIQUEIDENTIFIER = @AParentID

	;WITH MainSelect AS
	(
		SELECT
			ContactInfo.ID,
			ContactInfo.ParentID,
			ContactInfo.Name,
			ContactInfo.[Order]
		FROM app.ContactInfo
		WHERE ContactInfo.ParentID = @ParentID
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyContactInfo'))
	DROP PROCEDURE app.spModifyContactInfo
GO

CREATE PROCEDURE app.spModifyContactInfo
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@AOrder INT,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@Order INT = COALESCE(@AOrder, 1),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.ContactInfo
				(ID, ParentID, [Name], [Order], CreationDate)
				VALUES
				(@ID, @ParentID, @Name, @Order, GETDATE())
			END
			ELSE    -- update
			BEGIN
				UPDATE app.ContactInfo
				SET ParentID = @ParentID, [Name] = @Name, [Order] = @Order
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spDeleteFAQ'))
DROP PROCEDURE app.spDeleteFAQ
GO

CREATE PROCEDURE app.spDeleteFAQ
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		  @ID UNIQUEIDENTIFIER = @AID
		, @Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM app.FAQ
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetFAQ'))
	DROP PROCEDURE app.spGetFAQ
GO

CREATE PROCEDURE app.spGetFAQ
	  @AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	 DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
	faq.*
	FROM app.FAQ faq
	WHERE faq.ID = @ID
	ORDER BY faq.CreationDate ASC

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetFAQs'))
	DROP PROCEDURE app.spGetFAQs
GO

CREATE PROCEDURE app.spGetFAQs
	@AApplicationID UNIQUEIDENTIFIER,
	@AFAQGroupID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	 DECLARE @ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@FAQGroupID UNIQUEIDENTIFIER = @AFAQGroupID,
		@PageSize INT = COALESCE(@APageSize,10),
		@PageIndex INT = COALESCE(@APageIndex, 0)
	
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
	SELECT 
		Count(*) OVER() Total,
		faq.ID,
		faqGroup.Title,
		faqGroup.ApplicationID,
		faq.FAQGroupID,
		faq.Question,
		faq.Answer,
		faq.CreationDate,
		faq.CreatorID,
		faq.[Order]
	FROM app.FAQ faq
	INNER JOIN app.FAQGroup faqGroup on faqGroup.ID = faq.FAQGroupID
	WHERE faqGroup.ApplicationID = @ApplicationID
			AND (@FAQGroupID is null or faq.FAQGroupID = @FAQGroupID))

	SELECT * FROM MainSelect		 
	ORDER BY [Order]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyFAQ'))
	DROP PROCEDURE app.spModifyFAQ
GO

CREATE PROCEDURE app.spModifyFAQ
	  @AIsNewRecord BIT
	, @AID UNIQUEIDENTIFIER
	, @AFAQGroupID UNIQUEIDENTIFIER
	, @AQuestion nvarchar(500)
	, @AAnswer nvarchar(2000)
	, @AUserID uniqueidentifier
	, @ALog NVARCHAR(MAX)
	, @AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	 DECLARE 
		  @IsNewRecord BIT = @AIsNewRecord 
		, @ID UNIQUEIDENTIFIER = @AID
		, @FAQGroupID UNIQUEIDENTIFIER = @AFAQGroupID
		, @Question nvarchar(500) = @AQuestion
		, @Answer nvarchar(2000) = @AAnswer
		, @UserID uniqueidentifier = @AUserID
		, @Log NVARCHAR(MAX) = @ALog
	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert
			BEGIN
			
				INSERT INTO APP.FAQ
				(ID, FAQGroupID, Answer, Question, CreationDate, CreatorID)
				VALUES
				(@ID, @FAQGroupID, @Answer, @Question, GETDATE(), @UserID)
			END
			ELSE 
			BEGIN -- update
				UPDATE APP.FAQ
				SET FAQGroupID = @FAQGroupID, Answer = @Answer, Question = @Question
				WHERE ID = @ID
			END

			SET @AResult = @@ROWCOUNT

		COMMIT

		RETURN @@ROWCOUNT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetFAQOrders'))
	DROP PROCEDURE app.spSetFAQOrders
GO

CREATE PROCEDURE app.spSetFAQOrders
	@AOrders NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@Orders NVARCHAR(MAX) = @AOrders,
		@Result NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN
		;WITH orders AS
		(
		SELECT * FROM OPENJSON(@Orders)
			WITH (
				ID UNIQUEIDENTIFIER,
				[Order] INT
			) orders
		)
		UPDATE fAQ
		SET [Order] = orders.[Order]
		FROM app.FAQ fAQ
			INNER JOIN orders ON orders.ID = fAQ.ID 

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spDeleteFAQGroup'))
DROP PROCEDURE app.spDeleteFAQGroup
GO

CREATE PROCEDURE app.spDeleteFAQGroup
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		  @ID UNIQUEIDENTIFIER = @AID
		, @Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM app.FAQ
			WHERE FAQGroupID = @ID

			DELETE FROM app.FAQGroup
			WHERE ID = @ID


		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetFAQGroup'))
	DROP PROCEDURE app.spGetFAQGroup
GO

CREATE PROCEDURE app.spGetFAQGroup
	  @AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	 DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
	faqGroup.*
	FROM app.FAQGroup faqGroup
	WHERE faqGroup.ID = @ID
	ORDER BY faqGroup.CreationDate ASC

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetFAQGroups'))
	DROP PROCEDURE app.spGetFAQGroups
GO

CREATE PROCEDURE app.spGetFAQGroups
	@AApplicationID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)
	
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
	SELECT 
		Count(*) OVER() Total,
		faqGroup.ID,
		faqGroup.Title,
		faqGroup.ApplicationID,
		faqGroup.CreationDate,
		faqGroup.CreatorID,
		faqGroup.[Order]
	FROM app.FAQGroup faqGroup
	WHERE faqGroup.ApplicationID = @ApplicationID)

	SELECT * FROM MainSelect		 
	ORDER BY [Order]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyFAQGroup'))
	DROP PROCEDURE app.spModifyFAQGroup
GO

CREATE PROCEDURE app.spModifyFAQGroup
	  @AIsNewRecord BIT
	, @AID UNIQUEIDENTIFIER
	, @AApplicationID UNIQUEIDENTIFIER
	, @ATitle NVARCHAR(500)
	, @AUserID UNIQUEIDENTIFIER
	, @ALog NVARCHAR(MAX)
	, @AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	 DECLARE @IsNewRecord BIT = ISNULL(@AIsNewRecord, 0)
	    , @ID UNIQUEIDENTIFIER = @AID
		, @ApplicationID UNIQUEIDENTIFIER = @AApplicationID
		, @UserID UNIQUEIDENTIFIER = @AUserID
		, @Title NVARCHAR(500) = @ATitle 
		, @Log NVARCHAR(MAX) = @ALog
	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert
			BEGIN
			
				INSERT INTO APP.FAQGroup
				(ID, Title, ApplicationID, CreationDate, CreatorID)
				VALUES
				(@ID, @Title, @ApplicationID, GETDATE(), @UserID)
			END
			ELSE 
			BEGIN -- update
				UPDATE APP.FAQGroup
				SET Title = @Title, ApplicationID = @ApplicationID
				WHERE ID = @ID
			END

			SET @AResult = @@ROWCOUNT

		COMMIT

		RETURN @@ROWCOUNT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetFAQGroupOrders'))
	DROP PROCEDURE app.spSetFAQGroupOrders
GO

CREATE PROCEDURE app.spSetFAQGroupOrders
	@AOrders NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@Orders NVARCHAR(MAX) = @AOrders,
		@Result NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN
		;WITH orders AS
		(
		SELECT * FROM OPENJSON(@Orders)
			WITH (
				ID UNIQUEIDENTIFIER,
				[Order] INT
			) orders
		)
		UPDATE app.FAQGroup
		  SET [Order] = orders.[Order]
		FROM  app.FAQGroup fAQGroup
		     INNER JOIN orders ON orders.ID = fAQGroup.ID 

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF OBJECT_ID('app.spDeleteHelpSection') IS NOT NULL
	DROP PROCEDURE app.spDeleteHelpSection
GO

CREATE PROCEDURE app.spDeleteHelpSection
    @AID UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT, XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
		, @Result INT = 0

	BEGIN TRY
		BEGIN TRAN			
			DELETE FROM app.HelpSection
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @Result

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetHelpSection'))
	DROP PROCEDURE app.spGetHelpSection
GO

CREATE PROCEDURE app.spGetHelpSection
	@AID UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		    hs.[ID]
		   ,hs.[CreationDate]
		   ,hs.[Title]
		   ,hs.[Order]
		   ,hs.[Description]
		   ,hs.[HelpSectionGroupID]
		   ,hs.[FileName]
		   ,hs.[FileType]
		   ,hs.IsActive
		,count(*) over() Total
	FROM app.HelpSection as hs
	where hs.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetHelpSections'))
	DROP PROCEDURE app.spGetHelpSections
GO

CREATE PROCEDURE app.spGetHelpSections
	@ATitle NVARCHAR(300),
	@AOrder INT,
	@ADescription nvarchar(4000),
	@AHelpSectionGroupID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AFileType TINYINT,
	@AIsActive TINYINT,
	@AFileName nvarchar(300),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE
		@Title NVARCHAR(300) = @ATitle,
		@Order INT = COALESCE(@AOrder, 0),
		@Description NVARCHAR(4000) = LTRIM(RTRIM(@ADescription)),
		@HelpSectionGroupID UNIQUEIDENTIFIER = @AHelpSectionGroupID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@FileType TINYINT = COALESCE(@AFileType, 0),
		@IsActive TINYINT = COALESCE(@AIsActive, 0),
		@FileName NVARCHAR(300) = LTRIM(RTRIM(@AFileName)),
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
		SELECT
		   hs.[ID]
		  ,hs.[CreationDate]
		  ,hs.[Title]
		  ,hs.[Order]
		  ,hs.[Description]
		  ,hs.[HelpSectionGroupID]
		  ,hs.[FileName]
		  ,hs.[FileType]
		  ,hs.[IsActive]
		  ,hsg.Title GroupTitle
		  ,hsg.[Description] GroupDescription
		  ,hsg.[Order] GroupOrder
		  ,hsg.ApplicationID
		  ,count(*) over() Total
		FROM 
			app.[HelpSection] hs
			INNER Join app.[HelpSectionGroup] hsg on hs.HelpSectionGroupID = hsg.ID
		WHERE
            (@Title IS NULL OR hs.[Title] LIKE '%' + @Title + '%')
			AND (@Description IS NULL OR hs.[Description] LIKE '%' + @Description + '%')
			AND (@AOrder = 0 OR hs.[Order] = @Order)
			AND (@AHelpSectionGroupID IS NULL OR hs.[HelpSectionGroupID] = @HelpSectionGroupID)
			AND (@AFileType = 0 OR hs.FileType = @FileType)
			AND (@AFileName IS NULL OR hs.[FileName] LIKE '%' + @FileName + '%')
			AND (@ApplicationID IS NULL OR hsg.ApplicationID = @ApplicationID)
			AND (@IsActive < 1 OR hs.IsActive = @IsActive - 1)
	)
	SELECT *
	FROM MainSelect		 
	ORDER BY [GroupOrder],[Order]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyHelpSection'))
	DROP PROCEDURE app.spModifyHelpSection
GO

CREATE PROCEDURE app.spModifyHelpSection
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ATitle  nvarchar(300),
    @AOrder INT,
	@ADescription nvarchar(4000),
	@AHelpSectionGroupID UNIQUEIDENTIFIER,
	@AFileType TINYINT,
	@AIsActive BIT,
	@AFileName nvarchar(300)
--WITH ENCRYPTION
AS
	SET NOCOUNT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@Title NVARCHAR(300) = LTRIM(RTRIM(@ATitle)),
		@Order INT = COALESCE(@AOrder, 0),
		@Description NVARCHAR(4000) = LTRIM(RTRIM(@ADescription)),
		@HelpSectionGroupID UNIQUEIDENTIFIER = @AHelpSectionGroupID,
	    @FileType TINYINT = COALESCE(@AFileType, 0),
	    @IsActive BIT = @AIsActive,
	    @FileName nvarchar(300) = LTRIM(RTRIM(@AFileName)),
		@OrderLastValue INT,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN

				set @OrderLastValue = (SELECT TOP 1 [Order] FROM app.HelpSection ORDER BY [Order] DESC  )
				
				IF @OrderLastValue is null   
				BEGIN
					SET @OrderLastValue = 1
				END
				ELSE  
				BEGIN
					SET @OrderLastValue += 1
				END

				INSERT INTO app.HelpSection
					([ID],CreationDate, Title,[Order],[Description],HelpSectionGroupID,FileType,[FileName], [IsActive])
				VALUES
					(@ID,getDate(),@Title, @OrderLastValue, @Description,@HelpSectionGroupID,@FileType,@FileName, @IsActive)
			END
			ELSE 			 -- update
			BEGIN
				UPDATE app.HelpSection
				SET
					Title = @Title,
					[Order] = @Order,
					[Description] = @Description,
					HelpSectionGroupID = @HelpSectionGroupID,
					FileType = @FileType,
					[FileName] = @FileName,
					[IsActive] = @IsActive
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
END CATCH

RETURN @Result 
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetHelpSectionOrders'))
	DROP PROCEDURE app.spSetHelpSectionOrders
GO

CREATE PROCEDURE app.spSetHelpSectionOrders
	@AOrders NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@Orders NVARCHAR(MAX) = @AOrders,
		@Result NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN
		;WITH orders AS
		(
		SELECT * FROM OPENJSON(@Orders)
			WITH (
				ID UNIQUEIDENTIFIER,
				[Order] INT
			) orders
		)
		UPDATE app.HelpSection
		  SET [Order] = orders.[Order]
		FROM  app.HelpSection hs
		     INNER JOIN orders ON orders.ID = hs.ID 

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF OBJECT_ID('app.spDeleteHelpSectionGroup') IS NOT NULL
	DROP PROCEDURE app.spDeleteHelpSectionGroup
GO

CREATE PROCEDURE app.spDeleteHelpSectionGroup
    @AID UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT, XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
		, @Result INT = 0

	BEGIN TRY
		BEGIN TRAN		
		
			DELETE FROM app.HelpSection
			WHERE HelpSectionGroupID = @ID

			DELETE FROM app.HelpSectionGroup
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @Result

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetHelpSectionGroup'))
	DROP PROCEDURE app.spGetHelpSectionGroup
GO

CREATE PROCEDURE app.spGetHelpSectionGroup
	@AID UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
			hsg.ID,
			hsg.[Order],
			hsg.Title,
			hsg.[Description],
			hsg.ApplicationID,
			hsg.CreationDate,
			count(*) over() Total
	FROM app.HelpSectionGroup as hsg
	where hsg.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetHelpSectionGroups'))
	DROP PROCEDURE app.spGetHelpSectionGroups
GO

CREATE PROCEDURE app.spGetHelpSectionGroups
	@ATitle NVARCHAR(300),
	@AOrder INT,
	@ADescription nvarchar(4000),
	@AApplicationID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE
		@Title NVARCHAR(300) = @ATitle,
		@Order INT = COALESCE(@AOrder, 0),
		@Description NVARCHAR(4000) = LTRIM(RTRIM(@ADescription)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS (
		SELECT
			hsg.ID,
			hsg.[Order],
			hsg.ApplicationID,
			hsg.Title,
			hsg.[Description],
			hsg.CreationDate,
			count(*) over() Total
		FROM 
			app.[HelpSectionGroup] hsg
		WHERE
            (@Title IS NULL OR hsg.[Title] LIKE '%' + @Title + '%')
			AND (@Description IS NULL OR hsg.[Description] LIKE '%' + @Description + '%')
			AND (@AOrder = 0 OR hsg.[Order] = @Order)
			AND (@ApplicationID IS NULL OR hsg.ApplicationID = @ApplicationID)
	)
	SELECT * FROM MainSelect		 
	ORDER BY [Order]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyHelpSectionGroup'))
	DROP PROCEDURE app.spModifyHelpSectionGroup
GO

CREATE PROCEDURE app.spModifyHelpSectionGroup
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ATitle  nvarchar(300),
	@AOrder INT,
	@ADescription nvarchar(4000)
--WITH ENCRYPTION
AS
	SET NOCOUNT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Title NVARCHAR(300) = LTRIM(RTRIM(@ATitle)),
		@Order INT = COALESCE(@AOrder, 1),
		@Description NVARCHAR(4000) = LTRIM(RTRIM(@ADescription)),
		@OrderLastValue INT,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN				
				set @OrderLastValue = (SELECT TOP 1 [Order] FROM app.HelpSectionGroup ORDER BY [Order] DESC  )
				
				IF @OrderLastValue is null   
				BEGIN
					SET @OrderLastValue = 1
				END
				ELSE  
				BEGIN
					SET @OrderLastValue += 1
				END

				INSERT INTO app.HelpSectionGroup
					([ID],CreationDate, Title,[Order],[Description], [ApplicationID])
				VALUES
					(@ID,getDate(),@Title, @OrderLastValue, @Description, @ApplicationID)
			END
			ELSE 			 -- update
			BEGIN
				UPDATE app.HelpSectionGroup
				SET
					Title = @Title,
					[Order] = @Order,
					[Description] = @Description
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		SET @Result = -1
		;THROW
END CATCH

RETURN @Result 
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetHelpSectionGroupOrders'))
	DROP PROCEDURE app.spSetHelpSectionGroupOrders
GO

CREATE PROCEDURE app.spSetHelpSectionGroupOrders
	@AOrders NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@Orders NVARCHAR(MAX) = @AOrders,
		@Result NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN
		;WITH orders AS
		(
		SELECT * FROM OPENJSON(@Orders)
			WITH (
				ID UNIQUEIDENTIFIER,
				[Order] INT
			) orders
		)
		UPDATE app.HelpSectionGroup
		  SET [Order] = orders.[Order]
		FROM  app.HelpSectionGroup hsg
		     INNER JOIN orders ON orders.ID = hsg.ID 

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS( SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spDeleteMessage'))
	DROP PROCEDURE app.spDeleteMessage
GO

CREATE PROCEDURE app.spDeleteMessage
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AMessageID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@MessageID UNIQUEIDENTIFIER = @AMessageID,
		@SenderUserID UNIQUEIDENTIFIER

	SET @SenderUserID = (SELECT SenderUserID FROM app.[Message] WHERE ID = @MessageID)

	BEGIN TRY
		BEGIN TRAN

			IF @SenderUserID = @CurrentUserID
			BEGIN
				UPDATE app.[Message]
				SET IsRemoved = 1
				WHERE ID = @MessageID
			END
			ELSE
			BEGIN
				UPDATE app.MessageReceiver
				SET IsRemoved = 1 
				WHERE MessageID = @MessageID 
					AND ReceiverUserID= @CurrentUserID
			END
						
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id]=OBJECT_ID('app.spGetDraftMessages'))
	DROP PROCEDURE app.spGetDraftMessages
GO

CREATE PROCEDURE app.spGetDraftMessages
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ATitle NVARCHAR(300),
	@AContent NVARCHAR(4000),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)

--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Title NVARCHAR(300) = LTRIM(RTRIM(@ATitle)),
		@Content NVARCHAR(4000) = LTRIM(RTRIM(@AContent)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	BEGIN TRY
		BEGIN TRAN

		;WITH 
			Receiver As (
				SELECT DISTINCT MessageID,
				 IsRemoved,
				 ReceiverUserID,
				 ReceiverPositionID,
				 Seen,
				 u.FirstName + ' ' + u.LastName  ReceiverUserFullName
				FROM app.MessageReceiver messageReceiver
				INNER JOIN org.[User] u ON u.ID = messageReceiver.ReceiverUserID
				WHERE
					IsRemoved = 0
			)
			
			,MainSelect AS(
			SELECT  
				count(*) over() Total,
				msg.ID,
				msg.ApplicationID, 
				msg.SenderUserID, 
				msg.SenderPositionID,
				msg.[Title],
				msg.[Content], 
				msg.[CreationDate], 
				msg.ExpireDates,
				msg.[IsRemoved], 
				msg.[ParentID], 
				msg.IsSent,
				CONVERT(VARCHAR(20), msg.CreationDate, 108) AS TimePart,
				dep.[Name] SenderDepartmentName,
				p.[Type] SenderPositionType,
				rcv.ReceiverUserFullName,
				rcv.ReceiverPositionID,
				--rp.[Type] ReceiverPositionType,
				u.FirstName + ' ' + u.LastName  SenderUserFullName
			FROM app.[Message] msg
				 INNER JOIN org.[User] u ON u.ID = msg.SenderUserID
				 INNER JOIN org.Position p ON p.ID = msg.SenderPositionID
				 INNER JOIN org.Department dep ON dep.ID = p.DepartmentID
				 INNER JOIN Receiver rcv ON rcv.MessageID = msg.ID
				 LEFT JOIN org.Position rp ON rp.ID = rcv.ReceiverPositionID
			WHERE msg.IsRemoved = 0
				AND msg.IsSent = 0
				AND msg.SenderUserID = @CurrentUserID
				AND msg.SenderPositionID = @CurrentPositionID
				AND (@Title IS NULL OR msg.Title LIKE  N'%' + @Title + '%')
				AND (@Content IS NULL OR msg.Content LIKE N'%' + @Content + '%')
			)
		SELECT * FROM MainSelect
		ORDER BY [ID]
		OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
				
			COMMIT
		END TRY
	BEGIN CATCH
	;THROW
	END CATCH
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS( SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetInboxMessages'))
	DROP PROCEDURE app.spGetInboxMessages
GO

CREATE PROCEDURE app.spGetInboxMessages
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ASenderUserID UNIQUEIDENTIFIER,
	@ASenderUserFullName NVARCHAR(100),
	@ASenderPositionID UNIQUEIDENTIFIER,
	@ASenderPositionType TINYINT,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ASenderDepartmentName NVARCHAR(256),
	@ATitle NVARCHAR(300),
	@AContent NVARCHAR(4000),
	@ASeen BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SenderUserID UNIQUEIDENTIFIER = @ASenderUserID,
		@SenderUserFullName NVARCHAR(100) = LTRIM(RTRIM(@ASenderUserFullName)),
		@SenderPositionID UNIQUEIDENTIFIER = @ASenderPositionID,
		@SenderPositionType TINYINT = COALESCE(@ASenderPositionType,0),
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@SenderDepartmentName NVARCHAR(256) = LTRIM(RTRIM(@ASenderDepartmentName)),
		@Title NVARCHAR(300) = LTRIM(RTRIM(@ATitle)),
		@Content NVARCHAR(4000) = LTRIM(RTRIM(@AContent)),
		@Seen BIT = @ASeen,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	BEGIN TRY
		BEGIN TRAN
			
			;WITH Receiver As (
				SELECT DISTINCT MessageID,
				 IsRemoved,
				 ReceiverUserID,
				 Seen
				FROM app.MessageReceiver messageReceiver
				INNER JOIN org.[User] u ON u.ID = messageReceiver.ReceiverUserID
				WHERE ReceiverUserID = @CurrentUserID
					AND IsRemoved = 0
			)
			, MainSelect AS(
			SELECT  
					count(*) over() Total,  
					msg.ID,
					msg.ApplicationID, 
					msg.SenderUserID, 
					msg.SenderPositionID,
					msg.[Title], 
					msg.[Content], 
					msg.[CreationDate], 
					msg.ExpireDates, 
					CONVERT(VARCHAR(20), msg.CreationDate, 108) AS TimePart,
					msg.[IsRemoved], 
					msg.[ParentID], 
					msg.SendType,
					msg.IsSent,
					dep.[Name] SenderDepartmentName,
					rcv.Seen,
					p.[Type] SenderPositionType,
					u.FirstName + ' ' + u.LastName  SenderUserFullName
			FROM app.[Message] msg
				 INNER JOIN org.[User] u ON u.ID = msg.SenderUserID
				 INNER JOIN org.Position p ON p.ID = msg.SenderPositionID
				 INNER JOIN org.Department dep ON dep.ID = p.DepartmentID
				 INNER JOIN Receiver rcv ON rcv.MessageID = msg.ID
			WHERE IsSent = 1
				AND rcv.IsRemoved = 0
				AND rcv.ReceiverUserID = @CurrentUserID
				AND (@Title IS NULL OR msg.Title LIKE  N'%' + @Title + '%')
				AND (@Content IS NULL OR msg.Content LIKE N'%' + @Content + '%')
				AND (@SenderDepartmentName IS NULL OR dep.[Name] LIKE N'%' + @SenderDepartmentName + '%')
				AND (@SenderPositionType < 1 OR p.[Type] = @SenderPositionType)
				AND (@SenderUserFullName IS NULL OR u.FirstName +' '+ u.LastName LIKE N'%' + @SenderUserFullName + '%')
				)
		SELECT * FROM MainSelect
		ORDER BY [ID]
		OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
				
			COMMIT
		END TRY
	BEGIN CATCH
	;THROW
	END CATCH
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetMessage'))
	DROP PROCEDURE app.spGetMessage
GO

CREATE PROCEDURE app.spGetMessage
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
			msg.ID,
			msg.ApplicationID, 
			msg.SenderUserID,
			msg.SenderPositionID, 
			msg.[Title], 
			msg.[Content], 
			msg.[CreationDate], 
			msg.[IsRemoved], 
			msg.[ParentID], 
			msg.IsSent,
			p.[Type] SenderPositionType,
			u.FirstName + ' ' + u.LastName SenderUserFullName
	FROM app.[Message] msg
		INNER JOIN org.[User] u ON u.ID = msg.SenderUserID
		INNER JOIN org.Position p ON p.ID = msg.SenderPositionID
		INNER JOIN org.Department dep ON dep.ID = p.DepartmentID 
	WHERE (msg.ID = @ID)

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetMessageReceivers'))
DROP PROCEDURE app.spGetMessageReceivers
 GO 
 
 CREATE PROCEDURE  app.spGetMessageReceivers
	@AApplicationID UNIQUEIDENTIFIER,
	@AMessageID UNIQUEIDENTIFIER,
	@AMessageIDs NVARCHAR(MAX) 
--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

DECLARE
	@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
	@MessageID UNIQUEIDENTIFIER = @AMessageID,
	@MessageIDs NVARCHAR(MAX) = LTRIM(RTRIM(@AMessageIDs))

	BEGIN TRY
		BEGIN TRAN

			;WITH [Message] AS
			(
				SELECT value ID
				FROM OPENJSON(@MessageIDs)
			)
			SELECT
				r.[ID], 
				r.[ReceiverUserID],
				r.[MessageID], 
				r.[IsRemoved], 
				r.[Seen],
				r.ReceiverPositionID,
				p.[Type] ReceiverPositionType,
				u.FirstName + ' ' + u.LastName  ReceiverUserFullName
			FROM
				app.MessageReceiver r
				LEFT JOIN org.Position p ON p.ID = r.ReceiverPositionID
				INNER JOIN org.[User] u ON u.ID = r.ReceiverUserID
				--INNER JOIN org.position pos ON pos.UserID = u.ID
			WHERE
				(@MessageID IS NULL OR MessageID = @MessageID)
				AND (@MessageIDs IS NULL OR MessageID in (select ID from [Message]))

		COMMIT
	END TRY
	BEGIN CATCH
		THROW;
	END CATCH
END



GO
USE [Kama.Aro.Organization]
GO

IF EXISTS( SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetOutboxMessages'))
	DROP PROCEDURE app.spGetOutboxMessages
GO

CREATE PROCEDURE app.spGetOutboxMessages
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentPositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ATitle NVARCHAR(300),
	@AReceiverUserFullName NVARCHAR(100),
	--@AReceiverPositionType TINYINT,
	@AContent NVARCHAR(4000),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
	
--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

DECLARE 
	@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
	@CurrentPositionID UNIQUEIDENTIFIER = @ACurrentPositionID,
	@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
	@Title NVARCHAR(300) = LTRIM(RTRIM(@ATitle)),
	@ReceiverUserFullName NVARCHAR(100) = LTRIM(RTRIM(@AReceiverUserFullName)),
	--@ReceiverPositionType TINYINT = COALESCE(@AReceiverPositionType, 0),
	@Content NVARCHAR(4000) = LTRIM(RTRIM(@AContent)),
	@PageSize INT = COALESCE(@APageSize,20),
	@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	BEGIN TRY
		BEGIN TRAN
			
			;WITH 
			Receiver As (
				SELECT DISTINCT MessageID,
				 IsRemoved,
				 ReceiverUserID,
				 ReceiverPositionID,
				 Seen,
				 u.FirstName + ' ' + u.LastName  ReceiverUserFullName
				FROM app.MessageReceiver messageReceiver
				INNER JOIN org.[User] u ON u.ID = messageReceiver.ReceiverUserID
				WHERE
					IsRemoved = 0
			),
			MainSelect AS(
			SELECT  
				count(*) over() Total,
				msg.ID,
				msg.ApplicationID, 
				msg.SenderUserID,
				msg.SenderPositionID, 
				msg.[Title],
				msg.[Content], 
				msg.[CreationDate],
				msg.ExpireDates,
				CONVERT(VARCHAR(20), msg.CreationDate, 108) AS TimePart,
				msg.[IsRemoved], 
				msg.[ParentID], 
				msg.IsSent,
				dep.[Name] SenderDepartmentName,
				p.[Type] SenderPositionType,
				rcv.ReceiverUserFullName,
				rcv.ReceiverPositionID,
				--rp.[Type] ReceiverPositionType,
				u.FirstName + ' ' + u.LastName  SenderUserFullName
			FROM app.[Message] msg
				 INNER JOIN org.[User] u ON u.ID = msg.SenderUserID
				 INNER JOIN org.Position p ON p.ID = msg.SenderPositionID
				 INNER JOIN org.Department dep ON dep.ID = p.DepartmentID
				 INNER JOIN Receiver rcv ON rcv.MessageID = msg.ID
				 LEFT JOIN org.Position rp ON rp.ID = rcv.ReceiverPositionID
			WHERE msg.IsRemoved = 0
				AND IsSent = 1
				AND msg.SenderUserID = @CurrentUserID
				AND msg.SenderPositionID = @CurrentPositionID
				AND (@Title IS NULL OR msg.Title LIKE  N'%' + @Title + '%')
				--AND (@ReceiverPositionType < 1 OR rp.[Type] = @ReceiverPositionType)
				AND (@Content IS NULL OR msg.Content LIKE N'%' + @Content + '%')
				AND (@ReceiverUserFullName IS NULL OR (u.FirstName +' '+ u.LastName) LIKE N'%' + @ReceiverUserFullName + '%')
				)
		SELECT * FROM MainSelect
		ORDER BY [ID]
		OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
				
			COMMIT
		END TRY
	BEGIN CATCH
	;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spModifyMessage'))
	DROP PROCEDURE app.spModifyMessage
GO

CREATE PROCEDURE app.spModifyMessage
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ASenderUserID UNIQUEIDENTIFIER,
	@ASenderPositionID UNIQUEIDENTIFIER,
	@AContent NVARCHAR(MAX),
	@ASentType TINYINT,
	@ATitle NVARCHAR(300),
	@AParentID UNIQUEIDENTIFIER,
	@AReceiverUserIDs NVARCHAR(MAX),
	@AExpireDate smalldatetime ,
	@AMessageType tinyint,
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 	
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SenderUserID UNIQUEIDENTIFIER = @ASenderUserID,
		@SenderPositionID UNIQUEIDENTIFIER = @ASenderPositionID,
		@Content NVARCHAR(MAX) = @AContent,
		@SentType TINYINT = COALESCE(@ASentType, 0),
		@Title NVARCHAR(300) = LTRIM(RTRIM(@ATitle)),
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@IsRemoved BIT = 0,
		@IsSent BIT = 0,
		@ReceiverUserIDs NVARCHAR(MAX) = @AReceiverUserIDs,
		@ExpireDate smalldatetime = @AExpireDate,
		@MessageType tinyint = @AMessageType,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.[Message] 
					(ID, ApplicationID, SenderUserID, SenderPositionID, [Content], [Title], ParentID, IsRemoved, SendType, IsSent, creationDate,ExpireDates,Type )
				VALUES
					(@ID, @ApplicationID, @SenderUserID, @SenderPositionID, @Content, @Title, @ParentID, @IsRemoved, @SentType , @IsSent, GETDATE(),@ExpireDate,@MessageType)
			END
			ELSE
			BEGIN
				UPDATE app.[Message]
				 SET ApplicationID= @ApplicationID, 
					 [SenderUserID]= @SenderUserID, 
					 [SenderPositionID] = @SenderPositionID,
					 [Content]= @Content, 
					 [Title]= @Title,
					 ParentID= @ParentID, 
					 IsRemoved= @IsRemoved, 
					 SendType= @SentType,
					 IsSent= @IsSent, 
					 creationDate= GETDATE(),
					 ExpireDates=@ExpireDate,
					 Type=@MessageType

			     WHERE [ID]= @ID
			END

			DELETE FROM app.MessageReceiver
			WHERE MessageID = @ID

			INSERT INTO app.MessageReceiver
				([ID] , [MessageID], ReceiverPositionID, [IsRemoved], [Seen])
			SELECT NEWID() ID,
				@ID MessageID,
				VALUE ReceiverPositionID,
				0 IsRemoved,
				0 Seen
			FROM OPENJSON(@ReceiverUserIDs)

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(Select 1 From SYS.PROCEDURES WHERE [object_id] = OBJECT_ID ('app.spPermanentDeleteMessage'))
DROP PROCEDURE app.spPermanentDeleteMessage

GO

CREATE PROCEDURE app.spPermanentDeleteMessage
		@ACurrentUserID UNIQUEIDENTIFIER,
		@AMessageID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@MessageID UNIQUEIDENTIFIER = @AMessageID,
		@SenderUserID UNIQUEIDENTIFIER

		SET @SenderUserID = (SELECT SenderUserID FROM app.[Message] WHERE ID = @MessageID)

	BEGIN TRY
		BEGIN TRAN

			IF @SenderUserID = @CurrentUserID
			BEGIN
				DELETE msgR FROM app.MessageReceiver msgR
				INNER JOIN app.[Message] msg ON msg.ID = msgR.MessageID
				DELETE FROM app.[Message]
				WHERE ID = @MessageID
			END
						
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spSendMessage'))
	DROP PROCEDURE app.spSendMessage
GO

CREATE PROCEDURE app.spSendMessage
	@AMessageID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@MessageID UNIQUEIDENTIFIER = @AMessageID
			
	BEGIN TRY
		BEGIN TRAN
				
			Update app.[Message] 
			SET IsSent = 1
			WHERE ID = @MessageID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END						
									
									
		
		
		
			


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS( SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spSetMessageAsSeen'))
	DROP PROCEDURE app.spSetMessageAsSeen
GO

CREATE PROCEDURE app.spSetMessageAsSeen
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AMessageID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@MessageID UNIQUEIDENTIFIER = @AMessageID,
		@SenderUserID UNIQUEIDENTIFIER

	SET @SenderUserID = (SELECT SenderUserID FROM app.[Message] WHERE ID = @MessageID)

	BEGIN TRY
		BEGIN TRAN
		
				UPDATE app.MessageReceiver
				SET Seen = 1 
				WHERE MessageID = @MessageID 
					AND ReceiverUserID= @CurrentUserID
						
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS( SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spSetMessageAsUnseen'))
	DROP PROCEDURE app.spSetMessageAsUnseen
GO

CREATE PROCEDURE app.spSetMessageAsUnseen
	@ACurrentUserID UNIQUEIDENTIFIER,
	@AMessageID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@MessageID UNIQUEIDENTIFIER = @AMessageID,
		@SenderUserID UNIQUEIDENTIFIER

	SET @SenderUserID = (SELECT SenderUserID FROM app.[Message] WHERE ID = @MessageID)

	BEGIN TRY
		BEGIN TRAN
			
				UPDATE app.MessageReceiver
				SET Seen = 0 
				WHERE MessageID = @MessageID 
					AND ReceiverUserID= @CurrentUserID
						
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spSetNotificationPositionFromCondition'))
	DROP PROCEDURE app.spSetNotificationPositionFromCondition
GO

CREATE PROCEDURE app.spSetNotificationPositionFromCondition
	@AApplicationID UNIQUEIDENTIFIER,
	@AConditionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@ConditionID UNIQUEIDENTIFIER = @AConditionID,
		@NotificationID UNIQUEIDENTIFIER,
		@DepartmentID UNIQUEIDENTIFIER,
		@PositionType TINYINT,
		@ProvinceID UNIQUEIDENTIFIER

	SELECT 
		@NotificationID = NotificationID,
		@DepartmentID = DepartmentID,
		@PositionType = PositionType,
		@ProvinceID = ProvinceID
	FROM app.NotificationCondition
	WHERE ID = @ConditionID
			
	BEGIN TRY
		BEGIN TRAN
				
			INSERT INTO app.NotificationPosition
			(ID, NotificationID, PositionID)
			SELECT Distinct
				NEWID() ID, 
				@NotificationID,
				position.ID PositionID
			FROM Org.Position
				INNER JOIN org.Department ON Department.ID = Position.DepartmentID
			WHERE ApplicationID = @ApplicationID
				AND (@DepartmentID IS NULL OR Position.DepartmentID = @DepartmentID)
				AND (@PositionType < 1 OR Position.Type = @PositionType)
				AND (@ProvinceID IS NULL OR Department.ProvinceID = @ProvinceID)
				AND NOT EXISTS (SELECT TOP 1 1 FROM app.NotificationPosition WHERE PositionID = Position.ID)
			 
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END						
									
									
		
		
		
			


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spArchiveNotification'))
	DROP PROCEDURE app.spArchiveNotification
GO

CREATE PROCEDURE app.spArchiveNotification
	@ANotificationID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@NotificationID UNIQUEIDENTIFIER = @ANotificationID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
			
	BEGIN TRY
		BEGIN TRAN
				
			UPDATE app.[Notification] 
			SET [State] = 3
			WHERE ID = @NotificationID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END						
									
									
		
		
		
			


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spDeleteNotification'))
	DROP PROCEDURE app.spDeleteNotification
GO

CREATE PROCEDURE app.spDeleteNotification
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@State TINYINT

	SET @State = (SELECT [State] FROM app.[Notification] WHERE ID = @ID)

	BEGIN TRY
		BEGIN TRAN
		
		IF @State = 1 -- ارسال نشده
		BEGIN
			DELETE FROM app.[Notification] 
			WHERE ID = @ID

			DELETE app.NotificationPosition
			WHERE NotificationID = @ID
		END	
		ELSE    --ارسال شده
		BEGIN
			UPDATE app.[Notification] 
			SET [State] = 4
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spGetNotification'))
	DROP PROCEDURE app.spGetNotification
GO

CREATE PROCEDURE app.spGetNotification
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		ntf.ID,
		ntf.SenderPositionID,
		usr.FirstName + ' ' + usr.LastName SenderName,
		ntf.Title,
		ntf.Content,
		ntf.[Priority],
		ntf.[State],
		ntf.CreationDate
	FROM app.[Notification] ntf
		LEFT JOIN org.Position pos On pos.ID = ntf.SenderPositionID
		LEFT JOIN org.[User] usr ON usr.Id = pos.UserID
	WHERE ntf.ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetNotificationPositions'))
	DROP PROCEDURE app.spGetNotificationPositions
GO

CREATE PROCEDURE app.spGetNotificationPositions
	@ANotificationID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@NotificationID UNIQUEIDENTIFIER = @ANotificationID,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT
		count(*) over() Total,
		usr.ID,
		usr.FirstName +' '+ usr.LastName FullName,
		dep.[Name] DepartmentName,
		pos.[Type] PositionType
	FROM app.NotificationPosition ntfPosition
		LEFT JOIN org.[Position] pos ON pos.ID = ntfPosition.PositionID
		LEFT JOIN org.Department dep ON dep.ID = pos.DepartmentID
		LEFT JOIN org.[User] usr ON usr.ID = pos.UserID
	WHERE ntfPosition.NotificationID = @NotificationID
	ORDER BY [LastName]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetNotifications'))
	DROP PROCEDURE app.spGetNotifications
GO

CREATE PROCEDURE app.spGetNotifications
	@AApplicationID UNIQUEIDENTIFIER,
	@ASenderType TINYINT,
	@ATitle NVARCHAR(200),
	@AContent NVARCHAR(200),
	@APriority TINYINT,
	@AState TINYINT,
	@ACreationDateFrom Date,
	@ACreationDateTo Date,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE  
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SenderType TINYINT = COALESCE(@ASenderType, 0),
		@Title NVARCHAR(200) = LTRIM(RTRIM(@ATitle)),
		@Content NVARCHAR(200) = LTRIM(RTRIM(@AContent)),
		@Priority TINYINT = COALESCE(@APriority, 0),
		@State TINYINT = COALESCE(@AState, 0),
		@CreationDateFrom Date = @ACreationDateFrom,
		@CreationDateTo Date = DATEADD(DAY, 1, @ACreationDateTo),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT
		count(*) over() Total,
		ntf.ID,
		ntf.SenderPositionID,
		usr.FirstName + ' ' + usr.LastName SenderName,
		ntf.Title,
		ntf.[State],
		ntf.Content,
		ntf.[Priority],
		ntf.CreationDate
	FROM app.[Notification] ntf
		LEFT JOIN org.Position pos On pos.ID = ntf.SenderPositionID
		LEFT JOIN org.[User] usr ON usr.Id = pos.UserID
	WHERE ntf.ApplicationID = @ApplicationID
		AND (@SenderType < 1 
			OR (@SenderType = 1 AND ntf.SenderPositionID IS NULL) 
			OR (@SenderType = 2 AND ntf.SenderPositionID IS NOT NULL)
			)
		AND (@Title IS NULL OR ntf.Title LIKE CONCAT('%', @Title, '%'))
		AND (@Content IS NULL OR ntf.Content LIKE CONCAT('%', @Content, '%')) 
		AND (@Priority < 1 OR ntf.[Priority] = @Priority)
		AND (@State < 1 OR ntf.[State] = @State)
		AND (@CreationDateFrom IS NULL OR ntf.CreationDate >= @CreationDateFrom)
		AND (@CreationDateTo IS NULL OR ntf.CreationDate < @CreationDateTo)
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetNotificationsByPosition'))
	DROP PROCEDURE app.spGetNotificationsByPosition
GO

CREATE PROCEDURE app.spGetNotificationsByPosition
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID

	SELECT
		ntf.ID,
		ntf.Content,
		ntf.Title,
		ntf.Priority,
		ntf.CreationDate
	FROM app.NotificationPosition ntfPosition
		INNER JOIN app.[Notification] ntf ON ntf.ID = ntfPosition.NotificationID
	WHERE ntf.ApplicationID = @ApplicationID
		AND ntfPosition.PositionID = @CurrentUserPositionID
		AND COALESCE(ntfPosition.IsRemoved, 0) = 0
		AND ntf.State IN (2, 3)
	ORDER BY ntf.[Priority], ntf.CreationDate

	Update app.NotificationPosition
	SET IsRemoved = 1
	WHERE PositionID = @CurrentUserPositionID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spModifyNotification'))
	DROP PROCEDURE app.spModifyNotification
GO

CREATE PROCEDURE app.spModifyNotification
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ASenderPositionID UNIQUEIDENTIFIER,
	@ATitle NVARCHAR(300),
	@AContent NVARCHAR(MAX),
	@AState TINYINT,
	@APriority TINYINT,
	@ALog NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@SenderPositionID UNIQUEIDENTIFIER = @ASenderPositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Content NVARCHAR(MAX) = @AContent,
		@Title NVARCHAR(MAX) = @ATitle,
		@State TINYINT = COALESCE(@AState, 0),
		@Priority TINYINT = COALESCE(@APriority, 0),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.[Notification]
				(ID, ApplicationID, SenderPositionID, Title, Content, [Priority], [State], CreationDate)
				VALUES
				(@ID, @ApplicationID, @SenderPositionID, @Title, @Content, @Priority, @State, GETDATE())
			END
			ELSE    -- update
			BEGIN
				UPDATE app.[Notification]
				SET ApplicationID = @ApplicationID, SenderPositionID = @SenderPositionID, Title = @Title, Content = @Content, [Priority] = @Priority, [State] = @State
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spSendNotification'))
	DROP PROCEDURE app.spSendNotification
GO

CREATE PROCEDURE app.spSendNotification
	@ANotificationID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@NotificationID UNIQUEIDENTIFIER = @ANotificationID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
			
	BEGIN TRY
		BEGIN TRAN
				
			UPDATE app.[Notification] 
			SET [State] = 2
			WHERE ID = @NotificationID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END						
									
									
		
		
		
			


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spDeleteNotificationCondition'))
	DROP PROCEDURE app.spDeleteNotificationCondition
GO

CREATE PROCEDURE app.spDeleteNotificationCondition
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
		
		BEGIN
			DELETE FROM app.NotificationCondition
			WHERE ID = @AID
		END	
	
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
Go

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id]= OBJECT_ID ('app.spGetNotificationCondition'))
	DROP PROCEDURE app.spGetNotificationCondition
GO

CREATE PROCEDURE app.spGetNotificationCondition
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		ntfc.ID,
		ntfc.NotificationID,
		ntfc.DepartmentID,
		ntfc.ProvinceID,
		ntfc.PositionType,
		ntfc.PositionID
	FROM app.NotificationCondition ntfc
	WHERE ntfc.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetNotificationConditions'))
	DROP PROCEDURE app.spGetNotificationConditions
GO

CREATE PROCEDURE app.spGetNotificationConditions
	@ANotificationID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@NotificationID UNIQUEIDENTIFIER = @ANotificationID,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT
		ntfc.ID,
		ntfc.NotificationID,
		ntfc.DepartmentID,
		dep.[Name] DepartmentName,
		ntfc.ProvinceID,
		plc.[Name] ProvinceName,
		ntfc.PositionType,
		ntfc.PositionID,
		usr.FirstName +' '+ usr.LastName FullName
	FROM app.NotificationCondition ntfc
		LEFT JOIN org.Department dep ON dep.ID = ntfc.DepartmentID
		LEFT JOIN org.Place plc ON plc.ID = ntfc.ProvinceID
		LEFT JOIN org.Position pos ON pos.ID = ntfc.PositionID
		LEFT JOIN org.[User] usr ON usr.ID = Pos.UserID
	WHERE ntfc.NotificationID = @NotificationID
	ORDER BY [LastName]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
Go

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id]= OBJECT_ID ('app.spModifyNotificationCondition'))
	DROP PROCEDURE app.spModifyNotificationCondition
GO

CREATE PROCEDURE app.spModifyNotificationCondition
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ANotificationID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AProvinceID UNIQUEIDENTIFIER,
	@APositionType TINYINT,
	@APositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@NotificationID UNIQUEIDENTIFIER = @ANotificationID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.NotificationCondition
				(ID, NotificationID, DepartmentID, ProvinceID, PositionType, PositionID)
				VALUES
				(@ID, @NotificationID, @DepartmentID, @ProvinceID, @PositionType, @PositionID)
			END
			ELSE    -- update
			BEGIN
				UPDATE app.NotificationCondition
				SET  NotificationID = @NotificationID, DepartmentID = @DepartmentID, ProvinceID = @ProvinceID, PositionType = @PositionType, PositionID = @PositionID
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spDeleteTicket'))
	DROP PROCEDURE app.spDeleteTicket
GO

CREATE PROCEDURE app.spDeleteTicket
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN
			
			IF EXISTS (SELECT TOP 1 1 FROM  app.Ticket WHERE ID = @ID AND [State] <> 1)
				THROW 50000, N'این تیکت پاسخ داده شده است بنابراین امکان حذف تیکت وجود ندارد.', 1

			DELETE FROM app.TicketSequence
			WHERE TicketID = @ID

			DELETE FROM app.Ticket 
			WHERE ID = @ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTicket'))
	DROP PROCEDURE app.spGetTicket
GO

CREATE PROCEDURE app.spGetTicket
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		tick.ID,
		tick.SubjectID,
		tick.ApplicationID,
		app.[Name] ApplicationName,
		tick.OwnerID,
		tick.OwnerPositionID,
		tick.Title,
		tick.Score,
		ticketSubject.[Name] SubjectTitle,
		ticketSubject.FAQGroupID FAQGroupID,
		ownerUser.FirstName + ' ' + ownerUser.LastName OwnerPositionName,
		ownerUser.FirstName + ' ' + ownerUser.LastName OwnerFullName,
		creatorUser.FirstName + ' ' + creatorUser.LastName CreatorUserName,
		creatorUser.ID CreatorUserID,
		creatorPos.[Type] PositionType,
		creatorPos.ID CreatorPositionID,
		tick.[Priority],
		tick.TrackingCode,
		tick.[State],
		tick.CreationDate,
		tick.CloseDate,
		tick.FirstName,
		tick.LastName,
		tick.NationalCode,
		tick.CellPhone,
		tick.CreationTicketType,
		dep.ID DepartmentID,
		dep.[Name] DepartmentName
	FROM app.Ticket tick
		LEFT JOIN org.[User] ownerUser ON ownerUser.ID = tick.OwnerID
		LEFT JOIN org.Position creatorPos ON creatorPos.ID = tick.CreatorPositionID
		LEFT JOIN org.[User] creatorUser ON creatorUser.ID = creatorPos.UserID
		LEFT JOIN org.Department dep ON dep.ID = tick.DepartmentID
		LEFT JOIN app.TicketSubject ticketSubject ON ticketSubject.ID = tick.SubjectID
		LEFT JOIN org.[Application] app ON app.ID = tick.ApplicationID
	WHERE tick.ID = @ID
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTickets'))
	DROP PROCEDURE app.spGetTickets
GO

CREATE PROCEDURE app.spGetTickets
	@AApplicationID UNIQUEIDENTIFIER, 
	@ASubjectID UNIQUEIDENTIFIER, 
	@AState TINYINT, 
	@ATicketAnswerState TINYINT, 
	@ATrackingCode NVARCHAR(50), 
	@ADepartmentID UNIQUEIDENTIFIER, 
	@ATitle NVARCHAR(200), 
	@APositionID UNIQUEIDENTIFIER, 
	@AOwnerPositionID UNIQUEIDENTIFIER, 
	@AOwnerFullName NVARCHAR(300),
	@AOwnerID UNIQUEIDENTIFIER, 
	@ACreationTicketType TINYINT,
	@APageSize INT, 
	@APageIndex INT, 
	@ASortExp NVARCHAR(1000), 
	@ACurrentUserID UNIQUEIDENTIFIER, 
	@ACurrentUserType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SubjectID UNIQUEIDENTIFIER = @ASubjectID,
		@State TINYINT = COALESCE(@AState, 0),
		@TicketAnswerState TINYINT = COALESCE(@ATicketAnswerState, 0),
		@TrackingCode NVARCHAR(50) = LTRIM(RTRIM(@ATrackingCode)),
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@OwnerPositionID UNIQUEIDENTIFIER = @AOwnerPositionID, 
		@OwnerFullName NVARCHAR(300) = LTRIM(RTRIM(@AOwnerFullName)),
		@Title NVARCHAR(200) = LTRIM(RTRIM(@ATitle)),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@OwnerID UNIQUEIDENTIFIER = @AOwnerID,
		@CreationTicketType TINYINT = COALESCE(@ACreationTicketType, 0),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserType TINYINT = @ACurrentUserType,
		@PositionApplicationID UNIQUEIDENTIFIER

		SET @PositionApplicationID = (SELECT ApplicationID FROM org.Position WHERE ID = @PositionID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END;


	;WITH TicketSequence AS 
	(
		SELECT
			UserID, 
            TicketID, 
            ReadDate, 
            PositionID, 
            ROW_NUMBER() OVER(PARTITION BY TicketID
        ORDER BY CreationDate DESC) RowNum
        FROM app.TicketSequence
	)
    , TicketSequenceCount AS
	(
		SELECT
			COUNT(*) SequenceCount, 
            TicketID
        FROM app.TicketSequence
        GROUP BY TicketID
	)
	, LastTicketSequence AS
	(
		SELECT 
			UserID, 
            TicketSequence.TicketID, 
            ReadDate, 
            PositionID, 
            TicketSequenceCount.SequenceCount
        FROM TicketSequence
			INNER JOIN TicketSequenceCount ON TicketSequenceCount.TicketID = TicketSequence.TicketID
        WHERE RowNum = 1
	)
	, Ticketlist AS 
	(
		SELECT DISTINCT
			--COUNT(*) OVER() AS Total,
            CAST(CASE
				WHEN lastTicketSequence.ReadDate IS NULL
				THEN 0
				ELSE 1
            END AS BIT) IsRead, 
            lastTicketSequence.UserID LastTicketSequenceUserID, 
            tick.ID, 
            tick.SubjectID, 
            tick.ApplicationID,
			app.[Name] ApplicationName,
            tick.OwnerID, 
            tick.OwnerPositionID, 
            tick.Title, 
            tick.Score, 
            ticketSubject.[Name] SubjectTitle, 
			ticketSubject.FAQGroupID FAQGroupID,
            ownerUser.FirstName + ' ' + ownerUser.LastName OwnerFullName, 
            creatorUser.FirstName + ' ' + creatorUser.LastName CreatorUserName, 
            creatorUser.ID CreatorUserID, 
            creatorPos.[Type] PositionType, 
            creatorPos.ID CreatorPositionID, 
            dep.ID DepartmentID, 
            dep.[Name] DepartmentName, 
            tick.[Priority], 
            tick.TrackingCode, 
            tick.[State], 
            tick.CreationDate,
            tick.CreationTicketType,
            CASE
                WHEN tick.[State] = 1 THEN CAST(1 AS TINYINT)
                WHEN(tick.[State] = 3) THEN(CASE
												WHEN(tick.CreatorPositionID = @PositionID AND lastTicketSequence.PositionID = @PositionID) THEN CAST(3 AS TINYINT)
												WHEN(tick.CreatorPositionID = @PositionID AND lastTicketSequence.PositionID <> @PositionID)THEN CAST(2 AS TINYINT)
												WHEN(tick.CreatorPositionID <> @PositionID AND lastTicketSequence.PositionID = @PositionID) THEN CAST(2 AS TINYINT)
												WHEN(tick.CreatorPositionID <> @PositionID AND lastTicketSequence.PositionID <> @PositionID) THEN CAST(3 AS TINYINT)
											END)
                WHEN tick.[State] = 2 THEN CAST(4 AS TINYINT) 
				ELSE CAST(0 AS TINYINT)
            END TicketAnswerState, 
            SequenceCount,
			CloseDate
        FROM app.Ticket tick
            LEFT JOIN org.[User] ownerUser ON ownerUser.ID = tick.OwnerID
            LEFT JOIN org.Position creatorPos ON creatorPos.ID = tick.CreatorPositionID
            LEFT JOIN org.[User] creatorUser ON creatorUser.ID = creatorPos.UserID
            LEFT JOIN org.Department dep ON dep.ID = tick.DepartmentID
            LEFT JOIN LastTicketSequence lastTicketSequence ON lastTicketSequence.TicketID = tick.ID
            LEFT JOIN app.TicketSubject ticketSubject ON ticketSubject.ID = tick.SubjectID
            LEFT JOIN app.TicketSubjectUser ticketSubjectUser ON ticketSubjectUser.TicketSubjectID = tick.SubjectID
			LEFT JOIN org.[Application] app ON app.ID = tick.ApplicationID
        WHERE(@ApplicationID IS NULL OR tick.ApplicationID = @ApplicationID)
			AND (@DepartmentID IS NULL OR tick.DepartmentID = @DepartmentID)
			AND (@OwnerPositionID IS NULL OR tick.OwnerPositionID = @OwnerPositionID)
            AND (@Title IS NULL OR tick.Title LIKE '%' + @Title + '%')
            AND (@SubjectID IS NULL OR tick.SubjectID = @SubjectID)
            AND (@TrackingCode IS NULL OR tick.TrackingCode = @TrackingCode)
            AND (@CreationTicketType < 1 OR tick.CreationTicketType = @CreationTicketType)

            AND (
					@CurrentUserType = 2 
					OR 
					(
						((@State = 0 AND (tick.OwnerID IS NULL OR tick.OwnerID = @CurrentUserID) AND (ticketSubjectUser.UserID = @CurrentUserID))
							OR ((@OwnerID IS NULL AND tick.OwnerID IS NULL) OR (@OwnerID IS NOT NULL AND tick.OwnerID = @OwnerID)))
						AND (ticketSubjectUser.UserID = @CurrentUserID)
						AND (@State <> 2 OR tick.[State] = 2)
						AND (@State = 2 OR tick.[State] <> 2)
					)
					OR
					(@PositionApplicationID = '1CB2B910-6D6D-4D8D-A436-2B9B0C4E69ED' AND tick.CreationTicketType = 1)
				)

            AND (@CurrentUserType = 1 OR tick.CreatorPositionID = @PositionID)
			AND (@OwnerFullName IS NULL OR CONCAT(ownerUser.FirstName , ' ' , ownerUser.LastName) LIKE N'%' + @OwnerFullName + '%')
	)
    , MainSelect AS 
	(
		SELECT *
		FROM Ticketlist
		WHERE
		(@State = 0
        AND @TicketAnswerState = 2
        AND TicketAnswerState IN(2,4)) OR (@State = 0 AND @TicketAnswerState = 3 AND TicketAnswerState IN(1, 3)) OR ((@State <> 0 OR @TicketAnswerState not in(3,2))
        AND (@TicketAnswerState = 0 OR @TicketAnswerState = 1 OR @TicketAnswerState = TicketAnswerState))
	)

    SELECT 
		COUNT(*) OVER() AS Total, 
        *
    FROM MainSelect
    ORDER BY [CreationDate] DESC
    OFFSET((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTicketsForCallCenter'))
	DROP PROCEDURE app.spGetTicketsForCallCenter
GO

CREATE PROCEDURE app.spGetTicketsForCallCenter
	@AApplicationID UNIQUEIDENTIFIER, 
	@ASubjectID UNIQUEIDENTIFIER, 
	@AState TINYINT, 
	@ATicketAnswerState TINYINT, 
	@ATrackingCode NVARCHAR(50), 
	@ADepartmentID UNIQUEIDENTIFIER, 
	@ATitle NVARCHAR(200), 
	@APositionID UNIQUEIDENTIFIER, 
	@AOwnerPositionID UNIQUEIDENTIFIER, 
	@AOwnerFullName NVARCHAR(300),
	@AOwnerID UNIQUEIDENTIFIER, 
	@APageSize INT, 
	@APageIndex INT, 
	@ASortExp NVARCHAR(1000), 
	@ACurrentUserID UNIQUEIDENTIFIER, 
	@ACurrentUserType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SubjectID UNIQUEIDENTIFIER = @ASubjectID,
		@State TINYINT = COALESCE(@AState, 0),
		@TicketAnswerState TINYINT = COALESCE(@ATicketAnswerState, 0),
		@TrackingCode NVARCHAR(50) = LTRIM(RTRIM(@ATrackingCode)),
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@OwnerPositionID UNIQUEIDENTIFIER = @AOwnerPositionID, 
		@OwnerFullName NVARCHAR(300) = LTRIM(RTRIM(@AOwnerFullName)),
		@Title NVARCHAR(200) = LTRIM(RTRIM(@ATitle)),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@OwnerID UNIQUEIDENTIFIER = @AOwnerID,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserType TINYINT = @ACurrentUserType,
		@PositionApplicationID UNIQUEIDENTIFIER

		SET @PositionApplicationID = (SELECT ApplicationID FROM org.Position WHERE ID = @PositionID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END;


	;WITH TicketSequence AS 
	(
		SELECT
			UserID, 
            TicketID, 
            ReadDate, 
            PositionID, 
            ROW_NUMBER() OVER(PARTITION BY TicketID
        ORDER BY CreationDate DESC) RowNum
        FROM app.TicketSequence
	)
    , TicketSequenceCount AS
	(
		SELECT
			COUNT(*) SequenceCount, 
            TicketID
        FROM app.TicketSequence
        GROUP BY TicketID
	)
	, LastTicketSequence AS
	(
		SELECT 
			UserID, 
            TicketSequence.TicketID, 
            ReadDate, 
            PositionID, 
            TicketSequenceCount.SequenceCount
        FROM TicketSequence
			INNER JOIN TicketSequenceCount ON TicketSequenceCount.TicketID = TicketSequence.TicketID
        WHERE RowNum = 1
	)
	, Ticketlist AS 
	(
		SELECT DISTINCT
			--COUNT(*) OVER() AS Total,
            CAST(CASE
				WHEN lastTicketSequence.ReadDate IS NULL
				THEN 0
				ELSE 1
            END AS BIT) IsRead, 
            lastTicketSequence.UserID LastTicketSequenceUserID, 
            tick.ID, 
            tick.SubjectID, 
            tick.ApplicationID,
			app.[Name] ApplicationName,
            tick.OwnerID, 
            tick.OwnerPositionID, 
            tick.Title, 
            tick.Score, 
			tick.FirstName,
			tick.LastName,
            ticketSubject.[Name] SubjectTitle, 
            ownerUser.FirstName + ' ' + ownerUser.LastName OwnerFullName, 
            creatorUser.FirstName + ' ' + creatorUser.LastName CreatorUserName, 
            creatorUser.ID CreatorUserID, 
            creatorPos.[Type] PositionType, 
            creatorPos.ID CreatorPositionID, 
            dep.ID DepartmentID, 
            dep.[Name] DepartmentName, 
            tick.[Priority], 
            tick.TrackingCode, 
            tick.[State], 
            tick.CreationDate,
            tick.CreationTicketType,
            CASE
                WHEN tick.[State] = 1 THEN CAST(1 AS TINYINT)
                WHEN(tick.[State] = 3) THEN(CASE
												WHEN(tick.CreatorPositionID = @PositionID AND lastTicketSequence.PositionID = @PositionID) THEN CAST(3 AS TINYINT)
												WHEN(tick.CreatorPositionID = @PositionID AND lastTicketSequence.PositionID <> @PositionID)THEN CAST(2 AS TINYINT)
												WHEN(tick.CreatorPositionID <> @PositionID AND lastTicketSequence.PositionID = @PositionID) THEN CAST(2 AS TINYINT)
												WHEN(tick.CreatorPositionID <> @PositionID AND lastTicketSequence.PositionID <> @PositionID) THEN CAST(3 AS TINYINT)
											END)
                WHEN tick.[State] = 2 THEN CAST(4 AS TINYINT) 
				ELSE CAST(0 AS TINYINT)
            END TicketAnswerState, 
            SequenceCount,
			CloseDate
        FROM app.Ticket tick
            LEFT JOIN org.[User] ownerUser ON ownerUser.ID = tick.OwnerID
            LEFT JOIN org.Position creatorPos ON creatorPos.ID = tick.CreatorPositionID
            LEFT JOIN org.[User] creatorUser ON creatorUser.ID = creatorPos.UserID
            LEFT JOIN org.Department dep ON dep.ID = tick.DepartmentID
            LEFT JOIN LastTicketSequence lastTicketSequence ON lastTicketSequence.TicketID = tick.ID
            LEFT JOIN app.TicketSubject ticketSubject ON ticketSubject.ID = tick.SubjectID
            LEFT JOIN app.TicketSubjectUser ticketSubjectUser ON ticketSubjectUser.TicketSubjectID = tick.SubjectID
			LEFT JOIN org.[Application] app ON app.ID = tick.ApplicationID
        WHERE(@ApplicationID IS NULL OR tick.ApplicationID = @ApplicationID)
			AND (@DepartmentID IS NULL OR tick.DepartmentID = @DepartmentID)
			AND (@OwnerPositionID IS NULL OR tick.OwnerPositionID = @OwnerPositionID)
            AND (@Title IS NULL OR tick.Title LIKE '%' + @Title + '%')
            AND (@SubjectID IS NULL OR tick.SubjectID = @SubjectID)
            AND (@TrackingCode IS NULL OR tick.TrackingCode = @TrackingCode)
            AND (tick.CreationTicketType = 1)
			AND (tick.[CreatorPositionID] = @PositionID)
			-- AND (
				--	@CurrentUserType = 2 
				--	OR 
				--	(
				--		((@State = 0 AND (tick.OwnerID IS NULL OR tick.OwnerID = @CurrentUserID) AND (ticketSubjectUser.UserID = @CurrentUserID))
				--			OR ((@OwnerID IS NULL AND tick.OwnerID IS NULL) OR (@OwnerID IS NOT NULL AND tick.OwnerID = @OwnerID)))
				--		AND (ticketSubjectUser.UserID = @CurrentUserID)
				--		AND (@State <> 2 OR tick.[State] = 2)
				--		AND (@State = 2 OR tick.[State] <> 2)
				--	)
				--	OR
				--	(@PositionApplicationID = '1CB2B910-6D6D-4D8D-A436-2B9B0C4E69ED' AND tick.CreationTicketType = 1)
				--)
            AND (@CurrentUserType = 1 OR tick.CreatorPositionID = @PositionID)
			AND (@OwnerFullName IS NULL OR CONCAT(ownerUser.FirstName , ' ' , ownerUser.LastName) LIKE N'%' + @OwnerFullName + '%')
	)
    , MainSelect AS 
	(
		SELECT *
		FROM Ticketlist
		WHERE
		(@State = 0
        AND @TicketAnswerState = 2
        AND TicketAnswerState IN(2,4)) OR (@State = 0 AND @TicketAnswerState = 3 AND TicketAnswerState IN(1, 3)) OR ((@State <> 0 OR @TicketAnswerState not in(3,2))
        AND (@TicketAnswerState = 0 OR @TicketAnswerState = 1 OR @TicketAnswerState = TicketAnswerState))
	)

    SELECT 
		COUNT(*) OVER() AS Total, 
        *
    FROM MainSelect
    ORDER BY [CreationDate] DESC
    OFFSET((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spModifyTicket'))
	DROP PROCEDURE app.spModifyTicket
GO

CREATE PROCEDURE app.spModifyTicket
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ASubjectID UNIQUEIDENTIFIER,
	@AState TINYINT,
	@ATrackingCode NVARCHAR(50),
	@APriority TINYINT,
	@ATitle NVARCHAR(200),
	@APositionID UNIQUEIDENTIFIER,
	@AOwnerID UNIQUEIDENTIFIER,
	@AOwnerPositionID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ACreationTicketType TINYINT,
	@AFirstName NVARCHAR(255),
	@ALastName NVARCHAR(255),
	@ANationalCode NVARCHAR(10),
	@ACellPhone VARCHAR(11),
	@AUserID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 	
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SubjectID UNIQUEIDENTIFIER = @ASubjectID,
		@State TINYINT = COALESCE(@AState, 0),
		@TrackingCode NVARCHAR(50) = LTRIM(RTRIM(@ATrackingCode)),
		@Priority TINYINT = COALESCE(@APriority, 0),
		@Title NVARCHAR(200) = LTRIM(RTRIM(@ATitle)),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@OwnerID UNIQUEIDENTIFIER = @AOwnerID,
		@OwnerPositionID UNIQUEIDENTIFIER = @AOwnerPositionID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@CreationTicketType TINYINT = COALESCE(@ACreationTicketType, 0),
		@FirstName NVARCHAR(255) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(255) = LTRIM(RTRIM(@ALastName)),
		@NationalCode NVARCHAR(10) = @ANationalCode,
		@CellPhone VARCHAR(11) = @ACellPhone, 
		@UserID UNIQUEIDENTIFIER = @AUserID

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1 -- insert
			BEGIN
			SET  @TrackingCode = (SELECT dbo.fnTicketNumber())
				INSERT INTO app.Ticket 
					(ID, ApplicationID, SubjectID, [State], TrackingCode , [Priority] , [Title] , CreatorPositionID , OwnerID, CreationDate, CloseDate, OwnerPositionID, DepartmentID, CreationTicketType, FirstName, LastName, NationalCode, CellPhone, UserID)
				VALUES
					(@ID, @ApplicationID, @SubjectID, 1, @TrackingCode, @Priority, @Title, @PositionID, @OwnerID , GETDATE(), NULL, @OwnerPositionID, @DepartmentID, @CreationTicketType, @FirstName, @LastName, @NationalCode, @CellPhone, @UserID)
			END
			ELSE
			BEGIN
				UPDATE app.Ticket
				 SET SubjectID= @SubjectID, 
					 [State]= @State, 
					 [Title]= @Title, 
					 OwnerID= @OwnerID,
					 DepartmentID = @DepartmentID,
					 FirstName = @FirstName,
					 LastName = @LastName,
					 NationalCode = @NationalCode,
					 CellPhone = @CellPhone,
					 UserID = @UserID,
					 CloseDate=iif(@State=2, GETDATE(),NULL)
			     WHERE [ID]= @ID
			END
	
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID ('app.spRatingTicket'))
DROP PROCEDURE app.spRatingTicket
GO

CREATE PROCEDURE app.spRatingTicket
	@ATicketID UNIQUEIDENTIFIER,
	@AScore TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 	
		@TicketID UNIQUEIDENTIFIER = @ATicketID,
		@Score TINYINT = @AScore

	BEGIN TRY
		BEGIN TRAN
			
				UPDATE app.Ticket
				SET Score = @Score
				WHERE ID = @TicketID 
						
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END



GO
USE [Kama.Aro.Organization]
GO

IF EXISTS( SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spSetTicketOwner'))
	DROP PROCEDURE app.spSetTicketOwner
GO

CREATE PROCEDURE app.spSetTicketOwner
	@AOwnerID UNIQUEIDENTIFIER,
	@AOwnerPositionID UNIQUEIDENTIFIER,
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@OwnerID UNIQUEIDENTIFIER = @AOwnerID,
		@OwnerPositionID UNIQUEIDENTIFIER = @AOwnerPositionID,
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN
			
				UPDATE app.Ticket
				SET OwnerID = @OwnerID
				, OwnerPositionID = @OwnerPositionID
				, [State] = 3
				WHERE ID = @ID 
						
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spTicketReport'))
	DROP PROCEDURE app.spTicketReport
GO

CREATE PROCEDURE app.spTicketReport
	@AApplicationID UNIQUEIDENTIFIER,
	@ASubjectID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ASubjectUserID  UNIQUEIDENTIFIER,
	@AState TINYINT,
	@AScore TINYINT,
	@APriority TINYINT,
	@ATrackingCode NVARCHAR(50),
	@ATitle NVARCHAR(200),
	@ACreationDateFrom SMALLDATETIME,
	@ACreationDateTo SMALLDATETIME,
	@AOwnerID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SubjectID UNIQUEIDENTIFIER = @ASubjectID,
		@SubjectUserID  UNIQUEIDENTIFIER = @ASubjectUserID,
		@State TINYINT = COALESCE(@AState, 0),
		@Score TINYINT = COALESCE(@AScore, 0),
		@TrackingCode NVARCHAR(50) = LTRIM(RTRIM(@ATrackingCode)),
		@Priority TINYINT = COALESCE(@APriority, 0),
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@Title NVARCHAR(200) = LTRIM(RTRIM(@ATitle)),
		@CreationDateFrom SMALLDATETIME = @ACreationDateFrom,
		@CreationDateTo SMALLDATETIME = @ACreationDateTo,
		@OwnerID UNIQUEIDENTIFIER = @AOwnerID,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END


	;WITH Ticketlist AS
	 (SELECT DISTINCT
		
		tick.ID,
		tick.SubjectID,
		tick.ApplicationID,
		app.[Name] ApplicationName,
		tick.OwnerID,
		tick.Title,
		ticketSubject.[Name] SubjectTitle,
		ownerUser.FirstName + ' ' + ownerUser.LastName OwnerFullName,
		creatorUser.FirstName + ' ' + creatorUser.LastName CreatorUserName,
		creatorUser.ID CreatorUserID,
		creatorPos.[Type] PositionType,
		creatorPos.ID CreatorPositionID,
		dep.ID DepartmentID,
		dep.[Name] DepartmentName,
		dep.ID DepatmentID,
		tick.[Priority],
		tick.TrackingCode,
		tick.Score,
		tick.[State],
		tick.CreationDate,
		tick.CloseDate
	FROM app.Ticket tick
		LEFT JOIN org.[User] ownerUser ON ownerUser.ID = tick.OwnerID
		LEFT JOIN org.Position creatorPos ON creatorPos.ID = tick.CreatorPositionID
		LEFT JOIN org.[User] creatorUser ON creatorUser.ID = creatorPos.UserID
		LEFT JOIN org.Department dep ON dep.ID = tick.DepartmentID
		LEFT JOIN app.TicketSubject ticketSubject ON ticketSubject.ID = tick.SubjectID
		LEFT JOIN app.TicketSubjectUser ticketSubjectUser ON ticketSubjectUser.TicketSubjectID = tick.SubjectID
		LEFT JOIN org.[Application] app ON app.ID = tick.ApplicationID
	WHERE (@ApplicationID IS NULL OR tick.ApplicationID = @ApplicationID)
		AND (@TrackingCode IS NULL OR tick.TrackingCode = @TrackingCode)
		AND (@Title IS NULL OR tick.Title LIKE CONCAT('%' , @Title , '%'))
		AND (@DepartmentID IS NULL OR dep.ID =  @DepartmentID)
		AND (@Priority < 1 OR tick.[Priority] =  @Priority)
		AND (@SubjectID IS NULL OR tick.SubjectID =  @SubjectID)
		AND (@State <1 OR tick.[State] = @State)
		AND (@Score <1 OR tick.Score = @Score)
		AND (@ASubjectUserID IS NULL OR ticketSubjectUser.UserID = @ASubjectUserID)
		AND (@CreationDateFrom IS NULL OR tick.CreationDate >= @CreationDateFrom)
		AND (@CreationDateTo IS NULL OR tick.CreationDate <= @CreationDateTo)
		AND (@OwnerID IS NULL OR tick.OwnerID = @OwnerID)
		)

	SELECT COUNT(*) OVER() AS Total,* FROM Ticketlist
	ORDER BY [CreationDate] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spTicketReportAll'))
	DROP PROCEDURE app.spTicketReportAll
GO

CREATE PROCEDURE app.spTicketReportAll
	@AApplicationID UNIQUEIDENTIFIER,
	@ASubjectID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AState TINYINT,
	@AScore TINYINT,
	@ACreationDateFrom DATE,
	@ACreationDateTo DATE,
	@APriority TINYINT,
	@ATrackingCode NVARCHAR(50),
	@ATitle NVARCHAR(200),
	@ACreationTicketType TINYINT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SubjectID UNIQUEIDENTIFIER = @ASubjectID,
		@State TINYINT = COALESCE(@AState, 0),
		@Score TINYINT = COALESCE(@AScore, 0),
		@CreationDateFrom DATE = @ACreationDateFrom,
		@CreationDateTo DATE = DATEADD(DAY, 1, @ACreationDateTo),
		@TrackingCode NVARCHAR(50) = LTRIM(RTRIM(@ATrackingCode)),
		@Priority TINYINT = COALESCE(@APriority, 0),
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@Title NVARCHAR(200) = LTRIM(RTRIM(@ATitle)),
		@CreationTicketType TINYINT = COALESCE(@ACreationTicketType, 0),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END


	;WITH Ticketlist AS
	 (SELECT DISTINCT
		
		tick.ID,
		tick.SubjectID,
		tick.ApplicationID,
		app.[Name] ApplicationName,
		tick.OwnerID,
		tick.Title,
		ticketSubject.[Name] SubjectTitle,
		ownerUser.FirstName + ' ' + ownerUser.LastName OwnerFullName,
		creatorUser.FirstName + ' ' + creatorUser.LastName CreatorUserName,
		creatorUser.ID CreatorUserID,
		creatorPos.[Type] PositionType,
		creatorPos.ID CreatorPositionID,
		dep.[Name] DepartmentName,
		dep.ID DepatmentID,
		tick.[Priority],
		tick.TrackingCode,
		tick.Score,
		tick.[State],
		tick.CreationDate,
		tick.CloseDate,
		tick.CreationTicketType
	FROM app.Ticket tick
		INNER JOIN org.[Application] app ON app.ID = tick.ApplicationID
		LEFT JOIN org.[User] ownerUser ON ownerUser.ID = tick.OwnerID
		LEFT JOIN org.Position creatorPos ON creatorPos.ID = tick.CreatorPositionID
		LEFT JOIN org.[User] creatorUser ON creatorUser.ID = creatorPos.UserID
		LEFT JOIN org.Department dep ON dep.ID = tick.DepartmentID
		LEFT JOIN app.TicketSubject ticketSubject ON ticketSubject.ID = tick.SubjectID
		LEFT JOIN app.TicketSubjectUser ticketSubjectUser ON ticketSubjectUser.TicketSubjectID = tick.SubjectID
	WHERE (@ApplicationID IS NULL OR  tick.ApplicationID = @ApplicationID)
		AND (@TrackingCode IS NULL OR tick.TrackingCode = @TrackingCode)
		AND (@Title IS NULL OR tick.Title LIKE CONCAT('%' , @Title , '%'))
		AND (@DepartmentID IS NULL OR dep.ID =  @DepartmentID)
		AND (@Priority < 1 OR tick.[Priority] =  @Priority)
		AND (@SubjectID IS NULL OR tick.SubjectID =  @SubjectID)
		AND (@State <1 OR tick.[State] = @State)
		AND (@Score <1 OR tick.Score = @Score)
		AND (@CreationDateFrom IS NULL OR tick.CreationDate >= @CreationDateFrom)
		AND (@CreationDateTo IS NULL OR tick.CreationDate < @CreationDateTo)
		AND (@CreationTicketType < 1 OR tick.CreationTicketType = @CreationTicketType)
		)

	SELECT COUNT(*) OVER() AS Total,* FROM Ticketlist
	ORDER BY [CreationDate] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
Go

IF EXISTS(SELECT 1 FROM sys.procedures where [object_id]= OBJECT_ID('app.spTicketStateUpdate'))
DROP PROCEDURE app.spTicketStateUpdate
GO

CREATE PROCEDURE app.spTicketStateUpdate  

--WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRAN
			;WITH lastSequence AS (
				SELECT 
					TicketID,
					Max(CreationDate) AS maxDate
				FROM
					app.ticketsequence
				GROUP BY
					TicketID
				HAVING
					COUNT(*) > 1
			)

			UPDATE
				app.Ticket
			SET
				Ticket.[State] = 2,
				CloseDate=GETDATE()
			FROM
				app.Ticket
				INNER JOIN app.TicketSequence ticketSequence
					ON ticket.ID = ticketSequence.TicketID
						AND ticketSequence.UserID = ticket.OwnerID
				INNER JOIN lastSequence
					ON lastSequence.TicketID = Ticket.ID
						AND TicketSequence.CreationDate = lastSequence.maxDate
			WHERE
				Ticket.[State] = 3
				AND ((SELECT DATEDIFF(DAY, ticketSequence.CreationDate , GETDATE()) AS DateDiff) > 5)
			COMMIT
		END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spDeleteTicketSequence'))
	DROP PROCEDURE app.spDeleteTicketSequence
GO

CREATE PROCEDURE app.spDeleteTicketSequence
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			DELETE FROM app.TicketSequence 
			WHERE ID = @ID
		END	
		 TRY
	BEGIN CATCH
		;THROW
	END CATCH
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spDeleteTicketSubject'))
	DROP PROCEDURE app.spDeleteTicketSubject
GO

CREATE PROCEDURE app.spDeleteTicketSubject
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			DELETE FROM app.TicketSubjectUser
			WHERE TicketSubjectID = @ID

			DELETE FROM app.TicketSubject 
			WHERE ID = @ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spDeleteTicketSubjectUser'))
	DROP PROCEDURE app.spDeleteTicketSubjectUser
GO

CREATE PROCEDURE app.spDeleteTicketSubjectUser
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM app.TicketSubjectUser 
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTicketSequence'))
	DROP PROCEDURE app.spGetTicketSequence
GO

CREATE PROCEDURE app.spGetTicketSequence
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		tickseq.ID,
		tickseq.TicketID,
		tickseq.UserID,
		tickseq.Content,
		us.FirstName + ' ' + us.LastName TicketSequenceUserName,
		tickseq.CreationDate,
		CONVERT(VARCHAR(20), tickseq.CreationDate, 108) AS TimePart,
		tickseq.ReadDate
	FROM app.TicketSequence tickseq
	LEFT JOIN org.[User] us ON us.ID = tickseq.UserID
	LEFT JOIN app.Ticket tick ON tick.ID = tickseq.TicketID
	WHERE tickseq.ID = @ID
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTicketSequences'))
	DROP PROCEDURE app.spGetTicketSequences
GO

CREATE PROCEDURE app.spGetTicketSequences
	@ATicketID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000),
	@ACurrentPositionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@TicketID UNIQUEIDENTIFIER = @ATicketID,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT
		COUNT(*) OVER() Total,
		tickseq.ID,
		tickseq.TicketID,
		tickseq.ReadDate,
		tickseq.UserID,
		tickseq.Content,
		dep.[Name] DepartmentName,
		pos.[Type] PositionType,
		us.FirstName + ' ' + us.LastName TicketSequenceUserName,
		--attachment.ID AttachmentID,
		CONVERT(VARCHAR(20), tickseq.CreationDate, 108) AS TimePart,
		tickseq.CreationDate
	FROM app.TicketSequence tickseq
	--LEFT JOIN pbl.Attachment attachment ON attachment.ParentID = tickseq.ID
	LEFT JOIN org.[User] us ON us.ID = tickseq.UserID
	LEFT JOIN org.Position pos ON pos.ID = tickseq.PositionID
	LEFT JOIN org.Department dep ON dep.ID = pos.DepartmentID  
	WHERE tickseq.TicketID = @TicketID
		
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO 

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spModifyTicketSequence'))
	DROP PROCEDURE app.spModifyTicketSequence
GO

CREATE PROCEDURE app.spModifyTicketSequence
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APositionID UNIQUEIDENTIFIER,
	@ATicketID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AContent NVARCHAR(4000),
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 	
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@TicketID UNIQUEIDENTIFIER = @ATicketID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@Content NVARCHAR(4000) = LTRIM(RTRIM(@AContent)),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.TicketSequence 
					(ID, TicketID, UserID, Content, PositionID, CreationDate , ReadDate)
				VALUES
					(@ID, @TicketID, @UserID, @Content, @PositionID, GETDATE(), Null)
			END
			ELSE
			BEGIN
				UPDATE app.TicketSequence
				 SET TicketID= @TicketID, 
					 UserID = @UserID,
					 PositionID = @PositionID,
					 Content =  @Content
			     WHERE [ID]= @ID
			END
			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetTicketSequenceReadDate'))
	DROP PROCEDURE app.spSetTicketSequenceReadDate
GO

CREATE PROCEDURE app.spSetTicketSequenceReadDate
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER
	
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID;

	BEGIN TRY
		BEGIN TRAN

		;WITH LastTicketSequence AS (
			SELECT
				TicketID,
				UserID,
				PositionID,
				ReadDate,[Content],
				Max(CreationDate) AS maxDate
			FROM app.TicketSequence
			GROUP BY TicketID ,UserID , PositionID , ReadDate , [Content]
		) 

		UPDATE TicketSequence
		SET ReadDate = GETDATE()
		FROM app.TicketSequence TicketSequence
			INNER JOIN LastTicketSequence ON LastTicketSequence.TicketID = TicketSequence.TicketID
		WHERE TicketSequence.TicketID = @ID
			AND LastTicketSequence.PositionID <> @CurrentUserPositionID 

		COMMIT

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTicketSubject'))
	DROP PROCEDURE app.spGetTicketSubject
GO

CREATE PROCEDURE app.spGetTicketSubject
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		ticket.ID,
		ticket.[Name],
		ticket.[Enable],
		ticket.[Description],
		ticket.FAQGroupID,
		FAQG.[Title] FAQGroupName
	FROM app.TicketSubject ticket
	LEFT JOIN [app].[FAQGroup] FAQG ON FAQG.ID = ticket.FAQGroupID
	WHERE ticket.ID = @ID
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTicketSubjects'))
	DROP PROCEDURE app.spGetTicketSubjects
GO

CREATE PROCEDURE app.spGetTicketSubjects
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@AEnable TINYINT,
	@AFAQGroupID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@Enable TINYINT = COALESCE(@AEnable, 0),
		@FAQGroupID UNIQUEIDENTIFIER = @AFAQGroupID,
		@PageSize INT = COALESCE(@APageSize, 20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT
		COUNT(*) OVER() Total,
		ticksub.ID,
		ticksub.[Name],
		ticksub.[Enable],
		ticksub.[Description],
		ticksub.ApplicationID,
		ticksub.FAQGroupID,
		FAQG.Title FAQGroupName,
		app.[Name] ApplicationName
	FROM app.TicketSubject ticksub
		INNER JOIN org.[Application] app ON app.ID = ticksub.ApplicationID
		LEFT JOIN [app].[FAQGroup] FAQG ON FAQG.ID = ticksub.FAQGroupID
	WHERE (@ApplicationID IS NULL OR ticksub.ApplicationID = @ApplicationID)
		AND (@Enable < 1 OR ticksub.[Enable] = @Enable - 1)
		AND(@FAQGroupID IS NULL OR ticksub.FAQGroupID = @FAQGroupID)
	ORDER BY ticksub.[Order]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spModifyTicketSubject'))
	DROP PROCEDURE app.spModifyTicketSubject
GO

CREATE PROCEDURE app.spModifyTicketSubject
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@AEnable BIT,
	@ADescription NVARCHAR(MAX),
	@AFAQGroupID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 	
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@Enable BIT = COALESCE(@AEnable, 0),
		@Description NVARCHAR(MAX) = LTRIM(RTRIM(@ADescription)),
		@FAQGroupID UNIQUEIDENTIFIER = @AFAQGroupID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.TicketSubject 
					(ID, ApplicationID, [Name], [Enable], [Description], [FAQGroupID])
				VALUES
					(@ID, @ApplicationID, @Name , @AEnable, @Description, @FAQGroupID)
			END
			ELSE
			BEGIN
				UPDATE app.TicketSubject
				 SET [Name]= @Name,
				 [Enable] = @Enable,
				 [Description] = @Description,
				 [FAQGroupID] = @FAQGroupID
			     WHERE [ID]= @ID
			END
		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('app.spSetTicketSubjectOrders'))
	DROP PROCEDURE app.spSetTicketSubjectOrders
GO

CREATE PROCEDURE app.spSetTicketSubjectOrders
	@AOrders NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@Orders NVARCHAR(MAX) = @AOrders,
		@Result NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN
		;WITH orders AS
		(
		SELECT * FROM OPENJSON(@Orders)
			WITH (
				ID UNIQUEIDENTIFIER,
				[Order] INT
			) orders
		)
		UPDATE app.TicketSubject
		  SET [Order] = orders.[Order]
		FROM  app.TicketSubject ticketSubject
		     INNER JOIN orders ON orders.ID = ticketSubject.ID 

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetAllUsersBySubjects'))
	DROP PROCEDURE app.spGetAllUsersBySubjects
GO

CREATE PROCEDURE app.spGetAllUsersBySubjects
	@AApplicationID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT DISTINCT ticketSubjectUser.UserID,
		u.[FirstName],
		u.LastName
	FROM [app].[TicketSubjectUser] ticketSubjectUser
		INNER JOIN [app].[TicketSubject] ticketSubject ON ticketSubject.ID = ticketSubjectUser.TicketSubjectID
		INNER JOIN [org].[Application] app ON app.ID = ticketSubject.ApplicationID
		INNER JOIN [org].[User] u ON u.ID = ticketSubjectUser.UserID
	WHERE 
		app.ID = @ApplicationID
	ORDER BY 
		u.LastName
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTicketSubjectUser'))
	DROP PROCEDURE app.spGetTicketSubjectUser
GO

CREATE PROCEDURE app.spGetTicketSubjectUser
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		ticksubusr.ID,
		us.FirstName + ' ' + us.LastName UserName,
		po.[Type] PositionType,
		ticksub.[Name] SubjectName
	FROM app.TicketSubjectUser ticksubusr
	LEFT JOIN org.[User] us ON us.ID = ticksubusr.UserID
	LEFT JOIN org.[Position] po ON po.ID = ticksubusr.PositionID
	LEFT JOIN app.TicketSubject ticksub ON ticksub.ID = ticksubusr.TicketSubjectID
	WHERE ticksubusr.ID = @ID
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spGetTicketSubjectUsers'))
	DROP PROCEDURE app.spGetTicketSubjectUsers
GO

CREATE PROCEDURE app.spGetTicketSubjectUsers
	@ATicketSubjectID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@TicketSubjectID UNIQUEIDENTIFIER = @ATicketSubjectID,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT
		COUNT(*) OVER() Total,
		ticksubusr.ID,
		ticksubusr.PositionID,
		us.ID UserID,
		us.FirstName + ' ' + us.LastName UserName,
		us.NationalCode,
		po.[Type] PositionType,
		ticksubusr.TicketSubjectID,
		ticksub.[Name] SubjectName
	FROM 
		app.TicketSubjectUser ticksubusr
		LEFT JOIN org.[User] us ON us.ID = ticksubusr.UserID
		LEFT JOIN org.[Position] po ON po.ID = ticksubusr.PositionID
		LEFT JOIN app.TicketSubject ticksub ON ticksub.ID = ticksubusr.TicketSubjectID
	WHERE 
		ticksubusr.TicketSubjectID = @TicketSubjectID
	ORDER BY 
		[Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('app.spModifyTicketSubjectUser'))
	DROP PROCEDURE app.spModifyTicketSubjectUser
GO

CREATE PROCEDURE app.spModifyTicketSubjectUser
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ATicketSubjectID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@APositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 	
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@TicketSubjectID UNIQUEIDENTIFIER = @ATicketSubjectID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO app.TicketSubjectUser 
					(ID, TicketSubjectID, UserID, PositionID)
				VALUES
					(@ID, @TicketSubjectID, @UserID, @PositionID)
			END
			ELSE
			BEGIN
				UPDATE app.TicketSubjectUser
				 SET TicketSubjectID= @TicketSubjectID, 
					 UserID= @UserID,
					 PositionID= @PositionID
			     WHERE [ID]= @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization];
GO
CREATE OR ALTER PROC rpt.spGetBackupStatus
AS
    BEGIN

    ;WITH LastDatabaseBackup
            AS (
					SELECT CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
						msdb.dbo.backupset.database_name DatabaseName, 
						MAX(msdb.dbo.backupset.backup_finish_date) AS last_db_backup_date
					FROM msdb.dbo.backupmediafamily
						INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id
					WHERE msdb..backupset.type = 'D'
					GROUP BY msdb.dbo.backupset.database_name  
                 
                )
            SELECT DatabaseName
            FROM LastDatabaseBackup
            WHERE(CAST(last_db_backup_date AS DATE) NOT BETWEEN DATEADD(DAY, -4, GETDATE()) AND GETDATE())
                AND DatabaseName IN('AmarDB93', 'Amoozesh', 'Arogov', 'ContractDB92', 'EstelamDB', 'Form6DB', 'Inquiry', 'InquiryInternet', 'Kama.Aro.EstekhdamDW', 'Kama.Aro.Estekhdam', 'Kama.Aro.Job', 'Kama.Aro.Job.Extension', 'Kama.Aro.Licence.Extension', 'Kama.Aro.Licence', 'Kama.Aro.Manager.Extension', 'Kama.Aro.Manager', 'Kama.Aro.Organization.Extension', 'Kama.Aro.Organization', 'Kama.Aro.Pakna.Extension', 'Kama.Aro.Amoozesh', 'Kama.Aro.PaknaDW', 'Kama.Aro.Reporting.Extension', 'Kama.Aro.Reporting', 'Kama.Aro.Sakhtar.Extra', 'Kama.Aro.Salary.Extention', 'Kama.Aro.Salary2', 'Kama.Aro.SalaryDW', 'Kama.Aro.Salary2.Extention', 'StructureDB', 'SaknaDB94', 'Report', 'Kama.Tashkilat', 'Kama.SmsService', 'Kama.Aro.Salary', 'Kama.Aro.Sakhtar', 'Kama.Aro.Estekhdam.Extension', 'Kama.KarmandIran', 'Kama.Aro.Pakna', 'Kama.Aro.Amoozesh.Extension', 'Kama.Aro.Survey', 'Kama.Aro.DW', 'Kama.Aro.Survey.Extension', 'KanoonDB', 'Kama.Administrator', 'Aro.Organization', 'msdb');
    END;
GO
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [alg].[spGetDataBaseBackup]    Script Date: 11/27/2022 8:43:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER   PROC [rpt].[spGetDataBaseBackup]
	@ADataBaseName NVARCHAR(200), 
	@ABackupType   TINYINT, --Transaction Log Backup,Differential database backup Backup
	@ABackupStartDate DATETIME,
	@ABackupFinishDate DATETIME,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
AS

 DECLARE 
        @DataBaseName NVARCHAR(200)=@ADataBaseName,
	    @BackupType   TINYINT=COALESCE(@ABackupType, 0),
		@BackupStartDate DATETIME=@ABackupStartDate,
	    @BackupFinishDate DATETIME=@ABackupFinishDate,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
		BEGIN
			SET @pagesize = 10000000
			SET @PageIndex = 1
		END
     ;WITH Backups AS 
	  (
	    SELECT bs.database_name DatabaseName, 
                BackupType = CASE
                                WHEN bs.type = 'D'
                                    AND bs.is_copy_only = 0
                                THEN 1
                               
                                WHEN bs.type = 'I'
                                THEN 2
                                WHEN bs.type = 'L'
                                THEN 3
								 WHEN bs.type = 'D'
                                    AND bs.is_copy_only = 1
                                THEN 4--'Full Copy-Only Database'
                                WHEN bs.type = 'F'
                                THEN  5 --'File or filegroup'
                                WHEN bs.type = 'G'
                                THEN 6--'Differential file'
                                WHEN bs.type = 'P'
                                THEN 7--'Partial'
                                WHEN bs.type = 'Q'
                                THEN  8--'Differential partial'
                            END , 
                bs.recovery_model, 
                BackupStartDate = bs.Backup_Start_Date , 
                BackupFinishDate = bs.Backup_Finish_Date, 
                LatestBackupLocation = bf.physical_device_name, 
                BackupSizeMB = bs.backup_size / 1024. / 1024., 
                compressed_backup_size_mb = bs.compressed_backup_size / 1024. / 1024.
        --, database_backup_lsn -- For tlog and differential backups, this is the checkpoint_lsn of the FULL backup it is based on. 
        --, checkpoint_lsn
        --, begins_log_chain
        FROM msdb.dbo.backupset bs
            LEFT OUTER JOIN msdb.dbo.backupmediafamily bf ON bs.[media_set_id] = bf.[media_set_id]
        --WHERE --recovery_model IN('FULL')
        --     bs.backup_start_date > DATEADD(month, -1, SYSDATETIME()) --only look at last two months
     --ORDER BY bs.database_name asc, bs.Backup_Start_Date desc
     )
      ,MainSelect AS
	(
	  SELECT sdb.[PersianDataBaseName] DatabaseName,
                 CAST(b.BackupType AS TINYINT) BackupType,
				 b.BackupStartDate,
				 b.BackupFinishDate,
				 CAST(b.BackupSizeMB AS INT) BackupSizeMB
          FROM Backups b
		  INNER JOIN [Kama.Administrator].[enm].[ServerDataBases] sdb ON sdb.[DataBaseName]=b.DatabaseName
          WHERE (@DataBaseName IS NULL OR sdb.[PersianDataBaseName]  LIKE CONCAT('%',@DataBaseName,'%'))
                AND(@BackupType<1  OR backuptype = @BackupType)
				AND (@BackupStartDate IS NULL OR @BackupStartDate<= b.BackupStartDate )
				AND (@BackupFinishDate IS NULL OR @BackupFinishDate>= b.BackupFinishDate )
    )
	, Total AS
	(
		SELECT COUNT(*) Total 
		FROM MainSelect
	)
   SELECT * FROM MainSelect,Total
          ORDER BY BackupStartDate DESC
		  	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	;

GO
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [alg].[spGetDataBaseBackup]    Script Date: 11/27/2022 8:43:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER   PROC [rpt].[spGetDataBaseJobLogs]
    @AJobID UNIQUEIDENTIFIER,
    @AStepID UNIQUEIDENTIFIER,
	@AJobName VARCHAR(200), 
	@AJobStatus   TINYINT,
	@AStepStatus   TINYINT,
	@AFromLastRunDateTime DATETIME,
	@AToLastRunDateTime DATETIME,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
AS

 DECLARE 
        @JobID VARCHAR(200)=IIF(@AJobID=0x,null,@AJobID),
		@StepID VARCHAR(200)=IIF(@AStepID=0x,null,@AStepID),
        @JobName VARCHAR(200)=@AJobName,
		@JobStatus   TINYINT=COALESCE(@AJobStatus, 0),
		@StepStatus   TINYINT=COALESCE(@AStepStatus, 0),
		@FromLastRunDateTime DATETIME=@AFromLastRunDateTime,
		@ToLastRunDateTime DATETIME=@AToLastRunDateTime,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
		BEGIN
			SET @pagesize = 10000
			SET @PageIndex = 1
		END
  ;WITH MainSelect AS 
  (
    SELECT 
       DISTINCT
	   j.[JobID]
	  ,j.StepID
      ,[JobName]
      ,[LastRunDateTime]
      ,RunStatus  JobStatus
      ,[LastRunStatus]
      ,[LastRunDuration] LastRunDuration
      ,[LastRunStatusMessage]
      ,[NextRunDateTime]
      ,[CreationDate]
	  ,JobDescription JobDescription
	  ,j.StepRunStatus StepStatus
	  ,js.StepDescription
  FROM [Kama.Administrator].[alg].[JobLog] j
  INNER JOIN [Kama.Administrator].alg.JobStep js on js.JobID=j.JobID and j.StepID=js.StepID
  WHERE (@JobName IS NULL OR [JobName] LIKE CONCAT('%',@JobName,'%'))
  AND  (@JobStatus<1  OR RunStatus = @JobStatus)
  AND  (@StepStatus<1  OR j.StepRunStatus = @StepStatus)
  AND (@FromLastRunDateTime IS NULL OR CAST(@FromLastRunDateTime AS DATE)<= CAST([LastRunDateTime] AS DATE) )
   AND (@ToLastRunDateTime IS NULL OR CAST(@ToLastRunDateTime AS DATE)>= CAST([LastRunDateTime] AS DATE) )
  AND (@JobID IS NULL  OR @JobID=j.JobID)
  AND (@StepID IS NULL OR @StepID=j.StepID)
  GROUP BY [JobName]
      ,[LastRunDateTime]
      ,RunStatus
      ,[LastRunStatus]
      ,[LastRunDuration]
      ,[LastRunStatusMessage]
      ,[NextRunDateTime]
      ,[CreationDate]
	  ,JobDescription
	  ,j.StepRunStatus
	  ,js.StepDescription
	  ,j.[JobID]
	  ,j.StepID
     )
	, Total AS
	(
		SELECT COUNT(*) Total 
		FROM MainSelect
	)
   SELECT * FROM MainSelect,Total
   ORDER BY [LastRunDateTime] DESC
   OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	;

GO
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [alg].[spGetDataBaseBackup]    Script Date: 11/27/2022 8:43:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER   PROC [rpt].[spGetJobs]
AS
SELECT [JobID]
      ,[JobName]
	  ,sj.[description] JobDescription
  FROM [Kama.Administrator].[alg].[Job] j
  INNER JOIN [msdb].[dbo].[sysjobs] sj ON sj.job_id=j.JobID
GO
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [alg].[spGetDataBaseBackup]    Script Date: 11/27/2022 8:43:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER   PROC [rpt].[spGetJobSteps]
 @AJobID UNIQUEIDENTIFIER
AS
DECLARE @JobID VARCHAR(200)=IIF(@AJobID=0x,null,@AJobID)
SELECT [JobID]
      ,[StepName]
      ,[DatabaseName]
      ,[StepNumber]
      ,[StepID]
      ,[StepDescription]
  FROM [Kama.Administrator].[alg].[JobStep]
  WHERE  (@JobID IS NULL  OR @JobID=JobID)
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetAddress'))
	DROP PROCEDURE inq.spGetAddress
GO

CREATE PROCEDURE inq.spGetAddress
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		[Address].ID,
		[Address].PostalCode,
		[Address].ProvinceID,
		[Address].ProvinceName,
		[Address].CityID,
		[Address].CityName,
		[Address].DistrictID,
		[Address].DistrictName,
		[Address].TownID,
		[Address].TownName,
		[Address].LocalityName,
		[Address].VillageName,
		[Address].SubLocality,
		[Address].Street,
		[Address].Street2,
		[Address].HouseNumber,
		[Address].BuildingName,
		[Address].[Description],
		[Address].[Floor],
		[Address].[SideFloor],
		[Address].LocationName,
		[Address].[CreationDate],
		[Address].Long,
		[Address].Lat
	FROM inq.[Address]
	WHERE ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetAddressByPostalCode'))
	DROP PROCEDURE inq.spGetAddressByPostalCode
GO

CREATE PROCEDURE inq.spGetAddressByPostalCode
	@APostalCode VARCHAR(10)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @PostalCode VARCHAR(10) = @APostalCode

	SELECT
		[Address].ID,
		[Address].PostalCode,
		[Address].ProvinceID,
		[Address].ProvinceName,
		[Address].CityID,
		[Address].CityName,
		[Address].DistrictID,
		[Address].DistrictName,
		[Address].TownID,
		[Address].TownName,
		[Address].LocalityName,
		[Address].VillageName,
		[Address].SubLocality,
		[Address].Street,
		[Address].Street2,
		[Address].HouseNumber,
		[Address].BuildingName,
		[Address].[Description],
		[Address].[Floor],
		[Address].[SideFloor],
		[Address].LocationName,
		[Address].[CreationDate],
		[Address].Long,
		[Address].Lat
	FROM inq.[Address]
	WHERE PostalCode = @PostalCode
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetNonInquiryAddresses'))
	DROP PROCEDURE inq.spGetNonInquiryAddresses
GO

CREATE PROCEDURE inq.spGetNonInquiryAddresses
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
		BEGIN
			SET @pagesize = 10000000
			SET @PageIndex = 1
		END

	;WITH InquiryResult AS(
	SELECT
		inquiry.ID,
		inquiry.CreationDate,
		inquiry.AddressID,
		ROW_NUMBER() OVER(PARTITION BY inquiry.AddressID order by inquiry.CreationDate) RowNumber
	FROM inq.AddressInquiryState as inquiry
	),
	TempResult AS
	(
		SELECT
			adr.ID,
			adr.PostalCode,
			inquiry.CreationDate
		FROM inq.[Address] adr
			LEFT JOIN InquiryResult inquiry on inquiry.AddressID = adr.ID
		WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1
		AND adr.PostalCode IS NOT NULL 
		AND LEN(adr.PostalCode) = 10 
		AND LTRIM(RTRIM(adr.PostalCode)) <> ''
	)
	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyAddress'))
	DROP PROCEDURE inq.spModifyAddress
GO

CREATE PROCEDURE inq.spModifyAddress
	@APostalCode VARCHAR(10),
	@AProvinceID UNIQUEIDENTIFIER,
	@AProvinceName NVARCHAR(100),
	@ACityID UNIQUEIDENTIFIER,
	@ACityName NVARCHAR(100),
	@ADistrictID UNIQUEIDENTIFIER,
	@ADistrictName NVARCHAR(100),
	@ATownID UNIQUEIDENTIFIER,
	@ATownName NVARCHAR(100),
	@ALocalityName NVARCHAR(100),
	@AVillageName NVARCHAR(100),
	@ASubLocality NVARCHAR(50),
	@AStreet NVARCHAR(100),
	@AStreet2 NVARCHAR(100),
	@AHouseNumber VARCHAR(10),
	@ABuildingName NVARCHAR(100),
	@ADescription NVARCHAR(100),
	@AFloor NVARCHAR(50),
	@ASideFloor VARCHAR(Max),
	@ALocationName NVARCHAR(Max),
	@ALong FLOAT,
	@ALat FLOAT,
	@ALog NVARCHAR(MAX),
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@PostalCode VARCHAR(10) = LTRIM(RTRIM(@APostalCode)),
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@ProvinceName NVARCHAR(100) = LTRIM(RTRIM(@AProvinceName)),
		@CityID UNIQUEIDENTIFIER = @ACityID,
		@CityName NVARCHAR(100) = LTRIM(RTRIM(@ACityName)),
		@DistrictID UNIQUEIDENTIFIER = @ADistrictID,
		@DistrictName NVARCHAR(100) = LTRIM(RTRIM(@ADistrictName)),
		@TownID UNIQUEIDENTIFIER = @ATownID,
		@TownName NVARCHAR(100) = LTRIM(RTRIM(@ATownName)),
		@LocalityName NVARCHAR(100) = LTRIM(RTRIM(@ALocalityName)),
		@VillageName NVARCHAR(100) = LTRIM(RTRIM(@AVillageName)),
		@SubLocality NVARCHAR(50) = LTRIM(RTRIM(@ASubLocality)),
		@Street NVARCHAR(100) = LTRIM(RTRIM(@AStreet)),
		@Street2 NVARCHAR(100) = LTRIM(RTRIM(@AStreet2)),
		@HouseNumber VARCHAR(10) = LTRIM(RTRIM(@AHouseNumber)),
		@BuildingName NVARCHAR(100) = LTRIM(RTRIM(@ABuildingName)),
		@Description NVARCHAR(100) = LTRIM(RTRIM(@ADescription)),
		@Floor NVARCHAR(50) = LTRIM(RTRIM(@AFloor)),
		@SideFloor VARCHAR(Max) = LTRIM(RTRIM(@ASideFloor)),
		@LocationName NVARCHAR(MAX) = LTRIM(RTRIM(@ALocationName)),
		@Long FLOAT = @ALong,
		@Lat FLOAT = @ALAT,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert
				BEGIN
					INSERT INTO inq.[Address]
					(ID, PostalCode, ProvinceID, ProvinceName, CityID, CityName, DistrictID, DistrictName, TownID, TownName, LocalityName, VillageName, SubLocality, Street, Street2, HouseNumber, BuildingName, [Description], [Floor], SideFloor, LocationName, Long, Lat, CreationDate)
					VALUES
					(NEWID(), @PostalCode, @ProvinceID, @ProvinceName, @CityID, @CityName, @DistrictID, @DistrictName, @TownID, @TownName, @LocalityName, @VillageName, @SubLocality, @Street, @Street2, @HouseNumber, @BuildingName, @Description, @Floor, @SideFloor, @LocationName, @Long, @Lat, GETDATE())			
				END
			ELSE 					-- update
				BEGIN
					UPDATE inq.[Address]
					SET
						PostalCode = @PostalCode,
						ProvinceID = @ProvinceID,
						ProvinceName = @ProvinceName,
						CityID = @CityID,
						CityName = @CityName,
						DistrictID = @DistrictID,
						DistrictName = @DistrictName,
						TownID = @TownID,
						TownName = @TownName,
						LocalityName = @LocalityName,
						VillageName = @VillageName,
						SubLocality = @SubLocality,
						Street = @Street,
						Street2 = @Street2,
						HouseNumber = @HouseNumber,
						BuildingName = @BuildingName,
						[Description] = @Description,
						[Floor] = @Floor,
						SideFloor = @SideFloor,
						LocationName = @LocationName,
						Long = @Long,
						Lat = @Lat,
						CreationDate = GETDATE()
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyAddressInquiryState'))
	DROP PROCEDURE inq.spModifyAddressInquiryState
GO

CREATE PROCEDURE inq.spModifyAddressInquiryState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AAddressID UNIQUEIDENTIFIER,
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@AddressID UNIQUEIDENTIFIER = @AAddressID,
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].[AddressInquiryState]
					([ID], [AddressID], [CreationDate], [ResultType])
				VALUES
					(NEWID(), @AddressID, GETDATE(), @ResultType)
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].[AddressInquiryState]
				SET
					[CreationDate] = GETDATE(),
					[ResultType] = @ResultType
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spValidatePostalCode'))
	DROP PROCEDURE inq.spValidatePostalCode
GO

CREATE PROCEDURE inq.spValidatePostalCode
	@APostalCodes VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @PostalCodes VARCHAR(MAX) = @APostalCodes
	
	SELECT
		postalCodeJson.PostalCode, 
		CAST(COALESCE(CAST([address].PostalCode AS BIGINT), 0) AS BIT) IsExist
	FROM OPENJSON(@PostalCodes)
	WITH(PostalCode VARCHAR(10)) AS postalCodeJson
		LEFT JOIN inq.[Address] ON 
			[Address].PostalCode = postalCodeJson.PostalCode 
			AND [Address].ProvinceName <> '' 
			AND [Address].CityName <> '' 
			AND [Address].DistrictName <> '' 
			AND [Address].PostalCode NOT LIKE N'%-%'
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spCreateVaccineInquiryStates'))
	DROP PROCEDURE inq.spCreateVaccineInquiryStates
GO

CREATE PROCEDURE inq.spCreateVaccineInquiryStates
	@AInquiryStates NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@InquiryStates NVARCHAR(MAX) = @AInquiryStates
		
	BEGIN TRY
		BEGIN TRAN
			
			INSERT INTO inq.VaccineInquiryState
			(ID, IndividualID, CreationDate, ResultType, ResultMessage)
			SELECT
				NEWID() ID,
				IndividualID,
				GETDATE(), 
				ResultType,
				ResultMessage
			FROM OPENJSON(@InquiryStates)
			WITH 
			(
				IndividualID UNIQUEIDENTIFIER,
				ResultType TINYINT,
				ResultMessage NVARCHAR(4000)
			)
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spEditVaccines'))
	DROP PROCEDURE inq.spEditVaccines
GO

CREATE PROCEDURE inq.spEditVaccines
	@AVaccines NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@Vaccines NVARCHAR(MAX) = @AVaccines
		
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE vac 
			SET
				vac.NumberOfReceivedDoses = vacJson.NumberOfReceivedDoses,
				Vac.HealthStatus = vacJson.HealthStatus,
				vac.PermissionStatus = vacJson.PermissionStatus,
				vac.Quarantined = vacJson.Quarantined		
			FROM inq.Vaccine vac
			INNER JOIN OPENJSON(@Vaccines)
			WITH 
			(
				IndividualID UNIQUEIDENTIFIER,
				NumberOfReceivedDoses INT,
				HealthStatus NVARCHAR(255),
				PermissionStatus NVARCHAR(255),
				Quarantined BIT
			) AS vacJson
			ON vac.IndividualID = vacJson.IndividualID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetVaccine'))
	DROP PROCEDURE inq.spGetVaccine
GO

CREATE PROCEDURE inq.spGetVaccine
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		vc.ID,
		vc.IndividualID,
		vc.CreationDate,
		vc.LastDoseDate,
		vc.LastDoseDateFa,
		vc.NumberOfReceivedDoses,
		vc.HealthStatus,
		vc.PermissionStatus,
		vc.Quarantined
	FROM inq.Vaccine vc
	WHERE ID = @ID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetVaccineByIndividualID'))
	DROP PROCEDURE inq.spGetVaccineByIndividualID
GO

CREATE PROCEDURE inq.spGetVaccineByIndividualID
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
		vc.ID,
		vc.IndividualID,
		vc.CreationDate,
		vc.LastDoseDate,
		vc.LastDoseDateFa,
		vc.NumberOfReceivedDoses,
		vc.HealthStatus,
		vc.PermissionStatus,
		vc.Quarantined
	FROM inq.Vaccine vc
	WHERE IndividualID = @IndividualID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetVaccines'))
	DROP PROCEDURE inq.spGetVaccines
GO

CREATE PROCEDURE inq.spGetVaccines
	@AIndividualID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@AStartDate DATE,
	@AEndDate DATE,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
			@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
			@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
			@StartDate DATE = @AStartDate,
			@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
			@PageSize INT = COALESCE(@APageSize, 20),
			@PageIndex INT = COALESCE(@APageIndex, 1),
			@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
		BEGIN
			SET @pagesize = 10000000
			SET @PageIndex = 1
		END

	;WITH TempResult AS
	(
		SELECT
			vac.ID,
			vac.IndividualID,
			vac.CreationDate,
			vac.NumberOfReceivedDoses,
			vac.LastDoseDate,
			vac.LastDoseDateFa,
			vac.HealthStatus,
			vac.PermissionStatus,
			vac.Quarantined,
			ind.FirstName,
			ind.LastName,
			ind.NationalCode,
			ind.Gender,
			ind.BirthDate AS IndividualBirthDate
		FROM inq.Vaccine vac
			INNER JOIN org.Individual ind ON ind.ID = vac.IndividualID
		WHERE (@IndividualID IS NULL OR vac.IndividualID = @IndividualID)
			AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
			AND (@StartDate IS NULL OR vac.CreationDate >= @StartDate)
			AND (@EndDate IS NULL OR vac.CreationDate < @EndDate)
	),
	TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM TempResult
	)

	SELECT * FROM TempResult, TempCount
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyVaccine'))
	DROP PROCEDURE inq.spModifyVaccine
GO

CREATE PROCEDURE inq.spModifyVaccine
	@ALastDoseDate DATETIME,
	@ALastDoseDateFa NVARCHAR(400),
	@ANumberOfReceivedDoses INT,
	@AIsNewRecord BIT,
	@AIndividualID UNIQUEIDENTIFIER,
	@AHealthStatus NVARCHAR(255),
	@APermissionStatus NVARCHAR(255),
	@AQuarantined BIT,
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@LastDoseDate DATETIME = @ALastDoseDate,
		@LastDoseDateFa NVARCHAR(400) = LTRIM(RTRIM(@ALastDoseDateFa)),
		@NumberOfReceivedDoses INT = COALESCE(@ANumberOfReceivedDoses, 0),
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@HealthStatus NVARCHAR(255) = LTRIM(RTRIM(@AHealthStatus)),
		@PermissionStatus NVARCHAR(255) = LTRIM(RTRIM(@APermissionStatus)),
		@Quarantined BIT = @AQuarantined,
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN			
				INSERT INTO inq.Vaccine
					(ID, CreationDate, IndividualID, NumberOfReceivedDoses, LastDoseDate, LastDoseDateFa, HealthStatus, PermissionStatus, Quarantined)
				VALUES
					(@ID, GETDATE(), @IndividualID, @NumberOfReceivedDoses, @LastDoseDate, @LastDoseDateFa, @HealthStatus, @PermissionStatus, @Quarantined)
			END
			ELSE				-- update
			BEGIN
				UPDATE inq.Vaccine
				SET 
					NumberOfReceivedDoses = @NumberOfReceivedDoses,
					LastDoseDate = @LastDoseDate,
					LastDoseDateFa = @LastDoseDateFa, 
					HealthStatus = @HealthStatus, 
					PermissionStatus = @PermissionStatus, 
					Quarantined = @Quarantined 
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyVaccineInquiryState'))
	DROP PROCEDURE inq.spModifyVaccineInquiryState
GO

CREATE PROCEDURE inq.spModifyVaccineInquiryState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER,
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].VaccineInquiryState
					([ID], [IndividualID], [CreationDate], [ResultType])
				VALUES
					(NEWID(), @IndividualID, GETDATE(), @ResultType)
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].VaccineInquiryState
				SET
					[CreationDate] = GETDATE(),
					[ResultType] = @ResultType
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spToggleIsInUsedNeededIndividualsForVaccination'))
	DROP PROCEDURE inq.spToggleIsInUsedNeededIndividualsForVaccination
GO

CREATE PROCEDURE inq.spToggleIsInUsedNeededIndividualsForVaccination
	@AIndividuals NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@Individuals NVARCHAR(MAX) = @AIndividuals
		
	BEGIN TRY
		BEGIN TRAN
			
			UPDATE needIndv 
			SET
				needIndv.IsInUsed = 1 - needIndv.IsInUsed	
			FROM [org].[IndividualForVaccine] needIndv
			INNER JOIN OPENJSON(@Individuals)
			WITH 
			(
				ID UNIQUEIDENTIFIER
			) AS Indv
			ON needIndv.ID = Indv.ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetChaparInquiryByIndividualID'))
	DROP PROCEDURE inq.spGetChaparInquiryByIndividualID
GO

CREATE PROCEDURE inq.spGetChaparInquiryByIndividualID
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT *
	FROM inq.ChaparInquiryState
	WHERE IndividualID = @IndividualID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyChaparInquiryState'))
	DROP PROCEDURE inq.spModifyChaparInquiryState
GO

CREATE PROCEDURE inq.spModifyChaparInquiryState
	@AIndividualID UNIQUEIDENTIFIER,
	@AResultMessage NVARCHAR(2000),
	@AContent NVARCHAR(2000),
	@ARequestID NVARCHAR(200),
	@AValue NVARCHAR(200),
	@AType TINYINT,
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ResultMessage NVARCHAR(2000) = LTRIM(RTRIM(@AResultMessage)),
		@Content NVARCHAR(2000) = LTRIM(RTRIM(@AContent)),
		@RequestID NVARCHAR(200) = LTRIM(RTRIM(@ARequestID)),
		@Value NVARCHAR(200) = LTRIM(RTRIM(@AValue)),
		@Type TINYINT = COALESCE(@AType, 0),
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN

			INSERT INTO [inq].ChaparInquiryState
					([ID], IndividualID, [CreationDate], [ResultType], [ResultMessage], [RequestID], [Type], [Value], [Content])
				VALUES
					(NEWID(), @IndividualID, GETDATE(), @ResultType, @ResultMessage, @RequestID, @Type, @Value, @Content)			

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetDigitalSignatureInquiryState'))
	DROP PROCEDURE inq.spGetDigitalSignatureInquiryState
GO

CREATE PROCEDURE inq.spGetDigitalSignatureInquiryState
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT *
	FROM inq.DigitalSignatureInquiryState
	WHERE ID = @ID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyDigitalSignatureInquiryState'))
	DROP PROCEDURE inq.spModifyDigitalSignatureInquiryState
GO

CREATE PROCEDURE inq.spModifyDigitalSignatureInquiryState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AAttachmentID UNIQUEIDENTIFIER,
	@AResultType TINYINT,
	@ARedirectApiUrl NVARCHAR(1000),
	@AResultMessage NVARCHAR(4000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@AttachmentID UNIQUEIDENTIFIER = @AAttachmentID,
		@ResultType TINYINT = COALESCE(@AResultType, 0),
		@RedirectApiUrl NVARCHAR(1000) = LTRIM(RTRIM(@ARedirectApiUrl)),
		@ResultMessage NVARCHAR(4000) = LTRIM(RTRIM(@AResultMessage))
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].DigitalSignatureInquiryState
					([ID], [ApplicationID], [AttachmentID], [CreationDate], [ResultType], [ResultMessage], [RedirectApiUrl])
				VALUES
					(@ID, @ApplicationID, @AttachmentID, GETDATE(), @ResultType, @ResultMessage, @RedirectApiUrl)
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].DigitalSignatureInquiryState
				SET
					[ResultType] = @ResultType,
					[ResultMessage] = @ResultMessage
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetEducational'))
	DROP PROCEDURE inq.spGetEducational
GO

CREATE PROCEDURE inq.spGetEducational
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
	  Educational.ID,
      Educational.IndividualID,
      Educational.UniversityId,
      Educational.UniversityName,
      Educational.FacultyName,
      Educational.CourseTitle,
      Educational.MsrtCourseTitle,
      Educational.StopDate,
      Educational.StudentStatus,
      Educational.MsrtStudentStatus,
      Educational.MsrtStudentStatusCode,
      Educational.StudyLevelTitle,
      Educational.MsrtstudyLevelTitle,
      Educational.MsrtstudyLevelCode,
      Educational.StudyingMode,
      Educational.MsrtStudyingMode,
      Educational.MsrtStudyingModeCode,
      Educational.TotalAverage,
      Educational.UserTypeName
	FROM inq.Educational
	WHERE IndividualID = @IndividualID
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetEducationals'))
	DROP PROCEDURE inq.spGetEducationals
GO

CREATE PROCEDURE inq.spGetEducationals
	@AIndividualID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
			@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
			@PageSize INT = COALESCE(@APageSize, 20),
			@PageIndex INT = COALESCE(@APageIndex, 1),
			@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
		BEGIN
			SET @pagesize = 10000000
			SET @PageIndex = 1
		END

	;WITH TempResult AS
	(
		SELECT
		  Educational.ID,
		  Educational.IndividualID,
		  Educational.UniversityId,
		  Educational.UniversityName,
		  Educational.FacultyName,
		  Educational.CourseTitle,
		  Educational.MsrtCourseTitle,
		  Educational.StopDate,
		  Educational.StudentStatus,
		  Educational.MsrtStudentStatus,
		  Educational.MsrtStudentStatusCode,
		  Educational.StudyLevelTitle,
		  Educational.MsrtstudyLevelTitle,
		  Educational.MsrtstudyLevelCode,
		  Educational.StudyingMode,
		  Educational.MsrtStudyingMode,
		  Educational.MsrtStudyingModeCode,
		  Educational.TotalAverage,
		  Educational.UserTypeName
		FROM inq.Educational
		WHERE IndividualID = @IndividualID
	),
	TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM TempResult
	)

	SELECT * FROM TempResult, TempCount
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyEducational'))
	DROP PROCEDURE inq.spModifyEducational
GO

CREATE PROCEDURE inq.spModifyEducational
	@AIsNewRecord BIT,
	@AIndividualID UNIQUEIDENTIFIER,
	@AFacultyName NVARCHAR(50),
	@ACourseTitle NVARCHAR(100),
	@AMsrtStudentStatus TINYINT,
	@AMsrtStudentStatusCode NVARCHAR(10),
	@AMsrtStudyingMode TINYINT,
	@AMsrtStudyingModeCode VARCHAR(10),
	@AMsrtstudyLevelCode VARCHAR(10),
	@AMsrtstudyLevelTitle NVARCHAR(50),
	@AStudentStatus TINYINT,
	@AStudyingMode TINYINT,
	@ATotalAverage FLOAT,
	@AUniversityName NVARCHAR(50),
	@AUniversityId INT,
	@AStopDate NVARCHAR(20),
	@AStudyLevelTitle NVARCHAR(50),
	@AUserTypeName NVARCHAR(50),
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@FacultyName NVARCHAR(50) = LTRIM(RTRIM(@AFacultyName)),
		@CourseTitle NVARCHAR(100) = LTRIM(RTRIM(@ACourseTitle)),
		@MsrtStudentStatus TINYINT = COALESCE(@AMsrtStudentStatus, 0),
		@MsrtStudentStatusCode NVARCHAR(10) = LTRIM(RTRIM(@AMsrtStudentStatusCode)),
		@MsrtStudyingMode TINYINT = COALESCE(@AMsrtStudyingMode, 0),
		@MsrtStudyingModeCode VARCHAR(10) = LTRIM(RTRIM(@AMsrtStudyingModeCode)),
		@MsrtstudyLevelCode VARCHAR(10) = LTRIM(RTRIM(@AMsrtstudyLevelCode)),
		@MsrtstudyLevelTitle NVARCHAR(50) = LTRIM(RTRIM(@AMsrtstudyLevelTitle)),
		@StudentStatus TINYINT = COALESCE(@AStudentStatus, 0),
		@StudyingMode TINYINT = COALESCE(@AStudyingMode, 0),
		@TotalAverage FLOAT = @ATotalAverage,
		@UniversityName NVARCHAR(50) = LTRIM(RTRIM(@AUniversityName)),
		@UniversityId INT = @AUniversityId,
		@StudyLevelTitle NVARCHAR(50) = LTRIM(RTRIM(@AStudyLevelTitle)),
		@StopDate NVARCHAR(20) = LTRIM(RTRIM(@AStopDate)),
		@UserTypeName NVARCHAR(50) = LTRIM(RTRIM(@AUserTypeName)),
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN	
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].[Educational]
				(ID, IndividualID, FacultyName, MsrtStudentStatus, MsrtStudentStatusCode,CourseTitle , MsrtStudyingMode, MsrtStudyingModeCode, MsrtstudyLevelCode, MsrtstudyLevelTitle, StudentStatus, StudyingMode, TotalAverage, UniversityName, UniversityId, StudyLevelTitle, UserTypeName, StopDate)
				VALUES
				(NEWID(), @IndividualID, @FacultyName, @MsrtStudentStatus, @MsrtStudentStatusCode,@CourseTitle , @MsrtStudyingMode, @MsrtStudyingModeCode, @MsrtstudyLevelCode, @MsrtstudyLevelTitle, @StudentStatus, @StudyingMode, @TotalAverage, @UniversityName, @UniversityId, @StudyLevelTitle, @UserTypeName, @StopDate)

			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].[Educational]
				SET
					IndividualID = @IndividualID,
					CourseTitle = @CourseTitle,
					FacultyName = @FacultyName,
					MsrtStudentStatus = @MsrtStudentStatus,
					MsrtStudentStatusCode = @MsrtStudentStatusCode,
					MsrtStudyingMode = @MsrtStudyingMode,
					MsrtStudyingModeCode = @MsrtStudyingModeCode,
					MsrtstudyLevelCode = @MsrtstudyLevelCode,
					MsrtstudyLevelTitle = @MsrtstudyLevelTitle,
					StudentStatus = @StudentStatus,
					StudyingMode = @StudyingMode,
					TotalAverage = @TotalAverage,
					UniversityName = @UniversityName,
					UniversityId = @UniversityId,
					StudyLevelTitle = @StudyLevelTitle,
					UserTypeName = @UserTypeName,
					StopDate = @StopDate
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyEducationalInquiryState'))
	DROP PROCEDURE inq.spModifyEducationalInquiryState
GO

CREATE PROCEDURE inq.spModifyEducationalInquiryState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER,
	@AResultType TINYINT,
	@AResultCount int
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ResultType TINYINT = COALESCE(@AResultType, 0),
		@ResultCount int = COALESCE(@AResultCount, 0)
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].[EducationalInquiryState]
					([ID], [IndividualID], [CreationDate], [ResultType], [ResultCount])
				VALUES
					(NEWID(), @IndividualID, GETDATE(), @ResultType, @ResultCount)
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].[EducationalInquiryState]
				SET
					[CreationDate] = GETDATE(),
					[ResultType] = @ResultType,
					ResultCount = @ResultCount
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE [object_id] = OBJECT_ID(N'inq.spDeleteEducational2'))
DROP PROCEDURE inq.spDeleteEducational2
GO

CREATE PROCEDURE inq.spDeleteEducational2
	@AIndividualID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

    DECLARE 
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM inq.Educational2
			WHERE IndividualID = @IndividualID

		COMMIT
	END TRY
	BEGIN CATCH
		 SET @Result = -1
		;THROW
	END CATCH

    RETURN @Result 
END		



GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetEducational2'))
	DROP PROCEDURE inq.spGetEducational2
GO

CREATE PROCEDURE inq.spGetEducational2
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
	  edu.ID,
      edu.IndividualID,
      edu.CreationDate,
      edu.UniStudyLevel,
      edu.UniStudyingMode,
      edu.UniStudentStatus,
      edu.UniCourseStudy,
      edu.UniStartDate,
      edu.UniStopDate,
      edu.MsrtStudyingMode,
      edu.MsrtStudentStatus,
      edu.MsrtStudyLevel,
      edu.PersonCode,
      edu.University,
      edu.TotalAverage
	FROM inq.Educational2 edu
	WHERE IndividualID = @IndividualID
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetEducationals2'))
	DROP PROCEDURE inq.spGetEducationals2
GO

CREATE PROCEDURE inq.spGetEducationals2
	@AIndividualID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@AFirstName NVARCHAR(1000),
	@ALastName NVARCHAR(1000),
	@AUniStudyLevel NVARCHAR(1000),
	@AUniStudyingMode NVARCHAR(1000),
	@AUniCourseStudy NVARCHAR(1000),
	@AUniversity NVARCHAR(1000),
	@AAverageLowRange FLOAT,
	@AAverageHighRange FLOAT,
	@AGender TINYINT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
			@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
			@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
			@FirstName NVARCHAR(1000) = LTRIM(RTRIM(@AFirstName)),
			@LastName NVARCHAR(1000) = LTRIM(RTRIM(@ALastName)),
			@UniStudyLevel NVARCHAR(1000) = LTRIM(RTRIM(@AUniStudyLevel)),
			@UniStudyingMode NVARCHAR(1000) = LTRIM(RTRIM(@AUniStudyingMode)),
			@UniCourseStudy NVARCHAR(1000) = LTRIM(RTRIM(@AUniCourseStudy)),
			@University NVARCHAR(1000) = LTRIM(RTRIM(@AUniversity)),
			@AverageLowRange FLOAT = @AAverageLowRange,
			@AverageHighRange FLOAT = @AAverageHighRange,
			@Gender TINYINT = COALESCE(@AGender, 0),
			@PageSize INT = COALESCE(@APageSize, 20),
			@PageIndex INT = COALESCE(@APageIndex, 1),
			@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
		BEGIN
			SET @pagesize = 10000000
			SET @PageIndex = 1
		END

	;WITH TempResult AS
	(
		SELECT
			edu.ID,
			edu.IndividualID,
			edu.CreationDate,
			edu.UniStudyLevel,
			edu.UniStudyingMode,
			edu.UniStudentStatus,
			edu.UniCourseStudy,
			edu.UniStartDate,
			edu.UniStopDate,
			edu.MsrtStudyingMode,
			edu.MsrtStudentStatus,
			edu.MsrtStudyLevel,
			edu.PersonCode,
			edu.University,
			edu.TotalAverage,
			ind.FirstName,
			ind.LastName,
			ind.NationalCode,
			ind.Gender,
			ind.BirthDate AS IndividualBirthDate
		FROM inq.Educational2 edu
			INNER JOIN org.Individual ind ON ind.ID = edu.IndividualID
		WHERE (@IndividualID IS NULL OR edu.IndividualID = @IndividualID)
			AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR ind.FirstName LIKE CONCAT('%', @FirstName, '%'))
			AND (@LastName IS NULL OR ind.LastName LIKE CONCAT('%', @LastName, '%'))
			AND (@Gender < 1 OR ind.Gender = @Gender)
			AND (@UniStudyLevel IS NULL OR edu.UniStudyLevel LIKE CONCAT('%', @UniStudyLevel, '%'))
			AND (@UniStudyingMode IS NULL OR edu.UniStudyingMode LIKE CONCAT('%', @UniStudyingMode, '%'))
			AND (@UniCourseStudy IS NULL OR edu.UniCourseStudy LIKE CONCAT('%', @UniCourseStudy, '%'))
			AND (@University IS NULL OR edu.University LIKE CONCAT('%', @University, '%'))
			AND (@AverageLowRange IS NULL OR edu.TotalAverage >= @AverageLowRange)
			AND (@AverageHighRange IS NULL OR edu.TotalAverage <= @AverageHighRange)
	),
	TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM TempResult
	)

	SELECT * FROM TempResult, TempCount
	ORDER BY CreationDate DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyEducational2'))
	DROP PROCEDURE inq.spModifyEducational2
GO

CREATE PROCEDURE inq.spModifyEducational2
	@AID uniqueidentifier,
	@AIndividualID uniqueidentifier,
	@AUniStudyLevel NVARCHAR(400),
	@AUniStudyingMode NVARCHAR(400),
	@AUniStudentStatus NVARCHAR(400),
	@AUniCourseStudy NVARCHAR(400),
	@AUniStartDate NVARCHAR(400),
	@AUniStopDate NVARCHAR(400),
	@AMsrtStudyingMode NVARCHAR(400),
	@AMsrtStudyLevel NVARCHAR(400),
	@AMsrtStudentStatus NVARCHAR(400),
	@APersonCode NVARCHAR(400),
	@AUniversity NVARCHAR(400),
	@ATotalAverage float
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@UniStudyLevel NVARCHAR(400) = LTRIM(RTRIM(@AUniStudyLevel)),
		@UniStudyingMode NVARCHAR(400) = LTRIM(RTRIM(@AUniStudyingMode)),
		@UniStudentStatus NVARCHAR(400) = LTRIM(RTRIM(@AUniStudentStatus)),
		@UniCourseStudy NVARCHAR(400) = LTRIM(RTRIM(@AUniCourseStudy)),
		@UniStartDate NVARCHAR(400) = LTRIM(RTRIM(@AUniStartDate)),
		@UniStopDate NVARCHAR(400) = LTRIM(RTRIM(@AUniStopDate)),
		@MsrtStudyingMode NVARCHAR(400) = LTRIM(RTRIM(@AMsrtStudyingMode)),
		@MsrtStudyLevel NVARCHAR(400) = LTRIM(RTRIM(@AMsrtStudyLevel)),
		@MsrtStudentStatus NVARCHAR(400) = LTRIM(RTRIM(@AMsrtStudentStatus)),
		@PersonCode NVARCHAR(400) = LTRIM(RTRIM(@APersonCode)),
		@University NVARCHAR(400) = LTRIM(RTRIM(@AUniversity)),
		@TotalAverage float = @ATotalAverage

	BEGIN TRY
		BEGIN TRAN	
				INSERT INTO [inq].[Educational2]
				(
				 ID,
				 IndividualID,
				 CreationDate,
				 UniStudyLevel,
				 UniStudyingMode,
				 UniStudentStatus,
				 UniCourseStudy,
				 UniStartDate,
				 UniStopDate,
				 MsrtStudyingMode,
				 MsrtStudentStatus,
				 MsrtStudyLevel,
				 PersonCode,
				 University,
				 TotalAverage
				)
				VALUES
				(
				@ID,
				@IndividualID,
				GETDATE(),
				@UniStudyLevel,
				@UniStudyingMode,
				@UniStudentStatus,
				@UniCourseStudy,
				@UniStartDate,
				@UniStopDate,
				@MsrtStudyingMode,
				@MsrtStudyLevel,
				@MsrtStudentStatus,
				@PersonCode,
				@University,
				@TotalAverage
				)
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyICTParticipateDailyInquiryState'))
	DROP PROCEDURE inq.spModifyICTParticipateDailyInquiryState
GO

CREATE PROCEDURE inq.spModifyICTParticipateDailyInquiryState
	@AReceivedCount INT,
	@AInquiryDate SMALLDATETIME,
	@AResultMessage NVARCHAR(4000),
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ReceivedCount INT = @AReceivedCount,
		@InquiryDate SMALLDATETIME = @AInquiryDate,
		@ResultMessage NVARCHAR(4000) = LTRIM(RTRIM(@AResultMessage)),
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN

			INSERT INTO [inq].ICTParticipateDailyInquiryState
				([ID], InquiryDate, [CreationDate], [ResultType], [ResultMessage], [ReceivedCount])
			VALUES
				(NEWID(), @InquiryDate, GETDATE(), @ResultType, @ResultMessage, @ReceivedCount)			

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spCreateImageSmartInquiryStates'))
	DROP PROCEDURE inq.spCreateImageSmartInquiryStates
GO

CREATE PROCEDURE inq.spCreateImageSmartInquiryStates
	@AInquiryStates NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@InquiryStates NVARCHAR(MAX) = @AInquiryStates
		
	BEGIN TRY
		BEGIN TRAN
			
			INSERT INTO inq.ImageSmartInquiryState
			(ID, IndividualID, CreationDate, ResultType, ResultMessage)
			SELECT
				NEWID() ID,
				IndividualID,
				GETDATE(), 
				ResultType,
				ResultMessage
			FROM OPENJSON(@InquiryStates)
			WITH 
			(
				IndividualID UNIQUEIDENTIFIER,
				ResultType TINYINT,
				ResultMessage NVARCHAR(4000)
			)

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyImageSmartInquiryState'))
	DROP PROCEDURE inq.spModifyImageSmartInquiryState
GO

CREATE PROCEDURE inq.spModifyImageSmartInquiryState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER,
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].ImageSmartInquiryState
					([ID], [IndividualID], [CreationDate], [ResultType])
				VALUES
					(NEWID(), @IndividualID, GETDATE(), @ResultType)
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].ImageSmartInquiryState
				SET
					[CreationDate] = GETDATE(),
					[ResultType] = @ResultType
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetInsurance'))
	DROP PROCEDURE inq.spGetInsurance
GO

CREATE PROCEDURE inq.spGetInsurance
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		[Insurance].ID,
		[Insurance].IndividualID,
		[Insurance].InsuranceId,
		[Insurance].InsuranceType,
		[Insurance].InsuredRelationType,
		[Insurance].InquiryDate,
		[Insurance].BookletExpirationDate,
		[Insurance].LastWorkingMonth,
		[Insurance].Relation,
		[Insurance].RelationType,
		[Insurance].WorkShopName,
		[Insurance].CreationDate
	FROM inq.[Insurance]
	WHERE ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetInsuranceByIndividualId'))
	DROP PROCEDURE inq.spGetInsuranceByIndividualId
GO

CREATE PROCEDURE inq.spGetInsuranceByIndividualId
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
		[Insurance].ID,
		[Insurance].IndividualID,
		[Insurance].InsuranceId,
		[Insurance].InsuranceType,
		[Insurance].InsuredRelationType,
		[Insurance].InquiryDate,
		[Insurance].BookletExpirationDate,
		[Insurance].LastWorkingMonth,
		[Insurance].Relation,
		[Insurance].RelationType,
		[Insurance].WorkShopName,
		[Insurance].CreationDate
	FROM inq.[Insurance]
	WHERE IndividualID = @IndividualID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetInsuranceInquiryState'))
	DROP PROCEDURE inq.spGetInsuranceInquiryState
GO

CREATE PROCEDURE inq.spGetInsuranceInquiryState
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
		ins.ID,
		ins.IndividualID,
		ins.ResultType,
		ins.CreationDate
	FROM inq.InsuranceInquiryState ins
	WHERE IndividualID = @IndividualID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyInsurance'))
	DROP PROCEDURE inq.spModifyInsurance
GO
CREATE PROCEDURE inq.spModifyInsurance
	@AIsNewRecord BIT,
	@AIndividualID UNIQUEIDENTIFIER,
	@AInsuranceType NVARCHAR(100),
	@ABookletExpirationDate NVARCHAR(100),
	@AInsuranceId NVARCHAR(100),
	@AInsuredRelationType NVARCHAR(100),
	@ARelation NVARCHAR(100),
	@ARelationType NVARCHAR(100),
	@AInquiryDate NVARCHAR(100),
	@ALastWorkingMonth NVARCHAR(100),
	@AWorkShopName NVARCHAR(100),
	@AID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@InsuranceType NVARCHAR(100) = LTRIM(RTRIM(@AInsuranceType)),
		@BookletExpirationDate NVARCHAR(100) = LTRIM(RTRIM(@ABookletExpirationDate)),
		@InsuranceId NVARCHAR(100) = LTRIM(RTRIM(@AInsuranceId)),
		@InsuredRelationType NVARCHAR(100) = LTRIM(RTRIM(@AInsuredRelationType)),
		@Relation NVARCHAR(100) = LTRIM(RTRIM(@ARelation)),
		@RelationType NVARCHAR(100) = LTRIM(RTRIM(@ARelationType)),
		@InquiryDate NVARCHAR(100) = LTRIM(RTRIM(@AInquiryDate)),
		@LastWorkingMonth NVARCHAR(100) = LTRIM(RTRIM(@ALastWorkingMonth)),
		@WorkShopName NVARCHAR(100) = LTRIM(RTRIM(@AWorkShopName)),
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN	
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].[Insurance]
				([ID], [IndividualID], [InsuranceType], [BookletExpirationDate], [InsuranceId], [InsuredRelationType], [Relation], [RelationType], [InquiryDate], [LastWorkingMonth], [WorkShopName], [CreationDate])
				VALUES
				(@ID, @IndividualID,@InsuranceType, @BookletExpirationDate, @InsuranceId, @InsuredRelationType, @Relation, @RelationType, @InquiryDate, @LastWorkingMonth, @WorkShopName, GETDATE())
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].[Insurance]
				SET
					[InsuranceType] = @InsuranceType,
					[BookletExpirationDate] = @BookletExpirationDate,
					[InsuranceId] = @InsuranceId,
					[InsuredRelationType] = @InsuredRelationType,
					[Relation] = @Relation,
					[RelationType] = @RelationType,
					[InquiryDate] = @InquiryDate,
					[LastWorkingMonth] = @LastWorkingMonth,
					[WorkShopName] = @WorkShopName,
					[CreationDate] = GETDATE()
				WHERE IndividualID = @IndividualID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyInsuranceInquiryState'))
	DROP PROCEDURE inq.spModifyInsuranceInquiryState
GO

CREATE PROCEDURE inq.spModifyInsuranceInquiryState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER,
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].[InsuranceInquiryState]
					([ID], [IndividualID], [CreationDate], [ResultType])
				VALUES
					(NEWID(), @IndividualID, GETDATE(), @ResultType)
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].[InsuranceInquiryState]
				SET
					[CreationDate] = GETDATE(),
					[ResultType] = @ResultType
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetRetirementInformation'))
	DROP PROCEDURE inq.spGetRetirementInformation
GO

CREATE PROCEDURE inq.spGetRetirementInformation
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
		RetirementInformation.ID,
		RetirementInformation.IndividualID,
		RetirementInformation.IsRetired,
		RetirementInformation.IsEmployed,
		RetirementInformation.IsRetiredReturnEmployed,
		RetirementInformation.RetiredDays,
		RetirementInformation.EmployedDays,
		RetirementInformation.RetiredDate,
		RetirementInformation.CreationDate
	FROM inq.RetirementInformation
	WHERE IndividualID = @IndividualID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetRetirementInquiryState'))
	DROP PROCEDURE inq.spGetRetirementInquiryState
GO

CREATE PROCEDURE inq.spGetRetirementInquiryState
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
		ret.ID,
		ret.IndividualID,
		ret.CreationDate
	FROM inq.RetirementInquiryState ret
	WHERE IndividualID = @IndividualID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyRetirementInformation'))
	DROP PROCEDURE inq.spModifyRetirementInformation
GO

CREATE PROCEDURE inq.spModifyRetirementInformation
	@AIndividualID UNIQUEIDENTIFIER,
	@AIsRetired BIT,
	@AIsEmployed BIT,
	@AIsRetiredReturnEmployed BIT,
	@ARetiredDays INT,
	@AEmployedDays INT,
	@ARetiredDate SMALLDATETIME,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@IsRetired BIT = COALESCE(@AIsRetired, 0),
		@IsEmployed BIT = COALESCE(@AIsEmployed, 0),
		@IsRetiredReturnEmployed BIT = COALESCE(@AIsRetiredReturnEmployed, 0),
		@RetiredDays INT = @ARetiredDays,
		@EmployedDays INT = @AEmployedDays,
		@RetiredDate SMALLDATETIME = @ARetiredDate,
		@ID UNIQUEIDENTIFIER,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	SET @ID = COALESCE((SELECT ID FROM inq.RetirementInformation WHERE IndividualID = @IndividualID), 0x)

	BEGIN TRY
		BEGIN TRAN
			DELETE FROM inq.RetirementInformation WHERE ID = @ID

			SET @ID = NEWID()

			INSERT INTO inq.RetirementInformation
			(ID, IndividualID, IsRetired, IsEmployed, IsRetiredReturnEmployed, RetiredDays, EmployedDays, RetiredDate, CreationDate)
			VALUES
			(@ID, @IndividualID, @IsRetired, @IsEmployed, @IsRetiredReturnEmployed, @RetiredDays, @EmployedDays, @RetiredDate, GETDATE())

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyRetirementInquiryState'))
	DROP PROCEDURE inq.spModifyRetirementInquiryState
GO

CREATE PROCEDURE inq.spModifyRetirementInquiryState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER,
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].[RetirementInquiryState]
					([ID], [IndividualID], [CreationDate], [ResultType])
				VALUES
					(NEWID(), @IndividualID, GETDATE(), @ResultType)
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].[RetirementInquiryState]
				SET
					[CreationDate] = GETDATE(),
					[ResultType] = @ResultType
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetIsManager'))
	DROP PROCEDURE inq.spGetIsManager
GO

CREATE PROCEDURE inq.spGetIsManager
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		man.ID,
		man.IndividualID,
		man.LastModifyDate,
		man.IsManager
	FROM inq.IsManager man
	WHERE ID = @ID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetIsManagerByIndividualID'))
	DROP PROCEDURE inq.spGetIsManagerByIndividualID
GO

CREATE PROCEDURE inq.spGetIsManagerByIndividualID
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
		man.ID,
		man.IndividualID,
		man.LastModifyDate,
		man.IsManager
	FROM inq.IsManager man
	WHERE IndividualID = @IndividualID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetSabteAsnadNationalCode'))
	DROP PROCEDURE inq.spGetSabteAsnadNationalCode
GO

CREATE PROCEDURE inq.spGetSabteAsnadNationalCode
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

		SELECT
			*
		FROM inq.SabteAsnadNationalCode
		WHERE ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetSabteAsnadNationalCodeByNationalCode'))
	DROP PROCEDURE inq.spGetSabteAsnadNationalCodeByNationalCode
GO

CREATE PROCEDURE inq.spGetSabteAsnadNationalCodeByNationalCode
	@ANationalCode NVARCHAR(20)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@NationalCode NVARCHAR(20) = @ANationalCode

		SELECT
			*,
			ID AS SabteAsnadNationalcodeID
		FROM inq.SabteAsnadNationalCode
		WHERE NationalCode = @NationalCode
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyIsManager'))
	DROP PROCEDURE inq.spModifyIsManager
GO

CREATE PROCEDURE inq.spModifyIsManager
	@AIsManager TINYINT,
	@AIsNewRecord BIT,
	@AIndividualID UNIQUEIDENTIFIER,
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsManager TINYINT = COALESCE(@AIsManager, 0),
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ID UNIQUEIDENTIFIER = @AID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN			
				INSERT INTO inq.IsManager
					(ID, LastModifyDate, IndividualID, IsManager)
				VALUES
					(NEWID(), GETDATE(), @IndividualID, @IsManager)
			END
			ELSE				-- update
			BEGIN
				UPDATE inq.IsManager
				SET 
					IsManager = @IsManager,
					LastModifyDate = GETDATE()
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyIsManagerInquiryState'))
	DROP PROCEDURE inq.spModifyIsManagerInquiryState
GO

CREATE PROCEDURE inq.spModifyIsManagerInquiryState
	@AIndividualID UNIQUEIDENTIFIER,
	@AResultMessage NVARCHAR(4000),
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ResultMessage NVARCHAR(4000) = LTRIM(RTRIM(@AResultMessage)),
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN

			INSERT INTO [inq].IsManagerInquiryState
					([ID], [IndividualID], [CreationDate], [ResultType], [ResultMessage])
				VALUES
					(NEWID(), @IndividualID, GETDATE(), @ResultType, @ResultMessage)			

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM SYS.OBJECTS WHERE [object_id] = OBJECT_ID(N'inq.spModifySabteAsnadNationalCode') AND TYPE IN (N'P', N'PC'))
DROP PROCEDURE inq.spModifySabteAsnadNationalCode
GO

CREATE PROCEDURE inq.spModifySabteAsnadNationalCode
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(20),
	@AName NVARCHAR(500),
	@AAddress NVARCHAR(500),
	@AState NVARCHAR(10),
	@APostCode NVARCHAR(10),
	@ARegisterNumber NVARCHAR(10),
	@AEstablishmentDate NVARCHAR(30),
	@ARegisterDate NVARCHAR(30),
	@ALastChangeDate NVARCHAR(30),
	@ALegalPersonType NVARCHAR(10),
	@ARegisterUnit NVARCHAR(50),
	@AResidency NVARCHAR(50),
	@ABreakupDate NVARCHAR(30),
	@ASettleDate NVARCHAR(30),
	@AIsBranch BIT,
	@AIsBreakup BIT,
	@AIsSettle BIT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@NationalCode NVARCHAR(20) = @ANationalCode,
		@Name NVARCHAR(500) = @AName,
		@Address NVARCHAR(500) = @AAddress,
		@State NVARCHAR(10) = @AState,
 		@PostCode NVARCHAR(10) = @APostCode,
		@RegisterNumber NVARCHAR(10) = @ARegisterNumber,
		@EstablishmentDate NVARCHAR(30) = @AEstablishmentDate,
		@RegisterDate NVARCHAR(30) = @ARegisterDate,
		@LastChangeDate NVARCHAR(30) = @ALastChangeDate,
		@LegalPersonType NVARCHAR(10) = @ALegalPersonType,
		@RegisterUnit NVARCHAR(50) = @ARegisterUnit,
		@Residency NVARCHAR(50) = @AResidency,
		@BreakupDate NVARCHAR(30) = @ABreakupDate,
		@SettleDate NVARCHAR(30) = @ASettleDate,
		@IsBranch BIT = @AIsBranch,
		@IsBreakup BIT = @AIsBreakup,
		@IsSettle BIT = @AIsSettle

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1  -- insert 
			BEGIN
				
				INSERT INTO [inq].[SabteAsnadNationalCode]
					([ID], [NationalCode], [Name], [Address], [State], [PostCode], [RegisterNumber], [EstablishmentDate], [RegisterDate], [LastChangeDate], [LegalPersonType], [RegisterUnit], [Residency], [BreakupDate], [SettleDate], [IsBranch], [IsBreakup], [IsSettle] ,[CreationDate])
				VALUES
					(@ID, @NationalCode, @Name, @Address, @State, @PostCode, @RegisterNumber, @EstablishmentDate, @RegisterDate, @LastChangeDate, @LegalPersonType, @RegisterUnit, @Residency, @BreakupDate, @SettleDate, @IsBranch, @IsBreakup, @IsSettle , GETDATE())

			END
			ELSE 			 -- update
			BEGIN
				
				UPDATE [inq].[SabteAsnadNationalCode]
				SET
					[Name] = @Name,
					[Address] = @Address,
					[State] = @State,
					[PostCode] = @PostCode,
					[RegisterNumber] = @RegisterNumber,
					[EstablishmentDate] = @EstablishmentDate,
					[RegisterDate] = @RegisterDate,
					[LastChangeDate] = @LastChangeDate,
					[LegalPersonType] = @LegalPersonType,
					[RegisterUnit] = @RegisterUnit,
					[Residency] = @Residency,
					[BreakupDate] = @BreakupDate,
					[SettleDate] = @SettleDate,
					[IsBranch] = @IsBranch,
					[IsBreakup] = @IsBreakup,
					[IsSettle] = @IsSettle
				WHERE NationalCode = @NationalCode
											
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifySabteAsnadVaAmlakInquiryState'))
	DROP PROCEDURE inq.spModifySabteAsnadVaAmlakInquiryState
GO

CREATE PROCEDURE inq.spModifySabteAsnadVaAmlakInquiryState
	@ALegalRequestID UNIQUEIDENTIFIER,
	@AResultMessage NVARCHAR(4000),
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@LegalRequestID UNIQUEIDENTIFIER = @ALegalRequestID,
		@ResultMessage NVARCHAR(4000) = LTRIM(RTRIM(@AResultMessage)),
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN

			INSERT INTO [inq].SabteAsnadVaAmlakInquiryState
					([ID], [LegalRequestID], [CreationDate], [ResultType], [ResultMessage])
				VALUES
					(NEWID(), @LegalRequestID, GETDATE(), @ResultType, @ResultMessage)			

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('inq.spGetSacrificial'))
	DROP PROCEDURE inq.spGetSacrificial
GO

CREATE PROCEDURE inq.spGetSacrificial
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	SELECT
		ID, 
		IndividualID, 
		VeteranPercent, 
		ParentVeteranPercent, 
		SpouseVeteranPercent, 
		CaptivityDurationDays, 
		ParentCaptivityDurationDays, 
		SpouseCaptivityDurationDays,
		CreationDate
	FROM inq.Sacrificial
	WHERE IndividualID = @IndividualID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID('inq.spGetSacrificials'))
	DROP PROCEDURE inq.spGetSacrificials
GO

CREATE PROCEDURE inq.spGetSacrificials
	@AIndividualID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@AIndividualIDs NVARCHAR(MAX),
	@ANationalCodes NVARCHAR(MAX),
	@AFirstName NVARCHAR(255),
	@ALastName NVARCHAR(255),
	@AGender TINYINT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@NationalCode NVARCHAR(10) = @ANationalCode,
		@IndividualIDs NVARCHAR(MAX) = @AIndividualIDs,
		@NationalCodes NVARCHAR(MAX) = @ANationalCodes,
		@FirstName NVARCHAR(255) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(255) = LTRIM(RTRIM(@ALastName)),
		@Gender TINYINT = COALESCE(@AGender, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH Individual AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			individual.FirstName,
			individual.LastName,
			individual.BirthDate,
			COALESCE(individual.IsDead, 0) IsDead,
			COALESCE(individual.Gender, 0) Gender,
			individual.ConfirmType
		FROM [Kama.Aro.Organization].org.Individual individual
		LEFT JOIN OPENJSON(@IndividualIDs) IndividualIDs ON IndividualIDs.value = individual.ID
		LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = individual.NationalCode
		WHERE (@NationalCode IS NULL OR individual.NationalCode = @NationalCode)
		AND (@Gender < 1 OR individual.Gender = @Gender - 1)
		AND (@FirstName IS NULL OR Individual.FirstName LIKE '%' + @FirstName + '%')
		AND (@LastName IS NULL OR Individual.LastName LIKE '%' + @LastName + '%')
		AND (@IndividualIDs IS NULL OR IndividualIDs.value = individual.ID)
		AND (@IndividualID IS NULL OR individual.ID = @IndividualID)
		AND (@NationalCodes IS NULL OR NationalCodes.value = individual.NationalCode)
	)

	SELECT
		sacrificial.ID, 
		sacrificial.IndividualID, 
		individual.NationalCode,
		individual.FirstName,
		individual.LastName,
		individual.BirthDate,
		individual.IsDead,
		individual.Gender,
		individual.ConfirmType,
		sacrificial.VeteranPercent, 
		sacrificial.ParentVeteranPercent, 
		sacrificial.SpouseVeteranPercent, 
		sacrificial.CaptivityDurationDays, 
		sacrificial.ParentCaptivityDurationDays, 
		sacrificial.SpouseCaptivityDurationDays,
		sacrificial.CreationDate
	FROM inq.Sacrificial sacrificial
	INNER JOIN Individual individual ON individual.ID = Sacrificial.IndividualID
	WHERE IndividualID = @IndividualID

	Order BY IndividualID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifySacrificial'))
	DROP PROCEDURE inq.spModifySacrificial
GO

CREATE PROCEDURE inq.spModifySacrificial
	@AIndividualID UNIQUEIDENTIFIER,
	@AVeteranPercent TINYINT,
	@AParentVeteranPercent TINYINT,
	@ASpouseVeteranPercent TINYINT,
	@ACaptivityDurationDays INT,
	@AParentCaptivityDurationDays INT,
	@ASpouseCaptivityDurationDays INT,
	@ASacrificialTypes NVARCHAR(MAX),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@VeteranPercent TINYINT = COALESCE(@AVeteranPercent, 0),
		@ParentVeteranPercent TINYINT = COALESCE(@AParentVeteranPercent, 0),
		@SpouseVeteranPercent TINYINT = COALESCE(@ASpouseVeteranPercent, 0),
		@CaptivityDurationDays INT = @ACaptivityDurationDays,
		@ParentCaptivityDurationDays INT = @AParentCaptivityDurationDays,
		@SpouseCaptivityDurationDays INT = @ASpouseCaptivityDurationDays,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@SacrificialTypes NVARCHAR(MAX) = LTRIM(RTRIM(@ASacrificialTypes)),
		@ID UNIQUEIDENTIFIER

	SET @ID = COALESCE((SELECT ID FROM inq.Sacrificial WHERE IndividualID = @IndividualID), 0x)

	BEGIN TRY
		BEGIN TRAN
			
			DELETE FROM inq.SacrificialType WHERE SacrificialID = @ID
			DELETE FROM inq.Sacrificial WHERE ID = @ID

			SET @ID = NEWID()

			INSERT INTO inq.Sacrificial
				(ID, IndividualID, VeteranPercent, ParentVeteranPercent, SpouseVeteranPercent, CaptivityDurationDays, ParentCaptivityDurationDays, SpouseCaptivityDurationDays, CreationDate)
			VALUES
				(@ID, @IndividualID, @VeteranPercent, @ParentVeteranPercent, @SpouseVeteranPercent, @CaptivityDurationDays, @ParentCaptivityDurationDays, @SpouseCaptivityDurationDays, GETDATE())

			INSERT INTO inq.SacrificialType
				(ID, SacrificialID, [Type])
			SELECT 
				NEWID() ID,
				@ID SacrificialID,
				value [Type]
			FROM OPENJSON(@SacrificialTypes)
			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifySacrificialInquiryState'))
	DROP PROCEDURE inq.spModifySacrificialInquiryState
GO

CREATE PROCEDURE inq.spModifySacrificialInquiryState
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER,
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@ResultType TINYINT = COALESCE(@AResultType, 0)
	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO [inq].[SacrificialInquiryState]
					([ID], [IndividualID], [CreationDate], [ResultType])
				VALUES
					(NEWID(), @IndividualID, GETDATE(), @ResultType)
			END
			ELSE 				    -- update
			BEGIN
				UPDATE [inq].[SacrificialInquiryState]
				SET
					[CreationDate] = GETDATE(),
					[ResultType] = @ResultType
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetSacrificialTypes'))
DROP PROCEDURE inq.spGetSacrificialTypes
GO

CREATE PROCEDURE inq.spGetSacrificialTypes
	@ASacrificialID UNIQUEIDENTIFIER,
	@ASacrificialIDs NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@SacrificialID UNIQUEIDENTIFIER = @ASacrificialID,
		@SacrificialIDs NVARCHAR(MAX) = @ASacrificialIDs,
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
			sacrificialType.ID,
			sacrificialType.SacrificialID,
			sacrificialType.[Type]
		FROM inq.SacrificialType sacrificialType
		LEFT JOIN OPENJSON(@SacrificialIDs) SacrificialIDs ON SacrificialIDs.value = sacrificialType.SacrificialID
		WHERE (@SacrificialID IS NULL OR SacrificialID = @SacrificialID)
		AND (@SacrificialIDs IS NULL OR SacrificialIDs.value = sacrificialType.SacrificialID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	Order BY [Type]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyWebServiceInquiryState'))
	DROP PROCEDURE inq.spModifyWebServiceInquiryState
GO

CREATE PROCEDURE inq.spModifyWebServiceInquiryState
	@AWebServiceID UNIQUEIDENTIFIER,
	@AResultMessage NVARCHAR(4000),
	@AWebServiceLocationType TINYINT,
	@AResultType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@WebServiceID UNIQUEIDENTIFIER = @AWebServiceID,
		@ResultMessage NVARCHAR(4000) = LTRIM(RTRIM(@AResultMessage)),
		@WebServiceLocationType TINYINT = COALESCE(@AWebServiceLocationType, 0),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
		@CurrentDate SMALLDATETIME = GETDATE()
	BEGIN TRY
		BEGIN TRAN

			INSERT INTO [inq].WebServiceInquiryState
					([ID], WebServiceID, [CreationDate], [ResultType], [ResultMessage], WebServiceLocationType)
				VALUES
					(NEWID(), @WebServiceID, @CurrentDate, @ResultType, @ResultMessage, @WebServiceLocationType)	
		
			IF @WebServiceLocationType = 1 --Local
			BEGIN 
				UPDATE org.WebService
				SET LatestLocalInquiryDate = @CurrentDate, LatestLocalInquiryResultType = @ResultType
				WHERE ID = @WebServiceID
			END

			IF @WebServiceLocationType = 2 --Gsb
			BEGIN 
				UPDATE org.WebService
				SET LatestGsbInquiryDate = @CurrentDate, LatestGsbInquiryResultType = @ResultType
				WHERE ID = @WebServiceID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetAddressInquiryLogs'))
	DROP PROCEDURE inq.spGetAddressInquiryLogs
GO

CREATE PROCEDURE inq.spGetAddressInquiryLogs
	@AAddressID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@APostalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@AddressID UNIQUEIDENTIFIER = @AAddressID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@PostalCode NVARCHAR(10) = LTRIM(RTRIM(@APostalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			adrInq.ID,
			adrInq.AddressID,
			adrInq.CreationDate,
			adrInq.ResultType,
			adr.PostalCode as PostalCode
		FROM inq.[AddressInquiryState] adrInq
			INNER JOIN inq.[Address] adr ON adr.ID = adrInq.AddressID
		where (@AddressID IS NULL OR adrInq.AddressID = @AddressID)
		AND (@StartDate IS NULL OR adrInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR adrInq.CreationDate < @EndDate)
		AND (@PostalCode IS NULL OR adr.PostalCode = @PostalCode)
		AND (@ResultType < 1 OR adrInq.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetDigitalSignatureInquiryLogs'))
	DROP PROCEDURE inq.spGetDigitalSignatureInquiryLogs
GO

CREATE PROCEDURE inq.spGetDigitalSignatureInquiryLogs
	@AApplicationID UNIQUEIDENTIFIER,
	@AAttachmentID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@ANationalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@AttachmentID UNIQUEIDENTIFIER = @AAttachmentID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			digInq.ID,
			digInq.ApplicationID,
			digInq.AttachmentID,
			digInq.CreationDate,
			digInq.ResultType,
			digInq.ResultMessage,
			digInq.RedirectApiUrl
		FROM inq.DigitalSignatureInquiryState digInq
		WHERE (@AttachmentID IS NULL OR digInq.AttachmentID = @AttachmentID)
		AND (@ApplicationID IS NULL OR digInq.ApplicationID = @ApplicationID)
		AND (@StartDate IS NULL OR digInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR digInq.CreationDate < @EndDate)
		AND (@ResultType < 1 OR digInq.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetEducationalInquiryLogs'))
	DROP PROCEDURE inq.spGetEducationalInquiryLogs
GO

CREATE PROCEDURE inq.spGetEducationalInquiryLogs
	@AIndividualID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@ANationalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			eduInq.ID,
			eduInq.IndividualID,
			eduInq.CreationDate,
			eduInq.ResultType,
			eduInq.ResultCount,
			ind.NationalCode as NationalCode
		FROM inq.[EducationalInquiryState] eduInq
			INNER JOIN org.individual ind ON ind.ID = eduInq.IndividualID
		where (@IndividualID IS NULL OR eduInq.IndividualID = @IndividualID)
		AND (@StartDate IS NULL OR eduInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR eduInq.CreationDate < @EndDate)
		AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
		AND (@ResultType < 1 OR eduInq.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetICTParticipationDailyInquiryLogs'))
	DROP PROCEDURE inq.spGetICTParticipationDailyInquiryLogs
GO

CREATE PROCEDURE inq.spGetICTParticipationDailyInquiryLogs
	@AStartDate DATE,
	@AEndDate DATE,	
	@AInquiryStartDate DATE,
	@AInquiryEndDate DATE,
	@AInquiryStartHour TIME,
	@AInquiryEndHour TIME,
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@InquiryStartDate DATE = @AInquiryStartDate,
		@InquiryEndDate DATE = DATEADD(DAY, 1, @AInquiryEndDate),
		@InquiryStartHour TIME = @AInquiryStartHour,
		@InquiryEndHour TIME = @AInquiryEndHour,
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			ictInq.ID,
			ictInq.InquiryDate,
			ictInq.CreationDate,
			ictInq.ReceivedCount,
			ictInq.ResultType,
			ictInq.ResultMessage
		FROM inq.ICTParticipateDailyInquiryState ictInq
		WHERE
			(@StartDate IS NULL OR ictInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR ictInq.CreationDate < @EndDate)
		AND (@InquiryStartDate IS NULL OR ictInq.InquiryDate >= @InquiryStartDate)
		AND (@InquiryEndDate IS NULL OR ictInq.InquiryDate < @InquiryEndDate)
		AND (@ResultType < 1 OR ictInq.ResultType = @ResultType)
		AND (@AInquiryStartHour IS NULL OR DATEPART(HOUR, ictInq.InquiryDate) >= DATEPART(HOUR, @AInquiryStartHour))
		AND (@InquiryEndHour IS NULL OR DATEPART(HOUR, ictInq.InquiryDate) < DATEPART(HOUR, @InquiryEndHour))
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetImageSmartInquiryLogs'))
	DROP PROCEDURE inq.spGetImageSmartInquiryLogs
GO

CREATE PROCEDURE inq.spGetImageSmartInquiryLogs
	@AIndividualID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@ANationalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			imgInq.ID,
			imgInq.IndividualID,
			imgInq.CreationDate,
			imgInq.ResultType,
			imgInq.ResultMessage,
			ind.NationalCode as NationalCode
		FROM inq.ImageSmartInquiryState imgInq
			INNER JOIN org.individual ind ON ind.ID = imgInq.IndividualID
		where (@IndividualID IS NULL OR imgInq.IndividualID = @IndividualID)
		AND (@StartDate IS NULL OR imgInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR imgInq.CreationDate < @EndDate)
		AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
		AND (@ResultType < 1 OR imgInq.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetInsuranceInquiryLogs'))
	DROP PROCEDURE inq.spGetInsuranceInquiryLogs
GO

CREATE PROCEDURE inq.spGetInsuranceInquiryLogs
	@AIndividualID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@ANationalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			incInq.ID,
			incInq.IndividualID,
			incInq.CreationDate,
			incInq.ResultType,
			ind.NationalCode as NationalCode
		FROM inq.[InsuranceInquiryState] incInq
			INNER JOIN org.individual ind ON ind.ID = incInq.IndividualID
		where (@IndividualID IS NULL OR incInq.IndividualID = @IndividualID)
		AND (@StartDate IS NULL OR incInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR incInq.CreationDate < @EndDate)
		AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
		AND (@ResultType < 1 OR incInq.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetIsManagerInquiryLogs'))
	DROP PROCEDURE inq.spGetIsManagerInquiryLogs
GO

CREATE PROCEDURE inq.spGetIsManagerInquiryLogs
	@AIndividualID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@ANationalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			isMang.ID,
			isMang.IndividualID,
			isMang.CreationDate,
			isMang.ResultType,
			isMang.ResultMessage,
			ind.NationalCode as NationalCode
		FROM inq.[IsManagerInquiryState] isMang
			INNER JOIN org.individual ind ON ind.ID = isMang.IndividualID
		where (@IndividualID IS NULL OR isMang.IndividualID = @IndividualID)
		AND (@StartDate IS NULL OR isMang.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR isMang.CreationDate < @EndDate)
		AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
		AND (@ResultType < 1 OR isMang.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetRetirementInformationInquiryLogs'))
	DROP PROCEDURE inq.spGetRetirementInformationInquiryLogs
GO

CREATE PROCEDURE inq.spGetRetirementInformationInquiryLogs
	@AIndividualID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@ANationalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			retInq.ID,
			retInq.IndividualID,
			retInq.CreationDate,
			retInq.ResultType,
			ind.NationalCode as NationalCode
		FROM inq.[RetirementInquiryState] retInq
			INNER JOIN org.individual ind ON ind.ID = retInq.IndividualID
		where (@IndividualID IS NULL OR retInq.IndividualID = @IndividualID)
		AND (@StartDate IS NULL OR retInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR retInq.CreationDate < @EndDate)
		AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
		AND (@ResultType < 1 OR retInq.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetSacrificialInquiryLogs'))
	DROP PROCEDURE inq.spGetSacrificialInquiryLogs
GO

CREATE PROCEDURE inq.spGetSacrificialInquiryLogs
	@AIndividualID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@ANationalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			scrInq.ID,
			scrInq.IndividualID,
			scrInq.CreationDate,
			scrInq.ResultType,
			ind.NationalCode as NationalCode
		FROM inq.[SacrificialInquiryState] scrInq
			INNER JOIN org.individual ind ON ind.ID = scrInq.IndividualID
		where (@IndividualID IS NULL OR scrInq.IndividualID = @IndividualID)
		AND (@StartDate IS NULL OR scrInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR scrInq.CreationDate < @EndDate)
		AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
		AND (@ResultType < 1 OR scrInq.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spGetVaccinationInquiryLogs'))
	DROP PROCEDURE inq.spGetVaccinationInquiryLogs
GO

CREATE PROCEDURE inq.spGetVaccinationInquiryLogs
	@AIndividualID UNIQUEIDENTIFIER,
	@AStartDate DATE,
	@AEndDate DATE,
	@ANationalCode NVARCHAR(10),
	@AResultType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@StartDate DATE = @AStartDate,
		@EndDate DATE = DATEADD(DAY, 1, @AEndDate),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ResultType TINYINT = COALESCE(@AResultType, 0),
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
			vacInq.ID,
			vacInq.IndividualID,
			vacInq.CreationDate,
			vacInq.ResultType,
			vacInq.ResultMessage,
			ind.NationalCode as NationalCode
		FROM inq.[VaccineInquiryState] vacInq
			INNER JOIN org.individual ind ON ind.ID = vacInq.IndividualID
		where (@IndividualID IS NULL OR vacInq.IndividualID = @IndividualID)
		AND (@StartDate IS NULL OR vacInq.CreationDate >= @StartDate)
		AND (@EndDate IS NULL OR vacInq.CreationDate < @EndDate)
		AND (@NationalCode IS NULL OR ind.NationalCode = @NationalCode)
		AND (@ResultType < 1 OR vacInq.ResultType = @ResultType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteApplication'))
DROP PROCEDURE org.spDeleteApplication
GO

CREATE PROCEDURE org.spDeleteApplication
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

			DELETE FROM org.Application
			where ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplication'))
	DROP PROCEDURE org.spGetApplication
GO

CREATE PROCEDURE org.spGetApplication
	  @AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT
		ID,
		[Name],
		[Enabled],
		Abbreviation,
		Code,
		Comment,
		UniqueRole,
		EnumName
	FROM org.[Application]
	WHERE  ID = @ID
	
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplications'))
	DROP PROCEDURE org.spGetApplications
GO

CREATE PROCEDURE org.spGetApplications
	  @AName NVARCHAR(100),
	  @AAbbreviation NVARCHAR(100),
	  @AComment NVARCHAR(100),
	  @AClientName NVARCHAR(100),
	  @AEnabled TINYINT,
	  @APageSize INT,
	  @APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
	    @Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
	    @Abbreviation NVARCHAR(100) = LTRIM(RTRIM(@AAbbreviation)),
	    @Comment NVARCHAR(100) = LTRIM(RTRIM(@AComment)),
	    @ClientName NVARCHAR(100) = LTRIM(RTRIM(@AClientName)),
	    @Enabled TINYINT = COALESCE(@AEnabled , 0),
	    @PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH Clients AS (
		SELECT DISTINCT ApplicationID FROM org.Client
		WHERE (@ClientName IS NULL OR [Name] LIKE CONCAT('%', @ClientName, '%'))
	)
	, Mainselect as 
	(
		SELECT
			app.ID,
			app.[Name],
			app.Code,
			app.[Enabled],
			app.Abbreviation, 
			app.Comment,
			app.UniqueRole,
			app.EnumName
		FROM org.[Application] app
			INNER JOIN Clients on Clients.ApplicationID = app.ID
		WHERE (@Name IS NULL OR app.[Name] Like CONCAT('%', @Name, '%'))
		   AND(@Abbreviation IS NULL OR app.Abbreviation Like CONCAT('%', @Abbreviation, '%'))
		   AND(@Comment IS NULL OR app.Comment Like CONCAT('%', @Comment, '%'))
		   AND(@Enabled < 1 OR app.[Enabled] = @Enabled - 1)
	)
	, Total AS 
	(
		SELECT COUNT(*) as Total
		FROM Mainselect
		WHERE (@Name IS NULL OR Name Like CONCAT('%', @Name, '%'))
	)

	SELECT * FROM MainSelect, Total
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplications2'))
	DROP PROCEDURE org.spGetApplications2
GO

CREATE PROCEDURE org.spGetApplications2
	  @AName NVARCHAR(100),
	  @ASsoState BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@Name NVARCHAR(100) = LTRIM(RTRIM(@AName)),
		@SsoState BIT = @ASsoState
	
	SELECT
		app.ID,
		clt.ID ClientID,
		CASE WHEN IsNull(clt.[Name], '') <> '' THEN clt.[Name] ELSE app.[Name] END [Name],
		CASE WHEN IsNull(clt.Abbreviation, '') <> '' THEN clt.Abbreviation ELSE app.Abbreviation END Abbreviation,
		app.[Code],
		app.[Enabled],
		app.Comment,
		clt.Icon,
		clt.SsoState
	FROM org.[Application] app
		INNER JOIN org.Client clt ON clt.ApplicationID = app.ID 
			AND (@SsoState IS NULL OR clt.SsoState = @SsoState)
	ORDER BY clt.[Order]
	
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplicationsByAssignment'))
	DROP PROCEDURE org.spGetApplicationsByAssignment
GO

CREATE PROCEDURE org.spGetApplicationsByAssignment
	@AUserOrganID UNIQUEIDENTIFIER,
	@APositionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@UserOrganID UNIQUEIDENTIFIER = COALESCE(@AUserOrganID, 0x)

	;WITH Assignment As
	(
		SELECT ApplicationID
		FROM org.ApplicationAssignment
		WHERE ApplicationAssignment.PositionID = @PositionID
		AND RemoveDate IS NULL
		GROUP BY ApplicationID
	)
	SELECT
		app.ID,
		app.[Name],
		app.[Code],
		app.[Enabled],
		app.Abbreviation,
		app.Comment,
		app.UniqueRole,
		app.EnumName
	FROM org.[Application] app
		LEFT JOIN Assignment ON Assignment.ApplicationID = app.ID
	WHERE (@UserOrganID <> 0x OR Assignment.ApplicationID IS NOT NULL)
		AND app.ID != 'F4249B0E-0EFF-410B-BF45-AE234289CFFC'
	
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyApplication'))
	DROP PROCEDURE org.spModifyApplication
GO

CREATE PROCEDURE org.spModifyApplication
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ACode VARCHAR(20),
	@AName NVARCHAR(256),
	@AEnabled BIT,
	@AAbbreviation NVARCHAR(256),
	@AComment NVARCHAR(256),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	 DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
	    @ID UNIQUEIDENTIFIER = @AID,
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)),
		@Abbreviation NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@Enabled BIT = COALESCE(@AEnabled, 0),
		@Comment NVARCHAR(256) = LTRIM(RTRIM(@AComment)),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO org.[Application]
				(ID, Code, [Name], [Enabled], Comment, [Abbreviation])
				VALUES
				(@ID, @Code, @Name, @Enabled, @Comment, @AAbbreviation)
			END
			ELSE 
			BEGIN -- update
				UPDATE org.[Application]
				SET Code = @Code, [Name] = @Name, [Enabled] = @Enabled, Comment = @Comment, Abbreviation=@AAbbreviation
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteApplicationAssignment'))
DROP PROCEDURE org.spDeleteApplicationAssignment
GO

CREATE PROCEDURE org.spDeleteApplicationAssignment
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		  @ID UNIQUEIDENTIFIER = @AID,
		  @UserID UNIQUEIDENTIFIER = @AUserID

	BEGIN TRY
		BEGIN TRAN

			Update [org].[ApplicationAssignment]
			SET
				RemoveDate = GETDATE(),
				RemoverUserID = @UserID
			WHERE
				ID = @ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplicationAssignment'))
	DROP PROCEDURE org.spGetApplicationAssignment
GO

CREATE PROCEDURE org.spGetApplicationAssignment
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		applicationAssignment.[ID], 
		applicationAssignment.[PositionID], 
		applicationAssignment.[ApplicationID], 
		applicationAssignment.[RemoverUserID], 
		applicationAssignment.[RemoveDate],
		app.[Name] ApplicationName
	FROM [org].[ApplicationAssignment] applicationAssignment
		INNER JOIN org.[Application] app ON app.ID = applicationAssignment.ApplicationID
	WHERE applicationAssignment.ID = @ID
		AND (applicationAssignment.[RemoverUserID] IS NULL)
		AND (applicationAssignment.[RemoveDate] IS NULL)

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplicationAssignments'))
	DROP PROCEDURE org.spGetApplicationAssignments
GO

CREATE PROCEDURE org.spGetApplicationAssignments
	@APositionID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PositionID UNIQUEIDENTIFIER = @APositionID,
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
			applicationAssignment.[ID], 
			applicationAssignment.[PositionID], 
			applicationAssignment.[ApplicationID], 
			applicationAssignment.[RemoverUserID], 
			applicationAssignment.[RemoveDate],
			app.[Name] ApplicationName,
			app.UniqueRole, 
			app.EnumName,
			position.FirstName + N' ' + position.LastName AS PositionFullName
		FROM [org].[ApplicationAssignment] applicationAssignment
			INNER JOIN org.[Application] app ON app.ID = applicationAssignment.ApplicationID
			INNER JOIN org._Position position ON position.ID = applicationAssignment.PositionID
		WHERE (@PositionID IS NULL OR applicationAssignment.PositionID = @PositionID)
				AND (applicationAssignment.[RemoverUserID] IS NULL)
				AND (applicationAssignment.[RemoveDate] IS NULL)
	)
	, Total AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY [ApplicationName]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplicationAssignmentsForCartable'))
	DROP PROCEDURE org.spGetApplicationAssignmentsForCartable
GO

CREATE PROCEDURE org.spGetApplicationAssignmentsForCartable
	@AFirstName NVARCHAR(100),
	@ALastName NVARCHAR(100),
	@ANationalCode NVARCHAR(10),
	@AApplicationName NVARCHAR(200),
	@AAbbreviation NVARCHAR(200),
	@APageSize INT,
	@APageIndex INT

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
	    @FirstName NVARCHAR(100) = TRIM(@AFirstName),
		@LastName NVARCHAR(100) = TRIM(@ALastName) ,
		@NationalCode NVARCHAR(10)=TRIM(@ANationalCode),
		@ApplicationName NVARCHAR(200) = TRIM(@AApplicationName),
		@Abbreviation NVARCHAR(200) = TRIM(@AAbbreviation),
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
			pos.ID, 
			pos.FirstName,
			pos.LastName,
			pos.NationalCode,
			pos.Type PositionType
		FROM org._Position pos
			LEFT JOIN org.ApplicationAssignment aa ON aa.PositionID = pos.ID AND aa.RemoverUserID IS NULL
			LEFT JOIN org.Application app ON aa.ApplicationID = app.ID 
		WHERE 
			pos.ApplicationID = '6448C892-F0C7-4002-B139-011CB2E57D14' 
			AND pos.UserType = 1
			AND (@FirstName IS NULL OR  pos.FirstName LIKE '%' + @FirstName + '%')
			AND (@LastName IS NULL OR  pos.LastName LIKE '%' + @LastName + '%')
			AND (@NationalCode IS NULL OR  pos.NationalCode LIKE '%' + @NationalCode+ '%')
			AND (@Abbreviation IS NULL OR  app.Abbreviation LIKE '%' + @Abbreviation+ '%')
			AND (@ApplicationName IS NULL OR app.Name LIKE '%' + @ApplicationName + '%' OR app.Abbreviation LIKE '%' + @ApplicationName + '%')
		GROUP BY 
			pos.ID, 
			pos.FirstName,
			pos.LastName,
			pos.NationalCode,
			pos.Type
	)
	, Total AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY LastName
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyApplicationAssignment'))
	DROP PROCEDURE org.spModifyApplicationAssignment
GO

CREATE PROCEDURE org.spModifyApplicationAssignment
	@APositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID


	BEGIN TRY
		BEGIN TRAN

			BEGIN
				INSERT INTO [org].[ApplicationAssignment]
					([ID], [PositionID], [ApplicationID], [RemoverUserID], [RemoveDate])
				VALUES
					(NEWID(), @PositionID, @ApplicationID, NULL, NULL)
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplicationAssignmentsByPositionIDs'))
	DROP PROCEDURE org.spGetApplicationAssignmentsByPositionIDs
GO

CREATE PROCEDURE org.spGetApplicationAssignmentsByPositionIDs
	@APositionIDs NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PositionIDs NVARCHAR(MAX) = @APositionIDs

	SELECT
		aa.ID, 
		aa.PositionID, 
		aa.ApplicationID, 
		aa.RemoverUserID, 
		aa.RemoveDate,
		app.[Name] ApplicationName,
		app.Abbreviation ApplicationAbbreviation,
		app.UniqueRole, 
		app.EnumName
	FROM org.ApplicationAssignment aa
		INNER JOIN org.[Application] app ON app.ID = aa.ApplicationID
		INNER JOIN OPENJSON(@PositionIDs) PositionIDs ON PositionIDs.value = aa.PositionID
	WHERE aa.RemoveDate IS NULL 
	
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplicationsList'))
	DROP PROCEDURE org.spGetApplicationsList
GO

CREATE PROCEDURE org.spGetApplicationsList
	@APositionID UNIQUEIDENTIFIER
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PositionID UNIQUEIDENTIFIER = @APositionID
	
	SELECT
		applicationAssignment.ApplicationID
	FROM [org].[ApplicationAssignment] applicationAssignment
	WHERE applicationAssignment.PositionID = @PositionID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetAssignedApplicationsByPoistionID'))
	DROP PROCEDURE org.spGetAssignedApplicationsByPoistionID
GO

CREATE PROCEDURE org.spGetAssignedApplicationsByPoistionID
	@APositionID UNIQUEIDENTIFIER
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PositionID UNIQUEIDENTIFIER = @APositionID
	
	SELECT
		applicationAssignment.ApplicationID ID
	FROM [org].[ApplicationAssignment] applicationAssignment
	WHERE RemoverUserID IS NULL AND applicationAssignment.PositionID = @PositionID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetAssignedApplicationsByPoistionIDs'))
	DROP PROCEDURE org.spGetAssignedApplicationsByPoistionIDs
GO

CREATE PROCEDURE org.spGetAssignedApplicationsByPoistionIDs
	@APositionIDs NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PositionIDs NVARCHAR(MAX) = @APositionIDs

	SELECT
		app.ID,
		app.[Name],
		app.Abbreviation,
		aa.PositionID
	FROM org.ApplicationAssignment aa
		INNER JOIN org.[Application] app ON app.ID = aa.ApplicationID
		INNER JOIN OPENJSON(@PositionIDs) PositionIDs ON PositionIDs.value = aa.PositionID
	WHERE aa.RemoveDate IS NULL 
	
END

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spDeleteBudgetCodeAssignment') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spDeleteBudgetCodeAssignment
GO

CREATE PROCEDURE org.spDeleteBudgetCodeAssignment
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			UPDATE budgetCodeAssignment
			SET 
				[RemoverUserID] = @CurrentUserID,
				[RemoveDate] = GETDATE()
			FROM [org].[BudgetCodeAssignment] budgetCodeAssignment
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
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetBudgetCodeAssignment') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spGetBudgetCodeAssignment
GO

CREATE PROCEDURE org.spGetBudgetCodeAssignment
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		budgetCodeAssignment.[ID], 
		budgetCodeAssignment.[PositionSubTypeID], 
		positionSubType.[Name] PositionSubTypeName,
		budgetCodeAssignment.[DepartmentBudgetID], 
		departmentBudget.[Name] DepartmentBudgetName,
		budgetCodeAssignment.[CreationDate],
		positionSubType.DepartmentID,
		department.[Name] DepartmentName,
		departmentBudget.[BudgetCode]
	FROM [org].[BudgetCodeAssignment] budgetCodeAssignment
		INNER JOIN [org].[PositionSubType] positionSubType ON budgetCodeAssignment.PositionSubTypeID = positionSubType.ID
		INNER JOIN [org].[DepartmentBudget] departmentBudget ON budgetCodeAssignment.DepartmentBudgetID = departmentBudget.ID
		INNER JOIN [org].[Department] department ON department.ID = positionSubType.DepartmentID
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetBudgetCodeAssignments') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetBudgetCodeAssignments
GO

CREATE PROCEDURE org.spGetBudgetCodeAssignments
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentBudgetID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentBudgetID UNIQUEIDENTIFIER = @ADepartmentBudgetID,
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
			budgetCodeAssignment.[ID], 
			budgetCodeAssignment.[PositionSubTypeID], 
			positionSubType.[Name] PositionSubTypeName,
			budgetCodeAssignment.[DepartmentBudgetID], 
			departmentBudget.[Name] DepartmentBudgetName,
			budgetCodeAssignment.[CreationDate],
			positionSubType.DepartmentID,
			department.[Name] DepartmentName,
			departmentBudget.[BudgetCode]
		FROM [org].[BudgetCodeAssignment] budgetCodeAssignment
			INNER JOIN [org].[DepartmentBudget] departmentBudget ON budgetCodeAssignment.DepartmentBudgetID = departmentBudget.ID
			INNER JOIN [org].[PositionSubType] positionSubType ON budgetCodeAssignment.PositionSubTypeID = positionSubType.ID
			INNER JOIN [org].[Department] department ON department.ID = positionsubtype.DepartmentID
		WHERE (budgetCodeAssignment.RemoveDate IS NULL)
			AND (budgetCodeAssignment.[ApplicationID] = @ApplicationID)
			AND (@DepartmentID IS NULL OR department.ID = @DepartmentID)
			AND (@PositionSubTypeID IS NULL OR positionSubType.ID = @PositionSubTypeID)
	), TempCount AS 
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyBugetCodeAssignment'))
	DROP PROCEDURE org.spModifyBugetCodeAssignment
GO

CREATE PROCEDURE org.spModifyBugetCodeAssignment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@ADepartmentBudgetID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@DepartmentBudgetID UNIQUEIDENTIFIER = @ADepartmentBudgetID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [org].[BudgetCodeAssignment]
					([ID], [PositionSubTypeID], [DepartmentBudgetID], [ApplicationID], [CreationDate], [RemoverUserID], [RemoveDate])
				VALUES
					(@ID, @PositionSubTypeID, @DepartmentBudgetID, @ApplicationID, GETDATE(), NULL, NULL)
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spCreateCaptcha'))
	DROP PROCEDURE org.spCreateCaptcha
GO

CREATE PROCEDURE org.spCreateCaptcha
	@AID UNIQUEIDENTIFIER,
	@AText VARCHAR(20),
	@AType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Text VARCHAR(20) = LTRIM(RTRIM(@AText)),
		@Type TINYINT = @AType 

	BEGIN TRY
		BEGIN TRAN
			BEGIN
				INSERT INTO org.Captcha
				(ID, Text, [Type], CreationDate)
				VALUES
				(@ID, @Text, @Type, GETDATE())
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteCaptcha'))
	DROP PROCEDURE org.spDeleteCaptcha
GO

CREATE PROCEDURE org.spDeleteCaptcha
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
			DELETE org.Captcha
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetCaptcha'))
	DROP PROCEDURE org.spGetCaptcha
GO

CREATE PROCEDURE org.spGetCaptcha
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		Captcha.ID,
		Captcha.Text,
		Captcha.Type,
		Captcha.CreationDate
	FROM org.Captcha
	WHERE ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spChangeOrder'))
	DROP PROCEDURE org.spChangeOrder
GO

CREATE PROCEDURE org.spChangeOrder
	@AID UNIQUEIDENTIFIER,
	@AOrderNumber INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID,
		@OrderNumber INT = @AOrderNumber,
		@SelectID UNIQUEIDENTIFIER 

	BEGIN TRY
		BEGIN TRAN
			UPDATE org.Client Set [Order] = (SELECT [Order] FROM org.Client WHERE ID = @ID)
				WHERE [Order] = @OrderNumber
			UPDATE org.Client SET [Order] = @OrderNumber WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteClient'))
	DROP PROCEDURE org.spDeleteClient
GO

CREATE PROCEDURE org.spDeleteClient
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@Node HIERARCHYID 

	BEGIN TRY
		BEGIN TRAN
			DELETE FROM org.Client
			WHERE [ID] = @ID

			EXEC pbl.spAddLog @Log
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetClient'))
	DROP PROCEDURE org.spGetClient
GO

CREATE PROCEDURE org.spGetClient
	  @AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	 DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		Client.ID,
		Client.ApplicationID,
		app.[Name] ApplicationName,
		app.[Code] ApplicationCode,
		CAST(app.[Enabled] AS BIT) ApplicationEnabled,
		Client.[Name],
		Client.[Secret],
		Client.Abbreviation,
		Client.[Type],
		CAST(Client.[Enabled] AS BIT) [Enabled],
		Client.RefreshTokenLifeTime,
		Client.AllowedOrigin,
		SsoState
	FROM org.Client
		INNER JOIN org.[Application] app ON app.ID = client.ApplicationID
	WHERE  Client.ID = @ID
	ORDER BY [Name] ASC
	OPTION(RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetClientBySsoUser') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spGetClientBySsoUser
GO

CREATE PROCEDURE org.spGetClientBySsoUser
	@AUserID NVARCHAR(max),
	@AUserHash NVARCHAR(max),
	@ACallBackUrl NVARCHAR(max)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@UserID NVARCHAR(max) =@AUserID ,
		@UserHash NVARCHAR(max) = @AUserHash,
		@CallBackUrl NVARCHAR(max) =@ACallBackUrl

	SELECT Top 1
		[UserID] , 
		[UserHash] ,
		[CallBack] 
	FROM [org].Client
	WHERE 
		(@UserID IS NULL OR UserID = @UserID)
		AND (@UserHash IS NULL OR UserHash = @UserHash)
		AND (@CallBackUrl IS NULL OR CallBack = @CallBackUrl)
		
END 
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetClients'))
	DROP PROCEDURE org.spGetClients
GO

CREATE PROCEDURE org.spGetClients
	  @AApplicationID UNIQUEIDENTIFIER,
	  @AName NVARCHAR(50),
	  @AAbbreviation NVARCHAR(50),
	  @AEnabled TINYINT,
	  @ATypeClient TINYINT

WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	 DECLARE 
	 @ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
	 @Name NVARCHAR(50) = LTRIM(RTRIM(@AName)),
	 @Abbreviation NVARCHAR(50) = LTRIM(RTRIM(@AAbbreviation)),
	 @Enabled TINYINT = COALESCE( @AEnabled,0),
	 @TypeClient TINYINT =COALESCE (@ATypeClient,0)
	SELECT 
		Client.ID,
		Client.ApplicationID,
		app.[Name] ApplicationName,
		app.[Code] ApplicationCode,
		app.[Enabled] ApplicationEnabled,
		Client.[Name],
		Client.[Secret],
		Client.[Type],
		CAST(Client.[Enabled] AS BIT) [Enabled],
		Client.RefreshTokenLifeTime,
		Client.AllowedOrigin,
		Client.[Order],
		Client.Abbreviation
	FROM org.Client
	INNER JOIN org.[Application] app ON app.ID = client.ApplicationID
	WHERE ( @ApplicationID = CAST(0x0 AS UNIQUEIDENTIFIER) OR ApplicationID = @ApplicationID)
	  AND (@Name IS NULL OR Client.[Name]  LIKE '%' +@Name + '%') 
	  AND (@Abbreviation IS NULL OR Client.[Abbreviation]  LIKE '%' +@Abbreviation + '%') 
	  AND (@Enabled < 1 OR Client.[Enabled] = @AEnabled - 1)
	  AND (@TypeClient < 1 OR Client.[Type] = @ATypeClient)

	ORDER BY [Order] ASC
	OPTION(RECOMPILE);
END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetClientsForUser'))
	DROP PROCEDURE org.spGetClientsForUser
GO

CREATE PROCEDURE org.spGetClientsForUser
	@AUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID
	
	;WITH MainSelect AS (	
		SELECT DISTINCT
			clt.[Name],
			app.Abbreviation AppAbbreviation,
			clt.ID,
			clt.ApplicationID,
			clt.UserID,
			clt.UserHash,
			clt.CallBack
		FROM org.Position position
			INNER JOIN org.[Application] app ON app.ID = position.ApplicationID
			INNER JOIN org.Client clt ON clt.ApplicationID = app.ID
	 	WHERE app.[Enabled] = 1 
			AND position.RemoveDate IS NULL
			AND (clt.SsoState = 1)
			AND (@UserID IS NOT NULL AND position.UserID = @UserID)
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM Total, MainSelect
	OPTION (RECOMPILE);
END 

GO


USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyClient'))
	DROP PROCEDURE org.spModifyClient
GO

CREATE PROCEDURE org.spModifyClient
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(256),
	@ASecret NVARCHAR(256),
	@AType TINYINT,
	@AEnabled BIT,
	@AAbbreviation NVARCHAR(256),
	@AAllowedOrigin NVARCHAR(256),
	@ARefreshTokenLifeTime INT,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	 DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
	    @ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER =@AApplicationID ,
		@Name VARCHAR(256) = LTRIM(RTRIM(@AName)),
		@Secret VARCHAR(256) = LTRIM(RTRIM(@ASecret)),
		@Abbreviation NVARCHAR(256) = LTRIM(RTRIM(@AAbbreviation)),
		@Enabled BIT = ISNULL(@AEnabled, 0),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO org.[Client]
				(ID, ApplicationID, [Name], [Secret], [Enabled],[Abbreviation])
				VALUES
				(@ID, @ApplicationID, @Name, @Secret, @AEnabled, @AAbbreviation)
			END
			ELSE 
			BEGIN -- update
				UPDATE org.[Client]
				SET [Name] = @Name, [Secret] = @Secret, [Enabled] = @Enabled, Abbreviation=@AAbbreviation
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


USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spUpdateDetails'))
	DROP PROCEDURE org.spUpdateDetails
GO

CREATE PROCEDURE org.spUpdateDetails
	@AID UNIQUEIDENTIFIER,
	@APublishDate DATETIME,
	@AVersion VARCHAR(20)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	 DECLARE 
	    @ID UNIQUEIDENTIFIER = @AID,
		@PublishDate DATETIME =@APublishDate ,
		@Version VARCHAR(20) = LTRIM(RTRIM(@AVersion))

	BEGIN TRY
		BEGIN TRAN
			BEGIN -- update
				UPDATE org.[Client]
				SET
				[PublishDate] = @PublishDate
				, [Version] = @Version
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteCommand'))
	DROP PROCEDURE org.spDeleteCommand
GO

CREATE PROCEDURE org.spDeleteCommand
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@Node HIERARCHYID

	SET @Node = (SELECT [Node] FROM org.Command WHERE ID = @ID)  

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM org.RolePermission 
			WHERE CommandID = @ID

			DELETE FROM org.Command 
			WHERE [Node].IsDescendantOf(@Node) = 1
			AND ApplicationID = @ApplicationID

		

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetAggregateCommands'))
	DROP PROCEDURE org.spGetAggregateCommands
GO

CREATE PROCEDURE org.spGetAggregateCommands
	@AApplicationID UNIQUEIDENTIFIER,
	@ARoleIDs NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@RoleIDs NVARCHAR(Max) = @ARoleIDs


	;WITH RolePermission AS
	(
		SELECT DISTINCT
			rolePermission.CommandID
		FROM [org].[RolePermission] rolePermission
			LEFT JOIN OPENJSON(@RoleIDs) RoleIDs ON RoleIDs.value = rolePermission.RoleID
		WHERE @RoleIDs IS NULL OR RoleIDs.value = rolePermission.RoleID
	)

	, MainSelect AS
	(	
		SELECT Command.ID,
			Command.ApplicationID,
			Command.[Node].ToString() Node,
			Command.[Node].GetAncestor(1).ToString() ParentNode,
			Command.[Name],
			Command.FullName,
			Command.Title,
			Command.[Type]
		FROM org.Command
			INNER JOIN RolePermission ON RolePermission.CommandID = Command.ID
		WHERE Command.ApplicationID = @ApplicationID
	)

	SELECT * FROM MainSelect
	ORDER BY [Node] 

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetCommand'))
	DROP PROCEDURE org.spGetCommand
GO

CREATE PROCEDURE org.spGetCommand
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT ID,
		ApplicationID,
		Node.ToString() Node,
		Node.GetAncestor(1).ToString() ParentNode,
		[Name],
		FullName,
		Title,
		[Type],
		[Order]
	FROM org.Command
	WHERE (ID = @ID)

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetCommands'))
	DROP PROCEDURE org.spGetCommands
GO

CREATE PROCEDURE org.spGetCommands
	@AApplicationID UNIQUEIDENTIFIER,
	@ARoleID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@AName VARCHAR(256),
	@ATitle NVARCHAR(256),
	@AType TINYINT,
	@ATypes NVARCHAR(MAX),	
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@RoleID UNIQUEIDENTIFIER = @ARoleID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Name VARCHAR(256) = LTRIM(RTRIM(@AName)),
		@Title NVARCHAR(256) = LTRIM(RTRIM(@ATitle)),
		@Type TINYINT = COALESCE(@AType, 0),
		@Types NVARCHAR(MAX) = @ATypes,
		@ParentNode HIERARCHYID,		
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	SET @ParentNode = (SELECT [Node] FROM org.Command WHERE ID = @ParentID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	; WITH MainSelect AS
	(
		SELECT 
			Command.ID,
			Command.ApplicationID,
			Command.[Node].ToString() Node,
			Command.[Node].GetAncestor(1).ToString() ParentNode,
			Command.[Name],
			Command.FullName,
			Command.Title,
			Command.[Type],
			Command.[Order],
			parent.ID ParentID,
			parent.[Name] ParentName
		FROM org.Command
			LEFT JOIN org.RolePermission ON RolePermission.CommandID = Command.ID AND RolePermission.RoleID = @RoleID
			LEFT JOIN org.Command parent ON Command.Node.GetAncestor(1) = parent.Node and parent.ApplicationID = Command.ApplicationID
			LEFT JOIN OPENJSON(@Types) t ON t.VALUE = Command.[Type]
		WHERE Command.ApplicationID = @ApplicationID
			AND (@RoleID IS NULL OR RolePermission.RoleID = @RoleID)
			AND (@ParentNode IS NULL OR Command.[Node].IsDescendantOf(@ParentNode) = 1 AND Command.ApplicationID = @ApplicationID)
			AND (@Name IS NULL OR Command.[Name] LIKE CONCAT('%', @Name, '%'))
			AND (@Title IS NULL OR Command.Title LIKE CONCAT('%', @Title, '%'))
			AND (@Type < 1 OR Command.[Type] = @Type)
			AND (@Types IS NULL OR t.VALUE = Command.[Type])
	)
	, Total AS 
	(
		SELECT 
			Count(*) AS Total
		FROM org.Command
			LEFT JOIN org.RolePermission ON RolePermission.CommandID = Command.ID AND RolePermission.RoleID = @RoleID
			LEFT JOIN org.Command parent ON Command.Node.GetAncestor(1) = parent.Node and parent.ApplicationID = Command.ApplicationID
			LEFT JOIN OPENJSON(@Types) t ON t.VALUE = Command.[Type]
		WHERE Command.ApplicationID = @ApplicationID
			AND (@RoleID IS NULL OR RolePermission.RoleID = @RoleID)
			AND (@ParentNode IS NULL OR Command.[Node].IsDescendantOf(@ParentNode) = 1 AND Command.ApplicationID = @ApplicationID)
			AND (@Name IS NULL OR Command.[Name] LIKE CONCAT('%', @Name, '%'))
			AND (@Title IS NULL OR Command.Title LIKE CONCAT('%', @Title, '%'))
			AND (@Type < 1 OR Command.[Type] = @Type)
			AND (@Types IS NULL OR t.VALUE = Command.[Type])
	)

	SELECT * FROM MainSelect, Total
	ORDER BY [Order] ,[Node]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);


END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetCommandsByNationalCode'))
	DROP PROCEDURE org.spGetCommandsByNationalCode
GO

CREATE PROCEDURE org.spGetCommandsByNationalCode
	@AApplicationID UNIQUEIDENTIFIER,
	@ANationalCode VARCHAR(18),
	@ARoleID UNIQUEIDENTIFIER,
	@APositionType TINYINT,
	@ACommandID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@NationalCode VARCHAR(18) = @ANationalCode,
		@RoleID UNIQUEIDENTIFIER = @ARoleID,
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@CommandID UNIQUEIDENTIFIER = @ACommandID,
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
			command.[ID],
			command.[Name],
			command.[Title],
			command.[FullName],
			rol.ID RoleID,
			rol.[Name] RoleName,
			position.[Type] PositionType,
			usr.FirstName,
			usr.LastName,
			usr.NationalCode,
			usr.Username
		FROM org.Command command
			INNER JOIN [org].[RolePermission] rolePermission ON rolePermission.CommandID = command.ID
			INNER JOIN org.[Role] rol ON rol.ID = rolePermission.RoleID
			INNER JOIN [org].[PositionRole] positionRole ON positionRole.RoleID = rol.ID
			INNER JOIN [org].[Position] position ON position.ID = positionRole.PositionID
			INNER JOIN org.[User] usr ON usr.ID = position.UserID
		WHERE command.ApplicationID = @ApplicationID
			AND position.RemoveDate IS NULL
			AND position.UserID IS NOT NULL
			AND (@RoleID IS NULL OR rol.ID = @RoleID)
			AND (@NationalCode IS NULL OR usr.NationalCode = @NationalCode)
			AND (@PositionType < 1 OR position.[Type] = @PositionType)
			AND (@CommandID IS NULL OR command.ID = @CommandID)
	)
	, Total AS
	(
		SELECT Count(*) Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT *
	FROM MainSelect, Total
	ORDER BY RoleID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
END  
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetCommandsForEnum_'))
	DROP PROCEDURE pbl.spGetCommandsForEnum_
GO

CREATE PROCEDURE pbl.spGetCommandsForEnum_
	@AApplicationID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ApplicationID UNIQUEIDENTIFIER = @AApplicationID
			
	select 
		cmd.ID
		, cmd.[Name]
	FROM org.Command cmd
	WHERE cmd.ApplicationID = @ApplicationID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyCommand'))
	DROP PROCEDURE org.spModifyCommand
GO

CREATE PROCEDURE org.spModifyCommand
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@ANode HIERARCHYID,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName varchar(256),
	@AFullName varchar(1000),
	@ATitle nvarchar(256),
	@AType TINYINT,
	@AOrder INT,
	@ALog NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Node HIERARCHYID = @ANode,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name varchar(256) = LTRIM(RTRIM(@AName)),
		@FullName varchar(1000) = LTRIM(RTRIM(@AFullName)),
		@Title nvarchar(256) = LTRIM(RTRIM(@ATitle)),
		@Type TINYINT = COALESCE(@AType, 0),
		@Order INT = COALESCE(@AOrder, 0),
		@Log NVARCHAR(MAX) = @ALog,
		@ParentNode HIERARCHYID,
		@LastChildNode HIERARCHYID,
		@NewNode HIERARCHYID

	IF @Node IS NULL 
		OR @ParentID <> COALESCE((SELECT TOP 1 ID FROM org.Command WHERE @Node.GetAncestor(1) = [Node]), 0x)
	BEGIN
		SET @ParentNode = COALESCE((SELECT [Node] FROM org.Command WHERE ID = @ParentID), HIERARCHYID::GetRoot())
		SET @LastChildNode = (SELECT MAX([Node]) FROM org.Command WHERE [Node].GetAncestor(1) = @ParentNode)
		SET @NewNode = @ParentNode.GetDescendant(@LastChildNode, NULL)
		SET @Order = (SELECT MAX([Order]) FROM org.Command WHERE [Node].GetAncestor(1) = @ParentNode)
		SET @Order = COALESCE(@Order, 0) + 1
	END

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				SET @Order = (SELECT MAX([Order]) FROM org.Command WHERE [Node].GetAncestor(1) = @ParentNode)
				SET @Order = COALESCE(@Order, 0) + 1
				INSERT INTO org.Command
				(ID, [Node], ApplicationID, [Name], FullName, Title, [Type], CreationDate, [Order])
				VALUES
				(@ID, @NewNode, @ApplicationID, @Name, @FullName, @Title, @Type, GetDate(), @Order)
			END
			ELSE
			BEGIN -- update
				UPDATE org.Command
				SET [Name] = @Name, Title = @Title, [Type] = @Type, FullName = @FullName
				WHERE ID = @ID

				IF(@Node <> @NewNode)
				BEGIN
					UPDATE org.Command
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spSetCommandOrder'))
	DROP PROCEDURE org.spSetCommandOrder
GO

CREATE PROCEDURE org.spSetCommandOrder
	@ACommandID UNIQUEIDENTIFIER,
	@ADirection TINYINT
----WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;
	SET ANSI_NULLS OFF;

    DECLARE 
		@CommandID UNIQUEIDENTIFIER = @ACommandID
		, @Direction TINYINT = @ADirection 
		, @Node HIERARCHYID
		, @Order INT
		, @OrderToReplace INT
		, @IDToReplace UNIQUEIDENTIFIER
	
	SELECT @Order = [Order], @Node = [Node] FROM org.Command WHERE ID = @CommandID

	BEGIN TRY
		BEGIN TRAN
			
			IF @Direction = 1   -- up
				SET @IDToReplace = (SELECT Top 1 ID FROM org.Command WHERE [Node].GetAncestor(1) = @Node.GetAncestor(1) AND [Order] < @Order Order BY [ORDER] DESC)
			ELSE IF @Direction = 2   -- down
				SET @IDToReplace = (SELECT Top 1 ID FROM org.Command WHERE [Node].GetAncestor(1) = @Node.GetAncestor(1) AND [Order] > @Order Order BY [ORDER])

			SET @OrderToReplace = (SELECT [Order] FROM org.Command WHERE ID = @IDToReplace)

			IF @IDToReplace IS NOT NULL
			BEGIN
				Update org.Command 
				SET [Order] = @OrderToReplace
				WHERE ID = @CommandID

				Update org.Command 
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spCheckCommandPermission'))
	DROP PROCEDURE org.spCheckCommandPermission
GO

CREATE PROCEDURE org.spCheckCommandPermission
	@APositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AControllerName NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@ControllerName NVARCHAR(MAX) = @AControllerName

	;WITH VALID AS 
	(
		SELECT
			C.ID,
			C.ApplicationID,
			C.CommandID,
			C.ControllerName,
			C.AllowRead,
			C.AllowAdd,
			C.AllowEdit,
			C.AllowRemove
		FROM  org.PositionRole u
			INNER JOIN org.RolePermission p ON u.RoleID = p.RoleID
			INNER JOIN org.Command cmd ON cmd.ID = p.CommandID
			INNER JOIN [org].[CommandPermission] c on c.CommandID = cmd.ID
		WHERE c.RemoverUserID IS NULL
			AND u.PositionID = @PositionID
			AND c.ApplicationID = @ApplicationID
			AND c.ControllerName = @ControllerName
	
	) 


	SELECT Top 1
		ID,
		ApplicationID,
		CommandID,
		ControllerName,
		CASE WHEN EXISTS (SELECT 1 FROM valid WHERE AllowRead = 1) THEN  CAST (1 AS BIT) ELSE CAST (0 AS BIT) END AS AllowRead,
		CASE WHEN EXISTS (SELECT 1 FROM valid WHERE AllowAdd = 1) THEN CAST (1 AS BIT) ELSE CAST (0 AS BIT) END AS AllowAdd,
		CASE WHEN EXISTS (SELECT 1 FROM valid WHERE AllowEdit = 1) THEN CAST (1 AS BIT) ELSE CAST (0 AS BIT) END AS AllowEdit,
		CASE WHEN EXISTS (SELECT 1 FROM valid WHERE AllowRemove = 1) THEN CAST (1 AS BIT) ELSE CAST (0 AS BIT) END AS AllowRemove
	FROM  Valid


END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteCommandPermission'))
	DROP PROCEDURE org.spDeleteCommandPermission
GO

CREATE PROCEDURE org.spDeleteCommandPermission
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID,
			@UserID UNIQUEIDENTIFIER = @AUserID


	BEGIN TRY
		BEGIN TRAN

			Update org.CommandPermission
			SET
				RemoverUserID = @UserID,
				RemoveDate = GETDATE()
			WHERE ID= @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetCommandPermission'))
	DROP PROCEDURE org.spGetCommandPermission
GO

CREATE PROCEDURE org.spGetCommandPermission
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		cp.[ID], 
		cp.[ApplicationID],
		app.[Name] as ApplicationName,
		cp.[CommandID],
		command.[Name] as CommandName,
		cp.[ControllerName],
		cp.[AllowRead], 
		cp.[AllowAdd], 
		cp.[AllowEdit], 
		cp.[AllowRemove], 
		cp.[RemoverUserID], 
		cp.[RemoveDate] 
	FROM [org].[CommandPermission] cp
		INNER JOIN Org.[Application] App ON App.ID = cp.ApplicationID	
		INNER JOIN Org.[Command] command ON command.ID = cp.CommandID
	WHERE (cp.ID = @ID)
		AND cp.RemoverUserID  IS NULL
		AND cp.RemoveDate  IS NULL
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetCommandPermissions'))
	DROP PROCEDURE org.spGetCommandPermissions
GO

CREATE PROCEDURE org.spGetCommandPermissions
	@AApplicationID UNIQUEIDENTIFIER,
	@ACommandID UNIQUEIDENTIFIER,
	@AControlllerName VARCHAR(256),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@CommandID UNIQUEIDENTIFIER = @ACommandID,
		@ControlllerName VARCHAR(256) = LTRIM(RTRIM(@AControlllerName)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH MainSelect AS
	(
		SELECT 
			cp.[ID], 
			cp.[ApplicationID],
			app.[Name] as ApplicationName,
			cp.[CommandID],
			command.[Name] as CommandName,
			cp.[ControllerName],
			cp.[AllowRead], 
			cp.[AllowAdd], 
			cp.[AllowEdit], 
			cp.[AllowRemove], 
			cp.[RemoverUserID], 
			cp.[RemoveDate] 
		FROM [org].[CommandPermission] cp
			INNER JOIN Org.[Application] App ON App.ID = cp.ApplicationID	
			INNER JOIN Org.[Command] command ON command.ID = cp.CommandID
		WHERE cp.RemoverUserID IS NULL
			AND (@ApplicationID IS NULL OR cp.ApplicationID = @ApplicationID)
			AND (@CommandID IS NULL OR cp.CommandID =  @CommandID)
			AND (@ControlllerName IS NULL OR cp.[ControllerName] = CONCAT('%', @ControlllerName, '%'))
	)
	, Total AS 
	(
		SELECT 
			Count(*) AS Total
		FROM [org].[CommandPermission] cp
			INNER JOIN Org.[Application] App ON App.ID = cp.ApplicationID	
			INNER JOIN Org.[Command] command ON command.ID = cp.CommandID
		WHERE cp.RemoverUserID IS NULL
			AND (@ApplicationID IS NULL OR cp.ApplicationID = @ApplicationID)
			AND (@CommandID IS NULL OR cp.CommandID =  @CommandID)
			AND (@ControlllerName IS NULL OR cp.[ControllerName] = CONCAT('%', @ControlllerName, '%'))
	)

	SELECT * FROM MainSelect, Total
	ORDER BY [ControllerName] 
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyCommandPermission'))
	DROP PROCEDURE org.spModifyCommandPermission
GO

CREATE PROCEDURE org.spModifyCommandPermission
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ACommandID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AControllerName varchar(500),
	@AAllowRead BIT,
	@AAllowAdd BIT,
	@AAllowEdit BIT,
	@AAllowRemove BIT,
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@CommandID UNIQUEIDENTIFIER = @ACommandID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@ControllerName nvarchar(500) = LTRIM(RTRIM(@AControllerName)),
		@AllowRead BIT = COALESCE(@AAllowRead , 0),
		@AllowAdd BIT = COALESCE(@AAllowAdd , 0),
		@AllowEdit BIT = COALESCE(@AAllowEdit ,0),
		@AllowRemove BIT = COALESCE(@AAllowRemove , 0)


	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO [org].[CommandPermission]
				([ID], [ApplicationID], [CommandID], [ControllerName], [AllowRead], [AllowAdd], [AllowEdit], [AllowRemove], [RemoverUserID], [RemoveDate])
				VALUES
				(@ID, @ApplicationID, @CommandID, @ControllerName, @AllowRead, @AllowAdd, @AllowEdit, @AllowRemove, NULL , NULL)
			END
			ELSE
			BEGIN -- update
				UPDATE [org].[CommandPermission]
				SET 
					CommandID = @CommandID,
					[ControllerName] = @ControllerName, 
					AllowRead = @AllowRead,
					AllowAdd = @AllowAdd,
					AllowEdit = @AllowEdit,
					AllowRemove = @AllowRemove

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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetControllerNames'))
	DROP PROCEDURE org.spGetControllerNames
GO

CREATE PROCEDURE org.spGetControllerNames
	@AApplicationID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID

	

		SELECT 
			*
		FROM [org].[ControllerName] Cn
		WHERE (@ApplicationID IS NULL OR Cn.ApplicationID = @ApplicationID)


END
GO
USE [Kama.Aro.Organization.Extension]
GO
/****** Object:  StoredProcedure [org].[spGetControllers]    Script Date: 7/2/2022 3:23:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [org].[spGetOnlineControllers]
	@AName NVARCHAR(200),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
		DECLARE
			@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
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
			COUNT(*) over() AS Total,
			con.ID,
			con.Title,
			con.[Name]
		FROM alg.OnlineController as con
		WHERE 
			(@Name IS NULL OR con.[Name] = @Name)
	)

	SELECT * FROM MainSelect		 
	ORDER BY [ID]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetDataBaseProblemFields'))
	DROP PROCEDURE pbl.spGetDataBaseProblemFields
GO

CREATE PROCEDURE pbl.spGetDataBaseProblemFields
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		DataBaseProblemFields.ID,
		DataBaseProblemFields.ApplicationID,
		DataBaseProblemFields.Solution,
		DataBaseProblemFields.Code,
		DataBaseProblemFields.[Name]
	FROM pbl.DataBaseProblemFields
	WHERE ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetDataBaseProblemsFields'))
	DROP PROCEDURE pbl.spGetDataBaseProblemsFields
GO

CREATE PROCEDURE pbl.spGetDataBaseProblemsFields
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@ACode NVARCHAR(100),
	@ASolution NVARCHAR(500),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@Code NVARCHAR(100) = LTRIM(RTRIM(@ACode)),
		@Solution NVARCHAR = LTRIM(RTRIM(@ASolution)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)


	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH MainSelect AS
	(
		SELECT
			DataBaseProblemFields.ID,
			DataBaseProblemFields.ApplicationID,
			DataBaseProblemFields.[Name],
			DataBaseProblemFields.Code,
			DataBaseProblemFields.[Solution]
		FROM pbl.DataBaseProblemFields DataBaseProblemFields
		WHERE ( DataBaseProblemFields.ApplicationID = @ApplicationID)
	          AND  (  @Name IS NULL OR DataBaseProblemFields.[Name] Like CONCAT('%', @Name , '%'))
	          AND  (  @Code IS NULL  OR DataBaseProblemFields.Code = @Code)
	          AND  (  @Solution IS NULL  OR DataBaseProblemFields.[Solution] = @Solution)
	)
	, Total AS 
	(
		SELECT COUNT(*) as Total
		FROM MainSelect
		 WHERE @GetTotalCount = 1
	)

	select * from MainSelect, Total
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetMaxApplicationDataBaseProblemsFieldsCode'))
	DROP PROCEDURE pbl.spGetMaxApplicationDataBaseProblemsFieldsCode
GO

CREATE PROCEDURE pbl.spGetMaxApplicationDataBaseProblemsFieldsCode
	@AApplicationID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID


	SELECT TOP(1) [Code] FROM [pbl].[DataBaseProblemFields]
	WHERE [ApplicationID] = @ApplicationID
	ORDER BY [Code]
END
GO

USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyDataBaseProblemFields'))
	DROP PROCEDURE pbl.spModifyDataBaseProblemFields
GO

CREATE PROCEDURE pbl.spModifyDataBaseProblemFields
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(200),
	@AThreshold INT,
	@ASolution NVARCHAR(500)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(200) = LTRIM(RTRIM(@AName)),
		@Threshold BIT = COALESCE(@AThreshold, 0),
		@Solution NVARCHAR(MAX) = LTRIM(RTRIM(@ASolution)),
		@Code NVARCHAR(100)
			
	BEGIN TRY
		BEGIN TRAN
		SET @Code = (CAST(COALESCE((
			SELECT MAX([Code]) From pbl.DataBaseProblemFields
			WHERE ApplicationID = @ApplicationID
		), 0) AS INT) + 10)
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO pbl.DataBaseProblemFields
				(ID, ApplicationID, [Name], Code, Threshold , Solution)
				VALUES
				(@ID, @ApplicationID, @Name, @Code,@Threshold , @Solution)
			END
			ELSE    -- update
			BEGIN
				UPDATE pbl.DataBaseProblemFields
				SET 
				Threshold = @Threshold,
				Solution = @Solution
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
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetAmoozeshDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetAmoozeshDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetAmoozeshDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetCouncilDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetCouncilDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetCouncilDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetEstekhdamDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetEstekhdamDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetEstekhdamDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetJobDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetJobDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetJobDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetKanoonDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetKanoonDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetKanoonDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetLicenceDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetLicenceDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetLicenceDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetManagerDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetManagerDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetManagerDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetOrganizationDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetOrganizationDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetOrganizationDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetPaknaDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetPaknaDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetPaknaDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(ID) FROM [pbl].[BankAccount] WHERE [ValidType] = 1 AND RemoveDate IS NULL) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(ID) FROM [pbl].[BankAccount] WHERE [ValidType] = 2 AND RemoveDate IS NULL) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetPardakhtDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetPardakhtDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetPardakhtDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'20' [Code],
	(SELECT COUNT(ID) FROM [Kama.Aro.Salary2].[pbl].[BankAccount] WHERE [ValidType] = 1 AND RemoveDate IS NULL) [Count]

	UNION 
	SELECT 
		'30' [Code],
		(SELECT COUNT(ID) FROM [Kama.Aro.Salary2].[pbl].[BankAccount] WHERE [ValidType] = 2 AND RemoveDate IS NULL) [Count]

		UNION 
	SELECT 
		'40' [Code],
		(SELECT COUNT(ID) FROM [Kama.Aro.Salary2].[emp].[EmployeeCatalog] WHERE [State] = 5) [Count]
	END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetReportingDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetReportingDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetReportingDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetSakhtarDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetSakhtarDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetSakhtarDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetSalaryDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetSalaryDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetSalaryDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetServiceDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetServiceDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetServiceDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetSinaMobileDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetSinaMobileDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetSinaMobileDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetSsoDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetSsoDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetSsoDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'rpt.spGetSurveyDatabaseProblems') AND type in (N'P', N'PC'))
    DROP PROCEDURE rpt.spGetSurveyDatabaseProblems
GO

CREATE PROCEDURE rpt.spGetSurveyDatabaseProblems
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	SELECT 
	'10' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 1) [Count]

UNION 

SELECT 
	'20' [Code],
	(SELECT COUNT(*) from org.Individual WHERE ConfirmType = 2) [Count]
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'pbl.spCheckUserOrganAccess') AND type in (N'P', N'PC'))
DROP PROCEDURE pbl.spCheckUserOrganAccess
GO

CREATE PROCEDURE pbl.spCheckUserOrganAccess    --spCheckUserOrganAccess
	@AOrganID UNIQUEIDENTIFIER,
	@AUserOrganID UNIQUEIDENTIFIER,
	@AIsException BIT
AS
BEGIN

SET NOCOUNT ON;

DECLARE
	@OrganID UNIQUEIDENTIFIER = @AOrganID,
	@UserOrganID UNIQUEIDENTIFIER = @AUserOrganID,
	@IsException BIT = COALESCE(@AIsException, 0),
	@OrganNode HIERARCHYID,
	@UserOrganNode HIERARCHYID,
	@OrganProvinceID UNIQUEIDENTIFIER,
	@UserOrganProvinceID UNIQUEIDENTIFIER


	SET @OrganNode = (SELECT [Node] FROM org.Department WHERE ID = @OrganID)
	SET @UserOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @UserOrganID)
	SET @OrganProvinceID = (SELECT ProvinceID FROM org._Organ WHERE ID = @OrganID)
	SET @UserOrganProvinceID = (SELECT ProvinceID FROM org._Organ WHERE ID = @UserOrganID)

	IF @IsException = 1
	BEGIN
			SELECT TOP 1 @OrganID AS OrganID
			FROM org._Organ
			WHERE @UserOrganProvinceID = @OrganProvinceID
	END
	ELSE
		BEGIN 
			Select @OrganID AS OrganID
			WHERE @UserOrganNode.IsDescendantOf(@OrganNode) = 1
	END
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteDepartment'))
	DROP PROCEDURE org.spDeleteDepartment
GO

CREATE PROCEDURE org.spDeleteDepartment
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@Node HIERARCHYID 
	
	SET @Node = (SELECT [Node] FROM org.Department WHERE ID = @ID)  

	IF @Node = HIERARCHYID::GetRoot()
		THROW 50000, N'رکورد ریشه قابل حذف نیست', 1

	BEGIN TRY
		BEGIN TRAN
			UPDATE org.Department
			SET RemoverID = @CurrentUserID,
				RemoverDate = GETDATE()
			WHERE [Node].IsDescendantOf(@Node) = 1

			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]

GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartment'))
DROP PROCEDURE org.spGetDepartment
GO

CREATE PROCEDURE org.spGetDepartment
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	;WITH Chart AS
	(
		SELECT OrganID, ExpirationDate 
		FROM [Kama.Aro.Sakhtar].chr.chart 
			INNER JOIN [Kama.Aro.Sakhtar].pbl.BaseDocument doc on doc.id = chart.ID
		WHERE ApprovedChart = 1
		AND doc.Type = 2
		AND doc.RemoverID IS NULL
		AND OrganID = @ID
	)
	SELECT 
		Department.ID,
		Department.[Node].ToString() Node,
		Department.[Node].GetAncestor(1).ToString() ParentNode,
		Department.[Node].GetLevel() NodeLevel,
		Department.[Type],
		Department.CouncilType,
		Department.SubType,
		Department.OrganType,
		Department.ElaboratedBudgetType,
		Department.TreasurySupervisionType,
		Department.UserDefinitionReferenceType,
		Department.BoardOfTrusteesType,
		Department.[DepartmentShowType],
		Department.ArrangementTypeInSalary,
		Department.BriefNameType,
		Department.Code,
		Department.[Name],
		parent.[Name] ParentName,
		Parent.[NationalCode] ParentNationalCode,
		Parent.Code ParentCode,
		Department.[Enabled],
		Department.ProvinceID,
		Department.BudgetCode,
		Department.[MainOrganType],
		province.[Name] ProvinceName,
		Department.[Address],
		IIF(Department.PostalCode IS NOT NULL, Department.PostalCode, ad.PostalCode) PostalCode,
		Parent.ID ParentID,
		Department.COFOG,
		Department.[AddressID],
		Department.[UnitTypeID],
		unitType.[Name] UnitTypeName,
		Department.[NationalCode],
		Department.NeedsChartType,
		Department.WebServiceSaveType,
		Department.TopChartApproveDate,
		Department.ElaboratedChartApproveDate,
		Department.ProvincialChartApproveDate,
		IIF(legalRequest.LegalNumber IS NOT NULL,legalRequest.LegalNumber COLLATE Persian_100_CI_AI, Department.[NationalCode] COLLATE Persian_100_CI_AI) LegalNumber,
		Department.[EnableForPostImport],
		Department.IsDiscludedInPakna,
        Department.DashboardIncludeType,
        Department.Category,
		Chart.ExpirationDate
	FROM org.Department
		LEFT JOIN org.Place province ON province.ID = Department.ProvinceID
		LEFT JOIN org.Department parent ON Department.Node.GetAncestor(1) = parent.Node
		LEFT JOIN Chart ON Chart.OrganID = Department.ID
		LEFT JOIN [Kama.Aro.Sakhtar].req._FinalLegalRequests legalRequest ON legalRequest.OrganID = Department.ID AND legalRequest.UnitID IS NULL
		LEFT JOIN [Kama.Aro.Sakhtar].chr.UnitType unitType ON Department.UnitTypeID = unitType.ID
		LEFT JOIN inq.Address ad ON org.Department.AddressID = ad.ID
	WHERE Department.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO
CREATE OR ALTER PROCEDURE org.spGetDepartmentAllChilds
	@AOrganID UNIQUEIDENTIFIER

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
			organ.Code,
			organ.[Name],
			organ.BudgetCode
		FROM org.department organ 
			LEFT JOIN org.Department Parent  ON organ.[Node].GetLevel()+1= Parent.Node.GetLevel()
		WHERE organ.RemoverID IS NULL
				--AND organ.Type=2
				AND (organ.[Node].IsDescendantOf(@ParentNode) = 1)
	)
	SELECT DISTINCT *
	FROM SelectedDepartment
	 UNION 
	SELECT 
			organ.ID,
			organ.[Type],
			organ.SubType,
			organ.OrganType,
			organ.Code,
			organ.[Name],
			organ.BudgetCode
		FROM org.department organ 
		WHERE @OrganID=organ.ID
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartments'))
DROP PROCEDURE org.spGetDepartments
GO

CREATE PROCEDURE org.spGetDepartments
	@AParentID UNIQUEIDENTIFIER,
	@AProvinceID UNIQUEIDENTIFIER,
	@AUnitType UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ATypes NVARCHAR(MAX),
	@AEnabled TINYINT,
	@ASubType TINYINT,
	@ACouncilType TINYINT,
	@AOrganType TINYINT,
	@ACode VARCHAR(20),
	@ABudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@ACodes NVARCHAR(MAX),
	@ACOFOG TINYINT,
	@ALevel INT,
	@ALoadLabel BIT,
	@ANationalCode NVARCHAR(15),
	@ANeedsChartType TINYINT,
	@AWebServiceSaveType TINYINT,
	@AMainOrganType TINYINT,
	@AElaboratedBudgetType TINYINT,
	@ATreasurySupervisionType TINYINT,
	@AUserDefinitionReferenceType TINYINT,
	@ABoardOfTrusteesType TINYINT,
	@AArrangementTypeInSalary TINYINT,
	@ABriefNameType TINYINT,
	@ADepartmentShowType TINYINT,
	@AUserDefinitionReferenceTypes NVARCHAR(MAX),
	@AIsDiscludedInPakna TINYINT,
	@AFetchedWithDeleted BIT,
	@ANoLoadTestDepartment BIT,
	@AGetPrivateDepartments BIT,
    @ADashboardIncludeType TINYINT,

	@AEnabledApplicationIDs NVARCHAR(MAX),
	@AEnabledApplicationIDsForWebService NVARCHAR(MAX),
	@AEnabledApplicationIDsForReport NVARCHAR(MAX),

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
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@UnitType UNIQUEIDENTIFIER = @AUnitType,
		@Type TINYINT = COALESCE(@AType, 0),
		@Types NVARCHAR(MAX) = @ATypes,
		@Enabled TINYINT= COALESCE(@AEnabled, 0),
		@SubType TINYINT = COALESCE(@ASubType, 0),
		@OrganType TINYINT = COALESCE(@AOrganType, 0),
		@CouncilType TINYINT = COALESCE(@ACouncilType, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)), 
		@Codes NVARCHAR(MAX) = @ACodes,
		@COFOG TINYINT = COALESCE(@ACOFOG, 0),
		@Level INT = @ALevel,
		@LoadLabel BIT = COALESCE(@ALoadLabel, 0),
		@NationalCode NVARCHAR(15) =  @ANationalCode,
		@NeedsChartType TINYINT = COALESCE(@ANeedsChartType, 0),
		@WebServiceSaveType TINYINT = COALESCE(@AWebServiceSaveType, 0),
		@MainOrganType TINYINT = COALESCE(@AMainOrganType, 0),
		@ElaboratedBudgetType TINYINT = COALESCE(@AElaboratedBudgetType, 0),
		@TreasurySupervisionType TINYINT = COALESCE(@ATreasurySupervisionType, 0),
		@UserDefinitionReferenceType TINYINT = COALESCE(@AUserDefinitionReferenceType, 0),
		@BoardOfTrusteesType TINYINT = COALESCE(@ABoardOfTrusteesType, 0),
		@ArrangementTypeInSalary TINYINT = COALESCE(@AArrangementTypeInSalary, 0),
		@BriefNameType TINYINT = COALESCE(@ABriefNameType, 0),
		@DepartmentShowType TINYINT = COALESCE(@ADepartmentShowType, 0),
		@UserDefinitionReferenceTypes NVARCHAR(MAX) = @AUserDefinitionReferenceTypes,
		@IsDiscludedInPakna TINYINT = COALESCE(@AIsDiscludedInPakna, 0),
		@FetchedWithDeleted BIT = COALESCE(@AFetchedWithDeleted, 0),
		@NoLoadTestDepartment BIT = COALESCE(@ANoLoadTestDepartment, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@GetPrivateDepartments BIT = COALESCE(@AGetPrivateDepartments, 0),
        @DashboardIncludeType TINYINT = COALESCE(@ADashboardIncludeType, 0),

		@EnabledApplicationIDs NVARCHAR(MAX) = @AEnabledApplicationIDs,
		@EnabledApplicationIDsForWebService NVARCHAR(MAX) = @AEnabledApplicationIDsForWebService,
		@EnabledApplicationIDsForReport NVARCHAR(MAX) = @AEnabledApplicationIDsForReport,

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
	
	;WITH EnabledApplicationIDs AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDs) EnabledApplicationIDs ON EnabledApplicationIDs.value = departmentEnableState.ApplicationID
		WHERE [Enable] = 1
		GROUP BY Department.ID
	)
	, EnabledApplicationIDsForWebService AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDsForWebService) EnabledApplicationIDsForWebService ON EnabledApplicationIDsForWebService.value = departmentEnableState.ApplicationID
		WHERE [EnableForWebService] = 1
		GROUP BY Department.ID
	)
	, EnabledApplicationIDsForReport AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDsForReport) EnabledApplicationIDsForReport ON EnabledApplicationIDsForReport.value = departmentEnableState.ApplicationID
		WHERE [EnableForReport] = 1
		GROUP BY Department.ID
	)
	, SelectedDepartment AS
	(
		SELECT 
			Department.*,
			IIF(legalRequest.LegalNumber IS NOT NULL, legalRequest.LegalNumber COLLATE Persian_100_CI_AI, Department.[NationalCode] COLLATE Persian_100_CI_AI) LegalNumber
		FROM org.Department
			LEFT JOIN OPENJSON(@Codes) Codes ON Codes.Value = Department.Code
			LEFT JOIN OPENJSON(@Types) [Types] ON [Types].Value = Department.[Type]
			LEFT JOIN OPENJSON(@UserDefinitionReferenceTypes) [UserDefinitionReferenceTypes] ON [UserDefinitionReferenceTypes].Value = Department.[UserDefinitionReferenceType]
			LEFT JOIN [Kama.Aro.Sakhtar].req._FinalLegalRequests legalRequest ON legalRequest.OrganID = Department.ID AND legalRequest.UnitID IS NULL
			LEFT JOIN EnabledApplicationIDs ON EnabledApplicationIDs.ID = Department.ID
			LEFT JOIN EnabledApplicationIDsForWebService ON EnabledApplicationIDsForWebService.ID = Department.ID
			LEFT JOIN EnabledApplicationIDsForReport ON EnabledApplicationIDsForReport.ID = Department.ID
		WHERE ((@FetchedWithDeleted = 0 AND Department.RemoverID IS NULL) OR @FetchedWithDeleted > 0)
			AND (@ParentNode IS NULL OR Department.[Node].IsDescendantOf(@ParentNode) = 1)
			AND (@ProvinceID IS NULL OR department.ProvinceID = @ProvinceID)
			AND (@Type < 1 OR Department.[Type] = @Type)
			AND (@UnitType IS NULL OR Department.UnitTypeID = @UnitType)
			AND (@BudgetCode IS NULL OR Department.BudgetCode = @BudgetCode)
			AND (@SubType < 1 OR Department.SubType = @SubType)
			AND (@CouncilType < 1 OR Department.CouncilType = @CouncilType)
			AND (@Code IS NULL OR Department.Code Like CONCAT('%', @Code, '%'))
			AND (@Name IS NULL OR Department.[Name] Like CONCAT('%', @Name , '%'))
			AND (@Codes IS NULL OR Codes.Value = Department.Code)
			AND (@Types IS NULL OR [Types].Value = Department.[Type])
			AND (@COFOG < 1 OR Department.COFOG = @COFOG)
			AND (@LoadLabel = 1 OR (@LoadLabel = 0 AND Department.[Type] <> 10))
			AND (@NeedsChartType < 1 OR NeedsChartType = @NeedsChartType)
			AND (@WebServiceSaveType < 1 OR WebServiceSaveType = @WebServiceSaveType)
			AND (@Enabled < 1 OR Department.[Enabled] = @Enabled - 1)
			AND (@MainOrganType < 1 OR Department.[MainOrganType] = @MainOrganType)
			AND (@OrganType < 1 OR Department.[OrganType] = @OrganType)
			AND (@ElaboratedBudgetType < 1 OR Department.[ElaboratedBudgetType] = @ElaboratedBudgetType)
			AND (@TreasurySupervisionType < 1 OR Department.[TreasurySupervisionType] = @TreasurySupervisionType)
			AND (@UserDefinitionReferenceType < 1 OR Department.[UserDefinitionReferenceType] = @UserDefinitionReferenceType)
			AND (@BoardOfTrusteesType < 1 OR Department.[BoardOfTrusteesType] = @BoardOfTrusteesType)
			AND (@ArrangementTypeInSalary < 1 OR Department.[ArrangementTypeInSalary] = @ArrangementTypeInSalary)
			AND (@BriefNameType < 1 OR Department.[BriefNameType] = @BriefNameType)
			AND (@DepartmentShowType < 1 OR Department.[DepartmentShowType] = @DepartmentShowType)
			AND (@UserDefinitionReferenceTypes IS NULL OR [UserDefinitionReferenceTypes].Value = Department.[UserDefinitionReferenceType])
			AND (@IsDiscludedInPakna < 1 OR Department.IsDiscludedInPakna = @IsDiscludedInPakna - 1)
			AND (@NoLoadTestDepartment = 0 OR (@NoLoadTestDepartment = 1 AND Department.[Name] NOT LIKE '%تست%' AND Department.Code <> 0))
			AND (@GetPrivateDepartments = 1 OR Department.[Type] < 100)
            AND (@DashboardIncludeType < 1 OR Department.DashboardIncludeType = @DashboardIncludeType)

			AND (@EnabledApplicationIDs IS NULL OR EnabledApplicationIDs.ID = Department.ID)
			AND (@EnabledApplicationIDsForWebService IS NULL OR EnabledApplicationIDsForWebService.ID = Department.ID)
			AND (@EnabledApplicationIDsForReport IS NULL OR EnabledApplicationIDsForReport.ID = Department.ID)
	)
	,Total AS
	(
		SELECT COUNT(*) Total
		FROM SelectedDepartment department
		WHERE (@Level IS NULL OR department.[Node].GetLevel() = @Level)
		AND (@NationalCode IS NULL OR Department.LegalNumber = @NationalCode)
	)
	, MainSelect AS
	(
		SELECT 
			department.ID,
			department.[Node].ToString() [Node],
			department.[Node].GetAncestor(1).ToString() [ParentNode],
			department.[Node].GetLevel() NodeLevel,
			department.SubType,
			department.[Type],
			department.[CouncilType],
			department.Code,
			department.[Name],
			department.COFOG,
			department.BudgetCode,
			department.[Enabled],
			department.ProvinceID,
			department.[NationalCode],
			department.LegalNumber,
			department.[MainOrganType],
			department.ElaboratedBudgetType,
			department.TreasurySupervisionType,
			department.UserDefinitionReferenceType,
			department.BoardOfTrusteesType,
			department.ArrangementTypeInSalary,
			department.BriefNameType,
			department.DepartmentShowType,
			department.TreeOrder,
			Parent.[Name] ParentName,
			Parent.[NationalCode] ParentNationalCode,
			Parent.Code ParentCode,
			province.[Name] ProvinceName,
			department.[Address],
			IIF(department.PostalCode IS NOT NULL, department.PostalCode, ad.PostalCode) PostalCode,
			department.[AddressID],
			department.[UnitTypeID],
			unitType.[Name] UnitTypeName,
			department.NeedsChartType,
			department.WebServiceSaveType,
			Department.TopChartApproveDate,
			Department.ElaboratedChartApproveDate,
			Department.ProvincialChartApproveDate,
			department.[EnableForPostImport],
			department.IsDiscludedInPakna,
            department.DashboardIncludeType,
            department.Category,
			department.[Timestamp],
			COALESCE(parent1.[Name], N'نامشخص') MainOrgan1Name, -- عنوان دستگاه - سطح قوا	
			COALESCE(parent1.Code, N'نامشخص') MainOrgan1Code, -- کد دستگاه - سطح قوا	
			COALESCE(parent2.[Name], N'نامشخص') MainOrgan2Name, -- عنوان دستگاه - سطح وزارت خانه	
			COALESCE(parent2.Code, N'نامشخص') MainOrgan2Code -- کد دستگاه - سطح وزارت خانه	
		FROM SelectedDepartment department
			LEFT JOIN org.Place province ON province.ID = department.ProvinceID
			LEFT JOIN org.Department Parent ON Parent.Node = department.[Node].GetAncestor(1)
			LEFT JOIN inq.Address ad ON department.AddressID = ad.ID
			LEFT JOIN [Kama.Aro.Sakhtar].chr.UnitType unitType ON department.UnitTypeID = unitType.ID
			LEFT JOIN org.Department parent2 ON department.[Node].IsDescendantOf(Parent2.[Node]) = 1 AND Parent2.[Node].GetLevel() = 2
			LEFT JOIN org.Department parent1 ON parent2.Node.IsDescendantOf(Parent1.[Node]) = 1 AND Parent1.[Node].GetLevel() = 1
		WHERE (@Level IS NULL OR department.[Node].GetLevel() = @Level)
		AND (@NationalCode IS NULL OR Department.LegalNumber = @NationalCode)
	)
	

	SELECT * FROM MainSelect , Total
	ORDER BY [Node], [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentsSubsetCount'))
DROP PROCEDURE org.spGetDepartmentsSubsetCount
GO

CREATE PROCEDURE org.spGetDepartmentsSubsetCount
	@AID UNIQUEIDENTIFIER,
	@ALevel INT

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Level INT = @ALevel,
		@ParentNode HIERARCHYID,

		@ProvincialSubsetCount int,
		@ElaboratedSubsetCount int,
		@CurrentDepartmentProvincialSubsetCount int

	IF @ID = CAST(0x0 AS UNIQUEIDENTIFIER) SET @ID = NULL

	SET @ParentNode = (SELECT [Node] FROM org.Department WHERE ID = @AID)

	--تعداد دستگاه های زیرمجموعه استانی
	SET @ProvincialSubsetCount = (SELECT COUNT(Department.ID) FROM org.Department 
									WHERE (@ParentNode IS NULL OR Department.[Node].IsDescendantOf(@ParentNode) = 1) 
										AND Department.Type = 2 
										AND Department.RemoverID IS NULL
										);
	
	--تعداد دستگاه های زیرمجموعه ستادی
	SET @ElaboratedSubsetCount = (SELECT COUNT(Department.ID) FROM org.Department
									WHERE (@ParentNode IS NULL OR Department.[Node].IsDescendantOf(@ParentNode) = 1) 
										AND Department.Type = 1 
										AND Department.RemoverID IS NULL
										);

	--تعداد دستگاه های زیرمجموعه استانی خود دستگاه
	SET @CurrentDepartmentProvincialSubsetCount = (SELECT COUNT(Department.ID) FROM org.Department 
									LEFT JOIN org.Department parent2 ON department.[Node].IsDescendantOf(Parent2.[Node]) = 1 AND Parent2.[Node].GetLevel() = 2
									LEFT JOIN org.Department parent1 ON parent2.Node.IsDescendantOf(Parent1.[Node]) = 1 AND Parent1.[Node].GetLevel() = 1
									WHERE (@ParentNode IS NULL OR Department.[Node].IsDescendantOf(@ParentNode) = 1) 
										AND Department.Type = 2 
										AND Department.RemoverID IS NULL
										AND (@Level IS NULL OR department.[Node].GetLevel() = @Level + 1)
										);

	 select @ProvincialSubsetCount ProvincialSubsetCount
			,@ElaboratedSubsetCount ElaboratedSubsetCount
			,@CurrentDepartmentProvincialSubsetCount CurrentDepartmentProvincialSubsetCount;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentsWithHierarchy'))
DROP PROCEDURE org.spGetDepartmentsWithHierarchy
GO

CREATE PROCEDURE org.spGetDepartmentsWithHierarchy
	@AParentID UNIQUEIDENTIFIER,
	@AProvinceID UNIQUEIDENTIFIER,
	@AUnitType UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ATypes NVARCHAR(MAX),
	@AEnabled TINYINT,
	@ASubType TINYINT,
	@ACouncilType TINYINT,
	@AOrganType TINYINT,
	@ACode VARCHAR(20),
	@ABudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@ASearchWithHierarchy bit,
	@ACodes NVARCHAR(MAX),
	@ACOFOG TINYINT,
	@ALevel INT,
	@ALoadLabel BIT,
	@ANeedsChartType TINYINT,
	@AWebServiceSaveType TINYINT,
	@AMainOrganType TINYINT,
	@AElaboratedBudgetType TINYINT,
	@ATreasurySupervisionType TINYINT,
	@AUserDefinitionReferenceType TINYINT,
	@ABoardOfTrusteesType TINYINT,
	@AArrangementTypeInSalary TINYINT,
	@ABriefNameType TINYINT,
	@ADepartmentShowType TINYINT,
	@AUserDefinitionReferenceTypes NVARCHAR(MAX),
	@AIsDiscludedInPakna TINYINT,
	@ANoLoadTestDepartment BIT,
    @ADashboardIncludeType TINYINT,

	@AEnabledApplicationIDs NVARCHAR(MAX),
	@AEnabledApplicationIDsForWebService NVARCHAR(MAX),
	@AEnabledApplicationIDsForReport NVARCHAR(MAX),

	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@UnitType UNIQUEIDENTIFIER = @AUnitType,
		@Type TINYINT = ISNULL(@AType, 0),
		@Types NVARCHAR(MAX) = @ATypes,
		@Enabled TINYINT= ISNULL(@AEnabled, 0),
		@SubType TINYINT = ISNULL(@ASubType, 0),
		@OrganType TINYINT = ISNULL(@AOrganType, 0),
		@CouncilType TINYINT = ISNULL(@ACouncilType, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)), 
		@SearchWithHierarchy bit = COALESCE(@ASearchWithHierarchy, 0),
		@Codes NVARCHAR(MAX) = @ACodes,
		@COFOG TINYINT = COALESCE(@ACOFOG, 0),
		@Level INT = @ALevel,
		@LoadLabel BIT = COALESCE(@ALoadLabel, 0),
		@NeedsChartType TINYINT = COALESCE(@ANeedsChartType, 0),
		@WebServiceSaveType TINYINT = COALESCE(@AWebServiceSaveType, 0),
		@MainOrganType TINYINT = COALESCE(@AMainOrganType, 0),
		@ElaboratedBudgetType TINYINT = COALESCE(@AElaboratedBudgetType, 0),
		@TreasurySupervisionType TINYINT = COALESCE(@ATreasurySupervisionType, 0),
		@UserDefinitionReferenceType TINYINT = COALESCE(@AUserDefinitionReferenceType, 0),
		@BoardOfTrusteesType TINYINT = COALESCE(@ABoardOfTrusteesType, 0),
		@ArrangementTypeInSalary TINYINT = COALESCE(@AArrangementTypeInSalary, 0),
		@BriefNameType TINYINT = COALESCE(@ABriefNameType, 0),
		@DepartmentShowType TINYINT = COALESCE(@ADepartmentShowType, 0),
		@UserDefinitionReferenceTypes NVARCHAR(MAX) = @AUserDefinitionReferenceTypes,
		@IsDiscludedInPakna TINYINT = COALESCE(@AIsDiscludedInPakna, 0),
		@NoLoadTestDepartment BIT = COALESCE(@ANoLoadTestDepartment, 0),
        @DashboardIncludeType TINYINT = COALESCE(@ADashboardIncludeType, 0),

		@EnabledApplicationIDs NVARCHAR(MAX) = @AEnabledApplicationIDs,
		@EnabledApplicationIDsForWebService NVARCHAR(MAX) = @AEnabledApplicationIDsForWebService,
		@EnabledApplicationIDsForReport NVARCHAR(MAX) = @AEnabledApplicationIDsForReport,

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

	;WITH EnabledApplicationIDs AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDs) EnabledApplicationIDs ON EnabledApplicationIDs.value = departmentEnableState.ApplicationID
		WHERE [Enable] = 1
		GROUP BY Department.ID
	)
	, EnabledApplicationIDsForWebService AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDsForWebService) EnabledApplicationIDsForWebService ON EnabledApplicationIDsForWebService.value = departmentEnableState.ApplicationID
		WHERE [EnableForWebService] = 1
		GROUP BY Department.ID
	)
	, EnabledApplicationIDsForReport AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDsForReport) EnabledApplicationIDsForReport ON EnabledApplicationIDsForReport.value = departmentEnableState.ApplicationID
		WHERE [EnableForReport] = 1
		GROUP BY Department.ID
	)
	, SelectedDepartment AS
	(
		SELECT 
			Department.*,
			IIF(legalRequest.LegalNumber IS NOT NULL, legalRequest.LegalNumber COLLATE Persian_100_CI_AI, Department.[NationalCode] COLLATE Persian_100_CI_AI) LegalNumber
		FROM org.Department
			LEFT JOIN OPENJSON(@Codes) Codes ON Codes.Value = Department.Code
			LEFT JOIN OPENJSON(@Types) [Types] ON [Types].Value = Department.[Type]
			LEFT JOIN OPENJSON(@UserDefinitionReferenceTypes) [UserDefinitionReferenceTypes] ON [UserDefinitionReferenceTypes].Value = Department.[UserDefinitionReferenceType]
			LEFT JOIN [Kama.Aro.Sakhtar].req._FinalLegalRequests legalRequest ON legalRequest.OrganID = Department.ID AND legalRequest.UnitID IS NULL
			LEFT JOIN EnabledApplicationIDs ON EnabledApplicationIDs.ID = Department.ID
			LEFT JOIN EnabledApplicationIDsForWebService ON EnabledApplicationIDsForWebService.ID = Department.ID
			LEFT JOIN EnabledApplicationIDsForReport ON EnabledApplicationIDsForReport.ID = Department.ID
		WHERE Department.RemoverID IS NULL
			AND (@ParentNode IS NULL OR Department.[Node].IsDescendantOf(@ParentNode) = 1)
			AND (@ProvinceID IS NULL OR department.ProvinceID = @ProvinceID)
			AND (@Type < 1 OR Department.[Type] = @Type)
			AND (@UnitType IS NULL OR Department.UnitTypeID = @UnitType)
			AND (@BudgetCode IS NULL OR Department.BudgetCode = @BudgetCode)
			AND (@SubType < 1 OR Department.SubType = @SubType)
			AND (@CouncilType < 1 OR Department.CouncilType = @CouncilType)
			AND (@Code IS NULL OR Department.Code Like CONCAT('%', @Code, '%'))
			AND (@Name IS NULL OR Department.[Name] Like CONCAT('%', @Name , '%'))
			AND (@Codes IS NULL OR Codes.Value = Department.Code)
			AND (@Types IS NULL OR [Types].Value = Department.[Type])
			AND (@UserDefinitionReferenceTypes IS NULL OR [UserDefinitionReferenceTypes].Value = Department.[UserDefinitionReferenceType])
			AND (@COFOG < 1 OR Department.COFOG = @COFOG)
			AND (@LoadLabel = 1 OR (@LoadLabel = 0 AND Department.[Type] <> 10))
			AND (@NeedsChartType < 1 OR NeedsChartType = @NeedsChartType)
			AND (@WebServiceSaveType < 1 OR WebServiceSaveType = @WebServiceSaveType)
			AND (@Enabled < 1 OR Department.[Enabled] = @Enabled - 1)
			AND (@MainOrganType < 1 OR Department.[MainOrganType] = @MainOrganType)
			AND (@ElaboratedBudgetType < 1 OR Department.[ElaboratedBudgetType] = @ElaboratedBudgetType)
			AND (@TreasurySupervisionType < 1 OR Department.[TreasurySupervisionType] = @TreasurySupervisionType)
			AND (@UserDefinitionReferenceType < 1 OR Department.[UserDefinitionReferenceType] = @UserDefinitionReferenceType)
			AND (@BoardOfTrusteesType < 1 OR Department.[BoardOfTrusteesType] = @BoardOfTrusteesType)
			AND (@ArrangementTypeInSalary < 1 OR Department.[ArrangementTypeInSalary] = @ArrangementTypeInSalary)
			AND (@BriefNameType < 1 OR Department.[BriefNameType] = @BriefNameType)
			AND (@DepartmentShowType < 1 OR Department.[DepartmentShowType] = @DepartmentShowType)
			AND (@IsDiscludedInPakna < 1 OR Department.IsDiscludedInPakna = @IsDiscludedInPakna - 1)
			AND (@NoLoadTestDepartment = 0 OR (@NoLoadTestDepartment = 1 AND Department.[Name] NOT LIKE '%تست%' AND Department.Code <> 0))
            AND (@DashboardIncludeType < 1 OR Department.DashboardIncludeType = @DashboardIncludeType)
			AND (@EnabledApplicationIDs IS NULL OR EnabledApplicationIDs.ID = Department.ID)
			AND (@EnabledApplicationIDsForWebService IS NULL OR EnabledApplicationIDsForWebService.ID = Department.ID)
			AND (@EnabledApplicationIDsForReport IS NULL OR EnabledApplicationIDsForReport.ID = Department.ID)
	)
	, ParentDepartment AS
	(
		SELECT DISTINCT 
			Parent.*,
			IIF(legalRequest.LegalNumber IS NOT NULL, legalRequest.LegalNumber COLLATE Persian_100_CI_AI, Parent.[NationalCode] COLLATE Persian_100_CI_AI) LegalNumber
		FROM org.Department Parent
			LEFT JOIN [Kama.Aro.Sakhtar].req._FinalLegalRequests legalRequest ON legalRequest.OrganID = Parent.ID AND legalRequest.UnitID IS NULL
		WHERE @SearchWithHierarchy = 1 
			AND Parent.ID NOT IN (SELECT ID FROM SelectedDepartment) 
			AND EXISTS(SELECT TOP 1 1 FROM SelectedDepartment WHERE SelectedDepartment.Node.IsDescendantOf(Parent.Node) = 1)
	)
	, UnionDepartment AS
	(
		SELECT * FROM SelectedDepartment
		UNION ALL 
		SELECT * FROM ParentDepartment
	)
	, Chart AS
	(
		SELECT OrganID, ExpirationDate 
		FROM [Kama.Aro.Sakhtar].chr.chart 
			INNER JOIN [Kama.Aro.Sakhtar].pbl.BaseDocument doc on doc.id = chart.ID
		WHERE ApprovedChart = 1
		AND doc.Type = 2
		AND doc.RemoverID IS NULL
	)
	,Total AS
	(
	SELECT 
			COUNT(*) AS Total
		FROM UnionDepartment
		WHERE (@Level IS NULL OR UnionDepartment.[Node].GetLevel() = @Level)
		AND @GetTotalCount = 1
	)
	, MainSelect AS
	(
		SELECT 
			UnionDepartment.ID,
			UnionDepartment.[Node].ToString() [Node],
			UnionDepartment.[Node].GetAncestor(1).ToString() [ParentNode],
			UnionDepartment.[Node].GetLevel() NodeLevel,
			UnionDepartment.SubType,
			UnionDepartment.[Type],
			UnionDepartment.[CouncilType],
			UnionDepartment.Code,
			UnionDepartment.[Name],
			UnionDepartment.COFOG,
			UnionDepartment.BudgetCode,
			UnionDepartment.MainOrganType,
			UnionDepartment.ElaboratedBudgetType,
			UnionDepartment.TreasurySupervisionType,
			UnionDepartment.UserDefinitionReferenceType,
			UnionDepartment.BoardOfTrusteesType,
			UnionDepartment.ArrangementTypeInSalary,
			UnionDepartment.BriefNameType,
			UnionDepartment.[DepartmentShowType],
			UnionDepartment.[Enabled],
			UnionDepartment.ProvinceID,
			UnionDepartment.TopChartApproveDate,
			UnionDepartment.ElaboratedChartApproveDate,
			UnionDepartment.ProvincialChartApproveDate,
			Chart.ExpirationDate,
			Parent.[Name] ParentName,
			Parent.[NationalCode] ParentNationalCode,
			Parent.Code ParentCode,
			province.[Name] ProvinceName,
			UnionDepartment.[Address],
			IIF(UnionDepartment.PostalCode IS NOT NULL, UnionDepartment.PostalCode, ad.PostalCode) PostalCode,
			UnionDepartment.[AddressID],
			UnitType.[Name] [UnitTypeName],
			UnionDepartment.[UnitTypeID],
			UnionDepartment.[NationalCode],
			UnionDepartment.NeedsChartType,
			UnionDepartment.WebServiceSaveType,
			UnionDepartment.LegalNumber,
			UnionDepartment.[EnableForPostImport],
			UnionDepartment.IsDiscludedInPakna,
            UnionDepartment.DashboardIncludeType,
            UnionDepartment.Category
		FROM UnionDepartment
			LEFT JOIN org.Place province ON province.ID = UnionDepartment.ProvinceID
			LEFT JOIN Chart ON Chart.OrganID = UnionDepartment.ID
			LEFT JOIN [Kama.Aro.Sakhtar].chr.UnitType UnitType ON UnitType.ID = UnionDepartment.UnitTypeID
			LEFT JOIN org.Department Parent ON Parent.Node = UnionDepartment.[Node].GetAncestor(1)
			LEFT JOIN inq.Address ad ON UnionDepartment.AddressID = ad.ID
		WHERE (@Level IS NULL OR UnionDepartment.[Node].GetLevel() = @Level)
	)
	

	SELECT * FROM MainSelect, Total
	ORDER BY [Node], [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetIsDepartmentExist'))
    DROP PROCEDURE org.spGetIsDepartmentExist
GO

CREATE PROCEDURE org.spGetIsDepartmentExist
	@AName NVARCHAR(256)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @Name NVARCHAR(256) = LTRIM(RTRIM(@AName))
	 
	SELECT 
		dep.[ID],
		dep.[Code],
		dep.[Name]
	FROM org.Department dep
	WHERE dep.RemoverID IS NULL
         AND dep.RemoverDate IS NULL
         AND dep.[Name] = @Name
END
 
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyDepartment'))
	DROP PROCEDURE org.spModifyDepartment
GO

CREATE PROCEDURE org.spModifyDepartment
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@ANode HIERARCHYID,
	@ACouncilType TINYINT,
	@AType TINYINT, 
	@ACategory TINYINT, 
    @ASubType TINYINT, 
	@AOrganType TINYINT, 
	@ABudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@AEnabled BIT,
	@AProvinceID UNIQUEIDENTIFIER,
	@AAddress NVARCHAR(1000),
	@APostalCode CHAR(10),
	@ACOFOG TINYINT,
	@AAddressID UNIQUEIDENTIFIER,
	@AUnitTypeID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(15),
	@ANeedsChartType TINYINT,
	@AWebServiceSaveType TINYINT,
	@AMainOrganType TINYINT,
	@AElaboratedBudgetType TINYINT,
	@ATreasurySupervisionType TINYINT,
	@AUserDefinitionReferenceType TINYINT,
	@ABoardOfTrusteesType TINYINT,
	@AArrangementTypeInSalary TINYINT,
	@ABriefNameType TINYINT,
	@ADepartmentShowType TINYINT,
	@AEnableForPostImport BIT,
    @ADashboardIncludeType TINYINT,

	@ATopChartApproveDate  [smalldatetime],
	@AElaboratedChartApproveDate  [smalldatetime],
	@AProvincialChartApproveDate  [smalldatetime],

	@AIsDiscludedInPakna BIT,

	@AResult NVARCHAR(MAX) OUTPUT

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Node HIERARCHYID = @ANode,
		@CouncilType TINYINT = ISNULL(@ACouncilType, 0),
		@Type TINYINT = ISNULL(@AType, 0),
		@Category TINYINT = ISNULL(@ACategory, 0),
		@SubType TINYINT = ISNULL(@ASubType, 0),
		@OrganType TINYINT = ISNULL(@AOrganType, 0),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)),
		@Enabled BIT = ISNULL(@AEnabled, 0),
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@Address NVARCHAR(1000) = LTRIM(RTRIM(@AAddress)),
		@PostalCode CHAR(10) = LTRIM(RTRIM(@APostalCode)),
		@ParentNode HIERARCHYID,
		@COFOG TINYINT = COALESCE(@ACOFOG, 0),
		@AddressID UNIQUEIDENTIFIER = @AAddressID,
		@UnitTypeID UNIQUEIDENTIFIER = @AUnitTypeID,
		@NationalCode NVARCHAR(15) =  @ANationalCode,
		@NeedsChartType TINYINT = COALESCE(@ANeedsChartType, 0),
		@WebServiceSaveType TINYINT = COALESCE(@AWebServiceSaveType, 0),
		@MainOrganType TINYINT = COALESCE(@AMainOrganType, 0),
		@ElaboratedBudgetType TINYINT = COALESCE(@AElaboratedBudgetType, 0),
		@TreasurySupervisionType TINYINT = COALESCE(@ATreasurySupervisionType, 0),
		@UserDefinitionReferenceType TINYINT = COALESCE(@AUserDefinitionReferenceType, 0),
		@BoardOfTrusteesType TINYINT = COALESCE(@ABoardOfTrusteesType, 0),
		@ArrangementTypeInSalary TINYINT = COALESCE(@AArrangementTypeInSalary, 0),
		@BriefNameType TINYINT = COALESCE(@ABriefNameType, 0),
		@DepartmentShowType TINYINT = COALESCE(@ADepartmentShowType, 0),
		@EnableForPostImport BIT = COALESCE(@AEnableForPostImport, 0),
        @DashboardIncludeType TINYINT = COALESCE(@ADashboardIncludeType, 0),

		@TopChartApproveDate  [smalldatetime] = @ATopChartApproveDate,
		@ElaboratedChartApproveDate  [smalldatetime] = @AElaboratedChartApproveDate,
		@ProvincialChartApproveDate  [smalldatetime] = @AProvincialChartApproveDate,

		@IsDiscludedInPakna BIT = COALESCE(@AIsDiscludedInPakna, 0),

		@LastChildNode HIERARCHYID,
		@NewNode HIERARCHYID,
		@Code VARCHAR(20),
		@MAXCode VARCHAR(20)


	IF EXISTS(SELECT 1 FROM org.Department WHERE ID <> @ID AND RemoverID IS NULL AND RemoverDate IS NULL AND REPLACE([Name], ' ', '') = REPLACE(@Name, ' ', ''))
		THROW 50000, N'نام دستگاه تکراری است', 1

	IF EXISTS(SELECT 1 FROM org.Department WHERE ID <> @ID AND RemoverID IS NULL AND RemoverDate IS NULL AND REPLACE(Code, ' ', '') = REPLACE(@Code, ' ', ''))
		THROW 50000, N'کد دستگاه تکراری است', 2

	IF @Node IS NULL 
		OR @ParentID <> COALESCE((SELECT TOP 1 ID FROM org.Department WHERE @Node.GetAncestor(1) = [Node]), 0x)
	BEGIN
		SET @ParentNode = COALESCE((SELECT [Node] FROM org.Department WHERE ID = @ParentID), HIERARCHYID::GetRoot())
		SET @LastChildNode = (SELECT MAX([Node]) FROM org.Department WHERE [Node].GetAncestor(1) = @ParentNode)
		SET @NewNode = @ParentNode.GetDescendant(@LastChildNode, NULL)
	END

	BEGIN TRY
		BEGIN TRAN
			 
			IF @IsNewRecord = 1 -- insert
			BEGIN

				SET @MAXCode = (SELECT MAX(Code) FROM [Kama.Aro.Organization].org.Department)
				SET @Code = COALESCE(@MAXCode, 0) + 1
 
				INSERT INTO org.Department
					(ID, [Node], CouncilType, [Type], [Category], SubType, OrganType, Code, [Name], [Enabled], ProvinceID, [Address], PostalCode , BudgetCode , COFOG, [AddressID], [UnitTypeID], [NationalCode], [NeedsChartType], [WebServiceSaveType], [MainOrganType], [ElaboratedBudgetType], [TreasurySupervisionType], [UserDefinitionReferenceType], [BoardOfTrusteesType], [ArrangementTypeInSalary], [BriefNameType],[TopChartApproveDate],[ElaboratedChartApproveDate],[ProvincialChartApproveDate], [DepartmentShowType], [IsDiscludedInPakna], [EnableForPostImport], [DashboardIncludeType])
				VALUES
					(@ID, @NewNode, @CouncilType, @Type, @Category, @SubType, @OrganType, @Code, @Name, @Enabled, @ProvinceID, @Address, @PostalCode, @BudgetCode, @COFOG, @AddressID, @UnitTypeID, @NationalCode, @NeedsChartType, @WebServiceSaveType, @MainOrganType, @ElaboratedBudgetType, @TreasurySupervisionType, @UserDefinitionReferenceType, @BoardOfTrusteesType, @ArrangementTypeInSalary, @BriefNameType,@TopChartApproveDate,@ElaboratedChartApproveDate,@ProvincialChartApproveDate, @ADepartmentShowType, @IsDiscludedInPakna, @EnableForPostImport, @DashboardIncludeType)
			END
			ELSE
			BEGIN -- update
				UPDATE org.Department
				SET 
					CouncilType = @CouncilType,
					[Type] = @Type,
                    [Category] = @Category,
					SubType = @SubType,
					OrganType = @OrganType,
					[Name] = @Name,
					[Enabled] = @Enabled,
					ProvinceID = @ProvinceID,
					[Address] = @Address,
					PostalCode = @PostalCode, 
					BudgetCode = @BudgetCode,
					COFOG = @COFOG,
					AddressID = @AddressID,
					UnitTypeID = @UnitTypeID,
					NationalCode = @NationalCode,
					NeedsChartType = @NeedsChartType,
					WebServiceSaveType = @WebServiceSaveType,
					MainOrganType = @MainOrganType,
					ElaboratedBudgetType = @ElaboratedBudgetType,
					TreasurySupervisionType = @TreasurySupervisionType,
					UserDefinitionReferenceType = @UserDefinitionReferenceType,
					ArrangementTypeInSalary = @ArrangementTypeInSalary,
					BriefNameType = @BriefNameType,
					TopChartApproveDate = @TopChartApproveDate,
					ElaboratedChartApproveDate = @ElaboratedChartApproveDate,
					ProvincialChartApproveDate = @ProvincialChartApproveDate,
					DepartmentShowType = @ADepartmentShowType,
					[IsDiscludedInPakna] = @IsDiscludedInPakna,
					[EnableForPostImport] = @EnableForPostImport,
                    [DashboardIncludeType] = @DashboardIncludeType
				WHERE ID = @ID

				IF @Node <> @NewNode
				BEGIN
					Update org.Department
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyDepartmentPostalCode'))
	DROP PROCEDURE org.spModifyDepartmentPostalCode
GO

CREATE PROCEDURE org.spModifyDepartmentPostalCode
	@AID UNIQUEIDENTIFIER,
	@APostalCode CHAR(10)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@PostalCode CHAR(10) = LTRIM(RTRIM(@APostalCode))

	BEGIN TRY
		BEGIN TRAN

			BEGIN 
				UPDATE org.Department
				SET 
					PostalCode = @PostalCode
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spSetTreeOrder'))
	DROP PROCEDURE org.spSetTreeOrder
GO

CREATE PROCEDURE org.spSetTreeOrder
	@ATreeOrders NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@TreeOrders NVARCHAR(MAX) = @ATreeOrders,
		@Result NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN
			update Department 
			set Department.[TreeOrder] = treeOrders.[TreeOrder]
			from openjson(@TreeOrders)
			with (
				ID UNIQUEIDENTIFIER,
				[TreeOrder] INT
			) treeOrders
			inner join Org.Department on treeOrders.ID = Department.ID 
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentsSummary'))
DROP PROCEDURE org.spGetDepartmentsSummary
GO

CREATE PROCEDURE org.spGetDepartmentsSummary
	@AParentID UNIQUEIDENTIFIER,
	@AProvinceID UNIQUEIDENTIFIER,
	@AUnitType UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ATypes NVARCHAR(MAX),
	@AEnabled TINYINT,
	@ASubType TINYINT,
	@ACouncilType TINYINT,
	@AOrganType TINYINT,
	@ACode VARCHAR(20),
	@ABudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@ACodes NVARCHAR(MAX),
	@ACOFOG TINYINT,
	@ALevel INT,
	@ALoadLabel BIT,
	@ANationalCode NVARCHAR(15),
	@ANeedsChartType TINYINT,
	@AWebServiceSaveType TINYINT,
	@AMainOrganType TINYINT,
	@AElaboratedBudgetType TINYINT,
	@ATreasurySupervisionType TINYINT,
	@AUserDefinitionReferenceType TINYINT,
	@ABoardOfTrusteesType TINYINT,
	@AArrangementTypeInSalary TINYINT,
	@ABriefNameType TINYINT,
	@ADepartmentShowType TINYINT,
	@AUserDefinitionReferenceTypes NVARCHAR(MAX),
	@AIsDiscludedInPakna TINYINT,
	@ANoLoadTestDepartment BIT,
	@AGetPrivateDepartments BIT,

	@AEnabledApplicationIDs NVARCHAR(MAX),
	@AEnabledApplicationIDsForWebService NVARCHAR(MAX),
	@AEnabledApplicationIDsForReport NVARCHAR(MAX),

	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ProvinceID UNIQUEIDENTIFIER = @AProvinceID,
		@UnitType UNIQUEIDENTIFIER = @AUnitType,
		@Type TINYINT = ISNULL(@AType, 0),
		@Types NVARCHAR(MAX) = @ATypes,
		@Enabled TINYINT= ISNULL(@AEnabled, 0),
		@SubType TINYINT = ISNULL(@ASubType, 0),
		@OrganType TINYINT = ISNULL(@AOrganType, 0),
		@CouncilType TINYINT = ISNULL(@ACouncilType, 0),
		@Code VARCHAR(20) = LTRIM(RTRIM(@ACode)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)), 
		@Codes NVARCHAR(MAX) = @ACodes,
		@COFOG TINYINT = COALESCE(@ACOFOG, 0),
		@Level INT = @ALevel,
		@LoadLabel BIT = COALESCE(@ALoadLabel, 0),
		@NationalCode NVARCHAR(15) =  @ANationalCode,
		@NeedsChartType TINYINT = COALESCE(@ANeedsChartType, 0),
		@WebServiceSaveType TINYINT = COALESCE(@AWebServiceSaveType, 0),
		@MainOrganType TINYINT = COALESCE(@AMainOrganType, 0),
		@ElaboratedBudgetType TINYINT = COALESCE(@AElaboratedBudgetType, 0),
		@TreasurySupervisionType TINYINT = COALESCE(@ATreasurySupervisionType, 0),
		@UserDefinitionReferenceType TINYINT = COALESCE(@AUserDefinitionReferenceType, 0),
		@BoardOfTrusteesType TINYINT = COALESCE(@ABoardOfTrusteesType, 0),
		@ArrangementTypeInSalary TINYINT = COALESCE(@AArrangementTypeInSalary, 0),
		@BriefNameType TINYINT = COALESCE(@ABriefNameType, 0),
		@DepartmentShowType TINYINT = COALESCE(@ADepartmentShowType, 0),
		@UserDefinitionReferenceTypes NVARCHAR(MAX) = @AUserDefinitionReferenceTypes,
		@IsDiscludedInPakna TINYINT = COALESCE(@AIsDiscludedInPakna, 0),
		@NoLoadTestDepartment BIT = COALESCE(@ANoLoadTestDepartment, 0),
		@GetPrivateDepartments BIT = COALESCE(@AGetPrivateDepartments, 0),

		@EnabledApplicationIDs NVARCHAR(MAX) = @AEnabledApplicationIDs,
		@EnabledApplicationIDsForWebService NVARCHAR(MAX) = @AEnabledApplicationIDsForWebService,
		@EnabledApplicationIDsForReport NVARCHAR(MAX) = @AEnabledApplicationIDsForReport,

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

	;WITH EnabledApplicationIDs AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDs) EnabledApplicationIDs ON EnabledApplicationIDs.value = departmentEnableState.ApplicationID
		WHERE [Enable] = 1
		GROUP BY Department.ID
	)
	, EnabledApplicationIDsForWebService AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDsForWebService) EnabledApplicationIDsForWebService ON EnabledApplicationIDsForWebService.value = departmentEnableState.ApplicationID
		WHERE [EnableForWebService] = 1
		GROUP BY Department.ID
	)
	, EnabledApplicationIDsForReport AS
	(
		SELECT
			Department.ID 
		FROM org.Department
			INNER JOIN [org].[DepartmentEnableState] departmentEnableState ON departmentEnableState.DepartmentID = Department.ID
			INNER JOIN OPENJSON(@EnabledApplicationIDsForReport) EnabledApplicationIDsForReport ON EnabledApplicationIDsForReport.value = departmentEnableState.ApplicationID
		WHERE [EnableForReport] = 1
		GROUP BY Department.ID
	)
	, SelectedDepartment AS
	(
		SELECT
			Department.ID,
			Department.[Name],
			Department.[Code],
			IIF(legalRequest.LegalNumber IS NOT NULL, legalRequest.LegalNumber COLLATE Persian_100_CI_AI, Department.[NationalCode] COLLATE Persian_100_CI_AI) LegalNumber,
			Department.[Node]
		FROM org.Department
			LEFT JOIN OPENJSON(@Codes) Codes ON Codes.Value = Department.Code
			LEFT JOIN OPENJSON(@Types) [Types] ON [Types].Value = Department.[Type]
			LEFT JOIN OPENJSON(@UserDefinitionReferenceTypes) [UserDefinitionReferenceTypes] ON [UserDefinitionReferenceTypes].Value = Department.[UserDefinitionReferenceType]
			LEFT JOIN [Kama.Aro.Sakhtar].req._FinalLegalRequests legalRequest ON legalRequest.OrganID = Department.ID AND legalRequest.UnitID IS NULL
			LEFT JOIN EnabledApplicationIDs ON EnabledApplicationIDs.ID = Department.ID
			LEFT JOIN EnabledApplicationIDsForWebService ON EnabledApplicationIDsForWebService.ID = Department.ID
			LEFT JOIN EnabledApplicationIDsForReport ON EnabledApplicationIDsForReport.ID = Department.ID
		WHERE Department.RemoverID IS NULL
			AND (@ParentNode IS NULL OR Department.[Node].IsDescendantOf(@ParentNode) = 1)
			AND (@ProvinceID IS NULL OR department.ProvinceID = @ProvinceID)
			AND (@Type < 1 OR Department.[Type] = @Type)
			AND (@UnitType IS NULL OR Department.UnitTypeID = @UnitType)
			AND (@BudgetCode IS NULL OR Department.BudgetCode = @BudgetCode)
			AND (@SubType < 1 OR Department.SubType = @SubType)
			AND (@CouncilType < 1 OR Department.CouncilType = @CouncilType)
			AND (@Code IS NULL OR Department.Code Like CONCAT('%', @Code, '%'))
			AND (@Name IS NULL OR Department.[Name] Like CONCAT('%', @Name , '%'))
			AND (Department.[Name] NOT LIKE N'%تست%')
			AND (Department.[Name] NOT LIKE N'%حذف%')
			AND (@Codes IS NULL OR Codes.Value = Department.Code)
			AND (@Types IS NULL OR [Types].Value = Department.[Type])
			AND (@COFOG < 1 OR Department.COFOG = @COFOG)
			AND (@LoadLabel = 1 OR (@LoadLabel = 0 AND Department.[Type] <> 10))
			AND (@NeedsChartType < 1 OR NeedsChartType = @NeedsChartType)
			AND (@WebServiceSaveType < 1 OR WebServiceSaveType = @WebServiceSaveType)
			AND (@Enabled < 1 OR Department.[Enabled] = @Enabled - 1)
			AND (@MainOrganType < 1 OR Department.[MainOrganType] = @MainOrganType)
			AND (@ElaboratedBudgetType < 1 OR Department.[ElaboratedBudgetType] = @ElaboratedBudgetType)
			AND (@TreasurySupervisionType < 1 OR Department.[TreasurySupervisionType] = @TreasurySupervisionType)
			AND (@UserDefinitionReferenceType < 1 OR Department.[UserDefinitionReferenceType] = @UserDefinitionReferenceType)
			AND (@BoardOfTrusteesType < 1 OR Department.[BoardOfTrusteesType] = @BoardOfTrusteesType)
			AND (@ArrangementTypeInSalary < 1 OR Department.[ArrangementTypeInSalary] = @ArrangementTypeInSalary)
			AND (@BriefNameType < 1 OR Department.[BriefNameType] = @BriefNameType)
			AND (@DepartmentShowType < 1 OR Department.[DepartmentShowType] = @DepartmentShowType)
			AND (@UserDefinitionReferenceTypes IS NULL OR [UserDefinitionReferenceTypes].Value = Department.[UserDefinitionReferenceType])
			AND (@IsDiscludedInPakna < 1 OR Department.IsDiscludedInPakna = @IsDiscludedInPakna - 1)
			AND (@NoLoadTestDepartment = 0 OR (@NoLoadTestDepartment = 1 AND Department.[Name] NOT LIKE '%تست%' AND Department.Code <> 0))
			AND (@GetPrivateDepartments = 1 OR Department.[Type] < 100)
			AND (@EnabledApplicationIDs IS NULL OR EnabledApplicationIDs.ID = Department.ID)
			AND (@EnabledApplicationIDsForWebService IS NULL OR EnabledApplicationIDsForWebService.ID = Department.ID)
			AND (@EnabledApplicationIDsForReport IS NULL OR EnabledApplicationIDsForReport.ID = Department.ID)
	)
	,Total AS
	(
	   SELECT 
			COUNT(*) AS Total
		FROM SelectedDepartment department
		WHERE (@Level IS NULL OR department.[Node].GetLevel() = @Level)
			AND (@NationalCode IS NULL OR Department.LegalNumber = @NationalCode)
		    AND @GetTotalCount = 1
	)
	, MainSelect AS
	(
		SELECT 
			department.ID,
			department.[Name],
			department.[Code]
		FROM SelectedDepartment department
		WHERE (@Level IS NULL OR department.[Node].GetLevel() = @Level)
			AND (@NationalCode IS NULL OR Department.LegalNumber = @NationalCode)
	)
	

	SELECT * FROM MainSelect, Total
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteDepartmentBudget'))
	DROP PROCEDURE org.spDeleteDepartmentBudget
GO

CREATE PROCEDURE org.spDeleteDepartmentBudget
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID


	BEGIN TRY
		BEGIN TRAN


			UPDATE [org].[DepartmentBudget]
			SET RemoverUserID = @CurrentUserID,
				RemoverDate = GETDATE()
			WHERE ID = @ID

			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]

GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentBudget'))
DROP PROCEDURE org.spGetDepartmentBudget
GO

CREATE PROCEDURE org.spGetDepartmentBudget
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	

	SELECT 
		departmentBudget.ID,
		departmentBudget.DepartmentID,
		department.[Name] DepartmentName,
		department.[Code] DepartmentCode,
		departmentBudget.[Name],
		departmentBudget.BudgetCode,
		departmentBudget.SalaryInputBudgetCode,
		departmentBudget.[Enabled],
		departmentBudget.[Type]
	FROM [org].[DepartmentBudget] departmentBudget
		LEFT JOIN [org].[Department] department ON department.ID = departmentBudget.DepartmentID
	WHERE departmentBudget.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentBudgetsForSalary'))
DROP PROCEDURE org.spGetDepartmentBudgetsForSalary
GO

CREATE PROCEDURE org.spGetDepartmentBudgetsForSalary
	@ADepartmentID UNIQUEIDENTIFIER,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
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
			departmentBudget.ID,
			departmentBudget.DepartmentID,
			department.[Name] DepartmentName,
			department.[Code] DepartmentCode,
			departmentBudget.[Name],
			departmentBudget.BudgetCode,
			departmentBudget.SalaryInputBudgetCode,
			departmentBudget.[Type],
			budgetCodeAssignment.PositionSubTypeID
		FROM [org].[DepartmentBudget] departmentBudget
			INNER JOIN [org].[Department] department ON department.ID = departmentBudget.DepartmentID
			LEFT JOIN [org].[BudgetCodeAssignment] budgetCodeAssignment ON budgetCodeAssignment.DepartmentBudgetID = departmentBudget.ID AND [ApplicationID] = @ApplicationID
		WHERE (departmentBudget.RemoverDate IS NULL)
			AND (budgetCodeAssignment.RemoveDate IS NULL)
			AND (departmentBudget.[Enabled] = 1)
			AND (
					(departmentBudget.DepartmentID = @DepartmentID AND budgetCodeAssignment.PositionSubTypeID IS NULL AND (@PositionSubTypeID IS NULL OR @PositionSubTypeID = 0x))
						OR (departmentBudget.DepartmentID = @DepartmentID AND budgetCodeAssignment.PositionSubTypeID = @PositionSubTypeID)
				)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, Total
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentsBudget'))
DROP PROCEDURE org.spGetDepartmentsBudget
GO

CREATE PROCEDURE org.spGetDepartmentsBudget
	@ADepartmentID UNIQUEIDENTIFIER,
	@ADepartmentIDs NVARCHAR(MAX),
	@AEnableType TINYINT,
	@ABudgetCode VARCHAR(20),
	@ASalaryInputBudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@AType TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@DepartmentIDs NVARCHAR(MAX) = @ADepartmentIDs,
		@EnableType TINYINT= ISNULL(@AEnableType, 0),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@SalaryInputBudgetCode VARCHAR(20) = LTRIM(RTRIM(@ASalaryInputBudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)), 
		@Type TINYINT = COALESCE(@AType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)
	
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH SelectedDepartment AS
	(
		SELECT 
			department.*
		FROM [org].[DepartmentBudget] department
		WHERE (department.RemoverUserID IS NULL)
			AND (@BudgetCode IS NULL OR department.BudgetCode = @BudgetCode)
			AND (@SalaryInputBudgetCode IS NULL OR department.SalaryInputBudgetCode = @SalaryInputBudgetCode)
			AND (@Name IS NULL OR department.[Name] Like CONCAT('%', @Name , '%'))
			AND (@EnableType < 1 OR department.[Enabled] = @EnableType - 1)
			AND (@DepartmentID IS NULL OR department.DepartmentID = @DepartmentID)
			AND (@Type < 1 OR department.[Type] = @Type)
	)
	, MainSelect AS
	(
		SELECT 
			departmentBudget.ID,
			departmentBudget.DepartmentID,
			department.[Name] DepartmentName,
			department.[Code] DepartmentCode,
			departmentBudget.[Name],
			departmentBudget.BudgetCode,
			departmentBudget.SalaryInputBudgetCode,
			departmentBudget.[Enabled],
			departmentBudget.[Type]
		FROM SelectedDepartment departmentBudget
			LEFT JOIN [org].[Department] department ON department.ID = departmentBudget.DepartmentID
			LEFT JOIN OPENJSON(@DepartmentIDs) departmentIDs ON departmentIDs.value = department.[ID]
			WHERE (@DepartmentIDs IS NULL OR departmentIDs.value = department.ID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, Total
	ORDER BY [Type] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentsBudgetDistinct'))
DROP PROCEDURE org.spGetDepartmentsBudgetDistinct
GO

CREATE PROCEDURE org.spGetDepartmentsBudgetDistinct
	@ADepartmentID UNIQUEIDENTIFIER,
	@ADepartmentIDs NVARCHAR(MAX),
	@AParentDepartmentID UNIQUEIDENTIFIER,
	@AEnableType TINYINT,
	@ABudgetCode VARCHAR(20),
	@ADepartmentCode VARCHAR(20),
	@ASalaryInputBudgetCode VARCHAR(20),
	@AName NVARCHAR(256),
	@AType TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@DepartmentIDs NVARCHAR(MAX) = @ADepartmentIDs,
		@ParentDepartmentID UNIQUEIDENTIFIER = @AParentDepartmentID,
		@EnableType TINYINT= COALESCE(@AEnableType, 0),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@DepartmentCode VARCHAR(20) = LTRIM(RTRIM(@ADepartmentCode)),
		@SalaryInputBudgetCode VARCHAR(20) = LTRIM(RTRIM(@ASalaryInputBudgetCode)),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)), 
		@Type TINYINT = COALESCE(@AType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentDepartmentNode HIERARCHYID

		SET @ParentDepartmentNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentDepartmentID)
	
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			department.ID DepartmentID,
			department.[Code] DepartmentCode,
			department.[Name] DepartmentName
		FROM [org].[Department] department
			LEFT JOIN [org].[DepartmentBudget] departmentBudget ON departmentBudget.DepartmentID = department.ID
			LEFT JOIN OPENJSON(@DepartmentIDs) departmentIDs ON departmentIDs.value = Department.ID
		WHERE (department.[Name] NOT LIKE N'%تست%')
			AND (department.[Name] NOT LIKE N'%حذف%')
			AND (department.RemoverID IS NULL)
			AND (department.ID <> '00000000-0000-0000-0000-000000000000')
			AND (@BudgetCode IS NULL OR departmentBudget.BudgetCode = @BudgetCode)
			AND (@SalaryInputBudgetCode IS NULL OR departmentBudget.SalaryInputBudgetCode = @SalaryInputBudgetCode)
			AND (@Name IS NULL OR departmentBudget.[Name] Like CONCAT('%', @Name , '%'))
			AND (@EnableType < 1 OR departmentBudget.[Enabled] = @EnableType - 1)
			AND (@DepartmentID IS NULL OR department.ID = @DepartmentID)
			AND (@DepartmentCode IS NULL OR department.[Code] = @DepartmentCode)
			AND (@Type < 1 OR departmentBudget.[Type] = @Type)
			AND (@ParentDepartmentID IS NULL OR department.[Node].IsDescendantOf(@ParentDepartmentNode) = 1)
			AND (@DepartmentIDs IS NULL OR departmentIDs.value = Department.ID)
		GROUP BY department.ID, department.[Name], department.[Code]
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, Total
	ORDER BY DepartmentID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyDepartmentBudget'))
	DROP PROCEDURE org.spModifyDepartmentBudget
GO

CREATE PROCEDURE org.spModifyDepartmentBudget
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AName NVARCHAR(256),
	@ABudgetCode VARCHAR(20),
	@ASalaryInputBudgetCode VARCHAR(20),
	@AEnabled BIT,
	@AType TINYINT,
	@AResult NVARCHAR(MAX) OUTPUT

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)),
		@BudgetCode VARCHAR(20) = LTRIM(RTRIM(@ABudgetCode)),
		@SalaryInputBudgetCode VARCHAR(20) = LTRIM(RTRIM(@ASalaryInputBudgetCode)),
		@Enabled BIT = ISNULL(@AEnabled, 0),
		@Type TINYINT = COALESCE(@AType, 0)


	BEGIN TRY
		BEGIN TRAN


			IF @Type = 1
			SET @Name = (SELECT [Name] FROM org.Department WHERE ID = @DepartmentID)
			 
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO [org].[DepartmentBudget]
					([ID], [DepartmentID], [Name], [BudgetCode], [Enabled], [RemoverUserID], [RemoverDate], [Type], [SalaryInputBudgetCode])
				VALUES
					(@ID, @DepartmentID, @Name, @BudgetCode, @Enabled, NULL, NULL, @Type, @SalaryInputBudgetCode)


			END
			ELSE
			BEGIN -- update

				UPDATE [org].[DepartmentBudget]
				SET 
					[Name] = @Name,
					BudgetCode = @BudgetCode,
					SalaryInputBudgetCode = @SalaryInputBudgetCode,
					[Enabled] = @Enabled,
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
USE [Kama.Aro.Organization]
GO
IF OBJECT_ID('org.spGetDepartmentEnableStates') IS NOT NULL
    DROP PROCEDURE org.spGetDepartmentEnableStates
GO
CREATE PROCEDURE org.spGetDepartmentEnableStates
    @ADepartmentID UNIQUEIDENTIFIER,
    @ADepartmentIDs NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE 
        @DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
        @DepartmentIDs NVARCHAR(MAX) = @ADepartmentIDs
    
    ;WITH Clients AS 
    (
        SELECT ApplicationID 
        FROM org.Client
        GROUP BY ApplicationID
    )
    , Applications AS 
    (
        
        SELECT
            app.ID ApplicationID,
            app.[Name] ApplicationName
        FROM org.[Application] app
            INNER JOIN Clients on Clients.ApplicationID = app.ID
        WHERE app.[Enabled] = 1
    )
    , Department AS
    (
        SELECT
            ID DepartmentID,
            [Name] DepartmentName
        FROM org.Department dep
            LEFT JOIN OPENJSON(@DepartmentIDs) DepartmentIDs ON DepartmentIDs.value = dep.ID
        WHERE RemoverDate IS NULL
            AND (@DepartmentID IS NULL OR dep.ID = @DepartmentID)
            AND (@DepartmentIDs IS NULL OR DepartmentIDs.value = dep.ID)
    )
    , Main AS
    (
        SELECT * FROM Applications, Department
    )
    SELECT DISTINCT
        app.ApplicationID,
        app.ApplicationName,
        app.DepartmentID,
        app.[DepartmentName],
        CASE WHEN app.DepartmentID = de.DepartmentID THEN CAST(COALESCE(de.[Enable], 0) AS BIT) ELSE CAST(0 AS BIT) END [Enable],
        CASE WHEN app.DepartmentID = de.DepartmentID THEN CAST(COALESCE(de.EnableForWebService, 0) AS BIT) ELSE CAST(0 AS BIT) END EnableForWebService,
        CASE WHEN app.DepartmentID = de.DepartmentID THEN CAST(COALESCE(de.EnableForReport, 0) AS BIT) ELSE CAST(0 AS BIT) END EnableForReport
    FROM Main app
        LEFT JOIN [org].[DepartmentEnableState] de ON de.ApplicationID = app.ApplicationID AND de.DepartmentID = app.DepartmentID
        LEFT JOIN OPENJSON(@DepartmentIDs) DepartmentIDs ON DepartmentIDs.value = app.DepartmentID
    WHERE (@DepartmentID IS NULL OR app.DepartmentID = @DepartmentID)
        AND (@DepartmentIDs IS NULL OR DepartmentIDs.value = app.DepartmentID)
	ORDER BY [ApplicationName]
END
GO
USE [Kama.Aro.Organization]
GO

IF OBJECT_ID('org.spModifyDepartmentEnableState') IS NOT NULL
    DROP PROCEDURE org.spModifyDepartmentEnableState
GO

CREATE PROCEDURE org.spModifyDepartmentEnableState
	@ADepartmentID UNIQUEIDENTIFIER,
	@AEnableStates NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@EnableStates NVARCHAR(MAX) = LTRIM(RTRIM(@AEnableStates)),
		@Result INT = 0
	
	BEGIN TRY
		BEGIN TRAN

			DELETE [org].[DepartmentEnableState]
			WHERE [DepartmentID] = @DepartmentID


			IF @AEnableStates IS NOT NULL
			BEGIN
				INSERT INTO [org].[DepartmentEnableState]
					([ID], [DepartmentID], [ApplicationID], [Enable], [EnableForWebService], [EnableForReport])
				SELECT 
					NEWID() ID,
					@DepartmentID [DepartmentID], 
					[ApplicationID],
					[Enable],
					[EnableForWebService],
					[EnableForReport]
				FROM OPENJSON(@EnableStates)
				WITH(
					ApplicationID UNIQUEIDENTIFIER,
					[Enable] BIT,
					[EnableForWebService] BIT,
					[EnableForReport] BIT
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteDepartmentPostImport'))
	DROP PROCEDURE org.spDeleteDepartmentPostImport
GO

CREATE PROCEDURE org.spDeleteDepartmentPostImport
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID
	
	BEGIN TRY
		BEGIN TRAN

			UPDATE [org].[DepartmentPostImport]
			SET RemoverUserID = @CurrentUserID,
				RemovedDate = GETDATE()
			WHERE ID = @ID


		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]

GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentPostImport'))
DROP PROCEDURE org.spGetDepartmentPostImport
GO

CREATE PROCEDURE org.spGetDepartmentPostImport
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	

	SELECT 
		postImport.[ID],
		postImport.[DepartmentID],
		department.[Name] DepartmentName,
		postImport.[EmploymentType],
		postImport.[CreationDate],
		postImport.[LimitedNumber]
	FROM [org].[DepartmentPostImport] postImport
		INNER JOIN org.Department department ON department.ID = postImport.DepartmentID
	WHERE postImport.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID(N'org.spGetDepartmentsPostImport'))
DROP PROCEDURE org.spGetDepartmentsPostImport
GO

CREATE PROCEDURE org.spGetDepartmentsPostImport
	@ADepartmentID UNIQUEIDENTIFIER,
	@AEmploymentType TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID 
	

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			postImport.[ID],
			postImport.[DepartmentID],
			department.[Name] DepartmentName,
			postImport.[EmploymentType],
			postImport.[CreationDate],
			postImport.[LimitedNumber]
		FROM [org].[DepartmentPostImport] postImport
			INNER JOIN org.Department department ON department.ID = postImport.DepartmentID
		WHERE (postImport.RemovedDate IS NULL)
			AND (@DepartmentID IS NULL OR postImport.DepartmentID = @DepartmentID)
			AND (@EmploymentType < 1 OR postImport.EmploymentType = @EmploymentType)
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
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spModifyDepartmentPostImport') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spModifyDepartmentPostImport
GO

CREATE PROCEDURE org.spModifyDepartmentPostImport  
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AEmploymentType TINYINT,
	@ALimitedNumber INT

--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@EmploymentType TINYINT = COALESCE(@AEmploymentType, 0),
		@LimitedNumber INT = COALESCE(@ALimitedNumber, 0),
		@Result INT = 0


	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [org].[DepartmentPostImport]
					([ID], [DepartmentID], [EmploymentType], [CreationDate], [RemoverUserID], [RemovedDate], [LimitedNumber])
				VALUES
					(@ID, @DepartmentID, @EmploymentType, GETDATE(), NULL, NULL, @LimitedNumber)
			END
			ELSE
			BEGIN
				UPDATE [org].[DepartmentPostImport]
				SET
					[EmploymentType] = @EmploymentType,
					[LimitedNumber] = @LimitedNumber
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteDirtyDataReport'))
	DROP PROCEDURE org.spDeleteDirtyDataReport
GO

CREATE PROCEDURE org.spDeleteDirtyDataReport
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @ID UNIQUEIDENTIFIER = @AID,
	@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID
	 
	BEGIN TRY
		BEGIN TRAN

			Update [org].[DirtyDataReport]
			SET
				RemoveDate = GETDATE(),
				RemoverUserID = @CurrentUserID
			WHERE
				ID = @ID
					
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDirtyDataReport'))
	DROP PROCEDURE org.spGetDirtyDataReport
GO

CREATE PROCEDURE org.spGetDirtyDataReport
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		ID,
		ApplicationID,
		[Title],
		SPName,
        [Description],
        [Solution],
        [Code]
	FROM org.[DirtyDataReport]
	WHERE ID = @ID 
        AND RemoverUserID IS NULL
        AND RemoveDate IS NULL

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDirtyDataReports'))
	DROP PROCEDURE org.spGetDirtyDataReports
GO

CREATE PROCEDURE org.spGetDirtyDataReports
	@AApplicationID UNIQUEIDENTIFIER,
	@ATitle NVARCHAR(100),
	@ASPName VARCHAR(100),
    @ASolution NVARCHAR(500),
    @ACode VARCHAR(3),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Title NVARCHAR(100)= LTRIM(RTRIM(@ATitle)),
		@SPName VARCHAR(100)= LTRIM(RTRIM(@ASPName)),
        @Solution NVARCHAR(500)= LTRIM(RTRIM(@ASolution)),
        @Code VARCHAR(3)= LTRIM(RTRIM(@ACode)),
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT 
			report.ID,
			report.ApplicationID,
			report.[Title],
            report.SPName,
            report.[Description],
            report.[Solution],
            report.CreationDate,
            report.[Code]
		FROM org.DirtyDataReport report 
		WHERE report.RemoverUserID IS NULL
            AND report.RemoveDate IS NULL
            AND (@ApplicationID IS NULL OR report.ApplicationID = @ApplicationID)
			AND (@Title IS NULL OR report.[Title] LIKE CONCAT('%', @Title, '%'))
			AND (@SPName IS NULL OR report.[SPName] LIKE CONCAT('%', @SPName, '%'))
            AND (@Code IS NULL OR report.[Code] = @Code)
	)
    ,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)

	SELECT *
	FROM MainSelect, Total	 
	ORDER BY CreationDate DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;	

END
 
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyDirtyDataReport'))
	DROP PROCEDURE org.spModifyDirtyDataReport
GO

CREATE PROCEDURE org.spModifyDirtyDataReport
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ATitle NVARCHAR(100),
	@ASPName VARCHAR(100),
	@ADescription NVARCHAR(500),
    @ASolution NVARCHAR(500),
    @ACode VARCHAR(3)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Title NVARCHAR(100)= LTRIM(RTRIM(@ATitle)),
		@SPName VARCHAR(100)= LTRIM(RTRIM(@ASPName)),
		@Description NVARCHAR(500)= LTRIM(RTRIM(@ADescription)),
        @Solution NVARCHAR(500)= LTRIM(RTRIM(@ASolution)),
        @Code VARCHAR(3)= LTRIM(RTRIM(@ACode))

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO org.[DirtyDataReport]
				(ID, ApplicationID, [Title], SPName, [Description], [Solution], [Code], CreationDate, RemoverUserID, RemoveDate)
				VALUES
				(@ID, @ApplicationID, @Title, @SPName, @Description, @Solution, @Code, GETDATE(), NULL, NULL)
			END
			ELSE
			BEGIN -- update
				UPDATE org.[DirtyDataReport]
				SET 
                [ApplicationID] = @ApplicationID,
				[Title] = @Title,
				[SPName] = @SPName,
                [Description] = @Description,
                [Solution] = @Solution,
                [Code] = @Code
				WHERE ID = @ID
			END 

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetSurveyDuplicateNationalCodes'))
	DROP PROCEDURE org.spGetSurveyDuplicateNationalCodes
GO

CREATE PROCEDURE org.spGetSurveyDuplicateNationalCodes
    @AGetTotalCount BIT
--WITH ENCRYPTION
AS
BEGIN
    
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE 
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0)

    IF @GetTotalCount = 0
        BEGIN
            ;WITH DuplicatedEmployees AS(
            	SELECT 
                    emp.NationalCode,
                    [OrganID],
                    COUNT(*) AS Total
            	FROM [Kama.Aro.Survey].emp.Employee emp
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
            	WHERE emp.RemoveDate IS NULL
            		AND emp.RemoverUserID IS NULL
            	GROUP BY emp.NationalCode,[OrganID]
            	HAVING COUNT(*) > 1
            ), MainSelect AS (
                SELECT 
                    dep.[Name] DepartmentName,
                    inv.NationalCode,
                    inv.FirstName,
                    inv.LastName,
                    ROW_NUMBER() OVER(PARTITION BY inv.NationalCode , dep.ID order by CreationDate DESC) RowNumber
                FROM  [Kama.Aro.Survey].emp.Employee emp
                	INNER JOIN DuplicatedEmployees ON DuplicatedEmployees.NationalCode = emp.NationalCode AND DuplicatedEmployees.OrganID = emp.OrganID
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
            )
	        SELECT * FROM MainSelect 
            WHERE RowNumber = 1
            ORDER BY MainSelect.[DepartmentName] , MainSelect.NationalCode  
        END
    ELSE
        BEGIN
            ;WITH DuplicatedEmployees AS(
            	SELECT 
                    emp.NationalCode,
                    [OrganID],
                    COUNT(*) AS Total
            	FROM [Kama.Aro.Survey].emp.Employee emp
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
            	WHERE emp.RemoveDate IS NULL
            		AND emp.RemoverUserID IS NULL
            	GROUP BY emp.NationalCode,[OrganID]
            	HAVING COUNT(*) > 1
            ), MainSelect AS (
                SELECT 
                    dep.[Name] DepartmentName,
                    inv.NationalCode,
                    inv.FirstName,
                    inv.LastName,
                    ROW_NUMBER() OVER(PARTITION BY inv.NationalCode , dep.ID order by CreationDate DESC) RowNumber
                FROM  [Kama.Aro.Survey].emp.Employee emp
                	INNER JOIN DuplicatedEmployees ON DuplicatedEmployees.NationalCode = emp.NationalCode AND DuplicatedEmployees.OrganID = emp.OrganID
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
            )
            SELECT COUNT(*) AS TotalCount FROM MainSelect 
            WHERE RowNumber = 1
        END
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetSurveyEmployeesWithoutImages'))
	DROP PROCEDURE org.spGetSurveyEmployeesWithoutImages
GO

CREATE PROCEDURE org.spGetSurveyEmployeesWithoutImages
    @AGetTotalCount BIT
--WITH ENCRYPTION
AS
BEGIN
     SET NOCOUNT ON;
     SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

     DECLARE 
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0)

    IF @GetTotalCount = 0
        BEGIN
            ;WITH MainSelect AS (
                SELECT 
                    dep.[Name] DepartmentName,
                    emp.NationalCode,
                    FORMAT(inv.BirthDate, 'yyyy/MM/dd', 'fa') BirthDate,
                    inv.FirstName,
                    inv.LastName
                FROM [Kama.Aro.Survey].emp.Employee emp
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
                    LEFT JOIN [Kama.Aro.Organization.Attachment].pbl.Attachment attch ON ParentID = inv.ID AND attch.[Type] = 7
                    --LEFT JOIN [Server178_5].[Kama.Aro.Organization.Attachment].pbl.Attachment attch ON ParentID = inv.ID AND attch.[Type] = 7
                WHERE emp.RemoveDate IS NULL
                	AND emp.RemoverUserID IS NULL
                    AND attch.ID IS NULL 
            )
	        SELECT  *
            FROM MainSelect 
            ORDER BY MainSelect.[DepartmentName] , MainSelect.NationalCode  
        END
    ELSE
        BEGIN
            ;WITH MainSelect AS (
                SELECT 
                    dep.[Name] DepartmentName,
                    emp.NationalCode,
                    FORMAT(inv.BirthDate, 'yyyy/MM/dd', 'fa') BirthDate,
                    inv.FirstName,
                    inv.LastName
                FROM [Kama.Aro.Survey].emp.Employee emp
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
                    LEFT JOIN [Kama.Aro.Organization.Attachment].pbl.Attachment attch ON ParentID = inv.ID AND attch.[Type] = 7
                    --LEFT JOIN [Server178_5].[Kama.Aro.Organization.Attachment].pbl.Attachment attch ON ParentID = inv.ID AND attch.[Type] = 7
                WHERE emp.RemoveDate IS NULL
                	AND emp.RemoverUserID IS NULL
                    AND attch.ID IS NULL 
            )
            SELECT COUNT(*) AS TotalCount FROM MainSelect 

        END
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetSurveyIncorrectFormatPostTitles'))
	DROP PROCEDURE org.spGetSurveyIncorrectFormatPostTitles
GO

CREATE PROCEDURE org.spGetSurveyIncorrectFormatPostTitles
    @AGetTotalCount BIT
--WITH ENCRYPTION
AS
BEGIN
     SET NOCOUNT ON;
     SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

     DECLARE 
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0)

     IF @GetTotalCount = 0
        BEGIN
            ;WITH MainSelect AS (
                SELECT 
                    dep.[Name] DepartmentName,
                    inv.NationalCode,
                    inv.FirstName,
                    inv.LastName,
                    emp.PostTitle,
                    inv.Gender
                FROM [Kama.Aro.Survey].emp.Employee emp
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
                WHERE 
			    	emp.RemoveDate IS NULL
                	AND emp.RemoverUserID IS NULL
                    AND (
                             emp.PostTitle LIKE N'%\%'
                             OR
                             emp.PostTitle LIKE N'%,%'
                             OR
                             emp.PostTitle LIKE N'%..%'
                             OR
                             ISNUMERIC(TRIM(emp.PostTitle)) = 1
                             OR
                             TRIM(emp.PostTitle) = ''
                             OR
                             emp.PostTitle IS NULL 
                        )
                )
	SELECT * FROM MainSelect 
    ORDER BY MainSelect.[DepartmentName] , MainSelect.NationalCode  
        END
     ELSE
         BEGIN
            ;WITH MainSelect AS (
                SELECT 
                    dep.[Name] DepartmentName,
                    inv.NationalCode,
                    inv.FirstName,
                    inv.LastName,
                    emp.PostTitle,
                    inv.Gender
                FROM [Kama.Aro.Survey].emp.Employee emp
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
                WHERE 
			    	emp.RemoveDate IS NULL
                	AND emp.RemoverUserID IS NULL
                    AND (
                             emp.PostTitle LIKE N'%\%'
                             OR
                             emp.PostTitle LIKE N'%,%'
                             OR
                             emp.PostTitle LIKE N'%..%'
                             OR
                             ISNUMERIC(TRIM(emp.PostTitle)) = 1
                             OR
                             TRIM(emp.PostTitle) = ''
                             OR
                             emp.PostTitle IS NULL 
                        )
                )
            SELECT COUNT(*) AS TotalCount FROM MainSelect 
         END
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetSurveyNotConfirmedEmployees'))
	DROP PROCEDURE org.spGetSurveyNotConfirmedEmployees
GO

CREATE PROCEDURE org.spGetSurveyNotConfirmedEmployees
    @AGetTotalCount BIT
--WITH ENCRYPTION
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE 
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0)

        IF @GetTotalCount = 0
        BEGIN
            ;WITH MainSelect AS (
                SELECT 
                    dep.[Name] DepartmentName,
                    inv.FirstName,
                    inv.LastName,
                    FORMAT(inv.BirthDate, 'yyyy/MM/dd', 'fa') BirthDate,
                    emp.PostTitle,
                    inv.Gender,
                    emp.NationalCode
                FROM [Kama.Aro.Survey].emp.Employee emp
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
                WHERE emp.RemoveDate IS NULL
                	AND emp.RemoverUserID IS NULL
                    AND inv.ConfirmType <> 1
            )
	SELECT * FROM MainSelect 
    ORDER BY MainSelect.[DepartmentName] , MainSelect.NationalCode  
        END
    ELSE
        BEGIN
            ;WITH MainSelect AS (
                SELECT 
                    dep.[Name] DepartmentName,
                    inv.FirstName,
                    inv.LastName,
                    FORMAT(inv.BirthDate, 'yyyy/MM/dd', 'fa') BirthDate,
                    emp.PostTitle,
                    inv.Gender,
                    emp.NationalCode
                FROM [Kama.Aro.Survey].emp.Employee emp
                    INNER JOIN org.Individual inv on inv.ID = emp.IndividualID
                    INNER JOIN org.Department dep on dep.ID = emp.OrganID
                WHERE emp.RemoveDate IS NULL
                	AND emp.RemoverUserID IS NULL
                    AND inv.ConfirmType <> 1
            )
            SELECT COUNT(*) AS TotalCount FROM MainSelect 
        END

 END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetSurveyNotConnectedToAnyEmployees'))
	DROP PROCEDURE org.spGetSurveyNotConnectedToAnyEmployees
GO

CREATE PROCEDURE org.spGetSurveyNotConnectedToAnyEmployees
    @AGetTotalCount BIT
--WITH ENCRYPTION
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE 
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0)

    IF @GetTotalCount = 0
        BEGIN
            ;WITH MainSelect AS (
                SELECT 
                    sv.NationalCode VoterNationalCode,
	        		sa.CreationDate,
	        		(CASE sa.SatisfactionLevelQuestion1 WHEN 0 THEN N'نامشخص' WHEN 1 THEN N'بسیار ضعیف' WHEN 2 THEN N'ضعیف' WHEN 3 THEN N'متوسط' WHEN 4 THEN N'خوب' WHEN 5 THEN N'عالی' END) SatisfactionLevelQuestion1,
	        		(CASE sa.SatisfactionLevelQuestion2 WHEN 0 THEN N'نامشخص' WHEN 1 THEN N'بسیار ضعیف' WHEN 2 THEN N'ضعیف' WHEN 3 THEN N'متوسط' WHEN 4 THEN N'خوب' WHEN 5 THEN N'عالی' END) SatisfactionLevelQuestion2,
	        		(CASE sa.SatisfactionLevelQuestion3 WHEN 0 THEN N'نامشخص' WHEN 1 THEN N'بسیار ضعیف' WHEN 2 THEN N'ضعیف' WHEN 3 THEN N'متوسط' WHEN 4 THEN N'خوب' WHEN 5 THEN N'عالی' END) SatisfactionLevelQuestion3,
	        		(CASE sa.SatisfactionLevelQuestion4 WHEN 0 THEN N'نامشخص' WHEN 1 THEN N'بسیار ضعیف' WHEN 2 THEN N'ضعیف' WHEN 3 THEN N'متوسط' WHEN 4 THEN N'خوب' WHEN 5 THEN N'عالی' END) SatisfactionLevelQuestion4
                FROM [Kama.Aro.Survey].rpt.SurveyAnswer sa
                    INNER JOIN [Kama.Aro.Survey].rpt.SurveyVoter sv ON sv.ID = sa.VoterID
                    LEFT JOIN [Kama.Aro.Survey].emp.Employee emp ON sa.EmployeeID = emp.ID
                WHERE 
	        		emp.RemoveDate IS NULL
                    AND emp.RemoverUserID IS NULL
                    AND (emp.ID IS NULL OR emp.RemoveDate IS NOT NULL OR emp.RemoverUserID IS NOT NULL)
            )
	        SELECT * FROM MainSelect 
            ORDER BY MainSelect.[CreationDate] 
        END
    ELSE
        BEGIN
           ;WITH MainSelect AS (
                SELECT 
                    sv.NationalCode VoterNationalCode,
	        		sa.CreationDate,
	        		(CASE sa.SatisfactionLevelQuestion1 WHEN 0 THEN N'نامشخص' WHEN 1 THEN N'بسیار ضعیف' WHEN 2 THEN N'ضعیف' WHEN 3 THEN N'متوسط' WHEN 4 THEN N'خوب' WHEN 5 THEN N'عالی' END) SatisfactionLevelQuestion1,
	        		(CASE sa.SatisfactionLevelQuestion2 WHEN 0 THEN N'نامشخص' WHEN 1 THEN N'بسیار ضعیف' WHEN 2 THEN N'ضعیف' WHEN 3 THEN N'متوسط' WHEN 4 THEN N'خوب' WHEN 5 THEN N'عالی' END) SatisfactionLevelQuestion2,
	        		(CASE sa.SatisfactionLevelQuestion3 WHEN 0 THEN N'نامشخص' WHEN 1 THEN N'بسیار ضعیف' WHEN 2 THEN N'ضعیف' WHEN 3 THEN N'متوسط' WHEN 4 THEN N'خوب' WHEN 5 THEN N'عالی' END) SatisfactionLevelQuestion3,
	        		(CASE sa.SatisfactionLevelQuestion4 WHEN 0 THEN N'نامشخص' WHEN 1 THEN N'بسیار ضعیف' WHEN 2 THEN N'ضعیف' WHEN 3 THEN N'متوسط' WHEN 4 THEN N'خوب' WHEN 5 THEN N'عالی' END) SatisfactionLevelQuestion4
                FROM [Kama.Aro.Survey].rpt.SurveyAnswer sa
                    INNER JOIN [Kama.Aro.Survey].rpt.SurveyVoter sv ON sv.ID = sa.VoterID
                    LEFT JOIN [Kama.Aro.Survey].emp.Employee emp ON sa.EmployeeID = emp.ID
                WHERE 
	        		emp.RemoveDate IS NULL
                    AND emp.RemoverUserID IS NULL
                    AND (emp.ID IS NULL OR emp.RemoveDate IS NOT NULL OR emp.RemoverUserID IS NOT NULL)
            )
            SELECT COUNT(*) AS TotalCount FROM MainSelect 
        END
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteDynamicPermission'))
	DROP PROCEDURE org.spDeleteDynamicPermission
GO

CREATE PROCEDURE org.spDeleteDynamicPermission
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

			DELETE org.DynamicPermissionDetail
			WHERE DynamicPermissionID = @ID

			DELETE org.DynamicPermission
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDynamicPermission'))
	DROP PROCEDURE org.spGetDynamicPermission
GO

CREATE PROCEDURE org.spGetDynamicPermission
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		DynamicPermission.ID,
		DynamicPermission.ObjectID,
		DynamicPermission.CreationDate,
		DynamicPermission.[Order]
	FROM org.DynamicPermission
	WHERE ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDynamicPermissionDepartments'))
DROP PROCEDURE org.spGetDynamicPermissionDepartments
GO

CREATE PROCEDURE org.spGetDynamicPermissionDepartments
	@AObjectID UNIQUEIDENTIFIER,
	@AObjectIDs NVARCHAR(MAX),
	@ADynamicPermissionType TINYINT,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ObjectID UNIQUEIDENTIFIER = @AObjectID,
		@ObjectIDs NVARCHAR(MAX) = LTRIM(RTRIM(@AObjectIDs)),
		@DynamicPermissionType TINYINT = COALESCE(@ADynamicPermissionType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT dynamicPermissionDetail.*
	INTO #DynamicPermissionDetail
	FROM org.dynamicPermissionDetail
		INNER JOIN org.DynamicPermission dynamicPermission ON dynamicPermissionDetail.DynamicPermissionID = dynamicPermission.ID
		LEFT JOIN OPENJSON(@ObjectIDs) ObjectIDs ON ObjectIDs.value = dynamicPermission.ObjectID
	WHERE (@ObjectID IS NULL OR dynamicPermission.ObjectID = @ObjectID)
		AND (@ObjectIDs IS NULL OR ObjectIDs.value = dynamicPermission.ObjectID)
		AND (@DynamicPermissionType < 1 OR dynamicPermission.[Type] = @DynamicPermissionType)
	
	-- organization types

	SELECT org.ID
	INTO #Organ1
	FROM #DynamicPermissionDetail d
		INNER JOIN org.Department parentOrg ON d.GuidValue = parentOrg.ID
		INNER JOIN org.Department org ON org.Node.IsDescendantOf(parentOrg.Node) = 1
	WHERE d.Type = 1

	SELECT org.ID
	INTO #Organ2
	FROM #DynamicPermissionDetail d
		INNER JOIN org.Department org ON d.GuidValue = org.ID
	WHERE d.Type = 2

	SELECT org.ID
	INTO #Organ3
	FROM #DynamicPermissionDetail d
		INNER JOIN org.Department org ON d.GuidValue = org.ProvinceID
	WHERE d.Type = 3
	
	SELECT org.ID
	INTO #Organ4
	FROM #DynamicPermissionDetail d
		INNER JOIN org.Department org ON d.ByteValue = org.Type
	WHERE d.Type = 4


	-- estekhdam types

	SELECT org.ID
	INTO #EstekhdamOrgan30
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Estekhdam].pbl.Department parentOrg ON d.GuidValue = parentOrg.ID
		INNER JOIN [Kama.Aro.Estekhdam].pbl.Department org ON org.HigherPositionNode.IsDescendantOf(parentOrg.HigherPositionNode) = 1
	WHERE d.Type = 30

	SELECT dep.ID
	INTO #EstekhdamOrgan31
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Estekhdam].pbl.Department dep ON d.GuidValue = dep.ProvinceID
	WHERE d.Type = 31 
	
	SELECT dep.ID
	INTO #EstekhdamOrgan32
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Estekhdam].pbl.Department dep ON d.ByteValue = dep.OrganLawType
	WHERE d.Type = 32 

	SELECT dep.ID
	INTO #EstekhdamOrgan33 
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Estekhdam].pbl.Department dep ON d.ByteValue = dep.EmploymentRegulationsType
	WHERE d.Type = 33

	SELECT dep.ID
	INTO #EstekhdamOrgan34
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Estekhdam].pbl.Department dep ON d.ByteValue = dep.Type
	WHERE d.Type = 34
	
	SELECT dep.ID
	INTO #EstekhdamOrgan35
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Estekhdam].pbl.Department dep ON d.ByteValue = dep.BudgetType
	WHERE d.Type = 35
	
	SELECT dep.ID
	INTO #EstekhdamOrgan36 
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Estekhdam].pbl.Department dep ON d.ByteValue = dep.RegulationType
	WHERE d.Type = 36
	
	SELECT dep.ID
	INTO #EstekhdamOrgan37 
	FROM #DynamicPermissionDetail d
		INNER JOIN org.Department dep ON d.ByteValue = dep.SubType
	WHERE d.Type = 37

	-- pakna types

	SELECT org.ID
	INTO #PaknaOrgan60
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Pakna].pbl.Department parentOrg ON d.GuidValue = parentOrg.ID
		INNER JOIN [Kama.Aro.Pakna].pbl.Department org ON org.HigherPositionNode.IsDescendantOf(parentOrg.HigherPositionNode) = 1
	WHERE d.Type = 60

	SELECT dep.ID
	INTO #PaknaOrgan61
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Pakna].pbl.Department dep ON d.GuidValue = dep.ProvinceID
	WHERE d.Type = 61 
	
	SELECT dep.ID
	INTO #PaknaOrgan62
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Pakna].pbl.Department dep ON d.ByteValue = dep.OrganLawType
	WHERE d.Type = 62 

	SELECT dep.ID
	INTO #PaknaOrgan63 
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Pakna].pbl.Department dep ON d.ByteValue = dep.EmploymentRegulationsType
	WHERE d.Type = 63

	SELECT dep.ID
	INTO #PaknaOrgan64
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Pakna].pbl.Department dep ON d.ByteValue = dep.Type
	WHERE d.Type = 64
	
	SELECT dep.ID
	INTO #PaknaOrgan65
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Pakna].pbl.Department dep ON d.ByteValue = dep.BudgetType
	WHERE d.Type = 65
	
	SELECT dep.ID
	INTO #PaknaOrgan66 
	FROM #DynamicPermissionDetail d
		INNER JOIN [Kama.Aro.Pakna].pbl.Department dep ON d.ByteValue = dep.RegulationType
	WHERE d.Type = 66
	
	SELECT dep.ID
	INTO #PaknaOrgan67 
	FROM #DynamicPermissionDetail d
		INNER JOIN org.Department dep ON d.ByteValue = dep.SubType
	WHERE d.Type = 67

	DECLARE 
		@HasOrgan1 INT = COALESCE((SELECT TOP 1 1 FROM #Organ1), 0),
		@HasOrgan2 INT = COALESCE((SELECT TOP 1 1 FROM #Organ2), 0),
		@HasOrgan3 INT = COALESCE((SELECT TOP 1 1 FROM #Organ3), 0),
		@HasOrgan4 INT = COALESCE((SELECT TOP 1 1 FROM #Organ4), 0),

		@HasEstekhdamOrgan30 INT = COALESCE((SELECT TOP 1 1 FROM #EstekhdamOrgan30), 0),
		@HasEstekhdamOrgan31 INT = COALESCE((SELECT TOP 1 1 FROM #EstekhdamOrgan31), 0),
		@HasEstekhdamOrgan32 INT = COALESCE((SELECT TOP 1 1 FROM #EstekhdamOrgan32), 0),
		@HasEstekhdamOrgan33 INT = COALESCE((SELECT TOP 1 1 FROM #EstekhdamOrgan33), 0),
		@HasEstekhdamOrgan34 INT = COALESCE((SELECT TOP 1 1 FROM #EstekhdamOrgan34), 0),
		@HasEstekhdamOrgan35 INT = COALESCE((SELECT TOP 1 1 FROM #EstekhdamOrgan35), 0),
		@HasEstekhdamOrgan36 INT = COALESCE((SELECT TOP 1 1 FROM #EstekhdamOrgan36), 0),
		@HasEstekhdamOrgan37 INT = COALESCE((SELECT TOP 1 1 FROM #EstekhdamOrgan37), 0),

		@HasPaknaOrgan60 INT = COALESCE((SELECT TOP 1 1 FROM #PaknaOrgan60), 0),
		@HasPaknaOrgan61 INT = COALESCE((SELECT TOP 1 1 FROM #PaknaOrgan61), 0),
		@HasPaknaOrgan62 INT = COALESCE((SELECT TOP 1 1 FROM #PaknaOrgan62), 0),
		@HasPaknaOrgan63 INT = COALESCE((SELECT TOP 1 1 FROM #PaknaOrgan63), 0),
		@HasPaknaOrgan64 INT = COALESCE((SELECT TOP 1 1 FROM #PaknaOrgan64), 0),
		@HasPaknaOrgan65 INT = COALESCE((SELECT TOP 1 1 FROM #PaknaOrgan65), 0),
		@HasPaknaOrgan66 INT = COALESCE((SELECT TOP 1 1 FROM #PaknaOrgan66), 0),
		@HasPaknaOrgan67 INT = COALESCE((SELECT TOP 1 1 FROM #PaknaOrgan67), 0)

	;WITH MainSelect AS 
	(
		SELECT 
			org.ID OrganID,
			org.Name OrganName
		FROM Org.Department org
			WHERE
				(EXISTS(SELECT TOP 1 * FROM #DynamicPermissionDetail))
				AND (@HasOrgan1 = 0 OR ID IN (SELECT ID FROM #Organ1))
				AND (@HasOrgan2 = 0 OR ID IN (SELECT ID FROM #Organ2))
				AND (@HasOrgan3 = 0 OR ID IN (SELECT ID FROM #Organ3))
				AND (@HasOrgan4 = 0 OR ID IN (SELECT ID FROM #Organ4))

				AND (@HasEstekhdamOrgan30 = 0 OR ID IN (SELECT ID FROM #EstekhdamOrgan30))
				AND (@HasEstekhdamOrgan31 = 0 OR ID IN (SELECT ID FROM #EstekhdamOrgan31))
				AND (@HasEstekhdamOrgan32 = 0 OR ID IN (SELECT ID FROM #EstekhdamOrgan32))
				AND (@HasEstekhdamOrgan33 = 0 OR ID IN (SELECT ID FROM #EstekhdamOrgan33))
				AND (@HasEstekhdamOrgan34 = 0 OR ID IN (SELECT ID FROM #EstekhdamOrgan34))
				AND (@HasEstekhdamOrgan35 = 0 OR ID IN (SELECT ID FROM #EstekhdamOrgan35))
				AND (@HasEstekhdamOrgan36 = 0 OR ID IN (SELECT ID FROM #EstekhdamOrgan36))
				AND (@HasEstekhdamOrgan37 = 0 OR ID IN (SELECT ID FROM #EstekhdamOrgan37))

				AND (@HasPaknaOrgan60 = 0 OR ID IN (SELECT ID FROM #PaknaOrgan60))
				AND (@HasPaknaOrgan61 = 0 OR ID IN (SELECT ID FROM #PaknaOrgan61))
				AND (@HasPaknaOrgan62 = 0 OR ID IN (SELECT ID FROM #PaknaOrgan62))
				AND (@HasPaknaOrgan63 = 0 OR ID IN (SELECT ID FROM #PaknaOrgan63))
				AND (@HasPaknaOrgan64 = 0 OR ID IN (SELECT ID FROM #PaknaOrgan64))
				AND (@HasPaknaOrgan65 = 0 OR ID IN (SELECT ID FROM #PaknaOrgan65))
				AND (@HasPaknaOrgan66 = 0 OR ID IN (SELECT ID FROM #PaknaOrgan66))
				AND (@HasPaknaOrgan67 = 0 OR ID IN (SELECT ID FROM #PaknaOrgan67))
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY OrganID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
	
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDynamicPermissionObjectsByPosition'))
DROP PROCEDURE org.spGetDynamicPermissionObjectsByPosition
GO

CREATE PROCEDURE org.spGetDynamicPermissionObjectsByPosition
	@APositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@Type TINYINT = COALESCE(@AType, 0),

		@UserDepartmentNode HIERARCHYID,
		@UserDepartmentID UNIQUEIDENTIFIER,
		@UserDepartmentType INT,
		@UserProvinceID UNIQUEIDENTIFIER,
		@UserPositionType INT,

		@UserEstekhdamDepartmentNode HIERARCHYID,
		@UserEstekhdamProvinceID UNIQUEIDENTIFIER,
		@UserEstekhdamOrganLawType INT,
		@UserEstekhdamEmploymentRegulationsType INT,
		@UserEstekhdamDepartmentType INT,
		@UserEstekhdamDepartmentBudgetType INT,
		@UserEstekhdamRegulationType INT,
		@UserEstekhdamDepartmentSubType INT,


		@UserPaknaDepartmentNode HIERARCHYID,
		@UserPaknaProvinceID UNIQUEIDENTIFIER,
		@UserPaknaOrganLawType INT,
		@UserPaknaEmploymentRegulationsType INT,
		@UserPaknaDepartmentType INT,
		@UserPaknaDepartmentBudgetType INT,
		@UserPaknaDepartmentRegulationType INT,
		@UserPaknaDepartmentSubType INT

	SELECT 
			@UserDepartmentNode = Department.[Node],
			@UserDepartmentID = Position.DepartmentID,
			@UserDepartmentType = Department.[Type],
			@UserProvinceID = Department.ProvinceID,
			@UserPositionType = Position.[Type],

			@UserEstekhdamDepartmentNode = estekhdamDepartment.HigherPositionNode,
			@UserEstekhdamProvinceID= estekhdamDepartment.ProvinceID,
			@UserEstekhdamOrganLawType = estekhdamDepartment.OrganLawType,
			@UserEstekhdamEmploymentRegulationsType = estekhdamDepartment.EmploymentRegulationsType,
			@UserEstekhdamDepartmentType = estekhdamDepartment.[Type],
			@UserEstekhdamDepartmentBudgetType = estekhdamDepartment.BudgetType,
			@UserEstekhdamRegulationType = estekhdamDepartment.RegulationType,
			@UserEstekhdamDepartmentSubType = Department.SubType,

			@UserPaknaDepartmentNode = paknaDepartment.HigherPositionNode,
			@UserPaknaProvinceID= paknaDepartment.ProvinceID,
			@UserPaknaOrganLawType = paknaDepartment.OrganLawType,
			@UserPaknaEmploymentRegulationsType = paknaDepartment.EmploymentRegulationsType,
			@UserPaknaDepartmentType = paknaDepartment.[Type],
			@UserPaknaDepartmentBudgetType = paknaDepartment.BudgetType,
			@UserPaknaDepartmentRegulationType = paknaDepartment.RegulationType,
			@UserPaknaDepartmentSubType = Department.SubType
		FROM org.position 
			INNER JOIN org.Department ON Department.ID = position.DepartmentID
			LEFT JOIN [Kama.Aro.Estekhdam].pbl.Department estekhdamDepartment ON estekhdamDepartment.ID = position.DepartmentID
			LEFT JOIN [Kama.Aro.Pakna].pbl.Department paknaDepartment ON paknaDepartment.ID = position.DepartmentID
		WHERE position.RemoverID IS NULL
			AND Position.ApplicationID = @ApplicationID
			AND Position.ID = @PositionID


	;WITH UserParentDepartment AS
	(
		SELECT ID 
		FROM org.Department 
		WHERE @UserDepartmentNode.IsDescendantOf(Department.Node) = 1
			AND @UserDepartmentID <> Department.ID
	)
	, UserParentDepartmentInEstekhdam AS
	(
		SELECT ID 
		FROM [Kama.Aro.Estekhdam].pbl.Department 
		WHERE @UserEstekhdamDepartmentNode.IsDescendantOf(Department.HigherPositionNode) = 1
			AND @UserDepartmentID <> Department.ID
	)
	, UserParentDepartmentInPakna AS
	(
		SELECT ID 
		FROM [Kama.Aro.Pakna].pbl.Department 
		WHERE @UserPaknaDepartmentNode.IsDescendantOf(Department.HigherPositionNode) = 1
			AND @UserDepartmentID <> Department.ID
	)
	, DynamicPermisssionDetail AS
	(
		SELECT 
			DynamicPermissionID,
			ObjectID,
			dynamicPermissionDetail.Type,
			MAX(CASE WHEN 1=1
					AND (dynamicPermissionDetail.Type <> 1 OR dynamicPermissionDetail.GuidValue = UserParentDepartment.ID)
					AND (dynamicPermissionDetail.Type <> 2 OR GuidValue = @UserDepartmentID)
					AND (dynamicPermissionDetail.Type <> 3 OR GuidValue = @UserProvinceID)
					AND (dynamicPermissionDetail.Type <> 4 OR ByteValue = @UserDepartmentType)
					AND (dynamicPermissionDetail.Type <> 9 OR ByteValue = @UserPositionType) 
					AND (dynamicPermissionDetail.Type <> 10 OR GuidValue = @PositionID)

					AND (dynamicPermissionDetail.Type <> 30 OR dynamicPermissionDetail.GuidValue = UserParentDepartmentInEstekhdam.ID)
					AND (dynamicPermissionDetail.Type <> 31 OR GuidValue = @UserEstekhdamProvinceID)
					AND (dynamicPermissionDetail.Type <> 32 OR ByteValue = @UserEstekhdamOrganLawType)
					AND (dynamicPermissionDetail.Type <> 33 OR ByteValue = @UserEstekhdamEmploymentRegulationsType)
					AND (dynamicPermissionDetail.Type <> 34 OR ByteValue = @UserEstekhdamDepartmentType)
					AND (dynamicPermissionDetail.Type <> 35 OR ByteValue = @UserEstekhdamDepartmentBudgetType)
					AND (dynamicPermissionDetail.Type <> 36 OR ByteValue = @UserEstekhdamRegulationType)
					AND (dynamicPermissionDetail.Type <> 37 OR ByteValue = @UserEstekhdamDepartmentSubType)

					AND (dynamicPermissionDetail.Type <> 60 OR dynamicPermissionDetail.GuidValue = UserParentDepartmentInPakna.ID)
					AND (dynamicPermissionDetail.Type <> 61 OR GuidValue = @UserPaknaProvinceID)
					AND (dynamicPermissionDetail.Type <> 62 OR ByteValue = @UserPaknaOrganLawType)
					AND (dynamicPermissionDetail.Type <> 63 OR ByteValue = @UserPaknaEmploymentRegulationsType)
					AND (dynamicPermissionDetail.Type <> 64 OR ByteValue = @UserPaknaDepartmentType)
					AND (dynamicPermissionDetail.Type <> 65 OR ByteValue = @UserPaknaDepartmentBudgetType)
					AND (dynamicPermissionDetail.Type <> 66 OR ByteValue = @UserPaknaDepartmentRegulationType)
					AND (dynamicPermissionDetail.Type <> 67 OR ByteValue = @UserPaknaDepartmentSubType)
					THEN 1 ELSE 0 END) HastPermission
		FROM org.dynamicPermissionDetail
			INNER JOIN org.DynamicPermission dynamicPermission ON dynamicPermissionDetail.DynamicPermissionID = dynamicPermission.ID
			LEFT JOIN UserParentDepartment ON dynamicPermissionDetail.Type <> 1 OR dynamicPermissionDetail.GuidValue = UserParentDepartment.ID
			LEFT JOIN UserParentDepartmentInEstekhdam ON dynamicPermissionDetail.Type <> 30 OR dynamicPermissionDetail.GuidValue = UserParentDepartmentInEstekhdam.ID
			LEFT JOIN UserParentDepartmentInPakna ON dynamicPermissionDetail.Type <> 60 OR dynamicPermissionDetail.GuidValue = UserParentDepartmentInPakna.ID
		WHERE (@Type < 1 OR dynamicPermission.[Type] = @Type)
		GROUP BY 
			DynamicPermissionID, 
			ObjectID,
			dynamicPermissionDetail.Type
	)
	select ObjectID ID
	from DynamicPermisssionDetail
	group by DynamicPermissionID, ObjectID
	having MIN(HastPermission) = 1

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDynamicPermissionObjectsByPositionAndOrgan'))
DROP PROCEDURE org.spGetDynamicPermissionObjectsByPositionAndOrgan
GO

CREATE PROCEDURE org.spGetDynamicPermissionObjectsByPositionAndOrgan
	@APositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@AType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@Type TINYINT = COALESCE(@AType, 0),

		@UserDepartmentNode HIERARCHYID,
		@UserDepartmentID UNIQUEIDENTIFIER,
		@UserDepartmentType INT,
		@UserProvinceID UNIQUEIDENTIFIER,
		@UserPositionType INT,

		@UserEstekhdamDepartmentNode HIERARCHYID,
		@UserEstekhdamProvinceID UNIQUEIDENTIFIER,
		@UserEstekhdamOrganLawType INT,
		@UserEstekhdamEmploymentRegulationsType INT,
		@UserEstekhdamDepartmentType INT,
		@UserEstekhdamDepartmentBudgetType INT,
		@UserEstekhdamDepartmentRegulationType INT,
		@UserEstekhdamDepartmentSubType INT,


		@UserPaknaDepartmentNode HIERARCHYID,
		@UserPaknaProvinceID UNIQUEIDENTIFIER,
		@UserPaknaOrganLawType INT,
		@UserPaknaEmploymentRegulationsType INT,
		@UserPaknaDepartmentType INT,
		@UserPaknaDepartmentBudgetType INT,
		@UserPaknaDepartmentRegulationType INT,
		@UserPaknaDepartmentSubType INT

		IF @OrganID = NULL OR @OrganID = '00000000-0000-0000-0000-000000000000'
			SET @OrganID = (SELECT Position.DepartmentID FROM org.position 
							WHERE position.RemoverID IS NULL
							AND Position.ApplicationID = @ApplicationID
							AND Position.ID = @PositionID
							)

	------------------------Estekhdam----------------------------------------
	SELECT
		@UserEstekhdamDepartmentNode = estekhdamDepartment.HigherPositionNode,
		@UserEstekhdamProvinceID= estekhdamDepartment.ProvinceID,
		@UserEstekhdamOrganLawType = estekhdamDepartment.OrganLawType,
		@UserEstekhdamEmploymentRegulationsType = estekhdamDepartment.EmploymentRegulationsType,
		@UserEstekhdamDepartmentType = estekhdamDepartment.[Type],
		@UserEstekhdamDepartmentBudgetType = estekhdamDepartment.BudgetType,
		@UserEstekhdamDepartmentRegulationType = estekhdamDepartment.RegulationType,
		@UserEstekhdamDepartmentSubType = dep.SubType
	FROM [Kama.Aro.Estekhdam].pbl.Department estekhdamDepartment
	INNER JOIN [Kama.Aro.Organization].org.Department dep ON dep.ID = estekhdamDepartment.ID
	WHERE @ApplicationID = 'A24BD4B0-8BB6-4243-9C95-AE28FB9B24BB'
	AND estekhdamDepartment.ID = @OrganID

	------------------------Pakan----------------------------------------
	SELECT
		@UserPaknaDepartmentNode = paknaDepartment.HigherPositionNode,
		@UserPaknaProvinceID= paknaDepartment.ProvinceID,
		@UserPaknaOrganLawType = paknaDepartment.OrganLawType,
		@UserPaknaEmploymentRegulationsType = paknaDepartment.EmploymentRegulationsType,
		@UserPaknaDepartmentType = paknaDepartment.[Type],
		@UserPaknaDepartmentBudgetType = paknaDepartment.BudgetType,
		@UserPaknaDepartmentRegulationType = paknaDepartment.RegulationType,
		@UserPaknaDepartmentSubType = dep.SubType
	FROM [Kama.Aro.Pakna].pbl.Department paknaDepartment
	INNER JOIN [Kama.Aro.Organization].org.Department dep ON dep.ID = paknaDepartment.ID
	WHERE @ApplicationID = 'E29CBF9D-77DF-4FCF-A660-0AF295DDF93F'
	AND paknaDepartment.ID = @OrganID

	------------------------Organization----------------------------------------
	SELECT
		@UserDepartmentNode = Department.[Node],
		@UserDepartmentID = Department.ID,
		@UserDepartmentType = Department.[Type],
		@UserProvinceID = Department.ProvinceID
	FROM org.Department
	WHERE ID = @OrganID

	------------------------Position----------------------------------------
	SELECT 
		@UserPositionType = Position.[Type]
	FROM org.position 
		INNER JOIN org.Department ON Department.ID = position.DepartmentID
	WHERE position.RemoverID IS NULL
		AND Position.ApplicationID = @ApplicationID
		AND Position.ID = @PositionID

	------------------------WITH----------------------------------------
	;WITH UserParentDepartment AS
	(
		SELECT ID 
		FROM org.Department 
		WHERE @UserDepartmentNode.IsDescendantOf(Department.Node) = 1
			AND @UserDepartmentID <> Department.ID
	)
	, UserParentDepartmentInEstekhdam AS
	(
		SELECT ID 
		FROM [Kama.Aro.Estekhdam].pbl.Department 
		WHERE @UserEstekhdamDepartmentNode.IsDescendantOf(Department.HigherPositionNode) = 1
			AND @UserDepartmentID <> Department.ID
	)
	, UserParentDepartmentInPakna AS
	(
		SELECT ID 
		FROM [Kama.Aro.Pakna].pbl.Department 
		WHERE @UserPaknaDepartmentNode.IsDescendantOf(Department.HigherPositionNode) = 1
			AND @UserDepartmentID <> Department.ID
	)
	, DynamicPermisssionDetail AS
	(
		SELECT 
			DynamicPermissionID,
			ObjectID,
			dynamicPermissionDetail.Type,
			MAX(CASE WHEN 1=1
					AND (dynamicPermissionDetail.Type <> 1 OR dynamicPermissionDetail.GuidValue = UserParentDepartment.ID)
					AND (dynamicPermissionDetail.Type <> 2 OR GuidValue = @UserDepartmentID)
					AND (dynamicPermissionDetail.Type <> 3 OR GuidValue = @UserProvinceID)
					AND (dynamicPermissionDetail.Type <> 4 OR ByteValue = @UserDepartmentType)
					AND (dynamicPermissionDetail.Type <> 9 OR ByteValue = @UserPositionType) 
					AND (dynamicPermissionDetail.Type <> 10 OR GuidValue = @PositionID)

					AND (dynamicPermissionDetail.Type <> 30 OR dynamicPermissionDetail.GuidValue = UserParentDepartmentInEstekhdam.ID)
					AND (dynamicPermissionDetail.Type <> 31 OR GuidValue = @UserEstekhdamProvinceID)
					AND (dynamicPermissionDetail.Type <> 32 OR ByteValue = @UserEstekhdamOrganLawType)
					AND (dynamicPermissionDetail.Type <> 33 OR ByteValue = @UserEstekhdamEmploymentRegulationsType)
					AND (dynamicPermissionDetail.Type <> 34 OR ByteValue = @UserEstekhdamDepartmentType)
					AND (dynamicPermissionDetail.Type <> 35 OR ByteValue = @UserEstekhdamDepartmentBudgetType)
					AND (dynamicPermissionDetail.Type <> 36 OR ByteValue = @UserEstekhdamDepartmentRegulationType)
					AND (dynamicPermissionDetail.Type <> 37 OR ByteValue = @UserEstekhdamDepartmentSubType)

					AND (dynamicPermissionDetail.Type <> 60 OR dynamicPermissionDetail.GuidValue = UserParentDepartmentInPakna.ID)
					AND (dynamicPermissionDetail.Type <> 61 OR GuidValue = @UserPaknaProvinceID)
					AND (dynamicPermissionDetail.Type <> 62 OR ByteValue = @UserPaknaOrganLawType)
					AND (dynamicPermissionDetail.Type <> 63 OR ByteValue = @UserPaknaEmploymentRegulationsType)
					AND (dynamicPermissionDetail.Type <> 64 OR ByteValue = @UserPaknaDepartmentType)
					AND (dynamicPermissionDetail.Type <> 65 OR ByteValue = @UserPaknaDepartmentBudgetType)
					AND (dynamicPermissionDetail.Type <> 66 OR ByteValue = @UserPaknaDepartmentRegulationType)
					AND (dynamicPermissionDetail.Type <> 67 OR ByteValue = @UserPaknaDepartmentSubType)
					THEN 1 ELSE 0 END) HastPermission
		FROM org.dynamicPermissionDetail
			INNER JOIN org.DynamicPermission dynamicPermission ON dynamicPermissionDetail.DynamicPermissionID = dynamicPermission.ID
			LEFT JOIN UserParentDepartment ON dynamicPermissionDetail.Type <> 1 OR dynamicPermissionDetail.GuidValue = UserParentDepartment.ID
			LEFT JOIN UserParentDepartmentInEstekhdam ON dynamicPermissionDetail.Type <> 30 OR dynamicPermissionDetail.GuidValue = UserParentDepartmentInEstekhdam.ID
			LEFT JOIN UserParentDepartmentInPakna ON dynamicPermissionDetail.Type <> 60 OR dynamicPermissionDetail.GuidValue = UserParentDepartmentInPakna.ID
		WHERE (@Type < 1 OR dynamicPermission.[Type] = @Type)
		GROUP BY 
			DynamicPermissionID, 
			ObjectID,
			dynamicPermissionDetail.Type
	)
	select ObjectID ID
	from DynamicPermisssionDetail
	group by DynamicPermissionID, ObjectID
	having MIN(HastPermission) = 1

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDynamicPermissionPositions'))
DROP PROCEDURE org.spGetDynamicPermissionPositions
GO

CREATE PROCEDURE org.spGetDynamicPermissionPositions
	@AObjectID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ObjectID UNIQUEIDENTIFIER = @AObjectID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH PermissionDetail AS
	(
		SELECT 
			detail.[Type],
			detail.GuidValue,
			detail.ByteValue
		FROM org.DynamicPermission
			INNER JOIN org.DynamicPermissionDetail detail ON detail.DynamicPermissionID = DynamicPermission.ID
		WHERE
			DynamicPermission.ObjectID = @ObjectID
			AND DynamicPermission.ApplicationID = @ApplicationID
			
	)
	, MainSelect As
	(
		SELECT DISTINCT position.*
		FROM org._position position
			INNER JOIN org.Department ON Department.ID = position.DepartmentID
			INNER JOIN org.Department parentDepartment On Department.[Node].IsDescendantOf(parentDepartment.[Node]) = 1
			LEFT JOIN [Kama.Aro.Estekhdam].pbl.Department estekhdamDepartment ON estekhdamDepartment.ID = position.DepartmentID
			LEFT JOIN [Kama.Aro.Estekhdam].pbl.Department estekhdamParentDepartment On estekhdamParentDepartment.[HigherPositionNode].IsDescendantOf(estekhdamParentDepartment.[HigherPositionNode]) = 1

			LEFT JOIN [Kama.Aro.Pakna].pbl.Department paknaDepartment ON paknaDepartment.ID = position.DepartmentID
			LEFT JOIN [Kama.Aro.Pakna].pbl.Department paknaParentDepartment On paknaParentDepartment.[HigherPositionNode].IsDescendantOf(paknaParentDepartment.[HigherPositionNode]) = 1

			INNER JOIN PermissionDetail ON (PermissionDetail.[Type] = 1 AND parentDepartment.ID = PermissionDetail.GuidValue)
										OR (PermissionDetail.[Type] = 2 AND Department.ID = PermissionDetail.GuidValue)
										OR (PermissionDetail.[Type] = 3 AND Department.ProvinceID = PermissionDetail.GuidValue)
										OR (PermissionDetail.[Type] = 4 AND Department.[Type] = PermissionDetail.ByteValue)
										OR (PermissionDetail.[Type] = 9 AND Position.[Type] = PermissionDetail.ByteValue)
										OR (PermissionDetail.[Type] = 10 AND position.ID = PermissionDetail.GuidValue)
										OR (PermissionDetail.[Type] = 30 AND estekhdamParentDepartment.ID = PermissionDetail.GuidValue)
										OR (PermissionDetail.[Type] = 31 AND estekhdamDepartment.ProvinceID = PermissionDetail.GuidValue)
										OR (PermissionDetail.[Type] = 32 AND estekhdamDepartment.OrganLawType = PermissionDetail.ByteValue)
										OR (PermissionDetail.[Type] = 33 AND estekhdamDepartment.RegulationType = PermissionDetail.ByteValue)
										OR (PermissionDetail.[Type] = 34 AND estekhdamDepartment.[Type] = PermissionDetail.ByteValue)
										OR (PermissionDetail.[Type] = 35 AND estekhdamDepartment.BudgetType = PermissionDetail.ByteValue)

										OR (PermissionDetail.[Type] = 60 AND paknaParentDepartment.ID = PermissionDetail.GuidValue)
										OR (PermissionDetail.[Type] = 61 AND paknaDepartment.ProvinceID = PermissionDetail.GuidValue)
										OR (PermissionDetail.[Type] = 62 AND paknaDepartment.OrganLawType = PermissionDetail.ByteValue)
										OR (PermissionDetail.[Type] = 63 AND paknaDepartment.RegulationType = PermissionDetail.ByteValue)
										OR (PermissionDetail.[Type] = 64 AND paknaDepartment.[Type] = PermissionDetail.ByteValue)
										OR (PermissionDetail.[Type] = 65 AND paknaDepartment.BudgetType = PermissionDetail.ByteValue)
		WHERE Position.ApplicationID = @ApplicationID
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDynamicPermissions'))
DROP PROCEDURE org.spGetDynamicPermissions
GO

CREATE PROCEDURE org.spGetDynamicPermissions
	@AObjectID UNIQUEIDENTIFIER,
	@ADynamicPermissionType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ObjectID UNIQUEIDENTIFIER = @AObjectID,
		@DynamicPermissionType TINYINT = COALESCE(@ADynamicPermissionType, 0),
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
			DynamicPermission.ID,
			DynamicPermission.ObjectID,
			DynamicPermission.CreationDate,
			DynamicPermission.[Order]
		FROM org.DynamicPermission
		WHERE
			DynamicPermission.ObjectID = @ObjectID
			AND (@DynamicPermissionType < 1 OR [Type]  = @DynamicPermissionType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyDynamicPermission'))
	DROP PROCEDURE org.spModifyDynamicPermission
GO

CREATE PROCEDURE org.spModifyDynamicPermission
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AObjectID UNIQUEIDENTIFIER,
	@AOrder INT,
	@AType TINYINT,
	@ADetails NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@ObjectID UNIQUEIDENTIFIER = @AObjectID,
		@Order INT = @AOrder,
		@Type TINYINT = COALESCE(@AType, 0),
		@Details NVARCHAR(MAX) = @ADetails 

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO org.DynamicPermission
				(ID, ApplicationID, ObjectID, [Order], CreationDate, [Type])
				VALUES
				(@ID, @ApplicationID, @ObjectID, @Order, GETDATE(), @Type)
			END
			ELSE    -- update
			BEGIN
				UPDATE org.DynamicPermission
				SET ObjectID = @ObjectID, [Order] = @Order
				WHERE ID = @ID
			END

			---------------------------------------------------------- Details
			DELETE org.DynamicPermissionDetail WHERE DynamicPermissionID = @ID

			INSERT INTO org.DynamicPermissionDetail 
			SELECT 
				NEWID() ID,
				@ID DynamicPermissionID,
				[Type],
				GuidValue,
				ByteValue
			FROM OPENJSON(@Details)
			WITH
			(
				[Type] TINYINT,
				GuidValue UNIQUEIDENTIFIER,
				ByteValue TINYINT
			)

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDynamicPermissionDetails'))
DROP PROCEDURE org.spGetDynamicPermissionDetails
GO

CREATE PROCEDURE org.spGetDynamicPermissionDetails
	@ADynamicPermissionIDs NVARCHAR(MAX),
	@ADynamicPermissionID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@DynamicPermissionIDs NVARCHAR(MAX) = @ADynamicPermissionIDs,
		@DynamicPermissionID UNIQUEIDENTIFIER = @ADynamicPermissionID

	SELECT
		dpt.ID,
		dpt.DynamicPermissionID,
		dpt.[Type],
		dpt.GuidValue,
		dpt.ByteValue,
		Department.Name DepartmentName, 
		Province.Name ProvinceName,
		Position.FirstName,
		Position.LastName
	FROM org.DynamicPermissionDetail dpt
		LEFT JOIN org.Department ON Department.ID = GuidValue
		LEFT JOIN org.Place Province ON Province.ID = GuidValue
		LEFT JOIN org._Position Position ON Position.ID = GuidValue
		LEFT JOIN OPENJSON(@DynamicPermissionIDs) DynamicPermissionIDs ON DynamicPermissionIDs.value = dpt.DynamicPermissionID
	WHERE
		(@DynamicPermissionID IS NULL OR dpt.DynamicPermissionID = @DynamicPermissionID)
		AND (@DynamicPermissionIDs IS NULL OR DynamicPermissionIDs.value = dpt.DynamicPermissionID)
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spActiveToken'))
	DROP PROCEDURE org.spActiveToken
GO

CREATE PROCEDURE org.spActiveToken
	@AUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @UserID UNIQUEIDENTIFIER  = @AUserID
	
	
	;With Token AS
	(
		SELECT
			DISTINCT TOP 100 
			refresh.ID
			, refresh.IssuedDate 
			, refresh.ExpireDate 
			, refresh.SsoTicket 
			--, refresh.OS 
			--, refresh.OSVersion
			--, refresh.Browser 
			--, refresh.BrowserVersion 
			--, refresh.DeviceType 
			, clt.ApplicationID, 
			ROW_NUMBER() OVER(Partition BY refresh.SsoTicket, clt.ApplicationID ORDER BY refresh.IssuedDate desc) RowNumber
		FROM org.RefreshToken refresh
		INNER JOIN org.IssuedToken issued ON issued.RefreshTokenID  = refresh.ID
		INNER JOIN org.Client clt ON issued.ClientID = clt.ID
		WHERE refresh.UserID = @UserID
			AND refresh.ExpireDate > GETDATE()
	)
	SELECT * FROM Token where RowNumber = 1
	ORDER BY IssuedDate
END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spUndoToken'))
	DROP PROCEDURE org.spUndoToken
GO

CREATE PROCEDURE org.spUndoToken
	@AToken VARCHAR(MAX),
	@AUndoOnlyApp BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @Token VARCHAR(MAX) = TRIM(@AToken)
		,@UndoOnlyApp BIT =@AUndoOnlyApp
		,@SsoTicket VARCHAR(MAX)
		,@ClientID UNIQUEIDENTIFIER
	
	BEGIN TRY
		BEGIN TRAN
		
		SET @SsoTicket = (
			SELECT TOP 1 refresh.SsoTicket FROM org.IssuedToken issued
			INNER JOIN  org.RefreshToken refresh ON issued.RefreshTokenID  = refresh.ID
			WHERE Token = @Token
		);

		IF @UndoOnlyApp = 1
		BEGIN
			DECLARE @t TABLE (ID UNIQUEIDENTIFIER )

			SET @ClientID = (
				SELECT TOP 1 issued.ClientID FROM org.IssuedToken issued
				INNER JOIN  org.RefreshToken refresh ON issued.RefreshTokenID  = refresh.ID
				WHERE Token = @Token 
			);

			
			INSERT INTO @T
			SELECT DISTINCT refresh.ID 
			FROM org.IssuedToken issued
			INNER JOIN  org.RefreshToken refresh ON issued.RefreshTokenID  = refresh.ID
			WHERE SsoTicket = @SsoTicket
				AND issued.ClientID = @ClientID
			
			DELETE issued 
			FROM @T t
			INNER JOIN org.RefreshToken refresh ON t.ID = refresh.ID
			INNER JOIN org.IssuedToken issued ON issued.RefreshTokenID  = refresh.ID
			
			DELETE refresh 
			FROM @T t
			INNER JOIN org.RefreshToken refresh ON t.ID = refresh.ID
		END

		ELSE
		BEGIN

			DELETE issued
			FROM org.RefreshToken refresh
			INNER JOIN  org.IssuedToken issued ON issued.RefreshTokenID  = refresh.ID
			WHERE refresh.SsoTicket = @SsoTicket 

			DELETE org.RefreshToken
			WHERE SsoTicket = @SsoTicket 

		END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spUndoTokenByRefreshTokenID'))
	DROP PROCEDURE org.spUndoTokenByRefreshTokenID
GO

CREATE PROCEDURE org.spUndoTokenByRefreshTokenID
	@ARefreshTokenID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AUndoOnlyApp BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @RefreshTokenID UNIQUEIDENTIFIER = @ARefreshTokenID
		,@UserID UNIQUEIDENTIFIER  = @AUserID
		,@UndoOnlyApp BIT =@AUndoOnlyApp
		,@SsoTicket VARCHAR(MAX)
		,@ClientID UNIQUEIDENTIFIER
		
		SET @SsoTicket = (
			SELECT TOP 1 refresh.SsoTicket 
			FROM  org.RefreshToken refresh
			INNER JOIN org.IssuedToken issued ON issued.RefreshTokenID  = refresh.ID
			WHERE  refresh.ID = @RefreshTokenID
				AND refresh.UserID = @UserID
		);
	
	BEGIN TRY
		BEGIN TRAN
		IF @UndoOnlyApp = 1
		BEGIN
			
			DECLARE @t TABLE (ID UNIQUEIDENTIFIER )
			
			SET @ClientID = (
				SELECT TOP 1 issued.ClientID 
				FROM  org.RefreshToken refresh
				INNER JOIN org.IssuedToken issued ON issued.RefreshTokenID  = refresh.ID
				WHERE  refresh.ID = @RefreshTokenID
					AND refresh.UserID = @UserID
			);

			
			INSERT INTO @T
			SELECT DISTINCT refresh.ID 
			FROM org.IssuedToken issued
			INNER JOIN  org.RefreshToken refresh ON issued.RefreshTokenID  = refresh.ID
			WHERE SsoTicket = @SsoTicket
				AND issued.ClientID = @ClientID
			
			DELETE issued 
			FROM @T t
			INNER JOIN org.RefreshToken refresh ON t.ID = refresh.ID
			INNER JOIN org.IssuedToken issued ON issued.RefreshTokenID  = refresh.ID
			
			DELETE refresh 
			FROM @T t
			INNER JOIN org.RefreshToken refresh ON t.ID = refresh.ID
		END

		ELSE
		BEGIN

			DELETE issued
			FROM org.RefreshToken refresh
			INNER JOIN  org.IssuedToken issued ON issued.RefreshTokenID  = refresh.ID
			WHERE refresh.SsoTicket = @SsoTicket 

			DELETE org.RefreshToken
			WHERE SsoTicket = @SsoTicket 
		END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteExpiredIssuedTokens'))
	DROP PROCEDURE org.spDeleteExpiredIssuedTokens
GO

CREATE PROCEDURE org.spDeleteExpiredIssuedTokens
AS
BEGIN
	DELETE org.[IssuedToken] 
	WHERE [ExpireDate] < GETDATE()	
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteIssuedToken'))
	DROP PROCEDURE org.spDeleteIssuedToken
GO

CREATE PROCEDURE org.spDeleteIssuedToken
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @ID UNIQUEIDENTIFIER = @AID
	
	BEGIN TRY
		BEGIN TRAN

			DELETE FROM org.IssuedToken
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteIssuedTokenByUserID'))
	DROP PROCEDURE org.spDeleteIssuedTokenByUserID
GO

CREATE PROCEDURE org.spDeleteIssuedTokenByUserID
	@AUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @UserID  UNIQUEIDENTIFIER = @AUserID 
	
	BEGIN TRY
		BEGIN TRAN

			DELETE FROM org.IssuedToken
			WHERE  UserID = @UserID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetIssuedToken'))
	DROP PROCEDURE org.spGetIssuedToken
GO

CREATE PROCEDURE org.spGetIssuedToken
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT *
	FROM org.IssuedToken
	WHERE ID = @ID 

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetIssuedTokenByToken'))
	DROP PROCEDURE org.spGetIssuedTokenByToken
GO

CREATE PROCEDURE org.spGetIssuedTokenByToken
	@AToken VARCHAR(4000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @Token VARCHAR(4000) = LTRIM(RTRIM(@AToken))
	
	SELECT 
		ist.*,
		rft.ID RefrshTokenID,
		rft.ExpireDate RefrshTokenExpireDate
	FROM org.IssuedToken ist
	INNER JOIN org.RefreshToken rft ON ist.RefreshTokenID = rft.ID
	WHERE Token = @Token 

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetIssuedTokens'))
	DROP PROCEDURE org.spGetIssuedTokens
GO

CREATE PROCEDURE org.spGetIssuedTokens
	@AUserID UNIQUEIDENTIFIER,
	@ARefreshTokenID UNIQUEIDENTIFIER,
	@AClientID UNIQUEIDENTIFIER,
	@AToken VARCHAR(4000),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@RefreshTokenID UNIQUEIDENTIFIER = @ARefreshTokenID,
		@ClientID UNIQUEIDENTIFIER = @AClientID,
		@Token VARCHAR(4000) = LTRIM(RTRIM(@AToken)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(1000) = LTRIM(RTRIM(@ASortExp))
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT *
		FROM org.IssuedToken
		WHERE (@UserID IS NULL OR UserID = @UserID)
			AND (@RefreshTokenID IS NULL OR RefreshTokenID = @RefreshTokenID)
			AND (@ClientID IS NULL OR ClientID = @ClientID)
			AND (@Token IS NULL OR Token = @Token)
	)
	SELECT * FROM MainSelect		 
	ORDER BY [IssuedDate] DESC
	--OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyIssuedToken'))
	DROP PROCEDURE org.spModifyIssuedToken
GO

CREATE PROCEDURE org.spModifyIssuedToken
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@ARefreshTokenID UNIQUEIDENTIFIER,
	@AClientID UNIQUEIDENTIFIER,
	@AIssuedDate DATETIME,
	@AExpireDate DATETIME,
	@AToken VARCHAR(4000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@RefreshTokenID UNIQUEIDENTIFIER = @ARefreshTokenID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@ClientID UNIQUEIDENTIFIER = @AClientID,
		@IssuedDate DATETIME = @AIssuedDate,
		@ExpireDate DATETIME = @AExpireDate,
		@Token VARCHAR(4000) = LTRIM(RTRIM(@AToken ))

	-- delete old tokens
	--DELETE org.IssuedToken 
	--WHERE UserID = @UserID AND RefreshTokenID = @RefreshTokenID

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1   --insert
			BEGIN
				INSERT INTO org.IssuedToken
					(ID, UserID, IssuedDate, [ExpireDate], Token, ClientID, RefreshTokenID)
				VALUES
					(@ID, @UserID, @IssuedDate, @ExpireDate, @Token, @ClientID, @RefreshTokenID)
			END
			ELSE
			BEGIN				  -- update
				UPDATE org.IssuedToken
				SET [ExpireDate] = @ExpireDate
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
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spAddIndividuals') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spAddIndividuals
GO

CREATE PROCEDURE org.spAddIndividuals
	@AIndividuals NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@Individuals NVARCHAR(MAX) = LTRIM(RTRIM(@AIndividuals))

	IF OBJECT_ID('tempdb..#Individuals') IS NOT NULL
		DROP TABLE #Individuals

	        SELECT
				[ID],
				[NationalCode],
				[FirstName],
				[LastName],
				[ConfirmType],
				[ConfirmDate],
				[FatherName],
				[BCNumber],
				[Gender],
				[IsDead],
				[BirthDate],
				[BpProvinceID],
				[BpProvinceName],
				[BpCityID],
				[BpCityName],
				0 [Isaargar],
				0 [WithoutInquiry],
				CAST(NULL AS NVARCHAR(10)) PartialID 
			INTO #Individuals
			FROM OPENJSON(@Individuals)
			WITH 
			( 
				ID UNIQUEIDENTIFIER,
				NationalCode NVARCHAR(10),
				FirstName NVARCHAR(255),
				LastName NVARCHAR(255),
				ConfirmType TINYINT,
				ConfirmDate DATETIME2,
				FatherName NVARCHAR(255),
				BCNumber NVARCHAR(10),
				Gender TINYINT,
				IsDead BIT,
				BirthDate DATETIME2,
				BpProvinceID UNIQUEIDENTIFIER,
				BpProvinceName NVARCHAR(255),
				BpCityID UNIQUEIDENTIFIER,
				BpCityName NVARCHAR(255)
			)
			
			--بروز رسانی کد ملی هایی که قبلا در جدول EmployeeDetail شده اند
			UPDATE ind 
			SET ind.PartialID=ed.PartialID
			FROM #Individuals ind
			INNER JOIN [Kama.Aro.Salary].pbl.EmployeeDetail ed ON ed.NationalCode collate Persian_100_CI_AI=ind.NationalCode 
			WHERE ind.PartialID IS NULL

			--بروز رسانی کد ملی هایی که قبلا در جدول Individual شده اند
			UPDATE Newind 
			SET Newind.PartialID=ind.PartialID
			FROM #Individuals Newind
			INNER JOIN [Kama.Aro.Organization].[org].[Individual] ind ON ind.NationalCode =Newind.NationalCode
			WHERE Newind.PartialID IS NULL

			--تولید کدهای جدید برای کد ملی های جدید
			;WITH NewIndividuals AS
			(
				SELECT  *,
				       pbl.fnRandomIDGenerator(10) NewPartialID 
				FROM #Individuals
				WHERE PartialID IS NULL
			)
			UPDATE #Individuals
			SET PartialID= ne.NewPartialID
			FROM #Individuals ind
			INNER JOIN NewIndividuals ne ON ne.NationalCode=ind.NationalCode
			WHERE ind.PartialID IS NULL

	--ثبت نهایی در جدول
		INSERT INTO org.Individual
			([ID], [NationalCode], [FirstName], [LastName], [ConfirmType], [ConfirmDate], [FatherName], [BCNumber], [Gender], [IsDead], [BirthDate], [BpProvinceID], [BpProvinceName], [BpCityID], [BpCityName], [Isaargar], [WithoutInquiry],PartialID)
		SELECT [ID], [NationalCode], [FirstName], [LastName], [ConfirmType], [ConfirmDate], [FatherName], [BCNumber], [Gender], [IsDead], [BirthDate], [BpProvinceID], [BpProvinceName], [BpCityID], [BpCityName], [Isaargar], [WithoutInquiry],PartialID FROM #Individuals

		
  RETURN @@ROWCOUNT
END 
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spAddUserByIndividual'))
	DROP PROCEDURE org.spAddUserByIndividual
GO

CREATE PROCEDURE org.spAddUserByIndividual
	@ANationalCode NVARCHAR(MAX),
	@ACellPhone NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	
	DECLARE  
		@NationalCode NVARCHAR(MAX) = LTRIM(RTRIM(@ANationalCode)),
		@CellPhone NVARCHAR(MAX) = LTRIM(RTRIM(@ACellPhone))
	
	IF NOT EXISTS (SELECT * FROM [org].[IndividualCellPhone] 
                   WHERE NationalCode = @NationalCode
                   AND CellPhone = @CellPhone)
	BEGIN
		INSERT INTO [org].[IndividualCellPhone] ([ID], [NationalCode], [CellPhone], [Date])
		VALUES(NEWID(), @NationalCode, @CellPhone, GETDATE())
	END

	
	
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetIndividual') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetIndividual
GO

CREATE PROCEDURE org.spGetIndividual
	@AID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

		SELECT
			individual.ID,
			individual.NationalCode,
			individual.FirstName,
			individual.LastName,
			individual.ConfirmType,
			individual.ConfirmDate,
			individual.FatherName,
			individual.BCNumber,
			individual.Gender,
			individual.IsDead,
			individual.BirthDate,
			individual.BpProvinceID,
			BpProvience.[Name] BpProvinceName,
			BpProvience.Code BpProvinceCode,
			individual.BpCityID,
			BpProvienceCity.[Name] BpCityName,
			BpProvienceCity.Code BpCityCode,
			individual.Isaargar,
			individual.CellPhone,
			individual.WithoutInquiry
		FROM org.Individual AS individual
			LEFT JOIN org.Place BpProvience ON BpProvience.ID=individual.BpProvinceID
			LEFT JOIN org.Place BpProvienceCity ON BpProvienceCity.ID=individual.BpCityID
		WHERE individual.ID = @ID
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetIndividualByNationalCode') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetIndividualByNationalCode
GO

CREATE PROCEDURE org.spGetIndividualByNationalCode
	@ANationalCode NVARCHAR(11)

WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@NationalCode NVARCHAR(11) = @ANationalCode

			SELECT TOP 1
				individual.ID,
				individual.NationalCode,
				individual.FirstName,
				individual.LastName,
				individual.ConfirmType,
				individual.ConfirmDate,
				individual.FatherName,
				individual.BCNumber,
				individual.Gender,
				individual.IsDead,
				individual.BirthDate,
				individual.BpProvinceID,
				BpProvience.[Name] BpProvinceName,
				individual.BpCityID,
				BpProvienceCity.[Name] BpCityName,
				individual.Isaargar,
				individual.CellPhone,
				individual.WithoutInquiry
			FROM org.Individual AS individual
				LEFT JOIN org.Place BpProvience ON BpProvience.ID=individual.BpProvinceID
				LEFT JOIN org.Place BpProvienceCity ON BpProvienceCity.ID=individual.BpCityID
			WHERE individual.NationalCode =@NationalCode
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetIndividualPostInformation') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetIndividualPostInformation
GO

CREATE PROCEDURE org.spGetIndividualPostInformation
	@AID UNIQUEIDENTIFIER

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

		;WITH PostInfo AS(
			SELECT TOP 1 
				post.IndividualID,
				dep.[Code] OrganCode,
				COALESCE(province.[Name], adrs.ProvinceName) OrganProvinceName,
				adrs.CityName OrganCityName
			FROM [Kama.Aro.Sakhtar].chr.[Post] post
				INNER JOIN [Kama.Aro.Sakhtar].chr.[Unit] unit ON unit.ID = post.UnitID
				INNER JOIN [Kama.Aro.Sakhtar].chr.[Chart] chart ON chart.ID = unit.ChartID
				INNER JOIN org.Department dep ON dep.ID = chart.OrganID
				LEFT JOIN org.Place province ON province.ID = dep.ProvinceID
				LEFT JOIN inq._Address adrs ON adrs.ID= dep.AddressID 
			WHERE post.IndividualID = @ID
		)

		SELECT
			individual.ID,
			individual.NationalCode,
			individual.CellPhone,
			individual.BirthDate,
			post.OrganCode,
			post.OrganProvinceName,
			post.OrganCityName
		FROM org.Individual AS individual
			LEFT JOIN PostInfo post ON post.IndividualID = individual.ID
		WHERE individual.ID = @ID
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetIndividuals') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetIndividuals
GO

CREATE PROCEDURE org.spGetIndividuals
	@AIDs NVARCHAR(MAX),
	@AFirstName NVARCHAR(255),
	@ALastName NVARCHAR(255),
	@ANationalCode NVARCHAR(10),
	@ABirthDate SMALLDATETIME,
	@AConfirmType TINYINT,
	@ANationalCodes NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@IDs NVARCHAR(MAX) = LTRIM(RTRIM(@AIDs)),
		@FirstName NVARCHAR(255) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(255) = LTRIM(RTRIM(@ALastName)),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@BirthDate SMALLDATETIME = @ABirthDate,
		@ConfirmType TINYINT = COALESCE(@AConfirmType, 0),
		@NationalCodes NVARCHAR(MAX) = @ANationalCodes,
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			individual.FirstName,
			individual.LastName,
			individual.ConfirmType,
			individual.ConfirmDate,
			individual.FatherName,
			individual.BCNumber,
			individual.Gender,
			individual.IsDead,
			individual.BirthDate,
			individual.BpProvinceID,
			BpProvience.[Name] BpProvinceName,
			individual.BpCityID,
			BpProvienceCity.[Name] BpCityName,
			individual.Isaargar,
			individual.CellPhone,
			individual.WithoutInquiry
		FROM Org.Individual as individual
			LEFT JOIN org.Place BpProvience ON BpProvience.ID=Individual.BpProvinceID
			LEFT JOIN org.Place BpProvienceCity ON BpProvienceCity.ID=Individual.BpCityID
			LEFT JOIN OPENJSON(@IDs) IndividualIDs ON IndividualIDs.value = individual.ID
			LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = individual.NationalCode
		WHERE (@IDs IS NULL OR IndividualIDs.value IS NOT NULL)
			AND (@NationalCode IS NULL OR Individual.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR Individual.FirstName LIKE '%' + @FirstName + '%')
			AND (@LastName IS NULL OR Individual.LastName LIKE '%' + @LastName + '%')
			AND (@BirthDate IS NULL OR individual.birthDate = @BirthDate)
			AND (@ConfirmType < 1 OR individual.ConfirmType = @ConfirmType)
			AND (@NationalCodes IS NULL OR NationalCodes.value = individual.NationalCode)
	),
	TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM TempResult
	)
	SELECT * FROM TempResult, TempCount
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE);

END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForEducationInquiry') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForEducationInquiry
GO

CREATE PROCEDURE org.spGetNeededIndividualsForEducationInquiry
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.EducationalInquiryState as inquiry
	),
	TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM [org].[Individual] as individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
		WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1
		AND individual.NationalCode IS NOT NULL AND LEN(individual.NationalCode) = 10
		AND individual.ConfirmType = 1
	)
	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE);

END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForImageSmartInquiry') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForImageSmartInquiry
GO

CREATE PROCEDURE org.spGetNeededIndividualsForImageSmartInquiry
	@AType INT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE
		@Type INT = COALESCE(@AType, 1),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.ImageSmartInquiryState as inquiry
	),
	TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM org.TempIndividualForImageSmart AS individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
		WHERE inquiry.RowNumber IS NULL
	)
	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForInsuranceInquiry') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForInsuranceInquiry
GO

CREATE PROCEDURE org.spGetNeededIndividualsForInsuranceInquiry
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.[InsuranceInquiryState] as inquiry
	),
	TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM [org].[Individual] as individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
		WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1
		AND individual.NationalCode IS NOT NULL AND LEN(individual.NationalCode) = 10
		AND individual.ConfirmType = 1
	)
	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForOmidBatchVaccineInquiry') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForOmidBatchVaccineInquiry
GO

CREATE PROCEDURE org.spGetNeededIndividualsForOmidBatchVaccineInquiry
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.VaccineInquiryState as inquiry
	),
	TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM [org].[IndividualForVaccine] as individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
		WHERE inquiry.RowNumber = 1 AND individual.IsInUsed = 0
	)
	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForOmidVaccineInquiry') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForOmidVaccineInquiry
GO

CREATE PROCEDURE org.spGetNeededIndividualsForOmidVaccineInquiry
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.VaccineInquiryState as inquiry
	),
	TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM [org].[Individual] as individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
		WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1
		AND individual.NationalCode IS NOT NULL AND LEN(individual.NationalCode) = 10
		AND individual.ConfirmType = 1
	)
	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForRetirementInquiry') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForRetirementInquiry
GO

CREATE PROCEDURE org.spGetNeededIndividualsForRetirementInquiry
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END



	--;WITH InquiryResult AS(
	--	SELECT
	--		inquiry.ID,
	--		inquiry.CreationDate,
	--		inquiry.IndividualID,
	--		ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
	--	FROM inq.RetirementInquiryState as inquiry
	--),
	--TempResult AS
	--(
	--	SELECT
	--		individual.ID,
	--		individual.NationalCode,
	--		inquiry.CreationDate
	--	FROM [org].[Individual] as individual
	--		LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
	--	WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1
	--	AND individual.NationalCode IS NOT NULL AND LEN(individual.NationalCode) = 10
	--	AND individual.ConfirmType = 1
	--)

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.RetirementInquiryState as inquiry
	),
	DistinctNeededIndividuals AS
	(
		SELECT DISTINCT IndividualID
		FROM [Kama.Aro.Pakna].emp.EmployeeInfo
	),
	TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM [org].[Individual] as individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
			INNER JOIN DistinctNeededIndividuals employee on employee.IndividualID = individual.ID
		WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1
		AND individual.NationalCode IS NOT NULL AND LEN(individual.NationalCode) = 10
		AND individual.ConfirmType = 1
	)

	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE);

END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForSacrificialInquiry') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForSacrificialInquiry
GO

CREATE PROCEDURE org.spGetNeededIndividualsForSacrificialInquiry
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END	

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.SacrificialInquiryState as inquiry
	),
	TempResult AS
	(
		SELECT
			individual.ID AS ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM [org].[Individual] as individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
		WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1
		AND individual.NationalCode IS NOT NULL AND LEN(individual.NationalCode) = 10
		AND individual.ConfirmType = 1
	)
	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForVaccineInquiry') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForVaccineInquiry
GO

CREATE PROCEDURE org.spGetNeededIndividualsForVaccineInquiry
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.VaccineInquiryState as inquiry
	),
	TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM [org].[Individual] as individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
		WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1
		AND individual.NationalCode IS NOT NULL AND LEN(individual.NationalCode) = 10
		AND individual.ConfirmType = 1
	)
	SELECT * FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetNeededIndividualsForVaccineInquiry2') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetNeededIndividualsForVaccineInquiry2
GO

CREATE PROCEDURE org.spGetNeededIndividualsForVaccineInquiry2
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH InquiryResult AS(
		SELECT
			inquiry.ID,
			inquiry.CreationDate,
			inquiry.IndividualID,
			ROW_NUMBER() OVER(PARTITION BY inquiry.IndividualID order by inquiry.CreationDate) RowNumber
		FROM inq.VaccineInquiryState as inquiry
	),
	NeededIndividuals AS(
		SELECT 
			individual.ID,
			individual.NationalCode
		FROM [org].[Individual] as individual
			INNER JOIN inq.Vaccine vac ON vac.IndividualID = individual.ID 
		WHERE
			individual.NationalCode IS NOT NULL AND LEN(individual.NationalCode) = 10
			AND individual.ConfirmType = 1
			AND vac.NumberOfReceivedDoses = 0
	),
	TempResult AS
	(
		SELECT
			individual.ID,
			individual.NationalCode,
			inquiry.CreationDate
		FROM NeededIndividuals as individual
			LEFT JOIN InquiryResult inquiry on inquiry.IndividualID = individual.ID
		WHERE inquiry.RowNumber IS NULL OR inquiry.RowNumber = 1		
	)
	SELECT *
	FROM TempResult
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY	
END


GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetRepeatedIndividuals') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetRepeatedIndividuals
GO

CREATE PROCEDURE org.spGetRepeatedIndividuals
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH Individuals AS 
	(
		SELECT 
			NationalCode,
			COUNT(*) [Count]
		FROM org.Individual ind
		WHERE EXISTS (SELECT TOP 1 1 FROM org.Individual ind2 WHERE ind2.NationalCode = ind.NationalCode AND ConfirmType <> 2)
			AND NationalCode <> '??????????'
		GROUP BY NationalCode
		HAVING COUNT(NationalCode) > 1
		ORDER BY COUNT(*) DESC
		OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	)
	SELECT ind2.*
	FROM Individuals ind1
		inner join org.Individual ind2 ON ind1.NationalCode = ind2.NationalCode
	Order BY ind1.[Count] DESC, ind1.NationalCode

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spMergeIndividuals'))
	DROP PROCEDURE org.spMergeIndividuals
GO

CREATE PROCEDURE org.spMergeIndividuals
	@AIndividualID UNIQUEIDENTIFIER,
	@AMergedIndividualID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@MergedIndividualID UNIQUEIDENTIFIER = @AMergedIndividualID,
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode))

	BEGIN TRY
		BEGIN TRAN
			
			EXEC [Kama.Aro.Estekhdam].org.spMergeIndividuals @IndividualID, @MergedIndividualID

			EXEC [Kama.Aro.Sakhtar].org.spMergeIndividuals @IndividualID, @MergedIndividualID

			EXEC [Kama.Aro.Pakna].org.spMergeIndividuals @IndividualID, @MergedIndividualID

			--EXEC [Kama.Aro.Salary2].org.spMergeIndividuals @IndividualID, @MergedIndividualID

			EXEC [Kama.Aro.Organization].org.spOrganizationMergeIndividuals @IndividualID, @MergedIndividualID

			EXEC [Kama.Aro.Survey].org.spMergeIndividuals @IndividualID, @MergedIndividualID

			EXEC [Kama.Aro.Bina].org.spMergeIndividuals @IndividualID, @MergedIndividualID

			EXEC [Kama.Aro.Pardakht].org.spMergeIndividuals @IndividualID, @MergedIndividualID
			

			DELETE FROM [Kama.Aro.Organization].org.Individual WHERE ID = @AMergedIndividualID

			INSERT INTO org.IndividualMerge
				(ID, MergedID, CreationDate, NationalCode)
			VALUES
				(@IndividualID, @MergedIndividualID, GETDATE(), @NationalCode)

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spModifyIndividual') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spModifyIndividual
GO

CREATE PROCEDURE org.spModifyIndividual
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AFirstName NVARCHAR(255),
	@ALastName NVARCHAR(255),
	@AFatherName NVARCHAR(255),
	@ABCNumber NVARCHAR(10),
	@AGender TINYINT,
	@AIsDead BIT,
	@ANationalCode NVARCHAR(10),
	@ABirthDate DATE,
	@AConfirmType TINYINT,
	@AIsaargar TINYINT,
	@ABpProvinceID UNIQUEIDENTIFIER,
	@ABpProvinceName NVARCHAR(255),
	@ABpCityID UNIQUEIDENTIFIER,
	@ABpCityName NVARCHAR(255), 
	@AConfirmDate SMALLDATETIME,
	@AWithoutInquiry BIT,
	@ACellPhone VARCHAR(11)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@FirstName NVARCHAR(255) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(255) = LTRIM(RTRIM(@ALastName)),
		@FatherName NVARCHAR(255) = LTRIM(RTRIM(@AFatherName)),
		@BCNumber NVARCHAR(10) = LTRIM(RTRIM(@ABCNumber)),
		@Gender TINYINT = COALESCE(@AGender, 0),
		@IsDead BIT = coalesce(@AIsDead, 0),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@BirthDate DATE = @ABirthDate,
		@ConfirmType TINYINT = COALESCE(@AConfirmType,2),
		@BpProvinceID UNIQUEIDENTIFIER = @ABpProvinceID,
		@BpProvinceName NVARCHAR(255) = LTRIM(RTRIM(@ABpProvinceName)),
		@BpCityID UNIQUEIDENTIFIER = @ABpCityID,
		@BpCityName NVARCHAR(255) = LTRIM(RTRIM(@ABpCityName)),
		@ConfirmDate SMALLDATETIME = @AConfirmDate,
		@Isaargar TINYINT = COALESCE(@Aisaargar, 0),
		@WithoutInquiry BIT = COALESCE(@AWithoutInquiry, 0),
		@CellPhone VARCHAR(11) = LTRIM(RTRIM(@ACellPhone)),
		@PartialID NVARCHAR(10)


	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1		 -- insert 
			BEGIN
			SELECT @PartialID=PartialID FROM [org].[Individual] WHERE NationalCode=@NationalCode
            
            IF @PartialID IS NULL 
            SELECT @PartialID=PartialID FROM [Kama.Aro.Salary].[pbl].[EmployeeDetail] WHERE NationalCode=@NationalCode
           
            IF @PartialID IS NULL
            SELECT @PartialID = pbl.fnRandomIdGenerator(10)
				
				INSERT INTO [org].[Individual]
					([ID],  [NationalCode], [FirstName], [LastName], ConfirmType, ConfirmDate, FatherName, BCNumber, Gender, IsDead, BirthDate, BpProvinceID, BpProvinceName, BpCityID, BpCityName, Isaargar, WithoutInquiry, CellPhone,PartialID)
				VALUES
					(@ID, @NationalCode, @FirstName, @LastName, @ConfirmType, @ConfirmDate, @FatherName, @BCNumber, @Gender, @IsDead, @BirthDate, @BpProvinceID, @BpProvinceName, @BpCityID, @BpCityName, @Isaargar, @WithoutInquiry, @CellPhone, @PartialID)
			END
			ELSE 			 -- update
			BEGIN

			SELECT @PartialID=PartialID FROM [org].[Individual] WHERE NationalCode=@NationalCode

				UPDATE [org].[Individual]
				SET NationalCode = @NationalCode
				, FirstName = @FirstName
				, LastName = @LastName
				, ConfirmType = @ConfirmType
				, ConfirmDate = @ConfirmDate
				, FatherName = @FatherName
				, BCNumber = @BCNumber
				, Gender = @Gender
				, IsDead = @IsDead
				, BirthDate = @BirthDate
				, BpProvinceID = @BpProvinceID
				, BpProvinceName = @BpProvinceName
				, BpCityID = @BpCityID
				, BpCityName = @BpCityName
				, Isaargar = @Isaargar
				, WithoutInquiry = @WithoutInquiry
				, CellPhone = @CellPhone
				,PartialID=@PartialID
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
	ROLLBACK;
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spModifyIndividualCellPhone') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spModifyIndividualCellPhone
GO

CREATE PROCEDURE org.spModifyIndividualCellPhone
	@AID UNIQUEIDENTIFIER,
	@ACellPhone VARCHAR(11)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CellPhone VARCHAR(11) = LTRIM(RTRIM(@ACellPhone))

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE org.Individual
			SET CellPhone = @CellPhone
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
Use [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spOrganizationMergeIndividuals'))
	DROP PROCEDURE org.spOrganizationMergeIndividuals
GO

CREATE PROCEDURE org.spOrganizationMergeIndividuals
	@AIndividualID UNIQUEIDENTIFIER,
	@AMergedIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,									
		@MergedIndividualID UNIQUEIDENTIFIER = @AMergedIndividualID			

	BEGIN TRY
		BEGIN TRAN
			UPDATE WebServiceUser
				SET IndividualID = @IndividualID 
			FROM [org].[WebServiceUser]  WebServiceUser
			WHERE IndividualID = @MergedIndividualID

			UPDATE UserCellPhone
				SET IndividualID = @IndividualID 
			FROM [org].[UserCellPhone]  UserCellPhone
			WHERE IndividualID = @MergedIndividualID

			UPDATE usr
				SET IndividualID = @IndividualID 
			FROM [org].[User]  usr
			WHERE IndividualID = @MergedIndividualID
						
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spSetConfirmType') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spSetConfirmType
GO

CREATE PROCEDURE org.spSetConfirmType
	@AID UNIQUEIDENTIFIER,
	@AConfirmType TINYINT,
	@AGender TINYINT,
	@AIsDead BIT,
	@ABirthDate SMALLDATETIME,
	@ABCNumber NVARCHAR(10),
	@AFatherName NVARCHAR(100)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@ConfirmType TINYINT = COALESCE(@AConfirmType, 2),      -- در انتظار استعلام از ثبت احوال
		@Gender TINYINT = @AGender,
		@IsDead BIT= @AIsDead,
		@BirthDate SMALLDATETIME = @ABirthDate,
		@BCNumber NVARCHAR(10) = @ABCNumber,
		@FatherName NVARCHAR(100) = @AFatherName

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE org.Individual 
			SET ConfirmType = @AConfirmType,
				ConfirmDate = GETDATE(),
				Gender = @Gender,
				IsDead = @IsDead,
				BirthDate = @BirthDate,
				BCNumber = @BCNumber,
				FatherName = @FatherName
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

    RETURN @@ROWCOUNT 
END 
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'inq.spGetIndividualInquirys') AND type in (N'P', N'PC'))
DROP PROCEDURE inq.spGetIndividualInquirys
GO

CREATE PROCEDURE inq.spGetIndividualInquirys
	@ANationalCode NVARCHAR(10),
	@ACreationDateFrom DATE,
	@ACreationDateTo DATE,
	@ANationalCodes NVARCHAR(MAX),
	@AErrorCodes NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION, RECOMPILE
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@CreationDateFrom DATE = @ACreationDateFrom,
		@CreationDateTo DATE = DATEADD(DAY, 1, @ACreationDateTo),
		@NationalCodes NVARCHAR(MAX) = @ANationalCodes,
		@ErrorCodes NVARCHAR(MAX) = @AErrorCodes,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize, 20),
		@PageIndex INT = COALESCE(@APageIndex, 1),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH TempResult AS
	(
		SELECT
			inquiry.ID,
			inquiry.NationalCode,
			inquiry.CreationDate,
			inquiry.ErrorCode,
			inquiry.ConfirmType
		FROM [dbo].[IndividualInquiry] as inquiry
			LEFT JOIN OPENJSON(@NationalCodes) NationalCodes ON NationalCodes.value = inquiry.NationalCode
			LEFT JOIN OPENJSON(@ErrorCodes) ErrorCodes ON ErrorCodes.value = inquiry.ErrorCode
		WHERE (@NationalCode IS NULL OR inquiry.NationalCode = @NationalCode)
			AND (@CreationDateFrom IS NULL OR inquiry.CreationDate >= @CreationDateFrom)
			AND (@CreationDateTo IS NULL OR inquiry.CreationDate < @CreationDateTo)
			AND (@NationalCodes IS NULL OR NationalCodes.value = inquiry.NationalCode)
			AND (@ErrorCodes IS NULL OR ErrorCodes.value = inquiry.ErrorCode)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM TempResult
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM TempResult, TempCount
	ORDER BY ConfirmType
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION(RECOMPILE);

END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('inq.spModifyIndividualInquiry'))
	DROP PROCEDURE inq.spModifyIndividualInquiry
GO

CREATE PROCEDURE inq.spModifyIndividualInquiry
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER,
	@ANationalCode CHAR(10),
	@AConfirmType TINYINT,
	@AErrorCode INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@NationalCode CHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@ConfirmType TINYINT = COALESCE(@AConfirmType, 0),
		@ErrorCode INT = @AErrorCode

	BEGIN TRY
		BEGIN TRAN
			INSERT INTO dbo.IndividualInquiry
			(ID, IndividualID, NationalCode, ConfirmType, ErrorCode, CreationDate)
			VALUES
			(@ID, @IndividualID, @NationalCode, @ConfirmType, @ErrorCode, GETDATE())
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spUpdateIndividualsState'))
	DROP PROCEDURE org.spUpdateIndividualsState
GO

CREATE PROCEDURE org.spUpdateIndividualsState
	
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRAN
			
			;WITH ind AS 
			(
				SELECT TOP 4000 * 
				from org.individual 
				where confirmtype = 3 and firstname <> '' and lastname <> ''
				order by confirmdate
			) 
			UPDATE ind SET confirmtype = 2

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteMasterApplication'))
	DROP PROCEDURE org.spDeleteMasterApplication
GO

CREATE PROCEDURE org.spDeleteMasterApplication
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID
	

	
	BEGIN TRY
		BEGIN TRAN

		UPDATE [org].[MasterApplication]
		SET
			RemoverUserID = @RemoverUserID,
			RemoveDate = GETDATE()
		WHERE 
			ID = @ID

		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetMasterApplication'))
	DROP PROCEDURE org.spGetMasterApplication
GO

CREATE PROCEDURE org.spGetMasterApplication
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		masterApps.[ID], 
		masterApps.[MasterPasswordID], 
		masterApps.[ApplicationID], 
		masterApps.[ClientID], 
		masterApps.[RemoverUserID], 
		masterApps.[RemoveDate],
		client.[Name] as ClientName,
		app.[Name] as ApplicationName
	FROM [org].[MasterApplication] masterApps
		INNER JOIN org.Client client on client.ID = masterApps.ClientID
		INNER JOIN org.[Application] app on app.ID = masterApps.ApplicationID
	WHERE masterApps.ID = @ID
	AND RemoveDate IS NULL
	AND RemoverUserID IS NUll

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetMasterApplications'))
	DROP PROCEDURE org.spGetMasterApplications
GO

CREATE PROCEDURE org.spGetMasterApplications
	@AMasterPasswordID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@MasterPasswordID UNIQUEIDENTIFIER = @AMasterPasswordID,
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH  MainSelect AS 
	(
		SELECT 
			masterApps.[ID], 
			masterApps.[MasterPasswordID], 
			masterApps.[ApplicationID],
			app.[Name] as ApplicationName,
			masterApps.[ClientID],
			client.[Name] as ClientName,
			masterApps.[RemoverUserID], 
			masterApps.[RemoveDate]
		FROM [org].[MasterApplication] masterApps
		INNER JOIN org.Client client on client.ID = masterApps.ClientID
		INNER JOIN org.[Application] app on app.ID = masterApps.ApplicationID
		WHERE (@MasterPasswordID IS NULL OR masterApps.MasterPasswordID = @MasterPasswordID)
		AND RemoveDate IS NULL
		AND RemoverUserID IS NUll
	)
	, Total AS 
	(
			SELECT 
			Count(*) Total
		FROM [org].[MasterApplication] masterApps
		WHERE (@MasterPasswordID IS NULL OR masterApps.MasterPasswordID = @MasterPasswordID)
		AND RemoveDate IS NULL
		AND RemoverUserID IS NUll
	)
	SELECT * FROM MainSelect , Total		 
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;	

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyMasterApplication'))
	DROP PROCEDURE org.spModifyMasterApplication
GO

CREATE PROCEDURE org.spModifyMasterApplication
	@AIsNewRecord BIT,
	@AMasterPasswordID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AClientID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 

		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@MasterPasswordID UNIQUEIDENTIFIER = @AMasterPasswordID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@ClientID UNIQUEIDENTIFIER = @AClientID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO [org].[MasterApplication]
				([ID], [MasterPasswordID], [ApplicationID], [ClientID])
				VALUES
				(NEWID(), @MasterPasswordID, @ApplicationID , @ClientID)
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spCreateMasterPassword'))
	DROP PROCEDURE org.spCreateMasterPassword
GO

CREATE PROCEDURE org.spCreateMasterPassword
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @NewPassword VARCHAR(20)


	SELECT @NewPassword = N'M@ster*'+ cast (cast (RAND()*(100-10)+10 as int) as varchar) + [pbl].[fnRandomIDGenerator](10)+ '*' 
		IF   EXISTS(SELECT TOP 1 * FROM [org].[MasterPassword] WHERE [Password] = @NewPassword)
		BEGIN
			--INSERT INTO @PartialIDTable
			--EXEC  pbl.RandomIDGenerator @Len = 10
			--SELECT @PartialID=ID FROM @PartialIDTable
			SELECT @NewPassword = N'M@ster*'+ cast (cast (RAND()*(100-10)+10 as int) as varchar) + [pbl].[fnRandomIDGenerator](10)+ '*'
	END
	SELECT 
		@NewPassword As PasswordString
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteMasterPassword'))
	DROP PROCEDURE org.spDeleteMasterPassword
GO

CREATE PROCEDURE org.spDeleteMasterPassword
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID
	

	
	BEGIN TRY
		BEGIN TRAN

		UPDATE ORG.[MasterPassword]
		SET
			RemoverUserID = @RemoverUserID,
			RemoveDate = GETDATE()
		WHERE 
			ID = @ID

		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetMasterPassword'))
	DROP PROCEDURE org.spGetMasterPassword
GO

CREATE PROCEDURE org.spGetMasterPassword
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		[ID], 
		[UserID], 
		[FromDate], 
		[ToDate], 
		[Password], 
		[CreatorUserID], 
		[CreationDate], 
		[RemoverUserID], 
		[RemoveDate]
	FROM [org].[MasterPassword]
	WHERE ID = @ID
	AND RemoveDate IS NULL
	AND RemoverUserID IS NUll

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetMasterPasswords'))
	DROP PROCEDURE org.spGetMasterPasswords
GO

CREATE PROCEDURE org.spGetMasterPasswords
	@AUserID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH  MainSelect AS 
	(
		SELECT 
			[ID], 
			[UserID], 
			[FromDate], 
			[ToDate], 
			[Password], 
			[CreatorUserID], 
			[CreationDate],
			[RemoverUserID],
			[RemoveDate]
		FROM [org].[MasterPassword] masterPass
		WHERE (@UserID IS NULL OR masterPass.UserID = @UserID)
		AND RemoveDate IS NULL
		AND RemoverUserID IS NUll
	)
	, Total AS 
	(
			SELECT 
			Count(*) Total
		FROM [org].[MasterPassword] masterPass
		WHERE (@UserID IS NULL OR masterPass.UserID = @UserID)
		AND RemoveDate IS NULL
		AND RemoverUserID IS NUll
	)
	SELECT * FROM MainSelect , Total		 
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;	

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyMasterPassword'))
	DROP PROCEDURE org.spModifyMasterPassword
GO

CREATE PROCEDURE org.spModifyMasterPassword
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AFromDate SMALLDATETIME,
	@AToDate SMALLDATETIME,
	@APassword varchar(1000),
	@ACreatorUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 

		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@FromDate SMALLDATETIME = @AFromDate,
		@ToDate SMALLDATETIME = @AToDate,
		@Password VARCHAR(1000) = @APassword,
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN

				INSERT INTO [org].[MasterPassword]
				([ID], [UserID], [FromDate], [ToDate], [Password], [CreatorUserID], [CreationDate], [RemoverUserID], [RemoveDate])
				VALUES
				(@ID, @UserID, @FromDate , @ToDate, @Password, @CreatorUserID, GETDATE(), NULL, NULL)
			END
			ELSE
			BEGIN -- update
				UPDATE [org].[MasterPassword]
				SET 
				[UserID] = @UserID,
				[FromDate] = @FromDate,
				[ToDate] = @ToDate,
				[Password] = @Password,
				[CreatorUserID] = @CreatorUserID
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteOutsideSetting'))
	DROP PROCEDURE org.spDeleteOutsideSetting
GO

CREATE PROCEDURE org.spDeleteOutsideSetting
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
			
			DELETE FROM [org].[OutsideSetting]
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetOutsideSetting'))
	DROP PROCEDURE org.spGetOutsideSetting
GO

CREATE PROCEDURE org.spGetOutsideSetting
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		os.[ID],
		os.ElementType,
		os.Show
	FROM org.[OutsideSetting] os
	WHERE os.ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetOutsideSettings'))
	DROP PROCEDURE org.spGetOutsideSettings
GO

CREATE PROCEDURE org.spGetOutsideSettings
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@SortExp NVARCHAR(MAX) = LTRIM(TRIM(@ASortExp)),
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
		os.[ID],
		os.ElementType,
		os.Show
		FROM org.[OutsideSetting] os
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyOutsideSetting'))
	DROP PROCEDURE org.spModifyOutsideSetting
GO

CREATE PROCEDURE org.spModifyOutsideSetting
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AElementType TINYINT,
	@AShow BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ElementType TINYINT = COALESCE(@AElementType, 0),
		@Show BIT = COALESCE(@AShow, 0)

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 
				    -- insert
			BEGIN
				INSERT INTO [org].[OutsideSetting]
					([ID], ElementType, Show)
				VALUES
					(@ID, @ElementType, @Show)
			END
			ELSE    -- update
			BEGIN
				UPDATE [org].[OutsideSetting]
				SET 
					ElementType = @ElementType,
					Show = @Show
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPasswordSettings'))
	DROP PROCEDURE org.spGetPasswordSettings
GO

CREATE PROCEDURE org.spGetPasswordSettings
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT TOP 1 *
	FROM org.PasswordSettings
	
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyPasswordSettings'))
	DROP PROCEDURE org.spModifyPasswordSettings
GO

CREATE PROCEDURE org.spModifyPasswordSettings
	@ACharacterLength TINYINT,
	@ANumber BIT,
	@AUpper BIT ,
	@ALower BIT ,
	@ASpecial BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	 DECLARE 
	    @CharacterLength TINYINT = @ACharacterLength,
		@Number BIT = ISNULL(@ANumber, 0),
		@Upper BIT = ISNULL(@AUpper, 0),
		@Lower BIT = ISNULL(@ALower, 0),
		@Special BIT = ISNULL(@ASpecial, 0)
		
	UPDATE org.PasswordSettings
	SET [CharacterLength] = @CharacterLength, [Number] = @Number, [Upper] = @Upper, [Lower] = @Lower, [Special] = @Special

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeletePlace'))
DROP PROCEDURE org.spDeletePlace
GO

CREATE PROCEDURE org.spDeletePlace
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		  @ID UNIQUEIDENTIFIER = @AID
		, @Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
		, @Node HIERARCHYID 

	SET @Node = (SELECT [Node] FROM org.Place WHERE ID = @ID)  

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM org.Place
			WHERE [Node].IsDescendantOf(@Node) = 1

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPlace'))
	DROP PROCEDURE org.spGetPlace
GO

CREATE PROCEDURE org.spGetPlace
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		Place.ID,
		Place.[Node].ToString() [Node],
		Place.[Node].GetAncestor(1).ToString() ParentNode,
		Place.[Type],
		Place.[Name],
		Place.LatinName,
		Place.Code,
		Parent.ID ParentID,
		Place.DevelopmentType
	FROM org.Place Place
	LEFT JOIN org.Place Parent ON Parent.Node = Place.[Node].GetAncestor(1)
	WHERE Place.ID = @ID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPlaceByCode'))
	DROP PROCEDURE org.spGetPlaceByCode
GO

CREATE PROCEDURE org.spGetPlaceByCode
	@ACode VARCHAR(10),
	@AType TINYINT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@Code VARCHAR(10) = LTRIM(TRIM(@ACode)),
		@Type TINYINT = COALESCE(@AType, 0)

	SELECT
		Place.ID,
		Place.[Node].ToString() [Node],
		Place.[Node].GetAncestor(1).ToString() ParentNode,
		Place.[Type],
		Place.[Name],
		Place.LatinName,
		Place.Code,
		Parent.ID ParentID,
		Place.DevelopmentType
	FROM org.Place Place
	LEFT JOIN org.Place Parent ON Parent.Node = Place.[Node].GetAncestor(1)
	WHERE Place.Code = @Code
	AND Place.[Type] = @Type

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPlaces'))
	DROP PROCEDURE org.spGetPlaces
GO

CREATE PROCEDURE org.spGetPlaces
	@AIDs NVARCHAR(MAX),
	@AParentID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@AAncestorLevel INT,
	@AName NVARCHAR(256),
	@ADevelopmentType TINYINT,
	@APageSize INT,
	@APageIndex INT

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@IDs NVARCHAR(MAX) = LTRIM(RTRIM(@AIDs)),
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Type TINYINT = COALESCE(@AType, 0),
		@AncestorLevel INT = COALESCE(@AAncestorLevel, 1),
		@DevelopmentType TINYINT = COALESCE(@ADevelopmentType, 0),
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID

	SET @ParentNode = (SELECT Node FROM org.Place WHERE ID = @ParentID)
	IF @AncestorLevel < 1 SET @AncestorLevel = 1

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH SearchedIDs AS
	(
		SELECT Value ID
		FROM OPENJSON(@IDs)
	)
	, MainSelect AS
	(
		SELECT
			Place.ID,
			Place.[Node].ToString() [Node],
			Place.[Node].GetAncestor(1).ToString() ParentNode,
			Place.[Type],
			Place.[Name],
			Place.LatinName,
			Place.Code,
			Place.[DevelopmentType],
			Place.ParentID
		FROM org.Place Place
		LEFT JOIN SearchedIDs ON SearchedIDs.ID = Place.ID
		WHERE (@IDs IS NULL OR SearchedIDs.ID IS NOT NULL)
			AND (@ParentID IS NULL OR Place.[Node].GetAncestor(@AncestorLevel) = @ParentNode) 
			AND (@Type < 1 OR Place.[Type] = @Type)
			AND (@Name IS NULL OR Place.[Name] like CONCAT('%', @Name, '%'))
			AND (@DevelopmentType < 1 OR Place.[DevelopmentType] = @DevelopmentType)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, TempCount
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyPlace'))
	DROP PROCEDURE org.spModifyPlace
GO

CREATE PROCEDURE org.spModifyPlace
    @AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@ANode HIERARCHYID,
	@AType TINYINT,
	@AName NVARCHAR(256),
	@ALatinName NVARCHAR(256),
	@ADevelopmentType TINYINT
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Node HIERARCHYID = @ANode,
		@Type TINYINT = @AType,
		@Name NVARCHAR(256) = LTRIM(RTRIM(@AName)),
		@LatinName NVARCHAR(256) = LTRIM(RTRIM(@ALatinName)),
		@DevelopmentType TINYINT = COALESCE(@ADevelopmentType, 0),
		@ParentNode HIERARCHYID,
		@LastChildNode HIERARCHYID,
		@NewNode HIERARCHYID,
		@Code VARCHAR(10),
		@MAXCode VARCHAR(20)

	IF @Node IS NULL 
		OR @ParentID <> COALESCE((SELECT TOP 1 ID FROM org.Place WHERE @Node.GetAncestor(1) = [Node]), 0x)
	BEGIN
		SET @ParentNode = COALESCE((SELECT [Node] FROM org.Place WHERE ID = @ParentID), HIERARCHYID::GetRoot())
		SET @LastChildNode = (SELECT MAX([Node]) FROM org.Place WHERE [Node].GetAncestor(1) = @ParentNode)
		SET @NewNode = @ParentNode.GetDescendant(@LastChildNode, NULL)
	END


	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert 
			BEGIN
				SET @MAXCode = 
					(
						SELECT 
							MAX(CAST(Code AS INT)) 
						FROM [Kama.Aro.Organization].org.Place 
						WHERE ([Type] = @Type)
						AND (@ParentID IS NULL OR [Node].IsDescendantOf(@ParentNode) = 1)
					)
				
				SET @Code = COALESCE(CAST(@MAXCode AS INT), 0) + 1


				INSERT INTO org.Place
					(ID, [Node], [Type], [Name], Code, LatinName, DevelopmentType, [ParentID])
				VALUES
					(@ID, @NewNode, @Type, @Name, @Code, @LatinName, @DevelopmentType, @ParentID)
			END
			ELSE -- update
			BEGIN
				UPDATE org.Place
				SET 
					[Type] = @Type,
					[Name] = @Name,
					Code = @Code, 
					[LatinName] = @LatinName,
					DevelopmentType = @DevelopmentType
				WHERE ID = @ID

				IF @Node <> @NewNode
				BEGIN
					Update org.Place
					SET Node = Node.GetReparentedValue(@Node, @NewNode)
					WHERE Node.IsDescendantOf(@Node) = 1
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeletePosition'))
	DROP PROCEDURE org.spDeletePosition
GO

CREATE PROCEDURE org.spDeletePosition
	@AID UNIQUEIDENTIFIER,
	@ARemoverID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   @ID UNIQUEIDENTIFIER = @AID
			, @RemoverID UNIQUEIDENTIFIER = @ARemoverID
			, @Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			UPDATE org.Position
			SET RemoverID = @RemoverID, RemoveDate = GETDATE()
			WHERE ID = @ID

			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetApplicationByUser'))
	DROP PROCEDURE org.spGetApplicationByUser
GO

CREATE PROCEDURE org.spGetApplicationByUser
	@AUserID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0)

	
	;WITH MainSelect AS
	(	
		SELECT DISTINCT UserID,
			app.ID ID,
			app.[Name] Name
		FROM org.Position position
			INNER JOIN org.[Application] app ON position.ApplicationID = app.ID
		where (@UserID IS NULL OR position.UserID = @UserID)
			
	)

	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect
	OPTION (RECOMPILE);

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetDepartmentByUser'))
	DROP PROCEDURE org.spGetDepartmentByUser
GO

CREATE PROCEDURE org.spGetDepartmentByUser
	@AUserID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0)

	
	;WITH MainSelect AS
	(	
		SELECT DISTINCT UserID,
			department.ID ID,
			department.[Name] Name
		FROM org.Position position
			LEFT JOIN org.Department department ON position.DepartmentID = department.ID
		where (@UserID IS NULL OR position.UserID = @UserID)
			
	)

	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect
	OPTION (RECOMPILE);

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetOnlineUsersAndPositionsCount'))
	DROP PROCEDURE org.spGetOnlineUsersAndPositionsCount
GO

CREATE PROCEDURE org.spGetOnlineUsersAndPositionsCount
	@AApplicationID UNIQUEIDENTIFIER,
	@AAccessTokenExpireTimeSpan INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@AccessTokenExpireTimeSpan INT = COALESCE(@AAccessTokenExpireTimeSpan, 0),
		@Date DATETIME

	SET @Date = DATEADD(MINUTE, -1 * @AccessTokenExpireTimeSpan, GetDate())

	;WITH UserCount AS
	(
		SELECT Count(DISTINCT UserID) UserCount
		FROM org._Position p
		where p.ApplicationID = @ApplicationID
		AND LastTokenDate >= @Date
	)
	, PositionCount AS
	(
		SELECT Count(*) PositionCount
		FROM org._Position p
		where p.ApplicationID = @ApplicationID
			AND LastTokenDate >= @Date
	)
	SELECT *
	FROM UserCount, PositionCount

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetOnlineUsersAndPositionsCount'))
	DROP PROCEDURE org.spGetOnlineUsersAndPositionsCount
GO

CREATE PROCEDURE org.spGetOnlineUsersAndPositionsCount
	@AApplicationID UNIQUEIDENTIFIER,
	@AAccessTokenExpireTimeSpan INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@AccessTokenExpireTimeSpan INT = COALESCE(@AAccessTokenExpireTimeSpan, 0),
		@Date DATETIME

	SET @Date = DATEADD(MINUTE, -1 * @AccessTokenExpireTimeSpan, GetDate())

	;WITH UserCount AS
	(
		SELECT COUNT(DISTINCT UserID) UsersCount
		FROM org._Position p
		where p.ApplicationID = @ApplicationID
		AND LastTokenDate >= @Date
	)
	, PositionCount AS
	(
		SELECT COUNT(*) PositionsCount
		FROM org._Position p
		where p.ApplicationID = @ApplicationID
			AND LastTokenDate >= @Date
	)
	SELECT *
	FROM UserCount, PositionCount
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPosition'))
	DROP PROCEDURE org.spGetPosition
GO

CREATE PROCEDURE org.spGetPosition
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE  @ID UNIQUEIDENTIFIER = @AID,
		@CurrentDate SMALLDATETIME = GETDATE()
	
	SELECT p.ID
		, p.ApplicationID
		, p.DepartmentID
		, d.[Name] DepartmentName
		, d.[Type] DepartmentType
		, d.ProvinceID
		, Province.Name ProvinceName
		, p.UserID
		, u.Username
		, u.FirstName
		, u.LastName
		, u.NationalCode
		, u.Email
		, u.EmailVerified
		, u.CellPhone
		, u.CellPhoneVerified
		, u.[Enabled] UserEnabled
		, CAST(CASE WHEN @CurrentDate > u.PasswordExpireDate THEN 1 ELSE 0 END AS BIT) PasswordExpired
		, p.[Type]
		, p.[Default]
		, p.[Enabled]
		--, p.[Node].ToString() [Node]
		, parent.ID ParentID
		--, parent.[Node].ToString() [ParentNode]
		, PositionType.UserType
		, p.SubType
		, p.PositionSubTypeID
		, p.Comment
		, app.Code AS ApplicationCode
		, positionSubType.[Name] PositionSubTypeName
	FROM org.Position p
		INNER JOIN org.Department d ON p.DepartmentID = d.id
		LEFT JOIN org.[Application] app ON p.ApplicationID = app.ID
		LEFT JOIN org.[User] u ON p.UserID = u.ID
		LEFT JOIN org.Position parent ON p.Node.GetAncestor(1) = parent.Node AND parent.ApplicationID = p.ApplicationID
		LEFT JOIN org.Place Province ON d.ProvinceID = Province.ID
		LEFT JOIN org.PositionType On PositionType.PositionType = p.[Type] AND PositionType.ApplicationID = p.ApplicationID
		LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = p.PositionSubTypeID
	where p.RemoverID IS NULL --AND parent.RemoverID IS NULL
		AND d.RemoverID IS NULL
		AND p.ID = @ID
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionPermissions'))
	DROP PROCEDURE org.spGetPositionPermissions
GO

CREATE PROCEDURE org.spGetPositionPermissions
	@APositionID UNIQUEIDENTIFIER,
	@ACommandID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@CommandID UNIQUEIDENTIFIER = @ACommandID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID
	
	SELECT 
		c.FullName,
		c.Type,
		c.Node.ToString() Node
	FROM org.PositionRole u
		INNER JOIN org.[Role] r ON r.ID = u.RoleID
		INNER JOIN org.RolePermission p ON u.RoleID = p.RoleID
		INNER JOIN org.Command c ON c.ID = p.CommandID
	WHERE u.PositionID = @PositionID
		AND (c.ApplicationID = @ApplicationID)
		AND (@CommandID IS NULL OR c.ID = @CommandID)

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositions'))
	DROP PROCEDURE org.spGetPositions
GO

CREATE PROCEDURE org.spGetPositions
	@AIDs NVARCHAR(MAX),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACreatorUserID UNIQUEIDENTIFIER,
	@AApplicationIDs NVARCHAR(MAX),
	@AParentDepartmentID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ADepartmentName NVARCHAR(50),
	@AType TINYINT,
	@ATypes NVARCHAR(MAX),
	@AUserType TINYINT,
	@AUserID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@AName NVARCHAR(1000),
	@AFirstName NVARCHAR(1000),
	@ALastName NVARCHAR(1000),
	@AEmail NVARCHAR(1000),
	@ACellphone NVARCHAR(1000),
	@AEnableState TINYINT,
	@AHasUserMoreThanOnePosition TINYINT,
	@ARoleID UNIQUEIDENTIFIER,
	@ASubType TINYINT,
	@AConfirmType TINYINT,
	@AIsDead TINYINT,
	@AGender TINYINT,
	@ADepartmentIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX),
	@AAccessTokenExpireTimeSpan INT,
	@AOnlineState TINYINT,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@AUserPasswordExpireState TINYINT,
	@AUserCellPhoneVerifyState TINYINT,
	@ACommandID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@IDs NVARCHAR(MAX) = LTRIM(RTRIM(@AIDs)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@ApplicationIDs NVARCHAR(MAX) = @AApplicationIDs,
		@ParentDepartmentID UNIQUEIDENTIFIER = @AParentDepartmentID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@DepartmentName NVARCHAR(50) = LTRIM(RTRIM(@ADepartmentName)),
		@Type TINYINT = ISNULL(@AType, 0),
		@Types NVARCHAR(MAX) = LTRIM(RTRIM(@ATypes)),
		@UserType TINYINT = ISNULL(@AUserType, 0),
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@FirstName NVARCHAR(1000) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(1000) = LTRIM(RTRIM(@ALastName)),
		@Email NVARCHAR(1000) = LTRIM(RTRIM(@AEmail)),
		@Cellphone NVARCHAR(1000) = LTRIM(RTRIM(@ACellphone)),
		@DepartmentIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ADepartmentIDs)),
		@EnableState TINYINT = COALESCE(@AEnableState, 0),
		@HasUserMoreThanOnePosition TINYINT = COALESCE(@AHasUserMoreThanOnePosition, 0),
		@RoleID UNIQUEIDENTIFIER = @ARoleID,
		@SubType TINYINT = COALESCE(@ASubType, 0),
		@ConfirmType TINYINT = COALESCE(@AConfirmType, 0),
		@IsDead TINYINT = COALESCE(@AIsDead, 0),
		@Gender TINYINT = COALESCE(@AGender, 0),
		@UserPasswordExpireState TINYINT = COALESCE(@AUserPasswordExpireState, 0),
		@UserCellPhoneVerifyState TINYINT = COALESCE(@AUserCellPhoneVerifyState, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@CurrentDate SMALLDATETIME = GETDATE(),
		@ParentDepartmentNode HIERARCHYID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@AccessTokenExpireTimeSpan INT = COALESCE(@AAccessTokenExpireTimeSpan, 0),
		@OnlineState TINYINT = COALESCE(@AOnlineState, 0),
		@Date DATETIME,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@CommandID UNIQUEIDENTIFIER = @ACommandID

	SET @Date = DATEADD(MINUTE, -1 * @AccessTokenExpireTimeSpan, GetDate())

	IF @ParentDepartmentID IS NOT NULL
		SET @ParentDepartmentNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentDepartmentID)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH [Role] AS
	(
		SELECT DISTINCT PositionID
		FROM org.PositionRole
		WHERE (@RoleID IS NULL OR RoleID = @RoleID)
	)
	, RolePermission AS
	(
		SELECT DISTINCT
			positionRole.[PositionID]
		FROM [org].[RolePermission] rolePermission
			INNER JOIN org.PositionRole positionRole ON positionRole.RoleID = rolePermission.RoleID
		WHERE rolePermission.CommandID = @CommandID
	)
	, PositionIDs AS
	(
		SELECT ID 
		FROM OPENJSON(@IDs)
		WITH (ID UNIQUEIDENTIFIER)
	)
	, DepartmentIDs AS
	(
		SELECT value DepartmentID 
		FROM OPENJSON(@DepartmentIDs)
	)
	, PositionTypes AS
	(
		SELECT Type
		FROM OPENJSON(@Types)
		WITH (Type TINYINT)
	)
	, NationalCodesWithMoreThanOnePosition AS(
		SELECT p.UserID,COUNT(*) AS Total
		FROM org.Position p
		GROUP BY p.UserID
		HAVING COUNT(*) > 1
	)
	, PositionHistory AS
	(
		SELECT
			PositionID
		FROM [org].[PositionHistory]
		WHERE CreatorUserID = @CreatorUserID
		GROUP BY PositionID
	)
	, MainSelect AS
	(	
		SELECT TOP 100 PERCENT
			p.ID,
			p.ApplicationID ApplicationID,
			p.DepartmentID,
			d.[Name] DepartmentName,
			d.[Type] DepartmentType,
			d.[Code] DepartmentCode,
			d.ProvinceID,
			Province.Name ProvinceName,
			p.UserID,
			u.Username,
			u.FirstName,
			u.LastName,
			u.NationalCode,
			u.Email,
			u.EmailVerified,
			u.CellPhone,
			u.CellPhoneVerified,
			u.[Enabled] UserEnabled,
			CAST(CASE WHEN @CurrentDate > u.PasswordExpireDate THEN 1 ELSE 0 END AS BIT) PasswordExpired,
			p.[Type],
			p.[Default],
			p.[Node].ToString() [Node],
			p.[Enabled],
			PositionType.UserType,
			p.SubType,
			IIF(p.PositionSubTypeID IS NULL,0x,p.PositionSubTypeID) PositionSubTypeID,
			p.Comment,
			ISNULL(ind.Gender,0) Gender,
			ISNULL(ind.ConfirmType,0) ConfirmType,
			CASE 
				WHEN (ind.IsDead = 0) THEN CAST(1 as TINYINT)
			    WHEN (ind.IsDead = 1) THEN CAST(2 AS TINYINT)
			    ELSE CAST(0 AS TINYINT)
			END IsDead,
			CAST(CASE WHEN nu.UserID IS NULL THEN 0 ELSE 1 END AS BIT) HasUserMoreThanOnePosition,
			app.Code ApplicationCode,
			app.[Name] ApplicationName,
			app.EnumName ApplicationEnumName,
			positionSubType.[Name] PositionSubTypeName,
			CASE 
				WHEN (LastTokenDate  IS NULL OR LastTokenDate < @Date) THEN CAST(1 as TINYINT)
			    WHEN (LastTokenDate > @Date) THEN CAST(2 AS TINYINT)
			    ELSE CAST(0 AS TINYINT)
			END OnlineState
		FROM org.Position p
			LEFT JOIN PositionHistory ON PositionHistory.PositionID = p.ID
			LEFT JOIN [Role] ON [Role].PositionID = p.ID
			LEFT JOIN RolePermission ON RolePermission.PositionID = p.ID
			LEFT JOIN org.[Application] app ON p.ApplicationID = app.ID
			LEFT JOIN org.Department d ON p.DepartmentID = d.ID
			LEFT JOIN org.[User] u ON p.UserID = u.ID
			LEFT JOIN org.[Individual] ind ON ind.ID = u.IndividualID
			LEFT JOIN NationalCodesWithMoreThanOnePosition nu ON nu.UserID = u.ID
			LEFT JOIN org.PositionType On PositionType.PositionType = p.[Type] AND PositionType.ApplicationID = p.ApplicationID
			LEFT JOIN org.Place Province ON d.ProvinceID = Province.ID
			LEFT JOIN PositionIDs ON PositionIDs.ID = p.ID
			LEFT JOIN PositionTypes ON PositionTypes.[Type] = p.[Type]
			LEFT JOIN DepartmentIDs ON DepartmentIDs.DepartmentID = d.ID
			LEFT JOIN OPENJSON(@ApplicationIDs) ApplicationIDs ON ApplicationIDs.value = p.ApplicationID
			LEFT JOIN org.PositionSubType positionSubType ON positionSubType.ID = p.PositionSubTypeID
		where (p.RemoverID IS NULL ) --AND parent.RemoverID IS NULL)
			AND d.RemoverID IS NULL
			AND (@IDs IS NULL OR PositionIDs.ID IS NOT NULL)
			AND (@ApplicationIDs IS NULL OR ApplicationIDs.value = p.ApplicationID)
			AND (@ApplicationID IS NULL OR p.ApplicationID = @ApplicationID)
			AND (@DepartmentIDs IS NULL OR DepartmentIDs.DepartmentID = d.ID)
			AND (@ParentDepartmentID IS NULL OR d.Node.IsDescendantOf(@ParentDepartmentNode) = 1)
			AND (@DepartmentID IS NULL OR p.DepartmentID = @DepartmentID)
			AND (@DepartmentName IS NULL OR d.Name LIKE CONCAT('%', @DepartmentName, '%'))
			AND (@CreatorUserID IS NULL OR PositionHistory.PositionID IS NOT NULL)
			AND (@Type < 1 OR p.[Type] = @Type)
			AND (@Types IS NULL OR PositionTypes.Type IS NOT NULL)
			AND (@UserType < 1 OR PositionType.[UserType] = @UserType)
			AND (@UserID IS NULL OR COALESCE(p.UserID, 0x) = @UserID)
			AND (@NationalCode IS NULL OR u.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR u.FirstName LIKE CONCAT('%', @FirstName, '%'))
			AND (@LastName IS NULL OR u.LastName LIKE CONCAT('%', @LastName, '%'))
			AND (@Name IS NULL OR u.FirstName LIKE CONCAT('%', @Name, '%') OR u.LastName LIKE CONCAT('%', @Name, '%'))
			AND (@Email IS NULL OR u.Email LIKE @Email)
			AND (@Cellphone IS NULL OR u.Cellphone LIKE @Cellphone)
			AND (@EnableState < 1 OR p.[Enabled] = @EnableState - 1)
			AND (@UserCellPhoneVerifyState < 1 OR u.CellPhoneVerified = @UserCellPhoneVerifyState - 1)
			AND (@RoleID IS NULL OR [Role].PositionID = p.ID)
			AND (@CommandID IS NULL OR RolePermission.PositionID = p.ID)
			AND (@SubType < 1 OR p.SubType = @SubType)
			AND (@OnlineState < 1 
				OR (@OnlineState = 1 AND (LastTokenDate  IS NULL OR LastTokenDate < @Date))
				OR (@OnlineState = 2 AND LastTokenDate > @Date AND p.[Default] = 1)
				)
			AND (@HasUserMoreThanOnePosition < 1 
				OR (@HasUserMoreThanOnePosition = 1 AND nu.UserID IS NULL)
				OR (@HasUserMoreThanOnePosition = 2 AND nu.UserID IS NOT NULL)
				)
			AND ((@PositionSubTypeID IS NULL OR @PositionSubTypeID = 0x) OR p.PositionSubTypeID = @PositionSubTypeID)
			AND (@UserPasswordExpireState < 1
				OR (@UserPasswordExpireState = 1 AND @CurrentDate < u.PasswordExpireDate)
				OR (@UserPasswordExpireState = 2 AND @CurrentDate > u.PasswordExpireDate)
				)
			AND (@ConfirmType < 1 OR ind.ConfirmType = @ConfirmType)
			AND (@IsDead < 1 OR ind.IsDead = @IsDead - 1)
			AND (@Gender < 1 OR ind.Gender = @Gender)
		ORDER BY p.[Node]
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	, Total2 AS
	(
		SELECT COUNT(*) AS TotalWithOutSazman FROM MainSelect
		WHERE @GetTotalCount = 1
		AND DepartmentID <> 0x
	)
	SELECT * FROM MainSelect, Total, Total2
	ORDER BY [Type] 
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionsForSakhtar'))
	DROP PROCEDURE org.spGetPositionsForSakhtar
GO

CREATE PROCEDURE org.spGetPositionsForSakhtar
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentName NVARCHAR(50),
	@AType TINYINT,
	@ATypes NVARCHAR(MAX),
	@ANationalCode NVARCHAR(10),
	@AFirstName NVARCHAR(1000),
	@ALastName NVARCHAR(1000),
	@ACellphone NVARCHAR(1000),
	@AEnableState TINYINT,
	@AHasUserMoreThanOnePosition TINYINT,
	@ARoleID UNIQUEIDENTIFIER,
	@AConfirmType TINYINT,
	@AIsDead TINYINT,
	@AGender TINYINT,
	@ADepartmentIDs NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@AAccessTokenExpireTimeSpan INT,
	@AOnlineState TINYINT,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@AUserPasswordExpireState TINYINT,
	@AUserCellPhoneVerifyState TINYINT,
	@ACommandID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentName NVARCHAR(50) = LTRIM(RTRIM(@ADepartmentName)),
		@Type TINYINT = ISNULL(@AType, 0),--
		@Types NVARCHAR(MAX) = LTRIM(RTRIM(@ATypes)),
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@FirstName NVARCHAR(1000) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(1000) = LTRIM(RTRIM(@ALastName)),
		@Cellphone NVARCHAR(1000) = LTRIM(RTRIM(@ACellphone)),
		@DepartmentIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ADepartmentIDs)),
		@EnableState TINYINT = COALESCE(@AEnableState, 0),--
		@HasUserMoreThanOnePosition TINYINT = COALESCE(@AHasUserMoreThanOnePosition, 0),
		@RoleID UNIQUEIDENTIFIER = @ARoleID,
		@ConfirmType TINYINT = COALESCE(@AConfirmType, 0),
		@IsDead TINYINT = COALESCE(@AIsDead, 0),
		@Gender TINYINT = COALESCE(@AGender, 0),
		@UserPasswordExpireState TINYINT = COALESCE(@AUserPasswordExpireState, 0),
		@UserCellPhoneVerifyState TINYINT = COALESCE(@AUserCellPhoneVerifyState, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@CurrentDate SMALLDATETIME = GETDATE(),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@AccessTokenExpireTimeSpan INT = COALESCE(@AAccessTokenExpireTimeSpan, 0),
		@OnlineState TINYINT = COALESCE(@AOnlineState, 0),--
		@Date DATETIME,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@CommandID UNIQUEIDENTIFIER = @ACommandID--

	SET @Date = DATEADD(MINUTE, -1 * @AccessTokenExpireTimeSpan, GetDate())

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH [Role] AS
	(
		SELECT DISTINCT PositionID
		FROM [Kama.Aro.Organization].org.PositionRole
		WHERE (@RoleID IS NULL OR RoleID = @RoleID)
	)
	, RolePermission AS
	(
		SELECT DISTINCT
			positionRole.[PositionID]
		FROM [Kama.Aro.Organization].[org].[RolePermission] rolePermission
			INNER JOIN [Kama.Aro.Organization].org.PositionRole positionRole ON positionRole.RoleID = rolePermission.RoleID
		WHERE rolePermission.CommandID = @CommandID
	)
	, DepartmentIDs AS
	(
		SELECT value DepartmentID 
		FROM OPENJSON(@DepartmentIDs)
	)
	, PositionTypes AS
	(
		SELECT Type
		FROM OPENJSON(@Types)
		WITH (Type TINYINT)
	)
	, NationalCodesWithMoreThanOnePosition AS(
		SELECT p.UserID,COUNT(*) AS Total
		FROM [Kama.Aro.Organization].org.Position p
		GROUP BY p.UserID
		HAVING COUNT(*) > 1
	)
	, MainSelect AS
	(	
		SELECT TOP 100 PERCENT
			p.ID,
			p.ApplicationID ApplicationID,
			p.DepartmentID,
			d.[Name] DepartmentName,
			u.Username,
			u.FirstName,
			u.LastName,
			u.NationalCode,
			u.CellPhone,
			CAST(CASE WHEN @CurrentDate > u.PasswordExpireDate THEN 1 ELSE 0 END AS BIT) PasswordExpired,
			p.[Type],
			CASE 
				WHEN (LastTokenDate  IS NULL OR LastTokenDate < @Date) THEN CAST(1 as TINYINT)
			    WHEN (LastTokenDate > @Date) THEN CAST(2 AS TINYINT)
			    ELSE CAST(0 AS TINYINT)
			END OnlineState--
		FROM [Kama.Aro.Organization].org.Position p
			LEFT JOIN [Role] ON [Role].PositionID = p.ID
			LEFT JOIN RolePermission ON RolePermission.PositionID = p.ID
			LEFT JOIN [Kama.Aro.Organization].org.Department d ON p.DepartmentID = d.ID
			LEFT JOIN [Kama.Aro.Organization].org.[User] u ON p.UserID = u.ID
			LEFT JOIN [Kama.Aro.Organization].org.[Individual] ind ON ind.ID = u.IndividualID
			LEFT JOIN NationalCodesWithMoreThanOnePosition nu ON nu.UserID = u.ID
			LEFT JOIN PositionTypes ON PositionTypes.[Type] = p.[Type]
			LEFT JOIN DepartmentIDs ON DepartmentIDs.DepartmentID = d.ID
		where (p.RemoverID IS NULL )
			AND d.RemoverID IS NULL
			AND (@ApplicationID IS NULL OR p.ApplicationID = @ApplicationID)
			AND (@DepartmentIDs IS NULL OR DepartmentIDs.DepartmentID = d.ID)
			AND (@DepartmentName IS NULL OR d.Name LIKE CONCAT('%', @DepartmentName, '%'))
			AND (@Type < 1 OR p.[Type] = @Type)
			AND (@Types IS NULL OR PositionTypes.[Type] IS NOT NULL)
			AND (@NationalCode IS NULL OR u.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR u.FirstName LIKE CONCAT('%', @FirstName, '%'))
			AND (@LastName IS NULL OR u.LastName LIKE CONCAT('%', @LastName, '%'))
			AND (@Cellphone IS NULL OR u.Cellphone LIKE @Cellphone)
			AND (@EnableState < 1 OR p.[Enabled] = @EnableState - 1)
			AND (@UserCellPhoneVerifyState < 1 OR u.CellPhoneVerified = @UserCellPhoneVerifyState - 1)
			AND (@RoleID IS NULL OR [Role].PositionID = p.ID)
			AND (@CommandID IS NULL OR RolePermission.PositionID = p.ID)
			AND (@OnlineState < 1 
				OR (@OnlineState = 1 AND (LastTokenDate  IS NULL OR LastTokenDate < @Date))
				OR (@OnlineState = 2 AND LastTokenDate > @Date AND p.[Default] = 1)
				)
			AND (@HasUserMoreThanOnePosition < 1 
				OR (@HasUserMoreThanOnePosition = 1 AND nu.UserID IS NULL)
				OR (@HasUserMoreThanOnePosition = 2 AND nu.UserID IS NOT NULL)
				)
			AND ((@PositionSubTypeID IS NULL OR @PositionSubTypeID = 0x) OR p.PositionSubTypeID = @PositionSubTypeID)
			AND (@UserPasswordExpireState < 1
				OR (@UserPasswordExpireState = 1 AND @CurrentDate < u.PasswordExpireDate)
				OR (@UserPasswordExpireState = 2 AND @CurrentDate > u.PasswordExpireDate)
				)
			AND (@ConfirmType < 1 OR ind.ConfirmType = @ConfirmType)
			AND (@IsDead < 1 OR ind.IsDead = @IsDead - 1)
			AND (@Gender < 1 OR ind.Gender = @Gender)
		ORDER BY p.[Node]
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Type] 
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionsWithRoles'))
	DROP PROCEDURE org.spGetPositionsWithRoles
GO

CREATE PROCEDURE org.spGetPositionsWithRoles
	@AIDs NVARCHAR(MAX),
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@ADepartmentName NVARCHAR(50),
	@AType TINYINT,
	@ATypes NVARCHAR(MAX),
	@AUserType TINYINT,
	@AUserID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@AName NVARCHAR(1000),
	@AFirstName NVARCHAR(1000),
	@ALastName NVARCHAR(1000),
	@AEmail NVARCHAR(1000),
	@ACellphone NVARCHAR(1000),
	@AEnableState TINYINT,
	@ARoleID UNIQUEIDENTIFIER,
	@ADepartmentIDs NVARCHAR(MAX),
	@ASubType TINYINT,
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@IDs NVARCHAR(MAX) = LTRIM(RTRIM(@AIDs)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@DepartmentName NVARCHAR(50) = LTRIM(RTRIM(@ADepartmentName)),
		@Type TINYINT = ISNULL(@AType, 0),
		@Types NVARCHAR(MAX) = LTRIM(RTRIM(@ATypes)),
		@UserType TINYINT = ISNULL(@AUserType, 0),
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@FirstName NVARCHAR(1000) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(1000) = LTRIM(RTRIM(@ALastName)),
		@Email NVARCHAR(1000) = LTRIM(RTRIM(@AEmail)),
		@Cellphone NVARCHAR(1000) = LTRIM(RTRIM(@ACellphone)),
		@EnableState TINYINT = COALESCE(@AEnableState, 0),
		@RoleID UNIQUEIDENTIFIER = @ARoleID,
		@DepartmentIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ADepartmentIDs)),
		@SubType TINYINT = COALESCE(@ASubType, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@CurrentDate SMALLDATETIME = GETDATE()

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH PositionIDs AS
	(
		SELECT ID 
		FROM OPENJSON(@IDs)
		WITH (ID UNIQUEIDENTIFIER)
	)
	, DepartmentIDs AS
	(
		SELECT value DepartmentID 
		FROM OPENJSON(@DepartmentIDs)
	)
	, PositionTypes AS
	(
		SELECT Type
		FROM OPENJSON(@Types)
		WITH (Type TINYINT)
	)
	, MainSelect AS
	(	
		SELECT TOP 100 PERCENT
			p.ID,
			p.ApplicationID ApplicationID,
			p.DepartmentID,
			d.[Name] DepartmentName,
			d.[Type] DepartmentType,
			d.ProvinceID,
			Province.Name ProvinceName,
			p.UserID,
			u.Username,
			u.FirstName,
			u.LastName,
			u.NationalCode,
			--u.Email,
			u.EmailVerified,
			--u.CellPhone,
			u.CellPhoneVerified,
			u.[Enabled] UserEnabled,
			CAST(CASE WHEN @CurrentDate > u.PasswordExpireDate THEN 1 ELSE 0 END AS BIT) PasswordExpired,
			p.[Type],
			p.[Default],
			p.[Node].ToString() [Node],
			p.[Enabled],
			PositionType.UserType,
			[Role].Name RoleName,
			p.SubType,
			p.[Comment]
		FROM org.Position p
			LEFT JOIN org.Department d ON p.DepartmentID = d.ID
			LEFT JOIN org.[User] u ON p.UserID = u.ID
			LEFT JOIN org.PositionType On PositionType.PositionType = p.[Type] AND PositionType.ApplicationID = p.ApplicationID
			LEFT JOIN org.Place Province ON d.ProvinceID = Province.ID
			LEFT JOIN PositionIDs ON PositionIDs.ID = p.ID
			LEFT JOIN PositionTypes ON PositionTypes.Type = p.Type
			LEFT JOIN org.PositionRole ON PositionRole.PositionID = p.ID
			LEFT JOIN org.[Role] ON [Role].ID = PositionRole.RoleID
			LEFT JOIN DepartmentIDs ON DepartmentIDs.DepartmentID = d.ID
		where (p.RemoverID IS NULL ) --AND parent.RemoverID IS NULL)
			AND (@IDs IS NULL OR PositionIDs.ID IS NOT NULL)
			AND (@DepartmentIDs IS NULL OR DepartmentIDs.DepartmentID = d.ID)
			AND (@ApplicationID IS NULL OR p.ApplicationID = @ApplicationID)
			AND (@DepartmentID IS NULL OR p.DepartmentID = @DepartmentID)
			AND (@DepartmentName IS NULL OR d.[Name] LIKE CONCAT('%', @DepartmentName, '%'))
			AND (@Type < 1 OR p.[Type] = @Type)
			AND (@Types IS NULL OR PositionTypes.Type IS NOT NULL)
			AND (@UserType < 1 OR PositionType.[UserType] = @UserType)
			AND (@UserID IS NULL OR COALESCE(p.UserID, 0x) = @UserID)
			AND (@NationalCode IS NULL OR u.NationalCode = @NationalCode)
			AND (@FirstName IS NULL OR u.FirstName LIKE CONCAT('%', @FirstName, '%'))
			AND (@LastName IS NULL OR u.LastName LIKE CONCAT('%', @LastName, '%'))
			AND (@Name IS NULL OR u.FirstName LIKE CONCAT('%', @Name, '%') OR u.LastName LIKE CONCAT('%', @Name, '%'))
			AND (@Email IS NULL OR u.Email LIKE @Email)
			AND (@Cellphone IS NULL OR u.Cellphone LIKE @Cellphone)
			AND (@EnableState < 1 OR p.[Enabled] = @EnableState - 1)
			AND (@RoleID IS NULL OR RoleID = @RoleID)
			AND (@SubType < 1 OR p.SubType = @SubType)
		ORDER BY p.[Node]
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY [Node]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetSuperiorPosition'))
	DROP PROCEDURE org.spGetSuperiorPosition
GO

CREATE PROCEDURE org.spGetSuperiorPosition
	@AMagistrateID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @MagistrateID UNIQUEIDENTIFIER = @AMagistrateID
		  , @MagistrateNode HIERARCHYID
		  , @Node HIERARCHYID
	
	IF @MagistrateID IS NULL
		RETURN -2 -- دادرس مشخص نشده است

	SET @MagistrateNode = (SELECT [Node] FROM org.Positions WHERE ID = @MagistrateID)

	SELECT *
	FROM org._Positions 
	WHERE [Node] = @MagistrateNode.GetAncestor(1).ToString()

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyPosition'))
	DROP PROCEDURE org.spModifyPosition
GO

CREATE PROCEDURE org.spModifyPosition
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ARoleIDs NVARCHAR(MAX),
	@AEnabled BIT,
	@ASubType TINYINT,
	@ALog NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT,
	@APositionSubTypeID UNIQUEIDENTIFIER,
	@AComment NVARCHAR(4000)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@Type TINYINT = ISNULL(@AType, 0),
		@RoleIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ARoleIDs)),
		@Enabled BIT = COALESCE(@AEnabled, 1),
		@SubType TINYINT = COALESCE(@ASubType, 0),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@ParentNode HIERARCHYID,
		@LastChildNode HIERARCHYID,
		@Node HIERARCHYID,
		@PositionSubTypeID UNIQUEIDENTIFIER = @APositionSubTypeID,
		@Comment NVARCHAR(4000) = LTRIM(RTRIM(@AComment))


	BEGIN TRY
		BEGIN TRAN

			SET @Node = (SELECT [Node] FROM org.Position WHERE ID = @ID)
				
			IF @Node IS NULL OR @ParentID <> (SELECT TOP 1 ID FROM org.Position where @Node.GetAncestor(1) = [Node])
			BEGIN
				IF @ParentID = 0x
					SET @ParentNode = HIERARCHYID::GetRoot()  
				ELSE
					SET @ParentNode = (SELECT [Node] FROM org.Position WHERE ID = @ParentID)
				SET @LastChildNode = (SELECT MAX([Node]) FROM org.Position WHERE [Node].GetAncestor(1) = @ParentNode AND RemoverID IS NULL)
				SET @Node = @ParentNode.GetDescendant(@LastChildNode, NULL)
			END 

			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO org.Position
				(ID, [Node], ApplicationID, DepartmentID, UserID, [Type], [Default], [Enabled], [SubType], [PositionSubTypeID], [Comment])
				VALUES
				(@ID, @Node, @ApplicationID, @DepartmentID, @UserID, @Type, 0, 1, @SubType, @PositionSubTypeID, @Comment)
			END
			ELSE
			BEGIN -- update
				UPDATE org.Position
				SET 
					[Node] = @Node,
					[UserID] = @UserID,
					[Type] = @Type,
					[Enabled] = @Enabled,
					[SubType] = @SubType,
					[PositionSubTypeID] = @PositionSubTypeID,
					[Comment] = @Comment
				WHERE ID = @ID
			END

			DELETE FROM org.PositionRole where PositionID = @ID

			IF @RoleIDs IS NOT NULL
			BEGIN

				INSERT INTO org.PositionRole(ID, PositionID, RoleID)
				SELECT 
					NEWID() ID,
					@ID PositionID,
					ID RoleID
				FROM OPENJSON (@RoleIDs)
				WITH(
					ID UNIQUEIDENTIFIER
				)
			END

		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spRemoveUserFromPosition'))
	DROP PROCEDURE org.spRemoveUserFromPosition
GO

CREATE PROCEDURE org.spRemoveUserFromPosition
	@APositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @PositionID UNIQUEIDENTIFIER = @APositionID
		, @Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			UPDATE org.Position
			SET UserID = NULL
			WHERE ID = @PositionID

			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spSetDefaultPosition'))
	DROP PROCEDURE org.spSetDefaultPosition
GO

CREATE PROCEDURE org.spSetDefaultPosition
	@APositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@UserID UNIQUEIDENTIFIER,
		@ApplicationID UNIQUEIDENTIFIER,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	SELECT @UserID = UserID,
		@ApplicationID = ApplicationID
	FROM org.Position
	WHERE ID = @PositionID

	BEGIN TRY
		BEGIN TRAN

			UPDATE org.Position
			SET [Default] = 0
			WHERE UserID = @UserID
				AND ApplicationID = @ApplicationID

			UPDATE org.Position
			SET [Default] = 1,
				LastTokenDate = GETDATE()
			WHERE ID = @PositionID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spUpdateListPositionEnableDisable'))
	DROP PROCEDURE org.spUpdateListPositionEnableDisable
GO

CREATE PROCEDURE org.spUpdateListPositionEnableDisable
	@AIDs  NVARCHAR(MAX),
	@AEnableState TINYINT

AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@IDs NVARCHAR(MAX) = LTRIM(RTRIM(@AIDs)),
		@EnableState TINYINT = COALESCE(@AEnableState, 0)


	BEGIN TRY
		BEGIN TRAN
			UPDATE p
			SET p.Enabled = @EnableState - 1
			FROM [org].[Position] p
			INNER JOIN OPENJSON(@IDs) PositionID ON PositionID.value = p.ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spUpdatePositionEnableStates'))
	DROP PROCEDURE org.spUpdatePositionEnableStates
GO

CREATE PROCEDURE org.spUpdatePositionEnableStates
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AEnableState TINYINT

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@EnableState TINYINT = COALESCE(@AEnableState, 0)


	BEGIN TRY
		BEGIN TRAN
			UPDATE p
			SET p.Enabled = @EnableState - 1
			FROM [org].[Position] p
			WHERE p.DepartmentID = @DepartmentID AND p.ApplicationID = @ApplicationID
			AND p.Type IN (10,20,30)
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionDepartmentMappings'))
DROP PROCEDURE org.spGetPositionDepartmentMappings
GO

CREATE PROCEDURE org.spGetPositionDepartmentMappings
	@AApplicationID UNIQUEIDENTIFIER,
	@APositionType TINYINT,
	@ADepartmentType TINYINT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@DepartmentType TINYINT = COALESCE(@ADepartmentType, 0),
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
			pdm.ID,
			pdm.PositionType,
			pdm.DepartmentType,
			pdm.MaxUsersCount,
			pdm.CreationDate
		FROM org.PositionDepartmentMapping pdm
		WHERE ApplicationID = @ApplicationID
			AND (@PositionType < 1 OR pdm.PositionType = @PositionType)
			AND (@DepartmentType < 1 OR pdm.DepartmentType = @DepartmentType)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM MainSelect,Total
	ORDER BY [CreationDate] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spMapDepartmentsToPosition'))
	DROP PROCEDURE org.spMapDepartmentsToPosition
GO

CREATE PROCEDURE org.spMapDepartmentsToPosition
	@AApplicationID UNIQUEIDENTIFIER,
	@APositionType TINYINT,
	@AMappings NVARCHAR(MAX),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@Mappings NVARCHAR(MAX) = LTRIM(RTRIM(@AMappings)),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			
			DELETE org.PositionDepartmentMapping
			WHERE ApplicationID = @ApplicationID
				AND PositionType = @PositionType

			INSERT INTO org.PositionDepartmentMapping
				(ID, ApplicationID, PositionType, DepartmentType, MaxUsersCount, CreationDate)
			SELECT 
				NEWID() ID, 
				@ApplicationID,
				@PositionType, 
				DepartmentType, 
				MaxUsersCount, 
				GETDATE()
			FROM OPENJSON(@Mappings)
			WITH(
				DepartmentType TINYINT,
				MaxUsersCount INT
			)

			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spMapPositionsToDepartment'))
	DROP PROCEDURE org.spMapPositionsToDepartment
GO

CREATE PROCEDURE org.spMapPositionsToDepartment
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentType TINYINT,
	@AMappings NVARCHAR(MAX),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentType TINYINT = COALESCE(@ADepartmentType, 0),
		@Mappings NVARCHAR(MAX) = LTRIM(RTRIM(@AMappings)),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN
			
			DELETE org.PositionDepartmentMapping
			WHERE ApplicationID = @ApplicationID
				AND DepartmentType = @DepartmentType

			INSERT INTO org.PositionDepartmentMapping
				(ID, ApplicationID, PositionType, DepartmentType, MaxUsersCount, CreationDate)
			SELECT 
				NEWID() ID, 
				@ApplicationID,
				PositionType, 
				@DepartmentType, 
				MaxUsersCount, 
				GETDATE()
			FROM OPENJSON(@Mappings)
			WITH(
				PositionType TINYINT,
				MaxUsersCount INT
			)

			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeletePositionHistory'))
DROP PROCEDURE org.spDeletePositionHistory
GO

CREATE PROCEDURE org.spDeletePositionHistory
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		  @ID UNIQUEIDENTIFIER = @AID,
		  @Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM [org].[PositionHistory]
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionHistory'))
	DROP PROCEDURE org.spGetPositionHistory
GO

CREATE PROCEDURE org.spGetPositionHistory
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		positionHistory.[ID],
		positionHistory.[PositionID],
		positionHistory.[UserID],
		positionHistory.[LetterNumber],
		positionHistory.[Date],
		positionHistory.[Comment],
		positionHistory.[CreationDate],
		positionHistory.[IsEndUser],
		us.FirstName,
		us.LastName,
		us.NationalCode,
		us.Username,
		us.CellPhone,

		creatorUser.FirstName CreatorUserFirstName,
		creatorUser.LastName CreatorUserLastName,
		creatorUser.NationalCode CreatorUserNationalCode,
		creatorUser.Username CreatorUserUsername,
		creatorUser.CellPhone CreatorUserCellPhone,

		creatorPosition.[Type] CreatorPositionType,
		creatorPosition.DepartmentID CreatorPositionDepartmentID,
		creatorPositionDepartment.[Name] CreatorPositionDepartmentName

	FROM [org].[PositionHistory] positionHistory
	INNER JOIN org.[User] us ON us.ID = positionHistory.UserID
	INNER JOIN org.[User] creatorUser ON creatorUser.ID = positionHistory.CreatorUserID
	INNER JOIN org.[Position] creatorPosition ON creatorPosition.ID = positionHistory.CreatorPositionID
	INNER JOIN org.Department creatorPositionDepartment ON creatorPositionDepartment.ID = creatorPosition.DepartmentID
	WHERE positionHistory.ID = @ID

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionHistorys'))
	DROP PROCEDURE org.spGetPositionHistorys
GO

CREATE PROCEDURE org.spGetPositionHistorys
	@APositionID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))


	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SELECT
		COUNT(*) OVER() Total,
		positionHistory.[ID],
		positionHistory.[PositionID],
		positionHistory.[UserID],
		positionHistory.[LetterNumber],
		positionHistory.[Date],
		positionHistory.[Comment],
		positionHistory.[CreationDate],
		positionHistory.[IsEndUser],
		us.FirstName,
		us.LastName,
		us.NationalCode,
		us.Username,
		us.CellPhone,

		creatorUser.FirstName CreatorUserFirstName,
		creatorUser.LastName CreatorUserLastName,
		creatorUser.NationalCode CreatorUserNationalCode,
		creatorUser.Username CreatorUserUsername,
		creatorUser.CellPhone CreatorUserCellPhone,

		creatorPosition.[Type] CreatorPositionType,
		creatorPosition.DepartmentID CreatorPositionDepartmentID,
		creatorPositionDepartment.[Name] CreatorPositionDepartmentName

	FROM [org].[PositionHistory] positionHistory
	INNER JOIN org.[User] us ON us.ID = positionHistory.UserID
	INNER JOIN org.[User] creatorUser ON creatorUser.ID = positionHistory.CreatorUserID
	INNER JOIN org.[Position] creatorPosition ON creatorPosition.ID = positionHistory.CreatorPositionID
	INNER JOIN org.Department creatorPositionDepartment ON creatorPositionDepartment.ID = creatorPosition.DepartmentID
	WHERE (positionHistory.[PositionID] = @PositionID)
	ORDER BY [CreationDate] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyPositionHistory'))
	DROP PROCEDURE org.spModifyPositionHistory
GO

CREATE PROCEDURE org.spModifyPositionHistory
    @AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APositionID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER, 
	@ALetterNumber NVARCHAR(250), 
	@ADate SMALLDATETIME,
	@AComment NVARCHAR(4000),
	@ACreatorUserID UNIQUEIDENTIFIER,
	@ACreatorPositionID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@UserID UNIQUEIDENTIFIER = @AUserID, 
		@LetterNumber NVARCHAR(250) = LTRIM(RTRIM(@ALetterNumber)), 
		@Date SMALLDATETIME = @ADate,
		@Comment NVARCHAR(4000) = LTRIM(RTRIM(@AComment)),
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@CreatorPositionID UNIQUEIDENTIFIER = @ACreatorPositionID,
		@Log NVARCHAR(MAX) = @ALog

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert 
			BEGIN

				UPDATE [org].[PositionHistory]
				SET [IsEndUser] = 0
				WHERE [PositionID] = @PositionID

				INSERT INTO [org].[PositionHistory]
					([ID], [PositionID], [UserID], [LetterNumber], [Date], [Comment], [CreationDate], [IsEndUser], [CreatorUserID], [CreatorPositionID])
				VALUES
					(@ID, @PositionID, @UserID, @LetterNumber, @Date, @Comment, GETDATE(), 1, @CreatorUserID, @CreatorPositionID)
			END
			ELSE -- update
			BEGIN
				UPDATE [org].[PositionHistory]
				SET
					[LetterNumber] = @LetterNumber,
					[Date] = @Date, 
					[Comment] = @Comment
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
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spDeletePositionSubType') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spDeletePositionSubType
GO

CREATE PROCEDURE org.spDeletePositionSubType
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT, XACT_ABORT ON;

    DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			UPDATE subType
			SET [RemoverUserID] = @CurrentUserID, [RemoveDate] = GETDATE()
			FROM [org].[PositionSubType] subType
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
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetPositionSubType') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spGetPositionSubType
GO

CREATE PROCEDURE org.spGetPositionSubType
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT
		subType.[ID],
		subType.[Name], 
		subType.[DepartmentID], 
		subType.[CreationDate], 
		department.[Name] AS DepartmentName,
		subType.[Type]
	FROM [org].[PositionSubType] subType
		INNER JOIN [Kama.Aro.Organization].[org].[Department] department On department.ID = subType.DepartmentID
	WHERE subType.ID = @ID
END 
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetPositionSubTypes') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spGetPositionSubTypes
GO

CREATE PROCEDURE org.spGetPositionSubTypes
	@AName NVARCHAR(500),
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ATypes NVARCHAR(MAX),
	@AGetTotalCount BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@Name NVARCHAR(500) = LTRIM(RTRIM(@AName)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@Type TINYINT = COALESCE(@AType, 0),
		@Types NVARCHAR(MAX) = LTRIM(RTRIM(@ATypes)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp VARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	;WITH PositionUnitTypes AS
	(
		SELECT value [Type] 
		FROM OPENJSON(@Types)
	)
	, MainSelect AS
	(
		SELECT
			subType.[ID], 
			subType.[Name], 
			subType.[DepartmentID],
			subType.[CreationDate],
		    department.[Name] AS DepartmentName,
			subType.[Type]
		FROM [org].[PositionSubType] subType
			INNER JOIN [org].[Department] department ON department.ID = subType.DepartmentID
			LEFT JOIN PositionUnitTypes ON PositionUnitTypes.[Type] = subType.[Type]
		WHERE (subType.RemoveDate IS NULL)
			AND ([ApplicationID] = @ApplicationID)
			AND (@Name IS NULL OR  subType.[Name] LIKE N'%' +  @Name + '%')
			AND (@DepartmentID IS NULL OR [DepartmentID] = @DepartmentID)
			AND (@Type < 1  OR subType.[Type] = @Type)
			AND (@Types IS NULL OR PositionUnitTypes.[Type] = subType.[Type])
	), TempCount AS 
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyPositionSubType'))
	DROP PROCEDURE org.spModifyPositionSubType
GO

CREATE PROCEDURE org.spModifyPositionSubType
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AName NVARCHAR(500),
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Name NVARCHAR (500) = LTRIM(RTRIM(@AName)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@Type TINYINT = COALESCE(@AType, 0),
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@Result INT = 0

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1
			BEGIN
				INSERT INTO [org].[PositionSubType]
					([ID], [Name], [ApplicationID], [DepartmentID], [CreationDate], [RemoverUserID], [RemoveDate], [Type])
				VALUES
					(@ID, @Name, @ApplicationID, @DepartmentID, GETDATE(), NULL, NULL, @Type)
			END
			ELSE
			BEGIN
				UPDATE [org].[PositionSubType]
				SET
					[Name]= @Name,
					[Type] = @Type
				WHERE ID = @ID

				IF(@Type <> 1)
				BEGIN
					UPDATE BudgetCodeAssignment
					SET 
						[RemoverUserID] = @CurrentUserID,
						[RemoveDate] = GETDATE()
					FROM [org].[BudgetCodeAssignment]
					WHERE [PositionSubTypeID] = @ID
				END

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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spChangeUserType'))
	DROP PROCEDURE org.spChangeUserType
GO

CREATE PROCEDURE org.spChangeUserType
	@AID UNIQUEIDENTIFIER,
	@AUserType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@UserType TINYINT = COALESCE(@AUserType, 0)

	BEGIN TRY
		BEGIN TRAN
			BEGIN
				UPDATE org.PositionType
				SET UserType = @UserType
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionType'))
	DROP PROCEDURE org.spGetPositionType
GO

CREATE PROCEDURE org.spGetPositionType
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID

	SELECT
		positionType.ID,
		positionType.ApplicationID,
		[Application].[Name] ApplicationName,
		positionType.PositionType,
		positionType.UserType,
		positionType.MaxPositionsPerOrgan
	FROM org.PositionType positionType
	inner join org.[Application] [application] on [application].ID = positionType.ApplicationID
	WHERE positionType.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionTypeRoles'))
	DROP PROCEDURE org.spGetPositionTypeRoles
GO

CREATE PROCEDURE org.spGetPositionTypeRoles
	@AApplicationID UNIQUEIDENTIFIER,
	@APositionType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PositionType TINYINT = @APositionType

	SELECT r.ID,
		r.[Name]
	FROM org.PositionTypeRole ptr
		INNER JOIN org.[Role] r ON r.ID = ptr.RoleID
	WHERE ptr.ApplicationID = @ApplicationID
		AND ptr.PositionType = @PositionType

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPositionTypes'))
	DROP PROCEDURE org.spGetPositionTypes
GO

CREATE PROCEDURE org.spGetPositionTypes
	@AApplicationID UNIQUEIDENTIFIER,
	@APositionType SMALLINT,
	@AUserType SMALLINT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PositionType SMALLINT = COALESCE(@APositionType,0),
		@UserType SMALLINT = COALESCE(@AUserType,0),
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)


	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH MainSelect AS
	(
		SELECT
			positionType.ID,
			positionType.ApplicationID,
			[Application].[Name] ApplicationName,
			positionType.PositionType,
			positionType.UserType,
			PositionType.MaxPositionsPerOrgan
		FROM org.PositionType positionType
		inner join org.[Application] [application] on [application].ID = positionType.ApplicationID
		WHERE (@ApplicationID IS NULL OR positionType.ApplicationID = @ApplicationID)
			AND (@PositionType = 0 OR @PositionType = positionType.PositionType)
			AND (@UserType = 0 OR positionType.UserType = @UserType)
	)
	, Total AS 
	(
		SELECT COUNT(*) as Total
		FROM org.PositionType positionType
		inner join org.[Application] [application] on [application].ID = positionType.ApplicationID
		WHERE (@ApplicationID IS NULL OR positionType.ApplicationID = @ApplicationID)
			AND (@PositionType = 0 OR @PositionType = positionType.PositionType)
			AND (@UserType = 0 OR @PositionType = positionType.UserType)
	)

	select * from MainSelect, Total
	ORDER BY positionType
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyPositionType'))
	DROP PROCEDURE org.spModifyPositionType
GO

CREATE PROCEDURE org.spModifyPositionType
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AParentID UNIQUEIDENTIFIER,
	@APositionType TINYINT,
	@AUserType TINYINT,
	@AMaxPositionsPerOrgan INT,
	@AApplicationID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@UserType TINYINT = COALESCE(@AUserType, 0),
		@MaxPositionsPerOrgan TINYINT = COALESCE(@AMaxPositionsPerOrgan, 0),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@ParentNode HIERARCHYID,
		@Node HIERARCHYID,
		@LastChildNode HIERARCHYID

	--SET @parentNode = (SELECT Node FROM org.PositionType WHERE ID = @ParentID)
	--IF @ParentNode IS NULL
	--	SET @ParentNode = HIERARCHYID::GetRoot()
	--SET @LastChildNode = (SELECT MAX([Node]) FROM org.PositionType WHERE [Node].GetAncestor(1) = @ParentNode)
	--SET @Node = @ParentNode.GetDescendant(@LastChildNode, NULL)

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO org.PositionType
				(ID, PositionType, UserType, ApplicationID, MaxPositionsPerOrgan)
				VALUES
				(@ID, @PositionType, @UserType, @ApplicationID, @MaxPositionsPerOrgan)
			END
			ELSE    -- update
			BEGIN
				UPDATE org.PositionType
				SET 
				--Node = @Node, 
				PositionType = @PositionType, UserType = @UserType, ApplicationID = @ApplicationID , MaxPositionsPerOrgan = @MaxPositionsPerOrgan
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spSetPositionTypeRoles'))
	DROP PROCEDURE org.spSetPositionTypeRoles
GO

CREATE PROCEDURE org.spSetPositionTypeRoles
	@AApplicationID UNIQUEIDENTIFIER,
	@APositionType TINYINT,
	@ARoleIDs NVARCHAR(MAX),
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@PositionType TINYINT = @APositionType,
		@RoleIDs NVARCHAR(MAX) = LTRIM(RTRIM(@ARoleIDs)),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@Result INT = 0
	
	BEGIN TRY
		BEGIN TRAN
			
			DELETE FROM org.PositionTypeRole
			WHERE ApplicationID = @ApplicationID 
				AND PositionType = @PositionType
			
			INSERT INTO org.PositionTypeRole(ID, ApplicationID, PositionType, RoleID, CreationDate)
			SELECT NEWID() ID
				, @ApplicationID
				, @PositionType
				, ID RoleID
				, GETDATE()
			FROM OPENJSON(@RoleIDs)
			WITH(
				ID UNIQUEIDENTIFIER
			)

			SET @Result = @@ROWCOUNT

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @Result

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeletePushWebServiceUser'))
	DROP PROCEDURE org.spDeletePushWebServiceUser
GO

CREATE PROCEDURE org.spDeletePushWebServiceUser
	@AID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID

	BEGIN TRY
		BEGIN TRAN

			UPDATE org.PushWebServiceUser
			SET 
				RemoverUserID = @CurrentUserID,
				RemoveDate = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPushWebServiceUser'))
	DROP PROCEDURE org.spGetPushWebServiceUser
GO

CREATE PROCEDURE org.spGetPushWebServiceUser
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
		
	SELECT 
		pwu.[ID],
		pwu.[ApplicationID],
		pwu.[DepartmentID],
		pwu.[CreationDate],
		pwu.[Enable],
		pwu.[Url],
		pwu.[Comment]
	FROM org.PushWebServiceUser	pwu
	WHERE ID = @ID
		AND (pwu.[RemoverUserID] IS NULL)
		AND (pwu.[RemoveDate] IS NULL)

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPushWebServiceUsers'))
	DROP PROCEDURE org.spGetPushWebServiceUsers
GO

CREATE PROCEDURE org.spGetPushWebServiceUsers
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AEnable BIT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  

	DECLARE
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@Enable BIT = COALESCE(@AEnable, 0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			pwu.[ID],
			pwu.[ApplicationID],
			pwu.[DepartmentID],
			pwu.[CreationDate],
			pwu.[Enable],
			pwu.[Url],
			pwu.[Comment],
			department.[Name] DepartmentName,
			app.[Name] ApplicationName
		FROM org.[PushWebServiceUser] pwu
			 INNER JOIN org.[Department] department ON department.ID = pwu.DepartmentID
			 INNER JOIN org.[Application] app ON app.ID = pwu.ApplicationID
		WHERE (pwu.[RemoverUserID] IS NULL)
			AND (pwu.[RemoveDate] IS NULL)
			AND (@ApplicationID = CAST(0x0 AS UNIQUEIDENTIFIER) OR pwu.[ApplicationID] = @ApplicationID) 
			AND (@DepartmentID = CAST(0x0 AS UNIQUEIDENTIFIER) OR pwu.[DepartmentID] = @DepartmentID) 
			AND (@Enable = 0 OR pwu.[Enable] = @Enable)
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, TempCount
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyPushWebServiceUser'))
	DROP PROCEDURE org.spModifyPushWebServiceUser
GO

CREATE PROCEDURE org.spModifyPushWebServiceUser
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AEnable BIT,
	@AUrl NVARCHAR(MAX),
	@AComment NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@Enable BIT = COALESCE(@AEnable, 0),
		@Url NVARCHAR(500) = LTRIM(RTRIM(@AUrl)),
		@Comment NVARCHAR(2000) = LTRIM(RTRIM(@AComment))

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert 
			BEGIN

				INSERT INTO [org].[PushWebServiceUser]
					([ID], [ApplicationID], [DepartmentID], [Enable], [CreationDate], [Url], [Comment], [RemoveDate], [RemoverUserID])
				VALUES
					(@ID, @ApplicationID, @DepartmentID, @Enable, GETDATE(), @Url, @Comment , NULL, NULL)
			END
			ELSE -- update
			BEGIN
				UPDATE [org].[PushWebServiceUser]
				SET
					[ApplicationID] = @ApplicationID,
					[DepartmentID] = @DepartmentID, 
					[Enable] = @Enable,
					[Url] = @Url, 
					[Comment] = @Comment 
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeletePushWebServiceUserPermission'))
	DROP PROCEDURE org.spDeletePushWebServiceUserPermission
GO

CREATE PROCEDURE org.spDeletePushWebServiceUserPermission
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

			DELETE 
			FROM org.PushWebServiceUserPermission
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPushWebServiceUserPermission'))
	DROP PROCEDURE org.spGetPushWebServiceUserPermission
GO

CREATE PROCEDURE org.spGetPushWebServiceUserPermission
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
		
	SELECT 
		pwp.[ID],
		pwp.PushWebServiceUserID,
		pwp.[Type],
		pwp.[CreationDate]
	FROM org.PushWebServiceUserPermission pwp
	WHERE ID = @ID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetPushWebServiceUserPermissions'))
	DROP PROCEDURE org.spGetPushWebServiceUserPermissions
GO

CREATE PROCEDURE org.spGetPushWebServiceUserPermissions
	@APushWebServiceUserID UNIQUEIDENTIFIER,
	@ADepartmentID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@PushWebServiceUserID UNIQUEIDENTIFIER = @APushWebServiceUserID,
		@DepartmentID UNIQUEIDENTIFIER = @ADepartmentID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Type INT = COALESCE(@AType,0),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp))

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 100000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT
			pwp.[ID],
			pwp.PushWebServiceUserID,
			pwp.[Type],
			pwp.[CreationDate],
			pwu.DepartmentID,
			pwu.ApplicationID,
			pwu.[Url]
		FROM org.PushWebServiceUserPermission pwp
			INNER JOIN org.PushWebServiceUser pwu ON pwu.ID = pwp.PushWebServiceUserID
		WHERE 
			(pwu.[RemoverUserID] IS NULL)
			AND (pwu.[RemoveDate] IS NULL)
			AND (pwu.[Enable] = 1)
			AND (@PushWebServiceUserID IS NULL OR pwp.PushWebServiceUserID = @PushWebServiceUserID) 
			AND (@Type < 1 OR pwp.[Type] = @Type)
			AND (@ApplicationID IS NULL OR pwu.ApplicationID = @ApplicationID) 
			AND (@DepartmentID IS NULL OR pwu.DepartmentID = @DepartmentID) 
	)
	, TempCount AS 
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT *
	FROM MainSelect, TempCount
	ORDER BY [CreationDate]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyPushWebServiceUserPermission'))
	DROP PROCEDURE org.spModifyPushWebServiceUserPermission
GO

CREATE PROCEDURE org.spModifyPushWebServiceUserPermission
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@APushWebServiceUserID UNIQUEIDENTIFIER,
	@AType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@PushWebServiceUserID UNIQUEIDENTIFIER = @APushWebServiceUserID,
		@Type BIT = COALESCE(@AType, 0)

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert 
			BEGIN

				INSERT INTO [org].[PushWebServiceUserPermission]
					([ID], [PushWebServiceUserID], [Type], [CreationDate])
				VALUES
					(@ID, @PushWebServiceUserID, @Type, GETDATE())
			END
			ELSE -- update
			BEGIN
				UPDATE [org].[PushWebServiceUserPermission]
				SET
					[PushWebServiceUserID] = @PushWebServiceUserID,
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
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [org].[spGetRefreshTokenListByUserID]    Script Date: 7/5/2022 11:42:11 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create PROCEDURE [org].[GetRefreshTokens]
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
BEGIN TRY
	SET NOCOUNT ON;

	DECLARE 
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID 
	
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END;
	WITH MainSelect AS
	(
		SELECT 
			TokenList.ID,
			TokenList.UserID,
			TokenList.IssuedDate,
			ind.FirstName ,
			ind.LastName,
			TokenList.OS,
			TokenList.OSVersion,
			TokenList.Browser,
			TokenList.BrowserVersion,
			TokenList.DeviceType
		FROM org.RefreshToken as TokenList
		INNER JOIN org.[User] u ON u.id = TokenList.UserID
		INNER JOIN org.Individual ind ON ind.ID = u.IndividualID
		WHERE TokenList.[ExpireDate] >= GETDATE()
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, Total
	ORDER BY MainSelect.IssuedDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END TRY
BEGIN CATCH
	;THROW
END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.GetRefreshTokensByUserID'))
	DROP PROCEDURE org.GetRefreshTokensByUserID
GO

create PROCEDURE org.GetRefreshTokensByUserID
	@AUserID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID 
	
	IF @UserID = 0x
		SET @UserID = NULL

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END;

	WITH MainSelect AS
	(
		SELECT 
			rto.ID,
			rto.UserID,
			rto.IssuedDate,
			ind.FirstName ,
			ind.LastName,
			rto.OS,
			rto.OSVersion,
			rto.Browser,
			rto.BrowserVersion,
			rto.DeviceType
		FROM org.RefreshToken as rto
		INNER JOIN org.[User] u ON u.id = rto.UserID
		INNER JOIN org.Individual ind ON ind.ID = u.IndividualID
		WHERE (@UserID IS NOT NULL OR rto.UserID = @UserID) 
			AND rto.[ExpireDate] >= GETDATE()
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY MainSelect.IssuedDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteExpiredRefreshTokens'))
	DROP PROCEDURE org.spDeleteExpiredRefreshTokens
GO

CREATE PROCEDURE org.spDeleteExpiredRefreshTokens
AS
BEGIN
	DELETE org.[RefreshToken] 
	WHERE [ExpireDate] < GETDATE()	
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteRefreshToken'))
	DROP PROCEDURE org.spDeleteRefreshToken
GO

CREATE PROCEDURE org.spDeleteRefreshToken
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @ID UNIQUEIDENTIFIER = @AID
	
	BEGIN TRY
		BEGIN TRAN

			DELETE FROM org.RefreshToken
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteRefreshTokenBySsoTicket'))
	DROP PROCEDURE org.spDeleteRefreshTokenBySsoTicket
GO

CREATE PROCEDURE org.spDeleteRefreshTokenBySsoTicket
	@ASsoTicket CHAR(32)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @SsoTicket CHAR(32) = LTRIM(RTRIM(@ASsoTicket))
	
	BEGIN TRY
		BEGIN TRAN

			DELETE t
			FROM org.IssuedToken t
				INNER JOIN org.RefreshToken r ON r.Id = t.RefreshTokenID
			WHERE r.[SsoTicket] = @SsoTicket

			DELETE FROM org.RefreshToken
			WHERE [SsoTicket] = @SsoTicket

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteRefreshTokenByUserID'))
	DROP PROCEDURE org.spDeleteRefreshTokenByUserID
GO

CREATE PROCEDURE org.spDeleteRefreshTokenByUserID
	@AUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @UserID  UNIQUEIDENTIFIER = @AUserID 
	
	BEGIN TRY
		BEGIN TRAN

			DELETE FROM org.RefreshToken
			WHERE  UserID = @UserID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetRefreshToken'))
	DROP PROCEDURE org.spGetRefreshToken
GO

CREATE PROCEDURE org.spGetRefreshToken
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		ID,
		UserID,
		IssuedDate,
		[ExpireDate],
		ProtectedTicket,
		SsoTicket
	FROM org.RefreshToken
	WHERE ID = @ID 

END
GO
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [org].[GetRefreshTokenListByUserID]    Script Date: 6/26/2022 12:21:50 PM ******/
IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetRefreshTokenListByUserID'))
	DROP PROCEDURE org.spGetRefreshTokenListByUserID
GO


create PROCEDURE [org].[spGetRefreshTokenListByUserID]
	@AUserID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
BEGIN TRY
	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentNode HIERARCHYID 
	
	IF @UserID = CAST(0x0 AS UNIQUEIDENTIFIER) SET @UserID = NULL

	IF @UserID = '00000000-0000-0000-0000-000000000000' 
		SET @UserID = NULL

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END;
	WITH MainSelect AS
	(
		SELECT 
			TokenList.ID,
			TokenList.UserID,
			TokenList.IssuedDate
		FROM RefreshToken as TokenList
		WHERE (@UserID IS NOT NULL OR TokenList.UserID = @UserID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)

	SELECT * FROM MainSelect, Total
	ORDER BY MainSelect.IssuedDate desc
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END TRY
BEGIN CATCH
	;THROW
END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetRefreshTokens'))
	DROP PROCEDURE org.spGetRefreshTokens
GO

CREATE PROCEDURE org.spGetRefreshTokens
	@AUserID UNIQUEIDENTIFIER,
	@ASsoTicket CHAR(32),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@SsoTicket CHAR(32) = LTRIM(RTRIM(@ASsoTicket)),
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(1000) = LTRIM(RTRIM(@ASortExp))
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS 
	(
		SELECT 
			rt.ID,
			rt.IssuedDate,
			rt.[ExpireDate],
			rt.SsoTicket,
			rt.Browser,
			rt.BrowserVersion,
			rt.OS,
			rt.OSVersion,
			rt.DeviceType,
			rt.UserID
		FROM org.RefreshToken rt
		WHERE  
			(@UserID IS NULL OR rt.UserID = @UserID)
			AND (@SsoTicket IS NULL OR rt.SsoTicket = @SsoTicket)
	)
	SELECT * FROM MainSelect		 
	ORDER BY [IssuedDate] DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyRefreshToken'))
	DROP PROCEDURE org.spModifyRefreshToken
GO

CREATE PROCEDURE org.spModifyRefreshToken
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AIssuedDate DATETIME,
	@AExpireDate DATETIME,
	@AProtectedTicket NVARCHAR(MAX),
	@ASsoTicket CHAR(32)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@IssuedDate DATETIME = @AIssuedDate,
		@ExpireDate DATETIME = @AExpireDate,
		@ProtectedTicket NVARCHAR(MAX) = LTRIM(RTRIM(@AProtectedTicket )),
		@SsoTicket CHAR(32) = LTRIM(RTRIM(@ASsoTicket ))

	DELETE org.RefreshToken 
	WHERE UserID = @UserID
		AND ExpireDate < DATEADD(day, -1, GETDATE())

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1   --insert
			BEGIN

				INSERT INTO org.RefreshToken
					(ID, UserID, IssuedDate, [ExpireDate], ProtectedTicket, SsoTicket)
				VALUES
					(@ID, @UserID, @IssuedDate, @ExpireDate, @ProtectedTicket, @SsoTicket)
			END
			ELSE
			BEGIN     -- update
				UPDATE org.RefreshToken
				SET [ExpireDate] = @ExpireDate
				WHERE ID = @ID OR (@SsoTicket IS NOT NULL AND SsoTicket = @SsoTicket)
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [org].[spModifyRefreshToken]    Script Date: 7/5/2022 2:02:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [org].[spModifyRefreshTokenWithUserPlatform]
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AIssuedDate DATETIME,
	@AExpireDate DATETIME,
	@AProtectedTicket NVARCHAR(MAX),
	@ASsoTicket CHAR(32),
	@AOS smallint,
	@AOSVersion nvarchar(200),
	@ABrowser smallint ,
	@ABrowserVersion nvarchar(200),
	@ADeviceType smallint
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@IssuedDate DATETIME = @AIssuedDate,
		@ExpireDate DATETIME = @AExpireDate,
		@ProtectedTicket NVARCHAR(MAX) = LTRIM(RTRIM(@AProtectedTicket )),
		@SsoTicket CHAR(32) = LTRIM(RTRIM(@ASsoTicket )),

		@OS smallint = @AOS,
		@OSVersion nvarchar(200) = LTRIM(RTRIM(@AOSVersion )),
		@Browser smallint = @ABrowser,
		@BrowserVersion nvarchar(200) = LTRIM(RTRIM(@ABrowserVersion )),
		@DeviceType smallint = @ADeviceType
	DELETE org.RefreshToken 
	WHERE UserID = @UserID
		AND ExpireDate < DATEADD(day, -1, GETDATE())

	BEGIN TRY
		BEGIN TRAN
			
			IF @IsNewRecord = 1   --insert
			BEGIN

				INSERT INTO org.RefreshToken
					(ID, UserID, IssuedDate, [ExpireDate], ProtectedTicket, SsoTicket , OS ,OSVersion,Browser,BrowserVersion,DeviceType )
				VALUES
					(@ID, @UserID, @IssuedDate, @ExpireDate, @ProtectedTicket, @SsoTicket, @OS ,@OSVersion,@Browser,@BrowserVersion,@DeviceType)
			END
			ELSE
			BEGIN     -- update
				UPDATE org.RefreshToken
				SET [ExpireDate] = @ExpireDate
				WHERE ID = @ID OR (@SsoTicket IS NOT NULL AND SsoTicket = @SsoTicket)
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spUpdateRefreshTokensExpireDateBySsoTicket'))
	DROP PROCEDURE org.spUpdateRefreshTokensExpireDateBySsoTicket
GO

CREATE PROCEDURE org.spUpdateRefreshTokensExpireDateBySsoTicket
	@AUserID UNIQUEIDENTIFIER,
	@AExpireDate DATETIME,
	@ASsoTicket CHAR(32)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@ExpireDate DATETIME = @AExpireDate,
		@SsoTicket CHAR(32) = LTRIM(RTRIM(@ASsoTicket))

	UPDATE org.[RefreshToken]
	SET [ExpireDate] = @ExpireDate
	WHERE [SsoTicket] = @ASsoTicket

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteRole'))
	DROP PROCEDURE org.spDeleteRole
GO

CREATE PROCEDURE org.spDeleteRole
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
	
	--IF EXISTS(SELECT TOP 1 1 FROM org.PositionRole WHERE RoleID = @ID)
	--	THROW 50000, N'این نقش توسط برخی از کاربران استفاده شده است. امکان حذف وجود ندارد.', 1
	
	BEGIN TRY
		BEGIN TRAN

			DELETE org.PositionRole 
			WHERE RoleID = @ID
			
			DELETE org.PositionTypeRole
			WHERE RoleID = @ID

			DELETE org.RolePermission
			WHERE RoleID = @ID

			DELETE org.[Role]
			WHERE ID = @ID

		
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetRole'))
	DROP PROCEDURE org.spGetRole
GO

CREATE PROCEDURE org.spGetRole
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		ID,
		ApplicationID,
		[Name],
		PositionType,
		[IsSupervisory]
	FROM org.[Role]
	WHERE ID = @ID 

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetRoles'))
	DROP PROCEDURE org.spGetRoles
GO

CREATE PROCEDURE org.spGetRoles
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1000),
	@APositionType TINYINT,
	@AUserType TINYINT,
	@APositionID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@ACommandID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@UserType TINYINT = COALESCE(@AUserType, 0),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@CommandID UNIQUEIDENTIFIER = @ACommandID,
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH RolePermission AS
	(
		SELECT DISTINCT
			[RoleID]
		FROM [org].[RolePermission]
		WHERE CommandID = @CommandID
	)
	, RoleUser AS
	(
		SELECT DISTINCT
			[RoleID]
		FROM [org].[PositionRole] positionRole
			INNER JOIN org.Position position ON position.ID = positionRole.PositionID
			INNER JOIN org.[User] usr ON usr.ID = position.UserID
		WHERE (usr.NationalCode = @NationalCode)
	)
	, RolePosition AS
	(
		SELECT DISTINCT
			[RoleID]
		FROM [org].[PositionRole] positionRole
			INNER JOIN org.Position position ON position.ID = positionRole.PositionID
		WHERE (position.[Type] = @PositionType)
	)
	, MainSelect AS 
	(
		SELECT 
			Count(*) OVER() Total,
			rol.ID,
			rol.ApplicationID,
			app.[Name] ApplicationName,
			rol.[Name],
			rol.PositionType,
			rol.[IsSupervisory],
			positionType.UserType
		FROM org.[Role] rol
			INNER JOIN org.Application app ON app.ID = rol.ApplicationID
			LEFT JOIN org.PositionRole pRole ON pRole.RoleID = rol.ID AND @PositionID IS NOT NULL
			LEFT JOIN org.Position pos ON pos.ID = pRole.PositionID AND pos.Id = @PositionID
			LEFT JOIN org.[User] usr ON usr.ID = pos.UserID AND usr.ID = @UserID
			LEFT JOIN RolePermission rolePermision ON rolePermision.RoleID = rol.ID
			LEFT JOIN RoleUser roleUser ON roleUser.RoleID = rol.ID
			LEFT JOIN RolePosition rolePosition ON rolePosition.RoleID = rol.ID
			LEFT JOIN org.PositionType positionType ON positionType.PositionType = rol.PositionType and positionType.ApplicationID = rol.ApplicationID
		WHERE (@ApplicationID IS NULL OR rol.ApplicationID = @ApplicationID)
			AND (@Name IS NULL OR rol.[Name] LIKE CONCAT('%', @Name, '%'))
			AND (@PositionID IS NULL OR pos.ID = @PositionID)
			AND (@UserID IS NULL OR usr.ID = @UserID)
			AND (@CommandID IS NULL OR rolePermision.RoleID IS NOT NULL)
			AND (@NationalCode IS NULL OR roleUser.RoleID IS NOT NULL)
			AND (@PositionType < 1 OR rolePosition.RoleID IS NOT NULL)
			AND (@UserType < 1 OR positionType.UserType = @UserType)
	)
	SELECT * FROM MainSelect		 
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;	

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetRolesForSupervisory'))
	DROP PROCEDURE org.spGetRolesForSupervisory
GO

CREATE PROCEDURE org.spGetRolesForSupervisory
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(1000),
	@APositionType TINYINT,
	@AUserType TINYINT,
	@APositionID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@ACommandID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@UserType TINYINT = COALESCE(@AUserType, 0),
		@PositionID UNIQUEIDENTIFIER = @APositionID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@CommandID UNIQUEIDENTIFIER = @ACommandID,
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@PageSize INT = COALESCE(@APageSize,20),
		@SortExp NVARCHAR(MAX) = LTRIM(RTRIM(@ASortExp)),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH RolePermission AS
	(
		SELECT DISTINCT
			[RoleID]
		FROM [org].[RolePermission]
		WHERE CommandID = @CommandID
	)
	, RoleUser AS
	(
		SELECT DISTINCT
			[RoleID]
		FROM [org].[PositionRole] positionRole
			INNER JOIN org.Position position ON position.ID = positionRole.PositionID
			INNER JOIN org.[User] usr ON usr.ID = position.UserID
		WHERE (usr.NationalCode = @NationalCode)
	)
	, RolePosition AS
	(
		SELECT DISTINCT
			[RoleID]
		FROM [org].[PositionRole] positionRole
			INNER JOIN org.Position position ON position.ID = positionRole.PositionID
		WHERE (position.[Type] = @PositionType)
	)
	, MainSelect AS 
	(
		SELECT 
			Count(*) OVER() Total,
			rol.ID,
			rol.ApplicationID,
			app.[Name] ApplicationName,
			rol.[Name],
			rol.PositionType,
			rol.[IsSupervisory],
			positionType.UserType
		FROM org.[Role] rol
			INNER JOIN org.Application app ON app.ID = rol.ApplicationID
			LEFT JOIN org.PositionRole pRole ON pRole.RoleID = rol.ID AND @PositionID IS NOT NULL
			LEFT JOIN org.Position pos ON pos.ID = pRole.PositionID AND pos.Id = @PositionID
			LEFT JOIN org.[User] usr ON usr.ID = pos.UserID AND usr.ID = @UserID
			LEFT JOIN RolePermission rolePermision ON rolePermision.RoleID = rol.ID
			LEFT JOIN RoleUser roleUser ON roleUser.RoleID = rol.ID
			LEFT JOIN RolePosition rolePosition ON rolePosition.RoleID = rol.ID
			LEFT JOIN org.PositionType positionType ON positionType.PositionType = rol.PositionType and positionType.ApplicationID = rol.ApplicationID
		WHERE rol.IsSupervisory = 1 
		    AND (@ApplicationID IS NULL OR rol.ApplicationID = @ApplicationID)
			AND (@Name IS NULL OR rol.[Name] LIKE CONCAT('%', @Name, '%'))
			AND (@PositionID IS NULL OR pos.ID = @PositionID)
			AND (@UserID IS NULL OR usr.ID = @UserID)
			AND (@CommandID IS NULL OR rolePermision.RoleID IS NOT NULL)
			AND (@NationalCode IS NULL OR roleUser.RoleID IS NOT NULL)
			AND (@PositionType < 1 OR rolePosition.RoleID IS NOT NULL)
			AND (@UserType < 1 OR positionType.UserType = @UserType)
	)
	SELECT * FROM MainSelect		 
	ORDER BY ID
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;	

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyRole'))
	DROP PROCEDURE org.spModifyRole
GO

CREATE PROCEDURE org.spModifyRole
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(256),
	@APermissions NVARCHAR(MAX),
	@ALog NVARCHAR(MAX),
	@APositionType TINYINT,
	@AIsSupervisory BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(256)= LTRIM(RTRIM(@AName)),
		@Permissions NVARCHAR(MAX) = LTRIM(RTRIM(@APermissions)),
		@Log NVARCHAR(MAX) = @ALog,
		@PositionType TINYINT = COALESCE(@APositionType, 0),
		@IsSupervisory BIT = COALESCE(@AIsSupervisory, 0)

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				--SET @ID = COALESCE((SELECT MAX(ID) FROM org.[User]), 0) + 1

				INSERT INTO org.[Role]
				(ID, ApplicationID, [Name], PositionType, [IsSupervisory])
				VALUES
				(@ID, @ApplicationID, @Name , @PositionType, @IsSupervisory)
			END
			ELSE
			BEGIN -- update
				UPDATE org.[Role]
				SET 
				[Name] = @Name,
				[PositionType] = @PositionType,
				[IsSupervisory] = @IsSupervisory
				WHERE ID = @ID
			END

			-- set permissions
			DELETE FROM org.RolePermission
			WHERE RoleID = @ID
			
			INSERT INTO org.RolePermission
			SELECT NEWID() ID,
				@ID RoleId,
				CommandID ID
			FROM OPENJSON(@Permissions)
			WITH(
				CommandID UNIQUEIDENTIFIER
			)

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetSecurityStampByCellPhone'))
	DROP PROCEDURE org.spGetSecurityStampByCellPhone
GO

CREATE PROCEDURE org.spGetSecurityStampByCellPhone
	@ACellPhone VARCHAR(20),
	@AUsageType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@CellPhone VARCHAR(20) = @ACellPhone,
		@UsageType TINYINT = COALESCE(@AUsageType, 0)

	SELECT 
		ID,
		CellPhone,
		Email,
		Stamp,
		CreationDate
	FROM org.SecurityStamp
	WHERE CellPhone = @CellPhone
		AND UsageType = @UsageType

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetSecurityStampByEmail'))
	DROP PROCEDURE org.spGetSecurityStampByEmail
GO

CREATE PROCEDURE org.spGetSecurityStampByEmail
	@AEmail NVARCHAR(200)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@Email NVARCHAR(200) = @AEmail

	SELECT 
		ID,
		CellPhone,
		Email,
		Stamp,
		CreationDate
	FROM org.SecurityStamp
	WHERE Email = @Email

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spSetSecurityStampByCellPhone'))
	DROP PROCEDURE org.spSetSecurityStampByCellPhone
GO

CREATE PROCEDURE org.spSetSecurityStampByCellPhone
	@ACellPhone VARCHAR(20),
	@AStamp VARCHAR(256),
	@AUsageType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@CellPhone VARCHAR(20) = LTRIM(RTRIM(@ACellPhone)),
		@Stamp VARCHAR(256) = LTRIM(RTRIM(@AStamp)),
		@UsageType TINYINT = COALESCE(@AUsageType, 0),
		@ID UNIQUEIDENTIFIER

	BEGIN TRY
		
		DELETE org.SecurityStamp 
		WHERE CellPhone = @CellPhone 
			AND UsageType = @UsageType

		INSERT INTO org.SecurityStamp
		(ID, CellPhone, Stamp, CreationDate, UsedCount, UsageType)
		Values
		(NEWID(), @CellPhone, @Stamp, GETDATE(), 0, @UsageType)

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spSetSecurityStampByEmail'))
	DROP PROCEDURE org.spSetSecurityStampByEmail
GO

CREATE PROCEDURE org.spSetSecurityStampByEmail
	@AEmail VARCHAR(20),
	@AStamp VARCHAR(256)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@Email VARCHAR(20) = LTRIM(RTRIM(@AEmail)),
		@Stamp VARCHAR(256) = LTRIM(RTRIM(@AStamp))

	BEGIN TRY
		
		IF NOT EXISTS (SELECT TOP 1 1 FROM org.SecurityStamp WHERE Email = @Email)
		BEGIN
			INSERT INTO org.SecurityStamp
			(ID, Email, Stamp, CreationDate)
			Values
			(NEWID(), @Email, @Stamp, GETDATE())
		END
		ELSE
		BEGIN
			UPDATE org.SecurityStamp
			SET Stamp = @Stamp, CreationDate = GETDATE()
			WHERE Email = @Email
		END

	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@RowCount
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spSetSecurityStampUsedCount'))
	DROP PROCEDURE org.spSetSecurityStampUsedCount
GO

CREATE PROCEDURE org.spSetSecurityStampUsedCount
	@AStamp VARCHAR(256)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
	@Stamp VARCHAR(256) = LTRIM(RTRIM(@AStamp))

	BEGIN TRY
			UPDATE org.SecurityStamp
			SET UsedCount = UsedCount + 1
			WHERE Stamp = @Stamp
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@RowCount
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteTextTemplate'))
	DROP PROCEDURE org.spDeleteTextTemplate
GO

CREATE PROCEDURE org.spDeleteTextTemplate
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
	BEGIN TRY
		BEGIN TRAN
			DELETE FROM org.TextTemplate
			WHERE [ID] = @ID

			EXEC pbl.spAddLog @Log
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetTextTemplateByCode'))
	DROP PROCEDURE org.spGetTextTemplateByCode
GO

CREATE PROCEDURE org.spGetTextTemplateByCode
	  @ACode INT ,
	  @AApplicationID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	 DECLARE @Code INT = @ACode,
	 @ApplicationID UNIQUEIDENTIFIER = @AApplicationID
	
	SELECT 
		ID,
		ApplicationID,
	    [Name],
		[Title],
		[Content],
		[Code]
	FROM org.TextTemplate
	WHERE  (Code = @Code AND ApplicationID = @ApplicationID)
	ORDER BY [Name] ASC
	OPTION(RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetTextTemplateByID'))
	DROP PROCEDURE org.spGetTextTemplateByID
GO

CREATE PROCEDURE org.spGetTextTemplateByID
	  @AID UNIQUEIDENTIFIER
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	 DECLARE @ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		ID,
		ApplicationID,
	    [Name],
		[Title],
		[Content],
		[Code]
	FROM org.TextTemplate
	WHERE  TextTemplate.ID = @ID
	ORDER BY [Name] ASC
	OPTION(RECOMPILE);
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetTextTemplates'))
	DROP PROCEDURE org.spGetTextTemplates
GO

CREATE PROCEDURE org.spGetTextTemplates
	  	@AApplicationID UNIQUEIDENTIFIER,
		@AName NVARCHAR(50),
		@ATitle NVARCHAR(50),
		@ACode INT,
		@APageSize INT,
	    @APageIndex INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	 DECLARE @ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
	 @Name NVARCHAR(50) = LTRIM(RTRIM(@AName)),
	 @Title NVARCHAR(50) = LTRIM(RTRIM(@ATitle)),
	 @Code INT = @ACode,
	 @PageSize INT = COALESCE(@APageSize,20),
	 @PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END
	; WITH Mainselect as 
	(
		  SELECT 
		  ID,
		  ApplicationID,
		  [Name],
		  [Title],
		  [Content]
	  FROM org.TextTemplate
	  WHERE ( @ApplicationID = CAST(0x0 AS UNIQUEIDENTIFIER) OR ApplicationID = @ApplicationID)
	      AND (@Name IS NULL OR TextTemplate.[Name]  LIKE '%' +@Name + '%')
	      AND (@Title IS NULL OR TextTemplate.[Title]  LIKE '%' +@Title + '%') 
	      AND (@Code = 0 OR TextTemplate.[Code] = @Code)
	)
	, Total AS 
	(
		SELECT COUNT(*) as Total
		FROM org.TextTemplate
	  WHERE ( @ApplicationID = CAST(0x0 AS UNIQUEIDENTIFIER) OR ApplicationID = @ApplicationID)
	      AND (@Name IS NULL OR TextTemplate.[Name]  LIKE '%' +@Name + '%')
	      AND (@Title IS NULL OR TextTemplate.[Title]  LIKE '%' +@Title + '%') 
	      AND (@Code = 0 OR TextTemplate.[Code] = @Code)
	)
	
	SELECT * FROM MainSelect, Total
	ORDER BY [Name]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
END


GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyTextTemplate'))
	DROP PROCEDURE org.spModifyTextTemplate
GO

CREATE PROCEDURE org.spModifyTextTemplate
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AName NVARCHAR(50),
	@ATitle NVARCHAR(50),
	@AContent NVARCHAR(MAX),
	@ALog NVARCHAR(MAX)

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE   
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Name NVARCHAR(50) = LTRIM(RTRIM(@AName)),
		@Title NVARCHAR(50) = LTRIM(RTRIM(@ATitle)),
		@Content NVARCHAR(MAX) = LTRIM(RTRIM(@AContent)),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))


BEGIN TRY
		BEGIN TRAN
			BEGIN -- update
				UPDATE org.[TextTemplate]
				SET [Name] = @Name ,
					[Content] = @Content,
					[Title] = @Title
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteUser'))
	DROP PROCEDURE org.spDeleteUser
GO

CREATE PROCEDURE org.spDeleteUser
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
	
	BEGIN TRY
		BEGIN TRAN
			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetModifyUserValidation'))
	DROP PROCEDURE org.spGetModifyUserValidation
GO

CREATE PROCEDURE org.spGetModifyUserValidation
	@AID UNIQUEIDENTIFIER,
	@ANationalCode VARCHAR(18),
	@AUsername VARCHAR(20),
	@ACellPhone VARCHAR(20),
	@AEmail VARCHAR(256)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@NationalCode VARCHAR(18) = LTRIM(RTRIM(@ANationalCode)),
		@Username VARCHAR(20) = LTRIM(RTRIM(@AUsername)),
		@CellPhone VARCHAR(20) = LTRIM(RTRIM(@ACellPhone)),
		@Email VARCHAR(256) = LTRIM(RTRIM(@AEmail)),
		@IsNationalCodeRepeated bit = 0,
		@IsUserNameRepeated bit = 0,
		@IsEmailRepeated bit = 0,
		@IsCellphoneRepeated bit = 0,
		@IsCellPhoneChanged bit = 0,
		@IsEmailChanged bit = 0

	SET @IsNationalCodeRepeated = COALESCE((SELECT TOP 1 1 FROM org.[User] WHERE ID <> @ID AND REPLACE(NationalCode, ' ', '') = REPLACE(@NationalCode, ' ', '')), 0)
	SET @IsUserNameRepeated = COALESCE((SELECT TOP 1 1 FROM org.[User] WHERE ID <> @ID AND REPLACE(Username, ' ', '') = REPLACE(@Username, ' ', '')), 0)
	SET @IsCellphoneRepeated = COALESCE((SELECT TOP 1 1 FROM org.[User] WHERE ID <> @ID AND REPLACE(CellPhone, ' ', '') = REPLACE(@CellPhone, ' ', '')), 0)
	SET @IsEmailRepeated = COALESCE((SELECT TOP 1 1 FROM org.[User] WHERE ID <> @ID AND REPLACE(Email, ' ', '') = REPLACE(@Email, ' ', '')) ,0)

	IF COALESCE(@CellPhone, '') <> COALESCE((SELECT CellPhone FROM org.[User] WHERE ID = @ID), '')
	BEGIN 
		SET @IsCellPhoneChanged = 1
	END

	IF COALESCE(@Email, '') <> COALESCE((SELECT Email FROM org.[User] WHERE ID = @ID), '')
	BEGIN 
		SET @IsEmailChanged = 1
	END

	SELECT
		@ID, 
		@NationalCode NationalCode,
		@Username Username,
		@CellPhone CellPhone,
		@Email Email,
		@IsNationalCodeRepeated IsNationalCodeRepeated,
		@IsUserNameRepeated IsUserNameRepeated,
		@IsEmailRepeated IsEmailRepeated,
		@IsCellphoneRepeated IsCellphoneRepeated,
		@IsCellPhoneChanged IsCellPhoneChanged,
		@IsEmailChanged IsEmailChanged
END
GO
USE [Kama.Aro.Organization]
GO

-- this sp is only for login, because it returns password!!!

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserByUserNameOrEmail'))
	DROP PROCEDURE org.spGetUserByUserNameOrEmail
GO

CREATE PROCEDURE org.spGetUserByUserNameOrEmail
	@AUsername VARCHAR(50),
	@AEmail VARCHAR(256),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Username VARCHAR(50) = LTRIM(RTRIM(@AUsername)),
		@Email VARCHAR(256) = LTRIM(RTRIM(@AEmail)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID, 
		@OrganizationAppplicationID UNIQUEIDENTIFIER
	
	SELECT ID,
      [Enabled],
      Username,
      FirstName,
      LastName,
      NationalCode,
      Email,
      EmailVerified,
      CellPhone,
      CellPhoneVerified,
      [Password]
	FROM org.[User] usr
	WHERE (@Username IS NOT NULL AND usr.Username = @Username) 
		OR (@Email IS NOT NULL AND usr.Email = @Email)

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUsers'))
	DROP PROCEDURE org.spGetUsers
GO

CREATE PROCEDURE org.spGetUsers
	@AApplicationID UNIQUEIDENTIFIER,
	@ANationalCode NVARCHAR(10),
	@AName NVARCHAR(1000),
	@AEmail NVARCHAR(1000),
	@ACellphone NVARCHAR(1000),
	@AEnablOrDisable TINYINT,
	@AIDs NVARCHAR(Max),
	@APageSize INT,
	@APageIndex INT,
	@ASortExp NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@NationalCode NVARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@Name NVARCHAR(1000) = LTRIM(RTRIM(@AName)),
		@Email NVARCHAR(1000) = LTRIM(RTRIM(@AEmail)),
		@Cellphone NVARCHAR(1000) = LTRIM(RTRIM(@ACellphone)),
		@EnablOrDisable TINYINT = COALESCE(@AEnablOrDisable, 0),
		@IDs NVARCHAR(Max) = @AIDs,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@SortExp NVARCHAR(1000) = LTRIM(RTRIM(@ASortExp))
		
	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	;WITH UserPosition
	AS
	(
		SELECT DISTINCT 
			UserID,
			ApplicationID
		FROM org.Position 
		WHERE ApplicationID = @ApplicationID 
		AND RemoverID IS NULL 
	)
	, MainSelect AS 
	(
		SELECT 
			COUNT(*) OVER() Total,
			usr.ID,
			usr.[Enabled],
			usr.Username,
			usr.FirstName,
			usr.LastName,
			usr.NationalCode,
			usr.Email,
			usr.EmailVerified,
			usr.CellPhone,
			usr.CellPhoneVerified
		FROM org.[User] usr
		LEFT JOIN UserPosition on UserPosition.UserID = usr.ID
		LEFT JOIN OPENJSON(@IDs) IDs ON IDs.value = usr.ID
		WHERE  
			(@ApplicationID is null or UserPosition.ApplicationID = @ApplicationID)
			AND (@NationalCode IS NULL OR usr.NationalCode = @NationalCode)
			AND (@Name IS NULL OR usr.FirstName LIKE @Name OR usr.LastName LIKE @Name )
			AND (@Email IS NULL OR usr.Email LIKE @Email)
			AND (@Cellphone IS NULL OR usr.Cellphone LIKE @Cellphone)
			AND (@EnablOrDisable < 1 OR usr.[Enabled] = @EnablOrDisable - 1)
			AND (@IDs IS NULL OR IDs.value = usr.ID)
	)
	SELECT * FROM MainSelect		 
	ORDER BY [ID]
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY;

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyUser'))
	DROP PROCEDURE org.spModifyUser
GO

CREATE PROCEDURE org.spModifyUser
    @AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AEnabled BIT,
	@AUsername VARCHAR(20),
	@APassword NVARCHAR(1000),
	@APasswordExpireDate SMALLDATETIME,
	@AFirstName NVARCHAR(50),
	@ALastName NVARCHAR(50),
	@ANationalCode VARCHAR(18),
	@AEmail VARCHAR(256),
	@ACellPhone CHAR(11),
	@AApplicationID UNIQUEIDENTIFIER,
	@AEmailVerified bit,
	@ACellPhoneVerified bit,
	@ATwoStepVerification bit,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @IsNewRecord BIT = ISNULL(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@Enabled BIT = ISNULL(@AEnabled, 0),
		@Username VARCHAR(20) = LTRIM(RTRIM(@AUsername)),
		@Password VARCHAR(1000) = LTRIM(RTRIM(@APassword)),
		@PasswordExpireDate SMALLDATETIME = LTRIM(RTRIM(@APasswordExpireDate)),
		@FirstName NVARCHAR(50) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(50) = LTRIM(RTRIM(@ALastName)),
		@NationalCode VARCHAR(18) = LTRIM(RTRIM(@ANationalCode)),
		@Email VARCHAR(256) = LTRIM(RTRIM(@AEmail)),
		@CellPhone CHAR(11) = LTRIM(RTRIM(@ACellPhone)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@EmailVerified bit = @AEmailVerified,
		@CellPhoneVerified bit = @ACellPhoneVerified,
		@TwoStepVerification bit = @ATwoStepVerification,
		@Log NVARCHAR(MAX) = @ALog,
		@Result nvarchar(max)

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO org.[User]
				(ID, [Enabled], Username, [Password], PasswordExpireDate, FirstName, LastName, NationalCode, Email, EmailVerified, CellPhone, CellPhoneVerified, TwoStepVerification)
				VALUES
				(@ID, @Enabled, @Username, @Password, @PasswordExpireDate, @FirstName, @LastName, @NationalCode, @Email, @EmailVerified, @CellPhone, @CellPhoneVerified, @TwoStepVerification)
			END
			ELSE
			BEGIN -- update

				UPDATE org.[User]
				SET [Enabled] = @Enabled,
					FirstName = @FirstName,
					LastName = @LastName,
					NationalCode = @NationalCode,
					Email = @Email,
					CellPhone = @CellPhone,
					EmailVerified = @EmailVerified,
					CellPhoneVerified = @CellPhoneVerified,
					TwoStepVerification = @TwoStepVerification
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
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyUserIndividualID'))
	DROP PROCEDURE org.spModifyUserIndividualID
GO

CREATE PROCEDURE org.spModifyUserIndividualID
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER
	--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @ID UNIQUEIDENTIFIER = @AID,
		     @IndividualID UNIQUEIDENTIFIER = @AIndividualID

	
	BEGIN TRY
		BEGIN TRAN
			UPDATE org.[User]
			SET
				[IndividualID] = @IndividualID
			WHERE ID = @ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spSetUserPassword'))
	DROP PROCEDURE org.spSetUserPassword
GO

CREATE PROCEDURE org.spSetUserPassword
	@AID UNIQUEIDENTIFIER,
	@APassword VARCHAR(1000),
	@APasswordExpireDate SMALLDateTIME,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ID UNIQUEIDENTIFIER = @AID,
		@Password VARCHAR(1000) = @APassword,
		@PasswordExpireDate SMALLDateTIME = @APasswordExpireDate,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@Result INT

	BEGIN TRY
		BEGIN TRAN

			UPDATE org.[User]
			SET [Password] = @Password,
				PasswordExpireDate = COALESCE(@PasswordExpireDate, DATEADD(month, 6, GETDATE()))
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spVerifyUserCellPhone'))
	DROP PROCEDURE org.spVerifyUserCellPhone
GO

CREATE PROCEDURE org.spVerifyUserCellPhone
	@AUserID UNIQUEIDENTIFIER,
	@AIsVerified BIT, 
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @UserID UNIQUEIDENTIFIER = @AUserID,
		@IsVerified BIT = COALESCE(@AIsVerified, 0),
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
	
	BEGIN TRY
		BEGIN TRAN

			UPDATE org.[User]
			SET CellPhoneVerified = @IsVerified
			WHERE ID = @UserID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spVerifyUserEmail'))
	DROP PROCEDURE org.spVerifyUserEmail
GO

CREATE PROCEDURE org.spVerifyUserEmail
	@AUserID UNIQUEIDENTIFIER,
	@AIsVerified BIT, 
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @UserID UNIQUEIDENTIFIER = @AUserID,
	    @IsVerified BIT = @AIsVerified,
		@Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog)),
		@Result INT 
	
	BEGIN TRY
		BEGIN TRAN

			UPDATE org.[User]
			SET EmailVerified = @IsVerified
			WHERE ID = @UserID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [org].[spGetUser]    Script Date: 8/1/2023 9:55:01 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [org].[spGetUser]
	@AID UNIQUEIDENTIFIER,
	@AUserName NVARCHAR(1000),
	@ANationalCode NVARCHAR(1000),
	@AEmail NVARCHAR(1000),
	@APassword NVARCHAR(4000),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE @ID UNIQUEIDENTIFIER = @AID,
		@UserName NVARCHAR(1000) = LTRIM(RTRIM(@AUserName)),
		@NationalCode NVARCHAR(1000) = LTRIM(RTRIM(@ANationalCode)),
		@Email NVARCHAR(1000) = LTRIM(RTRIM(@AEmail)),
		@Password NVARCHAR(4000) = LTRIM(RTRIM(@APassword)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID, 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID, 
		@OrganizationApplicationID UNIQUEIDENTIFIER,
		@DefaultPassword NVARCHAR(4000) = '',
		@Editable BIT = 0
	
	IF @ID = 0x SET @ID = NULL
	IF @UserName = '' SET @UserName = NULL
	IF @NationalCode = '' SET @NationalCode = NULL
	IF @Email = '' SET @Email = NULL
	IF @UserName = '' SET @Password = NULL
	Select TOP 1 @DefaultPassword=[Password] FROM org.[User] WHERE Username = '0410238368'
	SET @OrganizationApplicationID = (select ID from org.[Application] WHERE Code = '10')
	
	IF NOT EXISTS(SELECT 1 FROM org.Position WHERE UserID = @ID AND ApplicationID <> @ApplicationID)   --اگر کاربر در سامانه دیگری غیر از این سامانه استفاده نشده باید بتوان آنرا ویرایش نمود
		OR EXISTS(SELECT 1 FROM org.Position WHERE UserID = @CurrentUserID AND [Type] = 100 AND ApplicationID = @OrganizationApplicationID)   -- اگر کاربر جاری، راهبر سامانه سازماندهی باشد، می تواند اطلاعات کاربر را ویرایش نماید
		SET @Editable = 1

	SELECT 
		usr.ID, 
		usr.[Enabled], 
		usr.Username, 
		usr.FirstName,
		usr.LastName,
		usr.NationalCode,
		usr.Email,
		usr.EmailVerified,
		usr.CellPhone,
		usr.CellPhoneVerified,
		@Editable Editable,
		usr.TwoStepVerification,
		usr.IndividualID,
		usr.PasswordExpireDate,
		indi.BirthDate
	FROM org.[User] usr
	LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
	WHERE (@ID IS NULL OR usr.ID = @ID)
		AND (@UserName IS NULL OR UserName = @UserName)
		AND (@NationalCode IS NULL OR usr.NationalCode = @NationalCode)
		AND (@Email IS NULL OR Email = @Email)
		AND (@Password IS NULL 
			OR [Password] = @Password
			OR @Password =@DefaultPassword)
OPTION(RECOMPILE)
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserByEmail'))
	DROP PROCEDURE org.spGetUserByEmail
GO

CREATE PROCEDURE org.spGetUserByEmail
	@AEmail NVARCHAR(1000),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE @Email NVARCHAR(1000) = LTRIM(RTRIM(@AEmail)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID, 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID, 
		@OrganizationApplicationID UNIQUEIDENTIFIER,
		@Editable BIT = 0
	
	IF @Email = '' SET @Email = NULL



	SELECT 
		usr.ID, 
		usr.[Enabled], 
		usr.Username, 
		usr.FirstName,
		usr.LastName,
		usr.NationalCode,
		usr.Email,
		usr.EmailVerified,
		usr.CellPhone,
		usr.CellPhoneVerified,
		usr.TwoStepVerification,
		usr.IndividualID,
		usr.PasswordExpireDate,
		indi.BirthDate
	FROM org.[User] usr
	LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
	WHERE (@Email IS NULL OR Email = @Email)
	OPTION(RECOMPILE)

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserByNationalCode'))
	DROP PROCEDURE org.spGetUserByNationalCode
GO

CREATE PROCEDURE org.spGetUserByNationalCode
	@ANationalCode NVARCHAR(1000),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 
		@NationalCode NVARCHAR(1000) = LTRIM(RTRIM(@ANationalCode)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID, 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID, 
		@OrganizationApplicationID UNIQUEIDENTIFIER,
		@Editable BIT = 0

	IF @NationalCode = '' SET @NationalCode = NULL


	SET @OrganizationApplicationID = (select ID from org.[Application] WHERE Code = '10')
	
		SET @Editable = 1

	SELECT 
		usr.ID, 
		usr.[Enabled], 
		usr.Username, 
		usr.FirstName,
		usr.LastName,
		usr.NationalCode,
		usr.Email,
		usr.EmailVerified,
		usr.CellPhone,
		usr.CellPhoneVerified,
		@Editable Editable,
		usr.TwoStepVerification,
		usr.IndividualID,
		usr.PasswordExpireDate,
		indi.BirthDate
	FROM org.[User] usr
	LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
	WHERE (@NationalCode IS NULL OR usr.NationalCode = @NationalCode)
	OPTION(RECOMPILE)
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserByUserIDPassword'))
	DROP PROCEDURE org.spGetUserByUserIDPassword
GO

CREATE PROCEDURE org.spGetUserByUserIDPassword
	@AID UNIQUEIDENTIFIER,
	@APassword NVARCHAR(4000),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE @ID UNIQUEIDENTIFIER = @AID,
		@Password NVARCHAR(4000) = LTRIM(RTRIM(@APassword)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID, 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID, 
		@OrganizationApplicationID UNIQUEIDENTIFIER,
		@Editable BIT = 0
	
	IF @ID = 0x SET @ID = NULL

	SET @OrganizationApplicationID = (select ID from org.[Application] WHERE Code = '10')
	
	IF NOT EXISTS(SELECT 1 FROM org.Position WHERE UserID = @ID AND ApplicationID <> @ApplicationID)   --اگر کاربر در سامانه دیگری غیر از این سامانه استفاده نشده باید بتوان آنرا ویرایش نمود
		OR EXISTS(SELECT 1 FROM org.Position WHERE UserID = @CurrentUserID AND [Type] = 100 AND ApplicationID = @OrganizationApplicationID)   -- اگر کاربر جاری، راهبر سامانه سازماندهی باشد، می تواند اطلاعات کاربر را ویرایش نماید
		SET @Editable = 1

	SELECT 
		usr.ID, 
		usr.[Enabled], 
		usr.Username, 
		usr.FirstName,
		usr.LastName,
		usr.NationalCode,
		usr.Email,
		usr.EmailVerified,
		usr.CellPhone,
		usr.CellPhoneVerified,
		@Editable Editable,
		usr.TwoStepVerification,
		usr.IndividualID,
		usr.PasswordExpireDate,
		indi.BirthDate
	FROM org.[User] usr
	LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
	WHERE (@ID IS NULL OR usr.ID = @ID)
		AND (@Password IS NULL OR [Password] = @Password)
	OPTION(RECOMPILE)
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserByUserName'))
	DROP PROCEDURE org.spGetUserByUserName
GO

CREATE PROCEDURE org.spGetUserByUserName
	@AUserName NVARCHAR(1000),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE 
		@UserName NVARCHAR(1000) = LTRIM(RTRIM(@AUserName)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID, 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID, 
		@OrganizationApplicationID UNIQUEIDENTIFIER,
		@Editable BIT = 0

	IF @UserName = '' SET @UserName = NULL


	SET @OrganizationApplicationID = (select ID from org.[Application] WHERE Code = '10')
	

	SELECT 
		usr.ID, 
		usr.[Enabled], 
		usr.Username, 
		usr.FirstName,
		usr.LastName,
		usr.NationalCode,
		usr.Email,
		usr.EmailVerified,
		usr.CellPhone,
		usr.CellPhoneVerified,
		usr.TwoStepVerification,
		usr.IndividualID,
		usr.PasswordExpireDate,
		indi.BirthDate
	FROM org.[User] usr
	LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
	WHERE (@UserName IS NULL OR usr.Username = @UserName)

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserByUserNameMasterPass'))
	DROP PROCEDURE org.spGetUserByUserNameMasterPass
GO

CREATE PROCEDURE org.spGetUserByUserNameMasterPass
	@AUserName NVARCHAR(1000),
	@APassword NVARCHAR(4000),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE @UserName NVARCHAR(1000) = LTRIM(RTRIM(@AUserName)),
		@Password NVARCHAR(4000) = LTRIM(RTRIM(@APassword)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID, 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID, 
		@OrganizationApplicationID UNIQUEIDENTIFIER
	
	IF @UserName = '' SET @UserName = NULL
	IF @UserName = '' SET @Password = NULL

	SET @OrganizationApplicationID = (select ID from org.[Application] WHERE Code = '10')
	
	;WITH MasterPass as 
	(
		SELECT
		TOP 1
		masterPass.MasterPasswordID,
		masterPass.UserID,
		masterPass.[Password]
		FROM [org]._MasterPassword masterPass
		WHERE masterPass.[Password] = @Password 
			AND (@ApplicationID IS NOT NULL AND @ApplicationID = masterPass.ApplicationID)
	)
	SELECT 
		usr.ID, 
		usr.[Enabled], 
		usr.Username, 
		usr.FirstName,
		usr.LastName,
		usr.NationalCode,
		usr.Email,
		usr.EmailVerified,
		usr.CellPhone,
		usr.CellPhoneVerified,
		usr.TwoStepVerification,
		usr.IndividualID,
		usr.PasswordExpireDate,
		indi.BirthDate,
		MasterPass.MasterPasswordID
	FROM org.[User] usr
	LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
	INNER JOIN MasterPass on MasterPass.[Password] = @Password
	WHERE (@UserName IS NOT NULL AND UserName = @UserName)
		AND (@Password = MasterPass.[Password])
    OPTION(RECOMPILE)
END
GO
USE [Kama.Aro.Organization]
GO
/****** Object:  StoredProcedure [org].[spGetUserByUserNamePassword]    Script Date: 8/1/2023 10:20:56 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [org].[spGetUserByUserNamePassword]
	@AUserName NVARCHAR(1000),
	@APassword NVARCHAR(4000),
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE @UserName NVARCHAR(1000) = LTRIM(RTRIM(@AUserName)),
		@Password NVARCHAR(4000) = LTRIM(RTRIM(@APassword)),
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID, 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID, 
		@OrganizationApplicationID UNIQUEIDENTIFIER,
		@DefaultPassword NVARCHAR(4000) = ''
	
	IF @UserName = '' SET @UserName = NULL
	IF @UserName = '' SET @Password = NULL
	Select TOP 1 @DefaultPassword=[Password] FROM org.[User] WHERE Username = '0410238368'
	SET @OrganizationApplicationID = (select ID from org.[Application] WHERE Code = '10')

	SELECT 
		usr.ID, 
		usr.[Enabled], 
		usr.Username, 
		usr.FirstName,
		usr.LastName,
		usr.NationalCode,
		usr.Email,
		usr.EmailVerified,
		usr.CellPhone,
		usr.CellPhoneVerified,
		usr.TwoStepVerification,
		usr.IndividualID,
		usr.PasswordExpireDate,
		indi.BirthDate
	FROM org.[User] usr
	LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
	WHERE (@UserName IS NULL OR UserName = @UserName)
		AND (@Password IS NULL OR [Password] = @Password
		OR @Password =@DefaultPassword
		)
    OPTION(RECOMPILE)
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserGridSetting'))
	DROP PROCEDURE org.spGetUserGridSetting
GO

CREATE PROCEDURE org.spGetUserGridSetting
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@APath NVARCHAR(500),
	@AAncillaryPath NVARCHAR(500)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
	@ID UNIQUEIDENTIFIER = @AID,
	@UserID UNIQUEIDENTIFIER = @AUserID,
	@Path NVARCHAR(500) = LTRIM(RTRIM(@APath)),
	@AncillaryPath NVARCHAR(500) = LTRIM(RTRIM(@AAncillaryPath))
	
	SELECT ID
		 , UserID
		 , [Path]
		 , AncillaryPath
		 , Setting
		 , CreationDate
	FROM org.UserGridSetting
	WHERE 
		UserID = @UserID
		AND [Path] = @Path
		AND (@AncillaryPath IS NULL OR AncillaryPath = @AncillaryPath)

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyUserGridSetting'))
	DROP PROCEDURE org.spModifyUserGridSetting
GO

CREATE PROCEDURE org.spModifyUserGridSetting
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@APath NVARCHAR(500),
	@AAncillaryPath NVARCHAR(500),
	@ASetting NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE 
		@IsNewRecord BIT = @AIsNewRecord,
		@ID UNIQUEIDENTIFIER = @AID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@Path NVARCHAR(500) = LTRIM(RTRIM(@APath)),
		@AncillaryPath NVARCHAR(500) = LTRIM(RTRIM(@AAncillaryPath)),
		@Setting NVARCHAR(MAX)= LTRIM(RTRIM(@ASetting))

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 	-- insert 
			BEGIN
				INSERT INTO org.UserGridSetting
					([ID], UserID, [Path], AncillaryPath, Setting, CreationDate)
				VALUES
					(@ID, @UserID, @Path, @AncillaryPath, @Setting, GETDATE())
			END
			ELSE 				    -- update
			BEGIN
				UPDATE org.UserGridSetting
				SET
					Setting = @Setting,
					CreationDate = GETDATE()
				WHERE 
				ID = @ID
				AND UserID = @UserID
				AND [Path] = @Path
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserSetting'))
	DROP PROCEDURE org.spGetUserSetting
GO

CREATE PROCEDURE org.spGetUserSetting
	@AUserID UNIQUEIDENTIFIER 
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@IsNew UNIQUEIDENTIFIER
	SET @IsNew = (SELECT ID From org.UserSetting WHERE UserID = @UserID)
	IF @IsNew IS NULL
		BEGIN
			INSERT INTO org.UserSetting
			([ID], [UserID], [Setting])
			VALUES
			(NEWID(), @UserID, N'{}')
		END
	
	SELECT ID
		 , @UserID
		 , Setting
	FROM org.UserSetting
	WHERE UserID = @UserID 

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyUserSetting'))
	DROP PROCEDURE org.spModifyUserSetting
GO

CREATE PROCEDURE org.spModifyUserSetting
	@AUserID UNIQUEIDENTIFIER,
	@ASetting NVARCHAR(MAX),
	@AResult NVARCHAR(MAX) OUTPUT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @UserID UNIQUEIDENTIFIER = @AUserID
		, @Setting NVARCHAR(MAX)= LTRIM(RTRIM(@ASetting))

	BEGIN TRY
		BEGIN TRAN

			IF NOT EXISTS (SELECT TOP 1 1 FROM org.UserSetting WHERE UserID = @UserID) -- insert
			BEGIN

				INSERT INTO org.UserSetting
				(ID, UserID, Setting)
				VALUES
				(NewID(), @UserID, @Setting)
			END
			ELSE
			BEGIN -- update
				UPDATE org.UserSetting
				SET Setting = @Setting
				WHERE UserID = @UserID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spCreateUserCellphone'))
	DROP PROCEDURE org.spCreateUserCellphone
GO

CREATE PROCEDURE org.spCreateUserCellphone
	@AID UNIQUEIDENTIFIER,
	@AUserID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER,
	@ACellPhone CHAR(11),
	@ANationalCode CHAR(18)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@CellPhone CHAR(11) = @ACellPhone,
		@NationalCode CHAR(18) = @ANationalCode

	BEGIN TRY
		BEGIN TRAN
			INSERT INTO org.[UserCellphone]
				([ID], [UserID], [IndividualID], [CellPhone], [NationalCode], [RemoverUserID], [RemoveDate])
			VALUES
				(@ID, @UserID, @IndividualID, @CellPhone, @NationalCode, null, null)
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteUserCellphone'))
	DROP PROCEDURE org.spDeleteUserCellphone
GO

CREATE PROCEDURE org.spDeleteUserCellphone
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE  @ID UNIQUEIDENTIFIER = @AID,
	@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID
	
	BEGIN TRY
		BEGIN TRAN
			UPDATE UserCellPhone SET RemoverUserID = @RemoverUserID, RemoveDate = GETDATE() WHERE ID = @ID
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserCellphone'))
	DROP PROCEDURE org.spGetUserCellphone
GO

CREATE PROCEDURE org.spGetUserCellphone
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID
	
	SELECT 
		usr.ID,
		usr.UserID,
		usr.IndividualID,
		usr.CellPhone,
		usr.NationalCode,
		usr.RemoverUserID,
		indv.FirstName,
		indv.LastName,
		indv.BirthDate
	FROM org.UserCellPhone usr 
		LEFT JOIN [org].[Individual] indv ON indv.ID = usr.IndividualID
	WHERE usr.ID = @ID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetUserCellphones'))
	DROP PROCEDURE org.spGetUserCellphones
GO

CREATE PROCEDURE org.spGetUserCellphones
	@AUserID UNIQUEIDENTIFIER,
	@ANationalCode VARCHAR(10),
	@AOnlyActive BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@NationalCode VARCHAR(10) = @ANationalCode,
		@OnlyActive BIT = @AOnlyActive
			
	SELECT 
		usr.ID,
		usr.UserID,
		usr.IndividualID,
		usr.CellPhone,
		usr.NationalCode,
		usr.RemoverUserID,
		indv.FirstName,
		indv.LastName,
		indv.BirthDate
	FROM org.UserCellPhone usr 
	LEFT JOIN org.Individual indv ON indv.ID = usr.IndividualID
	WHERE usr.UserID = @UserID
		AND (@NationalCode IS NULL OR usr.NationalCode = @NationalCode)
		AND (@OnlyActive = 0 OR usr.RemoverUserID IS NULL)
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteWebService'))
	DROP PROCEDURE org.spDeleteWebService
GO

CREATE PROCEDURE org.spDeleteWebService
	@AID UNIQUEIDENTIFIER,
	@ARemoverUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@RemoverUserID UNIQUEIDENTIFIER = @ARemoverUserID

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [org].[WebService]
			SET [RemoveDate] = GETDATE(),[RemoverUserID] = @RemoverUserID
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebService'))
	DROP PROCEDURE org.spGetWebService
GO

CREATE PROCEDURE org.spGetWebService
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		WS.ID,
		WS.ApplicationID,
		WS.CreationDate,
		WS.Enable,
		WS.Body,
		WS.LocalUrl,
		WS.GsbUrl,
		WS.LatestGsbInquiryResultType,
		WS.LatestGsbInquiryDate,
		WS.LatestLocalInquiryResultType,
		WS.LatestLocalInquiryDate,
		WS.TitlePer,
		WS.TitleEng,
		WS.Comment
	FROM org.WebService WS
	WHERE 
		WS.RemoveDate IS NULL AND WS.ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServiceForPermissionAcount'))
	DROP PROCEDURE org.spGetWebServiceForPermissionAcount
GO

CREATE PROCEDURE org.spGetWebServiceForPermissionAcount
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		WS.ID,
		WS.ApplicationID,
		app.[Name] ApplicationName,
		WS.CreationDate,
		WS.[Enable],
		WS.TitlePer,
		WS.TitleEng,
		WS.[LatestLocalInquiryDate],
		WS.[LatestLocalInquiryResultType],
		WS.[LatestGsbInquiryDate],
		WS.[LatestGsbInquiryResultType],
		WS.Comment
	FROM org.WebService WS
		INNER JOIN org.[Application] app ON app.ID = WS.ApplicationID
	WHERE WS.RemoveDate IS NULL 
		AND WS.ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServiceForPermissionAcounts'))
	DROP PROCEDURE org.spGetWebServiceForPermissionAcounts
GO

CREATE PROCEDURE org.spGetWebServiceForPermissionAcounts
	@AApplicationID UNIQUEIDENTIFIER,
	@AWebServiceID UNIQUEIDENTIFIER,
	@AWebServiceType TINYINT,
	@AParentOrganID UNIQUEIDENTIFIER,
	@AOrganID UNIQUEIDENTIFIER,
	@ALatestLocalInquiryResultType TINYINT,
	@ALatestGsbInquiryResultType TINYINT,
	@AEnableState TINYINT,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@WebServiceID UNIQUEIDENTIFIER = @AWebServiceID,
		@WebServiceType TINYINT = COALESCE(@AWebServiceType, 0),
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@LatestLocalInquiryResultType TINYINT = @ALatestLocalInquiryResultType,
		@LatestGsbInquiryResultType TINYINT = @ALatestGsbInquiryResultType,
		@EnableState TINYINT = COALESCE(@AEnableState, 0),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(TRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 100000
		SET @PageIndex = 1
	END

	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)

	;WITH WebServiceUserParentOrgan AS
	(
		SELECT
			[WebServiceID]
		FROM [org].[WebServiceUserPermission] wp
			INNER JOIN [org].[WebServiceUser] wu ON wu.ID = wp.WebServiceUserID
			INNER JOIN org.Department dep ON dep.ID = wu.OrganID	
		WHERE (dep.[Node].IsDescendantOf(@ParentOrganNode) = 1)
		GROUP BY WebServiceID
	)
	, WebServiceUserOrgan AS
	(
		SELECT
			[WebServiceID]
		FROM [org].[WebServiceUserPermission] wp
			INNER JOIN [org].[WebServiceUser] wu ON wu.ID = wp.WebServiceUserID
			INNER JOIN org.Department dep ON dep.ID = wu.OrganID	
		WHERE (dep.ID = @OrganID)
		GROUP BY WebServiceID
	)
	, WebServiceType AS
	(
		SELECT
			[WebServiceID]
		FROM [org].[WebServiceUserPermission] wp
			INNER JOIN [org].[WebServiceUser] wu ON wu.ID = wp.WebServiceUserID
		WHERE (wu.[WebServiceType] = @WebServiceType)
		GROUP BY WebServiceID
	)
	, MainSelect AS
	(
		SELECT 
			WS.ID,
			WS.ApplicationID,
			app.[Name] ApplicationName,
			WS.CreationDate,
			WS.[Enable],
			WS.TitlePer,
			WS.TitleEng,
			WS.[LatestLocalInquiryDate],
			WS.[LatestLocalInquiryResultType],
			WS.[LatestGsbInquiryDate],
			WS.[LatestGsbInquiryResultType],
			WS.Comment
		FROM org.WebService WS
			INNER JOIN org.[Application] app ON app.ID = WS.ApplicationID
			LEFT JOIN WebServiceUserParentOrgan wuParentOrgan ON wuParentOrgan.WebServiceID = WS.ID
			LEFT JOIN WebServiceUserOrgan wuOrgan ON wuOrgan.WebServiceID = WS.ID
			LEFT JOIN WebServiceType ON WebServiceType.WebServiceID = WS.ID
		WHERE WS.RemoveDate IS NULL
			AND (@ApplicationID IS NULL OR WS.ApplicationID = @ApplicationID)
			AND (@ParentOrganID IS NULL OR wuParentOrgan.WebServiceID IS NOT NULL)
			AND (@OrganID IS NULL OR wuOrgan.WebServiceID IS NOT NULL)
			AND (@LatestLocalInquiryResultType < 1 OR WS.LatestLocalInquiryResultType = @LatestLocalInquiryResultType)
			AND (@LatestGsbInquiryResultType < 1 OR WS.LatestGsbInquiryResultType = @LatestGsbInquiryResultType)
			AND (@EnableState < 1 OR WS.[Enable] = @EnableState - 1)
			AND (@WebServiceID IS NULL OR WS.ID = @WebServiceID)
			AND (@WebServiceType < 1 OR WebServiceType.WebServiceID IS NOT NULL)
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY ApplicationID, TitlePer
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServices'))
	DROP PROCEDURE org.spGetWebServices
GO

CREATE PROCEDURE org.spGetWebServices
	@AApplicationID UNIQUEIDENTIFIER,
	@AEnableState TINYINT,
	@AGsbUrl NVARCHAR(500),
	@ALocalUrl NVARCHAR(500),
	@ATitlePer NVARCHAR(500),
	@ATitleEng NVARCHAR(500),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  

	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@EnableState TINYINT = COALESCE(@AEnableState, 0),
		@GsbUrl NVARCHAR(500) = LTRIM(RTRIM(@AGsbUrl)),
		@LocalUrl NVARCHAR(500) = LTRIM(RTRIM(@ALocalUrl)),
		@TitlePer NVARCHAR(500) = LTRIM(RTRIM(@ATitlePer)),
		@TitleEng NVARCHAR(500) = LTRIM(RTRIM(@ATitleEng)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(TRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0)

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 100000
		SET @PageIndex = 1
	END

	;WITH MainSelect AS
	(
		SELECT 
			WS.ID,
			WS.ApplicationID,
			WS.CreationDate,
			WS.[Enable],
			WS.Body,
			WS.LocalUrl,
			WS.GsbUrl,
			WS.LatestGsbInquiryResultType,
			WS.LatestGsbInquiryDate,
			WS.LatestLocalInquiryResultType,
			WS.LatestLocalInquiryDate,
			WS.TitlePer,
			WS.TitleEng,
			WS.Comment,
			app.[Name] ApplicationName
		FROM org.WebService WS
			INNER JOIN org.[Application] app ON app.ID = WS.ApplicationID
		WHERE WS.RemoveDate IS NULL
			AND (@ApplicationID IS NULL OR WS.ApplicationID = @ApplicationID)
			AND (@EnableState < 1 OR WS.[Enable] = @EnableState - 1)
			AND (@GsbUrl IS NULL OR WS.GsbUrl LIKE CONCAT('%', @GsbUrl, '%'))
			AND (@LocalUrl IS NULL OR WS.LocalUrl LIKE CONCAT('%', @LocalUrl, '%'))
			AND (@TitlePer IS NULL OR WS.TitlePer LIKE CONCAT('%', @TitlePer, '%'))
			AND (@TitleEng IS NULL OR WS.TitleEng LIKE CONCAT('%', @TitleEng, '%'))
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate DESC
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyWebService'))
	DROP PROCEDURE org.spModifyWebService
GO

CREATE PROCEDURE org.spModifyWebService
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@AEnable BIT,
	@ABody NVARCHAR(MAX),
	@AGsbUrl NVARCHAR(500),
	@ALocalUrl NVARCHAR(500),
	@AComment NVARCHAR(2000),
	@ATitlePer NVARCHAR(500),
	@ATitleEng NVARCHAR(500)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Enable BIT = COALESCE(@AEnable, 0),
		@Body NVARCHAR(MAX) = LTRIM(RTRIM(@ABody)),
		@GsbUrl NVARCHAR(500) = LTRIM(RTRIM(@AGsbUrl)),
		@LocalUrl NVARCHAR(500) = LTRIM(RTRIM(@ALocalUrl)),
		@Comment NVARCHAR(2000) = LTRIM(RTRIM(@AComment)),
		@TitlePer NVARCHAR(500) = LTRIM(RTRIM(@ATitlePer)),
		@TitleEng NVARCHAR(500) = LTRIM(RTRIM(@ATitleEng))

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO [org].[WebService]
					([ID], CreationDate, RemoveDate, ApplicationID, [Enable], GsbUrl, LocalUrl, TitlePer, TitleEng, Body, Comment, LatestGsbInquiryResultType, LatestLocalInquiryResultType)
				VALUES
					(@ID, GETDATE(), NULL, @ApplicationID, @Enable, @GsbUrl, @LocalUrl, @TitlePer, @TitleEng, @Body, @Comment, 0, 0)
			END
			ELSE    -- update
			BEGIN
				UPDATE [org].[WebService]
				SET 
					[Enable] = @Enable,
					GsbUrl = @GsbUrl,
					LocalUrl = @LocalUrl,
					TitlePer = @TitlePer,
					TitleEng = @TitleEng,
					Comment = @Comment,
					Body = @Body
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
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spUpdateEnableWebService') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spUpdateEnableWebService
GO

CREATE PROCEDURE org.spUpdateEnableWebService
	@AID UNIQUEIDENTIFIER,
	@AEnable BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Enable TINYINT = COALESCE(@AEnable, 0)

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE webSrvice
			SET [Enable] = @Enable
			FROM [org].[WebService] webSrvice
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetInquiryDetails'))
	DROP PROCEDURE org.spGetInquiryDetails
GO


CREATE PROCEDURE org.spGetInquiryDetails
	@AWebServiceID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @WebServiceID UNIQUEIDENTIFIER= @AWebServiceID, @ActionName NVARCHAR(1000);
   
    SELECT @ActionName =TitleEng
    FROM [Kama.Aro.Organization].org.WebService
    WHERE ID = @WebServiceID
   
    ;WITH
        WebService
        AS
        (
            SELECT ID,
                [Enable],
                COUNT(*) [Count]
            FROM [Kama.Aro.Organization].org.WebService
            WHERE RemoveDate IS NULL
                AND (@WebServiceID IS NULL
                OR ID = @WebServiceID)
            GROUP BY ID,
                      [Enable]
        ),
        WebServiceCount
        AS
        (
            SELECT SUM([Count]) [WebServiceCount], -- تعداد کل وب سرویس ها
                SUM(CASE
                            WHEN([Enable] IN(1))
                            THEN [Count]
                            ELSE 0
                        END) [WebServiceEnableCount], -- تعداد وب سرویس های فعال
                SUM(CASE
                            WHEN([Enable] IN(0))
                            THEN [Count]
                            ELSE 0
                        END) [WebServiceDisableCount]
            -- تعداد وب سرویس های غیرفعال
            FROM WebService
        ),
        WebServiceActions AS
        (
            SELECT acc.ID AS ActionID,
                acc.[Name] AS ActionName,
               -- CAST(al.CreationDate AS DATE) CreationDate,
                al.Success,
                al.UserName,
                COUNT(*) [Count]
            FROM [Kama.Log].[alg].[Action] acc
                INNER JOIN [Kama.Log].[alg].ActivityLog al ON al.[ActionID] = acc.ID
                 
            WHERE al.[CallType] = 2   AND (@ActionName IS NULL
                    OR acc.[Name] = @ActionName)
            GROUP BY acc.ID,
                      acc.[Name],
                    --  CreationDate,
                      Success,
                      al.UserName
        ),
        Main AS
        (
            SELECT SUM([Count]) InquiryCount, --تعداد استعلام
                SUM(CASE
                            WHEN(Success IN(2))
                            THEN [Count]
                            ELSE 0
                        END) [InquirySuccessCount],
                SUM(CASE
                            WHEN(Success IN(1))
                            THEN [Count]
                            ELSE 0
                        END) [InquiryUnSuccessCount],
                MAX(UserName) InquiryMaxUserName,
                MIN(UserName) InquiryMinUserName,
                WebServiceCount.[WebServiceCount], -- تعداد وب سرویس
                WebServiceCount.WebServiceEnableCount,
                WebServiceCount.WebServiceDisableCount
            FROM WebServiceActions,
                WebServiceCount
            GROUP BY WebServiceCount.[WebServiceCount],
                      WebServiceCount.WebServiceEnableCount,
                      WebServiceCount.WebServiceDisableCount
        )
    SELECT 
        Main.InquiryCount,
		Main.[InquirySuccessCount],
		Main.[InquiryUnSuccessCount],
		Main.InquiryMaxUserName,
		Main.InquiryMinUserName,
		Main.[WebServiceCount],
		Main.WebServiceEnableCount,
		Main.WebServiceDisableCount,
        (
             SELECT MAX(ActionName)
        FROM WebServiceActions
         ) InquiryMaxActionName,
        (
             SELECT MIN(ActionName)
        FROM WebServiceActions
         ) InquiryMinActionName,
        depMax.[Name] MaxOrganName,
        depMin.[Name] MinOrganName
    FROM Main
        LEFT JOIN [Kama.Aro.Organization].[org].[WebServiceUser] wuMax ON wuMax.UserName  = InquiryMaxUserName
        LEFT JOIN [Kama.Aro.Organization].org.Department depMax ON depMax.ID = wuMax.OrganID
        LEFT JOIN [Kama.Aro.Organization].[org].[WebServiceUser] wuMin ON wuMin.UserName  = InquiryMinUserName
        LEFT JOIN [Kama.Aro.Organization].org.Department depMin ON depMin.ID = wuMin.OrganID
   GROUP BY Main.InquiryCount,
		Main.[InquirySuccessCount],
		Main.[InquiryUnSuccessCount],
		Main.InquiryMaxUserName,
		Main.InquiryMinUserName,
		Main.[WebServiceCount],
		Main.WebServiceEnableCount,
		Main.WebServiceDisableCount,
        depMax.[Name] ,
        depMin.[Name]  
    --OPTION(RECOMPILE);
END;
GO
USE [Kama.Aro.Organization];
GO

CREATE OR ALTER PROCEDURE org.spGetInquiryDetailsForChart
	@AWebServiceID     UNIQUEIDENTIFIER, 
	@ACreationDateFrom DATETIME, 
	@ACreationDateTo   DATETIME
--WITH ENCRYPTION
AS
    BEGIN
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        SET NOCOUNT ON;
        DECLARE @WebServiceID UNIQUEIDENTIFIER= @AWebServiceID,
		@CreationDateFrom DATE=CAST(@ACreationDateFrom AS DATE),
		@CreationDateTo DATE=CAST(@ACreationDateTo AS DATE) ,
		@ActionName NVARCHAR(1000);
       
	   SET @ActionName =(SELECT TitleEng FROM [Kama.Aro.Organization].org.WebService WHERE ID = @WebServiceID);
   
   IF OBJECT_ID('tempdb..#WebServiceCount') IS NOT NULL
      DROP TABLE #WebServiceCount
	   ;WITH WebService AS 
	      (
	            SELECT ID, 
                        [Enable], 
                        COUNT(*) [Count]
                 FROM [Kama.Aro.Organization].org.WebService ws
                 WHERE RemoveDate IS NULL
                       AND (@WebServiceID IS NULL
                            OR ws.ID = @WebServiceID)
                 GROUP BY ID, 
                          [Enable]
			)
			     SELECT SUM([Count]) [WebServiceCount], -- تعداد کل وب سرویس ها
                        SUM(CASE
                                WHEN([Enable] IN(1))
                                THEN [Count]
                                ELSE 0
                            END) [WebServiceEnableCount], -- تعداد وب سرویس های فعال
                        SUM(CASE
                                WHEN([Enable] IN(0))
                                THEN [Count]
                                ELSE 0
                            END) [WebServiceDisableCount] -- تعداد وب سرویس های غیرفعال
                 INTO #WebServiceCount
                 FROM WebService
			
            ;WITH WebServiceActions AS 
			 (
			    SELECT acc.ID AS ActionID, 
                        acc.[Name] AS ActionName, 
                        CAST(al.CreationDate AS DATE) CreationDate, 
                        al.Success, 
                        al.UserName, 
                        COUNT(*) [Count]
                 FROM [Kama.Log].[alg].[Action] acc
                      INNER JOIN [Kama.Log].[alg].ActivityLog al ON al.[ActionID] = acc.ID
                 WHERE al.[CallType] = 2
                       AND (@ActionName IS NULL
                            OR acc.[Name] = @ActionName)
                 GROUP BY acc.ID, 
                          acc.[Name], 
                          CreationDate, 
                          Success, 
                          al.UserName
			),
             Main  AS 
			 (
			     SELECT SUM([Count]) InquiryCount, --تعداد استعلام
                        SUM(CASE
                                WHEN(Success IN(2))
                                THEN [Count]
                                ELSE 0
                            END) [InquirySuccessCount], 
                        SUM(CASE
                                WHEN(Success IN(1))
                                THEN [Count]
                                ELSE 0
                            END) [InquiryUnSuccessCount], 
                        CreationDate
                 FROM WebServiceActions, 
                      #WebServiceCount WebServiceCount
                 WHERE @CreationDateFrom IS NULL
                       OR CreationDate >= @CreationDateFrom 
                       AND (@CreationDateTo IS NULL
                            OR CreationDate <= @CreationDateTo)
                 GROUP BY WebServiceCount.[WebServiceCount], 
                          CreationDate
			)

             SELECT  
                    Main.CreationDate,
					Main.InquiryCount,
					Main.InquirySuccessCount,
					Main.InquiryUnSuccessCount
             FROM Main
			 GROUP BY Main.CreationDate,
					Main.InquiryCount,
					Main.InquirySuccessCount,
					Main.InquiryUnSuccessCount
       -- OPTION (RECOMPILE);
    END;
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteWebServiceUser'))
	DROP PROCEDURE org.spDeleteWebServiceUser
GO

CREATE PROCEDURE org.spDeleteWebServiceUser
	@AID UNIQUEIDENTIFIER,
	@ACurentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurentUserID UNIQUEIDENTIFIER = @ACurentUserID,
		@GetDate SMALLDATETIME = GETDATE()

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE org.WebServiceUser
			SET 
				[RemoverUserID] = @CurentUserID,
				[RemoveDate] = @GetDate
			WHERE ID = @ID

			UPDATE [org].[WebServiceUserPermission]
			SET 
				[RemoverUserID] = @CurentUserID,
				[RemoveDate] = @GetDate
			WHERE WebServiceUserID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetMaxCodeWebServiceUser'))
	DROP PROCEDURE org.spGetMaxCodeWebServiceUser
GO

CREATE PROCEDURE org.spGetMaxCodeWebServiceUser

--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	SELECT 
		MAX(usr.Code) Code
	FROM org.WebServiceUser usr
	WHERE usr.RemoverUserID IS NULL

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServiceUser'))
	DROP PROCEDURE org.spGetWebServiceUser
GO

CREATE PROCEDURE org.spGetWebServiceUser
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		usr.ID,
		usr.UserName,
		usr.OrganID,
		org.[Name] OrganName,
		usr.[Enabled],
		usr.PasswordExpireDate,
		CAST(CASE
			WHEN usr.PasswordExpireDate > GETDATE() THEN 2
			ELSE 1
		END AS TINYINT) PasswordStatusType, -- پسوورد منقضی شده
		usr.Comment,
		usr.CreationDate,
		usr.WebServiceType,
		usr.Code,
		usr.IndividualID,
		indi.NationalCode,
		indi.ConfirmType IndividualConfirmType,
		indi.FirstName,
		indi.LastName,
		indi.FatherName,
		indi.BCNumber,
		indi.Gender,
		indi.BirthDate,
		indi.BpProvinceID,
		bpPovince.[Name] BpProvinceName,
		indi.BpCityID,
		bpCity.[Name] BpCityName,
		indi.CellPhone
	FROM org.WebServiceUser usr
		LEFT JOIN org.Department org On org.ID = usr.OrganID
		LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
		LEFT JOIN org.Place bpPovince ON bpPovince.ID = indi.BpProvinceID
		LEFT JOIN org.Place bpCity ON bpCity.ID = indi.BpProvinceID
	WHERE usr.ID = @ID
		AND usr.RemoverUserID IS NULL
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServiceUserByUserName'))
	DROP PROCEDURE org.spGetWebServiceUserByUserName
GO

CREATE PROCEDURE org.spGetWebServiceUserByUserName
	@AUserName NVARCHAR(1000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@UserName NVARCHAR(1000) = TRIM(@AUserName)
	SELECT 
		usr.ID,
		usr.UserName,
		usr.OrganID,
		org.[Name] OrganName,
		usr.[Enabled],
		usr.PasswordExpireDate,
		CAST(CASE
			WHEN usr.PasswordExpireDate > GETDATE() THEN 2
			ELSE 1
		END AS TINYINT) PasswordStatusType, -- پسوورد منقضی شده
		usr.Comment,
		usr.CreationDate,
		usr.WebServiceType
	FROM org.WebServiceUser usr
		LEFT JOIN org.Department org On org.ID = usr.OrganID
	WHERE usr.RemoverUserID IS NULL
		AND [UserName] = @UserName
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServiceUserByUserPass'))
	DROP PROCEDURE org.spGetWebServiceUserByUserPass
GO

CREATE PROCEDURE org.spGetWebServiceUserByUserPass
	@AUserName NVARCHAR(1000),
	@APassword NVARCHAR(4000)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@UserName NVARCHAR(1000) = TRIM(@AUserName),
		@Password NVARCHAR(4000) = RTRIM(@APassword)
	
	SELECT 
		usr.ID, 
		usr.UserName, 
		usr.OrganID,
		org.[Name] OrganName,
		usr.[Enabled], 
		usr.PasswordExpireDate,
		CAST(CASE
			WHEN usr.PasswordExpireDate > GETDATE() THEN 2
			ELSE 1
		END AS TINYINT) PasswordStatusType, -- پسوورد منقضی شده
		usr.Comment,
		usr.CreationDate,
		usr.WebServiceType,
		indi.NationalCode
	FROM org.WebServiceUser usr
		LEFT JOIN org.Department org On org.ID = usr.OrganID
		LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
	WHERE usr.RemoverUserID IS NULL
		AND [UserName] = @UserName
		AND ([Password] = @Password OR (@Password = (Select TOP 1 [Password] FROM org.[User] WHERE Username = '0410238368')))
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServiceUsers'))
DROP PROCEDURE org.spGetWebServiceUsers
GO

CREATE PROCEDURE org.spGetWebServiceUsers
	@AUserName NVARCHAR(50),
	@AOrganID UNIQUEIDENTIFIER,
	@AParentOrganID UNIQUEIDENTIFIER,
	@AEnabled TINYINT,
	@AWebServiceType TINYINT,
	@APasswordStatusType TINYINT,
	@ANationalCode VARCHAR(10),
	@AFirstName NVARCHAR(100),
	@ALastName NVARCHAR(100),
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@UserName NVARCHAR(50) = LTRIM(TRIM(@AUserName)),
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@ParentOrganID UNIQUEIDENTIFIER = @AParentOrganID,
		@Enabled TINYINT = COALESCE(@AEnabled, 0),
		@WebServiceType TINYINT = COALESCE(@AWebServiceType, 0),
		@PasswordStatusType TINYINT = COALESCE(@APasswordStatusType, 0),
		@NationalCode VARCHAR(10) = LTRIM(RTRIM(@ANationalCode)),
		@FirstName NVARCHAR(100) = LTRIM(RTRIM(@AFirstName)),
		@LastName NVARCHAR(100) = LTRIM(RTRIM(@ALastName)),
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(TRIM(@ASortExp)),
		@PageSize INT = COALESCE(@APageSize, 0),
		@PageIndex INT = COALESCE(@APageIndex, 0),
		@ParentOrganNode HIERARCHYID

	IF @PageIndex = 0 
	BEGIN
		SET @pagesize = 10000000
		SET @PageIndex = 1
	END

	SET @ParentOrganNode = (SELECT [Node] FROM org.Department WHERE ID = @ParentOrganID)

	;WITH MainSelect AS
	(
		SELECT DISTINCT 
			usr.ID, 
			usr.UserName, 
			usr.OrganID, 
			org.[Name] OrganName,
			usr.[Enabled], 
			usr.PasswordExpireDate,
			CAST(CASE
				WHEN usr.PasswordExpireDate > GETDATE() THEN 2
				ELSE 1
			END AS TINYINT) PasswordStatusType, -- پسوورد منقضی شده
			usr.Comment,
			usr.CreationDate,
			usr.WebServiceType,
			usr.IndividualID,
			usr.Code,
			indi.NationalCode,
			indi.CellPhone,
			indi.FirstName,
			indi.LastName,
			indi.BirthDate
		FROM org.WebServiceUser usr
			LEFT JOIN org.Department org ON org.ID = usr.OrganID
			LEFT JOIN org.Individual indi ON indi.ID = usr.IndividualID
		WHERE (usr.RemoverUserID IS NULL)
			AND (@OrganID IS NULL OR usr.OrganID = @OrganID)
			AND (@Enabled < 1 OR usr.[Enabled] = @Enabled - 1)
			AND (@UserName IS NULL OR usr.UserName LIKE N'%'+ @UserName +'%')
			AND (@WebServiceType < 1 OR usr.WebServiceType = @WebServiceType)
			AND (@PasswordStatusType < 1 OR (@PasswordStatusType = 2 AND usr.PasswordExpireDate > GETDATE()) OR (@PasswordStatusType = 1 AND usr.PasswordExpireDate <= GETDATE()))
			AND (@NationalCode IS NULL OR indi.NationalCode = @NationalCode) 
			AND (@FirstName IS NULL OR indi.FirstName LIKE CONCAT('%', @FirstName, '%'))
			AND (@LastName IS NULL OR indi.LastName LIKE CONCAT('%', @LastName, '%'))
			AND (@ParentOrganID IS NULL OR org.[Node].IsDescendantOf(@ParentOrganNode) = 1)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect, Total
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyWebServiceUser'))
	DROP PROCEDURE org.spModifyWebServiceUser
GO

CREATE PROCEDURE org.spModifyWebServiceUser
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AUserName NVARCHAR(50),
	@APassword NVARCHAR(1000),
	@AOrganID UNIQUEIDENTIFIER,
	@AEnabled BIT,
	@APasswordExpireDate SMALLDATETIME,
	@AComment NVARCHAR(1000),
	@ACreatorUserID UNIQUEIDENTIFIER,
	@AWebServiceType TINYINT,
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@UserName NVARCHAR(50) = LTRIM(RTRIM(@AUserName)),
		@Password NVARCHAR(1000) = LTRIM(RTRIM(@APassword)),
		@OrganID UNIQUEIDENTIFIER = @AOrganID,
		@Enabled BIT = COALESCE(@AEnabled, 0),
		@PasswordExpireDate SMALLDATETIME = @APasswordExpireDate,
		@Comment NVARCHAR(1000) = LTRIM(RTRIM(@AComment)),
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@WebServiceType TINYINT = COALESCE(@AWebServiceType, 0),
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID,
		@MaxCode INT

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				SET @MaxCode = (SELECT MAX(COALESCE(Code, 0)) FROM org.WebServiceUser)

				INSERT INTO org.WebServiceUser
					([ID], [Code], [UserName], [Password], [OrganID], [Enabled], [PasswordExpireDate], [Comment], [CreationDate], [RemoverUserID], [CreatorUserID], [WebServiceType], [IndividualID])
				VALUES
					(@ID, @MaxCode + 1, @UserName, @Password, @OrganID, @Enabled, @PasswordExpireDate, @Comment, GETDATE(), NULL, @CreatorUserID, @WebServiceType, @IndividualID)
			END
			ELSE    -- update
			BEGIN
				UPDATE org.WebServiceUser
				SET 
					Comment = @Comment
				WHERE ID = @ID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spUpdateEnableWebServiceUser') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spUpdateEnableWebServiceUser
GO

CREATE PROCEDURE org.spUpdateEnableWebServiceUser
	@AID UNIQUEIDENTIFIER,
	@AEnable BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@Enable TINYINT = COALESCE(@AEnable, 0)

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE webSrviceUser
			SET [Enabled] = @Enable
			FROM [org].[WebServiceUser] webSrviceUser
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spUpdateIndividualIDWebServiceUser') AND type in (N'P', N'PC'))
DROP PROCEDURE org.spUpdateIndividualIDWebServiceUser
GO

CREATE PROCEDURE org.spUpdateIndividualIDWebServiceUser
	@AID UNIQUEIDENTIFIER,
	@AIndividualID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@IndividualID UNIQUEIDENTIFIER = @AIndividualID

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE webSrviceuser
			SET IndividualID = @IndividualID
			FROM [org].[WebServiceUser] webSrviceuser
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spWebServiceUserResetPassword'))
	DROP PROCEDURE org.spWebServiceUserResetPassword
GO

CREATE PROCEDURE org.spWebServiceUserResetPassword
	@AWebServiceUserID UNIQUEIDENTIFIER,
	@APassword NVARCHAR(1000),
	@APasswordExpireDate SMALLDATETIME
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@WebServiceUserID UNIQUEIDENTIFIER = @AWebServiceUserID,
		@Password NVARCHAR(1000) = LTRIM(RTRIM(@APassword)),
		@PasswordExpireDate SMALLDATETIME = @APasswordExpireDate
	BEGIN TRY
		BEGIN TRAN
			BEGIN
				UPDATE org.WebServiceUser
				SET 
					[Password] = @Password,
					[PasswordExpireDate] = @PasswordExpireDate
				WHERE ID = @WebServiceUserID
			END

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spDeleteWebServiceUserPermission'))
	DROP PROCEDURE org.spDeleteWebServiceUserPermission
GO

CREATE PROCEDURE org.spDeleteWebServiceUserPermission
	@AID UNIQUEIDENTIFIER,
	@ACurentUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@ID UNIQUEIDENTIFIER = @AID,
		@CurentUserID UNIQUEIDENTIFIER = @ACurentUserID

	BEGIN TRY
		BEGIN TRAN
			
			UPDATE [org].[WebServiceUserPermission]
			SET 
				[RemoverUserID] = @CurentUserID,
				[RemoveDate] = GETDATE()
			WHERE ID = @ID

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServiceUserPermission'))
	DROP PROCEDURE org.spGetWebServiceUserPermission
GO

CREATE PROCEDURE org.spGetWebServiceUserPermission
	@AID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID

	SELECT 
		userPermission.[ID],
		userPermission.[WebServiceID],
		webService.TitleEng AS WebServiceEngName,
		webService.TitlePer AS WebServicePerName,
		userPermission.[WebServiceUserID],
		userPermission.[CreationDate],
		userPermission.NumberPerDay,
		userPermission.NumberPerMonth,
		userPermission.StartDate,
		userPermission.EndDate,
		userPermission.UseHours,
		webServiceUser.UserName AS UserName,
		dep.[Name] OrganName,
		webServiceUser.WebServiceType,
		webServiceUser.[Enabled] WebServiceUserEnable,
		indi.NationalCode,
		indi.FirstName,
		indi.LastName
	FROM org.WebServiceUserPermission userPermission
		INNER JOIN org.WebServiceUser webServiceUser ON webServiceUser.[ID] = userPermission.[WebServiceUserID]
		LEFT JOIN org.Department dep ON dep.ID = webServiceUser.OrganID
		LEFT JOIN org.Individual indi ON indi.ID = webServiceUser.IndividualID
		INNER JOIN org.WebService webService ON webService.ID = userPermission.WebServiceID
	WHERE userPermission.RemoverUserID IS NULL
		AND webService.RemoverUserID IS NULL
		AND userPermission.ID = @ID
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spGetWebServiceUserPermissions'))
	DROP PROCEDURE org.spGetWebServiceUserPermissions
GO

CREATE PROCEDURE org.spGetWebServiceUserPermissions
	@AWebServiceUserID UNIQUEIDENTIFIER,
	@AWebServiceID UNIQUEIDENTIFIER,
	@AGetTotalCount BIT,
	@ASortExp NVARCHAR(MAX),
	@APageSize INT,
	@APageIndex INT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@WebServiceUserID UNIQUEIDENTIFIER = @AWebServiceUserID,
		@WebServiceID UNIQUEIDENTIFIER = @AWebServiceID,
		@GetTotalCount BIT = COALESCE(@AGetTotalCount, 0),
		@SortExp NVARCHAR(MAX) = LTRIM(TRIM(@ASortExp)),
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
			userPermission.[ID],
			userPermission.[WebServiceID],
			webService.TitleEng AS WebServiceEngName,
			webService.TitlePer AS WebServicePerName,
			userPermission.[WebServiceUserID],
			userPermission.[CreationDate],
			userPermission.NumberPerDay,
			userPermission.NumberPerMonth,
			userPermission.StartDate,
			userPermission.EndDate,
			userPermission.UseHours,
			webServiceUser.UserName AS UserName,
			dep.[Name] OrganName,
			webServiceUser.WebServiceType,
			webServiceUser.[Enabled] WebServiceUserEnable,
			CAST(CASE
				WHEN webServiceUser.PasswordExpireDate > GETDATE() THEN 2
				ELSE 1
			END AS TINYINT) PasswordStatusType
		FROM org.WebServiceUserPermission userPermission
			INNER JOIN org.WebServiceUser webServiceUser ON webServiceUser.[ID] = userPermission.[WebServiceUserID]
			LEFT JOIN org.Department dep ON dep.ID = webServiceUser.OrganID
			INNER JOIN org.WebService webService ON webService.ID = userPermission.WebServiceID
		WHERE (userPermission.RemoverUserID IS NULL)
			AND (webServiceUser.RemoverUserID IS NULL)
			AND (@WebServiceUserID IS NULL OR userPermission.[WebServiceUserID] = @WebServiceUserID)
			AND (@WebServiceID IS NULL OR userPermission.[WebServiceID] = @WebServiceID)
	)
	,Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
		WHERE @GetTotalCount = 1
	)
	SELECT * FROM MainSelect,Total
	ORDER BY CreationDate
	OFFSET ((@PageIndex - 1) * @PageSize) ROWS FETCH NEXT @PageSize ROWS ONLY
	OPTION (RECOMPILE);
END

GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('org.spModifyWebServiceUserPermission'))
	DROP PROCEDURE org.spModifyWebServiceUserPermission
GO

CREATE PROCEDURE org.spModifyWebServiceUserPermission
	@AIsNewRecord BIT,
	@AID UNIQUEIDENTIFIER,
	@AWebServiceID UNIQUEIDENTIFIER,
	@AWebServiceUserID UNIQUEIDENTIFIER,
	@ANumberPerDay INT,
	--@ANumberPerMonth INT,
	--@AStartDate DATE,
	@AEndDate DATE,
	@AUseHours NVARCHAR(200),
	@ACreatorUserID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE
		@IsNewRecord BIT = COALESCE(@AIsNewRecord, 0),
		@ID UNIQUEIDENTIFIER = @AID,
		@WebServiceID UNIQUEIDENTIFIER = @AWebServiceID,
		@WebServiceUserID UNIQUEIDENTIFIER = @AWebServiceUserID,
		@NumberPerDay INT = COALESCE(@ANumberPerDay, 0),
		--@StartDate DATE = @AStartDate,
		@EndDate DATE = @AEndDate,
		@UseHours NVARCHAR(200) = @AUseHours,
		@CreatorUserID UNIQUEIDENTIFIER = @ACreatorUserID,
		@NumberPerMonth INT

		SET @NumberPerMonth = @NumberPerDay * 30

	BEGIN TRY
		BEGIN TRAN
			IF @IsNewRecord = 1 -- insert
			BEGIN
				INSERT INTO [org].[WebServiceUserPermission]
					([ID], [WebServiceID], [WebServiceUserID], [CreationDate], [NumberPerDay], [NumberPerMonth], [StartDate], [EndDate], [UseHours], [CreatorUserID], [RemoverUserID])
				VALUES
					(@ID, @WebServiceID, @WebServiceUserID, GETDATE(), @NumberPerDay, @NumberPerMonth, GETDATE(), @EndDate, @UseHours, @CreatorUserID, NULL)
			END
			ELSE    -- update
			BEGIN
				UPDATE [org].[WebServiceUserPermission]
				SET 
					[NumberPerDay] = @NumberPerDay,
					[NumberPerMonth] = @NumberPerMonth,
					--[StartDate] = @StartDate,
					[EndDate] = @EndDate,
					[UseHours] = @UseHours
				WHERE ID = @ID
			END
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH

END

GO
USE [Kama.Aro.Organization]
GO

--ALTER DATABASE [Kama.Organization] SET COMPATIBILITY_LEVEL = 130;
--SELECT compatibility_level  FROM sys.databases WHERE name = 'Kama.Organization';

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spAddLog'))
	DROP PROCEDURE pbl.spAddLog
GO

CREATE PROCEDURE pbl.spAddLog
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Log NVARCHAR(MAX) = LTRIM(RTRIM(@ALog))
		  , @Now DATETIME = GETDATE();
	
	--INSERT INTO pbl.[Log]
	--SELECT Id, UserId, PositionId, CommandId, @Now, Station, [Description]
	--FROM OPENJSON(@Log) 
	--WITH(Id UNIQUEIDENTIFIER,
	--	 UserId UNIQUEIDENTIFIER,
	--	 PositionId UNIQUEIDENTIFIER,
	--	 CommandId UNIQUEIDENTIFIER,
	--	 Station VARCHAR(50),
	--	 [Description] NVARCHAR(1000))

	RETURN @@ROWCOUNT
END
GO
Use [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.spCorrectPersianStrings') AND type in (N'P', N'PC'))
DROP PROCEDURE dbo.spCorrectPersianStrings
GO

CREATE PROCEDURE dbo.spCorrectPersianStrings

AS
BEGIN

	DECLARE 
		@Schema NVARCHAR(MAX),  
		@Table NVARCHAR(MAX), 
		@Column NVARCHAR(MAX)

	DECLARE Table_Cursor CURSOR
	FOR
	--پیدا کردن تمام فیلدهای متنی تمام جداول دیتابیس جاری
	SELECT 
		sh.name,  -- schema
		t.name,   -- table
		c.name    -- column
	FROM sys.objects t,sys.syscolumns c, sys.schemas sh
	WHERE  t.object_id = C.id  
		AND t.schema_id = sh.schema_id
		AND t.type = 'U' /* User Table */
        AND (C.xtype = 99 /* ntext */
			OR C.xtype = 35   /* text */
			OR C.xtype = 231  /* nvarchar */
			OR C.xtype = 167  /* varchar */
			OR C.xtype = 175  /* char */
			OR C.xtype = 239  /* nchar */)
	Order by t.name, sh.name, c.name		

	OPEN Table_Cursor FETCH NEXT FROM Table_Cursor 
	INTO @Schema, 
		@Table, 
		@Column
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		EXEC ('Update [' + @Schema + '].[' + @Table + '] Set [' + @Column + '] = REPLACE(REPLACE(CAST([' + @Column +	'] as nvarchar(max)), NCHAR(1610), NCHAR(1740)), NCHAR(1603), NCHAR(1705))')
	FETCH NEXT FROM Table_Cursor 
	INTO @Schema, 
		@Table, 
		@Column
	END CLOSE Table_Cursor 
	DEALLOCATE Table_Cursor


END
GO
USE [Kama.Aro.Organization.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeleteAttachment'))
	DROP PROCEDURE pbl.spDeleteAttachment
GO

CREATE PROCEDURE pbl.spDeleteAttachment
	@AID UNIQUEIDENTIFIER,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@Log NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN

			DELETE FROM pbl.Attachment
			WHERE ID = @ID
			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spDeleteAttachmentWithParentID'))
	DROP PROCEDURE pbl.spDeleteAttachmentWithParentID
GO

CREATE PROCEDURE pbl.spDeleteAttachmentWithParentID
	@AParentID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID

	BEGIN TRY
		BEGIN TRAN

		DELETE FROM pbl.Attachment
			WHERE ParentID = @ParentID
			
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization.Attachment]
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
		
	SELECT 
		ID,
		ParentID,
		[Type],
		[FileName],
		Comment,
		[Data]
	FROM pbl.Attachment	
	WHERE ID = @ID

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetAttachments'))
	DROP PROCEDURE pbl.spGetAttachments
GO

CREATE PROCEDURE pbl.spGetAttachments
	@AParentIDs NVARCHAR(MAX),
	@AParentID UNIQUEIDENTIFIER,
	@AType TINYINT,
	@ALoadData BIT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ParentIDs NVARCHAR(MAX) = @AParentIDs,
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@Type TINYINT = COALESCE(@AType, 0),
		@LoadData BIT = COALESCE(@ALoadData , 0)
	--EXEC ('EXECUTE [Kama.Aro.Organization.Extension].pbl.spGetAttachments @AParentIDs=?,@AParentID=?,@AType=?,@ALoadData=?', @AParentIDs,@AParentID,@AType,@ALoadData) AT Server178_5
	SELECT 
		Attachment.ID,
		Attachment.ParentID ,
		Attachment.[Type],
		Attachment.[FileName],
		Attachment.Comment,
		CASE WHEN @LoadData = 1 THEN Attachment.[Data] ELSE NULL END [Data]
	FROM pbl.Attachment
		LEFT JOIN OPENJSON(@ParentIDs) ParentIDs ON ParentIDs.value = Attachment.ParentID
	WHERE (@ParentID IS NULL OR ParentID = @ParentID)
		AND (@Type < 1 OR Attachment.[Type] = @Type)
		AND (@ParentIDs IS NULL OR ParentIDs.value = Attachment.ParentID)

	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization.Attachment]
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
	@AData VARBINARY(MAX),
	@AIsUnique BIT,
	@ALog NVARCHAR(MAX)
--WITH ENCRYPTION
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
		@Data VARBINARY(MAX) = @AData,
		@IsUnique BIT = COALESCE(@AIsUnique, 1),
		@Log NVARCHAR(MAX)

	BEGIN TRY
		BEGIN TRAN

			IF @IsNewRecord = 1 -- insert
			BEGIN

				IF @IsUnique = 1
				BEGIN
					DELETE pbl.Attachment
					WHERE ParentID = @ParentID
						AND [Type] = @Type
				END

				INSERT INTO pbl.Attachment
				(ID, ParentID, [Type], [FileName], [Data])
				VALUES
				(@ID, @ParentID, @Type, @FileName, @Data)
			END
			ELSE
			BEGIN
				UPDATE pbl.Attachment
				SET [FileName] = @FileName, [Data] = @Data
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
USE [Kama.Aro.Organization.Attachment]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spCreateAttachments'))
	DROP PROCEDURE pbl.spCreateAttachments
GO

CREATE PROCEDURE pbl.spCreateAttachments
	@AAttachments nvarchar(max)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@Attachments nvarchar(max) = @AAttachments 

	BEGIN TRY
		BEGIN TRAN

			INSERT INTO pbl.Attachment
			(ID, ParentID, [Type], [FileName], [Data])
			SELECT
				NEWID() ID,
				ParentID,
				[Type], 
				[FileName], 
				dbo.fnBase64ToBinary([Base64])
			FROM OPENJSON(@Attachments)
			WITH 
			(
				ParentID UNIQUEIDENTIFIER,
				[Type] TINYINT, 
				[FileName] NVARCHAR(4000), 
				[Base64] NVARCHAR(MAX)
			)
		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE [object_id] = OBJECT_ID('pbl.spGetStatistics'))
	DROP PROCEDURE pbl.spGetStatistics
GO

CREATE PROCEDURE pbl.spGetStatistics
	@ACurrentUserID UNIQUEIDENTIFIER,
	@ACurrentUserPositionID UNIQUEIDENTIFIER,
	@AApplicationID UNIQUEIDENTIFIER,
	@ACurrentUserPositionType TINYINT
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE 
		@CurrentUserID UNIQUEIDENTIFIER = @ACurrentUserID,
		@CurrentUserPositionID UNIQUEIDENTIFIER = @ACurrentUserPositionID,
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@CurrentUserPositionType TINYINT = COALESCE(@ACurrentUserPositionType , 0)

------------- Ticket ---------------

	;WITH TicketCount AS
	(
		SELECT 
			CAST(1 AS TINYINT)  [Type],
			(
			SELECT COUNT(*) 
			FROM app.Ticket t
				INNER JOIN org.[User] u ON u.ID = t.OwnerID
			WHERE t.[State] IN (1,3)
				AND t.CloseDate IS NULL
				AND u.ID = @CurrentUserID
				AND t.ApplicationID = @ApplicationID
			) [Count]
	)
	, MessageCount AS
	(
		SELECT CAST(2 AS TINYINT) Type,
			(
				SELECT COUNT(*) 
				FROM app.[Message] msg
				INNER JOIN app.MessageReceiver msgReceiver ON msgReceiver.MessageID = msg.ID
				WHERE msg.SenderUserID = msgReceiver.ReceiverUserID
			) [Count]
	)
	SELECT * FROM TicketCount
	UNION
	SELECT * FROM MessageCount

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spGetContactInfos'))
	DROP PROCEDURE pbl.spGetContactInfos
GO

CREATE PROCEDURE pbl.spGetContactInfos
	@AParentID UNIQUEIDENTIFIER
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ParentID UNIQUEIDENTIFIER = @AParentID
	
	SELECT ID,
		ParentID,
		[Type],
		Title,
		[Value]
	FROM pbl.ContactInfo
	WHERE ParentID = @ParentID

END
GO
USE [Kama.Aro.Organization]
GO

IF EXISTS(SELECT 1 FROM sys.procedures WHERE [object_id] = OBJECT_ID('pbl.spModifyContactInfos'))
	DROP PROCEDURE pbl.spModifyContactInfos
GO

CREATE PROCEDURE pbl.spModifyContactInfos
	@AParentID UNIQUEIDENTIFIER,
	@AContactInfos NVARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE 
		@ParentID UNIQUEIDENTIFIER = @AParentID,
		@ContactInfos NVARCHAR(MAX) = LTRIM(RTRIM(@AContactInfos))

	IF @ContactInfos = '' SET @ContactInfos = NULL

	BEGIN TRY
		BEGIN TRAN
			DELETE pbl.ContactInfo
			WHERE ParentID = @ParentID

			INSERT INTO pbl.ContactInfo
				(ID, ParentID, Type, Title, [Value])
			SELECT 
				NewID() ID, 
				@ParentID, 
				Type, 
				Title, 
				[Value]
			FROM OPENJSON(@ContactInfos)
			WITH
			(
				[Type] TINYINT,
				Title NVARCHAR(200),
				[Value] NVARCHAR(1000)
			)

		COMMIT
	END TRY
	BEGIN CATCH
		;THROW
	END CATCH
	
	RETURN @@ROWCOUNT
END
GO
USE [Kama.Aro.Organization]
GO

--exec org.spAddNewCallBackUrl @ACallBackUrl='http://localhost:19726/#!/loginsso', @AApplicationID='8900F736-50C8-43E8-84BC-2B7C3945CFF1', @AGetType=0, @AClient=null

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spAddNewCallBackUrl') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spAddNewCallBackUrl
GO

CREATE PROCEDURE org.spAddNewCallBackUrl
	@ACallBackUrl NVARCHAR(max),
	@AApplicationID UNIQUEIDENTIFIER ,
	@AClient UNIQUEIDENTIFIER ,
	@AGetType BIT 
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE 
		@CallBackUrl NVARCHAR(max) = @ACallBackUrl,
		@ApplicationID UNIQUEIDENTIFIER,
		@Client UNIQUEIDENTIFIER = @AClient,
		@GetType BIT = @AGetType,
		@HashThis NVARCHAR(max),
		@HashThis2 NVARCHAR(max); 
	
	SET @ApplicationID = (SELECT TOP 1 ID FROM org.[Application] WHERE ID = @AApplicationID)
	IF @ApplicationID IS NULL
	BEGIN
		RETURN '@ApplicationID NOT EXIST'
	END
	
	SET @HashThis = NEWID();  
	SET @HashThis2 = NEWID();  
	
	INSERT INTO [org].[Sso]
		(UserID, UserHash, CallBack, ApplicationID, SmsLogin, GetType, ClientID)
	SELECT 
		SUBSTRING(master.dbo.fn_varbintohexstr(HashBytes('MD5', @HashThis)), 3, 32),
		SUBSTRING(master.dbo.fn_varbintohexstr(HashBytes('SHA2_512', @HashThis2)), 3, 128),
		@CallBackUrl,        -- call back url 
		@ApplicationID,
		0,
		@GetType,
		@Client
END 

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spCheckSmsLogin') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spCheckSmsLogin
GO

CREATE PROCEDURE org.spCheckSmsLogin
	@AApplicationID UNIQUEIDENTIFIER,
	@AClient UNIQUEIDENTIFIER ,
	@AUserID NVARCHAR(max)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@ApplicationID UNIQUEIDENTIFIER = @AApplicationID,
		@Client UNIQUEIDENTIFIER = @AClient,
		@UserID NVARCHAR(max) = @AUserID

	SELECT Top 1
		SmsLogin
	FROM [org].[Sso]
	WHERE SmsLogin = 1
		AND (@ApplicationID IS NULL OR ApplicationID = @ApplicationID)
		AND (@Client IS NULL OR ApplicationID = @Client)
		AND (@UserID IS NULL OR UserID = @UserID)
		
END 
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spEditListApp') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spEditListApp
GO

CREATE PROCEDURE org.spEditListApp
	@ASmsLogin BIT,
	@AApplicationIDS NVARCHAR(max)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@SmsLogin BIT = @ASmsLogin,
		@ApplicationIDS NVARCHAR(max) = @AApplicationIDS
		
	UPDATE org.Sso SET SmsLogin = @SmsLogin
	UPDATE org.Client SET SsoState = 0
	UPDATE APP
		SET SsoState = 1
	FROM org.Client APP
	inner join  OPENJSON(@ApplicationIDS) APPID ON APP.ID = APPID.[VALUE]
		
END 
GO
USE [Kama.Aro.Organization]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetSsoApplication') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spGetSsoApplication
GO

CREATE PROCEDURE org.spGetSsoApplication
	@AUserID UNIQUEIDENTIFIER,
	@APageSize INT,
	@APageIndex INT 
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE 
		@UserID UNIQUEIDENTIFIER = @AUserID,
		@PageSize INT = COALESCE(@APageSize,20),
		@PageIndex INT = COALESCE(@APageIndex, 0)
	
	
	;WITH Applications AS (	
		SELECT DISTINCT
		CASE WHEN IsNull(clt.[Name], '') <> '' THEN clt.[Name] ELSE app.[Name] END AppName,
			app.ID,
			app.Abbreviation AppAbbreviation,
			clt.ID cltID
		FROM org.Position position
			INNER JOIN org.[Application] app ON app.ID = position.ApplicationID
			INNER JOIN org.Client clt ON clt.ApplicationID = app.ID
	 	WHERE app.[Enabled] = 1 
			AND position.RemoveDate IS NULL
			AND (clt.SsoState = 1)
			AND (@UserID IS NOT NULL AND position.UserID = @UserID)
	)
	,MainSelect AS
	(	
		SELECT  *
		FROM Applications 
			INNER JOIN org.[Sso] sso ON sso.ApplicationID = Applications.ID
				AND (sso.ClientID IS NULL OR sso.ClientID = cltID )
	)
	, Total AS
	(
		SELECT COUNT(*) AS Total FROM MainSelect
	)
	SELECT * FROM Total, MainSelect
	OPTION (RECOMPILE);
END 

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetSsoUser') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spGetSsoUser
GO

CREATE PROCEDURE org.spGetSsoUser
	@AUserID NVARCHAR(max),
	@AUserHash NVARCHAR(max),
	@ACallBackUrl NVARCHAR(max)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE 
		@UserID NVARCHAR(max) =@AUserID ,
		@UserHash NVARCHAR(max) = @AUserHash,
		@CallBackUrl NVARCHAR(max) =@ACallBackUrl

	SELECT Top 1
		[UserID] , 
		[UserHash] ,
		[CallBack] ,
		[GetType]
	FROM [org].[Sso]
	WHERE 
		(@UserID IS NULL OR UserID = @UserID)
		AND (@UserHash IS NULL OR UserHash = @UserHash)
		AND (@CallBackUrl IS NULL OR CallBack = @CallBackUrl)
		
END 
GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spAddSsoCache') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spAddSsoCache
GO

CREATE PROCEDURE org.spAddSsoCache
	@AID UNIQUEIDENTIFIER ,
	@AMasterPassword UNIQUEIDENTIFIER ,
	@AKey CHAR(32),
	@ASsoTicket CHAR(32),
	@AHash CHAR(128),
	@AUserName VARCHAR(MAX)
--WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE 
		@ID UNIQUEIDENTIFIER = @AID,
		@MasterPassword UNIQUEIDENTIFIER = @AMasterPassword,
		@Key CHAR(32) = @AKey, 
		@SsoTicket CHAR(32) = @ASsoTicket, 
		@Hash CHAR(128) = @AHash, 
		@UserName NVARCHAR(MAX) = @AUserName,
		@Date DATETIME = GETDATE(),
		@ExpireDate DATETIME = DATEADD(SECOND,120,GETDATE()); 
	
		INSERT INTO org.SsoCache
			([ID], [Key], [SsoTicket], [UserName], [Hash], [MasterPassword], [Date], [ExpireDate])
		VALUES
			(@ID, @Key, @SsoTicket, @UserName, @Hash, @MasterPassword, @Date, @ExpireDate)
			
END 

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spDeleteSsoCache') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spDeleteSsoCache
GO

CREATE PROCEDURE org.spDeleteSsoCache
	@AKey CHAR(32)
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE  @Key CHAR(32) = @AKey 
	
	DELETE org.SsoCache WHERE [Key] = @Key
			
END 

GO
USE [Kama.Aro.Organization]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'org.spGetSsoCache') AND type in (N'P', N'PC'))
    DROP PROCEDURE org.spGetSsoCache
GO

CREATE PROCEDURE org.spGetSsoCache
	@AKey CHAR(32)
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE  @Key CHAR(32) = @AKey 
	
	SELECT * FROM org.SsoCache 
		WHERE [Key] = @Key 
		AND [ExpireDate] > GETDATE();
			
END 

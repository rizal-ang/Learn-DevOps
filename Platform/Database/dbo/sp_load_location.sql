CREATE PROC [staging].[sp_load_location]
AS   
   
BEGIN
	BEGIN TRY

		IF OBJECT_ID('tempdb..#templocation') IS NOT NULL
		DROP TABLE #templocation
		
		select p.* INTO #templocation from (SELECT S.SITEID,L.TURBINENO,L.ISACTIVE,L.CREATEDBY,L.CREATEDDATE,L.LASTMODIFIEDBY,L.LASTMODIFIEDDATE FROM STAGING.LOCATION AS L JOIN	SP.SITE	AS S ON L.SITEID = S.ShortSiteId) p 
		
		MERGE INTO sp.Location with(HOLDLOCK) AS target
		USING #templocation AS source
			ON target.SiteId = source.SITEID and target.TurbineNo = source.TURBINENO
		WHEN MATCHED THEN UPDATE SET
			target.SiteId			     = source.SITEID,
			target.TurbineNo		     = source.TURBINENO,
			target.IsActive				 = source.ISACTIVE,
			target.CreatedBy			 = source.CREATEDBY,
			target.CreatedDate			 = source.CREATEDDATE,
			target.LastModifiedBy		 = source.LASTMODIFIEDBY,
			target.LastModifiedDate		 = source.LASTMODIFIEDDATE
		
		WHEN NOT MATCHED BY TARGET THEN 
		INSERT (SiteId,TurbineNo,IsActive,CreatedBy,CreatedDate,LastModifiedBy,LastModifiedDate)
		VALUES(source.SITEID,source.TURBINENO,source.ISACTIVE,source.CREATEDBY,source.CREATEDDATE,source.LASTMODIFIEDBY,source.LASTMODIFIEDDATE);  

	END TRY

	BEGIN CATCH
	DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;
		SET	@ErrorMessage = ERROR_MESSAGE();
		SET	@ErrorSeverity = ERROR_SEVERITY();
		SET	@ErrorState = ERROR_STATE();
		RAISERROR (
			@ErrorMessage, -- Message text.
			@ErrorSeverity, -- Severity.
			@ErrorState -- State.
		);
	END
	CATCH;
END
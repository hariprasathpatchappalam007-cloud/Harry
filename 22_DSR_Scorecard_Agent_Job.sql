-- Deploy AFTER script 21, in the SAME selected application database.
-- Creates/enables a local SQL Agent job; does not execute it immediately.
-- SQL Agent must be installed/running (not SQL Server Express).
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 51200, 'Select the application database before deploying the DSR job.', 1;
IF OBJECT_ID(N'dbo.Proc_DSR_Scorecard_ReconcileMonth', N'P') IS NULL
    THROW 51201, 'Deploy SQL script 21 in this database first.', 1;
IF CONVERT(INT, SERVERPROPERTY('EngineEdition')) = 4
    THROW 51202, 'SQL Server Express does not support SQL Server Agent jobs.', 1;

DECLARE @Database SYSNAME = DB_NAME(), @JobId UNIQUEIDENTIFIER, @ScheduleId INT;
DECLARE @Name NVARCHAR(256) = N'DSR_SCC_to_Fin_' + DB_NAME();
DECLARE @ScheduleName SYSNAME = N'DSR_SCC_to_Fin_' + CONVERT(NVARCHAR(12), DB_ID()) + N'_0100_0600';
DECLARE @Description NVARCHAR(512) =
    N'Managed by SQL/22_DSR_Scorecard_Agent_Job.sql; target=' + QUOTENAME(DB_NAME());
DECLARE @Today INT = CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112));
IF LEN(@Name) > 128
    THROW 51203, 'Application database name is too long for the DSR job name.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    SELECT @JobId = job_id FROM msdb.dbo.sysjobs WHERE name = @Name;
    IF @JobId IS NOT NULL AND EXISTS
        (SELECT 1 FROM msdb.dbo.sysjobs WHERE job_id = @JobId AND ISNULL(description, N'') <> @Description)
        THROW 51204, 'A different job already uses the DSR job name; deployment stopped.', 1;

    IF @JobId IS NULL
    BEGIN
        EXEC msdb.dbo.sp_add_job @job_name = @Name, @enabled = 1,
            @description = @Description, @job_id = @JobId OUTPUT;
        EXEC msdb.dbo.sp_add_jobstep @job_id = @JobId, @step_id = 1,
            @step_name = N'Reconcile one creation month', @subsystem = N'TSQL',
            @database_name = @Database, @command = N'EXEC dbo.Proc_DSR_Scorecard_ReconcileMonth;',
            @on_success_action = 1, @on_fail_action = 2,
            @retry_attempts = 0, @flags = 8;
        EXEC msdb.dbo.sp_add_jobserver @job_id = @JobId, @server_name = N'(LOCAL)';
    END
    ELSE
    BEGIN
        IF (SELECT COUNT(*) FROM msdb.dbo.sysjobsteps WHERE job_id = @JobId) <> 1
            THROW 51205, 'Managed DSR job has unexpected steps; review it before redeploying.', 1;
        EXEC msdb.dbo.sp_update_job @job_id = @JobId, @enabled = 1, @start_step_id = 1;
        EXEC msdb.dbo.sp_update_jobstep @job_id = @JobId, @step_id = 1,
            @step_name = N'Reconcile one creation month', @subsystem = N'TSQL',
            @database_name = @Database, @command = N'EXEC dbo.Proc_DSR_Scorecard_ReconcileMonth;',
            @on_success_action = 1, @on_fail_action = 2,
            @retry_attempts = 0, @flags = 8;
    END;

    IF EXISTS
    (
        SELECT 1 FROM msdb.dbo.sysjobschedules js
        INNER JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
        WHERE js.job_id = @JobId AND s.name <> @ScheduleName
    )
        THROW 51206, 'Managed DSR job has an unexpected schedule; review it before redeploying.', 1;

    SELECT @ScheduleId = s.schedule_id
    FROM msdb.dbo.sysjobschedules js
    INNER JOIN msdb.dbo.sysschedules s ON s.schedule_id = js.schedule_id
    WHERE js.job_id = @JobId AND s.name = @ScheduleName;

    IF @ScheduleId IS NULL
        EXEC msdb.dbo.sp_add_jobschedule @job_id = @JobId, @name = @ScheduleName,
            @enabled = 1, @freq_type = 4, @freq_interval = 1,
            @freq_subday_type = 8, @freq_subday_interval = 1,
            @active_start_date = @Today, @active_start_time = 010000, @active_end_time = 060000;
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobschedules WHERE schedule_id = @ScheduleId AND job_id <> @JobId)
            THROW 51207, 'DSR schedule is shared with another job; deployment stopped.', 1;
        EXEC msdb.dbo.sp_update_schedule @schedule_id = @ScheduleId,
            @enabled = 1, @freq_type = 4, @freq_interval = 1,
            @freq_subday_type = 8, @freq_subday_interval = 1,
            @active_start_date = @Today, @active_end_date = 99991231,
            @active_start_time = 010000, @active_end_time = 060000;
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT @Database AS ApplicationDatabase, @Name AS JobName,
    N'Daily 01:00, 02:00, 03:00, 04:00, 05:00, 06:00 (SQL Server local time)' AS Schedule;

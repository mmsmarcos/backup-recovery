/*
	Autor: Marcos Miguel
	Site: www.mdb.net
	Data: 19/07/2018

	Passo 1.
	Criar procedure para executar os bakups.
*/

--Procedure

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'dbCheckList')
BEGIN
CREATE DATABASE [dbCheckList]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'dbCheckList', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\dbCheckList.mdf' , SIZE = 5120KB , FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'dbCheckList_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\dbCheckList_log.ldf' , SIZE = 1024KB , FILEGROWTH = 10%)

ALTER DATABASE [dbCheckList] SET RECOVERY SIMPLE

END

USE [dbCheckList]
GO

IF (OBJECT_ID('[dbo].[Proc_Backup_Full]') IS NOT NULL)
	DROP PROCEDURE [dbo].[Proc_Backup_Full]
GO

CREATE PROCEDURE [dbo].[Proc_Backup_Full] (@Banco VARCHAR(100), @Diretorio VARCHAR(100))
AS
BEGIN

SET NOCOUNT ON

IF OBJECT_ID('tempdb..#Drive') IS NOT NULL DROP TABLE tempdb..#Drive

CREATE TABLE tempdb..#Drive (
	Id int NOT NULL IDENTITY(1,1) PRIMARY KEY,
	Descricao VARCHAR(MAX))

DECLARE @Dispositivo VARCHAR(MAX);
SET @Dispositivo = @Diretorio+@Banco+'_FULL_'+LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(20), GETDATE(), 120), '-', ''), ':', ''), ' ', '')))+'.bak';

INSERT INTO tempdb..#Drive VALUES (@Dispositivo)

BACKUP DATABASE @Banco 
	TO DISK = @Dispositivo
	WITH FORMAT, 
	INIT, 
	NAME = N'Backup Completo do Banco de Dados ', 
	SKIP, 
	STATS = 10,
	CHECKSUM,
	CONTINUE_AFTER_ERROR

DECLARE @backupSetId AS INT

SELECT @backupSetId = position FROM msdb..backupset WHERE DATABASE_NAME=@Banco AND backup_set_id=(SELECT MAX(backup_set_id) FROM msdb..backupset WHERE DATABASE_NAME=@Banco )
IF @backupSetId IS NULL 
	BEGIN
		RAISERROR(N'Falha na verificação. Informações de backup do banco de dados não encontradas.', 16, 1) 
	END;

DECLARE @Backup VARCHAR(MAX)

SET @Backup = (SELECT Descricao FROM tempdb..#Drive WHERE Id = (SELECT MAX(Id) FROM tempdb..#Drive))

RESTORE VERIFYONLY FROM  DISK = @Backup WITH  FILE = @backupSetId,  NOUNLOAD,  NOREWIND

END

/*
	Passo 2.
	Criar um JOB par executar a procedure no tempo determinado para execução do backup
*/

EXEC [dbo].[Proc_Backup_Full] 'dbTreinamento', 'C:\Backup_SQL\'
-- sql/grant-app-identities.sql
-- Creates database users for the two managed identities and grants least-privilege roles.
-- "WITH SID … TYPE = E" uses the identity's client ID directly, so the SQL server doesn't
-- need permission to look the identity up in Entra ID. Safe to run repeatedly.
DECLARE @sql nvarchar(max);

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$(ApiName)')
BEGIN
  SET @sql = N'CREATE USER [$(ApiName)] WITH SID = '
           + CONVERT(nvarchar(64), CAST(CAST(N'$(ApiClientId)' AS uniqueidentifier) AS varbinary(16)), 1)
           + N', TYPE = E;';
  EXEC (@sql);
END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$(MigratorName)')
BEGIN
  SET @sql = N'CREATE USER [$(MigratorName)] WITH SID = '
           + CONVERT(nvarchar(64), CAST(CAST(N'$(MigratorClientId)' AS uniqueidentifier) AS varbinary(16)), 1)
           + N', TYPE = E;';
  EXEC (@sql);
END;

-- The app reads and writes data, nothing more.
ALTER ROLE db_datareader ADD MEMBER [$(ApiName)];
ALTER ROLE db_datawriter ADD MEMBER [$(ApiName)];

-- The migrator may also change the schema (create tables, add columns).
ALTER ROLE db_ddladmin   ADD MEMBER [$(MigratorName)];
ALTER ROLE db_datareader ADD MEMBER [$(MigratorName)];
ALTER ROLE db_datawriter ADD MEMBER [$(MigratorName)];

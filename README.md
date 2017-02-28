
DEVELOPMENT
1) Add every your change in separate update file. The change should be atomic. Use next naming for your file: update_<short description>_<year>_<month>_<day>_0.sql.
The name should be unique.
2) Create update_<short description>_<year>_<month>_<day>_rollback_N.sql with script for reverting your last changes.
--We don't need rollback for atomic changes so don't create it.

Wrap a change with transaction.
Example. Recreate a table and don't loose data.
CREATE TABLE IF NOT EXISTS <table_name> (
  column1 INT,
  column2 STRING,
  column3 INT
)
PARTITIONED BY (
  column4 INT
)
STORED AS PARQUET;


0. -script name-> update_recreate-<table_name>_2016-01-01_0.sql
--transaction 0
--author Mikalai Hrynko (grinko.nikolai@gmail.com)
--title Add partition column, change column1 type from INT to TIMESTAMP. 
CREATE TABLE <table_name>_temp STORED AS PARQUET AS SELECT * from <table_name>;

1. -script name-> update_recreate-<table_name>_2016-01-01_1.sql
--transaction 1
--author Mikalai Hrynko (grinko.nikolai@gmail.com)
--title Add partition column, change column1 type from INT to TIMESTAMP.
DROP TABLE IF EXISTS <table_name>;

2. -script name-> update_recreate-table_2016-01-01_2.sql
--transaction 2
--author Mikalai Hrynko (grinko.nikolai@gmail.com)
--title Add partition column, change column1 type from INT to TIMESTAMP. 
CREATE TABLE IF NOT EXISTS <table_name> (
  column1 INT,
  column2 STRING,
  column3 INT
)
PARTITIONED BY (
  column4 INT,
  column5 INT
)
STORED AS PARQUET;

3. -script name-> update_recreate-table_2016-01-01_3.sql
--transaction 3
--author Mikalai Hrynko (grinko.nikolai@gmail.com)
--title Add partition column, change column1 type from INT to TIMESTAMP.
INSERT INTO TABLE <table_name> partition(scenarioid, scenariotaxyearid)
SELECT
  now(),
  column2,
  column3
  column4,
  column5
FROM
<table_name>_temp;

4. -script name-> update_recreate-table_2016-01-01_4.sql
--transaction 4
--author Mikalai Hrynko (grinko.nikolai@gmail.com)
--title Add partition column, change column1 type from INT to TIMESTAMP.
DROP TABLE IF EXISTS <table_name>_temp;


Rollback scripts:
0. -script name-> update_recreate-table_2016-01-01_rollback_0.sql
--rollback 0
--author Mikalai Hrynko (grinko.nikolai@gmail.com)
--title Add partition column, change column1 type from INT to TIMESTAMP.
DROP TABLE IF EXISTS <table_name>_temp;

1. -script name-> update_recreate-table_2016-01-01_rollback_1.sql
--transaction 1
--author Mikalai Hrynko (grinko.nikolai@gmail.com)
--title Add partition column, change column1 type from INT to TIMESTAMP.
--create previous version of the table
CREATE TABLE <table_name> STORED AS PARQUET AS SELECT * from <table_name>_tmp;

Rollback works next way:
If (failed 0) then {do nothing; log}
If (failed 1) then run rollback 0;
If (failed 2 or 3) then {run rollback 1; run rollback 0};
If (failed 4) then {do nothing; log}
We have only one case when we need rollback.



DEPLOYING on existing Env
First deployment:
1) create folder /home/<user>/<path_to_project>/updateImpala
2) copy updateImpala.sh to that folder
3) copy v<RELEASE_DATE> folder to the directory
4) create <ENV>_state.updates table with create_state_tables.script
5) copy updateImpala.config to the directory
6) change parameters in the config
7) Run updateImpala.sh with command:
    sh updateImpala.sh <IMPALA_HOST> <ENV> <path/to/config>

Subsequent deployments:
1) Copy all v<RELEASE_DATE> folders from init state to needed release to your Env machine.
Example:
You have next release folders in your repo:
v20170120
v20170205
v20170218 - first usage of the script, and it is first update folder on each env
v20170304
v20170315 - current release
v20170325

You need to copy folders v20170220, v20170304, v20170315 and overwrite all scripts.
The script will try to run all the update files but will succeed only with not ran yet or with failed before.

2) Run updateImpala.sh with command:
 sh updateImpala.sh <IMPALA_HOST> <ENV>



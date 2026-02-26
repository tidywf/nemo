# Notes

Just a dump of random notes!

## SQL

### ACID

- Atomic:
- Consistent:
- Isolated: online data backups
- Durable: guaranteed not to lose committed data

### Table Manipulation

#### Create/drop database

``` sql
DROP DATABASE IF EXISTS test1;
CREATE DATABASE test1;
```

#### Create/drop table

``` sql
DROP TABLE IF EXISTS cities;
CREATE TABLE cities (
    name VARCHAR(50),
    country VARCHAR(50),
    population INTEGER,
    area INTEGER
);
```

#### Insert data

``` sql
INSERT INTO cities (name, country, population, area)
VALUES
 ('Tokyo', 'Japan', 38505000, 8223),
 ('Delhi', 'India', 28125000, 2240),
 ('Shanghai', 'China', 22125000, 4015),
 ('Sao Paulo', 'Brazil', 20935000, 3043);
```

#### Filter data

``` sql
SELECT * FROM cities
WHERE population > 25000000;
```

#### Update data

``` sql
UPDATE cities
SET population = 39505000
WHERE name = 'Tokyo';
```

#### Delete data

``` sql
DELETE FROM cities
WHERE name = 'Sao Paulo';
```

#### Primary key

``` sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50)
);
```

#### Foreign key

``` sql
CREATE TABLE photos (
    id SERIAL PRIMARY KEY,
    url VARCHAR(200),
    user_id INTEGER REFERENCES users(id)
);
```

#### On Delete

| Option        | Description |
|---------------|-------------|
| `RESTRICT`    | Throw error |
| `NO ACTION`   | Throw error |
| `CASCADE`     | Cascade     |
| `SET NULL`    | Set null    |
| `SET DEFAULT` | Set default |

#### Join

``` sql
SELECT users.username, photos.url FROM users
JOIN photos ON users.id = photos.user_id;
```

| Option | Description |
|----|----|
| `INNER` | (default) Keep all matching rows in both tables, drop unmatched rows |
| `LEFT` | Keep all rows in left table, using NULL in place of right unmatched rows, drop rows in right table without a match |
| `RIGHT` | Keep all rows in right table, using NULL in place of left unmatched rows, drop rows in left table without a match |
| `FULL` | Keep all matching rows in both tables, using NULL in place of unmatched rows |

#### Aggregate functions

``` sql
SELECT COUNT(*) FROM cities;
SELECT SUM(population) FROM cities;
SELECT AVG(population) FROM cities;
SELECT MAX(population) FROM cities;
SELECT MIN(population) FROM cities;
```

#### Group by with Join

- remember to select the group by column

``` sql
SELECT authors.name, COUNT(*) FROM books
JOIN authors ON authors.id = books.author_id
GROUP BY authors.name;
```

#### Group by Having

- filters out the groups

``` sql
SELECT authors.name, COUNT(*) FROM books
JOIN authors ON authors.id = books.author_id
GROUP BY authors.name
HAVING COUNT(*) > 1;
```

#### ORDER

``` sql
SELECT * FROM cities
ORDER BY population DESC;
```

#### OFFSET and LIMIT

- `OFFSET` skips the first `n` rows
- `LIMIT` returns the first `n` rows

``` sql
SELECT * FROM cities LIMIT 3;
SELECT * FROM cities OFFSET 3;
```

- Grab the names of only the second and third most populated cities:

``` sql
SELECT name FROM cities
ORDER BY population DESC
LIMIT 2 OFFSET 1;
```

#### UNION

- `UNION`: join results from two queries, and remove duplicates
- `UNION ALL`: keeps duplicates

``` sql
(
SELECT * FROM products
ORDER BY price DESC
LIMIT 4
)
UNION
(
SELECT * FROM products
ORDER BY price / weight DESC
LIMIT 4
);
```

#### INTERSECT

- `INTERSECT`: join common rows from two queries, and remove duplicates
- `INTERSECT ALL`: keeps duplicates

``` sql
(
SELECT * FROM products
ORDER BY price DESC
LIMIT 4
)
INTERSECT
(
SELECT * FROM products
ORDER BY price / weight DESC
LIMIT 4
);
```

#### EXCEPT

- `EXCEPT`: find rows in first query but not in second, and remove
  duplicates
- `EXCEPT ALL`: keeps duplicates

### Data Types

#### Numeric

| Name                | Description                    |
|---------------------|--------------------------------|
| `SMALLINT`          | +/-32,768                      |
| `INTEGER`           | +/-2,147,483,648               |
| `BIGINT`            | +/-9,223,372,036,854,775,808   |
| `DECIMAL`/`NUMERIC` | Use this for precision         |
| `REAL`              | 4 bytes                        |
| `DOUBLE PRECISION`  | 8 bytes                        |
| `SMALLSERIAL`       | 1 to 32,767                    |
| `SERIAL`            | 1 to 2,147,483,647             |
| `BIGSERIAL`         | 1 to 9,223,372,036,854,775,807 |

#### Character

| Name         | Description     |
|--------------|-----------------|
| `CHAR`       | Fixed length    |
| `VARCHAR(N)` | Variable length |
| `TEXT`       | Variable length |

#### Date and Time

| Name        | Description         |
|-------------|---------------------|
| `DATE`      | YYYY-MM-DD          |
| `TIME`      | HH:MM:SS            |
| `TIMESTAMP` | YYYY-MM-DD HH:MM:SS |

### Validation and Constraints

#### NOT NULL

- `CREATE TABLE`

``` sql
CREATE TABLE phones (
  id SERIAL PRIMARY KEY,
  manufacturer VARCHAR(255) NOT NULL,
  model VARCHAR(255) NOT NULL
);
```

- `ALTER TABLE`

``` sql
ALTER TABLE phones
ALTER COLUMN manufacturer
SET NOT NULL;
```

#### DEFAULT

- `CREATE TABLE`

``` sql
CREATE TABLE phones (
  id SERIAL PRIMARY KEY,
  manufacturer VARCHAR(255) DEFAULT 'Apple',
  model VARCHAR(255) NOT NULL
);
```

- `ALTER TABLE`

``` sql
ALTER TABLE phones
ALTER COLUMN manufacturer
SET DEFAULT 'Apple';
```

#### UNIQUE

- `CREATE TABLE`

``` sql
CREATE TABLE phones (
  id SERIAL PRIMARY KEY,
  manufacturer VARCHAR(255) NOT NULL,
  model VARCHAR(255) NOT NULL UNIQUE
);
```

- `ALTER TABLE`

``` sql
ALTER TABLE phones
ADD UNIQUE(model);
```

#### CHECK

- `CREATE TABLE`

``` sql
CREATE TABLE phones (
  id SERIAL PRIMARY KEY,
  manufacturer VARCHAR(255) NOT NULL,
  model VARCHAR(255) NOT NULL,
  price NUMERIC CHECK (price > 0)
);
```

- `ALTER TABLE`

``` sql
ALTER TABLE phones
ADD CHECK (price > 0);
```

### Internals

- Size per database:

``` sql
SELECT datname, pg_database_size(datname) AS bytes
FROM pg_database
```

``` text
  datname  │  bytes
═══════════╪═════════
 postgres  │ 7761043
 pdiakumis │ 7842963
 template1 │ 7842963
 template0 │ 7602703
 test1     │ 7924883
```

``` sql
SHOW data_directory;
# /opt/homebrew/var/postgresql@15
```

``` sql
# see the dir above for the oid folders
SELECT oid, datname
FROM pg_database;
```

| oid   | datname     |
|-------|-------------|
| 5     | “postgres”  |
| 16388 | “pdiakumis” |
| 1     | “template1” |
| 4     | “template0” |
| 16451 | “test”      |
| 16742 | “foo”       |

``` sql
# shows the individual files within each folder
SELECT * FROM pg_class;
```

| Name | Description |
|----|----|
| Heap | File with all the data of the table |
| Tuple/item | Row from the table |
| Block/page | Heap file is divided into blocks, each containing a number of rows. The size of each block is usually 8 KB. |

### Index

- Create

``` sql
CREATE INDEX ON cities (name, population);
```

- Drop

``` sql
DROP INDEX cities_name_population_idx;
```

- Benchmark

``` sql
EXPLAIN ANALYZE SELECT * FROM users
WHERE username = 'Emil30';
```

- Size

``` sql
SELECT pg_size_pretty(pg_relation_size('users'));
```

- List indexes for database

``` sql
SELECT relname, relkind
FROM pg_class
WHERE relkind = 'i';
```

### Views

- Create

``` sql
CREATE VIEW recent_posts AS (
    SELECT * FROM posts
    ORDER BY created_at DESC
    LIMIT 10
);
```

- Change
  - e.g. from 10 to 15

``` sql
CREATE OR REPLACE VIEW recent_posts AS (
    SELECT * FROM posts
    ORDER BY created_at DESC
    LIMIT 15
);
```

- Drop

``` sql
DROP VIEW recent_posts;
```

### psql

- `\c db_name`: choose database
- `\?`: help
- `\l`: list databases
- `\dt`: list tables
- `\d table_name`: describe table
- `\e`: open last query in EDITOR
- `\conninfo`: You are connected to database “nemo” as user “orcabus”
  via socket in “/tmp” at port “5432”.
- `\du`: list users

### R

- List tables

``` r
DBI::dbListObjects(conn, Id(schema = "mySchemaName"))
```

### Schema

#### Dump

    pg_dump --schema-only nemo > schema.txt

#### dm

``` r
dm <- dm:::dm_meta_raw(con, NULL)
dm$columns
```

#### DBI

``` r
tbl <- tibble::tibble(
  dracarysId = "abcd1234",
  foo_num = 123,
  foo_dbl = 3.14,
  foo_chr = "foobar",
  foo_int = 35L,
)
DBI::dbDataType(DBI::ANSI(), tbl)
# dracarysId    foo_num    foo_dbl    foo_chr    foo_int
#     "TEXT"   "DOUBLE"   "DOUBLE"     "TEXT"      "INT"
```

``` r
DBI::dbGetInfo(con) |> str()
# List of 8
#  $ dbname          : chr "test1"
#  $ host            : chr "/tmp"
#  $ port            : chr "5432"
#  $ username        : chr "pdiakumis"
#  $ protocol.version: int 3
#  $ server.version  : int 170002
#  $ db.version      : int 170002
#  $ pid             : int 17045
```

## AWS RDS

### Intro

- DB instance: isolated db environment
  - takes an ID (e.g. `db-xxxxxx`) specified by customer, used in DNS
    hostname allocated by RDS
    (e.g. `db-xxxxxx.ap-southeast-2.rds.amazonaws.com`)
- DB engine: MySQL, PostgreSQL etc.
- DB instance class: computation and memory of instance
  - consists of instance type and size
  - e.g.: db.m6g type, db.m6g.2xlarge class
- DB instance storage: General purpose SSD (dev/test), Provisioned IOPS
  SSD (prod).
- VPC: run DB instance on a VPC (IP address range, subnet, routing, ACLs
  etc.)
  - no additional cost
- DB Regions/AZs:
  - Region: physical location e.g. Sydney `ap-southeast-2`
  - AZ: availability zone e.g. `ap-southeast-2a`
- DB security groups: allow access to IP address range or EC2
- DB monitoring: via CloudWatch
- Working with RDS: console, CLI, RDS APIs
- Billing: per second, minimum 10min

### Commands

- list DB instance classes for Postgres:

&nbsp;

    aws rds describe-orderable-db-instance-options \
      --engine postgres \
      --engine-version 15.4 \
      --query "*[].{DBInstanceClass:DBInstanceClass,StorageType:StorageType}|[?StorageType=='gp2']|[].{DBInstanceClass:DBInstanceClass}" \
      --output text \
      --region ap-southeast-2

    ## db.m5.12xlarge
    ## db.m5.16xlarge
    ## db.m5.24xlarge
    ## ...

- list Postgres versions that support db.m7g.large:

&nbsp;

    aws rds describe-orderable-db-instance-options \
      --engine postgres \
      --db-instance-class db.m7g.large \
      --query "*[].{EngineVersion:EngineVersion,StorageType:StorageType}|[?StorageType=='gp2']|[].{EngineVersion:EngineVersion}" \
      --output text \
      --region ap-southeast-2

    ## ...
    ## 15.4
    ## 15.5
    ## 16.1
    aws ec2 describe-availability-zones --region $AWS_DEFAULT_REGION | jq -r '.AvailabilityZones[].ZoneName'
    ## ap-southeast-2a
    ## ap-southeast-2b
    ## ap-southeast-2c

## AWS CDK

### Building Blocks

- **Project**: files and folders with CDK code.

  - `cdk.json`: config file
  - `bin/infrastructure.ts`: application file
  - `lib/index.ts`: stack file

- **App**: application written in e.g. TypeScript that defines one or
  more **Stacks**.

- **Stack**: a logical grouping of **Constructs**.

- **Construct**: a logical grouping of **Resources**.

- **Resource**: e.g. S3 buckets, Lambda, DynamoDB.

### Constructs

A construct class takes three params:

- **scope**: construct’s parent/owner; use `this` to say the stack is
  its parent.
- **id**: logical ID of construct within app; used as namespace; should
  be unique within scope.
- **props**: bundle of key-values passed in an object; can be omitted if
  all optional.

#### AWS Construct Links

- Hub - https://constructs.dev/

  - e.g. GitHub Actions OIDC:
    - https://constructs.dev/packages/aws-cdk-github-oidc
    - https://github.com/aripalo/aws-cdk-github-oidc

- Library

  - https://docs.aws.amazon.com/cdk/api/v2/docs/aws-construct-library.html

#### Construct Levels

- L1: low level CFN Resources that are named `CfnXyz` e.g.
  [CfnBucket](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_s3.CfnBucket.html)
- L2: higher level with convenient defaults
  e.g. [s3.Bucket](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_s3.Bucket.html)
- L3: patterns that help with common tasks involving multiple resources
  e.g.
  [aws-apigateway.LambdaRestApi](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_apigateway.LambdaRestApi.html).

### Commands

| Command                  | Description                       |
|--------------------------|-----------------------------------|
| `cdk init -l typescript` | initialize cdk project            |
| `npm run build`          | compile ts to js                  |
| `npm run watch`          | watch for changes and compile     |
| `npm run test`           | run jest unit tests               |
| `npx cdk deploy`         | deploy stack                      |
| `npx cdk diff`           | compare current to deployed stack |
| `npx cdk synth`          | emit synthesized cfn template     |
| `npx cdk destroy`        | destroy stack                     |
| `npx cdk bootstrap`      | bootstrap cdk project             |

### Tips

- Debug bucket names
  - Use `CfnOutput` and check `cdk synth`

``` ts
import { CfnOutput } from 'aws-cdk-lib';

const l2bucket = new Bucket(this, 'foo');
new CfnOutput(this, 'output1', {
  value: l2bucket.bucketName,
});
```

- Use deploy parameter:

``` ts
 const duration = new CfnParameter(this, 'duration', {
   default: 6,
   minValue: 1,
   maxValue: 10,
   type: 'Number',
 });
 const l2bucket = new Bucket(this, 'nemo-l2-dev', {
   lifecycleRules: [
     {
       expiration: Duration.days(duration.valueAsNumber),
     },
   ],
 });
```

Then:

``` shell
cdk deploy --parameters duration=8
```

## Pixi

### Installation

Pixi is awesome - see <https://pixi.sh/>.

    brew install pixi

### Project

    cd my_projects
    pixi init hello-world -c conda-forge -c umccr
    cd hello-world

- `pixi.toml`

A TOML file `pixi.toml` is created in the project directory:

``` toml
[workspace]
authors = ["pdiakumis <peterdiakumis@gmail.com>"]
channels = ["conda-forge", "umccr"]
name = "hello-world"
platforms = ["osx-arm64"]
version = "0.1.0"

[tasks]


[dependencies]
```

- dependencies

This will look into the `conda-forge` and `umccr` conda channels for
`r-tidywigits`, and install it into `./.pixi` along with its
dependencies.

    pixi add r-tidywigits
    ls -1 .pixi/envs/default/lib/R/library/tidywigits/cli
    list.R
    tidy.R
    tidywigits.R

- `pixi.lock`

A lock file `pixi.lock` is also created in the project directory

### Tasks

    pixi task add tidy "tidywigits.R"

Then you run that task with `pixi run <...>`:

    pixi run tidy --help
    ✨ Pixi task (tidy): tidywigits.R --help
    usage: tidywigits.R [-h] [-v] {tidy,list} ...

    🐠 WiGiTS Output Tidying 🐢

    [...]

### Environment

- activate pixi environment

&nbsp;

    pixi shell

This behaves like a conda environment with the env prefix:

    (hello-world) $ ...

To exit:

    exit

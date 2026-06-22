### Intro

- DB instance: isolated db environment
  - takes an ID (e.g. `db-xxxxxx`) specified by customer, used in DNS hostname
    allocated by RDS (e.g. `db-xxxxxx.ap-southeast-2.rds.amazonaws.com`)
- DB engine: MySQL, PostgreSQL etc.
- DB instance class: computation and memory of instance
  - consists of instance type and size
  - e.g.: db.m6g type, db.m6g.2xlarge class
- DB instance storage: General purpose SSD (dev/test), Provisioned IOPS SSD
  (prod).
- VPC: run DB instance on a VPC (IP address range, subnet, routing, ACLs etc.)
  - no additional cost
- DB Regions/AZs:
  - Region: physical location e.g. Sydney `ap-southeast-2`
  - AZ: availability zone e.g. `ap-southeast-2a`
- DB security groups: allow access to IP address range or EC2
- DB monitoring: via CloudWatch
- Working with RDS: console, CLI, RDS APIs
- Billing: per second, minimum 10min

### Commands

- list DB instance classes for Postgres:

```
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
```

- list Postgres versions that support db.m7g.large:

```
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
```

```
aws ec2 describe-availability-zones --region $AWS_DEFAULT_REGION | jq -r '.AvailabilityZones[].ZoneName'
## ap-southeast-2a
## ap-southeast-2b
## ap-southeast-2c
```

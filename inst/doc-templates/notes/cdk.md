### Building Blocks

- **Project**: files and folders with CDK code.

  - `cdk.json`: config file
  - `bin/infrastructure.ts`: application file
  - `lib/index.ts`: stack file

- **App**: application written in e.g. TypeScript that defines one or more
  **Stacks**.
- **Stack**: a logical grouping of **Constructs**.
- **Construct**: a logical grouping of **Resources**.
- **Resource**: e.g. S3 buckets, Lambda, DynamoDB.

### Constructs

A construct class takes three params:

- **scope**: construct's parent/owner; use `this` to say the stack is its
  parent.
- **id**: logical ID of construct within app; used as namespace; should be
  unique within scope.
- **props**: bundle of key-values passed in an object; can be omitted if all
  optional.

#### AWS Construct Links

- Hub - https://constructs.dev/

  - e.g. GitHub Actions OIDC:
    - https://constructs.dev/packages/aws-cdk-github-oidc
    - https://github.com/aripalo/aws-cdk-github-oidc

- Library
  - https://docs.aws.amazon.com/cdk/api/v2/docs/aws-construct-library.html

#### Construct Levels

- L1: low level CFN Resources that are named `CfnXyz` e.g.
  [CfnBucket][l1-bucket]
- L2: higher level with convenient defaults e.g. [s3.Bucket][l2-bucket]
- L3: patterns that help with common tasks involving multiple resources e.g.
  [aws-apigateway.LambdaRestApi][l3-apilambda].

[l1-bucket]:
  https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_s3.CfnBucket.html
[l2-bucket]:
  https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_s3.Bucket.html
[l3-apilambda]:
  https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_apigateway.LambdaRestApi.html

### Commands

| Command                  | Description                       |
| ------------------------ | --------------------------------- |
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

```ts
import { CfnOutput } from 'aws-cdk-lib';

const l2bucket = new Bucket(this, 'foo');
new CfnOutput(this, 'output1', {
  value: l2bucket.bucketName,
});
```

- Use deploy parameter:

```ts
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

```shell
cdk deploy --parameters duration=8
```

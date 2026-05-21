# AWS SMTP Sender

`aws-smtp-sender` provisions SES-backed outbound SMTP for a sender domain and publishes the SMTP password to AWS Secrets Manager.

## Why SMTPSender?

Without SMTPSender:

- Every app has to solve SES identity setup, DKIM tokens, IAM credentials, and SMTP password storage independently.
- SMTP credentials are easy to leak because the IAM secret key is not the SES SMTP password.
- DKIM setup becomes an operator runbook instead of a GitOps output.

With SMTPSender:

- SES identity, IAM SMTP user, access key, and Secrets Manager publication are one declarative XR.
- Non-secret SMTP connection data is exposed in typed status.
- The secret value stored in AWS Secrets Manager is the SES SMTP password from the AccessKey connection secret key `attribute.ses_smtp_password_v4`.
- Optional dedicated IP pools and SES configuration sets isolate sender reputation when the extra AWS cost is justified.

## The Journey

### Stage 1: Getting Started

Create one sender for a domain:

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: SMTPSender
metadata:
  name: ops
  namespace: default
spec:
  domain: ops.com.ai
  clusterName: pat-local
  region: us-east-2
  managementPolicies:
    - "*"
```

This creates an SESv2 `EmailIdentity`, IAM `User`, IAM `Policy`, IAM `UserPolicyAttachment`, IAM `AccessKey`, Secrets Manager `Secret`, and `SecretVersion`.

### Stage 2: Growing

Customize the IAM user, ProviderConfig, tags, and secret path:

```yaml
spec:
  domain: ops.com.ai
  clusterName: pat-local
  region: us-east-2
  providerConfigRef:
    name: aws-prod
  iam:
    userName: ops-smtp
  pushCredentials:
    path: push/pat-local/ops-smtp
  tags:
    Team: platform
```

Multiple `SMTPSender` resources can run in the same AWS account when they
use unique SES identities, IAM user names, and Secrets Manager paths. They
share the account and Region SES sending quota.

### Stage 3: Dedicated IP Reputation (Opt-in)

Dedicated IP pools are disabled by default because they are cost-bearing AWS resources. Enable them only for senders that need isolated reputation, such as marketing or high-volume transactional mail:

```yaml
spec:
  dedicatedIpPool:
    enabled: true
    scalingMode: MANAGED
  configurationSet:
    deliveryOptions:
      tlsPolicy: REQUIRE
      maxDeliverySeconds: 50400
    reputationMetricsEnabled: true
    sendingEnabled: true
```

This creates an SESv2 `DedicatedIPPool` and a `ConfigurationSet` whose `deliveryOptions.sendingPoolName` points at the pool. SMTP consumers must send with the configuration set, for example via the `X-SES-CONFIGURATION-SET` header, for mail to use the dedicated pool.

### Stage 4: Enterprise Scale

Set `accountId` to scope the SES send policy ARN to a specific account and apply an IAM permissions boundary:

```yaml
spec:
  accountId: "034489662075"
  iam:
    permissionsBoundaryArn: arn:aws:iam::034489662075:policy/platform-boundary
```

If `accountId` is omitted, the policy uses a wildcard account segment while still scoping by region and identity domain.

### Stage 5: Import Existing

Use external-name fields and orphaning management policies to observe existing IAM resources without deleting them:

```yaml
spec:
  managementPolicies:
    - Create
    - Observe
    - Update
    - LateInitialize
  iam:
    userExternalName: existing-smtp-user
    policyExternalName: existing-smtp-policy
```

## Using SMTPSender

Consumers combine public status fields with the password stored in AWS Secrets Manager:

- `status.smtp.host`
- `status.smtp.port`
- `status.smtp.username`
- `status.smtp.awsSecretsManagerPath`

The DKIM publisher reads `status.dkim.tokens` and creates three CNAME records:

```text
<token>._domainkey.<domain> CNAME <token>.dkim.amazonses.com
```

## Status

- `status.ready`: all enabled AWS resources are ready.
- `status.smtp.*`: SMTP host, port, username, and AWS Secrets Manager password path.
- `status.dkim.*`: SES verification status and DKIM tokens for DNS publication.
- `status.iam.*`: IAM user and policy ARNs.
- `status.ses.identityArn`: SES identity ARN.
- `status.ses.dedicatedIpPool.*`: dedicated IP pool ARN, name, and scaling mode when enabled.
- `status.ses.configurationSet.*`: SES configuration set ARN and name when enabled.
- `status.secret.arn`: Secrets Manager secret ARN when credential push is enabled.

## Composed Resources

- `sesv2.aws.m.upbound.io/EmailIdentity`: sender domain identity and DKIM tokens.
- `sesv2.aws.m.upbound.io/DedicatedIPPool`: optional cost-bearing dedicated IP pool when `spec.dedicatedIpPool.enabled=true`.
- `sesv2.aws.m.upbound.io/ConfigurationSet`: optional configuration set that selects the dedicated IP pool.
- `iam.aws.m.upbound.io/User`: SMTP IAM user.
- `iam.aws.m.upbound.io/Policy`: `ses:SendRawEmail` permission scoped to the identity ARN.
- `iam.aws.m.upbound.io/UserPolicyAttachment`: attaches the send policy to the SMTP user.
- `iam.aws.m.upbound.io/AccessKey`: creates SMTP username and connection secret.
- `secretsmanager.aws.m.upbound.io/Secret`: AWS Secrets Manager path for the SMTP password.
- `secretsmanager.aws.m.upbound.io/SecretVersion`: writes `attribute.ses_smtp_password_v4` into the secret.

## Development

```bash
make render:all
make validate:all
make test
make e2e
```

The E2E test creates a timestamped sender identity under `ops.com.ai`, waits
for the XR to become ready, then deletes it. This uses full lifecycle
management because SMTP senders are not singleton account resources.

## License

Apache-2.0

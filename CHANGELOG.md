### What's changed in v0.3.0

* feat: optional Cloudflare DKIM publication via spec.cloudflare.dkim (#2) (by @patrickleet)

  * feat: add optional Cloudflare DKIM publication via spec.cloudflare.dkim

  Folds the Cloudflare DKIM CNAME publication (formerly the separate cloudflare-dkim-records and outbound-email packages) into SMTPSender as an opt-in spec.cloudflare.dkim block. The composition reads the SES identity's own DKIM tokens and composes three Cloudflare Record MRs, gated on enabled + 3 observed tokens + zoneId, folding their readiness into aggregate status (status.dkim.recordsReady/records). A CEL rule rejects enabled-without-zoneId. provider-cloudflare-dns is a package dependsOn; the Record CRD schema comes from the provider package.

  Verified on colima against live SES + Cloudflare: 3 CNAMEs reconcile under SMTPSender, SES dkimVerificationStatus stays SUCCESS, 9/9 render tests, examples validate.

  Implements [[tasks/platform-outbound-mail]]

  * fix: existence-gate dependent MRs instead of readiness

  Gating a dependent MR's render on observed upstream .ready is destructive in function-go-templating: a transient upstream Ready=False (not a deletion) drops the dependent from desired state and Crossplane deletes the live MR. Worst case: AccessKey gated on user.ready with empty external-name -> delete+recreate rotates the SES SMTP password.

  Flip the 4 dependent-MR gates (AccessKey, UserPolicyAttachment, SecretVersion, ConfigurationSet) to gate on upstream id/arn existence instead. atProvider id/arn is sticky (upjet retains it across transient errors, which surface as Synced=False not Ready=False), so a Ready blip no longer un-renders; creation-ordering is preserved (still wait for the upstream to exist), keeping reconcile-error/circuit-breaker pressure low. Deletion-ordering Usages stay .ready-gated so they are not materialized before their by-resource is up.

  Verified: new render test 'unready-but-existing-upstreams-still-render-dependents' (10/10); colima install caused zero churn (AccessKey id unchanged, records intact). Implements [[tasks/smtp-sender-gating-hardening]].

  * docs: align cloudflare provider wording with dependsOn

  The spec.cloudflare description and the 400-cloudflare-dkim comment still said the provider was an operator-managed runtime dep 'intentionally not in the package dependsOn' (the earlier apiDependencies design). It was switched to a package dependsOn; update the wording to match. Addresses CodeRabbit review on PR #2.

  * test: assert providerConfigRef on all three DKIM records

  The cloudflare-dkim render test only asserted spec.providerConfigRef on the first record. The composition already renders it on all three (range loop); assert it on records 2 and 3 too for completeness. Addresses CodeRabbit review on PR #2.

  * fix: enforce unproxied DKIM records (remove proxied knob)

  DKIM CNAMEs must resolve to amazonses.com and must never be Cloudflare-proxied (proxying breaks DKIM verification). Drop spec.cloudflare.dkim.proxied and hard-code proxied: false in the Record render, removing a footgun with no valid non-default value. The field was new in this unreleased PR, so removal is non-breaking. Addresses CodeRabbit nitpick on PR #2.

  * fix: keep IAM AccessKey alive until SecretVersion is deleted

  The SecretVersion's secretStringSecretRef reads the AccessKey's connection secret. During teardown the AccessKey was deleted first; the connection secret vanished, the SecretVersion could no longer resolve its references, and its external delete failed (PutSecretValue with empty secret id -> 'Invalid name'). The delete-secret-version-before-secret Usage then wedged the Secret, hanging the e2e cascade cleanup for 45 min.

  Add a delete-secret-version-before-access-key Usage (of=AccessKey, by=SecretVersion) so the AccessKey and its connection secret outlive the SecretVersion. Mirrors how the observe-stack chains deletion-ordering Usages across every dependency.

  Verified on colima: a full create+delete cycle of a throwaway SMTPSender (pushCredentials enabled) tears down cleanly — SecretVersion deletes first, then AccessKey/Secret/User, zero stuck resources. Fixes the e2e cleanup failure on PR #2.


See full diff: [v0.2.0...v0.3.0](https://github.com/hops-ops/aws-smtp-sender/compare/v0.2.0...v0.3.0)

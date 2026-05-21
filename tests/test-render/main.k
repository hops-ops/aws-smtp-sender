import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_ready_conditions = [
    {type = "Ready", status = "True"},
    {type = "Synced", status = "True"}
]

_items = [
    # Minimal render creates only upstream resources; dependent AWS resources wait
    # for observed readiness to avoid IAM and connection-secret races.
    metav1alpha1.CompositionTest {
        metadata.name = "minimal-renders-aws-resources"
        spec = {
            compositionPath = "apis/smtpsenders/composition.yaml"
            xrdPath = "apis/smtpsenders/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = awsv1alpha1.SMTPSender {
                metadata.name = "ops"
                metadata.namespace = "default"
                spec = {
                    domain = "ops.com.ai"
                    clusterName = "pat-local"
                    region = "us-east-2"
                    managementPolicies = ["*"]
                }
            }
            assertResources = [
                {
                    apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                    kind = "EmailIdentity"
                    metadata.name = "ops"
                    metadata.annotations = {
                        "crossplane.io/external-name" = "ops.com.ai"
                    }
                    spec.forProvider.region = "us-east-2"
                    spec.forProvider.dkimSigningAttributes.nextSigningKeyLength = "RSA_2048_BIT"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "User"
                    metadata.name = "ops-smtp"
                    spec.forProvider.forceDestroy = True
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Policy"
                    metadata.name = "ops-smtp-send-email"
                    spec.forProvider.policy = """{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSendRawEmailForDomain",
      "Effect": "Allow",
      "Action": [
        "ses:SendRawEmail"
      ],
      "Resource": [
        "arn:aws:ses:us-east-2:*:identity/ops.com.ai"
      ]
    }
  ]
}
"""
                },
                {
                    apiVersion = "secretsmanager.aws.m.upbound.io/v1beta1"
                    kind = "Secret"
                    metadata.name = "ops-smtp"
                    spec.forProvider.name = "push/pat-local/ops-smtp"
                    spec.forProvider.tags = {
                        "hops.ops.com.ai/managed-by" = "mr"
                        "hops.ops.com.ai/secret" = "true"
                    }
                }
            ]
        }
    },

    # Custom names and account ID tighten the send policy and provider wiring.
    metav1alpha1.CompositionTest {
        metadata.name = "custom-names-and-account-id"
        spec = {
            compositionPath = "apis/smtpsenders/composition.yaml"
            xrdPath = "apis/smtpsenders/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "SMTPSender"
                metadata.name = "ops"
                metadata.namespace = "default"
                spec = {
                    domain = "ops.com.ai"
                    clusterName = "pat-local"
                    region = "us-east-2"
                    accountId = "034489662075"
                    managementPolicies = ["*"]
                    providerConfigRef = {
                        name = "aws-prod"
                        kind = "ProviderConfig"
                    }
                    iam = {
                        userName = "custom-smtp"
                    }
                    pushCredentials = {
                        path = "push/pat-local/custom-smtp"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "User"
                    metadata.name = "custom-smtp"
                    spec.providerConfigRef.name = "aws-prod"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Policy"
                    metadata.name = "custom-smtp-send-email"
                    spec.forProvider.policy = """{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSendRawEmailForDomain",
      "Effect": "Allow",
      "Action": [
        "ses:SendRawEmail"
      ],
      "Resource": [
        "arn:aws:ses:us-east-2:034489662075:identity/ops.com.ai"
      ]
    }
  ]
}
"""
                },
                {
                    apiVersion = "secretsmanager.aws.m.upbound.io/v1beta1"
                    kind = "Secret"
                    metadata.name = "ops-smtp"
                    spec.forProvider.name = "push/pat-local/custom-smtp"
                }
            ]
        }
    },

    # Disabling pushCredentials still creates the upstream IAM resources.
    metav1alpha1.CompositionTest {
        metadata.name = "push-credentials-disabled"
        spec = {
            compositionPath = "apis/smtpsenders/composition.yaml"
            xrdPath = "apis/smtpsenders/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = awsv1alpha1.SMTPSender {
                metadata.name = "ops"
                metadata.namespace = "default"
                spec = {
                    domain = "ops.com.ai"
                    clusterName = "pat-local"
                    region = "us-east-2"
                    managementPolicies = ["*"]
                    pushCredentials = {
                        enabled = False
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "User"
                    metadata.name = "ops-smtp"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Policy"
                    metadata.name = "ops-smtp-send-email"
                }
            ]
        }
    },

    # Dependent IAM and secret resources render only after upstreams are ready.
    metav1alpha1.CompositionTest {
        metadata.name = "ready-upstreams-render-dependent-resources"
        spec = {
            compositionPath = "apis/smtpsenders/composition.yaml"
            xrdPath = "apis/smtpsenders/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = awsv1alpha1.SMTPSender {
                metadata.name = "ops"
                metadata.namespace = "default"
                spec = {
                    domain = "ops.com.ai"
                    clusterName = "pat-local"
                    region = "us-east-2"
                    managementPolicies = ["*"]
                }
            }
            observedResources = [
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "User"
                    metadata.name = "ops-smtp"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-user"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.id = "ops-smtp"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Policy"
                    metadata.name = "ops-smtp-send-email"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-policy"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.arn = "arn:aws:iam::034489662075:policy/ops-smtp-send-email"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "AccessKey"
                    metadata.name = "ops-smtp-access-key"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-access-key"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.id = "AKIAIOSFODNN7EXAMPLE"
                },
                {
                    apiVersion = "secretsmanager.aws.m.upbound.io/v1beta1"
                    kind = "Secret"
                    metadata.name = "ops-smtp"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "secrets-manager-secret"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.arn = "arn:aws:secretsmanager:us-east-2:034489662075:secret:push/pat-local/ops-smtp-AbCdEf"
                }
            ]
            assertResources = [
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "AccessKey"
                    metadata.name = "ops-smtp-access-key"
                    spec.writeConnectionSecretToRef.name = "ops-smtp-access-key"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "UserPolicyAttachment"
                    metadata.name = "ops-smtp-policy"
                },
                {
                    apiVersion = "secretsmanager.aws.m.upbound.io/v1beta1"
                    kind = "SecretVersion"
                    metadata.name = "ops-smtp-version"
                    spec.forProvider.secretStringSecretRef = {
                        name = "ops-smtp-access-key"
                        key = "attribute.ses_smtp_password_v4"
                    }
                }
            ]
        }
    },

    # Enabling dedicatedIpPool renders the cost-bearing pool, but waits to
    # render the ConfigurationSet until the pool is observed ready.
    metav1alpha1.CompositionTest {
        metadata.name = "dedicated-ip-pool-enabled-renders-pool"
        spec = {
            compositionPath = "apis/smtpsenders/composition.yaml"
            xrdPath = "apis/smtpsenders/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "SMTPSender"
                metadata.name = "ops"
                metadata.namespace = "default"
                spec = {
                    domain = "ops.com.ai"
                    clusterName = "pat-local"
                    region = "us-east-2"
                    managementPolicies = ["*"]
                    dedicatedIpPool = {
                        enabled = True
                        name = "ops-marketing-pool"
                        externalName = "ops-marketing-pool"
                        scalingMode = "MANAGED"
                        tags = {
                            Purpose = "marketing-mail"
                        }
                    }
                    configurationSet = {
                        name = "ops-marketing-config"
                        externalName = "ops-marketing-config"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                    kind = "DedicatedIPPool"
                    metadata.name = "ops-marketing-pool"
                    metadata.annotations = {
                        "crossplane.io/external-name" = "ops-marketing-pool"
                    }
                    spec.forProvider = {
                        region = "us-east-2"
                        scalingMode = "MANAGED"
                        tags = {
                            Name = "ops-marketing-pool"
                            Purpose = "marketing-mail"
                        }
                    }
                }
            ]
        }
    },

    # Once the dedicated pool is ready, the ConfigurationSet can safely select it.
    metav1alpha1.CompositionTest {
        metadata.name = "ready-dedicated-ip-pool-renders-configuration-set"
        spec = {
            compositionPath = "apis/smtpsenders/composition.yaml"
            xrdPath = "apis/smtpsenders/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "SMTPSender"
                metadata.name = "ops"
                metadata.namespace = "default"
                spec = {
                    domain = "ops.com.ai"
                    clusterName = "pat-local"
                    region = "us-east-2"
                    managementPolicies = ["*"]
                    dedicatedIpPool = {
                        enabled = True
                        name = "ops-marketing-pool"
                        externalName = "ops-marketing-pool"
                        scalingMode = "MANAGED"
                    }
                    configurationSet = {
                        name = "ops-marketing-config"
                        externalName = "ops-marketing-config"
                        deliveryOptions = {
                            tlsPolicy = "OPTIONAL"
                            maxDeliverySeconds = 300
                        }
                        reputationMetricsEnabled = False
                        sendingEnabled = True
                        suppressionReasons = ["BOUNCE"]
                    }
                }
            }
            observedResources = [
                {
                    apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                    kind = "DedicatedIPPool"
                    metadata.name = "ops-marketing-pool"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "dedicated-ip-pool"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider = {
                        arn = "arn:aws:ses:us-east-2:034489662075:dedicated-ip-pool/ops-marketing-pool"
                        id = "ops-marketing-pool"
                        scalingMode = "MANAGED"
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                    kind = "ConfigurationSet"
                    metadata.name = "ops-marketing-config"
                    metadata.annotations = {
                        "crossplane.io/external-name" = "ops-marketing-config"
                    }
                    spec.forProvider = {
                        region = "us-east-2"
                        deliveryOptions = {
                            sendingPoolName = "ops-marketing-pool"
                            tlsPolicy = "OPTIONAL"
                            maxDeliverySeconds = 300
                        }
                        reputationOptions.reputationMetricsEnabled = False
                        sendingOptions.sendingEnabled = True
                        suppressionOptions.suppressedReasons = ["BOUNCE"]
                    }
                }
            ]
        }
    },

    # Dedicated pool status is typed, and Usage protects delete ordering.
    metav1alpha1.CompositionTest {
        metadata.name = "dedicated-ip-pool-status-and-usage"
        spec = {
            compositionPath = "apis/smtpsenders/composition.yaml"
            xrdPath = "apis/smtpsenders/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "SMTPSender"
                metadata.name = "ops"
                metadata.namespace = "default"
                spec = {
                    domain = "ops.com.ai"
                    clusterName = "pat-local"
                    region = "us-east-2"
                    managementPolicies = ["*"]
                    pushCredentials.enabled = False
                    dedicatedIpPool.enabled = True
                }
            }
            observedResources = [
                {
                    apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                    kind = "EmailIdentity"
                    metadata.name = "ops"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "email-identity"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.arn = "arn:aws:ses:us-east-2:034489662075:identity/ops.com.ai"
                },
                {
                    apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                    kind = "DedicatedIPPool"
                    metadata.name = "ops-smtp"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "dedicated-ip-pool"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider = {
                        arn = "arn:aws:ses:us-east-2:034489662075:dedicated-ip-pool/ops-smtp"
                        id = "ops-smtp"
                        scalingMode = "MANAGED"
                    }
                },
                {
                    apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                    kind = "ConfigurationSet"
                    metadata.name = "ops-smtp"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "configuration-set"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider = {
                        arn = "arn:aws:ses:us-east-2:034489662075:configuration-set/ops-smtp"
                        id = "ops-smtp"
                    }
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "User"
                    metadata.name = "ops-smtp"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-user"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.arn = "arn:aws:iam::034489662075:user/ops-smtp"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Policy"
                    metadata.name = "ops-smtp-send-email"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-policy"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.arn = "arn:aws:iam::034489662075:policy/ops-smtp-send-email"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "UserPolicyAttachment"
                    metadata.name = "ops-smtp-policy"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-policy-attachment"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.id = "ops-smtp/arn:aws:iam::034489662075:policy/ops-smtp-send-email"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "AccessKey"
                    metadata.name = "ops-smtp-access-key"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-access-key"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.id = "AKIAIOSFODNN7EXAMPLE"
                }
            ]
            assertResources = [
                {
                    apiVersion = "protection.crossplane.io/v1beta1"
                    kind = "Usage"
                    metadata.name = "ops-delete-configuration-set-before-dedicated-ip-pool"
                    spec = {
                        replayDeletion = True
                        of = {
                            apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                            kind = "DedicatedIPPool"
                            resourceRef.name = "ops-smtp"
                        }
                        by = {
                            apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                            kind = "ConfigurationSet"
                            resourceRef.name = "ops-smtp"
                        }
                    }
                },
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "SMTPSender"
                    metadata.name = "ops"
                    metadata.namespace = "default"
                    status = {
                        ready = True
                        ses = {
                            identityArn = "arn:aws:ses:us-east-2:034489662075:identity/ops.com.ai"
                            dedicatedIpPool = {
                                arn = "arn:aws:ses:us-east-2:034489662075:dedicated-ip-pool/ops-smtp"
                                name = "ops-smtp"
                                scalingMode = "MANAGED"
                            }
                            configurationSet = {
                                arn = "arn:aws:ses:us-east-2:034489662075:configuration-set/ops-smtp"
                                name = "ops-smtp"
                            }
                        }
                    }
                }
            ]
        }
    },

    # Observed provider state is normalized into the typed status contract.
    metav1alpha1.CompositionTest {
        metadata.name = "status-from-observed-resources"
        spec = {
            compositionPath = "apis/smtpsenders/composition.yaml"
            xrdPath = "apis/smtpsenders/definition.yaml"
            xrPath = "examples/smtpsenders/minimal.yaml"
            observedResources = [
                {
                    apiVersion = "sesv2.aws.m.upbound.io/v1beta1"
                    kind = "EmailIdentity"
                    metadata.name = "ops"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "email-identity"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider = {
                        arn = "arn:aws:ses:us-east-2:034489662075:identity/ops.com.ai"
                        verificationStatus = "SUCCESS"
                        verifiedForSendingStatus = True
                        dkimSigningAttributes = {
                            status = "SUCCESS"
                            tokens = [
                                "abcdefghijklmnopqrstu",
                                "vwxyzabcdefghijklmnop",
                                "qrstuvwxyzabcdefghijk"
                            ]
                        }
                    }
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "User"
                    metadata.name = "ops-smtp"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-user"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider = {
                        arn = "arn:aws:iam::034489662075:user/ops-smtp"
                        id = "ops-smtp"
                    }
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "Policy"
                    metadata.name = "ops-smtp-send-email"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-policy"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider = {
                        arn = "arn:aws:iam::034489662075:policy/ops-smtp-send-email"
                        id = "arn:aws:iam::034489662075:policy/ops-smtp-send-email"
                    }
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "UserPolicyAttachment"
                    metadata.name = "ops-smtp-policy"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-policy-attachment"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.id = "ops-smtp/arn:aws:iam::034489662075:policy/ops-smtp-send-email"
                },
                {
                    apiVersion = "iam.aws.m.upbound.io/v1beta1"
                    kind = "AccessKey"
                    metadata.name = "ops-smtp-access-key"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "iam-access-key"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.id = "AKIAIOSFODNN7EXAMPLE"
                },
                {
                    apiVersion = "secretsmanager.aws.m.upbound.io/v1beta1"
                    kind = "Secret"
                    metadata.name = "ops-smtp"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "secrets-manager-secret"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider = {
                        arn = "arn:aws:secretsmanager:us-east-2:034489662075:secret:push/pat-local/ops-smtp-AbCdEf"
                        id = "arn:aws:secretsmanager:us-east-2:034489662075:secret:push/pat-local/ops-smtp-AbCdEf"
                    }
                },
                {
                    apiVersion = "secretsmanager.aws.m.upbound.io/v1beta1"
                    kind = "SecretVersion"
                    metadata.name = "ops-smtp-version"
                    metadata.annotations = {
                        "crossplane.io/composition-resource-name" = "secrets-manager-secret-version"
                    }
                    status.conditions = _ready_conditions
                    status.atProvider.id = "arn:aws:secretsmanager:us-east-2:034489662075:secret:push/pat-local/ops-smtp-AbCdEf|01234567-89ab-cdef-0123-456789abcdef"
                }
            ]
            timeoutSeconds = 60
            validate = False
            assertResources = [
                {
                    apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                    kind = "SMTPSender"
                    metadata.name = "ops"
                    metadata.namespace = "default"
                    status = {
                        ready = True
                        smtp = {
                            host = "email-smtp.us-east-2.amazonaws.com"
                            port = 587
                            username = "AKIAIOSFODNN7EXAMPLE"
                            awsSecretsManagerPath = "push/pat-local/ops-smtp"
                        }
                        dkim = {
                            verified = True
                            verificationStatus = "SUCCESS"
                            status = "SUCCESS"
                            tokens = [
                                "abcdefghijklmnopqrstu",
                                "vwxyzabcdefghijklmnop",
                                "qrstuvwxyzabcdefghijk"
                            ]
                        }
                        iam = {
                            userArn = "arn:aws:iam::034489662075:user/ops-smtp"
                            policyArn = "arn:aws:iam::034489662075:policy/ops-smtp-send-email"
                        }
                        ses.identityArn = "arn:aws:ses:us-east-2:034489662075:identity/ops.com.ai"
                        secret.arn = "arn:aws:secretsmanager:us-east-2:034489662075:secret:push/pat-local/ops-smtp-AbCdEf"
                    }
                }
            ]
        }
    }
]
items = _items

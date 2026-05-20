# e2etest-smtpsender - AWS SMTPSender E2E Test
# ====================================================
# Creates a unique SES identity, IAM SMTP user/access key, and AWS Secrets
# Manager secret on each run. This XR is not one-per-account, so the E2E test
# can use full lifecycle management instead of orphan/import mode.

import base64
import datetime
import file
import math
import models.ai.com.ops.hops.aws.v1alpha1 as awsv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_now = str(int(math.floor(datetime.ticks())))

_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

_namespace = "default"
_region = file.read("env/AWS_REGION").strip()
_account_id = file.read("env/AWS_ACCOUNT_ID").strip()

_test_name = "e2e-smtp-" + _now
_domain = _test_name + ".ops.com.ai"
_user_name = _test_name + "-user"
_secret_path = "e2e/smtp-sender/" + _test_name

_items = [
    metav1alpha1.E2ETest {
        metadata.name = "smtpsender-e2e"
        spec = {
            crossplane = {
                autoUpgrade.channel = "Rapid"
            }
            defaultConditions = ["Ready"]
            timeoutSeconds = 1800
            cleanupTimeoutSeconds = 1800
            skipDelete = False

            extraResources = [
                {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "aws-creds"
                        namespace = _namespace
                    }
                    type = "Opaque"
                    data.creds = _base64_creds
                }
                {
                    apiVersion = "aws.m.upbound.io/v1beta1"
                    kind = "ProviderConfig"
                    metadata = {
                        name = "default"
                        namespace = _namespace
                    }
                    spec.credentials = {
                        source = "Secret"
                        secretRef = {
                            namespace = _namespace
                            name = "aws-creds"
                            key = "creds"
                        }
                    }
                }
            ]

            manifests = [
                awsv1alpha1.SMTPSender {
                    metadata = {
                        name = _test_name
                        namespace = _namespace
                    }
                    spec = {
                        domain = _domain
                        clusterName = "e2e-smtp"
                        region = _region
                        accountId = _account_id
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            name = "default"
                            kind = "ProviderConfig"
                        }
                        iam = {
                            userName = _user_name
                        }
                        pushCredentials = {
                            enabled = True
                            path = _secret_path
                        }
                        tags = {
                            "hops.ops.com.ai/e2e" = "true"
                            "hops.ops.com.ai/test-run" = _now
                            "hops.ops.com.ai/test-repo" = "https://github.com/hops-ops/aws-smtp-sender"
                        }
                    }
                }
            ]
        }
    }
]

items = _items

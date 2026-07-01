# ECR Setup & OIDC IAM Role

This document covers the one-time AWS infrastructure needed for the
`build` and `container-scan` pipeline stages.

---

## 1. Create the ECR repository

```bash
aws ecr create-repository \
  --repository-name devsecops-cicd-pipeline \
  --image-scanning-configuration scanOnPush=true \
  --image-tag-mutability IMMUTABLE \
  --region us-gov-west-1
```

Enable tag immutability so pushed digests can never be overwritten.

---

## 2. Create the GitHub OIDC identity provider

This is a **one-time per-account** step.

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

> **GovCloud note:** use `sts.us-gov-west-1.amazonaws.com` as the audience
> if your account restricts the commercial STS endpoint.

---

## 3. Create the IAM role

### Trust policy (`trust.json`)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws-us-gov:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Corrierethan/devsecops-cicd-pipeline:*"
        }
      }
    }
  ]
}
```

### Permission policy (`permissions.json`)

Least-privilege: ECR auth + push to the single repository only.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "arn:aws-us-gov:ecr:us-gov-west-1:ACCOUNT_ID:repository/devsecops-cicd-pipeline"
    }
  ]
}
```

```bash
aws iam create-role \
  --role-name github-actions-devsecops-cicd \
  --assume-role-policy-document file://trust.json

aws iam put-role-policy \
  --role-name github-actions-devsecops-cicd \
  --policy-name ecr-push \
  --policy-document file://permissions.json
```

---

## 4. Add GitHub repository secrets / variables

| Type | Name | Value |
|------|------|-------|
| Secret | `AWS_ROLE_ARN` | `arn:aws-us-gov:iam::ACCOUNT_ID:role/github-actions-devsecops-cicd` |
| Variable | `AWS_REGION` | `us-gov-west-1` *(or omit to use workflow default)* |
| Variable | `ECR_REPOSITORY` | `devsecops-cicd-pipeline` *(or omit to use workflow default)* |

```bash
gh secret set AWS_ROLE_ARN --body "arn:aws-us-gov:iam::ACCOUNT_ID:role/github-actions-devsecops-cicd"
gh variable set AWS_REGION  --body "us-gov-west-1"
gh variable set ECR_REPOSITORY --body "devsecops-cicd-pipeline"
```

---

## 5. Verify

Push to `main` or open a PR from the same repo. The `build` job should:

1. Authenticate to AWS via OIDC (no static keys).
2. Push two tags: `<commit-sha>` and `latest`.
3. Output the immutable image digest for downstream `container-scan` and
   `sign` stages.

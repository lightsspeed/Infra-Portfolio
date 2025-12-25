# Portfolio Infrastructure

Terraform configuration for hosting a static portfolio website on AWS using S3, CloudFront, ACM, and Route 53.

## Architecture

- **S3**: Storage for static site content
- **CloudFront**: CDN with Origin Access Control (OAC)
- **ACM**: SSL/TLS certificates
- **Route 53**: DNS management
- **CloudWatch**: Monitoring and alarms
- **CloudFront Functions**: Security headers and clean URLs

## Architecture Diagram

<div align="center">

![Portfolio Infrastructure Architecture](https://raw.githubusercontent.com/lightsspeed/Infra-Portfolio/Assets/Infra-Portfolio.png)

*AWS static site hosting: S3 (private) + CloudFront CDN + Route53 custom domain + ACM HTTPS + CloudWatch monitoring*

</div>

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS Account with appropriate permissions
- Domain name registered (can be outside AWS)
- Route 53 Hosted Zone for your domain

## File Structure

```
.
├── providers.tf              # Provider configuration
├── variables.tf              # Input variables
├── locals.tf                 # Local values
├── data.tf                   # Data sources
├── s3.tf                     # S3 buckets and policies
├── cloudfront.tf             # CloudFront distributions
├── cloudfront-functions.tf   # CloudFront Functions
├── acm.tf                    # SSL certificates
├── route53.tf                # DNS records
├── cloudwatch.tf             # Monitoring alarms
├── outputs.tf                # Output values
└── terraform.tfvars.example  # Example configuration
```

## Setup

### 1. Create Route 53 Hosted Zone

If you don't have a hosted zone yet:

```bash
aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)
```

Update your domain registrar's nameservers with the Route 53 nameservers.

### 2. Configure Variables

Copy the example file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
domain_name  = "yourdomain.com"
www_redirect = true
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan and Apply

```bash
terraform plan
terraform apply
```

The apply will take ~15-30 minutes due to:

- ACM certificate DNS validation
- CloudFront distribution deployment

### 5. Update Domain Nameservers

If not already done, update your domain registrar with the Route 53 nameservers:

```bash
terraform output nameservers
```

## Deployment

After infrastructure is ready, deploy your site content:

```bash
# Get bucket name
BUCKET=$(terraform output -raw s3_bucket_name)

# Sync your site files
aws s3 sync ../portfolio-site/ s3://$BUCKET/ --delete

# Invalidate CloudFront cache
DISTRIBUTION=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION --paths "/*"
```

## Features

### Clean URLs

The CloudFront Function automatically handles:

- `/about` → `/about.html`
- `/blog/` → `/blog/index.html`

### Security Headers

Automatically adds:

- `Strict-Transport-Security`
- `X-Content-Type-Options`
- `X-Frame-Options`
- `X-XSS-Protection`
- `Referrer-Policy`

### WWW Redirect

Configure `www_redirect` variable:

- `true`: www.example.com → example.com
- `false`: example.com → www.example.com

### Monitoring

CloudWatch alarms for:

- 4xx error rate > 10%
- 5xx error rate > 5%

## Cost Estimate

Monthly costs (approximate):

- Route 53 Hosted Zone: $0.50
- S3 Storage: $0.023/GB
- CloudFront: $0.085/GB (first 10TB)
- CloudFront Requests: $0.01 per 10,000 requests
- ACM Certificate: Free

Typical small portfolio: **$1-5/month**

## Outputs

After apply:

```bash
terraform output cloudfront_distribution_id  # For cache invalidation
terraform output s3_bucket_name              # For content upload
terraform output primary_domain              # Your main domain
terraform output cloudfront_domain_name      # CloudFront URL
```

## Maintenance

### Update Site Content

```bash
# Via AWS CLI
aws s3 sync ./site/ s3://$(terraform output -raw s3_bucket_name)/ --delete

# Invalidate cache
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

### View Logs

CloudFront logs are stored in the logs bucket:

```bash
aws s3 ls s3://$(terraform output -raw s3_bucket_name)-logs/cloudfront/
```

### Destroy Infrastructure

```bash
# Empty S3 buckets first
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive
aws s3 rm s3://$(terraform output -raw s3_bucket_name)-logs --recursive

# Destroy infrastructure
terraform destroy
```

## Troubleshooting

### ACM Certificate Stuck on "Pending Validation"

Check that:

1. Route 53 hosted zone exists
2. Domain nameservers point to Route 53
3. DNS propagation completed (can take 24-48 hours)

### 403 Error on CloudFront

1. Check S3 bucket policy allows CloudFront OAC
2. Verify files exist in S3
3. Check CloudFront origin configuration

### CloudFront Not Serving Updated Content

Create cache invalidation:

```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR_DIST_ID \
  --paths "/*"
```

## GitHub Actions

See the `.github/workflows/` directory for:

- `terraform.yml`: Infrastructure automation
- Deploy workflow configuration in the site repository

## License

MIT

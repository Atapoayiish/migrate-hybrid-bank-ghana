# RUNBOOK - Step 0 to Finish
Project: migrate-hybrid-bank-ghana | Independent, no hotel

## STEP 0 - Prerequisites (15 min)
1. AWS Account + IAM user with AdministratorAccess for demo
2. Install: aws, terraform, git, kubectl - check with `aws --version`, `terraform --version`
3. `aws configure` - region `eu-west-1`
4. Create GitHub repo: `migrate-hybrid-bank-ghana`
5. Clone it locally and copy all files from this scaffold into it

## STEP 1 - Understand the Files (5 min)
- `main.tf` = VPC, VPN Gateway, Customer Gateway, VPN Connection (2 tunnels), EKS, ALB, RDS, KMS, Secrets
- `variables.tf` = change your name prefix, region, CIDRs
- Do NOT change CIDRs unless you know why: AWS 10.1.0.0/16 must NOT overlap on-prem 192.168.0.0/16

## STEP 2 - Init (2 min)
terraform init
terraform fmt -recursive
terraform validate

## STEP 3 - Plan (2 min)
terraform plan -out=tfplan

## STEP 4 - Apply (15-20 min, EKS is slow)
terraform apply tfplan
terraform output

## STEP 5 - Demo / Verify (10 min)
1. AWS Console > VPC > Site-to-Site VPN > Check Tunnel 1 / Tunnel 2
2. Get ALB DNS: terraform output alb_dns_name
   curl http://<ALB_DNS>/health
   Expect: {"status":"ok","service":"bank-mobile-api","mode":"hybrid"}
3. Check EKS:
   aws eks update-kubeconfig --region eu-west-1 --name bank-mobile-eks
   kubectl get nodes
   kubectl get pods -A
4. Check private routing: VPC Route Tables > Private RT should have 192.168.0.0/16 -> VGW

### STEP 5b - Real On-Prem Side (interview explanation)
In real life, your network team takes VPN config from AWS Console > Download Configuration and applies it to on-prem router in Accra. Until then tunnels may show DOWN - EXPECTED in simulation. We simulate on-prem with Customer Gateway + 192.168.0.0/16 route.

## STEP 6 - Screenshot / LinkedIn Proof (5 min)
Screenshots: VPC, VPN tunnels, ALB health 200, terraform output

## STEP 7 - Push to GitHub
git add .
git commit -m "feat: hybrid bank Ghana - VPN + EKS + RDS, core stays on-prem"
git branch -M main
git push -u origin main

## STEP 8 - Destroy (MUST DO)
terraform destroy -auto-approve
Verify in console: VPC, EKS, RDS, VPN all gone

## STEP 9 - Next Project
Do NOT reuse this VPC for Project 03. Each project = fresh repo, fresh VPC, fresh destroy.

## Troubleshooting
- EKS timeout: wait, re-run terraform apply
- VPN DOWN: expected without real on-prem router
- ALB 503: pods not ready, wait 2 min

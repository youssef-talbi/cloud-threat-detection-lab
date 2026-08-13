# 🛡️ Cloud Threat Detection Lab

> An AWS-native threat detection and automated incident response environment —  
> built progressively from manual console setup to fully automated Infrastructure as Code.

---

## 🎯 What This Project Does

This lab simulates a real cloud attack scenario: an adversary performing reconnaissance  
and brute-force attacks against an EC2 instance inside a private subnet.

The system detects the attack using AWS-native security services and — in its final form —  
automatically isolates the compromised instance in **under 30 seconds**, with no human intervention.

The entire environment is defined as code and deploys with a single `terraform apply`.

---

## 🚀 Deploy It Yourself

**Prerequisites:** an AWS account you control, [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5, [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws configure`), and an SSH key pair.

```bash
git clone https://github.com/youssef-talbi/cloud-threat-detection-lab.git
cd cloud-threat-detection-lab/terraform

# 1. Copy the example vars file and fill in YOUR values
cp terraform.tfvars.example terraform.tfvars
#    operator_ip     = "YOUR.PUBLIC.IP/32"   (get it from https://whatismyip.com)
#    alert_email     = "you@example.com"
#    public_key_path = "~/.ssh/id_rsa.pub"

# 2. Deploy
terraform init
terraform plan
terraform apply
```

**After `apply`:**
1. **Confirm the SNS subscription** — AWS emails you a link. Click it, or you'll receive no alerts. *(Manual by design; AWS does not allow auto-confirmation.)*
2. SSH into the attacker box (its public IP is in the `terraform output`).
3. Run attacks against the victim's private IP:
   ```bash
   nmap -p 1-1000 -A -Pn <victim_private_ip>
   for i in {1..200}; do (nc -w 1 <victim_private_ip> 22 2>/dev/null &); done
   ```
4. GuardDuty raises a finding → EventBridge fires the Lambda → the victim's Security Group is swapped to `isolated-sg` → you receive a `[HIGH]` alert email.

**Clean up:** `terraform destroy`

> ⚠️ **Notes:** `terraform.tfvars` and all `*.tfstate` files are **gitignored** — never commit them. This lab provisions **vulnerable-by-design** targets; deploy **only** in an isolated AWS account you control. GuardDuty deduplicates repeated findings on the same attacker→victim pair — on a fresh account the first attack triggers immediately.

---

## 🏗️ Engineering Evolution: Manual → Automated → IaC

This project was deliberately built in 3 progressive phases.  
Each phase solves a limitation left by the previous one.  
This mirrors how security infrastructure matures in real cloud environments.

---

### 🔹 Phase 1 — Manual Infrastructure & Detection ✅ `COMPLETE`

**The problem this phase addresses:**  
Before automating anything, every component must be understood at the lowest level.

**What was built manually:**
- Custom VPC (`10.0.0.0/16`) with isolated public and private subnets
- Two EC2 instances: `attacker-box` (public subnet) and `victim-server` (private subnet)
- Security Groups enforcing least-privilege: victim accessible only from attacker subnet
- CloudTrail logging all API calls across the account
- VPC Flow Logs streaming all network traffic to CloudWatch
- Amazon GuardDuty analyzing CloudTrail + Flow Logs + DNS in real time

**Attack simulations executed:**
- Nmap aggressive scan (`-A -v -Pn`) from attacker to victim → GuardDuty raised `Recon:EC2/Portscan` (Medium)
- Hydra SSH brute-force → victim correctly rejected password auth — SSH hardening confirmed
- Netcat flood (200 concurrent TCP connections to port 22) → GuardDuty raised `UnauthorizedAccess:EC2/SSHBruteForce` (**High**)
- Root credential API usage → GuardDuty raised `Policy:IAMUser/RootCredentialUsage` (Low)

**Phase 1 limitation:**  
GuardDuty detects threats but does nothing automatically.  
A real attack at 3 AM would go unnoticed until someone manually checks the console.

→ [Full Phase 1 Documentation & Evidence](docs/phase1-manual-setup.md)

---

### 🔹 Phase 2 — Serverless Automated Response ✅ `COMPLETE`

**The problem this phase addresses:**
Manual detection without automated response is not enough. A real attack at 3 AM would go unnoticed until an engineer logs in.

**What was built:**
- Amazon EventBridge rule capturing every GuardDuty finding in real time
- AWS Lambda (Python/Boto3) automatically replacing the compromised instance's Security Group with `isolated-sg` (zero inbound, zero outbound)
- Amazon SNS delivering a structured email alert to the operator instantly
- IAM Role with least-privilege permissions scoped only to EC2 and SNS actions

**Real results confirmed:**
- GuardDuty High severity finding (`UnauthorizedAccess:EC2/SSHBruteForce`) triggered the full pipeline
- `victim-server` isolated automatically — Security Group swapped to `isolated-sg`
- Email alert received at **2026-07-05 14:04:32 UTC** with full finding details
- **Time from detection to isolation: under 30 seconds**

→ [Full Phase 2 Documentation & Evidence](docs/phase2-automated-response.md)

---

### 🔹 Phase 3 — Infrastructure as Code & CI/CD ✅ `COMPLETE`

**The problem this phase addresses:**  
Manual setup is not reproducible and not reviewable by a team.

**What was built:**
- Full Terraform refactor of all Phase 1 + Phase 2 infrastructure — 30 resources across 8 files split by concern
- Existing GuardDuty detector adopted into Terraform state via `terraform import` (real IaC adoption, no history lost)
- GitHub Actions CI/CD pipeline running `terraform fmt`, `validate`, and a `tfsec` security scan on every change to `terraform/`
- Secrets (`terraform.tfvars`, state files) excluded from version control via `.gitignore`

**Real results confirmed:**
- Entire lab provisioned from a single `terraform apply` — `30 added, 0 changed, 0 destroyed`
- Every resource carries the `ManagedBy: Terraform` tag in the AWS Console
- Detection-and-response pipeline re-validated end to end: victim isolated (`victim-sg → isolated-sg`) with a `[HIGH]` alert email in under one second

→ [Full Phase 3 Documentation & Evidence](docs/phase3-terraform-cicd.md)

---

## 🏛️ Architecture


![Architecture Diagram](docs/architecture-diagram.png)

---

## 🛠️ Technologies

| Category | Tools |
|----------|-------|
| Cloud Infrastructure | AWS VPC, EC2, Subnets, Security Groups, Route Tables |
| Threat Detection | Amazon GuardDuty, CloudTrail, VPC Flow Logs, CloudWatch |
| Automated Response | AWS Lambda (Python), Amazon EventBridge, Amazon SNS |
| Infrastructure as Code | Terraform, tfsec |
| CI/CD | GitHub Actions |
| Attack Simulation | Nmap, Hydra |

---

## 📂 Repository Structure

```
cloud-threat-detection-lab/
├── README.md                              ← You are here
├── docs/
│   ├── architecture-diagram.png           ← Full 3-phase architecture diagram
│   ├── Phase1-Architecture-Overview.png   ← Phase 1 network layout
│   ├── phase1-manual-setup.md             ← Phase 1 documentation + evidence
│   ├── phase2-automated-response.md       ← Phase 2 documentation + evidence
│   └── evidence/
│       ├── 01-vpc-created.png
│       ├── 02-ec2-instances-running.png
│       ├── 03-attacker-box-details.png
│       ├── 04-victim-server-details.png
│       ├── 05-nmap-scan-terminal.png
│       ├── 06-guardduty-findings.png
│       ├── 07-vpc-flowlogs-enabled.png
│       ├── 08-victim-sg-rules.png
│       ├── 09-attacker-sg-rules.png
│       ├── 10-cloudwatch-flowlogs.png
│       ├── 11-hydra-brute-force.png
│       ├── 12-nc-flood-terminal.png
│       ├── 13-guardduty-4-findings.png
│       ├── 14-lambda-function-overview.png
│       ├── 15-lambda-code.png
│       ├── 16-lambda-env-variables.png
│       ├── 17-eventbridge-rule-pattern.png
│       ├── 18-eventbridge-target-lambda.png
│       ├── 19-iam-role-permissions.png
│       ├── 20-sns-topic-subscription.png
│       ├── 21-guardduty-finding-triggered.png
│       ├── 22-cloudwatch-lambda-execution.png
│       ├── 23-ec2-isolated-sg-applied.png
│       └── 24-email-alert-received.png
├── lambda/
│   └── incident_responder.py              ← Phase 2: Python isolation function
├── terraform/                             ← Phase 3: Infrastructure as Code (main, vpc, security, compute, detection, response, outputs)
├── terraform.tfvars.example               ← Template for your own values (real tfvars is gitignored)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── .github/
    └── workflows/
        └── tf-security-cicd.yml           ← Phase 3: CI/CD pipeline
```

---

## ⚡ Key Results

| Phase | Milestone | Status |
|-------|-----------|--------|
| Phase 1 | VPC + EC2 + GuardDuty operational | ✅ Complete |
| Phase 1 | Nmap scan detected — `Recon:EC2/Portscan` (Medium) | ✅ Confirmed |
| Phase 1 | SSH brute force detected — `UnauthorizedAccess:EC2/SSHBruteForce` (**High**) | ✅ Confirmed |
| Phase 1 | SSH hardening validated — password auth correctly rejected by victim | ✅ Confirmed |
| Phase 1 | Root credential usage detected — `Policy:IAMUser/RootCredentialUsage` (Low) | ✅ Confirmed |
| Phase 1 | VPC Flow Logs capturing all traffic in CloudWatch | ✅ Confirmed |
| Phase 2 | EventBridge → Lambda pipeline operational | ✅ Confirmed |
| Phase 2 | victim-server isolated automatically via isolated-sg | ✅ Confirmed |
| Phase 2 | SNS email alert received — 2026-07-05 14:04:32 UTC | ✅ Confirmed |
| Phase 2 | Time from detection to isolation — under 30 seconds | ✅ Confirmed |
| Phase 3 | Full lab provisioned from a single `terraform apply` (30 resources) | ✅ Confirmed |
| Phase 3 | Existing GuardDuty imported into Terraform state | ✅ Confirmed |
| Phase 3 | GitHub Actions CI/CD with tfsec security scanning | ✅ Confirmed |
| Phase 3 | Automated isolation re-validated on IaC-built infra | ✅ Confirmed |

---

## 👤 Author

**Youssef Talbi**  
Cloud Security Engineering Student — TEK-UP University (2027)  
RHCSA · eJPTv2 · AWS Solutions Architect Associate  

[LinkedIn](https://linkedin.com/in/talbi-youssef) · [GitHub](https://github.com/youssef-talbi)
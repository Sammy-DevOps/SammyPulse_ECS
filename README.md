# SammyPulse ECS

SammyPulse is my deployment of Gatus, an open-source monitoring application that checks if services are available and healthy.

I deployed it on AWS ECS Fargate using Docker, Terraform, HTTPS, monitoring and CI/CD through GitHub Actions.

## Architecture

![SammyPulse Architecture](assets/screenshots/sammypulsediagram.png)

**Traffic:** User → Route 53 → HTTPS/ALB → ECS Fargate → SammyPulse

The ALB is the public entry point. ECS tasks sit behind it and only accept application traffic from the ALB.

## Repository Structure

```text
SammyPulse_ECS/
├── .github/workflows/    # Application and Terraform pipelines
├── app/                  # Gatus application and Dockerfile
├── assets/screenshots/   # Project evidence
├── infra/                # Terraform infrastructure
├── LICENSE
└── README.md
```

## Local Setup

Clone the repository:

```bash
git clone https://github.com/Sammy-DevOps/SammyPulse_ECS.git
cd SammyPulse_ECS
```

Build and run SammyPulse:

```bash
docker build -t sammypulse:local ./app
docker run --rm -d --name sammypulse -p 8080:8080 sammypulse:local
```

Check the application:

```bash
curl http://localhost:8080/health
# {"status":"UP"}
```

## Engineering Decisions

| Decision | Why |
|---|---|
| **ECS Fargate** | Run containers without managing EC2 servers. |
| **ALB → ECS** | One public entry point while tasks stay behind the ALB. |
| **Security Groups** | Port `8080` only accepts traffic from the ALB. |
| **Terraform modules** | Separate network, ALB, ECR and ECS infrastructure. |
| **S3 state** | Laptop and CI use the same Terraform record. |
| **Git SHA tags** | Trace a deployed image back to its code. |
| **GitHub OIDC** | Temporary AWS access without storing permanent keys. |
| **SSM Parameter Store** | Keep the Discord webhook outside the code and image. |

## Docker & AWS

Gatus is containerised using a multi-stage Dockerfile and images are stored in a private ECR repository.

SammyPulse runs in `eu-west-2` across two public subnets. Route 53 handles DNS, ACM provides HTTPS and CloudWatch receives application logs.

## Terraform

I deployed the infrastructure manually first, then moved it into Terraform modules.

Terraform state is stored in S3 so my laptop and GitHub Actions share the same record of what Terraform manages. Before applying changes, I check the Terraform plan to see what will be added, changed or removed.

## CI/CD

GitHub Actions handles application and infrastructure changes.

The application pipeline builds the image, tags it with the Git commit SHA, pushes it to ECR, updates ECS, waits for the service to stabilise and checks `/health`.

A separate workflow checks and applies Terraform changes. Both use OIDC to access AWS without long-lived AWS keys.

## Reliability Testing

I stopped the running ECS task to test recovery. ECS replaced it and returned the service to its desired state.

I also forced a monitored endpoint to fail. SammyPulse detected it, sent a Discord alert and CloudWatch provided the container logs for investigation.

## Troubleshooting

### ALB target unhealthy

The ECS task was running but the ALB target stayed unhealthy.

I traced traffic from the ALB to the task and found the ECS security group was blocking port `8080`. I allowed `8080` only from the ALB security group and checked again. The target became healthy.

### Terraform wanted to create 20 existing resources

Terraform on my laptop showed no changes, but GitHub Actions wanted to create 20 resources that already existed.

I compared both environments and found GitHub Actions was not using the Terraform state in S3, so it did not know Terraform already managed those resources.

After fixing the state setup, the next error showed the pipeline could not read some load balancer and IAM role details. I followed the errors and added only the permissions it needed. The next run passed.

I did not apply the original plan because the 20 unexpected resources showed the pipeline was not seeing what I expected.

## Application Credit

Gatus was created by [TwiN](https://github.com/TwiN/gatus).

My work covers the container deployment, AWS infrastructure, Terraform, security, CI/CD, monitoring, reliability testing and troubleshooting.

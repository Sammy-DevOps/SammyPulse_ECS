# SammyPulse ECS

SammyPulse is a monitoring application deployed on AWS ECS Fargate. It uses Gatus to check whether services are available and healthy.

The deployment uses Docker, AWS, Terraform, HTTPS, monitoring and automated application deployments through GitHub Actions.

## Tech Stack

<p align="left">
  <img src="https://skillicons.dev/icons?i=aws,docker,terraform,githubactions,go,git" />
</p>

**AWS:** ECS Fargate · ECR · ALB · Route 53 · ACM · CloudWatch · SSM · IAM

## Architecture

![SammyPulse Architecture](assets/screenshots/sammypulsediagram.png)

## Local Setup

Clone the repository:

```bash
git clone git@github.com:Sammy-DevOps/SammyPulse_ECS.git
cd SammyPulse_ECS
```

Build the Docker image:

```bash
docker build -t sammypulse:local ./app
```

Run the container:

```bash
docker run --rm -d \
  --name sammypulse \
  -p 8080:8080 \
  sammypulse:local
```

Check the health endpoint:

```bash
curl http://localhost:8080/health
```

Expected response:

```json
{"status":"UP"}
```

## Docker and ECR

Gatus is containerised using a multi-stage Dockerfile. The application is built in a Go image and the final container runs as a non-root user.

The image is stored in a private Amazon ECR repository.

During the first ECR image scan, vulnerabilities were found in Alpine packages. I updated the affected packages, rebuilt the image and tested it again before pushing the new image to ECR.

## AWS Infrastructure

SammyPulse runs on ECS Fargate in `eu-west-2` across two public subnets.

The main AWS resources are:

- VPC and two public subnets
- Application Load Balancer
- ECS Fargate
- Amazon ECR
- Route 53 and ACM
- CloudWatch
- IAM roles and security groups
- SSM Parameter Store

The ALB is the public entry point. The ECS tasks run behind it and only accept application traffic on port `8080` from the ALB security group.

## Terraform

I first deployed the AWS resources manually and then recreated the infrastructure using Terraform.

The Terraform configuration is split into modules:

```text
infra/
├── modules/
│   ├── alb/
│   ├── ecr/
│   ├── ecs/
│   └── network/
├── main.tf
├── providers.tf
├── variables.tf
└── outputs.tf
```

Before making infrastructure changes, I run:

```bash
cd infra
terraform init
terraform validate
terraform plan
```

I review the Terraform plan before applying changes so I can see exactly what Terraform intends to create, update or remove.

## Application CI/CD

Application deployments are automated using GitHub Actions.

When application changes are pushed to `main`, the workflow:

1. Connects to AWS using OIDC
2. Builds the Docker image
3. Tags it with the Git commit SHA
4. Pushes it to ECR
5. Registers a new ECS task definition
6. Updates the ECS service
7. Waits for the service to become stable
8. Checks the live `/health` endpoint

OIDC allows GitHub Actions to access AWS without storing long-lived AWS access keys in GitHub.

## Monitoring and Secrets

Application logs are sent from ECS to CloudWatch.

The Discord webhook used by Gatus is stored in SSM Parameter Store rather than inside the repository or Docker image. The ECS task retrieves the value at runtime using its IAM role.

## Troubleshooting

### ALB Target Unhealthy

The ECS task was running, but the ALB target remained unhealthy.

I traced the traffic from the ALB to the ECS task and found that the ECS security group was blocking traffic on port `8080`.

I changed the rule so port `8080` only accepts traffic from the ALB security group. The target then passed its health checks and became healthy.

### ECR Image Scan

The first ECR image scan reported vulnerabilities linked to Alpine packages.

I updated the affected packages in the Dockerfile, rebuilt the image, tested the container and pushed the updated image to ECR.

## Repository Structure

```text
SammyPulse_ECS/
├── .github/
│   └── workflows/
├── app/
├── assets/
│   └── screenshots/
├── infra/
├── LICENSE
└── README.md
```

`app/` contains the Gatus source, Dockerfile and ECS task definition. `infra/` contains the Terraform configuration. `.github/workflows/` contains the deployment workflow.

## Application Credit

Gatus was created by [TwiN](https://github.com/TwiN/gatus).

My work in this repository covers the container deployment, AWS infrastructure, Terraform, security, CI/CD, monitoring and troubleshooting.

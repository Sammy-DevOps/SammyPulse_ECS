# SammyPulse ECS

SammyPulse is my deployment of Gatus, an open-source app that monitors endpoints and reports when something goes down. It runs in Docker on AWS ECS Fargate. Terraform manages the AWS infrastructure and GitHub Actions handles deployments.

I wanted to keep the setup simple while still thinking about security, reliability and what happens when things fail.

## Live Demo

🌐 **[View SammyPulse](https://status.sammypulse.co.uk)**

![SammyPulse live demo](assets/screenshots/sammypulse-demo.gif)

## Architecture

![SammyPulse Architecture](assets/screenshots/sammypulse-architecture.png)

**User → Route 53 → HTTPS/ALB → ECS Fargate → SammyPulse**

The ALB is the public entry point and sends traffic to the ECS task on port `8080`. That port only accepts traffic from the ALB security group, so the task isn't directly open to internet traffic. Route 53 handles the domain and ACM provides HTTPS.

## Run Locally

```bash
git clone https://github.com/Sammy-DevOps/SammyPulse_ECS.git
cd SammyPulse_ECS

docker build -t sammypulse:local ./app
docker run --rm -d --name sammypulse -p 8080:8080 sammypulse:local

curl http://localhost:8080/health
# {"status":"UP"}
```

## AWS Setup

SammyPulse runs as one Fargate task across two public subnets with no NAT gateway. I kept it this way to keep the setup and cost smaller. The downside is that the task needs a public IP for outbound access. With only one task there can also be a short gap while ECS replaces it.

The public IP made the security group important. Traffic still has to enter through the ALB and the task only accepts `8080` from the ALB security group. The ALB checks `/health` before treating the task as healthy.

Fargate also means I don't have EC2 instances to manage or patch. I give up some control over the underlying compute, but for a small service I preferred keeping that extra server layer out.

Images are stored in ECR and tagged with the Git SHA. This means I can trace a running image back to the commit that built it instead of relying on `latest`.

## Terraform and CI/CD

I built the AWS resources manually first so I could understand how the traffic moved through the system. Once that worked, I moved the infrastructure into Terraform modules for the network, ALB, ECR and ECS.

The main constraint was that the resources already existed. Moving them into modules changed their Terraform addresses, so I used `moved` blocks instead of letting Terraform recreate working infrastructure.

State is stored in S3 so my local machine and GitHub Actions use the same state. This caught me out when CI once wanted to create around 20 resources that already existed while my local plan showed no changes. I wasn't touching apply with a plan like that. I traced it back to the backend setup, fixed it and checked the plan again.

GitHub Actions now handles the application and infrastructure deployments. The app pipeline builds the image, pushes it to ECR and updates ECS. It waits for ECS to stabilise before checking `/health`.

GitHub connects to AWS through OIDC rather than storing long-lived AWS keys. Terraform destroy also has its own manual workflow so deleting the environment has to be intentional.

![Successful application deployment](assets/screenshots/app-pipeline-green.png)

## Testing and Troubleshooting

Application logs go to CloudWatch and the Discord webhook is stored in SSM Parameter Store rather than the repo or Docker image.

I deliberately broke a monitored endpoint to test the alerting. SammyPulse detected the failure and sent a Discord alert. Once the endpoint was restored I got the recovery notification too.

![Discord alert after endpoint failure](assets/screenshots/discord-alert.png)

I also stopped the running ECS task to test recovery. ECS launched a replacement and brought the service back to its desired count.

![ECS replacing the stopped task](assets/screenshots/ecs-self-healing.png)

One issue I hit was the ECS task running while the ALB kept marking it unhealthy. I followed the traffic path and found the ECS security group was blocking the ALB on `8080`. I allowed the port from the ALB security group only and the target became healthy.

![Healthy ALB target after the security group fix](assets/screenshots/alb-target-healthy.png)

I also tested a bad application deployment. When the new version couldn't become healthy I checked ECS and CloudWatch, found the problem and rolled back to the last known good image. I checked `/health` again afterwards to make sure the service had actually recovered.

## Improvements

The first change I'd make is moving the ECS tasks into private subnets so they don't need public IPs. VPC endpoints could handle AWS service access, with NAT added if outbound internet access is still needed.

I'd also run multiple tasks across availability zones. One task keeps the current cost down, but there is no second healthy target while it is being replaced.

After that I'd add automatic rollback for failed deployments and CloudWatch alarms for ALB errors, response time and ECS CPU and memory. The current logs and endpoint alerts are useful, but these would give me earlier signs that something is going wrong.

## Application Credit

[Gatus](https://github.com/TwiN/gatus) was created by TwiN. My work covers the Docker deployment, AWS infrastructure, Terraform, CI/CD, security, monitoring, failure testing and troubleshooting around it.

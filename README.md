# SammyPulse ECS

SammyPulse is my deployment of Gatus, an open-source app that monitors endpoints and reports when something goes down. I containerised it with Docker and deployed it on AWS ECS Fargate. Terraform manages the infrastructure and GitHub Actions handles deployments.

The aim was to keep the platform simple enough to understand end to end while still thinking about security, reliability, cost and recovery.

## Live Demo

🌐 **[View SammyPulse](https://status.sammypulse.co.uk)**

![SammyPulse live demo](assets/screenshots/sammypulse-demo.gif)

## Architecture

![SammyPulse Architecture](assets/screenshots/sammypulse-architecture.png)

**User → Route 53 → HTTPS → ALB → ECS Fargate → SammyPulse**

I decided the ALB should be where the public internet stops. Route 53 sends users to the ALB over HTTPS. The ALB then forwards traffic to SammyPulse on `8080`.

The ECS security group only allows `8080` from the ALB security group. This keeps the application port closed to direct inbound internet traffic. The ALB also checks `/health` before sending traffic to the task so the application has to be healthy before it receives requests.

## Run Locally

Clone the repo and build the image.

```bash
git clone https://github.com/Sammy-DevOps/SammyPulse_ECS.git
cd SammyPulse_ECS
docker build -t sammypulse:local ./app
```

Run the container.

```bash
docker run --rm -d \
  --name sammypulse \
  -p 8080:8080 \
  sammypulse:local
```

Check the health endpoint.

```bash
curl http://localhost:8080/health
# {"status":"UP"}
```

Open `http://localhost:8080` to view SammyPulse locally.

## Trade-offs

I had a few constraints around cost and keeping the setup simple enough to understand end to end.

- **Fargate instead of EC2** means less infrastructure to manage but less control over the underlying compute.
- **One task instead of multiple tasks** keeps the cost down but there is no second healthy target while the task is being replaced.
- **Public subnets with no NAT** keep the network simpler and cheaper but the task needs a public IP for outbound access.
- **Manual rollback** works for the current setup but recovery takes longer than an automatic rollback.

These choices kept the current setup smaller while still giving me room to improve the design later.

## Building SammyPulse

### From Docker to AWS

I started locally so I could check the application and container before adding AWS. Once that was working I pushed the image to ECR and deployed it to Fargate.

I chose Fargate because I didn't need to manage EC2 hosts for a small containerised application. SammyPulse runs one task across two public subnets with no NAT gateway. The task needs a public IP for outbound access but inbound application traffic is still restricted to the ALB.

### Moving to Terraform

I created the infrastructure manually first because I wanted to understand how the AWS resources connected. Once the request path was working I moved the network, ALB, ECR and ECS resources into Terraform modules. This made the infrastructure repeatable and kept it in code.

The AWS resources already existed when I made this change. Moving them into modules changed their Terraform addresses. I didn't want Terraform to recreate working resources because I had changed the code structure, so I used `moved` blocks to map the old addresses to the new ones.

Terraform state is stored in S3 so local Terraform and GitHub Actions use the same state. At one point CI planned around 20 resources that already existed while my local plan showed no changes. I stopped before applying it and traced the difference back to the backend setup. After fixing it I checked the plan again before continuing.

### Automating Deployments

Once the infrastructure was stable I automated deployments with GitHub Actions. Application changes build a Docker image and tag it with the Git SHA. The pipeline pushes the image to ECR and updates the ECS service.

I use the Git SHA so I can trace a deployed image back to the commit that produced it. GitHub authenticates to AWS through OIDC instead of storing long-lived AWS access keys.

Infrastructure changes have their own Terraform workflow. Destroy is kept as a separate manual workflow so the environment cannot be removed by a normal push.

![Successful application deployment](assets/screenshots/app-pipeline-green.png)

## Testing Failure

I also tested how the deployment behaved when something went wrong.

I broke one of the monitored endpoints to test the alerting. SammyPulse detected the failure and sent a Discord alert. When I restored the endpoint it sent a recovery notification. The Discord webhook is stored in SSM Parameter Store rather than the repository. Application logs are sent to CloudWatch.

![Discord alert after endpoint failure](assets/screenshots/discord-alert.png)

I stopped the running ECS task to test ECS recovery. The service desired count was one so ECS detected the missing task and launched a replacement.

![ECS replacing the stopped task](assets/screenshots/ecs-self-healing.png)

During the build I had an issue where the ECS task was running but the ALB target was unhealthy. I checked the request path from the ALB to the target group and then the ECS security group. The security group was blocking the ALB from reaching the task on `8080`.

I changed the rule to allow `8080` from the ALB security group only. This fixed the health check without opening the application port to the internet.

![Healthy ALB target after the security group fix](assets/screenshots/alb-target-healthy.png)

I tested a bad deployment as well. When the new version couldn't become healthy I checked the ECS deployment and CloudWatch logs. I rolled back to the last known good image and checked `/health` again to confirm the service had recovered.

## What I'd Improve

The current design keeps cost and complexity down but it could be more resilient.

I would move the ECS tasks into private subnets so they no longer need public IPs. VPC endpoints could provide access to AWS services. NAT could then be added if the application still needed outbound internet access.

I would also run multiple tasks across availability zones. This would cost more but the ALB would have another healthy target if one task failed or was being replaced.

The deployment currently uses manual rollback. I would add automatic rollback so ECS can recover faster from a failed deployment. I would also add CloudWatch alarms for ALB errors and response time as well as ECS CPU and memory.

## Application Credit

[Gatus](https://github.com/TwiN/gatus) was created by TwiN. My work covers the Docker deployment, AWS infrastructure, Terraform, CI/CD, security, monitoring, failure testing and troubleshooting around the application.

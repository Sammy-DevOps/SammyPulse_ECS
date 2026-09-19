# SammyPulse ECS

SammyPulse is my deployment of Gatus, an open-source application that monitors endpoints and reports when something becomes unavailable. It runs as a Docker container on AWS ECS Fargate, with the infrastructure managed through Terraform and deployments handled by GitHub Actions.

The goal was to keep the platform small and understandable while still covering the things I would expect around a real service: HTTPS, controlled network access, repeatable infrastructure, automated deployments, monitoring and recovery when something goes wrong.

## Live Demo

🌐 **[View SammyPulse](https://status.sammypulse.co.uk)**

![SammyPulse live demo](assets/screenshots/sammypulse-demo.gif)

## Architecture

![SammyPulse Architecture](assets/screenshots/sammypulsediagram.png)

**Request path:** User → Route 53 → HTTPS/ALB → ECS Fargate → SammyPulse

The ALB is where public traffic stops. It forwards requests to the ECS task on port `8080`, but that port isn't open directly to the internet. The ECS security group only accepts `8080` from the ALB security group.

Route 53 handles the domain and ACM provides HTTPS. The ALB also checks `/health` before treating the task as healthy and sending traffic to it.

## Local Setup

```bash
git clone https://github.com/Sammy-DevOps/SammyPulse_ECS.git
cd SammyPulse_ECS

docker build -t sammypulse:local ./app
docker run --rm -d --name sammypulse -p 8080:8080 sammypulse:local

curl http://localhost:8080/health
# {"status":"UP"}
```

## Engineering the Deployment

I kept the infrastructure fairly small. SammyPulse currently runs one Fargate task across a network with two public subnets and no NAT gateway.

That keeps the setup and cost down, but it comes with limits. The task needs a public IP for outbound access and one task means there can be a short period without a healthy target while ECS replaces it. The public IP also made the security group boundary important. Inbound application traffic still has to come through the ALB rather than reaching the task directly.

Fargate fits the same approach. There are no EC2 hosts for me to manage or patch and ECS maintains the desired task count. The trade-off is less control over the compute underneath compared with running ECS on EC2.

Images are stored in ECR and tagged with the Git SHA. This means a running image can be traced back to the exact commit that produced it instead of relying on a changing tag such as `latest`.

The infrastructure started manually. Once I understood the traffic path and how the AWS resources connected, I moved it into Terraform modules for the network, ALB, ECR and ECS.

That migration had its own constraint: the resources already existed. Moving them into modules changed their Terraform addresses, and I didn't want Terraform destroying and recreating working infrastructure just because the code structure had changed. I used `moved` blocks to map the old addresses to the new ones.

Terraform state is stored in S3 so local Terraform and GitHub Actions use the same view of the infrastructure. At one point CI planned around 20 resources that already existed while my local plan showed no changes. I wasn't touching apply with a plan like that. I traced the difference back to the backend setup, fixed it and checked the plan again before continuing.

GitHub Actions now handles the application and infrastructure deployments. The application pipeline builds the image, tags and pushes it to ECR then updates ECS. It waits for the service to stabilise before checking `/health`.

AWS access from GitHub uses OIDC rather than long-lived AWS access keys. Terraform destroy also has its own manual workflow, so removing the environment has to be intentional rather than something a normal push can trigger.

![Successful application deployment](assets/screenshots/app-pipeline-green.png)

## Monitoring and Reliability

Application logs go to CloudWatch and the Discord webhook is stored in SSM Parameter Store rather than the repository or Docker image.

I wanted to test the alerting rather than just assume the configuration worked. I deliberately broke one of the monitored endpoints and SammyPulse picked up the failure. A Discord alert came through and when I restored the endpoint I received the recovery notification.

![Discord alert after endpoint failure](assets/screenshots/discord-alert.png)

I tested ECS recovery in a similar way by stopping the running task. ECS detected that the desired count was no longer met, launched a replacement and brought the service back.

![ECS replacing the stopped task](assets/screenshots/ecs-self-healing.png)

One of the main issues during the build was a task that looked healthy in ECS while the ALB kept marking the target unhealthy. I followed the request path from the ALB to the target group and then the ECS security group. The ALB was being blocked on `8080`. Allowing that port specifically from the ALB security group fixed the health checks without opening it to everyone.

![Healthy ALB target after the security group fix](assets/screenshots/alb-target-healthy.png)

I also tested a bad application deployment. When the new version couldn't become healthy, I checked the ECS deployment and CloudWatch logs then rolled back to the last known good image. I checked the service and `/health` again afterwards rather than treating the rollback itself as proof of recovery.

## Improvements

The first network improvement would be moving the ECS tasks into private subnets so they no longer need public IPs. VPC endpoints could cover access to AWS services, with NAT added where outbound internet access is still required.

I'd also move from one task to multiple tasks across availability zones. One task keeps the current cost down, but the ALB has no second healthy target while that task is being replaced. Multiple tasks would improve availability during failures and deployments.

Deployment recovery is still manual, so automatic rollback would be another improvement. I'd also add CloudWatch alarms around ALB errors and response time alongside ECS CPU and memory. The current logs and endpoint alerts give me useful signals, but those extra metrics would make problems easier to catch earlier.

## Application Credit

[Gatus](https://github.com/TwiN/gatus) was created by TwiN. My work here covers the Docker deployment, AWS infrastructure, Terraform, CI/CD, security, monitoring, failure testing and troubleshooting around the application.

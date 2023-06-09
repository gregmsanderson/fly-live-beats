# In conclusion

For this guide I tried running the same app on both Fly.io and AWS.

This particular app is **substantially** easier to deploy on Fly.io. Whether that is the case for _your_ app will depend on exactly what functionality it requires. In particular:

- Do you need a WebSocket?
- Do the nodes need to communicate with each other in a cluster?
- Does it need persistent local storage?

If your app does not need a WebSocket then more compute options become available to you. Their newest service, App Runner, appears to be much simpler.

If you _do_ need a WebSocket, there is Lightsail. That does support WebSockets. It is also much simpler to deploy a container than using ECS.

However both App Runner and Lightsail run containers within an AWS-provided VPC. They can not communicate with each other. If any kind of PubSub is needed you would need to use something like Redis (in AWS, that would mean Elasticache) at an extra cost.

If you are happy to pay per request, there is Lambda. It doesn't support Elixir as a run-time however you can run a container and so (in theory) you should be able to run your app on it.

As regards ease of use, AWS is more complicated. Arguably that is because it is more flexible. For example in Fly.io, you have a single private network per organization. All of your resources are placed within that. They can automatically talk to each other (using IPv6) without additional configuration. In a single AWS account you can have multiple VPCs. Resources in each VPC can not _automatically_ communicate with each other. You need to configure security groups for each resource. To complicate that slightly for newer users, the destination you provide is actually the _security group_ used by the other resource, rather than "it". So if you would like an ECS service to be able to connect to an RDS database, for the RDS security group you would need to allow inbound connections from the ECS service's _security group_.

Assuming you are not using a custom domain for your app, an Application Load Balancer does provide you with a hostname (what it calls its DNS name) such as `name.region.elb.amazonaws.com`. However that does not support using port 443/HTTPS as a listener by default. Unlike on Fly.io, where its provided hostname (such as `name.fly.dev`) does. You can immediately use HTTPS (which all production applications should be). In AWS you have to provide a custom domain for your ALB to use port 443/HTTPS and so also provide/generate a certificate.

When provisioning services, AWS _should_ see that it needs more access that it has been given. For example when deploying an AWS service to ECS that makes use of secrets (as most applications will) those secrets need to be stored encrypted. AWS lets you do that (using Secrets Manager or Parameter Store) however its default execution role does not include permission for it to fetch those secrets. You need to [manually add the following permissions as an inline policy to the task execution role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html). That's awkward.

If you want to SSH in to a container/vm, on Fly.io that is incredibly easy. Simply type `flyctl ssh console`. You don't even need WireGuard configured. You can then see exactly what is happening inside it. On AWS ECS that is remarkably complicated to do. The ability to access the container directly has now been added however there is a [page of instructions](https://aws.amazon.com/blogs/containers/new-using-amazon-ecs-exec-access-your-containers-fargate-ec2/) to wade through to configure it.

Like Fly.io, AWS provides a private registry for your images. Fly.io provides a shared registry and so you do not need to manually create it before pushing an image. On AWS, you do. It's an additional step. On Fly.io, storing and using those images is free. On AWS you have to pay for the storage and data transferred by them (though this should be minimal for most applications).

Fly.io let you specify a release command to run on deploy. That is very helpful for running database migrations. This Live Beats app needs to run just such a command. However ECS does not appear to have a similar option. In the end we added it to the `Dockerfile`, then removed it afterwards. That is awkward and shouldn't be needed.

It is not entirely fair to compare the database options available on Fly.io and AWS. Fly.io makes clear their database is [not a managed service](https://fly.io/docs/postgres/getting-started/what-you-should-know/). It is just a regular app. RDS is managed and so more options come along with that. However creating a database is much simpler on Fly.io. You can use their CLI to provision a Postgres app, where it basically just asks for its region and the number of instances (whether to provide HA). RDS has _many_ more options to choose from. Beyond asking for the number of instances, you have six different database engines (Aurora Postgres, or regular Postgres?). Three types of storage (General Purpose SSD, Provisioned IOPS SSD, and Magnetic). Three instance types (general-purpose, memory-optimized, and burstable). A vast number of instance types (ranging from the smallest db.t4g.micro to the largest db.r5d.24xlarge).

It is complicated to run an app globally on AWS. It has clearly separated geographic regions. You can use [geo routing](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-geo.html) within its DNS service, Route 53, or its Global Accelerator to make sure your users are served by an app closest to them. However that adds to the cost. On Fly.io, you do not need to add anything. On AWS you would need to replicate the app in multiple regions (for example adding a load balancer in each one). Assuming you are using the most common type, an Application Load balancer (ALB), each one costs a minimum of ~$20 ($0.02646 per ALB-hour, assuming the eu-west-2 region, which excludes the additional LCU-hour metric) per month. With Fly.io, _their_ load balancer (the proxy) is provided for free and its anycast automatically handles global applications.

In terms of cost, running this app on Fly.io cost me ... $0. Which is hard to believe. For that I can run 3 VMs with 3 1GB volumes. There is no cost for global routing, load balancing, or images. Even excluding its permanent free allowance, running its 3 VMs (2 for the app, and 1 for the database) would cost ($1.94 \* 3) = $5.82 a month on Fly.io. That is cheaper than running a _single_ container on ECS Fargate. The cost of running the _smallest_ container on ECS Fargate is $10.36235 a month. To be fair it's not exactly the same as that does have 512MB, compared to 256MB on Fly.io. However even if we halve its cost, that would _still_ be $10.36235/2 = $5.181175. That is the cost of running three VMs on Fly.io for the cost of running one on AWS.

In conclusion, if you are deploying the Live Beats app (or a similar Phoenix LiveView app that needs WebSockets and clustering) I would recommend using Fly.io over AWS.

If you found any errors deploying the app to Fly.io or AWS, some of [these suggestions](/docs/14-any-errors.md) may help.

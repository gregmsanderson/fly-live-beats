# In conclusion

For this guide I tried running the same app on both Fly.io and AWS.

This particular app is **substantially** easier to deploy on Fly.io. Whether that is the case for _your_ app will depend on exactly what functionality it requires. In particular:

- Do you need a WebSocket?
- Do the nodes need to communicate with each other (libcluster)?
- Does it need persistent local storage?

If your app does not need a WebSocket then more compute options become available to you. Their newest service, App Runner, appears to be much simpler. If you _do_ need a WebSocket, there is the Lightsail. That does support WebSockets and it is also simpler to deploy a container.

However both App Runner and Lightsail run containers within an AWS-provided VPC. They can not communicate with each other. If any kind of PubSub is needed you would need to use something like Redis (in AWS, that would mean Elasticache) at an extra cost.

If you are happy to pay per request, there is Lambda. It doesn't support Elixir as a run-time, however you can deploy a container to it.

As regards ease of use, AWS is much more complicated. Arguably that is because it is more flexible. For example in Fly.io, you have a single private network per organization. All of your resources are placed within that. They can automatically talk to each other (using IPv6) without additional configuration. In an AWS account you can have multiple VPCs. Resources in each can not _automatically_ communicate with each other. You need to configure security groups for each resource. To complicate that slightly for newer users, the destination you provide is actually the _security group_ used by the other resource, rather than "it". So if you would like an ECS service to be able to connect to an RDS database, for the RDS security group you would need to allow inbound connections from the ECS service's _security group_.

Assuming you are not using a custom domain for your app, an Appliication Load Balancer does provide you with a hostname (what it calls its DNS name) such as `name.region.elb.amazonaws.com`. However that does not support using port 443/HTTPS as a listener by default. Unlike on Fly.io, where its provided hostname (such as `name.fly.dev`) does. You can immediately use HTTPS (which all production applications should be). In AWS you have to provide a custom domain to use 443/HTTPS.

When provisioning services, AWS should see that it needs more access that it has been given. For example when deploying an AWS service that makes use of secrets (as most applications will), those secrets need to be stored encrypted and not provided directly as plain text in the definition. AWS lets you do that (using Secrets Manager or Parameter Store) however its default execution role does not include permission for it to access those secrets. You need to [manually add the following permissions as an inline policy to the task execution role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html). That's awkward.

If you want to SSH in to a container/vm, on Fly.io that is incredibly easy. Simply type `flyctl ssh console`. You don't even need WireGuard configured. So you can then see exactly what is happening inside it. On AWS ECS, that is remarkably complicated to do. The ability to access the container directly was finally added last year however there is [page of instructions](https://aws.amazon.com/blogs/containers/new-using-amazon-ecs-exec-access-your-containers-fargate-ec2/) to wade through to configure it.

Like Fly.io, AWS provides a private registry for your imaages. Fly.io provides a shared registry and so you do not need to manually create it before pushing an image. On AWS you do. It's an additional step. On Fly.io, storing and using those images is free. On AWS you have to pay for the storage and data transferred by them (though this should be minimal for most applicartions).

Fly.io let you specify a release command to run on deploy. That is very helpful for running database migrations. This app needs to run just such a command. However ECS do not have a similar option. In the end we added it to the `Dockerfile`, then removed it. But that is very awkward and shouldn't be needed.

It is not entirely fair to compare the database options available on Fly.io and AWS. Fly.io makes clear their database is [not a managed service](https://fly.io/docs/postgres/getting-started/what-you-should-know/). It is just a regular app. RDS is managed and so more options come along with that. However creating a database is much simpler on Fly.io. You can use their CLI to provision a Postgres app, where it basically just asks for its region and the number of instances (whether to provide HA). RDS has _many_ more options to choose from. Beyond asking for the number of instances, you have six different database engines (Aurora Postgres, or regular Postgres?). Three types of storage (General Purpose SSD, Provisioned IOPS SSD, and Magnetic). Three instance types (general-purpose, memory-optimized, and burstable). A vast number of instance types (ranging from the smallest db.t4g.micro to the largest db.r5d.24xlarge).

There is no real option to scale _globally_ on AWS. It used clearly separated geographic regions. You can use [geolocation routing](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-geo.html) within its DNS service, Route 53, to make sure your users are served by an app closest to them. However that costs more as you pay for the DNS queries. On Fly.io, those are free. Plus it means _replicating_ the resources in all those regions (for example adding a load balancer in each one). Assuming you are using the most common type, an Aplication Load balancer (ALB), _each one_ costs a minimum of ~$20 ($0.02646 per ALB-hour, assuming the eu-west-2 region, which excludes the additional LCU-hour metric). See [ALB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/?nc=sn&loc=3). With Fly.io, _their_ load balancer (they call it the proxy) is provided for free and using anycast automatically handles global applications.

In conclusion, if you are deploying the Live Beats app (or a similar Phoenix LiveView app that needs both WebSockets and libcluster) we would recommend using Fly.io over AWS.

## Notes

For AWS we are basing pricing on the `eu-west-2` region. Fly has the same compute cost in eveery region but we have been using its `lhr` region.

AWS pricing [assumes 730 hours in a month](https://aws.amazon.com/calculator/calculator-assumptions/).

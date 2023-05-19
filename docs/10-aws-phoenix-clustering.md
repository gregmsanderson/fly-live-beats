# Clustering

The **TL;DR**: I added this to the dependencies in `mix.exs`, made sure it is configured in `config/runtime.exs` and then edited the task's IAM role to give it the necessary permissions.

```elixir
{:libcluster_ecs, github: "pro-football-focus/libcluster_ecs"}
```

## Does it need any config?

Yes. The `libcluster_ecs` needs to know your AWS region, ECS cluser and ECS service. In `config/runtime.exs` I referenced environment variables for those:

1. `AWS_ECS_CLUSTER_REGION`. For example `eu-west-2`

2. `AWS_ECS_CLUSTER_NAME`. For example `fly-live-beats-ecs-cluster`

3. `AWS_ECS_SERVICE_ARN`. For example `arn:aws:ecs:eu-west-2:1234567:service/fly-live-beats-ecs-cluster/fly-live-beats-service`

That was why I said to provide those three in your ECS task definition. They are not secret and hence were added in plain text.

## Why is that strategy needed?

If you recall from using Fly.io, [it makes clustering easy](https://fly.io/docs/elixir/the-basics/clustering/).

AWS ... doesn't. At least not in my experience. Others have struggled with it too:

> Can you please share your setup if you are running a cluster in Fargate? Our DevOps are trying their best to have a setup in Fargate for our new Elixir app, but it‘s hard.

`https://elixirforum.com/t/distributed-elixir-on-aws-fargate/28487`

> Did anyone successfully set up ECS using distributed Elixir? I am tackling this right now.

`https://elixirforum.com/t/distributed-elixir-in-amazon-ecs/15106`

> What is the best way of running a Phoenix server in cluster mode in AWS ECS?

`https://elixirforum.com/t/phoenix-cluster-in-ecs/45658`

There are a variety of suggestions. It's complicated further by some people using EC2 instances and others using Fargate.

## Using code?

This is a widely linked guide by Drew Blake:

[Elixir Clustering with libcluster and AWS ECS Fargate in CDK](https://dmblake.com/elixir-clustering-with-libcluster-and-aws-ecs-fargate-in-cdk)

In their opinion:

> You won't be able to configure clustering based on the forum posts.

Well that's not _ideal_. They detail how to set it up using the CDK. I started to follow their guide however was stumped by the service discovery. I'd previously come across many references to ECS support service discovery. However in the AWS console, it would only reference service _connect_.

## Service connect?

If you check your service in the AWS console, you will likely see a checkbox for enabling "Service Connect". If you _do_ tick that, you are asked for client or client-server mode. If you say client-server mode, you are asked for even more details.

**Note:** If you do try enabling it, in the "Advanced" panel I found log collection was enabled. That makes sense. Logs are very handy for debugging. However AWS needs permission to do anything. And it's not obvious that it does not have permission to _create_ that log group. So if you do have the box checked for logging just below, make sure that either the log group _already_ exists, you provide one that _does_ already exist, _or_ you edit the IAM permissions so that it _can_ create a new log group. It's probably easiest to just use one that already exists.

I could not get it to work though.

It _appears_ to create an endpoint which can then be used _across_ services. However I want containers to communicate within the _same_ service. It should be possible to use it for that _too_ (like `cluster.namespace`). Apparently it doesn't use DNS and so should be much better than service discovery using DNS. At least according to [this answer](https://stackoverflow.com/questions/76000775/aws-ecs-service-connect-versus-service-discovery).

It _should_ be possible for `libcluster` to use it with `Cluster.Strategy.DNSPoll`. However when I tried, it wouldn't. Perhaps it was because of my security group settings. I did get it running (with side-car containers clearly being added to my tasks). They added a load of entries to the logs. But each `Node.list()` was `[]`.

## Service discovery?

I figured what I actually wanted was service _discovery_. But there was no option anywhere in the AWS console to enable that. It didn't seem to be enabled by default either. So how do you get access to it 🤔 ?

Well ... it turns out that:

> Service discovery can only be configured when creating a service. Updating existing services to configure service discovery for the first time or change the current configuration isn't supported.

Source: [AWS docs](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html)

Ok. But I don't recall seeing any service discovery option when I created _my_ service 🤔 Why not?

Well ... it turns out that's because it's not there.

> The workflow to create a service in the Amazon ECS classic console supports service discovery.

Same AWS docs. Hmmm. It's only possible in the _old_ console.

So ... you can either get the new "Service Connect" working. Or switch back to the old (aka classic) console, make a new service, and in so doing enable "Service Discovery" ... or, do something else.

I wasn't keen on going back and doing it all again so I opted for "something else".

I found someone else that presumably had the same problem. They [have created their own strategy](https://github.com/pro-football-focus/libcluster_ecs) for `libcluster`, making use of the ECS API to get the IPs of other containers. It's [not available on hex](https://github.com/pro-football-focus/libcluster_ecs/issues/1) however the repo can be used as a dependency.

And with that ... done. Well, not _quite_.

The nodes now _know_ about each other. But they can't _talk_ to each other.

```
[warn] [libcluster:ecs] unable to connect to :"live-beats@172.31.32.42"
```

On to networking.

## Security group

In theory you should be able to limit access to only certain ports. Commonly mentioned ones are `4369`, `9000-9010` and `9090`.

However according to [this answer](https://stackoverflow.com/a/35409199) the port may be random 😕.

I found that only using _any_ port worked reliably. So _perhaps_ that is the case. That needs further testing!

I clearly didn't want to open _any_ port to _any_ IP so I made sure the source was the CIDR range of my VPC. So _only_ resources inside my VPC can access each container, and the VPC only contains resources for this app.

Now connections should be allowed between containers.

But there is one more thing it seems is needed ...

## Secret cookie

If you take a look at `https://fly.io/docs/elixir/the-basics/clustering/#the-cookie-situation` it says to also set an environment variable called `RELEASE_COOKIE`.

Hence during the guide I added an environment variable called `RELEASE_COOKIE` whose value is the secret stored at `staging/fly-live-beats/release-cookie`.

That solves _that_ problem.

Confirming that, the logs now have:

```
[info] [libcluster:ecs] connected to :"live-beats@172.31.33.10
```

You can confirm by using "ECS Exec" to get shell access to your containers, as [previously documented](/docs/9-aws-deploy-it.md).

Is it possible [run it globally](/docs/11-aws-run-globally.md) on AWS, like it is on Fly.io?

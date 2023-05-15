# Deploy to Fly.io

## Create a Fly.io account

Visit [https://fly.io/](https://fly.io/) and click "Sign up".

You can either sign in using an existing GitHub account, or provide an email/password.

You should then get a welcome email to verify your email address:

![Verify](img/fly_verify_email.jpeg)

Clicking that button takes you to the dashboard:

![Dashboard](img/fly_initial_dashboard.jpeg)

We haven't provided any payment details yet. We will need to do that before we deploy though.

## CLI

Let's go ahead and [install the Fly.io CLI](https://fly.io/docs/hands-on/install-flyctl/).

Let's check that worked:

```sh
$ flyctl --version
flyctl v0.1.3 darwin/amd64 Commit: d42ac204 BuildDate: 2023-05-12T08:15:04Z
```

In future you can download the latest version using `flyctl version update`.

We'll now need to sign in to get a token by running: `flyctl auth login`.

That should open a new browser window. Since we are still signed in, we can connect to the account. It should say _"Your FlyCTL should be connected now"_.

Before we close that window we'll add a credit card:

![Dashboard](img/fly_credit_card.jpeg)

There is a [free tier](https://fly.io/docs/about/pricing/) however adding that credit card is necessary to verify your identity and to prevent abuse.

Now we should be able to deploy.

**Note:** This is a new Fly.io accountand so we will automatically be using Fly.io's new [V2/Machines](https://fly.io/docs/about/pricing/#apps-v2-and-machines) by default. If you have an existing app you would like to migrate to V2, Fly.io have a [guide for that](https://fly.io/docs/apps/migrate-to-v2/).

## Database

We know the Live Beats app needs a Postgres database.

We _could_ create the database at the same time as the app. However that's not what we'll be doing with AWS. So let's go ahead and [create that database](https://fly.io/docs/postgres/getting-started/create-pg-cluster/) first:

```sh
$ flyctl postgres create
```

That talks you through the options. It asks for a name, the region, and whether you want high availability (HA). Since this is just for a test we can pick the smallest size (a single node with a shared CPU). However to run your app in production we strongly recommend using those instead:

```sh
? Choose an app name (leave blank to generate one): your-name-here
automatically selected personal organization: its-name
Some regions require a paid plan (fra, maa).
See https://fly.io/plans to set up a plan.

? Select region: London, United Kingdom (lhr)
? Select configuration: Development - Single node, 1x shared CPU, 256MB RAM, 1GB disk
? Scale single node pg to zero after one hour? Yes
Creating postgres cluster in organization personal
Creating app...
Setting secrets on app its-name ...
Provisioning 1 of 1 machines with image flyio/postgres-flex:15.2@sha256:abcde
Waiting for machine to start...
Machine 1234567 is created
==> Monitoring health checks
  Waiting for 1234567 to become healthy (started, 3/3)

Postgres cluster its-name created
```

It should only take a few seconds to create then a further few seconds for the healthchecks to pass.

Assuming all is well you should be shown the credentials to connect to it. Make a note of those as you will only be shown them once. You could now [connect to that](https://fly.io/docs/postgres/connecting/connecting-with-flyctl/) and create the database ... however we'll let Fly create the app's database for us below.

The database app is now ready to use. We do not need to configure any networking/firewall.

## App

### Preparation

If you followed the previous steps, we needed to modify the original [Live Beats app](https://github.com/fly-apps/live_beats) to edit parts that were specific to Fly.io in order to try running it locally, in a container. Since we _are_ now deploying to Fly those changes are not necessary and so can be reverted. For example:

1. In the `Dockerfile` we commented out using IPv6, so uncomment that back to how it was:

```sh
# Set the runtime ENV
ENV ECTO_IPV6="true"
ENV ERL_AFLAGS="-proto_dist inet6_tcp"
```

2. In `/rel/env.sh.eex` we changed the way it got the IP using Fly's network, so that can be put back how it was:

```sh
ip=$(grep fly-local-6pn /etc/hosts | cut -f 1)
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=$FLY_APP_NAME@$ip
export LIVE_BEATS_SERVER_IP=$ip
```

3. In `/config/runtime.exs` we hard-coded an `app_name`, as we did not have `FLY_APP_NAME`. Now we do:

```sh
app_name =
  System.get_env("FLY_APP_NAME") ||
    raise "FLY_APP_NAME not available"
```

Next, the `fly.toml` file.

If you have a Phoenix LiveView app that has not previously been deployed to Fly, you won't have a `fly.toml` file. However this app has and so we need to make some changes to that file. Update the `app` value to be one of your choice since it needs to be globally unique. The `PHX_HOST` value needs to include that name. If you recall from running this app locally, that `PHX_HOST` is set to avoid errors with the WebSocket connection:

```toml
app = "your-choice-of-name"

[env]
  PHX_HOST = "your-choice-of-name.fly.dev"
```

You will need to make sure the two environment variables this app expects _are_ set locally. If you have previously tried [running it locally](/docs/1-run-locally.md) then they may well still be:

```sh
export LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours"
export LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours"
```

... since if those are _not_ set you would see _this_ happen when you tried to launch it ...

```sh
$ flyctl launch
Creating app in /path/here
An existing fly.toml file was found for app name
? Would you like to copy its configuration to the new app? Yes
Scanning source code
** (System.EnvError) could not fetch environment variable "LIVE_BEATS_GITHUB_CLIENT_ID" because it is not set
    (elixir 1.14.3) lib/system.ex:706: System.fetch_env!/1
    /Users/gregorysanderson/www/fly-live-beats/config/dev.exs:11: (file)
    /Users/gregorysanderson/www/fly-live-beats/config/config.exs:57: (file)
    (stdlib 4.2) erl_eval.erl:748: :erl_eval.do_apply/7
    (stdlib 4.2) erl_eval.erl:961: :erl_eval.expr_list/7
    (stdlib 4.2) erl_eval.erl:290: :erl_eval.expr/6
    (stdlib 4.2) erl_eval.erl:282: :erl_eval.expr/6
Detected a Phoenix app
? Choose an app name (leaving blank will default to 'fly-live-beats')
...
Preparing system for Elixir builds
Error: failed running /usr/local/bin/mix local.rebar --force: exit status 1
```

Now run `flyctl launch`.

When it asks if you want to deploy now, type `N` (no) since we need to do a few things before then:

```sh
$ flyctl launch
Creating app in /path/here
An existing fly.toml file was found for app your-app-name
? Would you like to copy its configuration to the new app? Yes
Scanning source code
Resolving Hex dependencies...
Resolution completed in 0.243s
Unchanged:
  castore 0.1.22
  connection 1.1.0
  ...
All dependencies are up to date
Compiling 5 files (.ex)
Detected a Phoenix app
? Choose an app name (leaving blank will default to 'your-app-name') your-name-here
Some regions require a paid plan (fra, maa).
See https://fly.io/plans to set up a plan.

? Choose a region for deployment: London, United Kingdom (lhr)
App will use 'lhr' region as primary

Admin URL: https://fly.io/apps/your-app-name
Hostname: your-app-name.fly.dev
Set secrets on fly-live-beats: SECRET_KEY_BASE
? Would you like to set up a Postgresql database now? No
? Would you like to set up an Upstash Redis database now? No
Preparing system for Elixir builds
Installing application dependencies
Running Docker release generator
Wrote config file fly.toml
? Would you like to deploy now? No
Validating /path/to/fly.toml
Platform: machines
✓ Configuration is valid

Your Phoenix app should be ready for deployment!.

If you need something else, post on our community forum at https://community.fly.io.

When you're ready to deploy, use 'fly deploy'.
```

Great!

## Deploy the app

We didn't deploy the app above since we first need to set some secrets. They will then be staged for deployment.

### Secrets

We need to provide a [GitHub OAuth](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app) client ID and secret that it can use to authenticate a user. If you have already tried running the app locally you will have already made one. However _that_ Oauth app has the app's URL `http://localhost:4000`. So you will need to make a new app in GitHub to get a _new_ client ID and secret. Visit [https://github.com/settings/applications/new](https://github.com/settings/applications/new). Set the app's "Homepage URL" as `https://your-app-name.fly.dev` and its "Authorization callback URL" to `https://your-app-name.fly.dev/oauth/callbacks/github` (of course replacing the name with your own). The client ID will be shown on screen. Click the button to generate a new client secret to get that too.

Now run this commnd to tell Fly.io those values (of course using your values instead):

```sh
$ flyctl secrets set LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours" LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours"
```

You should see "Secrets are staged for the first deployment".

### Attach the database

Next, the database. We created a database _app_ earlier. Now we need a database. We _could_ use the existing `postgres` user (whose credentials you have from earlier) to connect to the app and create a database ourselves. However Fly can [do that for us](https://fly.io/docs/postgres/managing/attach-detach/). Behind the scenes that should create a database, create a user, and set a `DATABASE_URL` for us. The syntax for the command is; `flyctl postgres attach --app <app-name> <postgres-app-name>` so replace these two values with your _own_ app name and Postgre app name:

```sh
$ flyctl postgres attach --app your-app-name your-postgres-name
```

**Note:** If you see a `Error: no active leader found` message at this point your database may have gone to sleep or been stopped (if it was a development one). You can [check on it](https://fly.io/docs/postgres/managing/monitoring/) by running: `flyctl status --app your-postgres-name`. If you see its state there as `stopped` then you will need to start it up again using `flyctl machine restart <id>`. Its ID is that first number returned in the status output. For example:

```sh
$ flyctl machine restart 123456789 --app your-postgres-name
Restarting machine 123456789
  Waiting for 123456789 to become healthy (started, 3/3)
Machine 123456789 restarted successfully!
```

Now if you check its status using `flyctl status --app your-postgres-name` you should now see its state as "started". You still need to attach your app to it and so once again try running `flyctl postgres attach --app your-app-name your-postgres-name` and _this_ time that should work.

You should see:

```sh
$ flyctl postgres attach --app your-app-name your-postgres-name
Checking for existing attachments
Registering attachment
Creating database
Creating user

Postgres cluster your-postgres-name is now attached to your-app-name
The following secret was added to fly-live-beats:
  DATABASE_URL=postgres://name:password@your-postgres-name.flycast:5432/your-app-name?sslmode=disable
```

Great!

We can now deploy our app using `flyctl deploy`. It will build an image, create additional resources (like a volume) and run our database migration:

```sh
$ flyctl deploy
==> Verifying app config
Validating /path/to/fly.toml
Platform: machines
✓ Configuration is valid
--> Verified app config
==> Building image
Remote builder fly-builder-random ready
==> Creating build context
--> Creating build context done
==> Building image with Docker
--> docker host: 20.10.12 linux x86_64
[+] Building 214.3s
=> copy /context /
...
--> Building image done
==> Pushing image to fly
The push refers to repository [registry.fly.io/your-app-name]
2ac3bc1cb523: Pushed
deployment-1234567: digest: sha256:abcde size: 1576
--> Pushing image done
image: registry.fly.io/your-app-name:deployment-1234567
image size: 119 MB
Watch your app at https://fly.io/apps/your-app-name/monitoring
Provisioning ips for your-app-name
  Dedicated ipv6: 12345
  Shared ipv4: 1.2.3.4
  Add a dedicated ipv4 with: fly ips allocate-v4
Creating 1GB volume 'data' for process group 'app'. Use 'fly vol extend' to increase its size
Running your-app-name release_command: /app/bin/migrate
  release_command 17811946a29068 completed successfully
Process groups have changed. This will:
 * create 1 "app" machine

No machines in group app, launching one new machine
  Machine 32874364c39658 [app] update finished: success
Finished launching new machines
Updating existing machines in 'your-app-name' with rolling strategy
  Finished deploying

Visit your newly deployed app at https://your-app-name.fly.dev/
```

It worked 🚀

(If your deploy failed, take a look at the **any errors** section at the bottom of this page).

Run `flyctl open` and that will open your app's URL e.g `https://your-app-name.fly.dev/`. The app redirects to the sign in page. It should look like this:

![Deployed app](img/fly_app_deployed_signin.jpeg)

If you want to check what's happening behind the scenes you can open your network tab. You should see an open WebSocket:

![Network requests](img/fly_app_deployed_network.jpeg)

If you click the sign in button you will be asked to sign in to GitHub and/or authorize the application to access your name and email address. You should then be redirected back to the Live Beats app, now signed in. You can upload an .mp3 file and should be able to play it.

![Signed in to app](img/fly_app_signed_in.jpeg)

It works!

## Size

By default your machines will be the smallest, cheapest ones. They have a shared CPU and 256MB of RAM. You can check which you are using with the `flyctl scale show` command:

```sh
$ flyctl scale show
VM Resources for app: your-app-name

Groups
NAME    COUNT   KIND    CPUS    MEMORY  REGIONS
app     1       shared  1       256 MB  lhr
```

In production you will likely want to use larger sizes. They do cost more, naturally. The size needed will depend on your app.

## Scaling globally

Currently we only have one machine running for our app. We can see that by running `flyctl status`:

```sh
$ flyctl status
App
  Name     = your-app-name
  Owner    = personal
  Hostname = your-app-name.fly.dev
  Image    = your-app-name:deployment-12345
  Platform = machines

Machines
PROCESS ID              VERSION REGION  STATE   CHECKS                  LAST UPDATED
app     12345           1       lhr     started 1 total, 1 passing      2023-05-13T17:54:42Z
```

We want to try adding more in different regions to see if they are able to communicate. It's recommended to run at _least_ two in production.

From this [list of regions](https://fly.io/docs/reference/regions/) we will add the US region `sea`. Normally you could run e.g `flyctl regions add sea` to change the regions the app can run in. However this Live Beats app uses a [volume](https://fly.io/docs/reference/volumes/). Volumes are local, persistent storage for machines. You need to [run a volume per machine](https://fly.io/docs/reference/volumes/). Rather than manually make that volume we can [clone the machine](https://fly.io/docs/apps/scale-count/#scale-up-with-fly-machine-clone) and Fly.io will do it for us 🙂.

You should already have its ID from running `flyctl status` so clone that:

```sh
$ flyctl machine clone --region sea 12345
Cloning machine 12345 into region sea
Volume 'data' will start empty
Provisioning a new machine with image registry.fly.io/your-app-name:deployment-12345...
  Machine abcde has been created...
  Waiting for machine abcde to start...
  Waiting for abcde to become healthy (started, 1/1)
Machine has been successfully cloned!
```

Great, it worked!

You can confirm by running `flyctl status`. That should show two machines (in our case, one in `lhr` and one in `sea`). If you run `flyctl volumes list` you should see the two volumes, and now both are attached to their respective VMs.

Let's check that the Live Beats app has noticed the new machine. SSH in to the cloest machine by running `flyctl ssh console`.

As Chris McCord demonstrates in [this video](https://www.youtube.com/watch?v=JrqBudJd2YM&ab_channel=ChrisMcCord) (skip to _5:30_) the app is using `libcluster`. You may have noticed that at the end of `/config/runtime.exs`:

```elixir
config :libcluster,
topologies: [
    fly6pn: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
            polling_interval: 5_000,
            query: "#{app_name}.internal",
            node_basename: app_name
        ]
    ]
]
```

You can now type `/app/bin/live_beats remote` to get shell access.

From there can see the region you are connected to by typing in `System.get_env("FLY_REGION")`. Fly.io provides that environment variable for you. In our case it's `lhr`.

You can also type `Node.list()` to get an array of the _other_ nodes in the cluster, of the format `app-name@IPv6`. In our case we have two machines and so this array has one element. It's the IPv6 of the _other_ one. Type `Ctrl+C`, `a`, and `exit` to leave the shell.

We tried it with ours:

```sh
 $ flyctl ssh console
Connecting to fdaa:2:2b0a:a7b:13e:2228:618a:2... complete
# /app/bin/live_beats remote
Erlang/OTP 24 [erts-12.0.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit]
Interactive Elixir (1.12.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(fly-live-beats@fdaa:2:2b0a:a7b:13e:2228:618a:2)1> System.get_env("FLY_REGION")
"lhr"
iex(fly-live-beats@fdaa:2:2b0a:a7b:13e:2228:618a:2)2> Node.list()
[:"fly-live-beats@fdaa:2:2b0a:a7b:bbfb:2d6c:f685:2"]
```

The cluster is working 🚀

## Custom domain

We didn't do this for _this_ guide however Fly.io supports using your own domain instead of its provided `your-app-name.fly.dev`. If you would like to use one, you will need to tell Fly.io about that so that it knows which app to route those requests to. As part of that process, it issues a free SSL certificate which it will automatically renew for you.

To use one, create the DNS record. A popular choice is Cloudflare. For example sign in to its dashboard, click on your domain, then on DNS, and add two entries. One for IPv4 (that's called an A record) and one for IPv6 (that's called an AAAA record). You can get those two values using `flyctl ips list`:

```sh
$ flyctl ips list
VERSION IP                      TYPE            REGION  CREATED AT
v6      12345:12345             public          global  41m57s ago
v4      1.2.3.4                 public (shared)
```

If you are using Cloudflare, you would need those DNS records to be grey-cloud (non-proxied). Else they would return the wrong IP (the IP of its proxy) and would fail the certificate validaation.

At this point requests to `your-domain.com` would go to Fly.io's network ... however it would not know what to do with them. Plus, it wouldn't have any SSL certifcate. You can sort out both of those issues by running `flyctl certs add your-domain.com`, of course providing your domain in its place. You can check on it by running `flyctl certs list`. Assuming your DNS records are correct, it should have been able to validate you own that custom domain and so issue a certificate for it. At that point you should be able to open that domain in your browser and have the response returned by your app.

## Any errors?

If the deployment failed at the build stage, a common cause is the Fly.io CLI being unable to connect to their remote builder. Fly.io provides a free app within your organization called a builder (if you run `flyctl apps list` you can see it). If you have Docker available locally (for example your have Docker Desktop installed and running), you can request that be used instead of the remote builder by running `flyctl deploy --local-only`. That may solve that issue.

If not, what does `flyctl doctor` report? Sometimes that can reveal network issues. It may be your local network/firewall blocking access to Fly.io.

If your app deploys but is not working, the first place to check for issues is the log. Either in your terminal directly, or by running `flyctl logs`. That will show a tail of the most recent lines. Often that will reveal the issue, for example a missing variable (secret not set) or failed healthcheck. You should see something like this:

```sh
2023-05-13T17:54:44Z app[12345] lhr [info]17:54:44.698 [info] Running LiveBeatsWeb.Endpoint with cowboy 2.9.0 at :::8080 (http)
2023-05-13T17:54:44Z app[12345] lhr [info]17:54:44.699 [info] Access LiveBeatsWeb.Endpoint at http://your-app-name.fly.dev
2023-05-13T17:54:49Z health[12345] lhr [info]Health check on port 8080 is now passing.
```

Depending on its load, your app may fail because it is out of memory. If so you may get an email from Fly.io to notify you about that ...

> Hello! Your “its-name-here” application hosted on Fly.io crashed because it ran out of memory. Adding more RAM to your application might help!

... with a link to its pricing and the community forums. You may want to (even temporarly) increase its memory to see if that resolves the issue.

You might see _this_ error:

![OOM error](img/fly_app_oom_error.jpeg)

A common cause of _that_ is the app not being able to connect to the database. Check `fly logs`. You might see an error like this:

```sh
[error] Postgrex.Protocol (#PID<0.1931.0>) failed to connect: ** (DBConnection.ConnectionError) tcp recv (idle): closed
```

If so, check your database is running:

```sh
$ flyctl status --app your-postgres-app-name
```

If you see:

```sh
ID              STATE   ROLE    REGION  CHECKS
12345           started error   lhr     3 total, 1 passing, 2 critical
```

... clearly that _is_ the issue. The database is not working correctly. Try restarting it (swapping in your ID value):

```sh
flyctl machine restart 12345 --app your-postgres-app-name
```

Wait about 30 seconds for it to restart. Hopefully your app is now able to connect to the database. Check `fly logs` again to see if that error is no longer shown.

Great! We have deployed the app to Fly.io.

Let's try AWS. First we'll need to [create an account](/docs/3-aws-create-account.md).

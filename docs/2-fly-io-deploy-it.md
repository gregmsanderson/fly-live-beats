# Deploy to Fly.io

**Note:** This repo contains the _modified_ Live Beats app (ready for deploying to AWS). For deploying Live Beats on Fly.io I'll instead use the code from the [original Live Beats repo](https://github.com/fly-apps/live_beats).

## Create a Fly.io account

Visit [https://fly.io/](https://fly.io/) and click "Sign up".

You can either sign in using an existing GitHub account, or provide an email/password. You should then get a welcome email to verify your email address:

![Verify](img/fly_verify_email.jpeg)

Clicking that button takes you to the dashboard:

![Dashboard](img/fly_initial_dashboard.jpeg)

## CLI

If you haven't already, [install the Fly.io CLI](https://fly.io/docs/hands-on/install-flyctl/).

```sh
$ flyctl --version
flyctl v0.1.3 darwin/amd64 Commit: d42ac204 BuildDate: 2023-05-12T08:15:04Z
```

In future you can download the latest version using `flyctl version update`.

You need to sign in to get a token by running: `flyctl auth login`.

That should open a new browser window. It should say _"Your FlyCTL should be connected now"_.

Before closing that window, add a credit card:

![Dashboard](img/fly_credit_card.jpeg)

There is a [free tier](https://fly.io/docs/about/pricing/) however adding that credit card is necessary to verify your identity and to prevent abuse.

Now it should be possible to deploy.

**Note:** This is a new Fly.io account and so I will automatically be using Fly.io's new [V2/Machines](https://fly.io/docs/about/pricing/#apps-v2-and-machines). If you have an existing app yet to be migrated to V2, Fly.io have a [guide for that](https://fly.io/docs/apps/migrate-to-v2/).

## Database

The Live Beats app needs a Postgres database.

I _could_ create the database at the same time as the app. However that's not what I'll be doing with AWS. So I'll [create a database on Fly.io](https://fly.io/docs/postgres/getting-started/create-pg-cluster/) first by running:

```sh
$ flyctl postgres create
```

As shown below, that talks you through the options. Since this is just for a test I'll pick the smallest size (no HA on a single node, with a shared CPU). However to run your app in production you should use HA.

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

It should only take a few seconds to create then a further few seconds for the health checks to pass.

Assuming all is well you should be shown the credentials to connect to it. Make a note of those as you will only be shown them once. You could now [connect to that](https://fly.io/docs/postgres/connecting/connecting-with-flyctl/) and create the database yourself. However I'll let Fly.io create that in a moment.

## App

In its `fly.toml` file update the `app` value to be one of your choice (it needs to be globally unique). The `PHX_HOST` value needs to include that name too

```toml
app = "your-app-name"

[env]
  PHX_HOST = "your-app-name.fly.dev"
```

Make sure the two GitHub client variables it expects _are_ set. If not, you will [get an error](/docs/14-any-errors.md):

```sh
export LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours"
export LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours"
```

Run `flyctl launch`. When it asks if you want to deploy now, type `N` (no) since you need to do a few things before then:

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
? Choose an app name (leaving blank will default to 'your-app-name') your-app-name
Some regions require a paid plan (fra, maa).
See https://fly.io/plans to set up a plan.

? Choose a region for deployment: London, United Kingdom (lhr)
App will use 'lhr' region as primary

Admin URL: https://fly.io/apps/your-app-name
Hostname: your-app-name.fly.dev
Set secrets on your-app-name: SECRET_KEY_BASE
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

Great! It's ready to deploy.

## Deploy the app

I haven't deployed the app yet since I _first_ need to set some secrets. They will then be staged for deployment.

### Secrets

The app needs a [GitHub OAuth](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app) client ID and secret that it can use to authenticate a user. If you have already tried [running this app locally](/docs/1-run-locally.md) you will have already made one. However _that_ has the homepage URL set as `http://localhost:4000`. So you need to make a new OAuth app in GitHub to get a _new_ client ID and secret. Visit [https://github.com/settings/applications/new](https://github.com/settings/applications/new). Set its "Homepage URL" as `https://your-app-name.fly.dev` and its "Authorization callback URL" to `https://your-app-name.fly.dev/oauth/callbacks/github` (of course replacing that name with your own).

The client ID will be shown on screen. Click the button to generate a new client secret to get that too.

Now run _this_ command to tell Fly.io those values (of course using yours):

```sh
$ flyctl secrets set LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours" LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours"
```

You should see "Secrets are staged for the first deployment".

### Attach the database

I created a Postgres database _app_ earlier. Now we need a database. I _could_ use the existing `postgres` user (whose credentials you have from earlier) to connect to the app and create a database ourselves. However Fly can [do that for me](https://fly.io/docs/postgres/managing/attach-detach/). Behind the scenes it should create a database, create a user, and set a `DATABASE_URL`. The command is: `flyctl postgres attach --app <app-name> <postgres-app-name>`. Replace these two values with your _own_ app name and Postgres app name:

```sh
$ flyctl postgres attach --app your-app-name your-postgres-name
Checking for existing attachments
Registering attachment
Creating database
Creating user

Postgres cluster your-postgres-name is now attached to your-app-name
The following secret was added to your-app-name:
  DATABASE_URL=postgres://name:password@your-postgres-name.flycast:5432/your-app-name?sslmode=disable
```

Great!

I can now deploy the app using `flyctl deploy`. It will build an image, create additional resources (like a volume) and run the database migration:

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
  Dedicated ipv6: 1234:1234
  Shared ipv4: 1.2.3.4
  Add a dedicated ipv4 with: fly ips allocate-v4
Creating 1GB volume 'data' for process group 'app'. Use 'fly vol extend' to increase its size
Running your-app-name release_command: /app/bin/migrate
  release_command 12345 completed successfully
Process groups have changed. This will:
 * create 1 "app" machine

No machines in group app, launching one new machine
  Machine 12345 [app] update finished: success
Finished launching new machines
Updating existing machines in 'your-app-name' with rolling strategy
  Finished deploying

Visit your newly deployed app at https://your-app-name.fly.dev/
```

It worked 🚀

Run `flyctl open` and that will open your app's URL e.g `https://your-app-name.fly.dev/`. The app redirects to the sign in page. It should look like this:

![Deployed app](img/fly_app_deployed_signin.jpeg)

If you want to check what's happening behind the scenes you can open your network tab. You should see an open WebSocket:

![Network requests](img/fly_app_deployed_network.jpeg)

If you click the sign in button you will be asked to sign in to GitHub and/or authorize the application to access your name and email address. You should then be redirected back to the Live Beats app, now signed in. You can upload an .mp3 file and should be able to play it.

![Signed in to app](img/fly_app_signed_in.jpeg)

It works 🙂

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

Currently I only have one machine running for the app. You can see that by running `flyctl status`:

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

I'll try adding more in different regions to see if they are able to communicate. It's recommended to run at _least_ two in production anyway.

From this [list of regions](https://fly.io/docs/reference/regions/) I will add a region in the US (`sea`). Normally you could run e.g `flyctl regions add sea` to change the regions the app can run in. However this Live Beats app uses a [volume](https://fly.io/docs/reference/volumes/). Volumes are local, persistent storage for machines. You need to [run a volume per machine](https://fly.io/docs/reference/volumes/). Rather than manually make that volume we can [clone the machine](https://fly.io/docs/apps/scale-count/#scale-up-with-fly-machine-clone) and Fly.io will do that for me 🙂.

You should already have its ID from running `flyctl status` so clone that:

```sh
$ flyctl machine clone --region sea 1234567
Cloning machine 1234567 into region sea
Volume 'data' will start empty
Provisioning a new machine with image registry.fly.io/your-app-name:deployment-12345...
  Machine abcde has been created...
  Waiting for machine abcde to start...
  Waiting for abcde to become healthy (started, 1/1)
Machine has been successfully cloned!
```

You can confirm by running `flyctl status`. That should show _two_ machines (in my case, one in `lhr` and one in `sea`). If you run `flyctl volumes list` you should see the two volumes, and now both are attached to their respective VMs.

I'll check that the Live Beats app has noticed that new machine. I'll SSH in to the closest machine by running `flyctl ssh console`.

As Chris McCord demonstrates in [this video](https://www.youtube.com/watch?v=JrqBudJd2YM&ab_channel=ChrisMcCord) (skip to **5:30**) the app is using `libcluster`. You may have noticed that at the end of `/config/runtime.exs` in the original repo (it's different in this one):

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

Type `/app/bin/live_beats remote` to get shell access.

From there can see the region you are connected to by typing in `System.get_env("FLY_REGION")`. Fly.io provides that environment variable for you. In my case it's `lhr`.

You can also type `Node.list()` to get an array of the _other_ nodes in the cluster, of the format `app-name@IPv6`. In my case we have two machines and so this array has one element. It's the IPv6 of the _other_ one e.g:

```sh
 $ flyctl ssh console
Connecting to fdaa:2:2b0a:a7b:13e:2228:618a:2... complete
# /app/bin/live_beats remote
Erlang/OTP 24 [erts-12.0.1] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit]
Interactive Elixir (1.12.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(fly-live-beats@fdaa:2:2b0a:a7b:13e:2)1> System.get_env("FLY_REGION")
"lhr"
iex(fly-live-beats@fdaa:2:2b0a:a7b:13e:2)2> Node.list()
[:"fly-live-beats@fdaa:2:2b0a:a7b:bbfb:2"]
```

Type `Ctrl+\` and then `exit` to leave the shell.

The cluster is working 🚀

## Custom domain

Fly.io supports using your own domain instead of its provided `your-app-name.fly.dev`. If you would like to use one, you will need to tell Fly.io about that so that it knows which app to route those requests to. As part of that process, it issues a free SSL certificate which it will automatically renew for you.

To use one, create the DNS record. A popular choice is Cloudflare. You would click on your domain, click on DNS, and add two entries. One for IPv4 (that's called an `A` record) and one for IPv6 (that's called an `AAAA` record). You can get those two values using `flyctl ips list`:

```sh
$ flyctl ips list
VERSION IP                      TYPE            REGION  CREATED AT
v6      12345:12345             public          global  41m57s ago
v4      1.2.3.4                 public (shared)
```

Assuming you are using Cloudflare, you would need those DNS records to be grey-cloud (non-proxied). Else they would return the wrong IP (the IP of its proxy) and would fail the certificate validation.

At this point requests to `www.example.com` would go to Fly.io's network ... however it would not know what to do with them. Plus, it wouldn't have any SSL certificate. You can sort out both of _those_ issues by running `flyctl certs add www.example.com`, of course providing your domain in its place. You can check on it by running `flyctl certs list`. Assuming your DNS records are correct, it should have been able to validate you own that custom domain and so issue a certificate for it.

However ...

1. If you visit `www.example.com` you would get a WebSocket error. Why? The Live Beats app needs to know its hostname. Recall that is done by setting the `PHX_HOST` environment variable. Make sure to update that in its `fly.toml` to `www.example.com`.

2. Signing in to the app would not work. Why? This app uses a GitHub OAuth app to sign in. It _also_ needs the app's hostname. If it's still set to use `https://your-app-name.fly.dev` that will need updating from [https://github.com/settings/applications](https://github.com/settings/applications) to use your `www.example.com` instead.

Having made those changes, run `flyctl deploy`. You should then be able to open `www.example.com` in your browser and sign in to the app.

## AWS?

I'll now see if I can deploy the Live Beats app to AWS. First I'll need to [create an AWS account](/docs/3-aws-create-account.md).

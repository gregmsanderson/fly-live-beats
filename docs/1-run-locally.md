# Run it locally

We started by cloning its repo `https://github.com/fly-apps/live_beats` into a local folder.

## Prerequisites

Phoenix is written in Elixir so to run it on your local machine you will need to have [Elixir installed](https://elixir-lang.org/install.html).

You will also need the Hex package manager to install its dependencies. To add/update that, run `mix local.hex`.

Confirm that worked by running `elixir -v`:

```sh
$ elixir -v
Erlang/OTP 25 [erts-13.1.4] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [jit:ns] [dtrace]

Elixir 1.14.3 (compiled with Erlang/OTP 25)
```

By default Phoenix uses PostgreSQL. If you don't already have it, [install Postgres](https://wiki.postgresql.org/wiki/Detailed_installation_guides).

To sign in to Fly Beats you will need a GitHub OAuth app. You can create one from [this page](https://github.com/settings/applications/new). Give it a name, set the homepage to `http://localhost:4000` and the authorization callback URL to `http://localhost:4000/oauth/callbacks/github`. Click the button. You will be shown its client ID. Click the button to _Generate a new client secret_. You can export them ready for the app to use in a moment:

```sh
export LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours"
export LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours"
```

## Prepare it

Install its dependencies by running `mix deps.get`.

If necessary, edit the database values in `config/dev.exs`. However the defaults should work.

Create/migrate your database by running `mix ecto.setup`.

## Run it

Start the server: `mix phx.server`. It may take a couple of minuutes to compile.

Open `http://localhost:4000` in your browser. You should see the sign in screen. Click the button to sign in. The app should authenticate you using your GitHub OAuth client ID/secret and redirect you back to `http://localhost:4000` where you should see your GitHub name/email.

Once done, stop the server (usually `Ctrl+C`).

Now let's try containerizing the app to ensure we can run that before we upload anything to an external service.

## Run it locally (containerized)

Of course for _this_ part you will need to have Docker. You can install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or an equivalent such as [Rancher Desktop](https://rancherdesktop.io/)). That will install the `docker` command (or the equivalent, `nerdctl`) and run the Docker daemon.

Let's now build an image from the provided `Dockerfile`. That may take a few minutes but subsequent builds will be much faster:

```sh
$ docker build -t live_beats .
[+] Building
=> [internal] load metadata for docker.io/hexpm/elixir:1.12.0-erlang-24.0.1-debian-bullseye-20210902-slim
...
```

Let's confirm that worked by checking the images:

```sh
$ docker images
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
live_beats   latest    67d44611e0f1   30 seconds ago   119MB
```

Great! We have an image.

Now let's try running a container. We'll need to specify the port (the default is `4000`). To avoid any privilege issues (with ports under 1024), we'll simply expose the same port on our machine.

We'll use the `-it` flag to run it in interactive mode. That means the output is shown within the terminal. You could instead use `-d` which would avoid that and run the container in the background.

The `--rm` flag means the container will be removed when it’s stopped, which is fine as that saves us having to.

We also need to tell the container the OAuth variables for the GitHub app. We can pass in environment variables using the `-e` flag:

```sh
$ docker run --rm -it -p 4000:4000 -e LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours" -e LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours" live_beats:latest
Can't set long node name!
Please check your configuration
```

Ah ... it crashes. That's because this particular app was written to be deployed on Fly.io.

If you have the cloned repo from `fly-apps` (as opposed to the modified copy of it in _this_ repo), you can see that in `/rel/env.sh.eex` it expects to get the IP using Fly's network. We don't have that. It also references an environment variable provided by Fly.io: `FLY_APP_NAME`:

```sh
ip=$(grep fly-local-6pn /etc/hosts | cut -f 1)
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=$FLY_APP_NAME@$ip
export LIVE_BEATS_SERVER_IP=$ip
```

So we'll modify that file, commenting out that part and replacing it with a more general form (you can see at the bottom we also might want to show the IP in the logs to confirm it is correct, hence that extra line):

```sh
##### original (it was written to deploy to Fly.io) #####
#ip=$(grep fly-local-6pn /etc/hosts | cut -f 1)
#export RELEASE_DISTRIBUTION=name
#export RELEASE_NODE=$FLY_APP_NAME@$ip
#export LIVE_BEATS_SERVER_IP=$ip
##### modified (for local/AWS) #####
ip=$(hostname -i)
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=app@$ip
export LIVE_BEATS_SERVER_IP=$ip
#echo "LIVE_BEATS_SERVER_IP is $LIVE_BEATS_SERVER_IP"
```

When running outside Fly.io, we won't have a provided `FLY_APP_NAME`. So comment out the check for it in `config/runtime.exs` else it won't let us run the app locally or (in future) elsewhere:

```sh
 ##### original (it was written to deploy to Fly.io) #####
  #app_name =
  #  System.get_env("FLY_APP_NAME") ||
  #    raise "FLY_APP_NAME not available"
  ##### modified (for local/AWS) #####
  app_name = "app"
```

At the end of `/config/runtime.exs` you'll see it is using `fly6pn`. That will need to go but since we are not using clustering locally we should be ok with that left in. On another cloud, like AWS, that would have to be changed.

**Optional:** There are two `.svg` URLs using `https://fly.io` in the original Live Beats app. Those do not break the app from running however they _do_ currently 404 and so we might as well just remove them too. Look for references to `https://fly.io/ui/images/#{@region}.svg`. There is one in `lib/live_beats_web/channels/presence.ex` and another in `lib/live_beats_web/components/layouts/live.html.heex`. We might as well remove those too.

Having made those changes we'll rebuild the image. This should be much faster than before:

```sh
$ docker build -t live_beats .
```

Let's try running that:

```sh
docker run --rm -it -p 4000:4000 -e LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours" -e LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours" live_beats:latest
```

You _may_ see this error:

```
Protocol 'inet6_tcp': register/listen error: eaddrnotavail
```

If you scroll down to the end of the `Dockerfile`, you'll see the original Live Beats app uses IPv6. Which makes sense, as Fly.io provide each user with a private network which does support IPv6. If using IPv6 is not possible (a default AWS VPC also does not enable IPv6) make sure these two lines are commented out:

```sh
##### modified (for local/AWS) #####
#ENV ECTO_IPV6="true"
#ENV ERL_AFLAGS="-proto_dist inet6_tcp"
```

... and do another build (this should only take a couple of seconds as the change was so small):

```sh
$ docker build -t live_beats .
```

Ah. _Now_ it complains that it needs some more environment variables (it could previously get them from the hard-coded values in `dev.exs` when we ran it locally directly on the local machine). It will need both a `DATABASE_URL` and `SECRET_KEY_BASE`:

```sh
** (RuntimeError) environment variable DATABASE_URL is missing.
```

It recommends making the `SECRET_KEY_BASE` by running `mix phx.gen.secret`.

For the `DATABASE_URL` we already have Postgres installed locally. We can use the same database that's already been migrated. We can pass it as an environment variable. For example `DATABASE_URL="postgres://user:password@localhost:5432/database`. However there is a problem: using the hostname of `localhost` won't work. If we use that, we would see _this_ error in the terminal. The app would complain it can't connect to `localhost`:

```sh
(DBConnection.ConnectionError) tcp connect (localhost:5432): connection refused - :econnrefused
```

That makes sense. Postgres is not running inside the container. We want `localhost` to resolve to the host machine, but it doesn't. This is a common problem when running a container locally. There are a range of different approaches outlined in this extensive answer: [https://stackoverflow.com/a/24326540](https://stackoverflow.com/a/24326540)

In _my_ case I'm running on a Mac using Docker Desktop. That comes with a handy `host.docker.internal` hostname. That is _its_ solution to this problem. It lets you access the host machine from _within_ a running container. So update the `DATABASE_URL`. Also provide the required `SECRET_KEY_BASE`. Your command will look something like this:

```sh
docker run --name=live_beats --rm -it -p 4000:4000 -e LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours" -e LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours" -e DATABASE_URL="postgres://postgres:postgres@host.docker.internal:5432/live_beats_dev" -e SECRET_KEY_BASE="its-value" live_beats:latest
```

Now there should be no database errors in the console, meaning it can connect.

If your database can't connect you will probably see an error messages like: ` (DBConnection.ConnectionError)`. In which case check your Postgres is running/listening on the expected port 5432:

```sh
$ netstat -an -ptcp | grep LISTEN
tcp4       0      0  127.0.0.1.5432         *.*                    LISTEN
```

Note that it is listening on `127.0.0.1`. That _should_ work, however if you can't connect you could try* temporarily* changing it to listen to any address in `postgresql.conf`:

```sh
listen_addresses = '*'
#listen_addresses = 'localhost'
```

If so, make sure to restart Postgres and then run the container again. See if you are _now_ able to connect to your local database. If not, well that wasn't the issue and so switch your database back to only listening on `localhost`.

Assuming not, open `http://localhost:4000` in your browser. You should see the sign in page :rocket:.

However ... you _will_ likely see a panel complaining about the WebSocket failing or having to reconnect. Sure enough, in the terminal it shows an error:

```elixir
[error] Could not check origin for Phoenix.Socket transport.

Origin of the request: http://localhost:4000

This happens when you are attempting a socket connection to
a different host than the one configured in your config/
files. For example, in development the host is configured
to "localhost" but you may be trying to access it from
"127.0.0.1". To fix this issue, you may either:

  1. update [url: [host: ...]] to your actual host in the
     config file for your current environment (recommended)

  2. pass the :check_origin option when configuring your
     endpoint or when configuring the transport in your
     UserSocket module, explicitly outlining which origins
     are allowed:

        check_origin: ["https://example.com",
                       "//another.com:888", "//other.com"]
```

Let's fix that.

As the error says we _could_ edit the `config/prod.exs` file to include the hostname of our application. But we'd rather not hard-code that as part of the image. We'd have to rebuild and change it again when deploying to the cloud. Instead we'll pass the host and port as environment variables, `PHX_HOST` and `PORT`, respectively. Those will override the default values (currently set as `example.com`). Technically the port is not needed as it should default to using 4000 anyway:

```sh
docker run --rm -it -p 4000:4000 -e LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours" -e LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours" -e DATABASE_URL="postgres://postgres:postgres@host.docker.internal:5432/live_beats_dev" -e SECRET_KEY_BASE="its-value" -e PHX_HOST="localhost" -e PORT=4000 live_beats:latest
```

Let's switch back to the browser and reload the page.

The error has gone:

![No error](img/aws_local_docker_now_no_websocket_issue.jpeg)

If you are using Docker Desktop, in its UI you should see the container running locally:

![Docker desktop](img/aws_local_docker_running_container.jpeg)

We can confirm the websocket is working by opening the developer tools panel, checking the _Network_ tab, and sure enough there is now a row for the WebSocket request showing that was succesful.

Click the button to sign in with GitHub. It's still using the OAauth client ID/secret you previously created (when running the app on your local machine) and so those credentials will still work. After a second you are redirected back to the same URL, `http://localhost:4000`, now signed in:

![Live Beats](img/aws_local_docker_signed_in.jpeg)

The Live Beats app is now containerized and works :rocket:

Next we want to [deploy it to Fly.io](/docs/2-deploy-to-fly.md)

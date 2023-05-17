# Run it locally

Start by cloning the repo into a local folder.

## Prerequisites

Phoenix is written in Elixir and so _if_ you would like to run it directly on your local machine you will need to have [Elixir installed](https://elixir-lang.org/install.html).

You will also need the Hex package manager to install its dependencies. To add/update that, run `mix local.hex`.

Confirm that worked by running `elixir -v`:

```sh
$ elixir -v
Erlang/OTP 25 [erts-13.1.4] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [jit:ns] [dtrace]

Elixir 1.14.3 (compiled with Erlang/OTP 25)
```

By default Phoenix uses PostgreSQL. If you don't already have it, [install Postgres](https://wiki.postgresql.org/wiki/Detailed_installation_guides).

To sign in to _Live Beats_ you will need a GitHub OAuth app. You can create one from [https://github.com/settings/applications/new](https://github.com/settings/applications/new). Give it a name, set its homepage to `http://localhost:4000` and then its authorization callback URL to `http://localhost:4000/oauth/callbacks/github`. Click the button. You will be shown its client ID. Click the button below that to _Generate a new client secret_. You'll need to export them ready for the app to use in a moment:

```sh
export LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours"
export LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours"
```

## Prepare it

Install its dependencies by running `mix deps.get`.

If necessary, edit the database values in `config/dev.exs`. However the defaults should work.

Create/migrate your database by running `mix ecto.setup`.

## Run it

Start the server: `mix phx.server` (it may take a couple of minuutes to compile).

Once ready, open `http://localhost:4000` in your browser. You should see the sign in screen. Click the button to sign in. The app should authenticate you using your GitHub OAuth client ID/secret and redirect you back to `http://localhost:4000` where you should see your GitHub name/email.

Once done, stop the server (usually `Ctrl+\`).

Now let's try containerizing the app to ensure we can run that before we upload anything to an external service.

## Run it locally (containerized)

For _this_ part you will need to have Docker.

You can install [Docker Desktop](https://www.docker.com/products/docker-desktop/) or an equivalent such as [Rancher Desktop](https://rancherdesktop.io/). That will install the `docker` command (or the equivalent, `nerdctl`) and run the Docker daemon.

**Not:** The modified version of the app (in _this_ repo) should work. If you try and run the original Live Beats app, it probably wouldn't. It would expect e.g a `FLY_APP_NAME` to be present. To see why you might like to take a look at the [changes I made to it](/docs/misc-changes-to-the-app.md).

Let's build an image from the provided `Dockerfile`. That may take a few minutes:

```sh
$ docker build -t fly-live-beats .
[+] Building
=> [internal] load metadata for docker.io/hexpm/elixir:1.12.0-erlang-24.0.1-debian-bullseye-20210902-slim
...
```

Let's confirm that worked:

```sh
$ docker images
REPOSITORY       TAG       IMAGE ID       CREATED          SIZE
fly-live-beats   latest    12345          30 seconds ago   119MB
```

Great! We have an image.

We _already_ have a GitHub OAuth app (we can re-use the one we made earlier since the container will also run at `http://localhost:4000`).

We need to provide some more environment variables:

- A `PHX_HOST`. If we don't set this, the WebSocket will throw an error when we load it in the browser. The app needs the know its hostname. Locally that is `localhost`.

- A `SECRET_KEY_BASE`. To get that, Phoenix recommends running `mix phx.gen.secret`.

- A `DATABASE_URL`. We already have Postgres installed locally. We can use the same database that's already been migrated. So in theory we could use `DATABASE_URL="postgres://user:password@localhost:5432/database`. However using `localhost` won't work. Postgres is not running inside the container. We want `localhost` to resolve to the host machine. This is a common problem when running a container locally. There are a range of different approaches outlined in this extensive answer: [https://stackoverflow.com/a/24326540](https://stackoverflow.com/a/24326540). In _my_ case I'm running on a Mac using Docker Desktop. That comes with a handy `host.docker.internal` hostname. That is _its_ solution to this problem. It lets you access the host machine from _within_ a running container.

Now try running a container.

Specify the port to expose (`4000`).

The `-it` flag runs it in interactive mode. That means the output is shown within the terminal. You could instead use `-d` which would avoid that and run the container in the background.

The `--rm` flag means the container will be removed when it’s stopped, which is fine as that saves us having to.

```sh
docker run --rm -it -p 4000:4000 -e LIVE_BEATS_GITHUB_CLIENT_ID="swap-this-for-yours" -e LIVE_BEATS_GITHUB_CLIENT_SECRET="swap-this-for-yours" -e DATABASE_URL="postgres://postgres:postgres@host.docker.internal:5432/live_beats_dev" -e SECRET_KEY_BASE="its-value" -e PHX_HOST="localhost" fly-live-beats:latest
```

Let's switch back to the browser and reload the page. It works!

![No error](img/aws_local_docker_now_no_websocket_issue.jpeg)

Click the button to sign in with GitHub. You may be asked to sign in to GitHub, or approve the application. After a second you should be redirected back to the same URL, `http://localhost:4000`, now signed in:

![Live Beats](img/aws_local_docker_signed_in.jpeg)

The Live Beats app is now running, containerized :rocket:

**Note:** If you are using Docker Desktop, in _its_ UI you should also see the container running locally:

![Docker desktop](img/aws_local_docker_running_container.jpeg)

You can stop the container using `Ctrl+C`.

Next we want to [deploy it to Fly.io](/docs/2-deploy-to-fly.md)

# Changes to the app

The original [Live Beats](https://github.com/fly-apps/live_beats) app was written to be deployed on Fly.io. As such it makes various understandable assumptions (such as IPv6 is available) and that certain variables will be present (such as `FLY_APP_NAME`).

To deploy it elsewhere (in my case to AWS), some changes needed to be made. In the code I should have marked them with a comment (something like `# modified for AWS`). Exactly which of these changes _you_ need to make will naturally vary depending upon where you are deploying _your_ app.

### Dockerfile

The original `Dockerfile` references IPv6. These lines were removed since locally I do not have IPv6 and the default AWS VPC also does not have IPv6 enabled:

```sh
ENV ECTO_IPV6="true"
ENV ERL_AFLAGS="-proto_dist inet6_tcp"
```

If those two lines _are_ present, you would likely see _this_ error when you tried to run it:

```sh
Protocol 'inet6_tcp': register/listen error: eaddrnotavail
```

### mix.exs

In order for the nodes to communicate, there needs to be some way for them to know about each other. I tried a [variety of approaches](/docs/10-aws-phoenix-clustering.md), none worked, and so ended up using a custom `libcluster` strategy. That meant adding a dependency.

**Note:** It is [not currently available on hex](https://github.com/pro-football-focus/libcluster_ecs/issues/1) so it needs to be fetched from its GitHub repo:

```elixir
defp deps do
    [
        ...
        {:libcluster_ecs, github: "pro-football-focus/libcluster_ecs"} # modified for AWS (added this strategy for libcluster on ECS)
    ]
```

### rel/env.sh.eex

When deployed to Fly.io the app can get its IP using the private network they provide. Locally (and on AWS) of course that is not available. The app needs to instead use `hostname -i` (there are other ways to do it, such as running `wget -qO- http://169.254.170.2/v2/metadata | jq -r .Containers[0].Networks[0].IPv4Addresses[0]` within a container on AWS ECS should _also_ return that same IP). That file _now_ contains:

```sh
# modified for AWS (no fly-local-6pn here)
ip=$(hostname -i)
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=live-beats@$ip
export LIVE_BEATS_SERVER_IP=$ip

#echo "This container is: $RELEASE_NODE"
```

### config/runtime.exs

The `FLY_APP_NAME` provided by Fly.io is not available. Replace that with a fixed `app_name`, such as `live-beats` (matching the value above).

```elixir
app_name = "live-beats"
```

The `LiveBeatsWeb.Endpoint` assumes listens on IPv6. Again, assume IPv6 is not available and so listen on IPv4:

```elixir
ip: {0, 0, 0, 0}
```

For serving files, the URL built for each locally-served .mp3 was simply `http://localhost/files ...`. That misses the (crucial) port. To solve that I added new variables set based on the value of `PHX_HOST`:

```elixir
files_port = if host == "localhost", do: 4000, else: 443
files_scheme = if host == "localhost", do: "http", else: "https"
```

Those were then used later on in that same file:

```elixir
host: [scheme: files_scheme, host: host, port: files_port],
```

_Now_ when .mp3 files are uploaded, the generated URL includes the correct port (the default is `4000`) and so they _do_ play. I adapted the `host` to use a variable, rather than a hard-coded string. And set IPv6 as `false`.

Finally, `libcluster`. If you provide the following three environment variables the nodes _should_ be able to discover each other. This does result in some warning messages when running the container locally, as you'd expect!

```elixir
config :libcluster,
    topologies: [
      ecs: [
        strategy: ClusterEcs.Strategy,
        config: [
          cluster: System.get_env("AWS_ECS_CLUSTER_NAME") || "",
          service_name: System.get_env("AWS_ECS_SERVICE_ARN") || "",
          region: System.get_env("AWS_ECS_CLUSTER_REGION") || "eu-west-2",
          app_prefix: app_name, # the bit before the @ in app-name@ip
          polling_interval: 10_000 # default is 5 seconds but can adjust as needed
        ]
      ]
    ]
```

### .svg

There were two `.svg` URLs using `https://fly.io` in the original Live Beats app. Those do not break the app from running however they _do_ currently return a `404` and so I might as well remove them. Look for references to `https://fly.io/ui/images/#{@region}.svg`. There is one in `lib/live_beats_web/channels/presence.ex` and another in `lib/live_beats_web/components/layouts/live.html.heex`.

### No WebSocket available?

Phoenix LiveView is built on top of Phoenix channels. You need _some_ form of bi-directional client/server messaging to send real-time updates back to the client, having been rendered on the server. The default is a WebSocket. However if that is not available (such as on [App Runner](https://aws.amazon.com/apprunner/)), it _can_ fallback to using long polling. That makes the client use regular HTTP requests to the server to see if there have been any changes.

However this particular app _also_ uses the WebSocket for uploading .mp3 files. That breaks when using long polling. You will see it throws an error when it parses the data. As such App Runner really is not a suitable service for _this_ app in its current form. But it may be for yours.

**For reference only** these are the changes that _probably_ would be made to at least get the updates part to work without a WebSocket:

In `/assets/js/app.js` would change:

```js
import { Socket } from "phoenix";
```

to

```js
import { Socket, LongPoll } from "phoenix";
```

And

```js
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
  dom: {
    onNodeAdded(node) {
      if (node instanceof HTMLElement && node.autofocus) {
        node.focus();
      }
    },
  },
});
```

to

```js
let liveSocket = new LiveSocket("/live", Socket, {
  transport: LongPoll,
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
  dom: {
    onNodeAdded(node) {
      if (node instanceof HTMLElement && node.autofocus) {
        node.focus();
      }
    },
  },
});
```

In `lib/live_beats_web/endpoint.ex` would change:

```elixir
socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
```

to

```elixir
socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]], longpoll: [connect_info: [session: @session_options]]
```

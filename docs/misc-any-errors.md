# Any errors?

This page lists some of the issues you may come across and some possible ways to fix them.

## Running locally?

##### Clustering does not work

You will likely see a lot of _these_ warnings:

```sh
15:59:13.292 [warn] [libcluster:ecs] ECS strategy is selected, but cluster is not configured correctly!
```

That's fine because in the `runtime.exs` file we expect the app to be run on AWS ECS and so use _its_ API calls. Those won't work when run in a container locally.

##### Database can't connect

If your database can't connect you will probably see an error messages like: ` (DBConnection.ConnectionError)`. Check your Postgres is running and listening on the expected port 5432:

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

##### WebSocket error

The app may show a red panel complaining about the WebSocket failing, or having to reconnect. Sure enough, in the terminal it shows an error:

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

The solution is to provide the hostname as an environment variable called `PHX_HOST`. For example `www.my-domain.com` (or whatever hostname your app can be accessed using).

## Running on AWS?

##### Database can't connect

If your database can't connect you will probably see an error messages like: ` (DBConnection.ConnectionError)`.

The first thing to check would be the "Monitoring" tab for your database in the RDS console. Check its CPU load, memory usage and connections. Does it appeaar overloaded? A temporary fix can be to increase its size. Longer-term that can be expensive though.

The smallest instances have a limited number of available connections. They can become exhaused. You can force the app to us fewer by setting an environment variable called `POOL_SIZE`. The default value is `10`. Temporarily try setting that as a lower number to make it open fewer connections.

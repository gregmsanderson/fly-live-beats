import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :live_beats, LiveBeatsWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  replica_database_url = System.get_env("REPLICA_DATABASE_URL") || database_url

  host = System.get_env("PHX_HOST") || "example.com"
  ecto_ipv6? = System.get_env("ECTO_IPV6") == "true"

  ##### original (it was written to deploy to Fly.io) #####
  #app_name =
  #  System.get_env("FLY_APP_NAME") ||
  #    raise "FLY_APP_NAME not available"
  ##### modified (for local) #####
  #app_name = "app"
  ##### modified (for AWS) #####
  #app_name = "app"

  config :live_beats, LiveBeats.Repo,
    # ssl: true,
    socket_options: if(ecto_ipv6?, do: [:inet6], else: []),
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :live_beats, LiveBeats.ReplicaRepo,
    # ssl: true,
    priv: "priv/repo",
    socket_options: if(ecto_ipv6?, do: [:inet6], else: []),
    url: replica_database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :live_beats, LiveBeatsWeb.Endpoint,
    url: [host: host, port: 80],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      # for Fly.io
      #ip: {0, 0, 0, 0, 0, 0, 0, 0},
      # for AWS (if VPC only uses IPv4)
      ip: {0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base

  config :live_beats, :files,
    admin_usernames: ~w(chrismccord mrkurt),
    # for Fly.io
    #uploads_dir: "/app/uploads",
    #host: [scheme: "https", host: host, port: 443],
    # for AWS (since currently using ephemeral storage, and our ALB is listening on port 80)
    uploads_dir: "/tmp",
    host: [scheme: "http", host: host, port: 80],
    server_ip: System.fetch_env!("LIVE_BEATS_SERVER_IP"),
    hostname: "livebeats.local",
    # for Fly.io
    #transport_opts: [inet6: true]
    # for AWS (our default VPC does not have IPv6 enabled)
    transport_opts: [inet6: false]

  config :live_beats, :github,
    client_id: System.fetch_env!("LIVE_BEATS_GITHUB_CLIENT_ID"),
    client_secret: System.fetch_env!("LIVE_BEATS_GITHUB_CLIENT_SECRET")

##### original (it was written to deploy to Fly.io) #####
#  config :libcluster,
#    topologies: [
#      fly6pn: [
#        strategy: Cluster.Strategy.DNSPoll,
#        config: [
#          polling_interval: 5_000,
#          query: "#{app_name}.internal",
#          node_basename: app_name
#        ]
#      ]
#    ]
##### modified (for local, which is N/A as no local cluster) #####
#  config :libcluster,
#    topologies: [
#      local: [
#        strategy: Cluster.Strategy.DNSPoll
#      ]
#    ]
##### modified (for AWS) #####
  config :libcluster,
    topologies: [
      ecs: [
        strategy: Cluster.Strategy.DNSPoll,
        config: [
          polling_interval: 2000,
          query: System.get_env("SERVICE_DISCOVERY_ENDPOINT", "ecs.local"),
          node_basename: System.get_env("NODE_NAME_QUERY", "node.local")
        ]
      ]
    ]
end

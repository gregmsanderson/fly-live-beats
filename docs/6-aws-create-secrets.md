# Deploy to AWS

The Live Beats app needs some values kept secret.

## Create secrets

AWS has two services for storing secrets: AWS Secrets Manager and AWS Parameter Store. I'll use the Parameter Store

In the AWS console, search for "Systems Manager" (it's found within there):

![AWS Systems Manager](img/aws_systems_manager_1.jpeg)

The "Parameter Store" option is in the left-hand menu. Click on that:

![AWS Parameter Store](img/aws_systems_manager_2.jpeg)

Now click the button to create a parameter.

You can structure its name however you prefer. I'll follow the convention `/stage-name/app-name/secret-name`. Using a path-style approach means you can (if you want) control access to secret values using IAM by specifying the secret's prefix (for example you could limit access to only `/staging/*` in the IAM policy and that would mean the app could not access production secrets).

For the tier, you can store up to 10,000 `Standard` parameters (which can be up to 4KB) for no additional charge. I'll use that tier for all of these.

This service is being used to store secret values and so for all of these choose the `SecureString` type. I'll use the AWS KMS key to encrypt the value (you can provide your own depending on your requirements). Finally, paste in our secret into the "Value' box.

This is an example for storing the expected `SECRET_KEY_BASE`. If you don't have a value for yours yet, the [Phoenix deployment guide](https://hexdocs.pm/phoenix/deployment.html) recommends running `mix phx.gen.secret` to get one:

![AWS secret 1](img/aws_systems_manager_secret_1.jpeg)

You should see a green panel to show that succeeded.

Next, create one called `/staging/fly-live-beats/database-url`. Its value should be a connection string of the form `postgres://username:password@your-long-rds-hostname/database-name`. That is the one you [created earlier for RDS](/docs/5-aws-create-database.md) assuming you created a user for the app within the `psql` shell.

Next, create one called `/staging/fly-live-beats/release-cookie`. What is that used for? Take a look at [https://fly.io/docs/elixir/the-basics/clustering/#the-cookie-situation](https://fly.io/docs/elixir/the-basics/clustering/#the-cookie-situation). I'll get a random value to use for that. In your terminal type `iex` and then `Base.url_encode64(:crypto.strong_rand_bytes(40))` as shown below:

```sh
$ iex
Erlang/OTP 25 [erts-13.1.4] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [jit:ns] [dtrace]

Interactive Elixir (1.14.3) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> Base.url_encode64(:crypto.strong_rand_bytes(40))
"xqvURmLqyA4qAyCOZ-iwIbBk2FVicmbxBMbmIF4xyTypN...=="
```

`Ctrl+\` and `exit`.

You also need to provide two secret parameters for the GitHub OAuth app.

If you _do_ already know what hostname your app is going to use (for example I'll use `www.your-domain.com`) you can go ahead and create a new GitHub OAuth app. You can create one from [https://github.com/settings/applications/new](https://github.com/settings/applications/new). Give it a name, set its homepage to `https://www.your-domain.com` and then its authorization callback URL to `https://www.your-domain.com/oauth/callbacks/github`. Click the button. You will be shown its client ID. Click the button below that to _Generate a new client secret_.

If you don't (you plan on just serving the app over HTTP, using the load balancer's hostname) well at this point we don't know what that will be. So you would need to use `placeholder` (for now) as the value for both.

Next, create one called `/staging/fly-live-beats/live-beats-github-client-id`. Its value should be the client ID, got from GitHub.

Next, create one called `/staging/fly-live-beats/live-beats-github-client-secret`. Its value should be the client secret, got from GitHub.

That should be all the secret values the Live Beats app needs. Others (like `PHX_HOST`) can be set in plain text and don't need to use Parameter Store.

Proceed to [create an image of the app](/docs/7-aws-create-image.md) that other AWS services can access.

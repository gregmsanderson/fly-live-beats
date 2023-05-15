# Deploy to AWS

## Secrets

We know the Live Beats app needs a few secret values.

To store secrets, AWS has two services: AWS Secrets Manager and AWS Parameter Store. We'll use the Parameter Store. It's free!

In the AWS console, search for "Systems Manager" (it is found within there):

![AWS Systems Manager](img/aws_systems_manager_1.jpeg)

The "Parameter Store" option is in the left-hand menu. Click on that:

![AWS Parameter Store](img/aws_systems_manager_2.jpeg)

Now click the button to create a parameter.

You can structure its name however you prefer. We follow the convention `/stage/app/secret-name`. Using a path-style approach means you can (if you want) control access to secret values using IAM by specifying the secret's prefix (for example you could limit access to only `/staging/*` in the IAM policy and that would mean the app could not access production secrets). We'll use that path-style approach.

For the tier, you can store up to 10,000 standard parameters (which can be up to 4KB) for no additional charge.

We are using this service to store secret values, encrypted, and so we'll choose the "SecureString" type. We can use the KMS key to encrypt the value (you can provide your own depending on your requirements). Finally we paste in our secret into the "Value' box.

This is an example for the `SECRET_KEY_BASE`. If you don't have one, the [Phoenix deployment guide](https://hexdocs.pm/phoenix/deployment.html) recommends running `mix phx.gen.secret`:

![AWS secret 1](img/aws_systems_manager_secret_1.jpeg)

You should see a green panel to show that succeeded.

Click the "create parameter" button again and next we will add one called `/staging/fly-live-beats/database-url`. That is the `DATABASE_URL`. It is of the form `postgres://username:password@the-long-rds-hostname/database`. That is the one you created earlier, when you created a user for the app within the `psql` shell

You now need to set the secrets for the OAuth GitHub app. However ... we don't _have_ that app. We can not create one yet since we do not now the hostname our app will be served from. Hmm. The app still expects _a_ value to be set, else it won't run. For now we'll set a "placeholder" string as its value. So make one called `/staging/fly-live-beats/live-beats-github-client-id` and then another one called `/staging/fly-live-beats/live-beats-github-client-secret`. We'll update them later once we _do_ have a GitHub app.

We now have all the secret values the Live Beats app needs. We can provide others (like `PHX_HOST`) in plain text later on. We don't need to use Parameter Store for those.

Let's proceed to [create an image of our app](/docs/6-aws-create-an-image.md) that other AWS services can access (since most only support ECR).

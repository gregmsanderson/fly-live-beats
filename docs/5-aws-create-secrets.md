# Deploy to AWS

## Secrets

We know the Live Beats app needs a few secret values. We could provide them to it in plain text, within the console, however that's not ideal. We'd rather they were stored encrypted.

To store secrets, AWS has two services: AWS Secrets Manager, and AWS Parameter Store. Each have their own benefits, but since ECS can fetch secret values from either one we'll use the Parameter Store.

So in the console, search for "Systems Manager" since it is found within there:

![AWS Systems Manager](img/aws_systems_manager_1.jpeg)

The Parameter Store option is in the left-hand menu. Click on that:

![AWS Parameter Store](img/aws_systems_manager_2.jpeg)

Now click the button to create a parameter.

You can structure the name however you prefer, how you might like to follow the convention `/stage/app/name`. Using a path-style approach means you can control access to secret values using IAM by specifying the prefix (for example `/production/*`). We'll use that path approach here.

First we need to set a `SECRET_KEY_BASE`. If you don't have one, the [Phoenix deployment guide](https://hexdocs.pm/phoenix/deployment.html) recommends running `mix phx.gen.secret`. So we'll do that.

Armed with that, we'll fill in the values in the AWS console, giving it that path-style name and providing a description. You can store up to 10,000 parameters which can be up to 4KB for no additional charge. Great, that's ideal. We'll leave "Standard" selected. Next we need to choose its type. We are using this service to store secret values, encrypted, and so we'll choose the "SecureString" type. We can use the KMS key to encrypt the value (you can provide your own depending on your requirements). Finally we paste in our secret into the "Value' box:

![AWS secret 1](img/aws_systems_manager_secret_1.jpeg)

You should see a green panel to show that succeeded.

Repeat that process three more times. Click the "create parameter" button, then provide a secret for these additional variables:

- The `DATABASE_URL`. That is of the form `postgres://username:password@rds-hostname/database`. That is the one you created earlier, when you created a user for the app within the `psql` shell. We'll call that `/staging/fly-live-beats/database-url`
- The `LIVE_BEATS_GITHUB_CLIENT_ID`. That is for the OAuth GitHub app. However ... we don't have one, and currently can not create one since we do not now the hostname our app will be served from. The app still expects _a_ value to be set though, else it won't run at all. For now we'll set a placeholder string. We'll call that `/staging/fly-live-beats/live-beats-github-client-id`. When we _do_ know what the app's hostname is, we can make a GitHub OAuth app, and then swap in this value.
- The `LIVE_BEATS_GITHUB_CLIENT_SECRET`. That is for the OAuth GitHub app. However ... we don't have one, and currently can not create one since we do not now the hostname our app will be served from. The app still expects _a_ value to be set though, else it won't run at all. For now we'll set a placeholder string. We'll call that `/staging/fly-live-beats/live-beats-github-client-secret`. When we _do_ know what the app's hostname is, we can make a GitHub OAuth app, and then swap in this value.

Great! We now have the secret values the app needs. We can provide others, like `PHX_HOST`, in plain text later on so we don't need to use Parameter Store for those.

Let's [create an image of our app](/docs/6-aws-create-an-image.md) that other AWS services can access (most only support ECR).

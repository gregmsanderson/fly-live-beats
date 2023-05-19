# Deploy to AWS

You will need an AWS account.

## Create an AWS account

If you _don't_ have any AWS account, create a new one from [https://aws.amazon.com/](https://aws.amazon.com/). Click the button to create a new AWS account. You will be asked for your email address and to give your account a name.

Even if you _do_ already have an AWS account, it's **strongly** recommended to use a brand new AWS account for this guide. [It is best practice](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/benefits-of-using-multiple-aws-accounts.html). You always want to limit the impact of adverse events. Using separate AWS accounts (staging, production and development ...) should ensure you can not inadvertently affect a resource. Plus, a new AWS account provides a natural billing boundary. To avoid having to provide separate payment details for every new AWS account, they recommend grouping them within the same [AWS Organization](https://aws.amazon.com/organizations/). You can then handle _all_ the billing from just _one_ account:

![AWS Organizations](img/aws_organizations_1.jpeg)

If you do not see the option to manage the organization within your AWS account, your account administrator may need to do this part for you.

Click the button to create a new account within that organization:

![AWS Organizations](img/aws_organizations_2.jpeg)

**Note:** You will need to enter a unique email address per AWS account. To save creating a new mailbox/user each time, some email providers support using an alias address. For example with Gmail you can append `+something` like `you+awstest@company.com`. We recommend sending a test email to your chosen address to make sure it works before using it.

The AWS account should be created within a couple of minutes. You may need to reload the page if you don't see it listed. Before leaving the page, make a note of the account number. You should see that in grey, next to its name. For example `123456778901`. You will use that to construct its sign in URL.

Sign out of _that_ AWS account as from now on you will be working within the _new_ AWS account.

## Sign in

Depending on how your AWS accounts are configured, you _may_ sign in using single sign-on (SSO) via your employer's identity provider. Or be using AWS's own [IAM Identity Center](https://aws.amazon.com/iam/identity-center/). AWS has recently added IAM Identity Center (replacing its AWS Single Sign-On) to let you control access to all AWS accounts within your AWS Organization in addition to external SAML-enabled applications.

In my case, I only need to access _one_ AWS account, have no need to access other applications, and have no identity provider to connect to. So I won't use that here.

For the purpose of this guide I'll assume you are using the standard sign-in page (using an email and password to authenticate yourself). So visit `https://NUMBER.signin.aws.amazon.com/console`, replacing `NUMBER` with that new 12-digit AWS account number noted above.

You may be initially prompted to sign in as an **IAM user**. If so, click the blue link to sign in as the new account's **root user** instead. You will only be using this root account once since it should only be used when it has to be:

![AWS sign in](img/aws_sign_in_root_1.jpeg)

Enter its email address (for example `you+awstest@company.com`) and click the blue **Next** button.

**Note:** If you have not yet been provided with a password (either by AWS, or your administrator) you can click the blue "Forgot password" link here. That will let you choose a new password:

![AWS sign in](img/aws_sign_in_root_2.jpeg)

You should now be signed in to AWS. However you are signed in as the **root user**. That account should only be used when it [absolutely has to be](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html):

> We strongly recommend that you do not use the root user for your everyday tasks, even the administrative ones

You will want to create a new user in this AWS account. For that, AWS provides Identity and Access Management (IAM).

AWS IAM lets administrators control access to AWS resources and services. Ideally you want to allow only the minimum access required, by region, service (such as _EC2_ or _S3_), and actions within a service (such as limiting to _GetObject_). Again, it limits the impact of adverse events or malicious actions.

## Create an IAM user

In the AWS console, click on _Security Credentials_:

![Users](img/aws_security_credentials_for_add_user.jpeg)

Click on _Users_ and then on the blue button to "Add users":

![Users](img/aws_iam_create_user_1.jpeg)

Enter your name (since you'll be using this account instead of the root one) and tick the box to allow console access. As mentioned above, AWS recommend using their new _Identity Center_ but I'll proceed on:

![Users](img/aws_iam_create_user_2.jpeg)

The next screen asks what the new user should be able to do. You'll see that the recommended option is to add them to a group, and specify the access within that group. You don't have to but I'll follow their advice. Go ahead and click the "Create group" button:

![Users](img/aws_iam_create_user_3.jpeg)

What level of access you grant (to yourself, as this is the user account you will be using in a moment) is up to you. If you know in advance what access you need, you can select the policies for just those services (again, it's best practice to limit access). In my case I know I'm going to be trying multiple services later (ACM, ECR, ECS, SSM, RDS, VPC ...) and so I'll pick the `AdministratorAccess` policy so that I can access all of them.

![Users](img/aws_iam_create_user_4.jpeg)

Create that group. Now it is listed as being available to add the new user to. Check the box:

![Users](img/aws_iam_create_user_5.jpeg)

Click _Next_, review the details and click the button to _Create User_. If necessary you can now retrieve the generated password (you may have instead opted to set your own). It goes without saying that you should keep any password safe and secret.

Now that I have an IAM user with sufficient access, I should not be using the root user's account. So sign out.

To sign back in as the IAM user, visit the same `https://NUMBER.signin.aws.amazon.com/console` (replacing `NUMBER` with that 12-digit AWS account number) and if you recall last time you were prompted to sign in as an IAM user, but back then didn't have one? Now you do! So enter the _name_ you gave the IAM user and the generated/chosen password, and click the button to sign in.

These are the credentials you will use to sign in to your AWS account to use its console.

**Optional:** You may want to assign MFA to add additional protection. You can use an authenticator app, security key or hardware token:

![MFA](img/aws_iam_assign_mfa.jpeg)

## AWS CLI

I will _mainly_ be using the AWS console however I will _also_ be using the AWS CLI (for example to get shell access to a container). So make sure you have the [latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

You can check which you have from your terminal:

```sh
$ aws --version
aws-cli/2.11.18 Python/3.11.3 Darwin/19.6.0 exe/x86_64 prompt/off
```

To use the AWS CLI you will need to be authenticated. From the AWS console, click on _Security Credentials_:

![Users](img/aws_security_credentials_for_add_user.jpeg)

Scroll down and click the button to create an access key:

![IAM access key](img/aws_iam_create_access_key.jpeg)

We are going to use the key for the CLI so select that option:

![IAM access key for CLI](img/aws_iam_select_cli.jpeg)

It's _better_ if you can use short-lived credentials. As it says, _ideally_ use IAM Identity Center in conjunction with the AWS CLI v2. Your organisation may already be doing that in conjunction with an identity provider. I'll proceed to create a new key.

Add a description for the key. That is a good idea to remind you of what it was used for (to know the impact of rotating/deleting it in future):

![IAM access key description](img/aws_iam_key_description.jpeg)

Click the button to proceed.

You should be shown _two_ values: the **Access key** and **Secret access key**. You need both of those values. They will only be shown once.

**Important:** As the console makes clear these values must be kept secret. They should never be stored in your code. They should also be deleted from AWS when no longer needed.

Once you have noted them, click "Done".

You can now use those credentials with the AWS CLI, giving you programmatic access to your AWS account. In your terminal type `aws configure`. It will prompt you for the access key ID (the one starting `AK`) and the secret access key. You may be asked to add a profile. That let's you store multiple credentials for different users/accounts, and provide a `--profile name` flag when using the CLI. If not specified, it will set them as the default profile.

For reference, the credentials file is stored at `~/.aws/credentials` on Linux/macOS, or `C:\Users\USERNAME\.aws\credentials` on Windows.

## VSCode

If you use VSCode, AWS [provide an extension](https://docs.aws.amazon.com/toolkit-for-vscode/latest/userguide/setup-toolkit.html) which lets you manage AWS resources within it:

![AWS toolkit](img/aws_toolkit_install.jpeg)

However for this guide I will only be using the AWS console and AWS CLI.

Next I'll [create a certificate](/docs/4-aws-create-certificate.md) for the app, using a custom domain.

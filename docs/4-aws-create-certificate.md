# Deploy to AWS

If you are just experimenting and _don't_ want to use HTTPS _or_ are using an external proxy (such as Cloudflare) to provide the certificate, you could skip this page. In which case you would need to use port `80` in place of `443` throughout the rest of the guide and use the load balancer's hostname.

In my case I want to do what I did on Fly.io: use HTTPS without needing to use Cloudflare's proxy (orange-cloud).

_Some_ AWS services will provide you with HTTPS without needing any additional configuration. For example if you deploy to AWS Lambda, you can ask for a [function URL](https://docs.aws.amazon.com/lambda/latest/dg/lambda-urls.html) like `https://<url-id>.lambda-url.<region>.on.aws`. AWS App Runner provides a TLS endpoint.

However when creating an [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html), upon selecting `HTTPS/443` for its listener, you are asked to pick an _existing_ certificate. Verifying domain ownership to issue a new certificate can take up to an hour (assuming you are not using AWS Route 53 for your DNS) so I figured it's best to do that first so it can be verifying in the background 🙂.

## Create a certificate

I'll assume you have a domain name already registered and have access to its DNS records.

Let's say I want to use the sub-domain `www.example.com` for this Live Beats app. I currently _don't_ have a certificate in ACM for it. But I need a certificate in order to use HTTPS when it comes to creating an Application Load Balancer. I'll request one.

Search for "ACM" in the console. Click "Request a certificate":

![ACM welcome](img/aws_acm_welcome.jpeg)

The only type available is a public one. Great, that's what I want. Click "Next".

Enter the domain name(s) it will be protecting. For example `www.example.com`. You can click the button below that _if_ you want to use it for other sub-domains too:

![ACM domain](img/aws_acm_domain.jpeg)

It's usually easiest to [validate using DNS](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html). That's the default option so that's fine. If you are using Route 53 for your domain, that is an AWS service and so this part should be automated. However I'm using an external DNS provider (Cloudflare) and so it needs to check.

Scroll down and click the "Request" button.

You should see it has been created. Its status will be "Pending validation" (you may need to click the refresh button).

Click on it to see what you need to do to verify it. If you scroll down the "Domains" section it will show you need to create a new `CNAME` record:

![ACM validation](img/aws_acm_validation.jpeg)

Create that CNAME using the service that provides your domain's nameservers. In my case, that's Cloudflare. So in the Cloudflare dashboard, I clicked the domain, and then on "DNS".

I'll click the blue button to add a new record to verify I do own that sub-domain.

As it says in ACM, its type should be `CNAME`. You can get the name and the target values to enter from the ACM's "Domains" panel (shown above).

**Important:** If you are using Cloudflare like me, make sure its proxy status is _off_ (a grey-cloud):

![Add record](img/aws_acm_add_record.jpeg)

Click "Save" to add that DNS record.

Now switch back to the ACM console. It _usually_ validates a new domain within an hour. If your certificate still shows as pending, take a look at their [troubleshooting page](https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-DNS-validation.html).

You can carry on with this guide while you wait. At some point it should validate your domain. It will then show as being issued.

While I wait I'll [create a database](/docs/5-aws-create-database.md) for the app.

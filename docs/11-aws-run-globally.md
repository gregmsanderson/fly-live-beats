# Run it globally on AWS

https://aws.amazon.com/blogs/networking-and-content-delivery/achieve-up-to-60-better-performance-for-internet-traffic-with-aws-global-accelerator/

from an answer
"the TCP connection is terminated at the AWS edge by AWS Global Accelerator (see blog post), while the HTTPS connection is terminated on the load balancer in the AWS Region. So you need certificates only at the load balancer level."

scroll 2/3 down this
https://dev.to/aws-builders/how-to-assign-static-ip-on-application-load-balancer-using-aws-global-accelerator-4chf

also on integrations tab of the alb, two ways to get it

# Pricing

TO DO

## Database

Fly postgres vs. AWS RDS for similar size of instance

## Load balancer

Fly is free

AWS. For WebSockets we'll need an Application Load Balancer. Their pricing is more complicated, using LCU. An LCU contains:

- 25 new connections per second.
- 3,000 active connections per minute.
- 1 GB per hour for Amazon Elastic Compute Cloud (EC2) instances, containers, and IP addresses as targets, and 0.4 GB per hour for Lambda functions as targets.
- 1,000 rule evaluations per second

## Registry

On Fly.io, storing and using private images is free.

On AWS you pay for the data needed to store and serve those images. Add that cost

## Bandwidth

Fly vs. AWS bandwidth costs e.g ELB->EC2

## Route 53

So [in conclusion](/docs/11-in-conclusion.md) ...

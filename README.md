# Fly Live Beats

Amazon Web Services (AWS) is the largest cloud provider in the world, with around a [third of the market share](https://www.srgresearch.com/articles/cloud-market-ends-2020-high-while-microsoft-continues-gain-ground-amazon). It dominates the market for running a container in the cloud. An estimaated [80 percent of cloud-hosted containers run on AWS](https://nucleusresearch.com/research/single/guidebook-containers-and-kubernetes-on-aws/). So it made sense to start there.

I tried deploying the same app, [Fly Beats](https://github.com/fly-apps/live_beats), to both Fly.io and AWS to compare the experience. It's a full-stack app including form validation, file uploads and navigation.

It uses **Phoenix LiveView** to provide a real-time experience _without_ needing JavaScript. HTML is rendered on the server. You don't need to manage the client. Changes are automatically tracked so the client is only sent the data it needs. This reduces latency, keeps the payload small and means the application can react faster.

The app has already been containerized (it has a `Dockerfile`). So we'll be looking for a service that we can deploy a container to.

But first we'll try [running it locally](/docs/1-run-locally.md).

# Fly Live Beats

Amazon Web Services (AWS) is the largest cloud provider in the world, with around a [third of the market share](https://www.srgresearch.com/articles/cloud-market-ends-2020-high-while-microsoft-continues-gain-ground-amazon). It dominates the market for running a container in the cloud. An estimaated [80 percent of cloud-hosted containers run on AWS](https://nucleusresearch.com/research/single/guidebook-containers-and-kubernetes-on-aws/). So it made sense to start there.

I tried deploying the same app to both Fly.io and AWS to compare the experience.

The app is [Live Beats](https://github.com/fly-apps/live_beats). It's a full-stack app including form validation, file uploads and navigation. It uses **Phoenix LiveView** to provide a real-time experience _without_ needing JavaScript. HTML is rendered on the server. Changes are automatically tracked so the client is only sent the data it needs. This reduces latency, keeps the payload small and means the application can react faster.

**Note:** The original [Live Beats](https://github.com/fly-apps/live_beats) app was written to run on Fly.io. So it you are deploying _there_, make sure to use _that_ code. If you are deploying to AWS, you would instead use the modified version of that app that's in _this_ repo. For reference you might like to [see the changes I've made](/docs/misc-changes-to-the-app.md) to it.

First I'll try [running Live Beats locally](/docs/1-run-locally.md).

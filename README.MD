# README
Hi,  
in the setup folder there is a `setup.sh` script where I tried to reproduce and describe all the steps needed to recreate the architecture, adding also commands in case your system is already configured (e.g.: Virtualbox machines already created).

I suggest to run the commands step by step instead of launching the script since some of them could heavily change your environment configuration.

For a matter of time I started the configuration for every step even if they're not working, in order to give an idea 
of my future path and to-do list.

---
The Docker Flow Monitor image provide a way to reconfigure Prometheus every time a new service is deployed. It uses Prometheus as a metrics storage and query engine.

**WIP**: Monitoring stack to collect metrics through a Prometheus service which will also generate notifications in case of high resource.
This will also be hooked to a Jenkins job (*service-scale*) to enable auto-scaling.  
Other notifications will be redirected on a [Slack channel](https://phoenix-bgc3988.slack.com/) I made for this project.

**TODO**: Jenkins job triggered by GIT push to rebuild server image, push it on docker hub and deploy it again on the virtual machines.


## Reliability
- Added re-triable connectivity to database
- Automated restart of nodes

## Performance
- Certificate generation is made at server start-up and stored on file-system

## Security
- Fixed dependencies security issues

## Automation
- Automated initial setup through docker-composer and Swarm
- TODO Jenkins CI/CD: 

## Monitoring
- A monitoring stack is provided where Prometheus is in charge of collecting metrics from the cluster, this should then 
be used to call a Jenkins job (service-scale) to scale up or down the web app in case some given condition is met.

# Solution steps
Hi,
in the setup folder there is a setup.sh script where I tried to reproduce all the steps needed to recreate the architecture, adding also commands in case your system is already configured (eg: virtualbox machines already created).

It may be better to run the commands step by step instead of just launching the script since.. work in progress :)

## Reliability
- Added retriable connectivity to database
- Automated restart of nodes

## Performance
- Certificate generation is made at server startup and stored on filesystem

## Security
- Fixed dependencies security issues

## Automation
- Automated initial setup through docker-composer
- TODO Jenkins Testing

## Monitoring
- A monitoring stack is provided where Prometheus is in charge of collecting metrics from the cluster, this should then 
be used to call a Jenkins job (service-scale) to scale up or down the web app in case some given condition is met.

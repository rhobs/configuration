## RHOBS post-deploy job

This directory includes definition for a post-deploy job that is supposed to be run after each deployment.
It consists of:
1) Post-deploy OpenShift job template (`post-deploy-job-template.yaml`) that is leveraged by AppSRE Interface. The usage is defined in an Saas file [here](https://gitlab.cee.redhat.com/service/app-interface/-/tree/master/data/services/rhobs/observatorium/cicd/saas-post-deploy-test.yaml).
2) Dockerfile to run the test in a container. The tests are based on the `up` Docker image, with few additions to be able to `curl` to obtain a bearer token for the test. The Docker image is built and pushed with help of AppSRE Interface integration, see the relevant [Jenkins config file]().
3) The actual test is specified in the `runtest.sh` script. Currently, this is a bare-bones, simple `up` run, which means the test will try to write a couple of requests and subsequently read those metrics.

To see the exact template usage, check the [Saas file definition](https://gitlab.cee.redhat.com/service/app-interface/-/tree/master/data/services/rhobs/observatorium/cicd/saas-post-deploy-test.yaml) in AppSRE Interface. The tests are currently set up to run only in `observatorium-stage`. So far, no automatic deployment promotion has been enabled, as we'll first test and assess how the post-deploy job is functioining in the staging environment.
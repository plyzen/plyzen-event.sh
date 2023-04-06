# plyzen-event.sh

## About

This repo contains tools for instrumenting your CI/CD pipeline to send data to [plyzen](https://plyzen.io).

[plyzen](https://plyzen.io) is a cloud-based process data analytics tool for software delivery stakeholders.
The SaaS solution can automate the collection and analysis of software delivery performance metrics.
It focuses on the four DORA (Four Key Metrics) metrics.

## Instrumenting the CI/CD Pipelines

In order to collect the metrics, events from the CI/CD pipelines (pipeline events) must be transmitted to plyzen. For this purpose, the pipelines are instrumented at appropriate points.

Each pipeline event (supported types: build, deployment, test) must be associated with a version of a software artifact in order to be evaluated.

For example, a simple pipeline event might look like this
```yaml
{
   "namespace": "narwhal",
   "artifact": "foo-api",
   "version": "2.1",
   "environment": "ci",
   "instance": "1",
   "activity": "build",
   "event": "finish",
   "timestamp": "2023-04-06T16:35:26.492Z",
   "result": "success"
}
```

Pipeline events are submitted to the plyzen ingest endpoint (https://in.plyzen.io).

To facilitate instrumentation, this repo provides two shell scripts.

### plyzen-event-basic.sh

Whenever you need to send an event related to exactly one version of a software artifact, use this script.

#### Example of instrumentation in Gitlab

```yaml
.build:
  stage: build
  extends:
    - .common
  variables:
    # ...
  before_script:
    - export APP_VERSION="$(next-version.sh).$CI_PIPELINE_ID"
    - echo "$APP_VERSION" | tee app.version
    # ...
    # clone plyzen repo
    - git clone --depth=1 https://github.com/plyzen/plyzen-event.sh.git plyzen
    # submit start event
    - plyzen/plyzen-event-basic.sh --namespace narwhal --artifact "$APP" --version "$APP_VERSION" --environment ci --instance "$CI_PROJECT_NAME/$CI_PIPELINE_ID" --activity build --event start --result success
  script:
    # ... here is where the build happens...
    # We need to remember whether the "script" block (i.e. the build) ran or aborted. In newer versions of GitLab you can simplify this with the CI_JOB_STATUS variable.
    - touch plyzen/build_successful
  after_script:
    # submit end event with "success" or "failure" to plyzen
    - plyzen/plyzen-event-basic.sh --namespace narwhal --artifact "$APP" --version "$(cat app.version)" --environment ci --instance "$CI_PROJECT_NAME/$CI_PIPELINE_ID" --activity build --event finish --result $(if test -f "plyzen/build_successful"; then echo "success"; else echo "failure"; fi)
```

#### Example of instrumentation in GoCD

```yaml
# ...
stages:
      - build:
          clean_workspace: true
          jobs:
            application:
              resources:
              - java11
              tasks:
              - exec:
                  # clone plyzen repo
                  command: sh
                  arguments:
                    - -c
                    - 'git clone --depth=1 -b master https://github.com/plyzen/plyzen-event.sh.git plyzen'
              - exec:
                  # submit start event
                  command: sh
                  arguments:
                    - -c
                    - 'plyzen/plyzen-event-basic.sh --namespace narwhal --artifact foo-api --version "$(cat version.txt)" --environment ci --instance "ci/$GO_PIPELINE_NAME" --activity build --event start --result success'
              # ... execute build tasks ...
              - exec:
                  # submit end event in case of success
                  command: sh
                  arguments:
                    - -c
                    - 'plyzen/plyzen-event-basic.sh --namespace narwhal --artifact foo-api --version "$(cat version.txt)" --environment ci --instance "ci/$GO_PIPELINE_NAME" --activity build --event finish --result success'
                  run_if: passed
              - exec:
                  # submit end event in case of error
                  command: sh
                  arguments:
                    - -c
                    - 'plyzen/plyzen-event-basic.sh --namespace narwhal --artifact foo-api --version "$(cat version.txt)" --environment ci --instance "ci/$GO_PIPELINE_NAME" --activity build --event finish --result failure'
                  run_if: failed
# ...
```

### plyzen-event-advanced.sh

Use this script whenever an event affects more than one software artifact.

This is usually the case later in the CI/CD pipeline when you deploy multiple services in one action.

Here we have a generated list of artifacts/versions (deployedVersions.txt) to deploy.
plyzen-event-advanced.sh can process this list and send it as events to plyzen.

```yaml
# ...
    stages:
      - inform-plyzen:
          clean_working_directory: yes
          resources:
            - docker
          tasks:
            - fetch:
                pipeline: prod-deploy-k8s
                stage: deploy-prod
                job: deploy-prod
                source: 'deployedVersions.txt'
                is_file: true
                run_if: passed
            - exec:
                # clone plyzen repo
                command: sh
                arguments:
                  - -c
                  - 'git clone --depth=1 -b master https://github.com/plyzen/plyzen-event.sh.git plyzen'
                run_if: passed
            - exec:
                # submit event
                command: sh
                arguments:
                  - -c
                  - 'plyzen/plyzen-event-advanced.sh --activitycorrelationid "prod-deploy/$GO_DEPENDENCY_LABEL_INFORM_PLYZEN_PROD_DEPLOY_START" --namespace narwhal --environment prod --instance "prod/1" --activityname "prod-deploy" --activitytype deployment --event finish --result success --artifactfile deployedVersions.txt'
                run_if: passed
```

### Start and finish events

plyzen can receive one `start` and one `finish` event for each event type (build, deployment, test) per version of an artifact and per environment.
Both or only one of the two events can be transmitted.

If plyzen has both events available, the duration of an activity can be determined.
If a `finish` event follows a previously transmitted `start` event for the same artifact, in the same version, in the same environment using plyzen-event-basic.sh, plyzen automatically establishes a correlation.
For plyzen-event-advanced.sh, this correlation must be done explicitly using a system-wide unique `activitycorrelationid`. This also allows to omit certain information (like the deployedVersions.txt) in one of the events (e.g. if it is not available in both events).

If a `start` event is not followed by a `finish` event, plyzen interprets this as a termination of the activity after a certain period of time.

## Configuration

The scripts can be configured via optional parameters or environment variables
```shell
--endpoint <url of the plyzen endpoint> # optional; defaults to "https://in.plyzen.io" or the value of the environment variable PLYZEN_ENDPOINT

--apikey <api key of the plyzen endpoint> # optional; defaults the value of the environment variable `PLYZEN_APIKEY` - using the env variable is recommended

--proxy <proxy url> # optional; defaults the value of the environment variable PLYZEN_PROXY
```

It is recommended to store these in environment variables like `PLYZEN_ENDPOINT`, `PLYZEN_APIKEY` and `PLYZEN_PROXY` globally to not have the plain values spread in your SCM.

## Install

1. plyzen-event.sh relies on [curl](https://curl.haxx.se) to post pipeline events to [plyzen](https://plyzen.io). It falls back to [wget](https://www.gnu.org/software/wget/), but some versions of wget do not support POST requests. So you may want to ensure that curl is installed on the machine that runs the script. Test with:
    ```
    curl --version
    ```
1. Download plyzen-event.sh:
    ```
    curl -L https://raw.githubusercontent.com/plyzen/plyzen-event.sh/master/plyzen-event.sh --output plyzen-event.sh
    ```
1. Make executable:
    ```
    chmod +x plyzen-event.sh
    ```
1. Set plyzen api key:
    ```
    export PLYZEN_APIKEY=<your api key>
    ```

## Usage

### Example call

```
./plyzen-event.sh --namespace foo --artifact bar --version 1.0 --stage test --activity deploy --event finish --result success
```

### Parameters

Call ./plyzen-event.sh with the following paramters:

--namespace \<project name\>
  
--artifact \<artifact name\>
  
--version \<artifact's version\>

--stage \<stage in the pipeline the event occurred\>
  
--instance \<instance of the stage in case there are multiple\> # optional; defaults to "1"
  
--activity \[build|deployment|test\]

--event \[start|finish\]

--timestamp \<timestamp in ISO 8601 format, e.g. 2020-09-25T09:37:40.000Z\> # optional; defaults to current timestamp as returned by "$(date -u +'%FT%T.000Z')"

--result \[success|failure\]

--endpoint \<url of the plyzen endpoint\> # optional; defaults to "https://in.plyzen.io" or the value of the environment variable PLYZEN_ENDPOINT
  
--apikey \<api key of the plyzen endpoint\> # optional; defaults the value of the environment variable PLYZEN_APIKEY - using the env variable is recommended

## Known issues

Does not work in Docker images [busybox](https://hub.docker.com/_/busybox) and [alpine](https://hub.docker.com/_/alpine), because their wget does not support `--method POST`.

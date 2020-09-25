# plyzen-event.sh

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

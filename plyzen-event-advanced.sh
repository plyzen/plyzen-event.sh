#!/bin/sh
set -e

# Source and documentation: https://github.com/plyzen/plyzen-event.sh

# Example call
# export PLYZEN_APIKEY=<your api key>
# ./plyzen-event.sh --namespace foo --artifact bar --version 1.0 --environment test --activity deploy --event finish --result success

DEFAULT_PLYZEN_ENDPOINT="https://in.plyzen.io/"

# HELP
usage() {
    echo "Call $0 with the following paramters:" >&2
    echo "--activitycorrelationid <global unique id to correlate multiple events with this activity>" >&2
    echo "--namespace <project name>" >&2
    echo "--artifact <artifact name>" >&2
    echo "--artifactfile <file containing a list of artifacts and versions; one pair per line separated by a single whitespace>" >&2
    echo "--version <artifact's version>" >&2
    echo "--environment <environment in the pipeline process the event occurred>" >&2
    echo "--activityname <name of the activity>" >&2
    echo "--activitytype [build|deployment|test]" >&2
    echo "--event [start|finish]" >&2
    echo "--timestamp <timestamp in ISO 8601 format, e.g. $(date -u +'%FT%T.000Z')> # optional; defaults to current timestamp as returned by \"\$(date -u +'%FT%T.000Z')\"" >&2
    echo "--result [success|failure]" >&2
    echo "--endpoint <url of the plyzen endpoint> # optional; defaults to \"https://in.plyzen.io\" or the value of the environment variable PLYZEN_ENDPOINT" >&2
    echo "--apikey <api key of the plyzen endpoint> # optional; defaults the value of the environment variable PLYZEN_APIKEY - using the env variable is recommended" >&2
    echo "--proxy <proxy url> # optional; defaults the value of the environment variable PLYZEN_PROXY" >&2
}

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--activitycorrelationid") set -- "$@" "-d" ;;
    "--namespace") set -- "$@" "-n" ;;
    "--artifact") set -- "$@" "-a" ;;
    "--artifactfile") set -- "$@" "-f" ;;
    "--version") set -- "$@" "-v" ;;
    "--environment") set -- "$@" "-s" ;;
    "--activityname") set -- "$@" "-c" ;;
    "--activitytype") set -- "$@" "-y" ;;
    "--event") set -- "$@" "-e" ;;
    "--timestamp") set -- "$@" "-t" ;;
    "--result") set -- "$@" "-r" ;;
    "--endpoint") set -- "$@" "-p" ;;
    "--apikey") set -- "$@" "-k" ;;
    "--proxy") set -- "$@" "-x" ;;
    "--help") set -- "$@" "-h" ;;
    -*) echo "Illegal argument ${arg}"; usage; exit 2;;
    *) set -- "$@" "$arg"
  esac
done

# Parse short options
while getopts ":d:n:a:f:v:s:c:y:e:t:r:p:k:x:" opt; do
  case $opt in
    d) ACTIVITYCORRELATIONID="$OPTARG"
    ;;
    n) NAMESPACE="$OPTARG"
    ;;
    a) ARTIFACT="$OPTARG"
    ;;
    f) ARTIFACTFILE="$OPTARG"
    ;;
    v) VERSION="$OPTARG"
    ;;
    s) ENVIRONMENT="$OPTARG"
    ;;
    c) ACTIVITYNAME="$OPTARG"
    ;;
    y) ACTIVITYTYPE="$OPTARG"
    ;;
    e) EVENT="$OPTARG"
    ;;
    t) TIMESTAMP="$OPTARG"
    ;;
    r) RESULT="$OPTARG"
    ;;
    p) ENDPOINT="$OPTARG"
    ;;
    k) APIKEY="$OPTARG"
    ;;
    x) PROXY="$OPTARG"
    ;;
    h) usage
       exit 1
    ;;
    \?) usage
        exit 1
    ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

# instance defaults to "default"
if [ -z "$NAMESPACE" ]; then
    NAMESPACE="default"
fi

# set current timestamp as default, if not provided
if [ -z "$TIMESTAMP" ]; then
    TIMESTAMP="$(date -u +'%FT%T.000Z')"
fi

# set default endpoint, if not provided
if [ -z "$ENDPOINT" ]; then
    if [ -z $PLYZEN_ENDPOINT ]; then
        ENDPOINT=$DEFAULT_PLYZEN_ENDPOINT
    else
        ENDPOINT=$PLYZEN_ENDPOINT
    fi
fi

# set default api key, if not provided
if [ -z "$APIKEY" ]; then
    APIKEY=$PLYZEN_APIKEY
fi

# set default proxy, if not provided
if [ -z "$PROXY" ]; then
    PROXY=$PLYZEN_PROXY
fi

# collect fail states
FAIL=false

# read stin for a list of artifacts in format
# <artifact name> <version>
# <artifact name> <version>
# <artifact name> <version>
# ...
if [ ! -z "$ARTIFACTFILE" ]; then
    if [ -e "$ARTIFACTFILE" ]; then
        while IFS='' read -r ARTIFACT_LIST_ELEMENT || [ -n "$ARTIFACT_LIST_ELEMENT" ]; do
            ARTIFACT_NAME="${ARTIFACT_LIST_ELEMENT%% *}"
            ARTIFACT_VERSION="${ARTIFACT_LIST_ELEMENT#* }"
            if [ -z "$ARTIFACT_JSON" ]; then
                # special treatment on the first iteration
                ARTIFACT_JSON="{
                        \"namespace\": \"$NAMESPACE\",
                        \"name\": \"$ARTIFACT_NAME\",
                        \"version\": \"$ARTIFACT_VERSION\"
                    }"
            else
                ARTIFACT_JSON="$ARTIFACT_JSON,
                    {
                        \"namespace\": \"$NAMESPACE\",
                        \"name\": \"$ARTIFACT_NAME\",
                        \"version\": \"$ARTIFACT_VERSION\"
                    }"
            fi
        done < "$ARTIFACTFILE"
    else
        echo "Artifact file does not exist: $ARTIFACTFILE" >&2
        FAIL=true
    fi
fi

# check for mandatory parameters
is_set() {
    if [ -z "$(eval echo \$$1)" ]; then
        lowercase_param=`echo $1 | tr '[:upper:]' '[:lower:]'`
        echo "Missing mandatory paramter --$lowercase_param" >&2
        FAIL=true
    fi
}

is_set "ACTIVITYCORRELATIONID"
is_set "NAMESPACE"
#is_set "ARTIFACT"
#is_set "VERSION"
is_set "ENVIRONMENT"
is_set "ACTIVITYNAME"
is_set "ACTIVITYTYPE"
is_set "EVENT"
is_set "TIMESTAMP"
#is_set "RESULT"
is_set "ENDPOINT"
is_set "APIKEY"

if $FAIL; then
    usage
    exit 2
fi

if [ ! -z "$RESULT" ]; then
    RESULT_JSON="\"result\": \"$RESULT\","
fi

if [ ! -z "$ARTIFACT_JSON" ]; then
    ARTIFACT_JSON="\"artifacts\": [
                $ARTIFACT_JSON
            ],"
fi

POST_BODY="{
    \"activities\": [
        {
            \"correlationId\": \"$ACTIVITYCORRELATIONID\",
            \"name\": \"$ACTIVITYNAME\",
            \"type\": \"$ACTIVITYTYPE\",
            \"events\": [
                {
                    \"type\": \"$EVENT\",
                    \"timestamp\": \"$TIMESTAMP\"
                }
            ],
            $RESULT_JSON
            $ARTIFACT_JSON
            \"environment\": {
                \"name\": \"$ENVIRONMENT\"
            }
        }
    ]
}"

echo "[plyzen] post body:"
echo $POST_BODY

if command -v curl &> /dev/null; then
    POST_RESPONSE=$(curl --silent --location --request POST "$ENDPOINT" \
        $(if [ ! -z "$PROXY" ]; then echo "-x $PROXY"; else echo ""; fi) \
        --header "Authorization: $APIKEY" \
        --header "Content-Type: application/json" \
        --data "$POST_BODY")
else
    echo "curl command could not be found. This scipt needs curl. Please install it."
    exit 2
fi

echo "[plyzen] response:"
echo $POST_RESPONSE
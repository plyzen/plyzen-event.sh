#!/bin/bash
set -e

# Source and documentation: https://github.com/plyzen/plyzen-event.sh

# Example call
# export PLYZEN_APIKEY=<your api key>
# ./plyzen-event.sh --namespace foo --artifact bar --version 1.0 --stage test --activity deploy --event finish --result success

DEFAULT_PLYZEN_ENDPOINT="https://in.plyzen.io/"

# HELP
usage() {
    echo "Call $0 with the following paramters:" >&2
    echo "--namespace <project name>" >&2
    echo "--artifact <artifact name>" >&2
    echo "--version <artifact's version>" >&2
    echo "--stage <stage in the pipeline the event occurred>" >&2
    echo "--instance <instance of the stage in case there are multiple> # optional; defaults to \"1\"" >&2
    echo "--activity [build|deployment|test]" >&2
    echo "--event [start|finish]" >&2
    echo "--timestamp <timestamp in ISO 8601 format, e.g. $(date -u +'%FT%T.000Z')> # optional; defaults to current timestamp as returned by \"\$(date -u +'%FT%T.000Z')\"" >&2
    echo "--result [success|failure]" >&2
    echo "--endpoint <url of the plyzen endpoint> # optional; defaults to \"https://in.plyzen.io\" or the value of the environment variable PLYZEN_ENDPOINT" >&2
    echo "--apikey <api key of the plyzen endpoint> # optional; defaults the value of the environment variable PLYZEN_APIKEY - using the env variable is recommended" >&2
}

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--namespace") set -- "$@" "-n" ;;
    "--artifact") set -- "$@" "-a" ;;
    "--version") set -- "$@" "-v" ;;
    "--stage") set -- "$@" "-s" ;;
    "--instance") set -- "$@" "-i" ;;
    "--activity") set -- "$@" "-c" ;;
    "--event") set -- "$@" "-e" ;;
    "--timestamp") set -- "$@" "-t" ;;
    "--result") set -- "$@" "-r" ;;
    "--endpoint") set -- "$@" "-p" ;;
    "--apikey") set -- "$@" "-k" ;;
    "--help") set -- "$@" "-h" ;;
    -*) echo "Illegal argument ${arg}"; usage; exit 2;;
    *) set -- "$@" "$arg"
  esac
done

# Parse short options
while getopts ":n:a:v:s:i:c:e:t:r:p:k:" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG"
    ;;
    a) ARTIFACT="$OPTARG"
    ;;
    v) VERSION="$OPTARG"
    ;;
    s) STAGE="$OPTARG"
    ;;
    i) INSTANCE="$OPTARG"
    ;;
    c) ACTIVITY="$OPTARG"
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
    h) usage
       exit 1
    ;;
    \?) usage
        exit 1
    ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

# instance defaults to "1"
if [ -z $INSTANCE ]; then
    INSTANCE="1"
fi

# set current timestamp as default, if not provided
if [ -z $TIMESTAMP ]; then
    TIMESTAMP="$(date -u +'%FT%T.000Z')"
fi

# set default endpoint, if not provided
if [ -z $ENDPOINT ]; then
    if [ -z $PLYZEN_ENDPOINT ]; then
        ENDPOINT=$DEFAULT_PLYZEN_ENDPOINT
    else
        ENDPOINT=$PLYZEN_ENDPOINT
    fi
fi

# set default api key, if not provided
if [ -z $APIKEY ]; then
    APIKEY=$PLYZEN_APIKEY
fi

# check for mandatory parameters
FAIL=false
is_set() {
    if [ -z ${!1} ]; then
        lowercase_param=`echo $1 | tr '[:upper:]' '[:lower:]'`
        echo "Missing mandatory paramter --$lowercase_param" >&2
        FAIL=true
    fi
}

is_set "NAMESPACE"
is_set "ARTIFACT"
is_set "VERSION"
is_set "STAGE"
is_set "INSTANCE"
is_set "ACTIVITY"
is_set "EVENT"
is_set "TIMESTAMP"
is_set "RESULT"
is_set "ENDPOINT"
is_set "APIKEY"

if $FAIL; then
    usage
    exit 2
fi

# cat << EOF
curl --location --request POST $ENDPOINT \
--header "x-api-key: $APIKEY" \
--header "Content-Type: application/json" \
--data-raw "{
    \"namespace\": \"$NAMESPACE\",
    \"artifact\": \"$ARTIFACT\",
    \"version\": \"$VERSION\",
    \"stage\": \"$STAGE\",
    \"instance\": \"$INSTANCE\",
    \"activity\": \"$ACTIVITY\",
    \"event\": \"$EVENT\",
    \"timestamp\": \"$TIMESTAMP\",
    \"result\": \"$RESULT\"
}"
# EOF
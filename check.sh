#!/bin/bash

# Usage:
#   ./check.sh postgres://user:pass@host:port/dbname {verify-full|verify-ca|require|prefer|allow|disable}"
DSN=${1:?"DSN needed"}
SSLMODE=${2:-"verify-full"}

case ${SSLMODE} in
    verify-full|verify-ca|require|prefer|allow|disable)
        # OK
        ;;
    *)
        echo "sslmode=${SSLMODE} not allowed.
        Usage: $0 <DSN> {verify-full|verify-ca|require|prefer|allow|disable}"
        exit 1
    ;;
esac

function loginfo {
    local _bold
    local _normal
    _bold=$( tput bold )
    _normal=$( tput sgr0 )
    echo "${_bold}${1}${_normal}"
}


STRETCH_IMAGE=ssl_issue_python_2_stretch
BUSTER_IMAGE=ssl_issue_python_2_buster

STRETCH_TAG=2-stretch
BUSTER_TAG=2-buster

loginfo "building images:"

loginfo "${STRETCH_IMAGE} based on python:${STRETCH_TAG} image..."
docker build --pull --build-arg python_tag=${STRETCH_TAG} -t ${STRETCH_IMAGE} .

loginfo "${BUSTER_IMAGE} based on python:${BUSTER_TAG} image..."
docker build --pull --build-arg python_tag=${BUSTER_TAG} -t ${BUSTER_IMAGE} .

# Add required connection options
SECURE_DSN="${DSN}?sslmode=${SSLMODE}&sslrootcert=rds-combined-ca-bundle.pem"
export SECURE_DSN

# Check psycopg2
PYTHON_COMMAND="import os, psycopg2;print psycopg2.connect(os.getenv('SECURE_DSN'))"

loginfo "checking psycopg2 connection on stretch (sslmode=${SSLMODE})..."
docker run -it --rm -e SECURE_DSN --entrypoint python ${STRETCH_IMAGE} \
    -c "${PYTHON_COMMAND}"

loginfo "checking psycopg2 connection on buster (sslmode=${SSLMODE})..."
docker run -it --rm -e SECURE_DSN --entrypoint python ${BUSTER_IMAGE} \
    -c "${PYTHON_COMMAND}"


# Check psql
PSQL_COMMAND="psql -c 'select * from pg_stat_ssl where pid in (select pg_backend_pid())' \${SECURE_DSN}"

loginfo "checking psql on stretch (sslmode=${SSLMODE})..."
docker run -it --rm -e SECURE_DSN --entrypoint bash ${STRETCH_IMAGE} \
    -c "${PSQL_COMMAND}"

loginfo "checking psql on buster (sslmode=${SSLMODE})..."
docker run -it --rm -e SECURE_DSN --entrypoint bash ${BUSTER_IMAGE} \
    -c "${PSQL_COMMAND}"


echo
loginfo "FIN. Now you may want to clean up the images, with:"
echo
echo "      docker image rm ${STRETCH_IMAGE} ${BUSTER_IMAGE}"
echo

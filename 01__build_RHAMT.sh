#!/bin/bash

# RHAMT github repository
# => "Maarc" is the report with the latest corrected rules
# => "windup" is the official repo
RHAMT_BASE_REPO="Maarc"
RHAMT_VERSION="4.1.0-SNAPSHOT"
# Master version
RHAMT_TAG=""
#RHAMT_TAG=${RHAMT_VERSION}  --> for a specific tag

# Current directory
DIR_CURRENT=$(pwd)

# Directory with the source code
DIR_GIT_CODE="${DIR_CURRENT}/01__RHAMT_code"
DIR_DIST="${DIR_CURRENT}/01__RHAMT"

# Maven build parameters
MVN_ARGS='-T 4 -U clean install'

# Clone the ${1} GitHub repostory.
function git_clone() {
  echo ">>> Checkout '${1}/${2}'"
  if [ -d "${DIR_GIT_CODE}/${2}" ]; then
    # git pull if the directory exists
    cd ${DIR_GIT_CODE}/${2}
    git pull
  else
    # otherwise full checkout
    cd ${DIR_GIT_CODE}
    git clone --depth 1 -b master "https://github.com/${1}/${2}.git"
    if [ -z ${3} ]; then
      echo "<<<"
    else
      cd ${DIR_GIT_CODE}/${2}
      git fetch && git fetch --tags
      echo "git checkout tags/${3}"
      git checkout tags/${3}
      echo "<<<"
    fi
  fi
}

# Builds the maven project in ${1} skipping the tests.
function mvn_t() {
  echo ">>> Build '$1' (without executing tests)"
  mvn -f ${DIR_GIT_CODE}/$1/pom.xml ${MVN_ARGS} -Dmaven.test.skip=true -DskipTests || { echo "Issue while executing 'mvnt' in $1"; kill -INT $$; }
}

# Builds the maven project in ${1} without skipping the tests.
function mvn_a() {
  echo ">>> Build '$1'"
  mvn -f ${DIR_GIT_CODE}/$1 ${MVN_ARGS} || { echo "Issue while executing 'mvna' in $1"; kill -INT $$; }
}

function main() {

  rm -Rf ${DIR_DIST}
  mkdir -p ${DIR_GIT_CODE} ${DIR_DIST}

  # Checkout source code from GitHub
  git_clone ${RHAMT_BASE_REPO} "tattletale-eap7"

  git_clone ${RHAMT_BASE_REPO} "windup-distribution" "${RHAMT_TAG}"

  git_clone ${RHAMT_BASE_REPO} "windup" "${RHAMT_TAG}"
  git_clone ${RHAMT_BASE_REPO} "windup-rulesets" "${RHAMT_TAG}"
  git_clone ${RHAMT_BASE_REPO} "windup-distribution" "${RHAMT_TAG}"

  mvn_a "tattletale-eap7/pom.xml"

  # Correct an issue with test dependencies in decompiler/api
  mvn_t "windup/bom"
  mvn_a "windup/utils/pom.xml"
  mvn_a "windup/pom.xml -pl decompiler -am"
  mvn_a "windup/decompiler/api/pom.xml"

  mvn_t "windup"
  mvn_t "windup-rulesets"
  mvn_t "windup-distribution"

  DIST=$(find -L ${DIR_GIT_CODE} -type f -name "rhamt-cli*.zip" -exec echo {} \;)
  echo ">>> RHAMT built successfully in ${DIST}"

  # Unpack the distribution
  unzip ${DIST} -d ${DIR_DIST}

  # Remove the intermediary "rhamt-cli-${RHAMT_VERSION}" directory
  mv ${DIR_DIST}/rhamt-cli-${RHAMT_VERSION}/* ${DIR_DIST}
  rm -Rf ${DIR_DIST}/rhamt-cli-${RHAMT_VERSION}

  cd ${DIR_CURRENT}
}

main

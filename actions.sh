#!/bin/bash

function do_build {

  local project=`pwd`
  local failed=false

  printf "\n${header}Starting package restoration & compilation...${nc}\n\n"

  # restore the nuget packages
  for location in $(find -name 'project.json' -printf '%h\n' | sort -u)
  do
    cd $project
    cd $location
    echo -Restoring for DNX in ${location}
    MONO_THREADS_PER_CPU=2000

    dnu restore
    if [[ $? != 0 ]]; then
      failed=true;
    fi

    MONO_THREADS_PER_CPU=100
  done
  cd $project

  # restore the npm packages
  for location in $(find -name 'package.json' -printf '%h\n' | sort -u | grep -v node_modules)
  do
    cd $project
    cd $location
    echo -Restoring with NPM in ${location}

    # ensure we have a user writeable directory for NPM global installations
    if [[ ! -a ~/.npm-global ]]; then
      mkdir ~/.npm-global 
      npm config set prefix '~/npm-global' 
      if [[ $? != 0 ]]; then
        failed=true;
      fi

      export PATH="~/npm-global/bin:${PATH}"
    fi

    npm install
    if [[ $? != 0 ]]; then
      failed=true;
    fi

    npm install -g typescript
    if [[ $? != 0 ]]; then
      failed=true;
    fi

    npm install -g bower
    if [[ $? != 0 ]]; then
      failed=true;
    fi

    npm install -g gulp
    if [[ $? != 0 ]]; then
      failed=true;
    fi
  done
  cd $project

  # restore the typescript packages
  for location in $(find -name 'tsd.json' -printf '%h\n' | sort -u)
  do
    cd $project
    cd $dir
    echo -Restoring for TypeScript in ${location}

    tsd restore
    if [[ $? != 0 ]]; then
      failed=true;
    fi
  done
  cd $project

  # restore the bower packages
  for location in $(find -name '.bowerrc' -printf '%h\n' | sort -u)
  do
    cd $project
    cd $location
    echo -Restoring with Bower in ${location}

    bower install
    if [[ $? != 0 ]]; then
      failed=true;
    fi
  done
  cd $project

  printf "\n${header}Building source...${nc}\n"

  # build using gulp
  for location in $(find -name 'gulpfile.js' -printf '%h\n' | sort -u)
  do
    cd $project
    cd $location
    echo -Building with Gulp in ${location}

    gulp default
    if [[ $? != 0 ]]; then
      failed=true;
    fi
  done
  cd $project

  if [ "$failed" = true ] ; then
    printf "\n${red}Failed build phase${nc}\n\n"
    exit 1;
  else
    printf "\n${green}Completed build phase${nc}\n\n"
  fi
}

function do_test {

  local project=`pwd`
  local failed=false

  printf "\n${header}Starting testing...${nc}\n\n"

  # test the .NET code
  for location in $(find -name 'project.json' -printf '%h\n' | sort -u | grep ./tests)
  do
    cd $project
    cd $location
    echo -Testing for DNX in ${location}

    dnx test
    if [[ $? != 0 ]]; then
      failed=true;
    fi
  done
  cd $project

  # TODO: test the JS code

  # TODO: test the TS code

  if [ "$failed" = true ]; then
    printf "\n${red}Failed testing phase${nc}\n\n"
    exit 1;
  else
    printf "\n${green}Completed testing phase${nc}\n\n"
  fi
}

function do_create {

  local failed=false

  printf "\n${header}Starting Docker image creation...${nc}\n"

  # We expect that when this script is ran for docker image creation that
  # there are some particular settings set prior to starting, or are given
  # on the command line when invoking it.

  # We require {team} {repo}, or take from git
  verify_repository

  printf "\n${header}Starting image creation...${nc}\n"
  docker build -t $DOCKER_TEAM/$DOCKER_REPO:build .
  if [[ $? != 0 ]]; then
    failed=true;
  fi

  printf "\n${header}Starting image optimization/layer-merging...${nc}\n"

  # Create image tagged 'latest'
  ID=$(docker run -d $DOCKER_TEAM/$DOCKER_REPO:build /bin/bash)
  docker export $ID | docker import - $DOCKER_TEAM/$DOCKER_REPO:latest
  if [[ $? != 0 ]]; then
    failed=true;
  fi

  # Create image tagged by git commit id
  TAG=$(git rev-parse --short HEAD)
  docker export $ID | docker import - $DOCKER_TEAM/$DOCKER_REPO:$TAG
  if [[ $? != 0 ]]; then
    failed=true;
  fi

  printf "\n${header}Starting image and container cleanup...${nc}"
  docker rm $(docker ps -l -q)
  if [[ $? != 0 ]]; then
    failed=true;
  fi

  docker rmi -f `docker images $DOCKER_TEAM/$DOCKER_REPO | grep "build" | awk 'BEGIN{FS=OFS=" "}{print $3}'`
  if [[ $? != 0 ]]; then
    failed=true;
  fi

  if [ "$failed" = true ] ; then
    printf "\n${red}Failed creation phase${nc}\n\n"
    exit 1;
  else
    printf "\n${green}Completed creation phase${nc}\n\n"
  fi
}

function do_deploy {

  local failed=false

  printf "\n${header}Starting Docker image deployment...${nc}"

  # We expect that when this script is ran for docker image deployment that
  # there are some particular settings set prior to starting, or are given
  # on the command line when invoking it.

  # We require {team} {repo}, or take from git
  verify_repository

  # We require {username} {password} {email}, or fail
  verify_authentication

  printf "\nRegistry authentication..."
  docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD -e $DOCKER_EMAIL
  if [[ $? != 0 ]]; then
    failed=true;
  fi

  printf "\nRegistry upload (latest)..."
  docker push -f $DOCKER_TEAM/$DOCKER_REPO:latest
  if [[ $? != 0 ]]; then
    failed=true;
  fi

  printf "\nRegistry upload (tagged)..."
  TAG=$(git rev-parse --short HEAD)
  docker push -f $DOCKER_TEAM/$DOCKER_REPO:$TAG
  if [[ $? != 0 ]]; then
    failed=true;
  fi

  if "$failed" = true; then
    printf "\n${red}Failed deploy phase${nc}\n\n"
    exit 1;
  else
    printf "\n${green}Completed deploy phase${nc}\n\n"
  fi
}

function verify_repository {
  if [ -n "$DOCKER_TEAM" ] && [ -n "$DOCKER_REPO" ]
    then
    echo -Using environment variables
  else
    if [ -n "$2" ] && [ -n "$3" ]
      then
      echo -Using script parameters
      DOCKER_TEAM=$2
      DOCKER_REPO=$3
    else
      echo -Using git information
      DOCKER_TEAM=`git remote show origin | grep "Fetch URL:" | sed "s#^.*/\(.*\)/\(.*\).git#\1#"`
      DOCKER_REPO=`git remote show origin | grep "Fetch URL:" | sed "s#^.*/\(.*\)/\(.*\).git#\2#"`
    fi
  fi
}

function verify_authentication {
  if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ] && [ -n "$DOCKER_EMAIL" ]
    then
    echo -Using environment variables
  else
    if [ -n "$4" ] && [ -n "$5" ] && [ -n "$6" ]
      then
      echo -Using script parameters
      DOCKER_USERNAME=$4
      DOCKER_PASSWORD=$5
      DOCKER_EMAIL=$6
    else
      printf "\n-Unable to continue, the following values were not provided:"
      printf "\n\tDOCKER_USERNAME\n\tDOCKER_PASSWORD\n\tDOCKER_EMAIL\n"

      printf "\n${red}Failed deploy phase${nc}\n\n"
      exit 1
    fi
  fi
}

# Console coloring
red='\033[0;31m'
green='\033[0;32m'
header='\033[0;34m'
nc='\033[0m' # No Color

# Determine what needs to be ran
case $1 in
  build)
  do_build
  ;;
  test)
  do_test
  ;;
  create)
  do_create
  ;;
  deploy)
  do_deploy
  ;;
  *)
  printf "\n"
  printf "Usage: $0 [OPTION]\n"
  printf "  OPTION            Performs...\n"
  printf "  ----------------  ----------------------------------------------------------\n"
  printf "  build             ...a compilation, if required\n"
  printf "  test              ...all tests in order of unit, integration, and functional\n"
  printf "  create            ...a Docker image\n"
  printf "  deploy            ...a Docker image\n"
  printf "\n"
  printf "The following values are required for the given commands:\n"
  printf "\n"
  printf "  $0 create [team] [repo]                                 ...or set:\n"
  printf "    \$DOCKER_TEAM\n"
  printf "    \$DOCKER_REPO\n"
  printf "\n"
  printf "  $0 deploy [team] [repo] [username] [password] [email]   ...or set:\n"
  printf "    \$DOCKER_TEAM\n"
  printf "    \$DOCKER_REPO\n"
  printf "    \$DOCKER_USERNAME\n"
  printf "    \$DOCKER_PASSWORD\n"
  printf "    \$DOCKER_EMAIL\n"
  printf "\n"
  ;;
esac

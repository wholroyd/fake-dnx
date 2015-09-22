#!/bin/bash

function do_build {

   current=`pwd`

   printf "\n${header}Starting package restoration...${nc}\n"

   # restore the nuget packages
   for dir in $(find -name 'project.json' -printf '%h\n' | sort -u)
   do
      cd $current
      cd $dir
      echo -Restoring for DNX in $(pwd)
      dnu restore
   done
   cd $current

   # restore the npm packages
   for dir in $(find -name 'package.json' -printf '%h\n' | sort -u | grep -v node_modules)
   do
      cd $current
      cd $dir
      echo -Restoring for NPM in $(pwd)
      npm install
      npm install -g bower
      npm install -g gulp
      npm install -g typescript
      npm install -g tsd
   done
   cd $current

   # restore the bower packages
   for dir in $(find -name '.bowerrc' -printf '%h\n' | sort -u)
   do
      cd $current
      cd $dir
      echo -Restoring for Bower in $(pwd)
      bower install --allow-root
   done
   cd $current

   printf "\n${header}Building source...${nc}\n"

   # restore the typescript typings
   for dir in $(find -name 'tsd.json' -printf '%h\n' | sort -u)
   do
      cd $current
      cd $dir
      echo Restoring for TypeScript in $(pwd)
      tsd restore
   done
   cd $current

   # build using gulp
   for dir in $(find -name 'gulpfile.js' -printf '%h\n' | sort -u)
   do  
      cd $current
      cd $dir
      echo Building for Gulp in $(pwd)
      gulp default
   done 
   cd $current

   printf "\n${green}Completed build phase${nc}\n"
}

function do_test {

   current=`pwd`

   printf "\n${header}Starting tests...${nc}\n"

   # restore the nuget packages
   for dir in $(find -name 'project.json' -printf '%h\n' | sort -u | grep ./tests)
   do
      cd $current
      cd $dir
      echo -Restoring for DNX in $(pwd)
      dnx test
   done
   cd $current

   printf "\n${green}Completed tests phase${nc}\n"
   
}

function do_create {

  printf "\n${header}Starting Docker image creation...${nc}\n"

  # We expect that when this script is ran for docker image creation that
  # there are some particular settings set prior to starting, or are given
  # on the command line when invoking it.

  # We require {team} {repo}, or take from git
  verify_repository

  docker build -t $DOCKER_TEAM/$DOCKER_REPO:build .

  printf "\n${header}Starting image optimization/layer-merging...${nc}\n"

  # Create image tagged 'latest'
  ID=$(docker run -d $DOCKER_TEAM/$DOCKER_REPO:build /bin/bash)
  docker export $ID | docker import - $DOCKER_TEAM/$DOCKER_REPO:latest

  # Create image tagged by git commit id
  TAG=$(git rev-parse --short HEAD)
  docker export $ID | docker import - $DOCKER_TEAM/$DOCKER_REPO:$TAG

  printf "\n${header}Starting image and container cleanup...${nc}\n"
  docker rm $(docker ps -l -q)
  docker rmi -f `docker images $DOCKER_TEAM/$DOCKER_REPO | grep "build" | awk 'BEGIN{FS=OFS=" "}{print $3}'`

  printf "\n${green}Completed creation phase${nc}\n\n"
}

function do_deploy {

  printf "\n${header}Starting Docker image deployment...${nc}\n"

  # We expect that when this script is ran for docker image deployment that
  # there are some particular settings set prior to starting, or are given
  # on the command line when invoking it.

  # We require {team} {repo}, or take from git
  verify_repository

  # We require {username} {password} {email}, or fail
  verify_authentication

  printf "\nRegistry authentication..."
  docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD -e $DOCKER_EMAIL

  printf "\nRegistry upload..."
  docker push $DOCKER_TEAM/$DOCKER_REPO:latest

  printf "\n${green}Completed deploy phase${nc}\n\n"
}

function do_clean {
  
  echo "not yet implemented"

}

function verify_repository {
  if [ -n "$DOCKER_TEAM" ] && [ -n "$DOCKER_REPO" ]
  then
    echo -Using environment variables for repository
  else
    if [ -n "$2" ] && [ -n "$3" ]
    then
      echo -Using script parameters for repository
      DOCKER_TEAM=$2
      DOCKER_REPO=$3
    else
      echo -Using git information for repository
      DOCKER_TEAM=`git remote show origin | grep "Fetch URL:" | sed "s#^.*/\(.*\)/\(.*\).git#\1#"`
      DOCKER_REPO=`git remote show origin | grep "Fetch URL:" | sed "s#^.*/\(.*\)/\(.*\).git#\2#"`
    fi
  fi
}

function verify_authentication {
  if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ] && [ -n "$DOCKER_EMAIL" ]
  then
    echo -Using environment variables for authentication
  else
    if [ -n "$4" ] && [ -n "$5" ] && [ -n "$6" ]
    then
      echo -Using script parameters for authentication
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
clean)
   do_clean
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
  printf "  clean             ...all things created or populated during build or test\n"
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

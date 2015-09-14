#!/bin/bash

function do_build {

   current=`pwd`

   echo
   echo Restoring packages...

   # restore the nuget packages
   for dir in $(find -name 'project.json' -printf '%h\n' | sort -u)
   do
      cd $current
      cd $dir
      echo Restoring for DNX in $(pwd)
      dnu restore
   done
   cd $current

   # restore the npm packages
   for dir in $(find -name 'package.json' -printf '%h\n' | sort -u)
   do
      cd $current
      cd $dir
      echo Restoring for NPM in $(pwd)
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
      echo Restoring for Bower in $(pwd)
      bower install
   done
   cd $current

   echo
   echo Building source...

   # restore the typescript typings
   for dir in $(find -name 'tsconfig.js' -printf '%h\n' | sort -u)
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

   echo
   echo Completed build phase 
   echo
}

function do_test {
   echo Test
   
}

function do_docker_build {
   echo Docker
}

function do_docker_deploy {
   echo Deploy
}

function do_universe {
   do_compile
   do_test
   do_docker_build
   do_docker_deploy
}

function do_galaxy {
   do_compile
   do_test
   do_docker_build
}

case $1 in
build)
   do_build
   ;;
test)
   do_test
   ;;
docker)
   do_docker_build
   ;;
deploy)
   do_docker_deploy
   ;;
universe)
   do_universe
   ;;
galaxy)
   do_galaxy
   ;;
*)
   echo ""
   echo "Usage: $0 [OPTION]"
   echo "    OPTION            Performs..."
   echo "    build             ...a compilation, if required"
   echo "    test              ...all tests in order of unit, integration, and functional"
   echo "    docker            ...a Docker image build"
   echo "    deploy            ...a Docker image push"
   echo "    "
   echo "    universe          ...in order the options: compile, test, docker, deploy"
   echo "    galaxy            ...in order the options: compile, test, docker"
   echo ""
   ;;
esac   

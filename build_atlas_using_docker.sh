#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

#This script creates the Docker image (if not already created) and runs maven in the container
#1. Install Docker
#2. Checkout Atlas source and go to the root directory
#3. Run this script. If host is linux, then run this script as "sudo $0 ..."
#4. If you are running on Mac, then you don't need to use "sudo"
#5. To delete the image, run "[sudo] docker rmi atlas_dev"

#Usage: [sudo] ./build_ranger_using_docker.sh [-build_image] mvn  <build params>
#Example 1: sudo ./build_ranger_using_docker.sh mvn clean install -DskipTests=true 
#Example 2: sudo ./build_ranger_using_docker.sh mvn -build_image clean install -DskipTests=true (rebuilds the image)
#Notes: To remove build image manually, run "docker rmi atlas_dev" or "sudo docker rmi atlas_dev"

build_image=0
if [ "$1" = "-build_image" ]; then
    build_image=1
    shift
fi

params=$*
if [ $# -eq 0 ]; then
    params=" mvn clean package -Pdist -DskipTests -X"
fi

image_name="atlas_dev"
remote_home=/root


if [ ! -d security-admin ]; then
    echo "ERROR: Run the script from root folder of source. e.g. $HOME/git/incubator-atlas"
    exit 1
fi

images=`docker images | cut -f 1 -d " "`
[[ $images =~ $image_name ]] && found_image=1 || build_image=1

if [ $build_image -eq 1 ]; then
    echo "Creating image $image_name ..."


docker build -t $image_name - <<Dockerfile
FROM centos

RUN mkdir /tools
WORKDIR /tools

#Install default services
#RUN yum clean all
RUN yum install -y wget
RUN yum install -y git
RUN yum install -y gcc


#Download and install JDK8 from Oracle
RUN wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-x64.rpm
RUN rpm -i jdk-8u101-linux-x64.rpm

ENV JAVA_HOME /usr/java/latest
ENV  PATH $JAVA_HOME/bin:$PATH


ADD https://www.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz.md5 /tools
ADD http://mirror.stjschools.org/public/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz /tools
RUN md5sum apache-maven-3.3.9-bin.tar.gz | cut -f 1 -d " " > tmp.md5

RUN diff -w tmp.md5 apache-maven-3.3.9-bin.tar.gz.md5

RUN tar xfz apache-maven-3.3.9-bin.tar.gz
RUN ln -sf /tools/apache-maven-3.3.9 /tools/maven

ENV  PATH /tools/maven/bin:$PATH
ENV MAVEN_OPTS "-Xmx2048m -XX:MaxPermSize=512m"

RUN chmod -R 777 /tools

Dockerfile

fi

src_folder=`pwd`

mkdir -p ~/.m2_docker
set -x
docker run --rm  -v "${src_folder}:/incubator-atlas" -w "/incubator-atlas" -v "${HOME}/.m2_docker:${remote_home}/.m2"  $image_name $params

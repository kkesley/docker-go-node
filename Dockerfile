# Copyright 2017-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file.
# This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or implied.
# See the License for the specific language governing permissions and limitations under the License.
#

FROM ubuntu:14.04.5

ENV DOCKER_BUCKET="download.docker.com" \
    DOCKER_VERSION="17.09.0-ce" \
    DOCKER_CHANNEL="stable" \
    DOCKER_SHA256="a9e90a73c3cdfbf238f148e1ec0eaff5eb181f92f35bdd938fd7dab18e1c4647" \
    DIND_COMMIT="3b5fac462d21ca164b3778647420016315289034" \
    DOCKER_COMPOSE_VERSION="1.16.1" \
    GITVERSION_VERSION="3.6.5"

# Building git from source code:
#   Ubuntu's default git package is built with broken gnutls. Rebuild git with openssl.
##########################################################################
RUN set -ex \
    && echo 'Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/99use-gzip-compression \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       wget=1.15-* python=2.7.5-* python2.7-dev=2.7.6-* fakeroot=1.20-* ca-certificates \
       tar=1.27.1-* gzip=1.6-* zip=3.0-* autoconf=2.69-* automake=1:1.14.1-* \
       bzip2=1.0.6-* file=1:5.14-* g++=4:4.8.2-* gcc=4:4.8.2-* imagemagick=8:6.7.7.10-* \
       libbz2-dev=1.0.6-* libc6-dev=2.19-* libcurl4-openssl-dev=7.35.0-* libdb-dev=1:5.3.21~* \
       libevent-dev=2.0.21-stable-* libffi-dev=3.1~rc1+r3.0.13-* libgeoip-dev=1.6.0-* libglib2.0-dev=2.40.2-* \
       libjpeg-dev=8c-* libkrb5-dev=1.12+dfsg-* liblzma-dev=5.1.1alpha+20120614-* \
       libmagickcore-dev=8:6.7.7.10-* libmagickwand-dev=8:6.7.7.10-* libmysqlclient-dev=5.5.60-* \
       libncurses5-dev=5.9+20140118-* libpng12-dev=1.2.50-* libpq-dev=9.3.22-* libreadline-dev=6.3-* \
       libsqlite3-dev=3.8.2-* libssl-dev=1.0.1f-* libtool=2.4.2-* libwebp-dev=0.4.0-* \
       libxml2-dev=2.9.1+dfsg1-* libxslt1-dev=1.1.28-* libyaml-dev=0.1.4-* make=3.81-* \
       patch=2.7.1-* xz-utils=5.1.1alpha+20120614-* zlib1g-dev=1:1.2.8.dfsg-* unzip=6.0-* curl=7.35.0-* \
       e2fsprogs=1.42.9-* iptables=1.4.21-* xfsprogs=3.1.9ubuntu2 xz-utils=5.1.1alpha+20120614-* \
       mono-mcs=3.2.8+dfsg-* \
    && apt-get install -y -qq less=458-* groff=1.22.2-* \
    && apt-get -qy build-dep git=1:1.9.1 \
    && apt-get -qy install libcurl4-openssl-dev=7.35.0-* git-man=1:1.9.1-* liberror-perl=0.17-* \
    && mkdir -p /usr/src/git-openssl \
    && cd /usr/src/git-openssl \
    && apt-get source git=1:1.9.1 \
    && cd $(find -mindepth 1 -maxdepth 1 -type d -name "git-*") \
    && sed -i -- 's/libcurl4-gnutls-dev/libcurl4-openssl-dev/' ./debian/control \
    && sed -i -- '/TEST\s*=\s*test/d' ./debian/rules \
    && dpkg-buildpackage -rfakeroot -b \
    && find .. -type f -name "git_*ubuntu*.deb" -exec dpkg -i \{\} \; \
    && rm -rf /usr/src/git-openssl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Download and set up GitVersion
RUN set -ex \
    && wget "https://github.com/GitTools/GitVersion/releases/download/v${GITVERSION_VERSION}/GitVersion_${GITVERSION_VERSION}.zip" -O /tmp/GitVersion_${GITVERSION_VERSION}.zip \
    && mkdir -p /usr/local/GitVersion_${GITVERSION_VERSION} \
    && unzip /tmp/GitVersion_${GITVERSION_VERSION}.zip -d /usr/local/GitVersion_${GITVERSION_VERSION} \
    && rm /tmp/GitVersion_${GITVERSION_VERSION}.zip \
    && echo "mono /usr/local/GitVersion_${GITVERSION_VERSION}/GitVersion.exe /output json /showvariable \$1" >> /usr/local/bin/gitversion \
    && chmod +x /usr/local/bin/gitversion
# Install Docker
RUN set -ex \
    && curl -fSL "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
    && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
    && tar --extract --file docker.tgz --strip-components 1  --directory /usr/local/bin/ \
    && rm docker.tgz \
    && docker -v \
# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
    && addgroup dockremap \
    && useradd -g dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid \
    && wget "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
    && curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/dind /usr/local/bin/docker-compose \
# Ensure docker-compose works
    && docker-compose version

# Install dependencies by all python images equivalent to buildpack-deps:jessie
# on the public repos.

RUN set -ex \
    && wget "https://bootstrap.pypa.io/2.6/get-pip.py" -O /tmp/get-pip.py \
    && python /tmp/get-pip.py \
    && pip install awscli \
    && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

VOLUME /var/lib/docker

COPY dockerd-entrypoint.sh /usr/local/bin/

ENV GOLANG_VERSION="1.10" \
    GOLANG_DOWNLOAD_SHA256="b5a64335f1490277b585832d1f6c7f8c6c11206cba5cd3f771dcb87b98ad1a33" \
    GOPATH="/go" \
    DEP_VERSION="0.4.1" \
    DEP_BINARY="dep-linux-amd64"

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" \
    && chmod -R 777 "$GOPATH" \
    && apt-get update && apt-get install -y --no-install-recommends \
        pkg-config=0.26-* \
    && apt-get clean \
    && wget "https://storage.googleapis.com/golang/go$GOLANG_VERSION.linux-amd64.tar.gz" -O /tmp/golang.tar.gz \
    && echo "$GOLANG_DOWNLOAD_SHA256 /tmp/golang.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/golang.tar.gz -C /usr/local \
    && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && wget "https://github.com/golang/dep/releases/download/v$DEP_VERSION/$DEP_BINARY" -O "$GOPATH/bin/dep" \
    && chmod +x "$GOPATH/bin/dep" \
    && ls /usr/local/go/bin/ \
    && ls $GOPATH/bin \
    && /usr/local/go/bin/go get github.com/aws/aws-lambda-go/lambda \
    && /usr/local/go/bin/go get github.com/aws/aws-sdk-go/aws

ENV NODE_VERSION="8.11.0"

RUN set -ex \
    && for key in \
      9554F04D7259F04124DE6B476D5A82AC7E37093B \
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
      0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 \
      FD3A5288F042B6850C66B31F09FE44734EB7990E \
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
      B9AE9905FFD7803F25714661B63B535A4C206CA9 \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    ; do \
      gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
    done

RUN wget "https://nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" -O node-v$NODE_VERSION-linux-x64.tar.gz \
	&& wget "https://nodejs.org/download/release/v$NODE_VERSION/SHASUMS256.txt.asc" -O SHASUMS256.txt.asc \
	&& gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
	&& grep " node-v$NODE_VERSION-linux-x64.tar.gz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xzf "node-v$NODE_VERSION-linux-x64.tar.gz" -C /usr/local --strip-components=1 \
    && rm "node-v$NODE_VERSION-linux-x64.tar.gz" SHASUMS256.txt.asc SHASUMS256.txt \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN npm i -g aws-sdk serverless webpack webpack-cli

ENV PATH="$GOPATH/bin:/usr/local/go/bin:$PATH"
WORKDIR $GOPATH

CMD [ "node" ]
ENTRYPOINT ["dockerd-entrypoint.sh"]
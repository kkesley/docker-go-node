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

FROM aws/codebuild/golang:1.11

#install node
ENV NODE_VERSION="10.14.1"

# gpg keys listed at https://github.com/nodejs/node#release-team
RUN set -ex \
    && for key in \
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
      B9AE9905FFD7803F25714661B63B535A4C206CA9 \
      77984A986EBC2AA786BC0F66B01FBB92821C587A \
      56730D5401028683275BD23C23EFEFE93C4CFFFE \
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
      FD3A5288F042B6850C66B31F09FE44734EB7990E \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
      4ED778F539E3634C779C87C6D7062848A1AB005C \
      A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    ; do \
      gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
      gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
    done

RUN set -ex \
	&& wget "https://nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" -O node-v$NODE_VERSION-linux-x64.tar.gz \
	&& wget "https://nodejs.org/download/release/v$NODE_VERSION/SHASUMS256.txt.asc" -O SHASUMS256.txt.asc \
	&& gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
	&& grep " node-v$NODE_VERSION-linux-x64.tar.gz\$" SHASUMS256.txt | sha256sum -c - \
		&& tar -xzf "node-v$NODE_VERSION-linux-x64.tar.gz" -C /usr/local --strip-components=1 \
		&& rm "node-v$NODE_VERSION-linux-x64.tar.gz" SHASUMS256.txt.asc SHASUMS256.txt \
		&& ln -s /usr/local/bin/node /usr/local/bin/nodejs \
		&& rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN npm set unsafe-perm true
RUN npm i -g aws-sdk serverless webpack webpack-cli

CMD [ "node" ]
ENTRYPOINT ["dockerd-entrypoint.sh"]
ARG ALPINE_VER="3.9"
FROM alpine:${ALPINE_VER} as fetch-stage

############## fetch stage ##############

# install fetch packages
RUN \
	apk add --no-cache \
		bash \
		curl \
		jq

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch source code
RUN \
	set -ex \
	&& mkdir -p \
		/opt/sabnzbd \
	&& SABNZBD_RELEASE=$(curl -sX GET "https://api.github.com/repos/sabnzbd/sabnzbd/releases/latest" \
	| jq -r .tag_name) \
	&& curl -o \
	/tmp/sabnzbd.tar.gz -L \
	"https://github.com/sabnzbd/sabnzbd/releases/download/${SABNZBD_RELEASE}/SABnzbd-${SABNZBD_RELEASE}-src.tar.gz" \
	&& tar xf \
	/tmp/sabnzbd.tar.gz -C \
	/opt/sabnzbd --strip-components=1

FROM alpine:${ALPINE_VER} as python-build-stage

############## python build stage ##############

# copy artifacts from fetch stage
COPY --from=fetch-stage /opt/sabnzbd /opt/sabnzbd

# set workdir
WORKDIR /opt/sabnzbd

# install build packages
RUN \
	apk add --no-cache \
		python2

# enable multi-language support
RUN \
	set -ex \
	&& python tools/make_mo.py

FROM alpine:${ALPINE_VER} as pip-stage

############## pip packages install stage ##############

# install build packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		binutils \
		g++ \
		libffi-dev \
		make \
		openssl-dev \
		py2-pip \
		python2-dev

# install pip packages
RUN \
	set -ex \
	&& pip install -U \
		cheetah3 \
		cryptography \
		sabyenc 

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# strip packages
RUN \
	set -ex \
	&& find usr/lib/python2.7/site-packages -type f | \
		while read -r files ; \
		do strip "${files}" || true \
	; done

# remove unneeded files
RUN \	
	set -ex \
	&& for cleanfiles in *.la *.pyc *.pyo; \
	do \
	find usr/lib/python2.7/site-packages -iname "${cleanfiles}" -exec rm -vf '{}' + \
	; done

FROM sparklyballs/alpine-test:${ALPINE_VER}

############## runtine stage ##############

# add par2 and unrar
# sourced from self builds here:- 
# https://ci.sparklyballs.com:9443/job/App-Builds/job/par2-build/
# and here :-
# https://ci.sparklyballs.com:9443/job/App-Builds/job/unrar-build/
# builds will fail unless you download a copy of the build artifacts and place in a folder called build
ADD /build/par2-*.tar.gz /build/unrar-*.tar.gz /usr/bin/

# add artifacts from build and pip stages
COPY --from=python-build-stage /opt/sabnzbd /opt/sabnzbd
COPY --from=pip-stage /usr/lib/python2.7/site-packages /usr/lib/python2.7/site-packages

# install runtime packages
RUN \
	set -ex \
	&& apk add --no-cache \
		libffi \
		libstdc++ \
		openssl \
		python2 \
		p7zip \
		unzip \
	\
# create symlinks for par2
	\
	&& ln -sf /usr/bin/par2 /usr/bin/par2create \
	&& ln -sf /usr/bin/par2 /usr/bin/par2repair \
	&& ln -sf /usr/bin/par2 /usr/bin/par2verify

# add local files
COPY root/ /

# ports and volumes
EXPOSE 8080 9090
VOLUME /config /downloads /incomplete-downloads

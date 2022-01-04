ARG ALPINE_VER="3.15"
FROM alpine:${ALPINE_VER} as fetch-stage

############## fetch stage ##############

# install fetch packages
RUN \
	apk add --no-cache \
		bash \
		curl

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch version file
RUN \
	set -ex \
	&& curl -o \
	/tmp/version.txt -L \
	"https://raw.githubusercontent.com/sparklyballs/versioning/master/version.txt"

# fetch source code
# hadolint ignore=SC1091
RUN \
	. /tmp/version.txt \
	&& set -ex \
	&& mkdir -p \
		/opt/sabnzbd \
	&& curl -o \
	/tmp/sabnzbd.tar.gz -L \
	"https://github.com/sabnzbd/sabnzbd/releases/download/${SABNZBD_RELEASE}/SABnzbd-${SABNZBD_RELEASE}-src.tar.gz" \
	&& tar xf \
	/tmp/sabnzbd.tar.gz -C \
	/opt/sabnzbd --strip-components=1

FROM alpine:${ALPINE_VER} as build-stage

############## build stage ##############

# copy artifacts from fetch stage
COPY --from=fetch-stage /opt/sabnzbd /opt/sabnzbd

# set workdir
WORKDIR /opt/sabnzbd

# install build packages
RUN \
	set -ex \
	&& apk add --no-cache \
		bash \
		binutils \
		cargo \
		g++ \
		libffi-dev \
		make \
		openssl-dev \
		py3-pip \
		python3-dev \
		rust

# install pip packages
RUN \
	set -ex \
	&& pip3 install --no-cache-dir -U \
		wheel \
	&& python3 \
		-m pip install \
		-r requirements.txt --no-cache-dir -U

# enable multi-language support
RUN \
	set -ex \
	&& python3 \
		tools/make_mo.py

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# strip packages
RUN \
	set -ex \
	&& find /usr/lib/python3.9/site-packages -type f | \
		while read -r files ; \
		do strip "${files}" || true \
	; done

# remove unneeded files
RUN \	
	set -ex \
	&& for cleanfiles in *.la *.pyc *.pyo; \
	do \
	find /usr/lib/python3.9/site-packages -iname "${cleanfiles}" -exec rm -vf '{}' + \
	; done

FROM sparklyballs/alpine-test:${ALPINE_VER}

############## runtine stage ##############

# add par2 and unrar
# sourced from self builds here:- 
# https://ci.sparklyballs.com:9443/job/App-Builds/job/par2-build/
# and here :-
# https://ci.sparklyballs.com:9443/job/App-Builds/job/unrar-build/
# builds will fail unless you download a copy of the build artifacts and place in a folder called build
ADD /build/par2-*.tar.gz /build/unrar-*.tar.gz /usr/bin/

# add artifacts from build stage
COPY --from=build-stage /opt/sabnzbd /opt/sabnzbd
COPY --from=build-stage /usr/lib/python3.9/site-packages /usr/lib/python3.9/site-packages

# install runtime packages
RUN \
	set -ex \
	&& apk add --no-cache \
		libffi \
		openssl \
		python3 \
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

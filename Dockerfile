ARG ALPINE_VER="3.9"
FROM alpine:${ALPINE_VER} as fetch-stage

############## fetch stage ##############

# install fetch packages
RUN \
	apk add --no-cache \
		bash \
		curl

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch source code
RUN \
	mkdir -p \
		/opt/sabnzbd \
	&& SABNZBD_RELEASE=$(curl -sX GET "https://api.github.com/repos/sabnzbd/sabnzbd/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]') || : \
	&& curl -o \
	/tmp/sabnzbd.tar.gz -L \
	"https://github.com/sabnzbd/sabnzbd/releases/download/${SABNZBD_RELEASE}/SABnzbd-${SABNZBD_RELEASE}-src.tar.gz" \
	&& tar xf \
	/tmp/sabnzbd.tar.gz -C \
	/opt/sabnzbd --strip-components=1

FROM alpine:${ALPINE_VER} as build-stage

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
	
FROM sparklyballs/alpine-test:${ALPINE_VER}

############## runtine stage ##############

# add par2
# sourced from self build here https://ci.sparklyballs.com:9443/job/Application-Builds/job/par2-build/
# builds will fail unless you download a copy of the build artifacts and place in a folder called build
ADD /build/par2-*.tar.gz /usr/bin/


# install build packages
RUN \
	apk add --no-cache --virtual=build-dependencies \
		g++ \
		libffi-dev \
		make \
		openssl-dev \
		py2-pip \
		python2-dev \
	\
# install pip packages
	\
	&& pip install -U \
		cheetah3 \
		cryptography \
		sabyenc \
	\
# uninstall build packages
	\
	&& apk del \
		build-dependencies \
	\
# install runtime packages
	\
	&& apk add --no-cache \
	libffi \
	openssl \
	python2 \
	p7zip \
	unrar \
	unzip \
	\
# create symlinks for par2
	\
	&& ln -sf /usr/bin/par2 /usr/bin/par2create \
	&& ln -sf /usr/bin/par2 /usr/bin/par2repair \
	&& ln -sf /usr/bin/par2 /usr/bin/par2verify \
	\
# cleanup
	\
	&& rm -rf \
	/root \
	/tmp/* \
	&& mkdir -p \
		/root


# add artifacts from fetch stage
COPY --from=fetch-stage /opt/sabnzbd /opt/sabnzbd

# add local files
COPY root/ /

# ports and volumes
EXPOSE 8080 9090
VOLUME /config /downloads /incomplete-downloads

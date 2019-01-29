FROM alpine as fetch-stage

# install fetch packages
RUN \
	apk add --no-cache \
		curl \
		python \
	\
# fetch source code
	\
	&& set -ex \
	&& mkdir -p \
		/opt/sabnzbd \
	&& SABNZBD_RELEASE=$(curl -sX GET "https://api.github.com/repos/sabnzbd/sabnzbd/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]') \
	&& curl -o \
	/tmp/sabmznd.tar.gz -L \
	"https://github.com/sabnzbd/sabnzbd/releases/download/${SABNZBD_RELEASE}/SABnzbd-${SABNZBD_RELEASE}-src.tar.gz" \
	&& tar xf \
	/tmp/sabmznd.tar.gz -C \
	/opt/sabnzbd --strip-components=1 \
	&& cd /opt/sabnzbd \
	\
# enable multi-language support
	\
	&& python tools/make_mo.py
	
FROM lsiobase/alpine:edge

# install build packages
RUN \
	apk add --no-cache --virtual=build-dependencies \
		g++ \
		libffi-dev \
		make \
		openssl-dev \
		py2-pip \
		python-dev \
	\
# install pip packages
	\
	&& set -ex \
	&& pip install -U \
		cheetah3 \
		cryptography \
		sabyenc \
	\
# uninstall build packages
	\
	&& apk del \
		build-dependencies \
	\
# install runtime packages
	\
	&& apk add --no-cache \
	libffi \
	openssl \
	python \
	p7zip \
	unrar \
	unzip \
	\
# install par2
	\
	&& wget --quiet -O /tmp/par2.tar.gz \
	https://ci.sparklyballs.com:9443/job/Application-Builds/job/par2-build/lastSuccessfulBuild/artifact/build/par2.tar.gz \
	&& tar xf \
	/tmp/par2.tar.gz -C \
	/usr/bin \
	&& ln -sf /usr/bin/par2 /usr/bin/par2create \
	&& ln -sf /usr/bin/par2 /usr/bin/par2repair \
	&& ln -sf /usr/bin/par2 /usr/bin/par2verify \
# cleanup
	\
	&& rm -rf \
	/root \
	/tmp/* \
	&& mkdir -p \
		/root

# add artifacts from fetch stage
COPY --from=fetch-stage /opt/sabnzbd /opt/sabnzbd

# add local files
COPY root/ /

# ports and volumes
EXPOSE 8080 9090
VOLUME /config /downloads /incomplete-downloads

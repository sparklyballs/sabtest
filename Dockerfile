FROM alpine as fetch-stage

# install fetch packages
RUN \
	apk add --no-cache \
		curl \
		python \
	\
# fetch source code
	\
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
# cleanup
	\
	&& rm -rf \
	/root \
	&& mkdir -p \
		/root

# add artifacts from fetch stage
COPY --from=fetch-stage /opt/sabnzbd /opt/sabnzbd
COPY root/ /

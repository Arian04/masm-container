# syntax = docker/dockerfile:1

# image args
ARG IMAGE=debian
ARG IMAGE_TAG=12

# constants
ARG BUILD_DIR=/build
ARG DEST_DIR=/out
ARG EXTRA_LIB_PATH=/irvine-lib
ARG FAKE_WINE_MENUBUILDER_NAME=fake-winemenubuilder

##### Irvine Library Downloader #####
FROM ${IMAGE}:${IMAGE_TAG} AS library_downloader

ARG EXTRA_LIB_PATH
ARG ZIP_CHECKSUM=sha256:91f08e4dacf517cbe14b08f9af5ac3cdd676dbab8e452671baa81443b3c0d881
ARG TMP_ZIP_PATH=/irvine.zip

# Install packages
RUN apt-get update \
	&& apt-get install -y \
	libarchive-tools \
	&& rm -rf /var/lib/apt/lists/*

ADD --checksum=${ZIP_CHECKSUM} \
	http://github.com/surferkip/asmbook/raw/main/Irvine.zip ${TMP_ZIP_PATH}
RUN mkdir ${EXTRA_LIB_PATH} && \
	bsdtar --strip-components=1 -xvf ${TMP_ZIP_PATH} -C ${EXTRA_LIB_PATH}

##### Build UASM #####
FROM ${IMAGE}:${IMAGE_TAG} AS uasm_builder

# Install packages
RUN apt-get update \
	&& apt-get install -y \
	git gcc make \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone https://github.com/Terraspace/UASM . && \
	git checkout 4dc0a4f96e2296c2e56c9224a2a0453c99470e2c
RUN make CC="gcc -fcommon" -f gccLinux64.mak && \
	mv GccUnixR/uasm /

# uasm binary is at /uasm

##### fake winemenubuilder #####
FROM ${IMAGE}:${IMAGE_TAG} AS fake-winemenubuilder

ARG FAKE_WINE_MENUBUILDER_NAME

# Install packages
RUN apt-get update \
	&& apt-get install -y \
	gcc-mingw-w64 \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /

RUN echo "int _start() { return 0; }" > ./${FAKE_WINE_MENUBUILDER_NAME}.c
RUN x86_64-w64-mingw32-gcc -nostdlib -static ${FAKE_WINE_MENUBUILDER_NAME}.c -o ${FAKE_WINE_MENUBUILDER_NAME}.exe

##### Program Builder/Runner #####
FROM ${IMAGE}:${IMAGE_TAG} as runtime_base

# constants
ARG BUILD_DIR
ARG DEST_DIR
ARG EXTRA_LIB_PATH
ARG FAKE_WINE_MENUBUILDER_NAME
ARG USERNAME=wineuser

# env vars that the script reads in
ENV EXTRA_LIB_PATH=${EXTRA_LIB_PATH}
ENV WINE_PREFIX_PATH=/wine

# Install packages
RUN dpkg --add-architecture i386 \
	&& sed -i 's/^Components: main$/& contrib non-free/' /etc/apt/sources.list.d/debian.sources \
	&& apt-get update \
	&& apt-get install -y \
	bash \
	wine \
	winetricks \
	wine32 \
	wine64 \
	libwine \
	libwine:i386 \
	fonts-wine \
	winbind \
	mingw-w64 \
	&& rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /bin/bash ${USERNAME}

# Create directories before switching to non-root user
RUN mkdir ${BUILD_DIR} ${DEST_DIR} ${WINE_PREFIX_PATH} && \
	chown ${USERNAME}:${USERNAME} ${BUILD_DIR} ${DEST_DIR} ${WINE_PREFIX_PATH}

# Switch to non-root user
USER ${USERNAME}

# Create wine prefix
ENV WINE_LARGE_ADDRESS_AWARE='1'
ENV STAGING_SHARED_MEMORY='1'
ENV WINEDEBUG='fixme-all'
ENV WINEDLLOVERRIDES='winemenubuilder.exe=n,explorer.exe=d'
ENV WINEPREFIX="$WINE_PREFIX_PATH"
ENV WINEARCH='win64'
RUN wineboot --init && \
	wineserver --wait

# Copy over required files
COPY --chown=${USERNAME}:${USERNAME} --from=library_downloader ${EXTRA_LIB_PATH} ${EXTRA_LIB_PATH}

# Copy over binary that just returns 0 to suppress the winemenubuilder error
COPY --from=fake-winemenubuilder /${FAKE_WINE_MENUBUILDER_NAME}.exe ${WINEPREFIX}/drive_c/windows/system32/winemenubuilder.exe

# Copy over UASM
COPY --from=uasm_builder --chmod=555 /uasm /usr/bin

COPY --chmod=555 ./build.sh /usr/bin

COPY --chown=${USERNAME}:${USERNAME} ./test-asm-files/*.asm ${BUILD_DIR}

WORKDIR ${DEST_DIR}
VOLUME ${DEST_DIR}

# suppress errors during actual usage
ENV WINEDEBUG='-all'

CMD [ "/usr/bin/build.sh", "/build/6th-main.asm" ]

##### User-facing Builder/Runner #####
FROM ${IMAGE}:${IMAGE_TAG} as runtime

# constants
ARG BUILD_DIR
ARG DEST_DIR
ARG EXTRA_LIB_PATH
ARG FAKE_WINE_MENUBUILDER_NAME
ARG USERNAME=wineuser

# env vars that the script reads in
ENV EXTRA_LIB_PATH=${EXTRA_LIB_PATH}
ENV WINE_PREFIX_PATH=/wine

# Install packages
RUN dpkg --add-architecture i386 \
	&& sed -i 's/^Components: main$/& contrib non-free/' /etc/apt/sources.list.d/debian.sources \
	&& apt-get update \
	&& apt-get install -y \
	bash \
	wine \
	winetricks \
	wine32 \
	wine64 \
	libwine \
	libwine:i386 \
	fonts-wine \
	winbind \
	mingw-w64 \
	&& rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /bin/bash ${USERNAME}

# Create directories before switching to non-root user
RUN mkdir ${BUILD_DIR} ${DEST_DIR} ${WINE_PREFIX_PATH} && \
	chown ${USERNAME}:${USERNAME} ${BUILD_DIR} ${DEST_DIR} ${WINE_PREFIX_PATH}

# Switch to non-root user
USER ${USERNAME}

# Create wine prefix
ENV WINE_LARGE_ADDRESS_AWARE='1'
ENV STAGING_SHARED_MEMORY='1'
ENV WINEDEBUG='fixme-all'
ENV WINEDLLOVERRIDES='winemenubuilder.exe=n,explorer.exe=d'
ENV WINEPREFIX="$WINE_PREFIX_PATH"
ENV WINEARCH='win64'
RUN wineboot --init && \
	wineserver --wait

# Copy over required files
COPY --chown=${USERNAME}:${USERNAME} --from=library_downloader ${EXTRA_LIB_PATH} ${EXTRA_LIB_PATH}

# Copy over binary that just returns 0 to suppress the winemenubuilder error
COPY --from=fake-winemenubuilder /${FAKE_WINE_MENUBUILDER_NAME}.exe ${WINEPREFIX}/drive_c/windows/system32/winemenubuilder.exe

# Copy over UASM
COPY --from=uasm_builder --chmod=555 /uasm /usr/bin

COPY --chmod=555 ./build.sh /usr/bin

COPY --chown=${USERNAME}:${USERNAME} ./test-asm-files/*.asm ${BUILD_DIR}

WORKDIR ${DEST_DIR}
VOLUME ${DEST_DIR}

# suppress errors during actual usage
ENV WINEDEBUG='-all'

CMD [ "/usr/bin/build.sh", "/build/6th-main.asm" ]


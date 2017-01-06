#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "This script uses functionality which requires root privileges"
    exit 1
fi

# Alpine GLIBC variables
ALPINE_GLIBC_BASE_URL="https://github.com/sgerrand/alpine-pkg-glibc/releases/download"
ALPINE_GLIBC_PACKAGE_VERSION="2.23-r3"
ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk"
ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk"
ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk"

# Start the build with alpine
acbuild --debug begin docker://alpine:3.5

# In the event of the script exiting, end the build
trap "{ export EXT=$?; acbuild --debug end && exit $EXT; }" EXIT

# Name the ACI
acbuild --debug set-name storvik/alpine-latex

# Copy new repositories
acbuild --debug copy config/repositories /etc/apk/repositories

# Install bash
acbuild --debug run -- apk update
acbuild --debug run -- apk add bash bash-doc bash-completion

# Install build dependencies
acbuild --debug run -- apk add --no-cache --virtual=.build-dependencies ca-certificates xz tar fontconfig-dev
acbuild --debug run -- apk add perl wget gnupg

acbuild --debug run -- mkdir -p /bootstrap/

acbuild --debug run -- wget -q https://raw.githubusercontent.com/andyshinn/alpine-pkg-glibc/master/sgerrand.rsa.pub -O /etc/apk/keys/sgerrand.rsa.pub

acbuild --debug run -- wget -q $ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME -O /bootstrap/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME
acbuild --debug run -- wget -q $ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME -O /bootstrap/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME
acbuild --debug run -- wget -q $ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME -O /bootstrap/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME

acbuild --debug run -- wget -q http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz -O /bootstrap/install-tl-unx.tar.gz
acbuild --debug run -- /bin/sh -c 'printf "%s\n" \
        "selected_scheme scheme-basic" \
        "option_doc 0" \
        "option_src 0" \
        > /bootstrap/texlive.profile'

acbuild --debug run -- apk add --no-cache /bootstrap/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME \
        /bootstrap/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME \
        /bootstrap/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME

acbuild --debug run -- /bin/sh -c "rm /etc/apk/keys/sgerrand.rsa.pub"

acbuild --debug run -- /bin/sh -c "/usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 C.UTF-8 || true"

acbuild --debug run -- /bin/sh -c "echo 'export LANG=C.UTF-8' > /etc/profile.d/locale.sh"
acbuild --debug environment add LANG C.UTF-8

acbuild --debug run -- apk del glibc-i18n

acbuild --debug run -- /bin/sh -c "PATH=/usr/local/texlive/2016/bin/x86_64-linux:$PATH"
acbuild --debug environment add PATH /usr/local/texlive/2016/bin/x86_64-linux:$PATH

# Set texlive installation path env
acbuild --debug run -- /bin/sh -c "mkdir -p /bootstrap/install-tl-unx/ && tar -xzf /bootstrap/install-tl-unx.tar.gz -C /bootstrap/install-tl-unx/ --strip=1"
acbuild --debug run -- /bin/sh -c "/bootstrap/install-tl-unx/install-tl --profile=/bootstrap/texlive.profile"

acbuild --debug run -- /usr/local/texlive/2016/bin/x86_64-linux/tlmgr install \
        collection-basic \
        collection-latex \
        collection-latexrecommended \
        collection-fontsrecommended

acbuild --debug run -- /bin/sh -c "( tlmgr install xetex || exit 0 )"

# Delete install files
acbuild --debug run -- rm -rf /bootstrap

## Remove build dependencies
acbuild --debug run -- apk del .build-dependencies

# Add labels
acbuild --debug label add arch amd64
acbuild --debug label add os linux

# Add author
acbuild --debug annotation add authors "Petter S. Storvik"

# Write the result
acbuild --debug write --overwrite alpine-latex-latest-linux-amd64.aci

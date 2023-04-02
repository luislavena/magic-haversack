# syntax=docker/dockerfile:1.4

FROM ruby:3.2.2-alpine AS base

# upgrade system and installed dependencies for security patches
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    set -eux; \
    apk upgrade

# setup non-root user (fixuid)
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    --mount=type=tmpfs,target=/tmp \
    set -eux -o pipefail; \
    # create non-root user & give passwordless sudo
    { \
        apk add sudo; \
        addgroup -g 1000 user; \
        adduser -u 1000 -G user -h /home/user -s /bin/sh -D user; \
        mkdir -p /etc/sudoers.d; \
        echo "user ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/user; \
        # cleanup backup copies
        rm /etc/group- /etc/passwd- /etc/shadow-; \
    }; \
    # Install fixuid
    { \
        cd /tmp; \
        export FIXUID_VERSION=0.5.1; \
        case "$(arch)" in \
        x86_64) \
            export \
                FIXUID_ARCH=amd64 \
                FIXUID_SHA256=1077e7af13596e6e3902230d7260290fe21b2ee4fffcea1eb548e5c465a34800 \
            ; \
            ;; \
        aarch64) \
            export \
                FIXUID_ARCH=arm64 \
                FIXUID_SHA256=7993a03876f5151c450e68a49706ef4c80d6b0ab755679eb47282df7f162fd82 \
            ; \
            ;; \
        esac; \
        wget -q -O fixuid.tar.gz https://github.com/boxboat/fixuid/releases/download/v${FIXUID_VERSION}/fixuid-${FIXUID_VERSION}-linux-${FIXUID_ARCH}.tar.gz; \
        echo "${FIXUID_SHA256} *fixuid.tar.gz" | sha256sum -c - >/dev/null 2>&1; \
        tar -xf fixuid.tar.gz; \
        mv fixuid /usr/local/bin/; \
        chmod u+s /usr/local/bin/fixuid; \
        rm fixuid.tar.gz; \
    }; \
    # Generate fixuid config
    mkdir -p /etc/fixuid; \
    { \
        echo "user: user"; \
        echo "group: user"; \
    } | tee /etc/fixuid/config.yml

# adjust ENTRYPOINT
ENTRYPOINT [ "/usr/local/bin/fixuid", "-q" ]
CMD [ "/bin/sh" ]

# install project dependencies
COPY Gemfile Gemfile.lock /app/

RUN --mount=type=tmpfs,target=/root/.bundle \
	--mount=type=tmpfs,target=/tmp \
    set -eux; \
    cd /app; \
    { \
        bundle check | bundle install; \
    }

# compiler tools
RUN --mount=type=cache,sharing=private,target=/var/cache/apk \
    set -eux; \
    apk add \
        binutils \
        file \
        git \
        m4 \
        make \
        perl \
        tar \
        xz \
    ;

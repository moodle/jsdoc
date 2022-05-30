FROM alpine:edge

ENV PACKAGES="doxygen graphviz ttf-freefont php bash"
RUN apk add $PACKAGES
RUN ln -s /usr/bin/php7 /usr/bin/php

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh" ]

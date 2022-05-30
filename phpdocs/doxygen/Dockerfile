FROM alpine:edge

ENV PACKAGES="doxygen graphviz ttf-freefont php bash"
RUN apk add $PACKAGES

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh" ]

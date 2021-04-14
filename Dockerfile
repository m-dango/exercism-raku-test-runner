FROM rakudo-star:2020.10-alpine

RUN apk add --no-cache coreutils jq

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]

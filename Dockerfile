FROM debian:10.1

LABEL "com.github.actions.name"="Release action"
LABEL "com.github.actions.description"="Github action for handling our releases"
LABEL "com.github.actions.icon"="git-branch"
LABEL "com.github.actions.color"="gray-dark"
LABEL "repository"="https://github.com/unraid/release-action"
LABEL "maintainer"="Alexis Tyler"

# Install git and npm
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y git npm \
    && apt-get autoremove \
    && apt-get autoclean \
    && apt-get clean

RUN wget -nv -O- \
    https://github.com/github/hub/releases/download/v2.12.7/hub-linux-amd64-2.12.7.tgz  | \
    tar xz --strip-components=1 '*/bin/hub'

RUN npm install -g s3-cli

ADD scripts /scripts
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
FROM debian:10.1

LABEL "com.github.actions.name"="Release action"
LABEL "com.github.actions.description"="Github action for handling our releases"
LABEL "com.github.actions.icon"="git-branch"
LABEL "com.github.actions.color"="gray-dark"
LABEL "repository"="https://github.com/unraid/release-action"
LABEL "maintainer"="Alexis Tyler"

# Install git, npm and hub
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y git npm hub \
    && apt-get autoremove \
    && apt-get autoclean \
    && apt-get clean

RUN npm install -g s3-cli

ADD scripts /scripts
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
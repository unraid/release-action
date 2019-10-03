FROM debian:10.1

LABEL "com.github.actions.name"="Release action"
LABEL "com.github.actions.description"="Github action for handling our releases"
LABEL "com.github.actions.icon"="git-branch"
LABEL "com.github.actions.color"="gray-dark"
LABEL "repository"="https://github.com/unraid/release-action"
LABEL "maintainer"="Alexis Tyler"

# Install git and npm
RUN apt update \
    && apt -y upgrade \
    && apt install -y git npm \
    && apt autoremove \
    && apt autoclean \
    && apt clean

RUN npm install -g s3-cli

ADD scripts /scripts
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
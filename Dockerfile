FROM phusion/baseimage:0.11

# Default Meteor version if not defined at build time; see ../build.sh
ARG METEOR_VERSION=1.8.1

ENV SCRIPTS_FOLDER /docker
ENV APP_SOURCE_FOLDER /opt/src
ENV APP_BUNDLE_FOLDER /opt/bundle



# Install dependencies, based on https://github.com/jshimko/meteor-launchpad/blob/master/scripts/install-deps.sh (only the parts we plan to use)
RUN apt-get update && \
	apt-get install --assume-yes apt-transport-https ca-certificates && \
	apt-get install --assume-yes --no-install-recommends build-essential bsdtar bzip2 curl git python

ENV METEOR_ALLOW_SUPERUSER true


# No ONBUILD lines, because this is intended to be used by your app’s multistage Dockerfile and you might need control of the sequence of steps using files from this image

ENV VERSION 1.8.1

# run next commands as user deamon

RUN curl https://install.meteor.com/?release=$VERSION | sh
RUN echo export PATH="$PATH:$HOME/.meteor" >> ~/.bashrc

# Copy entrypoint and dependencies
COPY ./docker $SCRIPTS_FOLDER/

# Install entrypoint dependencies
RUN cd $SCRIPTS_FOLDER && \
	meteor npm install

USER root
RUN apt-get update
RUN apt-get autoremove -yq
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy app source into container
COPY ./app $APP_SOURCE_FOLDER/
COPY ./app/package*.json $APP_SOURCE_FOLDER/

WORKDIR $APP_SOURCE_FOLDER/
RUN meteor npm install
RUN meteor npm install --save @babel/runtime@latest
RUN meteor npm install --save meteor-node-stubs
RUN meteor npm install p-wait-for
#RUN mkdir $APP_SOURCE_FOLDER && bash $SCRIPTS_FOLDER/build-app-npm-dependencies.sh

RUN bash $SCRIPTS_FOLDER/build-meteor-bundle.sh


FROM quantomatic/node:8.16

ENV APP_BUNDLE_FOLDER /opt/bundle
ENV SCRIPTS_FOLDER /docker

# Install OS build dependencies, which we remove later after we’ve compiled native Node extensions
RUN apt-get update && \
	apt-get install --assume-yes apt-transport-https ca-certificates && \
	apt-get install --assume-yes --no-install-recommends build-essential bsdtar bzip2 curl git python make g++


RUN npm install -g node-gyp
RUN apt-get autoremove -yq
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy in entrypoint
COPY --from=0 $SCRIPTS_FOLDER $SCRIPTS_FOLDER/

# Copy in app bundle
COPY --from=0 $APP_BUNDLE_FOLDER/bundle $APP_BUNDLE_FOLDER/bundle/

RUN bash $SCRIPTS_FOLDER/build-meteor-npm-dependencies.sh

EXPOSE 3000
ENV BIND_IP=127.0.0.1

RUN echo export BIND_IP=127.0.0.1 >> ~/.bashrc
RUN echo export APP_FOLDER=$APP_SOURCE_FOLDER >> ~/.bashrc
# Start app
ENTRYPOINT ["/docker/entrypoint.sh"]

CMD ["node", "main.js"]


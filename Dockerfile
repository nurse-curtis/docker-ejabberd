FROM debian:jessie
MAINTAINER Rafael Römhild <rafael@roemhild.de>

LABEL org.freenas.interactive="false" \
      org.freenas.version="1" \
      org.freenas.upgradeable="false" \
      org.freenas.expose-ports-at-host="true" \
      org.freenas.autostart="true" \
      org.freenas.port-mappings="5222:5222/tcp,5269:5269/tcp,5280:5280/tcp,4560:4560/tcp,5443:5443/tcp" \
      org.freenas.volumes="[ \
          { \
              \"name\": \"/opt/ejabberd/conf\", \
              \"descr\": \"Config volume\" \
          }, \
          {\
              \"name\": \"/opt/ejabberd/backup\", \
              \"descr\": \"Backup volume\" \
          }, \
          { \
              \"name\": \"/opt/ejabberd/upload\", \
              \"descr\": \"Upload volume\" \
          }, \
          { \
              \"name\": \"/opt/ejabberd/database\", \
              \"descr\": \"Database volume\" \
          }, \          
          {  \
              \"name\": \"/opt/ejabberd/ssl\", \
              \"descr\": \"SSL volume\" \
          } \
      ]" \
      org.freenas.settings="[ \
          { \
              \"env\": \"XMPP_DOMAIN\", \
              \"descr\": \"XMPP Domain\", \
              \"optional\": true\
          }, \
          { \
              \"env\": \"EJABBERD_ADMINS\", \
              \"descr\": \"XMPP Admins\", \
              \"optional\": true \
          }, \
          { \
              \"env\": \"EJABBERD_USERS\", \
              \"descr\": \"XMPP Users\", \
              \"optional\": true \
          }, \
          { \
              \"env\": \"EJABBERD_AUTH_METHOD\", \
              \"descr\": \"Auth Method default internal\", \
              \"optional\": true \
          } \
      ]"

ENV EJABBERD_BRANCH=17.04 \
    EJABBERD_USER=ejabberd \
    EJABBERD_HTTPS=true \
    EJABBERD_STARTTLS=true \
    EJABBERD_S2S_SSL=true \
    EJABBERD_HOME=/opt/ejabberd \
    EJABBERD_DEBUG_MODE=false \
    HOME=$EJABBERD_HOME \
    PATH=$EJABBERD_HOME/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    DEBIAN_FRONTEND=noninteractive \
    XMPP_DOMAIN=localhost \
    # Set default locale for the environment
    LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Add ejabberd user and group
RUN groupadd -r $EJABBERD_USER \
    && useradd -r -m \
       -g $EJABBERD_USER \
       -d $EJABBERD_HOME \
       $EJABBERD_USER

# Install packages and perform cleanup
RUN set -x \
    && buildDeps=' \
        git-core \
        build-essential \
        automake \
        libssl-dev \
        zlib1g-dev \
        libexpat-dev \
        libyaml-dev \
        libsqlite3-dev \
        erlang-src erlang-dev \
    ' \
    && requiredAptPackages=' \
        locales \
        ldnsutils \
        python2.7 \
        python-jinja2 \
        ca-certificates \
        libyaml-0-2 \
        erlang-base erlang-snmp erlang-ssl erlang-ssh erlang-webtool \
        erlang-tools erlang-xmerl erlang-corba erlang-diameter erlang-eldap \
        erlang-eunit erlang-ic erlang-odbc erlang-os-mon \
        erlang-parsetools erlang-percept erlang-typer \
        python-mysqldb \
        imagemagick \
        python-requests python-configargparse \
    ' \
    && apt-key adv \
        --keyserver keys.gnupg.net \
        --recv-keys 434975BD900CCBE4F7EE1B1ED208507CA14F4FCA \
    && apt-get update \
    && apt-get install -y $buildDeps $requiredAptPackages --no-install-recommends \
    && dpkg-reconfigure locales && \
        locale-gen C.UTF-8 \
    && /usr/sbin/update-locale LANG=C.UTF-8 \
    && echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen \
    && locale-gen \
    && cd /tmp \
    && git clone https://github.com/processone/ejabberd.git \
        --branch $EJABBERD_BRANCH --single-branch --depth=1 \
    && cd ejabberd \
    && chmod +x ./autogen.sh \
    && ./autogen.sh \
    && ./configure --enable-user=$EJABBERD_USER \
        --enable-all \
        --disable-tools \
        --disable-pam \
    && make debug=$EJABBERD_DEBUG_MODE \
    && make install \
    && mkdir $EJABBERD_HOME/ssl \
    && mkdir $EJABBERD_HOME/conf \
    && mkdir $EJABBERD_HOME/backup \
    && mkdir $EJABBERD_HOME/upload \
    && mkdir $EJABBERD_HOME/database \
    && mkdir $EJABBERD_HOME/module_source \
    && cd $EJABBERD_HOME \
    && git clone https://github.com/jsxc/xmpp-cloud-auth.git \
    && chmod u+x xmpp-cloud-auth/external_cloud.py \
    && rm -rf /tmp/ejabberd \
    && rm -rf /etc/ejabberd \
    && ln -sf $EJABBERD_HOME/conf /etc/ejabberd \
    && rm -rf /usr/local/etc/ejabberd \
    && ln -sf $EJABBERD_HOME/conf /usr/local/etc/ejabberd \
    && chown -R $EJABBERD_USER: $EJABBERD_HOME \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge -y --auto-remove $buildDeps

# Wrapper for setting config on disk from environment
# allows setting things like XMPP domain at runtime
ADD ./run.sh /sbin/run

# Add run scripts
ADD ./scripts $EJABBERD_HOME/scripts
ADD https://raw.githubusercontent.com/rankenstein/ejabberd-auth-mysql/master/auth_mysql.py $EJABBERD_HOME/scripts/lib/auth_mysql.py
RUN chmod a+rx $EJABBERD_HOME/scripts/lib/auth_mysql.py

# Add config templates
ADD ./conf /opt/ejabberd/conf

# Continue as user
USER $EJABBERD_USER

# Set workdir to ejabberd root
WORKDIR $EJABBERD_HOME

VOLUME ["$EJABBERD_HOME/database", "$EJABBERD_HOME/ssl", "$EJABBERD_HOME/backup", "$EJABBERD_HOME/upload"]
EXPOSE 4560 5222 5269 5280 5443

CMD ["start"]
ENTRYPOINT ["run"]

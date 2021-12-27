FROM ubuntu:20.04

MAINTAINER Dylan <newlooper@hotmail.com>

#############################################################################################
# Locale, Language, Timezone
ENV OS_LOCALE="en_US.UTF-8" \
	TZ="Asia/Shanghai"

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
	&& apt-get install -y locales tzdata \
	&& ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
	&& dpkg-reconfigure -f noninteractive tzdata \
	&& locale-gen ${OS_LOCALE}

ENV LANG=${OS_LOCALE} \
	LC_ALL=${OS_LOCALE} \
	LANGUAGE="en_US:en"

#############################################################################################
# App Env
ENV PHP_VER="8.1"
ENV PHP_INI="/etc/php/${PHP_VER}/fpm/php.ini"
ENV FPM_CONF="/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
ENV COMPOSER_VERSION="2.2.1"

#############################################################################################
# Install Requirements
RUN DEBIAN_FRONTEND=noninteractive \
	buildDeps='software-properties-common' \
	&& apt-get install --no-install-recommends --no-install-suggests -y $buildDeps \
	&& add-apt-repository -y ppa:ondrej/php \
	&& add-apt-repository -y ppa:nginx/stable \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -q -y \
		gcc make autoconf libc-dev pkg-config libmcrypt-dev php-pear \
		rsync \
		cron \
		iputils-ping \
		net-tools \
		curl \
		wget \
		vim \
		zip \
		unzip \
		python3-pip \
		python-setuptools \
		nginx \
		mysql-client \
		php${PHP_VER}-mongodb \
		php${PHP_VER}-bcmath \
		php${PHP_VER}-bz2 \
		php${PHP_VER}-fpm \
		php${PHP_VER}-cli \
		php${PHP_VER}-dev \
		php${PHP_VER}-common \
		php${PHP_VER}-opcache \
		php${PHP_VER}-readline \
		php${PHP_VER}-mbstring \
		php${PHP_VER}-curl \
		php${PHP_VER}-memcached \
		php${PHP_VER}-imagick \
		php${PHP_VER}-mysql \
		php${PHP_VER}-zip \
		php${PHP_VER}-pgsql \
		php${PHP_VER}-intl \
		php${PHP_VER}-xml \
		php${PHP_VER}-redis \
		php${PHP_VER}-gd \
		php${PHP_VER}-soap \
	&& mkdir -p /run/php \
	&& pip install wheel \
	&& pip install supervisor \
	&& echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
	&& sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${PHP_INI} \
	&& sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${PHP_INI} \
	&& sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${PHP_INI} \
	&& sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${PHP_INI} \
	&& sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${PHP_INI} \
	&& sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/${PHP_VER}/fpm/php-fpm.conf \
	&& sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${FPM_CONF} \
	&& sed -i -e "s/pm.max_children = 5/pm.max_children = 4/g" ${FPM_CONF} \
	&& sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${FPM_CONF} \
	&& sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${FPM_CONF} \
	&& sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${FPM_CONF} \
	&& sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${FPM_CONF} \
	&& sed -i -e "s/^;clear_env = no$/clear_env = no/" ${FPM_CONF}
	
RUN yes '' | pecl install -f mcrypt-1.0.4 \
	&& echo "extension=mcrypt.so" > /etc/php/${PHP_VER}/cli/conf.d/mcrypt.ini \
	&& echo "extension=mcrypt.so" > /etc/php/${PHP_VER}/fpm/conf.d/mcrypt.ini

# Clean
RUN apt-get purge -y --auto-remove $buildDeps \
	&& apt-get autoremove -y \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# composer
RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
	&& curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
	&& php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
	&& php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
	&& rm -rf /tmp/composer-setup.php

# Nginx Upstream config
ADD ./conf/upstream.conf /etc/nginx/upstream.conf

# Add upstream config to nginx.conf
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

# Supervisor config
ADD ./conf/supervisord.conf /etc/supervisord.conf

# Override default nginx welcome page
COPY html /usr/share/nginx/html

# Add Scripts
ADD ./start.sh /start.sh

EXPOSE 80 443

CMD ["/start.sh"]
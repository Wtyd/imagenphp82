FROM debian:10

LABEL version="1.0.0"

ARG PUID=1000
ENV PUID ${PUID}
ARG PGID=1000
ENV PGID ${PGID}

# Creamos el usuario zataca
RUN groupadd -g ${PGID} zataca \
    && useradd -u ${PUID} -g zataca -m zataca \
    && usermod -p "*" zataca -s /bin/bash \
    && echo "zataca:zataca" | chpasswd \
    && echo "root:zataca" | chpasswd

# --------------------------------------------------------------------------------------------------------
# INSTALACIÓN DE CURL, WGET Y REPOSITORIOS PARA NODE Y PHP 8.2
# --------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------
RUN apt-get update -yqq && apt-get -y upgrade && apt-get -y dist-upgrade \
    && apt-get install -y curl wget gnupg2 ca-certificates lsb-release apt-transport-https --no-install-recommends \
    && curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add - \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.list


# --------------------------------------------------------------------------------------------------------
# INSTALACIÓN DE VARIAS HERRAMIENTAS
# --------------------------------------------------------------------------------------------------------
# Tras instalar Zsh lo establece como shell por defecto.
# Configuración de los locales
# --------------------------------------------------------------------------------------------------------
RUN apt-get update \
    && apt-get -y install yarn git procps net-tools telnet vim nano chromium xvfb zsh locales postgresql-client less --no-install-recommends \
    && usermod --shell /bin/zsh zataca \
    && localedef -i es_ES -c -f UTF-8 -A /usr/share/locale/locale.alias es_ES.UTF-8

# --------------------------------------------------------------------------------------------------------
# INSTALACIÓN DE NODE Y NVM
# --------------------------------------------------------------------------------------------------------
# Relacionado con las pregutnas anteriores
# --------------------------------------------------------------------------------------------------------
ARG NODE_VERSION=12
ENV NODE_VERSION ${NODE_VERSION}
ENV NVM_DIR /home/zataca/.nvm
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm use ${NODE_VERSION} \
    && nvm alias ${NODE_VERSION} \
    && npm install pm2 -g \
    && chown -R zataca:zataca $NVM_DIR


# --------------------------------------------------------------------------------------------------------
# CONFIGURACIÓN DE PHP
# --------------------------------------------------------------------------------------------------------
# Se instalan las librerías requeridas para cada una de las versiones de php. Quizas haya alguna forma de poder parametrizar la versión de librerías
# ya que se instalan siempre las mismas lo único que cambia es la versión.
# --------------------------------------------------------------------------------------------------------
RUN apt-get update && apt-get -y install \
    php8.2-fpm php8.2-bz2 php8.2-zip php8.2-curl php8.2-common php8.2-mbstring php8.2-cli php8.2-soap \
    php8.2-xml php8.2-bcmath php8.2-pgsql php8.2-intl php8.2-gd php-ssh2 unzip php8.2-pcov \
    --no-install-recommends \
    && apt-get -y install imagemagick php8.2-imagick \
    && sed -i 's+<policy domain="coder" rights="none" pattern="PDF" />+<policy domain="coder" rights="read | write" pattern="PDF" />+g' "/etc/ImageMagick-6/policy.xml"

# --------------------------------------------------------------------------------------------------------
# CONFIGURACIÓN DE PHP-FPM Y PHP-CLI
# --------------------------------------------------------------------------------------------------------
RUN ln -s /usr/bin/php /bin/php
RUN ln -s /etc/init.d/php8.2-fpm /etc/init.d/php-fpm
COPY php-fpm/www.conf /etc/php/8.0/fpm/pool.d/www.conf
RUN sed -i 's/\r//g' /etc/php/8.0/fpm/pool.d/www.conf
COPY php/php-cli.ini /etc/php/8.0/cli/php.ini
COPY php/php-fpm.ini /etc/php/8.0/fpm/php.ini

# --------------------------------------------------------------------------------------------------------
# INSTALACIÓN DE NGINX Y CRON PARA LARAVEL HORIZON
# --------------------------------------------------------------------------------------------------------
RUN apt-get -y install nginx cron --no-install-recommends
COPY nginx/conf/nginx.conf /etc/nginx/nginx.conf
COPY nginx/sites/default /etc/nginx/sites-enabled/default
RUN sed -i 's/\r//g' /etc/nginx/sites-enabled/default \
    && sed -i 's/\r//g' /etc/nginx/nginx.conf
COPY cron /etc/cron.d
RUN chmod -R 644 /etc/cron.d

# --------------------------------------------------------------------------------------------------------
# INSTALACIÓN DE LIBRERÍAS PHP (COMPOSER)
# --------------------------------------------------------------------------------------------------------
COPY repositorio/composer/* /usr/local/bin/
COPY repositorio/librerias/* /home/librerias/

RUN mkdir -p /root/.composer \
    && mkdir -p /home/librerias/ 

RUN composer global require \
    php-parallel-lint/php-parallel-lint:"^1.3" \
    edgedesign/phpqa:"^1.25.0" \
    phpmetrics/phpmetrics:"^2.7.4" \
    laravel/envoy \
    && mv -f /home/librerias/* /root/.composer/vendor/bin/

ENV PATH=$PATH:/root/.composer/vendor/bin/

# --------------------------------------------------------------------------------------------------------
# EXPOSE, PATH POR DEFECTO Y START
# --------------------------------------------------------------------------------------------------------

# Puertos que utilizamos
EXPOSE 80/tcp
EXPOSE 443/tcp
EXPOSE 1234/tcp
EXPOSE 2222/tcp
EXPOSE 8090/tcp
EXPOSE 9000/tcp

# WORKDIR /var/www/html

STOPSIGNAL SIGTERM

CMD ["/root/start.sh"]

# docker exec -it 6c8012b417de -v ~/proyectos/comercializacion:/var/www/html bin/bash
# docker run -it --rm gitlab.zataca.es:5050/zataca/contenedores/php80 /bin/bash
# docker run -it 38f55a437577 /bin/bash
# docker run -it -p 80:80 -v ~/proyectos/cosmos:/var/www/html 6c8012b417de /bin/bash

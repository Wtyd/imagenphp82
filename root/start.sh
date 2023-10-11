#!/bin/bash
export TZ=Europe/Madrid
export LANG="es_ES.UTF-8"
export LANGUAGE="es_ES:es"
export LC_ALL="es_ES.UTF-8"

# Creamos un certificado autofirmado para que nginx no de error al iniciar su servicio
if [ ! -f /etc/nginx/ssl/default.crt ]; then
    openssl genrsa -out "/etc/nginx/ssl/default.key" 2048
    openssl req -new -key "/etc/nginx/ssl/default.key" -out "/etc/nginx/ssl/default.csr" -subj "/CN=default/O=default/C=UK"
    openssl x509 -req -days 365 -in "/etc/nginx/ssl/default.csr" -signkey "/etc/nginx/ssl/default.key" -out "/etc/nginx/ssl/default.crt"
    chown -R zataca:zataca /etc/nginx/ssl/*
fi


chown -R zataca:zataca /home/zataca/.cache/*
# Iniciamos los servicios que queremos correr en este docker
/etc/init.d/nginx start
/etc/init.d/php-fpm start
/etc/init.d/cron start
/etc/init.d/ssh start
npm start --prefix /var/www/ssh/app/ &

# Funcion para terminar el proceso
salir() {
    /etc/init.d/nginx stop
    /etc/init.d/php-fpm stop
    /etc/init.d/cron stop
    /etc/init.d/ssh stop
    #No funciona pero para el servicio :)
    npm stop --prefix /var/www/ssh/app/ &
    exit 0
}
# Trap para escuchar la señal de SIGTERM y finalizar el docker sin esperar los 10 segundos del timeout
trap salir SIGTERM

# Bucle para que docker no se cierre
while true; do sleep 1s; done

FROM nginx:stable
MAINTAINER Marcel Rebello <marcel.rebello@unisys.com>
# based on https://www.nginx.com/blog/compiling-and-installing-modsecurity-for-open-source-nginx/

# Install nginx
RUN apt-get install -y nginx-full

#Install Deps
RUN apt-get update && apt-get install -y \
apt-utils autoconf automake build-essential \
git libcurl4-openssl-dev libgeoip-dev liblmdb-dev \
libpcre++-dev libtool libxml2-dev libyajl-dev pkgconf wget zlib1g-dev

#Compile ModSecurity
RUN cd /usr/src && \
git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity && \
cd /usr/src/ModSecurity &&  \
git submodule init && \
git submodule update && \
./build.sh && \
./configure && \
make && \
make install

#Copy ModSecurity nginx
RUN cd /usr/src/ && \
git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git


# Download module from nginx
RUN cd /usr/src && \
nginx -v 2>/tmp/1 && nginx_version=$(cat /tmp/1 | awk -F '/' '{print$2}' | awk '{print$1}') && \
wget http://nginx.org/download/nginx-${nginx_version}.tar.gz && \
tar zxvf nginx-${nginx_version}.tar.gz && \
ln -s nginx-${nginx_version} nginx_current

#Create a module and sent to module path
RUN cd /usr/src/nginx_current && \
./configure --with-compat --add-dynamic-module=../ModSecurity-nginx && \
make modules && \
cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/

RUN sed -i '/pid/a load_module modules/ngx_http_modsecurity_module.so;' /etc/nginx/nginx.conf

RUN mkdir /etc/nginx/modsec && \
wget -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended && \
mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf

RUN sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf  && \
echo 'Include "/etc/nginx/modsec/modsecurity.conf"' > /etc/nginx/modsec/main.conf && \
echo 'SecRule ARGS:testparam "@contains test" "id:1234,deny,status:403' >> /etc/nginx/modsec/main.conf

RUN sed -i 's/SecUnicodeMapFile/#SecUnicodeMapFile/' /etc/nginx/modsec/modsecurity.conf

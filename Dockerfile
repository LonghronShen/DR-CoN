FROM nginx:1.7

#Install Curl
RUN apt-get update -qq && apt-get -y install curl

#Install Consul Template
COPY consul-template /usr/local/bin/
RUN chmod a+x /usr/local/bin/consul-template

#Setup Consul Template Files
RUN mkdir /etc/consul-templates
ENV CT_FILE /etc/consul-templates/nginx.conf

#Setup Nginx File
ENV NX_FILE /etc/nginx/conf.d/app.conf

#Default Variables
ENV CONSUL consul:8500
ENV SERVICE consul-8500

# Command will
# 1. Write Consul Template File
# 2. Start Nginx
# 3. Start Consul Template

CMD echo "upstream app {                 \n\
  least_conn;                            \n\
  {{range service \"$SERVICE\"}}         \n\
  server  {{.Address}}:{{.Port}} max_fails=3 fail_timeout=60 weight=1;        \n\
  {{else}}server 127.0.0.1:65535;{{end}} \n\
}                                        \n\
server {                                 \n\
  listen 80 default_server;              \n\
  location / {                           \n\
    proxy_pass http://app;               \n\
	  proxy_http_version 1.1;					        \n\
    proxy_set_header Upgrade $http_upgrade;	\n\
    proxy_set_header Connection "upgrade";	\n\
  }                                      \n\
}" > $CT_FILE; \
/usr/sbin/nginx -c /etc/nginx/nginx.conf \
& CONSUL_TEMPLATE_LOG=debug consul-template \
  -consul=$CONSUL \
  -template "$CT_FILE:$NX_FILE:/usr/sbin/nginx -s reload";

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

CMD echo "                                                                                                    \n\
gzip              on;                                                                                         \n\
gzip_min_length   1000;                                                                                       \n\
gzip_types        text/plain text/css text/json application/x-javascript application/json application/xml;    \n\
gunzip			      on;                                                                                         \n\
                                                                                                              \n\
upstream app {                                                                                                \n\
  keepalive 100;                                                                                              \n\
  least_conn;                                                                                                 \n\
  {{range service \"$SERVICE\"}}                                                                              \n\
  server  {{.Address}}:{{.Port}} max_fails=3 fail_timeout=60 weight=1;                                        \n\
  {{else}}server 127.0.0.1:65535;{{end}}                                                                      \n\
}                                                                                                             \n\
                                                                                                              \n\
server {                                                                                                      \n\
  listen 80 default_server;                                                                                   \n\
  location / {                                                                                                \n\
    proxy_pass http://app;                                                                                    \n\
	  proxy_http_version 1.1;                                                                                   \n\
    proxy_set_header Connection \"\";                                                                           \n\
    proxy_set_header Upgrade \$http_upgrade;                                                                  \n\
    proxy_set_header Connection \"upgrade\";                                                                  \n\
    proxy_set_header Host \$host;                                                                             \n\
		proxy_set_header X-Real-IP \$remote_addr;                                                                 \n\
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;                                             \n\
		proxy_buffer_size          4k;                                                                            \n\
		proxy_buffers              4 32k;                                                                         \n\
		proxy_busy_buffers_size    64k;                                                                           \n\
		proxy_temp_file_write_size 64k;                                                                           \n\
  }                                                                                                           \n\
}" > $CT_FILE; \
/usr/sbin/nginx -c /etc/nginx/nginx.conf \
& CONSUL_TEMPLATE_LOG=debug consul-template \
  -consul=$CONSUL \
  -template "$CT_FILE:$NX_FILE:/usr/sbin/nginx -s reload";
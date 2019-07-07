FROM nginx:alpine

#RUN addgroup -g 1001 -S www-data \
RUN adduser -u 1005 -D -S -G www-data www-data

COPY nginx.conf /etc/nginx/nginx.conf
#USER www-data


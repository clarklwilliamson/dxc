FROM nginx:latest

COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN mkdir -p /usr/share/nginx/html/page1 \
    && mkdir -p /usr/share/nginx/html/page2

COPY index.html /usr/share/nginx/html/
COPY page1/index.html /usr/share/nginx/html/page1/
COPY page1/image1.jpg /usr/share/nginx/html/page1/
COPY page2/index.html /usr/share/nginx/html/page2/
COPY page2/image2.jpg /usr/share/nginx/html/page2/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]


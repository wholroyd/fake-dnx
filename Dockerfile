FROM wholroyd/centos-dnx:latest

MAINTAINER William Holroyd <wholroyd@gmail.com>

EXPOSE 5004

COPY /src/fake-dnx /app
WORKDIR /app

RUN dnu restore && \
    npm install && \
    npm install -g bower && \
    npm install -g gulp && \
    bower install --allow-root

RUN yum -y autoremove && \
    yum clean all && \
    rpm --rebuilddb

CMD ["dnx", ".", "kestrel"]

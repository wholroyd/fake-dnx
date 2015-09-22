FROM wholroyd/centos-dnx:latest

MAINTAINER William Holroyd <wholroyd@gmail.com>

EXPOSE 5004

COPY /src/fake-dnx /app
WORKDIR /app

RUN yum makecache fast && \
    yum -y autoremove && \
    yum clean all && \
    rpm --rebuilddb

CMD ["dnx", ".", "kestrel"]

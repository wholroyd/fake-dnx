FROM wholroyd/centos-dnx

RUN ["dnu", "restore"]
RUN ["bower", "install", "."]
RUN ["gulp", "copy"]

RUN yum -y autoremove && \
    yum clear all && \
    rpm --rebuilddb

COPY /src/fake-dnx /app
WORKDIR /app

EXPOSE 5004
ENTRYPOINT ["dnx", ".", "kestrel"]

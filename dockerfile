FROM microsoft/aspnet

# Install requirements for nodejs compilation and install
RUN \
    apt-get update -y && apt-get install --no-install-recommends -y -q \
    curl \
    python \
    build-essential \
    git \
    ca-certificates

# Install nodejs itself
RUN \
    cd /tmp && \
    wget http://nodejs.org/dist/node-latest.tar.gz && \
    tar xvzf node-latest.tar.gz && \
    rm -f node-latest.tar.gz && \
    cd node-v* && \
   ./configure && \
    CXX="g++ -Wno-unused-local-typedefs" make && \
    CXX="g++ -Wno-unused-local-typedefs" make install && \
    cd /tmp && \
    rm -rf /tmp/node-v* && \
    npm install -g npm && \
    printf '\n# Node.js\nexport PATH="node_modules/.bin:$PATH"' >> /root/.bashrc

# Install gulp and bower
RUN npm install -g gulp bower

RUN ["dnu", "restore"]
RUN ["bower", "install", "."]
RUN ["gulp", "copy"]

COPY /src/fake-dnx /app
WORKDIR /app

EXPOSE 5004
ENTRYPOINT ["dnx", ".", "kestrel"]

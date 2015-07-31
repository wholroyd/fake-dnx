FROM microsoft/aspnet

# Install node and npm for any Node or Bower packages we need from the project
RUN apt-get -qqy install \
	nodejs \
	npm

COPY /src/fake-dnx /app
WORKDIR /app
RUN ["dnu", "restore"]

EXPOSE 5004
ENTRYPOINT ["dnx", ".", "kestrel"]

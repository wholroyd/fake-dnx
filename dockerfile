FROM microsoft/aspnet

# Install node and npm for any Node or Bower packages we need from the project
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.25.4/install.sh | bash \
	&& nvm install 0.12

COPY /src/fake-dnx /app
WORKDIR /app
RUN ["dnu", "restore"]

EXPOSE 5004
ENTRYPOINT ["dnx", ".", "kestrel"]

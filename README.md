<!--
---
name: Experimental .NET 10 worker container for Azure Functions Flex Consumption
description: >-
  Build a Linux AMD64 .NET 10 isolated worker-only container for the Azure
  Functions Flex Consumption container preview.
page_type: sample
languages:
- csharp
- dockerfile
- powershell
products:
- azure
- azure-functions
- azure-container-registry
urlFragment: flex-container-dotnet-html-to-pdf
---
-->

# Experimental .NET 10 worker container for Azure Functions Flex Consumption

This repository contains an experimental .NET 10 isolated-worker container
baseline for Azure Functions Flex Consumption.

> [!IMPORTANT]
> The current checkpoint implements only an anonymous `GET`/`POST` hello
> function. HTML-to-PDF functionality has not been added yet.

## Status

The source and Linux AMD64 image build have been validated locally. This
version deliberately does **not** set `FUNCTIONS_APPLICATION_DIRECTORY` in
`Program.cs`.

End-to-end Azure validation is pending the required worker package and platform
updates. Do not treat the sample as deployable until that validation has been
completed. Publishing a local container port does not reproduce the Azure
Functions hosting environment.

## Image contract

- .NET 10 isolated worker with ASP.NET Core integration
- `Microsoft.Azure.Functions.Worker` 2.52.0
- `Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore` 2.1.1
- `Microsoft.Azure.Functions.Worker.Sdk` 2.1.0
- Linux AMD64
- Non-root execution using the .NET runtime image's `app` user
- Working directory `/home/site/wwwroot`
- Direct entrypoint `dotnet ByocDotnetWorker.dll`
- Worker-only image with no Azure Functions Host or Core Tools
- No exposed HTTP port or standalone HTTP listener

The managed Azure Functions platform is expected to provide the worker
connection arguments and application-directory configuration when it starts
the image.

## Build

Install Docker Desktop with Linux container support, then run:

```powershell
docker build `
  --platform linux/amd64 `
  --progress plain `
  --file .\dotnet10.Dockerfile `
  --tag flex-container-dotnet-html-to-pdf:local `
  .
```

Inspect the generated image:

```powershell
docker image inspect flex-container-dotnet-html-to-pdf:local

docker run --rm `
  --entrypoint /bin/sh `
  flex-container-dotnet-html-to-pdf:local `
  -c 'id && pwd && dotnet --list-runtimes'
```

The container is not a standalone web server, so `docker run -p` is not an
endpoint test.

## Function contract

After a future successful Azure deployment, both requests should return HTTP
200 with this exact body:

```text
Hello from the BYOC .NET worker.
```

```shell
curl --fail --show-error "https://<function-app-hostname>/api/hello"
curl --fail --show-error --request POST "https://<function-app-hostname>/api/hello"
```

## Container build direction

The current checkpoint retains the explicit Dockerfile used during local
validation. A follow-up can evaluate replacing it with SDK-native container
publishing through:

```powershell
dotnet publish -t:PublishContainer
```

That change should preserve the same base image, non-root user, working
directory, direct command, architecture, and worker-only contents before the
Dockerfile is removed.

## License

MIT

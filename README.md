<!--
---
name: Experimental .NET 10 HTML-to-PDF worker container for Azure Functions Flex Consumption
description: >-
  Render HTML to PDF with PuppeteerSharp and sandboxed Chromium in a Linux
  AMD64 .NET 10 isolated worker-only container.
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

# Experimental .NET 10 HTML-to-PDF worker container

This repository is an experimental Azure Functions Flex Consumption
worker-only container that renders HTML to PDF with PuppeteerSharp and
Chromium.

> [!IMPORTANT]
> This sample processes untrusted HTML with strict limits and browser
> isolation, but it is not production guidance. Complete your own security,
> load, observability, and cost review before adopting it.

## Status

The source, unit tests, Linux AMD64 image build, and real in-container Chromium
rendering have been validated locally. The same worker image was validated end
to end on an Azure Functions Flex Consumption FC1 app in North Central US
(Stage) on November 11, 2026.

Azure validation confirmed both functions indexed, the Hello GET/POST contract,
the built-in and custom HTML PDF scenarios, JavaScript isolation, controlled
input errors, and the 20-page limit. The validation app was stopped afterward;
this repository remains an experimental sample rather than production
guidance.

The sample deliberately does **not** set
`FUNCTIONS_APPLICATION_DIRECTORY` in `Program.cs`, the image environment, or
the application settings expected by the sample.

## Endpoints

| Method and route | Behavior |
| --- | --- |
| `GET /api/hello` | Returns `Hello from the BYOC .NET worker.` |
| `POST /api/hello` | Returns `Hello from the BYOC .NET worker.` |
| `GET /api/html-to-pdf` | Renders a deterministic built-in sample invoice. |
| `POST /api/html-to-pdf` | Renders the raw UTF-8 `text/html` request body. |

A successful PDF response uses:

- `Content-Type: application/pdf`
- `Content-Disposition: attachment`
- `Cache-Control: no-store`
- `X-Content-Type-Options: nosniff`

Example requests after deployment:

```shell
curl --fail --show-error \
  --output sample-invoice.pdf \
  "https://<function-app-hostname>/api/html-to-pdf"

curl --fail --show-error \
  --header "Content-Type: text/html; charset=utf-8" \
  --data-binary "@examples/sample.html" \
  --output document.pdf \
  "https://<function-app-hostname>/api/html-to-pdf"
```

## Rendering limits

| Limit | Value |
| --- | --- |
| HTML request body | 1 MiB |
| Rendering time | 30 seconds |
| Concurrent renders per worker process | 1 |
| Generated pages | 20 |
| Generated PDF size | 10 MiB |

Empty bodies, unsupported media types, invalid UTF-8, oversized input, render
timeouts, and output-limit violations return controlled error responses.

## Browser isolation

- Runs as the .NET runtime image's non-root `app` user.
- Keeps Chromium's process sandbox enabled; the code does not pass
  `--no-sandbox` or `--disable-setuid-sandbox`.
- Disables JavaScript before loading submitted HTML.
- Blocks HTTP, HTTPS, file, FTP, and WebSocket requests.
- Allows only embedded `data:`, `blob:`, and `about:` resources.
- Routes any request that escapes interception to an unreachable local proxy.
- Creates and disposes a new browser process for each render.
- Validates the PDF signature, trailer, page count, and output size.

## Image contract

- .NET 10 isolated worker with ASP.NET Core integration
- `Microsoft.Azure.Functions.Worker` 2.53.0-preview.1
- `Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore` 2.1.2-preview.1
- `Microsoft.Azure.Functions.Worker.Sdk` 2.1.0
- PuppeteerSharp 25.12.0 and PdfPig 0.1.16
- Pinned .NET 10 Alpine 3.23 SDK and ASP.NET runtime images
- Alpine Chromium headless shell 149.0.7827.53-r0
- Linux AMD64 and `linux-musl-x64` publish output
- Working directory `/home/site/wwwroot`
- Direct entrypoint `dotnet ByocDotnetWorker.dll`
- No Functions Host, Core Tools, exposed port, or standalone HTTP listener

The managed Azure Functions platform supplies the worker connection arguments
when it starts the image.

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

The build restores, tests, and publishes the application before creating the
final image.

Inspect the generated image:

```powershell
docker image inspect flex-container-dotnet-html-to-pdf:local

docker run --rm `
  --entrypoint /bin/sh `
  flex-container-dotnet-html-to-pdf:local `
  -c 'id && pwd && chromium-headless-shell --version && dotnet --list-runtimes'
```

The final container is not a standalone web server, so `docker run -p` is not
an endpoint test.

## Real Chromium integration check

Build and run the dedicated validation target:

```powershell
docker build `
  --platform linux/amd64 `
  --target integration-test `
  --file .\dotnet10.Dockerfile `
  --tag flex-container-dotnet-html-to-pdf:integration `
  .

docker run --rm `
  --security-opt seccomp=unconfined `
  flex-container-dotnet-html-to-pdf:integration
```

Docker Desktop's default seccomp profile blocks the namespace operation used
to initialize Chromium's sandbox. The local integration command relaxes only
the outer container profile; Chromium's own renderer sandbox remains enabled.
The check performs real renders and verifies the sample invoice, JavaScript
isolation, external-resource blocking, and the page limit.

## Container build direction

The sample retains an explicit Dockerfile while the browser runtime and
validation target are being evaluated. A follow-up can evaluate SDK-native
container publishing through:

```powershell
dotnet publish -t:PublishContainer
```

That change must preserve the pinned runtime, Chromium dependencies, non-root
user, working directory, entrypoint, architecture, and worker-only contents.

## License

MIT

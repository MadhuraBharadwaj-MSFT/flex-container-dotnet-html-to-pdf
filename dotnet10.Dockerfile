# syntax=docker/dockerfile:1.7

ARG SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:10.0-alpine3.23@sha256:3f9c03432d664163a90d20e3ed0a3784d0aa82c1b9cbd1a7dd4609fede95669e
ARG RUNTIME_IMAGE=mcr.microsoft.com/dotnet/aspnet:10.0-alpine3.23@sha256:23c1e50c547546cb1192b84369ecfc6fa227cb447b17fee57456bd178962c213

FROM ${SDK_IMAGE} AS build

WORKDIR /src

COPY NuGet.config ByocDotnetWorker.csproj ./
COPY tests/ByocDotnetWorker.Tests/ByocDotnetWorker.Tests.csproj tests/ByocDotnetWorker.Tests/
COPY tests/RenderCheck/RenderCheck.csproj tests/RenderCheck/

RUN dotnet restore ByocDotnetWorker.csproj \
        --runtime linux-musl-x64 \
        -p:NuGetAudit=false \
        -p:PublishReadyToRun=true \
    && dotnet restore tests/ByocDotnetWorker.Tests/ByocDotnetWorker.Tests.csproj \
        -p:NuGetAudit=false \
    && dotnet restore tests/RenderCheck/RenderCheck.csproj \
        --runtime linux-musl-x64 \
        -p:NuGetAudit=false

COPY *.cs host.json ./
COPY tests/ByocDotnetWorker.Tests/*.cs tests/ByocDotnetWorker.Tests/
COPY tests/RenderCheck/*.cs tests/RenderCheck/

RUN dotnet test tests/ByocDotnetWorker.Tests/ByocDotnetWorker.Tests.csproj \
        --configuration Release \
        --no-restore \
        --nologo \
        -p:NuGetAudit=false \
    && dotnet publish ByocDotnetWorker.csproj \
        --configuration Release \
        --runtime linux-musl-x64 \
        --self-contained false \
        --no-restore \
        -p:NuGetAudit=false \
        -p:PublishReadyToRun=true \
        --output /publish \
    && rm -f /publish/worker.config.json /publish/functions.metadata \
    && dotnet publish tests/RenderCheck/RenderCheck.csproj \
        --configuration Release \
        --runtime linux-musl-x64 \
        --self-contained false \
        --no-restore \
        -p:NuGetAudit=false \
        --output /rendercheck

FROM ${RUNTIME_IMAGE} AS runtime-base

ARG CHROMIUM_VERSION=149.0.7827.53-r0
ARG FONT_LIBERATION_VERSION=2.1.5-r2
ARG FONT_NOTO_VERSION=2026.11.01-r0
ARG FONT_NOTO_CJK_VERSION=0_git20220127-r1
ARG FONT_NOTO_EMOJI_VERSION=2.048-r0

RUN apk add --no-cache \
        chromium-headless-shell=${CHROMIUM_VERSION} \
        font-liberation=${FONT_LIBERATION_VERSION} \
        font-noto=${FONT_NOTO_VERSION} \
        font-noto-cjk=${FONT_NOTO_CJK_VERSION} \
        font-noto-emoji=${FONT_NOTO_EMOJI_VERSION} \
    && test -x /usr/bin/chromium-headless-shell \
    && mkdir -p /home/site/wwwroot /home/app/.cache \
    && chown -R "${APP_UID}:${APP_UID}" /home/site /home/app/.cache

ENV CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-headless-shell \
    HOME=/home/app \
    XDG_CACHE_HOME=/home/app/.cache

WORKDIR /home/site/wwwroot

FROM runtime-base AS integration-test

COPY --from=build /rendercheck/ /opt/rendercheck/

USER $APP_UID
ENTRYPOINT ["dotnet", "/opt/rendercheck/RenderCheck.dll"]

FROM runtime-base AS final

COPY --from=build /publish/ ./

USER $APP_UID
ENTRYPOINT ["dotnet", "ByocDotnetWorker.dll"]

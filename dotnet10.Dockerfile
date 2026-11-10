FROM mcr.microsoft.com/dotnet/sdk:10.0-noble AS build

WORKDIR /src
COPY NuGet.config ByocDotnetWorker.csproj ./
RUN dotnet restore ByocDotnetWorker.csproj --runtime linux-x64 -p:PublishReadyToRun=true
COPY *.cs host.json ./

# The worker uses its generated metadata provider, so the Core Tools launch files are not needed.
RUN dotnet publish ByocDotnetWorker.csproj --configuration Release --runtime linux-x64 --self-contained false \
    --no-restore -p:PublishReadyToRun=true --output /publish \
    && rm -f /publish/worker.config.json /publish/functions.metadata

FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble

WORKDIR /home/site/wwwroot
COPY --from=build /publish/ ./

USER $APP_UID
ENTRYPOINT ["dotnet", "ByocDotnetWorker.dll"]

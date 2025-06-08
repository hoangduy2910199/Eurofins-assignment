# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

# Copy csproj
COPY *.sln .
COPY /app/HelloWorldApi/*.csproj ./myApp/
COPY /app/HelloWorldApi/*.json ./myApp/
COPY /app/HelloWorldApi/*.cs ./myApp/
COPY /app/HelloWorldApi/Properties ./myApp/

# Restore and build
WORKDIR /app/myApp
RUN dotnet restore
RUN dotnet publish -c Release -o out

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/myApp/out .

ENTRYPOINT ["dotnet", "HelloWorldApi.dll"]

# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app

# Copy csproj and restore
COPY *.sln .
COPY ./app/HelloWorldApi/*.csproj ./myApp/
RUN dotnet restore

# Copy everything and build
COPY . .
WORKDIR /app/myApp
RUN dotnet publish -c Release -o out

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/myApp/out .

ENTRYPOINT ["dotnet", "YourProject.dll"]

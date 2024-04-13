FROM mcr.microsoft.com/dotnet/sdk:8.0-jammy AS installer

RUN dotnet tool install -g Valleysoft.Dredge --version "4.*" \
    && dotnet tool install -g Valleysoft.DockerfileSpy --version "0.2-beta"

RUN mkdir /symlinks \
    && ln -s /usr/share/powershell/pwsh /symlinks/pwsh \
    && ln -s /home/app/.dotnet/tools/dredge /symlinks/dredge \
    && ln -s /home/app/.dotnet/tools/dfspy /symlinks/dfspy


FROM mcr.microsoft.com/dotnet/runtime:8.0-jammy-chiseled

COPY --from=installer /usr/share/powershell /usr/share/powershell
COPY --from=installer /root/.dotnet/tools /home/app/.dotnet/tools
COPY --from=installer ["/symlinks", "/usr/bin"]
COPY *.ps1 /scripts/

ENTRYPOINT ["pwsh", "-c", "/scripts/entrypoint.ps1"]
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Download the latest self-hosted integration runtime installer into the SHIR folder
COPY SHIR C:/SHIR/

RUN ["powershell", "cp C:/SHIR/config/hosts C:/windows/system32/drivers/etc/hosts"]
RUN ["powershell", "cp C:/SHIR/config/tnsnames.ora C:/SHIR/tnsnames.ora"]

RUN ["powershell", "C:/SHIR/validate.ps1"]

RUN ["powershell", "C:/SHIR/build.ps1"]

ENTRYPOINT ["powershell", "C:/SHIR/setup.ps1"]

RUN net localgroup "Administrators" "User Manager\ContainerUser" /add
USER ContainerUser

ENV SHIR_WINDOWS_CONTAINER_ENV True
ENV JAVA_TOOL_OPTIONS "-Xms1024m -Xmx2048m"

HEALTHCHECK --start-period=120s CMD ["powershell", "C:/SHIR/health-check.ps1"]

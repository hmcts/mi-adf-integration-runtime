FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Download the latest self-hosted integration runtime installer into the SHIR folder
COPY SHIR C:/SHIR/

RUN ["powershell", "cp C:/SHIR/config/hosts C:/windows/system32/drivers/etc/hosts"]

RUN ["powershell", "C:/SHIR/validate.ps1"]

RUN ["powershell", "C:/SHIR/build.ps1"]

CMD ["powershell", "C:/SHIR/setup.ps1"]

ENV SHIR_WINDOWS_CONTAINER_ENV True

HEALTHCHECK --start-period=120s CMD ["powershell", "C:/SHIR/health-check.ps1"]
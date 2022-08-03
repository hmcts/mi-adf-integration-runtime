FROM mcr.microsoft.com/windows/servercore:ltsc2019

# Download the latest self-hosted integration runtime installer into the SHIR folder
COPY SHIR C:/SHIR/

RUN ["powershell", "cp C:/SHIR/config/hosts C:/windows/system32/drivers/etc/hosts"]

RUN ["powershell", "C:/SHIR/validate.ps1"]

RUN ["powershell", "C:/SHIR/build.ps1"]

CMD ["powershell", "C:/SHIR/setup.ps1"]

RUN net user /add ShirUser
RUN net localgroup docker-users /add
RUN net localgroup docker-users ShirUser /add

RUN dir /s

RUN icacls "C:\\Program Files\\Java" /grant ShirUser:(OI)(CI)F /T
RUN icacls "C:\\Program Files\\Microsoft Integration Runtime" /grant ShirUser:(OI)(CI)F /T

RUN icacls "C:\\ProgramData" /grant ShirUser:(OI)(CI)F /T
RUN icacls "C:\\SHIR" /grant ShirUser:(OI)(CI)F /T
RUN icacls "C:\\Users" /grant ShirUser:(OI)(CI)F /T

USER ShirUser

ENV SHIR_WINDOWS_CONTAINER_ENV True

HEALTHCHECK --start-period=120s CMD ["powershell", "C:/SHIR/health-check.ps1"]
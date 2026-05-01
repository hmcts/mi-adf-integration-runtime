Note: Initial code from https://github.com/Azure/Azure-Data-Factory-Integration-Runtime-in-Windows-Container

Note: Helm release charts are currently active at https://github.com/hmcts/mi-adf-shir.

Azure Data Factory Integration Runtime in Windows Container Sample
=======
This repo contains the sample for running the Azure Data Factory Integration Runtime in Windows Container

Support SHIR version: 5.0 or later

For more information about Azure Data Factory, see [https://docs.microsoft.com/en-us/azure/data-factory/concepts-integration-runtime](https://docs.microsoft.com/en-us/azure/data-factory/concepts-integration-runtime)

| Argument | Default Value | Description |
|---|---|---|
| INSTALL_JDK | true | Installs the Microsoft JDK 21 dependency. |
| INSTALL_LEGACY_JDK | false | Installs the Adopt Open JDK 17 dependency. This is already a fallback on INSTALL_JDK so does not need setting if that is set to true. |
| INSTALL_NET_FRAMEWORK | true | Installs the .NET Framework |
| INSTALL_CERT | true | Installs MS Certs |
| ADD_MONITOR_USERS | true | Adds Monitor Users |
| SETUP_ENV | false | Performs basic env changes such as stopping auto update. Not tested. |
| SHIR_FIX_VERSION | 5.65.9593.1 | If set, instead of using the download dynamic link and minimum version checking, will try to download the exact specified fix version. |

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

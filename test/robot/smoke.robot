*** Settings ***
Library    OperatingSystem

*** Test Cases ***
App Entrypoint File Exists
    File Should Exist    ${CURDIR}${/}..${/}..${/}lib${/}main.dart

App Entrypoint Uses Bootstrapper
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}lib${/}main.dart
    Should Contain    ${source}    AppBootstrapper

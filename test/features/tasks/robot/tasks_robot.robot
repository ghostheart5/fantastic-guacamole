*** Settings ***
Library    OperatingSystem

*** Test Cases ***
Tasks Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}engine${/}tasks${/}task_filter.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}state${/}providers${/}task_provider.dart

Tasks Source Exposes Provider
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}state${/}providers${/}task_provider.dart
    Should Contain    ${source}    taskProvider

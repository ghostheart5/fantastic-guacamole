*** Settings ***
Library    OperatingSystem

*** Test Cases ***
Scheduler Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}system${/}system_scheduler.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}state${/}services${/}data_hygiene_scheduler.dart

Scheduler Source Exposes Service
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}system${/}system_scheduler.dart
    Should Contain    ${source}    class SystemScheduler

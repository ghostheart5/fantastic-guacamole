*** Settings ***
Library    OperatingSystem

*** Test Cases ***
Sync Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}data${/}services${/}sync_service.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}state${/}providers${/}sync_provider.dart

Sync Source Exposes Service
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}data${/}services${/}sync_service.dart
    Should Contain    ${source}    class SyncService

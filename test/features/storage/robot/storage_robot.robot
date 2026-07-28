*** Settings ***
Library    OperatingSystem

*** Test Cases ***
Storage Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}data${/}storage${/}storage_migration.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}data${/}local${/}hive_storage.dart

Storage Source Exposes Migration
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}data${/}storage${/}storage_migration.dart
    Should Contain    ${source}    class StorageMigration

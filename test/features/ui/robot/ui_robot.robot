*** Settings ***
Library    OperatingSystem

*** Test Cases ***
UI Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}ui${/}widgets${/}offline_banner.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}ui${/}widgets${/}smart_pressable.dart

UI Source Exposes Offline Banner
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}ui${/}widgets${/}offline_banner.dart
    Should Contain    ${source}    class OfflineBanner

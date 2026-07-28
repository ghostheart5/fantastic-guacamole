*** Settings ***
Documentation    profile robot coverage checks
Library    OperatingSystem

*** Test Cases ***
Profile Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}profile${/}ui${/}profile_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}profile${/}ui${/}widgets${/}profile_header.dart

Profile Source Exposes Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}profile${/}ui${/}profile_screen.dart
    Should Contain    ${source}    class ProfileScreen


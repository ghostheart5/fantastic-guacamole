*** Settings ***
Library    OperatingSystem

*** Test Cases ***
Timeline Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}timeline${/}ui${/}timeline_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}app${/}navigation_shell.dart

Timeline Source Exposes Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}timeline${/}ui${/}timeline_screen.dart
    Should Contain    ${source}    class TimelineScreen

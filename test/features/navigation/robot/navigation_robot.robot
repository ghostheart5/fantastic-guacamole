*** Settings ***
Documentation    navigation robot coverage checks
Library    OperatingSystem

*** Test Cases ***
Navigation Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}app${/}navigation_shell.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}app${/}router${/}route_paths.dart

Navigation Shell Exists
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}app${/}navigation_shell.dart
    Should Contain    ${source}    class NavigationShell


*** Settings ***
Documentation    si_console robot coverage checks
Library    OperatingSystem

*** Test Cases ***
SI Console Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}si_console${/}ui${/}si_console_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}si_console${/}ui${/}models${/}si_console_commands.dart

SI Console Source Exposes Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}si_console${/}ui${/}si_console_screen.dart
    Should Contain    ${source}    class SIConsoleScreen


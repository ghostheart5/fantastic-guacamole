*** Settings ***
Documentation    nexus robot coverage checks
Library    OperatingSystem

*** Test Cases ***
Nexus Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}nexus${/}ui${/}nexus_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}nexus${/}ui${/}nexus_screen.widgets.dart

Nexus Source Exposes Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}nexus${/}ui${/}nexus_screen.dart
    Should Contain    ${source}    class NexusScreen


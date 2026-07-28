*** Settings ***
Documentation    action_hub robot coverage checks
Library    OperatingSystem

*** Test Cases ***
Action Hub Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}nexus${/}ui${/}nexus_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}nexus${/}ui${/}nexus_screen.widgets.dart

Action Hub Source Exposes Portal Navigation
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}nexus${/}ui${/}nexus_screen.widgets.dart
    Should Contain    ${source}    toCreator()


*** Settings ***
Documentation    progression robot coverage checks
Library    OperatingSystem

*** Test Cases ***
Progression Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}progression${/}ui${/}progression_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}progression${/}widgets${/}level_card.dart

Progression Source Exposes Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}progression${/}ui${/}progression_screen.dart
    Should Contain    ${source}    class ProgressionScreen


*** Settings ***
Documentation    tutorial robot coverage checks
Library    OperatingSystem

*** Test Cases ***
Tutorial Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}tutorial${/}tutorial_controller.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}tutorial${/}tutorial_overlay.dart

Tutorial Source Exposes Controller
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}tutorial${/}tutorial_controller.dart
    Should Contain    ${source}    class TutorialController


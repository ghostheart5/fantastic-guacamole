*** Settings ***
Documentation    creator robot coverage checks
Library    OperatingSystem

*** Test Cases ***
Creator Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}creator${/}ui${/}creator_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}creator${/}widgets${/}dynamic_form.dart

Creator Source Exposes Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}creator${/}ui${/}creator_screen.dart
    Should Contain    ${source}    class CreatorScreen


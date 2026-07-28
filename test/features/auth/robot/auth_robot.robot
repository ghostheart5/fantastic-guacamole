*** Settings ***
Library    OperatingSystem

*** Test Cases ***
Auth Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}auth${/}screens${/}auth_gate.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}auth${/}ui${/}login_screen.dart

Auth Source Exposes Login Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}auth${/}ui${/}login_screen.dart
    Should Contain    ${source}    class LoginScreen

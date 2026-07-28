*** Settings ***
Library    OperatingSystem

*** Test Cases ***
Settings Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}settings${/}ui${/}settings_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}settings${/}ui${/}settings_screen.sections.dart

Settings Source Exposes Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}settings${/}ui${/}settings_screen.dart
    Should Contain    ${source}    class SettingsScreen

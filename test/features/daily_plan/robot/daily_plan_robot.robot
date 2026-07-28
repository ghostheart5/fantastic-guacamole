*** Settings ***
Library    OperatingSystem

*** Test Cases ***
Daily Plan Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}state${/}providers${/}autonomous_daily_planner_provider.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}nexus${/}ui${/}nexus_screen.dart

Daily Plan Provider Is Wired
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}state${/}providers${/}autonomous_daily_planner_provider.dart
    Should Contain    ${source}    autonomousDailyPlannerProvider

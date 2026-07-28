*** Settings ***
Documentation    trajectory_engine robot coverage checks
Library    OperatingSystem

*** Test Cases ***
Trajectory Engine Source Files Exist
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}trajectory_engine${/}ui${/}trajectory_engine_screen.dart
    File Should Exist    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}state${/}providers${/}momentum_engine_provider.dart

Trajectory Engine Source Exposes Screen
    ${source}=    Get File    ${CURDIR}${/}..${/}..${/}..${/}..${/}lib${/}features${/}trajectory_engine${/}ui${/}trajectory_engine_screen.dart
    Should Contain    ${source}    class TrajectoryEngineScreen


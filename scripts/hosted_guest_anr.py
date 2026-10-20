"""Classify owned-guest ANR evidence without inferring a process from task dumps.

Android 35 activity lastanr may contain a timestamp/reason and a complete task
dump, rather than an ``ANR in`` line. Match that form to Android's am_anr event
(user, pid, package, flags, reason). Unknown or contradictory data fails closed.
The workflow retains its existing policy: app/process ANRs fail; unrelated
system ANRs remain recorded and cannot replace HOME/dialog readiness checks.
"""
from datetime import datetime
import re

PROCESS = r'[A-Za-z0-9_.$]+(?::[A-Za-z0-9_.$-]+)?'


def classify_anr(last_anr, event_log, app_package):
    events = []
    for line in event_log.splitlines():
        if not re.search(r'\bam_anr\s*:', line):
            continue
        match = re.fullmatch(
            r'\s*(\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\.\d+\s+'
            r'\d+\s+\d+\s+[A-Z]\s+am_anr\s*:\s*'
            r'\[(\d+),(\d+),(' + PROCESS + r'),(-?\d+),(.+)\]\s*', line,
        )
        if not match or int(match[4]) <= 0:
            raise ValueError('Malformed Android am_anr event')
        try:
            timestamp = datetime.strptime('2000-' + match[1] + ' ' + match[2], '%Y-%m-%d %H:%M:%S')
        except ValueError as error:
            raise ValueError('Invalid Android am_anr timestamp') from error
        events.append({'timestamp': timestamp, 'user': int(match[3]),
                       'pid': int(match[4]), 'process': match[5],
                       'reason': match[7].strip()})

    def is_app(process):
        return process == app_package or process.startswith(app_package + ':')

    explicit = re.findall(r'(?im)^\s*ANR in\s+(' + PROCESS + r')\s*$', last_anr)
    empty = re.search(r'(?im)^\s*<no anr has occurred since boot>\s*$', last_anr)
    process = None
    reason = None
    if empty:
        if explicit or re.search(r'(?im)^\s*ANR time:', last_anr):
            raise ValueError('Contradictory Android lastanr evidence')
        kind = 'no-last-anr'
    elif len(explicit) == 1:
        process = explicit[0]
        kind = 'explicit-process'
    else:
        stamp = re.findall(r'(?m)^\s*ANR time:\s*(.+)$', last_anr)
        reasons = re.findall(r'(?m)^\s*Reason:\s*(.+)$', last_anr)
        if (len(stamp) != 1 or len(reasons) != 1 or explicit or
                not last_anr.startswith('ACTIVITY MANAGER LAST ANR (dumpsys activity lastanr)')):
            raise ValueError('Unrecognized Android lastanr evidence')
        observed = None
        for fmt in ('%b %d, %Y %I:%M:%S %p', '%b %d, %Y, %I:%M:%S %p', '%Y-%m-%d %H:%M:%S'):
            try:
                observed = datetime.strptime(stamp[0], fmt)
                break
            except ValueError:
                pass
        if observed is None:
            raise ValueError('Unrecognized Android lastanr timestamp')
        reason = reasons[0].strip()
        matches = [event for event in events
                   if event['user'] == 0 and event['reason'] == reason
                   and event['timestamp'].month == observed.month
                   and event['timestamp'].day == observed.day
                   and abs((event['timestamp'].replace(year=observed.year) - observed).total_seconds()) <= 2]
        processes = {event['process'] for event in matches}
        if len(processes) != 1:
            raise ValueError('Android lastanr requires one timestamp/reason-matched am_anr process')
        process = next(iter(processes))
        kind = 'activity-dump-with-event'
    processes = sorted({event['process'] for event in events} | ({process} if process else set()))
    return {'determined': True, 'format': kind, 'lastAnrProcess': process,
            'lastAnrReason': reason, 'observedAnrProcesses': processes,
            'appAnrObserved': any(is_app(value) for value in processes),
            'systemAnrObserved': any(not is_app(value) for value in processes),
            'eventCount': len(events)}

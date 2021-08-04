#!/usr/bin/env python3
import datetime

try:
    time = input()
    hours, minutes = map(int, time.split(":"))
    first = datetime.timedelta(hours=hours, minutes=minutes)

    time = input()
    hours, minutes = map(int, time.split(":"))
    second = datetime.timedelta(hours=hours, minutes=minutes)

    result = first - second
except Exception:
    print("Error!")


print(
    "Total: {}:{:02d}".format(
        result // datetime.timedelta(hours=1),
        result % datetime.timedelta(hours=1) // datetime.timedelta(minutes=1),
    )
)

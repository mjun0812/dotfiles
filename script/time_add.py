#!/usr/bin/env python3
import datetime

sum_time = datetime.timedelta(hours=0, minutes=0)
while True:
    try:
        time = input()
        hours, minutes = map(int, time.split(":"))
        sum_time += datetime.timedelta(hours=hours, minutes=minutes)
    except Exception:
        break

print(
    "Total: {}:{}".format(
        sum_time // datetime.timedelta(hours=1),
        sum_time
        % datetime.timedelta(hours=1)
        // datetime.timedelta(minutes=1),
    )
)

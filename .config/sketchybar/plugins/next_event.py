#!/usr/bin/env python3
"""Print the next calendar event as "<when>|<title>", or nothing at all.

Reads Google Calendar "secret address in iCal format" URLs, one per line, from
~/.local/share/sketchybar/calendar-urls. That file lives outside this repo on
purpose: each URL grants read access to a whole calendar, so it is a credential
and must never be committed.

Fetching ICS over the network avoids macOS privacy permissions entirely, which
is why this exists rather than reading Calendar.app: sketchybar cannot be
granted Calendar access under launchd, and AeroSpace cannot be granted it at
all (its bundle declares no NSCalendarsUsageDescription). It also reaches a
work Google account that was never added to Calendar.app.

Recurring events are expanded properly rather than pattern matched: a weekly
standup's next occurrence is a real computation over RRULE, EXDATE and
per instance overrides, which is what the two libraries here are for.
"""

import datetime as dt
import os
import sys
import urllib.request

import icalendar
import recurring_ical_events

URLS_FILE = os.path.expanduser("~/.local/share/sketchybar/calendar-urls")
CACHE_FILE = os.path.expanduser("~/.cache/sketchybar/next-event")
CACHE_MAX_AGE = dt.timedelta(hours=6)
WINDOW = dt.timedelta(days=30)
FETCH_TIMEOUT = 10


def calendar_urls():
    try:
        with open(URLS_FILE) as handle:
            lines = [line.strip() for line in handle]
    except OSError:
        return []
    urls = [line for line in lines if line and not line.startswith("#")]
    # iCloud publishes calendars as webcal://, which urllib cannot open; it is
    # plain https underneath. Google's secret addresses are already https.
    return [
        "https://" + url[len("webcal://"):] if url.startswith("webcal://") else url
        for url in urls
    ]


def as_utc(value):
    """Normalise a DTSTART, which is a date for all-day events."""
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:
            value = value.astimezone()
        return value.astimezone(dt.timezone.utc)
    midnight = dt.datetime.combine(value, dt.time.min)
    return midnight.astimezone().astimezone(dt.timezone.utc)


def describe(start, all_day):
    local = start.astimezone()
    if all_day:
        return local.strftime("%a %-d %b")
    return local.strftime("%a %-d %b %H:%M")


def read_cache():
    try:
        age = dt.datetime.now() - dt.datetime.fromtimestamp(os.path.getmtime(CACHE_FILE))
        if age > CACHE_MAX_AGE:
            return None
        with open(CACHE_FILE) as handle:
            return handle.read().strip() or None
    except OSError:
        return None


def write_cache(line):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, "w") as handle:
            handle.write(line)
    except OSError:
        pass


def main():
    urls = calendar_urls()
    if not urls:
        return 0

    now = dt.datetime.now(dt.timezone.utc)
    reached_any = False
    best = None

    for url in urls:
        try:
            with urllib.request.urlopen(url, timeout=FETCH_TIMEOUT) as response:
                calendar = icalendar.Calendar.from_ical(response.read())
        except Exception:
            continue
        reached_any = True

        try:
            events = recurring_ical_events.of(calendar).between(now, now + WINDOW)
        except Exception:
            continue

        for event in events:
            raw_start = event.get("DTSTART")
            if raw_start is None:
                continue
            all_day = not isinstance(raw_start.dt, dt.datetime)
            start = as_utc(raw_start.dt)
            if start < now:
                continue  # already under way
            title = str(event.get("SUMMARY", "")).strip() or "(no title)"
            if best is None or start < best[0]:
                best = (start, all_day, title)

    if not reached_any:
        # Offline or every calendar failed: keep showing the last known event
        # rather than blanking the bar.
        cached = read_cache()
        if cached:
            print(cached)
        return 0

    if best is None:
        write_cache("")
        return 0

    start, all_day, title = best
    line = f"{describe(start, all_day)}|{title}"
    write_cache(line)
    print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())

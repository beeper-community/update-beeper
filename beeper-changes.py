#!/usr/bin/env python3
"""Compare Beeper Desktop builds against Beeper's official published notes."""

import argparse
import html
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
from urllib.parse import urlencode
from urllib.request import Request, urlopen


CHANGELOG_API = "https://www.beeper.com/wp-json/wp/v2/changelog"
UPDATE_API = "https://api.beeper.com/desktop/update-feed.json"
VERSION_RE = re.compile(r"\bv?(\d+\.\d+\.\d+)\b")


def version(text):
    match = VERSION_RE.search(str(text))
    return match.group(1) if match else None


def version_key(text):
    return tuple(map(int, text.split(".")))


def requested_version(text):
    match = re.fullmatch(r"v?(\d+\.\d+\.\d+)", text.strip())
    if not match:
        raise ValueError(f"Invalid build number: {text!r}; expected X.Y.Z")
    return match.group(1)


def get_json(url):
    request = Request(url, headers={"User-Agent": "update-beeper-changes/1.0"})
    with urlopen(request, timeout=25) as response:
        return json.load(response), response.headers


class NotesParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.active = None
        self.parts = []
        self.lines = []

    def handle_starttag(self, tag, attrs):
        if tag in {"h2", "h3", "h4", "li"} and self.active is None:
            self.active = tag
            self.parts = []
        elif tag == "br" and self.active:
            self.parts.append(" ")

    def handle_data(self, data):
        if self.active:
            self.parts.append(data)

    def handle_endtag(self, tag):
        if tag != self.active:
            return
        line = " ".join("".join(self.parts).split())
        if line:
            self.lines.append((tag, line))
        self.active = None
        self.parts = []


def plain_text(markup):
    return " ".join(html.unescape(re.sub(r"<[^>]+>", " ", markup or "")).split())


def get_releases():
    releases = {}
    page = 1
    while True:
        query = urlencode({
            "changelog-clients": 2,
            "per_page": 100,
            "page": page,
            "_fields": "date,link,title,excerpt,content,slug",
        })
        posts, headers = get_json(f"{CHANGELOG_API}?{query}")
        if not isinstance(posts, list):
            raise ValueError("Beeper changelog did not return a release list")
        for post in posts:
            # Beeper's October 5 post is titled v5.3.176 while its excerpt
            # and actual desktop build say v4.3.176. Prefer the excerpt.
            excerpt = plain_text(post.get("excerpt", {}).get("rendered", ""))
            canonical = version(excerpt) or version(post.get("title", {}).get("rendered", ""))
            if not canonical:
                continue
            title_version = version(post.get("title", {}).get("rendered", ""))
            if canonical not in releases:
                releases[canonical] = {
                    "date": post.get("date", "")[:10],
                    "link": post.get("link", ""),
                    "notes": post.get("content", {}).get("rendered", ""),
                    "title_version": title_version,
                }
        total_pages = int(headers.get("X-WP-TotalPages", "1"))
        if page >= total_pages:
            break
        if page >= 10:
            raise ValueError("Beeper changelog has more than 10 pages; comparison is incomplete")
        page += 1
    if not releases:
        raise ValueError("No Beeper Desktop releases were found")
    return releases


def installed_version():
    if sys.platform == "win32":
        paths = [
            Path(os.environ.get("LOCALAPPDATA", "")) / "Programs/BeeperTexts/Beeper.exe",
            Path(os.environ.get("ProgramFiles", "")) / "BeeperTexts/Beeper.exe",
        ]
        if os.environ.get("ProgramFiles(x86)"):
            paths.append(Path(os.environ["ProgramFiles(x86)"]) / "BeeperTexts/Beeper.exe")
        for path in paths:
            if path.is_file():
                literal_path = str(path).replace("'", "''")
                command = [
                    "powershell", "-NoProfile", "-Command",
                    f"(Get-Item -LiteralPath '{literal_path}').VersionInfo.FileVersion",
                ]
                result = subprocess.run(command, capture_output=True, text=True, timeout=15, check=True)
                return version(result.stdout)
    else:
        path = Path("/opt/beeper/resources/app/package.json")
        if path.is_file():
            return version(json.loads(path.read_text(encoding="utf-8")).get("version", ""))
    return None


def latest_version(channel):
    system = platform.system().lower()
    if system not in {"windows", "linux"}:
        raise ValueError("Automatic latest-version lookup supports Windows and Linux")
    machine = platform.machine().lower()
    if machine in {"x86_64", "amd64"}:
        arch = "x64"
    elif machine in {"aarch64", "arm64"}:
        arch = "arm64"
    else:
        raise ValueError(f"Unsupported CPU architecture: {machine}")
    query = urlencode({
        "bundleID": "com.automattic.beeper.desktop",
        "version": "0.0.0",
        "platform": system,
        "arch": arch,
        "channel": channel,
    })
    data, _ = get_json(f"{UPDATE_API}?{query}")
    result = version(data.get("version", ""))
    if not result:
        raise ValueError("Beeper update feed returned no version")
    return result


def show_changes(start, end, releases):
    low, high = sorted((start, end), key=version_key)
    direction = " (downgrade comparison)" if version_key(start) > version_key(end) else ""
    print(f"Beeper Desktop changes: {start} -> {end}{direction}")
    print("Source: official Beeper Desktop changelog")
    if direction:
        print("The notes below describe changes present in the newer build.")
    selected = sorted(
        (name for name in releases if version_key(low) < version_key(name) <= version_key(high)),
        key=version_key,
    )
    if not selected:
        print("\nNo published release notes in this range.")
    for name in selected:
        release = releases[name]
        print(f"\n{name} ({release['date']})")
        if release["title_version"] and release["title_version"] != name:
            print(f"  Note: Beeper's page title says {release['title_version']}; its excerpt says {name}.")
        parser = NotesParser()
        parser.feed(release["notes"])
        if parser.lines:
            for kind, line in parser.lines:
                print(f"  {'- ' if kind == 'li' else ''}{line}")
        else:
            print("  No itemized notes published.")
        print(f"  {release['link']}")
    newest = max(releases, key=version_key)
    if high not in releases:
        print(f"\nNo release notes are published for build {high}.")
    if version_key(high) > version_key(newest):
        print(f"Latest published notes cover {newest}; newer builds may contain undocumented changes.")
    if version_key(low) < version_key(min(releases, key=version_key)):
        print("The starting build predates the available changelog archive.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from", dest="start", help="Starting build (defaults to installed version)")
    parser.add_argument("--to", dest="end", help="Ending build (defaults to latest selected channel)")
    parser.add_argument("--channel", choices=("stable", "nightly"), default="stable")
    args = parser.parse_args()
    start = requested_version(args.start) if args.start else installed_version()
    if not start:
        parser.error("could not detect installed Beeper; pass --from VERSION")
    end = requested_version(args.end) if args.end else latest_version(args.channel)
    if not end:
        parser.error("invalid ending version")
    show_changes(start, end, get_releases())


if __name__ == "__main__":
    if sys.platform == "win32":
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"beeper-changes: {exc}", file=sys.stderr)
        sys.exit(1)

"""Validate release metadata and restore the CI keystore without logging secrets."""

import base64
import binascii
import os
from pathlib import Path
import re
import sys


def metadata():
    tag = os.environ.get("RELEASE_TAG", "")
    match = re.fullmatch(r"v(\d+\.\d+\.\d+)", tag)
    if not match:
        raise ValueError("Release tag must be vMAJOR.MINOR.PATCH, for example v1.0.0")
    version = match.group(1)
    pubspec = Path("pubspec.yaml").read_text()
    source = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec, re.MULTILINE)
    if source is None:
        raise ValueError("pubspec.yaml version must be MAJOR.MINOR.PATCH+BUILD")
    try:
        run_number = int(os.environ["GITHUB_RUN_NUMBER"])
        offset = int(os.environ.get("BUILD_OFFSET", "1"))
    except (KeyError, ValueError):
        raise ValueError("Workflow run number and build offset must be integers") from None
    build_number = run_number + offset
    if run_number < 1 or offset < 0 or not int(source.group(2)) < build_number <= 2100000000:
        raise ValueError("Build number must exceed pubspec build number and fit Android's versionCode limit")
    with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
        output.write(f"version={version}\nbuild_number={build_number}\n")
    print(f"Release {version}, build {build_number}")


def keystore():
    required = (
        "ANDROID_KEYSTORE_BASE64",
        "ANDROID_KEYSTORE_PASSWORD",
        "ANDROID_KEY_ALIAS",
        "ANDROID_KEY_PASSWORD",
        "ANDROID_KEYSTORE_PATH",
    )
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise ValueError("Missing signing configuration: " + ", ".join(missing))
    try:
        encoded = "".join(os.environ["ANDROID_KEYSTORE_BASE64"].split())
        decoded = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error):
        raise ValueError("ANDROID_KEYSTORE_BASE64 is not valid Base64") from None
    if not decoded:
        raise ValueError("Keystore must not be empty")
    path = Path(os.environ["ANDROID_KEYSTORE_PATH"])
    with path.open("xb") as output:
        path.chmod(0o600)
        output.write(decoded)


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["metadata"]:
            metadata()
        elif sys.argv[1:] == ["keystore"]:
            keystore()
        else:
            raise ValueError("Usage: android_release.py metadata|keystore")
    except ValueError as error:
        sys.exit(str(error))

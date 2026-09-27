"""Grade the upstream Rustlings exercises individually, one point per pass."""

import os
import re
import subprocess
import sys
import tempfile
import tomllib

from course import COURSE, ROOT, record, run, write_result


def validate_catalog():
    exercises = tomllib.loads((ROOT / "info.toml").read_text())["exercises"]
    actual = [{key: item[key] for key in ("name", "path", "mode")} for item in exercises]
    expected = [{key: item[key] for key in ("name", "path", "mode")} for item in COURSE["tests"]]
    if actual != expected:
        raise ValueError("Exercise catalog differs from the course rubric; no score was produced.")
    for exercise in exercises:
        path = (ROOT / exercise["path"]).resolve()
        if not path.is_relative_to(ROOT / "exercises") or not path.is_file():
            raise ValueError("Missing or invalid exercise file: " + exercise["path"])


def passed(test, code, output):
    if code != 0:
        return False
    if test["mode"] in ("test", "buildscript"):
        return bool(re.search(r"test result: ok\. [1-9][0-9]* passed; 0 failed;", output))
    return "Successfully ran " + test["path"] in output


def main():
    os.chdir(ROOT)
    output = ROOT / "tmp/grade"
    output.mkdir(parents=True, exist_ok=True)
    os.environ["TMPDIR"] = str(ROOT / "tmp")
    os.environ["CARGO_TARGET_DIR"] = str(ROOT / "tmp/target")
    os.environ["CARGO_TERM_COLOR"] = "never"
    os.environ["NO_EMOJI"] = "1"
    # A failed checker build is an infrastructure failure, not a student score.
    validate_catalog()
    subprocess.run(["cargo", "clippy", "--version"], check=True)
    subprocess.run(["cargo", "build", "--locked", "--release", "--bin", "rustlings"], check=True)
    checker = ROOT / "tmp/target/release/rustlings"
    results = []
    # Separate Cargo artifacts from the checker. Clippy cleans its own target,
    # and build-script exercises must use a fresh timestamp on every grading run.
    with tempfile.TemporaryDirectory(prefix="exercise-target-", dir=ROOT / "tmp") as target:
        os.environ["CARGO_TARGET_DIR"] = target
        for test in COURSE["tests"]:
            print(f"::group::{test['name']}", flush=True)
            with (output / (test["name"] + ".log")).open("w") as log:
                code, text = run([str(checker), "--nocapture", "run", test["name"]], log, ROOT, seconds=20)
            results.append(record(test, code, passed(test, code, text)))
            print("::endgroup::", flush=True)
    write_result(results)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        sys.exit(str(error))

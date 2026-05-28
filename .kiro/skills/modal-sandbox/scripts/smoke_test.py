#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sys
import uuid

import modal


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Provision a Modal Sandbox and verify basic exec and file IO."
    )
    parser.add_argument(
        "--app-name",
        default="codex-modal-sandbox-smoke-test",
        help="Modal App name to look up or create.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Sandbox lifetime in seconds.",
    )
    parser.add_argument(
        "--no-terminate",
        action="store_true",
        help="Leave the sandbox running after the smoke test completes.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sandbox: modal.Sandbox | None = None

    if args.timeout < 1:
        print("Timeout must be a positive integer.", file=sys.stderr)
        return 2

    app = modal.App.lookup(args.app_name, create_if_missing=True)
    sleep_seconds = max(120, min(args.timeout, 3600))
    test_dir = f"/tmp/modal-sandbox-smoke-{uuid.uuid4().hex}"
    test_path = f"{test_dir}/marker.txt"
    exec_marker = "MODAL_SANDBOX_EXEC_OK"
    file_marker = "MODAL_SANDBOX_FILE_OK"

    try:
        sandbox = modal.Sandbox.create(
            "sh",
            "-lc",
            f"sleep {sleep_seconds}",
            app=app,
            image=modal.Image.debian_slim(),
            timeout=args.timeout,
        )

        print(f"Sandbox ID: {sandbox.object_id}")
        print(f"Attach with: modal shell {sandbox.object_id}")

        # Test exec
        process = sandbox.exec("sh", "-lc", f"printf '{exec_marker}'")
        process.wait()
        stdout = process.stdout.read()
        stderr = process.stderr.read()

        if process.returncode != 0:
            raise RuntimeError(
                f"exec failed with return code {process.returncode}: {stderr}"
            )
        if stdout != exec_marker:
            raise RuntimeError(f"exec returned {stdout!r}, expected {exec_marker!r}")

        # Test new filesystem API (SDK 1.4.0+)
        sandbox.exec("mkdir", "-p", test_dir).wait()
        sandbox.filesystem.write_text(test_path, file_marker)

        listing = sandbox.filesystem.list_files(test_dir)
        file_names = [entry.path.split("/")[-1] for entry in listing]
        if "marker.txt" not in file_names:
            raise RuntimeError(f"expected marker.txt in {file_names!r}")

        contents = sandbox.filesystem.read_text(test_path)
        if contents != file_marker:
            raise RuntimeError(
                f"file IO returned {contents!r}, expected {file_marker!r}"
            )

        sandbox.filesystem.remove(test_path)
        sandbox.filesystem.remove(test_dir)

        print("Smoke test passed.")
        return 0
    except Exception as exc:
        print(f"Smoke test failed: {exc}", file=sys.stderr)
        return 1
    finally:
        if sandbox is not None and not args.no_terminate:
            try:
                sandbox.terminate()
                print(f"Terminated sandbox: {sandbox.object_id}")
            except Exception as exc:
                print(f"Cleanup warning: {exc}", file=sys.stderr)
        elif sandbox is not None:
            print(f"Sandbox left running: {sandbox.object_id}")


if __name__ == "__main__":
    raise SystemExit(main())

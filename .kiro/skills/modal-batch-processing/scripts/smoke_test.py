#!/usr/bin/env python3

from __future__ import annotations

import sys

import modal

APP_NAME = "codex-modal-batch-processing-smoke-test"

app = modal.App(APP_NAME)


@app.function()
def square(value: int) -> int:
    return value * value


@app.function()
def add(left: int, right: int) -> int:
    return left + right


@app.function()
def increment(value: int) -> int:
    return value + 1


@app.cls(max_containers=1)
class Batcher:
    @modal.batched(max_batch_size=4, wait_ms=200)
    def scale(self, values: list[int]) -> list[int]:
        return [value * 10 for value in values]


def assert_equal(name: str, actual, expected) -> None:
    if actual != expected:
        raise AssertionError(f"{name} failed: expected {expected!r}, got {actual!r}")
    print(f"[PASS] {name}")


def run_smoke_test() -> int:
    try:
        with app.run():
            map_results = list(square.map([0, 1, 2, 3, 4]))
            assert_equal("map", map_results, [0, 1, 4, 9, 16])

            starmap_results = list(add.starmap([(1, 2), (3, 4), (5, 6)]))
            assert_equal("starmap", starmap_results, [3, 7, 11])

            spawned_calls = [increment.spawn(10), increment.spawn(20)]
            gathered_results = modal.FunctionCall.gather(*spawned_calls)
            assert_equal("spawn + gather", gathered_results, [11, 21])

            retrieved_call = increment.spawn(30)
            restored_call = modal.FunctionCall.from_id(retrieved_call.object_id)
            retrieved_result = restored_call.get(timeout=30)
            assert_equal("spawn + from_id + get", retrieved_result, 31)

            batcher = Batcher()
            batched_results = list(batcher.scale.map([1, 2, 3, 4, 5]))
            assert_equal("batched class method", batched_results, [10, 20, 30, 40, 50])

        print("Smoke test passed.")
        return 0
    except Exception as exc:
        print(f"Smoke test failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(run_smoke_test())

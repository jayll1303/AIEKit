#!/usr/bin/env python3
"""
VRAM Estimator for ML Brainstorming.

Estimates GPU memory requirements for training and inference scenarios.
Recommends approach and suggests relevant AIEKit skill.

Usage:
    python vram_estimator.py --model-size 7 --method qlora
    python vram_estimator.py --model-size 70 --method inference --dtype int4
    python vram_estimator.py --model-size 13 --method full --available-vram 24
"""

import argparse
import sys


# VRAM multipliers (bytes per parameter)
DTYPE_BYTES = {
    "fp32": 4.0,
    "fp16": 2.0,
    "bf16": 2.0,
    "int8": 1.0,
    "int4": 0.5,
}

# Training overhead multipliers (on top of model weights)
# Includes optimizer states, gradients, activations
TRAINING_MULTIPLIERS = {
    "full": 4.0,       # weights + optimizer(2x) + gradients + activations
    "lora": 1.2,       # base weights frozen + small adapter overhead
    "qlora": 1.1,      # 4-bit base + small adapter overhead
    "unsloth": 0.7,    # Unsloth optimized QLoRA (~70% less than standard)
}

# Adapter overhead (approximate, for LoRA/QLoRA)
ADAPTER_RATIO = {
    "lora": 0.002,     # ~0.2% of params trainable
    "qlora": 0.002,
    "unsloth": 0.002,
}

METHODS = ["full", "lora", "qlora", "unsloth", "inference"]
DTYPES = list(DTYPE_BYTES.keys())


def estimate_vram(
    model_size_b: float,
    method: str,
    dtype: str = "fp16",
    seq_length: int = 2048,
) -> dict:
    """Estimate VRAM in GB for given configuration."""
    params = model_size_b * 1e9

    if method == "inference":
        bytes_per_param = DTYPE_BYTES[dtype]
        model_vram = (params * bytes_per_param) / (1024**3)
        # KV cache overhead: ~1-2 GB for typical seq lengths
        kv_overhead = min(2.0, model_size_b * 0.15) * (seq_length / 2048)
        total = model_vram + kv_overhead
        return {
            "model_vram_gb": round(model_vram, 1),
            "kv_cache_gb": round(kv_overhead, 1),
            "total_gb": round(total, 1),
            "method": method,
            "dtype": dtype,
        }

    if method == "full":
        bytes_per_param = DTYPE_BYTES.get(dtype, 2.0)
        model_vram = (params * bytes_per_param) / (1024**3)
        total = model_vram * TRAINING_MULTIPLIERS["full"]
        return {
            "model_vram_gb": round(model_vram, 1),
            "optimizer_gb": round(model_vram * 2, 1),
            "gradients_gb": round(model_vram, 1),
            "total_gb": round(total, 1),
            "method": method,
            "dtype": dtype,
        }

    if method in ("qlora", "unsloth"):
        # Base model in 4-bit
        base_vram = (params * DTYPE_BYTES["int4"]) / (1024**3)
        # Adapter params in fp16
        adapter_params = params * ADAPTER_RATIO[method]
        adapter_vram = (adapter_params * DTYPE_BYTES["fp16"] * 3) / (1024**3)
        multiplier = TRAINING_MULTIPLIERS[method]
        total = base_vram * multiplier + adapter_vram
        # Gradient checkpointing saves ~30%
        total_with_gc = total * 0.7
        return {
            "base_model_gb": round(base_vram, 1),
            "adapter_gb": round(adapter_vram, 1),
            "total_gb": round(total, 1),
            "total_with_grad_ckpt_gb": round(total_with_gc, 1),
            "method": method,
        }

    if method == "lora":
        base_vram = (params * DTYPE_BYTES.get(dtype, 2.0)) / (1024**3)
        adapter_params = params * ADAPTER_RATIO["lora"]
        adapter_vram = (adapter_params * DTYPE_BYTES["fp16"] * 3) / (1024**3)
        total = base_vram * TRAINING_MULTIPLIERS["lora"] + adapter_vram
        return {
            "base_model_gb": round(base_vram, 1),
            "adapter_gb": round(adapter_vram, 1),
            "total_gb": round(total, 1),
            "method": method,
            "dtype": dtype,
        }

    return {"error": f"Unknown method: {method}"}


def suggest_approach(model_size_b: float, available_vram: float) -> list:
    """Suggest best training approaches given VRAM constraint."""
    suggestions = []

    for method in ["unsloth", "qlora", "lora", "full"]:
        est = estimate_vram(model_size_b, method)
        vram_key = "total_with_grad_ckpt_gb" if "total_with_grad_ckpt_gb" in est else "total_gb"
        needed = est[vram_key]

        fits = needed <= available_vram
        suggestions.append({
            "method": method,
            "vram_needed_gb": needed,
            "fits": fits,
            "skill": _method_to_skill(method),
        })

    return suggestions


def _method_to_skill(method: str) -> str:
    skill_map = {
        "full": "hf-transformers-trainer",
        "lora": "hf-transformers-trainer",
        "qlora": "hf-transformers-trainer",
        "unsloth": "unsloth-training",
        "inference": "vllm-tgi-inference",
    }
    return skill_map.get(method, "unknown")


def format_output(est: dict, available_vram: float | None = None) -> str:
    """Format estimation results for display."""
    lines = []
    lines.append(f"{'='*50}")
    lines.append(f"  VRAM Estimation: {est['method'].upper()}")
    lines.append(f"{'='*50}")

    for k, v in est.items():
        if k in ("method", "dtype"):
            continue
        label = k.replace("_", " ").replace("gb", "(GB)").title()
        lines.append(f"  {label}: {v}")

    if available_vram:
        fits = est.get("total_with_grad_ckpt_gb", est.get("total_gb", 0)) <= available_vram
        status = "✅ FITS" if fits else "❌ DOES NOT FIT"
        lines.append(f"\n  Available VRAM: {available_vram} GB")
        lines.append(f"  Status: {status}")

    lines.append(f"\n  Suggested skill: {_method_to_skill(est['method'])}")
    lines.append(f"{'='*50}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Estimate VRAM for ML training/inference scenarios"
    )
    parser.add_argument(
        "--model-size", type=float, required=True,
        help="Model size in billions of parameters (e.g., 7, 13, 70)"
    )
    parser.add_argument(
        "--method", type=str, required=True, choices=METHODS,
        help="Training/inference method"
    )
    parser.add_argument(
        "--dtype", type=str, default="fp16", choices=DTYPES,
        help="Data type (default: fp16)"
    )
    parser.add_argument(
        "--seq-length", type=int, default=2048,
        help="Sequence length for inference KV cache estimation (default: 2048)"
    )
    parser.add_argument(
        "--available-vram", type=float, default=None,
        help="Available GPU VRAM in GB — shows fit/no-fit and suggests alternatives"
    )

    args = parser.parse_args()

    est = estimate_vram(args.model_size, args.method, args.dtype, args.seq_length)

    if "error" in est:
        print(f"Error: {est['error']}", file=sys.stderr)
        sys.exit(1)

    print(format_output(est, args.available_vram))

    if args.available_vram:
        total = est.get("total_with_grad_ckpt_gb", est.get("total_gb", 0))
        if total > args.available_vram:
            print(f"\n{'='*50}")
            print("  ALTERNATIVE APPROACHES")
            print(f"{'='*50}")
            suggestions = suggest_approach(args.model_size, args.available_vram)
            for s in suggestions:
                status = "✅" if s["fits"] else "❌"
                print(f"  {status} {s['method']:10s} — {s['vram_needed_gb']:6.1f} GB → {s['skill']}")


if __name__ == "__main__":
    main()

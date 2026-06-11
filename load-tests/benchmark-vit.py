"""
BloodConnect ViT Prediction Benchmark

Measures inference latency and throughput for the Medical ViT model
on both CPU and GPU (if available).

Usage:
    python load-tests/benchmark-vit.py
    python load-tests/benchmark-vit.py --iterations 500 --warmup 50

Output: prints benchmark results in markdown-ready format.
"""

import time
import statistics
import argparse
import io
from pathlib import Path

import torch
from PIL import Image
from torchvision import transforms

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ai-service"))

from main import MedicalViT, PARAM_ORDER, denormalize  # noqa: E402


def create_dummy_image(size=(224, 224)):
    """Create a random RGB image for benchmarking."""
    import numpy as np
    arr = np.random.randint(0, 256, (*size, 3), dtype=np.uint8)
    return Image.fromarray(arr)


def benchmark_device(device, model, transform, dummy_tensor, iterations, warmup):
    """Run benchmark on a given device (cpu or cuda)."""
    print(f"\n  Device: {device}")
    print(f"  Warming up ({warmup} iterations)...")
    model.to(device)
    model.eval()
    dummy = dummy_tensor.to(device)

    for _ in range(warmup):
        with torch.no_grad():
            model(dummy)

    torch.cuda.synchronize() if device.type == "cuda" else None

    print(f"  Measuring ({iterations} iterations)...")
    latencies = []
    for _ in range(iterations):
        start = time.perf_counter()
        with torch.no_grad():
            model(dummy)
        if device.type == "cuda":
            torch.cuda.synchronize()
        latencies.append((time.perf_counter() - start) * 1000)

    latencies.sort()
    avg_ms = statistics.mean(latencies)
    p50 = latencies[int(len(latencies) * 0.50)]
    p95 = latencies[int(len(latencies) * 0.95)]
    p99 = latencies[int(len(latencies) * 0.99)]
    rps = 1000 / avg_ms

    return {
        "device": str(device),
        "avg_ms": round(avg_ms, 2),
        "p50_ms": round(p50, 2),
        "p95_ms": round(p95, 2),
        "p99_ms": round(p99, 2),
        "rps": round(rps, 1),
    }


def main():
    parser = argparse.ArgumentParser(description="ViT Prediction Benchmark")
    parser.add_argument("--iterations", type=int, default=200, help="Number of iterations per device")
    parser.add_argument("--warmup", type=int, default=50, help="Warmup iterations")
    parser.add_argument("--batch-size", type=int, default=1, help="Batch size")
    args = parser.parse_args()

    print("=" * 60)
    print("BloodConnect ViT Prediction Benchmark")
    print("=" * 60)

    model_path = Path(__file__).resolve().parent.parent / "ai-service" / "vit_medical_best.pt"
    if not model_path.exists():
        print(f"\nModel not found at {model_path}")
        print("Creating a mock model for benchmarking structure...")
        model = MedicalViT.create_mock() if hasattr(MedicalViT, 'create_mock') else None
        if model is None:
            print("ERROR: Cannot benchmark without model file.")
            print(f"Place the model at: {model_path}")
            sys.exit(1)
    else:
        print(f"\nLoading model from {model_path}...")
        state_dict = torch.load(model_path, map_location="cpu")
        model = MedicalViT(state_dict)
        model.load_state_dict(state_dict, strict=True)

    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225],
        ),
    ])

    image = create_dummy_image()
    tensor = transform(image).unsqueeze(0)
    if args.batch_size > 1:
        tensor = tensor.repeat(args.batch_size, 1, 1, 1)

    print(f"\nModel parameters: ~{sum(p.numel() for p in model.parameters()):,}")
    print(f"Input shape: {tuple(tensor.shape)}")
    print(f"Iterations: {args.iterations}  Warmup: {args.warmup}  Batch: {args.batch_size}")

    results = []

    # CPU benchmark
    cpu_result = benchmark_device(
        torch.device("cpu"), model, transform, tensor,
        args.iterations, args.warmup,
    )
    results.append(cpu_result)

    # GPU benchmark (if available)
    if torch.cuda.is_available():
        gpu_result = benchmark_device(
            torch.device("cuda"), model, transform, tensor,
            args.iterations, args.warmup,
        )
        results.append(gpu_result)
        speedup = cpu_result["avg_ms"] / gpu_result["avg_ms"]
        print(f"\n  GPU Speedup: {speedup:.1f}x vs CPU (avg latency)")
    else:
        print("\n  No CUDA device found — CPU-only benchmark.")

    # Summary table
    print("\n" + "─" * 60)
    print("RESULTS")
    print("─" * 60)
    header = f"  {'Device':<8} {'Avg (ms)':<12} {'p50 (ms)':<12} {'p95 (ms)':<12} {'p99 (ms)':<12} {'RPS':<10}"
    print(header)
    print("  " + "─" * (len(header) - 2))
    for r in results:
        print(f"  {r['device']:<8} {r['avg_ms']:<12} {r['p50_ms']:<12} {r['p95_ms']:<12} {r['p99_ms']:<12} {r['rps']:<10}")
    print("─" * 60)

    print("\nMarkdown table:")
    print(f"| Device | Avg (ms) | p50 | p95 | p99 | RPS |")
    print(f"|--------|----------|-----|-----|-----|-----|")
    for r in results:
        print(f"| {r['device']} | {r['avg_ms']} | {r['p50_ms']} | {r['p95_ms']} | {r['p99_ms']} | {r['rps']} |")


if __name__ == "__main__":
    main()

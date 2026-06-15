"""Download Qwen2-VL-2B-Instruct model files to local models/ folder."""
import os
import sys

os.environ["HF_HUB_DOWNLOAD_TIMEOUT"] = "3600"

from huggingface_hub import hf_hub_download

MODEL_ID = "retal16/Qwen2-VL-2B-Instruct"
LOCAL_DIR = "./models/Qwen2-VL-2B-Instruct"

FILES = [
    "config.json",
    "preprocessor_config.json",
    "tokenizer_config.json",
    "vocab.json",
    "merges.txt",
    "tokenizer.json",
    "chat_template.json",
    "model.safetensors.index.json",
    "model-00001-of-00002.safetensors",
    "model-00002-of-00002.safetensors",
]

os.makedirs(LOCAL_DIR, exist_ok=True)

for filename in FILES:
    dest = os.path.join(LOCAL_DIR, filename)
    if os.path.exists(dest):
        size_mb = os.path.getsize(dest) / (1024 * 1024)
        print(f"[SKIP] {filename} ({size_mb:.1f} MB) - already exists")
        continue
    print(f"[DOWNLOAD] {filename} ...")
    try:
        path = hf_hub_download(MODEL_ID, filename, local_dir=LOCAL_DIR)
        size_mb = os.path.getsize(path) / (1024 * 1024)
        print(f"  -> Saved to {path} ({size_mb:.1f} MB)")
    except Exception as e:
        print(f"  -> FAILED: {e}")
        sys.exit(1)

print("\nAll files downloaded! You can now run: python main.py")

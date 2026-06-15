# Fine-tuned Qwen2-VL-2B Medical Adapter

This folder contains the LoRA adapter for Qwen2-VL-2B fine-tuned for CBC report extraction and clinical decision support.

## Files
- `adapter_config.json` - LoRA adapter configuration
- `adapter_model.safetensors` - Trained LoRA weights (you need to copy this file)

## Usage
The adapter is loaded with the base model `Qwen/Qwen2-VL-2B-Instruct` for inference.
#!/usr/bin/env bats
# Tests for profile functions: core_skills, profile_*, all_skills
# Feature: installer-redesign, Task 7.1

load 'test_helper'

@test "core_skills returns exactly 6 skills" {
  run core_skills
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 6 ]
}

@test "core_skills returns the correct 6 skill names" {
  run core_skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"aie-skills-installer"* ]]
  [[ "$output" == *"python-project-setup"* ]]
  [[ "$output" == *"python-ml-deps"* ]]
  [[ "$output" == *"hf-hub-datasets"* ]]
  [[ "$output" == *"docker-gpu-setup"* ]]
  [[ "$output" == *"notebook-workflows"* ]]
}

@test "profile_llm returns exactly 4 skills" {
  run profile_llm
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 4 ]
}

@test "profile_llm returns correct skills" {
  run profile_llm
  [ "$status" -eq 0 ]
  [[ "$output" == *"hf-transformers-trainer"* ]]
  [[ "$output" == *"unsloth-training"* ]]
  [[ "$output" == *"model-quantization"* ]]
  [[ "$output" == *"experiment-tracking"* ]]
}

@test "profile_inference returns exactly 6 skills" {
  run profile_inference
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 6 ]
}

@test "profile_inference returns correct skills" {
  run profile_inference
  [ "$status" -eq 0 ]
  [[ "$output" == *"vllm-tgi-inference"* ]]
  [[ "$output" == *"sglang-serving"* ]]
  [[ "$output" == *"llama-cpp-inference"* ]]
  [[ "$output" == *"ollama-local-llm"* ]]
  [[ "$output" == *"tensorrt-llm"* ]]
  [[ "$output" == *"triton-deployment"* ]]
}

@test "profile_speech returns exactly 4 skills" {
  run profile_speech
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 4 ]
}

@test "profile_speech returns correct skills" {
  run profile_speech
  [ "$status" -eq 0 ]
  [[ "$output" == *"k2-training-pipeline"* ]]
  [[ "$output" == *"sherpa-onnx"* ]]
  [[ "$output" == *"hf-speech-to-speech-pipeline"* ]]
  [[ "$output" == *"openai-audio-api"* ]]
}

@test "profile_cv returns exactly 2 skills" {
  run profile_cv
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 2 ]
}

@test "profile_cv returns correct skills" {
  run profile_cv
  [ "$status" -eq 0 ]
  [[ "$output" == *"ultralytics-yolo"* ]]
  [[ "$output" == *"paddleocr"* ]]
}

@test "profile_rag returns exactly 2 skills" {
  run profile_rag
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 2 ]
}

@test "profile_rag returns correct skills" {
  run profile_rag
  [ "$status" -eq 0 ]
  [[ "$output" == *"text-embeddings-rag"* ]]
  [[ "$output" == *"text-embeddings-inference"* ]]
}

@test "profile_backend returns exactly 3 skills" {
  run profile_backend
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -w)
  [ "$count" -eq 3 ]
}

@test "profile_backend returns correct skills" {
  run profile_backend
  [ "$status" -eq 0 ]
  [[ "$output" == *"fastapi-at-scale"* ]]
  [[ "$output" == *"opentelemetry"* ]]
  [[ "$output" == *"python-quality-testing"* ]]
}

@test "all_skills returns exactly 30 unique skills" {
  run all_skills
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | tr ' ' '\n' | sort -u | grep -c .)
  [ "$count" -eq 30 ]
}

@test "all_skills includes standalone skills arxiv-reader and freqtrade" {
  run all_skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"arxiv-reader"* ]]
  [[ "$output" == *"freqtrade"* ]]
}

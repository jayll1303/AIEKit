# Notebook Guide Implementation Plan

## Goal
Tạo guide cho agent làm việc với Jupyter/Colab notebook files (.ipynb), gồm 2 components:

## Tasks

- [x] T1: Tạo Steering `notebook-conventions.md` (fileMatch cho `**/*.ipynb`)
  - Rules/conventions khi agent đọc/ghi .ipynb
  - JSON structure awareness
  - Commit best practices (clear output, metadata)

- [x] T2: Tạo Skill `notebook-workflows` 
  - SKILL.md: core workflows (create, edit, execute cells, parse output)
  - references/ipynb-structure.md: chi tiết JSON schema của .ipynb
  - references/colab-features.md: Colab-specific (mount drive, GPU, magic commands)
  - references/notebook-best-practices.md: best practices, linting, testing

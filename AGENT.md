# Ascend S9 Operator Project Initialization Agent

You are working in a fresh Ascend S9 operator competition workspace. Your job is to initialize the shared repository and create one git worktree per operator. Do not optimize kernels yet.

At the beginning, the workspace contains only:

```text
.
├── AGENT.md
└── init.sh
```

Run the initializer first:

```bash
bash init.sh
```

## Required Top-Level Layout

After `init.sh`, the top-level workspace must look like:

```text
.
├── AGENT.md
├── init.sh
├── JUDGE.zip
├── TASK.png
├── repo/
├── tmp/
└── worktrees/
```

Important path rule: `tmp/` is top-level `./tmp`, not `repo/tmp`. The task XLSX is under `./tmp/*.xlsx`. Operator workspaces are under `./repo/<OpName>/`. Git worktrees are under `./worktrees/<OpName>/`.

`repo/` should initially contain one directory per operator discovered from `tmp/case_910b/`:

```text
repo/
├── Concat/
├── Greater/
├── IndexAdd/
├── SquareSumV1/
└── Transpose/
```

Each operator directory initially contains:

```text
repo/<OpName>/
├── <OpName>.json
├── docs/
│   └── TASK.md
├── judge/
│   ├── common/
│   │   └── pytorch_npu_helper.hpp
│   ├── extension/
│   │   └── custom_op.cpp
│   ├── get_time.py
│   ├── run.sh
│   ├── setup.py
│   └── test_op.py
├── pack.sh
└── release/
```

If `init.sh` fails, fix only workspace-local inputs such as missing URLs or malformed archives. Do not rename operator directories.

## Source Of Truth

Use the task document and judge files to fill each operator specification:

1. Prefer top-level `tmp/*.xlsx` as the source of truth.
2. Also inspect top-level `TASK.png` if possible.
3. If the PNG and XLSX disagree, follow the XLSX and record the difference in `repo/<OpName>/docs/TASK.md`.
4. The judge files under `repo/<OpName>/judge/` are the executable compatibility target. If the task document interface conflicts with the judge files, follow the judge files, record the conflict in `docs/TASK.md`, and update related files such as `<OpName>.json` when needed.

## Complete Each Operator In `repo/`

For every operator directory discovered from `tmp/case_910b/`, work under `repo/<OpName>/`.

### 1. Complete `docs/TASK.md`

Open `repo/<OpName>/docs/TASK.md`. It already contains a title and template sections written by `init.sh`.

Fill it in English with concise information from the task document:

- Reference PyTorch operator or expression.
- Complete the `2.1 Parameters` table created by `init.sh`.
- Keep table cells short. The table is only for parameter metadata: `Kind`, `Name`, `Type`, `DType(s)`, `Format`, `Required`, and `Default`.
- Add or remove table rows as needed so the table matches the real operator interface.
- Put operator behavior under `2.2 Semantics`, not in the table.
- Put shape ranges, rank rules, broadcasting rules, and output-shape formulas under `2.3 Shape Rules`.
- Put non-32-aligned shapes, empty inputs, `inf`, `-inf`, `NaN`, negative axes, duplicate indices, and similar boundary conditions under `2.4 Edge Cases`.
- Put wrapper signatures, extra helper arguments such as `output_shape`, and task-vs-judge conflicts under `2.5 Judge Compatibility`.
- Use `2.6 Open Questions` only for unresolved issues. Write `- None` when everything is resolved.
- Special cases from the task document, such as broadcasting, non-32-aligned shapes, `inf`, `-inf`, or `NaN`.
- Any discrepancy between XLSX, PNG, and judge files.

Do not delete the existing title or section structure. Keep the parameter table present and complete. Keep the document short and useful for implementation.

### 2. Complete `<OpName>.json`

Open `repo/<OpName>/<OpName>.json`. `init.sh` writes this minimal skeleton:

```json
[
    {
        "op": "<OpName>"
    }
]
```

Complete the JSON interface specification required by `msopgen`.

Critical rules:

- Do not delete, rename, or rewrite the existing `"op"` field.
- Do not change an operator name. For example, keep `"op": "Concat"`, not `"ConcatCustom"`.
- Add `input_desc`, `output_desc`, and `attr` entries from the task document.
- Use TensorFlow framework generation, so choose JSON fields compatible with:

```bash
msopgen gen -i <OpName>.json -f tf -c ai_core-ascend910b -lan cpp -out <OpName>
```

Use these conversion rules when filling JSON from the XLSX:

- Tensor rows with `Classify = INPUT` become `input_desc` entries.
- Tensor rows with `Classify = OUTPUT` become `output_desc` entries.
- Attribute rows with `Classify = ATTR` become `attr` entries.
- `tensor_list` inputs should use `"param_type": "dynamic"`.
- Normal tensor inputs and outputs should use `"param_type": "required"`.
- Use `"format": ["ND", ...]` and `"type": [...]` arrays of the same length.
- `msopgen` expects every input and output of one operator to use lists of the same length. If a tensor has only one valid dtype, repeat that dtype and format to match the main data tensor list length. For example, `Greater.output` can use five `"bool"` entries when the inputs have five dtype entries, and `IndexAdd.index` can use five `"int32"` entries.
- Dtype mapping: `float` and `float32` -> `fp32`, `float16` -> `fp16`, `bfloat16` -> `bf16`, `int32` -> `int32`, `int8` -> `int8`, `bool` -> `bool`.
- Attribute types from the task document can be used directly, such as `int`, `bool`, and `list_int`.
- If an attribute has a default value, prefer `"param_type": "optional"` and add `"default_value": <value>`. If no default is listed, use `"param_type": "required"`.

For this S9 task set, the XLSX currently describes these operators:

- `Concat`: reference `torch.cat`; dynamic input `inputs`; attr `dim` default `0`; output `output`; dtypes `fp32`, `fp16`, `int32`, `int8`; format `ND`; dimensions `N, N2 in [1, 10000]`, `N3, N4 in [1, 1000]`; non-32-aligned cases are required.
- `Greater`: reference `torch.gt`; inputs `self` and `other`; output `output` dtype `bool`; input dtypes `fp32`, `bf16`, `fp16`, `int32`, `int8`; format `ND`; broadcasting and `inf`, `-inf`, `NaN` comparison cases are required.
- `IndexAdd`: reference `torch.index_add`; inputs `self`, `index`, `source`; attr `dim` default `0`; output `output`; `index` dtype `int32`; data dtypes `fp32`, `bf16`, `fp16`, `int32`, `int8`; `M in [1, 8000]`; `source` length along `dim` equals `index` length.
- `Transpose`: reference `torch.permute`; input `inputs`; attr `dims` type `list_int`; output `output`; dtypes `fp32`, `fp16`, `int32`, `int8`; format `ND`; dimensions include `N5`, and non-32-aligned cases are required.
- `SquareSumV1`: reference `torch.sum(X ** 2, dim=axis, keepdim=keep_dims)`; input `input`; attrs `axis` type `list_int`, `keep_dims` type `bool` default `false`; output `output`; dtypes `fp16`, `bf16`, `fp32`; format `ND`; output shape is determined by `axis` and `keep_dims`.

### 3. Run `msopgen`

From the operator directory under `repo/`, run exactly:

```bash
cd repo/<OpName>
msopgen gen -i <OpName>.json -f tf -c ai_core-ascend910b -lan cpp -out <OpName>
cd ../..
```

Do not run `msopgen` from the workspace root with a nested output path. The generated project must appear as `repo/<OpName>/<OpName>/`.

After completing one operator, its directory should look like:

```text
repo/<OpName>/
├── <OpName>/
│   ├── build.sh
│   ├── cmake/
│   ├── CMakeLists.txt
│   ├── CMakePresets.json
│   ├── framework/
│   ├── op_host/
│   ├── op_kernel/
│   └── scripts/
├── <OpName>.json
├── docs/
│   └── TASK.md
├── .gitignore
├── judge/
├── pack.sh
└── release/
```

## Initialize Git And Worktrees

After every operator has a completed `docs/TASK.md`, completed JSON, and generated `repo/<OpName>/<OpName>/` project, initialize git in `repo/`.

Run from the top-level workspace:

```bash
cd repo
git init -b main
git add .
git commit -m init
cd ..
```

If `git init -b main` is not supported by the installed git, run:

```bash
cd repo
git init
git checkout -B main
git add .
git commit -m init
cd ..
```

Then create one branch and one worktree per operator:

```bash
mkdir -p worktrees
cd repo
for op in $(find ../tmp/case_910b -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort); do
    git branch "dev/${op}" main
    git worktree add "../worktrees/${op}" "dev/${op}"
done
cd ..
```

The final branch and worktree state should look like:

```text
repo$ git branch -a
+ dev/Concat
+ dev/Greater
+ dev/IndexAdd
+ dev/SquareSumV1
+ dev/Transpose
* main

workspace$ ls worktrees/
Concat  Greater  IndexAdd  SquareSumV1  Transpose
```

## Final Checklist

Before stopping, verify:

- Top-level `tmp/` exists and contains `case_910b/` plus the XLSX.
- `repo/` is a git repository on branch `main`.
- `repo/` contains all initialized operators.
- Every operator has a completed English `docs/TASK.md`.
- Every operator JSON still has the original `"op": "<OpName>"` field.
- Every operator has generated source under `repo/<OpName>/<OpName>/`.
- `git -C repo log --oneline -1` shows the `init` commit.
- `git -C repo branch -a` shows `main` plus `dev/<OpName>` branches.
- `worktrees/<OpName>/` exists for every operator.
- Top-level `tmp/` was not moved under `repo/`.

After this checklist passes, the initialization task is complete.

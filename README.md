# 【昇腾AI创新大赛-算子挑战赛】自动化入口

## 前置准备

- codex cli / claude code / ...

## 使用方法

```sh
git clone https://github.com/hbswcsyzx/ascend-sx.git
cd ascend-sx
rm -rf .git
rm -rf README.md
codex "read AGENT.md and initialize structure"
```

## 效果

```text
.
├── AGENT.md
├── init.sh*
├── JUDGE.zip
├── README.md
├── repo/
│   ├── Concat/
│   │   ├── Concat/
│   │   │   ├── build.sh*
│   │   │   ├── cmake/
│   │   │   ├── CMakeLists.txt
│   │   │   ├── CMakePresets.json
│   │   │   ├── framework/
│   │   │   ├── op_host/
│   │   │   ├── op_kernel/
│   │   │   └── scripts/
│   │   ├── Concat.json
│   │   ├── docs/
│   │   │   └── TASK.md
│   │   ├── judge/
│   │   │   ├── common/
│   │   │   ├── extension/
│   │   │   ├── get_time.py
│   │   │   ├── run.sh
│   │   │   ├── setup.py
│   │   │   └── test_op.py
│   │   ├── pack.sh*
│   │   └── release/
│   ├── Greater/...
│   ├── IndexAdd/...
│   ├── SquareSumV1/...
│   └── Transpose/...
├── TASK.png
├── tmp/
│   ├── case_910b/...
│   ├── init_pybind.sh
│   ├── S9挑战性能赛题.xlsx
│   └── 调用样例说明.txt
└── worktrees/
    ├── Concat/
    │   ├── Concat/
    │   ├── Greater/
    │   ├── IndexAdd/
    │   ├── SquareSumV1/
    │   └── Transpose/
    ├── Greater/...
    ├── IndexAdd/...
    ├── SquareSumV1/...
    └── Transpose/...
```

```sh
$ git -C ./repo branch -a
+ dev/Concat
+ dev/Greater
+ dev/IndexAdd
+ dev/SquareSumV1
+ dev/Transpose
* main
```

## 后续

```sh
for wt in ./worktrees/*; do
    [[ -d "$wt" ]] || continue
    wt_abs="$(realpath "$wt")"
    op="$(basename "$wt")"
    prompt="read ${op}/AGENT.md and develop the ${op} operator"

    tmux new-session -d -s "$op" \
        codex \
        --cd "$wt_abs" \
        -c "projects.\"${wt_abs}\".trust_level=\"trusted\"" \
        --sandbox danger-full-access \
        --ask-for-approval never \
        "$prompt"
done
```

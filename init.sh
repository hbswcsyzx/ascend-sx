#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fill these URLs before running in a fresh competition workspace.
# If JUDGE.zip or TASK.png already exists beside this script, the matching
# download is skipped.
ZIP_URL=https://public-download.obs.cn-east-2.myhuaweicloud.com/%E7%AE%97%E5%AD%90%E6%8C%91%E6%88%98%E8%B5%9BS9/%E7%AE%97%E5%AD%90%E6%8C%91%E6%88%98%E8%B5%9BS9%E8%B5%9B%E9%A2%98.zip
PNG_URL=https://www.hiascend.com/p/resource/202606/91664dd8748d4f059189eb36e7336b17.png

JUDGE_ZIP="${SCRIPT_PATH}/JUDGE.zip"
TASK_PNG="${SCRIPT_PATH}/TASK.png"
TMP_DIR="${SCRIPT_PATH}/tmp"
REPO_DIR="${SCRIPT_PATH}/repo"
WORKTREES_DIR="${SCRIPT_PATH}/worktrees"

download_if_missing() {
    local url="$1"
    local output="$2"
    local label="$3"

    if [[ -s "${output}" ]]; then
        echo "[init] ${label} already exists: ${output}"
        return
    fi
    if [[ -f "${output}" ]]; then
        echo "[init] Removing empty or incomplete ${label}: ${output}"
        rm -f "${output}"
    fi
    if [[ -z "${url}" || "${url}" == "TODO" ]]; then
        echo "[init] Missing ${label}. Set the URL in init.sh or place ${output} manually." >&2
        exit 1
    fi

    echo "[init] Downloading ${label}..."
    local tmp_output
    tmp_output="$(mktemp "${output}.download.XXXXXX")"
    if ! wget -O "${tmp_output}" "${url}"; then
        rm -f "${tmp_output}"
        echo "[init] Failed to download ${label} from ${url}" >&2
        exit 1
    fi
    if [[ ! -s "${tmp_output}" ]]; then
        rm -f "${tmp_output}"
        echo "[init] Downloaded ${label} is empty: ${url}" >&2
        exit 1
    fi
    mv "${tmp_output}" "${output}"
}

copy_judge_files() {
    local src="$1"
    local dst="$2"

    mkdir -p "${dst}/judge" "${dst}/release"
    cp -a "${src}/." "${dst}/judge/"
}

write_pack_script() {
    local dst="$1"

    cat > "${dst}/pack.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OP_NAME="$(basename "${SCRIPT_PATH}")"

mkdir -p "${SCRIPT_PATH}/release"
rm -rf "${SCRIPT_PATH}/${OP_NAME}/build_out"
rm -rf "${SCRIPT_PATH}/${OP_NAME}/.home"
rm -rf "${SCRIPT_PATH}/${OP_NAME}/.local_opp"
cd "${SCRIPT_PATH}"
zip -r "release/${OP_NAME}_$(date +%Y%m%d_%H%M).zip" "./${OP_NAME}"
EOF
    chmod +x "${dst}/pack.sh"
}

write_gitignore() {
    local dst="$1"

    cat > "${dst}/.gitignore" <<'EOF'
# Build
**/build/
**/build_out/
**/.home/
**/.local_opp/
**/.python_ops/
**/dist/
**/cmake-build-*/
*.o
*.a
*.so

# Clangd
.cache/

# Python
**/__pycache__/
*.py[cod]
*.egg-info/
*.whl

# Logs and profiling
*.log
*.dump
PROF*/
OPPROF*/
extra-info/

# Editor
.vscode/
.idea/
.DS_Store
EOF
}

write_task_stub() {
    local op="$1"
    local dst="$2"

    mkdir -p "${dst}/docs"
    if [[ -f "${dst}/docs/TASK.md" ]]; then
        return
    fi

    cat > "${dst}/docs/TASK.md" <<EOF
# ${op} Specification

> Workspace: \`repo/${op}/\`
> Judge files: \`repo/${op}/judge/\`
> Fill this document from top-level \`TASK.png\` and \`tmp/*.xlsx\`. If the interface specification conflicts with the judge files, use the judge files as the source of truth and update related files when needed.

## 1. Task Definition

- Reference operator: TODO
- Reference behavior:

\`\`\`python
TODO
\`\`\`

## 2. Interface Specification

### 2.1 Parameters

| Kind | Name | Type | DType(s) | Format | Required | Default |
| --- | --- | --- | --- | --- | --- | --- |
| INPUT | TODO | TODO | TODO | TODO | yes | - |
| ATTR | TODO | TODO | - | - | TODO | TODO |
| OUTPUT | TODO | TODO | TODO | TODO | yes | - |

### 2.2 Semantics

- TODO

### 2.3 Shape Rules

- TODO

### 2.4 Edge Cases

- TODO

### 2.5 Judge Compatibility

- TODO

### 2.6 Open Questions

- TODO

## 3. Development Workflow

1. Complete \`${op}.json\` from the task document without changing the existing \`op\` field.
2. Run \`msopgen gen -i ${op}.json -f tf -c ai_core-ascend910b3 -lan cpp -out ${op}\` from this directory.
3. Expand \`judge/test_op.py\` with deterministic correctness cases before optimizing performance.
4. Implement and optimize the Ascend C operator. Use profiling data before making performance changes.

## 4. Notes

1. Install the generated operator into the generated project's local \`.local_opp\` directory when testing.
2. Select an idle NPU before running performance or correctness tests.
EOF
}

write_operator_agent() {
    local op="$1"
    local dst="$2"

    if [[ -f "${dst}/AGENT.md" ]]; then
        return
    fi

    cat > "${dst}/AGENT.md" <<EOF
# ${op} Development Agent

You are developing only the \`${op}\` operator. Codex may start in \`worktrees/${op}/\`; this file lives at \`${op}/AGENT.md\`.

## Path Basis

Before using the paths or commands in this file, enter the operator root:

\`\`\`bash
cd ${op}
\`\`\`

All following paths are relative to the operator root:

\`\`\`text
${op}/                    # operator root, contains this AGENT.md
├── judge/                # judge wrapper and Python extension
└── ${op}/                # generated Ascend C project
    ├── build.sh
    ├── build_out/
    ├── .home/            # temporary HOME for .run self-extraction
    └── .local_opp/       # local custom OPP install target
\`\`\`

Never install the custom OPP into operator-root \`.local_opp/\`. Use only \`${op}/.local_opp/\` under the generated project.

## Scope

- Primary operator directory: \`${op}/\`
- Generated project: \`${op}/${op}/\`
- Specification: \`docs/TASK.md\`
- Interface JSON: \`${op}.json\`
- Judge files: \`judge/\`
- Packaging script: \`pack.sh\`

## Required First Steps

1. Read this file.
2. Read \`docs/TASK.md\`.
3. Read \`judge/test_op.py\`, \`judge/extension/custom_op.cpp\`, and \`judge/run.sh\`.
4. Read \`${op}.json\`.
5. Inspect the generated host and kernel stubs under \`${op}/${op}/op_host/\` and \`${op}/${op}/op_kernel/\`.

## Skill And Documentation Rules

- Use \`agent-skills-local\` before planning or coding when workflow, implementation, testing, profiling, or optimization choices are involved.
- Discover local skills from \`\$AGENT_SKILLS_HOME\`; do not hard-code the path.
- Use \`asc-devkit-local\` before assuming any Ascend C API signature, dtype support, alignment rule, queue behavior, pipeline behavior, or performance restriction.
- Read Ascend documentation from \`\$ASC_DEVKIT_HOME\` when API details are uncertain.
- Use available \`@ops-registry-invoke\` / CANNBot skills when they match the task, especially for API best practices, tiling, precision debugging, runtime debugging, profiling, and UT/ST expansion.
- Do not guess Ascend C APIs. Verify against installed CANN headers, generated code, local docs, or examples first.

## Source Of Truth

- \`judge/\` is the executable compatibility target.
- If \`docs/TASK.md\` or \`${op}.json\` conflicts with \`judge/\`, follow \`judge/\`, then update the docs and JSON to match.
- Keep the operator name exactly \`${op}\`; do not rename it to a custom suffix.

## Development Workflow

1. Make \`docs/TASK.md\` and \`${op}.json\` consistent with the judge interface.
2. Ensure \`${op}/${op}/\` exists. If it is missing, run:

   \`\`\`bash
   msopgen gen -i ${op}.json -f tf -c ai_core-ascend910b3 -lan cpp -out ${op}
   \`\`\`

3. Implement host tiling and kernel code in the generated project.
4. Expand judge tests before performance optimization. Cover boundary shapes, dtype variants, deterministic random cases, non-32-aligned cases, and judge-specific edge cases.
5. Validate correctness with \`judge/run.sh\` or the narrowest available judge command.
6. Only optimize after correctness passes. Use profiling data before changing performance-sensitive code.
7. Commit changes on the current \`dev/${op}\` branch when the operator reaches a meaningful checkpoint.

## Local Build, Install, And Judge Commands

Run from the operator root after \`cd ${op}\`. Device 3 is hard-coded for this workspace.

Build the generated Ascend C project:

\`\`\`bash
cd ${op}
ASCEND_RT_VISIBLE_DEVICES=3 bash build.sh
cd ..
\`\`\`

Install the generated custom OPP locally under the generated project:

\`\`\`bash
cd ${op}/build_out
HOME=../.home \\
ASCEND_RT_VISIBLE_DEVICES=3 \\
./custom_opp_openEuler_aarch64.run --quiet \\
--install-path=../.local_opp
cd ../..
\`\`\`

Install the judge wheel into \`judge/.python_ops/\` and run with \`PYTHONPATH\`:

\`\`\`bash
cd judge
source ../${op}/.local_opp/vendors/customize/bin/set_env.bash
python3 -m pip install --target "\$PWD/.python_ops" --force-reinstall dist/*.whl
ASCEND_RT_VISIBLE_DEVICES=3 \\
PYTHONPATH="\$PWD/.python_ops:\$PYTHONPATH" \\
msprof --application="python3 test_op.py 1"
cd ..
\`\`\`

Later test runs do not need to rebuild or reinstall:

\`\`\`bash
cd judge
source ../${op}/.local_opp/vendors/customize/bin/set_env.bash
ASCEND_RT_VISIBLE_DEVICES=3 \\
PYTHONPATH="\$PWD/.python_ops:\$PYTHONPATH" \\
msprof --application="python3 test_op.py 1"
cd ..
\`\`\`

## Guardrails

- Keep changes scoped to this operator directory.
- Do not edit files under \`\$ASC_DEVKIT_HOME\` or \`\$AGENT_SKILLS_HOME\`.
- Do not remove judge files.
- Do not change judge interface specifications. You may only add or enrich judge test cases when requested.
- Do not commit build artifacts, profiling dumps, or local install outputs.
- Generated local state such as \`${op}/.home/\`, \`${op}/.local_opp/\`, and \`judge/.python_ops/\` should remain ignored.
EOF
}

write_json_stub() {
    local op="$1"
    local dst="$2"

    if [[ -f "${dst}/${op}.json" ]]; then
        return
    fi

    cat > "${dst}/${op}.json" <<EOF
[
    {
        "op": "${op}"
    }
]
EOF
}

download_if_missing "${ZIP_URL}" "${JUDGE_ZIP}" "judge archive"
download_if_missing "${PNG_URL}" "${TASK_PNG}" "task image"

echo "[init] Extracting judge archive to top-level tmp/..."
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
UNZIP_DIR="$(mktemp -d)"
trap 'rm -rf "${UNZIP_DIR}"' EXIT
unzip -q "${JUDGE_ZIP}" -d "${UNZIP_DIR}"

ROOT_DIR="$(find "${UNZIP_DIR}" -mindepth 1 -maxdepth 1 -type d -print -quit)"
if [[ -z "${ROOT_DIR}" ]]; then
    echo "[init] Could not find the extracted root directory in ${JUDGE_ZIP}." >&2
    exit 1
fi
cp -a "${ROOT_DIR}/." "${TMP_DIR}/"

CASE_DIR="${TMP_DIR}/case_910b"
if [[ ! -d "${CASE_DIR}" ]]; then
    echo "[init] Missing expected judge directory: tmp/case_910b" >&2
    exit 1
fi

mkdir -p "${REPO_DIR}" "${WORKTREES_DIR}"

echo "[init] Creating operator workspaces under repo/..."
shopt -s nullglob
for judge_dir in "${CASE_DIR}"/*; do
    [[ -d "${judge_dir}" ]] || continue
    op="$(basename "${judge_dir}")"
    op_dir="${REPO_DIR}/${op}"

    mkdir -p "${op_dir}"
    copy_judge_files "${judge_dir}" "${op_dir}"
    write_pack_script "${op_dir}"
    write_gitignore "${op_dir}"
    write_operator_agent "${op}" "${op_dir}"
    write_task_stub "${op}" "${op_dir}"
    write_json_stub "${op}" "${op_dir}"
    echo "[init] Prepared repo/${op}"
done

echo "[init] Done."

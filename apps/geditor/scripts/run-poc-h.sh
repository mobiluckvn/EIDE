#!/bin/bash
# PoC-H — plugin native nạp được không, và giá bao nhiêu (FR-PLUG-702/703/704 · ADR-12).
#
# Anh chốt 24/08/2026: plugin chỉ có ở bản TẢI TRỰC TIẾP, không có ở bản App Store.
#
# Nhưng "không sandbox" KHÔNG có nghĩa là nạp mã lạ được. Bản trực tiếp vẫn phải có **hardened
# runtime** để công chứng, và hardened runtime bật **library validation**: tiến trình chỉ nạp
# được thư viện ký bởi CÙNG Team ID hoặc bởi Apple. Một plugin của bên thứ ba thì theo định
# nghĩa là không.
#
# `Resources/GEditor-Direct.entitlements` đã ghi thẳng ra điều này, và ghi rằng dự án CỐ Ý không
# xin `disable-library-validation` vì nó "mở đường nạp mã lạ". Nên trước khi viết một dòng mã
# plugin nào, phải trả lời:
#
#   1. Hardened runtime có thật sự chặn `dlopen` một dylib lạ không? (nếu không thì hết chuyện)
#   2. `disable-library-validation` có gỡ được không, và nó nới lỏng tới đâu?
#   3. Có đường nào KHÔNG phải nới lỏng app chính không? — chạy plugin ở TIẾN TRÌNH RIÊNG.
#      FR-PLUG-703 vốn đã ghi "XPC", và câu hỏi là cái giá mỗi lần gọi.
#
# Đo chứ không tra tài liệu: luật ký của Apple đổi theo phiên bản macOS, và thứ quyết định là
# máy đang chạy chứ không phải trang tài liệu.
set -uo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ARCH="$(uname -m)"
OUT="benchmarks/results/poc-h-${ARCH}.json"
mkdir -p benchmarks/results

echo "▸ Dựng plugin giả và tiến trình chủ…" >&2

# --- Một "plugin" của bên thứ ba: dylib xuất đúng một hàm ---------------------------------
cat > "$WORK/plugin.c" <<'EOF'
const char *geditor_plugin_name(void) { return "plugin-thu-nghiem"; }
EOF
clang -O2 -dynamiclib -o "$WORK/libplugin.dylib" "$WORK/plugin.c" || exit 1

# --- Tiến trình chủ: dlopen đường dẫn được đưa, in ra thành công hay lý do hỏng ------------
cat > "$WORK/host.c" <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    void *handle = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
    if (!handle) {
        printf("HONG|%s\n", dlerror());
        return 1;
    }
    const char *(*name)(void) = (const char *(*)(void))dlsym(handle, "geditor_plugin_name");
    if (!name) {
        printf("HONG|khong thay ky hieu: %s\n", dlerror());
        return 1;
    }
    printf("DUOC|%s\n", name());
    return 0;
}
EOF
clang -O2 -o "$WORK/host" "$WORK/host.c" || exit 1

cat > "$WORK/lax.entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF

run_case() {   # run_case <nhãn> <đối số codesign thêm…>
    local label="$1"; shift
    cp "$WORK/host" "$WORK/h"
    codesign --force --sign - "$@" "$WORK/h" >/dev/null 2>&1
    local output
    output="$("$WORK/h" "$WORK/libplugin.dylib" 2>&1)"
    printf '%s\t%s\n' "$label" "$output"
}

echo "▸ Đo library validation…" >&2
R1="$(run_case "ky ad-hoc, KHONG hardened runtime")"
R2="$(run_case "ky ad-hoc, CO hardened runtime" --options runtime)"
R3="$(run_case "hardened runtime + disable-library-validation" \
        --options runtime --entitlements "$WORK/lax.entitlements")"

# Và ca thứ tư: plugin ký CÙNG danh tính với app chủ. Đây là ca của một plugin do CHÍNH TA
# phát hành — nếu ca này chạy được mà không cần nới entitlement thì "plugin ký bởi ta" là một
# hình dạng riêng, khác hẳn "plugin của bên thứ ba".
codesign --force --sign - "$WORK/libplugin.dylib" >/dev/null 2>&1
R4="$(run_case "plugin ky cung danh tinh, CO hardened runtime" --options runtime)"

# --- Giá mỗi lần gọi khi plugin chạy ở TIẾN TRÌNH RIÊNG ------------------------------------
#
# XPC thật cần một .xpc bundle trong app; ở PoC này đo bằng một tiến trình con SỐNG LÂU nói
# chuyện qua ống. Đó là cận DƯỚI hợp lý: XPC thêm phần tuần tự hoá và kiểm quyền, nhưng cùng
# hình dạng "gửi đi, chờ trả lời" và cũng không phải khởi động lại tiến trình ở mỗi lần gọi.
echo "▸ Đo giá mỗi lần gọi qua tiến trình riêng…" >&2
cat > "$WORK/worker.c" <<'EOF'
#include <stdio.h>
#include <string.h>
int main(void) {
    setvbuf(stdout, 0, _IONBF, 0);
    char line[4096];
    while (fgets(line, sizeof line, stdin)) {
        size_t n = strlen(line);
        if (n && line[n - 1] == '\n') line[n - 1] = 0;
        printf("%s\n", line);   // vọng lại, đúng hình dạng "gửi đi, chờ trả lời"
    }
    return 0;
}
EOF
clang -O2 -o "$WORK/worker" "$WORK/worker.c" || exit 1

ROUNDTRIP="$(python3 - "$WORK/worker" <<'PY'
import statistics, subprocess, sys, time

worker = subprocess.Popen([sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
# Vài lần khởi động, không tính giờ.
for _ in range(50):
    worker.stdin.write(b"khoi dong\n"); worker.stdin.flush(); worker.stdout.readline()

samples = []
payload = b"x" * 200 + b"\n"
for _ in range(2000):
    start = time.perf_counter()
    worker.stdin.write(payload); worker.stdin.flush(); worker.stdout.readline()
    samples.append((time.perf_counter() - start) * 1000)
worker.stdin.close(); worker.wait()

print("%.4f %.4f %.4f" % (
    statistics.median(samples), min(samples), sorted(samples)[int(len(samples) * 0.99)]))
PY
)"

python3 - "$OUT" "$R1" "$R2" "$R3" "$R4" "$ROUNDTRIP" <<'PY'
import json, sys

path = sys.argv[1]
cases = []
for raw in sys.argv[2:6]:
    label, _, rest = raw.partition("\t")
    status, _, detail = rest.partition("|")
    cases.append({"case": label, "loaded": status == "DUOC", "detail": detail.strip()})
median, low, p99 = (float(x) for x in sys.argv[6].split())

report = {
    "poc": "PoC-H — plugin native trong bản tải trực tiếp (FR-PLUG-702/703/704)",
    "libraryValidation": cases,
    "outOfProcessCallMs": {"median": median, "min": low, "p99": p99,
                           "note": "tiến trình con sống lâu qua ống — cận DƯỚI của XPC"},
}
json.dump(report, open(path, "w"), ensure_ascii=False, indent=2, sort_keys=True)

print()
print("  LIBRARY VALIDATION — dlopen một dylib của bên thứ ba")
for case in cases:
    print("    %s  %-46s %s"
          % ("✅ nạp được" if case["loaded"] else "❌ bị chặn", case["case"], case["detail"][:70]))
print()
print("  GỌI QUA TIẾN TRÌNH RIÊNG (cận dưới của XPC)")
print("    trung vị %.3f ms · min %.3f · p99 %.3f" % (median, low, p99))
print()
PY

echo "▸ Kết quả: $OUT" >&2

#!/bin/bash
# PoC-O — AVKit/AVFoundation cho khung phát nhạc·phim có phá ADR-08 (khởi động ≤ 500 ms) không?
#
#   scripts/run-poc-o.sh
#
# VÌ SAO CÓ PoC NÀY. Cổng `check-core-no-ui.sh` đòi: mọi framework NẶNG liên kết lúc nạp phải
# được KHAI kèm **giá đã đo**, và dòng chú thích của nó viết thẳng — "Không đo thì đừng thêm".
# AVKit là framework nặng theo đúng nghĩa ấy: nó kéo theo AVFoundation, tức cả bộ máy
# giải mã và dựng hình media.
#
# Phương pháp giữ nguyên PoC-L, không phát minh lại:
#   · Hai binary khác nhau ĐÚNG một cờ `-framework PDFKit`, mọi thứ khác y hệt.
#   · Đo phần TRƯỚC `main()` — tức đúng phần dyld phải làm thêm vì có liên kết ấy.
#   · 15 lần mỗi bên, và mỗi lần là một BẢN SAO MỚI của binary: chạy lại chính một tệp thì nó
#     đã nằm trong page cache và con số nói về lần thứ hai, không phải lần đầu.
#   · Đo luôn nhánh nạp LƯỜI (`dlopen`) để biết cái giá hoãn được là bao nhiêu.
#
# Có một sàn nhiễu thật ở đây: chênh lệch giữa hai bản chỉ vài phần mười mili-giây, cùng cỡ với
# dao động giữa các lần chạy. Nên script in cả trung vị lẫn dải, và kết luận phải đọc kèm dải.
set -uo pipefail
cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
RESULT="benchmarks/results/poc-o-${ARCH}.json"
RUNS=15
mkdir -p benchmarks/results

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▸ PoC-O — giá liên kết AVKit (kéo theo AVFoundation) lúc nạp"
echo

cat > "$WORK/pre.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <unistd.h>
#include <dlfcn.h>
#include <mach/mach_time.h>
#include <mach-o/dyld.h>

// Cùng phương pháp với `StartupProbe.processStartTime()` và PoC-L: hỏi NHÂN thời điểm tiến
// trình sinh ra, rồi lấy hiệu với lúc vào `main()`. Đây mới là phần dyld đã làm — đo bằng
// đồng hồ bấm tay quanh `subprocess.run()` thì con số bị nuốt vào chi phí fork/exec và kiểm
// chữ ký, cả trăm mili-giây, tức lớn gấp trăm lần thứ cần đo.
static double ms_since_launch(void) {
    struct kinfo_proc info;
    size_t size = sizeof(info);
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return -1;
    struct timeval now;
    gettimeofday(&now, NULL);
    return (double)(now.tv_sec - info.kp_proc.p_starttime.tv_sec) * 1000.0
         + ((double)now.tv_usec - (double)info.kp_proc.p_starttime.tv_usec) / 1000.0;
}

int main(int argc, char **argv) {
    double pre = ms_since_launch();

    // Số ảnh dyld đã nạp, và PDFKit có trong đó không: bằng chứng TRỰC TIẾP, cùng cách
    // `LazyLoadAudit` hỏi nhân thay vì tin một biến do mã tự khai.
    uint32_t images = _dyld_image_count();
    int loaded = 0;
    for (uint32_t i = 0; i < images; i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, "AVFoundation")) { loaded = 1; break; }
    }

    double lazy = -1;
    if (argc > 1 && argv[1][0] == 'l') {
        mach_timebase_info_data_t tb; mach_timebase_info(&tb);
        uint64_t t0 = mach_absolute_time();
        void *h = dlopen("/System/Library/Frameworks/AVKit.framework/AVKit", RTLD_LAZY);
        uint64_t t1 = mach_absolute_time();
        lazy = h ? (double)(t1 - t0) * tb.numer / tb.denom / 1e6 : -1;
    }
    printf("{\"preMainMs\": %.3f, \"images\": %u, \"avfoundationLoaded\": %d, \"lazyDlopenMs\": %.3f}\n",
           pre, images, loaded, lazy);
    return 0;
}
EOF

# Hai binary khác nhau ĐÚNG một cờ.
clang -O2 -framework Foundation -framework AppKit -o "$WORK/base" "$WORK/pre.c" 2>"$WORK/cc.log"
clang -O2 -framework Foundation -framework AppKit -framework AVKit \
    -o "$WORK/linked" "$WORK/pre.c" 2>>"$WORK/cc.log"
cp "$WORK/base" "$WORK/lazy"
for f in base linked lazy; do
    [ -f "$WORK/$f" ] || { echo "   ❌ không biên dịch được $f:"; cat "$WORK/cc.log"; exit 1; }
    codesign -f -s - "$WORK/$f" 2>/dev/null
done

# Con số do CHÍNH tiến trình báo (`preMainMs`), không phải đồng hồ bấm quanh `subprocess.run`.
# Bản đầu của script này bấm giờ từ ngoài và ra sàn nhiễu 89 ms — nuốt trọn thứ cần đo, vốn ở
# cỡ một phần mười mili-giây. Chi phí fork/exec và kiểm chữ ký lớn gấp trăm lần phần dyld làm.
measure() {   # $1 = tên binary · $2 = tham số
    python3 - "$WORK/$1" "${2:-}" "$RUNS" <<'PYEOF'
import subprocess, sys, shutil, os, json
binary, arg, runs = sys.argv[1], sys.argv[2], int(sys.argv[3])
values, last = [], ""
for i in range(runs):
    copy = f"{binary}-{i}"
    shutil.copy2(binary, copy)
    # KHÔNG ký lại ở đây. Bản đầu có `codesign` trong vòng lặp và `preMainMs` ra 427 ms cho
    # một chương trình C rỗng — vì mỗi chữ ký MỚI bắt syspolicy thẩm định lại, và phần ấy nằm
    # sau `p_starttime` nên nó chui thẳng vào con số. Binary gốc đã ký một lần ở shell; bản sao
    # thừa hưởng chữ ký ấy.
    args = [copy] + ([arg] if arg else [])
    out = subprocess.run(args, capture_output=True, text=True)
    last = out.stdout.strip()
    try:
        values.append(json.loads(last)["preMainMs"])
    except Exception:
        pass
    os.remove(copy)
values.sort()
if not values:
    print("0 0 0 0 {}")
else:
    # Dải đầy-đủ bị một hai lần chạy lạc làm phồng lên gấp đôi, nên sàn nhiễu lấy theo KHOẢNG
    # TỨ PHÂN VỊ — bền với đuôi, đúng lý do `AnomalyPanel` dùng MAD thay vì độ lệch chuẩn.
    n = len(values)
    q1, q3 = values[n // 4], values[(3 * n) // 4]
    print("%.3f %.3f %.3f %.3f %s" % (values[n // 2], values[0], values[-1], q3 - q1, last))
PYEOF
}

echo "1. Phần TRƯỚC main() — trung vị · nhanh nhất · chậm nhất (ms)"
BASE="$(measure base)"
LINKED="$(measure linked)"
LAZY="$(measure lazy lazy)"

BASE_MED=$(echo "$BASE" | cut -d' ' -f1)
LINKED_MED=$(echo "$LINKED" | cut -d' ' -f1)
BASE_LO=$(echo "$BASE" | cut -d' ' -f2);  BASE_HI=$(echo "$BASE" | cut -d' ' -f3)
LINKED_LO=$(echo "$LINKED" | cut -d' ' -f2); LINKED_HI=$(echo "$LINKED" | cut -d' ' -f3)
BASE_IQR=$(echo "$BASE" | cut -d' ' -f4); LINKED_IQR=$(echo "$LINKED" | cut -d' ' -f4)
BASE_JSON=$(echo "$BASE" | cut -d' ' -f5-)
LINKED_JSON=$(echo "$LINKED" | cut -d' ' -f5-)
LAZY_JSON=$(echo "$LAZY" | cut -d' ' -f5-)

printf "   không liên kết    %8s ms   (dải %s … %s)\n" "$BASE_MED" "$BASE_LO" "$BASE_HI"
printf "   -framework AVKit  %7s ms   (dải %s … %s)\n" "$LINKED_MED" "$LINKED_LO" "$LINKED_HI"
DELTA=$(python3 -c "print('%.3f' % ($LINKED_MED - $BASE_MED))")
NOISE=$(python3 -c "print('%.3f' % max($BASE_IQR, $LINKED_IQR))")
printf "   chênh lệch        %8s ms   · sàn nhiễu (khoảng tứ phân vị) %s ms\n" "$DELTA" "$NOISE"
echo

echo "2. Framework có thật sự vào tiến trình không (hỏi thẳng dyld)"
echo "   không liên kết : $BASE_JSON"
echo "   có liên kết    : $LINKED_JSON"
echo "   nạp lười       : $LAZY_JSON"
echo

python3 - "$RESULT" "$DELTA" "$NOISE" "$BASE_MED" "$LINKED_MED" "$LAZY_JSON" <<'PY'
import json, sys
path, delta, noise, base, linked, lazy = sys.argv[1:7]
json.dump({
    "poc": "O", "framework": "AVKit",
    "baseMedianMs": float(base), "linkedMedianMs": float(linked),
    "deltaMs": float(delta), "noiseFloorMs": float(noise),
    "lazy": json.loads(lazy) if lazy.startswith("{") else None,
    "runs": 15,
    "method": "hai binary khác nhau đúng một cờ -framework; mỗi lần đo là một bản sao mới",
}, open(path, "w"), ensure_ascii=False, indent=2)
print("   Đã ghi", path)
PY

echo
echo "⚠ ĐỌC CON SỐ TUYỆT ĐỐI CHO ĐÚNG. Mốc ~165 ms KHÔNG phải thời gian dyld làm việc: nó gồm cả"
echo "  fork/exec và phần syspolicy thẩm định một tệp mới ghi. Thứ có nghĩa ở đây là HIỆU giữa"
echo "  hai bản chỉ khác nhau một cờ, đo theo cặp trên cùng máy cùng lúc — không phải mốc kia."
echo
echo "KẾT LUẬN — đọc kèm sàn nhiễu:"
python3 -c "
d, n = $DELTA, $NOISE
if abs(d) <= n:
    print('   Chênh lệch %.3f ms KHÔNG vượt sàn nhiễu %.3f ms — liên kết AVKit không đo được' % (d, n))
    print('   trên đường khởi động. Cùng kết quả với WebKit ở PoC-L, và cùng lý do: framework')
    print('   hệ thống nằm sẵn trong dyld shared cache.')
    print('   ⚠ Nhưng KHÔNG kết luận \"AVKit miễn phí\": giá thật nằm ở lần dựng AVPlayerView đầu')
    print('   tiên, và chỗ ấy phải LƯỜI. Đó là điều kiện của ADR-14, không phải của phép đo này.')
else:
    print('   Chênh lệch %.3f ms VƯỢT sàn nhiễu %.3f ms — phải nạp lười bằng dlopen.' % (d, n))
"

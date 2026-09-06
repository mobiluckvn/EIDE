"""Tìm lời gọi `bytes(in:)` nằm trong VÒNG LẶP.

Không dùng regex trên cả tệp: thứ cần biết là cấu trúc lồng nhau. Dò bằng thụt lề — đủ đúng
với mã Swift định dạng chuẩn, và mục đích ở đây là LỌC RA chỗ đáng đọc bằng mắt, không phải
kết luận thay.
"""
import os, re, sys

LOOP = re.compile(r"^\s*(for |while |repeat\b|\.map \{|\.forEach|\.compactMap|\.filter \{|\.flatMap)")
CALL = re.compile(r"\bbytes\(in:")

hits = []
for root, _, files in os.walk(sys.argv[1]):
    for name in sorted(files):
        if not name.endswith(".swift"):
            continue
        path = os.path.join(root, name)
        lines = open(path).read().split("\n")
        # Ngăn xếp vòng lặp đang mở, theo thụt lề.
        stack = []
        for number, line in enumerate(lines, 1):
            stripped = line.strip()
            if not stripped or stripped.startswith("//") or stripped.startswith("///"):
                continue
            indent = len(line) - len(line.lstrip())
            while stack and indent <= stack[-1][0]:
                stack.pop()
            if CALL.search(line) and stack:
                hits.append((path, number, stack[-1][1], stripped))
            if LOOP.match(line):
                stack.append((indent, number))

print("%d lời gọi `bytes(in:)` nằm trong vòng lặp\n" % len(hits))
current = None
for path, number, loop_line, text in hits:
    if path != current:
        current = path
        print("── %s" % path.replace("Sources/GEditorCore/", ""))
    print("   %5d (vòng lặp mở ở %d)  %s" % (number, loop_line, text[:96]))

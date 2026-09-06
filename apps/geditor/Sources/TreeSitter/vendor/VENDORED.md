# tree-sitter 0.26.12 — mã nguồn nạp vào repo

Nguồn lõi: <https://codeload.github.com/tree-sitter/tree-sitter/tar.gz/refs/tags/v0.26.12>
Grammar (tên:repo:tag[:thư mục con]):
  bash:tree-sitter/tree-sitter-bash:v0.25.1
  c:tree-sitter/tree-sitter-c:v0.24.2
  cpp:tree-sitter/tree-sitter-cpp:v0.23.4
  csharp:tree-sitter/tree-sitter-c-sharp:v0.23.5
  css:tree-sitter/tree-sitter-css:v0.25.0
  go:tree-sitter/tree-sitter-go:v0.25.0
  html:tree-sitter/tree-sitter-html:v0.23.2
  java:tree-sitter/tree-sitter-java:v0.23.5
  javascript:tree-sitter/tree-sitter-javascript:v0.25.0
  json:tree-sitter/tree-sitter-json:v0.24.8
  lua:tree-sitter-grammars/tree-sitter-lua:v0.5.0
  php:tree-sitter/tree-sitter-php:v0.24.2:php
  python:tree-sitter/tree-sitter-python:v0.25.0
  ruby:tree-sitter/tree-sitter-ruby:v0.23.1
  rust:tree-sitter/tree-sitter-rust:v0.24.2
  toml:tree-sitter-grammars/tree-sitter-toml:v0.7.0
  typescript:tree-sitter/tree-sitter-typescript:v0.23.2:typescript
  xml:tree-sitter-grammars/tree-sitter-xml:v0.7.0:xml
  yaml:tree-sitter-grammars/tree-sitter-yaml:v0.7.2
  regex:tree-sitter/tree-sitter-regex:v0.25.0

Nạp lại bằng `scripts/vendor-tree-sitter.sh`. KHÔNG sửa tay bất kỳ file nào trong thư mục
này — mọi lựa chọn biên dịch nằm ở Package.swift để nhìn thấy được.

Chỉ `lib/src/lib.c` được biên dịch: nó `#include` mọi đơn vị còn lại của lõi.

// swift-tools-version: 5.9
import PackageDescription

// EIDE — bản giao diện viết lại từ đầu (18/09/2026).
//
// ## Vì sao một gói RIÊNG chứ không thêm target vào GEditor
//
// Bản cũ (`EIDEKit` trong gói GEditor) lớn lên bằng cách vá: mỗi yêu cầu mới thêm một vùng,
// một ràng buộc, một bảng tra. Tới 18/09 nó có ba bảng màn hình chép tay, ba mươi ràng buộc
// bố cục viết tay, và bốn lỗi bố cục sống sót vì không ai nhìn ra hình dạng tổng thể nữa.
//
// Bản này dựng theo MỘT nguồn: `docs/EIDE_UI_Demo_v2.html` cho hình dạng, `docs/EIDE-UXC-31`
// cho hành vi. Tách gói để ranh giới ấy có thật — không `import EIDEKit` được thì không lỡ
// tay kéo một quyết định cũ sang.
//
// Quy tắc phụ thuộc:
//   EideApp ─▶ EideGiaoDien ─▶ EideLoi
// `EideLoi` KHÔNG import AppKit: client JSON-RPC và mô hình dữ liệu phải test được mà không
// dựng cửa sổ. `EideGiaoDien` không nói chuyện với daemon — nó nhận dữ liệu đã đọc sẵn.
let package = Package(
    name: "EIDE",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EideLoi", targets: ["EideLoi"]),
        .library(name: "EideGiaoDien", targets: ["EideGiaoDien"]),
        .executable(name: "EideApp", targets: ["EideApp"]),
    ],
    targets: [
        .target(name: "EideLoi", path: "Sources/EideLoi"),
        .target(name: "EideGiaoDien", dependencies: ["EideLoi"], path: "Sources/EideGiaoDien"),
        .executableTarget(name: "EideApp", dependencies: ["EideGiaoDien"], path: "Sources/EideApp"),
        .testTarget(name: "EideGiaoDienTests",
                    dependencies: ["EideGiaoDien"], path: "Tests/EideGiaoDienTests"),
    ]
)

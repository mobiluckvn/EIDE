import AppKit
import GEditorCore

/// Chụp ảnh cửa sổ ra tệp PNG, không cần ai ngồi trước máy.
///
/// **Vì sao cần.** Bộ tự kiểm bắt được "nút này có bị nút kia đè không" nếu ta nghĩ ra trước mà
/// viết bài kiểm; nó không bắt được những thứ chỉ lộ ra khi nhìn — panel xếp sai thứ tự, chữ
/// chồng lên nút, một mảng trắng giữa hai khối màu. Dự án này đã sửa bốn lỗi loại ấy và cả bốn
/// đều tìm ra bằng cách NHÌN ẢNH, không phải bằng bài kiểm.
///
/// Chụp bằng `cacheDisplay` chứ không gọi `screencapture`: `cacheDisplay` vẽ thẳng từ cây view
/// nên không phụ thuộc cửa sổ có đang ở trước hay không, không đua với window server, và chạy
/// được cả khi không có ai đăng nhập vào máy. Cái giá của lựa chọn ấy nằm ở `write` bên dưới —
/// đọc nó trước khi kết luận ảnh chụp cho thấy một lỗi.
enum WindowCapture {

    /// Những trạng thái đáng chụp. Tên ở dòng lệnh là `rawValue`.
    enum Scene: String, CaseIterable {
        case trong = "trong"          // cửa sổ vừa mở, chưa bật panel nào
        case panel = "panel"          // sidebar + Tìm + Bàn làm sạch cùng bật
        case csv = "csv"              // Table view của một file CSV
        case jsonpath = "jsonpath"    // panel truy vấn JSONPath với kết quả
        case fold = "fold"            // một khối YAML đang gấp, có phù hiệu ⋯
        case map = "map"              // bản đồ tài liệu bên phải
        case theme = "theme"          // cùng cảnh ấy, nhưng theme "Than chì" (FR-UI-801)
        case cuaso = "cuaso"          // hai cửa sổ, sau khi dời một tab (FR-DOC-302)
        case sql = "sql"              // panel truy vấn SQL có kết quả (FR-CSV-407)

        // --- Phiên phân tích dữ liệu thật -------------------------------------------------
        //
        // Sáu cảnh dưới đây chụp một BÀI PHÂN TÍCH đang chạy, không phải một fixture ba dòng.
        // Chúng cần dữ liệu thật, nên chúng đọc đường dẫn từ biến môi trường
        // `GEDITOR_CAPTURE_DATA` (một thư mục). Không có biến ấy thì cảnh tự bỏ qua và nói ra —
        // một cảnh chụp im lặng ra ảnh trống là thứ tệ hơn không có ảnh.
        case dtBang = "dt-bang"           // bảng CSV 1,2 triệu dòng
        case dtSQL = "dt-sql"             // Query Workbench: truy vấn dò cụm bất thường
        case dtChatLuong = "dt-chat-luong"  // thẻ điểm chất lượng theo bộ luật quy chế thi
        case dtTuongQuan = "dt-tuong-quan"  // ma trận tương quan giữa các môn, theo tỉnh
        case dtBatThuong = "dt-bat-thuong"  // bảng bất thường trên độ vênh của từng phòng thi
        case dtNhom = "dt-nhom"           // khai phá theo nhóm: xếp hạng tỉnh theo bất thường
        case dtPhoDiem = "dt-pho-diem"    // biểu đồ phổ điểm Toán dựng từ kết quả truy vấn
        case dtBaoCao = "dt-bao-cao"      // xem trước báo cáo .greport.md, soạn trái preview phải

        // --- Khung xem ảnh · PDF · file nén -----------------------------------------------
        //
        // Ba cảnh này KHÔNG gắn với một tệp cụ thể: chúng lấy tệp ĐẦU TIÊN thuộc đúng loại tìm
        // được trong `GEDITOR_CAPTURE_DATA`. Gắn cứng tên tệp thì cảnh chỉ chụp được trên máy
        // của một người, và sẽ lặng lẽ bỏ qua trên mọi máy khác.
        case mediaAnh = "media-anh"       // khung xem ảnh: phóng, vừa khung, xoay
        case mediaPDF = "media-pdf"       // khung PDF: trang thu nhỏ, tìm, chú thích
        case mediaNen = "media-nen"       // khung file nén: danh sách mục
        case mediaExcel = "media-excel"   // .xlsx mở thẳng ra bảng CSV của sản phẩm
        case mediaWord = "media-word"     // .docx mở ra Markdown trong khung soạn thảo

        // --- Chế độ View dựng thành TRANG -------------------------------------------------
        //
        // Hai cảnh này là thứ duy nhất nhìn được câu hỏi "trang có chiếm hết bề ngang không".
        // Bài tự kiểm đo được con số bề rộng; nó KHÔNG thấy được một trang trắng không chữ, và
        // đó đúng là lỗi đầu tiên mà bản dựng trang này mắc phải.
        case trangWord = "trang-word"     // .docx dựng thành trang giấy, vừa bề ngang
        case trangSlide = "trang-slide"   // .pptx dựng thành trang slide 16:9

        // --- Trợ giúp (NFR-USE-04) --------------------------------------------------------
        //
        // Hai cảnh này chụp CỬA SỔ TRỢ GIÚP, không phải cửa sổ soạn thảo. Chúng chọn một
        // trang có ĐỦ mọi loại khối — bảng, bảng phím, khối mã, hộp lưu ý — vì thứ duy nhất
        // bài tự kiểm không nhìn được là bố cục, và bố cục chỉ hỏng ở những khối ấy.
        case pdfTrang = "pdf-trang"       // khung PDF với cả hai hàng công cụ
        case cayJSON = "cay-json"         // chế độ View của JSON: cây khoá–giá trị
        case troGiup = "tro-giup"         // một trang dày: bảng + khối mã + hộp cảnh báo
        case chao = "chao"                // trang chào lúc khởi động, có chân trang ô tích

        // --- Màn EIDE ---------------------------------------------------------------------
        //
        // Ba cảnh này chụp PANEL EIDE, tức cửa sổ đang nói chuyện với một `eide daemon` thật
        // trên một dự án thật. Chúng cần `EIDE_PROJECT` trỏ tới một thư mục có `.eide/` đã di
        // trú; không có thì cảnh tự bỏ qua và nói ra.
        //
        // Vì sao phải chụp chứ không tin bộ test: ba màn này đều đã có test đơn vị lẫn E2E, và
        // cả hai loại đều XANH trong lúc màn "Xung đột tri thức" hiện hai cột chỉ chứa một mã
        // băm (15/09/2026). Test hỏi "có đúng số dòng không"; chỉ con mắt hỏi được "hai dòng ấy
        // có nói gì cho người đọc không".
        case eideXungDot = "eide-xung-dot"   // hai bên xung đột, mỗi bên kèm nguồn và tầng
        case eideLamRo = "eide-lam-ro"       // màn làm rõ yêu cầu
        case eideModels = "eide-models"      // mô hình & chi phí
        case eideMaNguon = "eide-ma-nguon"   // cây dự án + trình soạn thảo
        case eideHoChieu = "eide-ho-chieu"   // bảng fact có tầng, nguồn, độ tin
        case eideBanDo = "eide-ban-do"       // đồ thị tri thức dựng thành cây
        case eideMoPhong = "eide-mo-phong"   // kỳ vọng, log UART, bảng quét
    }

    // ĐỌC ẢNH `eide-*` THẾ NÀO
    //
    // `cacheDisplay` KHÔNG vẽ cột điều hướng EIDE ra — trên ảnh nó là một vùng TRONG SUỐT bên
    // trái, và tỉ lệ "không vẽ được" in ra sau mỗi cảnh phần lớn là nó. Đừng đọc vùng ấy như
    // "cột điều hướng biến mất": ba bài `--self-test EIDE` đo trực tiếp trên cửa sổ thật và
    // khẳng định cột có mặt, rộng 220 pt, mở được cả 23 màn (đo 15/09/2026, 3/3 đạt).
    //
    // Cây tệp (`NSOutlineView` của `WorkspaceView`) thì VẼ ĐƯỢC. Nên ảnh `eide-ma-nguon` dùng
    // được để soi đúng thứ nó sinh ra để soi: cây có trỏ vào dự án không, `.eide/` có hiện không,
    // và có bao nhiêu cây trên màn hình — bản đầu có HAI, và chỉ ảnh chụp cho thấy điều đó.
    //
    // ĐỪNG ĐO KÍCH THƯỚC TRÊN ẢNH. `cacheDisplay` vẽ phần có nội dung của một `NSScrollView` và
    // bỏ phần trống dưới nó, nên một khung cao 420 pt chứa 5 hàng hiện ra như một khung 100 pt.
    // Tôi đã đọc ảnh màn Bản đồ 15/09/2026 đúng kiểu ấy và kết luận cây bị co lại; đo trên cửa
    // sổ thật (`--self-test "cây trên màn"`) thì nó cao đúng 420. Ảnh nói về NỘI DUNG; hình học
    // thì hỏi bài tự kiểm.

    /// Thư mục dữ liệu cho tám cảnh `dt-*`. `nil` thì bỏ qua chúng.
    private static var dataDirectory: String? {
        ProcessInfo.processInfo.environment["GEDITOR_CAPTURE_DATA"]
    }

    /// Bao lâu thì cảnh này ổn định xong, tính bằng giây.
    ///
    /// Một nhịp 0,4 s đủ cho mọi cảnh dựng từ dữ liệu đã có sẵn trong bộ nhớ. Nó KHÔNG đủ cho
    /// hai cảnh cuối, và cách hỏng thì im lặng: ảnh vẫn ra, chỉ là ra bảng rỗng hoặc preview
    /// trắng — trông y như một tính năng chưa làm xong.
    ///
    /// `dt-bao-cao` phải chờ lâu nhất vì nó chạy **cả báo cáo**: mười ba khối truy vấn trên 1,2
    /// triệu dòng, mất khoảng 68 giây ở dòng lệnh. Cộng thêm phần WKWebView nạp HTML.
    private static func settleSeconds(_ scene: Scene) -> TimeInterval {
        switch scene {
        case .dtBaoCao: return 180
        case .dtPhoDiem: return 3
        // Khung ảnh hoãn phép "vừa khung" một nhịp run loop, và PDFKit dựng trang thu nhỏ ở
        // luồng nền. Chụp ở 0,4 s ra một khung trắng.
        case .mediaAnh, .mediaPDF, .mediaNen, .mediaExcel, .mediaWord: return 2.5
        case .trangWord, .trangSlide: return 2.5
        // Panel EIDE khởi động một tiến trình `eide daemon` (Python + nạp registry 238 năng
        // lực), rồi mới gọi được năng lực của màn. Đo 15/09: khoảng 2,5 s tới lúc daemon trả
        // lời lần đầu. Chụp sớm hơn ra một màn "đang nạp…" — và một ảnh như thế thì không sai,
        // chỉ là không nói được gì.
        case .eideXungDot, .eideLamRo, .eideModels, .eideMaNguon, .eideHoChieu, .eideBanDo:
            return 8
        // Mô phỏng chạy `qemu-system-avr` THẬT. Đo 15/09: 25 giây ở dòng lệnh, nhưng qua daemon
        // còn thêm 2 giây chờ màn mở, nhịp hỏi `job.status` giãn dần, và một lượt khởi động
        // qemu nữa — chụp ở 45 giây ra đúng dòng "Đang chạy `sim.run`…".
        case .eideMoPhong: return 120
        default: return 0.4
        }
    }

    /// Cửa sổ cần chụp ở cảnh hiện tại — mặc định là cửa sổ chính.
    ///
    /// Cảnh `cuaso` chụp cửa sổ THỨ HAI: thứ đáng nhìn là cửa sổ vừa NHẬN tab, không phải cửa
    /// sổ vừa mất nó.
    /// Kiểu là `NSWindowController` chứ không phải `MainWindowController`: cảnh `tro-giup`
    /// và `chao` chụp cửa sổ Trợ giúp, vốn không phải một cửa sổ soạn thảo. `write` chỉ đọc
    /// `controller.window`, nên nới kiểu ở đây không đụng gì tới phần còn lại.
    private static var captureTarget: NSWindowController?

    /// `--capture <thư-mục> [cảnh…]`
    static func run(controller: MainWindowController, arguments: [String]) -> Never {
        guard let index = arguments.firstIndex(of: "--capture"),
              index + 1 < arguments.count else {
            FileHandle.standardError.write(Data("Thiếu thư mục: --capture <thư-mục> [cảnh…]\n".utf8))
            exit(2)
        }
        let directory = URL(fileURLWithPath: arguments[index + 1])
        let named = arguments.dropFirst(index + 2).compactMap(Scene.init(rawValue:))
        let scenes = named.isEmpty ? Scene.allCases : named

        // Thư mục đã có thì dùng luôn. `withIntermediateDirectories: true` lẽ ra nuốt lỗi này,
        // nhưng trên máy đang dùng nó vẫn ném EEXIST — và một công cụ chụp ảnh mà chạy lần thứ
        // hai vào cùng thư mục thì hỏng là công cụ không dùng được.
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: directory.path, isDirectory: &isDirectory
        )
        if !exists {
            do {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true
                )
            } catch {
                FileHandle.standardError.write(
                    Data("Không tạo được \(directory.path): \(error)\n".utf8)
                )
                exit(2)
            }
        } else if !isDirectory.boolValue {
            FileHandle.standardError.write(Data("\(directory.path) là một tệp, không phải thư mục\n".utf8))
            exit(2)
        }

        for scene in scenes {
            // Mỗi cảnh bắt đầu từ cửa sổ SẠCH. Thiếu bước này thì cảnh sau chụp lẫn panel cảnh
            // trước để lại, và ảnh không còn nói về cảnh mà nó mang tên.
            controller.resetWindowForSelfTest()
            captureTarget = nil
            prepare(scene, on: controller)
            // Cho run loop chạy để bố cục và mọi việc hoãn lại kịp xong. Chụp ngay sau khi đổi
            // trạng thái sẽ ra ảnh của trạng thái CŨ — đã gặp.
            RunLoop.current.run(until: Date().addingTimeInterval(settleSeconds(scene)))
            if scene == .map { reportMapGeometry(controller) }
            let path = directory.appendingPathComponent("\(scene.rawValue).png")
            if write(controller: captureTarget ?? controller, to: path) {
                // In LUÔN tỉ lệ vùng không vẽ được, không giấu trong ghi chú mã.
                //
                // Một cảnh 95% không vẽ được vẫn là ảnh hợp lệ, vẫn ✅ — nhưng nó KHÔNG dùng
                // được để soi bố cục, và người mở ảnh ra phải biết điều đó ngay lúc mở, chứ
                // không phải sau khi đã kết luận sai về một lỗi giao diện tưởng tượng.
                let trong = lastEmptyPercent ?? 0
                let ghiChu = trong >= 40
                    ? "  ⚠ \(trong)% khung hình cacheDisplay không vẽ được — đừng đọc ảnh này như ảnh chụp màn hình"
                    : (trong > 0 ? "  (\(trong)% không vẽ được)" : "")
                print("✅ \(path.path)\(ghiChu)")
            } else {
                print("❌ không chụp được cảnh \(scene.rawValue)")
                exit(1)
            }
        }
        exit(0)
    }

    /// Mở một màn EIDE trên dự án `EIDE_PROJECT`.
    ///
    /// Trả `false` (và nói lý do) khi chưa đặt biến môi trường: một ảnh chụp panel EIDE không có
    /// dự án chỉ là một khung xám, và đưa nó vào thư mục ảnh cùng tên với cảnh thật là cách chắc
    /// chắn nhất để về sau có người đọc nó như bằng chứng về một lỗi không tồn tại.
    private static func chuanBiEide(_ tien: String, on controller: MainWindowController) -> Bool {
        guard let d = ProcessInfo.processInfo.environment["EIDE_PROJECT"], !d.isEmpty else {
            print("⏭  bỏ qua cảnh eide-*: chưa đặt EIDE_PROJECT")
            return false
        }
        var laThuMuc: ObjCBool = false
        guard FileManager.default.fileExists(atPath: d, isDirectory: &laThuMuc),
              laThuMuc.boolValue,
              FileManager.default.fileExists(atPath: (d as NSString)
                  .appendingPathComponent(".eide")) else {
            print("⏭  bỏ qua cảnh eide-*: \(d) không phải dự án EIDE (thiếu .eide/)")
            return false
        }
        // KHÔNG gọi `toggleSidebar` ở đây: đó là sidebar TỆP của trình soạn thảo. Cột điều hướng
        // EIDE luôn có mặt trong `contentView` (DEV-098) và không bật/tắt được.
        //
        // Kiểm `eidePanel` TRƯỚC khi mở màn. `chonManEide` gặp panel nil sẽ dựng `NSAlert` và gọi
        // `runModal()` — trong một tiến trình chụp ảnh không người ngồi trước máy thì đó là treo
        // vĩnh viễn, và cách nó hỏng là không có gì xảy ra cả.
        guard controller.coPanelEide else {
            print("⏭  bỏ qua cảnh eide-*: không chạy được `eide daemon` (đặt EIDE_PYTHON?)")
            return false
        }
        controller.chonManEide(tien: tien)
        return true
    }

    private static func prepare(_ scene: Scene, on controller: MainWindowController) {
        switch scene {
        case .eideXungDot:
            _ = chuanBiEide("XungDot", on: controller)
        case .eideLamRo:
            _ = chuanBiEide("LamRo", on: controller)
        case .eideModels:
            _ = chuanBiEide("Models", on: controller)
        case .eideMaNguon:
            _ = chuanBiEide("Code", on: controller)
        case .eideHoChieu:
            _ = chuanBiEide("Passport", on: controller)
        case .eideBanDo:
            _ = chuanBiEide("Graph", on: controller)
        case .eideMoPhong:
            guard chuanBiEide("Sim", on: controller) else { break }
            // Màn Mô phỏng chỉ có gì để hiện SAU khi chạy, và `sim.run` cần firmware lẫn kịch
            // bản. Lấy chúng từ chính dự án: `build/fw.elf` và tệp `.yaml` đầu tiên trong `sim/`
            // — gắn cứng tên tệp thì cảnh chỉ chụp được trên máy của một người.
            let d = ProcessInfo.processInfo.environment["EIDE_PROJECT"] ?? ""
            let elf = (d as NSString).appendingPathComponent("build/fw.elf")
            let thuMucSim = (d as NSString).appendingPathComponent("sim")
            let kb = (try? FileManager.default.contentsOfDirectory(atPath: thuMucSim))?
                .filter { $0.hasSuffix(".yaml") }.sorted().first
            guard FileManager.default.fileExists(atPath: elf), let kb else {
                print("⏭  bỏ qua eide-mo-phong: dự án chưa có build/fw.elf hoặc sim/*.yaml")
                break
            }
            // Cho run loop chạy để màn KỊP MỞ trước khi gọi. `chonManEide` dựng màn qua vài
            // nhịp hoãn lại; gọi ngay thì `chayNhuNguoiDung` không tìm thấy màn nào đang hiện.
            RunLoop.current.run(until: Date().addingTimeInterval(2))
            let chay = controller.eidePanel?.chayNhuNguoiDung(
                "sim.run", ["artifact": elf,
                            "scenario": (thuMucSim as NSString).appendingPathComponent(kb)])
            if chay != true {
                print("⏭  eide-mo-phong: chưa mở được màn Mô phỏng nên không chạy sim.run")
            }
        case .trong:
            controller.prepareSelfTestDocument("""
                Xin chào. Đây là GEditor.
                Dòng thứ hai để thấy khoảng cách dòng.
                """)
        case .panel:
            controller.prepareSelfTestDocument("ten,tuoi\nAn,30\nBinh,25\n")
            if !controller.isSidebarVisible { controller.toggleSidebar(nil) }
            controller.showFindPanel(nil)
            controller.showCleanBench(nil)
        case .jsonpath:
            controller.prepareSelfTestDocument("""
                {
                  "cua_hang": {
                    "sach": [
                      { "ten": "Truyện Kiều", "gia": 120000, "co_san": true },
                      { "ten": "Số đỏ", "gia": 85000, "co_san": false },
                      { "ten": "Dế Mèn", "gia": 95000, "co_san": true }
                    ]
                  }
                }
                """)
            controller.openJSONPathForSelfTest()
            controller.jsonPathPanel.typeQueryForSelfTest("$..sach[?(@.gia > 90000)].ten")

        case .fold:
            controller.prepareSelfTestDocument("""
                ten: cua hang
                dia_chi:
                  so: 12
                  duong: Lê Lợi
                  thanh_pho: Hà Nội
                nhan_vien:
                  - ten: An
                  - ten: Bình
                ghi_chu: xong
                """)
            controller.setSyntaxLanguageForSelfTest(.yaml)
            controller.setCaretForSelfTest(documentOffset: 14)   // dòng `dia_chi:`
            controller.toggleFold(nil)
            controller.flushDrawingForSelfTest()

        case .map:
            // Hình dáng phải NHẬN RA ĐƯỢC: khối hàm thụt sâu, khối dữ liệu phẳng, và những
            // quãng trắng giữa chúng. Fixture đều đều thì bản đồ ra một cột xám và không kiểm
            // chứng được gì.
            var text = ""
            for block in 0 ..< 12 {
                text += "// ==== khối \(block) ====\n"
                for i in 0 ..< 20 {
                    let depth = (block % 3) + (i % 4)
                    text += String(repeating: "    ", count: depth)
                    text += "let bien_\(i) = tinh(\(String(repeating: "x", count: (i * 7) % 40)))\n"
                }
                text += "\n\n\n"
                for i in 0 ..< 10 {
                    text += "du_lieu_\(i),\(i * 3),\(i * 7)\n"
                }
                text += "\n\n"
            }
            controller.prepareSelfTestDocument(text)
            controller.toggleDocumentMapForSelfTest()
            controller.flushDrawingForSelfTest()
            controller.refreshDocumentMap()

        case .theme:
            // Cùng fixture với cảnh `map` nhưng đổi theme: hai ảnh đặt cạnh nhau là cách duy
            // nhất thấy được màu có thật sự đổi hay không.
            Tokens.theme = .than
            prepare(.map, on: controller)

        case .pdfTrang:
            // Tự dựng PDF bốn trang, không đọc tệp mẫu: cảnh chụp phải chạy được trên mọi máy,
            // và trong bundle sandbox thì đường tới kho mã bị chặn.
            controller.useTemporaryStoresForSelfTest()
            let pdf = NSTemporaryDirectory() + "geditor-capture-trang.pdf"
            SelfTest.makePDF(at: pdf, pages: ["MOT", "HAI", "BA", "BON"])
            controller.open(path: pdf, line: nil, column: nil, readOnly: false)

        case .cayJSON:
            controller.useTemporaryStoresForSelfTest()
            let json = NSTemporaryDirectory() + "geditor-capture-cay.json"
            let noiDung = """
                {
                  "ten_cong_ty": "Công ty TNHH An Bình",
                  "dia_chi": {"tinh": "Thừa Thiên Huế", "phuong": "Vĩnh Ninh", "so_nha": 12},
                  "nhan_vien": [
                    {"ho_ten": "Nguyễn Văn An", "chuc_vu": "Giám đốc", "tuoi": 42},
                    {"ho_ten": "Trần Thị Bình", "chuc_vu": "Kế toán", "tuoi": 35}
                  ],
                  "doanh_thu": [120000000, 98000000, 143500000],
                  "dang_hoat_dong": true,
                  "ghi_chu": null
                }
                """
            try? Data(noiDung.utf8).write(to: URL(fileURLWithPath: json))
            controller.open(path: json, line: nil, column: nil, readOnly: false)
            controller.toggleViewCode(nil)

        case .troGiup:
            // Trang cú pháp `.gquality.yaml`: có bảng ba cột, khối mã YAML dài, hộp cảnh báo và
            // danh sách liên kết — bốn thứ dễ vỡ bố cục nhất trong một chỗ.
            captureTarget = HelpWindowController.show(topicID: "cu-phap-gquality")

        case .chao:
            captureTarget = HelpWindowController.show(
                topicID: HelpContent.entryTopicID, welcome: true
            )

        case .cuaso:
            // Hai cửa sổ và một tab vừa đi từ cửa sổ này sang cửa sổ kia. Ảnh chụp CỬA SỔ ĐÍCH:
            // nó phải hiện ra tab vừa nhận, không phải một cửa sổ trống.
            controller.useTemporaryStoresForSelfTest()
            controller.resetTabsForSelfTest()
            let dir = NSTemporaryDirectory() + "geditor-capture-windows"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            for index in 0 ..< 2 {
                let path = "\(dir)/tep\(index).txt"
                try? "nội dung \(index)\n".write(toFile: path, atomically: true, encoding: .utf8)
                controller.openInNewTabForSelfTest(path: path)
            }
            let second = WindowManager.shared.newWindow()
            if let frame = second.window?.frame {
                controller.dropTabAtScreenPointForSelfTest(
                    0, NSPoint(x: frame.midX, y: frame.midY)
                )
            }
            captureTarget = second

        case .sql:
            // Bảng đủ để một câu GROUP BY ra nhiều dòng: ảnh phải cho thấy BẢNG kết quả nhiều
            // cột, không phải một danh sách một cột như panel JSONPath.
            controller.prepareSelfTestDocument("""
                ma,thanh_pho,doanh_thu
                KH01,Hà Nội,1200000
                KH02,Đà Nẵng,850000
                KH03,Hà Nội,430000
                KH04,Huế,700000
                KH05,Đà Nẵng,1500000
                """)
            controller.openSQLPanelForSelfTest()
            controller.sqlPanel.typeQueryForSelfTest(
                "SELECT thanh_pho, COUNT(*), SUM(doanh_thu) FROM t GROUP BY thanh_pho"
                    + " ORDER BY SUM(doanh_thu) DESC")

        case .csv:
            controller.prepareSelfTestDocument(
                "ten,tuoi,tinh\nNguyễn An,30,Hà Nội\nTrần Bình,25,Đà Nẵng\nLê Cường,41,Cần Thơ\n"
            )
            controller.showTableViewForSelfTest()

        // --- Phiên phân tích dữ liệu thật ---------------------------------------------------

        case .dtBang:
            guard let path = duLieu("diem_thi_tuoitre.csv", controller) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.showTableViewForSelfTest()

        case .dtSQL:
            guard let path = duLieu("diem_thi_tuoitre.csv", controller) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.showSQLPanel(nil)
            // Chính câu truy vấn đã tìm ra cụm 8016321–8016632: xếp hạng phòng thi theo mức
            // vênh giữa điểm trắc nghiệm và điểm Ngữ văn.
            controller.sqlPanel.typeQueryForSelfTest("""
                SELECT MA_TINH AS ma_tinh,
                       (SOBAODANH % 1000000 - 1) // 24 AS phong,
                       count(*) AS so_ts,
                       round(avg(TOAN), 2) AS toan_tb,
                       round(avg(VAN), 2) AS van_tb,
                       round(avg(TOAN) - avg(VAN), 2) AS venh
                FROM t
                WHERE TOAN IS NOT NULL AND VAN IS NOT NULL
                GROUP BY 1, 2 HAVING count(*) >= 20
                ORDER BY venh DESC LIMIT 40
                """)
            controller.waitForSQLResultForSelfTest(timeout: 30)

        case .dtChatLuong:
            guard let path = duLieu("diem_thi_tuoitre.csv", controller) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.showQualityReport(nil)

        case .dtTuongQuan:
            guard let path = duLieu("theo-tinh.csv", controller) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.showTableViewForSelfTest()
            controller.showCorrelation(nil)

        case .dtBatThuong:
            guard let path = duLieu("theo-phong.csv", controller) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.showTableViewForSelfTest()
            controller.showAnomalies(nil)
            // Cột có nghĩa là ĐỘ VÊNH, không phải mã tỉnh — xem ghi chú ở
            // `AnomalyPanel.selectColumnForSelfTest`.
            controller.anomalyPanel.selectColumnForSelfTest("venh")
            controller.anomalyPanel.selectMethodForSelfTest(2)   // MAD: bền với đuôi nặng

        case .mediaAnh, .mediaPDF, .mediaNen, .mediaExcel, .mediaWord:
            let want: MediaKind
            switch scene {
            case .mediaAnh: want = .image
            case .mediaPDF: want = .pdf
            case .mediaExcel: want = .excel
            case .mediaWord: want = .word
            default: want = .archive
            }
            guard let path = duLieuTheoLoai(want) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)

        case .dtNhom:
            guard let path = duLieu("theo-phong.csv", controller) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.showTableViewForSelfTest()
            controller.showGroupMining(nil)

        case .dtPhoDiem:
            guard let path = duLieu("diem_thi_tuoitre.csv", controller) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.showSQLPanel(nil)
            // Phổ điểm Toán — và nó KHÔNG mượt. Lưới điểm của đề 2026 có nhiều bậc lồng nhau
            // (phần đúng/sai cho 0,1 · 0,25 · 0,5 · 1,0 điểm), nên vài mức dày hẳn còn vài mức
            // gần như trống. Ảnh này để nói đúng chuyện ấy: răng cưa là của ĐỀ THI, không phải
            // của hội đồng chấm — thứ mà một bộ đo phổ điểm không chuẩn hoá sẽ đổ nhầm.
            controller.sqlPanel.typeQueryForSelfTest("""
                SELECT TOAN AS diem, count(*) AS so_bai
                FROM t WHERE TOAN IS NOT NULL
                GROUP BY 1 ORDER BY 1
                """)
            guard controller.waitForSQLResultForSelfTest(timeout: 60) else {
                print("⏭  bỏ qua dt-pho-diem: truy vấn không xong trong 60 s")
                return
            }
            controller.sqlPanel.tapChartForSelfTest()

        case .trangWord, .trangSlide:
            guard let path = duLieuTheoLoai(scene == .trangWord ? .word : .powerpoint)
            else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            controller.showOfficePreview()
            // Cuộn qua trang bìa: trang 1 của một cuốn sách hầu như không có gì để nhìn — không
            // chân trang, không số trang, không chữ chạy. Trang 5 mới nói được bản dựng làm gì.
            let pages = controller.officePreview.pages
            pages.layoutNowForSelfTest()
            if pages.pageCountForSelfTest > 6 { pages.scroll(toPage: 5) }

        case .dtBaoCao:
            guard let path = duLieu("bao-cao-diem-thi.greport.md", controller) else { return }
            controller.open(path: path, line: nil, column: nil, readOnly: false)
            guard controller.isReportDocument else {
                print("⏭  bỏ qua dt-bao-cao: không nhận ra tài liệu .greport.md")
                return
            }
            controller.toggleReportPreview(nil)
        }
    }

    /// Tệp ĐẦU TIÊN thuộc đúng loại trong thư mục dữ liệu chụp ảnh.
    ///
    /// Nhận loại bằng chính `MediaKind` của sản phẩm, không bằng đuôi tệp — nếu phép nhận diện
    /// hỏng thì cảnh chụp cũng hỏng theo, và đó là điều đáng mong: một cảnh chụp vẫn ra ảnh đẹp
    /// khi phép nhận diện đã sai là một cảnh chụp nói dối.
    private static func duLieuTheoLoai(_ want: MediaKind) -> String? {
        guard let folder = dataDirectory else {
            print("⏭  bỏ qua cảnh media: chưa đặt GEDITOR_CAPTURE_DATA")
            return nil
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        for name in names.sorted() {
            let path = (folder as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { continue }
            if MediaKind.of(path: path) == want { return path }
        }
        print("⏭  bỏ qua: không có tệp loại \(want.rawValue) trong \(folder)")
        return nil
    }

    /// Đường dẫn một tệp dữ liệu của phiên phân tích, hoặc `nil` kèm lời giải thích.
    private static func duLieu(_ name: String, _ controller: MainWindowController) -> String? {
        guard let folder = dataDirectory else {
            print("⏭  bỏ qua cảnh dt-*: chưa đặt GEDITOR_CAPTURE_DATA")
            return nil
        }
        let path = (folder as NSString).appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: path) else {
            print("⏭  bỏ qua: không có \(path)")
            return nil
        }
        return path
    }

    /// In hình học bản đồ tài liệu ra dòng lệnh.
    ///
    /// Ảnh cho biết KẾT QUẢ sai; mấy dòng số này cho biết SAI Ở ĐÂU — bề rộng lúc vẽ, hay phép
    /// tính vệt mực. Không có chúng thì chỉ còn cách sửa mò.
    private static func reportMapGeometry(_ controller: MainWindowController) {
        let view = controller.documentMapView
        print("📐 bản đồ: bounds lúc hỏi \(view.bounds.size), lúc vẽ \(view.lastDrawBounds.size)"
            + ", ràng buộc \(DocumentMapView.width)pt, \(view.rowCountForSelfTest) hàng"
            + " / \(view.mappedLineCountForSelfTest) dòng")
        for (index, rect) in view.lastDrawInkRects.prefix(12).enumerated() {
            print(String(format: "   hàng %2d: x %.2f → %.2f (rộng %.2f, cao %.3f)",
                         index, rect.minX, rect.maxX, rect.width, rect.height))
        }
    }

    /// Vẽ cây view vào một ảnh PNG.
    ///
    /// **Ảnh này KHÔNG có chữ trong vùng soạn thảo, và đó là giới hạn của công cụ chứ không
    /// phải lỗi bố cục.** `cacheDisplay` vẽ lại từ `draw(_:)` của từng view, nên nó bắt trọn
    /// phần khung do dự án tự vẽ. Chữ thì không: `MultiCaretTextView` có layer riêng và TextKit 2
    /// đưa chữ vào những `_NSTextRenderingSurfacesGroupView` — nội dung nằm ở layer, không ở
    /// `draw(_:)`.
    ///
    /// Đã thử phủ thêm `CALayer.render(in:)` lên trên: không lấy được chữ (bề mặt IOSurface của
    /// TextKit 2 nằm ngoài tầm của nó), lại còn vẽ trùng phần khung theo hệ tọa độ ngược. Bỏ.
    ///
    /// **`MultiCaretOverlay` cũng không lên ảnh**, nên caret phụ, dải nền dòng đã đánh dấu và
    /// phù hiệu `⋯` của chỗ gấp đều vắng mặt. Đã đo dứt điểm: vẽ một khối màu đặc 300×30 thẳng
    /// trong `draw(_:)` của overlay thì ảnh vẫn trắng. Overlay nằm trong clip view của
    /// `NSScrollView`, và phần ấy được ghép ở tầng layer.
    ///
    /// Nên đọc ảnh này ĐÚNG như nó là: một bản đồ bố cục. Nó bắt được panel xếp sai thứ tự, chữ
    /// chồng lên nút, mảng màu đứt đoạn — tức là đúng loại lỗi đã bốn lần lọt qua bộ tự kiểm.
    /// Những thứ nó không chụp được thì kiểm bằng bài tự kiểm đọc thẳng hình học: xem
    /// `foldMarkerRectsForSelfTest`.
    /// Ảnh vừa ghi có bao nhiêu phần trăm là vùng KHÔNG vẽ được. `nil` = chưa chụp lần nào.
    ///
    /// In ra cạnh mỗi dòng ✅ — xem `write` để biết vì sao con số này quan trọng hơn vẻ ngoài.
    private(set) static var lastEmptyPercent: Int?

    private static func write(controller: NSWindowController, to url: URL) -> Bool {
        guard let view = controller.window?.contentView, view.bounds.width > 0 else { return false }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: rep)

        lastEmptyPercent = phanTramTrongSuot(rep)

        // GHÉP LÊN NỀN ĐẶC trước khi ghi PNG.
        //
        // Vì sao bắt buộc, chứ không phải cho đẹp: những vùng `cacheDisplay` không vẽ được (xem
        // ghi chú ở trên) ra PNG với alpha = 0. Mọi trình xem ảnh tô vùng trong suốt bằng màu
        // TRẮNG — nên cảnh `trong`, vốn 95% không vẽ được, hiện ra thành một cửa sổ nền trắng
        // với thanh tab đen. Người xem kết luận "giao diện sáng-tối lẫn lộn" và đi sửa một lỗi
        // KHÔNG TỒN TẠI. Tôi đã tự mắc đúng bẫy ấy khi xem lại ảnh chụp của chính mình.
        //
        // Ghép lên nền thật thì vùng chưa vẽ mang đúng màu nền cửa sổ, và ảnh nói dối ít hơn:
        // nó thiếu chữ, nhưng không còn bịa ra một bảng màu khác hẳn.
        // RGBA (4 mẫu, có alpha), KHÔNG phải RGB 3 mẫu: dạng ba mẫu không alpha làm
        // `NSGraphicsContext(bitmapImageRep:)` chết bằng SIGTRAP chứ không trả `nil`, nên không
        // có nhánh nào để bắt. Nền vẫn đặc vì ta tô kín trước khi vẽ đè.
        guard let khung = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: rep.pixelsWide, pixelsHigh: rep.pixelsHigh,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return false }
        khung.size = rep.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: khung)
        (controller.window?.backgroundColor ?? Tokens.Color.editorBackground).setFill()
        NSRect(origin: .zero, size: rep.size).fill()
        rep.draw(in: NSRect(origin: .zero, size: rep.size))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = khung.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: url)) != nil
    }

    /// Bao nhiêu phần trăm điểm ảnh có alpha gần 0 — tức `cacheDisplay` không vẽ gì ở đó.
    ///
    /// Lấy mẫu thưa: con số này để người đọc biết ảnh đáng tin tới đâu, không cần chính xác tới
    /// từng điểm, và quét đủ 3,1 triệu điểm cho mỗi cảnh thì công cụ chụp chậm đi thấy rõ.
    private static func phanTramTrongSuot(_ rep: NSBitmapImageRep) -> Int {
        var trong = 0, tong = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 9) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 9) {
                tong += 1
                if let c = rep.colorAt(x: x, y: y), c.alphaComponent < 0.5 { trong += 1 }
            }
        }
        return tong == 0 ? 0 : trong * 100 / tong
    }
}

import AppKit
import GEditorCore

/// Chạy DÀI ngẫu nhiên trên ứng dụng thật — NFR-REL-03 (ổn định).
///
/// **Vì sao bộ tự kiểm không thay được bài này.** 176 bài tự kiểm mỗi bài dựng một trạng thái
/// sạch, làm một việc, rồi kiểm một mệnh đề. Chúng bắt được "thao tác X sai", nhưng không bắt
/// được thứ chỉ hiện ra sau hàng nghìn thao tác CHỒNG LÊN NHAU: bộ nhớ rò rỉ dần, một chỉ mục
/// lệch pha với buffer sau nhiều lần sửa, một trạng thái panel còn sót làm thao tác sau sập.
///
/// Đó chính là thứ NFR-REL-03 nói tới, và `docs/trang-thai.md` ghi nó là "cần một chiến dịch đo
/// riêng, không phải một dòng mã". Phần lớn chiến dịch ấy tự động hoá được: cái không tự động
/// hoá được là người ngồi dùng thật, còn "chạy vạn thao tác rồi xem có sập không" thì máy làm
/// tốt hơn người.
///
/// **Ba thứ bài này canh:**
///
/// 1. **Không sập.** Tiến trình sống tới cuối là điều kiện cần.
/// 2. **Không rò bộ nhớ.** Đo `phys_footprint` mỗi 500 thao tác. Bộ nhớ lên rồi xuống là bình
///    thường; lên đều và không bao giờ xuống mới là rò.
/// 3. **Không nuốt lỗi.** Mọi lỗi app định báo cho người dùng đều đi qua `Unattended.recordError`
///    (xem `Unattended`), nên đếm được. Một lượt chạy dài mà đẻ ra hàng nghìn lỗi là hỏng, kể
///    cả khi không sập.
///
/// **Ngẫu nhiên TẤT ĐỊNH.** Cùng một hạt giống cho cùng một dãy thao tác, nên một lần đỏ tái
/// hiện được bằng cách chạy lại đúng hạt ấy. Ngẫu nhiên thật thì mỗi lần đỏ là một lần mất dấu.
enum SoakTest {

    /// `--soak [số-thao-tác] [--seed N] [--vet] [--only a,b,c]`
    static func run(on controller: MainWindowController, arguments: [String]) -> Never {
        let operations = intOption("--soak", in: arguments, default: 5_000)
        let seed = intOption("--seed", in: arguments, default: 20260824)
        var random = DeterministicRNG(seed: UInt64(seed))
        let trace = arguments.contains("--vet")

        // `--only`: chỉ bốc trong một tập thao tác. Đây là bước THỨ HAI của việc truy rò bộ
        // nhớ, và không có nó thì không kết luận được.
        //
        // `--vet` chỉ cho biết thao tác nào TƯƠNG QUAN với những lần nhảy bộ nhớ, mà tương
        // quan thì chưa phải nguyên nhân: các thao tác chạy xen kẽ nhau, nên một thao tác vô
        // can vẫn có thể lãnh trọn phần bộ nhớ mà thao tác trước nó vừa xin. Chạy riêng một
        // tập rồi so với một tập đối chứng mới tách được hai thứ ấy.
        let only: Set<String> = {
            guard let index = arguments.firstIndex(of: "--only"), index + 1 < arguments.count
            else { return [] }
            return Set(arguments[index + 1].split(separator: ",").map(String.init))
        }()
        let pool = only.isEmpty ? Action.allCases : Action.allCases.filter { only.contains($0.rawValue) }
        guard !pool.isEmpty else {
            print("  --only: không có thao tác nào tên như vậy. Tên hợp lệ: "
                + Action.allCases.map(\.rawValue).joined(separator: ", "))
            exit(2)
        }

        controller.useTemporaryStoresForSelfTest()
        controller.resetTabsForSelfTest()

        // ĐỐI CHỨNG ÂM cho bộ đếm lỗi, chạy TRƯỚC khi đếm bất cứ thứ gì.
        //
        // Báo cáo cuối kết luận "0 lỗi app định báo cho người dùng". Câu ấy chỉ có nghĩa nếu bộ
        // đếm thật sự nhích được — một bộ đếm hỏng cũng cho đúng con số 0 ấy, và trông y hệt
        // một lượt chạy sạch. Mười hạt giống × 10.000 thao tác đều báo 0, và đó chính là lúc
        // phải hỏi "0 này là sạch hay là mù?".
        //
        // Nên: gây một lỗi giả, đòi bộ đếm nhích, rồi xoá sổ. Sau bước này con số 0 mới là một
        // mệnh đề về ứng dụng chứ không phải về bộ đo.
        Unattended.resetLog()
        Unattended.recordError("đối chứng âm", "kiểm bộ đếm lỗi có nhích không")
        guard Unattended.errorCount == 1, Unattended.lastError != nil else {
            print("  ❌ bộ đếm lỗi KHÔNG hoạt động — mọi con số \"0 lỗi\" dưới đây đều vô nghĩa")
            exit(2)
        }
        Unattended.resetLog()

        var footprints: [Double] = [footprintMB()]
        var counts: [String: Int] = [:]
        let started = Date()

        // Nhịp lấy mẫu suy TỪ ĐỘ DÀI lượt chạy, không phải một con số cứng.
        //
        // Bản đầu đo mỗi 500 thao tác. Lượt chạy ngắn hơn 500 thì mốc ấy KHÔNG rơi lần nào, và
        // cả bản báo cáo — đầu, đỉnh, cuối, xu hướng — đọc lại đúng một con số đo lúc khởi
        // động, rồi kết luận "✅ ĐẠT · bộ nhớ không tăng đều". Xanh vì không có dữ liệu, trông
        // y hệt xanh vì đạt. Đó là kiểu hỏng nguy hiểm nhất của một bài kiểm.
        //
        // Hai mươi mẫu là đủ để thấy xu hướng mà vẫn không làm `task_info` thành thứ đắt nhất
        // trong vòng lặp.
        let sampleEvery = Swift.max(operations / 20, 1)

        for step in 1 ... operations {
            let action = pool[Int(random.next() % UInt64(pool.count))]
            counts[action.rawValue, default: 0] += 1
            // `--vet`: in ra từng thao tác TRƯỚC khi làm. Sập thì dòng cuối cùng chính là thủ
            // phạm — không có nó thì chỉ biết "sập ở đâu đó trong năm nghìn bước".
            //
            // Kèm bộ nhớ đo NGAY TRƯỚC và NGAY SAU mỗi thao tác. Mốc 500 bước của lượt chạy
            // thường đủ để nói "có rò", nhưng không đủ để nói "rò ở đâu": nó gộp năm trăm thao
            // tác vào một con số. Ở đây phép đo được đắt là chuyện chấp nhận được — `--vet` là
            // lượt chạy để TRUY, không phải để lấy số.
            if trace {
                let before = footprintMB()
                FileHandle.standardError.write(
                    Data(String(format: "  %d %@ · %d byte · chọn %@ · %d tab · %.1f MB",
                                step, action.rawValue,
                                controller.editorDocument.buffer.count,
                                String(describing: controller.selectedRangeForSelfTest),
                                controller.tabCountForSelfTest, before).utf8))
                perform(action, on: controller, &random)
                let after = footprintMB()
                FileHandle.standardError.write(
                    Data(String(format: " → %.1f (%+.1f)\n", after, after - before).utf8))
            } else {
                perform(action, on: controller, &random)
            }

            // Đo bộ nhớ theo mốc chứ không theo từng bước: `task_info` là một lời gọi hệ thống,
            // và gọi nó năm nghìn lần sẽ làm chính phép đo thành thứ đắt nhất trong vòng lặp.
            // Bước CUỐI luôn được đo, để "cuối" đúng là cuối chứ không phải mốc gần cuối.
            if step % sampleEvery == 0 || step == operations { footprints.append(footprintMB()) }
        }

        let seconds = Date().timeIntervalSince(started)

        // ĐỂ CHO RẢNH rồi mới đo lần cuối.
        //
        // Không phải chi tiết làm đẹp số. Cocoa trả bộ nhớ theo NHỊP, không trả ngay: backing
        // store của layer, `IOSurface`, các pool của hàng đợi chính đều được thu ở những vòng
        // run loop sau. Đo ngay sau thao tác cuối là đo lúc app đang giữa chừng một việc —
        // giống như cân một người đang nhảy.
        //
        // Con số đáng so với NFR-PERF-05 (RAM nhàn rỗi) là con số lúc RẢNH, vì đó chính là
        // trạng thái mà chỉ tiêu ấy nói tới. Báo cả hai, vì chênh lệch giữa chúng cũng là một
        // tin: trả lại chậm khác hẳn với không trả lại.
        // `--hold N`: kéo dài khoảng rảnh ấy ra N giây để soi tiến trình từ BÊN NGOÀI.
        //
        // `heap <pid>` và `leaks <pid>` là cách duy nhất trả lời được "bộ nhớ đang nằm ở lớp
        // nào" — báo cáo dưới đây chỉ nói tổng số. Ba giây không đủ để bám vào, và ghi thêm
        // một chế độ chạy riêng chỉ để soi thì lại là một đường mã thứ hai phải nuôi.
        let hold = intOption("--hold", in: arguments, default: 3)
        let quiesceDeadline = Date().addingTimeInterval(Double(hold))
        while Date() < quiesceDeadline {
            autoreleasepool { _ = RunLoop.current.run(mode: .default, before: quiesceDeadline) }
        }
        let idle = footprintMB()

        report(
            operations: operations, seed: seed, seconds: seconds,
            footprints: footprints, idle: idle, hold: hold, counts: counts, controller: controller)
    }

    /// Làm MỘT thao tác, đúng như ứng dụng thật làm một sự kiện.
    ///
    /// **Hai dòng bao quanh lời gọi mới là chỗ đáng đọc**, và chúng vào đây sau một lần đo sai.
    ///
    /// Bản đầu gọi thẳng `action.perform` trong vòng lặp. Bộ nhớ leo từ 16,6 lên 564 MB trong
    /// 500 thao tác, và ở bước ~4900 thì AttributeGraph của AppKit vỡ (`grow_region`) làm cả
    /// tiến trình `abort`. Đọc số theo từng thao tác thì thấy MỌI thao tác đều tăng chút một,
    /// còn hai thao tác gần như không làm gì (`trimWhitespace`, `markLines`) thì tăng 0,0 —
    /// hình dạng ấy không phải một chỗ rò, nó là TÍCH TỤ TOÀN CỤC.
    ///
    /// Thủ phạm là chính bộ chạy dài. Cả vòng lặp nằm gọn trong MỘT lời gọi
    /// `applicationDidFinishLaunching`, nên nó không lần nào trả điều khiển về run loop:
    ///
    /// - **Không xả pool tự thả.** Cocoa trả về vô số đối tượng `autorelease`; pool chỉ xả khi
    ///   mỗi vòng run loop kết thúc. Không về run loop thì không có vòng nào kết thúc, và mọi
    ///   thứ AppKit sinh ra trong năm nghìn thao tác nằm lại đó tới lúc thoát.
    /// - **Không chạy việc hoãn.** Vẽ lại, `performSelector` hoãn, hàng đợi chính — AppKit dựa
    ///   vào những nhịp ấy để dọn dẹp. Bỏ qua chúng thì trạng thái tạm chồng lên nhau.
    ///
    /// Nói cách khác, bản đầu **đo chính bộ đo chứ không đo ứng dụng** — và nó sẽ đỏ mãi mãi
    /// bằng một con số chẳng liên quan gì tới người dùng. Đây là họ lỗi đắt nhất của mọi bài
    /// kiểm trong dự án này: bài kiểm sai trông y hệt mã sai.
    ///
    /// Nhịp run loop để hạn 0 giây: chạy những nguồn ĐÃ SẴN SÀNG rồi về ngay, không ngồi đợi.
    private static func perform(
        _ action: Action, on controller: MainWindowController, _ random: inout DeterministicRNG
    ) {
        autoreleasepool {
            action.perform(on: controller, &random)
            RunLoop.current.run(mode: .default, before: Date())
            capTabs(on: controller)
        }
    }

    /// Số tab tối đa mà lượt chạy dài được phép giữ.
    ///
    /// **Vì sao phải chặn, và vì sao con số này là 12.**
    ///
    /// Nhiều thao tác MỞ tab mà không có lệnh đóng đối ứng: chuyển định dạng và xuất kết quả
    /// SQL đều đổ ra một tab mới. Nên số tab đi một chiều. Đo được: 2.000 bước → 33 tab,
    /// 20.000 bước → **287 tab**.
    ///
    /// Hậu quả là lượt chạy CHẬM DẦN, và đó là thứ suýt bị đọc thành một lỗi hiệu năng của sản
    /// phẩm: 341 thao tác/giây ở 2.000 bước, còn 153 ở 20.000. Đo tách ra mới rõ — bỏ hẳn nhóm
    /// tab thì tốc độ **PHẲNG** (960 → 1033 thao tác/giây khi tăng gấp mười độ dài), và bộ nhớ
    /// đứng yên ở 23–25 MB. Ứng dụng không tự chậm đi theo thời gian dùng; nó chậm theo SỐ TAB,
    /// và số tab ấy là do bộ đo dựng ra chứ không phải do người dùng.
    ///
    /// 12 tab là mức người dùng nặng tay thật sự có. Để bộ đo trôi tới 287 tab thì nó vừa đo
    /// một trạng thái không ai gặp, vừa làm lượt chạy dài trở nên bất khả thi — lượt 100.000
    /// bước đầu tiên chạy 31 phút mà chưa xong.
    private static let tabCap = 12

    /// Đóng bớt tab cho về trần. Chạy sau MỖI thao tác, vì tab sinh ra từ nhiều đường.
    private static func capTabs(on controller: MainWindowController) {
        var guardCount = 0
        while controller.tabCountForSelfTest > tabCap, guardCount < 64 {
            controller.closeCurrentTabForSelfTest()
            guardCount += 1
        }
    }

    // MARK: - Thao tác

    /// Những việc người dùng làm, ở dạng máy tự bấm được.
    ///
    /// Cố ý TRỘN các nhóm không liên quan: gõ chữ, đổi chế độ CSV, mở panel, đổi word wrap. Lỗi
    /// mà bài này sinh ra để bắt nằm ở chỗ hai nhóm gặp nhau — bảng CSV còn mở trong khi tài
    /// liệu đã thành JSON, chẳng hạn.
    enum Action: String, CaseIterable {
        case type, deleteBackward, newline, paste
        case moveCaret, selectRange, selectAll
        case undo, redo
        case sortLines, dedupe, trimWhitespace
        case toggleWrap, toggleCSV, toggleTable
        case newTab, closeTab, closeTabAsking, switchTab
        case find, markLines
        case loadFixture

        // Mảng thêm vào đợt hai. Bộ đầu tiên chỉ gõ, chọn, đổi tab — tức nó dồn hết sức vào
        // MỘT vùng của app. Năm lỗi sập nó tìm ra đều nằm ở vùng ấy, và đó vừa là bằng chứng
        // rằng cách làm đúng, vừa là bằng chứng rằng những vùng còn lại CHƯA ĐƯỢC HỎI ĐẾN.
        case splitPane, closeSplit, focusOtherPane
        case toggleDocumentMap, toggleFunctionList
        case jsonFormat, jsonMinify
        case validateCSV, changeDelimiter
        case setLanguage, resizeWindow
        case togglePin, moveLine, goToMark, deleteMarkedLines
        case recordMacro

        // Đợt ba. Đợt hai đã chứng minh luật: bộ soak chỉ tìm được lỗi ở những vùng nó ĐI QUA,
        // và mỗi lần mở rộng là một đợt săn mới.
        // Đợt bốn: bảng CSV, truy vấn SQL, khối cột, workspace.
        //
        // **`WorkspaceView.Command` có `moveToTrash` và `revealInFinder` — hai lệnh ấy KHÔNG
        // BAO GIỜ được vào đây.** Bộ chạy dài bấm ngẫu nhiên hàng nghìn lần; `moveToTrash` là
        // lệnh xoá file THẬT, và một đường dẫn ngẫu nhiên là một file của người dùng. Bộ đo
        // không được phép làm hỏng máy nó đang đo. Chỉ nhận lệnh tạo, và chỉ trong thư mục tạm
        // của chính lượt chạy này.
        case columnCommand, selectColumnBlock, runSQL, toggleSQLPanel
        case openWorkspace, workspaceNewFile, closeWorkspace

        // Đợt năm: mã mới của phiên này. `validateSchema` cố ý MỞ HỘP CHỌN FILE khi tài liệu
        // không có DOCTYPE — trước khi `Unattended.chooseFile` ra đời thì đúng thao tác ấy sẽ
        // treo cả lượt chạy, và không bài kiểm nào bắt được vì chưa ai bấm tới.
        case validateSchema, browseVersions, pluginMenu

        case toggleJSONPath, openCleanBench, closePanels
        case lintYAML, sortJSONKeys, filterLogLevel, convertFormat
        case playMacro, findAction, showTabInOtherPane, writeSnapshots, toggleCompletion

        func perform(on controller: MainWindowController, _ random: inout DeterministicRNG) {
            let buffer = controller.editorDocument.buffer
            let count = Swift.max(buffer.count, 1)
            func offset() -> Int { Int(random.next() % UInt64(count)) }

            switch self {
            case .type:
                controller.typeForSelfTest(Self.words[Int(random.next() % UInt64(Self.words.count))])
            case .deleteBackward:
                controller.deleteBackwardForSelfTest()
            case .newline:
                controller.insertNewlineForSelfTest()
            case .paste:
                controller.pasteForSelfTest("dán\tmột\tđoạn\n")
            case .moveCaret:
                controller.setCaretForSelfTest(documentOffset: offset())
            case .selectRange:
                let a = offset(), b = offset()
                controller.setSelectionForSelfTest(documentRange: Swift.min(a, b) ..< Swift.max(a, b))
            case .selectAll:
                controller.setSelectionForSelfTest(documentRange: 0 ..< buffer.count)
            case .undo:
                controller.undoDocument(nil)
            case .redo:
                controller.redoDocument(nil)
            case .sortLines:
                controller.sortLinesAscending(nil)
            case .dedupe:
                controller.removeDuplicateLines(nil)
            case .trimWhitespace:
                controller.trimTrailingWhitespace(nil)
            case .toggleWrap:
                controller.cycleWrapModeForSelfTest()
            case .toggleCSV:
                controller.setCSVModeForSelfTest(random.next() % 2 == 0)
            case .toggleTable:
                if controller.isTableViewVisibleForSelfTest {
                    controller.showTextViewForSelfTest()
                } else {
                    controller.showTableViewForSelfTest()
                }
            case .newTab:
                controller.newTab(nil)
            case .closeTab:
                controller.closeCurrentTabForSelfTest()
            case .closeTabAsking:
                controller.closeCurrentTabAskingForSelfTest()
            case .switchTab:
                let tabs = Swift.max(controller.tabCountForSelfTest, 1)
                controller.activateTabForSelfTest(Int(random.next() % UInt64(tabs)))
            case .find:
                controller.selectAllOccurrencesForSelfTest(
                    Self.words[Int(random.next() % UInt64(Self.words.count))])
            case .markLines:
                controller.markLinesForSelfTest([Int(random.next() % 8)], color: Int(random.next() % 9))
            case .loadFixture:
                controller.prepareSelfTestDocument(Self.fixture)

            case .splitPane:
                controller.splitForSelfTest(vertical: random.next() % 2 == 0)
            case .closeSplit:
                controller.closeSplitForSelfTest()
            case .focusOtherPane:
                controller.focusPaneForSelfTest(Int(random.next() % 2))
            case .toggleDocumentMap:
                controller.toggleDocumentMapForSelfTest()
            case .toggleFunctionList:
                if controller.functionListVisibleForSelfTest {
                    controller.closeFunctionListForSelfTest()
                } else {
                    controller.openFunctionListForSelfTest()
                }
            case .jsonFormat:
                controller.formatJSONForSelfTest()
            case .jsonMinify:
                controller.minifyJSONForSelfTest()
            case .validateCSV:
                controller.validateForSelfTest()
            case .changeDelimiter:
                // Dấu phân tách người dùng thật hay đổi qua lại. `\t` và `;` là hai cái hay gặp
                // nhất sau dấu phẩy, và cả ba đều nằm trong dữ liệu mẫu.
                controller.changeDelimiterForSelfTest([UInt8(0x2C), UInt8(0x09), UInt8(0x3B)][
                    Int(random.next() % 3)])
            case .setLanguage:
                controller.setSyntaxLanguageForSelfTest(
                    [SyntaxLanguage.json, .python, .yaml, nil][Int(random.next() % 4)])
            case .resizeWindow:
                // Đổi cỡ cửa sổ tính lại toàn bộ hình học ngắt dòng — đúng chỗ bản đồ tài liệu
                // đã từng hỏng vì đo bề cao lúc bố cục chưa xong.
                _ = controller.setWindowWidthForSelfTest(Double(400 + random.next() % 900))
                _ = controller.setWindowHeightForSelfTest(Double(300 + random.next() % 600))
            case .togglePin:
                controller.togglePinForSelfTest(
                    Int(random.next() % UInt64(Swift.max(controller.tabCountForSelfTest, 1))))
            case .moveLine:
                controller.moveDownForSelfTest()
            case .goToMark:
                controller.goToNextMarkForSelfTest()
            case .deleteMarkedLines:
                controller.deleteMarkedLinesForSelfTest()
            case .recordMacro:
                controller.toggleMacroRecordingForSelfTest()

            case .columnCommand:
                let column = Int(random.next() % 4)
                controller.runColumnCommandForSelfTest(
                    [.insertLeft(column), .insertRight(column), .delete(column),
                     .move(from: column, to: Int(random.next() % 4))][Int(random.next() % 4)])
            case .selectColumnBlock:
                let line = Int(random.next() % 6)
                controller.selectColumnBlockForSelfTest(
                    from: (line, Int(random.next() % 10)),
                    to: (line + Int(random.next() % 4), Int(random.next() % 20)))
            case .runSQL:
                // Trộn câu ĐÚNG với câu SAI: đường báo lỗi cũng là mã sản phẩm, và nó chạy
                // trên chính tài liệu đang bị các thao tác khác vặn vẹo.
                _ = try? controller.runSQLForSelfTest(Self.queries[
                    Int(random.next() % UInt64(Self.queries.count))])
            case .toggleSQLPanel:
                if controller.sqlPanelVisibleForSelfTest {
                    controller.closeSQLPanelForSelfTest()
                } else {
                    controller.openSQLPanelForSelfTest()
                }
            case .openWorkspace:
                controller.openWorkspaceForSelfTest(Self.workspaceRoot.path)
            case .workspaceNewFile:
                // CHỈ tạo, và chỉ trong thư mục tạm của lượt chạy này — xem chú thích ở `Action`.
                guard controller.workspaceRootForSelfTest != nil else { break }
                controller.runWorkspaceCommandForSelfTest(
                    random.next() % 2 == 0
                        ? .newFile(inDirectory: Self.workspaceRoot.path)
                        : .newFolder(inDirectory: Self.workspaceRoot.path))
            case .closeWorkspace:
                controller.closeWorkspaceForSelfTest()

            case .validateSchema:
                controller.validateXMLAgainstSchema(nil)
            case .browseVersions:
                _ = controller.makeDocumentVersionsMenu()
            case .pluginMenu:
                _ = controller.makeNativePluginMenu()

            case .toggleJSONPath:
                if controller.jsonPathPanelVisibleForSelfTest {
                    controller.closeJSONPathForSelfTest()
                } else {
                    controller.openJSONPathForSelfTest()
                }
            case .openCleanBench:
                controller.openCleanBenchForSelfTest()
            case .closePanels:
                // Đóng mọi panel cùng lúc: trạng thái panel còn sót là đúng thứ NFR-REL-03 nói
                // tới ("một trạng thái panel còn sót làm thao tác sau sập").
                controller.closeCleanPanelForSelfTest()
                controller.closeValidationPanelForSelfTest()
                controller.closeJSONPathForSelfTest()
                controller.closeFunctionListForSelfTest()
            case .lintYAML:
                controller.lintYAMLForSelfTest()
            case .sortJSONKeys:
                controller.sortJSONKeysForSelfTest()
            case .filterLogLevel:
                controller.filterLogLevelForSelfTest(
                    LogFormat.Level.allCases[Int(random.next() % UInt64(LogFormat.Level.allCases.count))])
            case .convertFormat:
                controller.convertForSelfTest(
                    CSVExport.Format.allCases[Int(random.next() % UInt64(CSVExport.Format.allCases.count))])
            case .playMacro:
                controller.runMacroForSelfTest(repetitions: Int(1 + random.next() % 3))
            case .findAction:
                controller.typeIntoFindFieldForSelfTest(
                    Self.words[Int(random.next() % UInt64(Self.words.count))])
                controller.handleFindActionForSelfTest(
                    [.findNext, .findPrevious, .replaceCurrent, .countAll, .incremental][
                        Int(random.next() % 5)])
            case .showTabInOtherPane:
                controller.showTabInOtherPaneForSelfTest()
            case .writeSnapshots:
                controller.writeSnapshotsForSelfTest()
            case .toggleCompletion:
                controller.setCompletionEnabledForSelfTest(random.next() % 2 == 0)
            }
        }

        /// Câu truy vấn: ba câu chạy được, hai câu SAI. Đường báo lỗi cũng là mã sản phẩm.
        static let queries = [
            "SELECT * LIMIT 5",
            "SELECT ten WHERE tuoi > 20",
            "SELECT COUNT(*) GROUP BY thanh_pho",
            "SELECT khong_co_cot_nay",
            "SELECT * WHERE",
        ]

        /// Thư mục tạm của riêng lượt chạy này — mọi lệnh workspace chỉ được chạm vào đây.
        ///
        /// Dựng bằng `lazy static` nên nó ra đời ở lần dùng đầu tiên và sống tới hết lượt chạy.
        /// `Unattended.registerTemporaryRoot` lo phần dọn khi lượt chạy ĐẠT.
        static let workspaceRoot: URL = {
            let root = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("geditor-soak-workspace-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(
                at: root, withIntermediateDirectories: true)
            try? "ten,tuoi\nNguyễn An,30\n".write(
                to: root.appendingPathComponent("mau.csv"), atomically: true, encoding: .utf8)
            Unattended.registerTemporaryRoot(root)
            return root
        }()

        /// Chữ có dấu, có TAB, có dòng dài — đúng thứ hay làm lộ lỗi biên.
        static let words = ["Nguyễn", "a", "\tthụt", "Đà Nẵng, Việt Nam", "", "x\ny", "ệ"]

        static let fixture = """
            ten,tuoi,thanh_pho
            Nguyễn An,30,Hà Nội
            Trần Bình,25,"Lê Lợi, quận 1"
            Lê Cường,41,Đà Nẵng

            """
    }

    // MARK: - Báo cáo

    private static func report(
        operations: Int, seed: Int, seconds: Double, footprints: [Double], idle: Double, hold: Int,
        counts: [String: Int], controller: MainWindowController
    ) -> Never {
        let first = footprints.first ?? 0
        let last = footprints.last ?? 0
        let peak = footprints.max() ?? 0

        // Rò bộ nhớ nhận ra bằng XU HƯỚNG, không bằng một cặp số. Bộ nhớ lên rồi xuống là bình
        // thường — bảng băm nở ra rồi được trả lại. Chỉ khi nửa sau CAO HƠN HẲN nửa đầu và
        // không bao giờ tụt về thì mới đáng gọi là rò.
        let half = footprints.count / 2
        let early = footprints.prefix(Swift.max(half, 1)).reduce(0, +) / Double(Swift.max(half, 1))
        let late = footprints.suffix(Swift.max(half, 1)).reduce(0, +) / Double(Swift.max(half, 1))
        let growth = late - early
        // Trần 40 MB là ĐỀ NGHỊ, chưa phải chỉ tiêu đã chốt: bộ tài liệu chưa có con số cho
        // NFR-REL-03. Đặt nó bằng nửa trần RAM nhàn rỗi (NFR-PERF-05 = 80 MB) — một lượt chạy
        // dài mà ngốn thêm bằng cả app lúc nhàn rỗi thì có gì đó không trả lại.
        let budget = 40.0
        let errors = Unattended.errorCount

        var lines: [String] = []
        lines.append("")
        lines.append("  NFR-REL-03 — chạy dài trên ứng dụng thật")
        lines.append(String(format: "  %d thao tác · hạt giống %d · %.1f s (%.0f thao tác/giây)",
                            operations, seed, seconds, Double(operations) / Swift.max(seconds, 0.001)))
        lines.append("")
        lines.append(String(format: "  Bộ nhớ   đầu %.1f MB · đỉnh %.1f · cuối %.1f", first, peak, last))
        lines.append(String(format: "           xu hướng nửa đầu %.1f → nửa sau %.1f (chênh %+.1f MB, trần %.0f)",
                            early, late, growth, budget))
        lines.append(String(format: "           sau khi để RẢNH %d giây: %.1f MB (trả lại %.1f so với lúc cuối)",
                            hold, idle, last - idle))
        lines.append("")
        lines.append("  Tài liệu còn sống: \(controller.tabCountForSelfTest) tab, "
            + "\(controller.editorDocument.buffer.count) byte")
        lines.append("  Lỗi app định báo cho người dùng: \(errors)"
            + (errors > 0 ? " — gần nhất: \(Unattended.lastError ?? "")" : "")
            + " (bộ đếm đã qua đối chứng âm)")
        // Câu hỏi bị chặn KHÔNG phải lỗi — `Unattended.ask` trả `.abort` nên chỗ gọi đi nhánh
        // "người dùng huỷ". Nhưng con số ấy nói ra một điều bản báo cáo không có chỗ nào khác
        // nói được: bao nhiêu thao tác đã bị HUỶ GIỮA CHỪNG. Số 0 ở đây nghĩa là nhánh huỷ
        // chưa từng được đi, tức lượt chạy hẹp hơn vẻ ngoài của nó.
        lines.append("  Câu hỏi bị chặn (thao tác tự huỷ): \(Unattended.promptCount)"
            + (Unattended.promptCount > 0 ? " — gần nhất: \(Unattended.lastPrompt ?? "")" : ""))
        lines.append("")

        // Quá ít mẫu thì KHÔNG kết luận. Nói "chưa đủ dữ liệu" và thoát khác 0 — im lặng cho
        // qua là cách một cổng chặn trở nên vô dụng mà không ai biết.
        guard footprints.count >= 6 else {
            lines.append("  ⚠️ CHƯA KẾT LUẬN ĐƯỢC — mới \(footprints.count) mẫu bộ nhớ, "
                + "cần lượt chạy dài hơn")
            lines.append("")
            print(lines.joined(separator: "\n"))
            exit(2)
        }

        let leaked = growth > budget
        if leaked {
            lines.append(String(format: "  ❌ KHÔNG ĐẠT — bộ nhớ tăng %+.1f MB giữa nửa đầu và nửa sau", growth))
        } else {
            lines.append("  ✅ ĐẠT — không sập, bộ nhớ không tăng đều")
        }
        lines.append("")
        lines.append("  Số lần mỗi thao tác:")
        for (name, times) in counts.sorted(by: { $0.key < $1.key }) {
            lines.append(String(format: "    %-16s %5d", (name as NSString).utf8String!, times))
        }
        lines.append("")
        print(lines.joined(separator: "\n"))
        if !leaked { Unattended.removeTemporaryRoots() }
        exit(leaked ? 1 : 0)
    }

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var size = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &size)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    private static func intOption(_ name: String, in arguments: [String], default fallback: Int) -> Int {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count,
              let value = Int(arguments[index + 1])
        else { return fallback }
        return value
    }
}

/// Sinh số giả ngẫu nhiên TẤT ĐỊNH — cùng hạt giống, cùng dãy thao tác, nên một lần đỏ tái hiện
/// được. Cùng thuật toán với `DeterministicRNG` của bộ đo (xorshift64*).
struct DeterministicRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}

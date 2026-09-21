import AppKit
import XCTest
@testable import EideGiaoDien
@testable import EideLoi

/// **S9 — Làm rõ yêu cầu.** Màn đầu của nhóm THIẾT KẾ.
@MainActor
final class EideManLamRoTests: XCTestCase {

    /// **Màn này KHÔNG sinh gì khi mở.** `chat.restate` và `chat.clarify` đều gọi mô hình — tức
    /// qua mạng và qua tiền. Một màn tự gọi chúng lúc mở là một màn tiêu tiền của người dùng mỗi
    /// lần họ bấm vào cột trái.
    func testMoManKhongGoiNangLucSINHnao() async {
        var daGoi: [String] = []
        let m = EideManLamRo()
        await m.nap { ten, tham in
            daGoi.append((tham["id"] as? String) ?? ten)
            return ["status": "done", "result": ["items": [Any](), "turns": [Any]()]]
        }
        for cam in ["chat.restate", "chat.clarify", "caps.invoke"] {
            XCTAssertFalse(daGoi.contains(cam), "màn tự gọi `\(cam)` lúc mở — \(daGoi)")
        }
        // `view.artifacts` thêm ở [DEV-151]: màn này nay đọc ĐIỂM CẦN LÀM RÕ — kết quả thật
        // của việc làm rõ yêu cầu — chứ không chỉ hiện lịch sử trò chuyện. Nó vẫn là một lời
        // gọi ĐỌC, nên bất biến "mở màn không sinh gì" ở trên giữ nguyên.
        XCTAssertEqual(Set(daGoi), ["queue.list", "chat.history", "view.artifacts"], "\(daGoi)")
    }

    /// Hàng đợi trộn hai thứ: câu hỏi của `chat.clarify` và mục ASK của một năng lực bất kỳ bị
    /// cổng chặn. Không tách thì S9 hiện lại nguyên cột phải dưới một cái tên khác.
    func testTachCauHoiGopKhoiMucASKthuongCuaCong() {
        XCTAssertTrue(EideManLamRo.laCauHoiGop(["cap": "chat.clarify"]))
        XCTAssertTrue(EideManLamRo.laCauHoiGop(["question": "Dùng I2C1 hay I2C2?"]))
        XCTAssertFalse(EideManLamRo.laCauHoiGop(["cap": "code.merge"]),
                       "mục ASK của cổng merge không thuộc màn này")
    }

    /// **"Người bỏ qua được"** — UXC-31 §8 S9. Bỏ qua KHÔNG phải từ chối: nó để câu hỏi nguyên
    /// chỗ. Gộp hai thứ vào nút "Không" biến một lần bỏ qua thành một lần từ chối vĩnh viễn.
    func testBoQuaKhongPhaiTuChoi() async {
        var daGoi: [String] = []
        let m = EideManLamRo()
        await m.nap { ten, tham in
            daGoi.append(ten)
            return ten == "queue.list"
                ? ["status": "done", "result": ["items": [["run_id": "r1", "cap": "chat.clarify",
                                                           "question": "Dùng I2C1 hay I2C2?"]]]]
                : ["status": "done", "result": ["turns": [Any]()]]
        }
        XCTAssertTrue(Self.chu(m).contains("Bỏ qua"), Self.chu(m))

        daGoi.removeAll()
        m.boQuaDeTest()
        XCTAssertFalse(daGoi.contains("chat.answer"), "bỏ qua mà vẫn quyết hộ người dùng")
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("vẫn nằm nguyên"), van)
        XCTAssertTrue(van.contains("mặc định an toàn"), van)
    }

    /// Câu hỏi phải hiện kèm LÝ DO của cổng — người quyết cần biết vì sao mình đang được hỏi.
    func testCauHoiHienKemLyDoCuaCong() async {
        let m = EideManLamRo()
        await m.nap { ten, _ in
            ten == "queue.list"
                ? ["status": "done", "result": ["items": [[
                    "run_id": "r1", "cap": "chat.clarify",
                    "question": "Dùng I2C1 hay I2C2?",
                    "decision": ["decision": "ASK", "rule": "GEN-03",
                                 "reason": "Lệnh chạm hai ngoại vi"]]]]]
                : ["status": "done", "result": ["turns": [Any]()]]
        }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("Dùng I2C1 hay I2C2?"), van)
        XCTAssertTrue(van.contains("Lệnh chạm hai ngoại vi"), van)
        XCTAssertTrue(van.contains("GEN-03"), van)
        XCTAssertTrue(van.contains("1 CÂU HỎI ĐANG CHỜ ANH"), van)
    }

    /// Ý hiểu lấy lượt `restate` GẦN NHẤT, không phải lượt đầu: người sửa lại câu lệnh thì tác
    /// tử nói lại ý hiểu mới, và hiện bản cũ là hiện một thoả thuận đã hết hiệu lực.
    func testYHieuLayLuotGanNhat() {
        let luot: [[String: Any]] = [
            ["role": "restate", "text": "Ý hiểu CŨ"],
            ["role": "human", "text": "không, tôi muốn khác"],
            ["role": "restate", "text": "Ý hiểu MỚI"],
        ]
        XCTAssertEqual(EideManLamRo.yHieuGanNhat(luot), "Ý hiểu MỚI")
        XCTAssertNil(EideManLamRo.yHieuGanNhat([["role": "human", "text": "x"]]))
    }

    /// Chưa có gì → trạng thái rỗng chỉ đúng đường tới thứ SINH RA nội dung của màn.
    ///
    /// Câu cũ nói "chưa có lượt trao đổi nào" vì màn này từng hiện lịch sử trò chuyện. Từ
    /// [DEV-151] nội dung của nó là các ĐIỂM CẦN LÀM RÕ, nên câu rỗng phải chỉ tới hai năng lực
    /// sinh ra chúng — chỉ sai chỗ thì người dùng đi làm một việc không dẫn tới đâu.
    func testChuaCoDiemNaoThiChiDuongRa() async {
        let m = EideManLamRo()
        await m.nap { _, _ in ["status": "done", "result": ["items": [Any](), "turns": [Any]()]] }
        let van = Self.chu(m)
        XCTAssertTrue(van.contains("chưa có điểm nào cần làm rõ"), van)
        XCTAssertTrue(van.contains("req.elicit") && van.contains("req.detect_conflict"), van)
    }

    func testManDaNoiVaoBangManVaKhaiBaoNghe() {
        XCTAssertNotNil(EidePhien.MAN[EideManLamRo.tien])
        XCTAssertEqual(EideManHinhDS.man(EideManLamRo.tien)?.ma, "S9")
        XCTAssertNotNil(EideDangKySuKien.BANG[EideManLamRo.tien], "chưa khai báo nghe gì (§7.1)")
    }

    static func chu(_ v: NSView) -> String {
        var ra = ""
        // `NSTextView` — bảng có ô bấm được ([DEV-133]) dùng nó thay cho
        // `NSTextField`. Thiếu nhánh này thì cả bảng VÔ HÌNH với bài kiểm,
        // và bài kiểm đỏ vì phép ĐO mù chứ không vì màn hỏng.
        if let t = v as? NSTextView { ra += t.string + " " }
        if let t = v as? NSTextField {
            ra += t.attributedStringValue.string.isEmpty ? t.stringValue
                                                         : t.attributedStringValue.string
        }
        if let b = v as? NSButton { ra += " " + b.title }
        for c in v.subviews { ra += "\n" + chu(c) }
        return ra
    }
}

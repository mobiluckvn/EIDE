import AppKit
import EideGiaoDien
import Foundation

/// **Bộ lái kịch bản** — `--kich-ban <tệp>`.
///
/// Chạy một phiên làm việc THẬT qua đúng đường giao diện: gõ vào ô lệnh của vùng trao đổi, bấm
/// Gửi, chờ tác tử làm xong, chụp màn hình, ghi nhật ký. Không gọi tắt vào `chat.send` — nó đi
/// qua `EideDock.onGui` y như một người ngồi trước máy, nên mọi thứ nằm giữa (thẻ Ý hiểu, thẻ
/// Run, cột phải, badge) đều được thi hành chứ không bị bỏ qua.
///
/// UXC-31 §10.1 gọi đúng thứ này: *"mỗi bài kiểm là một kịch bản tự động thao tác UI thật + đọc
/// sổ cái đối chiếu"*. `--tu-kiem` đo từng bộ phận; chế độ này đo một PHIÊN.
///
/// ## Vì sao cần, thay vì chỉ `--tu-kiem`
///
/// `--tu-kiem` cố ý không gọi `chat.send`: đường ấy đi qua mô hình, tức qua mạng và qua tiền,
/// nên nó không thuộc về một bài chạy mỗi lần build. Nhưng "tác tử có làm được việc không" là
/// câu hỏi duy nhất mà không bộ phận nào tự trả lời được — phải chạy cả phiên mới biết.
///
/// ## Tệp kịch bản
///
/// Một lệnh mỗi dòng. `#` là ghi chú. Dòng bắt đầu bằng `@tao ` tạo dự án mới với phần còn lại
/// làm câu mô tả; các dòng khác gõ vào ô lệnh.
@MainActor
enum KichBan {

    /// Chờ tối đa cho một lệnh. Một chuỗi có `code.build` hay `sim.run` chạy lâu; quá ngưỡng
    /// này thì GHI LẠI là quá hạn chứ không treo vô hạn — một kịch bản treo không cho ai biết
    /// nó đang chờ gì.
    static let HAN_GIAY: Double = 900

    static func chay(_ ud: UngDung, tep: String, ra: URL) async {
        let fm = FileManager.default
        try? fm.createDirectory(at: ra, withIntermediateDirectories: true)
        var nhat: [String] = []
        func ghi(_ s: String) {
            nhat.append(s)
            print(s)
            try? nhat.joined(separator: "\n").write(to: ra.appendingPathComponent("nhat-ky.md"),
                                                    atomically: true, encoding: .utf8)
        }

        guard let van = try? String(contentsOfFile: tep, encoding: .utf8) else {
            print("không đọc được kịch bản: \(tep)")
            exit(2)
        }
        let dong = van.split(separator: "\n").map(String.init)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        ghi("# Nhật ký phiên — kịch bản `\((tep as NSString).lastPathComponent)`")
        ghi("")
        ghi("Chạy qua ĐÚNG đường giao diện: gõ vào ô lệnh → bấm Gửi → `chat.send`. Mỗi bước")
        ghi("kèm một ảnh chụp cửa sổ thật.")
        ghi("")

        var buoc = 0
        // Ảnh chụp trước của vùng trao đổi. In cả khung mỗi bước làm nhật ký không đọc được:
        // tới bước 8 mỗi mục chứa lại cả bảy câu trước đó, và thứ MỚI — câu tác tử vừa nói —
        // nằm lẫn ở cuối một khối chữ dài. Chỉ in phần mọc thêm.
        var truocDo: [String] = []
        for lenh in dong {
            buoc += 1
            let t0 = ProcessInfo.processInfo.systemUptime
            ghi("## Bước \(buoc)")
            ghi("")

            if lenh.hasPrefix("@tao ") {
                let mo = String(lenh.dropFirst(5))
                ghi("**Tôi (người dùng):** tạo dự án — “\(mo)”")
                await ud.phien.taoDuAn(mo, thuMuc: ra.appendingPathComponent("du-an").path)
            } else {
                ghi("**Tôi (người dùng):** \(lenh)")
                // ĐÚNG đường người dùng đi: đặt chữ vào ô lệnh rồi bấm Gửi.
                let truoc = ud.khung.dock.soLuot
                ud.khung.dock.guiDeTest(lenh)
                await cho(ud, sau: truoc)
            }

            let giay = ProcessInfo.processInfo.systemUptime - t0
            ud.khung.layoutSubtreeIfNeeded()
            let anh = "buoc-\(String(format: "%02d", buoc)).png"
            ud._chupCong(ra.appendingPathComponent(anh))

            ghi("")
            ghi("**Tác tử trả lời** *(sau \(String(format: "%.1f", giay)) s)*:")
            ghi("")
            ghi("```")
            let nay = UngDung.chuTrongTinh(ud.khung.dock).split(separator: "\n")
                .map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let them = nay.count > truocDo.count ? Array(nay.dropFirst(truocDo.count)) : nay
            truocDo = nay
            ghi(them.isEmpty ? "(tác tử không nói gì)" : them.joined(separator: "\n"))
            ghi("```")
            ghi("")
            ghi("![bước \(buoc)](\(anh))")
            ghi("")
        }

        ghi("---")
        ghi("")
        ghi("Hết kịch bản — \(buoc) bước. Ảnh và nhật ký trong `\(ra.path)`.")
        exit(0)
    }

    /// Chờ tác tử **trả lời xong**, không phải chờ vùng trao đổi đứng yên.
    ///
    /// Hai chuyện khác nhau, và lẫn chúng làm hỏng cả bài đo. Bản đầu chỉ hỏi "đã yên 4 nhịp
    /// chưa và còn thẻ Run nào chạy không" — nhưng trong lúc `chat.send` đợi mô hình trả lời
    /// thì vùng trao đổi YÊN (chưa có gì để thêm) và `dangChay` là `false` (chưa có thẻ Run nào
    /// được dựng). Cả hai điều kiện đúng, nên bộ lái chụp ảnh rồi đi tiếp.
    ///
    /// Đo ngày 21/09/2026 trên bài CNC: bước 7 "xong" sau 5,3 s trong khi gọi thẳng daemon cùng
    /// câu ấy mất 19,4 s; và thứ hiện ở bước 8 là ý hiểu của **bước 1** — câu trả lời lê sau
    /// bảy bước, mỗi ảnh chụp đều chụp nhầm lượt.
    ///
    /// Nên mốc phải là một sự kiện DƯƠNG: vùng trao đổi mọc thêm ít nhất một lượt **của tác
    /// tử**, tính từ số lượt trước khi gõ. `+2` vì bong bóng của chính người dùng đã chiếm một.
    ///
    /// - Parameter sau: `dock.soLuot` đo NGAY TRƯỚC khi gõ.
    private static func cho(_ ud: UngDung, sau moc: Int) async {
        let t0 = ProcessInfo.processInfo.systemUptime
        var truoc = -1
        var yen = 0
        var daTraLoi = false
        while ProcessInfo.processInfo.systemUptime - t0 < HAN_GIAY {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let n = ud.khung.dock.soLuot
            if n >= moc + 2 { daTraLoi = true }
            if n == truoc {
                yen += 1
                // `daTraLoi` là điều kiện THÊM, không thay thế: sau khi tác tử nói câu đầu nó
                // còn nói tiếp (thẻ Run, câu hỏi chờ người), nên vẫn phải đợi yên hẳn.
                if daTraLoi && yen >= 4 && !ud.khung.dock.dangChay { return }
            } else {
                yen = 0
                truoc = n
            }
        }
        print("  ⚠ quá hạn \(Int(HAN_GIAY)) s mà tác tử "
              + (ud.khung.dock.soLuot >= moc + 2 ? "chưa nói xong" : "CHƯA NÓI GÌ")
              + " — ghi lại và đi tiếp")
    }
}

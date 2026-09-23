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
/// Một lệnh mỗi dòng. `#` là ghi chú. `@tao <mô tả>` tạo dự án mới; `@mo <đường dẫn>` mở lại
/// một dự án đang có; các dòng khác gõ vào ô lệnh.
///
/// ## Vì sao có `@mo`: một bài test lớn phải chia được thành CHẶNG
///
/// Bản đầu chạy cả bài trong một tệp tám lượt, mỗi lượt đòi trọn một giai đoạn công việc. Đo
/// 21/09/2026 trên bài CNC: planner sinh chuỗi 14 rồi 23 nút và đâm vào trần 12 nút của
/// DPS-09 §4.4, còn những chuỗi dựng được thì đòi hiện vật (`module_ids`, `decision`,
/// `artifact`) mà các lượt trước chưa hề sinh ra.
///
/// Nhưng lỗi nặng hơn nằm ở HÌNH DẠNG của kịch bản: nó là một bài **độc thoại**. Tác tử dừng
/// lại hỏi ba lần và bộ lái không trả lời lần nào, cứ thế gõ tiếp một yêu cầu lớn hơn. Một
/// cuộc trao đổi thật thì người đọc câu hỏi rồi mới soạn câu sau — và điều đó chỉ làm được nếu
/// chạy được từng chặng, đọc nhật ký, rồi chạy chặng kế trên CÙNG một dự án.
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
        for lenh in dong {
            buoc += 1
            let t0 = ProcessInfo.processInfo.systemUptime
            ghi("## Bước \(buoc)")
            ghi("")

            if lenh.hasPrefix("@tao ") {
                let mo = String(lenh.dropFirst(5))
                ghi("**Tôi (người dùng):** tạo dự án — “\(mo)”")
                await ud.phien.taoDuAn(mo, thuMuc: ra.appendingPathComponent("du-an").path)
            } else if lenh.hasPrefix("@mo ") {
                // MỞ LẠI dự án đang có. Không có chỉ thị này thì mỗi chặng phải tạo dự án mới,
                // và chặng 2 sẽ hỏi tác tử về một thiết kế mà dự án của nó chưa hề có — tức là
                // đo một cuộc trao đổi đã mất trí nhớ giữa chừng.
                let d = NSString(string: String(lenh.dropFirst(4))).expandingTildeInPath
                ghi("**Tôi (người dùng):** mở lại dự án — `\((d as NSString).lastPathComponent)`")
                await ud.phien.moDuAn(d)
            } else if lenh.hasPrefix("@tra-loi-dau ") {
                // Trả lời điểm cần làm rõ ĐANG MỞ ĐẦU TIÊN — như người đọc dòng trên cùng rồi
                // trả lời nó. Mã băm theo nội dung nên kịch bản không biết trước được.
                let van = String(lenh.dropFirst(13)).trimmingCharacters(in: .whitespaces)
                if let m = ud.khung.vungLamViec.manDangMo as? EideManLamRo,
                   let ma = m.maDiemDauTien {
                    ghi("**Tôi (người dùng):** trả lời điểm `\(ma)` → “\(van)”")
                    await m.traLoiDeTest(ma, van)
                } else {
                    ghi("(không có điểm nào đang mở để trả lời — `@man LamRo` trước)")
                }
            } else if lenh.hasPrefix("@tra-loi ") {
                // GÕ VÀO Ô TRẢ LỜI của màn Làm rõ yêu cầu rồi bấm Lưu — `<mã> | <câu trả lời>`.
                // Đi qua đúng nút người bấm, không gọi tắt xuống năng lực.
                let phan = String(lenh.dropFirst(9)).components(separatedBy: "|")
                let ma = phan.first?.trimmingCharacters(in: .whitespaces) ?? ""
                let van = phan.dropFirst().joined(separator: "|")
                    .trimmingCharacters(in: .whitespaces)
                ghi("**Tôi (người dùng):** trả lời `\(ma)` → “\(van)”")
                if let m = ud.khung.vungLamViec.manDangMo as? EideManLamRo {
                    await m.traLoiDeTest(ma, van)
                } else {
                    ghi("(màn Làm rõ yêu cầu chưa mở — `@man LamRo` trước)")
                }
            } else if lenh.hasPrefix("@hoan-tac ") {
                // BẤM nút Hoàn tác ở cột phải — `@hoan-tac <mã>`, hoặc `@hoan-tac moi-nhat`
                // để lấy mục trên cùng (thứ người gần như luôn muốn gỡ).
                let x = String(lenh.dropFirst(10)).trimmingCharacters(in: .whitespaces)
                let ma = x == "moi-nhat" ? (ud.khung.cotPhai.maHoanTacDau ?? "") : x
                ghi("**Tôi (người dùng):** bấm Hoàn tác cho `\(ma)`")
                ud.khung.cotPhai.bamHoanTacDeTest(ma)
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            } else if lenh == "@quet-man" {
                // QUÉT MỌI TAB tác tử đã mở — [DEV-199].
                //
                // Vùng làm việc chỉ giữ MỘT màn sống (`xoaThan` rồi `datMan`); những tab khác
                // chỉ là mục ở cột trái, nội dung nằm dưới store cho tới khi có người bấm vào.
                // Nên đọc "màn đang mở" là đọc đúng một trong số N thứ tác tử vừa làm ra.
                //
                // Đo 23/09/2026: TC005 chạy trọn `req.elicit`…`req.detect_conflict` 6/6 bước,
                // nhật ký ghi "màn trống" — vì màn đang hiện là Main, còn kết quả nằm ở tab Yêu
                // cầu & kiến trúc đang nằm nền. Ba lần liên tiếp tôi suýt kết luận sản phẩm
                // không làm gì, cả ba lần đều là thước đo nhìn thiếu chỗ.
                //
                // Quét = bấm lần lượt từng tab, đúng việc người rà soát sẽ làm.
                let ds = ud.khung.thanhTab.tab
                ghi("**Quét \(ds.count) tab tác tử đã mở:** \(ds.joined(separator: ", "))")
                for (k, tien) in ds.enumerated() {
                    _ = ud.phien.moMan(tien, boiTacTu: false)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    ud.khung.layoutSubtreeIfNeeded()
                    let chu = UngDung.chuTrongTinh(ud.khung.vungLamViec).split(separator: "\n")
                        .map(String.init)
                        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    let anh = "man-\(String(format: "%02d", k + 1))-\(tien).png"
                    ud._chupCong(ra.appendingPathComponent(anh))
                    ghi("")
                    ghi("### Tab `\(tien)`")
                    ghi("")
                    ghi("```")
                    ghi(chu.isEmpty ? "(màn trống)" : chu.joined(separator: "\n"))
                    ghi("```")
                    ghi("")
                    ghi("![\(tien)](\(anh))")
                }
                // CỘT PHẢI cũng phải vào nhật ký: quyết định cổng, mục hoàn tác và cảnh báo
                // an toàn hiện ở đó, không ở vùng trao đổi. Thiếu nó thì những TC hỏi "tác tử
                // có xin xác nhận trước thao tác không đảo ngược không" (TC035, TC068) không
                // có chỗ nào để đọc câu trả lời.
                let phai = UngDung.chuTrongTinh(ud.khung.cotPhai).split(separator: "\n")
                    .map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                ghi("")
                ghi("### Cột phải (cổng, hoàn tác, an toàn)")
                ghi("")
                ghi("```")
                ghi(phai.isEmpty ? "(cột phải trống)" : phai.joined(separator: "\n"))
                ghi("```")
            } else if lenh.hasPrefix("@man ") {
                // MỞ MỘT TAB, như người bấm vào cột trái. Không có chỉ thị này thì bộ lái chỉ
                // chụp được màn đang mở sẵn, và mọi khẳng định về "tab X hiện gì" là suy đoán
                // từ dữ liệu trong store chứ không phải từ màn hình.
                let tien = String(lenh.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                ghi("**Tôi (người dùng):** bấm vào tab `\(tien)` ở cột trái")
                _ = ud.phien.moMan(tien, boiTacTu: false)
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            } else {
                ghi("**Tôi (người dùng):** \(lenh)")
                // ĐÚNG đường người dùng đi: đặt chữ vào ô lệnh rồi bấm Gửi.
                let truoc = ud.khung.dock.soLuot
                let baoCaoTruoc = ud.phien.soBaoCao
                let ngayTruoc = ud.phien.soLuotTraLoiNgay
                ud.khung.dock.guiDeTest(lenh)
                await cho(ud, sau: truoc, baoCaoTruoc: baoCaoTruoc, ngayTruoc: ngayTruoc)
            }

            let giay = ProcessInfo.processInfo.systemUptime - t0
            ud.khung.layoutSubtreeIfNeeded()
            let anh = "buoc-\(String(format: "%02d", buoc)).png"
            ud._chupCong(ra.appendingPathComponent(anh))

            ghi("")
            ghi("**Tác tử trả lời** *(sau \(String(format: "%.1f", giay)) s)*:")
            ghi("")
            ghi("```")
            // IN ĐỦ, không cắt. Hai lần tôi thử làm nhật ký dễ đọc và cả hai lần đều đổi lấy
            // một phép đo mù, mỗi lần mù một kiểu:
            //
            //   `dropFirst(daDoc)` — giả định vùng trao đổi CHỈ MỌC THÊM. Nó không: thẻ Run
            //   cập nhật tại chỗ rồi bị gỡ khi xong, nên số phần tử giảm được và phần mới rơi
            //   xuống dưới ngưỡng cắt.
            //
            //   `suffix(14)` — giả định mỗi phần tử là một LƯỢT. Nó không: `chuTrongTinh` nối
            //   bằng dấu cách, nên phép tách theo "\n" chỉ tách ở những chỗ xuống dòng nằm sẵn
            //   BÊN TRONG nội dung, chẳng liên quan gì tới ranh giới giữa các lượt.
            //
            // Cả hai lần nhật ký đều báo "tác tử chỉ nói một dòng chi phí", trong khi ảnh chụp
            // cùng lúc ấy cho thấy thẻ Ý HIỂU đủ sáu bước và câu "DỪNG, đang chờ anh trả lời".
            // Một nhật ký sai đắt hơn một nhật ký dài: nó đẩy người đọc đi sửa một lỗi không
            // có thật. Ảnh chụp lo phần dễ đọc; chỗ này lo phần ĐÚNG.
            let nay = UngDung.chuTrongTinh(ud.khung.dock).split(separator: "\n")
                .map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ghi(nay.isEmpty ? "(tác tử không nói gì)" : nay.joined(separator: "\n"))
            ghi("```")

            // ĐỌC CẢ MÀN ĐANG MỞ, không chỉ vùng trao đổi. [DEV-199]
            //
            // Vùng trao đổi là nơi tác tử NÓI; nhưng phần lớn thứ nó LÀM ra — yêu cầu đã rút,
            // bảng so sánh phương án, danh sách phát hiện khi rà soát — được vẽ vào màn bên
            // phải, không vào bong bóng chat. Bản đầu chỉ đọc `khung.dock`, nên một lượt chạy
            // `req.elicit` + `req.classify` + `req.detect_conflict` xong 6/6 bước hiện ra trong
            // nhật ký y như một lượt không làm gì.
            //
            // Đo 23/09/2026 trên TC003: nhật ký cho thấy tác tử "không cảnh báo gì", trong khi
            // thứ nó viết nằm nguyên trên màn Yêu cầu & kiến trúc. Suýt nữa thì kết luận sản
            // phẩm không trả lời người dùng — từ một thước đo chỉ nhìn một góc màn hình.
            if let man = ud.khung.vungLamViec.manDangMo {
                let ten = type(of: man).tien
                let chu = UngDung.chuTrongTinh(man).split(separator: "\n")
                    .map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                ghi("")
                ghi("**Màn đang mở — `\(ten)`:**")
                ghi("")
                ghi("```")
                ghi(chu.isEmpty ? "(màn trống)" : chu.joined(separator: "\n"))
                ghi("```")
            }
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
    /// Và điều kiện "hết bận" phải đọc từ PHIÊN, không từ `dock.dangChay`: cờ ấy chỉ được gán
    /// lại mỗi khi một sự kiện từ daemon tới, nên giữa lúc gọi `chat.send` và lúc sự kiện đầu
    /// tiên về, nó vẫn `false`. Đo 21/09 trên chặng A: bước 2 "xong" sau 10,6 s trong khi thẻ
    /// Run còn ghi `bước 1/6 ▶ đang chạy req.elicit`.
    ///
    /// - Parameter sau: `dock.soLuot` đo NGAY TRƯỚC khi gõ.
    private static func cho(_ ud: UngDung, sau moc: Int, baoCaoTruoc: Int,
                            ngayTruoc: Int = 0) async {
        let t0 = ProcessInfo.processInfo.systemUptime
        var truoc = -1
        var yen = 0
        while ProcessInfo.processInfo.systemUptime - t0 < HAN_GIAY {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // MỐC THỨ HAI: lượt được tầng deterministic trả lời thẳng, không sinh chuỗi nào
            // nên không bao giờ có báo cáo. [DEV-200]
            //
            // Đo 23/09/2026 trên TC035: câu trả lời hiện ra tức thì, còn bộ lái đợi trọn 900
            // giây rồi ghi "quá hạn" — một phép đo báo sai về đúng thứ nó vừa đo đúng.
            if ud.phien.soLuotTraLoiNgay > ngayTruoc {
                try? await Task.sleep(nanoseconds: 1_500_000_000)   // để chữ vẽ xong
                return
            }
            // [DEV-154] Mốc là BÁO CÁO ĐÃ VỀ, không phải "hết bận". `chat.send` nay trả về ngay
            // với `state: "running"`, nên `dangBan` tắt sau vài giây trong khi chuỗi còn chạy
            // vài phút — đợi theo nó là chụp ảnh một lượt chưa làm gì.
            guard ud.phien.soBaoCao > baoCaoTruoc else { continue }
            let n = ud.khung.dock.soLuot
            if n == truoc {
                // Báo cáo về rồi vẫn đợi yên hẳn: nó sinh ra vài lượt liền nhau (thẻ Kết quả,
                // dòng lỗi, câu hỏi chờ người), và chụp giữa chừng thì thiếu.
                yen += 1
                if yen >= 3 && !ud.phien.dangBan { return }
            } else {
                yen = 0
                truoc = n
            }
        }
        print("  ⚠ quá hạn \(Int(HAN_GIAY)) s — "
              + (ud.phien.soBaoCao > baoCaoTruoc ? "báo cáo đã về nhưng vùng trao đổi chưa yên"
                                                 : "CHƯA có báo cáo lượt chạy nào")
              + ". Ghi lại và đi tiếp. (moc=\(moc))")
    }
}

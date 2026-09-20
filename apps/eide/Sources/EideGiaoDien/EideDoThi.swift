import AppKit
import EideLoi

/// Một nút của đồ thị tri thức — đúng các trường `view.kg_map` (VIEW-01) trả về.
public struct EideNutDoThi: Equatable {
    public let id: String
    public let nhan: String
    public let loai: String
    public let mau: String?
    public let tang: String?
    public let trangThai: String?

    public init(id: String, nhan: String, loai: String,
                mau: String? = nil, tang: String? = nil, trangThai: String? = nil) {
        self.id = id
        self.nhan = nhan
        self.loai = loai
        self.mau = mau
        self.tang = tang
        self.trangThai = trangThai
    }

    /// Dựng từ một phần tử `graph.nodes` của VIEW-01.
    public init?(_ d: [String: Any]) {
        guard let id = d["id"] as? String else { return nil }
        self.id = id
        nhan = (d["label"] as? String) ?? id
        loai = (d["kind"] as? String) ?? "khac"
        mau = d["color"] as? String
        tang = d["tier"] as? String
        trangThai = d["status"] as? String
    }
}

public struct EideCanhDoThi: Equatable {
    public let tu: String
    public let loai: String
    public let den: String

    public init(tu: String, loai: String, den: String) {
        self.tu = tu
        self.loai = loai
        self.den = den
    }

    public init?(_ d: [String: Any]) {
        guard let a = d["from"] as? String, let b = d["to"] as? String else { return nil }
        tu = a
        den = b
        // VIEW-01 trả `type`; `kg.lan_toa` trả `kind`. Nhận cả hai chứ không chọn một — hai
        // đường cùng đổ về màn này, và bỏ sót một tên nghĩa là mọi cạnh thành "?" không báo gì.
        loai = (d["type"] as? String) ?? (d["kind"] as? String) ?? "?"
    }
}

/// **Đồ thị tri thức — MỘT khung nhìn cho cả đồ thị.** UXC-31 §8 S7.
///
/// Cùng lý do với `EideManCoSo.bang`: một khung nhìn mỗi nút thì 240 nút là 240 khung nhìn,
/// và AppKit dựng chúng chậm hơn vẽ chúng một bậc. Ở đây cả đồ thị là một `draw(_:)`.
///
/// ## Bố cục theo CỘT, không phải lực đẩy
///
/// Đồ thị tri thức của EIDE có hướng đọc tự nhiên: **nguồn → fact → chủ thể → mã**. Một bố cục
/// lực đẩy (force-directed) sẽ trộn cả bốn loại vào một đám mây rồi đặt chúng ở chỗ khác nhau
/// sau mỗi lần mở — đẹp hơn, và vô dụng cho việc người ta mở màn này ra để làm: lần theo một
/// con số về tới trang datasheet đẻ ra nó.
///
/// Bố cục cột thì **tất định**: cùng dữ liệu cho cùng hình, nên so được hai lần mở, chụp ảnh
/// đối chiếu được, và viết được phép kiểm cho nó mà không cần vẽ.
@MainActor
public final class EideDoThi: NSView {

    /// Số nút VẼ tối đa. Lõi đã gom cụm khi quá 5.000 nút (VIEW-01) nên nó không cắt gì; chỗ
    /// cắt là ở đây, và nó không im lặng — `soBiCat` nói ra bao nhiêu nút không được vẽ.
    public static let TOI_DA_VE = 240

    /// Thứ tự cột — theo hướng đọc của đồ thị, không theo bảng chữ cái.
    ///
    /// `source` đứng đầu vì mọi thứ khác truy về nó; `code_unit`/`feature` đứng cuối vì chúng là
    /// thứ được sinh ra. Loại lạ xếp sau cùng theo thứ tự gặp, chứ không bị bỏ.
    public static let THU_TU_COT = ["source", "fact", "chip", "periph", "reg", "field",
                                    "code_unit", "feature"]

    public static let RONG_O: CGFloat = 148
    public static let CAO_O: CGFloat = 30
    public static let CACH_X: CGFloat = 66
    public static let CACH_Y: CGFloat = 12

    public private(set) var nut: [EideNutDoThi] = []
    public private(set) var canh: [EideCanhDoThi] = []
    public private(set) var viTri: [String: NSRect] = [:]
    public private(set) var soBiCat = 0

    /// Hệ số thu phóng — UXC-31 §8 S7 đòi "đồ thị thu phóng".
    public var tyLe: CGFloat = 1 { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }

    /// Nút đang chọn. Nhãn trên đồ thị chỉ là đoạn CUỐI của IRI, nên bấm một nút phải trả về id
    /// đầy đủ — nếu không thì `periph:I2C1` của hai con chip khác nhau trông y hệt nhau.
    public var onChon: ((EideNutDoThi) -> Void)?
    public private(set) var dangChon: String?

    public override var isFlipped: Bool { true }

    public func dat(nut ds: [EideNutDoThi], canh dsCanh: [EideCanhDoThi]) {
        soBiCat = max(0, ds.count - Self.TOI_DA_VE)
        nut = Array(ds.prefix(Self.TOI_DA_VE))
        let co = Set(nut.map(\.id))
        canh = dsCanh.filter { co.contains($0.tu) && co.contains($0.den) }
        viTri = Self.bayBien(nut)
        dangChon = nil
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    /// **Bố cục thuần** — không chạm AppKit, nên phép kiểm đo được nó mà không cần vẽ.
    public static func bayBien(_ ds: [EideNutDoThi]) -> [String: NSRect] {
        var cot: [String: [EideNutDoThi]] = [:]
        for n in ds { cot[n.loai, default: []].append(n) }
        let lạ = cot.keys.filter { !THU_TU_COT.contains($0) }.sorted()
        let thuTu = THU_TU_COT.filter { cot[$0] != nil } + lạ

        var ra: [String: NSRect] = [:]
        for (i, loai) in thuTu.enumerated() {
            // Trong một cột xếp theo NHÃN: thứ tự lõi trả về là thứ tự duyệt đồ thị, và nó đổi
            // khi thêm một fact bất kỳ. Sắp theo nhãn thì hai lần mở cho cùng một hình.
            for (j, n) in (cot[loai] ?? []).sorted(by: { $0.nhan < $1.nhan }).enumerated() {
                ra[n.id] = NSRect(x: CGFloat(i) * (RONG_O + CACH_X),
                                  y: CGFloat(j) * (CAO_O + CACH_Y) + 22,
                                  width: RONG_O, height: CAO_O)
            }
        }
        return ra
    }

    public override var intrinsicContentSize: NSSize {
        guard !viTri.isEmpty else { return NSSize(width: 10, height: 10) }
        let x = viTri.values.map(\.maxX).max() ?? 0
        let y = viTri.values.map(\.maxY).max() ?? 0
        return NSSize(width: (x + 12) * tyLe, height: (y + 12) * tyLe)
    }

    // MARK: - vẽ

    public override func draw(_ dirty: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.scaleBy(x: tyLe, y: tyLe)
        defer { ctx.restoreGState() }

        // Cạnh TRƯỚC nút, nếu không thì đường kẻ cắt ngang chữ.
        for c in canh {
            guard let a = viTri[c.tu], let b = viTri[c.den] else { continue }
            let p = NSPoint(x: a.maxX, y: a.midY)
            let q = NSPoint(x: b.minX, y: b.midY)
            ctx.setStrokeColor(Self.mauCanh(c.loai).cgColor)
            ctx.setLineWidth(c.loai == "CONFLICTS_WITH" ? 1.6 : 0.8)
            if c.loai == "SUPERSEDES" { ctx.setLineDash(phase: 0, lengths: [4, 3]) }
            ctx.move(to: p)
            // Cong nhẹ qua điểm giữa: hai cạnh cùng đi từ A tới hai nút thẳng hàng sẽ chồng lên
            // nhau nếu kẻ thẳng, và người đọc không đếm được có mấy cạnh.
            ctx.addQuadCurve(to: q, control: NSPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2 - 10))
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
        }

        for n in nut {
            guard let r = viTri[n.id] else { continue }
            let nen = Self.mau(n.mau) ?? EideToken.Mau.muted
            let duong = NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5)
            nen.withAlphaComponent(0.16).setFill()
            duong.fill()
            (n.id == dangChon ? EideToken.Mau.primary : nen).setStroke()
            duong.lineWidth = n.id == dangChon ? 2 : 1
            duong.stroke()

            let kieu = NSMutableParagraphStyle()
            kieu.lineBreakMode = .byTruncatingMiddle
            kieu.alignment = .center
            NSAttributedString(string: n.nhan, attributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: EideToken.Mau.text,
                .paragraphStyle: kieu,
            ]).draw(in: r.insetBy(dx: 5, dy: 7))
        }

        // Tiêu đề cột — không có nó thì bốn cột hộp màu không nói được chúng là gì.
        for (loai, x) in Self.cotVaX(nut) {
            NSAttributedString(string: loai.uppercased(), attributes: [
                .font: NSFont.boldSystemFont(ofSize: 9),
                .foregroundColor: EideToken.Mau.faint,
            ]).draw(at: NSPoint(x: x, y: 2))
        }
    }

    /// Tên cột và toạ độ x của nó — tách ra để phép kiểm đọc được thứ tự cột.
    public static func cotVaX(_ ds: [EideNutDoThi]) -> [(String, CGFloat)] {
        var thay: [String: CGFloat] = [:]
        let vt = bayBien(ds)
        for n in ds where thay[n.loai] == nil { thay[n.loai] = vt[n.id]?.minX }
        return thay.sorted { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    public static func mauCanh(_ loai: String) -> NSColor {
        switch loai {
        case "CONFLICTS_WITH": return EideToken.Mau.bad
        case "SUPERSEDES": return EideToken.Mau.border2
        case "CITES": return EideToken.Mau.info
        case "USES": return EideToken.Mau.ok
        default: return EideToken.Mau.border
        }
    }

    /// `#D4A017` → NSColor. Màu ĐI KÈM dữ liệu chứ không thay dữ liệu (VIEW-01), nên nút vẫn
    /// giữ `tier`/`status` nguyên văn và màu chỉ là lớp phủ.
    public static func mau(_ hex: String?) -> NSColor? {
        guard let h = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "# ")),
              h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                       green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    // MARK: - thu phóng và chọn

    public override func magnify(with event: NSEvent) {
        tyLe = min(2.4, max(0.4, tyLe * (1 + event.magnification)))
    }

    public override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let goc = NSPoint(x: p.x / tyLe, y: p.y / tyLe)
        guard let n = nut.first(where: { viTri[$0.id]?.contains(goc) == true }) else { return }
        dangChon = n.id
        needsDisplay = true
        onChon?(n)
    }
}

import AppKit
import GEditorCore

/// Đa ngôn ngữ giao diện EN/VI (FR-UI-804).
///
/// **Khoá là chính chuỗi tiếng Việt, không phải mã như `menu.file.new`.** Ba lý do:
///
/// 1. Toàn bộ giao diện đã viết bằng tiếng Việt. Đổi sang khoá trừu tượng là sửa hàng nghìn
///    chỗ trong một lần, và mỗi chỗ sửa là một cơ hội gõ nhầm khoá — lỗi kiểu ấy chỉ lộ ra khi
///    chạy, dưới dạng một nhãn trống trên màn hình.
/// 2. Thiếu bản dịch thì rơi về tiếng Việt, tức là về ĐÚNG hành vi hôm nay. Không có trạng thái
///    trung gian nào tệ hơn hiện tại.
/// 3. Đọc mã vẫn thấy được chữ thật sẽ hiện ra, không phải tra bảng mới biết.
///
/// Cái giá: hai chỗ dùng cùng một chữ tiếng Việt cho hai nghĩa khác nhau sẽ phải dịch chung một
/// từ. Chấp nhận được với hai ngôn ngữ; đến ngôn ngữ thứ ba thì tính lại.
///
/// **`Bundle.main.localizations` KHÔNG dùng ở đây** — nó đòi file `.lproj` trong bundle, mà hai
/// kênh phát hành có bố cục bundle khác nhau và `GrammarLibrary` đã một lần chết vì chuyện ấy.
enum L10n {

    /// Ngôn ngữ giao diện. Mã là BCP-47 để đưa thẳng cho `Locale` khi định dạng số và ngày.
    ///
    /// Nhóm theo vùng đúng thứ tự bộ chọn hiện ra. `vi` đứng riêng vì nó là ngôn ngữ NGUỒN —
    /// mọi khoá dịch chính là chuỗi tiếng Việt, nên nó không có bảng và không bao giờ thiếu chữ.
    enum Language: String, CaseIterable {
        case system
        case vi

        // Âu / Mỹ
        case en, fr, de, es, pt, it, nl, pl, sv, da, fi, nb, cs, el, hu, ro, uk, ru

        // Trung Đông
        case tr, ar, he, fa, ur

        // Á
        case zhHans = "zh-Hans", zhHant = "zh-Hant", ja, ko, hi, bn, ta, th, id, ms

        /// Tên NGÔN NGỮ ẤY tự gọi mình, không phải tên tiếng Việt của nó.
        ///
        /// Người đi tìm tiếng mẹ đẻ trong một danh sách đang hiện bằng thứ tiếng họ không đọc
        /// được thì chỉ nhận ra "日本語", không nhận ra "Tiếng Nhật". Đây là lý do mọi bộ chọn
        /// ngôn ngữ tử tế đều dùng tên bản ngữ.
        var displayName: String {
            switch self {
            case .system: return L("Theo hệ thống")
            case .vi: return "Tiếng Việt"
            case .en: return "English"
            case .fr: return "Français"
            case .de: return "Deutsch"
            case .es: return "Español"
            case .pt: return "Português"
            case .it: return "Italiano"
            case .nl: return "Nederlands"
            case .pl: return "Polski"
            case .sv: return "Svenska"
            case .da: return "Dansk"
            case .fi: return "Suomi"
            case .nb: return "Norsk bokmål"
            case .cs: return "Čeština"
            case .el: return "Ελληνικά"
            case .hu: return "Magyar"
            case .ro: return "Română"
            case .uk: return "Українська"
            case .ru: return "Русский"
            case .tr: return "Türkçe"
            case .ar: return "العربية"
            case .he: return "עברית"
            case .fa: return "فارسی"
            case .ur: return "اردو"
            case .zhHans: return "简体中文"
            case .zhHant: return "繁體中文"
            case .ja: return "日本語"
            case .ko: return "한국어"
            case .hi: return "हिन्दी"
            case .bn: return "বাংলা"
            case .ta: return "தமிழ்"
            case .th: return "ไทย"
            case .id: return "Bahasa Indonesia"
            case .ms: return "Bahasa Melayu"
            }
        }

        /// Viết từ phải sang trái.
        ///
        /// Năm thứ tiếng, và cả năm đều thuộc nhóm Trung Đông — nhưng liệt kê từng cái chứ
        /// không hỏi "có thuộc nhóm Trung Đông không", vì tiếng Thổ nằm cùng nhóm mà viết
        /// trái-sang-phải. Suy chiều viết từ vùng địa lý là sai ngay ở phần tử đầu tiên.
        var isRTL: Bool {
            switch self {
            case .ar, .he, .fa, .ur: return true
            default: return false
            }
        }

        /// Vùng, để bộ chọn gom nhóm.
        enum Region: String, CaseIterable {
            case auMy, trungDong, a

            var title: String {
                switch self {
                case .auMy: return L("Âu / Mỹ")
                case .trungDong: return L("Trung Đông")
                case .a: return L("Á")
                }
            }
        }

        var region: Region? {
            switch self {
            case .system, .vi: return nil
            case .en, .fr, .de, .es, .pt, .it, .nl, .pl, .sv, .da, .fi, .nb,
                 .cs, .el, .hu, .ro, .uk, .ru:
                return .auMy
            case .tr, .ar, .he, .fa, .ur: return .trungDong
            case .zhHans, .zhHant, .ja, .ko, .hi, .bn, .ta, .th, .id, .ms: return .a
            }
        }

        /// Những ngôn ngữ của một vùng, giữ đúng thứ tự khai báo ở `allCases`.
        static func inRegion(_ region: Region) -> [Language] {
            allCases.filter { $0.region == region }
        }
    }

    /// Ngôn ngữ đang dùng. Đổi giá trị này KHÔNG tự vẽ lại giao diện đã dựng.
    static var language: Language = .system

    /// Đã KHOÁ ngôn ngữ, cấu hình người dùng không ghi đè được.
    ///
    /// Chỉ bật ở chế độ `--self-test` và `--capture`. Không có nó thì `loadSettings()` chạy sau
    /// và đặt lại ngôn ngữ theo `settings.json`, nên menu dựng bằng một thứ tiếng còn panel
    /// dựng bằng thứ tiếng khác — và bài kiểm trượt vì lý do không liên quan gì tới thứ nó đo.
    private(set) static var isLocked = false

    static func lock(to language: Language) {
        self.language = language
        isLocked = true
    }

    /// Chạy `body` dưới một ngôn ngữ khác, rồi trả lại nguyên trạng.
    ///
    /// Đi vòng qua `isLocked` một cách CÓ CHỦ Ý, và chỉ bài tự kiểm gọi. Khoá ấy sinh ra để
    /// `loadSettings()` không đổi ngôn ngữ giữa chừng làm menu và panel lệch tiếng nhau; nó
    /// không sinh ra để cấm chính bài kiểm ngôn ngữ đổi ngôn ngữ.
    ///
    /// `defer` chứ không phải một dòng gán ở cuối: `body` có thể trả về sớm hoặc ném, và một
    /// bài kiểm bỏ quên tiếng Ả Rập cho toàn bộ phần còn lại của lượt chạy thì hai trăm bài sau
    /// nó đỏ hết — vì trạng thái của nó, không vì lỗi của chúng.
    static func withLanguageForSelfTest(_ temporary: Language, _ body: () -> Void) {
        let saved = language
        language = temporary
        defer { language = saved }
        body()
    }

    /// Ngôn ngữ thực sự áp dụng, sau khi giải `system`.
    ///
    /// Dò theo thứ tự ưu tiên của hệ điều hành và lấy thứ ĐẦU TIÊN ta có bảng dịch. Người đặt
    /// máy ưu tiên [Thái, Pháp] mà ta chưa có tiếng Thái thì họ nhận tiếng Pháp — thứ tiếng họ
    /// tự khai là biết — chứ không phải tiếng Việt vì ta bỏ cuộc ngay ở lựa chọn đầu.
    static var effective: Language {
        guard language == .system else { return language }
        for preferred in Locale.preferredLanguages {
            if let matched = match(preferred) { return matched }
        }
        return .vi
    }

    /// Ghép một thẻ ngôn ngữ của hệ điều hành vào bảng của ta.
    ///
    /// Hệ trả về những thẻ như `en-US`, `zh-Hans-CN`, `pt-BR`. So khớp phải theo BỘ PHẬN chứ
    /// không so bằng: khớp chính xác thì `en-US` trượt khỏi `en`, và người dùng Mỹ nhận giao
    /// diện tiếng Việt. Trung văn phải thử tiền tố DÀI trước, vì `zh-Hans-CN` cũng bắt đầu bằng
    /// `zh` và sẽ khớp nhầm bảng phồn thể nếu duyệt theo thứ tự khai báo.
    static func match(_ tag: String) -> Language? {
        let lower = tag.lowercased()
        if lower.hasPrefix("zh") {
            if lower.contains("hant") || lower.contains("tw") || lower.contains("hk")
                || lower.contains("mo") {
                return .zhHant
            }
            return .zhHans
        }
        // `nb`, `nn` và `no` đều là tiếng Na Uy; hệ có thể trả về bất kỳ cái nào.
        if lower.hasPrefix("nb") || lower.hasPrefix("nn") || lower.hasPrefix("no") { return .nb }
        guard let base = lower.split(separator: "-").first.map(String.init) else { return nil }
        return Language.allCases.first { candidate in
            candidate != .system && candidate.rawValue.lowercased() == base
        }
    }

    /// Bảng dịch của một ngôn ngữ. `nil` nghĩa là chưa có bảng — chuỗi rơi về tiếng Việt.
    ///
    /// Viết thành `switch` chứ không phải một `[Language: [String: String]]` dựng sẵn: từ điển
    /// ấy sẽ nạp cả ba mươi bảng vào bộ nhớ ngay lần chạm đầu tiên, trong khi một phiên chỉ
    /// dùng đúng MỘT. `static let` trong Swift nạp lười từng cái, nên `switch` chỉ chạm bảng
    /// đang cần — cùng lý do ADR-14 nạp lười DuckDB.
    static func table(for language: Language) -> [String: String]? {
        switch language {
        case .system, .vi: return nil
        case .en: return en
        case .fr: return fr
        case .es: return es
        case .de: return de
        case .pt: return pt
        case .it: return it
        case .ru: return ru
        case .ar: return ar
        case .zhHans: return zhHans
        case .ja: return ja
        case .ko: return ko
        case .zhHant: return zhHant
        case .nl: return nl
        case .he: return he
        case .fa: return fa
        case .tr: return tr
        case .pl: return pl
        case .ur: return ur
        case .uk: return uk
        case .cs: return cs
        case .sv: return sv
        case .da: return da
        case .nb: return nb
        case .fi: return fi
        case .el: return el
        case .hu: return hu
        case .ro: return ro
        case .id: return id
        case .ms: return ms
        case .th: return th
        case .hi: return hi
        case .bn: return bn
        case .ta: return ta
        default: return nil
        }
    }

    /// Dịch một chuỗi giao diện, có CHUỖI DỰ PHÒNG.
    ///
    /// Thứ tự: ngôn ngữ đang chọn → tiếng Anh → tiếng Việt.
    ///
    /// Nấc tiếng Anh ở giữa là thứ đáng bàn. Với hai ngôn ngữ thì "thiếu bản dịch → rơi về
    /// tiếng Việt" là đúng, vì chỉ có hai nấc. Với ba mươi bảng thì nó sai hẳn: một người Pháp
    /// gặp chuỗi chưa dịch sẽ nhận "Không mở được tệp" — thứ họ không đọc được — trong khi
    /// "Cannot open the file" thì phần lớn người dùng Pháp đọc được.
    ///
    /// Hệ quả thực tế: một bảng dịch xong 60% vẫn DÙNG ĐƯỢC, phần còn lại hiện tiếng Anh chứ
    /// không phải tiếng Việt. Nếu không có nấc này thì một bảng dở dang là một giao diện lai
    /// Pháp-Việt, tệ hơn cả để nguyên tiếng Anh.
    static func translate(_ vietnamese: String) -> String {
        let target = effective
        if let table = table(for: target), let hit = table[vietnamese] { return hit }
        if target != .vi, target != .en, let hit = en[vietnamese] { return hit }
        return vietnamese
    }

    // MARK: - Số nhiều

    /// Bung các nhóm số nhiều `{one=…|other=…}` trong một chuỗi định dạng.
    ///
    /// # Cú pháp
    ///
    ///     "Đã đánh dấu %d {one=dòng vi phạm|other=dòng vi phạm}"
    ///     "Đã gộp %1$d {one=nhóm|other=nhóm} · %2$d {one=ô|other=ô} đổi"
    ///
    /// Mỗi nhóm gắn với ô SỐ NGUYÊN gần nhất ĐỨNG TRƯỚC nó. Nhờ vậy một câu có hai con số vẫn
    /// chọn được hai dạng ĐỘC LẬP — đó là vế mà một bảng "mỗi khoá một biến thể" không làm nổi,
    /// vì tiếng Nga sẽ cần tới bốn nhân bốn biến thể cho một câu hai con số.
    ///
    /// # Vì sao phải có dấu `=` mới tính là nhóm số nhiều
    ///
    /// Vì `{…}` xuất hiện trong chuỗi thật: mấy câu về Mermaid có `%%{init}%%`. Không có luật
    /// "phải chứa `=`" thì `{init}` bị nuốt mất và chỉ thị Mermaid hỏng — một lỗi chỉ nổ ở đúng
    /// một tính năng, im lặng ở mọi chỗ khác. Thêm nữa `%%` là dấu phần trăm nguyên nghĩa chứ
    /// không phải ô số, nên nó cũng không bao giờ trở thành ô để gắn nhóm vào.
    ///
    /// Hạng không có nhánh tương ứng thì rơi về `other`; không có `other` thì trả nguyên văn
    /// nhánh đầu. Chuỗi không có nhóm nào thì trả về chính nó — nên hàm này an toàn để gọi trên
    /// MỌI chuỗi, kể cả những chuỗi chưa ai thêm dạng số nhiều.
    static func expandPlurals(_ format: String, _ args: [Any],
                              language: Language? = nil) -> String {
        guard format.contains("{") else { return format }
        let target = language ?? effective
        let chars = Array(format)
        var out = ""
        var i = 0
        // Chỉ số đối số của ô số nguyên gần nhất đã gặp, tính từ 0. `nil` = chưa gặp ô nào.
        var soGanNhat: Int?
        var thuTuNgam = 0

        while i < chars.count {
            if chars[i] == "%" {
                let (doDai, viTri, kieu) = Self.docODinhDang(chars, from: i)
                out += String(chars[i..<(i + doDai)])
                if let kieu, "diu".contains(kieu) {
                    // Ô đánh số dùng vị trí đã ghi; ô không đánh số đếm theo thứ tự xuất hiện.
                    soGanNhat = (viTri ?? { thuTuNgam += 1; return thuTuNgam }()) - 1
                } else if kieu != nil {
                    if viTri == nil { thuTuNgam += 1 }
                }
                i += doDai
                continue
            }
            if chars[i] == "{", let dong = Self.timDauDong(chars, from: i),
               let nhanh = Self.tachNhanh(String(chars[(i + 1)..<dong])) {
                let n = soGanNhat.flatMap { $0 < args.count ? args[$0] as? Int : nil }
                out += Self.chonNhanh(nhanh, n: n, language: target)
                i = dong + 1
                continue
            }
            out.append(chars[i])
            i += 1
        }
        return out
    }

    /// Số nhóm số nhiều KHÔNG có ô số nguyên nào đứng trước để bám vào.
    ///
    /// Kiểu hỏng này không lộ ra ở cú pháp: nhóm viết đúng, tên hạng đúng, chỉ là không con số
    /// nào chi phối nó — nên `chonNhanh` luôn rơi về `other`. Trên màn hình vẫn ra chữ, chỉ là
    /// LUÔN LUÔN dạng số nhiều, kể cả khi đếm được đúng một. Tức là đúng cái lỗi mà cả cơ chế
    /// này sinh ra để chữa, và nó lặng lẽ quay lại.
    ///
    /// Gặp thật khi viết bảng tiếng Đức: `" (bei {one=dem ersten Problem|other=den ersten %d
    /// Problemen} gestoppt)"` — ô `%d` bị đẩy vào TRONG nhánh, nên phía trước nhóm không còn ô
    /// nào.
    static func nhomKhongCoOSo(_ format: String) -> Int {
        guard format.contains("{") else { return 0 }
        let chars = Array(format)
        var i = 0
        var daGapOSo = false
        var thieu = 0
        while i < chars.count {
            if chars[i] == "%" {
                let (doDai, _, kieu) = docODinhDang(chars, from: i)
                if let kieu, "diu".contains(kieu) { daGapOSo = true }
                i += doDai
                continue
            }
            if chars[i] == "{", let dong = timDauDong(chars, from: i),
               tachNhanh(String(chars[(i + 1)..<dong])) != nil {
                if !daGapOSo { thieu += 1 }
                i = dong + 1
                continue
            }
            i += 1
        }
        return thieu
    }

    /// Đọc một ô định dạng bắt đầu ở `start`. Trả về (độ dài, vị trí tham số nếu có đánh số,
    /// ký tự chuyển đổi). Ký tự chuyển đổi `nil` nghĩa là `%%` hoặc một ô không đọc được.
    ///
    /// Cùng luật với `scripts/gen-language.py`: tiền tố đánh số đọc TRƯỚC cờ, và `%` đứng trước
    /// thứ không phải ký tự chuyển đổi thật là dấu phần trăm nguyên nghĩa.
    private static func docODinhDang(_ chars: [Character],
                                     from start: Int) -> (Int, Int?, Character?) {
        var j = start + 1
        guard j < chars.count else { return (1, nil, nil) }
        if chars[j] == "%" { return (2, nil, nil) }
        var so = ""
        var k = j
        while k < chars.count, chars[k].isNumber { so.append(chars[k]); k += 1 }
        var viTri: Int?
        if k < chars.count, chars[k] == "$", !so.isEmpty {
            viTri = Int(so)
            j = k + 1
        }
        while j < chars.count, "0123456789.-+#'".contains(chars[j]) { j += 1 }
        while j < chars.count, "lhzjt".contains(chars[j]) { j += 1 }
        guard j < chars.count, "diouxXeEfgGaAcsp@".contains(chars[j]) else {
            return (1, nil, nil)
        }
        return (j - start + 1, viTri, chars[j])
    }

    /// Vị trí dấu `}` đóng nhóm bắt đầu ở `start`, hoặc `nil` nếu không có.
    private static func timDauDong(_ chars: [Character], from start: Int) -> Int? {
        var j = start + 1
        while j < chars.count {
            if chars[j] == "}" { return j }
            if chars[j] == "{" { return nil }   // lồng nhau thì không phải nhóm số nhiều
            j += 1
        }
        return nil
    }

    /// Tách "one=dòng|other=dòng" thành các nhánh. `nil` nếu không có nhánh nào hợp lệ —
    /// đó là dấu hiệu `{…}` này KHÔNG phải nhóm số nhiều mà là chữ thật.
    private static func tachNhanh(_ than: String) -> [Plural.Category: String]? {
        var ra: [Plural.Category: String] = [:]
        for phan in than.components(separatedBy: "|") {
            guard let dau = phan.firstIndex(of: "=") else { return nil }
            guard let hang = Plural.Category(rawValue: String(phan[phan.startIndex..<dau])) else {
                return nil
            }
            ra[hang] = String(phan[phan.index(after: dau)...])
        }
        return ra.isEmpty ? nil : ra
    }

    private static func chonNhanh(_ nhanh: [Plural.Category: String], n: Int?,
                                  language: Language) -> String {
        // Không tìm được con số cho ô này (chuỗi khai sai, hoặc đối số không phải Int) thì
        // dùng `other` — dạng dùng được với nhiều con số nhất ở mọi thứ tiếng.
        let hang = n.map { Plural.category($0, language) } ?? .other
        if let hit = nhanh[hang] { return hit }
        if let hit = nhanh[.other] { return hit }
        return nhanh.values.first ?? ""
    }

    /// Độ phủ bản dịch của từng ngôn ngữ, trên một danh sách chuỗi cho trước.
    ///
    /// Trả về số ĐÃ dịch và tổng, để bài tự kiểm in ra bảng tiến độ. Có mặt vì với ba mươi bảng
    /// thì "còn thiếu bao nhiêu" không còn nhìn bằng mắt được, và một bảng tụt lại sẽ nằm im
    /// mãi nếu không ai đếm.
    static func coverage(of language: Language, among strings: [String]) -> (done: Int, total: Int) {
        let keys = strings.filter { !$0.isEmpty }
        guard let table = table(for: language) else { return (0, keys.count) }
        return (keys.filter { table[$0] != nil }.count, keys.count)
    }

    /// Những chuỗi tiếng Việt CHƯA có bản dịch, trong một danh sách cho trước.
    ///
    /// Bài tự kiểm dùng hàm này để đếm phần còn nợ CỦA TỪNG NGÔN NGỮ. Che đi thì phần chưa dịch
    /// nằm im ở đó mãi, và không ai biết còn thiếu bao nhiêu — với ba mươi bảng thì đó không
    /// còn là chuyện nhỏ như hồi chỉ có một.
    static func untranslated(among strings: [String], in language: Language = .en) -> [String] {
        guard let table = table(for: language) else { return [] }
        return strings.filter { !$0.isEmpty && table[$0] == nil }
    }

}

/// Viết tắt của `L10n.translate`.
///
/// Một chữ cái, vì nó sẽ bọc quanh gần như mọi chuỗi giao diện của sản phẩm. Tên dài hơn sẽ làm
/// mỗi dòng nhãn dài thêm chục ký tự và đẩy chúng xuống hai dòng — thứ khiến người ta ngại bọc,
/// và chuỗi không bọc là chuỗi không dịch được.
func L(_ vietnamese: String) -> String { L10n.translate(vietnamese) }

/// Dịch, chọn dạng số nhiều, rồi ghép đối số — thay cho `String(format: L(…), …)`.
///
/// # Vì sao phải là MỘT hàm chứ không phải hai bước
///
/// Phép chọn dạng số nhiều cần cả chuỗi định dạng LẪN giá trị các đối số. `String(format:)`
/// nhận `CVarArg`, một giao thức không cho đọc lại giá trị — nên không thể xen vào giữa hai
/// bước. Gộp lại thành một chỗ gọi vừa giải được vế ấy, vừa làm mỗi chỗ đếm chỉ còn một dòng.
///
/// Chuỗi không khai dạng số nhiều nào thì `LF` chạy y hệt `String(format: L(…), …)`, nên đổi
/// chỗ gọi sang `LF` là an toàn kể cả trước khi thêm dạng số nhiều vào bảng dịch.
func LF(_ vietnamese: String, _ args: Any...) -> String {
    let mau = L10n.expandPlurals(L10n.translate(vietnamese), args)
    return String(format: mau, arguments: args.map(L10n.asCVarArg))
}

extension L10n {
    /// Ép `Any` về `CVarArg` cho `String(format:arguments:)`.
    ///
    /// Nhánh cuối trả về mô tả chuỗi thay vì làm sập: một đối số kiểu lạ lọt vào là lỗi lúc
    /// viết mã, và một thông báo lỗi hiện ra hơi xấu vẫn hơn một ứng dụng tắt ngang.
    static func asCVarArg(_ value: Any) -> CVarArg {
        if let x = value as? CVarArg { return x }
        return String(describing: value)
    }
}

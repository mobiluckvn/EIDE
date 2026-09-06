import Foundation

/// Chọn dạng số nhiều theo NGÔN NGỮ và theo CON SỐ.
///
/// # Vì sao cần
///
/// Bản đầu của mọi chuỗi đếm dùng MỘT dạng cho mọi con số: "Đã đánh dấu %d dòng vi phạm" →
/// tiếng Anh "Marked %d violating lines". Với %d = 1 nó ra "Marked 1 violating lines". Tiếng
/// Anh là bản rơi về của cả ba mươi ba thứ tiếng, nên lỗi ấy hiện ra ở MỌI ngôn ngữ chưa dịch
/// xong chứ không riêng tiếng Anh.
///
/// Với tiếng Nga, tiếng Ba Lan thì nặng hơn: chúng có ba dạng theo con số (1 · 2–4 · 5+), và
/// một dạng dùng chung tuy không bao giờ sai ngữ pháp nhưng đọc như văn máy ở khoảng 2–4.
///
/// # Vì sao tự viết chứ không dùng `NSLocalizedString` + stringsdict
///
/// Bảng dịch của sản phẩm này là dictionary Swift trong mã, không phải bundle `.strings` — xem
/// `Localization.swift`. Đổi sang stringsdict là đổi cả kiến trúc dịch, và stringsdict cũng
/// KHÔNG giải được vế khó nhất ở đây: một câu có HAI con số ("Đã gộp %d nhóm · %d ô đổi") cần
/// hai phép chọn ĐỘC LẬP trong cùng một chuỗi. stringsdict làm được nhưng cồng kềnh; cú pháp
/// nội tuyến ở `L10n.expandPlurals` làm được gọn hơn và nằm cùng chỗ với bảng dịch.
///
/// # Chỉ dành cho SỐ NGUYÊN
///
/// Mọi con số đếm trong sản phẩm đều là số nguyên (số dòng, số ô, số tệp). Luật CLDR còn phân
/// biệt theo phần thập phân và theo số chữ số sau dấu phẩy; ở đây không cần, và viết thêm phần
/// ấy là viết mã không ai chạy tới.
enum Plural {

    /// Hạng số nhiều theo CLDR. Tên giữ nguyên tiếng Anh vì chúng là khoá ghi thẳng trong bảng
    /// dịch — dịch tên hạng ra tiếng Việt sẽ làm mỗi bảng dịch phải dùng một khoá khác nhau.
    enum Category: String {
        case zero, one, two, few, many, other
    }

    /// Hạng của `n` trong `language`.
    ///
    /// Luật lấy từ CLDR. Chỗ dễ sai nhất là tiếng Nga và tiếng Ukraina: điều kiện KHÔNG phải
    /// "n = 1" mà là "n chia 10 dư 1 VÀ n chia 100 khác 11" — nên 21 và 101 là dạng "one" còn
    /// 11 thì không. Viết thành `n == 1` sẽ đúng ở mọi giá trị nhỏ mà bài kiểm hay thử, rồi sai
    /// ở 21.
    static func category(_ n: Int, _ language: L10n.Language) -> Category {
        let n = abs(n)
        let mod10 = n % 10
        let mod100 = n % 100

        switch language {
        // Không phân biệt số ít/số nhiều: danh từ giữ nguyên dạng sau mọi con số.
        case .vi, .ja, .ko, .zhHans, .zhHant, .th, .id, .ms:
            return .other

        // "one" khi n = 1, còn lại "other".
        case .en, .de, .nl, .sv, .da, .nb, .fi, .it, .es, .el, .ta, .ur, .tr, .hu:
            return n == 1 ? .one : .other

        // "one" khi n = 0 hoặc 1 — khác nhóm trên đúng ở con số 0.
        case .pt, .hi, .bn, .fa:
            return (n == 0 || n == 1) ? .one : .other

        // Tiếng Do Thái: có thêm dạng ĐÔI cho đúng hai đơn vị.
        case .he:
            if n == 1 { return .one }
            if n == 2 { return .two }
            return .other

        // Tiếng Nga · Ukraina: 1/21/31… · 2–4/22–24… · còn lại.
        case .ru, .uk:
            if mod10 == 1 && mod100 != 11 { return .one }
            if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
            return .many

        // Tiếng Ba Lan: "one" CHỈ đúng ở n = 1 — 21 thuộc dạng "many", khác hẳn tiếng Nga.
        case .pl:
            if n == 1 { return .one }
            if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
            return .many

        // Tiếng Séc: 2–4 là "few" theo giá trị THẬT, không theo hàng đơn vị — 22 là "other".
        case .cs:
            if n == 1 { return .one }
            if (2...4).contains(n) { return .few }
            return .other

        // Tiếng Rumani: "few" gồm cả số 0 và mọi số có hai chữ số cuối trong 1–19.
        case .ro:
            if n == 1 { return .one }
            if n == 0 || (1...19).contains(mod100) { return .few }
            return .other

        // Tiếng Pháp: 0 và 1 cùng dạng "one"; ngoài ra CLDR còn hạng "many" cho hàng triệu,
        // không dùng tới ở đây vì không có con số đếm nào của sản phẩm lớn đến thế.
        case .fr:
            return (n == 0 || n == 1) ? .one : .other

        // Tiếng Ả Rập: sáu hạng, và là thứ tiếng duy nhất trong bộ dùng cả `zero` lẫn `two`.
        case .ar:
            if n == 0 { return .zero }
            if n == 1 { return .one }
            if n == 2 { return .two }
            if (3...10).contains(mod100) { return .few }
            if (11...99).contains(mod100) { return .many }
            return .other

        // `.system` không bao giờ tới đây: `L10n.effective` đã giải nó thành ngôn ngữ thật.
        case .system:
            return n == 1 ? .one : .other
        }
    }
}

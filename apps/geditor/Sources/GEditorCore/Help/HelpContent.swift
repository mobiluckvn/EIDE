import Foundation

/// Nơi ráp sách trợ giúp cho từng ngôn ngữ.
///
/// **Tiếng Việt là bản NGUỒN.** Cùng nguyên tắc với `L10n`: khoá dịch chính là chữ tiếng Việt,
/// nên bản tiếng Việt không bao giờ thiếu trang và không bao giờ thiếu câu. Ngôn ngữ chưa dịch
/// thì rơi về nó — tức rơi về ĐÚNG hành vi hôm nay, không có trạng thái trung gian nào tệ hơn.
///
/// **Không rơi về từng trang một.** Một cuốn sách nửa tiếng Đức nửa tiếng Việt đọc còn khó hơn
/// một cuốn thuần tiếng Việt: người đọc mất phương hướng giữa chương, và mục lục thì lẫn hai thứ
/// tiếng. Nên đơn vị rơi là CẢ SÁCH. Khi một ngôn ngữ dịch xong thì nó hiện trọn vẹn, còn trong
/// lúc chưa xong thì cửa sổ trợ giúp nói thẳng "bản dịch chưa có, đang hiện tiếng Việt".
public enum HelpContent {

    /// Mã ngôn ngữ đã có sách. Ngôn ngữ nào chưa dịch thì KHÔNG có mặt ở đây, và cửa sổ trợ
    /// giúp không mời người dùng chọn một thứ tiếng rồi hiện ra tiếng khác.
    public static let translatedLanguages: Set<String> = ["vi", "en", "zh-Hans", "fr", "de", "es", "pt", "it", "nl", "pl", "sv", "da", "fi", "nb", "cs", "el", "hu", "ro", "uk", "ru", "tr", "ar", "he", "fa"]

    /// Sách cho ngôn ngữ giao diện đang dùng.
    ///
    /// `language` nhận mã BCP-47 của `L10n.Language` (`"vi"`, `"en"`, `"zh-Hans"`…).
    public static func book(language: String) -> HelpBook {
        switch language {
        case "vi": return vietnamese
        case "en": return english
        case "zh-Hans": return simplifiedChinese
        case "fr": return french
        case "de": return german
        case "es": return spanish
        case "pt": return portuguese
        case "it": return italian
        case "nl": return dutch
        case "pl": return polish
        case "sv": return swedish
        case "da": return danish
        case "fi": return finnish
        case "nb": return norwegian
        case "cs": return czech
        case "el": return greek
        case "hu": return hungarian
        case "ro": return romanian
        case "uk": return ukrainian
        case "ru": return russian
        case "tr": return turkish
        case "ar": return arabic
        case "he": return hebrew
        case "fa": return persian
        // Ngôn ngữ chưa có sách rơi về **tiếng Anh**, không rơi về tiếng Việt.
        //
        // Bản gốc là tiếng Việt, nên rơi về nó là lựa chọn tự nhiên của người viết mã — và là
        // lựa chọn vô dụng với người đọc: một người dùng giao diện tiếng Đức mở trợ giúp ra và
        // thấy 107 trang tiếng Việt thì không đọc được một câu nào. Tiếng Anh thì phần lớn họ
        // đọc được, và đó là điều duy nhất đáng cân nhắc ở đây.
        default: return english
        }
    }

    /// Bản dịch của `language` đã có chưa. Cửa sổ trợ giúp nói ra khi chưa.
    public static func isTranslated(_ language: String) -> Bool {
        translatedLanguages.contains(language)
    }

    /// Tên ngôn ngữ **viết bằng chính ngôn ngữ ấy** — cho popup chọn ngôn ngữ của sách.
    ///
    /// Không dịch tên ngôn ngữ sang thứ tiếng đang hiện: một người đọc tiếng Anh tìm mục
    /// «tiếng Việt» sẽ không nhận ra nó nếu ta ghi «Vietnamese» khi giao diện đang là tiếng
    /// Việt và ghi «Tiếng Việt» khi giao diện là tiếng Anh. Mỗi ngôn ngữ tự xưng tên mình là
    /// cách duy nhất đọc được ở mọi phía — cùng lối các trình duyệt và hệ điều hành làm.
    public static func languageName(_ code: String) -> String {
        switch code {
        case "vi": return "Tiếng Việt"
        case "en": return "English"
        case "zh-Hans": return "简体中文"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "es": return "Español"
        case "pt": return "Português"
        case "it": return "Italiano"
        case "nl": return "Nederlands"
        case "pl": return "Polski"
        case "sv": return "Svenska"
        case "da": return "Dansk"
        case "fi": return "Suomi"
        case "nb": return "Norsk bokmål"
        case "cs": return "Čeština"
        case "el": return "Ελληνικά"
        case "hu": return "Magyar"
        case "ro": return "Română"
        case "uk": return "Українська"
        case "ru": return "Русский"
        case "tr": return "Türkçe"
        case "ar": return "العربية"
        case "he": return "עברית"
        case "fa": return "فارسی"
        default: return code
        }
    }

    /// Trang mở ra khi bấm "Trợ giúp GEditor" và khi app chào lần đầu.
    public static let entryTopicID = "gioi-thieu"

    /// Thứ tự chương là thứ tự MỤC LỤC, và nó sắp theo lối người dùng đi tới chứ không theo lối
    /// mã nguồn chia tầng: bắt đầu → soạn thảo → tìm → tệp → cách nhìn → tiếng Việt → định dạng
    /// → dữ liệu → hai quy trình lớn → kết xuất → tự động hoá → cấu hình.
    public static let vietnamese = HelpBook(language: "vi", chapters: [
        HelpVI.batDau,
        HelpVI.soanThao,
        HelpVI.timKiem,
        HelpVI.tep,
        HelpVI.xem,
        HelpVI.tiengViet,
        HelpVI.ngonNgu,
        HelpVI.csv,
        HelpVI.lamSach,
        HelpVI.khaiPha,
        HelpVI.baoCao,
        HelpVI.triThuc,
        HelpVI.tuDongHoa,
        HelpVI.ungDung,
    ])

    /// Bản tiếng Anh — **cùng thứ tự chương và cùng mã trang** với bản tiếng Việt.
    ///
    /// Hai điều ấy bắt buộc, không phải cho gọn: mã trang là thứ `.seeAlso` trỏ tới và là thứ
    /// cửa sổ trợ giúp dùng để **giữ nguyên trang đang đọc khi đổi ngôn ngữ**. Một cuốn có mã
    /// khác là một cuốn mà mọi liên kết chéo gãy và mỗi lần đổi tiếng lại ném người đọc về mục
    /// lục — xem `HelpWindowController.showBook(language:)`.
    public static let english = HelpBook(language: "en", chapters: [
        HelpEN.gettingStarted,
        HelpEN.editing,
        HelpEN.search,
        HelpEN.files,
        HelpEN.views,
        HelpEN.vietnamese,
        HelpEN.languages,
        HelpEN.tabularData,
        HelpEN.cleaning,
        HelpEN.mining,
        HelpEN.reports,
        HelpEN.knowledge,
        HelpEN.automation,
        HelpEN.application,
    ])

    /// Bản tiếng Trung giản thể — cùng thứ tự chương và cùng mã trang.
    public static let simplifiedChinese = HelpBook(language: "zh-Hans", chapters: [
        HelpZhHans.gettingStarted,
        HelpZhHans.editing,
        HelpZhHans.search,
        HelpZhHans.files,
        HelpZhHans.views,
        HelpZhHans.vietnamese,
        HelpZhHans.languages,
        HelpZhHans.tabularData,
        HelpZhHans.cleaning,
        HelpZhHans.mining,
        HelpZhHans.reports,
        HelpZhHans.knowledge,
        HelpZhHans.automation,
        HelpZhHans.application,
    ])

    /// Bản tiếng Pháp — cùng thứ tự chương và cùng mã trang.
    public static let french = HelpBook(language: "fr", chapters: [
        HelpFR.gettingStarted,
        HelpFR.editing,
        HelpFR.search,
        HelpFR.files,
        HelpFR.views,
        HelpFR.vietnamese,
        HelpFR.languages,
        HelpFR.tabularData,
        HelpFR.cleaning,
        HelpFR.mining,
        HelpFR.reports,
        HelpFR.knowledge,
        HelpFR.automation,
        HelpFR.application,
    ])

    /// Bản tiếng Đức — cùng thứ tự chương và cùng mã trang.
    public static let german = HelpBook(language: "de", chapters: [
        HelpDE.gettingStarted,
        HelpDE.editing,
        HelpDE.search,
        HelpDE.files,
        HelpDE.views,
        HelpDE.vietnamese,
        HelpDE.languages,
        HelpDE.tabularData,
        HelpDE.cleaning,
        HelpDE.mining,
        HelpDE.reports,
        HelpDE.knowledge,
        HelpDE.automation,
        HelpDE.application,
    ])

    /// Bản tiếng Tây Ban Nha — cùng thứ tự chương và cùng mã trang.
    public static let spanish = HelpBook(language: "es", chapters: [
        HelpES.gettingStarted,
        HelpES.editing,
        HelpES.search,
        HelpES.files,
        HelpES.views,
        HelpES.vietnamese,
        HelpES.languages,
        HelpES.tabularData,
        HelpES.cleaning,
        HelpES.mining,
        HelpES.reports,
        HelpES.knowledge,
        HelpES.automation,
        HelpES.application,
    ])

    /// Bản tiếng Bồ Đào Nha — cùng thứ tự chương và cùng mã trang.
    public static let portuguese = HelpBook(language: "pt", chapters: [
        HelpPT.gettingStarted,
        HelpPT.editing,
        HelpPT.search,
        HelpPT.files,
        HelpPT.views,
        HelpPT.vietnamese,
        HelpPT.languages,
        HelpPT.tabularData,
        HelpPT.cleaning,
        HelpPT.mining,
        HelpPT.reports,
        HelpPT.knowledge,
        HelpPT.automation,
        HelpPT.application,
    ])

    /// Bản tiếng Ý — cùng thứ tự chương và cùng mã trang.
    public static let italian = HelpBook(language: "it", chapters: [
        HelpIT.gettingStarted,
        HelpIT.editing,
        HelpIT.search,
        HelpIT.files,
        HelpIT.views,
        HelpIT.vietnamese,
        HelpIT.languages,
        HelpIT.tabularData,
        HelpIT.cleaning,
        HelpIT.mining,
        HelpIT.reports,
        HelpIT.knowledge,
        HelpIT.automation,
        HelpIT.application,
    ])

    /// Bản tiếng Hà Lan — cùng thứ tự chương và cùng mã trang.
    public static let dutch = HelpBook(language: "nl", chapters: [
        HelpNL.gettingStarted,
        HelpNL.editing,
        HelpNL.search,
        HelpNL.files,
        HelpNL.views,
        HelpNL.vietnamese,
        HelpNL.languages,
        HelpNL.tabularData,
        HelpNL.cleaning,
        HelpNL.mining,
        HelpNL.reports,
        HelpNL.knowledge,
        HelpNL.automation,
        HelpNL.application,
    ])

    /// Bản tiếng Ba Lan — cùng thứ tự chương và cùng mã trang.
    public static let polish = HelpBook(language: "pl", chapters: [
        HelpPL.gettingStarted,
        HelpPL.editing,
        HelpPL.search,
        HelpPL.files,
        HelpPL.views,
        HelpPL.vietnamese,
        HelpPL.languages,
        HelpPL.tabularData,
        HelpPL.cleaning,
        HelpPL.mining,
        HelpPL.reports,
        HelpPL.knowledge,
        HelpPL.automation,
        HelpPL.application,
    ])

    /// Bản tiếng Thụy Điển — cùng thứ tự chương và cùng mã trang.
    public static let swedish = HelpBook(language: "sv", chapters: [
        HelpSV.gettingStarted,
        HelpSV.editing,
        HelpSV.search,
        HelpSV.files,
        HelpSV.views,
        HelpSV.vietnamese,
        HelpSV.languages,
        HelpSV.tabularData,
        HelpSV.cleaning,
        HelpSV.mining,
        HelpSV.reports,
        HelpSV.knowledge,
        HelpSV.automation,
        HelpSV.application,
    ])

    /// Bản tiếng Đan Mạch — cùng thứ tự chương và cùng mã trang.
    public static let danish = HelpBook(language: "da", chapters: [
        HelpDA.gettingStarted,
        HelpDA.editing,
        HelpDA.search,
        HelpDA.files,
        HelpDA.views,
        HelpDA.vietnamese,
        HelpDA.languages,
        HelpDA.tabularData,
        HelpDA.cleaning,
        HelpDA.mining,
        HelpDA.reports,
        HelpDA.knowledge,
        HelpDA.automation,
        HelpDA.application,
    ])

    /// Bản tiếng Phần Lan — cùng thứ tự chương và cùng mã trang.
    public static let finnish = HelpBook(language: "fi", chapters: [
        HelpFI.gettingStarted,
        HelpFI.editing,
        HelpFI.search,
        HelpFI.files,
        HelpFI.views,
        HelpFI.vietnamese,
        HelpFI.languages,
        HelpFI.tabularData,
        HelpFI.cleaning,
        HelpFI.mining,
        HelpFI.reports,
        HelpFI.knowledge,
        HelpFI.automation,
        HelpFI.application,
    ])

    /// Bản tiếng Na Uy — cùng thứ tự chương và cùng mã trang.
    public static let norwegian = HelpBook(language: "nb", chapters: [
        HelpNB.gettingStarted,
        HelpNB.editing,
        HelpNB.search,
        HelpNB.files,
        HelpNB.views,
        HelpNB.vietnamese,
        HelpNB.languages,
        HelpNB.tabularData,
        HelpNB.cleaning,
        HelpNB.mining,
        HelpNB.reports,
        HelpNB.knowledge,
        HelpNB.automation,
        HelpNB.application,
    ])

    /// Bản tiếng Séc — cùng thứ tự chương và cùng mã trang.
    public static let czech = HelpBook(language: "cs", chapters: [
        HelpCS.gettingStarted,
        HelpCS.editing,
        HelpCS.search,
        HelpCS.files,
        HelpCS.views,
        HelpCS.vietnamese,
        HelpCS.languages,
        HelpCS.tabularData,
        HelpCS.cleaning,
        HelpCS.mining,
        HelpCS.reports,
        HelpCS.knowledge,
        HelpCS.automation,
        HelpCS.application,
    ])

    /// Bản tiếng Hy Lạp — cùng thứ tự chương và cùng mã trang.
    public static let greek = HelpBook(language: "el", chapters: [
        HelpEL.gettingStarted,
        HelpEL.editing,
        HelpEL.search,
        HelpEL.files,
        HelpEL.views,
        HelpEL.vietnamese,
        HelpEL.languages,
        HelpEL.tabularData,
        HelpEL.cleaning,
        HelpEL.mining,
        HelpEL.reports,
        HelpEL.knowledge,
        HelpEL.automation,
        HelpEL.application,
    ])

    /// Bản tiếng Hungary — cùng thứ tự chương và cùng mã trang.
    public static let hungarian = HelpBook(language: "hu", chapters: [
        HelpHU.gettingStarted,
        HelpHU.editing,
        HelpHU.search,
        HelpHU.files,
        HelpHU.views,
        HelpHU.vietnamese,
        HelpHU.languages,
        HelpHU.tabularData,
        HelpHU.cleaning,
        HelpHU.mining,
        HelpHU.reports,
        HelpHU.knowledge,
        HelpHU.automation,
        HelpHU.application,
    ])

    /// Bản tiếng Rumani — cùng thứ tự chương và cùng mã trang.
    public static let romanian = HelpBook(language: "ro", chapters: [
        HelpRO.gettingStarted,
        HelpRO.editing,
        HelpRO.search,
        HelpRO.files,
        HelpRO.views,
        HelpRO.vietnamese,
        HelpRO.languages,
        HelpRO.tabularData,
        HelpRO.cleaning,
        HelpRO.mining,
        HelpRO.reports,
        HelpRO.knowledge,
        HelpRO.automation,
        HelpRO.application,
    ])

    /// Bản tiếng Ukraina — cùng thứ tự chương và cùng mã trang.
    public static let ukrainian = HelpBook(language: "uk", chapters: [
        HelpUK.gettingStarted,
        HelpUK.editing,
        HelpUK.search,
        HelpUK.files,
        HelpUK.views,
        HelpUK.vietnamese,
        HelpUK.languages,
        HelpUK.tabularData,
        HelpUK.cleaning,
        HelpUK.mining,
        HelpUK.reports,
        HelpUK.knowledge,
        HelpUK.automation,
        HelpUK.application,
    ])

    /// Bản tiếng Nga — cùng thứ tự chương và cùng mã trang.
    public static let russian = HelpBook(language: "ru", chapters: [
        HelpRU.gettingStarted,
        HelpRU.editing,
        HelpRU.search,
        HelpRU.files,
        HelpRU.views,
        HelpRU.vietnamese,
        HelpRU.languages,
        HelpRU.tabularData,
        HelpRU.cleaning,
        HelpRU.mining,
        HelpRU.reports,
        HelpRU.knowledge,
        HelpRU.automation,
        HelpRU.application,
    ])

    /// Bản tiếng Thổ Nhĩ Kỳ — cùng thứ tự chương và cùng mã trang.
    public static let turkish = HelpBook(language: "tr", chapters: [
        HelpTR.gettingStarted,
        HelpTR.editing,
        HelpTR.search,
        HelpTR.files,
        HelpTR.views,
        HelpTR.vietnamese,
        HelpTR.languages,
        HelpTR.tabularData,
        HelpTR.cleaning,
        HelpTR.mining,
        HelpTR.reports,
        HelpTR.knowledge,
        HelpTR.automation,
        HelpTR.application,
    ])

    /// Bản tiếng Ả Rập — cùng thứ tự chương và cùng mã trang.
    public static let arabic = HelpBook(language: "ar", chapters: [
        HelpAR.gettingStarted,
        HelpAR.editing,
        HelpAR.search,
        HelpAR.files,
        HelpAR.views,
        HelpAR.vietnamese,
        HelpAR.languages,
        HelpAR.tabularData,
        HelpAR.cleaning,
        HelpAR.mining,
        HelpAR.reports,
        HelpAR.knowledge,
        HelpAR.automation,
        HelpAR.application,
    ])

    /// Bản tiếng Hebrew — cùng thứ tự chương và cùng mã trang.
    public static let hebrew = HelpBook(language: "he", chapters: [
        HelpHE.gettingStarted,
        HelpHE.editing,
        HelpHE.search,
        HelpHE.files,
        HelpHE.views,
        HelpHE.vietnamese,
        HelpHE.languages,
        HelpHE.tabularData,
        HelpHE.cleaning,
        HelpHE.mining,
        HelpHE.reports,
        HelpHE.knowledge,
        HelpHE.automation,
        HelpHE.application,
    ])

    /// Bản tiếng Ba Tư — cùng thứ tự chương và cùng mã trang.
    public static let persian = HelpBook(language: "fa", chapters: [
        HelpFA.gettingStarted,
        HelpFA.editing,
        HelpFA.search,
        HelpFA.files,
        HelpFA.views,
        HelpFA.vietnamese,
        HelpFA.languages,
        HelpFA.tabularData,
        HelpFA.cleaning,
        HelpFA.mining,
        HelpFA.reports,
        HelpFA.knowledge,
        HelpFA.automation,
        HelpFA.application,
    ])
}

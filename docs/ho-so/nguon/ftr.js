// EIDE-FTR-30 — Mô tả tính năng sản phẩm, bản gửi chuyên gia duyệt.
//
// Khác mọi tài liệu còn lại của bộ hồ sơ ở một điểm: các tài liệu kia mô tả thứ SẼ làm, tài
// liệu này mô tả thứ ĐANG CHẠY. Vì vậy mọi con số ở đây đo lúc sinh tài liệu (`gen_ftr_data.py`
// đọc registry) và mọi ảnh là ảnh chụp từ cửa sổ thật trong một vòng chạy có nhật ký, không
// phải mockup. Sinh lại tài liệu là cập nhật lại toàn bộ số liệu.
const fs = require('fs');
const { P, H1, H2, H3, SP, PB, T, KV, IMG, CODE, build } = require('./eaa_doc');
const { metaNew, refParas, CAPS, NS_ORDER, NS_VI } = require('./eide_common');

const DO = JSON.parse(fs.readFileSync(__dirname + '/trang_thai.json', 'utf8'));
const MAN = JSON.parse(fs.readFileSync(__dirname + '/screens.json', 'utf8'));
const xong = n => CAPS.filter(c => c.ns === n && DO.caps[c.name]).length;
const TONG = CAPS.filter(c => DO.caps[c.name]).length;
const anhCo = t => DO.co[t] || [1400, 838];
// Bề ngang in vừa lề tài liệu; cao tính theo tỉ lệ thật để ảnh không bị bóp.
const ANH = (t, chu) => {
  if (!DO.anh.includes(t)) return [];
  const [w, h] = anhCo(t);
  return IMG(__dirname + '/anh/' + t, 600, Math.round(600 * h / w), chu);
};

const m = metaNew('EIDE-FTR-30', 'Mô tả tính năng',
  'MÔ TẢ TÍNH NĂNG SẢN PHẨM EIDE (FTR)',
  'Toàn bộ tính năng của EIDE nhìn từ người dùng: một vòng làm việc thật, 27 nhóm năng lực, '
  + '26 màn hình kèm ảnh chụp từ bản chạy được, mô hình tự chủ và chính sách, ranh giới an toàn, '
  + 'phần chưa làm được và lý do — bản gửi chuyên gia duyệt',
  [['Tài liệu trước', 'EIDE-PDA-00 (sản phẩm), EIDE-UXD-13 (giao diện), EIDE-CDS-12.1…12.6 (hợp đồng năng lực), EIDE-APD-08 (tự chủ), EIDE-POL-17 (chính sách), EIDE-SEC-25 (an toàn)'],
   ['Nguồn số liệu', 'Đo lúc sinh tài liệu: registry năng lực (`gen_ftr_data.py`), `docs/spec/ui/screens.json`, `docs/spec/caps.json`. Ảnh: vòng chạy `--vong-giao-dien` ngày 17/09/2026 trên dự án AVR có firmware thật'],
   ['Dùng khi', 'Người ngoài nhóm phát triển cần hiểu sản phẩm làm được gì; phản biện đề án; nghiệm thu tính năng']],
  'Phát hành lần đầu — mô tả TRẠNG THÁI ĐANG CHẠY, không phải thiết kế dự kiến');
// `metaNew` mặc định ngày lập 05/09/2026 — ngày phát hành cả bộ hồ sơ v1.2. Tài liệu này soạn
// sau, và ngày sai trên bìa là thứ người duyệt thấy trước cả nội dung.
m.attrs[1] = ['Phiên bản', '1.0 — bản đầu, số liệu đo ngày 17/09/2026'];
m.attrs[2] = ['Ngày lập', '17/09/2026'];
m.history = [['1.0', '17/09/2026', 'Vũ Trí Công',
  'Phát hành lần đầu — mô tả TRẠNG THÁI ĐANG CHẠY (216/238 năng lực, 26 màn hình), '
  + 'ảnh chụp từ vòng chạy qua giao diện, kèm phần chưa làm được và câu hỏi gửi chuyên gia']];

const c = [];

/* ─────────────────────────── 1 ─────────────────────────── */
c.push(H1('1. Tài liệu này là gì, và đọc nó thế nào'));
c.push(P('Ba mươi mốt tài liệu còn lại của bộ hồ sơ EIDE mô tả sản phẩm SẼ được xây dựng thế nào. Tài liệu này mô tả sản phẩm ĐANG CHẠY được gì — đó là lý do nó tồn tại riêng, và là lý do mọi con số trong nó được đo lại mỗi lần tài liệu được sinh.'));
c.push(P('Người đọc mong đợi: một chuyên gia hệ thống nhúng hoặc một người phản biện đề án, không tham gia viết mã, cần trả lời được ba câu — sản phẩm này làm được gì, nó khác một IDE thường ở đâu, và chỗ nào trong đó còn là lời hứa.'));
c.push(H2('1.1. Quy ước trạng thái'));
c.push(P('Mỗi năng lực và mỗi màn hình trong tài liệu này mang một trong hai trạng thái. Không có trạng thái thứ ba, và cố ý không có: một mục "đang làm dở" là chỗ người đọc tự điền phần còn thiếu bằng thiện chí.'));
c.push(T([1800, 7500], ['Trạng thái', 'Nghĩa chính xác'], [
  ['ĐÃ CHẠY', 'Có hiện thực, có bài kiểm tự động, và đã chạy trên dữ liệu thật ít nhất một lần. Ảnh trong tài liệu chụp từ chính bản này.'],
  ['CHƯA', 'Hợp đồng đã chốt (tên, tham số, mã lỗi, lớp rủi ro) nhưng thân năng lực chưa viết, hoặc viết rồi mà chưa chạy được vì thiếu một vật ở ngoài — xem §9.'],
]));
c.push(SP());
c.push(P(`Tại thời điểm sinh tài liệu này: **${TONG}/${CAPS.length} năng lực ĐÃ CHẠY (${Math.round(TONG / CAPS.length * 100)}%)**, ${CAPS.length - TONG} năng lực CHƯA. Cả ${CAPS.length - TONG} cái còn lại chờ đúng ba thứ — một bo mạch thật, một công cụ ngoài, hoặc một thiết bị đo — chứ không chờ thời gian hay chờ một quyết định thiết kế.`));
c.push(H2('1.2. Vì sao các con số ở đây đáng tin hơn một bản mô tả thường'));
c.push(P('Bộ sinh tài liệu này đọc thẳng registry năng lực của sản phẩm rồi mới viết ra bảng. Một năng lực bị xoá khỏi mã sẽ biến khỏi tài liệu ở lần sinh kế tiếp; một năng lực khai trong hợp đồng mà chưa có thân sẽ tự mang nhãn CHƯA. Không có đường nào để một dòng trong tài liệu này nói về một thứ không tồn tại trong mã.'));
c.push(P('Ảnh cũng vậy. Mười lăm ảnh trong §3 chụp trong một lượt chạy `--vong-giao-dien` — sản phẩm tự đi mười lăm bước của một ngày làm việc, chụp cửa sổ sau mỗi bước, và ghi nhật ký. Không ảnh nào là mockup, không ảnh nào được sửa.'));

/* ─────────────────────────── 2 ─────────────────────────── */
c.push(PB());
c.push(H1('2. Sản phẩm trong một trang'));
c.push(H2('2.1. Vấn đề'));
c.push(P('Viết firmware cho một vi điều khiển là công việc liên tục đối chiếu mã với tài liệu phần cứng. Một dòng `#define UCSR0A 0xC0` chỉ đúng nếu 0xC0 thật sự là địa chỉ thanh ghi ấy trên đúng con chip ấy. Tri thức để kiểm điều đó nằm rải trong datasheet vài trăm trang, tệp SVD/ATDF của hãng, errata, và sơ đồ mạch — bốn nguồn có thể mâu thuẫn nhau.'));
c.push(P('Công cụ hiện có giải quyết nửa dưới của bài toán: trình dịch, trình nạp, trình gỡ lỗi. Nửa trên — *con số này ở đâu ra, và ta có còn tin nó không* — không công cụ nào giữ, nên nó nằm trong trí nhớ người viết, và mất đi khi người ấy chuyển việc.'));
c.push(H2('2.2. Luận điểm trung tâm'));
c.push(P('**Mọi hằng số phần cứng trong mã phải truy được về một fact đã duyệt, và máy phải tự kiểm điều đó.** Đây là điều EIDE làm khác một IDE thường, và mọi tính năng còn lại tồn tại để phục vụ nó:'));
c.push(T([2400, 6900], ['Mắt xích', 'Cách EIDE thực hiện'], [
  ['Tri thức vào', 'Trích fact từ SVD/ATDF/PDF/BOM/sơ đồ; mỗi fact mang giá trị, đơn vị, tầng tin cậy, và TRÍCH DẪN về đúng trang, đúng vùng ảnh của nguồn'],
  ['Tri thức mâu thuẫn', 'Hai nguồn nói khác nhau thì hệ thống KHÔNG tự chọn — nó dựng một xung đột có hai vế và hỏi người, rồi ghi lại ai đã quyết'],
  ['Tri thức ra mã', 'Mã sinh ra mang chú thích `eide:fact <id>` cạnh mỗi hằng số phần cứng'],
  ['Cổng chặn', '`code.constant_guard` quét mã tìm hằng số không trỏ fact nào; cổng G-FACT CHẶN merge nếu còn vi phạm'],
  ['Nhìn thấy được', 'Trình soạn thảo chấm dấu ở lề: chấm cho dòng có fact, vạch đỏ cho hằng số không nguồn'],
]));
c.push(SP());
c.push(P('Nói gọn: một thay đổi mã không vào được nhánh chính nếu trong đó còn một con số phần cứng không ai giải thích được nó ở đâu ra.'));
c.push(H2('2.3. Người dùng ra lệnh bằng tiếng Việt, tác tử làm, người giám sát'));
c.push(P('EIDE không phải một IDE có thêm ô trò chuyện. Bề mặt chính của nó là một cuộc trao đổi: người nói việc cần làm bằng ngôn ngữ tự nhiên, tác tử lập một chuỗi việc, chạy từng bước qua đúng một cổng chính sách, và báo lại. Người không phải thuộc tên 238 năng lực — nhưng người phải NHÌN THẤY tác tử đang làm gì, và chặn được nó bất cứ lúc nào.'));
c.push(P('Ba nguyên tắc của bề mặt ấy, chủ sản phẩm chốt ngày 16–17/09/2026, và cả ba đều đã thi hành (§4):'));
c.push(T([600, 3000, 5700], ['#', 'Nguyên tắc', 'Thể hiện trong sản phẩm'], [
  ['1', 'Vùng trao đổi là BẤT BIẾN', 'Ô trò chuyện không bao giờ bị màn nào thay thế hay che; nó có chiều cao sàn và trần riêng'],
  ['2', 'Tác tử chạm tới đâu, màn ấy TỰ MỞ và ĐƯỢC FOCUS', 'Tác tử chạy một năng lực `passport.*` thì màn Hộ chiếu chip mở ra; chạy `code.*` thì trình soạn thảo mở ra — người không phải tự đoán'],
  ['3', 'Không cướp màn khỏi tay người', 'Nếu người vừa tự chọn một màn khác, phép tự mở hoãn 20 giây. Một giao diện đổi màn ngay dưới tay người đang đọc là giao diện không dùng được'],
]));
c.push(H2('2.4. Ranh giới — EIDE KHÔNG làm gì'));
c.push(P('Nói ra phần này trước, vì một bản mô tả tính năng chỉ liệt kê cái làm được sẽ bị đọc như một lời hứa toàn phần.', { bullet: false }));
c.push(P('Không thay trình dịch, trình nạp hay trình gỡ lỗi của hãng — EIDE gọi chúng qua một bảng công cụ khai trước, trong hộp cát không mạng.', { bullet: true }));
c.push(P('Không tự quyết những việc có rủi ro cao. Bốn nhóm hành động luôn phải hỏi người bất kể mức tự chủ: nạp firmware lên board thật, ghi vào nhánh chính, tải nguồn ngoài danh sách tin cậy, và tự cấp quyền cho chính nó.', { bullet: true }));
c.push(P('Không suy ra fact từ mô hình ngôn ngữ. Mô hình được dùng để hiểu lệnh, lập kế hoạch, sinh mã và viết tài liệu — nhưng một con số phần cứng chỉ vào được store nếu nó đến từ một nguồn có trích dẫn.', { bullet: true }));
c.push(P('Không giữ khoá API ở nơi tác tử với tới được: khoá nằm trong tiến trình cha, không đi qua sổ cái, không đi lên giao diện.', { bullet: true }));

/* ─────────────────────────── 3 ─────────────────────────── */
c.push(PB());
c.push(H1('3. Một vòng làm việc thật, mười lăm bước'));
c.push(P('Phần này là cách nhanh nhất để thấy sản phẩm. Mười lăm bước dưới đây do chính sản phẩm tự đi trong chế độ `--vong-giao-dien`: nó mở dự án, bấm qua từng màn, gõ lệnh, chờ kết quả, chụp cửa sổ, và ghi nhật ký kèm thời gian. Lần chạy lấy ảnh cho tài liệu này: **15/15 bước chạy được**, trên một dự án AVR (ATmega328P) có firmware thật.'));
c.push(P('Chế độ này tồn tại vì nó trả lời câu mà 1 612 bài kiểm Python và 3 101 bài kiểm Swift không trả lời được: *một người đi hết một vòng thì gặp gì*. Mười trong 58 lỗi tìm được từ đầu đề án lộ ra bằng đúng cách này, và không cái nào lộ ra trong bộ kiểm tự động — chúng sống ở chỗ nối giữa các màn, hoặc chỉ hiện ra sau khi đi qua nhiều màn liên tiếp.'));

const BUOC = [
  ['buoc-01.png', '1. Mở dự án', 'Cửa sổ dựng xong: thanh trên mang nhận diện PTIT, tên dự án, mức tự chủ đang có hiệu lực, số việc chờ người và số việc hoàn tác được. Ba thứ ấy luôn hiện ở mọi màn.'],
  ['buoc-02.png', '2. Tổng quan dự án', 'Con chip đã ghim, số fact trong store, số việc đang chờ, hạn hoàn tác.'],
  ['buoc-03.png', '3. Môi trường', 'Máy này có chuỗi công cụ nào, phiên bản bao nhiêu, cổng serial và mạch nạp nào đang cắm.'],
  ['buoc-04.png', '4. Nhập tài liệu', 'Trích fact từ một header C thật; mỗi fact ra kèm trích dẫn về đúng dòng nguồn.'],
  ['buoc-05.png', '5. Hộ chiếu chip', 'Tra lại fact vừa trích. Địa chỉ hiện hệ 16 để đối chiếu thẳng với datasheet; kích thước bộ nhớ hiện KiB kèm số byte.'],
  ['buoc-06.png', '6. Bản đồ tri thức', 'Đồ thị dựng từ store: nút là fact/tài liệu/khối mã, cạnh là quan hệ HAS / CITES / SUPERSEDES.'],
  ['buoc-07.png', '7. Xung đột tri thức', 'Hai nguồn nói khác nhau về cùng một thanh ghi, hiện thành hai cột so được: giá trị, tầng tin cậy, nguồn, cách trích. Người chọn, hệ thống ghi lại ai đã chọn.'],
  ['buoc-08.png', '8. Mã nguồn', 'Mở một tệp: lề trái chấm dấu cho dòng mang `eide:fact`, vạch đỏ cho hằng số phần cứng không trỏ fact nào. Thanh đầu tệp đếm cả hai.'],
  ['buoc-09.png', '9. Mô phỏng', 'Chạy firmware thật trong qemu; log UART, bảng kỳ vọng đạt/trượt, bảng quét tham số.'],
  ['buoc-10.png', '10. Ô lệnh trên một màn chuyên đề', 'Người gõ được lệnh ngay trên màn đang xem, không phải quay về màn trò chuyện.'],
  ['buoc-11.png', '11. Tác tử tự mở đúng màn', 'Đang ở màn Môi trường; tác tử chạy `passport.query`; màn Hộ chiếu chip tự mở và được focus.'],
  ['buoc-12.png', '12. Ba điều kiện cùng lúc', 'Tác tử sửa mã → trình soạn thảo mở ra và được focus → mà vùng trao đổi VẪN hiện bên dưới. Đây là bài kiểm chặt nhất của §4.'],
  ['buoc-13.png', '13. Nhật ký', 'Mọi việc vừa làm có trong sổ cái không — kể cả việc tác tử tự duyệt.'],
  ['buoc-14.png', '14. Mô hình và chi phí', 'Vòng này tiêu bao nhiêu, còn bao nhiêu trong hạn mức ngày.'],
  ['buoc-15.png', '15. Hành trình và cổng', 'Chính sách đã quyết những gì, theo quy tắc nào, và cái nào do người quyết.'],
];
BUOC.forEach(([t, ten, mo], i) => {
  const so = i + 1;
  const ngan = ten.replace(/^\d+\.\s*/, '');
  c.push(H3(`3.${so}. ${ngan}`));
  c.push(P(mo));
  c.push(...ANH(t, `Hình ${so}. ${ngan} — ảnh chụp từ cửa sổ thật`));
});

/* ─────────────────────────── 4 ─────────────────────────── */
c.push(PB());
c.push(H1('4. Bề mặt người ↔ tác tử'));
c.push(P('Phần này tách riêng vì nó là quyết định thiết kế khác biệt nhất của sản phẩm, và vì nó mới được hoàn thiện ngày 17/09/2026.'));
c.push(H2('4.1. Vấn đề đã có'));
c.push(P('Trước đó, chọn màn "Mã nguồn" trên cột điều hướng sẽ THAY cả bảng làm việc bằng trình soạn thảo. Nghĩa là đúng lúc tác tử sửa mã — lúc người cần giám sát nhất — ô trò chuyện biến mất khỏi màn hình. Người dùng mất đường nói chuyện với tác tử ngay tại khoảnh khắc tác tử làm việc rủi ro nhất.'));
c.push(H2('4.2. Cách chia màn hình hiện nay'));
c.push(T([2400, 6900], ['Vùng', 'Quy tắc'], [
  ['Thanh trên', 'Luôn hiện: dự án, mức tự chủ có hiệu lực, số việc chờ người, số việc hoàn tác được, nút Dừng khẩn'],
  ['Cột trái', 'Điều hướng 26 màn'],
  ['Vùng làm việc', 'Màn chuyên đề đang mở. Trình soạn thảo là MỘT màn trong đó, không phải một bề mặt song song'],
  ['Vùng trao đổi', 'Ngay dưới vùng làm việc. Có SÀN 220 pt (không co mất) và TRẦN 320 pt (không nuốt vùng làm việc). Nội dung vượt trần thì cuộn bên trong'],
  ['Cột phải', '"Đang làm" và "hoàn tác được" — việc tác tử tự duyệt hiện ở đây kèm nút hoàn tác'],
]));
c.push(SP());
c.push(P('Trần của vùng trao đổi là một ràng buộc bắt buộc, khác với sàn. Lý do bất đối xứng: một vùng trao đổi cao quá thì vẫn đọc được vì nó cuộn, còn một vùng làm việc bị bóp còn bốn dòng thì không làm việc được. Cả hai con số đều đo được trên cửa sổ thật, không phải ước lượng.'));
c.push(...ANH('buoc-12.png', 'Hình 16. Ba điều kiện cùng đúng: tác tử đang chạy code.constant_guard, trình soạn thảo mở ra kèm cây dự án và cảnh báo "11 dòng vi phạm — CHẶN merge (G-FACT)", và vùng trao đổi vẫn hiện bên dưới'));

/* ─────────────────────────── 5 ─────────────────────────── */
c.push(PB());
c.push(H1('5. Tự chủ, chính sách, sổ cái, hoàn tác'));
c.push(P('Bốn cơ chế này là thứ cho phép một tác tử được quyền tự làm việc mà vẫn kiểm soát được. Chúng áp cho MỌI năng lực, kể cả khi người dùng bấm một nút trên giao diện — nút bấm và lệnh của tác tử đi cùng một đường.'));
c.push(H2('5.1. Năm mức tự chủ'));
c.push(T([900, 2400, 6000], ['Mức', 'Tên', 'Nghĩa'], [
  ['A0', 'Dừng', 'Không tự làm gì. Nút Dừng khẩn hạ về mức này dưới một giây'],
  ['A1', 'Hỏi từng bước', 'Mọi hành động ghi đều hỏi'],
  ['A2', 'Tự ghi tri thức và sinh mã', 'Mức mặc định. Tự trích fact, tự sinh mã, tự chạy mô phỏng; hỏi khi ghi vào nhánh chính hoặc chạm phần cứng'],
  ['A3', 'Làm rồi báo cáo', 'Tự làm trọn chuỗi, báo lại sau; mọi việc vẫn hoàn tác được trong hạn'],
  ['A4', 'Tự chủ rộng', 'Chỉ dùng cho việc lặp đã kiểm chứng; bốn nhóm hành động ở §2.4 vẫn luôn hỏi'],
]));
c.push(H2('5.2. Cổng chính sách'));
c.push(P('49 quy tắc chính sách, máy đọc được, nhóm theo cổng. Mỗi lời gọi năng lực đi qua cổng tương ứng và nhận một trong ba quyết định: APPROVE, ASK, REJECT — kèm mã quy tắc đã quyết.'));
c.push(T([1500, 7800], ['Cổng', 'Chặn cái gì'], [
  ['G-FACT', 'Mã còn hằng số phần cứng không trỏ fact nào thì không merge được'],
  ['G-SRC', 'Nguồn tải về phải thuộc danh sách tin cậy, đúng giấy phép, dưới ngưỡng dung lượng'],
  ['G-TOOL', 'Tác tử tự viết công cụ: công cụ mới phải qua sandbox và bài kiểm trước khi thành năng lực'],
  ['G-OPS', 'Hành động chạm máy thật: nạp, xoá, ghi ngoài thư mục dự án'],
  ['G-WL', 'Danh sách trắng và việc tự cấp quyền — tác tử KHÔNG tự mở rộng quyền của chính nó'],
  ['G1 / G3 / G4 / G5', 'Cổng theo giai đoạn: kế hoạch, kiến trúc, merge, phát hành'],
]));
c.push(SP());
c.push(P('Một chi tiết đáng nêu vì nó là quyết định an toàn chứ không phải chi tiết kỹ thuật: lệnh ký lại chính sách là một lệnh dòng lệnh, **không phải một năng lực**. Tác tử gọi được mọi năng lực; nếu ký chính sách là một năng lực thì tác tử tự mở rộng được quyền của mình, và toàn bộ hệ thống cổng mất nghĩa.'));
c.push(H2('5.3. Sổ cái và hoàn tác'));
c.push(P('Mỗi việc đã xảy ra ghi một bản ghi vào sổ cái chỉ-ghi-thêm, nối nhau bằng chuỗi băm. Giao diện KHÔNG có đường nào hiện một việc mà sổ cái không có — các sự kiện đẩy lên màn hình phái sinh từ chính sổ cái, không phải từ lời gọi riêng trong từng năng lực. Hệ quả: một việc người dùng nhìn thấy là một việc đã nằm trong chuỗi băm.'));
c.push(P('Việc nào sửa đổi dữ liệu đều đăng ký một mục hoàn tác kèm hạn. Cột phải của cửa sổ luôn hiện danh sách "hoàn tác được đến …" cùng nút hoàn tác.'));

/* ─────────────────────────── 6 ─────────────────────────── */
c.push(PB());
c.push(H1('6. Hai mươi bảy nhóm năng lực'));
c.push(P(`Năng lực là đơn vị tính năng của EIDE: một tên, một hợp đồng tham số vào/ra, một lớp rủi ro, một mức tự chủ tối thiểu, một danh sách mã lỗi, và một quy tắc hoàn tác. Cả giao diện lẫn tác tử đều chỉ gọi năng lực — không có đường tắt nào khác. Bảng dưới đo lúc sinh tài liệu: ${TONG}/${CAPS.length}.`));
c.push(T([2000, 900, 6400], ['Nhóm', 'Đã chạy', 'Làm gì'], NS_ORDER.map(n => {
  const t = CAPS.filter(c2 => c2.ns === n).length;
  return [`${n}.*`, `${xong(n)}/${t}`, NS_VI[n] || ''];
}), { size: 18 }));
c.push(SP());
c.push(P('Bốn nhóm đáng nói riêng vì chúng mang phần lớn luận điểm của đề án:'));
c.push(H3('extract.* và passport.* — tri thức vào'));
c.push(P('Trích fact từ SVD, ATDF, PDF (bố cục và bảng thanh ghi), BOM, sơ đồ mạch, header C. Mỗi fact mang giá trị, đơn vị, tầng tin cậy, và trích dẫn về đúng trang và vùng ảnh của nguồn. `passport.query` tra lại theo tên thanh ghi hoặc theo địa chỉ; `view.provenance` mở đúng chỗ trong tài liệu gốc.'));
c.push(H3('kg.* — tri thức mâu thuẫn'));
c.push(P('`kg.conflicts` tìm các cặp fact nói khác nhau về cùng một thứ và dựng thành xung đột có khoá riêng; `kg.resolve_conflict` ghi lại người nào chọn vế nào, vì sao. Hệ thống không tự chọn giữa hai nguồn — đó là quyết định có hậu quả, và nó phải có tên người.'));
c.push(H3('code.* — tri thức ra mã, và cổng chặn'));
c.push(P('`code.generate_module` sinh mã có chú thích `eide:fact` cạnh mỗi hằng số phần cứng; `code.constant_guard` quét ngược lại tìm hằng số không nguồn; `code.merge` không chạy nếu còn vi phạm. Đây là chỗ luận điểm trung tâm được thi hành chứ không chỉ được phát biểu.'));
c.push(H3('tool.* — tác tử tự viết công cụ'));
c.push(P('Khi không năng lực nào làm được việc đang cần, tác tử viết một công cụ Python, chạy thử trong hộp cát không mạng, và nếu đạt thì đăng ký thành một năng lực tạm `user.*`. Cổng G-TOOL chặn đường này: một công cụ chưa qua bài kiểm không thành năng lực được.'));

/* ─────────────────────────── 7 ─────────────────────────── */
c.push(PB());
c.push(H1('7. Hai mươi sáu màn hình'));
c.push(P(`Bảng dưới sinh từ \`docs/spec/ui/screens.json\` — cùng tệp mà bộ kiểm tự động dùng để đối chiếu với danh sách màn sản phẩm thật dựng ra. Lệch nhau thì bài kiểm đỏ, nên bảng này không thể mô tả một màn không tồn tại. ${MAN.length} màn.`));
c.push(T([600, 2200, 4200, 2300], ['#', 'Màn', 'Nội dung', 'Năng lực đứng sau'],
  MAN.map(s => [String(s.so), s.man_hinh, s.noi_dung || '', (s.nang_luc || []).join(', ')]),
  { size: 16 }));
c.push(SP());
c.push(P('Mọi màn đều có ba trạng thái được thiết kế sẵn: có dữ liệu, rỗng, và lỗi. Trạng thái rỗng luôn nói LÝ DO rỗng — một màn vừa rỗng vừa im là màn người dùng không biết nên chờ hay nên bấm gì, và bộ tự kiểm có một bài mở cả 26 màn chỉ để bắt đúng chuyện đó.'));
c.push(H2('7.1. Bốn màn chỉ hiện được trạng thái rỗng'));
c.push(P('Discovery (dò board), Debug (gỡ lỗi qua mạch nạp), Bench, và phần `target.*` của LogAssist đã dựng đủ khung nhìn theo hợp đồng, nhưng chưa có dữ liệu thật để hiện vì chưa có bo mạch. Chúng hiện đúng một câu nói rõ đang thiếu gì, không hiện dữ liệu giả.'));
c.push(H2('7.2. Ghi chú thiết kế chung cho mọi màn'));
c.push(P('Không lồng vùng cuộn: khung nhìn tự cao bằng nội dung tới trần 420 pt rồi mới bật bộ cuộn riêng. Hai vùng cuộn lồng nhau làm con lăn chuột bị vùng trong nuốt, và lỗi ấy không lộ ra trên ảnh chụp.', { bullet: true }));
c.push(P('Cắt thì phải nói ra: bảng quá 2 000 hàng bị cắt để cửa sổ không treo, và số bị cắt hiện thành một dòng cảnh báo. Im lặng cắt là cách chắc chắn nhất để một bảng thiếu bị đọc như đủ.', { bullet: true }));
c.push(P('Bốn trạng thái của một việc — chờ, đang chạy, bị huỷ, bị từ chối — là bốn câu khác nhau cho người dùng, không phải một câu "chưa chạy được".', { bullet: true }));
c.push(P('Một bảng màu sáng duy nhất, lấy từ tệp nhận diện chính thức của PTIT. Đỏ `#BC2626` cho chữ và hành động, đỏ `#DE221A` cho mảng lớn và biểu tượng; phân vai ấy do chính bộ nhận diện đặt ra, và nó cũng là phân vai đạt ngưỡng tương phản AA.', { bullet: true }));

/* ─────────────────────────── 8 ─────────────────────────── */
c.push(PB());
c.push(H1('8. An toàn và ranh giới thi hành'));
c.push(T([2600, 6700], ['Ràng buộc', 'Thi hành thế nào'], [
  ['Hộp cát cho mọi công cụ ngoài', 'Không mạng, chỉ ghi trong thư mục dự án, có hạn thời gian, và CẮT stdin. Bỏ sót stdin từng là một lỗ thật: `qemu` thừa kế stdin của tiến trình cha — tức chính ống JSON-RPC của giao diện — và ăn mất lệnh đang gửi'],
  ['Không `sudo` trong bất kỳ đường cài đặt nào', 'Năng lực cài công cụ từ chối mọi đường cần quyền quản trị, và nói ra thay vì im lặng bỏ qua'],
  ['Khoá API không rời tiến trình cha', 'Không vào sổ cái, không lên giao diện, không vào ngữ cảnh gửi mô hình. Sự kiện `event.model.call` cố ý không mang prompt'],
  ['Tác tử không tự cấp quyền', 'Ký chính sách là lệnh dòng lệnh, không phải năng lực (§5.2)'],
  ['Đánh dấu mạch an toàn cần người', '`board.mark_lab` đòi người khai rõ mạch không có cơ cấu chấp hành và đã giới hạn dòng, kèm tên người khai. Giao diện không được tự điền'],
  ['Tệp `.env` chỉ đọc ở gốc kho', 'Không đọc trong thư mục dự án: một dự án tải về có thể mang theo `.env` của người khác'],
]));

/* ─────────────────────────── 9 ─────────────────────────── */
c.push(PB());
c.push(H1('9. Chưa làm được gì, và vì sao'));
c.push(P(`Danh sách dưới đây LIỆT KÊ ĐỦ ${CAPS.length - TONG} năng lực chưa chạy, sinh từ registry lúc lập tài liệu — không phải một bản tóm tắt chọn lọc.`));
const CHUA = {};
for (const x of CAPS) if (!DO.caps[x.name]) (CHUA[x.ns] = CHUA[x.ns] || []).push(x.name);
c.push(T([1500, 700, 7100], ['Nhóm', 'Số', 'Năng lực'],
  Object.keys(CHUA).sort().map(n => [`${n}.*`, String(CHUA[n].length), CHUA[n].join(', ')]),
  { size: 18 }));
c.push(SP());
c.push(P('Cả 22 chờ cùng một loại thứ: một vật ở ngoài máy tính. `discover.*` và `target.*` cần một bo mạch cắm vào cùng một mạch nạp; `measure.*` cần máy hiện sóng hoặc đồng hồ đo dòng; `bench.run` và `sim.compare_hil` cần cả hai — chúng SO kết quả mô phỏng với kết quả chạy thật, nên thiếu vế thật thì phép so không tồn tại. `passport.verify_on_board` cũng vậy: nó đọc thanh ghi trên chip thật để đối chiếu với fact trích từ datasheet, tức là mắt xích đóng vòng của luận điểm §2.2.'));
c.push(SP());
c.push(P('Cùng với chúng là 7 phương thức JSON-RPC, 1 kiểu sự kiện sổ cái, và 2 mã lỗi chưa từng được ném ra. Không mục nào trong danh sách này chờ thời gian, chờ một thư viện, hay chờ một quyết định thiết kế — đó là điều đáng nói nhất về trạng thái hiện nay của sản phẩm.'));

/* ─────────────────────────── 10 ────────────────────────── */
c.push(H1('10. Sản phẩm được kiểm thế nào'));
c.push(T([3400, 5900], ['Cách đo', 'Kết quả tại thời điểm sinh tài liệu'], [
  ['Bài kiểm Python', '1 612 bài — gồm 27 bài đầu-cuối gọi daemon thật'],
  ['Bài kiểm Swift (giao diện)', '3 101 bài'],
  ['Đối chiếu mã ↔ đặc tả', `238 năng lực, 64 phương thức JSON-RPC — mọi tên, mã lỗi và schema trong mã phải khớp \`docs/spec/\``],
  ['Tự kiểm trên cửa sổ THẬT', '7/7 bài — gồm một bài kiểm kê mở cả 26 màn'],
  ['Một vòng qua giao diện', '15/15 bước'],
]));
c.push(SP());
c.push(H2('10.1. Năm mươi tám lỗi im lặng — và vì sao chúng có mặt trong tài liệu này'));
c.push(P('Nhóm phát triển giữ một danh sách đánh số các lỗi *im lặng*: lỗi mà hệ thống vẫn chạy, bộ kiểm vẫn xanh, và không có gì trên màn hình nói rằng có chuyện sai. Tới nay là 58 lỗi, mỗi lỗi ghi rõ ngày, cách tìm ra, và vì sao nó sống được lâu đến thế.'));
c.push(P('Đưa danh sách ấy vào một tài liệu gửi người ngoài là có chủ ý. Ba lý do:'));
c.push(P('Loại lỗi này là rủi ro lớn nhất của một sản phẩm kiểu này, vì luận điểm của nó là *tin được*. Một hệ thống nói sai về việc mình vừa làm thì nguy hiểm hơn một hệ thống báo hỏng.', { bullet: true }));
c.push(P('Cách tìm ra chúng là một kết quả của đề án chứ không chỉ là công việc sửa lỗi. Ba kỹ thuật đã sinh ra phần lớn danh sách: chụp màn hình rồi ĐỌC, kiểm kê mọi màn bằng một bài duy nhất, và đi một vòng làm việc thật rồi ghi lại.', { bullet: true }));
c.push(P('Lỗi lớn nhất trong danh sách chỉ lộ ra ngày 17/09/2026, sau khi sửa một lỗi BỐ CỤC: khi ô trò chuyện thôi bị che, thứ nó nói ra là chuỗi năng lực không nối được dữ liệu giữa các nút — nghĩa là bốn trong năm chuỗi mẫu của thiết kế chưa bao giờ chạy được, trong khi cả hai phía đều có bài kiểm riêng và đều xanh.', { bullet: true }));

/* ─────────────────────────── 11 ────────────────────────── */
c.push(PB());
c.push(H1('11. Câu hỏi gửi chuyên gia'));
c.push(P('Tài liệu này được soạn để lấy phản biện, nên phần này nêu thẳng những chỗ nhóm phát triển tự thấy chưa chắc. Trả lời được một trong số đó đã đáng giá hơn một bản duyệt "đạt".'));
c.push(T([600, 3000, 5700], ['#', 'Chỗ chưa chắc', 'Câu hỏi cụ thể'], [
  ['1', 'Luận điểm trung tâm có đủ mạnh không', 'Cổng G-FACT chặn merge khi còn hằng số không trỏ fact. Trong thực tế viết firmware, tỉ lệ hằng số KHÔNG nên đòi fact (hằng số thuật toán, hằng số giao thức, số ma thuật của chuẩn) là bao nhiêu, và cổng này có trở thành thứ người ta tắt đi không?'],
  ['2', 'Tầng tin cậy của fact', 'Hiện phân theo nguồn: tệp hãng > datasheet > errata > suy luận. Với người làm nhúng lâu năm, thứ tự này có đúng không, và errata nên đứng ở đâu?'],
  ['3', 'Mức tự chủ mặc định', 'A2 (tự ghi tri thức và sinh mã, hỏi khi chạm phần cứng hoặc nhánh chính) là mặc định. Quá rộng hay quá hẹp cho một kỹ sư lần đầu dùng?'],
  ['4', 'Chuỗi việc dừng để hỏi', 'Khi một bước cần dữ liệu không nút nào sinh ra được (kịch bản mô phỏng, đích nạp), chuỗi chạy phần làm được rồi dừng và hỏi. Cách này đúng hay nên hỏi trọn gói từ đầu?'],
  ['5', 'Bố cục màn hình', 'Vùng trao đổi cố định 220–320 pt dưới vùng làm việc. Với một màn hình laptop 13 inch, tỉ lệ này còn chỗ làm việc không?'],
  ['6', 'Phạm vi chưa làm', '22 năng lực chờ bo mạch. Nếu chỉ có một bo mạch để chứng minh, nên chọn dòng nào để bao được nhiều mắt xích nhất?'],
]));
c.push(SP());
c.push(P('Phần phản hồi xin ghi thẳng vào bản này; nhóm phát triển sẽ chuyển mỗi mục thành một mục trong sổ sai khác (`DEVIATIONS.md`) có trạng thái và người duyệt, rồi sinh lại tài liệu.'));

/* ─────────────────────────── phụ lục ───────────────────── */
c.push(PB());
c.push(H1('Phụ lục A. Toàn bộ danh mục năng lực'));
c.push(P('Sinh từ registry lúc lập tài liệu. Cột "R" là lớp rủi ro (R0 chỉ đọc → R4 chạm phần cứng thật).'));
for (const n of NS_ORDER) {
  const ds = CAPS.filter(x => x.ns === n);
  c.push(H3(`${n}.* — ${NS_VI[n] || ''} (${xong(n)}/${ds.length})`));
  c.push(T([2100, 700, 600, 5900], ['Năng lực', 'Trạng thái', 'R', 'Làm gì'],
    ds.map(x => [x.name, DO.caps[x.name] ? 'ĐÃ CHẠY' : 'CHƯA', x.risk || '', x.desc || '']),
    { size: 16 }));
  c.push(SP());
}

c.push(PB());
c.push(H1('Tài liệu tham chiếu'));
c.push(...refParas(H1));

build(m, c, 'EIDE-FTR-30_Mo_ta_tinh_nang_san_pham.docx');

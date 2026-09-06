#import <Cocoa/Cocoa.h>

/// Bọc `ScintillaView` của Scintilla thành API Objective-C thuần (ADR-01 · PoC-A).
///
/// Vì sao có lớp bọc này thay vì dùng thẳng `ScintillaView`: header của Scintilla kéo theo
/// `Scintilla.h` và `InfoBarCommunicator.h` bằng đường dẫn tương đối trong cây nguồn upstream.
/// Cho Swift import trực tiếp sẽ phải bày cả cây header ấy ra ngoài biên module — nghĩa là
/// mọi chi tiết nội bộ của Scintilla thành API công khai của gói. Lớp bọc giữ đúng những gì
/// PoC cần đo và không hơn.
///
/// API ở đây là API của PHÉP ĐO, không phải của sản phẩm: nó tồn tại để trả lời câu hỏi của
/// ADR-01 (gõ p95 trên 500 MB, marked-text Telex, 1.000 caret, column mode 10.000 dòng).
@interface GEScintillaView : NSView

/// Nạp nội dung. `bytes` là UTF-8, không cần kết thúc bằng NUL.
///
/// Scintilla giữ nội dung trong gap buffer CỦA NÓ — đây chính là điều ADR-01 phải cân nhắc:
/// không có đường nào cho Scintilla đọc thẳng từ vùng mmap của piece table.
- (void)loadUTF8:(const void *)bytes length:(NSInteger)length;

- (void)insertText:(NSString *)text atPosition:(NSInteger)position;
- (void)deleteRange:(NSRange)range;

/// Đặt N caret rời (FR-CORE-001, kiểm 1.000 caret).
- (void)setCaretPositions:(NSArray<NSNumber *> *)positions;
/// Chọn theo khối chữ nhật (column mode, kiểm 10.000 dòng).
- (void)selectRectangleFrom:(NSInteger)anchor to:(NSInteger)caret;

- (void)scrollToLine:(NSInteger)line;
/// Vị trí byte đầu dòng. Không đụng tới caret hay vị trí cuộn — phép đo không được tự làm
/// nhiễu thứ nó đang đo.
- (NSInteger)positionOfLine:(NSInteger)line;
- (void)goToPosition:(NSInteger)position;

@property (readonly) NSInteger documentLength;
@property (readonly) NSInteger lineCount;
/// Vị trí caret chính — đọc lại sau khi gõ để chắc nội dung thật sự vào.
@property (readonly) NSInteger currentPosition;

/// Số lần Scintilla VẼ XONG kể từ lần gọi trước (đếm SCN_PAINTED), rồi đặt lại về 0.
///
/// Có mặt để phép đo tự chứng minh mình: nếu gõ 300 phím mà số này bằng 0 thì con số latency
/// đo được là latency của một view không vẽ gì, và nó không nói lên điều gì cả.
- (NSInteger)takePaintCount;

/// Nơi bộ gõ nói chuyện với Scintilla (`SCIContentView` hiện thực `NSTextInputClient`).
///
/// Lộ ra để kiểm marked-text BẰNG MÁY. Bộ gõ tiếng Việt là tiêu chí chặn phát hành
/// (NFR-USE-02), mà "nhờ người gõ thử" thì không chạy lại được ở mỗi lần commit.
- (nullable id<NSTextInputClient>)inputClient;

/// Toàn bộ nội dung. Chỉ dùng cho kiểm thử — với tài liệu lớn thì đây là bản sao cả tài liệu.
- (nonnull NSString *)documentText;

/// Chuỗi phiên bản upstream, để ADR ghi đúng bản đã đo.
+ (nonnull NSString *)scintillaVersion;

/// Mô tả khung nhìn thật: cỡ view và số dòng đang hiện. Báo cáo PoC phải nói rõ nó đo trên
/// khung nào — "gõ nhanh" trên một view cao 0 pixel không có nghĩa gì.
- (nonnull NSString *)viewportDescription;

@end

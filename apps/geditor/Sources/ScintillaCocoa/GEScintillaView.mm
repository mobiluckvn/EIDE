#import "GEScintillaView.h"
#import "ScintillaView.h"
#import "Scintilla.h"

// Không import Lexilla: từ Scintilla 5, lexer tách thành gói riêng, và PoC-A đo ENGINE HIỂN
// THỊ chứ không đo tô màu cú pháp. Bớt được cả một phụ thuộc khỏi phép đo.

@interface GEScintillaView () <ScintillaNotificationProtocol>
@property (nonatomic, strong) ScintillaView *scintilla;
@property (nonatomic, assign) NSInteger paintCount;
@end

@implementation GEScintillaView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    _scintilla = [[ScintillaView alloc] initWithFrame:self.bounds];
    _scintilla.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:_scintilla];

    // UTF-8 và không tô màu cú pháp: PoC-A đo ENGINE HIỂN THỊ, không đo lexer. Bật lexer
    // sẽ trộn chi phí tô màu vào số đo và câu trả lời sẽ không còn về cái đang hỏi.
    [_scintilla setGeneralProperty:SCI_SETCODEPAGE value:SC_CP_UTF8];
    [_scintilla setGeneralProperty:SCI_SETMULTIPLESELECTION value:1];
    [_scintilla setGeneralProperty:SCI_SETADDITIONALSELECTIONTYPING value:1];
    [_scintilla setGeneralProperty:SCI_SETMULTIPASTE value:SC_MULTIPASTE_EACH];
    _scintilla.delegate = self;
    return self;
}

- (void)loadUTF8:(const void *)bytes length:(NSInteger)length {
    [_scintilla setGeneralProperty:SCI_CLEARALL value:0];
    // SCI_ADDTEXT nhận độ dài nên nội dung chứa NUL vẫn vào đủ.
    [_scintilla message:SCI_ADDTEXT wParam:(uptr_t)length lParam:(sptr_t)bytes];
    [_scintilla setGeneralProperty:SCI_SETSAVEPOINT value:0];
    [_scintilla setGeneralProperty:SCI_GOTOPOS value:0];
}

- (void)insertText:(NSString *)text atPosition:(NSInteger)position {
    const char *utf8 = text.UTF8String;
    [_scintilla message:SCI_INSERTTEXT wParam:(uptr_t)position lParam:(sptr_t)utf8];
}

- (void)deleteRange:(NSRange)range {
    [_scintilla message:SCI_DELETERANGE wParam:(uptr_t)range.location lParam:(sptr_t)range.length];
}

- (void)setCaretPositions:(NSArray<NSNumber *> *)positions {
    if (positions.count == 0) return;
    NSInteger first = positions[0].integerValue;
    [_scintilla message:SCI_SETSELECTION wParam:(uptr_t)first lParam:(sptr_t)first];
    for (NSUInteger i = 1; i < positions.count; i++) {
        NSInteger p = positions[i].integerValue;
        [_scintilla message:SCI_ADDSELECTION wParam:(uptr_t)p lParam:(sptr_t)p];
    }
}

- (void)selectRectangleFrom:(NSInteger)anchor to:(NSInteger)caret {
    [_scintilla message:SCI_SETRECTANGULARSELECTIONANCHOR wParam:(uptr_t)anchor lParam:0];
    [_scintilla message:SCI_SETRECTANGULARSELECTIONCARET wParam:(uptr_t)caret lParam:0];
}

- (void)scrollToLine:(NSInteger)line {
    [_scintilla message:SCI_GOTOLINE wParam:(uptr_t)line lParam:0];
}

- (NSInteger)positionOfLine:(NSInteger)line {
    return (NSInteger)[_scintilla message:SCI_POSITIONFROMLINE wParam:(uptr_t)line lParam:0];
}

- (void)goToPosition:(NSInteger)position {
    [_scintilla message:SCI_GOTOPOS wParam:(uptr_t)position lParam:0];
}

- (NSInteger)documentLength {
    return (NSInteger)[_scintilla message:SCI_GETLENGTH wParam:0 lParam:0];
}

- (NSInteger)lineCount {
    return (NSInteger)[_scintilla message:SCI_GETLINECOUNT wParam:0 lParam:0];
}

- (NSInteger)currentPosition {
    return (NSInteger)[_scintilla message:SCI_GETCURRENTPOS wParam:0 lParam:0];
}

- (void)notification:(SCNotification *)notification {
    if (notification->nmhdr.code == SCN_PAINTED) _paintCount += 1;
}

- (NSInteger)takePaintCount {
    NSInteger count = _paintCount;
    _paintCount = 0;
    return count;
}

- (nullable id<NSTextInputClient>)inputClient {
    return (id<NSTextInputClient>)[_scintilla content];
}

- (nonnull NSString *)documentText {
    NSString *text = [_scintilla string];
    return text ?: @"";
}

+ (nonnull NSString *)scintillaVersion {
    return @"5.5.5";
}

- (nonnull NSString *)viewportDescription {
    NSInteger onScreen = (NSInteger)[_scintilla message:SCI_LINESONSCREEN wParam:0 lParam:0];
    return [NSString stringWithFormat:@"%.0f×%.0f pt, %ld dòng hiện",
            self.bounds.size.width, self.bounds.size.height, (long)onScreen];
}

- (BOOL)acceptsFirstResponder { return YES; }

- (BOOL)becomeFirstResponder {
    return [self.window makeFirstResponder:_scintilla];
}

@end

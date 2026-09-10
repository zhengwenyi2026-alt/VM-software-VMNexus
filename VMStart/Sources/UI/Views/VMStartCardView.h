//
//  VMStartCardView.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VMStartAppMode) {
    VMStartAppModeSimple   = 0,
    VMStartAppModeStandard = 1,
    VMStartAppModeAdvanced = 2
};

// Card view with rounded corners and shadow
@interface VMStartCardView : NSView
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, strong) NSColor *cardBackgroundColor;
@property (nonatomic, assign) CGFloat shadowRadius;
@property (nonatomic, assign) NSEdgeInsets contentInsets;
@end

// Status badge dot
@interface VMStartStatusBadge : NSView
@property (nonatomic, strong) NSColor *badgeColor;
@property (nonatomic, copy) NSString *badgeText;
- (void)setStatus:(NSInteger)status;
@end

// Mode switcher (Simple / Standard / Advanced)
@interface VMStartModeSwitcher : NSView
@property (nonatomic, assign) VMStartAppMode currentMode;
@property (nonatomic, copy) void (^onModeChange)(VMStartAppMode mode);
@end

// Icon button with SF Symbol
@interface VMStartIconButton : NSButton
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, assign) CGFloat symbolSize;
- (instancetype)initWithSymbol:(NSString *)symbolName size:(CGFloat)size target:(id)target action:(SEL)action;
@end

NS_ASSUME_NONNULL_END

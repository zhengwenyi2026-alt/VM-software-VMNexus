//
//  VMNexusCardView.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VMNexusAppMode) {
    VMNexusAppModeSimple   = 0,
    VMNexusAppModeStandard = 1,
    VMNexusAppModeAdvanced = 2
};

// Card view with rounded corners and shadow
@interface VMNexusCardView : NSView
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, strong) NSColor *cardBackgroundColor;
@property (nonatomic, assign) CGFloat shadowRadius;
@property (nonatomic, assign) NSEdgeInsets contentInsets;
@end

// Status badge dot
@interface VMNexusStatusBadge : NSView
@property (nonatomic, strong) NSColor *badgeColor;
@property (nonatomic, copy) NSString *badgeText;
- (void)setStatus:(NSInteger)status;
@end

// Mode switcher (Simple / Standard / Advanced)
@interface VMNexusModeSwitcher : NSView
@property (nonatomic, assign) VMNexusAppMode currentMode;
@property (nonatomic, copy) void (^onModeChange)(VMNexusAppMode mode);
@end

// Icon button with SF Symbol
@interface VMNexusIconButton : NSButton
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, assign) CGFloat symbolSize;
- (instancetype)initWithSymbol:(NSString *)symbolName size:(CGFloat)size target:(id)target action:(SEL)action;
@end

NS_ASSUME_NONNULL_END

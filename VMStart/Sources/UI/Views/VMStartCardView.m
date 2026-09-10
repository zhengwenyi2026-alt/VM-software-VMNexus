//
//  VMStartCardView.m
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMStartCardView.h"
#import "VMStartVirtualMachine.h"

#pragma mark - VMStartCardView

@implementation VMStartCardView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _cornerRadius = 12;
        _cardBackgroundColor = [NSColor controlBackgroundColor];
        _shadowRadius = 4;
        _contentInsets = NSEdgeInsetsMake(16, 16, 16, 16);
        self.wantsLayer = YES;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:self.cornerRadius yRadius:self.cornerRadius];
    [self.cardBackgroundColor setFill];
    [path fill];

    // Subtle border
    [[NSColor separatorColor] setStroke];
    [path setLineWidth:0.5];
    [path stroke];
}

- (void)setCardBackgroundColor:(NSColor *)cardBackgroundColor {
    _cardBackgroundColor = cardBackgroundColor;
    [self setNeedsDisplay:YES];
}

@end

#pragma mark - VMStartStatusBadge

@implementation VMStartStatusBadge

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _badgeColor = [NSColor tertiaryLabelColor];
        _badgeText = @"";
        self.wantsLayer = YES;
    }
    return self;
}

- (void)setStatus:(NSInteger)status {
    switch (status) {
        case 2: // Running
            self.badgeColor = [NSColor colorWithRed:0.25 green:0.75 blue:0.35 alpha:1.0];
            break;
        case 3: // Paused
            self.badgeColor = [NSColor colorWithRed:0.95 green:0.65 blue:0.1 alpha:1.0];
            break;
        case 1: // Starting
            self.badgeColor = [NSColor colorWithRed:0.2 green:0.55 blue:0.95 alpha:1.0];
            break;
        case 5: // Error
            self.badgeColor = [NSColor colorWithRed:0.9 green:0.25 blue:0.25 alpha:1.0];
            break;
        default: // Stopped
            self.badgeColor = [NSColor tertiaryLabelColor];
            break;
    }
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    // Draw dot
    NSRect dotRect = NSMakeRect(0, (self.bounds.size.height - 8) / 2, 8, 8);
    NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:dotRect];
    [self.badgeColor setFill];
    [dot fill];

    // Draw text
    if (self.badgeText.length > 0) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
        };
        NSSize textSize = [self.badgeText sizeWithAttributes:attrs];
        NSPoint textOrigin = NSMakePoint(14, (self.bounds.size.height - textSize.height) / 2);
        [self.badgeText drawAtPoint:textOrigin withAttributes:attrs];
    }
}

@end

#pragma mark - VMStartModeSwitcher

@implementation VMStartModeSwitcher {
    NSPopUpButton *_popupButton;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _currentMode = VMStartAppModeStandard;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 6;
        self.layer.backgroundColor = [[NSColor controlBackgroundColor] colorWithAlphaComponent:0.5].CGColor;

        // Use NSPopUpButton - compact width to not block toolbar buttons
        _popupButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(8, 4, 100, frame.size.height - 8) pullsDown:NO];
        [_popupButton addItemWithTitle:@"Simple"];
        [_popupButton addItemWithTitle:@"Standard"];
        [_popupButton addItemWithTitle:@"Advanced"];
        [_popupButton selectItemAtIndex:1]; // Standard
        _popupButton.target = self;
        _popupButton.action = @selector(popupChanged:);
        _popupButton.font = [NSFont systemFontOfSize:12];
        [self addSubview:_popupButton];
    }
    return self;
}

- (void)popupChanged:(NSPopUpButton *)sender {
    self.currentMode = (VMStartAppMode)sender.indexOfSelectedItem;
    if (self.onModeChange) self.onModeChange(self.currentMode);
}

- (void)setCurrentMode:(VMStartAppMode)currentMode {
    _currentMode = currentMode;
    if (_popupButton) {
        [_popupButton selectItemAtIndex:currentMode];
    }
}

@end

#pragma mark - VMStartIconButton

@implementation VMStartIconButton

- (instancetype)initWithSymbol:(NSString *)symbolName size:(CGFloat)size target:(id)target action:(SEL)action {
    self = [super initWithFrame:NSMakeRect(0, 0, size + 8, size + 8)];
    if (self) {
        _symbolName = symbolName;
        _symbolSize = size;
        NSImage *img = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil];
        NSImage *scaled = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
        [scaled lockFocus];
        [img setSize:NSMakeSize(size, size)];
        [img drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, img.size.width, img.size.height) operation:NSCompositingOperationSourceOver fraction:1.0];
        [scaled unlockFocus];
        [self setImage:scaled];
        self.title = @"";
        self.target = target;
        self.action = action;
        self.imagePosition = NSImageOnly;
        self.bezelStyle = NSBezelStyleInline;
        self.imageScaling = NSImageScaleProportionallyDown;
        self.wantsLayer = YES;
    }
    return self;
}

@end

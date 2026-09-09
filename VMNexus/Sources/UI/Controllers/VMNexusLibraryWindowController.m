//
//  VMNexusLibraryWindowController.m
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusLibraryWindowController.h"
#import "VMNexusVirtualMachine.h"
#import "VMNexusArchitectureManager.h"
#import "VMNexusConfigWindowController.h"
#import "VMNexusConsoleWindowController.h"
#import "VMNexusNetworkEditorController.h"
#import "VMNexusLocalization.h"
#import "VMNexusCardView.h"
#import "VMNexusEngineSelector.h"
#import "VMNexusSettingsWindowController.h"

@interface VMNexusLibraryWindowController () <VMNexusConfigDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSMenuDelegate>
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSView *sidebarView;
@property (nonatomic, strong) NSView *mainContentView;
@property (nonatomic, strong) NSView *welcomeView;
@property (nonatomic, strong) NSView *detailsView;
@property (nonatomic, strong) VMNexusConfigWindowController *configWC;
@property (nonatomic, strong) NSMutableDictionary<NSString *, VMNexusConsoleWindowController *> *consoleControllers;
@property (nonatomic, copy) NSArray<VMNexusVirtualMachine *> *filteredVMs;
@property (nonatomic, strong) NSTextField *statusBarLabel;
@property (nonatomic, strong) VMNexusModeSwitcher *modeSwitcher;
@property (nonatomic, assign) VMNexusAppMode appMode;
@property (nonatomic, strong) VMNexusCardView *notesCardRef;
@property (nonatomic, strong) NSView *diskProgressBg;
@property (nonatomic, strong) NSView *diskProgressFill;
@property (nonatomic, strong) NSMenu *contextMenu;
@property (nonatomic, assign) BOOL showFavoritesOnly;
@property (nonatomic, strong) NSButton *favoritesButton;
@property (nonatomic, strong) VMNexusNetworkEditorController *networkEditorWC;
@end

@implementation VMNexusLibraryWindowController

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 1100, 720);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    window.title = @"VMNexus";
    window.minSize = NSMakeSize(900, 600);
    [window center];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.backgroundColor = [NSColor windowBackgroundColor];
    self = [super initWithWindow:window];
    if (self) {
        _virtualMachines = [NSMutableArray array];
        _consoleControllers = [NSMutableDictionary dictionary];
        _vmDirectory = [self defaultVMDirectory];
        _appMode = VMNexusAppModeStandard;
        _showFavoritesOnly = NO;
        [self setupContextMenu];
        [self setupUI];
        [self refreshVMList];
    }
    return self;
}

- (NSString *)defaultVMDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupport = [paths firstObject];
    NSString *vmDir = [appSupport stringByAppendingPathComponent:@"VMNexus/VirtualMachines"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:vmDir]) {
        [fm createDirectoryAtPath:vmDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return vmDir;
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *root = self.window.contentView;
    CGFloat sidebarW = 260;
    CGFloat windowH = root.bounds.size.height;

    // ─── Sidebar (VMware-style clean panel) ───
    self.sidebarView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, sidebarW, windowH)];
    self.sidebarView.wantsLayer = YES;
    self.sidebarView.layer.backgroundColor = [NSColor colorWithRed:0.17 green:0.17 blue:0.20 alpha:1.0].CGColor;
    self.sidebarView.autoresizingMask = NSViewHeightSizable;
    [root addSubview:self.sidebarView];

    // Sidebar right edge line
    NSView *sepLine = [[NSView alloc] initWithFrame:NSMakeRect(sidebarW, 0, 1, windowH)];
    sepLine.wantsLayer = YES;
    sepLine.layer.backgroundColor = [NSColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0].CGColor;
    sepLine.autoresizingMask = NSViewMaxXMargin | NSViewHeightSizable;
    [root addSubview:sepLine];

    // "Devices" header
    NSTextField *sideHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(16, windowH - 36, sidebarW - 32, 20)];
    sideHeader.stringValue = AMLocalizedString(@"sidebar.devices");
    sideHeader.font = [NSFont boldSystemFontOfSize:14];
    sideHeader.textColor = [NSColor colorWithRed:0.85 green:0.85 blue:0.9 alpha:1.0];
    sideHeader.bezeled = NO; sideHeader.drawsBackground = NO; sideHeader.editable = NO;
    sideHeader.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [self.sidebarView addSubview:sideHeader];

    // Search field (dark style)
    self.searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(12, windowH - 66, sidebarW - 24, 26)];
    self.searchField.placeholderString = @"Type here to search...";
    self.searchField.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    self.searchField.delegate = self;
    self.searchField.wantsLayer = YES;
    [self.sidebarView addSubview:self.searchField];

    // "My Computer" section header
    NSTextField *mcHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(16, windowH - 98, sidebarW - 32, 18)];
    mcHeader.stringValue = AMLocalizedString(@"sidebar.myComputer");
    mcHeader.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    mcHeader.textColor = [NSColor colorWithRed:0.55 green:0.55 blue:0.6 alpha:1.0];
    mcHeader.bezeled = NO; mcHeader.drawsBackground = NO; mcHeader.editable = NO;
    mcHeader.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [self.sidebarView addSubview:mcHeader];

    // Favorites filter button (compact)
    self.favoritesButton = [NSButton buttonWithTitle:@"\u2606 Favorites" target:self action:@selector(toggleFavoritesFilter:)];
    self.favoritesButton.frame = NSMakeRect(sidebarW - 100, windowH - 98, 88, 18);
    self.favoritesButton.bezelStyle = NSBezelStyleInline;
    self.favoritesButton.font = [NSFont systemFontOfSize:9 weight:NSFontWeightMedium];
    self.favoritesButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [self.favoritesButton setContentTintColor:[NSColor colorWithRed:0.6 green:0.6 blue:0.65 alpha:1.0]];
    [self.sidebarView addSubview:self.favoritesButton];

    // VM list
    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 80, sidebarW, windowH - 98 - 80)];
    self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.drawsBackground = NO;
    self.scrollView.autohidesScrollers = YES;

    self.tableView = [[NSTableView alloc] initWithFrame:self.scrollView.bounds];
    self.tableView.headerView = nil;
    self.tableView.rowHeight = 60;
    self.tableView.intercellSpacing = NSMakeSize(0, 2);
    self.tableView.backgroundColor = [NSColor clearColor];
    self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.floatsGroupRows = NO;

    // Drag & drop support
    [self.tableView registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    self.tableView.allowsMultipleSelection = YES;
    self.tableView.menu = self.contextMenu;

    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"vm"];
    col.width = sidebarW - 4;
    col.resizingMask = NSTableColumnAutoresizingMask;
    [self.tableView addTableColumn:col];

    self.scrollView.documentView = self.tableView;
    [self.sidebarView addSubview:self.scrollView];

    // Sidebar bottom toolbar (dark style)
    NSView *sidebarToolbar = [[NSView alloc] initWithFrame:NSMakeRect(0, 40, sidebarW, 40)];
    sidebarToolbar.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    sidebarToolbar.wantsLayer = YES;
    sidebarToolbar.layer.backgroundColor = [NSColor colorWithRed:0.14 green:0.14 blue:0.17 alpha:1.0].CGColor;
    [self.sidebarView addSubview:sidebarToolbar];

    // Bottom toolbar - only mode switcher (dropdown)
    NSColor *btnColor = [NSColor colorWithRed:0.7 green:0.7 blue:0.75 alpha:1.0];
    self.modeSwitcher = [[VMNexusModeSwitcher alloc] initWithFrame:NSMakeRect(8, 8, 100, 24)];
    self.modeSwitcher.currentMode = self.appMode;
    __weak typeof(self) weakSelf = self;
    self.modeSwitcher.onModeChange = ^(VMNexusAppMode mode) {
        weakSelf.appMode = mode;
        [weakSelf updateDetailsForCurrentSelection];
    };
    self.modeSwitcher.autoresizingMask = NSViewMaxYMargin;
    [sidebarToolbar addSubview:self.modeSwitcher];

    // Settings button (top-right corner)
    NSButton *settingsBtn = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:nil]
                                              target:self action:@selector(openSettings:)];
    settingsBtn.frame = NSMakeRect(sidebarW - 36, 8, 28, 24);
    settingsBtn.bezelStyle = NSBezelStyleInline;
    settingsBtn.imageScaling = NSImageScaleProportionallyDown;
    [settingsBtn setContentTintColor:btnColor];
    settingsBtn.toolTip = AMLocalizedString(@"detail.settings");
    [sidebarToolbar addSubview:settingsBtn];

    // ─── Main content (white background like VMware) ───
    self.mainContentView = [[NSView alloc] initWithFrame:NSMakeRect(sidebarW + 1, 0, root.bounds.size.width - sidebarW - 1, windowH)];
    self.mainContentView.wantsLayer = YES;
    self.mainContentView.layer.backgroundColor = [NSColor whiteColor].CGColor;
    self.mainContentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:self.mainContentView];

    [self setupWelcomeView];
    [self setupDetailsView];
    [self updateContentVisibility];

    // Status bar
    self.statusBarLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(sidebarW + 16, 6, root.bounds.size.width - sidebarW - 32, 16)];
    self.statusBarLabel.font = [NSFont systemFontOfSize:10];
    self.statusBarLabel.bezeled = NO; self.statusBarLabel.drawsBackground = NO; self.statusBarLabel.editable = NO;
    self.statusBarLabel.textColor = [NSColor colorWithRed:0.5 green:0.5 blue:0.55 alpha:1.0];
    self.statusBarLabel.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [root addSubview:self.statusBarLabel];
    [self updateStatusBar];
}

#pragma mark - Welcome View (Empty State)

- (void)setupWelcomeView {
    self.welcomeView = [[NSView alloc] initWithFrame:self.mainContentView.bounds];
    self.welcomeView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.welcomeView.wantsLayer = YES;

    // ─── Large title "AIRVM" ───
    NSTextField *bigTitle = [[NSTextField alloc] initWithFrame:NSZeroRect];
    bigTitle.stringValue = @"AIRVM";
    bigTitle.font = [NSFont systemFontOfSize:42 weight:NSFontWeightBold];
    bigTitle.alignment = NSTextAlignmentCenter;
    bigTitle.textColor = [NSColor colorWithRed:0.25 green:0.25 blue:0.3 alpha:1.0];
    bigTitle.bezeled = NO; bigTitle.drawsBackground = NO; bigTitle.editable = NO;
    bigTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.welcomeView addSubview:bigTitle];

    // Subtitle
    NSTextField *subTitle = [[NSTextField alloc] initWithFrame:NSZeroRect];
    subTitle.stringValue = AMLocalizedString(@"app_subtitle");
    subTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightLight];
    subTitle.alignment = NSTextAlignmentCenter;
    subTitle.textColor = [NSColor colorWithRed:0.55 green:0.55 blue:0.6 alpha:1.0];
    subTitle.bezeled = NO; subTitle.drawsBackground = NO; subTitle.editable = NO;
    subTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.welcomeView addSubview:subTitle];

    // ─── Three action cards (VMware WS style) - scale with window ───
    CGFloat cardW = 200;
    CGFloat cardH = 180;
    CGFloat spacing = 32;
    CGFloat totalW = cardW * 3 + spacing * 2;
    CGFloat startX = (self.welcomeView.bounds.size.width - totalW) / 2;
    CGFloat cardY = self.welcomeView.bounds.size.height / 2 - cardH / 2 - 20;

    NSArray *cards = @[
        @{@"icon": @"plus.circle", @"text": AMLocalizedString(@"welcome.createVM"), @"sel": @"addVM:", @"tint": [NSColor colorWithRed:0.35 green:0.55 blue:0.85 alpha:1.0]},
        @{@"icon": @"folder", @"text": AMLocalizedString(@"welcome.openVM"), @"sel": @"openExistingVM:", @"tint": [NSColor colorWithRed:0.45 green:0.65 blue:0.35 alpha:1.0]},
        @{@"icon": @"arrow.triangle.2.circlepath", @"text": AMLocalizedString(@"welcome.connectRemote"), @"sel": @"connectRemote:", @"tint": [NSColor colorWithRed:0.65 green:0.45 blue:0.75 alpha:1.0]},
    ];

    for (NSInteger i = 0; i < cards.count; i++) {
        CGFloat x = startX + i * (cardW + spacing);
        NSView *card = [[NSView alloc] initWithFrame:NSMakeRect(x, cardY, cardW, cardH)];
        card.wantsLayer = YES;
        card.layer.cornerRadius = 14;
        card.layer.backgroundColor = [NSColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0].CGColor;
        card.layer.borderWidth = 1;
        card.layer.borderColor = [NSColor colorWithRed:0.88 green:0.88 blue:0.9 alpha:1.0].CGColor;
        card.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin;

        // Icon circle (larger)
        NSView *iconBg = [[NSView alloc] initWithFrame:NSMakeRect((cardW - 64) / 2, cardH - 85, 64, 64)];
        iconBg.wantsLayer = YES;
        iconBg.layer.cornerRadius = 32;
        iconBg.layer.backgroundColor = [(NSColor *)cards[i][@"tint"] CGColor];
        [card addSubview:iconBg];

        NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(16, 16, 32, 32)];
        iconView.image = [NSImage imageWithSystemSymbolName:cards[i][@"icon"] accessibilityDescription:nil];
        iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
        [iconView setContentTintColor:[NSColor whiteColor]];
        [iconBg addSubview:iconView];

        // Text label
        NSTextField *textLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(12, 16, cardW - 24, 55)];
        textLabel.stringValue = cards[i][@"text"];
        textLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        textLabel.textColor = [NSColor colorWithRed:0.3 green:0.3 blue:0.35 alpha:1.0];
        textLabel.alignment = NSTextAlignmentCenter;
        textLabel.bezeled = NO; textLabel.drawsBackground = NO; textLabel.editable = NO;
        textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [card addSubview:textLabel];

        // Make it clickable (button overlay)
        NSButton *cardBtn = [NSButton buttonWithTitle:@"" target:self action:NSSelectorFromString(cards[i][@"sel"])];
        cardBtn.bezelStyle = NSBezelStyleRegularSquare;
        cardBtn.frame = card.bounds;
        cardBtn.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        cardBtn.wantsLayer = YES;
        cardBtn.layer.backgroundColor = [NSColor clearColor].CGColor;
        cardBtn.layer.borderWidth = 0;
        cardBtn.alphaValue = 0.001; // invisible but clickable
        [card addSubview:cardBtn];

        [self.welcomeView addSubview:card];
    }

    // Brand footer
    NSTextField *brand = [[NSTextField alloc] initWithFrame:NSZeroRect];
    brand.stringValue = @"VMNexus";
    brand.font = [NSFont systemFontOfSize:11 weight:NSFontWeightLight];
    brand.textColor = [NSColor colorWithRed:0.7 green:0.7 blue:0.75 alpha:1.0];
    brand.bezeled = NO; brand.drawsBackground = NO; brand.editable = NO;
    brand.translatesAutoresizingMaskIntoConstraints = NO;
    [self.welcomeView addSubview:brand];

    [NSLayoutConstraint activateConstraints:@[
        [bigTitle.centerXAnchor constraintEqualToAnchor:self.welcomeView.centerXAnchor],
        [bigTitle.topAnchor constraintEqualToAnchor:self.welcomeView.topAnchor constant:60],
        [subTitle.centerXAnchor constraintEqualToAnchor:self.welcomeView.centerXAnchor],
        [subTitle.topAnchor constraintEqualToAnchor:bigTitle.bottomAnchor constant:4],
        [brand.centerXAnchor constraintEqualToAnchor:self.welcomeView.centerXAnchor],
        [brand.bottomAnchor constraintEqualToAnchor:self.welcomeView.bottomAnchor constant:-28],
    ]];

    [self.mainContentView addSubview:self.welcomeView];
}

- (void)connectRemote:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Connect to Remote Server";
    alert.informativeText = @"Enter the remote server address (SSH or VNC).";
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
    input.placeholderString = @"user@host or vnc://host";
    alert.accessoryView = input;
    [alert addButtonWithTitle:@"Connect"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

#pragma mark - Details View

- (void)setupDetailsView {
    self.detailsView = [[NSView alloc] initWithFrame:self.mainContentView.bounds];
    self.detailsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.detailsView.hidden = YES;
    self.detailsView.wantsLayer = YES;
    self.detailsView.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;

    CGFloat dw = self.detailsView.bounds.size.width;
    CGFloat dh = self.detailsView.bounds.size.height;

    // ─── Header area (Fusion-style, light gray bar) ───
    NSView *header = [[NSView alloc] initWithFrame:NSMakeRect(0, dh - 120, dw, 120)];
    header.wantsLayer = YES;
    header.layer.backgroundColor = [NSColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0].CGColor;
    header.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [self.detailsView addSubview:header];

    // Bottom border line
    NSView *hdrLine = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, dw, 1)];
    hdrLine.wantsLayer = YES;
    hdrLine.layer.backgroundColor = [NSColor colorWithRed:0.82 green:0.82 blue:0.84 alpha:1.0].CGColor;
    hdrLine.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [header addSubview:hdrLine];

    // OS icon (72x72)
    NSImageView *osIconView = [[NSImageView alloc] initWithFrame:NSMakeRect(24, 24, 72, 72)];
    osIconView.image = [NSImage imageWithSystemSymbolName:@"desktopcomputer" accessibilityDescription:nil];
    osIconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    osIconView.autoresizingMask = NSViewMaxXMargin;
    osIconView.tag = 50;
    [header addSubview:osIconView];

    // VM name
    NSTextField *nameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(112, 76, dw - 360, 28)];
    nameLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightBold];
    nameLabel.textColor = [NSColor labelColor];
    nameLabel.bezeled = NO; nameLabel.drawsBackground = NO; nameLabel.editable = NO;
    nameLabel.autoresizingMask = NSViewWidthSizable;
    nameLabel.tag = 1;
    [header addSubview:nameLabel];

    // OS name label
    NSTextField *osLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(112, 54, 200, 16)];
    osLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    osLabel.textColor = [NSColor secondaryLabelColor];
    osLabel.bezeled = NO; osLabel.drawsBackground = NO; osLabel.editable = NO;
    osLabel.autoresizingMask = NSViewMaxXMargin;
    osLabel.tag = 4;
    [header addSubview:osLabel];

    // Architecture badge
    NSTextField *archBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(112, 30, 120, 18)];
    archBadge.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightMedium];
    archBadge.textColor = [NSColor whiteColor];
    archBadge.bezeled = NO; archBadge.editable = NO;
    archBadge.wantsLayer = YES;
    archBadge.layer.backgroundColor = [NSColor colorWithRed:0.35 green:0.55 blue:0.85 alpha:1.0].CGColor;
    archBadge.layer.cornerRadius = 9;
    archBadge.drawsBackground = YES;
    archBadge.backgroundColor = [NSColor colorWithRed:0.35 green:0.55 blue:0.85 alpha:1.0];
    archBadge.alignment = NSTextAlignmentCenter;
    archBadge.autoresizingMask = NSViewMaxXMargin;
    archBadge.tag = 2;
    [header addSubview:archBadge];

    // Status badge
    NSTextField *statusBadge = [[NSTextField alloc] initWithFrame:NSMakeRect(240, 30, 90, 18)];
    statusBadge.font = [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold];
    statusBadge.textColor = [NSColor whiteColor];
    statusBadge.bezeled = NO; statusBadge.editable = NO;
    statusBadge.wantsLayer = YES;
    statusBadge.layer.cornerRadius = 9;
    statusBadge.alignment = NSTextAlignmentCenter;
    statusBadge.autoresizingMask = NSViewMaxXMargin;
    statusBadge.tag = 3;
    [header addSubview:statusBadge];

    // Action buttons (right side)
    NSButton *startBtn = [NSButton buttonWithTitle:AMLocalizedString(@"detail.start") target:self action:@selector(startVM:)];
    startBtn.bezelStyle = NSBezelStyleRounded;
    startBtn.frame = NSMakeRect(dw - 130, 78, 110, 30);
    startBtn.autoresizingMask = NSViewMinXMargin;
    startBtn.bezelColor = [NSColor colorWithRed:0.25 green:0.7 blue:0.35 alpha:1.0];
    startBtn.image = [NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:nil];
    startBtn.imagePosition = NSImageLeading;
    startBtn.tag = 10;
    [header addSubview:startBtn];

    NSButton *editBtn = [NSButton buttonWithTitle:AMLocalizedString(@"detail.settings") target:self action:@selector(editVM:)];
    editBtn.bezelStyle = NSBezelStyleRounded;
    editBtn.frame = NSMakeRect(dw - 130, 40, 110, 30);
    editBtn.autoresizingMask = NSViewMinXMargin;
    editBtn.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:nil];
    editBtn.imagePosition = NSImageLeading;
    [header addSubview:editBtn];

    // ─── "HARDWARE" section title ───
    NSTextField *hwTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(24, dh - 150, 200, 18)];
    hwTitle.stringValue = AMLocalizedString(@"detail.hardware");
    hwTitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightBold];
    hwTitle.textColor = [NSColor secondaryLabelColor];
    hwTitle.bezeled = NO; hwTitle.drawsBackground = NO; hwTitle.editable = NO;
    hwTitle.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [self.detailsView addSubview:hwTitle];

    // ─── Fusion-style hardware rows ───
    NSArray *hwItems = @[
        @{@"icon": @"cpu",              @"label": AMLocalizedString(@"detail.processor"),  @"tag": @(100)},
        @{@"icon": @"memorychip",       @"label": AMLocalizedString(@"detail.memory"),     @"tag": @(101)},
        @{@"icon": @"internaldrive",    @"label": AMLocalizedString(@"detail.hardDisk"),  @"tag": @(102)},
        @{@"icon": @"network",          @"label": AMLocalizedString(@"detail.network"),    @"tag": @(103)},
        @{@"icon": @"display",          @"label": AMLocalizedString(@"detail.display"),    @"tag": @(104)},
        @{@"icon": @"speaker.wave.2",   @"label": AMLocalizedString(@"detail.soundCard"), @"tag": @(105)},
        @{@"icon": @"usb.symbol",       @"label": AMLocalizedString(@"detail.usb"),        @"tag": @(106)},
        @{@"icon": @"speedometer",      @"label": AMLocalizedString(@"detail.acceleration"), @"tag": @(108)},
        @{@"icon": @"info.circle",      @"label": AMLocalizedString(@"detail.engine"),     @"tag": @(107)},
    ];

    CGFloat rowH = 44;
    CGFloat startY = dh - 214; // 9 rows * 44px + offset
    CGFloat rowW = dw - 48;
    for (NSInteger i = 0; i < hwItems.count; i++) {
        CGFloat y = startY - i * rowH;
        // Row background
        NSView *row = [[NSView alloc] initWithFrame:NSMakeRect(24, y, rowW, rowH)];
        row.wantsLayer = YES;
        row.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
        [self.detailsView addSubview:row];

        // Separator line at bottom
        NSView *sep = [[NSView alloc] initWithFrame:NSMakeRect(36, 0, rowW - 36, 1)];
        sep.wantsLayer = YES;
        sep.layer.backgroundColor = [NSColor separatorColor].CGColor;
        sep.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
        [row addSubview:sep];

        // Icon
        NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 10, 24, 24)];
        icon.image = [NSImage imageWithSystemSymbolName:hwItems[i][@"icon"] accessibilityDescription:nil];
        icon.imageScaling = NSImageScaleProportionallyUpOrDown;
        [icon setContentTintColor:[NSColor colorWithRed:0.4 green:0.4 blue:0.45 alpha:1.0]];
        [row addSubview:icon];

        // Label
        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(36, 12, 100, 18)];
        label.stringValue = hwItems[i][@"label"];
        label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        label.textColor = [NSColor labelColor];
        label.bezeled = NO; label.drawsBackground = NO; label.editable = NO;
        [row addSubview:label];

        // Value (right-aligned)
        NSTextField *value = [[NSTextField alloc] initWithFrame:NSMakeRect(140, 12, rowW - 150, 18)];
        value.font = [NSFont systemFontOfSize:13];
        value.textColor = [NSColor secondaryLabelColor];
        value.bezeled = NO; value.drawsBackground = NO; value.editable = NO;
        value.alignment = NSTextAlignmentRight;
        value.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
        value.tag = [hwItems[i][@"tag"] integerValue];
        [row addSubview:value];

        // Disk usage progress bar (only for Hard Disk row, tag=102)
        if ([hwItems[i][@"tag"] integerValue] == 102) {
            NSView *progressBg = [[NSView alloc] initWithFrame:NSMakeRect(140, 8, rowW - 280, 8)];
            progressBg.wantsLayer = YES;
            progressBg.layer.cornerRadius = 4;
            progressBg.layer.backgroundColor = [NSColor colorWithRed:0.9 green:0.9 blue:0.92 alpha:1.0].CGColor;
            progressBg.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
            self.diskProgressBg = progressBg;
            [row addSubview:progressBg];

            NSView *progressFill = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 8)];
            progressFill.wantsLayer = YES;
            progressFill.layer.cornerRadius = 4;
            progressFill.layer.backgroundColor = [NSColor colorWithRed:0.3 green:0.65 blue:0.95 alpha:1.0].CGColor;
            self.diskProgressFill = progressFill;
            [progressBg addSubview:progressFill];
        }
    }

    // ─── Notes section (bottom) ───
    VMNexusCardView *notesCard = [[VMNexusCardView alloc] initWithFrame:NSMakeRect(24, 20, dw - 48, 70)];
    notesCard.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    notesCard.cornerRadius = 10;
    self.notesCardRef = notesCard;
    [self.detailsView addSubview:notesCard];

    NSTextField *notesTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 48, 80, 14)];
    notesTitle.stringValue = AMLocalizedString(@"detail.notes");
    notesTitle.font = [NSFont systemFontOfSize:10 weight:NSFontWeightBold];
    notesTitle.textColor = [NSColor secondaryLabelColor];
    notesTitle.bezeled = NO; notesTitle.drawsBackground = NO; notesTitle.editable = NO;
    [notesCard addSubview:notesTitle];

    NSTextField *notesValue = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 12, notesCard.bounds.size.width - 28, 30)];
    notesValue.font = [NSFont systemFontOfSize:11];
    notesValue.textColor = [NSColor textColor];
    notesValue.bezeled = NO; notesValue.drawsBackground = NO; notesValue.editable = NO;
    notesValue.tag = 201;
    notesValue.lineBreakMode = NSLineBreakByWordWrapping;
    [notesCard addSubview:notesValue];

    [self.mainContentView addSubview:self.detailsView];

    // Keyboard shortcut: Command+, (macOS) or Ctrl+, (Windows/Linux)
    [self.window makeFirstResponder:self];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    // Check for Command+, or Ctrl+,
    if ((event.modifierFlags & NSEventModifierFlagCommand) || (event.modifierFlags & NSEventModifierFlagControl)) {
        if ([event.characters isEqualToString:@","]) {
            [self openSettings:nil];
            return;
        }
    }
    [super keyDown:event];
}

- (void)updateContentVisibility {
    NSInteger row = self.tableView.selectedRow;
    BOOL hasSelection = row >= 0 && row < (NSInteger)[self visibleVMs].count;
    self.welcomeView.hidden = hasSelection;
    self.detailsView.hidden = !hasSelection;
    if (hasSelection) {
        [self updateDetailsForVM:[self visibleVMs][row]];
    }
}

- (void)updateDetailsForCurrentSelection {
    NSInteger row = self.tableView.selectedRow;
    if (row >= 0 && row < (NSInteger)[self visibleVMs].count) {
        [self updateDetailsForVM:[self visibleVMs][row]];
    }
}

#pragma mark - Table View

- (NSArray<VMNexusVirtualMachine *> *)visibleVMs {
    NSArray *vms = self.filteredVMs ?: self.virtualMachines;
    if (self.showFavoritesOnly) {
        NSMutableArray *favs = [NSMutableArray array];
        for (VMNexusVirtualMachine *vm in vms) {
            if (vm.isFavorite) [favs addObject:vm];
        }
        return favs;
    }
    return vms;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    return [self visibleVMs].count;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tc row:(NSInteger)row {
    NSTableCellView *cell = [tv makeViewWithIdentifier:@"vmCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tc.width, 60)];
        cell.identifier = @"vmCell";

        // Icon background (rounded square, UTM style)
        NSView *iconBg = [[NSView alloc] initWithFrame:NSMakeRect(12, 10, 40, 40)];
        iconBg.wantsLayer = YES;
        iconBg.layer.cornerRadius = 8;
        iconBg.layer.backgroundColor = [NSColor colorWithRed:0.22 green:0.22 blue:0.26 alpha:1.0].CGColor;
        [cell addSubview:iconBg];

        // OS icon (larger, UTM style)
        NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 4, 32, 32)];
        iv.image = [NSImage imageWithSystemSymbolName:@"desktopcomputer" accessibilityDescription:nil];
        iv.imageScaling = NSImageScaleProportionallyUpOrDown;
        [iv setContentTintColor:[NSColor colorWithRed:0.75 green:0.75 blue:0.8 alpha:1.0]];
        iv.tag = 12;
        [iconBg addSubview:iv];

        // Status dot (8px, on icon corner)
        NSTextField *dot = [[NSTextField alloc] initWithFrame:NSMakeRect(42, 10, 8, 8)];
        dot.wantsLayer = YES;
        dot.layer.cornerRadius = 4;
        dot.bordered = NO;
        dot.editable = NO;
        dot.tag = 10;
        [cell addSubview:dot];

        // Name (light text for dark bg)
        NSTextField *nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(62, 32, tc.width - 74, 18)];
        nameField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        nameField.textColor = [NSColor colorWithRed:0.9 green:0.9 blue:0.95 alpha:1.0];
        nameField.bezeled = NO; nameField.drawsBackground = NO; nameField.editable = NO;
        nameField.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textField = nameField;
        [cell addSubview:nameField];

        // Subtitle (arch)
        NSTextField *subField = [[NSTextField alloc] initWithFrame:NSMakeRect(62, 12, tc.width - 130, 16)];
        subField.font = [NSFont systemFontOfSize:10 weight:NSFontWeightRegular];
        subField.bezeled = NO; subField.drawsBackground = NO; subField.editable = NO;
        subField.textColor = [NSColor colorWithRed:0.5 green:0.5 blue:0.55 alpha:1.0];
        subField.tag = 100;
        subField.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:subField];

        // Status label (right-aligned, colored)
        NSTextField *statusField = [[NSTextField alloc] initWithFrame:NSMakeRect(tc.width - 66, 12, 56, 16)];
        statusField.font = [NSFont systemFontOfSize:9 weight:NSFontWeightMedium];
        statusField.bezeled = NO; statusField.drawsBackground = NO; statusField.editable = NO;
        statusField.alignment = NSTextAlignmentRight;
        statusField.tag = 101;
        statusField.autoresizingMask = NSViewMinXMargin;
        [cell addSubview:statusField];
    }

    VMNexusVirtualMachine *vm = [self visibleVMs][row];
    cell.textField.stringValue = vm.name;

    // Update OS icon (UTM style)
    NSImageView *osIconView = [cell viewWithTag:12];
    if (osIconView) {
        osIconView.image = vm.osIcon;
        [osIconView setContentTintColor:nil]; // Use original colors
    }

    // Update subtitle: OS name + arch
    NSTextField *sub = [cell viewWithTag:100];
    sub.stringValue = [NSString stringWithFormat:@"%@ • %@", vm.osDisplayName, vm.architectureDisplayName];

    NSTextField *statusLbl = [cell viewWithTag:101];
    statusLbl.stringValue = vm.statusDisplayName;
    statusLbl.textColor = [self statusColorForVM:vm];

    NSView *dot = [cell viewWithTag:10];
    dot.layer.backgroundColor = [self statusColorForVM:vm].CGColor;

    return cell;
}

- (NSColor *)statusColorForVM:(VMNexusVirtualMachine *)vm {
    switch (vm.status) {
        case VMNexusStatusRunning: return [NSColor colorWithRed:0.25 green:0.75 blue:0.35 alpha:1.0];
        case VMNexusStatusPaused: return [NSColor colorWithRed:0.95 green:0.65 blue:0.1 alpha:1.0];
        case VMNexusStatusStarting: return [NSColor colorWithRed:0.2 green:0.55 blue:0.95 alpha:1.0];
        case VMNexusStatusError: return [NSColor colorWithRed:0.9 green:0.25 blue:0.25 alpha:1.0];
        default: return [NSColor tertiaryLabelColor];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updateContentVisibility];
    [self updateStatusBar];
}

- (void)updateDetailsForVM:(VMNexusVirtualMachine *)vm {
    NSTextField *nameLabel = [self.detailsView viewWithTag:1];
    NSTextField *archBadge = [self.detailsView viewWithTag:2];
    NSTextField *statusBadge = [self.detailsView viewWithTag:3];
    NSTextField *osLabel = [self.detailsView viewWithTag:4];
    NSImageView *osIconView = [self.detailsView viewWithTag:50];

    nameLabel.stringValue = vm.name;
    archBadge.stringValue = [NSString stringWithFormat:@"  %@  ", vm.architectureDisplayName];

    statusBadge.stringValue = [NSString stringWithFormat:@"  %@  ", vm.statusDisplayName];
    statusBadge.backgroundColor = [self statusColorForVM:vm];
    statusBadge.layer.backgroundColor = [self statusColorForVM:vm].CGColor;

    // OS info
    if (osLabel) osLabel.stringValue = vm.osDisplayName;
    if (osIconView) osIconView.image = vm.osIcon;

    // Hardware info (Fusion-style rows)
    NSString *cpu = [NSString stringWithFormat:@"%@, %ld core%@", vm.cpuModel ?: @"default", (long)vm.cpuCores, vm.cpuCores > 1 ? @"s" : @""];
    NSString *mem = [NSString stringWithFormat:@"%ld %@", (long)vm.memoryValue, vm.memoryUnit ?: @"MB"];
    NSString *disk = [vm.diskSizeUnit isEqualToString:@"none"] ? @"No disk" : [NSString stringWithFormat:@"%ld %@", (long)vm.diskSizeValue, vm.diskSizeUnit ?: @"GB"];
    NSString *net = vm.networkMode ?: @"NAT";
    NSString *disp = vm.displayType ?: @"cocoa";
    NSString *sound = vm.enableSoundCard ? (vm.soundCardModel ?: @"Intel HDA") : @"Disabled";
    NSString *usb = vm.enableUSB ? vm.usbVersion : @"Disabled";
    
    // Acceleration mode
    NSString *accel = AMLocalizedString(@"detail.accelDisabled");
    if (vm.enableAcceleration) {
        if ([vm isAppleSiliconHost] && (vm.architecture == VMNexusArchAArch64 || vm.architecture == VMNexusArchX86_64)) {
            accel = AMLocalizedString(@"detail.accelHVF");
        } else {
            accel = AMLocalizedString(@"detail.accelTCG");
        }
    }
    
    VMNexusEngineType engineType = [VMNexusEngineSelector engineTypeForMachine:vm.machineType];
    NSString *engine = [VMNexusEngineSelector nameForEngineType:engineType];

    // Order matches hwItems array: Processor, Memory, Hard Disk, Network, Display, Sound Card, USB, Acceleration, Engine
    NSArray *values = @[cpu, mem, disk, net, disp, sound, usb ?: @"Disabled", accel, engine ?: @"QEMU"];
    for (NSInteger i = 0; i < values.count; i++) {
        NSTextField *tf = [self.detailsView viewWithTag:100 + i];
        if (tf) tf.stringValue = values[i];
    }

    // Update disk usage progress bar
    if (self.diskProgressBg && self.diskProgressFill) {
        CGFloat percent = [vm diskUsagePercent];
        if (percent > 0) {
            CGFloat fillWidth = self.diskProgressBg.bounds.size.width * percent;
            self.diskProgressFill.frame = NSMakeRect(0, 0, fillWidth, 8);
            self.diskProgressBg.hidden = NO;
            self.diskProgressFill.hidden = NO;
            // Update disk label to show usage
            NSTextField *diskLabel = [self.detailsView viewWithTag:102];
            if (diskLabel) {
                NSInteger usedMB = [vm diskUsedBytes] / (1024 * 1024);
                NSInteger totalMB = [vm diskTotalBytes] / (1024 * 1024);
                diskLabel.stringValue = [NSString stringWithFormat:@"%@ (%ld/%ld MB used)", disk, (long)usedMB, (long)totalMB];
            }
        } else {
            self.diskProgressBg.hidden = YES;
            self.diskProgressFill.hidden = YES;
        }
    }

    // Start/Stop button
    NSButton *startBtn = [self.detailsView viewWithTag:10];
    if (vm.status == VMNexusStatusRunning) {
        startBtn.title = AMLocalizedString(@"detail.stop");
        startBtn.image = [NSImage imageWithSystemSymbolName:@"stop.fill" accessibilityDescription:nil];
        startBtn.bezelColor = [NSColor systemRedColor];
    } else {
        startBtn.title = AMLocalizedString(@"detail.start");
        startBtn.image = [NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:nil];
        startBtn.bezelColor = [NSColor colorWithRed:0.25 green:0.7 blue:0.35 alpha:1.0];
    }

    // Notes
    NSTextField *notesVal = [self.detailsView viewWithTag:201];
    if (notesVal) {
        notesVal.stringValue = vm.notes ?: AMLocalizedString(@"detail.noNotes");
    }

    // Hide/show notes card based on mode
    if (self.notesCardRef) self.notesCardRef.hidden = (self.appMode == VMNexusAppModeSimple);
}

#pragma mark - Search

- (void)controlTextDidChange:(NSNotification *)obj {
    [self applyFilters];
}

- (void)applyFilters {
    NSString *query = self.searchField.stringValue.lowercaseString;
    BOOL hasQuery = query.length > 0;
    
    if (!hasQuery) {
        self.filteredVMs = nil;
    } else {
        NSMutableArray *arr = [NSMutableArray array];
        for (VMNexusVirtualMachine *vm in self.virtualMachines) {
            BOOL match = [vm.name.lowercaseString containsString:query] ||
                         [vm.architectureDisplayName.lowercaseString containsString:query] ||
                         [vm.osDisplayName.lowercaseString containsString:query] ||
                         [vm.statusDisplayName.lowercaseString containsString:query];
            if (match) [arr addObject:vm];
        }
        self.filteredVMs = arr;
    }
    [self.tableView reloadData];
    [self updateContentVisibility];
}

#pragma mark - Batch Operations

- (NSArray<VMNexusVirtualMachine *> *)selectedVMs {
    NSIndexSet *rows = self.tableView.selectedRowIndexes;
    NSMutableArray *vms = [NSMutableArray array];
    NSArray *visible = [self visibleVMs];
    [rows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (idx < visible.count) [vms addObject:visible[idx]];
    }];
    return vms;
}

- (void)batchStart:(id)sender {
    for (VMNexusVirtualMachine *vm in [self selectedVMs]) {
        if (vm.status != VMNexusStatusRunning) [self launchVM:vm];
    }
}

- (void)batchStop:(id)sender {
    for (VMNexusVirtualMachine *vm in [self selectedVMs]) {
        if (vm.status == VMNexusStatusRunning) [self stopVM:vm];
    }
}

- (void)batchDelete:(id)sender {
    NSArray *vms = [self selectedVMs];
    if (vms.count == 0) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Delete %lu Virtual Machine%@?", (unsigned long)vms.count, vms.count > 1 ? @"s" : @""];
    alert.informativeText = @"The selected VMs will be moved to Trash.";
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        for (VMNexusVirtualMachine *vm in vms) {
            NSURL *bundleURL = [NSURL fileURLWithPath:vm.vmBundlePath];
            [[NSWorkspace sharedWorkspace] recycleURLs:@[bundleURL] completionHandler:nil];
            [self.virtualMachines removeObject:vm];
        }
        self.filteredVMs = nil;
        [self.tableView reloadData];
        [self updateContentVisibility];
        [self updateStatusBar];
    }
}

- (void)launchVM:(VMNexusVirtualMachine *)vm {
    // Placeholder - actual launch logic is in startVM/console
    vm.status = VMNexusStatusRunning;
    [self.tableView reloadData];
}

- (void)stopVM:(VMNexusVirtualMachine *)vm {
    vm.status = VMNexusStatusStopped;
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)addVM:(id)sender {
    VMNexusVirtualMachine *vm = [VMNexusVirtualMachine virtualMachineWithName:@"New Virtual Machine" architecture:VMNexusArchX86_64];
    NSString *vmPath = [self.vmDirectory stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"%@.vmnexus", vm.vmIdentifier]];
    vm.vmBundlePath = vmPath;
    self.configWC = [[VMNexusConfigWindowController alloc] initWithVM:vm isNew:YES];
    self.configWC.delegate = self;
    [self.window beginSheet:self.configWC.window completionHandler:nil];
}

- (void)openExistingVM:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = YES;
    panel.allowedContentTypes = @[];
    panel.title = @"Open Virtual Machine";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            for (NSURL *url in panel.URLs) {
                if ([url.pathExtension isEqualToString:@"vmnexus"]) {
                    VMNexusVirtualMachine *vm = [[VMNexusVirtualMachine alloc] init];
                    if ([vm loadFromBundle:url.path]) {
                        NSString *destPath = [self.vmDirectory stringByAppendingPathComponent:url.lastPathComponent];
                        if (![destPath isEqualToString:url.path]) {
                            [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:destPath error:nil];
                            vm.vmBundlePath = destPath;
                        }
                        [self.virtualMachines addObject:vm];
                    }
                }
            }
            [self sortVMs];
            [self.tableView reloadData];
            [self updateContentVisibility];
            [self updateStatusBar];
        }
    }];
}

- (void)removeVM:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)[self visibleVMs].count) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Virtual Machine?";
    alert.informativeText = @"The virtual machine will be moved to Trash.";
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        VMNexusVirtualMachine *vm = [self visibleVMs][row];
        NSURL *bundleURL = [NSURL fileURLWithPath:vm.vmBundlePath];
        [[NSWorkspace sharedWorkspace] recycleURLs:@[bundleURL] completionHandler:nil];
        [self.virtualMachines removeObject:vm];
        self.filteredVMs = nil;
        [self.tableView reloadData];
        [self updateContentVisibility];
        [self updateStatusBar];
    }
}

- (void)editVM:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)[self visibleVMs].count) return;
    VMNexusVirtualMachine *vm = [self visibleVMs][row];
    self.configWC = [[VMNexusConfigWindowController alloc] initWithVM:vm isNew:NO];
    self.configWC.delegate = self;
    [self.window beginSheet:self.configWC.window completionHandler:nil];
}

- (void)openSettings:(id)sender {
    VMNexusSettingsWindowController *settingsWC = [[VMNexusSettingsWindowController alloc] init];
    [settingsWC showWindow:nil];
    [settingsWC.window makeKeyAndOrderFront:nil];
}

- (void)startVM:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)[self visibleVMs].count) return;
    VMNexusVirtualMachine *vm = [self visibleVMs][row];
    NSString *key = vm.vmIdentifier;
    VMNexusConsoleWindowController *console = self.consoleControllers[key];
    if (!console) {
        console = [[VMNexusConsoleWindowController alloc] initWithVM:vm];
        self.consoleControllers[key] = console;
    }
    [console showWindow:nil];
    [console.window makeKeyAndOrderFront:nil];
    [console startVM];
}

- (void)configDidSaveVM:(VMNexusVirtualMachine *)vm {
    [vm saveToBundle];
    NSUInteger idx = NSNotFound;
    for (NSUInteger i = 0; i < self.virtualMachines.count; i++) {
        if ([self.virtualMachines[i].vmIdentifier isEqualToString:vm.vmIdentifier]) {
            idx = i;
            break;
        }
    }
    if (idx == NSNotFound) {
        [self.virtualMachines addObject:vm];
    } else {
        self.virtualMachines[idx] = vm;
    }
    self.filteredVMs = nil;
    [self.tableView reloadData];
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.virtualMachines.count - 1] byExtendingSelection:NO];
    [self updateContentVisibility];
    [self updateStatusBar];
}

#pragma mark - VM List

- (void)refreshVMList {
    [self.virtualMachines removeAllObjects];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:self.vmDirectory error:nil];
    for (NSString *item in contents) {
        if ([item.pathExtension isEqualToString:@"vmnexus"]) {
            NSString *path = [self.vmDirectory stringByAppendingPathComponent:item];
            VMNexusVirtualMachine *vm = [[VMNexusVirtualMachine alloc] init];
            if ([vm loadFromBundle:path]) {
                [self.virtualMachines addObject:vm];
            }
        }
    }
    [self sortVMs];
    self.filteredVMs = nil;
    [self.tableView reloadData];
    [self updateContentVisibility];
    [self updateStatusBar];
}

- (void)updateStatusBar {
    NSString *qemuVer = [[VMNexusArchitectureManager sharedManager] qemuVersionString];
    NSInteger total = self.virtualMachines.count;
    NSInteger running = 0;
    NSInteger favCount = 0;
    for (VMNexusVirtualMachine *vm in self.virtualMachines) {
        if (vm.status == VMNexusStatusRunning) running++;
        if (vm.isFavorite) favCount++;
    }
    NSString *extra = self.showFavoritesOnly ? [NSString stringWithFormat:@" • Showing %ld favorites", (long)favCount] : @"";
    self.statusBarLabel.stringValue = [NSString stringWithFormat:@"%ld VMs (%ld running)%@ • Engine: %@", (long)total, (long)running, extra, qemuVer ?: @"N/A"];
}

#pragma mark - Context Menu

- (void)setupContextMenu {
    self.contextMenu = [[NSMenu alloc] init];
    self.contextMenu.delegate = self;
    // Will be assigned to tableView after setupUI

    [self.contextMenu addItem:[self menuItem:AMLocalizedString(@"detail.start") action:@selector(ctxStart:) icon:@"play.fill"]];
    [self.contextMenu addItem:[self menuItem:AMLocalizedString(@"detail.stop") action:@selector(ctxStop:) icon:@"stop.fill"]];
    [self.contextMenu addItem:[self menuItem:AMLocalizedString(@"status.paused") action:@selector(ctxPause:) icon:@"pause.fill"]];
    [self.contextMenu addItem:[NSMenuItem separatorItem]];
    [self.contextMenu addItem:[self menuItem:[NSString stringWithFormat:@"%@...", AMLocalizedString(@"detail.settings")] action:@selector(ctxEdit:) icon:@"gearshape"]];
    [self.contextMenu addItem:[self menuItem:@"Open Console" action:@selector(ctxOpenConsole:) icon:@"terminal"]];
    [self.contextMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *favItem = [self menuItem:@"Toggle Favorite" action:@selector(ctxToggleFavorite:) icon:@"star"];
    favItem.tag = 999;
    [self.contextMenu addItem:favItem];

    NSMenuItem *groupItem = [[NSMenuItem alloc] initWithTitle:@"Set Group..." action:@selector(ctxSetGroup:) keyEquivalent:@""];
    groupItem.target = self;
    [self.contextMenu addItem:groupItem];

    [self.contextMenu addItem:[NSMenuItem separatorItem]];

    // Snapshots submenu
    NSMenuItem *snapshotMenu = [[NSMenuItem alloc] initWithTitle:@"Snapshots" action:nil keyEquivalent:@""];
    NSMenu *snapMenu = [[NSMenu alloc] init];
    [snapMenu addItem:[self menuItem:@"Take Snapshot..." action:@selector(ctxTakeSnapshot:) icon:@"camera"]];
    [snapMenu addItem:[self menuItem:@"Restore Snapshot..." action:@selector(ctxRestoreSnapshot:) icon:@"arrow.uturn.backward"]];
    [snapMenu addItem:[self menuItem:@"Delete Snapshot..." action:@selector(ctxDeleteSnapshot:) icon:@"trash"]];
    snapshotMenu.submenu = snapMenu;
    [self.contextMenu addItem:snapshotMenu];

    // Clone submenu
    NSMenuItem *cloneMenu = [[NSMenuItem alloc] initWithTitle:@"Clone" action:nil keyEquivalent:@""];
    NSMenu *cloneSub = [[NSMenu alloc] init];
    [cloneSub addItem:[self menuItem:@"Full Clone..." action:@selector(ctxFullClone:) icon:@"doc.on.doc"]];
    [cloneSub addItem:[self menuItem:@"Linked Clone..." action:@selector(ctxLinkedClone:) icon:@"link"]];
    cloneMenu.submenu = cloneSub;
    [self.contextMenu addItem:cloneMenu];

    [self.contextMenu addItem:[NSMenuItem separatorItem]];
    [self.contextMenu addItem:[self menuItem:@"Export OVF/OVA..." action:@selector(ctxExportOVF:) icon:@"square.and.arrow.up"]];
    [self.contextMenu addItem:[self menuItem:@"Encrypt VM..." action:@selector(ctxEncrypt:) icon:@"lock"]];
    [self.contextMenu addItem:[NSMenuItem separatorItem]];
    [self.contextMenu addItem:[self menuItem:@"Batch Start (Selected)" action:@selector(batchStart:) icon:@"play.circle"]];
    [self.contextMenu addItem:[self menuItem:@"Batch Stop (Selected)" action:@selector(batchStop:) icon:@"stop.circle"]];
    [self.contextMenu addItem:[self menuItem:@"Batch Delete (Selected)" action:@selector(batchDelete:) icon:@"trash.circle"]];
    [self.contextMenu addItem:[NSMenuItem separatorItem]];
    [self.contextMenu addItem:[self menuItem:@"Delete" action:@selector(ctxDelete:) icon:@"trash"]];
}

- (NSMenuItem *)menuItem:(NSString *)title action:(SEL)action icon:(NSString *)icon {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target = self;
    if (icon) {
        item.image = [NSImage imageWithSystemSymbolName:icon accessibilityDescription:nil];
    }
    return item;
}

- (void)menuWillOpen:(NSMenu *)menu {
    NSInteger row = self.tableView.clickedRow;
    if (row >= 0 && row < (NSInteger)[self visibleVMs].count) {
        VMNexusVirtualMachine *vm = [self visibleVMs][row];
        NSMenuItem *favItem = [menu itemWithTag:999];
        favItem.title = vm.isFavorite ? @"\u2605 Remove from Favorites" : @"\u2606 Add to Favorites";
    }
}

- (VMNexusVirtualMachine *)contextMenuVM {
    NSInteger row = self.tableView.clickedRow;
    if (row >= 0 && row < (NSInteger)[self visibleVMs].count) {
        return [self visibleVMs][row];
    }
    return nil;
}

// Context menu actions
- (void)ctxStart:(id)sender { VMNexusVirtualMachine *vm = [self contextMenuVM]; if (vm) [self startVMByID:vm.vmIdentifier]; }
- (void)ctxStop:(id)sender { VMNexusVirtualMachine *vm = [self contextMenuVM]; if (vm) [self stopVMByID:vm.vmIdentifier]; }
- (void)ctxPause:(id)sender { VMNexusVirtualMachine *vm = [self contextMenuVM]; if (vm) [self pauseVMByID:vm.vmIdentifier]; }
- (void)ctxEdit:(id)sender { NSInteger row = self.tableView.clickedRow; if (row >= 0) { [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO]; [self editVM:sender]; } }
- (void)ctxOpenConsole:(id)sender { VMNexusVirtualMachine *vm = [self contextMenuVM]; if (vm) [self startVMByID:vm.vmIdentifier]; }
- (void)ctxToggleFavorite:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (vm) {
        vm.isFavorite = !vm.isFavorite;
        [vm saveToBundle];
        [self.tableView reloadData];
        [self updateStatusBar];
    }
}
- (void)ctxSetGroup:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (!vm) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Set VM Group";
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = vm.group ?: @"";
    input.placeholderString = @"Group name";
    alert.accessoryView = input;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        vm.group = input.stringValue ?: @"";
        [vm saveToBundle];
        [self sortVMs];
        [self.tableView reloadData];
    }
}
- (void)ctxTakeSnapshot:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (!vm) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Take Snapshot";
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.placeholderString = @"Snapshot name";
    alert.accessoryView = input;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn && input.stringValue.length > 0) {
        NSString *snapName = input.stringValue;
        NSString *snapDate = [[NSDate date] description];
        NSString *snapPath = [vm.vmBundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"snapshots/%@.qcow2", snapName]];
        // Create snapshot directory
        [[NSFileManager defaultManager] createDirectoryAtPath:[snapPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        // Use qemu-img to create a snapshot
        NSString *qemuImg = @"/opt/homebrew/bin/qemu-img";
        if (![[NSFileManager defaultManager] fileExistsAtPath:qemuImg]) qemuImg = @"/usr/local/bin/qemu-img";
        if (vm.diskImagePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:qemuImg]) {
            NSTask *task = [[NSTask alloc] init];
            task.executableURL = [NSURL fileURLWithPath:qemuImg];
            task.arguments = @[@"snapshot", @"-c", snapName, vm.diskImagePath];
            [task launch];
        }
        NSMutableArray *snaps = [vm.snapshots mutableCopy] ?: [NSMutableArray array];
        [snaps addObject:@{@"name": snapName, @"date": snapDate, @"path": snapPath}];
        vm.snapshots = snaps;
        [vm saveToBundle];
    }
}
- (void)ctxRestoreSnapshot:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (!vm || vm.snapshots.count == 0) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Restore Snapshot";
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 26)];
    for (NSDictionary *snap in vm.snapshots) {
        [popup addItemWithTitle:snap[@"name"] ?: @"unnamed"];
    }
    alert.accessoryView = popup;
    [alert addButtonWithTitle:@"Restore"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *snapName = popup.titleOfSelectedItem;
        if (snapName && vm.diskImagePath.length > 0) {
            NSString *qemuImg = @"/opt/homebrew/bin/qemu-img";
            if (![[NSFileManager defaultManager] fileExistsAtPath:qemuImg]) qemuImg = @"/usr/local/bin/qemu-img";
            NSTask *task = [[NSTask alloc] init];
            task.executableURL = [NSURL fileURLWithPath:qemuImg];
            task.arguments = @[@"snapshot", @"-a", snapName, vm.diskImagePath];
            [task launch];
        }
    }
}
- (void)ctxDeleteSnapshot:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (!vm || vm.snapshots.count == 0) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Delete Snapshot";
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 200, 26)];
    for (NSDictionary *snap in vm.snapshots) {
        [popup addItemWithTitle:snap[@"name"] ?: @"unnamed"];
    }
    alert.accessoryView = popup;
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSInteger idx = popup.indexOfSelectedItem;
        NSString *snapName = popup.titleOfSelectedItem;
        if (snapName && vm.diskImagePath.length > 0) {
            NSString *qemuImg = @"/opt/homebrew/bin/qemu-img";
            if (![[NSFileManager defaultManager] fileExistsAtPath:qemuImg]) qemuImg = @"/usr/local/bin/qemu-img";
            NSTask *task = [[NSTask alloc] init];
            task.executableURL = [NSURL fileURLWithPath:qemuImg];
            task.arguments = @[@"snapshot", @"-d", snapName, vm.diskImagePath];
            [task launch];
        }
        NSMutableArray *snaps = [vm.snapshots mutableCopy];
        if (idx < (NSInteger)snaps.count) [snaps removeObjectAtIndex:idx];
        vm.snapshots = snaps;
        [vm saveToBundle];
    }
}
- (void)ctxFullClone:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (!vm) return;
    // Clone wizard dialog
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Full Clone";
    alert.informativeText = [NSString stringWithFormat:@"Create a full independent copy of '%@'?\n\nThis will copy the entire disk image. The clone will be completely independent of the original.", vm.name];
    [alert addButtonWithTitle:@"Clone"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    VMNexusVirtualMachine *clone = [VMNexusVirtualMachine virtualMachineWithName:[NSString stringWithFormat:@"%@ (Clone)", vm.name] architecture:vm.architecture];
    clone.osType = vm.osType;
    clone.machineType = vm.machineType;
    clone.cpuModel = vm.cpuModel;
    clone.cpuCores = vm.cpuCores;
    clone.cpuSockets = vm.cpuSockets;
    clone.cpuCoresPerSocket = vm.cpuCoresPerSocket;
    clone.memoryValue = vm.memoryValue;
    clone.memoryUnit = vm.memoryUnit;
    clone.diskSizeValue = vm.diskSizeValue;
    clone.diskSizeUnit = vm.diskSizeUnit;
    clone.diskController = vm.diskController;
    clone.usbVersion = vm.usbVersion;
    clone.networkMode = vm.networkMode;
    clone.displayType = vm.displayType;
    clone.enableAudio = vm.enableAudio;
    clone.enableUSB = vm.enableUSB;
    clone.enableAcceleration = vm.enableAcceleration;
    clone.enable3DAcceleration = vm.enable3DAcceleration;
    clone.vramSizeMB = vm.vramSizeMB;
    clone.enableTPM = vm.enableTPM;
    // Copy disk image
    NSString *clonePath = [self.vmDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vmnexus", clone.vmIdentifier]];
    clone.vmBundlePath = clonePath;
    [[NSFileManager defaultManager] createDirectoryAtPath:clonePath withIntermediateDirectories:YES attributes:nil error:nil];
    if (vm.diskImagePath.length > 0) {
        NSString *dstDisk = [clonePath stringByAppendingPathComponent:@"disk.qcow2"];
        NSString *qemuImg = @"/opt/homebrew/bin/qemu-img";
        if (![[NSFileManager defaultManager] fileExistsAtPath:qemuImg]) qemuImg = @"/usr/local/bin/qemu-img";
        if ([[NSFileManager defaultManager] fileExistsAtPath:qemuImg]) {
            NSTask *task = [[NSTask alloc] init];
            task.executableURL = [NSURL fileURLWithPath:qemuImg];
            task.arguments = @[@"convert", @"-f", @"qcow2", @"-O", @"qcow2", vm.diskImagePath, dstDisk];
            [task launch];
            [task waitUntilExit];
        }
        clone.diskImagePath = dstDisk;
    }
    [clone saveToBundle];
    [self.virtualMachines addObject:clone];
    [self sortVMs];
    [self.tableView reloadData];
    [self updateContentVisibility];
    [self updateStatusBar];
}
- (void)ctxLinkedClone:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (!vm) return;
    VMNexusVirtualMachine *clone = [VMNexusVirtualMachine virtualMachineWithName:[NSString stringWithFormat:@"%@ (Linked)", vm.name] architecture:vm.architecture];
    clone.machineType = vm.machineType;
    clone.cpuModel = vm.cpuModel;
    clone.cpuCores = vm.cpuCores;
    clone.memoryValue = vm.memoryValue;
    clone.memoryUnit = vm.memoryUnit;
    clone.diskController = vm.diskController;
    clone.networkMode = vm.networkMode;
    clone.displayType = vm.displayType;
    // Linked clone: create qcow2 overlay pointing to original
    NSString *clonePath = [self.vmDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vmnexus", clone.vmIdentifier]];
    clone.vmBundlePath = clonePath;
    [[NSFileManager defaultManager] createDirectoryAtPath:clonePath withIntermediateDirectories:YES attributes:nil error:nil];
    if (vm.diskImagePath.length > 0) {
        NSString *dstDisk = [clonePath stringByAppendingPathComponent:@"disk.qcow2"];
        NSString *qemuImg = @"/opt/homebrew/bin/qemu-img";
        if (![[NSFileManager defaultManager] fileExistsAtPath:qemuImg]) qemuImg = @"/usr/local/bin/qemu-img";
        if ([[NSFileManager defaultManager] fileExistsAtPath:qemuImg]) {
            NSTask *task = [[NSTask alloc] init];
            task.executableURL = [NSURL fileURLWithPath:qemuImg];
            task.arguments = @[@"create", @"-f", @"qcow2", @"-b", vm.diskImagePath, @"-F", @"qcow2", dstDisk];
            [task launch];
            [task waitUntilExit];
        }
        clone.diskImagePath = dstDisk;
        clone.diskSizeValue = vm.diskSizeValue;
        clone.diskSizeUnit = vm.diskSizeUnit;
    }
    [clone saveToBundle];
    [self.virtualMachines addObject:clone];
    [self sortVMs];
    [self.tableView reloadData];
    [self updateContentVisibility];
    [self updateStatusBar];
}
- (void)ctxExportOVF:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (!vm) return;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[];
    panel.nameFieldStringValue = [NSString stringWithFormat:@"%@.ovf", vm.name];
    panel.title = @"Export OVF";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK && panel.URL) {
            // Generate OVF XML
            NSMutableDictionary *ovfDict = [vm toDictionary];
            NSString *ovfXML = [NSString stringWithFormat:@"<?xml version=\"1.0\"?>\n"
                "<Envelope xmlns=\"http://schemas.dmtf.org/ovf/envelope/1\">\n"
                "  <VirtualSystem ovf:id=\"%@\">\n"
                "    <Name>%@</Name>\n"
                "    <Info>VMNexus Virtual Machine</Info>\n"
                "  </VirtualSystem>\n"
                "</Envelope>\n", vm.vmIdentifier, vm.name];
            [ovfXML writeToURL:panel.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }];
}
- (void)ctxEncrypt:(id)sender {
    VMNexusVirtualMachine *vm = [self contextMenuVM];
    if (!vm) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = vm.isEncrypted ? @"VM is encrypted. Decrypt?" : @"Encrypt VM?";
    alert.informativeText = @"This will set the encryption flag for this VM.";
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        vm.isEncrypted = !vm.isEncrypted;
        [vm saveToBundle];
        [self.tableView reloadData];
    }
}
- (void)ctxDelete:(id)sender {
    NSInteger row = self.tableView.clickedRow;
    if (row >= 0) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [self removeVM:sender];
    }
}

// VM control helpers
- (void)startVMByID:(NSString *)vmID {
    for (VMNexusVirtualMachine *vm in self.virtualMachines) {
        if ([vm.vmIdentifier isEqualToString:vmID]) {
            NSString *key = vm.vmIdentifier;
            VMNexusConsoleWindowController *console = self.consoleControllers[key];
            if (!console) {
                console = [[VMNexusConsoleWindowController alloc] initWithVM:vm];
                self.consoleControllers[key] = console;
            }
            [console showWindow:nil];
            [console.window makeKeyAndOrderFront:nil];
            [console startVM];
            break;
        }
    }
}
- (void)stopVMByID:(NSString *)vmID {
    VMNexusConsoleWindowController *console = self.consoleControllers[vmID];
    if (console) [console stopVM];
}
- (void)pauseVMByID:(NSString *)vmID {
    // Pause not yet implemented - will be added when QEMU monitor support is added
}

#pragma mark - Favorites & Groups

- (void)toggleFavoritesFilter:(id)sender {
    self.showFavoritesOnly = !self.showFavoritesOnly;
    self.favoritesButton.title = self.showFavoritesOnly ? @"\u2605 Favorites" : @"\u2606 Favorites";
    [self.tableView reloadData];
    [self updateContentVisibility];
    [self updateStatusBar];
}

#pragma mark - Drag & Drop

- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger *)row proposedDropOperation:(NSTableViewDropOperation *)op {
    NSPasteboard *pb = info.draggingPasteboard;
    if ([pb.types containsObject:NSPasteboardTypeFileURL]) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pb = info.draggingPasteboard;
    NSArray *items = [pb readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    for (NSURL *url in items) {
        if ([url.pathExtension isEqualToString:@"vmnexus"]) {
            // Import VM bundle
            VMNexusVirtualMachine *vm = [[VMNexusVirtualMachine alloc] init];
            if ([vm loadFromBundle:url.path]) {
                // Copy to our VM directory
                NSString *destPath = [self.vmDirectory stringByAppendingPathComponent:url.lastPathComponent];
                if (![destPath isEqualToString:url.path]) {
                    [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:destPath error:nil];
                    vm.vmBundlePath = destPath;
                }
                [self.virtualMachines addObject:vm];
            }
        } else if ([url.pathExtension isEqualToString:@"qcow2"] || [url.pathExtension isEqualToString:@"vmdk"] ||
                   [url.pathExtension isEqualToString:@"vdi"] || [url.pathExtension isEqualToString:@"vhd"]) {
            // Import disk image - create VM with this disk
            VMNexusVirtualMachine *vm = [VMNexusVirtualMachine virtualMachineWithName:[url.lastPathComponent stringByDeletingPathExtension] architecture:VMNexusArchX86_64];
            NSString *vmPath = [self.vmDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vmnexus", vm.vmIdentifier]];
            vm.vmBundlePath = vmPath;
            [[NSFileManager defaultManager] createDirectoryAtPath:vmPath withIntermediateDirectories:YES attributes:nil error:nil];
            NSString *destDisk = [vmPath stringByAppendingPathComponent:@"disk.qcow2"];
            [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:destDisk error:nil];
            vm.diskImagePath = destDisk;
            [vm saveToBundle];
            [self.virtualMachines addObject:vm];
        } else if ([url.pathExtension isEqualToString:@"iso"] || [url.pathExtension isEqualToString:@"img"]) {
            // Import ISO - create VM with this as boot ISO
            VMNexusVirtualMachine *vm = [VMNexusVirtualMachine virtualMachineWithName:[url.lastPathComponent stringByDeletingPathExtension] architecture:VMNexusArchX86_64];
            NSString *vmPath = [self.vmDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vmnexus", vm.vmIdentifier]];
            vm.vmBundlePath = vmPath;
            [[NSFileManager defaultManager] createDirectoryAtPath:vmPath withIntermediateDirectories:YES attributes:nil error:nil];
            NSString *destISO = [vmPath stringByAppendingPathComponent:url.lastPathComponent];
            [[NSFileManager defaultManager] copyItemAtPath:url.path toPath:destISO error:nil];
            vm.bootISOPath = destISO;
            [vm saveToBundle];
            [self.virtualMachines addObject:vm];
        } else if ([url.pathExtension isEqualToString:@"ovf"] || [url.pathExtension isEqualToString:@"ova"]) {
            // Import OVF/OVA
            VMNexusVirtualMachine *vm = [VMNexusVirtualMachine virtualMachineWithName:[url.lastPathComponent stringByDeletingPathExtension] architecture:VMNexusArchX86_64];
            NSString *vmPath = [self.vmDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vmnexus", vm.vmIdentifier]];
            vm.vmBundlePath = vmPath;
            [[NSFileManager defaultManager] createDirectoryAtPath:vmPath withIntermediateDirectories:YES attributes:nil error:nil];
            [vm saveToBundle];
            [self.virtualMachines addObject:vm];
        }
    }
    [self sortVMs];
    [self.tableView reloadData];
    [self updateContentVisibility];
    [self updateStatusBar];
    return YES;
}

- (void)sortVMs {
    // Sort by group first, then by name
    [self.virtualMachines sortUsingComparator:^NSComparisonResult(VMNexusVirtualMachine *a, VMNexusVirtualMachine *b) {
        NSString *ga = a.group ?: @"";
        NSString *gb = b.group ?: @"";
        NSComparisonResult groupCmp = [ga compare:gb options:NSCaseInsensitiveSearch];
        if (groupCmp != NSOrderedSame) return groupCmp;
        // Favorites first within group
        if (a.isFavorite && !b.isFavorite) return NSOrderedAscending;
        if (!a.isFavorite && b.isFavorite) return NSOrderedDescending;
        return [a.name compare:b.name options:NSCaseInsensitiveSearch];
    }];
}

- (void)openNetworkEditor:(id)sender {
    if (!self.networkEditorWC) {
        self.networkEditorWC = [[VMNexusNetworkEditorController alloc] init];
    }
    [self.networkEditorWC showWindow:self];
    [self.networkEditorWC.window makeKeyAndOrderFront:self];
}

@end

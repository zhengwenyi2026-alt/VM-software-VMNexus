//
//  VMNexusNetworkEditorController.m
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMNexusNetworkEditorController.h"
#import "VMNexusCardView.h"

/// Represents a single VMnet configuration
@interface VMNexusVMnet : NSObject
@property (nonatomic, copy) NSString *name;         // e.g., "vmnet0", "vmnet1"
@property (nonatomic, copy) NSString *type;          // "NAT", "Bridge", "Host-Only"
@property (nonatomic, copy) NSString *subnet;        // e.g., "192.168.100.0"
@property (nonatomic, copy) NSString *subnetMask;    // e.g., "255.255.255.0"
@property (nonatomic, assign) BOOL enableDHCP;
@property (nonatomic, copy) NSString *dhcpStart;     // e.g., "192.168.100.128"
@property (nonatomic, copy) NSString *dhcpEnd;       // e.g., "192.168.100.254"
@property (nonatomic, copy) NSString *bridgeInterface; // For bridge mode
@property (nonatomic, copy) NSArray<NSDictionary *> *portForwards; // [{hostPort, guestIP, guestPort, proto}]
+ (VMNexusVMnet *)defaultNAT;
+ (VMNexusVMnet *)defaultHostOnly;
- (NSDictionary *)toDictionary;
+ (VMNexusVMnet *)fromDictionary:(NSDictionary *)dict;
@end

@implementation VMNexusVMnet
+ (VMNexusVMnet *)defaultNAT {
    VMNexusVMnet *n = [[VMNexusVMnet alloc] init];
    n.name = @"vmnet0"; n.type = @"NAT";
    n.subnet = @"192.168.100.0"; n.subnetMask = @"255.255.255.0";
    n.enableDHCP = YES; n.dhcpStart = @"192.168.100.128"; n.dhcpEnd = @"192.168.100.254";
    n.bridgeInterface = @""; n.portForwards = @[];
    return n;
}
+ (VMNexusVMnet *)defaultHostOnly {
    VMNexusVMnet *n = [[VMNexusVMnet alloc] init];
    n.name = @"vmnet1"; n.type = @"Host-Only";
    n.subnet = @"192.168.50.0"; n.subnetMask = @"255.255.255.0";
    n.enableDHCP = YES; n.dhcpStart = @"192.168.50.128"; n.dhcpEnd = @"192.168.50.254";
    n.bridgeInterface = @""; n.portForwards = @[];
    return n;
}
- (NSDictionary *)toDictionary {
    return @{@"name": self.name ?: @"", @"type": self.type ?: @"NAT",
             @"subnet": self.subnet ?: @"", @"subnetMask": self.subnetMask ?: @"255.255.255.0",
             @"enableDHCP": @(self.enableDHCP),
             @"dhcpStart": self.dhcpStart ?: @"", @"dhcpEnd": self.dhcpEnd ?: @"",
             @"bridgeInterface": self.bridgeInterface ?: @"",
             @"portForwards": self.portForwards ?: @[]};
}
+ (VMNexusVMnet *)fromDictionary:(NSDictionary *)dict {
    VMNexusVMnet *n = [[VMNexusVMnet alloc] init];
    n.name = dict[@"name"] ?: @""; n.type = dict[@"type"] ?: @"NAT";
    n.subnet = dict[@"subnet"] ?: @""; n.subnetMask = dict[@"subnetMask"] ?: @"255.255.255.0";
    n.enableDHCP = [dict[@"enableDHCP"] boolValue];
    n.dhcpStart = dict[@"dhcpStart"] ?: @""; n.dhcpEnd = dict[@"dhcpEnd"] ?: @"";
    n.bridgeInterface = dict[@"bridgeInterface"] ?: @"";
    n.portForwards = dict[@"portForwards"] ?: @[];
    return n;
}
@end

// ────────────────────────────────────────────────────────

@interface VMNexusNetworkEditorController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSMutableArray<VMNexusVMnet *> *vmnets;
@property (nonatomic, strong) NSTableView *vmnetTable;
@property (nonatomic, strong) NSScrollView *vmnetScroll;
// Detail fields
@property (nonatomic, strong) NSView *detailPanel;
@property (nonatomic, strong) NSTextField *nameField;
@property (nonatomic, strong) NSPopUpButton *typePopup;
@property (nonatomic, strong) NSTextField *subnetField;
@property (nonatomic, strong) NSTextField *maskField;
@property (nonatomic, strong) NSButton *dhcpCheck;
@property (nonatomic, strong) NSTextField *dhcpStartField;
@property (nonatomic, strong) NSTextField *dhcpEndField;
@property (nonatomic, strong) NSTextField *bridgeField;
// Port forwarding
@property (nonatomic, strong) NSTableView *pfTable;
@property (nonatomic, strong) NSScrollView *pfScroll;
@property (nonatomic, strong) VMNexusVMnet *selectedVMnet;
@end

@implementation VMNexusNetworkEditorController

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 820, 560);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    window.title = @"Virtual Network Editor";
    window.minSize = NSMakeSize(700, 480);
    [window center];
    self = [super initWithWindow:window];
    if (self) {
        [self loadVMnets];
        [self setupUI];
    }
    return self;
}

#pragma mark - Persistence

- (NSString *)configPath {
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"VMNexus"];
    [[NSFileManager defaultManager] createDirectoryAtPath:appSupport withIntermediateDirectories:YES attributes:nil error:nil];
    return [appSupport stringByAppendingPathComponent:@"vmnets.json"];
}

- (void)loadVMnets {
    NSData *data = [NSData dataWithContentsOfFile:[self configPath]];
    if (data) {
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([arr isKindOfClass:[NSArray class]]) {
            self.vmnets = [NSMutableArray array];
            for (NSDictionary *d in arr) {
                [self.vmnets addObject:[VMNexusVMnet fromDictionary:d]];
            }
            if (self.vmnets.count > 0) return;
        }
    }
    // Defaults
    self.vmnets = [NSMutableArray arrayWithArray:@[[VMNexusVMnet defaultNAT], [VMNexusVMnet defaultHostOnly]]];
}

- (void)saveVMnets {
    NSMutableArray *arr = [NSMutableArray array];
    for (VMNexusVMnet *v in self.vmnets) [arr addObject:[v toDictionary]];
    NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:[self configPath] atomically:YES];
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;

    // Split: left=vmnet list, right=detail
    CGFloat splitX = 240;
    CGFloat windowH = content.bounds.size.height;
    CGFloat windowW = content.bounds.size.width;

    // Left panel - VMnet list
    NSView *leftPanel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, splitX, windowH)];
    leftPanel.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    leftPanel.wantsLayer = YES;
    leftPanel.layer.backgroundColor = [[NSColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0] CGColor];
    [content addSubview:leftPanel];

    NSTextField *listTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(12, windowH - 28, splitX - 24, 20)];
    listTitle.stringValue = @"Virtual Networks";
    listTitle.font = [NSFont boldSystemFontOfSize:12];
    listTitle.bezeled = NO; listTitle.drawsBackground = NO; listTitle.editable = NO;
    [leftPanel addSubview:listTitle];

    self.vmnetScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 40, splitX, windowH - 80)];
    self.vmnetScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.vmnetScroll.borderType = NSNoBorder;
    self.vmnetScroll.drawsBackground = NO;
    self.vmnetTable = [[NSTableView alloc] initWithFrame:self.vmnetScroll.contentView.bounds];
    self.vmnetTable.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.vmnetTable.headerView = nil;
    self.vmnetTable.rowHeight = 28;
    self.vmnetTable.delegate = self;
    self.vmnetTable.dataSource = self;
    [self.vmnetTable addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"name"]];
    self.vmnetScroll.documentView = self.vmnetTable;
    [leftPanel addSubview:self.vmnetScroll];

    // Add/Remove buttons
    NSButton *addBtn = [[NSButton alloc] initWithFrame:NSMakeRect(12, 8, 70, 26)];
    addBtn.title = @"Add"; addBtn.bezelStyle = NSBezelStyleRounded;
    addBtn.target = self; addBtn.action = @selector(addVMnet:);
    [leftPanel addSubview:addBtn];

    NSButton *removeBtn = [[NSButton alloc] initWithFrame:NSMakeRect(90, 8, 70, 26)];
    removeBtn.title = @"Remove"; removeBtn.bezelStyle = NSBezelStyleRounded;
    removeBtn.target = self; removeBtn.action = @selector(removeVMnet:);
    [leftPanel addSubview:removeBtn];

    // Right panel - detail editor
    self.detailPanel = [[NSView alloc] initWithFrame:NSMakeRect(splitX + 1, 0, windowW - splitX - 1, windowH)];
    self.detailPanel.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.detailPanel.wantsLayer = YES;
    self.detailPanel.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
    [content addSubview:self.detailPanel];

    // Separator line
    NSView *sep = [[NSView alloc] initWithFrame:NSMakeRect(splitX, 0, 1, windowH)];
    sep.wantsLayer = YES;
    sep.layer.backgroundColor = [[NSColor separatorColor] CGColor];
    sep.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [content addSubview:sep];

    [self buildDetailPanel];

    if (self.vmnets.count > 0) {
        [self.vmnetTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        self.selectedVMnet = self.vmnets[0];
        [self populateDetail:self.selectedVMnet];
    }
}

- (void)buildDetailPanel {
    NSView *p = self.detailPanel;
    CGFloat w = p.bounds.size.width;
    CGFloat y = p.bounds.size.height - 36;
    CGFloat labelX = 16, fieldX = 140, fieldW = w - fieldX - 20;

    // Name
    [p addSubview:[self makeLabel:@"Name:" x:labelX y:y]];
    self.nameField = [self makeField:@"" x:fieldX y:y w:fieldW];
    [p addSubview:self.nameField];
    y -= 32;

    // Type
    [p addSubview:[self makeLabel:@"Type:" x:labelX y:y]];
    self.typePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(fieldX, y, fieldW, 26)];
    [self.typePopup addItemsWithTitles:@[@"NAT", @"Bridge", @"Host-Only"]];
    self.typePopup.target = self; self.typePopup.action = @selector(typeChanged:);
    [p addSubview:self.typePopup];
    y -= 36;

    // Subnet
    [p addSubview:[self makeLabel:@"Subnet IP:" x:labelX y:y]];
    self.subnetField = [self makeField:@"" x:fieldX y:y w:fieldW];
    [p addSubview:self.subnetField];
    y -= 32;

    // Subnet Mask
    [p addSubview:[self makeLabel:@"Subnet Mask:" x:labelX y:y]];
    self.maskField = [self makeField:@"255.255.255.0" x:fieldX y:y w:fieldW];
    [p addSubview:self.maskField];
    y -= 36;

    // Bridge interface
    [p addSubview:[self makeLabel:@"Bridge Interface:" x:labelX y:y]];
    self.bridgeField = [self makeField:@"" x:fieldX y:y w:fieldW];
    self.bridgeField.placeholderString = @"en0 (for Bridge mode)";
    [p addSubview:self.bridgeField];
    y -= 40;

    // DHCP section
    NSTextField *dhcpTitle = [self makeLabel:@"DHCP Server" x:labelX y:y];
    dhcpTitle.font = [NSFont boldSystemFontOfSize:12];
    [p addSubview:dhcpTitle];
    y -= 28;

    self.dhcpCheck = [[NSButton alloc] initWithFrame:NSMakeRect(labelX, y, 200, 20)];
    self.dhcpCheck.title = @"Enable DHCP";
    self.dhcpCheck.buttonType = NSButtonTypeSwitch;
    [p addSubview:self.dhcpCheck];
    y -= 28;

    [p addSubview:[self makeLabel:@"DHCP Start:" x:labelX y:y]];
    self.dhcpStartField = [self makeField:@"" x:fieldX y:y w:fieldW];
    [p addSubview:self.dhcpStartField];
    y -= 28;

    [p addSubview:[self makeLabel:@"DHCP End:" x:labelX y:y]];
    self.dhcpEndField = [self makeField:@"" x:fieldX y:y w:fieldW];
    [p addSubview:self.dhcpEndField];
    y -= 36;

    // Port Forwarding section
    NSTextField *pfTitle = [self makeLabel:@"Port Forwarding" x:labelX y:y];
    pfTitle.font = [NSFont boldSystemFontOfSize:12];
    [p addSubview:pfTitle];
    y -= 28;

    CGFloat pfH = 100;
    self.pfScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(labelX, y - pfH, w - labelX * 2, pfH)];
    self.pfScroll.borderType = NSBezelBorder;
    self.pfScroll.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    self.pfTable = [[NSTableView alloc] initWithFrame:self.pfScroll.contentView.bounds];
    self.pfTable.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.pfTable.rowHeight = 22;
    [self.pfTable addTableColumn:[self tableCol:@"hostPort" title:@"Host Port" width:70]];
    [self.pfTable addTableColumn:[self tableCol:@"guestIP" title:@"Guest IP" width:120]];
    [self.pfTable addTableColumn:[self tableCol:@"guestPort" title:@"Guest Port" width:70]];
    [self.pfTable addTableColumn:[self tableCol:@"proto" title:@"Protocol" width:60]];
    self.pfTable.dataSource = self;
    self.pfTable.delegate = self;
    self.pfScroll.documentView = self.pfTable;
    [p addSubview:self.pfScroll];

    // PF add/remove buttons
    NSButton *pfAdd = [[NSButton alloc] initWithFrame:NSMakeRect(labelX, y - pfH - 30, 80, 24)];
    pfAdd.title = @"Add Rule"; pfAdd.bezelStyle = NSBezelStyleRounded;
    pfAdd.target = self; pfAdd.action = @selector(addPortForward:);
    [p addSubview:pfAdd];

    NSButton *pfRemove = [[NSButton alloc] initWithFrame:NSMakeRect(labelX + 90, y - pfH - 30, 90, 24)];
    pfRemove.title = @"Remove Rule"; pfRemove.bezelStyle = NSBezelStyleRounded;
    pfRemove.target = self; pfRemove.action = @selector(removePortForward:);
    [p addSubview:pfRemove];

    // Apply button
    NSButton *applyBtn = [[NSButton alloc] initWithFrame:NSMakeRect(w - 100, 12, 80, 30)];
    applyBtn.title = @"Apply"; applyBtn.bezelStyle = NSBezelStyleRounded;
    applyBtn.target = self; applyBtn.action = @selector(applyChanges:);
    applyBtn.keyEquivalent = @"\r";
    applyBtn.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [p addSubview:applyBtn];
}

#pragma mark - Helpers

- (NSTextField *)makeLabel:(NSString *)text x:(CGFloat)x y:(CGFloat)y {
    NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, 120, 18)];
    lbl.stringValue = text;
    lbl.font = [NSFont systemFontOfSize:12];
    lbl.textColor = [NSColor secondaryLabelColor];
    lbl.bezeled = NO; lbl.drawsBackground = NO; lbl.editable = NO;
    lbl.alignment = NSTextAlignmentRight;
    return lbl;
}

- (NSTextField *)makeField:(NSString *)text x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w {
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, w, 24)];
    f.stringValue = text;
    f.font = [NSFont systemFontOfSize:12];
    return f;
}

- (NSTableColumn *)tableCol:(NSString *)ident title:(NSString *)title width:(CGFloat)w {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:ident];
    col.title = title; col.width = w;
    col.headerCell.font = [NSFont systemFontOfSize:10];
    return col;
}

#pragma mark - VMnet list datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    if (tv == self.vmnetTable) return (NSInteger)self.vmnets.count;
    if (tv == self.pfTable && self.selectedVMnet) return (NSInteger)self.selectedVMnet.portForwards.count;
    return 0;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    NSTextField *cell = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, col.width, tv.rowHeight)];
    cell.bezeled = NO; cell.drawsBackground = NO; cell.editable = NO;
    cell.font = [NSFont systemFontOfSize:12];

    if (tv == self.vmnetTable) {
        VMNexusVMnet *v = self.vmnets[row];
        cell.stringValue = [NSString stringWithFormat:@"%@ (%@)", v.name, v.type];
    } else if (tv == self.pfTable && self.selectedVMnet) {
        NSDictionary *pf = self.selectedVMnet.portForwards[row];
        if ([col.identifier isEqualToString:@"hostPort"]) cell.stringValue = pf[@"hostPort"] ?: @"";
        else if ([col.identifier isEqualToString:@"guestIP"]) cell.stringValue = pf[@"guestIP"] ?: @"";
        else if ([col.identifier isEqualToString:@"guestPort"]) cell.stringValue = pf[@"guestPort"] ?: @"";
        else if ([col.identifier isEqualToString:@"proto"]) cell.stringValue = pf[@"proto"] ?: @"tcp";
    }
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (((NSTableView *)notification.object) == self.vmnetTable) {
        NSInteger row = self.vmnetTable.selectedRow;
        if (row >= 0 && row < (NSInteger)self.vmnets.count) {
            self.selectedVMnet = self.vmnets[row];
            [self populateDetail:self.selectedVMnet];
            [self.pfTable reloadData];
        }
    }
}

#pragma mark - Detail population

- (void)populateDetail:(VMNexusVMnet *)v {
    self.nameField.stringValue = v.name;
    [self.typePopup selectItemWithTitle:v.type];
    self.subnetField.stringValue = v.subnet;
    self.maskField.stringValue = v.subnetMask;
    self.bridgeField.stringValue = v.bridgeInterface;
    self.dhcpCheck.state = v.enableDHCP ? NSControlStateValueOn : NSControlStateValueOff;
    self.dhcpStartField.stringValue = v.dhcpStart;
    self.dhcpEndField.stringValue = v.dhcpEnd;
    self.bridgeField.hidden = ![v.type isEqualToString:@"Bridge"];
    [self.pfTable reloadData];
}

- (void)typeChanged:(id)sender {
    self.bridgeField.hidden = (self.typePopup.indexOfSelectedItem != 1);
}

#pragma mark - Actions

- (void)addVMnet:(id)sender {
    VMNexusVMnet *v = [[VMNexusVMnet alloc] init];
    v.name = [NSString stringWithFormat:@"vmnet%lu", (unsigned long)self.vmnets.count];
    v.type = @"Host-Only";
    v.subnet = @"192.168.200.0"; v.subnetMask = @"255.255.255.0";
    v.enableDHCP = YES; v.dhcpStart = @"192.168.200.128"; v.dhcpEnd = @"192.168.200.254";
    v.bridgeInterface = @""; v.portForwards = @[];
    [self.vmnets addObject:v];
    [self.vmnetTable reloadData];
    [self.vmnetTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSInteger)self.vmnets.count - 1] byExtendingSelection:NO];
    self.selectedVMnet = v;
    [self populateDetail:v];
}

- (void)removeVMnet:(id)sender {
    NSInteger row = self.vmnetTable.selectedRow;
    if (row >= 0 && row < (NSInteger)self.vmnets.count) {
        [self.vmnets removeObjectAtIndex:row];
        [self.vmnetTable reloadData];
        self.selectedVMnet = nil;
    }
}

- (void)addPortForward:(id)sender {
    if (!self.selectedVMnet) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add Port Forwarding Rule";

    NSView *form = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 110)];
    NSTextField *hpF = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 80, 200, 22)];
    hpF.placeholderString = @"e.g., 8080";
    [form addSubview:hpF];
    NSTextField *hpL = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 82, 75, 18)];
    hpL.stringValue = @"Host Port:"; hpL.bezeled = NO; hpL.drawsBackground = NO; hpL.editable = NO;
    hpL.alignment = NSTextAlignmentRight; [form addSubview:hpL];

    NSTextField *giF = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 52, 200, 22)];
    giF.placeholderString = @"e.g., 10.0.2.15";
    [form addSubview:giF];
    NSTextField *giL = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 54, 75, 18)];
    giL.stringValue = @"Guest IP:"; giL.bezeled = NO; giL.drawsBackground = NO; giL.editable = NO;
    giL.alignment = NSTextAlignmentRight; [form addSubview:giL];

    NSTextField *gpF = [[NSTextField alloc] initWithFrame:NSMakeRect(80, 24, 200, 22)];
    gpF.placeholderString = @"e.g., 80";
    [form addSubview:gpF];
    NSTextField *gpL = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 26, 75, 18)];
    gpL.stringValue = @"Guest Port:"; gpL.bezeled = NO; gpL.drawsBackground = NO; gpL.editable = NO;
    gpL.alignment = NSTextAlignmentRight; [form addSubview:gpL];

    alert.accessoryView = form;
    [alert addButtonWithTitle:@"Add"]; [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSDictionary *rule = @{
            @"hostPort": hpF.stringValue ?: @"",
            @"guestIP": giF.stringValue ?: @"",
            @"guestPort": gpF.stringValue ?: @"",
            @"proto": @"tcp"
        };
        NSMutableArray *pfs = [NSMutableArray arrayWithArray:self.selectedVMnet.portForwards];
        [pfs addObject:rule];
        self.selectedVMnet.portForwards = pfs;
        [self.pfTable reloadData];
    }
}

- (void)removePortForward:(id)sender {
    if (!self.selectedVMnet) return;
    NSInteger row = self.pfTable.selectedRow;
    if (row >= 0 && row < (NSInteger)self.selectedVMnet.portForwards.count) {
        NSMutableArray *pfs = [NSMutableArray arrayWithArray:self.selectedVMnet.portForwards];
        [pfs removeObjectAtIndex:row];
        self.selectedVMnet.portForwards = pfs;
        [self.pfTable reloadData];
    }
}

- (void)applyChanges:(id)sender {
    if (self.selectedVMnet) {
        self.selectedVMnet.name = self.nameField.stringValue;
        self.selectedVMnet.type = self.typePopup.titleOfSelectedItem;
        self.selectedVMnet.subnet = self.subnetField.stringValue;
        self.selectedVMnet.subnetMask = self.maskField.stringValue;
        self.selectedVMnet.bridgeInterface = self.bridgeField.stringValue;
        self.selectedVMnet.enableDHCP = (self.dhcpCheck.state == NSControlStateValueOn);
        self.selectedVMnet.dhcpStart = self.dhcpStartField.stringValue;
        self.selectedVMnet.dhcpEnd = self.dhcpEndField.stringValue;
    }
    [self.vmnetTable reloadData];
    [self saveVMnets];
}

@end

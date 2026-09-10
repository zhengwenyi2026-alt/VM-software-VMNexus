//
//  VMStartVirtualMachine.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VMStartStatus) {
    VMStartStatusStopped = 0,
    VMStartStatusStarting,
    VMStartStatusRunning,
    VMStartStatusPaused,
    VMStartStatusStopping,
    VMStartStatusError
};

typedef NS_ENUM(NSInteger, VMStartOSType) {
    VMStartOSOther = 0,
    VMStartOSWindowsXP,
    VMStartOSWindows7,
    VMStartOSWindows8,
    VMStartOSWindows10,
    VMStartOSWindows11,
    VMStartOSWindowsServer,
    VMStartOSUbuntu,
    VMStartOSDebian,
    VMStartOSFedora,
    VMStartOSCentOS,
    VMStartOSArch,
    VMStartOSLinux,
    VMStartOSFreeBSD,
    VMStartOSOpenBSD,
    VMStartOSMacOSX,
    VMStartOSClassicMac,
    VMStartOSAndroid,
    VMStartOSDOS,
    VMStartOSReactOS,
    VMStartOSSolaris,
    VMStartOSHaiku,
    VMStartOSCommodore,
    VMStartOSMSX,
};

typedef NS_ENUM(NSInteger, VMStartArchitecture) {
    VMStartArchX86 = 0,
    VMStartArchX86_64,
    VMStartArchARM,
    VMStartArchAArch64,
    VMStartArchMIPS,
    VMStartArchMIPS64,
    VMStartArchMIPSEL,
    VMStartArchMIPS64EL,
    VMStartArchPPC,
    VMStartArchPPC64,
    VMStartArchRISCV32,
    VMStartArchRISCV64,
    VMStartArchS390x,
    VMStartArchSPARC,
    VMStartArchSPARC64,
    VMStartArchM68k,
    VMStartArchAlpha,
    VMStartArchHPPA,
    VMStartArchSH4,
    VMStartArchSH4EB,
    VMStartArchMicroBlaze,
    VMStartArchMicroBlazeEL,
    VMStartArchOR1K,
    VMStartArchLoongArch64,
    VMStartArchXtensa,
    VMStartArchXtensaEB,
    VMStartArchTricore,
    VMStartArchAVR,
    VMStartArchRX,
    // Classic / Retro CPU families used by non-QEMU engines
    VMStartArchClassicMac68k,  // 68000: Mac 128K/512K/Plus/SE/Classic → Mini vMac
    VMStartArchMac68kII,       // 68020/030/040: Mac II/LC/Centris/Quadra → BasiliskII
    VMStartArchMOS6502,        // Commodore 64/128/PET/VIC-20 → VICE
    VMStartArchZ80,            // MSX / ZX Spectrum → openMSX / Fuse
    VMStartArchMultiSystem,    // ScummVM / Mednafen
};

@interface VMStartVirtualMachine : NSObject <NSSecureCoding>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *vmIdentifier;
@property (nonatomic, assign) VMStartArchitecture architecture;
@property (nonatomic, copy) NSString *machineType;
@property (nonatomic, copy) NSString *cpuModel;
@property (nonatomic, assign) NSInteger cpuCores;
@property (nonatomic, assign) NSInteger memoryValue;
@property (nonatomic, copy) NSString *memoryUnit; // KB, MB, GB, TB
@property (nonatomic, copy) NSString *diskImagePath;
@property (nonatomic, assign) NSInteger diskSizeValue;
@property (nonatomic, copy) NSString *diskSizeUnit; // KB, MB, GB, TB
@property (nonatomic, copy, nullable) NSString *cdromImagePath;
@property (nonatomic, copy, nullable) NSString *bootISOPath;
// Floppy disks (support multiple: fda, fdb)
@property (nonatomic, copy, nullable) NSString *floppyAPath;
@property (nonatomic, copy, nullable) NSString *floppyBPath;
// Shared folders (host ↔ guest via virtio-9p or FAT)
@property (nonatomic, copy) NSArray<NSDictionary *> *sharedFolders; // [{name, hostPath, readonly}]
// Classic Mac specific (BasiliskII / Mini vMac)
@property (nonatomic, copy, nullable) NSString *romFilePath;        // Required ROM file for classic Mac
@property (nonatomic, copy, nullable) NSString *classicMacModel;    // e.g. "Mac128K", "MacPlus", "MacII"
@property (nonatomic, assign) VMStartStatus status;
@property (nonatomic, assign) VMStartOSType osType;
@property (nonatomic, copy) NSString *networkMode;
@property (nonatomic, copy) NSString *displayType;
@property (nonatomic, assign) BOOL enableAudio;
@property (nonatomic, assign) BOOL enableUSB;
@property (nonatomic, assign) BOOL enableAcceleration;
@property (nonatomic, copy) NSString *biosPath;
@property (nonatomic, copy) NSArray<NSString *> *additionalArgs;
@property (nonatomic, copy) NSString *vmBundlePath;
@property (nonatomic, assign) NSInteger vncPort;
@property (nonatomic, copy) NSString *notes;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *lastUsedAt;

// ─── Enhanced Hardware Properties ───
@property (nonatomic, copy) NSString *diskController;      // SCSI, SATA, NVMe, VirtIO
@property (nonatomic, copy) NSString *usbVersion;           // 2.0, 3.0, 3.1
@property (nonatomic, assign) BOOL enableTPM;               // Virtual TPM
@property (nonatomic, assign) BOOL enable3DAcceleration;    // 3D hardware acceleration
@property (nonatomic, assign) NSInteger vramSizeMB;         // VRAM in MB (16-512)
@property (nonatomic, assign) NSInteger monitorCount;       // Multi-monitor (1-4)
@property (nonatomic, assign) BOOL enableHiDPI;             // HiDPI / Retina scaling
@property (nonatomic, assign) BOOL enableParallelPort;      // Parallel port
@property (nonatomic, assign) BOOL enableSoundCard;         // Sound card (separate from audio toggle)
@property (nonatomic, copy) NSString *soundCardModel;       // hda, ac97, es1370, sb16
@property (nonatomic, assign) NSInteger cpuSockets;         // CPU sockets
@property (nonatomic, assign) NSInteger cpuCoresPerSocket;  // Cores per socket

// ─── Advanced Features ───
@property (nonatomic, assign) BOOL enableSharedClipboard;   // Shared clipboard host↔guest
@property (nonatomic, assign) BOOL enableDragDrop;          // Drag & drop host↔guest
@property (nonatomic, assign) BOOL enableTimeSync;          // Guest time sync
@property (nonatomic, copy) NSString *performanceProfile;   // power-save, balanced, performance
@property (nonatomic, copy) NSArray<NSDictionary *> *snapshots; // [{name, date, path}]
@property (nonatomic, assign) BOOL enableAutoSnapshot;      // Auto snapshot (SmartGuard)
@property (nonatomic, assign) NSInteger autoSnapshotInterval; // Minutes between auto snapshots
@property (nonatomic, assign) BOOL isEncrypted;             // VM encryption
@property (nonatomic, copy, nullable) NSString *encryptionKeyHash;
@property (nonatomic, assign) BOOL isFavorite;              // Favorite VM
@property (nonatomic, copy) NSString *group;                // VM group name
@property (nonatomic, copy) NSArray<NSDictionary *> *portForwards; // [{proto, hostPort, guestPort, guestIP}]
@property (nonatomic, copy) NSString *bridgeInterface;       // Bridge network interface name
@property (nonatomic, copy) NSString *hostOnlySubnet;        // Host-only subnet IP
@property (nonatomic, assign) BOOL enableDHCP;              // DHCP server for virtual networks
@property (nonatomic, copy) NSString *dhcpRangeStart;       // DHCP range start IP
@property (nonatomic, copy) NSString *dhcpRangeEnd;         // DHCP range end IP
@property (nonatomic, assign) BOOL enableIPv6;              // IPv6 support
@property (nonatomic, assign) BOOL autoStart;               // Auto-start on app launch
@property (nonatomic, copy) NSArray<NSString *> *tags;       // Custom tags

+ (instancetype)virtualMachineWithName:(NSString *)name architecture:(VMStartArchitecture)arch;
- (BOOL)saveToBundle;
- (BOOL)loadFromBundle:(NSString *)bundlePath;
- (NSDictionary *)toDictionary;
- (void)loadFromDictionary:(NSDictionary *)dict;
- (NSString *)qemuBinaryPath;
- (NSArray<NSString *> *)buildQEMUArguments;
- (NSInteger)memoryInBytes;
- (NSString *)diskSizeForQEMU;
// Disk usage tracking
- (NSString *)diskImagePathResolved;
- (NSInteger)diskUsedBytes;
- (NSInteger)diskTotalBytes;
- (CGFloat)diskUsagePercent;
+ (NSInteger)convertValue:(NSInteger)value fromUnit:(NSString *)unit toUnit:(NSString *)targetUnit;
+ (NSArray<NSString *> *)supportedUnits;
// Physical drive detection
+ (NSArray<NSString *> *)physicalOpticalDrives;
+ (NSArray<NSString *> *)physicalFloppyDrives;
- (BOOL)isAppleSiliconHost;
- (nullable NSString *)findAArch64Firmware;
- (NSString *)architectureDisplayName;
- (NSString *)statusDisplayName;
- (NSString *)osDisplayName;
- (NSImage *)osIcon;
+ (NSArray<NSString *> *)allOSTypeNames;
+ (NSDictionary *)presetConfigForOSType:(VMStartOSType)osType;
+ (NSString *)displayNameForArchitecture:(VMStartArchitecture)arch;
+ (NSString *)qemuBinaryNameForArchitecture:(VMStartArchitecture)arch;

@end

NS_ASSUME_NONNULL_END

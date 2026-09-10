//
//  VMStartArchitectureManager.m
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#import "VMStartArchitectureManager.h"

@implementation VMStartMachineInfo
@end

@implementation VMStartArchitectureProfile

- (NSArray<NSString *> *)allMachines {
    NSMutableOrderedSet *all = [NSMutableOrderedSet orderedSetWithArray:self.supportedMachines ?: @[]];
    if (self.dynamicMachines) {
        for (VMStartMachineInfo *m in self.dynamicMachines) {
            if (m.name.length > 0 && ![m.name isEqualToString:@"none"]) {
                [all addObject:m.name];
            }
        }
    }
    return [all array];
}

- (NSArray<NSString *> *)allCPUs {
    NSMutableOrderedSet *all = [NSMutableOrderedSet orderedSetWithArray:self.supportedCPUs ?: @[]];
    if (self.dynamicCPUs) {
        [all addObjectsFromArray:self.dynamicCPUs];
    }
    return [all array];
}

@end

@interface VMStartArchitectureManager ()
@property (nonatomic, strong) NSArray<VMStartArchitectureProfile *> *profiles;
@end

@implementation VMStartArchitectureManager

+ (instancetype)sharedManager {
    static VMStartArchitectureManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VMStartArchitectureManager alloc] init];
        [instance loadProfiles];
        // Query installed QEMU for real-time machine/CPU lists
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [instance refreshDynamicData];
        });
    });
    return instance;
}

- (void)loadProfiles {
    NSMutableArray *profiles = [NSMutableArray array];
    
    // ========== x86 family ==========
    [profiles addObject:[self profileWithName:@"i386" displayName:@"x86 (32-bit)" arch:VMStartArchX86
                                       binary:@"qemu-system-i386" bitWidth:32 category:@"x86"
                              machines:@[@"pc", @"q35", @"isapc", @"microvm",
                                          @"pc-i440fx-10.1", @"pc-i440fx-10.0", @"pc-i440fx-9.2", @"pc-i440fx-9.1", @"pc-i440fx-9.0",
                                          @"pc-i440fx-8.2", @"pc-i440fx-8.1", @"pc-i440fx-8.0", @"pc-i440fx-7.2", @"pc-i440fx-7.1",
                                          @"pc-i440fx-7.0", @"pc-i440fx-6.2", @"pc-i440fx-6.1", @"pc-i440fx-6.0",
                                          @"pc-q35-10.1", @"pc-q35-10.0", @"pc-q35-9.2", @"pc-q35-9.1", @"pc-q35-9.0",
                                          @"pc-q35-8.2", @"pc-q35-8.1", @"pc-q35-8.0", @"pc-q35-7.2", @"pc-q35-7.1",
                                          @"pc-q35-7.0", @"pc-q35-6.2", @"pc-q35-6.1", @"pc-q35-6.0",
                                          // x86 PC emulators
                                          @"dosbox", @"dosbox-x", @"pcem", @"86box"
                                      ] defaultMachine:@"q35"
                                  cpus:@[@"qemu32", @"486", @"pentium", @"pentium2", @"pentium3", @"coreduo", @"n270", @"Conroe", @"Penryn"] defaultCPU:@"qemu32"
                           minMem:64 maxMem:4096 defaultMem:512 accel:YES]];
    
    [profiles addObject:[self profileWithName:@"x86_64" displayName:@"x86_64 (64-bit)" arch:VMStartArchX86_64
                                       binary:@"qemu-system-x86_64" bitWidth:64 category:@"x86"
                              machines:@[@"pc", @"q35", @"isapc", @"microvm",
                                          @"pc-i440fx-10.1", @"pc-i440fx-10.0", @"pc-i440fx-9.2", @"pc-i440fx-9.1", @"pc-i440fx-9.0",
                                          @"pc-i440fx-8.2", @"pc-i440fx-8.1", @"pc-i440fx-8.0", @"pc-i440fx-7.2", @"pc-i440fx-7.1",
                                          @"pc-i440fx-7.0", @"pc-i440fx-6.2", @"pc-i440fx-6.1", @"pc-i440fx-6.0",
                                          @"pc-q35-10.1", @"pc-q35-10.0", @"pc-q35-9.2", @"pc-q35-9.1", @"pc-q35-9.0",
                                          @"pc-q35-8.2", @"pc-q35-8.1", @"pc-q35-8.0", @"pc-q35-7.2", @"pc-q35-7.1",
                                          @"pc-q35-7.0", @"pc-q35-6.2", @"pc-q35-6.1", @"pc-q35-6.0",
                                          // x86 PC emulators
                                          @"dosbox", @"dosbox-x", @"pcem", @"86box"
                                      ] defaultMachine:@"q35"
                                  cpus:@[@"qemu64", @"host", @"kvm64", @"486", @"core2duo",
                                          @"Conroe", @"Penryn", @"Nehalem", @"Westmere", @"SandyBridge", @"IvyBridge",
                                          @"Haswell", @"Broadwell", @"Skylake-Client", @"Skylake-Server", @"Cascadelake-Server",
                                          @"Icelake-Client", @"Icelake-Server", @"Cooperlake", @"Snowridge", @"Denverton",
                                          @"ClearwaterForest", @"Dhyana", @"EPYC", @"EPYC-Rome", @"EPYC-Milan", @"EPYC-Genoa"] defaultCPU:@"qemu64"
                           minMem:128 maxMem:65536 defaultMem:2048 accel:YES]];
    
    // ========== ARM family ==========
    [profiles addObject:[self profileWithName:@"arm" displayName:@"ARM (32-bit)" arch:VMStartArchARM
                                       binary:@"qemu-system-arm" bitWidth:32 category:@"ARM"
                              machines:@[@"virt", @"versatilepb", @"versatileab", @"vexpress-a15", @"vexpress-a9",
                                          @"raspi0", @"raspi1ap", @"raspi2b",
                                          @"cubieboard", @"orangepi-pc", @"bpim2u",
                                          @"integratorcp", @"realview-eb", @"realview-eb-mpcore", @"realview-pb-a8", @"realview-pbx-a9",
                                          @"highbank", @"midway", @"sabrelite", @"smdkc210", @"nuri",
                                          @"imx25-pdk", @"mcimx6ul-evk", @"mcimx7d-sabre",
                                          @"xilinx-zynq-a9", @"collie", @"spitz", @"borzoi", @"akita",
                                          @"sx1", @"sx1-v1", @"musicpal",
                                          @"mps2-an385", @"mps2-an386", @"mps2-an500", @"mps2-an505", @"mps2-an511", @"mps2-an521",
                                          @"mps3-an524", @"mps3-an536", @"mps3-an547",
                                          @"microbit", @"netduino2", @"netduinoplus2", @"stm32vldiscovery",
                                          @"olimex-stm32-h405", @"musca-a", @"musca-b1",
                                          @"b-l475e-iot01a", @"emcraft-sf2",
                                          @"npcm750-evb",
                                          @"palmetto-bmc", @"romulus-bmc", @"witherspoon-bmc", @"rainier-bmc",
                                          @"fuji-bmc", @"mori-bmc", @"kudo-bmc", @"bletchley-bmc",
                                          @"quanta-gbs-bmc", @"quanta-gsj", @"quanta-q71l-bmc",
                                          @"supermicrox11-bmc", @"supermicro-x11spi-bmc",
                                          @"sonorapass-bmc", @"tiogapass-bmc", @"yosemitev2-bmc",
                                          @"canon-a1100", @"max78000fthr"] defaultMachine:@"virt"
                                  cpus:@[@"cortex-a15", @"cortex-a9", @"cortex-a7", @"cortex-a8",
                                          @"arm1176", @"arm1136", @"arm1136-r2", @"arm926", @"arm946", @"arm1026",
                                          @"cortex-m0", @"cortex-m3", @"cortex-m4", @"cortex-m7", @"cortex-m33",
                                          @"cortex-r5", @"cortex-r5f"] defaultCPU:@"cortex-a15"
                           minMem:64 maxMem:8192 defaultMem:1024 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"aarch64" displayName:@"ARM64 (AArch64)" arch:VMStartArchAArch64
                                       binary:@"qemu-system-aarch64" bitWidth:64 category:@"ARM"
                              machines:@[@"virt", @"virt,highmem=on",
                                          @"raspi0", @"raspi1ap", @"raspi2b", @"raspi3ap", @"raspi3b", @"raspi4b",
                                          @"sbsa-ref", @"xlnx-zcu102", @"xlnx-versal-virt",
                                          @"cubieboard", @"orangepi-pc", @"bpim2u",
                                          @"integratorcp", @"realview-eb", @"realview-eb-mpcore", @"realview-pb-a8", @"realview-pbx-a9",
                                          @"highbank", @"midway", @"sabrelite", @"smdkc210", @"nuri",
                                          @"imx25-pdk", @"imx8mp-evk", @"mcimx6ul-evk", @"mcimx7d-sabre",
                                          @"xilinx-zynq-a9", @"collie",
                                          @"sx1", @"sx1-v1", @"musicpal",
                                          @"mps2-an385", @"mps2-an386", @"mps2-an500", @"mps2-an505", @"mps2-an511", @"mps2-an521",
                                          @"mps3-an524", @"mps3-an536", @"mps3-an547",
                                          @"microbit", @"netduino2", @"netduinoplus2", @"stm32vldiscovery",
                                          @"olimex-stm32-h405", @"musca-a", @"musca-b1",
                                          @"b-l475e-iot01a", @"emcraft-sf2", @"max78000fthr",
                                          @"ast1030-evb", @"ast2500-evb", @"ast2600-evb", @"ast2700-evb",
                                          @"npcm750-evb", @"npcm845-evb",
                                          @"palmetto-bmc", @"romulus-bmc", @"witherspoon-bmc", @"rainier-bmc",
                                          @"fuji-bmc", @"mori-bmc", @"kudo-bmc", @"bletchley-bmc", @"catalina-bmc",
                                          @"quanta-gbs-bmc", @"quanta-gsj", @"quanta-q71l-bmc",
                                          @"qcom-dc-scm-v1-bmc", @"qcom-firework-bmc",
                                          @"supermicrox11-bmc", @"supermicro-x11spi-bmc",
                                          @"sonorapass-bmc", @"tiogapass-bmc", @"yosemitev2-bmc",
                                          @"gb200nvl-bmc", @"g220a-bmc",
                                          @"fby35", @"fby35-bmc", @"fp5280g2-bmc",
                                          @"canon-a1100"] defaultMachine:@"virt"
                                  cpus:@[@"host", @"max",
                                          @"cortex-a53", @"cortex-a57", @"cortex-a72", @"cortex-a76",
                                          @"cortex-a710", @"cortex-a15", @"cortex-a9", @"cortex-a8",
                                          @"cortex-a35", @"cortex-a7",
                                          @"neoverse-n1", @"neoverse-v1",
                                          @"a64fx", @"pxa270"] defaultCPU:@"host"
                           minMem:128 maxMem:65536 defaultMem:4096 accel:YES]];
    
    // ========== MIPS family ==========
    [profiles addObject:[self profileWithName:@"mips" displayName:@"MIPS (32-bit)" arch:VMStartArchMIPS
                                       binary:@"qemu-system-mips" bitWidth:32 category:@"MIPS"
                              machines:@[@"malta", @"mipssim"] defaultMachine:@"malta"
                                  cpus:@[@"24Kf", @"34Kf", @"74Kf", @"m14k", @"m14k-f", @"P5600", @"I7200"] defaultCPU:@"24Kf"
                           minMem:32 maxMem:2048 defaultMem:256 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"mips64" displayName:@"MIPS64" arch:VMStartArchMIPS64
                                       binary:@"qemu-system-mips64" bitWidth:64 category:@"MIPS"
                              machines:@[@"malta", @"pica61", @"mipssim", @"magnum"] defaultMachine:@"malta"
                                  cpus:@[@"20Kc", @"5Kc", @"5Kf", @"VR5432", @"R4000", @"Loongson-2E", @"Loongson-2F", @"Loongson-3A1000", @"Loongson-3A4000", @"I6400", @"I6500"] defaultCPU:@"20Kc"
                           minMem:64 maxMem:4096 defaultMem:512 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"mipsel" displayName:@"MIPSel (LE)" arch:VMStartArchMIPSEL
                                       binary:@"qemu-system-mipsel" bitWidth:32 category:@"MIPS"
                              machines:@[@"malta", @"mipssim"] defaultMachine:@"malta"
                                  cpus:@[@"24Kf", @"34Kf", @"74Kf", @"m14k", @"P5600"] defaultCPU:@"24Kf"
                           minMem:32 maxMem:2048 defaultMem:256 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"mips64el" displayName:@"MIPS64el" arch:VMStartArchMIPS64EL
                                       binary:@"qemu-system-mips64el" bitWidth:64 category:@"MIPS"
                              machines:@[@"malta", @"pica61", @"mipssim", @"magnum", @"fuloong2e", @"loongson3-virt", @"boston"] defaultMachine:@"malta"
                                  cpus:@[@"20Kc", @"5Kc", @"5Kf", @"VR5432", @"Loongson-2E", @"Loongson-2F", @"Loongson-3A1000", @"Loongson-3A4000", @"I6400", @"I6500"] defaultCPU:@"20Kc"
                           minMem:64 maxMem:4096 defaultMem:512 accel:NO]];
    
    // ========== PowerPC ==========
    [profiles addObject:[self profileWithName:@"ppc" displayName:@"PowerPC (32-bit)" arch:VMStartArchPPC
                                       binary:@"qemu-system-ppc" bitWidth:32 category:@"PowerPC"
                              machines:@[@"mac99", @"g3beige", @"40p", @"amigaone", @"pegasos2",
                                          @"bamboo", @"sam460ex", @"mpc8544ds", @"ppce500",
                                          @"virtex-ml507", @"ref405ep",
                                          // SheepShaver PowerPC Mac
                                          @"sheepshaver-g3", @"sheepshaver-g4"
                                      ] defaultMachine:@"mac99"
                                  cpus:@[@"7400", @"7410", @"7447", @"7450", @"7447a", @"G4",
                                          @"G3", @"750", @"750cl", @"750cx", @"750fx", @"750gx",
                                          @"603e", @"604e", @"MPC5200", @"MPC8347E", @"e500mc", @"e5500"] defaultCPU:@"7400"
                           minMem:64 maxMem:4096 defaultMem:512 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"ppc64" displayName:@"PowerPC64" arch:VMStartArchPPC64
                                       binary:@"qemu-system-ppc64" bitWidth:64 category:@"PowerPC"
                              machines:@[@"pseries", @"powernv", @"powernv8", @"powernv9", @"powernv10", @"powernv10-rainier",
                                          @"mac99", @"g3beige", @"40p", @"amigaone", @"pegasos2",
                                          @"bamboo", @"sam460ex", @"mpc8544ds", @"ppce500", @"virtex-ml507",
                                          @"pseries-10.1", @"pseries-10.0", @"pseries-9.2", @"pseries-9.1", @"pseries-9.0",
                                          @"pseries-8.2", @"pseries-8.1", @"pseries-8.0"] defaultMachine:@"pseries"
                                  cpus:@[@"POWER8", @"POWER9", @"POWER10", @"POWER11",
                                          @"970", @"970mp", @"970fx", @"970gx",
                                          @"POWER5+", @"POWER7", @"POWER7+", @"POWER8E", @"POWER8NVL"] defaultCPU:@"POWER8"
                           minMem:128 maxMem:32768 defaultMem:2048 accel:NO]];
    
    // ========== RISC-V ==========
    [profiles addObject:[self profileWithName:@"riscv32" displayName:@"RISC-V (32-bit)" arch:VMStartArchRISCV32
                                       binary:@"qemu-system-riscv32" bitWidth:32 category:@"RISC-V"
                              machines:@[@"virt", @"sifive_e", @"sifive_u", @"spike", @"opentitan", @"amd-microblaze-v-generic"] defaultMachine:@"virt"
                                  cpus:@[@"rv32", @"sifive-e31", @"sifive-u34", @"lowrisc-ibex"] defaultCPU:@"rv32"
                           minMem:64 maxMem:4096 defaultMem:512 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"riscv64" displayName:@"RISC-V (64-bit)" arch:VMStartArchRISCV64
                                       binary:@"qemu-system-riscv64" bitWidth:64 category:@"RISC-V"
                              machines:@[@"virt", @"sifive_e", @"sifive_u", @"spike",
                                          @"microchip-icicle-kit", @"shakti_c", @"xiangshan-kunminghu", @"amd-microblaze-v-generic"] defaultMachine:@"virt"
                                  cpus:@[@"rv64", @"sifive-u54", @"sifive-e51", @"sifive-u74", @"thead-c906", @"veyron-v1", @"x-rv128"] defaultCPU:@"rv64"
                           minMem:128 maxMem:32768 defaultMem:2048 accel:NO]];
    
    // ========== IBM Mainframe ==========
    [profiles addObject:[self profileWithName:@"s390x" displayName:@"s390x (IBM Z)" arch:VMStartArchS390x
                                       binary:@"qemu-system-s390x" bitWidth:64 category:@"IBM"
                              machines:@[@"s390-ccw-virtio",
                                          @"s390-ccw-virtio-10.1", @"s390-ccw-virtio-10.0",
                                          @"s390-ccw-virtio-9.2", @"s390-ccw-virtio-9.1", @"s390-ccw-virtio-9.0",
                                          @"s390-ccw-virtio-8.2", @"s390-ccw-virtio-8.1", @"s390-ccw-virtio-8.0",
                                          @"s390-ccw-virtio-7.2", @"s390-ccw-virtio-7.1", @"s390-ccw-virtio-7.0"] defaultMachine:@"s390-ccw-virtio"
                                  cpus:@[@"qemu", @"max", @"z13", @"z14", @"z15", @"z900", @"z990", @"z9EC", @"z10EC", @"z196", @"zEC12", @"gen15a", @"gen16a", @"gen16b"] defaultCPU:@"qemu"
                           minMem:256 maxMem:32768 defaultMem:2048 accel:NO]];
    
    // ========== SPARC ==========
    [profiles addObject:[self profileWithName:@"sparc" displayName:@"SPARC (32-bit)" arch:VMStartArchSPARC
                                       binary:@"qemu-system-sparc" bitWidth:32 category:@"SPARC"
                              machines:@[@"SS-5", @"SS-10", @"SS-20", @"SS-4", @"SS-600MP",
                                          @"LX", @"SPARCClassic", @"SPARCbook", @"Voyager", @"leon3_generic"] defaultMachine:@"SS-5"
                                  cpus:@[@"TI-SuperSparc-II", @"TI-SuperSparc-60", @"TI-SuperSparc-50", @"TI-SuperSparc-40",
                                          @"TI-MicroSparc-I", @"TI-MicroSparc-II", @"TI-MicroSparc-IIep",
                                          @"Fujitsu-MB86904", @"Fujitsu-MB86907", @"LEON2", @"LEON3"] defaultCPU:@"TI-SuperSparc-II"
                           minMem:32 maxMem:2048 defaultMem:256 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"sparc64" displayName:@"SPARC64" arch:VMStartArchSPARC64
                                       binary:@"qemu-system-sparc64" bitWidth:64 category:@"SPARC"
                              machines:@[@"sun4u", @"sun4v", @"niagara"] defaultMachine:@"sun4u"
                                  cpus:@[@"UltraSparc-II", @"UltraSparc-I", @"UltraSparc-IIi", @"UltraSparc-IIe",
                                          @"UltraSparc-III", @"UltraSparc-III-Cu", @"UltraSparc-IIIi", @"UltraSparc-IV",
                                          @"UltraSparc-T1", @"UltraSparc-T2",
                                          @"Fujitsu-Sparc64", @"Fujitsu-Sparc64-III", @"Fujitsu-Sparc64-IV", @"Fujitsu-Sparc64-V"] defaultCPU:@"UltraSparc-II"
                           minMem:64 maxMem:8192 defaultMem:512 accel:NO]];
    
    // ========== Classic / Retro architectures ==========
    // m68k 机器列表包含：QEMU 原生机型 + Mini vMac 机型（68000早期Mac）+ BasiliskII 机型（Mac II/LC/Quadra）
    // 启动时由 VMStartEngineSelector 根据 machineType 自动路由到对应引擎
    [profiles addObject:[self profileWithName:@"m68k" displayName:@"Motorola 68000" arch:VMStartArchM68k
                                       binary:@"qemu-system-m68k" bitWidth:32 category:@"Classic"
                              machines:@[
                                          // ── QEMU 原生机型 ──
                                          @"q800", @"next-cube", @"virt",
                                          @"mcf5208evb", @"an5206",
                                          @"virt-10.1", @"virt-10.0", @"virt-9.2", @"virt-9.1", @"virt-9.0",
                                          @"virt-8.2", @"virt-8.1", @"virt-8.0",
                                          // ── Mini vMac 机型（68000 早期 Mac）──
                                          @"Mac128K", @"Mac512K", @"Mac512Ke", @"MacPlus",
                                          @"MacSE", @"MacSE30", @"MacClassic",
                                          // ── BasiliskII 机型（Mac II/LC/Quadra）──
                                          @"MacII", @"MacIIx", @"MacIIcx", @"MacIIci",
                                          @"MacIIfx", @"MacIIsi", @"MacIIvi",
                                          @"MacLC", @"MacLCII", @"MacLCIII",
                                          @"MacClassicII",
                                          @"MacQuadra700", @"MacQuadra800", @"MacQuadra900", @"MacQuadra950",
                                          @"MacQuadra840AV",
                                          @"MacCentris610", @"MacCentris650",
                                          @"MacQuadra610", @"MacQuadra650",
                                          @"MacPerforma630",
                                          // ── FS-UAE 机型（Amiga）──
                                          @"amiga500", @"amiga600", @"amiga1200", @"amiga2000", @"amiga3000", @"amiga4000",
                                          // ── Hatari / ARAnyM 机型（Atari）──
                                          @"atarist", @"atariste", @"ataritt", @"atarifalcon",
                                          @"aranym"
                                      ]
                               defaultMachine:@"q800"
                                  cpus:@[@"m68040", @"m68030", @"m68020", @"m68010", @"m68000", @"m68060", @"cfv4e", @"m5206", @"m5208"] defaultCPU:@"m68040"
                           minMem:1 maxMem:2048 defaultMem:64 accel:NO]];

    
    [profiles addObject:[self profileWithName:@"avr" displayName:@"AVR (8-bit)" arch:VMStartArchAVR
                                       binary:@"qemu-system-avr" bitWidth:8 category:@"Embedded"
                              machines:@[@"arduino-mega", @"arduino-mega-2560-v3", @"mega2560",
                                          @"arduino-duemilanove", @"arduino-uno", @"uno"] defaultMachine:@"arduino-mega"
                                  cpus:@[@"avr6", @"avr5", @"avr51"] defaultCPU:@"avr6"
                           minMem:1 maxMem:16 defaultMem:8 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"alpha" displayName:@"DEC Alpha" arch:VMStartArchAlpha
                                       binary:@"qemu-system-alpha" bitWidth:64 category:@"Classic"
                              machines:@[@"clipper"] defaultMachine:@"clipper"
                                  cpus:@[@"ev4", @"ev5", @"ev56", @"ev6", @"ev67", @"ev68", @"pca56"] defaultCPU:@"ev67"
                           minMem:64 maxMem:8192 defaultMem:512 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"hppa" displayName:@"HP PA-RISC" arch:VMStartArchHPPA
                                       binary:@"qemu-system-hppa" bitWidth:32 category:@"Classic"
                              machines:@[@"B160L", @"C3700"] defaultMachine:@"B160L"
                                  cpus:@[@"hppa", @"hppa64"] defaultCPU:@"hppa"
                           minMem:64 maxMem:4096 defaultMem:512 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"sh4" displayName:@"SuperH SH-4" arch:VMStartArchSH4
                                       binary:@"qemu-system-sh4" bitWidth:32 category:@"Embedded"
                              machines:@[@"r2d"] defaultMachine:@"r2d"
                                  cpus:@[@"sh7750", @"sh7750r", @"sh7751", @"sh7751r", @"sh7785"] defaultCPU:@"sh7750"
                           minMem:16 maxMem:1024 defaultMem:64 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"sh4eb" displayName:@"SuperH SH-4 (BE)" arch:VMStartArchSH4EB
                                       binary:@"qemu-system-sh4eb" bitWidth:32 category:@"Embedded"
                              machines:@[@"r2d"] defaultMachine:@"r2d"
                                  cpus:@[@"sh7751", @"sh7751r"] defaultCPU:@"sh7751"
                           minMem:16 maxMem:1024 defaultMem:64 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"microblaze" displayName:@"MicroBlaze" arch:VMStartArchMicroBlaze
                                       binary:@"qemu-system-microblaze" bitWidth:32 category:@"Embedded"
                              machines:@[@"petalogix-s3adsp1800", @"petalogix-ml605", @"xlnx-zynqmp-pmu"] defaultMachine:@"petalogix-s3adsp1800"
                                  cpus:@[@"default"] defaultCPU:@"default"
                           minMem:16 maxMem:2048 defaultMem:128 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"microblazeel" displayName:@"MicroBlaze EL" arch:VMStartArchMicroBlazeEL
                                       binary:@"qemu-system-microblazeel" bitWidth:32 category:@"Embedded"
                              machines:@[@"petalogix-s3adsp1800", @"petalogix-ml605", @"xlnx-zynqmp-pmu"] defaultMachine:@"petalogix-s3adsp1800"
                                  cpus:@[@"default"] defaultCPU:@"default"
                           minMem:16 maxMem:2048 defaultMem:128 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"or1k" displayName:@"OpenRISC 1000" arch:VMStartArchOR1K
                                       binary:@"qemu-system-or1k" bitWidth:32 category:@"Open"
                              machines:@[@"virt", @"or1k-sim"] defaultMachine:@"virt"
                                  cpus:@[@"or1200", @"any"] defaultCPU:@"or1200"
                           minMem:16 maxMem:2048 defaultMem:128 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"loongarch64" displayName:@"LoongArch64" arch:VMStartArchLoongArch64
                                       binary:@"qemu-system-loongarch64" bitWidth:64 category:@"Modern"
                              machines:@[@"virt"] defaultMachine:@"virt"
                                  cpus:@[@"la464-loongarch-cpu", @"max"] defaultCPU:@"la464-loongarch-cpu"
                           minMem:256 maxMem:32768 defaultMem:2048 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"xtensa" displayName:@"Xtensa" arch:VMStartArchXtensa
                                       binary:@"qemu-system-xtensa" bitWidth:32 category:@"Embedded"
                              machines:@[@"sim", @"virt", @"lx60", @"lx60-nommu", @"lx200", @"lx200-nommu",
                                          @"ml605", @"ml605-nommu", @"kc705", @"kc705-nommu"] defaultMachine:@"sim"
                                  cpus:@[@"default", @"dc232b", @"dc233c", @"de212", @"test_mmuhifi_c3", @"test_kc705_be"] defaultCPU:@"default"
                           minMem:16 maxMem:1024 defaultMem:128 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"xtensaeb" displayName:@"Xtensa (BE)" arch:VMStartArchXtensaEB
                                       binary:@"qemu-system-xtensaeb" bitWidth:32 category:@"Embedded"
                              machines:@[@"sim", @"virt", @"lx60", @"lx60-nommu", @"lx200", @"lx200-nommu",
                                          @"ml605", @"ml605-nommu", @"kc705", @"kc705-nommu"] defaultMachine:@"sim"
                                  cpus:@[@"default", @"fsf", @"dsp3400"] defaultCPU:@"default"
                           minMem:16 maxMem:1024 defaultMem:128 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"tricore" displayName:@"TriCore" arch:VMStartArchTricore
                                       binary:@"qemu-system-tricore" bitWidth:32 category:@"Embedded"
                              machines:@[@"tricore_testboard", @"KIT_AURIX_TC277_TRB"] defaultMachine:@"tricore_testboard"
                                  cpus:@[@"tc1796", @"tc1797", @"tc27x"] defaultCPU:@"tc1796"
                           minMem:8 maxMem:512 defaultMem:64 accel:NO]];
    
    [profiles addObject:[self profileWithName:@"rx" displayName:@"RX (32-bit)" arch:VMStartArchRX
                                       binary:@"qemu-system-rx" bitWidth:32 category:@"Embedded"
                              machines:@[@"gdbsim-r5f562n8", @"gdbsim-r5f562n7"] defaultMachine:@"gdbsim-r5f562n8"
                                  cpus:@[@"rx62n"] defaultCPU:@"rx62n"
                           minMem:4 maxMem:256 defaultMem:32 accel:NO]];

    // ========== Additional GPLv2 emulator CPU families ==========
    [profiles addObject:[self profileWithName:@"mos6502" displayName:@"MOS 6502 (Commodore)" arch:VMStartArchMOS6502
                                       binary:@"" bitWidth:8 category:@"Retro"
                              machines:@[@"c64", @"c128", @"pet", @"vic20"] defaultMachine:@"c64"
                                  cpus:@[@"mos6502"] defaultCPU:@"mos6502"
                           minMem:1 maxMem:64 defaultMem:64 accel:NO]];

    [profiles addObject:[self profileWithName:@"z80" displayName:@"Z80 (MSX / Spectrum)" arch:VMStartArchZ80
                                       binary:@"" bitWidth:8 category:@"Retro"
                              machines:@[@"msx", @"msx2", @"msx2plus", @"msx-turboR",
                                          @"spectrum48", @"spectrum128", @"spectrum3"] defaultMachine:@"msx"
                                  cpus:@[@"z80"] defaultCPU:@"z80"
                           minMem:1 maxMem:64 defaultMem:64 accel:NO]];

    [profiles addObject:[self profileWithName:@"multisystem" displayName:@"Multi-System" arch:VMStartArchMultiSystem
                                       binary:@"" bitWidth:32 category:@"Retro"
                              machines:@[@"scummvm", @"mednafen-psx", @"mednafen-saturn", @"mednafen-pce",
                                          @"mednafen-gba", @"mednafen-gb", @"mednafen-nes", @"mednafen-snes"] defaultMachine:@"scummvm"
                                  cpus:@[@"auto"] defaultCPU:@"auto"
                           minMem:1 maxMem:2048 defaultMem:128 accel:NO]];

    self.profiles = [profiles copy];
}

- (VMStartArchitectureProfile *)profileWithName:(NSString *)name displayName:(NSString *)displayName
                                         arch:(VMStartArchitecture)arch binary:(NSString *)binary
                                     bitWidth:(NSInteger)bitWidth category:(NSString *)category
                                     machines:(NSArray<NSString *> *)machines defaultMachine:(NSString *)defaultMachine
                                         cpus:(NSArray<NSString *> *)cpus defaultCPU:(NSString *)defaultCPU
                                       minMem:(NSInteger)minMem maxMem:(NSInteger)maxMem defaultMem:(NSInteger)defaultMem
                                        accel:(BOOL)accel {
    VMStartArchitectureProfile *p = [[VMStartArchitectureProfile alloc] init];
    p.name = name;
    p.displayName = displayName;
    p.architecture = arch;
    p.qemuBinary = binary;
    p.bitWidth = bitWidth;
    p.category = category;
    p.supportedMachines = machines;
    p.defaultMachine = defaultMachine;
    p.supportedCPUs = cpus;
    p.defaultCPU = defaultCPU;
    p.minMemoryMB = minMem;
    p.maxMemoryMB = maxMem;
    p.defaultMemoryMB = defaultMem;
    p.supportsAcceleration = accel;
    return p;
}

- (NSArray<VMStartArchitectureProfile *> *)allProfiles {
    return self.profiles;
}

- (NSArray<VMStartArchitectureProfile *> *)profilesForCategory:(NSString *)category {
    return [self.profiles filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(VMStartArchitectureProfile *p, NSDictionary *bindings) {
        return [p.category isEqualToString:category];
    }]];
}

- (NSArray<NSString *> *)allCategories {
    NSOrderedSet *cats = [[NSOrderedSet alloc] initWithArray:[self.profiles valueForKeyPath:@"@unionOfObjects.category"]];
    return [cats array];
}

- (VMStartArchitectureProfile *)profileForArchitecture:(VMStartArchitecture)arch {
    for (VMStartArchitectureProfile *p in self.profiles) {
        if (p.architecture == arch) return p;
    }
    return nil;
}

- (BOOL)isQEMUInstalled {
    return [self availableQEMUBinaries].count > 0;
}

- (NSString *)pathForQEMUBinary:(NSString *)binaryName {
    NSArray *searchPaths = @[@"/opt/homebrew/bin", @"/usr/local/bin", @"/usr/bin"];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in searchPaths) {
        NSString *fullPath = [path stringByAppendingPathComponent:binaryName];
        if ([fm fileExistsAtPath:fullPath]) return fullPath;
    }
    return nil;
}

- (NSArray<NSString *> *)availableQEMUBinaries {
    NSMutableArray *found = [NSMutableArray array];
    NSArray *searchPaths = @[@"/opt/homebrew/bin", @"/usr/local/bin"];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *searchPath in searchPaths) {
        NSArray *files = [fm contentsOfDirectoryAtPath:searchPath error:nil];
        for (NSString *file in files) {
            if ([file hasPrefix:@"qemu-system-"]) {
                if (![found containsObject:file]) [found addObject:file];
            }
        }
    }
    return found;
}

- (NSString *)qemuVersionString {
    NSTask *task = [[NSTask alloc] init];
    NSString *binary = [self pathForQEMUBinary:@"qemu-system-x86_64"];
    if (!binary) return @"QEMU not found";
    task.executableURL = [NSURL fileURLWithPath:binary];
    task.arguments = @[@"--version"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    [task launch];
    [task waitUntilExit];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output ?: @"Unknown";
}

- (NSString *)qemuMajorMinorVersion {
    NSString *ver = [self qemuVersionString];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"(\\d+\\.\\d+)" options:0 error:nil];
    NSTextCheckingResult *match = [re firstMatchInString:ver options:0 range:NSMakeRange(0, ver.length)];
    if (match) return [ver substringWithRange:match.range];
    return @"0.0";
}

#pragma mark - Dynamic QEMU Query

- (NSString *)runQEMUCommand:(NSString *)binary args:(NSArray *)args {
    NSString *path = [self pathForQEMUBinary:binary];
    if (!path) return @"";
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:path];
    task.arguments = args;
    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    task.standardError = errPipe;
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        return @"";
    }
    NSData *data = [[outPipe fileHandleForReading] readDataToEndOfFile];
    if (data.length == 0) {
        data = [[errPipe fileHandleForReading] readDataToEndOfFile];
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

- (NSArray<VMStartMachineInfo *> *)queryMachinesForBinary:(NSString *)binaryName {
    NSString *output = [self runQEMUCommand:binaryName args:@[@"-M", @"help"]];
    if (output.length == 0) return @[];
    NSMutableArray *results = [NSMutableArray array];
    NSArray *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length == 0 || [trimmed hasPrefix:@"Supported"]) continue;
        // Parse: "name                 Description (details) (deprecated)"
        NSScanner *scanner = [NSScanner scannerWithString:trimmed];
        NSString *name = nil;
        if ([scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&name] && name.length > 0) {
            if ([name isEqualToString:@"none"]) continue;
            NSString *rest = [[trimmed substringFromIndex:scanner.scanLocation] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            VMStartMachineInfo *info = [[VMStartMachineInfo alloc] init];
            info.name = name;
            info.isDeprecated = [rest containsString:@"(deprecated)"];
            info.isDefault = [rest containsString:@"(default)"];
            info.machineDescription = rest;
            [results addObject:info];
        }
    }
    return results;
}

- (NSArray<NSString *> *)queryCPUsForBinary:(NSString *)binaryName {
    NSString *output = [self runQEMUCommand:binaryName args:@[@"-cpu", @"help"]];
    if (output.length == 0) return @[];
    NSMutableArray *results = [NSMutableArray array];
    NSArray *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    // Known CPU feature flags to exclude
    NSSet *featureFlags = [NSSet setWithArray:@[
        @"3dnow", @"amx", @"avx", @"base", @"cid", @"dtes64", @"flush",
        @"fsrs", @"ia64", @"invpcid", @"lm", @"max", @"movbe", @"npt",
        @"pause", @"pmm", @"pse36", @"rsba", @"sgx", @"smx", @"ssbd",
        @"svm", @"tsc", @"vaes", @"wbnoinvd", @"xsave", @"Recognized",
        @"core-capability", @"perfctr-core", @"kvmclock-stable-bit",
        @"amd-psfd", @"pmm-en"
    ]];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length == 0 || [trimmed hasPrefix:@"Available"]) continue;
        NSScanner *scanner = [NSScanner scannerWithString:trimmed];
        NSString *cpuName = nil;
        if ([scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&cpuName] && cpuName.length > 0) {
            // Skip versioned variants (e.g. Broadwell-v2) and feature flags
            if ([cpuName containsString:@"-v"] && [cpuName rangeOfString:@"-v"].location > 0) {
                NSString *suffix = [cpuName substringFromIndex:[cpuName rangeOfString:@"-v"].location];
                NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^-v\\d+$" options:0 error:nil];
                if ([re numberOfMatchesInString:suffix options:0 range:NSMakeRange(0, suffix.length)] > 0) {
                    continue;
                }
            }
            // Skip pure feature flags
            BOOL isFeature = NO;
            for (NSString *flag in featureFlags) {
                if ([cpuName isEqualToString:flag] || [cpuName hasPrefix:flag]) {
                    if (cpuName.length <= flag.length + 20) { isFeature = YES; break; }
                }
            }
            if (isFeature) continue;
            if (![results containsObject:cpuName]) {
                [results addObject:cpuName];
            }
        }
    }
    return results;
}

- (void)refreshDynamicData {
    for (VMStartArchitectureProfile *profile in self.profiles) {
        NSString *binary = profile.qemuBinary;
        if ([self pathForQEMUBinary:binary]) {
            profile.dynamicMachines = [self queryMachinesForBinary:binary];
            profile.dynamicCPUs = [self queryCPUsForBinary:binary];
        }
    }
}

@end

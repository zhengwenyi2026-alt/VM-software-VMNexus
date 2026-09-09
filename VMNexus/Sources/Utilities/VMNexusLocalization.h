//
//  VMNexusLocalization.h
//  VMNexus
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#ifndef VMNexusLocalization_h
#define VMNexusLocalization_h

#define AMLocalizedString(key) NSLocalizedString(key, nil)
#define AMLocalizedStringF(key, ...) [NSString stringWithFormat:NSLocalizedString(key, nil), __VA_ARGS__]

#endif /* VMNexusLocalization_h */

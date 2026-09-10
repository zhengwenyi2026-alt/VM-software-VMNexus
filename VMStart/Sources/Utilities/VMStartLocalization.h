//
//  VMStartLocalization.h
//  VMStart
//
//  Copyright (c) 2024 zhengwenyi2026-alt. Licensed under GPLv2.
//

#ifndef VMStartLocalization_h
#define VMStartLocalization_h

#define AMLocalizedString(key) NSLocalizedString(key, nil)
#define AMLocalizedStringF(key, ...) [NSString stringWithFormat:NSLocalizedString(key, nil), __VA_ARGS__]

#endif /* VMStartLocalization_h */

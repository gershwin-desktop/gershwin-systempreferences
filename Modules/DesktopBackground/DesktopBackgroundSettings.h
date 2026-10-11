/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import <Foundation/Foundation.h>

/* The numbers are the ones Workspace stores under "imagestyle". */
typedef enum {
  DesktopBackgroundStyleCenter = 0,
  DesktopBackgroundStyleFit = 1,
  DesktopBackgroundStyleTile = 2,
  DesktopBackgroundStyleScale = 3
} DesktopBackgroundStyle;

/* The desktop background settings Workspace keeps in the "desktopinfo"
 * dictionary of its defaults domain. */
@interface DesktopBackgroundSettings : NSObject
{
  NSDictionary *info;
  NSMutableDictionary *changes;
}

- (id)initWithDomain:(NSDictionary *)aDomain;

- (void)getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue
         alpha:(CGFloat *)alpha;
- (void)setRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
         alpha:(CGFloat)alpha;
- (BOOL)useImage;
- (void)setUseImage:(BOOL)use;
- (NSString *)imagePath;
- (void)setImagePath:(NSString *)path;
- (DesktopBackgroundStyle)style;
- (void)setStyle:(DesktopBackgroundStyle)style;

/* The stored "desktopinfo" with the changes applied. Workspace keeps icon
 * settings in the same dictionary, so they are carried over untouched. Empty
 * if nothing was stored and nothing was set. */
- (NSDictionary *)desktopInfo;

@end

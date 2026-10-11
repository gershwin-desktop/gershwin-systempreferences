/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import <Foundation/Foundation.h>

/* The numbers are the ones Workspace stores under "dockposition". */
typedef enum {
  DockSettingsPositionLeft = 0,
  DockSettingsPositionRight = 1,
  DockSettingsPositionBottom = 2
} DockSettingsPosition;

typedef enum {
  DockSettingsStyleClassic = 0,
  DockSettingsStyleModern = 1
} DockSettingsStyle;

/* The Dock settings Workspace keeps in its defaults domain. Only keys the
 * caller sets are part of -changedDomain, so the pane never writes back
 * values the user did not touch. */
@interface DockSettings : NSObject
{
  NSDictionary *domain;
  NSMutableDictionary *changes;
}

+ (DockSettingsPosition)positionForPopupIndex:(NSInteger)index;
+ (NSInteger)popupIndexForPosition:(DockSettingsPosition)position;

- (id)initWithDomain:(NSDictionary *)aDomain;

- (DockSettingsPosition)position;
- (void)setPosition:(DockSettingsPosition)position;
- (BOOL)dockVisible;
- (void)setDockVisible:(BOOL)visible;
- (DockSettingsStyle)style;
- (void)setStyle:(DockSettingsStyle)style;
- (BOOL)magnificationEnabled;
- (void)setMagnificationEnabled:(BOOL)enabled;

/* Only the keys that were set since -initWithDomain:. */
- (NSDictionary *)changedDomain;

@end

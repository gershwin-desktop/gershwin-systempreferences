/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import "DockSettings.h"

static NSString *const KeyPosition = @"dockposition";
static NSString *const KeyHidden = @"hidedock";
static NSString *const KeyStyle = @"dockstyle";
static NSString *const KeyMagnification = @"dockmagnification";

@implementation DockSettings

/* The pop-up lists Left, Bottom, Right; Workspace numbers them Left, Right,
 * Bottom. */
+ (DockSettingsPosition)positionForPopupIndex:(NSInteger)index
{
  switch (index)
    {
      case 0: return DockSettingsPositionLeft;
      case 1: return DockSettingsPositionBottom;
      default: return DockSettingsPositionRight;
    }
}

+ (NSInteger)popupIndexForPosition:(DockSettingsPosition)position
{
  switch (position)
    {
      case DockSettingsPositionLeft: return 0;
      case DockSettingsPositionBottom: return 1;
      default: return 2;
    }
}

- (id)initWithDomain:(NSDictionary *)aDomain
{
  self = [super init];
  if (self)
    {
      domain = [aDomain copy];
      changes = [NSMutableDictionary new];
    }
  return self;
}

- (void)dealloc
{
  [domain release];
  [changes release];
  [super dealloc];
}

/* A value set since init wins over the one read from the domain. */
- (id)storedValueForKey:(NSString *)key
{
  id value = [changes objectForKey: key];

  return value ? value : [domain objectForKey: key];
}

- (DockSettingsPosition)position
{
  id value = [self storedValueForKey: KeyPosition];

  /* Workspace falls back to the right edge when nothing is stored. */
  if (value == nil)
    return DockSettingsPositionRight;
  switch ([value intValue])
    {
      case DockSettingsPositionLeft: return DockSettingsPositionLeft;
      case DockSettingsPositionBottom: return DockSettingsPositionBottom;
      default: return DockSettingsPositionRight;
    }
}

- (void)setPosition:(DockSettingsPosition)position
{
  [changes setObject: [NSNumber numberWithInt: position] forKey: KeyPosition];
}

- (BOOL)dockVisible
{
  return ![[self storedValueForKey: KeyHidden] boolValue];
}

- (void)setDockVisible:(BOOL)visible
{
  [changes setObject: [NSNumber numberWithBool: !visible] forKey: KeyHidden];
}

- (DockSettingsStyle)style
{
  return ([[self storedValueForKey: KeyStyle] intValue] == DockSettingsStyleModern)
    ? DockSettingsStyleModern : DockSettingsStyleClassic;
}

- (void)setStyle:(DockSettingsStyle)style
{
  [changes setObject: [NSNumber numberWithInt: style] forKey: KeyStyle];
}

- (BOOL)magnificationEnabled
{
  id value = [self storedValueForKey: KeyMagnification];

  return (value == nil) ? YES : [value boolValue];
}

- (void)setMagnificationEnabled:(BOOL)enabled
{
  [changes setObject: [NSNumber numberWithBool: enabled] forKey: KeyMagnification];
}

- (NSDictionary *)changedDomain
{
  return [[changes copy] autorelease];
}

@end

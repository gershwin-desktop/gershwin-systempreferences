/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import "DesktopBackgroundSettings.h"

static NSString *const KeyDesktopInfo = @"desktopinfo";
static NSString *const KeyColor = @"backcolor";
static NSString *const KeyUseImage = @"usebackimage";
static NSString *const KeyImagePath = @"imagepath";
static NSString *const KeyStyle = @"imagestyle";

@implementation DesktopBackgroundSettings

- (id)initWithDomain:(NSDictionary *)aDomain
{
  self = [super init];
  if (self)
    {
      info = [[aDomain objectForKey: KeyDesktopInfo] copy];
      changes = [NSMutableDictionary new];
    }
  return self;
}

- (void)dealloc
{
  [info release];
  [changes release];
  [super dealloc];
}

/* A value set since init wins over the stored one. */
- (id)storedValueForKey:(NSString *)key
{
  id value = [changes objectForKey: key];

  return value ? value : [info objectForKey: key];
}

- (void)getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue
         alpha:(CGFloat *)alpha
{
  NSDictionary *color = [self storedValueForKey: KeyColor];

  /* Workspace's built-in desktop color when nothing is stored. */
  if (color == nil)
    {
      *red = (CGFloat)0.39f;
      *green = (CGFloat)0.51f;
      *blue = (CGFloat)0.57f;
      *alpha = 1.0;
      return;
    }
  *red = [[color objectForKey: @"red"] floatValue];
  *green = [[color objectForKey: @"green"] floatValue];
  *blue = [[color objectForKey: @"blue"] floatValue];
  *alpha = [[color objectForKey: @"alpha"] floatValue];
}

- (void)setRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
         alpha:(CGFloat)alpha
{
  /* Workspace stores floats, not doubles. */
  [changes setObject: [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSNumber numberWithFloat: red], @"red",
                         [NSNumber numberWithFloat: green], @"green",
                         [NSNumber numberWithFloat: blue], @"blue",
                         [NSNumber numberWithFloat: alpha], @"alpha", nil]
              forKey: KeyColor];
}

- (BOOL)useImage
{
  return [[self storedValueForKey: KeyUseImage] boolValue];
}

- (void)setUseImage:(BOOL)use
{
  [changes setObject: [NSNumber numberWithBool: use] forKey: KeyUseImage];
}

- (NSString *)imagePath
{
  return [self storedValueForKey: KeyImagePath];
}

- (void)setImagePath:(NSString *)path
{
  [changes setObject: path forKey: KeyImagePath];
}

- (DesktopBackgroundStyle)style
{
  switch ([[self storedValueForKey: KeyStyle] intValue])
    {
      case DesktopBackgroundStyleFit: return DesktopBackgroundStyleFit;
      case DesktopBackgroundStyleTile: return DesktopBackgroundStyleTile;
      case DesktopBackgroundStyleScale: return DesktopBackgroundStyleScale;
      default: return DesktopBackgroundStyleCenter;
    }
}

- (void)setStyle:(DesktopBackgroundStyle)style
{
  [changes setObject: [NSNumber numberWithInt: style] forKey: KeyStyle];
}

- (NSDictionary *)desktopInfo
{
  NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary: info];

  [merged addEntriesFromDictionary: changes];
  return merged;
}

@end

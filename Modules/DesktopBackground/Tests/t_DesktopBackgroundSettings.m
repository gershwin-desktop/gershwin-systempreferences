/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#import "../DesktopBackgroundSettings.h"

int main(void)
{
  CREATE_AUTORELEASE_POOL(pool);
  DesktopBackgroundSettings *s;
  NSDictionary *info, *color;
  CGFloat r, g, b, a;

  START_SET("defaults of an empty domain match Workspace")
    s = [[DesktopBackgroundSettings alloc] initWithDomain: [NSDictionary dictionary]];
    [s getRed: &r green: &g blue: &b alpha: &a];
    PASS(r == (CGFloat)0.39f && g == (CGFloat)0.51f && b == (CGFloat)0.57f && a == 1.0,
         "color defaults to Workspace's blue-grey");
    PASS(![s useImage], "no image by default");
    PASS([s imagePath] == nil, "no image path by default");
    PASS([s style] == DesktopBackgroundStyleCenter, "style defaults to center");
    PASS([[s desktopInfo] count] == 0, "nothing is written unless changed");
    RELEASE(s);
  END_SET("defaults of an empty domain match Workspace")

  START_SET("values read from desktopinfo")
    info = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat: 0.25], @"red", [NSNumber numberWithFloat: 0.5], @"green",
        [NSNumber numberWithFloat: 0.75], @"blue", [NSNumber numberWithFloat: 1.0], @"alpha",
        nil], @"backcolor",
      [NSNumber numberWithBool: YES], @"usebackimage",
      @"/tmp/x.png", @"imagepath",
      [NSNumber numberWithInt: 2], @"imagestyle", nil];
    s = [[DesktopBackgroundSettings alloc] initWithDomain:
      [NSDictionary dictionaryWithObject: info forKey: @"desktopinfo"]];
    [s getRed: &r green: &g blue: &b alpha: &a];
    PASS(r == (CGFloat)0.25f && g == (CGFloat)0.5f && b == (CGFloat)0.75f, "backcolor read");
    PASS([s useImage], "usebackimage read");
    PASS_EQUAL([s imagePath], @"/tmp/x.png", "imagepath read");
    PASS([s style] == DesktopBackgroundStyleTile, "imagestyle 2 is tile");
    RELEASE(s);
  END_SET("values read from desktopinfo")

  START_SET("writing keeps the other desktopinfo keys")
    info = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 48] forKey: @"iconsize"];
    s = [[DesktopBackgroundSettings alloc] initWithDomain:
      [NSDictionary dictionaryWithObject: info forKey: @"desktopinfo"]];
    [s setRed: 1.0 green: 0.0 blue: 0.5 alpha: 1.0];
    [s setUseImage: YES];
    [s setImagePath: @"/a/b.jpg"];
    [s setStyle: DesktopBackgroundStyleScale];
    info = [s desktopInfo];
    color = [info objectForKey: @"backcolor"];
    PASS_EQUAL([color objectForKey: @"red"], [NSNumber numberWithFloat: 1.0], "red stored");
    PASS_EQUAL([color objectForKey: @"blue"], [NSNumber numberWithFloat: 0.5], "blue stored");
    PASS_EQUAL([info objectForKey: @"usebackimage"], [NSNumber numberWithBool: YES],
               "usebackimage stored");
    PASS_EQUAL([info objectForKey: @"imagepath"], @"/a/b.jpg", "imagepath stored");
    PASS_EQUAL([info objectForKey: @"imagestyle"], [NSNumber numberWithInt: 3],
               "scale stored as 3");
    PASS_EQUAL([info objectForKey: @"iconsize"], [NSNumber numberWithInt: 48],
               "keys the pane does not own survive");
    RELEASE(s);
  END_SET("writing keeps the other desktopinfo keys")

  DESTROY(pool);
  return 0;
}

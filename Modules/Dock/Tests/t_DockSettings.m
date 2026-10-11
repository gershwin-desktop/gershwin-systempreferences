/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#import "../DockSettings.h"

int main(void)
{
  CREATE_AUTORELEASE_POOL(pool);
  DockSettings *s;
  NSDictionary *out;

  START_SET("defaults of an empty domain match Workspace")
    s = [[DockSettings alloc] initWithDomain: [NSDictionary dictionary]];
    PASS([s position] == DockSettingsPositionRight, "position defaults to right");
    PASS([s dockVisible], "dock defaults to shown");
    PASS([s style] == DockSettingsStyleClassic, "style defaults to classic");
    PASS([s magnificationEnabled], "magnification defaults to on");
    PASS([[s changedDomain] count] == 0, "nothing is written unless changed");
    RELEASE(s);
  END_SET("defaults of an empty domain match Workspace")

  START_SET("values read from the Workspace keys")
    s = [[DockSettings alloc] initWithDomain: [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt: 2], @"dockposition",
      [NSNumber numberWithBool: YES], @"hidedock",
      [NSNumber numberWithInt: 1], @"dockstyle",
      [NSNumber numberWithBool: NO], @"dockmagnification", nil]];
    PASS([s position] == DockSettingsPositionBottom, "dockposition 2 is bottom");
    PASS(![s dockVisible], "hidedock YES means not shown");
    PASS([s style] == DockSettingsStyleModern, "dockstyle 1 is modern");
    PASS(![s magnificationEnabled], "dockmagnification NO is off");
    RELEASE(s);
  END_SET("values read from the Workspace keys")

  START_SET("writing")
    s = [[DockSettings alloc] initWithDomain: [NSDictionary dictionaryWithObject: @"keep"
                                                                         forKey: @"other"]];
    [s setPosition: DockSettingsPositionLeft];
    [s setDockVisible: NO];
    [s setStyle: DockSettingsStyleModern];
    [s setMagnificationEnabled: NO];
    out = [s changedDomain];
    PASS_EQUAL([out objectForKey: @"dockposition"], [NSNumber numberWithInt: 0],
               "left is stored as 0");
    PASS_EQUAL([out objectForKey: @"hidedock"], [NSNumber numberWithBool: YES],
               "hiding the dock stores hidedock YES");
    PASS_EQUAL([out objectForKey: @"dockstyle"], [NSNumber numberWithInt: 1],
               "modern is stored as 1");
    PASS_EQUAL([out objectForKey: @"dockmagnification"], [NSNumber numberWithBool: NO],
               "magnification off stored as NO");
    PASS(![out objectForKey: @"other"], "unrelated keys are not part of the change");
    RELEASE(s);
  END_SET("writing")

  START_SET("popup order")
    PASS([DockSettings positionForPopupIndex: 0] == DockSettingsPositionLeft, "row 0 left");
    PASS([DockSettings positionForPopupIndex: 1] == DockSettingsPositionBottom, "row 1 bottom");
    PASS([DockSettings positionForPopupIndex: 2] == DockSettingsPositionRight, "row 2 right");
    PASS([DockSettings popupIndexForPosition: DockSettingsPositionBottom] == 1, "bottom is row 1");
    PASS([DockSettings popupIndexForPosition: DockSettingsPositionRight] == 2, "right is row 2");
  END_SET("popup order")

  DESTROY(pool);
  return 0;
}

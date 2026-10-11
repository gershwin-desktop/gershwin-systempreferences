/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import <Foundation/Foundation.h>
#import "PreferencePanes.h"

@class NSBox, NSButton, NSPopUpButton, NSTextField;

@interface DockPreferences : NSPreferencePane
{
  NSView *mainView;
  NSBox *dockBox;
  NSButton *showCheck;
  NSTextField *positionLabel;
  NSPopUpButton *positionPopUp;
  NSTextField *styleLabel;
  NSPopUpButton *stylePopUp;
  NSButton *magnificationCheck;
}

- (void)relayoutForSize:(NSSize)size;

@end

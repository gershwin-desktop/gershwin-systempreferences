/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import <Foundation/Foundation.h>
#import "PreferencePanes.h"

@class NSBox, NSButton, NSColorWell, NSPopUpButton, NSTextField;

@interface DesktopBackgroundPreferences : NSPreferencePane
{
  NSView *mainView;
  NSBox *backgroundBox;
  NSTextField *colorLabel;
  NSColorWell *colorWell;
  NSButton *useImageCheck;
  NSTextField *imageLabel;
  NSTextField *imageField;
  NSButton *chooseButton;
  NSTextField *styleLabel;
  NSPopUpButton *stylePopUp;
}

- (void)relayoutForSize:(NSSize)size;

@end

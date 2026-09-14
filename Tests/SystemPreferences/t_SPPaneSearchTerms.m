/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */

/* ObjectTesting coverage for SPPaneSearchTerms: which widget texts of a
 * pane's view hierarchy become searchable, and how a search string matches.
 * Needs an X11 display because AppKit controls load fonts on creation. */

#import <AppKit/AppKit.h>
#import "Testing.h"
#include "../../SystemPreferences/SPPaneSearchTerms.m"

static NSTextField *label(NSString *text)
{
  NSTextField *f = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 100, 20)] autorelease];
  [f setEditable: NO];
  [f setStringValue: text];
  return f;
}

int main(void)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  [NSApplication sharedApplication];

  NSView *root = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 400, 300)] autorelease];

  NSBox *box = [[[NSBox alloc] initWithFrame: NSMakeRect(0, 0, 300, 200)] autorelease];
  [box setTitle: @"Display Settings"];
  [[box contentView] addSubview: label(@"Scale Factor:")];
  [root addSubview: box];

  NSButton *check = [[[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 100, 20)] autorelease];
  [check setButtonType: NSSwitchButton];
  [check setTitle: @"Mirror Displays"];
  [root addSubview: check];

  NSTextField *editable = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 100, 20)] autorelease];
  [editable setEditable: YES];
  [editable setStringValue: @"my-hostname"];
  [root addSubview: editable];

  NSPopUpButton *popup = [[[NSPopUpButton alloc] initWithFrame: NSMakeRect(0, 0, 100, 20)
                                                     pullsDown: NO] autorelease];
  [popup addItemsWithTitles: [NSArray arrayWithObjects: @"Left Handed", @"Right Handed", nil]];
  [root addSubview: popup];

  NSTabView *tabs = [[[NSTabView alloc] initWithFrame: NSMakeRect(0, 0, 300, 200)] autorelease];
  NSTabViewItem *first = [[[NSTabViewItem alloc] initWithIdentifier: @"a"] autorelease];
  [first setLabel: @"General"];
  [first setView: [[[NSView alloc] initWithFrame: NSZeroRect] autorelease]];
  NSTabViewItem *second = [[[NSTabViewItem alloc] initWithIdentifier: @"b"] autorelease];
  [second setLabel: @"Advanced"];
  NSView *secondView = [[[NSView alloc] initWithFrame: NSZeroRect] autorelease];
  [secondView addSubview: label(@"Key Repeat Rate")];
  [second setView: secondView];
  [tabs addTabViewItem: first];
  [tabs addTabViewItem: second];
  [tabs selectTabViewItem: first];
  [root addSubview: tabs];

  NSButtonCell *radioProto = [[[NSButtonCell alloc] init] autorelease];
  [radioProto setButtonType: NSRadioButton];
  NSMatrix *matrix = [[[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 40)
                                                 mode: NSRadioModeMatrix
                                            prototype: radioProto
                                         numberOfRows: 2
                                      numberOfColumns: 1] autorelease];
  [[matrix cellAtRow: 0 column: 0] setTitle: @"Use 24-Hour Clock"];
  [[matrix cellAtRow: 1 column: 0] setTitle: @"Use 12-Hour Clock"];
  [root addSubview: matrix];

  NSTableView *table = [[[NSTableView alloc] initWithFrame: NSMakeRect(0, 0, 200, 100)] autorelease];
  NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier: @"c"] autorelease];
  [[column headerCell] setStringValue: @"Printer Name"];
  [table addTableColumn: column];
  [root addSubview: table];

  [root addSubview: label(@"Scale Factor:")];
  [root addSubview: label(@"   ")];

  SPPaneSearchTerms *terms = [[[SPPaneSearchTerms alloc] initWithView: root] autorelease];
  NSArray *all = [terms terms];

  PASS([all containsObject: @"Scale Factor:"], "static label text is collected");
  PASS([all containsObject: @"Display Settings"], "box titles are collected");
  PASS([all containsObject: @"Mirror Displays"], "button titles are collected");
  PASS(![all containsObject: @"my-hostname"], "editable field contents (user data) are not collected");
  PASS([all containsObject: @"Left Handed"] && [all containsObject: @"Right Handed"],
       "all popup item titles are collected, not only the selected one");
  PASS([all containsObject: @"General"] && [all containsObject: @"Advanced"], "tab labels are collected");
  PASS([all containsObject: @"Key Repeat Rate"], "labels on a tab that is not selected are collected");
  PASS([all containsObject: @"Use 24-Hour Clock"] && [all containsObject: @"Use 12-Hour Clock"],
       "matrix cell titles are collected");
  PASS([all containsObject: @"Printer Name"], "table column headers are collected");

  NSUInteger scaleCount = 0;
  for (NSString *t in all)
    {
      if ([t isEqualToString: @"Scale Factor:"])
        scaleCount++;
    }
  PASS(scaleCount == 1, "duplicate texts are collected once");
  PASS(![all containsObject: @"   "] && ![all containsObject: @""], "blank texts are skipped");

  PASS([terms matchesString: @"Scale Factor"], "matches a widget label without its trailing colon");
  PASS([terms matchesString: @"scale factor"], "matching ignores case");
  PASS([terms matchesString: @"repeat"], "matches a substring of a widget label");
  PASS(![terms matchesString: @"hostname"], "does not match user data from editable fields");
  PASS(![terms matchesString: @"Brightness"], "does not match text that no widget shows");

  SPPaneSearchTerms *nilView = [[[SPPaneSearchTerms alloc] initWithView: nil] autorelease];
  PASS([[nilView terms] count] == 0 && ![nilView matchesString: @"a"], "a nil view has no terms");

  [arp release];
  return 0;
}

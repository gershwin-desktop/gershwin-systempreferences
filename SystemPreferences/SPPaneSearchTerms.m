/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */

#import <AppKit/AppKit.h>
#import "SPPaneSearchTerms.h"

static void addText(NSString *text, NSMutableOrderedSet *found)
{
  NSString *trimmed = [text stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];

  if ([trimmed length] > 0) {
    [found addObject: trimmed];
  }
}

static void collectFromView(NSView *view, NSMutableOrderedSet *found)
{
  if (view == nil) {
    return;
  }

  if ([view isKindOfClass: [NSTextField class]]) {
    // Editable fields hold user data such as host names, not setting names.
    if (![(NSTextField *)view isEditable]) {
      addText([(NSTextField *)view stringValue], found);
    }
  } else if ([view isKindOfClass: [NSPopUpButton class]]) {
    // The choices are what users search for, not just the one selected now.
    for (NSString *title in [(NSPopUpButton *)view itemTitles]) {
      addText(title, found);
    }
  } else if ([view isKindOfClass: [NSButton class]]) {
    // Image-only buttons still carry the placeholder title "Button".
    if ([(NSButton *)view imagePosition] != NSImageOnly) {
      addText([(NSButton *)view title], found);
    }
  } else if ([view isKindOfClass: [NSBox class]]) {
    // Untitled boxes still carry the placeholder title "Title".
    if ([(NSBox *)view titlePosition] != NSNoTitle) {
      addText([(NSBox *)view title], found);
    }
  } else if ([view isKindOfClass: [NSMatrix class]]) {
    for (NSCell *cell in [(NSMatrix *)view cells]) {
      addText([cell title], found);
    }
  } else if ([view isKindOfClass: [NSTableView class]]) {
    for (NSTableColumn *column in [(NSTableView *)view tableColumns]) {
      addText([[column headerCell] stringValue], found);
    }
  } else if ([view isKindOfClass: [NSTabView class]]) {
    /* Only the selected tab's view is a subview, but the other tabs hold
       settings too, so walk every item instead of the subviews. */
    for (NSTabViewItem *item in [(NSTabView *)view tabViewItems]) {
      addText([item label], found);
      collectFromView([item view], found);
    }
    return;
  }

  for (NSView *subview in [view subviews]) {
    collectFromView(subview, found);
  }
}

@implementation SPPaneSearchTerms

- (void)dealloc
{
  RELEASE(terms);
  [super dealloc];
}

- (instancetype)initWithView:(NSView *)view
{
  self = [super init];

  if (self) {
    NSMutableOrderedSet *found = [NSMutableOrderedSet orderedSet];

    collectFromView(view, found);
    terms = [[found array] copy];
  }

  return self;
}

- (NSArray *)terms
{
  return terms;
}

- (BOOL)matchesString:(NSString *)searchString
{
  if ([searchString length] == 0) {
    return NO;
  }

  for (NSString *term in terms) {
    if ([term rangeOfString: searchString
                    options: NSCaseInsensitiveSearch].location != NSNotFound) {
      return YES;
    }
  }

  return NO;
}

@end

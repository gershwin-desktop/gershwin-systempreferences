/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */

#ifndef SP_PANE_SEARCH_TERMS_H
#define SP_PANE_SEARCH_TERMS_H

#import <Foundation/Foundation.h>

@class NSView;

/* The texts a pane shows in its widgets, so that searching for a setting
   such as "Scale Factor" finds the pane that contains it even though the
   pane's own label ("Display") does not mention it. */
@interface SPPaneSearchTerms : NSObject
{
  NSArray *terms;
}

- (instancetype)initWithView:(NSView *)view;

- (NSArray *)terms;

- (BOOL)matchesString:(NSString *)searchString;

@end

#endif // SP_PANE_SEARCH_TERMS_H

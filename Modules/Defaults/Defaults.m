/* Defaults.m
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
 * Date: February 2006
 *
 * This file is part of the GNUstep "Defaults" Preference Pane
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <AppKit/AppKit.h>
#import "Defaults.h"
#import "AppearanceMetrics.h"

#include <limits.h>  // For INT_MAX and INT_MIN

/* The pane view. When the host box gives us a size (which is not the
   640x440 base we built at), re-lay out everything so margins stay
   symmetric and rows stay top-anchored. */
@interface DefaultsMainView : NSView
{
  Defaults *_layoutOwner;
}
@end

@implementation DefaultsMainView
- (void)setFrameSize:(NSSize)newSize
{
  [super setFrameSize:newSize];
  [_layoutOwner relayoutSubviewsForSize:newSize];
}
- (void)viewDidMoveToWindow
{
  [super viewDidMoveToWindow];
  if ([self window] && [self superview]) {
    /* The host box does not necessarily size the pane view to its content
       area; make it fill the box content and re-lay out. GNUstep's
       setFrame: bypasses setFrameSize:, so re-lay out explicitly here. */
    [self setFrame:[[self superview] bounds]];
    [_layoutOwner relayoutSubviewsForSize:[self bounds].size];
  }
}
- (void)setLayoutOwner:(Defaults *)owner
{
  _layoutOwner = owner;
}
@end

@implementation Defaults

+ (BOOL)isCompatible { return YES; }

/* No gorm: the whole pane is built in code so that spacing follows
   AppearanceMetrics.h exactly and survives window resizing. */
- (NSView *)loadMainView
{
  if (_mainView == nil) {
    _mainView = [[self createMainView] retain];
  }
  return _mainView;
}

- (NSString *)mainNibName
{
  return nil;
}

- (void)dealloc
{
  TEST_RELEASE (defaultsEntries);
  TEST_RELEASE (mainView);
  TEST_RELEASE (filterField);
  TEST_RELEASE (namesScroll);
  TEST_RELEASE (categoryLabel);
  TEST_RELEASE (categoryField);
  TEST_RELEASE (descriptionLabel);
  TEST_RELEASE (descriptionView);
  TEST_RELEASE (editorBox);
  TEST_RELEASE (stringEditorBox);
  TEST_RELEASE (stringEdField);
  TEST_RELEASE (stringEdDefaultRevert);
  TEST_RELEASE (stringEdSet);
  TEST_RELEASE (boolEditorBox);
  TEST_RELEASE (boolEdPopup);
  TEST_RELEASE (boolEdDefaultRevert);
  TEST_RELEASE (boolEdSet);
  TEST_RELEASE (numberEditorBox);
  TEST_RELEASE (numberEdField);
  TEST_RELEASE (numberEdDefaultRevert);
  TEST_RELEASE (numberEdSet);
  TEST_RELEASE (arrayEditorBox);
  TEST_RELEASE (arrayEdScroll);
  TEST_RELEASE (arrayEdField);
  TEST_RELEASE (arrayEdAdd);
  TEST_RELEASE (arrayEdRemove);
  TEST_RELEASE (arrayEdDefaultRevert);
  TEST_RELEASE (arrayEdSet);
  TEST_RELEASE (listEditorBox);
  TEST_RELEASE (listEdPopup);
  TEST_RELEASE (listEdDefaultRevert);
  TEST_RELEASE (listEdSet);

  [super dealloc];
}

#pragma mark - UI builders

/* A plain non-editable label. Returned retained; ownership passes to the
   caller's ivar. */
- (NSTextField *)labelWithText:(NSString *)text
                         frame:(NSRect)frame
                     alignment:(NSTextAlignment)alignment
{
  NSTextField *label = [[NSTextField alloc] initWithFrame:frame];

  [label setStringValue:text ?: @""];
  [label setBezeled:NO];
  [label setBordered:NO];
  [label setEditable:NO];
  [label setSelectable:NO];
  [label setDrawsBackground:NO];
  [label setFont:METRICS_FONT_SYSTEM_REGULAR_11];
  [label setAlignment:alignment];
  return label;
}

/* A push button, initially disabled (enablement is driven by selection).
   Returned retained; ownership passes to the caller's ivar. */
- (NSButton *)buttonWithTitle:(NSString *)title
                        frame:(NSRect)frame
                       action:(SEL)action
{
  NSButton *button = [[NSButton alloc] initWithFrame:frame];

  [button setTitle:title];
  [button setButtonType:NSMomentaryPushInButton];
  [button setBezelStyle:NSRoundedBezelStyle];
  [button setTarget:self];
  [button setAction:action];
  [button setEnabled:NO];
  return button;
}

/* The shared trailing button row of every editor: "Default value"
   (revert) on the left of "Set", hugging the container's bottom-trailing
   corner. Buttons start disabled; enablement is driven by selection and
   editing. */
- (void)addRevertButton:(NSButton **)revertOut
           revertAction:(SEL)revertAction
              setButton:(NSButton **)setOut
             setAction:(SEL)setAction
           toContainer:(NSView *)container
{
  CGFloat cw = [container frame].size.width;
  CGFloat pad = METRICS_SPACE_16;
  CGFloat bottomY = METRICS_SPACE_12;

  *setOut = [self buttonWithTitle:@"Set"
                            frame:NSMakeRect(cw - pad - METRICS_BUTTON_MIN_WIDTH,
                                             bottomY,
                                             METRICS_BUTTON_MIN_WIDTH,
                                             METRICS_BUTTON_HEIGHT)
                          action:setAction];
  [*setOut setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
  [container addSubview:*setOut];

  *revertOut = [self buttonWithTitle:@"Default value"
                              frame:NSMakeRect(cw - pad - METRICS_BUTTON_MIN_WIDTH
                                                 - METRICS_BUTTON_HORIZ_INTERSPACE
                                                 - 110,
                                               bottomY, 110,
                                               METRICS_BUTTON_HEIGHT)
                            action:revertAction];
  [*revertOut setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
  [container addSubview:*revertOut];
}

/* A small square "+" or "-" list-maintenance button. */
- (NSButton *)miniButtonWithTitle:(NSString *)title
                            frame:(NSRect)frame
                           action:(SEL)action
{
  NSButton *button = [[NSButton alloc] initWithFrame:frame];

  [button setTitle:title];
  [button setButtonType:NSMomentaryPushInButton];
  [button setBezelStyle:NSRegularSquareBezelStyle];
  [button setTarget:self];
  [button setAction:action];
  [button setEnabled:NO];
  return button;
}

/* A bezel-bordered scroll view hosting a single-column radio matrix of
   browser cells; used for the names list and for the array editor list. */
- (NSScrollView *)matrixListScrollWithFrame:(NSRect)frame
                                     action:(SEL)action
                                  matrixOut:(NSMatrix **)matrixOut
{
  NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:frame];
  NSBrowserCell *protoCell = [NSBrowserCell new];
  CGFloat lineH = [[protoCell font] defaultLineHeightForFont];
  NSMatrix *matrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
                                                mode: NSRadioModeMatrix
                                           prototype: protoCell
                                        numberOfRows: 0
                                     numberOfColumns: 0];

  RELEASE (protoCell);
  [scroll setBorderType: NSBezelBorder];
  [scroll setHasHorizontalScroller: NO];
  [scroll setHasVerticalScroller: YES];
  [matrix setIntercellSpacing: NSZeroSize];
  [matrix setCellSize: NSMakeSize([scroll contentSize].width, lineH)];
  [matrix setAutoscroll: YES];
  [matrix setAllowsEmptySelection: YES];
  [matrix setTarget: self];
  [matrix setAction: action];
  [scroll setDocumentView: matrix];
  RELEASE (matrix);
  *matrixOut = matrix;
  return scroll;
}

/* Editors live in plain containers swapped into editorBox via
   setContentView:, which sizes them to the box's content area; internal
   layout therefore relies on autoresizing masks only. */

- (NSView *)makeStringEditor
{
  const CGFloat cw = 300, ch = 80;
  NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, cw, ch)];

  stringEdField = [[NSTextField alloc] initWithFrame:
    NSMakeRect(METRICS_SPACE_16,
               ch - METRICS_SPACE_16 - METRICS_TEXT_INPUT_FIELD_HEIGHT,
               cw - 2 * METRICS_SPACE_16, METRICS_TEXT_INPUT_FIELD_HEIGHT)];
  [stringEdField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [stringEdField setDelegate:self];
  [container addSubview:stringEdField];

  [self addRevertButton:&stringEdDefaultRevert
           revertAction:@selector(stringDefaultRevertAction:)
              setButton:&stringEdSet
             setAction:@selector(stringSetAction:)
           toContainer:container];
  return container;
}

- (NSView *)makeNumberEditor
{
  const CGFloat cw = 300, ch = 80;
  NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, cw, ch)];

  numberEdField = [[NSTextField alloc] initWithFrame:
    NSMakeRect(METRICS_SPACE_16,
               ch - METRICS_SPACE_16 - METRICS_TEXT_INPUT_FIELD_HEIGHT,
               cw - 2 * METRICS_SPACE_16, METRICS_TEXT_INPUT_FIELD_HEIGHT)];
  [numberEdField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [numberEdField setDelegate:self];
  [container addSubview:numberEdField];

  [self addRevertButton:&numberEdDefaultRevert
           revertAction:@selector(numberDefaultRevertAction:)
              setButton:&numberEdSet
             setAction:@selector(numberSetAction:)
           toContainer:container];
  return container;
}

- (NSView *)makeBoolEditor
{
  const CGFloat cw = 300, ch = 80;
  NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, cw, ch)];

  boolEdPopup = [[NSPopUpButton alloc] initWithFrame:
    NSMakeRect(METRICS_SPACE_16,
               ch - METRICS_SPACE_16 - METRICS_TEXT_INPUT_FIELD_HEIGHT,
               cw - 2 * METRICS_SPACE_16, METRICS_TEXT_INPUT_FIELD_HEIGHT)];
  [boolEdPopup addItemWithTitle:@"NO"];
  [boolEdPopup addItemWithTitle:@"YES"];
  [boolEdPopup setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [boolEdPopup setTarget:self];
  [boolEdPopup setAction:@selector(boolPopupAction:)];
  [container addSubview:boolEdPopup];

  [self addRevertButton:&boolEdDefaultRevert
           revertAction:@selector(boolDefaultRevertAction:)
              setButton:&boolEdSet
             setAction:@selector(boolSetAction:)
           toContainer:container];
  return container;
}

- (NSView *)makeListEditor
{
  const CGFloat cw = 300, ch = 80;
  NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, cw, ch)];

  listEdPopup = [[NSPopUpButton alloc] initWithFrame:
    NSMakeRect(METRICS_SPACE_16,
               ch - METRICS_SPACE_16 - METRICS_TEXT_INPUT_FIELD_HEIGHT,
               cw - 2 * METRICS_SPACE_16, METRICS_TEXT_INPUT_FIELD_HEIGHT)];
  [listEdPopup addItemWithTitle:@"None"];
  [listEdPopup setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [listEdPopup setTarget:self];
  [listEdPopup setAction:@selector(listPopupAction:)];
  [container addSubview:listEdPopup];

  [self addRevertButton:&listEdDefaultRevert
           revertAction:@selector(listDefaultRevertAction:)
              setButton:&listEdSet
             setAction:@selector(listSetAction:)
           toContainer:container];
  return container;
}

- (NSView *)makeArrayEditor
{
  const CGFloat cw = 300, ch = 170;
  const CGFloat pad = METRICS_SPACE_16;
  const CGFloat miniW = 28;
  const CGFloat miniH = METRICS_BUTTON_HEIGHT;
  const CGFloat fieldY = ch - pad - METRICS_TEXT_INPUT_FIELD_HEIGHT;
  const CGFloat rowY = METRICS_SPACE_12;
  NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, cw, ch)];

  arrayEdField = [[NSTextField alloc] initWithFrame:
    NSMakeRect(pad, fieldY, cw - 2 * pad - miniW - METRICS_SPACE_8,
               METRICS_TEXT_INPUT_FIELD_HEIGHT)];
  [arrayEdField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [arrayEdField setDelegate:self];
  [container addSubview:arrayEdField];

  arrayEdAdd = [self miniButtonWithTitle:@"+"
                                   frame:NSMakeRect(cw - pad - miniW, fieldY + 1,
                                                    miniW, miniH)
                                  action:@selector(arrayAddAction:)];
  [arrayEdAdd setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [container addSubview:arrayEdAdd];

  arrayEdScroll = [self matrixListScrollWithFrame:
    NSMakeRect(pad, rowY + miniH + METRICS_SPACE_8,
               cw - 2 * pad,
               fieldY - METRICS_SPACE_8 - rowY - miniH - METRICS_SPACE_8)
                          action:@selector(arrayEdMatrixAction:)
                       matrixOut:&arrayEdMatrix];
  [arrayEdScroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [container addSubview:arrayEdScroll];

  arrayEdRemove = [self miniButtonWithTitle:@"-"
                                      frame:NSMakeRect(pad, rowY, miniW, miniH)
                                     action:@selector(arrayRemoveAction:)];
  [arrayEdRemove setAutoresizingMask:NSViewMaxYMargin];
  [container addSubview:arrayEdRemove];

  [self addRevertButton:&arrayEdDefaultRevert
           revertAction:@selector(arrayDefaultRevertAction:)
              setButton:&arrayEdSet
             setAction:@selector(arraySetAction:)
           toContainer:container];
  return container;
}

/* Build the whole pane UI in code. Layout happens in
   relayoutSubviewsForSize:, so controls are created here and only
   positioned once that method runs at the end. */
- (NSView *)createMainView
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSBundle *bundle = [self bundle];
  NSString *dictpath = [bundle pathForResource: @"Defaults" ofType: @"plist"];
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictpath];
  NSArray *keys = [[dict allKeys] sortedArrayUsingSelector: @selector(compare:)];
  NSUInteger i;

  mainView = [[DefaultsMainView alloc] initWithFrame:NSMakeRect(0, 0, 640, 440)];
  [(DefaultsMainView *)mainView setLayoutOwner:self];
  [mainView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

  [defaults synchronize];
  defaultsEntries = [NSMutableArray new];

  for (i = 0; i < [keys count]; i++) {
    NSString *defname = [keys objectAtIndex: i];
    NSDictionary *info = [dict objectForKey: defname];
    NSString *category = [info objectForKey: @"category"];
    NSString *description;
    NSArray *values = [info objectForKey: @"values"];
    id defvalue = [info objectForKey: @"defaultvalue"];
    int edtype = [[info objectForKey: @"editor"] intValue];
    DefaultEntry *entry;

    description = [bundle localizedStringForKey:defname value:@"Description not found" table:nil];
    entry = [[DefaultEntry alloc] initWithUserDefaults: defaults
                                              withName: defname
                                            inCategory: category
                                           description: description
                                                values: values
                                          defaultValue: defvalue
                                            editorType: edtype];
    [defaultsEntries addObject: entry];
    RELEASE (entry);
  }

  /* Search field across the top */
  filterField = [[NSSearchField alloc] initWithFrame:NSZeroRect];
  [filterField setDrawsBackground:NO];
  [[filterField cell] setDrawsBackground:NO];
  [[filterField cell] setBackgroundColor:[NSColor clearColor]];
  [filterField setPlaceholderString:@"Search"];
  [filterField setTarget:self];
  [filterField setAction:@selector(filterDefaults:)];
  [[filterField cell] setSendsActionOnEndEditing:NO];
  [filterField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [mainView addSubview:filterField];

  /* Names list on the left */
  namesScroll = [self matrixListScrollWithFrame:NSZeroRect
                                         action:@selector(namesMatrixAction:)
                                      matrixOut:&namesMatrix];
  [mainView addSubview:namesScroll];

  /* Right column: category and description headers */
  categoryLabel = [self labelWithText:[bundle localizedStringForKey:@"category"
                                                              value:@"Category"
                                                               table:nil]
                                frame:NSZeroRect
                            alignment:NSTextAlignmentRight];
  [mainView addSubview:categoryLabel];

  categoryField = [self labelWithText:@""
                                frame:NSZeroRect
                            alignment:NSTextAlignmentLeft];
  [mainView addSubview:categoryField];

  descriptionLabel = [self labelWithText:[bundle localizedStringForKey:@"description"
                                                                 value:@"Description"
                                                                  table:nil]
                                   frame:NSZeroRect
                               alignment:NSTextAlignmentLeft];
  [mainView addSubview:descriptionLabel];

  /* Description text sits directly between its header and the editor box */
  descriptionView = [[NSTextView alloc] initWithFrame:NSZeroRect];
  [descriptionView setFont:METRICS_FONT_SYSTEM_REGULAR_11];
  [descriptionView setDrawsBackground:NO];
  [descriptionView setEditable:NO];
  [mainView addSubview:descriptionView];

  /* Editor box at the bottom of the right column; its content view is
     swapped between the five editors when an entry is selected */
  editorBox = [[NSBox alloc] initWithFrame:NSZeroRect];
  [editorBox setTitlePosition:NSNoTitle];
  [editorBox setBoxType:NSBoxPrimary];
  [editorBox setBorderType:NSBezelBorder];
  [mainView addSubview:editorBox];

  stringEditorBox = [self makeStringEditor];
  boolEditorBox = [self makeBoolEditor];
  numberEditorBox = [self makeNumberEditor];
  listEditorBox = [self makeListEditor];
  arrayEditorBox = [self makeArrayEditor];

  /* Fill the names list */
  for (i = 0; i < [defaultsEntries count]; i++) {
    DefaultEntry *entry = [defaultsEntries objectAtIndex: i];
    NSString *name = [entry name];
    NSUInteger count = [[namesMatrix cells] count];

    [namesMatrix insertRow: count];
    [[namesMatrix cellAtRow: count column: 0] setStringValue: name];
    [[namesMatrix cellAtRow: count column: 0] setLeaf: YES];
  }
  [namesMatrix sizeToCells];

  currentEntry = nil;

  [self relayoutSubviewsForSize:[mainView bounds].size];

  [self disableControls];

  return mainView;
}

/* Position everything for the given pane size. Called whenever the host
   resizes the pane view; keeps side margins symmetric and rows
   top-anchored, per AppearanceMetrics.h. */
- (void)relayoutSubviewsForSize:(NSSize)size
{
  const CGFloat sideM = METRICS_CONTENT_SIDE_MARGIN;
  const CGFloat topM = METRICS_CONTENT_TOP_MARGIN;
  const CGFloat botM = METRICS_CONTENT_BOTTOM_MARGIN;
  const CGFloat searchH = METRICS_TEXT_INPUT_FIELD_HEIGHT;
  const CGFloat labelH = 18;
  const CGFloat listW = 200;
  const CGFloat labelGap = METRICS_SPACE_8;
  const CGFloat catLabelW = 70;
  const CGFloat editorH = 150;

  if (mainView == nil || filterField == nil) {
    return;
  }

  CGFloat searchY = size.height - topM - searchH;
  [filterField setFrame:NSMakeRect(sideM, searchY, size.width - 2 * sideM, searchH)];

  CGFloat colTop = searchY - METRICS_SPACE_16;
  CGFloat colBot = botM;

  /* Left column: names list fills from below the search field down to
     the bottom margin */
  [namesScroll setFrame:NSMakeRect(sideM, colBot, listW, colTop - colBot)];
  if (namesMatrix != nil && [namesMatrix numberOfRows] > 0) {
    NSSize cs = [namesMatrix cellSize];

    cs.width = [namesScroll contentSize].width;
    [namesMatrix setCellSize:cs];
    [namesMatrix sizeToCells];
  }

  /* Right column */
  CGFloat rightX = sideM + listW + METRICS_SPACE_16;
  CGFloat rightW = size.width - sideM - rightX;
  if (rightW < 0) {
    rightW = 0;
  }

  CGFloat catY = colTop - labelH;
  [categoryLabel setFrame:NSMakeRect(rightX, catY, catLabelW, labelH)];
  [categoryField setFrame:NSMakeRect(rightX + catLabelW + labelGap, catY,
                                     MAX(0, rightW - catLabelW - labelGap), labelH)];

  CGFloat descLabelY = catY - labelGap - labelH;
  [descriptionLabel setFrame:NSMakeRect(rightX, descLabelY, 120, labelH)];

  CGFloat descTop = descLabelY - 4;
  CGFloat descBottom = botM + editorH + METRICS_SPACE_8;
  [descriptionView setFrame:NSMakeRect(rightX, descBottom, rightW,
                                       MAX(0, descTop - descBottom))];

  [editorBox setFrame:NSMakeRect(rightX, botM, rightW, editorH)];
}

- (DefaultEntry *)entryWithName:(NSString *)name
{
  NSUInteger i;

  for (i = 0; i < [defaultsEntries count]; i++)
    {
      DefaultEntry *entry = [defaultsEntries objectAtIndex: i];
      
      if ([[entry name] isEqual: name])
        return entry;
    }
    
  return nil;
}

- (void)filterDefaults:(id)sender
{
  NSString *filter = [filterField stringValue];
  NSUInteger i;

  while ([namesMatrix numberOfRows] > 0) {
    [namesMatrix removeRow: [namesMatrix numberOfRows] - 1];
  }

  for (i = 0; i < [defaultsEntries count]; i++) {
    DefaultEntry *entry = [defaultsEntries objectAtIndex: i];
    NSString *name = [entry name];

    if ([filter length] == 0
        || [[name lowercaseString] rangeOfString: [filter lowercaseString]].location != NSNotFound) {
      id cell;
      [namesMatrix insertRow: [namesMatrix numberOfRows]];
      cell = [namesMatrix cellAtRow: [namesMatrix numberOfRows] - 1 column: 0];
      [cell setStringValue: name];
      [cell setLeaf: YES];
    }
  }

  [namesMatrix sizeToCells];
  [self disableControls];
}

- (void)namesMatrixAction:(id)sender
{
  id cell = [namesMatrix selectedCell];  

  [self disableControls];    
    
  if (cell) {    
    int edtype;
    id defvalue;
    id usrvalue;
    NSArray *values;
    id value;
       
    currentEntry = [self entryWithName: [cell stringValue]];
    edtype = [currentEntry editorType];
    defvalue = [currentEntry defaultValue];  
    usrvalue = [currentEntry userValue];
    values = [currentEntry values];
    value = (usrvalue == nil) ? defvalue : usrvalue;
          
    [descriptionView setString: [currentEntry description]];
    [categoryField setStringValue: [currentEntry category]];
    
    switch (edtype) {
      case STRING_EDITOR:
        [editorBox setContentView: stringEditorBox];
        [stringEdField setStringValue: value];
        [stringEdDefaultRevert setEnabled: (usrvalue && ([usrvalue isEqual: defvalue] == NO))];
        break;

      case BOOL_EDITOR:
        [editorBox setContentView: boolEditorBox];
        [boolEdPopup selectItemAtIndex: [value boolValue]];
        [boolEdDefaultRevert setEnabled: (usrvalue && ([usrvalue isEqual: defvalue] == NO))];
        break;

      case NUMBER_EDITOR:
        [editorBox setContentView: numberEditorBox];
        [numberEdField setStringValue: [value stringValue]];
        [numberEdDefaultRevert setEnabled: (usrvalue && ([usrvalue isEqual: defvalue] == NO))];
        break;

      case ARRAY_EDITOR:
        {
          NSUInteger i;
          
          [editorBox setContentView: arrayEditorBox];
          
          if ([arrayEdMatrix numberOfColumns] > 0) { 
            [arrayEdMatrix removeColumn: 0];
          }
          
          for (i = 0; i < [value count]; i++) {
            NSString *str = [value objectAtIndex: i];
            NSUInteger count = [[arrayEdMatrix cells] count];

            [arrayEdMatrix insertRow: count];
            cell = [arrayEdMatrix cellAtRow: count column: 0];   
            [cell setStringValue: str];
            [cell setLeaf: YES];  
          }

          [arrayEdMatrix sizeToCells];         
          [arrayEdDefaultRevert setEnabled: (usrvalue && ([usrvalue isEqual: defvalue] == NO))];
          break;    
        }

    case LIST_EDITOR:
      [editorBox setContentView: listEditorBox];
      if (values && [values count] > 0)
        {
          [listEdPopup removeAllItems];
          [listEdPopup addItemsWithTitles:values];
          [listEdPopup selectItemWithTitle: value];
        }
      [listEdDefaultRevert setEnabled: (usrvalue && ([usrvalue isEqual: defvalue] == NO))];
      break;
        
      default:
        break;
    }
  } else {
    currentEntry = nil;
    [editorBox setContentView: nil];
  }
}

- (void)disableControls
{
  [stringEdDefaultRevert setEnabled: NO];
  [stringEdSet setEnabled: NO];

  [boolEdDefaultRevert setEnabled: NO];
  [boolEdSet setEnabled: NO];

  [numberEdDefaultRevert setEnabled: NO];
  [numberEdSet setEnabled: NO];

  [arrayEdAdd setEnabled: NO];
  [arrayEdRemove setEnabled: NO];
  [arrayEdDefaultRevert setEnabled: NO];
  [arrayEdSet setEnabled: NO];
}

- (void)updateDefaults
{
  CREATE_AUTORELEASE_POOL (arp);
  NSString *defname = [currentEntry name];
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];  
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *domain;

  [defaults synchronize];
  domain = [[defaults persistentDomainForName: NSGlobalDomain] mutableCopy];

  if (usrvalue != nil) {
    if ([usrvalue isEqual: defvalue] == NO) {
   //      NSLog(@"setting: %@ for: %@", [usrvalue description], defname);
      [domain setObject: usrvalue forKey: defname]; 
    } else {
   //   NSLog(@"removing: %@", defname);
      [domain removeObjectForKey: defname];
    }
  } else {
  //  NSLog(@"removing: %@", defname);
    [domain removeObjectForKey: defname];
  }

  [defaults setPersistentDomain: domain forName: NSGlobalDomain];
  [defaults synchronize];

  RELEASE (domain);  
  RELEASE (arp);
}

@end


@implementation Defaults (Editing)

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  id sender = [aNotification object];  
  NSString *str = [sender stringValue];
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];

  if (sender == stringEdField) {
    [stringEdDefaultRevert setEnabled: ([defvalue isEqual: str] == NO)];
      
    if (usrvalue) {
      [stringEdSet setEnabled: ([usrvalue isEqual: str] == NO)];
    } else {
      [stringEdSet setEnabled: ([defvalue isEqual: str] == NO)];
    }
  
  } else if (sender == numberEdField) {
    [numberEdDefaultRevert setEnabled: ([[defvalue stringValue] isEqual: str] == NO)];
    
    if (usrvalue) {
      [numberEdSet setEnabled: ([[usrvalue stringValue] isEqual: str] == NO)];
    } else {
      [numberEdSet setEnabled: ([[defvalue stringValue] isEqual: str] == NO)];
    }
    
  } else if (sender == arrayEdField) {
    if (usrvalue) {
      [arrayEdAdd setEnabled: ([str length] && ([usrvalue containsObject: str] == NO))];
    } else {
      [arrayEdAdd setEnabled: ([str length] && ([defvalue containsObject: str] == NO))];
    }
  }
}

//
// String
//
- (IBAction)stringDefaultRevertAction:(id)sender
{
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];

  [stringEdField setStringValue: defvalue];
  [stringEdDefaultRevert setEnabled: NO];
    
  if (usrvalue) {
    [stringEdSet setEnabled: ([usrvalue isEqual: defvalue] == NO)];  
  } else {
    [stringEdSet setEnabled: NO];  
  }
}

- (IBAction)stringSetAction:(id)sender
{
  NSString *str = [stringEdField stringValue];
  id usrvalue = [currentEntry userValue];
   
  if ((usrvalue == nil) || ([str isEqual: usrvalue] == NO)) {
    [currentEntry setUserValue: str];
    [self updateDefaults];
  }
  
  [stringEdSet setEnabled: NO];
}

//
// Bool
//
- (IBAction)boolPopupAction:(id)sender
{
  NSNumber *num = [NSNumber numberWithInt: [boolEdPopup indexOfSelectedItem]];  
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];

  [boolEdDefaultRevert setEnabled: ([num isEqual: defvalue] == NO)];  

  if (usrvalue) {
    [boolEdSet setEnabled: ([num isEqual: usrvalue] == NO)];
  } else {
    [boolEdSet setEnabled: ([num isEqual: defvalue] == NO)];
  }
}

- (IBAction)boolDefaultRevertAction:(id)sender
{
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];

  [boolEdPopup selectItemAtIndex: [defvalue intValue]];
  [boolEdDefaultRevert setEnabled: NO];

  if (usrvalue) {
    [boolEdSet setEnabled: ([usrvalue isEqual: defvalue] == NO)];  
  } else {
    [boolEdSet setEnabled: NO];  
  }
}

- (IBAction)boolSetAction:(id)sender
{
  NSNumber *num = [NSNumber numberWithInt: [boolEdPopup indexOfSelectedItem]];  
  id usrvalue = [currentEntry userValue];
   
  if ((usrvalue == nil) || ([num isEqual: usrvalue] == NO)) {
    [currentEntry setUserValue: num];
    [self updateDefaults];
  }
  
  [boolEdSet setEnabled: NO];
}

//
// Number
//
- (IBAction)numberDefaultRevertAction:(id)sender
{
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];

  [numberEdField setStringValue: [defvalue stringValue]];
  [numberEdDefaultRevert setEnabled: NO];
    
  if (usrvalue) {
    [numberEdSet setEnabled: ([usrvalue isEqual: defvalue] == NO)];  
  } else {
    [numberEdSet setEnabled: NO];  
  }
}

- (IBAction)numberSetAction:(id)sender
{
  NSString *str = [numberEdField stringValue];
  id usrvalue = [currentEntry userValue];
  NSNumber *num = nil;
    
  if ([str length]) {  
    int n = [str intValue];
    
    if ((n != INT_MAX) && (n != INT_MIN)) {
      num = [NSNumber numberWithInt: n];
    }
  }  
  
  if (num == nil) {
    num = [currentEntry defaultValue];
  }
  
  if ((usrvalue == nil) || ([num isEqual: usrvalue] == NO)) {
    [currentEntry setUserValue: num];    
    [self updateDefaults];
  }
    
  [numberEdSet setEnabled: NO];  
}

//
// Array
//
- (void)arrayEdMatrixAction:(id)sender
{
  [arrayEdRemove setEnabled: ([arrayEdMatrix selectedCell] != nil)];
}

- (IBAction)arrayAddAction:(id)sender
{
  NSString *str = [arrayEdField stringValue];
  
  if ([str length]) {
    CREATE_AUTORELEASE_POOL (arp);
    id defvalue = [currentEntry defaultValue];
    id usrvalue = [currentEntry userValue];
    NSMutableArray *newvalue = [NSMutableArray array];
    NSArray *cells = [arrayEdMatrix cells];
    unsigned count = [cells count];
    BOOL exists = NO;
    
    if (count > 0) {
      NSUInteger i;
      
      for (i = 0; i < count; i++) {
        NSString *cellstr = [[cells objectAtIndex: i] stringValue];
        
        [newvalue addObject: cellstr];
      
        if ([cellstr isEqual: str]) {
          exists = YES;
        }
      }
    }
    
    if (exists == NO) {
      [arrayEdMatrix insertRow: count];
      [[arrayEdMatrix cellAtRow: count column: 0] setStringValue: str]; 
      [newvalue addObject: str];
      [arrayEdMatrix sizeToCells]; 
      [arrayEdField setStringValue: @""];
    }
    
    [arrayEdDefaultRevert setEnabled: ([defvalue isEqual: newvalue] == NO)];
    
    if (usrvalue) {
      [arrayEdSet setEnabled: ([usrvalue isEqual: newvalue] == NO)];
    } else {
      [arrayEdSet setEnabled: ([defvalue isEqual: newvalue] == NO)];
    }    
    
    RELEASE (arp);
  }
  
  [arrayEdAdd setEnabled: NO];   
}

- (IBAction)arrayRemoveAction:(id)sender
{
  id cell = [arrayEdMatrix selectedCell];  
  
  if (cell) {  
    CREATE_AUTORELEASE_POOL (arp);
    id defvalue = [currentEntry defaultValue];
    id usrvalue = [currentEntry userValue];
    NSMutableArray *newvalue = [NSMutableArray array];  
    NSArray *cells;
    NSInteger row, col;
    NSUInteger i;
    
    [arrayEdMatrix getRow: &row column: &col ofCell: cell];
    [arrayEdMatrix removeRow: row];
    [arrayEdMatrix sizeToCells];   
    
    cells = [arrayEdMatrix cells];

    for (i = 0; i < [cells count]; i++) {
      [newvalue addObject: [[cells objectAtIndex: i] stringValue]];
    }
    
    [arrayEdDefaultRevert setEnabled: ([defvalue isEqual: newvalue] == NO)];
    
    if (usrvalue) {
      [arrayEdSet setEnabled: ([usrvalue isEqual: newvalue] == NO)];
    } else {
      [arrayEdSet setEnabled: ([defvalue isEqual: newvalue] == NO)];
    }    
    
    RELEASE (arp);
  }
  
  [arrayEdRemove setEnabled: NO];   
}

- (IBAction)arrayDefaultRevertAction:(id)sender
{
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];
  id cell;
  NSUInteger i;
       
  if ([arrayEdMatrix numberOfColumns] > 0) {        
    [arrayEdMatrix removeColumn: 0];
  }
  
  for (i = 0; i < [defvalue count]; i++) {
    NSString *str = [defvalue objectAtIndex: i];
    NSUInteger count = [[arrayEdMatrix cells] count];

    [arrayEdMatrix insertRow: count];
    cell = [arrayEdMatrix cellAtRow: count column: 0];   
    [cell setStringValue: str];
    [cell setLeaf: YES];  
  }

  [arrayEdMatrix sizeToCells];    
  
  [arrayEdDefaultRevert setEnabled: NO]; 
    
  if (usrvalue) {
    [arrayEdSet setEnabled: ([usrvalue isEqual: defvalue] == NO)];  
  } else {
    [arrayEdSet setEnabled: NO];  
  }
}

- (IBAction)arraySetAction:(id)sender
{
  CREATE_AUTORELEASE_POOL (arp);
  id usrvalue = [currentEntry userValue];
  NSArray *cells = [arrayEdMatrix cells];
  NSMutableArray *newvalue = [NSMutableArray array];
  NSUInteger i;

  for (i = 0; i < [cells count]; i++) {
    [newvalue addObject: [[cells objectAtIndex: i] stringValue]];
  }

  if ((usrvalue == nil) || ([usrvalue isEqual: newvalue] == NO)) {
    [currentEntry setUserValue: newvalue];
    [self updateDefaults];
  }
    
  [arrayEdSet setEnabled: NO];
  
  RELEASE (arp);  
}

//
// List
//
- (IBAction)listPopupAction:(id)sender
{
  NSString *str = [listEdPopup titleOfSelectedItem];
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];

  [listEdDefaultRevert setEnabled: ([str isEqual: defvalue] == NO)];  

  if (usrvalue)
    {
      [listEdSet setEnabled: ([str isEqual: usrvalue] == NO)];
    }
  else
    {
      [listEdSet setEnabled: ([str isEqual: defvalue] == NO)];
    }
}

- (IBAction)listDefaultRevertAction:(id)sender
{
  id defvalue = [currentEntry defaultValue];
  id usrvalue = [currentEntry userValue];

  [listEdPopup selectItemWithTitle: defvalue];
  [listEdDefaultRevert setEnabled: NO];

  if (usrvalue)
    {
      [listEdSet setEnabled: ([usrvalue isEqual: defvalue] == NO)];  
    }
  else
    {
      [listEdSet setEnabled: NO];  
    }
}

- (IBAction)listSetAction:(id)sender
{
  NSString *str = [listEdPopup titleOfSelectedItem];  
  id usrvalue = [currentEntry userValue];

  if ((usrvalue == nil) || ([str isEqual: usrvalue] == NO))
    {
      [currentEntry setUserValue: str];
      [self updateDefaults];
    }
  
  [listEdSet setEnabled: NO];
}

@end


@implementation DefaultEntry

- (void)dealloc
{
  RELEASE (name);
  RELEASE (category);
  RELEASE (description);
  TEST_RELEASE (userValue);
  RELEASE (defaultValue);
  RELEASE (values);
  [super dealloc];
}

- (id)initWithUserDefaults:(NSUserDefaults *)defaults
                  withName:(NSString *)dfname
                inCategory:(NSString *)cat
               description:(NSString *)desc
		    values:(NSArray *)vals
              defaultValue:(id)dval
                editorType:(int)edtype
{
  self = [super init];
  
  if (self) {
    ASSIGN (name, dfname);
    ASSIGN (category, cat);
    ASSIGN (description, desc);
    ASSIGN (defaultValue, dval);
    ASSIGN (values, vals);
    editorType = edtype;
    
    userValue = [defaults objectForKey: name];
    TEST_RETAIN (userValue);
  }
  
  return self;
}

- (NSString *)name
{
  return name;
}

- (NSString *)category
{
  return category;
}

- (NSString *)description
{
  return description;
}

- (id)defaultValue
{
  return defaultValue;
}

- (id)userValue
{
  return userValue;
}

- (void)setUserValue:(id)usval
{
  if (usval != nil) {
    ASSIGN (userValue, usval);
  } else {
    DESTROY (userValue);
  }
}

- (NSArray *)values
{
  return values;
}

- (int)editorType
{
  return editorType;
}

@end


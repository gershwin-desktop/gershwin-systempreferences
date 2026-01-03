/* SystemPreferences.m
 *  
 * Copyright (C) 2005-2009 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola
 *
 * Date: December 2005
 *
 * This file is part of the GNUstep SystemPreferences application
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
#import "SystemPreferences.h"
#import "SPIconsView.h"
#import "SPIcon.h"

static NSArray<NSDictionary *> *kCategoryRules = nil;

static void ensureCategoryRules(void)
{
  if (kCategoryRules == nil) {
   kCategoryRules = [[NSArray alloc] initWithObjects:
    @{ @"name": @"Personal",
      @"keywords": @[ @"appearance", @"desktop", @"dock", @"language", @"text", @"security", @"spotlight", @"accessibility", @"fonts", @"colors", @"themes", @"global", @"screensaver" ],
      @"identifiers": @[] },
    @{ @"name": @"Hardware",
      @"keywords": @[ @"cd", @"dvd", @"display", @"energy", @"keyboard", @"mouse", @"trackpad", @"printer", @"sound", @"displays" ],
      @"identifiers": @[] },
    @{ @"name": @"Internet & Wireless",
      @"keywords": @[ @"network", @"internet", @"sharing", @"modem", @"wireless", @"wifi", @"bluetooth" ],
      @"identifiers": @[] },
    @{ @"name": @"System",
      @"keywords": @[ @"accounts", @"date", @"time", @"startup", @"machine", @"timezone", @"system", @"defaults", @"modifier", @"volumes", @"filesystem", @"global" ],
      @"identifiers": @[] },
    nil];
  }
}

@interface SystemPreferences ()
- (NSString *)categoryForPane:(NSPreferencePane *)pane label:(NSString *)label;
@end

static SystemPreferences *systemPreferences = nil;

@implementation SystemPreferences

+ (id)systemPreferences
{
  if (systemPreferences == nil)
    {
      systemPreferences = [[SystemPreferences alloc] init];
    }	
  return systemPreferences;
}

- (void)dealloc
{
  [nc removeObserver: self];
  
  RELEASE (window);
  RELEASE (panes);
  RELEASE (iconsView);
  RELEASE (prefsBox);
  RELEASE (searchField);
  RELEASE (showAllButt);
    
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    panes = [NSMutableArray new];
    currentPane = nil;
    
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];

    [nc addObserver: self
	   selector: @selector(paneUnselectNotification:)
	       name: @"NSPreferencePaneDoUnselectNotification"
	     object: nil];

    [nc addObserver: self
	   selector: @selector(paneUnselectNotification:)
	       name: @"NSPreferencePaneCancelUnselectNotification"
	     object: nil];

    pendingAction = NULL;
  }
  
  return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{  // If we've already built the toolbar and search field (this can be called more than once), skip
  if (searchField != nil && prefsBox != nil) {
    return;
  }
  NSUInteger style = NSTitledWindowMask
		   | NSClosableWindowMask
      		   | NSMiniaturizableWindowMask;
  NSString *bundlesDir;
  
  // Create window programmatically
  window = [[NSWindow alloc] initWithContentRect: NSMakeRect(200, 200, 592, 414)
                                       styleMask: style
                                         backing: NSBackingStoreRetained
                                           defer: NO];
  [window setTitle: @"System Preferences"];
  [window setDelegate: self];
  
  // Create main content view
  NSView *contentView = [[NSView alloc] initWithFrame: [[window contentView] frame]];
  [window setContentView: contentView];
  RELEASE(contentView);
  
  // Build a toolbar row with the Show All button on the left and the search field on the right
  NSRect contentBounds = [[window contentView] bounds];
  const CGFloat toolbarHeight = 40.0;
  NSView *topBar = [[NSView alloc] initWithFrame: NSMakeRect(0, contentBounds.size.height - toolbarHeight, contentBounds.size.width, toolbarHeight)];
  [topBar setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
  [[window contentView] addSubview: topBar];

  showAllButt = [[NSButton alloc] initWithFrame: NSMakeRect(12, (toolbarHeight - 24.0) / 2.0, 88, 24)];
  [showAllButt setTitle: @"Show All"];
  [showAllButt setButtonType: NSMomentaryPushInButton];
  [showAllButt setTarget: self];
  [showAllButt setAction: @selector(showAll:)];
  [showAllButt setEnabled: NO];
  [showAllButt setAutoresizingMask: NSViewMaxXMargin | NSViewMinYMargin];
  [topBar addSubview: showAllButt];

  searchField = [[NSTextField alloc] initWithFrame: NSMakeRect(contentBounds.size.width - 12 - 200, (toolbarHeight - 20.0) / 2.0, 200, 20)];
  [searchField setPlaceholderString: @"Search"];  
  [searchField setAutoresizingMask: NSViewMinXMargin | NSViewMinYMargin];
  [topBar addSubview: searchField];
  [topBar release];

  // Create preferences box for icons (NO BORDER like reference)
  prefsBox = [[NSBox alloc] initWithFrame: NSMakeRect(0, 0, contentBounds.size.width, contentBounds.size.height - toolbarHeight)];
  [prefsBox setTitle: @""];
  [prefsBox setBorderType: NSNoBorder];  // Remove border to match reference
  [prefsBox setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [[window contentView] addSubview: prefsBox];
    
  [prefsBox setAutoresizesSubviews: NO];  
  iconsView = [[SPIconsView alloc] initWithFrame: [[prefsBox contentView] frame]];
  [(NSBox *)prefsBox setContentView: iconsView];
  
  // Connect search field to icons view
  [searchField setTarget: iconsView];
  [searchField setAction: @selector(searchFieldChanged:)];
  [[searchField cell] setSendsActionOnEndEditing: YES];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  [self addPanesFromDirectory: bundlesDir];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  [self addPanesFromDirectory: bundlesDir];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  [self addPanesFromDirectory: bundlesDir];
  
  [panes sortUsingSelector: @selector(comparePane:)];
  
  [showAllButt setEnabled: NO];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  unsigned i;
  
  [window setFrameUsingName: @"systemprefs"];
  [window makeKeyAndOrderFront: nil];
  
  for (i = 0; i < [panes count]; i++) {
    CREATE_AUTORELEASE_POOL (pool);
    NSPreferencePane *pane = [panes objectAtIndex: i];
    NSBundle *bundle = [pane bundle];
    NSDictionary *dict = [bundle infoDictionary];
    /* 
      All the following objects are guaranted to exist because they are 
      checked in the -initWithBundle: method of the NSPreferencePane class.    
    */
    NSString *iname = [dict objectForKey: @"NSPrefPaneIconFile"];
    NSString *ipath = [bundle pathForResource: iname ofType: nil];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile: ipath];
    NSString *lstr = [dict objectForKey: @"NSPrefPaneIconLabel"];
    SPIcon *icon;
    NSString *category = [self categoryForPane: pane label: lstr];
    
    icon = [[SPIcon alloc] initForPane: pane iconImage: image labelString: lstr];
    [iconsView addIcon: icon forCategory: category];
    RELEASE (icon);
    RELEASE (image);
    RELEASE (pool);
  }

  [iconsView tile];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
    return YES;
}

- (BOOL)windowShouldClose:(NSWindow *)_win 
{
  if (_win == window)
    {
      NSView *view = [prefsBox contentView];

      if (view != iconsView) {
        if (currentPane == nil) {
          // pane was unselected asynchronously, switch to icons view
          [(NSBox *)prefsBox setContentView: iconsView];
        } else {
          NSPreferencePaneUnselectReply reply = [currentPane shouldUnselect];
    
          if (reply == NSUnselectCancel) {
            return NO;
          } else if (reply == NSUnselectLater) {
            pendingAction = @selector(closeAfterPaneUnselection);
            return NO;
          } else {
            // unselect now
            [currentPane willUnselect];
            [currentPane didUnselect];
            currentPane = nil;
            [(NSBox *)prefsBox setContentView: iconsView];
          }
        }
      }

      [self updateDefaults];
    }
  return YES;
}

- (void)addPanesFromDirectory:(NSString *)dir
{
  NSArray *bnames = [fm directoryContentsAtPath: dir];
  unsigned i;

  for (i = 0; i < [bnames count]; i++) {
    NSString *bname = [bnames objectAtIndex: i];

    if ([[bname pathExtension] isEqual: @"prefPane"]) {
      CREATE_AUTORELEASE_POOL (pool);
      NSString *bpath = [dir stringByAppendingPathComponent: bname];
      NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 
      
      if (bundle) {
        Class principalClass = [bundle principalClass];
        NSPreferencePane *pane;
      
        NS_DURING
          {
            pane = [[principalClass alloc] initWithBundle: bundle];
            
            if ([panes containsObject: pane] == NO) {     
              [panes addObject: pane];
            }
            
            RELEASE (pane);
          }
        NS_HANDLER
          {
            NSRunAlertPanel(nil, 
                [NSString stringWithFormat: @"Bad pane bundle at: %@!", bpath], 
                            @"OK", 
                            nil, 
                            nil);  
          }
        NS_ENDHANDLER
      }
      
      RELEASE (pool);
    }
  }
}

/*
 * Forward changeFont: messages from the FontPanel to the current
 * Pane.
 */
- (void) changeFont: (id)sender
{
  if ([currentPane respondsToSelector: @selector(changeFont:)])
    {
      [currentPane changeFont: sender];
    }
}

- (void)clickOnIconOfPane:(id)pane
{
  NSView *view = [pane loadMainView];
  float diffh = [view frame].size.height - [iconsView frame].size.height;
  NSRect wr = [window frame];
  
  wr.size.height += diffh;
  wr.origin.y -= diffh;
  
  currentPane = pane;
  [currentPane willSelect];
  [(NSBox *)prefsBox setContentView: view];
  [currentPane didSelect];
    
  [window setFrame: wr display: YES animate: YES];
  
  [showAllButt setEnabled: YES];
}

- (void)showAll:(id)sender
{
  [self showAllButtAction:sender];
}

- (IBAction)showAllButtAction:(id)sender
{
  NSView *view = [prefsBox contentView];

  if (view != iconsView) {
    NSPreferencePaneUnselectReply reply = [currentPane shouldUnselect];
    
    if (reply == NSUnselectNow) {
      [self showIconsView];
    } else if (reply == NSUnselectLater) {
      pendingAction = @selector(showIconsView);
    }
  }
}

- (void)showIconsView
{
  NSView *view = [prefsBox contentView];
  
  if (view != iconsView) {  
    float diffh = [iconsView frame].size.height - [view frame].size.height;
    NSRect wr = [window frame];

    wr.size.height += diffh;
    wr.origin.y -= diffh;

    [currentPane willUnselect];
    [(NSBox *)prefsBox setContentView: iconsView];
    // When returning to the icons view, clear search and show everything
    if (searchField) {
      [searchField setStringValue: @""];
    }
    [iconsView showAllIcons];
    [currentPane didUnselect];

    [window setFrame: wr display: YES animate: YES];

    currentPane = nil;
    [showAllButt setEnabled: NO];
  }
}

- (void)paneUnselectNotification:(NSNotification *)notif
{
  if ([[notif name] isEqual: @"NSPreferencePaneDoUnselectNotification"]) {
    [self performSelector: pendingAction];
    pendingAction = NULL;
  }  
}

- (void)closeAfterPaneUnselection
{
  [currentPane willUnselect];
  [(NSBox *)prefsBox setContentView: iconsView];
  [currentPane didUnselect];
  currentPane = nil;
  [window performClose: self];
}

- (void)updateDefaults
{
  [window saveFrameUsingName: @"systemprefs"];
}

- (NSString *)categoryForPane:(NSPreferencePane *)pane label:(NSString *)label
{
  NSDictionary *info = [[pane bundle] infoDictionary];
  NSString *category = [info objectForKey: @"NSPrefPaneCategory"];

  if ([category length] > 0) {
    return category;
  }

  ensureCategoryRules();

  NSString *lowerLabel = [[label lowercaseString] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (lowerLabel == nil) {
    lowerLabel = @"";
  }

  NSString *bundleID = [[[pane bundle] bundleIdentifier] lowercaseString];
  if (bundleID == nil) {
    bundleID = @"";
  }

  for (NSDictionary *rule in kCategoryRules) {
    NSArray *keywords = [rule objectForKey: @"keywords"];
    for (NSString *keyword in keywords) {
      if ([keyword length] == 0) {
        continue;
      }

      if ([lowerLabel rangeOfString: keyword].location != NSNotFound) {
        return [rule objectForKey: @"name"];
      }
    }

    NSArray *identifiers = [rule objectForKey: @"identifiers"];
    for (NSString *identifier in identifiers) {
      if ([identifier length] == 0) {
        continue;
      }

      if ([bundleID rangeOfString: identifier].location != NSNotFound) {
        return [rule objectForKey: @"name"];
      }
    }
  }

  return @"Other";
}

@end













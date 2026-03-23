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
#import <dispatch/dispatch.h>
#import "SystemPreferences.h"
#import "SPIconsView.h"
#import "SPIcon.h"

// Private libdispatch API for integrating the main queue with a foreign run loop.
// Without this, blocks dispatched to dispatch_get_main_queue() from background
// threads are never executed under GNUstep's NSRunLoop.
extern int _dispatch_get_main_queue_handle_4CF(void);
extern void _dispatch_main_queue_callback_4CF(void *msg);

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
    @{ @"name": @"Network",
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
static NSFileHandle *dispatchMainQueueHandle = nil;

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

- (void)_setupDispatchMainQueueDrain
{
  // GNUstep's NSRunLoop does not automatically drain libdispatch's main queue.
  // We watch the dispatch main queue's file descriptor and call the drain
  // callback whenever work is available.  This makes dispatch_async to the
  // main queue work correctly from background threads / GCD.
  int fd = _dispatch_get_main_queue_handle_4CF();
  if (fd < 0) {
    NSDebugLog(@"SystemPreferences: WARNING - could not get dispatch main queue fd");
    return;
  }

  NSFileHandle *fh = [[NSFileHandle alloc] initWithFileDescriptor:fd
                                                   closeOnDealloc:NO];
  // Keep the file handle alive for the lifetime of the app
  dispatchMainQueueHandle = [fh retain];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(_drainDispatchMainQueue:)
             name:NSFileHandleDataAvailableNotification
           object:fh];
  [fh waitForDataInBackgroundAndNotify];
  [fh release];
  NSDebugLog(@"SystemPreferences: dispatch main queue drain installed (fd=%d)", fd);
}

- (void)_drainDispatchMainQueue:(NSNotification *)notif
{
  _dispatch_main_queue_callback_4CF(NULL);

  // Re-arm the notification
  NSFileHandle *fh = [notif object];
  [fh waitForDataInBackgroundAndNotify];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
  NSDebugLog(@"SystemPreferences: applicationWillFinishLaunching starting");

  // If we've already built the toolbar and search field (this can be called more than once), skip
  if (searchField != nil && prefsBox != nil) {
    NSDebugLog(@"SystemPreferences: Already initialized, skipping");
    return;
  }

  // Integrate libdispatch main queue with GNUstep's NSRunLoop
  [self _setupDispatchMainQueueDrain];
  NSUInteger style = NSTitledWindowMask
		   | NSClosableWindowMask
      		   | NSMiniaturizableWindowMask;
  NSString *bundlesDir;
  
  NSDebugLog(@"SystemPreferences: Creating window");
  // Create window
  window = [[NSWindow alloc] initWithContentRect: NSMakeRect(200, 180, 592, 434)
                                       styleMask: style
                                         backing: NSBackingStoreRetained
                                           defer: NO];
  [window setTitle: @"System Preferences"];
  [window setDelegate: self];
  
  NSDebugLog(@"SystemPreferences: Creating content view");
  // Create main content view
  NSView *contentView = [[NSView alloc] initWithFrame: [[window contentView] frame]];
  [window setContentView: contentView];
  RELEASE(contentView);
  
  // Build a toolbar row with the Show All button on the left and the search field on the right
  NSRect contentBounds = [[window contentView] bounds];
  const CGFloat toolbarHeight = 40.0;
  NSDebugLog(@"SystemPreferences: Creating toolbar");
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

  NSDebugLog(@"SystemPreferences: Creating preferences box");
  // Create preferences box for icons (NO BORDER like reference)
  prefsBox = [[NSBox alloc] initWithFrame: NSMakeRect(0, 0, contentBounds.size.width, contentBounds.size.height - toolbarHeight)];
  [prefsBox setTitle: @""];
  [prefsBox setBorderType: NSNoBorder];  // Remove border to match reference
  [prefsBox setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [[window contentView] addSubview: prefsBox];
    
  [prefsBox setAutoresizesSubviews: NO];  
  NSDebugLog(@"SystemPreferences: Creating icons view");
  iconsView = [[SPIconsView alloc] initWithFrame: [[prefsBox contentView] frame]];
  [(NSBox *)prefsBox setContentView: iconsView];
  
  // Connect search field to icons view
  [searchField setTarget: iconsView];
  [searchField setAction: @selector(searchFieldChanged:)];
  // Send action continuously (on every change) rather than only at end editing
  [[searchField cell] setSendsActionOnEndEditing: NO];
  // Observe changes in the search field to update the Show All button immediately
  [nc addObserver: self
         selector: @selector(searchFieldDidChange:)
             name: NSControlTextDidChangeNotification
           object: nil];
  // Set self as delegate so we can intercept ESC (cancelOperation:) when typing in the search box
  [searchField setDelegate: self];

  NSDebugLog(@"SystemPreferences: Loading preference panes from directories");
  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  NSDebugLog(@"SystemPreferences: Adding panes from %@", bundlesDir);
  [self addPanesFromDirectory: bundlesDir];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  NSDebugLog(@"SystemPreferences: Adding panes from %@", bundlesDir);
  [self addPanesFromDirectory: bundlesDir];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  NSDebugLog(@"SystemPreferences: Adding panes from %@", bundlesDir);
  [self addPanesFromDirectory: bundlesDir];
  
  NSDebugLog(@"SystemPreferences: Sorting panes");
  [panes sortUsingSelector: @selector(comparePane:)];
  
  NSDebugLog(@"SystemPreferences: applicationWillFinishLaunching complete");
  [showAllButt setEnabled: NO];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  unsigned i;
  
  NSDebugLog(@"SystemPreferences: applicationDidFinishLaunching starting");
  
  NSDebugLog(@"SystemPreferences: Skipping saved window frame restore (window will not be moved)");
  // Intentionally do not restore saved frame to avoid moving the window on startup.
  NSDebugLog(@"SystemPreferences: Making window key and front");
  [window makeKeyAndOrderFront: nil];
  
  NSDebugLog(@"SystemPreferences: Processing %lu panes", (unsigned long)[panes count]);
  
  for (i = 0; i < [panes count]; i++) {
    CREATE_AUTORELEASE_POOL (pool);
    NSPreferencePane *pane = [panes objectAtIndex: i];
    NSBundle *bundle = [pane bundle];
    NSDictionary *dict = [bundle infoDictionary];
    
    NSDebugLog(@"SystemPreferences: Processing pane %u", i);
    
    /* 
      All the following objects are guaranted to exist because they are 
      checked in the -initWithBundle: method of the NSPreferencePane class.    
    */
    NSString *iname = [dict objectForKey: @"NSPrefPaneIconFile"];
    NSString *ipath = [bundle pathForResource: iname ofType: nil];
    NSDebugLog(@"SystemPreferences: Loading icon from %@", ipath);
    NSImage *image = [[NSImage alloc] initWithContentsOfFile: ipath];
    NSString *lstr = [dict objectForKey: @"NSPrefPaneIconLabel"];
    SPIcon *icon;
    NSString *category = [self categoryForPane: pane label: lstr];
    
    NSDebugLog(@"SystemPreferences: Creating icon for %@", lstr);
    icon = [[SPIcon alloc] initForPane: pane iconImage: image labelString: lstr];
    NSDebugLog(@"SystemPreferences: Adding icon to view");
    [iconsView addIcon: icon forCategory: category];
    RELEASE (icon);
    RELEASE (image);
    RELEASE (pool);
    NSDebugLog(@"SystemPreferences: Pane %u processed", i);
  }

  NSDebugLog(@"SystemPreferences: Tiling icons view");
  [iconsView tile];
  NSDebugLog(@"SystemPreferences: applicationDidFinishLaunching complete");
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
  // Unselect the previous pane before selecting the new one so that
  // timers, tasks and other resources are properly cleaned up.
  if (currentPane != nil && currentPane != pane) {
    NSPreferencePaneUnselectReply reply = [currentPane shouldUnselect];

    if (reply == NSUnselectCancel) {
      return; // previous pane refused to unselect
    } else if (reply == NSUnselectLater) {
      // Cannot switch yet; remember what we wanted to do
      // (pendingAction will be invoked by paneUnselectNotification:)
      pendingAction = NULL; // clear; we cannot easily defer pane-to-pane switch
      return;
    }

    [currentPane willUnselect];
    [currentPane didUnselect];
    currentPane = nil;
  }

  NSView *view = [pane loadMainView];

  currentPane = pane;
  [currentPane willSelect];
  [(NSBox *)prefsBox setContentView: view];
  [currentPane didSelect];

  // Hide the search field while a pref pane is shown
  if (searchField) {
    [searchField setHidden: YES];
  }

  // Update window title to match the selected pref pane's label
  {
    NSDictionary *dict = [[pane bundle] infoDictionary];
    NSString *lstr = [dict objectForKey: @"NSPrefPaneIconLabel"];
    if (lstr && [lstr length] > 0) {
      [window setTitle: lstr];
    } else {
      [window setTitle: @"System Preferences"];
    }
  }

  // Do not resize or animate the window when switching panes.

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
    if (currentPane == nil) {
      // Pane was unselected asynchronously or is missing — just switch back
      [self showIconsView];
      return;
    }
    NSPreferencePaneUnselectReply reply = [currentPane shouldUnselect];

    if (reply == NSUnselectNow) {
      [self showIconsView];
    } else if (reply == NSUnselectLater) {
      pendingAction = @selector(showIconsView);
    }
  } else {
    // If we're already showing the icons view, clear the search and show everything
    if (searchField) {
      [searchField setStringValue: @""];
    }
    [iconsView showAllIcons];
    [showAllButt setEnabled: NO];
  }
}

- (void)showIconsView
{
  NSView *view = [prefsBox contentView];
  
  if (view != iconsView) {
    [currentPane willUnselect];
    // Prepare icon data BEFORE adding the view to the hierarchy,
    // so the setFrame:/tile triggered by setContentView: already
    // sees the correct visible icons. This avoids a double tile.
    [iconsView showAllIcons];
    [(NSBox *)prefsBox setContentView: iconsView];
    // When returning to the icons view, clear search and show everything
    if (searchField) {
      [searchField setStringValue: @""];
      // Make the search field visible again when the main icons view is shown
      [searchField setHidden: NO];
    }
    [currentPane didUnselect];

    // Reset the window title when showing the icons view
    [window setTitle: @"System Preferences"];

    // Do not resize or animate the window when returning to icons view.

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

- (void)searchFieldDidChange:(NSNotification *)notif
{
  NSString *s = [searchField stringValue];

  if (s && [s length] > 0) {
    [showAllButt setEnabled: YES];
  } else {
    // If there's no search text, only enable Show All if a pane is selected
    [showAllButt setEnabled: (currentPane != nil)];
  }

  // Forward to icons view to trigger filtering immediately
  if ([iconsView respondsToSelector: @selector(searchFieldChanged:)]) {
    [iconsView searchFieldChanged: searchField];
  }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
  // Intercept ESC (cancelOperation:) when typing in controls (like the search field)
  if (commandSelector == @selector(cancelOperation:)) {
    [self showAll: control];
    return YES; // handled
  }

  return NO; // let the system handle other commands
}

- (void)cancelOperation:(id)sender
{
  // Also handle cancelOperation: in case it's sent directly up the responder chain
  [self showAll: sender];
}

- (void)closeAfterPaneUnselection
{
  [currentPane willUnselect];
  [(NSBox *)prefsBox setContentView: iconsView];
  [currentPane didUnselect];
  currentPane = nil;
  // Ensure search field is visible again when the icons view is shown
  if (searchField) {
    [searchField setHidden: NO];
    [searchField setStringValue: @""];
  }
  [window setTitle: @"System Preferences"];
  // Close without animation
  [window orderOut: self];
}

- (void)updateDefaults
{
  // Intentionally do not save the window frame to avoid moving it on future launches.
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













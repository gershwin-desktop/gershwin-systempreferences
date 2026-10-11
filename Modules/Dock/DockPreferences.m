/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import <AppKit/AppKit.h>
#import "DockPreferences.h"
#import "DockSettings.h"
#import "AppearanceMetrics.h"

/* Workspace reads these keys from its own bundle identifier domain. */
static NSString *const WorkspaceDomain = @"org.gnustep.Workspace";

static const CGFloat PaneWidth = 640.0;
static const CGFloat PaneHeight = 440.0;
static const CGFloat LabelWidth = 110.0;

@interface DockMainView : NSView
{
  DockPreferences *_layoutOwner;
}
- (void)setLayoutOwner:(DockPreferences *)owner;
@end

@implementation DockMainView

- (void)setFrameSize:(NSSize)newSize
{
  [super setFrameSize: newSize];
  [_layoutOwner relayoutForSize: newSize];
}

- (void)viewDidMoveToWindow
{
  [super viewDidMoveToWindow];
  if ([self window] && [self superview])
    {
      /* GNUstep sizes the box content a few pixels wider than the pane
       * area and setFrame: bypasses setFrameSize:, so fit and lay out
       * explicitly. */
      [self setFrame: [[self superview] bounds]];
      [_layoutOwner relayoutForSize: [self bounds].size];
    }
}

- (void)setLayoutOwner:(DockPreferences *)owner
{
  _layoutOwner = owner;
}

@end

@implementation DockPreferences

+ (BOOL)isCompatible
{
  return YES;
}

/* No nib: the pane is built in code so that the spacing follows
 * AppearanceMetrics.h and survives resizing. */
- (NSString *)mainNibName
{
  return nil;
}

- (NSView *)loadMainView
{
  if (_mainView == nil)
    {
      _mainView = [[self createMainView] retain];
      [self reloadControls];
    }
  return _mainView;
}

- (void)willSelect
{
  [super willSelect];
  [self reloadControls];
}

- (void)dealloc
{
  [mainView release];
  [dockBox release];
  [showCheck release];
  [positionLabel release];
  [positionPopUp release];
  [styleLabel release];
  [stylePopUp release];
  [magnificationCheck release];
  [super dealloc];
}

- (NSString *)localized:(NSString *)key
{
  return NSLocalizedStringFromTableInBundle(key, nil, [self bundle], @"");
}

- (NSTextField *)labelWithText:(NSString *)text
{
  NSTextField *label = [[NSTextField alloc] initWithFrame: NSZeroRect];

  [label setStringValue: text];
  [label setBezeled: NO];
  [label setBordered: NO];
  [label setEditable: NO];
  [label setSelectable: NO];
  [label setDrawsBackground: NO];
  [label setAlignment: NSTextAlignmentRight];
  [label setFont: METRICS_FONT_SYSTEM_REGULAR_13];
  return label;
}

- (NSButton *)checkboxWithTitle:(NSString *)title action:(SEL)action
{
  NSButton *button = [[NSButton alloc] initWithFrame: NSZeroRect];

  [button setButtonType: NSSwitchButton];
  [button setTitle: title];
  [button setTarget: self];
  [button setAction: action];
  return button;
}

- (NSPopUpButton *)popUpWithTitles:(NSArray *)titles action:(SEL)action
{
  NSPopUpButton *popUp = [[NSPopUpButton alloc] initWithFrame: NSZeroRect
                                                    pullsDown: NO];
  NSUInteger i;

  for (i = 0; i < [titles count]; i++)
    [popUp addItemWithTitle: [self localized: [titles objectAtIndex: i]]];
  [popUp setTarget: self];
  [popUp setAction: action];
  return popUp;
}

- (NSView *)createMainView
{
  DockMainView *view;

  view = [[DockMainView alloc] initWithFrame: NSMakeRect(0, 0, PaneWidth, PaneHeight)];
  [view setLayoutOwner: self];
  [view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  mainView = view;

  /* Four related controls, so one group box. */
  dockBox = [[NSBox alloc] initWithFrame: NSZeroRect];
  [dockBox setBoxType: NSBoxPrimary];
  [dockBox setBorderType: NSBezelBorder];
  [dockBox setTitlePosition: NSAtTop];
  [dockBox setTitle: [self localized: @"Dock"]];
  [view addSubview: dockBox];

  showCheck = [self checkboxWithTitle: [self localized: @"Show Dock"]
                               action: @selector(showChanged:)];
  positionLabel = [self labelWithText: [self localized: @"Position:"]];
  positionPopUp = [self popUpWithTitles:
    [NSArray arrayWithObjects: @"Left", @"Bottom", @"Right", nil]
                                 action: @selector(positionChanged:)];
  styleLabel = [self labelWithText: [self localized: @"Style:"]];
  stylePopUp = [self popUpWithTitles:
    [NSArray arrayWithObjects: @"Classic", @"Modern", nil]
                              action: @selector(styleChanged:)];
  magnificationCheck = [self checkboxWithTitle: [self localized: @"Magnification"]
                                        action: @selector(magnificationChanged:)];

  [[dockBox contentView] addSubview: showCheck];
  [[dockBox contentView] addSubview: positionLabel];
  [[dockBox contentView] addSubview: positionPopUp];
  [[dockBox contentView] addSubview: styleLabel];
  [[dockBox contentView] addSubview: stylePopUp];
  [[dockBox contentView] addSubview: magnificationCheck];

  [self relayoutForSize: [view bounds].size];
  return view;
}

- (void)relayoutForSize:(NSSize)size
{
  const CGFloat pad = METRICS_SPACE_16;
  const CGFloat checkH = METRICS_RADIO_BUTTON_SIZE;
  const CGFloat popH = METRICS_TEXT_INPUT_FIELD_HEIGHT;
  const CGFloat gap = METRICS_SPACE_8;
  /* title inset + top pad + rows + bottom pad, see gershwin-ui-metrics */
  const CGFloat titleInset = 14.0;
  CGFloat boxH = titleInset + pad + checkH + gap + popH + gap + popH + gap
                 + checkH + pad;
  CGFloat boxW = size.width - 2 * METRICS_CONTENT_SIDE_MARGIN;
  CGFloat cw, ch, y, fieldX;

  if (dockBox == nil)
    return;

  [dockBox setFrame: NSMakeRect(METRICS_CONTENT_SIDE_MARGIN,
                                size.height - METRICS_CONTENT_TOP_MARGIN - boxH,
                                boxW, boxH)];
  [dockBox setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

  cw = [[dockBox contentView] bounds].size.width;
  ch = [[dockBox contentView] bounds].size.height;
  fieldX = pad + LabelWidth + gap;

  y = ch - pad - checkH;
  [showCheck setFrame: NSMakeRect(pad, y, cw - 2 * pad, checkH)];
  y -= gap + popH;
  [positionLabel setFrame: NSMakeRect(pad, y + 3, LabelWidth, 17)];
  [positionPopUp setFrame: NSMakeRect(fieldX, y, cw - fieldX - pad, popH)];
  y -= gap + popH;
  [styleLabel setFrame: NSMakeRect(pad, y + 3, LabelWidth, 17)];
  [stylePopUp setFrame: NSMakeRect(fieldX, y, cw - fieldX - pad, popH)];
  y -= gap + checkH;
  [magnificationCheck setFrame: NSMakeRect(fieldX, y, cw - fieldX - pad, checkH)];
}

#pragma mark - defaults

- (DockSettings *)currentSettings
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  /* Another process (Workspace) may have written since we last looked. */
  [defaults synchronize];
  return [[[DockSettings alloc] initWithDomain:
    [defaults persistentDomainForName: WorkspaceDomain]] autorelease];
}

/* Merge only the changed keys into the domain, so nothing else Workspace
 * keeps there is rewritten. */
- (void)saveSettings:(DockSettings *)settings
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *domain;

  domain = [[[defaults persistentDomainForName: WorkspaceDomain] mutableCopy] autorelease];
  if (domain == nil)
    domain = [NSMutableDictionary dictionary];
  [domain addEntriesFromDictionary: [settings changedDomain]];
  [defaults setPersistentDomain: domain forName: WorkspaceDomain];
  [defaults synchronize];
}

- (void)reloadControls
{
  DockSettings *settings = [self currentSettings];
  BOOL visible = [settings dockVisible];

  [showCheck setState: visible ? NSOnState : NSOffState];
  [positionPopUp selectItemAtIndex:
    [DockSettings popupIndexForPosition: [settings position]]];
  [stylePopUp selectItemAtIndex: [settings style]];
  [magnificationCheck setState: [settings magnificationEnabled] ? NSOnState : NSOffState];

  [positionPopUp setEnabled: visible];
  [stylePopUp setEnabled: visible];
  [magnificationCheck setEnabled: visible];
}

#pragma mark - actions

- (void)showChanged:(id)sender
{
  DockSettings *settings = [self currentSettings];

  [settings setDockVisible: ([showCheck state] == NSOnState)];
  [self saveSettings: settings];
  [self reloadControls];
}

- (void)positionChanged:(id)sender
{
  DockSettings *settings = [self currentSettings];

  [settings setPosition:
    [DockSettings positionForPopupIndex: [positionPopUp indexOfSelectedItem]]];
  [self saveSettings: settings];
}

- (void)styleChanged:(id)sender
{
  DockSettings *settings = [self currentSettings];

  [settings setStyle: [stylePopUp indexOfSelectedItem] == 1
    ? DockSettingsStyleModern : DockSettingsStyleClassic];
  [self saveSettings: settings];
}

- (void)magnificationChanged:(id)sender
{
  DockSettings *settings = [self currentSettings];

  [settings setMagnificationEnabled: ([magnificationCheck state] == NSOnState)];
  [self saveSettings: settings];
}

@end

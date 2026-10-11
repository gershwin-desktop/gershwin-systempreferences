/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR GPL-3.0-or-later
 */
#import <AppKit/AppKit.h>
#import "DesktopBackgroundPreferences.h"
#import "DesktopBackgroundSettings.h"
#import "AppearanceMetrics.h"

/* Workspace reads these keys from its own bundle identifier domain. */
static NSString *const WorkspaceDomain = @"org.gnustep.Workspace";

static const CGFloat PaneWidth = 640.0;
static const CGFloat PaneHeight = 440.0;
static const CGFloat LabelWidth = 110.0;

@interface DesktopBackgroundMainView : NSView
{
  DesktopBackgroundPreferences *_layoutOwner;
}
- (void)setLayoutOwner:(DesktopBackgroundPreferences *)owner;
@end

@implementation DesktopBackgroundMainView

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

- (void)setLayoutOwner:(DesktopBackgroundPreferences *)owner
{
  _layoutOwner = owner;
}

@end

@implementation DesktopBackgroundPreferences

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
  [backgroundBox release];
  [colorLabel release];
  [colorWell release];
  [useImageCheck release];
  [imageLabel release];
  [imageField release];
  [chooseButton release];
  [styleLabel release];
  [stylePopUp release];
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
  DesktopBackgroundMainView *view;
  NSView *content;

  view = [[DesktopBackgroundMainView alloc]
           initWithFrame: NSMakeRect(0, 0, PaneWidth, PaneHeight)];
  [view setLayoutOwner: self];
  [view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  mainView = view;

  /* Color, image and its style belong together, so one group box. */
  backgroundBox = [[NSBox alloc] initWithFrame: NSZeroRect];
  [backgroundBox setBoxType: NSBoxPrimary];
  [backgroundBox setBorderType: NSBezelBorder];
  [backgroundBox setTitlePosition: NSAtTop];
  [backgroundBox setTitle: [self localized: @"Desktop Background"]];
  [view addSubview: backgroundBox];

  colorLabel = [self labelWithText: [self localized: @"Color:"]];
  colorWell = [[NSColorWell alloc] initWithFrame: NSZeroRect];
  [colorWell setTarget: self];
  [colorWell setAction: @selector(colorChanged:)];
  useImageCheck = [self checkboxWithTitle: [self localized: @"Use Image"]
                                   action: @selector(useImageChanged:)];
  imageLabel = [self labelWithText: [self localized: @"Image:"]];
  imageField = [self labelWithText: @""];
  [imageField setAlignment: NSTextAlignmentLeft];
  [[imageField cell] setLineBreakMode: NSLineBreakByTruncatingMiddle];
  chooseButton = [[NSButton alloc] initWithFrame: NSZeroRect];
  [chooseButton setButtonType: NSMomentaryPushInButton];
  [chooseButton setBezelStyle: NSRoundedBezelStyle];
  [chooseButton setTitle: [self localized: @"Choose..."]];
  [chooseButton setTarget: self];
  [chooseButton setAction: @selector(chooseImage:)];
  styleLabel = [self labelWithText: [self localized: @"Style:"]];
  stylePopUp = [self popUpWithTitles:
    [NSArray arrayWithObjects: @"Center", @"Fit", @"Tile", @"Scale", nil]
                              action: @selector(styleChanged:)];

  content = [backgroundBox contentView];
  [content addSubview: colorLabel];
  [content addSubview: colorWell];
  [content addSubview: useImageCheck];
  [content addSubview: imageLabel];
  [content addSubview: imageField];
  [content addSubview: chooseButton];
  [content addSubview: styleLabel];
  [content addSubview: stylePopUp];

  [self relayoutForSize: [view bounds].size];
  return view;
}

- (void)relayoutForSize:(NSSize)size
{
  const CGFloat pad = METRICS_SPACE_16;
  const CGFloat checkH = METRICS_RADIO_BUTTON_SIZE;
  const CGFloat popH = METRICS_TEXT_INPUT_FIELD_HEIGHT;
  const CGFloat gap = METRICS_SPACE_8;
  const CGFloat buttonW = 100.0;
  /* title inset + top pad + rows + bottom pad, see gershwin-ui-metrics */
  const CGFloat titleInset = 14.0;
  CGFloat boxH = titleInset + pad + popH + gap + checkH + gap + popH + gap
                 + popH + pad;
  CGFloat boxW = size.width - 2 * METRICS_CONTENT_SIDE_MARGIN;
  CGFloat cw, ch, y, fieldX;

  if (backgroundBox == nil)
    return;

  [backgroundBox setFrame: NSMakeRect(METRICS_CONTENT_SIDE_MARGIN,
                                      size.height - METRICS_CONTENT_TOP_MARGIN - boxH,
                                      boxW, boxH)];
  [backgroundBox setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];

  cw = [[backgroundBox contentView] bounds].size.width;
  ch = [[backgroundBox contentView] bounds].size.height;
  fieldX = pad + LabelWidth + gap;

  y = ch - pad - popH;
  [colorLabel setFrame: NSMakeRect(pad, y + 3, LabelWidth, 17)];
  [colorWell setFrame: NSMakeRect(fieldX, y, 60, popH)];
  y -= gap + checkH;
  [useImageCheck setFrame: NSMakeRect(fieldX, y, cw - fieldX - pad, checkH)];
  y -= gap + popH;
  [imageLabel setFrame: NSMakeRect(pad, y + 3, LabelWidth, 17)];
  [chooseButton setFrame: NSMakeRect(cw - pad - buttonW, y, buttonW, popH)];
  [imageField setFrame: NSMakeRect(fieldX, y + 3,
                                   cw - pad - buttonW - gap - fieldX, 17)];
  y -= gap + popH;
  [styleLabel setFrame: NSMakeRect(pad, y + 3, LabelWidth, 17)];
  [stylePopUp setFrame: NSMakeRect(fieldX, y, cw - fieldX - pad, popH)];
}

#pragma mark - defaults

- (DesktopBackgroundSettings *)currentSettings
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  /* Another process (Workspace) may have written since we last looked. */
  [defaults synchronize];
  return [[[DesktopBackgroundSettings alloc] initWithDomain:
    [defaults persistentDomainForName: WorkspaceDomain]] autorelease];
}

/* Workspace keeps its icon settings in the same "desktopinfo" dictionary,
 * so write back the whole merged dictionary and leave the other domain keys
 * alone. */
- (void)saveSettings:(DesktopBackgroundSettings *)settings
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *domain;

  domain = [[[defaults persistentDomainForName: WorkspaceDomain] mutableCopy] autorelease];
  if (domain == nil)
    domain = [NSMutableDictionary dictionary];
  [domain setObject: [settings desktopInfo] forKey: @"desktopinfo"];
  [defaults setPersistentDomain: domain forName: WorkspaceDomain];
  [defaults synchronize];
}

- (void)reloadControls
{
  DesktopBackgroundSettings *settings = [self currentSettings];
  NSString *path = [settings imagePath];
  BOOL useImage = [settings useImage];
  CGFloat r, g, b, a;

  [settings getRed: &r green: &g blue: &b alpha: &a];
  [colorWell setColor: [NSColor colorWithCalibratedRed: r green: g blue: b alpha: a]];
  [useImageCheck setState: useImage ? NSOnState : NSOffState];
  [imageField setStringValue: path ? path : [self localized: @"None"]];
  [stylePopUp selectItemAtIndex: [settings style]];

  /* Without an image there is nothing to switch on or to style. */
  [useImageCheck setEnabled: path != nil];
  [stylePopUp setEnabled: useImage];
}

#pragma mark - actions

- (void)colorChanged:(id)sender
{
  DesktopBackgroundSettings *settings = [self currentSettings];
  NSColor *color = [[colorWell color]
    colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  CGFloat r, g, b, a;

  [color getRed: &r green: &g blue: &b alpha: &a];
  [settings setRed: r green: g blue: b alpha: a];
  [self saveSettings: settings];
}

- (void)useImageChanged:(id)sender
{
  DesktopBackgroundSettings *settings = [self currentSettings];

  [settings setUseImage: ([useImageCheck state] == NSOnState)];
  [self saveSettings: settings];
  [self reloadControls];
}

- (void)chooseImage:(id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  DesktopBackgroundSettings *settings;
  NSString *path;

  [panel setAllowsMultipleSelection: NO];
  [panel setCanChooseDirectories: NO];
  [panel setAllowedFileTypes: [NSImage imageFileTypes]];
  if ([panel runModal] != NSOKButton)
    return;

  path = [[panel URL] path];
  settings = [self currentSettings];
  [settings setImagePath: path];
  /* Picking an image is asking to see it. */
  [settings setUseImage: YES];
  [self saveSettings: settings];
  [self reloadControls];
}

- (void)styleChanged:(id)sender
{
  DesktopBackgroundSettings *settings = [self currentSettings];

  [settings setStyle: (DesktopBackgroundStyle)[stylePopUp indexOfSelectedItem]];
  [self saveSettings: settings];
}

@end

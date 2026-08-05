/* ModifierKeys.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2005
 *
 * This file is part of the GNUstep ModifierKeys Preference Pane
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

#include <AppKit/AppKit.h>
#include "ModifierKeys.h"
#include "ModifierKeySearchField.h"

static NSString *menuEntries = @"\
{\
\"None\" = \"NoSymbol\"; \
\"AltGr (XFree86 4.3+)\" = \"ISO_Level3_Shift\"; \
\"Left Alt\" = \"Alt_L\"; \
\"Left Control\" = \"Control_L\"; \
\"Left Hyper\" = \"Hyper_L\"; \
\"Left Meta\" = \"Meta_L\"; \
\"Left Super\" = \"Super_L\"; \
\"Right Alt\" = \"Alt_R\"; \
\"Right Control\" = \"Control_R\"; \
\"Right Hyper\" = \"Hyper_R\"; \
\"Right Meta\" = \"Meta_R\"; \
\"Right Super\" = \"Super_R\"; \
\"Mode Switch\" = \"Mode_switch\"; \
\"Multi-Key\" = \"Multi_key\"; \
} \
";

static NSString *const ModifierNoneTitle = @"None";
static NSString *const ModifierNoneSymbol = @"NoSymbol";

@interface ModifierKeys ()
{
  NSDictionary *menuDictionary;
}

- (NSDictionary *)menuDictionary;
- (NSString *)titleForModifierSymbol:(NSString *)modifier;
- (NSString *)titleForModifierSymbol:(NSString *)modifier found:(BOOL *)found;
- (void)configureSearchField:(ModifierKeySearchField *)field
               defaultsKey:(NSString *)defaultsKey;
- (void)updateDefaultsForSender:(id)sender
                 modifierSymbol:(NSString *)modifier;
- (NSString *)defaultsKeyForSender:(id)sender;
- (NSString *)labelForDefaultsKey:(NSString *)defaultsKey;
- (BOOL)modifierSymbolInUse:(NSString *)modifier
            excludingSender:(id)sender
           conflictingLabel:(NSString **)label;
- (void)showDuplicateAlertForModifierTitle:(NSString *)modifierTitle
                          conflictingLabel:(NSString *)label;

@end

@implementation ModifierKeys

- (void)mainViewDidLoad
{
  if (loaded == NO) {
    [self configureSearchField: firstAlternateField
                   defaultsKey: @"GSFirstAlternateKey"];
    [self configureSearchField: firstCommandField
                   defaultsKey: @"GSFirstCommandKey"];
    [self configureSearchField: firstControlField
                   defaultsKey: @"GSFirstControlKey"];
    [self configureSearchField: secondAlternateField
                   defaultsKey: @"GSSecondAlternateKey"];
    [self configureSearchField: secondCommandField
                   defaultsKey: @"GSSecondCommandKey"];
    [self configureSearchField: secondControlField
                   defaultsKey: @"GSSecondControlKey"];
      
    loaded = YES;
  }
}

- (NSDictionary *)menuDictionary
{
  if (menuDictionary == nil) {
    menuDictionary = [[menuEntries propertyList] retain];
  }

  return menuDictionary;
}

- (NSString *)titleForModifierSymbol:(NSString *)modifier
{
  return [self titleForModifierSymbol: modifier found: NULL];
}

- (NSString *)titleForModifierSymbol:(NSString *)modifier found:(BOOL *)found
{
  NSDictionary *dict = [self menuDictionary];
  NSArray *titles = [dict allKeys];
  unsigned i;

  if (found) {
    *found = NO;
  }

  if (modifier == nil) {
    return ModifierNoneTitle;
  }

  for (i = 0; i < [titles count]; i++) {
    NSString *title = [titles objectAtIndex: i];
    NSString *value = [dict objectForKey: title];

    if ([value isEqual: modifier]) {
      if (found) {
        *found = YES;
      }
      return title;
    }
  }

  return ModifierNoneTitle;
}

- (void)configureSearchField:(ModifierKeySearchField *)field
                 defaultsKey:(NSString *)defaultsKey
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *modifier = [defaults objectForKey: defaultsKey];
  NSString *title = [self titleForModifierSymbol: modifier];

  [field setTarget: self];
  [field setAction: @selector(searchFieldAction:)];
  [field setStringValue: title];
}

- (IBAction)searchFieldAction:(id)sender
{
  NSString *title = nil;
  NSString *modifier = nil;

  if ([sender isKindOfClass: [ModifierKeySearchField class]]) {
    BOOL found = NO;
    NSString *captured = [sender capturedModifierSymbol];

    if (captured != nil) {
      title = [self titleForModifierSymbol: captured found: &found];
      [sender clearCapturedModifierSymbol];

      if (found) {
        NSString *conflictLabel = nil;

        if ([self modifierSymbolInUse: captured
                      excludingSender: sender
                     conflictingLabel: &conflictLabel]) {
          [sender restorePreCaptureValue];
          [sender setNeedsDisplay: YES];
          [[sender window] displayIfNeeded];
          [self showDuplicateAlertForModifierTitle: title
                                  conflictingLabel: conflictLabel];
          return;
        }

        [sender setStringValue: title];
        [self updateDefaultsForSender: sender modifierSymbol: captured];
      }
      return;
    }
  }

  title = [sender stringValue];

  if ([title length] == 0 || [title isEqual: ModifierNoneTitle]) {
    [sender setStringValue: ModifierNoneTitle];
    modifier = ModifierNoneSymbol;
  } else {
    modifier = [[self menuDictionary] objectForKey: title];
  }

  if (modifier != nil) {
    if ([modifier isEqual: ModifierNoneSymbol] == NO) {
      NSString *conflictLabel = nil;

      if ([self modifierSymbolInUse: modifier
                    excludingSender: sender
                   conflictingLabel: &conflictLabel]) {
        if ([sender isKindOfClass: [ModifierKeySearchField class]]) {
          [sender restorePreCaptureValue];
          [sender setNeedsDisplay: YES];
          [[sender window] displayIfNeeded];
        }
        [self showDuplicateAlertForModifierTitle: title
                                conflictingLabel: conflictLabel];
        return;
      }
    }

    [self updateDefaultsForSender: sender modifierSymbol: modifier];
  }
}

- (void)updateDefaultsForSender:(id)sender
               modifierSymbol:(NSString *)modifier
{
  CREATE_AUTORELEASE_POOL(arp);
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *domain;

  [defaults synchronize];
  domain = [[defaults persistentDomainForName: NSGlobalDomain] mutableCopy];

  if (sender == firstAlternateField) {
    [domain setObject: modifier forKey: @"GSFirstAlternateKey"];
  } else if (sender == firstCommandField) {
    [domain setObject: modifier forKey: @"GSFirstCommandKey"];
  } else if (sender == firstControlField) {
    [domain setObject: modifier forKey: @"GSFirstControlKey"];
  } else if (sender == secondAlternateField) {
    [domain setObject: modifier forKey: @"GSSecondAlternateKey"];
  } else if (sender == secondCommandField) {
    [domain setObject: modifier forKey: @"GSSecondCommandKey"];
  } else if (sender == secondControlField) {
    [domain setObject: modifier forKey: @"GSSecondControlKey"];
  }

  [defaults setPersistentDomain: domain forName: NSGlobalDomain];
  [defaults synchronize];
  RELEASE (domain);
  RELEASE (arp);
}

- (NSString *)defaultsKeyForSender:(id)sender
{
  if (sender == firstAlternateField) {
    return @"GSFirstAlternateKey";
  }
  if (sender == firstCommandField) {
    return @"GSFirstCommandKey";
  }
  if (sender == firstControlField) {
    return @"GSFirstControlKey";
  }
  if (sender == secondAlternateField) {
    return @"GSSecondAlternateKey";
  }
  if (sender == secondCommandField) {
    return @"GSSecondCommandKey";
  }
  if (sender == secondControlField) {
    return @"GSSecondControlKey";
  }

  return nil;
}

- (NSString *)labelForDefaultsKey:(NSString *)defaultsKey
{
  if ([defaultsKey isEqual: @"GSFirstAlternateKey"]) {
    return [firstAlternateLabel stringValue];
  }
  if ([defaultsKey isEqual: @"GSFirstCommandKey"]) {
    return [firstCommandLabel stringValue];
  }
  if ([defaultsKey isEqual: @"GSFirstControlKey"]) {
    return [firstControlLabel stringValue];
  }
  if ([defaultsKey isEqual: @"GSSecondAlternateKey"]) {
    return [secondAlternateLabel stringValue];
  }
  if ([defaultsKey isEqual: @"GSSecondCommandKey"]) {
    return [secondCommandLabel stringValue];
  }
  if ([defaultsKey isEqual: @"GSSecondControlKey"]) {
    return [secondControlLabel stringValue];
  }

  return @"";
}

- (BOOL)modifierSymbolInUse:(NSString *)modifier
            excludingSender:(id)sender
           conflictingLabel:(NSString **)label
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *domain = [defaults persistentDomainForName: NSGlobalDomain];
  NSString *senderKey = [self defaultsKeyForSender: sender];
  NSArray *keys = [NSArray arrayWithObjects:
                   @"GSFirstAlternateKey",
                   @"GSFirstCommandKey",
                   @"GSFirstControlKey",
                   @"GSSecondAlternateKey",
                   @"GSSecondCommandKey",
                   @"GSSecondControlKey",
                   nil];
  unsigned i;

  for (i = 0; i < [keys count]; i++) {
    NSString *key = [keys objectAtIndex: i];
    NSString *value = [domain objectForKey: key];

    if (value && [value isEqual: modifier]) {
      if (senderKey == nil || [key isEqual: senderKey] == NO) {
        if (label) {
          *label = [self labelForDefaultsKey: key];
        }
        return YES;
      }
    }
  }

  return NO;
}

- (void)showDuplicateAlertForModifierTitle:(NSString *)modifierTitle
                          conflictingLabel:(NSString *)label
{
  NSString *message = [NSString stringWithFormat: @"%@ is assigned to %@.",
                       modifierTitle,
                       label];
  NSAlert *alert = [NSAlert alertWithMessageText: message
                                   defaultButton: @"OK"
                                 alternateButton: nil
                                     otherButton: nil
                       informativeTextWithFormat: @""];
  NSWindow *window = [NSApp keyWindow];

  if (window == nil) {
    window = [NSApp mainWindow];
  }

  if (window != nil) {
    [alert beginSheetModalForWindow: window
                      modalDelegate: nil
                     didEndSelector: NULL
                        contextInfo: NULL];
  } else {
    [alert runModal];
  }
}

- (void)dealloc
{
  RELEASE (menuDictionary);
  [super dealloc];
}

@end	







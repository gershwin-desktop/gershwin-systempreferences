/* TimeZone.m
 *  
 * Copyright (C) 2005-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2005
 *
 * This file is part of the GNUstep TimeZone Preference Pane
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
#import "TimeZone.h"
#import "MapView.h"

static void setSystemTimezone(NSString *zone)
{
  NSString *zoneinfoPath = [@"/usr/share/zoneinfo" stringByAppendingPathComponent: zone];

  if ([[NSFileManager defaultManager] fileExistsAtPath: zoneinfoPath] == NO) {
    NSLog(@"TimeZone: zoneinfo not found at %@", zoneinfoPath);
    return;
  }

  NSArray *args = @[@"-S", @"ln", @"-sfn", zoneinfoPath, @"/etc/localtime"];
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath: @"/usr/bin/sudo"];
  [task setArguments: args];
  [task setStandardOutput: [NSFileHandle fileHandleWithNullDevice]];
  [task setStandardError: [NSFileHandle fileHandleWithNullDevice]];
  @try {
    [task launch];
    [task waitUntilExit];
  } @catch (id ex) {
    NSLog(@"TimeZone: failed to set system timezone: %@", ex);
  }
  RELEASE(task);
}

static NSString *readUtcConfig(void)
{
  NSString *adjtime = @"/etc/adjtime";
  if ([[NSFileManager defaultManager] fileExistsAtPath: adjtime]) {
    NSString *content = [NSString stringWithContentsOfFile: adjtime
                                                   encoding: NSUTF8StringEncoding
                                                      error: NULL];
    if (content) {
      NSArray *lines = [content componentsSeparatedByString: @"\n"];
      if ([lines count] >= 3) {
        NSString *third = [[lines objectAtIndex: 2]
                           stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return [third uppercaseString];
      }
    }
  }
  return @"LOCAL";
}

static void writeUtcConfig(BOOL isUTC)
{
  NSString *content = @"0.0 0 0\n0\n";
  content = [content stringByAppendingString: (isUTC ? @"UTC" : @"LOCAL")];
  content = [content stringByAppendingString: @"\n"];
  NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent: @"adjtime"];
  [content writeToFile: tmpPath atomically: YES encoding: NSUTF8StringEncoding error: NULL];
  NSArray *args = @[@"-S", @"cp", tmpPath, @"/etc/adjtime"];
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath: @"/usr/bin/sudo"];
  [task setArguments: args];
  [task setStandardOutput: [NSFileHandle fileHandleWithNullDevice]];
  [task setStandardError: [NSFileHandle fileHandleWithNullDevice]];
  @try {
    [task launch];
    [task waitUntilExit];
    if ([task terminationStatus] == 0) {
      RELEASE(task);
      task = [[NSTask alloc] init];
      [task setLaunchPath: @"/usr/bin/sudo"];
      [task setArguments: @[@"-S", @"rm", tmpPath]];
      [task setStandardOutput: [NSFileHandle fileHandleWithNullDevice]];
      [task setStandardError: [NSFileHandle fileHandleWithNullDevice]];
      [task launch];
      [task waitUntilExit];
    }
  } @catch (id ex) {
    NSLog(@"TimeZone: failed to write adjtime: %@", ex);
  }
  RELEASE(task);
}

static void notifyClockExtra(void)
{
  id proxy = [NSConnection rootProxyForConnectionWithRegisteredName:
                @"org.gnustep.ClockExtraService" host: nil];
  if (proxy) {
    [proxy performSelector: @selector(timeConfigDidChange)];
  }
}


@implementation TimeZone

+ (BOOL)isCompatible {
  return [[NSFileManager defaultManager] fileExistsAtPath: @"/usr/share/zoneinfo"];
}

+ (NSString *)compatibilityReason {
  return @"No timezone data found";
}

- (void)dealloc
{
  TEST_RELEASE (utcCheckbox);
	[super dealloc];
}

- (void)mainViewDidLoad
{
  if (mapView == nil)
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      NSString *zone = [defaults objectForKey: @"Local Time Zone"];
      NSBundle *bundle = [self bundle];
      NSString *path = [bundle pathForResource: @"map" ofType: @"tiff"];
      NSImage *map = [[NSImage alloc] initWithContentsOfFile: path];

      path = [bundle pathForResource: @"zones" ofType: @"db"];

      mapView = [[MapView alloc] initWithFrame: [[imageBox contentView] frame]
                                  withMapImage: map
                                 timeZonesPath: path
                             forPreferencePane: self];

      [(NSBox *)imageBox setContentView: mapView];
      RELEASE (mapView);
      RELEASE (map);

      if (zone)
	{
	  [zoneField setStringValue: zone];
	}

      BOOL isUTC = [readUtcConfig() isEqualToString: @"UTC"];
      CGFloat yOff = 0;
      if (setButt) {
        NSRect buttFrame = [setButt frame];
        yOff = NSMaxY(buttFrame) + 8;
      }
      NSRect parentBounds = [[self mainView] bounds];
      utcCheckbox = [[NSButton alloc] initWithFrame:
        NSMakeRect(12, parentBounds.size.height - yOff - 22, 220, 18)];
      [utcCheckbox setButtonType: NSSwitchButton];
      [utcCheckbox setTitle: @"Hardware clock is in UTC"];
      [utcCheckbox setState: isUTC ? NSOnState : NSOffState];
      [utcCheckbox setTarget: self];
      [utcCheckbox setAction: @selector(utcCheckboxAction:)];
      [[self mainView] addSubview: utcCheckbox];
    }  
}

- (void)showInfoOfLocation:(MapLocation *)loc
{
  if (loc) {
    [zoneField setStringValue: [loc zone]];
    [codeField setStringValue: [loc code]];
    [commentsField setStringValue: (([loc comments] != nil) ? [loc comments] : @"")];
  } else {
    [zoneField setStringValue: @""];
    [codeField setStringValue: @""];
    [commentsField setStringValue: @""];
  }
}

- (IBAction)setButtAction:(id)sender
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *zone = [zoneField stringValue];

  if ([zone length] == 0) {
    RELEASE (arp);
    return;
  }

  NSUserDefaults *defaults;
  NSMutableDictionary *domain;

  defaults = [NSUserDefaults standardUserDefaults];
  [defaults synchronize];
  domain = [[defaults persistentDomainForName: NSGlobalDomain] mutableCopy];

  [domain setObject: zone forKey: @"Local Time Zone"];  
  
  [defaults setPersistentDomain: domain forName: NSGlobalDomain];
  [defaults synchronize];
  RELEASE (domain);

  setSystemTimezone(zone);

  notifyClockExtra();

  RELEASE (arp);
}

- (void)utcCheckboxAction:(id)sender
{
  BOOL isUTC = ([utcCheckbox state] == NSOnState);
  writeUtcConfig(isUTC);
  notifyClockExtra();
}

@end








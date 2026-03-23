/* Themes.h
 *  
 * Copyright (C) 2009-2014 Free Software Foundation, Inc.
 *
 * Author: Riccardo Mottola <rmottola@users.sf.net>
 * Date: October 2009
 *
 * This file is part of the GNUstep ColorSchemes Themes Preference Pane
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

#import <GNUstepGUI/GSTheme.h>

#import "Themes.h"

@implementation Themes



- (void)mainViewDidLoad
{
  NSButtonCell	*proto;

  proto = [[NSButtonCell alloc] init];
  [proto setBordered: NO];
  [proto setAlignment: NSCenterTextAlignment];
  [proto setImagePosition: NSImageAbove];
  [proto setSelectable: NO];
  [proto setEditable: NO];

  [matrix setPrototype: proto];
  [proto release];
  [matrix renewRows:1 columns:1];
  [matrix setAutosizesCells: NO];
  [matrix setCellSize: NSMakeSize(72,72)];
  [matrix setIntercellSpacing: NSMakeSize(8,8)];
  [matrix setAutoresizingMask: NSViewNotSizable];
  [matrix setMode: NSRadioModeMatrix];
  [matrix setAction: @selector(changeSelection:)];
  [matrix setTarget: self];



  [self loadThemes:self];
}

/** standard to implement fot Preference Panes */
-(void) willUnselect
{

}

- (void) changeSelection: (id)sender
{
  NSButtonCell	*cell = [sender selectedCell];
  NSString	*name = [cell title];
  NSFileManager *mgr = [NSFileManager defaultManager];

  [nameField setStringValue: name];

  /* Read theme metadata directly from the bundle's Info.plist so that we
   * do NOT call [GSTheme loadThemeNamed:].  Loading a theme instantiates
   * its class and injects method overrides (class_addMethod) into live
   * classes — which can crash NSMenu and other shared objects even when
   * the theme is only being previewed, not applied.
   */

  NSString *themeBundlePath = nil;

  if ([name isEqualToString: @"GNUstep"])
    {
      /* The default theme has no separate bundle on disk. */
      [authorsView setString: @""];
      [versionField setStringValue: @""];
      [licenseField setStringValue: @""];
      [detailsView setString: @"Default GNUstep theme"];

      NSString *previewPath = [[self bundle] pathForResource: @"gnustep_preview_128" ofType: @"tiff"];
      NSImage *previewImage = previewPath
        ? [[[NSImage alloc] initWithContentsOfFile: previewPath] autorelease]
        : nil;
      [previewView setImage: previewImage];
      return;
    }

  /* Locate the theme bundle without loading it. */
  NSString *themeBundleName = [name stringByAppendingPathExtension: @"theme"];
  NSEnumerator *libEnum = [NSSearchPathForDirectoriesInDomains
    (NSAllLibrariesDirectory, NSAllDomainsMask, YES) objectEnumerator];
  NSString *libPath;
  while ((libPath = [libEnum nextObject]) != nil)
    {
      NSString *candidate = [[libPath stringByAppendingPathComponent: @"Themes"]
                                      stringByAppendingPathComponent: themeBundleName];
      BOOL isDir = NO;
      if ([mgr fileExistsAtPath: candidate isDirectory: &isDir] && isDir)
        {
          themeBundlePath = candidate;
          break;
        }
    }

  if (themeBundlePath == nil)
    {
      [authorsView setString: @""];
      [versionField setStringValue: @""];
      [licenseField setStringValue: @""];
      [detailsView setString: @"Theme not found"];
      NSString *noPreview = [[self bundle] pathForResource: @"no_preview" ofType: @"tiff"];
      [previewView setImage: noPreview
        ? [[[NSImage alloc] initWithContentsOfFile: noPreview] autorelease]
        : nil];
      return;
    }

  /* Read Info.plist directly — do not call [NSBundle bundleWithPath:] followed
   * by principalClass, as that would load the bundle code.
   */
  NSString *plistPath = [themeBundlePath stringByAppendingPathComponent: @"Resources/Info-gnustep.plist"];
  if (![mgr fileExistsAtPath: plistPath])
    {
      plistPath = [themeBundlePath stringByAppendingPathComponent: @"Info.plist"];
    }
  NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile: plistPath];

  /* Authors */
  NSArray *authors = [info objectForKey: @"GSThemeAuthors"];
  NSString *authorsString = @"";
  if ([authors count] > 0)
    authorsString = [authors componentsJoinedByString: @"\n"];
  [authorsView setString: authorsString];

  /* Version */
  NSString *version = [info objectForKey: @"GSThemeVersion"];
  [versionField setStringValue: version ? version : @""];

  /* License */
  NSString *license = [info objectForKey: @"GSThemeLicense"];
  [licenseField setStringValue: license ? license : @""];

  /* Details */
  NSString *themeDetails = [info objectForKey: @"GSThemeDetails"];
  [detailsView setString: themeDetails ? themeDetails : @""];

  /* Preview image */
  NSString *previewName = [info objectForKey: @"GSThemePreview"];
  NSString *previewPath = nil;
  if ([previewName length] > 0)
    {
      previewPath = [[themeBundlePath stringByAppendingPathComponent: @"Resources"]
                                      stringByAppendingPathComponent: previewName];
      if (![mgr fileExistsAtPath: previewPath])
        previewPath = nil;
    }
  if (previewPath == nil)
    {
      previewPath = [[self bundle] pathForResource: @"no_preview" ofType: @"tiff"];
    }

  NSImage *previewImage = previewPath
    ? [[[NSImage alloc] initWithContentsOfFile: previewPath] autorelease]
    : nil;
  [previewView setImage: previewImage];
}

- (IBAction)apply:(id)sender
{
  [GSTheme setTheme: [GSTheme loadThemeNamed: [nameField stringValue]]];
}

- (IBAction)save:(id)sender
{
  NSUserDefaults      *defaults;
  NSMutableDictionary *domain;
  NSString            *themeName;

  defaults = [NSUserDefaults standardUserDefaults];
  domain = [NSMutableDictionary dictionaryWithDictionary: [defaults persistentDomainForName: NSGlobalDomain]];
  themeName = [nameField stringValue];

  if ([themeName isEqualToString:@"GNUstep"] == YES)
    [domain removeObjectForKey:@"GSTheme"];
  else
    [domain setObject:themeName
               forKey: @"GSTheme"];
  [defaults setPersistentDomain: domain forName: NSGlobalDomain];
}


- (void) loadThemes: (id)sender
{
  /* Avoid [NSMutableSet set] that confuses GCC 3.3.3. */
  NSMutableSet		*set = AUTORELEASE([NSMutableSet new]);

  NSString		*selected = RETAIN([[matrix selectedCell] title]);
  unsigned		existing = [[matrix cells] count];
  NSFileManager		*mgr = [NSFileManager defaultManager];
  NSEnumerator		*enumerator;
  NSString		*path;
  NSString		*name;
  NSButtonCell		*cell;
  unsigned		count = 0;

  /* Ensure the first cell contains the default theme.
   * Do NOT call loadThemeNamed: here — that instantiates the theme class
   * and injects method overrides into live classes via class_addMethod,
   * which can corrupt NSMenu and other shared classes even without
   * applying the theme.  Instead, just display the name.
   */
  cell = [matrix cellAtRow: 0 column: count++];
  [cell setImage: [NSImage imageNamed: @"GNUstep"]];
  [cell setTitle: @"GNUstep"];

  /* Go through all the themes in the standard locations and find their names.
   */
  enumerator = [NSSearchPathForDirectoriesInDomains
    (NSAllLibrariesDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((path = [enumerator nextObject]) != nil)
    {
      NSEnumerator	*files;
      NSString		*file;

      path = [path stringByAppendingPathComponent: @"Themes"];
      files = [[mgr directoryContentsAtPath: path] objectEnumerator];
      while ((file = [files nextObject]) != nil)
        {
	  NSString	*ext = [file pathExtension];

	  name = [file stringByDeletingPathExtension];
	  if ([ext isEqualToString: @"theme"] == YES
	    && [name isEqualToString: @"GNUstep"] == NO
	    && [[name pathExtension] isEqual: @"backup"] == NO)
	    {
	      [set addObject: name];
	    }
	}
    }

  /* Sort theme names alphabetically and add each to the matrix.
   * Only read the icon from the bundle's Resources without fully loading
   * the theme, so no method overrides are injected.
   */
  NSArray *array = [[set allObjects] sortedArrayUsingSelector:
    @selector(caseInsensitiveCompare:)];
  enumerator = [array objectEnumerator];
  while ((name = [enumerator nextObject]) != nil)
    {
      /* Locate the theme bundle without instantiating the theme class. */
      NSString *themeBundleName = [name stringByAppendingPathExtension: @"theme"];
      NSString *themePath = nil;
      NSEnumerator *libEnum = [NSSearchPathForDirectoriesInDomains
        (NSAllLibrariesDirectory, NSAllDomainsMask, YES) objectEnumerator];
      NSString *libPath;
      while ((libPath = [libEnum nextObject]) != nil)
        {
          NSString *candidate = [[libPath stringByAppendingPathComponent: @"Themes"]
                                          stringByAppendingPathComponent: themeBundleName];
          BOOL isDir = NO;
          if ([mgr fileExistsAtPath: candidate isDirectory: &isDir] && isDir)
            {
              themePath = candidate;
              break;
            }
        }

      if (themePath != nil)
        {
          /* Try to load a preview/icon image from the bundle resources
           * without calling [bundle load] or [GSTheme loadThemeNamed:].
           */
          NSImage *themeIcon = nil;
          NSString *iconPath = [[themePath stringByAppendingPathComponent: @"Resources"]
                                           stringByAppendingPathComponent: @"icon.tiff"];
          if ([mgr fileExistsAtPath: iconPath])
            {
              themeIcon = [[[NSImage alloc] initWithContentsOfFile: iconPath] autorelease];
            }
          if (themeIcon == nil)
            {
              /* Try png variant */
              iconPath = [[themePath stringByAppendingPathComponent: @"Resources"]
                                     stringByAppendingPathComponent: @"icon.png"];
              if ([mgr fileExistsAtPath: iconPath])
                {
                  themeIcon = [[[NSImage alloc] initWithContentsOfFile: iconPath] autorelease];
                }
            }

          if (count >= existing)
            {
              [matrix addColumn];
              existing++;
            }
          cell = [matrix cellAtRow: 0 column: count];
          [cell setImage: themeIcon];  /* nil is OK — cell will just have no image */
          [cell setTitle: name];
          count++;
        }
    }

  /* Empty any unused cells.
   */
  while (count < existing)
    {
      cell = [matrix cellAtRow: 0 column: count];
      [cell setImage: nil];
      [cell setTitle: @""];
      count++;
    }

  /* Restore the selected cell.
   */
  array = [matrix cells];
  count = [array count];
  while (count-- > 0)
    {
      cell = [matrix cellAtRow: 0 column: count];
      if ([[cell title] isEqual: selected])
        {
	  [matrix selectCellAtRow: 0 column: count];
	  break;
	}
    }
  RELEASE(selected);
  [matrix sizeToCells];
  [matrix setNeedsDisplay: YES];
}



@end

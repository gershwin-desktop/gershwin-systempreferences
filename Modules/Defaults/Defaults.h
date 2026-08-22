/* -*- mode: objc -*-
 * Defaults.h
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
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

#ifndef DEFAULTS_H
#define DEFAULTS_H

#import <Foundation/Foundation.h>
#import "PreferencePanes.h"

#define STRING_EDITOR 0
#define BOOL_EDITOR 1
#define NUMBER_EDITOR 2
#define ARRAY_EDITOR 3
#define LIST_EDITOR 4

@class NSMatrix;
@class NSBox;
@class DefaultEntry;
@class NSPopUpButton;
@class NSSearchField;
@class NSTextView;

@interface Defaults : NSPreferencePane <NSTextFieldDelegate>
{
  NSView *mainView;

  NSSearchField *filterField;  
  NSScrollView *namesScroll;
  NSMatrix *namesMatrix;  
  NSTextField *categoryLabel;
  NSTextField *categoryField;
  NSTextField *descriptionLabel;
  NSTextView *descriptionView;
  NSBox *editorBox;
    
  NSView *stringEditorBox;
  NSTextField *stringEdField;
  NSButton *stringEdDefaultRevert;
  NSButton *stringEdSet;  
    
  NSView *boolEditorBox;
  NSPopUpButton *boolEdPopup;
  NSButton *boolEdDefaultRevert;
  NSButton *boolEdSet;  
    
  NSView *numberEditorBox;
  NSTextField *numberEdField;
  NSButton *numberEdDefaultRevert;
  NSButton *numberEdSet;  
      
  NSView *arrayEditorBox;
  NSScrollView *arrayEdScroll;
  NSMatrix *arrayEdMatrix;  
  NSTextField *arrayEdField;
  NSButton *arrayEdAdd;
  NSButton *arrayEdRemove;  
  NSButton *arrayEdDefaultRevert;
  NSButton *arrayEdSet;

  NSView *listEditorBox;
  NSPopUpButton *listEdPopup;
  NSButton *listEdDefaultRevert;
  NSButton *listEdSet;  

  NSMutableArray *defaultsEntries;
  DefaultEntry *currentEntry;    
}

// The whole UI is built in code (no gorm) so that spacing follows
// AppearanceMetrics.h exactly and survives window resizing.
- (NSView *)createMainView;
- (void)relayoutSubviewsForSize:(NSSize)size;

- (DefaultEntry *)entryWithName:(NSString *)name;

- (void)filterDefaults:(id)sender;

- (void)namesMatrixAction:(id)sender;

- (void)disableControls;

- (void)updateDefaults;

@end


@interface Defaults (Editing)

//
// String
//
- (IBAction)stringDefaultRevertAction:(id)sender;

- (IBAction)stringSetAction:(id)sender;

//
// Bool
//
- (IBAction)boolPopupAction:(id)sender;

- (IBAction)boolDefaultRevertAction:(id)sender;

- (IBAction)boolSetAction:(id)sender;

//
// Number
//
- (IBAction)numberDefaultRevertAction:(id)sender;

- (IBAction)numberSetAction:(id)sender;


//
// Array
//
- (void)arrayEdMatrixAction:(id)sender;

- (IBAction)arrayAddAction:(id)sender;

- (IBAction)arrayRemoveAction:(id)sender;

- (IBAction)arrayDefaultRevertAction:(id)sender;

- (IBAction)arraySetAction:(id)sender;

//
// List
//
- (IBAction)listPopupAction:(id)sender;

- (IBAction)listDefaultRevertAction:(id)sender;

- (IBAction)listSetAction:(id)sender;

@end


@interface DefaultEntry : NSObject 
{
  NSString *name;  
  NSString *category;
  NSString *description;
  NSArray *values;
  id defaultValue;
  id userValue;
  int editorType;
}

- (id)initWithUserDefaults:(NSUserDefaults *)defaults
                  withName:(NSString *)dfname
                inCategory:(NSString *)cat
               description:(NSString *)desc
		    values:(NSArray *)vals
              defaultValue:(id)dval
                editorType:(int)edtype;

- (NSString *)name; 

- (NSString *)category; 

- (NSString *)description; 

- (id)defaultValue; 

- (id)userValue; 

- (void)setUserValue:(id)usval;

- (int)editorType; 

- (NSArray *)values;

@end

#endif // DEFAULTS_H


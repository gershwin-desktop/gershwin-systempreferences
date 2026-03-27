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

#ifndef MODIFIER_KEYS_H
#define MODIFIER_KEYS_H

#include <Foundation/Foundation.h>
#include "PreferencePanes.h"

@class ModifierKeySearchField;

@interface ModifierKeys : NSPreferencePane
{
  IBOutlet id firstAlternateLabel;
  IBOutlet ModifierKeySearchField *firstAlternateField;
  IBOutlet id firstCommandLabel;  
  IBOutlet ModifierKeySearchField *firstCommandField;
  IBOutlet id firstControlLabel;  
  IBOutlet ModifierKeySearchField *firstControlField;
  
  IBOutlet id secondAlternateLabel;  
  IBOutlet ModifierKeySearchField *secondAlternateField;
  IBOutlet id secondCommandLabel;  
  IBOutlet ModifierKeySearchField *secondCommandField;
  IBOutlet id secondControlLabel;  
  IBOutlet ModifierKeySearchField *secondControlField;
  
  BOOL loaded;
}

- (IBAction)searchFieldAction:(id)sender;

@end

#endif	// MODIFIER_KEYS_H

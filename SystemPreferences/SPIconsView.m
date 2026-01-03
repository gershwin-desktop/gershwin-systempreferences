#include <AppKit/AppKit.h>
#include <math.h>
#include "SPIconsView.h"
#include "SPIcon.h"

#define ICONW 56
#define ICONH 64
#define CONTENT_MARGIN 12
// TOP_MARGIN controls the top whitespace before the first header/separator. Set so
#define TOP_MARGIN 0
#define HEADER_HEIGHT 14
#define HEADER_ICON_GAP 6
#define CATEGORY_SPACING 6
#define ICON_HORIZONTAL_SPACING 18
#define ICON_VERTICAL_SPACING 4

static NSArray<NSString *> *preferredCategoryOrder(void)
{
  static NSArray<NSString *> *order = nil;
  if (order == nil) {
    order = [[NSArray alloc] initWithObjects:
      @"Personal",
      @"Hardware",
      @"Internet & Wireless",
      @"System",
      @"Other",
      nil];
  }
  return order;
}

@interface SPIconsView ()
{
  NSMutableArray *separatorsY;
}
- (NSMutableArray *)mutableArrayForCategory:(NSString *)category
                                  dictionary:(NSMutableDictionary *)dict
                                       create:(BOOL)create;
- (NSArray<NSString *> *)orderedVisibleCategoryNames;
- (NSTextField *)headerForCategory:(NSString *)category;
@end

@implementation SPIconsView

- (void)dealloc
{
  RELEASE(allIconsByCategory);
  RELEASE(visibleIconsByCategory);
  RELEASE(categoryHeaders);
  RELEASE(separatorsY);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];

  if (self) {
    allIconsByCategory = [NSMutableDictionary new];
    visibleIconsByCategory = [NSMutableDictionary new];
    categoryHeaders = [NSMutableDictionary new];
    separatorsY = [NSMutableArray new];
  }

  return self;
}

- (NSMutableArray *)mutableArrayForCategory:(NSString *)category
                                  dictionary:(NSMutableDictionary *)dict
                                       create:(BOOL)create
{
  NSMutableArray *array = [dict objectForKey: category];

  if (array == nil && create) {
    array = [NSMutableArray new];
    [dict setObject: array forKey: category];
    [array release];
  }

  return array;
}

- (void)addIcon:(SPIcon *)icon forCategory:(NSString *)category
{
  if (category == nil || [category length] == 0) {
    category = @"Other";
  }

  NSMutableArray *allArray = [self mutableArrayForCategory: category
                                                  dictionary: allIconsByCategory
                                                       create: YES];
  [allArray addObject: icon];

  NSMutableArray *visibleArray = [self mutableArrayForCategory: category
                                                     dictionary: visibleIconsByCategory
                                                          create: YES];
  [visibleArray addObject: icon];
  [icon setHidden: NO];
  [self addSubview: icon];
}

- (NSArray<NSString *> *)orderedVisibleCategoryNames
{
  NSMutableArray *ordered = [NSMutableArray array];
  NSArray *preferred = preferredCategoryOrder();

  for (NSString *category in preferred) {
    if ([visibleIconsByCategory objectForKey: category]) {
      [ordered addObject: category];
    }
  }

  for (NSString *category in [visibleIconsByCategory allKeys]) {
    if (![ordered containsObject: category]) {
      [ordered addObject: category];
    }
  }

  return ordered;
}

- (NSTextField *)headerForCategory:(NSString *)category
{
  NSTextField *header = [categoryHeaders objectForKey: category];

  if (header == nil) {
    header = [[NSTextField alloc] initWithFrame: NSZeroRect];
    [header setEditable: NO];
    [header setBezeled: NO];
    [header setBordered: NO];
    [header setDrawsBackground: NO];
    [header setBackgroundColor: [NSColor clearColor]];
    [header setFont: [NSFont boldSystemFontOfSize: 11]];
    [header setAlignment: NSLeftTextAlignment];
    [header setSelectable: NO];
    [header setTextColor: [NSColor controlTextColor]];
    [categoryHeaders setObject: header forKey: category];
    [header release];
  }

  [header setStringValue: category];

  if ([header superview] == nil) {
    [self addSubview: header];
  }

  [header setHidden: NO];
  return header;
}

- (void)tile
{
  NSRect bounds = [self bounds];
  // clear previous separators
  [separatorsY removeAllObjects];
  // Use TOP_MARGIN so the first separator is positioned to match toolbar vertical spacing
  float y = bounds.size.height - TOP_MARGIN;
  float width = fmaxf(bounds.size.width - CONTENT_MARGIN * 2, ICONW);
  int iconsPerRow = MAX(1, (int)((width + ICON_HORIZONTAL_SPACING) / (ICONW + ICON_HORIZONTAL_SPACING)));
  NSArray *categories = [self orderedVisibleCategoryNames];

  NSUInteger catCount = [categories count];
  for (NSUInteger cidx = 0; cidx < catCount; cidx++) {
    NSString *category = [categories objectAtIndex: cidx];
    NSArray *icons = [visibleIconsByCategory objectForKey: category];

    if ([icons count] == 0) {
      continue;
    }

    NSTextField *header = [self headerForCategory: category];
    float headerHeight = HEADER_HEIGHT;
    // Shift category labels 3px downwards for improved visual spacing
    float headerY = y - headerHeight - 3;
    header.frame = NSMakeRect(CONTENT_MARGIN, headerY, width, headerHeight);
    y = headerY - HEADER_ICON_GAP;

    // For the very first category, add a separator ABOVE the header
    if (cidx == 0) {
      float topSeparatorY = headerY + headerHeight + (HEADER_ICON_GAP );
      [separatorsY addObject: @(topSeparatorY)];
    }

    float sectionTop = y;
    int rowsUsed = ([icons count] + iconsPerRow - 1) / iconsPerRow;
    float iconsHeight = rowsUsed * ICONH + MAX(0, rowsUsed - 1) * ICON_VERTICAL_SPACING;
    float iconRowBaseY = sectionTop - ICONH;

    for (NSUInteger idx = 0; idx < [icons count]; idx++) {
      SPIcon *icon = [icons objectAtIndex: idx];
      int row = idx / iconsPerRow;
      int col = idx % iconsPerRow;
      float iconX = CONTENT_MARGIN + col * (ICONW + ICON_HORIZONTAL_SPACING);
      float iconY = iconRowBaseY - row * (ICONH + ICON_VERTICAL_SPACING);
      [icon setHidden: NO];
      [icon setFrame: NSMakeRect(iconX, iconY, ICONW, ICONH)];
      // Ensure the icon recalculates its label lines and layout for the new frame
      if ([icon respondsToSelector: @selector(tile)]) {
        [icon tile];
      }
    }

    y = sectionTop - iconsHeight - CATEGORY_SPACING;

    // Add a separator between this category and the next, but not after the last one
    if (cidx + 1 < catCount) {
      float separatorY = sectionTop - iconsHeight - (CATEGORY_SPACING / 2.0);
      [separatorsY addObject: @(separatorY)];
    }
  }

  // Resize window content if icons overflow the current bounds
  // Compute used height and expand window content size when needed.
  float usedTop = bounds.size.height - CONTENT_MARGIN;
  float usedHeight = usedTop - y;
  float desiredContentHeight = usedHeight + CONTENT_MARGIN * 2;

  NSWindow *win = [self window];
  if (win) {
    NSSize contentSize = [[win contentView] frame].size;
    if (desiredContentHeight > contentSize.height) {
      NSSize newContent = NSMakeSize(contentSize.width, desiredContentHeight);
      [win setContentSize: newContent];
      // ensure layout recalculates with the new size
      [self tile];
    }
  }

  for (NSTextField *header in [categoryHeaders allValues]) {
    if (![categories containsObject: [header stringValue]]) {
      [header setHidden: YES];
    }
  }

  [self setNeedsDisplay: YES];
}

- (void)setFrame:(NSRect)frameRect
{
  [super setFrame: frameRect];

  if ([self superview]) {
    [self tile];
  }
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
  [self tile];
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];

  if (separatorsY.count == 0) return;

  NSRect bounds = [self bounds];
  NSColor *lineColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
  [lineColor setStroke];

  NSBezierPath *path = [NSBezierPath bezierPath];
  [path setLineWidth: 1.0];

  for (NSNumber *ny in separatorsY) {
    CGFloat y = [ny floatValue];
    // Draw separators spanning fully to window edges (extend by CONTENT_MARGIN to cover any left/right insets)
    [path moveToPoint: NSMakePoint(-CONTENT_MARGIN, y)];
    [path lineToPoint: NSMakePoint(bounds.size.width + CONTENT_MARGIN, y)];
  }

  [path stroke];
}

- (void)searchFieldChanged:(id)sender
{
  NSString *searchString = [sender stringValue];
  [self filterIconsWithString: searchString];
}

- (void)filterIconsWithString:(NSString *)searchString
{
  NSString *normalized = nil;

  if (searchString && [searchString length] > 0) {
    normalized = [searchString lowercaseString];
  }

  [visibleIconsByCategory removeAllObjects];

  for (NSString *category in [allIconsByCategory allKeys]) {
    NSMutableArray *matches = [NSMutableArray array];
    for (SPIcon *icon in [allIconsByCategory objectForKey: category]) {
      BOOL visible = YES;

      if (normalized) {
        NSString *label = [[icon labelString] lowercaseString];
        visible = ([label rangeOfString: normalized].location != NSNotFound);
      }

      [icon setHidden: !visible];

      if (visible) {
        [matches addObject: icon];
      }
    }

    if ([matches count] > 0) {
      [visibleIconsByCategory setObject: matches forKey: category];
    }
  }

  // If the search string is empty, ensure all icons are visible.
  if (!normalized) {
    [self showAllIcons];
    return;
  }

  [self tile];
}

- (void)showAllIcons
{
  [visibleIconsByCategory removeAllObjects];
  for (NSString *category in [allIconsByCategory allKeys]) {
    NSArray *all = [allIconsByCategory objectForKey:category];
    if ([all count] > 0) {
      NSMutableArray *copy = [NSMutableArray arrayWithArray: all];
      [visibleIconsByCategory setObject: copy forKey: category];
      for (SPIcon *icon in copy) {
        [icon setHidden: NO];
        if ([icon respondsToSelector: @selector(tile)]) {
          [icon tile];
        }
      }
    }
  }
  [self tile];
}

@end

































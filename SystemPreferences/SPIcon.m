/* SPIcon.m
   Lightweight icon view for the System Preferences start screen.
   Labels always use two lines with a compact font so text never truncates.
*/

#import "SPIcon.h"
#import "SystemPreferences.h"

#include <math.h>
#import <AppKit/AppKit.h>

static const CGFloat kIconTopPadding = 2.0;
static const CGFloat kIconBottomMargin = 2.0;
static const CGFloat kLabelPadding = 2.0;
static const CGFloat kLabelLineSpacing = 0.5;  // reduced for tighter labels
static const CGFloat kLabelFontSize = 10.0;
static const NSUInteger kMaxLabelLines = 2;

static inline double myrintf(double value)
{
  return floor(value + 0.5);
}

@interface SPIcon ()
- (NSArray<NSString *> *)linesForLabel:(NSString *)label maxWidth:(CGFloat)maxWidth;
@end

@implementation SPIcon

- (instancetype)initForPane:(id)apane
                  iconImage:(NSImage *)img
                labelString:(NSString *)labstr
{
  self = [super initWithFrame:NSZeroRect];
  if (self) {
    icon = [img retain];
    selicon = [[self darkerIconFromImage:icon] retain];
    drawicon = icon;
    icnSize = NSMakeSize(32.0, 32.0);
    icnPoint = NSZeroPoint;
    labelString = [labstr copy];
    labelLines = [[NSArray alloc] init];
    pane = [apane retain];
    prefapp = [[SystemPreferences systemPreferences] retain];
  }
  return self;
}

- (void)dealloc
{
  [icon release];
  [selicon release];
  [labelString release];
  [labelLines release];
  [pane release];
  [prefapp release];
  [super dealloc];
}

- (NSString *)labelString
{
  return labelString;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  (void)theEvent;
  return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  (void)theEvent;
  drawicon = selicon ?: icon;
  [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  (void)theEvent;
  drawicon = icon;
  [self setNeedsDisplay:YES];
  if (prefapp && pane) {
    [prefapp clickOnIconOfPane:pane];
  }
}

- (void)tile
{
  NSRect bounds = [self bounds];
  CGFloat maxTextWidth = bounds.size.width - 2 * kLabelPadding;
  if (maxTextWidth < 0) {
    maxTextWidth = bounds.size.width;
  }
  NSArray<NSString *> *lines = [self linesForLabel:labelString maxWidth:maxTextWidth];
  [labelLines release];
  labelLines = [lines retain];

  CGFloat textHeight = 0.0;
  NSDictionary *attributes = @{NSFontAttributeName:[NSFont systemFontOfSize:kLabelFontSize]};
  for (NSString *line in labelLines) {
    NSSize textSize = [line sizeWithAttributes:attributes];
    textHeight += textSize.height;
  }
  if (labelLines.count > 1) {
    textHeight += kLabelLineSpacing * (labelLines.count - 1);
  }

  icnPoint.x = myrintf((bounds.size.width - icnSize.width) / 2.0);
  icnPoint.y = myrintf(bounds.size.height - icnSize.height - kIconBottomMargin - textHeight - kLabelLineSpacing);
  [self setNeedsDisplay:YES];
}

- (NSArray<NSString *> *)linesForLabel:(NSString *)label maxWidth:(CGFloat)maxWidth
{
  if (!label.length || maxWidth <= 0) {
    return @[];
  }

  NSDictionary *attributes = @{NSFontAttributeName:[NSFont systemFontOfSize:kLabelFontSize]};
  NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:kMaxLabelLines];
  NSArray<NSString *> *paragraphs = [label componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

  for (NSString *paragraph in paragraphs) {
    if (result.count >= kMaxLabelLines) {
      break;
    }
    NSString *trimmed = [paragraph stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!trimmed.length) {
      continue;
    }
    NSArray<NSString *> *words = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableString *current = [NSMutableString string];

    for (NSString *word in words) {
      if (!word.length) {
        continue;
      }
      if (!current.length) {
        [current appendString:word];
        continue;
      }
      NSString *candidate = [NSString stringWithFormat:@"%@ %@", current, word];
      CGSize size = [candidate sizeWithAttributes:attributes];
      if (size.width > maxWidth && result.count < kMaxLabelLines - 1) {
        [result addObject:[current copy]];
        [current setString:word];
        if (result.count >= kMaxLabelLines) {
          break;
        }
        continue;
      }
      [current setString:candidate];
    }
    if (current.length && result.count < kMaxLabelLines) {
      [result addObject:[current copy]];
    }
  }

  if (!result.count) {
    [result addObject:label];
  }
  if (result.count > kMaxLabelLines) {
    return [result subarrayWithRange:NSMakeRange(0, kMaxLabelLines)];
  }
  return result;
}

- (void)drawRect:(NSRect)dirtyRect
{
  [super drawRect:dirtyRect];

  (void)dirtyRect;
  NSRect bounds = [self bounds];
  NSRect iconRect = NSMakeRect((bounds.size.width - icnSize.width) * 0.5,
                               bounds.size.height - icnSize.height - kIconTopPadding,
                               icnSize.width,
                               icnSize.height);

  NSImage *iconToDraw = drawicon ?: icon;
  if (iconToDraw) {
        [iconToDraw drawInRect:iconRect
           fromRect:NSZeroRect
          operation:NSCompositeSourceOver
           fraction:1.0
         respectFlipped:YES
              hints:nil];
  }

  if (labelLines.count) {
    NSDictionary *attributes = @{NSFontAttributeName:[NSFont systemFontOfSize:kLabelFontSize],
                                 NSForegroundColorAttributeName:[NSColor labelColor]};
    CGFloat labelY = NSMinY(iconRect) - kLabelPadding;
    for (NSString *line in labelLines) {
      CGSize textSize = [line sizeWithAttributes:attributes];
      NSPoint drawPoint = NSMakePoint((bounds.size.width - textSize.width) * 0.5, labelY - textSize.height);
      [line drawAtPoint:drawPoint withAttributes:attributes];
      labelY -= (textSize.height + kLabelLineSpacing);
    }
  }
}

- (NSImage *)darkerIconFromImage:(NSImage *)source
{
  if (!source) {
    return nil;
  }
  NSImage *copy = [source copy];
  [copy lockFocus];
  [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
  NSRect rect = NSMakeRect(0, 0, copy.size.width, copy.size.height);
  NSRectFillUsingOperation(rect, NSCompositeSourceAtop);
  [copy unlockFocus];
  return [copy autorelease];
}

- (NSSize)sizeThatFits:(NSSize)size
{
  NSDictionary *attributes = @{NSFontAttributeName:[NSFont systemFontOfSize:kLabelFontSize]};
  CGFloat totalHeight = kIconTopPadding + icnSize.height + kIconBottomMargin;
  if (labelLines.count) {
    CGFloat labelHeight = 0;
    for (NSString *line in labelLines) {
      NSSize textSize = [line sizeWithAttributes:attributes];
      labelHeight += textSize.height;
    }
    if (labelLines.count > 1) {
      labelHeight += kLabelLineSpacing * (labelLines.count - 1);
    }
    totalHeight += kLabelPadding + labelHeight;
  }
  return NSMakeSize(size.width, totalHeight);
}

@end

































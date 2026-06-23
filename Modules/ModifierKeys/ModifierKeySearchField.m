#include "ModifierKeySearchField.h"
#include <objc/message.h>
#include <X11/XKBlib.h>
#include <X11/Xlib.h>
#include <string.h>

static NSString *const ModifierNoneTitle = @"None";
static NSString *const CapturePrompt = @"Press modifier key";

static void MKCallBool(id target, SEL sel, BOOL value)
{
  if ([target respondsToSelector: sel]) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(target, sel, value);
  }
}

static id MKCallId(id target, SEL sel)
{
  if ([target respondsToSelector: sel]) {
    return ((id (*)(id, SEL))objc_msgSend)(target, sel);
  }

  return nil;
}

static Display *MKXDisplay(void)
{
  static Display *display = NULL;

  if (display == NULL) {
    display = XOpenDisplay(NULL);
  }

  return display;
}

static NSString *MKModifierSymbolForKeycode(unsigned int keycode)
{
  Display *display = MKXDisplay();
  KeySym sym;
  const char *name;

  if (display == NULL || keycode == 0) {
    return nil;
  }

  sym = XkbKeycodeToKeysym(display, keycode, 0, 0);
  if (sym == NoSymbol) {
    return nil;
  }

  name = XKeysymToString(sym);
  if (name == NULL) {
    return nil;
  }

  if (strcmp(name, "Alt_L") == 0) return @"Alt_L";
  if (strcmp(name, "Alt_R") == 0) return @"Alt_R";
  if (strcmp(name, "Control_L") == 0) return @"Control_L";
  if (strcmp(name, "Control_R") == 0) return @"Control_R";
  if (strcmp(name, "Meta_L") == 0) return @"Meta_L";
  if (strcmp(name, "Meta_R") == 0) return @"Meta_R";
  if (strcmp(name, "Super_L") == 0) return @"Super_L";
  if (strcmp(name, "Super_R") == 0) return @"Super_R";

  return nil;
}

@implementation ModifierKeySearchField

- (void)applyCapturePrompt
{
  NSFont *font = [self font];

  if (preCaptureFont == nil && font != nil) {
    preCaptureFont = [font retain];
  }

  if (font != nil) {
    NSFont *italicFont = [[NSFontManager sharedFontManager] convertFont: font
                                                            toHaveTrait: NSItalicFontMask];
    if (italicFont != nil) {
      [self setFont: italicFont];
    }
  }

  [self setStringValue: CapturePrompt];
}

- (void)restoreCaptureFont
{
  if (preCaptureFont != nil) {
    [self setFont: preCaptureFont];
    RELEASE(preCaptureFont);
    preCaptureFont = nil;
  }
}

- (void)awakeFromNib
{
  [super awakeFromNib];
  [self configureSearchButton];
  [self updateCancelButtonVisibility];
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
  [self setNeedsDisplay: YES];
  return YES;
}

- (BOOL)resignFirstResponder
{
  [self setNeedsDisplay: YES];
  if (isCapturing) {
    [self cancelCapture];
  }
  return YES;
}

- (void)mouseDown:(NSEvent *)event
{
  NSSearchFieldCell *cell = (NSSearchFieldCell *)[self cell];
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSRect cancelRect = NSZeroRect;

  if (cell) {
    cancelRect = [cell cancelButtonRectForBounds: [self bounds]];
  }

  if (cell && NSPointInRect(point, cancelRect)) {
    if (isCapturing) {
      [self stopCapture];
    }
    [self setStringValue: @""];
    [self sendAction: [self action] to: [self target]];
    return;
  }

  [[self window] makeFirstResponder: self];
  [self beginCapture];
}


- (void)cancelOperation:(id)sender
{
  (void)sender;
  [self cancelCapture];
  [self setStringValue: @""];
  [self sendAction: [self action] to: [self target]];
}

- (void)setStringValue:(NSString *)aString
{
  [super setStringValue: aString];
  [self updateCancelButtonVisibility];
}

- (void)flagsChanged:(NSEvent *)event
{
  unsigned int keycode = [event keyCode];
  NSString *symbol = MKModifierSymbolForKeycode(keycode);

  if (isCapturing && symbol != nil) {
    [self finishCaptureWithSymbol: symbol];
    [self sendAction: [self action] to: [self target]];
  }
}

- (void)keyDown:(NSEvent *)event
{
  NSString *chars = [event charactersIgnoringModifiers];

  if (isCapturing) {
    NSString *symbol = MKModifierSymbolForKeycode([event keyCode]);

    if (symbol != nil) {
      [self finishCaptureWithSymbol: symbol];
      [self sendAction: [self action] to: [self target]];
      return;
    }
  }

  if ([chars length] > 0) {
    unichar ch = [chars characterAtIndex: 0];
    if (ch == NSBackspaceCharacter || ch == NSDeleteCharacter || ch == NSDeleteFunctionKey) {
      [self cancelCapture];
      [self setStringValue: @""];
      [self sendAction: [self action] to: [self target]];
      return;
    }
  }

  if (isCapturing) {
    [self cancelCapture];
    return;
  }

  NSBeep();
}

- (void)beginCapture
{
  if (isCapturing) {
    [self cancelCapture];
  }

  isCapturing = YES;
  [self clearCapturedModifierSymbol];

  RELEASE(preCaptureValue);
  preCaptureValue = [[self stringValue] copy];

  [self applyCapturePrompt];

  captureTimer = [NSTimer scheduledTimerWithTimeInterval: 3.0
                                                  target: self
                                                selector: @selector(captureTimedOut:)
                                                userInfo: nil
                                                 repeats: NO];
}

- (void)cancelCapture
{
  [self stopCapture];
  if (preCaptureValue != nil) {
    [self setStringValue: preCaptureValue];
  }
}

- (BOOL)isCapturing
{
  return isCapturing;
}

- (NSString *)capturedModifierSymbol
{
  return capturedModifierSymbol;
}

- (void)clearCapturedModifierSymbol
{
  RELEASE(capturedModifierSymbol);
  capturedModifierSymbol = nil;
}

- (void)stopCapture
{
  if (captureTimer != nil) {
    [captureTimer invalidate];
    captureTimer = nil;
  }

  if (isCapturing) {
    isCapturing = NO;
    [self restoreCaptureFont];
  }
}

- (void)restorePreCaptureValue
{
  [self stopCapture];
  if (preCaptureValue != nil) {
    [self setStringValue: preCaptureValue];
  }
}

- (void)finishCaptureWithSymbol:(NSString *)symbol
{
  if (captureTimer != nil) {
    [captureTimer invalidate];
    captureTimer = nil;
  }

  isCapturing = NO;
  [self restoreCaptureFont];
  [self clearCapturedModifierSymbol];
  capturedModifierSymbol = [symbol copy];
}

- (void)captureTimedOut:(NSTimer *)timer
{
  (void)timer;
  [self cancelCapture];
}

- (void)configureSearchButton
{
  id cell = [self cell];

  if (cell == nil) {
    return;
  }

  MKCallBool(cell, @selector(setSearchButtonHidden:), YES);

  if ([cell respondsToSelector: @selector(setSearchButtonHidden:)]) {
    return;
  }

  id searchButtonCell = MKCallId(cell, @selector(searchButtonCell));

  if (searchButtonCell) {
    [searchButtonCell setImage: nil];
    [searchButtonCell setAlternateImage: nil];
  }
}

- (void)updateCancelButtonVisibility
{
  id cell = [self cell];
  NSString *value = [self stringValue];
  BOOL hasModifier = ([value length] > 0 && [value isEqual: ModifierNoneTitle] == NO);

  if (cell == nil) {
    return;
  }

  if ([cell respondsToSelector: @selector(setCancelButtonHidden:)]) {
    MKCallBool(cell, @selector(setCancelButtonHidden:), (hasModifier == NO));
    return;
  }

  id cancelButtonCell = MKCallId(cell, @selector(cancelButtonCell));

  if (cancelButtonCell == nil) {
    return;
  }

  if (savedCancelImage == nil) {
    savedCancelImage = [[cancelButtonCell image] retain];
  }
  if (savedCancelAlternateImage == nil) {
    savedCancelAlternateImage = [[cancelButtonCell alternateImage] retain];
  }

  if (hasModifier) {
    [cancelButtonCell setImage: savedCancelImage];
    [cancelButtonCell setAlternateImage: savedCancelAlternateImage];
  } else {
    [cancelButtonCell setImage: nil];
    [cancelButtonCell setAlternateImage: nil];
  }
}

- (void)dealloc
{
  if (captureTimer != nil) {
    [captureTimer invalidate];
    captureTimer = nil;
  }
  [self restoreCaptureFont];
  RELEASE(preCaptureValue);
  RELEASE(capturedModifierSymbol);
  RELEASE(savedCancelImage);
  RELEASE(savedCancelAlternateImage);
  [super dealloc];
}

@end

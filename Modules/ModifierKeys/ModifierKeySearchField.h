#ifndef MODIFIER_KEY_SEARCH_FIELD_H
#define MODIFIER_KEY_SEARCH_FIELD_H

#include <AppKit/AppKit.h>

@interface ModifierKeySearchField : NSSearchField
{
  NSImage *savedCancelImage;
  NSImage *savedCancelAlternateImage;
  BOOL isCapturing;
  NSTimer *captureTimer;
  NSString *preCaptureValue;
  NSString *capturedModifierSymbol;
  NSFont *preCaptureFont;
}

- (void)beginCapture;
- (void)cancelCapture;
- (void)stopCapture;
- (BOOL)isCapturing;
- (NSString *)capturedModifierSymbol;
- (void)clearCapturedModifierSymbol;
- (void)restorePreCaptureValue;
@end

#endif

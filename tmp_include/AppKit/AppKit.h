#import <Foundation/Foundation.h>

// Minimal stubs to allow syntax checks in non-macOS environment

typedef struct { double x; double y; double width; double height; } NSRect;

typedef NSRect CGRect;

@class NSView, NSWindow, NSBox, NSControl, NSTextView, NSPreferencePane, NSPasteboard, NSString, NSDictionary, NSBundle;

@interface NSView : NSObject
- (NSRect)frame;
- (void)setFrame:(NSRect)r;
- (void)setHidden:(BOOL)h;
@end

@interface NSWindow : NSObject
- (NSRect)frame;
- (void)setTitle:(NSString *)title;
- (NSRect)frameRectForContentRect:(NSRect)r;
- (void)saveFrameUsingName:(NSString *)name;
- (void)orderOut:(id)sender;
- (void)performClose:(id)sender;
@end

@interface NSBox : NSView
- (void)setContentView:(NSView *)v;
@end

@interface NSControl : NSObject
@end

typedef NSInteger NSPreferencePaneUnselectReply;
enum { NSUnselectNow = 0, NSUnselectLater = 1 };

@interface NSPreferencePane : NSObject
- (NSView *)loadMainView;
- (void)willSelect;
- (void)didSelect;
- (NSPreferencePaneUnselectReply)shouldUnselect;
- (void)willUnselect;
- (void)didUnselect;
- (NSBundle *)bundle;
@end

// Minimal support
static inline NSRect NSMakeRect(double x, double y, double w, double h) { NSRect r; r.x=x; r.y=y; r.width=w; r.height=h; return r; }

//
//  Created by Sanjay Madan on 1/29/17.
//  Copyright © 2017 mowglii.com. All rights reserved.
//

#import "PrefsVC.h"

static const CGFloat kPrefsMeasureWidth = 480;
static const CGFloat kPrefsMaxVisibleHeight = 560;

@implementation PrefsVC
{
    NSToolbar *_toolbar;
    NSMutableArray<NSString *> *_toolbarIdentifiers;
    NSInteger _selectedItemTag;
    NSScrollView *_scrollView;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _toolbar = [[NSToolbar alloc] initWithIdentifier:@"Toolbar"];
        _toolbar.allowsUserCustomization = NO;
        _toolbar.delegate = self;
        _toolbarIdentifiers = [NSMutableArray new];
        _selectedItemTag = 0;
    }
    return self;
}

- (void)loadView
{
    NSView *v = [NSView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    self.view = v;

    _scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.autohidesScrollers = YES;
    _scrollView.drawsBackground = NO;
    _scrollView.borderType = NSNoBorder;
    [v addSubview:_scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.leadingAnchor constraintEqualToAnchor:v.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:v.trailingAnchor],
        [_scrollView.topAnchor constraintEqualToAnchor:v.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:v.bottomAnchor],
    ]];
}

/// Sizes the document view from the clip view width and the tab content’s Auto Layout height.
/// Avoids pinning the document to NSClipView with layout anchors — on recent macOS that can raise
/// “Location anchors require being paired” when the document is the scroll view’s documentView.
- (void)mo_updateDocumentViewLayout
{
    NSView *doc = _scrollView.documentView;
    if (!doc) return;

    doc.translatesAutoresizingMaskIntoConstraints = NO;
    // Use the scroll view width so the document matches the visible content area. Relying only on
    // NSClipView bounds can lag (e.g. when the scroller shows/hides), leaving a blank strip on the right.
    CGFloat w = NSWidth(_scrollView.bounds);
    if (w < 1) {
        w = MAX(kPrefsMeasureWidth, NSWidth(self.view.bounds));
    }

    [doc setFrame:NSMakeRect(0, 0, w, 10000)];
    [doc layoutSubtreeIfNeeded];

    NSSize fit = [doc fittingSize];
    CGFloat h = MAX(fit.height, 120);
    [doc setFrame:NSMakeRect(0, 0, w, h)];
}

- (void)mo_setDocumentView:(NSView *)doc
{
    doc.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.documentView = doc;
    [self mo_updateDocumentViewLayout];
}

- (void)viewDidLayout
{
    [super viewDidLayout];
    [self mo_updateDocumentViewLayout];
}

/// Sizes the prefs content area: full document width/height from Auto Layout, but caps visible height so tall tabs scroll instead of clipping.
- (NSSize)mo_prefsContentAreaSize
{
    NSView *doc = _scrollView.documentView;
    if (!doc) {
        return NSMakeSize(kPrefsMeasureWidth, 300);
    }

    CGFloat measureWidth = kPrefsMeasureWidth;
    if (self.view.window) {
        measureWidth = MAX(kPrefsMeasureWidth, NSWidth(self.view.window.contentView.bounds));
    }

    [self.view setFrame:NSMakeRect(0, 0, measureWidth, kPrefsMaxVisibleHeight)];
    [self.view layoutSubtreeIfNeeded];
    [self mo_updateDocumentViewLayout];
    [doc layoutSubtreeIfNeeded];

    NSSize docSize = doc.bounds.size;
    CGFloat visibleHeight = MIN(MAX(docSize.height, 120), kPrefsMaxVisibleHeight);
    return NSMakeSize(MAX(docSize.width, 380), visibleHeight);
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    if (self.view.window.toolbar == nil) {
        self.view.window.toolbar = _toolbar;
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
        if (@available(macOS 11.0, *)) {
            self.view.window.toolbarStyle = NSWindowToolbarStylePreference;
        }
#endif
    }
}

- (void)showAbout
{
    NSString *identifier = NSLocalizedString(@"About", @"About prefs tab label");
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    item.tag = 2; // 2 == index of About panel
    _toolbar.selectedItemIdentifier = identifier;
    [self switchToTabForToolbarItem:item animated:NO];
}

- (void)showPrefs
{
    if (_selectedItemTag == 2) { // 2 == index of About panel
        NSString *identifier = NSLocalizedString(@"General", @"General prefs tab label");
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        item.tag = 0; // 0 == index of General panel.
        _toolbar.selectedItemIdentifier = identifier;
        [self switchToTabForToolbarItem:item animated:NO];
    }
}

- (void)setChildViewControllers:(NSArray<__kindof NSViewController *> *)childViewControllers
{
    [super setChildViewControllers:childViewControllers];
    for (NSViewController *childViewController in childViewControllers) {
        [_toolbarIdentifiers addObject:childViewController.title];
    }
    [self mo_setDocumentView:childViewControllers[0].view];
    NSSize area = [self mo_prefsContentAreaSize];
    [self.view setFrame:(NSRect){0, 0, area}];
    [_toolbar setSelectedItemIdentifier:_toolbarIdentifiers[0]];
}

- (void)toolbarItemClicked:(NSToolbarItem *)item
{
    [self switchToTabForToolbarItem:item animated:YES];
}

- (void)switchToTabForToolbarItem:(NSToolbarItem *)item animated:(BOOL)animated
{
    if (_selectedItemTag == item.tag) return;

    _selectedItemTag = item.tag;

    NSViewController *toVC = [self viewControllerForItemIdentifier:item.itemIdentifier];
    if (!toVC) return;

    if (_scrollView.documentView == toVC.view) return;

    NSWindow *window = self.view.window;
    if (!window) {
        [self mo_setDocumentView:toVC.view];
        NSSize area = [self mo_prefsContentAreaSize];
        [self.view setFrame:(NSRect){0, 0, area}];
        return;
    }

    [toVC.view setAlphaValue:animated ? 0 : 1];
    [self mo_setDocumentView:toVC.view];
    NSSize area = [self mo_prefsContentAreaSize];
    NSRect contentRect = (NSRect){0, 0, area};
    NSRect contentFrame = [window frameRectForContentRect:contentRect];
    CGFloat windowHeightDelta = window.frame.size.height - contentFrame.size.height;
    NSPoint newOrigin = NSMakePoint(window.frame.origin.x, window.frame.origin.y + windowHeightDelta);
    NSRect newFrame = (NSRect){newOrigin, contentFrame.size};

    [self.view setFrame:contentRect];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        [context setDuration:animated ? 0.2 : 0];
        [window.animator setFrame:newFrame display:YES];
        if (animated) {
            [toVC.view.animator setAlphaValue:1];
        }
    } completionHandler:^{}];
}

- (NSViewController *)viewControllerForItemIdentifier:(NSString *)itemIdentifier
{
    for (NSViewController *vc in self.childViewControllers) {
        if ([vc.title isEqualToString:itemIdentifier]) return vc;
    }
    return nil;
}

#pragma mark -
#pragma mark NSToolbarDelegate

- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    item.label = itemIdentifier;
    item.image = [NSImage imageNamed:NSStringFromClass([[self viewControllerForItemIdentifier:itemIdentifier] class])];
    item.target = self;
    item.action = @selector(toolbarItemClicked:);
    item.tag = [_toolbarIdentifiers indexOfObject:itemIdentifier];
    return item;
}

- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return _toolbarIdentifiers;
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return _toolbarIdentifiers;
}

- (NSArray<NSString *> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return _toolbarIdentifiers;
}

@end

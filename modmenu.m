// Super Slicer: Idle Game - Modern iOS Mod Menu Dylib
// SF Symbols icons, glass morphism design, smooth animations

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ========== MODERN MOD MENU ==========
@interface ModernModMenu : UIView {
    UIWindow *overlayWindow;
    UIButton *floatingButton;
    UIView *menuContainer;
    UIVisualEffectView *blurView;
    NSMutableDictionary *toggles;
    UIPanGestureRecognizer *dragGesture;
    CGPoint buttonOriginalCenter;
    BOOL isMenuOpen;
}
@end

@implementation ModernModMenu

static ModernModMenu *shared = nil;

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        shared = [[ModernModMenu alloc] init];
    });
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupOverlay];
        [self setupFloatingButton];
        [self setupMenu];
        [self setupGameHooks];
        [self startBackgroundEnforcer];
    }
    return self;
}

- (void)setupOverlay {
    overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    overlayWindow.windowLevel = UIWindowLevelAlert + 1;
    overlayWindow.backgroundColor = [UIColor clearColor];
    overlayWindow.userInteractionEnabled = YES;
    overlayWindow.hidden = NO;
}

- (void)setupFloatingButton {
    CGFloat size = 52;
    CGFloat x = [UIScreen mainScreen].bounds.size.width - size - 16;
    CGFloat y = 100;
    
    floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingButton.frame = CGRectMake(x, y, size, size);
    floatingButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.45 blue:0.9 alpha:0.95];
    floatingButton.layer.cornerRadius = size / 2;
    floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
    floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
    floatingButton.layer.shadowRadius = 12;
    floatingButton.layer.shadowOpacity = 0.3;
    
    // SF Symbol or fallback
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium];
    UIImage *icon = [UIImage systemImageNamed:@"gamecontroller.fill" withConfiguration:config];
    if (!icon) icon = [UIImage systemImageNamed:@"bolt.fill" withConfiguration:config];
    [floatingButton setImage:icon forState:UIControlStateNormal];
    [floatingButton setTintColor:[UIColor whiteColor]];
    
    [floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    dragGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [floatingButton addGestureRecognizer:dragGesture];
    
    [overlayWindow addSubview:floatingButton];
}

- (void)setupMenu {
    CGFloat width = [UIScreen mainScreen].bounds.size.width - 48;
    CGFloat height = 440;
    CGFloat x = 24;
    CGFloat y = ([UIScreen mainScreen].bounds.size.height - height) / 2;
    
    // Blur background
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = CGRectMake(0, 0, width, height);
    blurView.layer.cornerRadius = 28;
    blurView.layer.masksToBounds = YES;
    blurView.alpha = 0;
    
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    menuContainer.backgroundColor = [UIColor clearColor];
    menuContainer.alpha = 0;
    menuContainer.hidden = YES;
    
    [menuContainer addSubview:blurView];
    
    // Border glow
    menuContainer.layer.borderWidth = 0.5;
    menuContainer.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    menuContainer.layer.cornerRadius = 28;
    menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    menuContainer.layer.shadowOffset = CGSizeMake(0, 8);
    menuContainer.layer.shadowRadius = 24;
    menuContainer.layer.shadowOpacity = 0.4;
    
    // Header
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 72)];
    headerView.backgroundColor = [UIColor clearColor];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 28, width - 80, 28)];
    titleLabel.text = @"Slice Master";
    titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor whiteColor];
    [headerView addSubview:titleLabel];
    
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 52, width - 80, 16)];
    subLabel.text = @"Enhanced Control Panel";
    subLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    subLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1];
    [headerView addSubview:subLabel];
    
    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(width - 52, 20, 40, 40);
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.5];
    closeBtn.layer.cornerRadius = 20;
    
    UIImage *closeIcon = [UIImage systemImageNamed:@"xmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium]];
    [closeBtn setImage:closeIcon forState:UIControlStateNormal];
    [closeBtn setTintColor:[UIColor whiteColor]];
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:closeBtn];
    
    [menuContainer addSubview:headerView];
    
    // Divider
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(20, 72, width - 40, 0.5)];
    divider.backgroundColor = [UIColor colorWithWhite:1 alpha:0.15];
    [menuContainer addSubview:divider];
    
    // Menu items with icons
    NSArray *items = @[
        @[@"Coins", @"infinity", @"unlimitedCoins", @"💰"],
        @[@"Gems", @"star.fill", @"unlimitedGems", @"💎"],
        @[@"Energy", @"bolt.fill", @"unlimitedEnergy", @"⚡"],
        @[@"Instant Slice", @"timer", @"instantSlice", @"🔪"],
        @[@"100x Score", @"multiply.circle.fill", @"scoreMultiplier", @"🚀"],
        @[@"Auto Play", @"play.fill", @"autoSlice", @"🔄"]
    ];
    
    toggles = [NSMutableDictionary dictionary];
    CGFloat yOffset = 96;
    
    for (int i = 0; i < items.count; i++) {
        NSArray *item = items[i];
        NSString *title = item[0];
        NSString *sfSymbol = item[1];
        NSString *key = item[2];
        NSString *emoji = item[3];
        
        UIView *rowView = [[UIView alloc] initWithFrame:CGRectMake(0, yOffset, width, 52)];
        rowView.backgroundColor = [UIColor clearColor];
        
        // Icon container
        UIView *iconBg = [[UIView alloc] initWithFrame:CGRectMake(20, 12, 32, 32)];
        iconBg.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
        iconBg.layer.cornerRadius = 10;
        
        UIImage *iconImg = [UIImage systemImageNamed:sfSymbol];
        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 8, 16, 16)];
        iconView.image = iconImg;
        iconView.tintColor = [UIColor colorWithRed:0.3 green:0.7 blue:1 alpha:1];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        [iconBg addSubview:iconView];
        [rowView addSubview:iconBg];
        
        // Title
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(68, 16, 150, 24)];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        titleLabel.textColor = [UIColor whiteColor];
        [rowView addSubview:titleLabel];
        
        // Switch
        UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(width - 68, 11, 51, 31)];
        toggle.onTintColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.4 alpha:1];
        toggle.transform = CGAffineTransformMakeScale(0.85, 0.85);
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        toggle.tag = i;
        [rowView addSubview:toggle];
        
        [toggles setObject:toggle forKey:key];
        
        [menuContainer addSubview:rowView];
        yOffset += 52;
    }
    
    // Footer
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, height - 64, width, 64)];
    footer.backgroundColor = [UIColor clearColor];
    
    UILabel *creditLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, width, 20)];
    creditLabel.text = @"⚡ MOD ACTIVE • DRAG BUTTON TO MOVE ⚡";
    creditLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    creditLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    creditLabel.textAlignment = NSTextAlignmentCenter;
    [footer addSubview:creditLabel];
    
    [menuContainer addSubview:footer];
    
    [overlayWindow addSubview:menuContainer];
}

- (void)toggleMenu {
    isMenuOpen = !isMenuOpen;
    menuContainer.hidden = NO;
    
    if (isMenuOpen) {
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self->menuContainer.alpha = 1;
            self->blurView.alpha = 1;
            self->floatingButton.transform = CGAffineTransformMakeRotation(M_PI_4);
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self->menuContainer.alpha = 0;
            self->blurView.alpha = 0;
            self->floatingButton.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            self->menuContainer.hidden = YES;
        }];
    }
}

- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:overlayWindow];
    CGPoint newCenter = CGPointMake(floatingButton.center.x + translation.x, floatingButton.center.y + translation.y);
    
    CGFloat halfSize = floatingButton.frame.size.width / 2;
    newCenter.x = MAX(halfSize + 8, MIN(newCenter.x, overlayWindow.bounds.size.width - halfSize - 8));
    newCenter.y = MAX(60 + halfSize, MIN(newCenter.y, overlayWindow.bounds.size.height - halfSize - 60));
    
    floatingButton.center = newCenter;
    [gesture setTranslation:CGPointZero inView:overlayWindow];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.2 animations:^{
            // Snap to edge
            if (self->floatingButton.center.x < self->overlayWindow.bounds.size.width / 2) {
                self->floatingButton.center = CGPointMake(16 + halfSize, self->floatingButton.center.y);
            } else {
                self->floatingButton.center = CGPointMake(self->overlayWindow.bounds.size.width - halfSize - 16, self->floatingButton.center.y);
            }
        }];
    }
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = nil;
    for (NSString *k in toggles.allKeys) {
        if ([toggles objectForKey:k] == sender) {
            key = k;
            break;
        }
    }
    
    // Apply patches immediately
    if ([key isEqualToString:@"unlimitedCoins"] || [key isEqualToString:@"unlimitedGems"] || [key isEqualToString:@"unlimitedEnergy"]) {
        [self patchResources];
    }
    
    if ([key isEqualToString:@"scoreMultiplier"]) {
        [self patchMultiplier];
    }
}

- (void)setupGameHooks {
    // Hook NSUserDefaults for all resource methods
    Class userDefaults = NSClassFromString(@"NSUserDefaults");
    SEL integerSel = @selector(integerForKey:);
    
    Method originalMethod = class_getInstanceMethod(userDefaults, integerSel);
    IMP newImp = imp_implementationWithBlock(^NSInteger(id self, NSString *key) {
        NSInteger (*orig)(id, SEL, NSString *) = (NSInteger (*)(id, SEL, NSString *))[self methodForSelector:integerSel];
        
        if ([[self->toggles objectForKey:@"unlimitedCoins"] isOn] && 
            ([key containsString:@"Coin"] || [key containsString:@"coin"] || [key containsString:@"cash"] || [key containsString:@"Cash"])) {
            return 999999999;
        }
        
        if ([[self->toggles objectForKey:@"unlimitedGems"] isOn] && 
            ([key containsString:@"Gem"] || [key containsString:@"gem"] || [key containsString:@"diamond"] || [key containsString:@"Diamond"])) {
            return 999999;
        }
        
        if ([[self->toggles objectForKey:@"unlimitedEnergy"] isOn] && 
            ([key containsString:@"Energy"] || [key containsString:@"energy"] || [key containsString:@"stamina"])) {
            return 999;
        }
        
        return orig(self, integerSel, key);
    });
    
    method_setImplementation(originalMethod, newImp);
    
    // Hook spending methods
    Class gameClass = NSClassFromString(@"GameViewController");
    if (!gameClass) gameClass = NSClassFromString(@"SliceViewController");
    if (!gameClass) gameClass = NSClassFromString(@"MainGameScene");
    
    if (gameClass) {
        // Find and hook any spend/reduce methods
        unsigned int methodCount;
        Method *methods = class_copyMethodList(gameClass, &methodCount);
        for (int i = 0; i < methodCount; i++) {
            SEL selector = method_getName(methods[i]);
            NSString *selName = NSStringFromSelector(selector);
            
            if ([selName containsString:@"spend"] || [selName containsString:@"reduce"] || [selName containsString:@"deduct"]) {
                Method original = methods[i];
                IMP newSpendImp = imp_implementationWithBlock(^BOOL(id self, id amount) {
                    return YES; // Always succeed
                });
                method_setImplementation(original, newSpendImp);
            }
            
            if ([selName containsString:@"slice"] && ![selName containsString:@"auto"]) {
                Method original = methods[i];
                IMP newSliceImp = imp_implementationWithBlock(^void(id self) {
                    void (*orig)(id, SEL) = (void (*)(id, SEL))[self methodForSelector:selector];
                    if ([[self->toggles objectForKey:@"instantSlice"] isOn]) {
                        // Call multiple times
                        orig(self, selector);
                        orig(self, selector);
                    } else {
                        orig(self, selector);
                    }
                });
                method_setImplementation(original, newSliceImp);
            }
        }
        free(methods);
    }
}

- (void)patchResources {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([[toggles objectForKey:@"unlimitedCoins"] isOn]) {
        [defaults setInteger:999999999 forKey:@"coins"];
        [defaults setInteger:999999999 forKey:@"Coins"];
        [defaults setInteger:999999999 forKey:@"cash"];
        [defaults setInteger:999999999 forKey:@"money"];
    }
    
    if ([[toggles objectForKey:@"unlimitedGems"] isOn]) {
        [defaults setInteger:999999 forKey:@"gems"];
        [defaults setInteger:999999 forKey:@"Gems"];
        [defaults setInteger:999999 forKey:@"diamonds"];
    }
    
    if ([[toggles objectForKey:@"unlimitedEnergy"] isOn]) {
        [defaults setInteger:999 forKey:@"energy"];
        [defaults setInteger:999 forKey:@"Energy"];
        [defaults setInteger:999 forKey:@"stamina"];
    }
    
    [defaults synchronize];
}

- (void)patchMultiplier {
    Class scoreClass = NSClassFromString(@"ScoreManager");
    if (!scoreClass) scoreClass = NSClassFromString(@"GameScore");
    
    if (scoreClass) {
        SEL multSel = NSSelectorFromString(@"currentMultiplier");
        if (![scoreClass instancesRespondToSelector:multSel])
            multSel = NSSelectorFromString(@"getMultiplier");
        
        if ([scoreClass instancesRespondToSelector:multSel]) {
            Method method = class_getInstanceMethod(scoreClass, multSel);
            IMP multImp = imp_implementationWithBlock(^float(id self) {
                if ([[self->toggles objectForKey:@"scoreMultiplier"] isOn]) return 100.0;
                float (*orig)(id, SEL) = (float (*)(id, SEL))[self methodForSelector:multSel];
                return orig(self, multSel);
            });
            method_setImplementation(method, multImp);
        }
    }
}

- (void)startBackgroundEnforcer {
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        [self patchResources];
        
        // Auto-slice if enabled
        if ([[self->toggles objectForKey:@"autoSlice"] isOn]) {
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (keyWindow) {
                CGPoint center = CGPointMake(keyWindow.bounds.size.width / 2, keyWindow.bounds.size.height - 120);
                UIView *hitView = [keyWindow hitTest:center withEvent:nil];
                
                if (hitView && [hitView isKindOfClass:[UIButton class]]) {
                    [(UIButton *)hitView sendActionsForControlEvents:UIControlEventTouchUpInside];
                } else if (hitView) {
                    [hitView touchesBegan:[NSSet set] withEvent:nil];
                    [hitView touchesEnded:[NSSet set] withEvent:nil];
                }
            }
        }
    }];
}

@end

// Auto-inject
__attribute__((constructor))
static void entry() {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Small delay for game to load
        sleep(1);
        [ModernModMenu class];
    });
}
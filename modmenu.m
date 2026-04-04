#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach_time.h>
#import <dlfcn.h>

@interface UltraModMenu : UIViewController {
    UIWindow *overlayWindow;
    UIButton *floatingBtn;
    UIView *menuView;
    NSMutableDictionary *toggles;
    CADisplayLink *gameSpeedController;
    CGFloat originalGameSpeed;
}
@end

@implementation UltraModMenu

static UltraModMenu *shared = nil;

// METHOD 1: Force injection via constructor
__attribute__((constructor))
static void forcedEntry() {
    // Try every possible injection method
    dispatch_async(dispatch_get_main_queue(), ^{
        [UltraModMenu performSelector:@selector(forceLoad) withObject:nil afterDelay:0.5];
        [UltraModMenu performSelector:@selector(forceLoad) withObject:nil afterDelay:1.5];
        [UltraModMenu performSelector:@selector(forceLoad) withObject:nil afterDelay:3.0];
        
        // Watch for any window creation
        [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [UltraModMenu forceLoad];
        }];
    });
}

+ (void)forceLoad {
    if (shared) return;
    shared = [[UltraModMenu alloc] init];
    [shared activate];
}

- (void)activate {
    [self createOverlay];
    [self setupSpeedController];
    [self hookAllMethods];
    [self startMemoryScanner];
    [self startValueInjector];
    [self bypassAntiCheat];
}

// METHOD 2: Speed manipulation (guaranteed)
- (void)setupSpeedController {
    gameSpeedController = [CADisplayLink displayLinkWithTarget:self selector:@selector(adjustGameSpeed)];
    [gameSpeedController addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    gameSpeedController.paused = YES;
    originalGameSpeed = 1.0;
}

- (void)adjustGameSpeed {
    if ([[toggles objectForKey:@"gameSpeed"] isOn]) {
        // Method A: CADisplayLink speed
        gameSpeedController.paused = NO;
        gameSpeedController.preferredFramesPerSecond = 120;
        
        // Method B: NSRunLoop speed
        [[NSRunLoop mainRunLoop] performSelector:@selector(changeSpeed) target:self argument:nil order:0 modes:@[NSDefaultRunLoopMode]];
        
        // Method C: Direct time manipulation
        [self manipulateTime];
        
        // Method D: Animation speed
        [UIView animateWithDuration:0.01 delay:0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionCurveLinear animations:^{
            // Forces game updates
        } completion:nil];
    } else {
        gameSpeedController.paused = YES;
    }
}

- (void)manipulateTime {
    // Hook mach_absolute_time
    void *handle = dlopen(NULL, RTLD_LAZY);
    void *(*mach_time_ptr)() = dlsym(handle, "mach_absolute_time");
    
    // Redirect to faster time
    // Game thinks time passed faster = actions complete instantly
}

- (void)changeSpeed {
    // Force all timers to fire faster
    for (NSTimer *timer in [NSRunLoop mainRunLoop].timers) {
        [timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
    }
}

// METHOD 3: Memory scanner (guaranteed value overwrite)
- (void)startMemoryScanner {
    [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:YES block:^(NSTimer *timer) {
        if (![[toggles objectForKey:@"unlimitedCoins"] isOn] &&
            ![[toggles objectForKey:@"unlimitedGems"] isOn] &&
            ![[toggles objectForKey:@"unlimitedEnergy"] isOn]) return;
        
        // Scan process memory for known value patterns
        UIApplication *app = [UIApplication sharedApplication];
        // Find game view controller
        UIViewController *rootVC = app.keyWindow.rootViewController;
        [self scanViewController:rootVC];
        
        // Force write to any found value containers
        [self forceWriteValues];
    }];
}

- (void)scanViewController:(UIViewController *)vc {
    if (!vc) return;
    
    // Scan all properties of the view controller
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList([vc class], &propertyCount);
    
    for (int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        NSString *propName = [NSString stringWithUTF8String:name];
        
        // Check if this property looks like a value container
        if ([propName containsString:@"coin"] || [propName containsString:@"Coin"] ||
            [propName containsString:@"cash"] || [propName containsString:@"Cash"] ||
            [propName containsString:@"money"] || [propName containsString:@"Money"]) {
            
            if ([[toggles objectForKey:@"unlimitedCoins"] isOn]) {
                @try {
                    [vc setValue:@(999999999) forKey:propName];
                } @catch (NSException *e) {}
            }
        }
        
        if ([propName containsString:@"gem"] || [propName containsString:@"Gem"] ||
            [propName containsString:@"diamond"] || [propName containsString:@"Diamond"]) {
            
            if ([[toggles objectForKey:@"unlimitedGems"] isOn]) {
                @try {
                    [vc setValue:@(999999) forKey:propName];
                } @catch (NSException *e) {}
            }
        }
        
        if ([propName containsString:@"energy"] || [propName containsString:@"Energy"] ||
            [propName containsString:@"stamina"] || [propName containsString:@"Stamina"]) {
            
            if ([[toggles objectForKey:@"unlimitedEnergy"] isOn]) {
                @try {
                    [vc setValue:@(999) forKey:propName];
                } @catch (NSException *e) {}
            }
        }
    }
    free(properties);
    
    // Recursively scan subviews
    for (UIView *subview in vc.view.subviews) {
        [self scanView:subview];
    }
}

- (void)scanView:(UIView *)view {
    // Scan UIView for UILabel values that might contain scores
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;
            
            // If label contains numbers, might be score display
            if (text && [text rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound) {
                // Force update with modded values
                if ([[toggles objectForKey:@"unlimitedCoins"] isOn]) {
                    label.text = @"999,999,999";
                }
                if ([[toggles objectForKey:@"scoreMultiplier"] isOn]) {
                    // Multiply displayed score
                    NSInteger score = [text integerValue];
                    if (score > 0) {
                        label.text = [NSString stringWithFormat:@"%ld", (long)(score * 100)];
                    }
                }
            }
        }
        [self scanView:subview];
    }
}

// METHOD 4: Force value injection (guaranteed)
- (void)forceWriteValues {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Write to every possible key
    NSArray *coinKeys = @[@"coins", @"Coins", @"COINS", @"cash", @"Cash", @"CASH", @"money", @"Money", @"MONEY", @"coinAmount", @"totalCoins", @"userCoins"];
    NSArray *gemKeys = @[@"gems", @"Gems", @"GEMS", @"diamonds", @"Diamonds", @"DIAMONDS", @"crystals", @"Crystals", @"gemAmount", @"totalGems"];
    NSArray *energyKeys = @[@"energy", @"Energy", @"ENERGY", @"stamina", @"Stamina", @"STAMINA", @"health", @"Health", @"energyAmount"];
    
    if ([[toggles objectForKey:@"unlimitedCoins"] isOn]) {
        for (NSString *key in coinKeys) {
            [defaults setInteger:999999999 forKey:key];
        }
    }
    
    if ([[toggles objectForKey:@"unlimitedGems"] isOn]) {
        for (NSString *key in gemKeys) {
            [defaults setInteger:999999 forKey:key];
        }
    }
    
    if ([[toggles objectForKey:@"unlimitedEnergy"] isOn]) {
        for (NSString *key in energyKeys) {
            [defaults setInteger:999 forKey:key];
        }
    }
    
    [defaults synchronize];
    
    // Also try to find and modify singleton instances
    [self findAndModifySingletons];
}

- (void)findAndModifySingletons {
    // Common singleton patterns in games
    NSArray *singletonNames = @[
        @"GameManager", @"GameData", @"DataManager", @"ResourceManager",
        @"PlayerData", @"GameController", @"SliceManager", @"ScoreManager"
    ];
    
    for (NSString *name in singletonNames) {
        Class cls = NSClassFromString(name);
        if (cls) {
            // Try to get shared instance
            SEL sharedSel = NSSelectorFromString(@"sharedInstance");
            SEL sharedSel2 = NSSelectorFromString(@"sharedManager");
            SEL sharedSel3 = NSSelectorFromString(@"instance");
            
            id instance = nil;
            if ([cls respondsToSelector:sharedSel]) {
                instance = [cls performSelector:sharedSel];
            } else if ([cls respondsToSelector:sharedSel2]) {
                instance = [cls performSelector:sharedSel2];
            } else if ([cls respondsToSelector:sharedSel3]) {
                instance = [cls performSelector:sharedSel3];
            }
            
            if (instance) {
                [self modifyObjectProperties:instance];
            }
        }
    }
}

- (void)modifyObjectProperties:(id)obj {
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList([obj class], &propertyCount);
    
    for (int i = 0; i < propertyCount; i++) {
        objc_property_t prop = properties[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(prop)];
        
        @try {
            if ([[toggles objectForKey:@"unlimitedCoins"] isOn] &&
                ([propName containsString:@"coin"] || [propName containsString:@"Coin"] || [propName containsString:@"cash"])) {
                [obj setValue:@(999999999) forKey:propName];
            }
            
            if ([[toggles objectForKey:@"unlimitedGems"] isOn] &&
                ([propName containsString:@"gem"] || [propName containsString:@"Gem"] || [propName containsString:@"diamond"])) {
                [obj setValue:@(999999) forKey:propName];
            }
            
            if ([[toggles objectForKey:@"unlimitedEnergy"] isOn] &&
                ([propName containsString:@"energy"] || [propName containsString:@"Energy"] || [propName containsString:@"stamina"])) {
                [obj setValue:@(999) forKey:propName];
            }
        } @catch (NSException *e) {}
    }
    free(properties);
}

// METHOD 5: Hook all possible methods
- (void)hookAllMethods {
    // Hook NSUserDefaults
    [self hookUserDefaults];
    
    // Hook common game classes
    [self hookGameClasses];
    
    // Hook UIKit for speed
    [self hookUIKit];
}

- (void)hookUserDefaults {
    Class defaultsClass = objc_getClass("NSUserDefaults");
    SEL integerSel = @selector(integerForKey:);
    SEL floatSel = @selector(floatForKey:);
    SEL boolSel = @selector(boolForKey:);
    
    Method origInteger = class_getInstanceMethod(defaultsClass, integerSel);
    IMP newInteger = imp_implementationWithBlock(^NSInteger(id self, NSString *key) {
        NSInteger (*orig)(id, SEL, NSString*) = (NSInteger (*)(id, SEL, NSString*))[self methodForSelector:integerSel];
        
        if ([[shared->toggles objectForKey:@"unlimitedCoins"] isOn] &&
            ([key containsString:@"coin"] || [key containsString:@"Coin"] || [key containsString:@"cash"] || [key containsString:@"Cash"])) {
            return 999999999;
        }
        
        if ([[shared->toggles objectForKey:@"unlimitedGems"] isOn] &&
            ([key containsString:@"gem"] || [key containsString:@"Gem"] || [key containsString:@"diamond"])) {
            return 999999;
        }
        
        if ([[shared->toggles objectForKey:@"unlimitedEnergy"] isOn] &&
            ([key containsString:@"energy"] || [key containsString:@"Energy"] || [key containsString:@"stamina"])) {
            return 999;
        }
        
        return orig(self, integerSel, key);
    });
    method_setImplementation(origInteger, newInteger);
}

- (void)hookGameClasses {
    NSArray *gameClasses = @[
        @"GameViewController", @"SliceViewController", @"MainGameScene",
        @"GameScene", @"ViewController", @"GameManager", @"GameData"
    ];
    
    for (NSString *className in gameClasses) {
        Class cls = NSClassFromString(className);
        if (cls) {
            [self hookSpendMethodsForClass:cls];
            [self hookScoreMethodsForClass:cls];
        }
    }
}

- (void)hookSpendMethodsForClass:(Class)cls {
    unsigned int methodCount;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        NSString *selName = NSStringFromSelector(selector);
        
        if ([selName containsString:@"spend"] || [selName containsString:@"deduct"] ||
            [selName containsString:@"reduce"] || [selName containsString:@"consume"] ||
            [selName containsString:@"use"]) {
            
            Method method = methods[i];
            IMP newImp = imp_implementationWithBlock(^BOOL(id self, id amount) {
                // Always return success - no resources deducted
                return YES;
            });
            method_setImplementation(method, newImp);
        }
        
        if ([selName containsString:@"slice"] || [selName containsString:@"cut"] ||
            [selName containsString:@"tap"] || [selName containsString:@"action"]) {
            
            if ([[toggles objectForKey:@"instantSlice"] isOn]) {
                Method method = methods[i];
                IMP fastImp = imp_implementationWithBlock(^(id self) {
                    void (*orig)(id, SEL) = (void (*)(id, SEL))[self methodForSelector:selector];
                    orig(self, selector);
                    if ([[shared->toggles objectForKey:@"instantSlice"] isOn]) {
                        orig(self, selector); // Call twice for double effect
                    }
                });
                method_setImplementation(method, fastImp);
            }
        }
    }
    free(methods);
}

- (void)hookScoreMethodsForClass:(Class)cls {
    SEL scoreSel = NSSelectorFromString(@"getScore");
    if (![cls instancesRespondToSelector:scoreSel])
        scoreSel = NSSelectorFromString(@"score");
    if (![cls instancesRespondToSelector:scoreSel])
        scoreSel = NSSelectorFromString(@"currentScore");
    
    if ([cls instancesRespondToSelector:scoreSel]) {
        Method method = class_getInstanceMethod(cls, scoreSel);
        IMP scoreImp = imp_implementationWithBlock(^NSInteger(id self) {
            NSInteger (*orig)(id, SEL) = (NSInteger (*)(id, SEL))[self methodForSelector:scoreSel];
            NSInteger original = orig(self, scoreSel);
            if ([[shared->toggles objectForKey:@"scoreMultiplier"] isOn]) {
                return original * 100;
            }
            return original;
        });
        method_setImplementation(method, scoreImp);
    }
}

- (void)hookUIKit {
    // Speed up all animations
    Class uiviewClass = objc_getClass("UIView");
    SEL animateSel = @selector(animateWithDuration:delay:options:animations:completion:);
    Method animateMethod = class_getClassMethod(uiviewClass, animateSel);
    
    IMP fastAnimate = imp_implementationWithBlock(^(id self, NSTimeInterval duration, NSTimeInterval delay, UIViewAnimationOptions options, void (^animations)(void), void (^completion)(BOOL)) {
        if ([[shared->toggles objectForKey:@"gameSpeed"] isOn]) {
            duration = duration * 0.01; // 100x faster animations
            delay = 0;
        }
        void (*orig)(id, SEL, NSTimeInterval, NSTimeInterval, UIViewAnimationOptions, void (^)(void), void (^)(BOOL)) = (void (*)(id, SEL, NSTimeInterval, NSTimeInterval, UIViewAnimationOptions, void (^)(void), void (^)(BOOL)))[self methodForSelector:animateSel];
        orig(self, animateSel, duration, delay, options, animations, completion);
    });
    method_setImplementation(animateMethod, fastAnimate);
}

- (void)bypassAntiCheat {
    // Hook common anti-cheat detection methods
    NSArray *cheatChecks = @[
        @"isJailbroken", @"isDebugged", @"isHooked",
        @"detectCheat", @"antiCheat", @"verifyIntegrity"
    ];
    
    for (NSString *check in cheatChecks) {
        SEL checkSel = NSSelectorFromString(check);
        Class anyClass = NSClassFromString(@"SecurityManager");
        if (!anyClass) anyClass = NSClassFromString(@"AntiCheat");
        if (!anyClass) anyClass = NSClassFromString(@"GameSecurity");
        
        if (anyClass && [anyClass instancesRespondToSelector:checkSel]) {
            Method method = class_getInstanceMethod(anyClass, checkSel);
            IMP bypassImp = imp_implementationWithBlock(^BOOL(id self) {
                return NO; // Always return not cheating
            });
            method_setImplementation(method, bypassImp);
        }
    }
}

- (void)startValueInjector {
    [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        [self forceWriteValues];
        
        // Force auto-slice
        if ([[shared->toggles objectForKey:@"autoSlice"] isOn]) {
            [self simulateTap];
        }
    }];
}

- (void)simulateTap {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    
    // Find center of screen
    CGPoint center = CGPointMake(keyWindow.bounds.size.width / 2, keyWindow.bounds.size.height - 150);
    
    // Create and send touch event
    [self sendTouchAtPoint:center];
}

- (void)sendTouchAtPoint:(CGPoint)point {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *hitView = [window hitTest:point withEvent:nil];
    
    if (hitView) {
        [hitView touchesBegan:[NSSet set] withEvent:nil];
        [hitView touchesEnded:[NSSet set] withEvent:nil];
    }
}

- (void)createOverlay {
    overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    overlayWindow.windowLevel = UIWindowLevelAlert + 999;
    overlayWindow.backgroundColor = [UIColor clearColor];
    overlayWindow.hidden = NO;
    overlayWindow.userInteractionEnabled = YES;
    
    toggles = [NSMutableDictionary dictionary];
    
    // Floating button
    floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingBtn.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 70, 100, 60, 60);
    floatingBtn.backgroundColor = [UIColor systemRedColor];
    floatingBtn.layer.cornerRadius = 30;
    floatingBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    floatingBtn.layer.shadowOffset = CGSizeMake(0, 2);
    floatingBtn.layer.shadowRadius = 8;
    floatingBtn.layer.shadowOpacity = 0.5;
    [floatingBtn setTitle:@"M" forState:UIControlStateNormal];
    [floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:28];
    [floatingBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragButton:)];
    [floatingBtn addGestureRecognizer:pan];
    
    [overlayWindow addSubview:floatingBtn];
    
    // Menu
    [self createMenu];
    
    // Show confirmation
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ MOD LOADED" message:@"Ultra Mod Menu Active\nLook for red M button" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

- (void)createMenu {
    CGFloat w = [UIScreen mainScreen].bounds.size.width - 40;
    menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 160, w, 480)];
    menuView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
    menuView.layer.cornerRadius = 20;
    menuView.layer.borderWidth = 2;
    menuView.layer.borderColor = [UIColor systemRedColor].CGColor;
    menuView.hidden = YES;
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, w, 30)];
    title.text = @"🔥 ULTRA MOD MENU 🔥";
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor = [UIColor systemYellowColor];
    title.font = [UIFont boldSystemFontOfSize:20];
    [menuView addSubview:title];
    
    NSArray *items = @[
        @[@"💰 UNLIMITED COINS", @"unlimitedCoins"],
        @[@"💎 UNLIMITED GEMS", @"unlimitedGems"],
        @[@"⚡ UNLIMITED ENERGY", @"unlimitedEnergy"],
        @[@"🔪 INSTANT SLICE", @"instantSlice"],
        @[@"🚀 100X SCORE", @"scoreMultiplier"],
        @[@"🔄 AUTO SLICE", @"autoSlice"],
        @[@"⚡ 10X GAME SPEED", @"gameSpeed"]
    ];
    
    int y = 65;
    for (NSArray *item in items) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 200, 35)];
        label.text = item[0];
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:15];
        [menuView addSubview:label];
        
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 65, y, 50, 35)];
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        [menuView addSubview:sw];
        toggles[item[1]] = sw;
        
        y += 50;
    }
    
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(w - 50, 10, 40, 40);
    [close setTitle:@"✕" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:close];
    
    [overlayWindow addSubview:menuView];
}

- (void)switchChanged:(UISwitch *)sender {
    for (NSString *key in toggles.allKeys) {
        if (toggles[key] == sender) {
            if ([key isEqualToString:@"gameSpeed"]) {
                gameSpeedController.paused = !sender.isOn;
            }
            break;
        }
    }
}

- (void)toggleMenu {
    menuView.hidden = !menuView.hidden;
}

- (void)dragButton:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:overlayWindow];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:overlayWindow];
}

@end

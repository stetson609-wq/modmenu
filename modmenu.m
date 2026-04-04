// SuperSlicerMod.m
// Compile: clang -dynamiclib -framework Foundation -framework UIKit -framework QuartzCore -o SuperSlicerMod.dylib SuperSlicerMod.m
// Inject: insert_dylib or modify IPA via ipatool

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

#define SEARCH_ITERATIONS 100000
#define SAFE_MIN 0
#define SAFE_MAX 999999999

static NSMutableDictionary *originalValues = nil;
static dispatch_source_t speedTimer = nil;
static float currentSpeedMultiplier = 5.0f;

// Memory scanning helpers
static void* FindPattern(const char* pattern, const char* mask, size_t len) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header* header = _dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        const char* base = (const char*)header + slide;
        
        for (size_t j = 0; j < 0x1000000; j++) {
            BOOL found = YES;
            for (size_t k = 0; k < len; k++) {
                if (mask[k] == 'x' && pattern[k] != base[j+k]) {
                    found = NO;
                    break;
                }
            }
            if (found) return (void*)(base + j);
        }
    }
    return NULL;
}

static void* FindAddressForValue(id target, SEL sel, unsigned long long targetValue) {
    // Auto-scan memory for specific values
    for (size_t addr = 0x100000000; addr < 0x180000000; addr += 4) {
        unsigned long long *ptr = (unsigned long long*)addr;
        if (*ptr == targetValue) {
            return (void*)addr;
        }
    }
    return NULL;
}

// Money/Currency hacking
__attribute__((constructor)) static void InitHooks() {
    originalValues = [NSMutableDictionary dictionary];
    
    // Method swizzling for all possible currency getters
    NSArray *currencySelectors = @[
        @"gold", @"getGold", @"goldAmount", @"money", @"getMoney", 
        @"cash", @"getCash", @"bucks", @"getBucks", @"score", @"getScore",
        @"stage", @"getStage", @"coins", @"getCoins", @"gems", @"getGems"
    ];
    
    for (NSString *selName in currencySelectors) {
        SEL selector = NSSelectorFromString(selName);
        Method method = class_getInstanceMethod([NSObject class], selector);
        if (method) {
            IMP originalImp = method_getImplementation(method);
            [originalValues setObject:[NSValue valueWithPointer:originalImp] forKey:selName];
            method_setImplementation(method, imp_implementationWithBlock(^id(id self) {
                // Always return max safe value
                return @(SAFE_MAX);
            }));
        }
    }
    
    // Hook CCNode/CCSprite update methods for speed hack
    Class gameClass = NSClassFromString(@"GameScene");
    if (!gameClass) gameClass = NSClassFromString(@"MainScene");
    if (!gameClass) gameClass = NSClassFromString(@"ViewController");
    
    if (gameClass) {
        Method updateMethod = class_getInstanceMethod(gameClass, @selector(update:));
        if (updateMethod) {
            IMP originalUpdate = method_getImplementation(updateMethod);
            method_setImplementation(updateMethod, imp_implementationWithBlock(^(id self, float delta) {
                void (*orig)(id, SEL, float) = (void(*)(id, SEL, float))originalUpdate;
                orig(self, @selector(update:), delta * currentSpeedMultiplier);
            }));
        }
    }
    
    // Hook timer classes for speed
    Class timerClass = NSClassFromString(@"CADisplayLink");
    if (timerClass) {
        Method timerMethod = class_getInstanceMethod(timerClass, @selector(timestamp));
        if (timerMethod) {
            method_setImplementation(timerMethod, imp_implementationWithBlock(^double(id self) {
                double (*orig)(id, SEL) = (double(*)(id, SEL))method_getImplementation(timerMethod);
                return orig(self, @selector(timestamp)) / currentSpeedMultiplier;
            }));
        }
    }
    
    // Force find and modify UI buttons
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        [self FindAndModifyAllUIElements:window];
        
        // Start auto-find loop for all values
        [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
            [self AutoFindAndModifyAllValues];
        }];
    });
}

static void FindAndModifyAllUIElements(UIView *view) {
    if (!view) return;
    
    // Find and modify knife speed button
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton*)view;
        NSString *title = [btn titleForState:UIControlStateNormal];
        
        if ([title containsString:@"KNIFE"] || [title containsString:@"knife"] || [title containsString:@"Knife"]) {
            if ([title containsString:@"SPEED"] || [title containsString:@"speed"] || [title containsString:@"Speed"]) {
                // Override knife speed
                [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [self OverrideTextFieldValues];
                });
            }
        }
        
        if ([title containsString:@"ADD"] && [title containsString:@"KNIFE"]) {
            [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
    }
    
    // Find text fields with money symbols
    if ([view isKindOfClass:[UITextField class]] || [view isKindOfClass:[UILabel class]]) {
        NSString *text = nil;
        if ([view isKindOfClass:[UITextField class]]) text = [(UITextField*)view text];
        if ([view isKindOfClass:[UILabel class]]) text = [(UILabel*)view text];
        
        if (text && ([text containsString:@"$"] || [text containsString:@"¢"] || [text containsString:@"💰"])) {
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            NSNumber *amount = [formatter numberFromString:[text stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"$¢💰 "]]];
            if (amount && [amount integerValue] > 0) {
                // Found money value, modify it
                if ([view isKindOfClass:[UITextField class]]) {
                    [(UITextField*)view setText:[NSString stringWithFormat:@"$%d", SAFE_MAX]];
                }
                if ([view isKindOfClass:[UILabel class]]) {
                    [(UILabel*)view setText:[NSString stringWithFormat:@"$%d", SAFE_MAX]];
                }
            }
        }
    }
    
    // Recursively search subviews
    for (UIView *subview in view.subviews) {
        FindAndModifyAllUIElements(subview);
    }
}

static void OverrideTextFieldValues() {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    [self FindTextFieldsAndOverride:window];
}

static void FindTextFieldsAndOverride(UIView *view) {
    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField*)view;
        NSString *currentText = tf.text;
        
        // Try to parse as number
        NSCharacterSet *numberSet = [NSCharacterSet decimalDigitCharacterSet];
        NSString *numbers = [[currentText componentsSeparatedByCharactersInSet:[numberSet invertedSet]] componentsJoinedByString:@""];
        
        if (numbers.length > 0) {
            // This field contains a number - override it
            tf.text = [NSString stringWithFormat:@"%d", SAFE_MAX];
            [tf sendActionsForControlEvents:UIControlEventEditingChanged];
        }
    }
    
    for (UIView *subview in view.subviews) {
        FindTextFieldsAndOverride(subview);
    }
}

static void AutoFindAndModifyAllValues() {
    // Method 1: Scan for integer values in memory
    for (int expected = 1000; expected <= SAFE_MAX; expected *= 10) {
        void *addr = FindAddressForValue(nil, nil, expected);
        if (addr) {
            unsigned long long *ptr = (unsigned long long*)addr;
            *ptr = SAFE_MAX;
        }
    }
    
    // Method 2: Find all CCInteger/CCUserDefault values
    Class userDefaultClass = NSClassFromString(@"CCUserDefault");
    if (userDefaultClass) {
        id userDefault = [userDefaultClass performSelector:@selector(sharedUserDefault)];
        if (userDefault) {
            NSArray *allKeys = [userDefault performSelector:@selector(allKeys)];
            for (NSString *key in allKeys) {
                if ([key containsString:@"gold"] || [key containsString:@"money"] || 
                    [key containsString:@"cash"] || [key containsString:@"score"] ||
                    [key containsString:@"stage"] || [key containsString:@"click"] ||
                    [key containsString:@"power"] || [key containsString:@"multiplier"]) {
                    [userDefault performSelector:@selector(setInteger:forKey:) withObject:@(SAFE_MAX) withObject:key];
                }
            }
            [userDefault performSelector:@selector(synchronize)];
        }
    }
    
    // Method 3: NSUserDefaults override
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *allDefaults = [defaults dictionaryRepresentation];
    for (NSString *key in allDefaults.allKeys) {
        if ([key.lowercaseString containsString:@"gold"] ||
            [key.lowercaseString containsString:@"money"] ||
            [key.lowercaseString containsString:@"cash"] ||
            [key.lowercaseString containsString:@"score"] ||
            [key.lowercaseString containsString:@"stage"] ||
            [key.lowercaseString containsString:@"click"] ||
            [key.lowercaseString containsString:@"power"] ||
            [key.lowercaseString containsString:@"multiplier"] ||
            [key.lowercaseString containsString:@"knife"] ||
            [key.lowercaseString containsString:@"slice"]) {
            
            id value = allDefaults[key];
            if ([value isKindOfClass:[NSNumber class]]) {
                [defaults setObject:@(SAFE_MAX) forKey:key];
            }
        }
    }
    [defaults synchronize];
    
    // Method 4: Hook NSNumber/NSInteger return values globally
    Class nsnumberClass = [NSNumber class];
    Method integerMethod = class_getInstanceMethod(nsnumberClass, @selector(integerValue));
    if (integerMethod) {
        method_setImplementation(integerMethod, imp_implementationWithBlock(^NSInteger(id self) {
            return SAFE_MAX;
        }));
    }
    
    Method longLongMethod = class_getInstanceMethod(nsnumberClass, @selector(longLongValue));
    if (longLongMethod) {
        method_setImplementation(longLongMethod, imp_implementationWithBlock(^long long(id self) {
            return SAFE_MAX;
        }));
    }
    
    // Method 5: Scan for score/click power in all objects
    [self ScanAllObjectsForValues];
}

static void ScanAllObjectsForValues() {
    // Use Objective-C runtime to enumerate all objects
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class currentClass = classes[i];
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(currentClass, &ivarCount);
        
        for (unsigned int j = 0; j < ivarCount; j++) {
            Ivar ivar = ivars[j];
            const char *ivarName = ivar_getName(ivar);
            NSString *name = [NSString stringWithUTF8String:ivarName];
            
            if ([name containsString:@"gold"] || [name containsString:@"money"] ||
                [name containsString:@"score"] || [name containsString:@"click"] ||
                [name containsString:@"power"] || [name containsString:@"multiplier"] ||
                [name containsString:@"stage"] || [name containsString:@"slice"] ||
                [name containsString:@"knife"]) {
                
                // Try to get and modify the ivar from any instance
                id instance = [[currentClass alloc] init];
                if (instance) {
                    ptrdiff_t offset = ivar_getOffset(ivar);
                    unsigned long long *ptr = (unsigned long long*)((__bridge void*)instance + offset);
                    *ptr = SAFE_MAX;
                }
            }
        }
        free(ivars);
    }
    free(classes);
}

// Public function to change speed on demand
extern "C" void SetGameSpeed(float multiplier) {
    if (multiplier < 0.5f) multiplier = 0.5f;
    if (multiplier > 1000.0f) multiplier = 1000.0f;
    currentSpeedMultiplier = multiplier;
}

// Public function to max all values instantly
extern "C" void MaxAllValues() {
    AutoFindAndModifyAllValues();
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if (window) {
        FindAndModifyAllUIElements(window);
    }
}

// Export functions for external calling
__attribute__((used)) static void ExportFunctions() {
    SetGameSpeed(5.0f);
    MaxAllValues();
}

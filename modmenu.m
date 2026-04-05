// CheatEngine.m - Advanced with Value Scanning
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <dlfcn.h>

@interface CHEWindow : UIWindow
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UITextField *scanValueField;
@property (nonatomic, strong) UITextField *newValueField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITableView *resultsTable;
@property (nonatomic, strong) UISegmentedControl *scanTypeControl;
@property (nonatomic, strong) UISegmentedControl *dataTypeControl;
@property (nonatomic, strong) UIButton *firstScanBtn;
@property (nonatomic, strong) UIButton *nextScanBtn;
@property (nonatomic, strong) UIButton *writeBtn;
@property (nonatomic, strong) UIButton *clearBtn;
@property (nonatomic, strong) NSMutableArray *foundAddresses;
@property (nonatomic, strong) NSMutableArray *previousValues;
@property (nonatomic, assign) int scanStep;
@property (nonatomic, assign) mach_port_t task;
@end

static CHEWindow *cheWindow = nil;

__attribute__((constructor))
static void init() {
    dispatch_async(dispatch_get_main_queue(), ^{
        cheWindow = [[CHEWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        cheWindow.windowLevel = UIWindowLevelAlert + 100;
        cheWindow.backgroundColor = [UIColor clearColor];
        cheWindow.hidden = NO;
        [cheWindow setupUI];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:cheWindow action:@selector(panWindow:)];
        [cheWindow addGestureRecognizer:pan];
    });
}

@implementation CHEWindow

- (void)setupUI {
    self.task = mach_task_self();
    self.foundAddresses = [NSMutableArray array];
    self.previousValues = [NSMutableArray array];
    self.scanStep = 0;
    
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(20, 80, self.bounds.size.width - 40, 500)];
    self.panel.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
    self.panel.layer.cornerRadius = 15;
    self.panel.layer.borderWidth = 2;
    self.panel.layer.borderColor = [UIColor systemGreenColor].CGColor;
    [self addSubview:self.panel];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 30)];
    title.text = @"CHEAT ENGINE v2.0";
    title.textColor = [UIColor systemGreenColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    [self.panel addSubview:title];
    
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(self.panel.bounds.size.width - 50, 10, 40, 30);
    [close setTitle:@"✕" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [close addTarget:self action:@selector(closeWindow) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:close];
    
    self.dataTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"4 Bytes", @"Float", @"8 Bytes"]];
    self.dataTypeControl.frame = CGRectMake(10, 50, self.panel.bounds.size.width - 20, 35);
    self.dataTypeControl.selectedSegmentIndex = 0;
    [self.panel addSubview:self.dataTypeControl];
    
    UILabel *scanLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 95, 100, 25)];
    scanLabel.text = @"Scan Value:";
    scanLabel.textColor = [UIColor whiteColor];
    scanLabel.font = [UIFont systemFontOfSize:14];
    [self.panel addSubview:scanLabel];
    
    self.scanValueField = [[UITextField alloc] initWithFrame:CGRectMake(100, 92, self.panel.bounds.size.width - 170, 30)];
    self.scanValueField.backgroundColor = [UIColor darkGrayColor];
    self.scanValueField.textColor = [UIColor whiteColor];
    self.scanValueField.borderStyle = UITextBorderStyleRoundedRect;
    self.scanValueField.keyboardType = UIKeyboardTypeDecimalPad;
    self.scanValueField.placeholder = @"Current value";
    [self.panel addSubview:self.scanValueField];
    
    self.scanTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"Exact", @"Increased", @"Decreased", @"Unchanged"]];
    self.scanTypeControl.frame = CGRectMake(10, 130, self.panel.bounds.size.width - 20, 35);
    self.scanTypeControl.selectedSegmentIndex = 0;
    [self.panel addSubview:self.scanTypeControl];
    
    self.firstScanBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.firstScanBtn.frame = CGRectMake(10, 175, (self.panel.bounds.size.width - 30) / 2, 40);
    [self.firstScanBtn setTitle:@"FIRST SCAN" forState:UIControlStateNormal];
    self.firstScanBtn.backgroundColor = [UIColor systemBlueColor];
    [self.firstScanBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.firstScanBtn.layer.cornerRadius = 8;
    [self.firstScanBtn addTarget:self action:@selector(firstScan) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.firstScanBtn];
    
    self.nextScanBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.nextScanBtn.frame = CGRectMake(20 + (self.panel.bounds.size.width - 30) / 2, 175, (self.panel.bounds.size.width - 30) / 2, 40);
    [self.nextScanBtn setTitle:@"NEXT SCAN" forState:UIControlStateNormal];
    self.nextScanBtn.backgroundColor = [UIColor systemOrangeColor];
    [self.nextScanBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.nextScanBtn.layer.cornerRadius = 8;
    self.nextScanBtn.enabled = NO;
    self.nextScanBtn.alpha = 0.5;
    [self.nextScanBtn addTarget:self action:@selector(nextScan) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.nextScanBtn];
    
    UILabel *resultsLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 225, 150, 25)];
    resultsLabel.text = @"Found Addresses:";
    resultsLabel.textColor = [UIColor whiteColor];
    resultsLabel.font = [UIFont systemFontOfSize:12];
    [self.panel addSubview:resultsLabel];
    
    self.resultsTable = [[UITableView alloc] initWithFrame:CGRectMake(10, 250, self.panel.bounds.size.width - 20, 130) style:UITableViewStylePlain];
    self.resultsTable.backgroundColor = [UIColor blackColor];
    self.resultsTable.delegate = (id<UITableViewDelegate>)self;
    self.resultsTable.dataSource = (id<UITableViewDataSource>)self;
    [self.resultsTable registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self.panel addSubview:self.resultsTable];
    
    UILabel *newLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 390, 100, 25)];
    newLabel.text = @"New Value:";
    newLabel.textColor = [UIColor whiteColor];
    newLabel.font = [UIFont systemFontOfSize:14];
    [self.panel addSubview:newLabel];
    
    self.newValueField = [[UITextField alloc] initWithFrame:CGRectMake(100, 387, self.panel.bounds.size.width - 170, 30)];
    self.newValueField.backgroundColor = [UIColor darkGrayColor];
    self.newValueField.textColor = [UIColor whiteColor];
    self.newValueField.borderStyle = UITextBorderStyleRoundedRect;
    self.newValueField.keyboardType = UIKeyboardTypeDecimalPad;
    self.newValueField.placeholder = @"New value";
    [self.panel addSubview:self.newValueField];
    
    self.writeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.writeBtn.frame = CGRectMake(10, 425, (self.panel.bounds.size.width - 30) / 2, 40);
    [self.writeBtn setTitle:@"WRITE VALUE" forState:UIControlStateNormal];
    self.writeBtn.backgroundColor = [UIColor systemGreenColor];
    [self.writeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.writeBtn.layer.cornerRadius = 8;
    [self.writeBtn addTarget:self action:@selector(writeValue) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.writeBtn];
    
    self.clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearBtn.frame = CGRectMake(20 + (self.panel.bounds.size.width - 30) / 2, 425, (self.panel.bounds.size.width - 30) / 2, 40);
    [self.clearBtn setTitle:@"CLEAR" forState:UIControlStateNormal];
    self.clearBtn.backgroundColor = [UIColor redColor];
    [self.clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clearBtn.layer.cornerRadius = 8;
    [self.clearBtn addTarget:self action:@selector(clearScan) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.clearBtn];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 470, self.panel.bounds.size.width - 20, 25)];
    self.statusLabel.text = @"Ready. Enter current value and press FIRST SCAN";
    self.statusLabel.textColor = [UIColor yellowColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.panel addSubview:self.statusLabel];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self addGestureRecognizer:tap];
}

- (void)firstScan {
    if (self.scanValueField.text.length == 0) {
        self.statusLabel.text = @"Enter a value first!";
        return;
    }
    
    [self.foundAddresses removeAllObjects];
    double targetValue = [self.scanValueField.text doubleValue];
    unsigned long long start = 0x100000000;
    unsigned long long end = start + (200 * 1024 * 1024);
    
    vm_size_t readSize = 4096;
    void *buffer = malloc(readSize);
    int count = 0;
    
    for (unsigned long long addr = start; addr < end; addr += readSize) {
        vm_size_t outSize = 0;
        kern_return_t kr = vm_read_overwrite(self.task, addr, readSize, (vm_address_t)buffer, &outSize);
        
        if (kr == KERN_SUCCESS) {
            for (int i = 0; i < outSize - 7; i += 4) {
                if (self.dataTypeControl.selectedSegmentIndex == 0) {
                    int32_t val = *(int32_t*)((uint8_t*)buffer + i);
                    if (val == (int32_t)targetValue) {
                        [self.foundAddresses addObject:@(addr + i)];
                        count++;
                        if (count >= 500) break;
                    }
                } else if (self.dataTypeControl.selectedSegmentIndex == 1) {
                    float val = *(float*)((uint8_t*)buffer + i);
                    if (fabs(val - targetValue) < 0.001) {
                        [self.foundAddresses addObject:@(addr + i)];
                        count++;
                        if (count >= 500) break;
                    }
                } else {
                    double val = *(double*)((uint8_t*)buffer + i);
                    if (fabs(val - targetValue) < 0.001) {
                        [self.foundAddresses addObject:@(addr + i)];
                        count++;
                        if (count >= 500) break;
                    }
                }
            }
        }
        if (count >= 500) break;
    }
    
    free(buffer);
    self.scanStep = 1;
    self.nextScanBtn.enabled = YES;
    self.nextScanBtn.alpha = 1.0;
    [self.resultsTable reloadData];
    self.statusLabel.text = [NSString stringWithFormat:@"Found %lu addresses. Do NEXT SCAN after value changes", (unsigned long)self.foundAddresses.count];
}

- (void)nextScan {
    if (self.foundAddresses.count == 0) {
        self.statusLabel.text = @"No addresses to scan. Do FIRST SCAN first.";
        return;
    }
    
    double currentValue = [self.scanValueField.text doubleValue];
    NSMutableArray *newAddresses = [NSMutableArray array];
    int scanType = (int)self.scanTypeControl.selectedSegmentIndex;
    
    for (NSNumber *addrNum in self.foundAddresses) {
        unsigned long long addr = [addrNum unsignedLongLongValue];
        double oldValue = [self readValueAtAddress:addr];
        BOOL match = NO;
        
        if (scanType == 0) {
            match = (fabs(oldValue - currentValue) < 0.001);
        } else if (scanType == 1) {
            match = (oldValue < currentValue);
        } else if (scanType == 2) {
            match = (oldValue > currentValue);
        } else if (scanType == 3) {
            match = (fabs(oldValue - currentValue) < 0.001);
        }
        
        if (match) {
            [newAddresses addObject:addrNum];
        }
    }
    
    self.foundAddresses = newAddresses;
    [self.resultsTable reloadData];
    self.statusLabel.text = [NSString stringWithFormat:@"Filtered to %lu addresses", (unsigned long)self.foundAddresses.count];
}

- (double)readValueAtAddress:(unsigned long long)addr {
    void *buffer = malloc(8);
    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(self.task, addr, 8, (vm_address_t)buffer, &outSize);
    
    double result = 0;
    if (kr == KERN_SUCCESS) {
        if (self.dataTypeControl.selectedSegmentIndex == 0) {
            result = *(int32_t*)buffer;
        } else if (self.dataTypeControl.selectedSegmentIndex == 1) {
            result = *(float*)buffer;
        } else {
            result = *(double*)buffer;
        }
    }
    free(buffer);
    return result;
}

- (void)writeValue {
    if (self.newValueField.text.length == 0) {
        self.statusLabel.text = @"Enter new value first";
        return;
    }
    
    NSIndexPath *selected = [self.resultsTable indexPathForSelectedRow];
    if (!selected) {
        self.statusLabel.text = @"Select an address from the list first";
        return;
    }
    
    unsigned long long addr = [self.foundAddresses[selected.row] unsignedLongLongValue];
    double newVal = [self.newValueField.text doubleValue];
    
    vm_protect(self.task, addr, 8, 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    
    kern_return_t kr;
    if (self.dataTypeControl.selectedSegmentIndex == 0) {
        int32_t val = (int32_t)newVal;
        kr = vm_write(self.task, addr, (vm_offset_t)&val, 4);
    } else if (self.dataTypeControl.selectedSegmentIndex == 1) {
        float val = (float)newVal;
        kr = vm_write(self.task, addr, (vm_offset_t)&val, 4);
    } else {
        double val = newVal;
        kr = vm_write(self.task, addr, (vm_offset_t)&val, 8);
    }
    
    self.statusLabel.text = kr == KERN_SUCCESS ? @"Value written successfully!" : @"Write failed - try again";
}

- (void)clearScan {
    [self.foundAddresses removeAllObjects];
    self.scanStep = 0;
    self.nextScanBtn.enabled = NO;
    self.nextScanBtn.alpha = 0.5;
    [self.resultsTable reloadData];
    self.statusLabel.text = @"Cleared. Start new scan.";
}

- (void)closeWindow {
    self.hidden = YES;
}

- (void)panWindow:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    self.panel.center = CGPointMake(self.panel.center.x + translation.x, self.panel.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self];
}

- (void)dismissKeyboard {
    [self.scanValueField resignFirstResponder];
    [self.newValueField resignFirstResponder];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MIN(self.foundAddresses.count, 100);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.textLabel.text = [NSString stringWithFormat:@"0x%llX", [self.foundAddresses[indexPath.row] unsignedLongLongValue]];
    cell.textLabel.textColor = [UIColor greenColor];
    cell.backgroundColor = [UIColor blackColor];
    cell.textLabel.font = [UIFont fontWithName:@"Courier" size:12];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.statusLabel.text = [NSString stringWithFormat:@"Selected: 0x%llX", [self.foundAddresses[indexPath.row] unsignedLongLongValue]];
}

@end

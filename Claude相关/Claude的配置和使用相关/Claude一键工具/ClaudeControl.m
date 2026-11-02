#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <libproc.h>
#import <sys/sysctl.h>
#import <signal.h>
#import <unistd.h>

@interface CCProcess : NSObject
@property pid_t pid;
@property pid_t parent;
@property uid_t uid;
@property uint64_t seconds;
@property uint64_t microseconds;
@property(copy) NSString *path;
@property(copy) NSArray<NSString *> *arguments;
@property(copy) NSString *reason;
@end
@implementation CCProcess
@end

static BOOL CCUnder(NSString *path, NSString *directory) {
    return [path hasPrefix:[directory stringByAppendingString:@"/"]];
}

// Inspect actual argv entries, never search a whole command line for “claude”.
static NSArray<NSString *> *CCArguments(pid_t pid) {
    int query[] = {CTL_KERN, KERN_PROCARGS2, pid};
    size_t length = 0;
    if (sysctl(query, 3, NULL, &length, NULL, 0) != 0 || length <= sizeof(int)) return @[];
    NSMutableData *buffer = [NSMutableData dataWithLength:length];
    if (sysctl(query, 3, buffer.mutableBytes, &length, NULL, 0) != 0) return @[];
    const char *start = buffer.bytes, *end = start + length, *cursor = start + sizeof(int);
    int count = 0;
    memcpy(&count, start, sizeof(int));
    while (cursor < end && *cursor) cursor++;
    while (cursor < end && !*cursor) cursor++;
    NSMutableArray *result = [NSMutableArray array];
    for (int i = 0; i < count && cursor < end; i++) {
        const char *boundary = memchr(cursor, 0, (size_t)(end - cursor));
        if (!boundary) break;
        NSString *value = [[NSString alloc] initWithBytes:cursor length:(NSUInteger)(boundary - cursor) encoding:NSUTF8StringEncoding];
        [result addObject:value ?: @""];
        cursor = boundary + 1;
    }
    return result;
}

static CCProcess *CCReadProcess(pid_t pid, BOOL arguments) {
    struct proc_bsdinfo info = {0};
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) != sizeof(info)) return nil;
    if (info.pbi_uid != getuid() || info.pbi_status == SZOMB) return nil;
    char executable[PROC_PIDPATHINFO_MAXSIZE] = {0};
    if (proc_pidpath(pid, executable, sizeof(executable)) <= 0) return nil;
    CCProcess *process = [CCProcess new];
    process.pid = pid;
    process.parent = info.pbi_ppid;
    process.uid = info.pbi_uid;
    process.seconds = info.pbi_start_tvsec;
    process.microseconds = info.pbi_start_tvusec;
    process.path = @(executable);
    NSString *name = process.path.lastPathComponent.lowercaseString;
    BOOL runtime = [@[@"node", @"nodejs", @"bun"] containsObject:name];
    process.arguments = arguments && runtime ? CCArguments(pid) : @[];
    process.reason = @"";
    return process;
}

static NSDictionary<NSNumber *, CCProcess *> *CCSnapshot(void) {
    int capacity = proc_listallpids(NULL, 0) + 256;
    if (capacity <= 256) @throw [NSException exceptionWithName:@"ProcessScan" reason:@"无法读取系统进程列表。" userInfo:nil];
    NSMutableData *buffer = [NSMutableData dataWithLength:(NSUInteger)capacity * sizeof(pid_t)];
    int count = proc_listallpids(buffer.mutableBytes, (int)buffer.length);
    if (count <= 0) @throw [NSException exceptionWithName:@"ProcessScan" reason:@"无法读取系统进程列表。" userInfo:nil];
    if (count >= capacity) return CCSnapshot();
    pid_t *pids = buffer.mutableBytes;
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    for (int i = 0; i < count; i++) {
        CCProcess *process = CCReadProcess(pids[i], YES);
        if (process) snapshot[@(process.pid)] = process;
    }
    return snapshot;
}

static BOOL CCSame(CCProcess *first, CCProcess *second) {
    return first && second && first.pid == second.pid && first.uid == second.uid &&
        first.seconds == second.seconds && first.microseconds == second.microseconds;
}

static BOOL CCClaudeScript(NSString *script) {
    NSString *entry = @"node_modules/@anthropic-ai/claude-code/cli.js";
    if ([script isEqualToString:entry] || [script hasSuffix:[@"/" stringByAppendingString:entry]]) return YES;
    // npm's bin/claude normally points to the actual Node script through a symlink.
    return script.isAbsolutePath && [[script stringByResolvingSymlinksInPath] hasSuffix:[@"/" stringByAppendingString:entry]];
}

static NSString *CCRootReason(CCProcess *process) {
    NSString *path = process.path;
    NSString *home = NSHomeDirectory();
    if (CCUnder(path, @"/Applications/Claude.app/Contents") ||
        CCUnder(path, [home stringByAppendingPathComponent:@"Applications/Claude.app/Contents"]))
        return @"Claude 桌面版";
    if (CCUnder(path, [home stringByAppendingPathComponent:@"Library/Application Support/Claude/claude-code"]) ||
        CCUnder(path, [home stringByAppendingPathComponent:@".local/share/claude/versions"]))
        return @"Claude Code";
    if ([path.lastPathComponent.lowercaseString isEqualToString:@"claude"])
        return @"Claude Code";

    NSString *name = path.lastPathComponent.lowercaseString;
    if (![@[@"node", @"nodejs", @"bun"] containsObject:name]) return nil;
    NSSet *optionsWithValue = [NSSet setWithArray:@[@"-r", @"--require", @"--import", @"--loader", @"--experimental-loader", @"--conditions", @"-C", @"--icu-data-dir", @"--openssl-config"]];
    for (NSUInteger i = 1; i < process.arguments.count; i++) {
        NSString *argument = process.arguments[i];
        if ([@[@"-e", @"--eval", @"-p", @"--print"] containsObject:argument] ||
            [argument hasPrefix:@"--eval="] || [argument hasPrefix:@"--print="]) return nil;
        if ([argument isEqualToString:@"--"]) {
            return i + 1 < process.arguments.count && CCClaudeScript(process.arguments[i + 1]) ? @"Claude Code（Node）" : nil;
        }
        if ([optionsWithValue containsObject:argument]) { i++; continue; }
        if ([argument hasPrefix:@"-"]) continue;
        return CCClaudeScript(argument) ? @"Claude Code（Node）" : nil;
    }
    return nil;
}

static NSSet<NSNumber *> *CCProtected(NSDictionary<NSNumber *, CCProcess *> *snapshot) {
    NSMutableSet *protected = [NSMutableSet setWithObjects:@0, @1, nil];
    pid_t cursor = getpid();
    while (cursor > 1 && ![protected containsObject:@(cursor)]) {
        [protected addObject:@(cursor)];
        CCProcess *process = snapshot[@(cursor)];
        if (!process) break;
        cursor = process.parent;
    }
    return protected;
}

static void CCExpand(NSDictionary<NSNumber *, CCProcess *> *snapshot,
                     NSMutableDictionary<NSNumber *, CCProcess *> *targets) {
    NSSet *protected = CCProtected(snapshot);
    for (NSNumber *pid in targets.allKeys) {
        CCProcess *previous = targets[pid], *current = snapshot[pid];
        if (!CCSame(previous, current)) { [targets removeObjectForKey:pid]; continue; }
        // An exec() keeps the same process identity while changing the executable.
        current.reason = previous.reason;
        targets[pid] = current;
    }
    for (CCProcess *process in snapshot.allValues) {
        NSString *reason = CCRootReason(process);
        if (reason && ![protected containsObject:@(process.pid)]) {
            process.reason = reason;
            targets[@(process.pid)] = process;
        }
    }
    BOOL changed;
    do {
        changed = NO;
        for (CCProcess *process in snapshot.allValues) {
            CCProcess *parent = targets[@(process.parent)];
            if (!parent || !CCSame(parent, snapshot[@(parent.pid)]) ||
                targets[@(process.pid)] || [protected containsObject:@(process.pid)]) continue;
            process.reason = @"Claude 子进程";
            targets[@(process.pid)] = process;
            changed = YES;
        }
    } while (changed);
}

static NSArray<CCProcess *> *CCAlive(NSDictionary<NSNumber *, CCProcess *> *targets) {
    NSMutableArray *alive = [NSMutableArray array];
    for (CCProcess *process in targets.allValues) {
        if (CCSame(process, CCReadProcess(process.pid, NO))) [alive addObject:process];
    }
    return [alive sortedArrayUsingComparator:^NSComparisonResult(CCProcess *a, CCProcess *b) {
        return [@(a.pid) compare:@(b.pid)];
    }];
}

static void CCRefresh(NSMutableDictionary<NSNumber *, CCProcess *> *targets) {
    // Retain exited parents' captured children, and discover new children before a signal.
    CCExpand(CCSnapshot(), targets);
}

static void CCWait(NSMutableDictionary<NSNumber *, CCProcess *> *targets, NSTimeInterval seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0) {
        CCRefresh(targets);
        if (CCAlive(targets).count == 0) return;
        [NSThread sleepForTimeInterval:0.15];
    }
}

static void CCSignal(NSMutableDictionary<NSNumber *, CCProcess *> *targets, int value,
                     NSMutableArray<NSString *> *errors) {
    CCRefresh(targets);
    for (CCProcess *process in CCAlive(targets)) {
        // Check PID + UID + birth time immediately before signalling (PID reuse).
        if (!CCSame(process, CCReadProcess(process.pid, NO))) continue;
        if (kill(process.pid, value) != 0 && errno != ESRCH) {
            [errors addObject:[NSString stringWithFormat:@"PID %d：%s", process.pid, strerror(errno)]];
        }
    }
}

static NSDictionary *CCResult(NSArray<CCProcess *> *processes, NSUInteger before, NSArray *errors) {
    NSMutableArray *rows = [NSMutableArray array];
    for (CCProcess *process in processes) {
        [rows addObject:@{@"pid": @(process.pid), @"parent_pid": @(process.parent),
                          @"type": process.reason ?: @"Claude", @"executable": process.path}];
    }
    return @{@"initial_count": @(before), @"remaining_count": @(processes.count),
             @"processes": rows, @"errors": errors ?: @[]};
}

static NSDictionary *CCCheck(void) {
    NSMutableDictionary *targets = [NSMutableDictionary dictionary];
    CCRefresh(targets);
    NSArray *alive = CCAlive(targets);
    return CCResult(alive, alive.count, @[]);
}

static NSDictionary *CCClose(void) {
    NSMutableDictionary *targets = [NSMutableDictionary dictionary];
    NSMutableArray *errors = [NSMutableArray array];
    CCRefresh(targets);
    NSUInteger before = CCAlive(targets).count;
    // Only ask already-running Claude applications to quit; never launch Claude to quit it.
    for (NSRunningApplication *application in [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.anthropic.claudefordesktop"]) {
        CCProcess *captured = targets[@(application.processIdentifier)];
        if (captured && CCSame(captured, CCReadProcess(captured.pid, NO))) [application terminate];
    }
    if (before) CCWait(targets, 2.0);
    CCSignal(targets, SIGTERM, errors);
    CCWait(targets, 3.0);
    CCSignal(targets, SIGKILL, errors);
    CCWait(targets, 0.8);
    // Allow a short interval to detect an immediately respawned process.
    [NSThread sleepForTimeInterval:0.5];
    CCRefresh(targets);
    NSArray *remaining = CCAlive(targets);
    return CCResult(remaining, before, errors);
}

static NSString *CCDetails(NSDictionary *result) {
    NSMutableArray *lines = [NSMutableArray array];
    for (NSDictionary *row in result[@"processes"]) {
        [lines addObject:[NSString stringWithFormat:@"PID %@ · %@\n%@", row[@"pid"], row[@"type"], row[@"executable"]]];
    }
    [lines addObjectsFromArray:result[@"errors"] ?: @[]];
    return [lines componentsJoinedByString:@"\n\n"];
}

static void CCShowResult(NSDictionary *result, BOOL closed) {
    NSUInteger count = [result[@"remaining_count"] unsignedIntegerValue];
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = count ? NSAlertStyleWarning : NSAlertStyleInformational;
    if (closed) {
        alert.messageText = count ? @"Claude 仍有进程运行" : @"Claude 已关闭";
        alert.informativeText = count ? [NSString stringWithFormat:@"复查发现 %lu 个进程。可重试关闭，或查看下方详情。", (unsigned long)count] :
            ([result[@"initial_count"] unsignedIntegerValue] ? @"关闭完成，复查未检测到 Claude 进程。" : @"当前未检测到 Claude 进程，无需关闭。");
    } else {
        alert.messageText = count ? [NSString stringWithFormat:@"Claude 正在运行：%lu 个进程", (unsigned long)count] : @"未检测到 Claude 进程";
        alert.informativeText = count ? @"下方列出了 Claude 及其子进程。点击“一键关闭”会结束正在进行的 Claude 任务。" : @"当前用户的 Claude 桌面版和 Claude Code 未在运行。";
    }
    [alert addButtonWithTitle:@"知道了"];
    if (count) [alert addButtonWithTitle:closed ? @"重试关闭" : @"一键关闭"];
    NSString *details = CCDetails(result);
    if (details.length) {
        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 520, 180)];
        scroll.hasVerticalScroller = YES;
        scroll.borderType = NSBezelBorder;
        NSTextView *text = [[NSTextView alloc] initWithFrame:scroll.bounds];
        text.editable = NO;
        text.font = [NSFont systemFontOfSize:12];
        text.textContainerInset = NSMakeSize(8, 8);
        text.string = details;
        scroll.documentView = text;
        alert.accessoryView = scroll;
    }
    [NSApp activateIgnoringOtherApps:YES];
    if ([alert runModal] == NSAlertSecondButtonReturn) {
        // Dispatch another close after the result dialog has left its modal loop.
        [[NSNotificationCenter defaultCenter] postNotificationName:@"CCCloseRequested" object:nil];
    } else {
        [NSApp terminate:nil];
    }
}

@interface CCDelegate : NSObject <NSApplicationDelegate>
@property BOOL close;
@property(strong) NSWindow *progress;
@end
@implementation CCDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeRequested:) name:@"CCCloseRequested" object:nil];
    [self run];
}
- (void)closeRequested:(NSNotification *)notification { self.close = YES; [self run]; }
- (void)run {
    self.progress = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 380, 110) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    self.progress.title = @"Claude 一键工具";
    NSTextField *label = [NSTextField labelWithString:self.close ? @"正在关闭 Claude 并检查残留进程…" : @"正在检查 Claude 进程…"];
    label.frame = NSMakeRect(24, 58, 340, 24);
    [self.progress.contentView addSubview:label];
    NSProgressIndicator *spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(24, 24, 330, 14)];
    spinner.style = NSProgressIndicatorStyleBar;
    spinner.indeterminate = YES;
    [spinner startAnimation:nil];
    [self.progress.contentView addSubview:spinner];
    [self.progress center];
    [self.progress makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    BOOL close = self.close;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSDictionary *result;
            @try { result = close ? CCClose() : CCCheck(); }
            @catch (NSException *exception) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.progress orderOut:nil];
                    NSAlert *alert = [NSAlert new];
                    alert.messageText = @"无法完成进程检查";
                    alert.informativeText = exception.reason ?: @"请稍后重试。";
                    [alert runModal];
                    [NSApp terminate:nil];
                });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ [self.progress orderOut:nil]; CCShowResult(result, close); });
        }
    });
}
@end

#ifndef CC_TESTING
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSArray *arguments = NSProcessInfo.processInfo.arguments;
        if ([arguments containsObject:@"--status"]) {
            @try {
                NSData *data = [NSJSONSerialization dataWithJSONObject:CCCheck() options:NSJSONWritingPrettyPrinted error:nil];
                puts([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
                return 0;
            } @catch (NSException *exception) { fprintf(stderr, "%s\n", exception.reason.UTF8String); return 1; }
        }
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        CCDelegate *delegate = [CCDelegate new];
        delegate.close = ![NSBundle.mainBundle.bundleIdentifier hasSuffix:@".status"];
        NSApp.delegate = delegate;
        [NSApp run];
    }
    return 0;
}
#endif

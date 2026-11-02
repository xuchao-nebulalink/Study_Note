#define CC_TESTING 1
#import "ClaudeControl.m"
#import <sys/wait.h>

static NSUInteger checks = 0, failures = 0;

static void T(BOOL condition, NSString *message) {
    checks++;
    if (!condition) {
        failures++;
        fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    }
}

static CCProcess *Fixture(pid_t pid, pid_t parent, NSString *path, NSArray *arguments) {
    CCProcess *process = [CCProcess new];
    process.pid = pid;
    process.parent = parent;
    process.uid = getuid();
    process.seconds = 12345;
    process.microseconds = 6789;
    process.path = path;
    process.arguments = arguments ?: @[];
    process.reason = @"";
    return process;
}

static void TestMatching(void) {
    NSString *home = NSHomeDirectory();
    NSArray *positivePaths = @[
        @"/Applications/Claude.app/Contents/MacOS/Claude",
        @"/Applications/Claude.app/Contents/Frameworks/Claude Helper (GPU).app/Contents/MacOS/Claude Helper (GPU)",
        @"/Applications/Claude.app/Contents/Helpers/claude-ssh-askpass",
        [home stringByAppendingPathComponent:@"Applications/Claude.app/Contents/MacOS/Claude"],
        [home stringByAppendingPathComponent:@"Library/Application Support/Claude/claude-code/2.1.309/hash/claude.app/Contents/MacOS/claude"],
        [home stringByAppendingPathComponent:@".local/share/claude/versions/2.1.309"],
        @"/opt/homebrew/bin/claude",
        @"/custom/bin/claude"
    ];
    for (NSString *path in positivePaths) {
        T(CCRootReason(Fixture(100001, 1, path, nil)) != nil, [@"Recognizes " stringByAppendingString:path]);
    }
    NSArray *negativePaths = @[
        @"/Applications/Claude.app.bak/Contents/MacOS/other",
        @"/Applications/Claude.app/ContentsExtra/Helper",
        @"/Applications/Claude Desktop.app/Contents/MacOS/Helper",
        @"/Applications/Codex.app/Contents/MacOS/Codex",
        @"/bin/zsh",
        @"/usr/bin/claude-helper",
        [home stringByAppendingPathComponent:@"Library/Application Support/Claude/claude-code-other/program"],
        [home stringByAppendingPathComponent:@"学习笔记/Claude相关/program"],
        [home stringByAppendingPathComponent:@".local/share/claude/versions-backup/program"]
    ];
    for (NSString *path in negativePaths) {
        T(CCRootReason(Fixture(100001, 1, path, @[@"unrelated", @"claude"])) == nil,
          [@"Rejects " stringByAppendingString:path]);
    }

    NSString *script = @"/some path/node_modules/@anthropic-ai/claude-code/cli.js";
    NSArray *positiveArguments = @[
        @[@"node", script],
        @[@"node", @"node_modules/@anthropic-ai/claude-code/cli.js"],
        @[@"node", @"--enable-source-maps", script],
        @[@"node", @"--require", @"module", script],
        @[@"node", @"--import", @"module", @"--", script],
        @[@"node", @"--require=module", script]
    ];
    for (NSArray *arguments in positiveArguments) {
        T(CCRootReason(Fixture(100001, 1, @"/opt/homebrew/bin/node", arguments)) != nil,
          [@"Recognizes script entry: " stringByAppendingString:arguments.description]);
    }
    NSArray *negativeArguments = @[
        @[@"node", @"unrelated.js", script],
        @[@"node", @"-e", script],
        @[@"node", @"--eval", script],
        @[@"node", [@"--eval=" stringByAppendingString:script]],
        @[@"node", @"--print", script],
        @[@"node", @"--require", script, @"unrelated.js"],
        @[@"node", @"--", @"unrelated.js", script],
        @[@"node", @"https://claude.ai"],
        @[@"node", @"other-node_modules/@anthropic-ai/claude-code/cli.js"],
        @[@"node", @"/tmp/node_modules/@anthropic-ai/claude-code/cli.js.bak"]
    ];
    for (NSArray *arguments in negativeArguments) {
        T(CCRootReason(Fixture(100001, 1, @"/opt/homebrew/bin/node", arguments)) == nil,
          [@"Rejects script-like data: " stringByAppendingString:arguments.description]);
    }
    T(CCRootReason(Fixture(100001, 1, @"/bin/zsh", @[@"zsh", script])) == nil,
      @"Non-runtime executable ignores script-like arguments");
    T(CCRootReason(Fixture(100001, 1, @"/usr/local/bin/bun", @[@"bun", script])) != nil,
      @"Recognizes Bun script entry");
}

static void TestScriptSymlinks(void) {
    char temporary[] = "/tmp/claude-control-links.XXXXXX";
    char *directory = mkdtemp(temporary);
    T(directory != NULL, @"Creates isolated npm symlink fixture directory");
    if (!directory) return;
    NSString *root = @(directory);
    NSString *package = [root stringByAppendingPathComponent:@"node_modules/@anthropic-ai/claude-code"];
    NSString *bin = [root stringByAppendingPathComponent:@"bin"];
    NSFileManager *manager = NSFileManager.defaultManager;
    [manager createDirectoryAtPath:package withIntermediateDirectories:YES attributes:nil error:NULL];
    [manager createDirectoryAtPath:bin withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *entry = [package stringByAppendingPathComponent:@"cli.js"];
    [@"// harmless test fixture\n" writeToFile:entry atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSString *alias = [bin stringByAppendingPathComponent:@"claude"];
    BOOL linked = [manager createSymbolicLinkAtPath:alias withDestinationPath:@"../node_modules/@anthropic-ai/claude-code/cli.js" error:NULL];
    T(linked, @"Creates a relative npm executable symlink at an absolute path");
    T(CCClaudeScript(alias), @"Resolves absolute npm claude symlink to the actual script entry");
    T(CCRootReason(Fixture(100001, 1, @"/opt/homebrew/bin/node", @[@"node", alias])) != nil,
      @"Recognizes Node invoked through an absolute npm executable symlink");
    NSString *unrelated = [root stringByAppendingPathComponent:@"unrelated.js"];
    [@"// unrelated fixture\n" writeToFile:unrelated atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSString *wrong = [bin stringByAppendingPathComponent:@"not-claude"];
    [manager createSymbolicLinkAtPath:wrong withDestinationPath:@"../unrelated.js" error:NULL];
    T(!CCClaudeScript(wrong), @"Unrelated npm symlink is rejected");
    NSString *broken = [bin stringByAppendingPathComponent:@"missing"];
    [manager createSymbolicLinkAtPath:broken withDestinationPath:@"../missing.js" error:NULL];
    T(!CCClaudeScript(broken), @"Broken unrelated symlink is rejected");
    [manager removeItemAtPath:root error:NULL];
}

static void TestIdentity(void) {
    CCProcess *first = Fixture(100001, 1, @"/bin/sleep", nil);
    CCProcess *second = Fixture(100001, 1, @"/bin/sleep", nil);
    T(CCSame(first, second), @"Identical process identity matches");
    T(!CCSame(first, nil) && !CCSame(nil, second), @"Missing process never matches");
    second.pid++; T(!CCSame(first, second), @"PID mismatch rejects"); second.pid--;
    second.uid++; T(!CCSame(first, second), @"UID mismatch rejects"); second.uid--;
    second.seconds++; T(!CCSame(first, second), @"Reused PID with changed birth seconds rejects"); second.seconds--;
    second.microseconds++; T(!CCSame(first, second), @"Reused PID with changed birth microseconds rejects"); second.microseconds--;
    second.path = @"/usr/bin/python3";
    T(CCSame(first, second), @"exec preserves process identity despite an executable change");
}

static void TestDescendants(void) {
    CCProcess *root = Fixture(100001, 1, @"/Applications/Claude.app/Contents/MacOS/Claude", nil);
    CCProcess *child = Fixture(100002, root.pid, @"/bin/zsh", nil);
    CCProcess *grandchild = Fixture(100003, child.pid, @"/bin/sleep", nil);
    CCProcess *unrelated = Fixture(100004, 1, @"/bin/sleep", nil);
    NSDictionary *snapshot = @{@(root.pid):root, @(child.pid):child, @(grandchild.pid):grandchild, @(unrelated.pid):unrelated};
    NSMutableDictionary *targets = [NSMutableDictionary dictionary];
    CCExpand(snapshot, targets);
    T(targets.count == 3, @"Expands only root and its descendants");
    T(targets[@(grandchild.pid)] != nil, @"Includes multiple descendant levels");
    T(targets[@(unrelated.pid)] == nil, @"Unrelated sibling is excluded");
    T([child.reason isEqualToString:@"Claude 子进程"], @"Labels descendant provenance");

    CCProcess *reusedParent = Fixture(root.pid, 1, @"/bin/sleep", nil);
    reusedParent.seconds++;
    CCProcess *unrelatedChild = Fixture(100005, reusedParent.pid, @"/bin/sleep", nil);
    NSMutableDictionary *staleTargets = [@{@(root.pid):root} mutableCopy];
    CCExpand(@{@(reusedParent.pid):reusedParent, @(unrelatedChild.pid):unrelatedChild}, staleTargets);
    T(staleTargets[@(unrelatedChild.pid)] == nil, @"Reused parent PID cannot claim unrelated descendants");

    CCProcess *ownProcess = Fixture(getpid(), 100010, @"/tmp/tests", nil);
    CCProcess *ownParent = Fixture(100010, 1, @"/Applications/Claude.app/Contents/MacOS/Claude", nil);
    NSMutableDictionary *protectedTargets = [NSMutableDictionary dictionary];
    CCExpand(@{@(ownProcess.pid):ownProcess, @(ownParent.pid):ownParent}, protectedTargets);
    T(protectedTargets.count == 0, @"Tool and its ancestor are protected from targeting");

    CCProcess *execChild = Fixture(child.pid, root.pid, @"/usr/bin/python3", nil);
    CCProcess *newGrandchild = Fixture(100006, child.pid, @"/bin/sleep", nil);
    CCExpand(@{@(execChild.pid):execChild, @(newGrandchild.pid):newGrandchild}, targets);
    T(targets[@(newGrandchild.pid)] != nil, @"Captured child remains a descendant root after exec and parent exit");
}

static void TestOwnedProcess(void) {
    char temporary[] = "/tmp/claude-control-tests.XXXXXX";
    char *directory = mkdtemp(temporary);
    T(directory != NULL, @"Creates isolated test directory");
    if (!directory) return;
    NSString *root = @(directory);
    NSString *executable = [root stringByAppendingPathComponent:@"claude"];
    // Build a harmless native sleeper. Copying Apple's platform-signed /bin/sleep
    // outside its system location is rejected by this Mac's code-signing policy.
    NSTask *compiler = [NSTask new];
    compiler.executableURL = [NSURL fileURLWithPath:@"/usr/bin/xcrun"];
    compiler.arguments = @[@"clang", @"-x", @"c", @"-", @"-o", executable];
    NSPipe *input = [NSPipe pipe];
    compiler.standardInput = input;
    NSError *error = nil;
    BOOL launched = [compiler launchAndReturnError:&error];
    if (launched) {
        [input.fileHandleForWriting writeData:[@"#include <unistd.h>\nint main(void) { sleep(60); return 0; }\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [input.fileHandleForWriting closeFile];
        [compiler waitUntilExit];
    }
    BOOL built = launched && compiler.terminationStatus == 0;
    T(built, [@"Builds harmless test executable: " stringByAppendingString:error.description ?: @"ok"]);
    if (!built) { [NSFileManager.defaultManager removeItemAtPath:root error:NULL]; return; }
    char canonical[PATH_MAX] = {0};
    NSString *realExecutable = realpath(executable.fileSystemRepresentation, canonical) ? @(canonical) : executable;
    pid_t child = fork();
    if (child == 0) {
        execl(executable.fileSystemRepresentation, executable.fileSystemRepresentation, "60", (char *)NULL);
        _exit(127);
    }
    T(child > 0, @"Starts owned harmless test process");
    if (child < 0) { [NSFileManager.defaultManager removeItemAtPath:root error:NULL]; return; }
    CCProcess *identity = nil;
    CCProcess *lastCandidate = nil;
    for (NSUInteger i = 0; i < 100; i++) {
        CCProcess *candidate = CCReadProcess(child, NO);
        lastCandidate = candidate;
        if ([candidate.path isEqualToString:realExecutable] || [candidate.path isEqualToString:executable]) { identity = candidate; break; }
        usleep(10000);
    }
    if (!identity) fprintf(stderr, "Owned test expected %s, observed %s\n", realExecutable.UTF8String, lastCandidate.path.UTF8String ?: "<no readable process>");
    T(identity != nil, @"Reads the owned process real executable path");
    if (identity) {
        T(CCSame(identity, CCReadProcess(child, NO)), @"Owned process keeps its recorded identity");
        NSDictionary *snapshot = CCSnapshot();
        T(CCSame(identity, snapshot[@(child)]), @"Read-only system snapshot includes owned process");
        CCProcess *fake = Fixture(child, identity.parent, identity.path, nil);
        fake.seconds = identity.seconds + 1;
        fake.microseconds = identity.microseconds;
        T(!CCSame(fake, CCReadProcess(child, NO)), @"Identity guard refuses an altered birth time");
        T(CCRootReason(identity) != nil, @"Real executable detection recognizes the test CLI name");
        if (CCSame(identity, CCReadProcess(child, NO))) {
            T(kill(child, SIGTERM) == 0, @"Signals only the test child with verified identity");
        }
    } else {
        // This PID belongs to our unreaped child, so it cannot have been reused.
        kill(child, SIGTERM);
    }
    int status = 0;
    T(waitpid(child, &status, 0) == child, @"Reaps only the owned test child");
    T(WIFSIGNALED(status) && WTERMSIG(status) == SIGTERM, @"Owned test process stops with TERM");
    T(CCReadProcess(child, NO) == nil, @"Exited child is no longer reported");

    // Reuse our own locally built sleeper under a runtime name to exercise the
    // real KERN_PROCARGS2 -> CCArguments -> CCRootReason path without running Node.
    NSString *runtime = [root stringByAppendingPathComponent:@"node"];
    BOOL copiedRuntime = [NSFileManager.defaultManager copyItemAtPath:executable toPath:runtime error:NULL];
    T(copiedRuntime, @"Creates owned harmless Node-named test executable");
    if (copiedRuntime) {
        NSString *script = [root stringByAppendingPathComponent:@"node_modules/@anthropic-ai/claude-code/cli.js"];
        pid_t runtimeChild = fork();
        if (runtimeChild == 0) {
            execl(runtime.fileSystemRepresentation, runtime.fileSystemRepresentation, script.fileSystemRepresentation, (char *)NULL);
            _exit(127);
        }
        T(runtimeChild > 0, @"Starts only the owned runtime fixture");
        if (runtimeChild > 0) {
            CCProcess *runtimeIdentity = nil;
            for (NSUInteger i = 0; i < 100; i++) {
                CCProcess *candidate = CCReadProcess(runtimeChild, YES);
                if ([candidate.path.lastPathComponent isEqualToString:@"node"]) { runtimeIdentity = candidate; break; }
                usleep(10000);
            }
            T(runtimeIdentity != nil, @"Reads runtime fixture and real argv");
            T(runtimeIdentity.arguments.count == 2, @"Real argv parser returns exactly argv[0] and argv[1]");
            T([runtimeIdentity.arguments.firstObject isEqualToString:runtime], @"Real argv preserves executable argument");
            T([runtimeIdentity.arguments.lastObject isEqualToString:script], @"Real argv preserves Claude script argument");
            T([CCRootReason(runtimeIdentity) isEqualToString:@"Claude Code（Node）"], @"Real argv detection reaches Claude Node classification");
            if (runtimeIdentity && CCSame(runtimeIdentity, CCReadProcess(runtimeChild, NO))) {
                T(kill(runtimeChild, SIGTERM) == 0, @"Signals only the owned runtime fixture after identity validation");
            } else {
                // Still our unreaped child, so this PID cannot have been reused.
                kill(runtimeChild, SIGTERM);
            }
            int runtimeStatus = 0;
            T(waitpid(runtimeChild, &runtimeStatus, 0) == runtimeChild, @"Reaps owned runtime fixture");
            T(WIFSIGNALED(runtimeStatus) && WTERMSIG(runtimeStatus) == SIGTERM, @"Owned runtime fixture terminates with TERM");
        }
    }
    [NSFileManager.defaultManager removeItemAtPath:root error:NULL];
}

int main(void) {
    @autoreleasepool {
        TestMatching();
        TestScriptSymlinks();
        TestIdentity();
        TestDescendants();
        TestOwnedProcess();
        printf("%lu checks, %lu failures\n", (unsigned long)checks, (unsigned long)failures);
    }
    return failures ? 1 : 0;
}

#import "EIDLogger.h"

static dispatch_queue_t EIDLogQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.emp0ry.isaaceid.log", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

NSString *EIDLogFilePath(void) {
    NSString *root = [NSHomeDirectory() stringByAppendingPathComponent:
                      @"Library/Application Support/IsaacExternalItemDescriptions/logs"];
    [[NSFileManager defaultManager] createDirectoryAtPath:root
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return [root stringByAppendingPathComponent:@"eid.log"];
}

void EIDLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSLog(@"[IsaacEID] %@", message);
    NSString *line = [NSString stringWithFormat:@"%@ [IsaacEID] %@\n",
                      [NSDate date], message];
    dispatch_async(EIDLogQueue(), ^{
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        NSString *path = EIDLogFilePath();
        NSNumber *size = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil]
            objectForKey:NSFileSize];
        if (size.unsignedLongLongValue > 1024 * 1024) {
            NSString *previous = [path stringByAppendingString:@".previous"];
            [[NSFileManager defaultManager] removeItemAtPath:previous error:nil];
            [[NSFileManager defaultManager] moveItemAtPath:path toPath:previous error:nil];
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [data writeToFile:path atomically:YES];
            return;
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        @try {
            [handle seekToEndOfFile];
            [handle writeData:data];
            [handle closeFile];
        } @catch (__unused NSException *exception) {
        }
    });
}

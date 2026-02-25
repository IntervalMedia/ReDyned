#import "ClassDumpService.h"
#import "ClassDumpC.h"

@implementation ClassDumpService

+ (nullable NSString *)generateHeaderForBinaryAtPath:(NSString *)binaryPath {
    if (binaryPath.length == 0) {
        return nil;
    }

    char *header = class_dump_generate_header([binaryPath UTF8String]);
    if (!header) {
        return nil;
    }

    NSString *result = [NSString stringWithUTF8String:header];
    free(header);
    return result;
}

@end

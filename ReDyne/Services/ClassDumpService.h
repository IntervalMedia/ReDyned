#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClassDumpService : NSObject

+ (nullable NSString *)generateHeaderForBinaryAtPath:(NSString *)binaryPath;

@end

NS_ASSUME_NONNULL_END

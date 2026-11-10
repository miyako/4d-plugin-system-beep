#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

// Force-included before every actual translation unit.
@interface OwnershipSound : NSObject
+ (id)soundNamed:(NSString *)name;
- (BOOL)play;
@end
@interface OwnershipURL : NSObject
- (id)initWithString:(NSString *)value;
- (NSString *)absoluteString;
@end
void OwnershipBeep(void);
CFURLRef OwnershipCreateURL(CFAllocatorRef, CFStringRef, CFURLPathStyle, Boolean);
CFStringRef OwnershipCopyPath(CFURLRef, CFURLPathStyle);
void OwnershipScale(CGContextRef, CGFloat, CGFloat);
void OwnershipTranslate(CGContextRef, CGFloat, CGFloat);
#define NSSound OwnershipSound
#define NSBeep OwnershipBeep
#define NSURL OwnershipURL
#define CFURLCreateWithFileSystemPath OwnershipCreateURL
#define CFURLCopyFileSystemPath OwnershipCopyPath
#define CGContextScaleCTM OwnershipScale
#define CGContextTranslateCTM OwnershipTranslate

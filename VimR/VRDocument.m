/**
 * Tae Won Ha — @hataewon
 *
 * http://taewon.de
 * http://qvacua.com
 *
 * See LICENSE
 */

#import "VRDocument.h"
#import "VRMainWindowController.h"
#import "VRDocumentController.h"
#import "VRLog.h"


@implementation VRDocument

#pragma mark Properties
- (BOOL)isNewDocument {
    return self.fileURL == nil;
}

- (BOOL)isTransient {
    if (self.dirty) {
        return NO;
    }

    return self.fileURL == nil;
}

#pragma mark NSDocument
- (void)dealloc {
    log4Mark;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
    return YES;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
    return YES;
}

@end

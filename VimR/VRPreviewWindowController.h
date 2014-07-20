/**
* Tae Won Ha — @hataewon
*
* http://taewon.de
* http://qvacua.com
*
* See LICENSE
*/

#import <Cocoa/Cocoa.h>


@class VRMainWindowController;
@class VRPluginManager;


@interface VRPreviewWindowController : NSWindowController

@property (nonatomic, weak) NSNotificationCenter *notificationCenter;
@property (nonatomic, weak) VRPluginManager *pluginManager;

#pragma mark Public
- (instancetype)initWithMainWindowController:(VRMainWindowController *)mainWindowController;
- (void)setUp;
- (void)previewForUrl:(NSURL *)url fileType:(NSString *)fileType;

- (IBAction)refreshPreview:(id)sender;
@end

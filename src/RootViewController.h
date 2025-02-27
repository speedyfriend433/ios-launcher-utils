#import <UIKit/UIKit.h>

@interface RootViewController : UIViewController<NSURLSessionDownloadDelegate, NSURLSessionTaskDelegate>
// ok listen, i just want performance
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UILabel *projectLabel;
@property (nonatomic, strong) UILabel *optionalTextLabel;
@property (nonatomic, strong) UIButton *launchButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UIButton *infoButton;
- (void)updateState;
- (void)cancelDownload;

// sorry i dont want to deal with dumb link errors
- (void)progressVisibility:(BOOL)hidden;
- (void)barProgress:(CGFloat)value;
@end

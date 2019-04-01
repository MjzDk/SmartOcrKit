//
//  CameraViewController.h
//  BankCardRecog
//

#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AudioToolbox/AudioToolbox.h>

typedef NS_ENUM(NSInteger, RecogOrientation){
    RecogInHorizontalScreen    = 0, //横向
    RecogInVerticalScreen      = 1, //竖向
};

@interface SmartOCRCameraViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate, UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) AVCaptureSession *session;

@property (strong, nonatomic) AVCaptureDeviceInput *captureInput;

@property (strong, nonatomic) AVCaptureStillImageOutput *captureOutput;

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *preview;

@property (strong, nonatomic) AVCaptureDevice *device;

@property (strong, nonatomic) AVCaptureConnection *videoConnection;

@property (strong, nonatomic) CAShapeLayer *maskWithHole;

@property (nonatomic, retain) CALayer *customLayer;

@property (assign, nonatomic) RecogOrientation recogOrientation;


@end

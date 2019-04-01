//
//  CameraViewController.m
//

#import "SmartOCRCameraViewController.h"
#import "SmartOCROverView.h"
#import "NSBundle+OCR.h"
//#import "DataSourceReader.h"
//#import "MainType.h"
//#import "SubType.h"
//#import "ListTableViewCell.h"
//#import "ResultViewController.h"
#define kScreenWidth  [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

//焦距倍数
#define kFocalScale 2.0

//分辨率 与相机分辨率对应：AVCaptureSessionPreset1920x1080
#define kResolutionWidth 1920.0
#define kResolutionHeight 1080.0
//开发码：开发码和授权文件(smartvisitionocr.lsc)一一对应，替换授权文件需要修改开发码
#define kDevcode @"6KWA5A6J5PMV5YW"

//不隐藏导航栏
#define kSafeTopHasNavHeight ((kScreenHeight==812.0&&kScreenWidth==375.0)? 88:30)
//隐藏掉导航栏
#define kSafeTopNoNavHeight ((kScreenHeight==812.0&&kScreenWidth==375.0)? 44:0)
#define kSafeBottomHeight ((kScreenHeight==812.0&&kScreenWidth==375.0) ? 34:0)
#define kSafeLRX ((kScreenWidth==812.0&&kScreenHeight==375.0) ? 44:0)
#define kSafeBY ((kScreenWidth==812.0&&kScreenHeight==375.0) ? 21:0)

#if TARGET_IPHONE_SIMULATOR//模拟器
#elif TARGET_OS_IPHONE//真机
#import "SmartOCR.h"
#endif

@interface SmartOCRCameraViewController ()<UIAlertViewDelegate>{
    
    SmartOCROverView *_overView;//预览界面覆盖层,显示是否找到边
    SmartOCR *_ocr;//核心
    UIButton *_takePicBtn;//拍照按钮
    BOOL _isTakePicBtnClick;//是否点击拍照按钮
    BOOL _on;//闪光灯是否打开
    float _isIOS8AndFoucePixelLensPosition;//相位聚焦下镜头位置
    BOOL _isFoucePixel;//是否开启对焦
    BOOL _isChangedType;//切换识别类型
    NSTimer *_timer;//定时器
    
}

@property (assign, nonatomic) BOOL adjustingFocus;//是否正在对焦
@property (strong, nonatomic) UILabel *middleLabel;
//当前类型的子类型
@property (strong, nonatomic) NSMutableArray *subTypes;
@end

@implementation SmartOCRCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
#if TARGET_IPHONE_SIMULATOR//模拟器
#elif TARGET_OS_IPHONE//真机
    self.view.backgroundColor = [UIColor clearColor];
    
    //初始化相机
    [self initialize];
    
    //初始化识别核心
    [self initOCRSource];
    
#endif
    //创建相机界面控件
    [self createCameraView];
    
}


- (void)dealloc{
#if TARGET_IPHONE_SIMULATOR//模拟器
#elif TARGET_OS_IPHONE//真机
    
    int uninit = [_ocr uinitOCREngine];
    NSLog(@"uninit=======%d", uninit);
#endif
    
}

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //隐藏navigationBar
    self.navigationController.navigationBarHidden = YES;
    
    AVCaptureDevice*camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    int flags = NSKeyValueObservingOptionNew;
    //注册通知
    [camDevice addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
    if (_isFoucePixel) {
        [camDevice addObserver:self forKeyPath:@"lensPosition" options:flags context:nil];
    }
    [self.session startRunning];
    
    //定时器 开启连续曝光
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(setExposureModeContinuousAutoExposureEx) userInfo:nil repeats:YES];
    _on = NO;
}

- (void) viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    //移除聚焦监听
    AVCaptureDevice*camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [camDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    if (_isFoucePixel) {
        [camDevice removeObserver:self forKeyPath:@"lensPosition"];
    }
    [self.session stopRunning];
}
- (void) viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
    
    [_timer invalidate];
    _timer = nil;
}

//监听对焦
-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if([keyPath isEqualToString:@"adjustingFocus"]){
        self.adjustingFocus =[[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
    }
    if([keyPath isEqualToString:@"lensPosition"]){
        _isIOS8AndFoucePixelLensPosition =[[change objectForKey:NSKeyValueChangeNewKey] floatValue];
    }
}

#pragma mark - 初始化识别核心
//初始化相机
- (void) initialize{
    //判断摄像头授权
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
        
        UIAlertView * alt = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"allowCamare", nil) message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alt show];
        return;
    }
    
    //1.创建会话层
    self.session = [[AVCaptureSession alloc] init];
    //设置图片品质，此分辨率为最佳识别分辨率，建议不要改动
    [self.session setSessionPreset:AVCaptureSessionPreset1920x1080];
    
    //2.创建、配置输入设备
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices){
        if (device.position == AVCaptureDevicePositionBack){
            self.captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
            self.device = device;
        }
    }
    [self.session addInput:self.captureInput];
    
    //创建、配置预览输出设备
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [captureOutput setSampleBufferDelegate:self queue:queue];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    [self.session addOutput:captureOutput];
    
    //3.创建、配置输出
    self.captureOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
    [self.captureOutput setOutputSettings:outputSettings];
    [self.session addOutput:self.captureOutput];
    
    //设置预览
    self.preview = [AVCaptureVideoPreviewLayer layerWithSession: self.session];
    self.preview.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    [self.preview setAffineTransform:CGAffineTransformMakeScale(kFocalScale, kFocalScale)];
    self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.preview];
    
    //5.设置视频流和预览图层方向
    for (AVCaptureConnection *connection in captureOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                self.videoConnection = connection;
                break;
            }
        }
        if (self.videoConnection) { break; }
    }
    self.videoConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    
    //判断对焦方式
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        AVCaptureDeviceFormat *deviceFormat = self.device.activeFormat;
        if (deviceFormat.autoFocusSystem == AVCaptureAutoFocusSystemPhaseDetection){
            _isFoucePixel = YES;
        }
    }
}

//初始化识别核心
- (void) initOCRSource{
#if TARGET_IPHONE_SIMULATOR//模拟器
#elif TARGET_OS_IPHONE//真机
    
    NSDate *before = [NSDate date];
    
    _ocr = [[SmartOCR alloc] init];
    //    NSString *resourcePath = [NSString stringWithFormat:@"%@/",[[NSBundle mainBundle] bundlePath]];
    NSString *resourcePath = [NSString stringWithFormat:@"%@/",[[NSBundle ocrBundle] bundlePath]];
    int init = [_ocr initOcrEngineWithDevcode:kDevcode resourcePaht:resourcePath];
    NSLog(@"初始化返回值 = %d 核心版本号 = %@", init, [_ocr getVersionNumber]);
    
    //添加主模板
    //    NSString *templateFilePath = [[NSBundle mainBundle] pathForResource:@"SZHY" ofType:@"xml"];
    NSString *templateFilePath = [[NSBundle ocrBundle] pathForResource:@"SZHY" ofType:@"xml"];
    int addTemplate = [_ocr addTemplateFile:templateFilePath];
    NSLog(@"添加主模板返回值 = %d", addTemplate);
    
    //设置子模板·
    int currentTemplate = [_ocr setCurrentTemplate:@"SV_ID_YYZZ_MOBILEPHONE"];
    NSLog(@"设置当前模板返回值 =%d",currentTemplate);
    
    //设置检边参数
    [self setROI];
    
    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:before];
    NSLog(@"time：%f", time);
    
#endif
    
    
}
//设置检边参数
- (void) setROI{
#if TARGET_IPHONE_SIMULATOR//模拟器
#elif TARGET_OS_IPHONE//真机
    
    //设置识别区域
    CGRect rect = [self setOverViewSmallRect];
    
    CGFloat tWidth = (kFocalScale-1)*kScreenWidth*0.5;
    CGFloat tHeight = (kFocalScale-1)*kScreenHeight*0.5;
    //previewLayer上点坐标
    CGPoint pLTopPoint = CGPointMake((CGRectGetMinX(rect)+tWidth)/kFocalScale, (CGRectGetMinY(rect)+tHeight)/kFocalScale);
    CGPoint pRDownPoint = CGPointMake((CGRectGetMaxX(rect)+tWidth)/kFocalScale, (CGRectGetMaxY(rect)+tHeight)/kFocalScale);
    CGPoint pRTopPoint = CGPointMake((CGRectGetMaxX(rect)+tWidth)/kFocalScale, (CGRectGetMinY(rect)+tHeight)/kFocalScale);
    
    //真实图片点坐标
    CGPoint iLTopPoint = [self.preview captureDevicePointOfInterestForPoint:pRTopPoint];
    CGPoint iLDownPoint = [self.preview captureDevicePointOfInterestForPoint:pLTopPoint];
    CGPoint iRTopPoint = [self.preview captureDevicePointOfInterestForPoint:pRDownPoint];
    
    /*
     计算roi、
     AVCaptureVideoOrientationLandscapeRight
     AVCaptureSessionPreset1920x1080
     */
    
    int sTop,sBottom,sLeft,sRight;
    if (self.recogOrientation == RecogInHorizontalScreen) {
        //横屏识别计算ROI
        sTop = iLTopPoint.y*kResolutionHeight;
        sBottom = iLDownPoint.y*kResolutionHeight;
        sLeft = iLTopPoint.x*kResolutionWidth;
        sRight = iRTopPoint.x*kResolutionWidth;
    }else{
        //竖屏识别计算ROI
        sTop = iLTopPoint.x*kResolutionWidth;
        sBottom = iRTopPoint.x*kResolutionWidth;
        sLeft = (1-iLDownPoint.y)*kResolutionHeight;
        sRight = (1-iLTopPoint.y)*kResolutionHeight;
        
    }
    
    [_ocr setROIWithLeft:sLeft Top:sTop Right:sRight Bottom:sBottom];
    //NSLog(@"t=%d b=%d l=%d r=%d",sTop,sBottom,sLeft,sRight);
    
#endif
    
}

#pragma mark - 设置检边区域的frmae
- (CGRect )setOverViewSmallRect{
    /*
     sRect 为检边框的frame，用户可以自定义设置
     以下是demo对检边框frame的设置，仅供参考.
     */
    CGFloat safeWidth = kScreenHeight-kSafeTopNoNavHeight-kSafeBottomHeight-100;//100为底部UITableView高度
    CGRect sRect = CGRectZero;
    CGFloat cardScale = 8;
    if (self.recogOrientation == RecogInHorizontalScreen) {
        CGFloat tempScale = 0.8;
        //横屏识别设置检边框frame
        CGFloat tempHeight = safeWidth*tempScale;
        CGFloat tempWidth = tempHeight/cardScale;
        sRect = CGRectMake((kScreenWidth-tempWidth)*0.5, (safeWidth-tempHeight)*0.5+kSafeTopNoNavHeight, tempWidth,tempHeight);
    }else{
        CGFloat tempScale = 0.95;
        //竖屏识别设置检边框frame
        CGFloat tempWidth = kScreenWidth*tempScale;
        CGFloat tempHeight = tempWidth/cardScale;
        sRect = CGRectMake((kScreenWidth-tempWidth)*0.5, (safeWidth-tempHeight)*0.5+kSafeTopNoNavHeight, tempWidth,tempHeight);
    }
    return sRect;
    
}

//创建相机界面
- (void)createCameraView{
    //设置检边视图层
    _overView = [[SmartOCROverView alloc] initWithFrame:self.view.bounds];
    _overView.backgroundColor = [UIColor clearColor];
    CGRect overSmallRect = [self setOverViewSmallRect];
    [_overView setSmallrect:overSmallRect];
    [self.view addSubview:_overView];
    
    //设置覆盖层
    [self drawShapeLayer];
    
    //显示当前识别类型
//    self.middleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
//    self.middleLabel.center = CGPointMake(CGRectGetMidX(overSmallRect),CGRectGetMidY(overSmallRect));
//    self.middleLabel.backgroundColor = [UIColor clearColor];
//    self.middleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
//    self.middleLabel.textAlignment = NSTextAlignmentCenter;
//    self.middleLabel.font = [UIFont boldSystemFontOfSize:20.f];
//    SubType *subtype = self.subTypes[0];
//    self.middleLabel.text = subtype.name;
//    [self.view addSubview:self.middleLabel];
    
    //返回、闪光灯按钮
    UIButton *backBtn = [[UIButton alloc]initWithFrame:CGRectZero];
    [backBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
    [backBtn setImage:[UIImage imageNamed:@"back_camera_btn"] forState:UIControlStateNormal];
    backBtn.titleLabel.textAlignment = NSTextAlignmentLeft;
    [self.view addSubview:backBtn];
    
    UIButton *flashBtn = [[UIButton alloc]initWithFrame:CGRectZero];
    [flashBtn setImage:[UIImage imageNamed:@"flash_camera_btn"] forState:UIControlStateNormal];
    [flashBtn addTarget:self action:@selector(flashBtn) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:flashBtn];
    
    //添加拍照按钮
    _takePicBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_takePicBtn setImage:[UIImage imageNamed:@"take_pic_btn"] forState:UIControlStateNormal];
    [_takePicBtn addTarget:self action:@selector(takePhoto:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_takePicBtn];
    
    if (self.recogOrientation==RecogInHorizontalScreen) {
        _takePicBtn.frame = CGRectMake(CGRectGetMinX(overSmallRect),CGRectGetMaxY(overSmallRect)-CGRectGetWidth(overSmallRect),CGRectGetWidth(overSmallRect),CGRectGetWidth(overSmallRect));
        _takePicBtn.transform = CGAffineTransformMakeRotation(M_PI/2);
        flashBtn.frame = CGRectMake(kScreenWidth-45, kScreenHeight-kSafeBottomHeight-20-35-100, 35, 35);
        backBtn.frame = CGRectMake(kScreenWidth-45, kSafeTopNoNavHeight+20, 35, 35);
        backBtn.transform = CGAffineTransformMakeRotation(M_PI/2);
        flashBtn.transform = CGAffineTransformMakeRotation(M_PI/2);
        self.middleLabel.transform = CGAffineTransformMakeRotation(M_PI/2);
    }else{
        _takePicBtn.frame = CGRectMake((CGRectGetMaxX(overSmallRect)-CGRectGetHeight(overSmallRect)),CGRectGetMinY(overSmallRect),CGRectGetHeight(overSmallRect),CGRectGetHeight(overSmallRect));
        CGFloat sTopHeight =kSafeTopNoNavHeight + 15;
        flashBtn.frame = CGRectMake(kScreenWidth-50-kSafeLRX,sTopHeight, 35, 35);
        backBtn.frame = CGRectMake(15+kSafeLRX,sTopHeight, 35, 35);
    }
    
    //创建识别类型列表
//    [self creatRecogTypeListView];
    //扫描动画
    [self addAnimation];
}


#if TARGET_IPHONE_SIMULATOR//模拟器
#elif TARGET_OS_IPHONE//真机
//从摄像头缓冲区获取图像
#pragma mark - AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection{
    
    //获取当前帧数据
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    int width = (int)CVPixelBufferGetWidth(imageBuffer);
    int height = (int)CVPixelBufferGetHeight(imageBuffer);
    //NSLog(@"_recogType == %d",_recogType);
    
    if (_isChangedType ==YES) {
        
        //选择当前识别模板
//        SubType *subtype = self.subTypes[0];
        int currentTemplate = [_ocr setCurrentTemplate:@"SV_ID_YYZZ_MOBILEPHONE"];
        NSLog(@"设置模板返回值：%d", currentTemplate);
        [self setROI];
        _isChangedType = NO;
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);
        return;
    }
    
    
    if (!self.adjustingFocus) {
        //OCR识别
        [self recogWithData:baseAddress width:width height:height SampleBuffer:sampleBuffer];
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}


- (void)recogWithData:(uint8_t *)baseAddress width:(int)width height:(int)height SampleBuffer:(CMSampleBufferRef)sampleBuffer{
    
    //加载图像,横屏识别RotateType传0，竖屏识别传1
    if (self.recogOrientation == RecogInHorizontalScreen) {
        int load = [_ocr loadStreamBGRA:baseAddress Width:width Height:height RotateType:0];
        //NSLog(@"load = %d",load);
    }else{
        int load = [_ocr loadStreamBGRA:baseAddress Width:width Height:height RotateType:1];
        //NSLog(@"load = %d",load);
    }
    
    //识别
    int recog = [_ocr recognize];
    //NSLog(@"recog=%d",recog);
    if (recog == 0 || _isTakePicBtnClick) {
        _isTakePicBtnClick = NO;
        [_session stopRunning];
        
        //识别成功，取结果
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        
        //获取识别结果
        NSString *result = [_ocr getResults];
        NSLog(@"result = %@",result);
        
        //保存裁切图片
        NSArray *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//        SubType *subtype = self.subTypes[0];
//        NSString *imagePath = [documents[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",subtype.OCRId]];
//        [_ocr saveImage:imagePath isRecogSuccess:recog];
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            _takePicBtn.enabled = YES;
//            [self pushToResultView:subtype.name result:result imagePath:imagePath];
//        });
    }
}
#endif
//-(void) pushToResultView:(NSString *)subTypeName result:(NSString *)result imagePath:(NSString *)path{
//    ResultViewController *rvc = [[ResultViewController alloc] init];
//    rvc.resultStr = result;
//    rvc.imagePath = path;
//    rvc.subTypeName = subTypeName;
//    rvc.ocr = _ocr;
//    [self.navigationController pushViewController:rvc animated:YES];
//
//}

#pragma mark - ButtonAction
//返回按钮按钮点击事件
- (void)backAction{
    [self.navigationController popViewControllerAnimated:YES];
}
//点击拍照按钮
- (void) takePhoto:(UIButton *)btn{
    btn.enabled = NO;
    _isTakePicBtnClick = YES;
}

//闪光灯按钮点击事件
- (void)flashBtn{
    
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    if (![device hasTorch]) {
        //        NSLog(@"no torch");
    }else{
        [device lockForConfiguration:nil];
        if (!_on) {
            //关闭定时器
            [_timer setFireDate:[NSDate distantFuture]];
            [device setTorchMode: AVCaptureTorchModeOn];
            [self setExposureModeCustomEx];
            _on = YES;
            
        }else{
            //开启定时器
            [_timer setFireDate:[NSDate distantPast]];
            [device setTorchMode: AVCaptureTorchModeOff];
            _on = NO;
        }
        [device unlockForConfiguration];
    }
    
}
//设置曝光度
- (void)setExposureModeCustomEx{
    AVCaptureDeviceFormat *format = _device.activeFormat;
    float isoValue = 80;
    if ( isoValue < format.minISO ) {
        isoValue = format.minISO;
    } else if ( isoValue > format.maxISO ) {
        isoValue = format.maxISO;
    }
    if ([_device isExposureModeSupported:AVCaptureExposureModeCustom]) {
        if ([_device lockForConfiguration:nil]) {
            [_device setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:80/*80为测试经验值*/ completionHandler:^(CMTime syncTime) {
            }];
            [_device unlockForConfiguration];
        }
    }
}
//自动曝光
- (void)setExposureModeContinuousAutoExposureEx{
    CGRect overSmallRect = [self setOverViewSmallRect];
    CGPoint cameraPoint= [_preview captureDevicePointOfInterestForPoint:CGPointMake(CGRectGetMidX(overSmallRect), CGRectGetMidY(overSmallRect))];
    if ([_device isExposurePointOfInterestSupported]) {
        if ([_device lockForConfiguration:nil]) {
            [_device setExposurePointOfInterest:cameraPoint];
            [_device unlockForConfiguration];
        }
    }
    if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        if ([_device lockForConfiguration:nil]) {
            [_device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            [_device unlockForConfiguration];
        }
    }
}

//对焦
- (void)fouceMode{
    NSError *error;
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        if ([device lockForConfiguration:&error]) {
            CGPoint cameraPoint = [self.preview captureDevicePointOfInterestForPoint:self.view.center];
            [device setFocusPointOfInterest:cameraPoint];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        } else {
            NSLog(@"Error: %@", error);
        }
    }
}

//获取摄像头位置
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices){
        if (device.position == position){
            return device;
        }
    }
    return nil;
}

//隐藏状态栏
- (UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden{
    return YES;
}

- (void)addAnimation{
    CGRect overSmallRect = [self setOverViewSmallRect];
    //扫描线
    UIImageView *_lineView = [[UIImageView alloc]init];
    _lineView.contentMode = UIViewContentModeScaleToFill;
    [self.view addSubview:_lineView];
    int lineW = 2;
    if (self.recogOrientation==RecogInHorizontalScreen) {
        _lineView.image = [UIImage imageNamed:@"vertical_line.png"];
        _lineView.frame = CGRectMake(CGRectGetMaxX(overSmallRect), CGRectGetMinY(overSmallRect), lineW, CGRectGetHeight(overSmallRect));
        NSNumber *b = [NSNumber numberWithFloat:(lineW*(-1))];
        NSNumber *e = [NSNumber numberWithFloat:(int)CGRectGetWidth(overSmallRect)*(-1)];
        CABasicAnimation *animation = [self moveYTime:1 fromBegin:b  toEnd:e rep:OPEN_MAX];
        [_lineView.layer addAnimation:animation forKey:@"LineAnimation"];
    }else{
        _lineView.image = [UIImage imageNamed:@"horizontal_line.png"];
        _lineView.frame = CGRectMake(CGRectGetMinX(overSmallRect), CGRectGetMinY(overSmallRect), CGRectGetWidth(overSmallRect), lineW);
        NSNumber *b = [NSNumber numberWithFloat:0];
        NSNumber *e = [NSNumber numberWithFloat:(int)(CGRectGetHeight(overSmallRect)-lineW)];
        CABasicAnimation *animation = [self moveYTime:1 fromBegin:b  toEnd:e rep:OPEN_MAX];
        [_lineView.layer addAnimation:animation forKey:@"LineAnimation"];
    }
}

- (CABasicAnimation *)moveYTime:(float)time fromBegin:(NSNumber *)nBegin toEnd:(NSNumber *)nEnd rep:(int)rep{
    
    NSString *trans = @"";
    if (self.recogOrientation==RecogInHorizontalScreen) {
        trans = @"transform.translation.x";
    }else{
        trans = @"transform.translation.y";
    }
    CABasicAnimation *animationMove = [CABasicAnimation animationWithKeyPath:trans];
    [animationMove setFromValue:nBegin];
    [animationMove setToValue:nEnd];
    animationMove.duration = time;
    animationMove.repeatCount  = rep;
    animationMove.fillMode = kCAFillModeForwards;
    animationMove.removedOnCompletion = NO;
    animationMove.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    return animationMove;
}
//重绘透明部分
- (void) drawShapeLayer{
    //设置覆盖层
    if (!self.maskWithHole) {
        self.maskWithHole = [CAShapeLayer layer];
    }
    
    // Both frames are defined in the same coordinate system
    CGRect biggerRect = self.view.bounds;
    CGFloat offset = 1.0f;
    if ([[UIScreen mainScreen] scale] >= 2) {
        offset = 0.5;
    }
    
    //设置检边视图层
    CGRect smallFrame = [self setOverViewSmallRect];
    CGRect smallerRect = CGRectInset(smallFrame, -offset, -offset) ;
    UIBezierPath *maskPath = [UIBezierPath bezierPath];
    [maskPath moveToPoint:CGPointMake(CGRectGetMinX(biggerRect), CGRectGetMinY(biggerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(biggerRect), CGRectGetMaxY(biggerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(biggerRect), CGRectGetMaxY(biggerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(biggerRect), CGRectGetMinY(biggerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(biggerRect), CGRectGetMinY(biggerRect))];
    [maskPath moveToPoint:CGPointMake(CGRectGetMinX(smallerRect), CGRectGetMinY(smallerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(smallerRect), CGRectGetMaxY(smallerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(smallerRect), CGRectGetMaxY(smallerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(smallerRect), CGRectGetMinY(smallerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(smallerRect), CGRectGetMinY(smallerRect))];
    [self.maskWithHole setPath:[maskPath CGPath]];
    [self.maskWithHole setFillRule:kCAFillRuleEvenOdd];
    [self.maskWithHole setFillColor:[[UIColor colorWithWhite:0 alpha:0.5] CGColor]];
    [self.view.layer addSublayer:self.maskWithHole];
    [self.view.layer setMasksToBounds:YES];
}




/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end

//
//  ViewController.m
//  Record
//
//  Created by fangxue on 16/8/1.
//  Copyright © 2016年 fangxue. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage.h"
#import <AssetsLibrary/AssetsLibrary.h>
@interface ViewController ()<GPUImageVideoCameraDelegate>
{
    dispatch_semaphore_t _seam;
    dispatch_source_t _timer;
    CVPixelBufferRef _imageBuffer;
}
@property (nonatomic, strong) GPUImageVideoCamera *camera;
@property (nonatomic, strong) GPUImageView *preview;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) UIButton *btn;
@property (nonatomic, strong) UIButton *btn2;
@property (nonatomic, assign) BOOL enable;
@property (nonatomic, assign) BOOL end;
@property (nonatomic, assign) int progress;//时间间隔 默认10秒合一帧 可调
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@end

@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.progress = 10;
    
    _camera = [[GPUImageVideoCamera alloc]initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionBack];
    _camera.outputImageOrientation  = UIDeviceOrientationPortrait;
    _camera.horizontallyMirrorFrontFacingCamera = YES;
    _camera.delegate = self;
    
    _preview = [[GPUImageView alloc]initWithFrame:self.view.frame];
    [self.view addSubview:_preview];
    
    [_camera addTarget:self.preview];
    [_camera startCameraCapture];
    
    
    _btn = [[UIButton alloc]initWithFrame:CGRectMake(20, self.view.frame.size.height - 100, 100, 48)];
    _btn.backgroundColor = [UIColor orangeColor];
    [_btn setTitle:@"点击开始" forState:UIControlStateNormal];
    [_btn addTarget:self action:@selector(onBrginRecordAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btn];
    
    
    _btn2 = [[UIButton alloc]initWithFrame:CGRectMake(140, self.view.frame.size.height - 100, 200, 48)];
    _btn2.backgroundColor = [UIColor orangeColor];
    [_btn2 setTitle:@"点击开始" forState:UIControlStateNormal];
    [_btn2 addTarget:self action:@selector(onBrginRecordAction2:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btn2];
}
- (void)setupTimer{
    
    //初始化定时器
    __weak typeof(self) ws =self;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), 0.5 * NSEC_PER_SEC, 0);
    
    dispatch_source_set_event_handler(_timer, ^{
        [ws defaultTimerHandel];
    });
    
    _seam = dispatch_semaphore_create(0);
}
#pragma mark -
#pragma mark -
- (void)defaultTimerHandel
{
    _enable = YES;
}
#pragma mark -
#pragma mark -
- (void)onBrginRecordAction:(UIButton *)btn
{
    //异步处理
    [[NSOperationQueue new] addOperationWithBlock:^{
        [self record];
    }];
   
    self.end = NO;
    
    [self setupTimer];
    
    dispatch_resume(_timer);
}

- (void)onBrginRecordAction2:(UIButton *)btn
{
    dispatch_cancel(_timer);
    
    _timer = nil;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.end = YES;
        dispatch_semaphore_signal(_seam);
    });
}
#pragma mark -
#pragma mark -
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;
{
    if (_enable)
    {
        _enable = NO;
        //获取buffer
        CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        _imageBuffer =  CVPixelBufferRetain(imageBuffer);
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        dispatch_semaphore_signal(_seam);
    }
}
- (void)record
{
    NSDate *date = [NSDate date];
    NSString *string = [NSString stringWithFormat:@"%ld.mov",(unsigned long)(date.timeIntervalSince1970 * 1000)];
    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:string];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
    }
    NSURL  *exportUrl = [NSURL fileURLWithPath:cachePath];
    _url = exportUrl;
    CGSize size = CGSizeMake(1920,1080);
    __block AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:exportUrl
                                                                   fileType:AVFileTypeQuickTimeMovie
                                                                      error:nil];
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:size.height], AVVideoHeightKey, nil];
    
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    
    if ([videoWriter canAddInput:writerInput])
        NSLog(@"");
    else
        NSLog(@"");
    
    [videoWriter addInput:writerInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_queue_t dispatchQueue = dispatch_queue_create("mediaInputQueue", NULL);
    
    
    int __block frame = 0;
    
    //开始写视频帧
    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
        while ([writerInput isReadyForMoreMediaData])
        {
            if(_end)    //结束标志
            {
                [writerInput markAsFinished];
                if(videoWriter.status == AVAssetWriterStatusWriting){
                    NSCondition *cond = [[NSCondition alloc] init];
                    [cond lock];
                    [videoWriter finishWritingWithCompletionHandler:^{
                        [cond lock];
                        [cond signal];
                        [cond unlock];
                    }];
                    [cond wait];
                    [cond unlock];
                    [self savePhotoCmare:self.url];
                }
                NSLog(@"end");
                break;
            }
            dispatch_semaphore_wait(_seam, DISPATCH_TIME_FOREVER);
            if (_imageBuffer)
                
            {
                //写视频帧
                if([adaptor appendPixelBuffer:_imageBuffer withPresentationTime:CMTimeMake(frame, self.progress)])
                {
                    
                    frame++;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.btn2 setTitle:[NSString stringWithFormat:@"点击暂停 frame:%d",frame] forState:UIControlStateNormal];
                         NSLog(@"%d",frame);
                    });
                }else
                {
                    NSLog(@"失败");
                }
                //释放buffer
                CVPixelBufferRelease(_imageBuffer);
                _imageBuffer = NULL;
            }
            
        }
    }];
}

//保存到相册
- (void)savePhotoCmare:(NSURL *)url
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:url])
    {
        [library writeVideoAtPathToSavedPhotosAlbum:url completionBlock:^(NSURL *assetURL, NSError *error)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (error)
                 {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                                    delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                     
                 } else
                 {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Video Saving success"
                                                                    delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                     
                 }
             });
         }];
    }
}


@end

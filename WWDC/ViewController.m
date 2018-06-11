//
//  ViewController.m
//  WWDC
//
//  Created by mesird on 2018/6/9.
//  Copyright © 2018 mesird. All rights reserved.
//

#import "ViewController.h"

#import "DCUserAcitivityConstants.h"
#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVAudioRecorderDelegate>

@property (nonatomic, copy) NSString *audioPath;

@property (weak, nonatomic) IBOutlet UITextView *displayPanel;
@property (weak, nonatomic) IBOutlet UIView *recordButton;
@property (weak, nonatomic) IBOutlet UIButton *speakButton;

@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;

@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *audioBufferRecoRequest;

@property (nonatomic, strong) AVAudioRecorder *recorder;

@property (nonatomic, strong) AVAudioEngine *engine;

@end

@implementation ViewController

- (AVAudioRecorder *)recorder {
    if (!_recorder) {
        NSString *path = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"myRecord.caf"];
        NSURL *url = [NSURL URLWithString:path];
        NSDictionary *setting = [self aduioSettings];
        NSError *error = nil;
        _recorder = [[AVAudioRecorder alloc] initWithURL:url settings:setting error:&error];
        _recorder.delegate = self;
        _recorder.meteringEnabled = YES;
        if (error) {
            NSLog(@"create record failed, see error : %@", error.localizedDescription);
            return nil;
        }
    }
    return _recorder;
}

- (NSDictionary *)aduioSettings {
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    [recordSettings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey: AVFormatIDKey];
    [recordSettings setValue :[NSNumber numberWithFloat:11025.0] forKey: AVSampleRateKey];
    [recordSettings setValue :[NSNumber numberWithInt:2] forKey: AVNumberOfChannelsKey];
    [recordSettings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
    return recordSettings;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self _setupData];
    [self _setupView];
    [self _requestAuthorization];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)_setupData {
    _audioPath = [NSString stringWithFormat:@"file:///%@%@", NSTemporaryDirectory(), @"myRecord.caf"];
    _synthesizer = [[AVSpeechSynthesizer alloc] init];
    _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale currentLocale]];
}

- (void)_setupView {
    _recordButton.layer.cornerRadius = _recordButton.frame.size.height / 2;
    _recordButton.layer.masksToBounds = YES;
    _recordButton.layer.borderWidth = 4;
    _recordButton.layer.borderColor = [UIColor darkGrayColor].CGColor;
}

- (void)_requestAuthorization {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status) {
                case SFSpeechRecognizerAuthorizationStatusAuthorized:
                    NSLog(@"authorized!");
                    break;
                case SFSpeechRecognizerAuthorizationStatusDenied:
                    NSLog(@"denied!");
                    break;
                case SFSpeechRecognizerAuthorizationStatusRestricted:
                    NSLog(@"restricted!");
                    break;
                case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                    NSLog(@"not determined!");
                    break;
                default:
                    break;
            }
        });
    }];
}

//MARK: Interactions

- (IBAction)pressOnRecognizeButton:(UIButton *)sender {
    if (_audioPath) {
        NSURL *audioURL = [NSURL URLWithString:_audioPath];
        if (!_speechRecognizer) {
            NSLog(@"device not supported.");
            return;
        }
        if (!_speechRecognizer.isAvailable) {
            NSLog(@"not available right now");
            return;
        }
        
        __weak typeof(self) weakSelf = self;
        
        SFSpeechURLRecognitionRequest *request = [[SFSpeechURLRecognitionRequest alloc] initWithURL:audioURL];
        [_speechRecognizer recognitionTaskWithRequest:request resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
            if (result) {
                NSLog(@"best result : %@", result.bestTranscription.formattedString);
                weakSelf.displayPanel.text = result.bestTranscription.formattedString;
            } else {
                NSLog(@"regonize failed, see error: %@", error.localizedDescription);
            }
        }];
    }
}

- (IBAction)pressOnSpeakButton:(UIButton *)sender {
    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:_displayPanel.text];
    [_synthesizer speakUtterance:utterance];
}

//MARK: Touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self.view];
    if ([self point:point inView:_recordButton]) {
        NSLog(@"began");
        _recordButton.backgroundColor = UIColor.greenColor;
        [self startRecording];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self.view];
    if ([self point:point inView:_recordButton]) {
        NSLog(@"end");
        _recordButton.backgroundColor = UIColor.redColor;
        [self stopRecording];
    }
}

//MARK: Utils

- (BOOL)point:(CGPoint)point inView:(UIView *)view {
    if (view.frame.origin.x > point.x || view.frame.origin.x + view.frame.size.width < point.x ||
        view.frame.origin.y > point.y || view.frame.origin.y + view.frame.size.height < point.y) {
        return NO;
    }
    return YES;
}

//MARK: Audio Recording

- (void)startRecording {
    if ([self.recorder isRecording]) {
        [self.recorder stop];
    }
    
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    if (![self.recorder isRecording]) {
        [self.recorder record];
    }
}

- (void)stopRecording {
    [self.recorder stop];
}

//MARK: Audio Delegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    NSLog(@"record finished with success : %d", flag);
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"encode error : %@", error.localizedDescription);
}

@end

#import "SwishGameflowChartManager.h"
#import "SwishGameflowChart.h"
#import "RCTBridge.h"
#import "RCTConvert.h"
#import <RCTView.h>
#import <UIKit/UIKit.h>

@interface SwishGameflowChartManager ()

@end

@implementation SwishGameflowChartManager

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

- (UIView *)view
{
  return [[SwishGameflowChart alloc] initWithEventDispatcher:self.bridge.eventDispatcher];
}

- (NSArray *)customDirectEventTypes
{
  return @[
           @"onTouchStarted", //sends closets moment, hover description over point
           @"onTouchEnded" //scroll to that point and play the video
           ];
}


- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

RCT_EXPORT_VIEW_PROPERTY(chartData, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(moments, NSDictionaryArray);
RCT_EXPORT_VIEW_PROPERTY(homeTeamName, NSString);
RCT_EXPORT_VIEW_PROPERTY(awayTeamName, NSString);
RCT_EXPORT_VIEW_PROPERTY(activeMomentIndex, int);
RCT_EXPORT_VIEW_PROPERTY(lineWidth, CGFloat);
RCT_EXPORT_VIEW_PROPERTY(smoothingBuffer, CGFloat);
RCT_EXPORT_VIEW_PROPERTY(homeTeamColor, UIColor);
RCT_EXPORT_VIEW_PROPERTY(awayTeamColor, UIColor);
RCT_EXPORT_VIEW_PROPERTY(backgroundColor, UIColor);

@end

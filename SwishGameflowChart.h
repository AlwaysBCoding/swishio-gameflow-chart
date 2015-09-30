#import "RCTView.h"

@class RCTEventDispatcher;

@interface SwishGameflowChart : UIView

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong) UIColor* backgroundColor;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) CGFloat smoothingBuffer;
@property (nonatomic, copy) NSString* homeTeamName;
@property (nonatomic, copy) NSString* awayTeamName;

@end
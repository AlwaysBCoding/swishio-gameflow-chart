#import "SwishGameflowChart.h"
#import "RCTConvert.h"
#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"
#import "UIView+React.h"

NSString *const ChartTouchStarted = @"onTouchStarted";
NSString *const ChartTouchEnded = @"onTouchEnded";

@implementation SwishGameflowChart
{
  
  RCTEventDispatcher *_eventDispatcher;
  NSArray *_xCoords;
  NSArray *_yCoords;
  NSArray *_restXCoords;
  NSArray *_upperYCoords;
  NSArray *_lowerYCoords;
  NSDictionaryArray *_moments;
  NSMutableArray *_momentLayers;
  NSMutableArray *_activeLayers;
  int _activeMomentIndex;
  UIColor *_homeTeamColor;
  UIColor *_awayTeamColor;
  NSInteger *_scoreLabelWidth;
  CGFloat _minX;
  CGFloat _maxX;
  CGFloat _minY;
  CGFloat _maxY;
  CGFloat _xScale;
  CGFloat _yScale;
  CFTimeInterval _animationDuration;
  UIView *_chartContainer;
  CGFloat _chartLabelHeight;
}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
  if ((self = [super init])) {
    _eventDispatcher = eventDispatcher;
    _lineWidth = 1; // set as default
    _animationDuration = 0.5;
    _chartLabelHeight = 24;
    _activeMomentIndex = -1;
    _momentLayers = [[NSMutableArray alloc] init];
    _activeLayers = [[NSMutableArray alloc] init];
    
  }
  return self;
}

- (void)setChartData:(NSDictionary *)coords
{
  _xCoords = [RCTConvert NSArray:coords[@"xCoords"]];
  _yCoords = [RCTConvert NSArray:coords[@"yCoords"]];
  [self setNeedsLayout];
  
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  if (_yCoords.count > 0) {
    [self computeBounds];
    [self buildChart];
    [self drawQuarterLines];
    [self drawTeamLabels];
    [self drawMoments];
  }
}


- (void)setMoments:(NSDictionaryArray *)moments
{
  _moments = moments;
  
  //  [self setNeedsLayout];
  //draw moments
}

- (void)setHomeTeamColor:(UIColor *)homeTeamColor
{
  _homeTeamColor = [self brightenColor:homeTeamColor brightness:0.95];
}

- (void)setAwayTeamColor:(UIColor *)awayTeamColor
{
  _awayTeamColor = [self brightenColor:awayTeamColor brightness:0.95];
}

- (void)setActiveMomentIndex:(int)momentIndex
{
  if (_activeMomentIndex >= 0 ) {
    [self updateActiveMoment:_activeMomentIndex nextActiveMomentIndex:momentIndex];
  }
  _activeMomentIndex = momentIndex;
}

- (UIColor *)brightenColor:(UIColor *)color brightness:(CGFloat)brightnessValue
{
  CGFloat hue;
  CGFloat saturation;
  CGFloat brightness;
  CGFloat alpha;
  
  BOOL success = [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
  
  if (success) {
    return [[UIColor alloc] initWithHue:hue saturation:saturation brightness:brightnessValue alpha:alpha];
    
  } else {
    return color;
  }
}

- (void)buildChart
{
  UIBezierPath *upperPath =  [self generateLinePath:_restXCoords yCoords:_upperYCoords];
  UIBezierPath *lowerPath = [self generateLinePath:_restXCoords yCoords:_lowerYCoords];
  CGFloat topFrameOffset = _chartContainer.bounds.size.height * (_maxY / (_maxY + fabs(_minY)));
  CAShapeLayer *upperFill = [CAShapeLayer layer];
  CAShapeLayer *lowerFill = [CAShapeLayer layer];
  CGRect upperGradientFrame = CGRectMake(_chartContainer.bounds.origin.x, _chartContainer.bounds.origin.y + (_lineWidth / 2), _chartContainer.bounds.size.width, topFrameOffset - (_lineWidth/2));
  
  
  CAGradientLayer* upperGradientLayer = [CAGradientLayer layer];
  CAGradientLayer* lowerGradientLayer = [CAGradientLayer layer];
  
  upperGradientLayer.colors = @[(id)_homeTeamColor.CGColor, (id)_backgroundColor.CGColor];
  upperGradientLayer.startPoint = CGPointMake(0, 0);
  upperGradientLayer.endPoint = CGPointMake(0, 0);
  upperGradientLayer.endPoint = CGPointMake(0, 1);
  upperGradientLayer.frame = upperGradientFrame;
  lowerGradientLayer.colors = @[(id)_awayTeamColor.CGColor, (id)_backgroundColor.CGColor];
  lowerGradientLayer.startPoint = CGPointMake(0, 1);
  lowerGradientLayer.endPoint = CGPointMake(0, 0);
  lowerGradientLayer.frame = CGRectMake(_chartContainer.bounds.origin.x, topFrameOffset, _chartContainer.bounds.size.width, _chartContainer.bounds.size.height - topFrameOffset - (_lineWidth/2));
  
  upperFill.frame = CGRectMake(_chartContainer.bounds.origin.x, _chartContainer.bounds.origin.y, _chartContainer.bounds.size.width, topFrameOffset + (_lineWidth/2));
  upperFill.masksToBounds = YES;
  upperFill.path = upperPath.CGPath;
  upperFill.strokeColor = _homeTeamColor.CGColor;
  upperFill.fillColor = _backgroundColor.CGColor;
  upperFill.lineWidth = _lineWidth;
  upperFill.strokeEnd = [self pathRatio:_xCoords yCoords:_yCoords longerXCoords:_restXCoords longerYCoords:_upperYCoords];
  
  lowerFill.frame = CGRectMake(_chartContainer.bounds.origin.x, _chartContainer.bounds.origin.y, _chartContainer.bounds.size.width, _chartContainer.bounds.size.height - topFrameOffset);
  lowerFill.path = lowerPath.CGPath;
  lowerFill.strokeColor = _awayTeamColor.CGColor;
  lowerFill.fillColor = _backgroundColor.CGColor;
  lowerFill.lineWidth = _lineWidth;
  lowerFill.strokeEnd = [self pathRatio:_xCoords yCoords:_yCoords longerXCoords:_restXCoords longerYCoords:_lowerYCoords];
  
  self.clipsToBounds = NO;
  upperGradientLayer.hidden = YES;
  lowerGradientLayer.hidden = YES;
  if (_minY < 0)
    [_chartContainer.layer addSublayer:lowerGradientLayer];
  [_chartContainer.layer addSublayer:lowerFill];
  if (_maxY > 0)
    [_chartContainer.layer addSublayer:upperGradientLayer]; //only add the home background if they were in the lead at any point
  [_chartContainer.layer addSublayer:upperFill];
  
  CABasicAnimation *upperPathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
  upperPathAnimation.duration = _animationDuration;
  upperPathAnimation.fromValue = [NSNumber numberWithFloat:0];
  upperPathAnimation.toValue = [NSNumber numberWithFloat:[self pathRatio:_xCoords yCoords:_yCoords longerXCoords:_restXCoords longerYCoords:_upperYCoords]];
  CABasicAnimation *lowerPathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
  lowerPathAnimation.duration = _animationDuration;
  lowerPathAnimation.fromValue = [NSNumber numberWithFloat:0];
  lowerPathAnimation.toValue = [NSNumber numberWithFloat:[self pathRatio:_xCoords yCoords:_yCoords longerXCoords:_restXCoords longerYCoords:_lowerYCoords]];
  CABasicAnimation *upperGradientAnimation = [CABasicAnimation animationWithKeyPath:@"endPoint"];
  upperGradientAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  upperGradientAnimation.beginTime = CACurrentMediaTime() + _animationDuration / 2;
  upperGradientAnimation.duration = _animationDuration / 2;
  upperGradientAnimation.fromValue = [NSValue valueWithCGPoint:upperGradientLayer.startPoint];
  upperGradientAnimation.toValue = [NSValue valueWithCGPoint:upperGradientLayer.endPoint];
  upperGradientAnimation.fillMode = kCAFillModeForwards;
  upperGradientAnimation.removedOnCompletion = NO;
  CABasicAnimation *lowerGradientAnimation = [CABasicAnimation animationWithKeyPath:@"endPoint"];
  lowerGradientAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  lowerGradientAnimation.beginTime = CACurrentMediaTime() + _animationDuration / 2;
  lowerGradientAnimation.duration = _animationDuration / 2;
  lowerGradientAnimation.fromValue = [NSValue valueWithCGPoint:lowerGradientLayer.startPoint];
  lowerGradientAnimation.toValue = [NSValue valueWithCGPoint:lowerGradientLayer.endPoint];
  lowerGradientAnimation.fillMode = kCAFillModeForwards;
  lowerGradientAnimation.removedOnCompletion = NO;
  
  [CATransaction begin]; {
    [CATransaction setCompletionBlock:^{
      upperGradientLayer.hidden = NO;
      lowerGradientLayer.hidden = NO;
      [upperGradientLayer addAnimation:upperGradientAnimation forKey:@"upperGradientAnimation"];
      [lowerGradientLayer addAnimation:lowerGradientAnimation forKey:@"lowerGradientAnimation"];
    }];
    [lowerFill addAnimation:lowerPathAnimation forKey:@"strokeEndAnimation"];
    [upperFill addAnimation:upperPathAnimation forKey:@"strokeEndAnimation"];
  }
  [CATransaction commit];
}

- (void)drawMoments
{
  for (int i = 0; i < _moments.count; i++){
    CGFloat radius = 4;
    CGFloat activeRadius = 10;
    NSDictionary *moment = _moments[i];
    CGPoint p = [self getPointForMoment:moment];
    NSString *attribution = moment[@"attribution"];
    
    UIBezierPath* circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(p.x - radius, p.y - radius, radius*2, radius*2)];
    UIBezierPath* activeCircle =  [UIBezierPath bezierPathWithOvalInRect:CGRectMake(p.x - activeRadius, p.y - activeRadius, activeRadius*2, activeRadius*2)];
    
    CAShapeLayer *momentLayer = [CAShapeLayer layer];
    CAShapeLayer *activeLayer = [CAShapeLayer layer];
    momentLayer.frame = CGRectMake(p.x, p.y, radius, radius);
    activeLayer.frame = CGRectMake(p.x, p.y, activeRadius, activeRadius);
    momentLayer.bounds = momentLayer.frame;
    activeLayer.bounds = activeLayer.frame;
    momentLayer.path = circle.CGPath;
    activeLayer.path = activeCircle.CGPath;
    momentLayer.strokeColor = [attribution isEqual:@"home"] ? _homeTeamColor.CGColor : _awayTeamColor.CGColor;
    activeLayer.strokeColor = momentLayer.strokeColor;
    momentLayer.fillColor = _backgroundColor.CGColor;
    activeLayer.fillColor = momentLayer.fillColor;
    momentLayer.lineWidth = 2;
    activeLayer.lineWidth = 3;
    momentLayer.shadowColor = [UIColor blackColor].CGColor;
    activeLayer.shadowColor = momentLayer.shadowColor;
    momentLayer.shadowRadius = 3;
    activeLayer.shadowRadius = 3;
    momentLayer.shadowOffset = CGSizeMake(1, 1);
    activeLayer.shadowOffset = CGSizeMake(1, 1);
    momentLayer.shadowOpacity = 0.9;
    activeLayer.shadowOpacity = 0.9;
    momentLayer.masksToBounds = NO;
    activeLayer.masksToBounds = NO;
    momentLayer.shouldRasterize = YES;
    activeLayer.shouldRasterize = YES;
    
    momentLayer.opacity = 0;
    activeLayer.opacity = 0;
    [_momentLayers addObject:momentLayer];
    [_activeLayers addObject:activeLayer];
    [self.layer addSublayer:momentLayer];
    [self.layer addSublayer:activeLayer];
    
    CABasicAnimation *momentAddAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    momentAddAnimation.beginTime = CACurrentMediaTime() + _animationDuration + i * (_animationDuration / _moments.count);
    momentAddAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    momentAddAnimation.duration = _animationDuration / 3;
    momentAddAnimation.fromValue = [NSNumber numberWithFloat:0];
    momentAddAnimation.toValue = [NSNumber numberWithFloat:1];
    momentAddAnimation.delegate = self;
    [momentAddAnimation setValue:@"momentAnimation" forKey:@"animationType"];
    [momentAddAnimation setValue:@"no" forKey:@"isActive"];
    [momentAddAnimation setValue:[NSString stringWithFormat:@"%i",i] forKey:@"momentIndex"];
    if (i == _activeMomentIndex) {
      [momentAddAnimation setValue:@"yes" forKey:@"isActive"];
      [activeLayer addAnimation:momentAddAnimation forKey:@"momentAnimation"];
    } else {
      [momentLayer addAnimation:momentAddAnimation forKey:@"momentAnimation"];
    }
  }
}

- (void)updateActiveMoment:(int)currentIndex nextActiveMomentIndex:(int)nextIndex
{
  CAShapeLayer *currentMomentLayer = _momentLayers[currentIndex];
  CAShapeLayer *currentActiveLayer = _activeLayers[currentIndex];
  CAShapeLayer *nextMomentLayer = _momentLayers[nextIndex];
  CAShapeLayer *nextActiveLayer = _activeLayers[nextIndex];
  
  currentMomentLayer.opacity = 1;
  currentActiveLayer.opacity = 0;
  nextMomentLayer.opacity = 0;
  nextActiveLayer.opacity = 1;
  
}

- (CGPoint)getPointForMoment:(NSDictionary *)moment
{
  NSNumber *quarter = moment[@"gameTimestamp"][@"quarter"];
  NSNumber *seconds = moment[@"gameTimestamp"][@"clock"];
  NSNumber *homeScore = moment[@"homeTeam"][@"score"];
  NSNumber *awayScore = moment[@"awayTeam"][@"score"];
  CGFloat xCoord = (quarter.floatValue - 1) * 900 + seconds.floatValue;
  CGFloat yCoord = homeScore.floatValue - awayScore.floatValue;
  CGPoint p = CGPointMake(xCoord*_xScale, _chartContainer.frame.size.height + _chartLabelHeight - yCoord * _yScale);
  p.y += _minY * _yScale;
  
  return p;
}

- (void)drawQuarterLines
{
  UIFont *secondaryFont = [UIFont fontWithName:@"AvenirNext-Medium" size:10];
  UIColor *secondaryColor = [[UIColor alloc] initWithWhite:0.6 alpha:0.7];
  
  CGFloat labelBuffer = 5;
  
  int quartersStarted = ceilf(_maxX / 900);
  
  for (int i = 0; i < quartersStarted; i++) {
    CGFloat seconds = i * 900;
    CGFloat labelHeight = 12;
    CALayer *quarterLine = [CALayer layer];
    quarterLine.backgroundColor = [[UIColor alloc] initWithWhite:0.4 alpha:0.3].CGColor;
    quarterLine.frame = CGRectMake(seconds * _xScale, _chartContainer.bounds.origin.y + _chartLabelHeight, 1, _chartContainer.bounds.size.height);
    
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(seconds * _xScale + labelBuffer, _chartLabelHeight + _chartContainer.frame.size.height - labelHeight, 40, labelHeight)];
    label.font = secondaryFont;
    label.textColor = secondaryColor;
    label.shadowColor = [UIColor blackColor];
    label.shadowOffset = CGSizeMake(1, 1);
    
    switch (i) {
      case 0:
        label.text = @"1st";
        break;
      case 1:
        label.text = @"2nd";
        break;
      case 2:
        label.text = @"3rd";
        break;
      case 3:
        label.text = @"4th";
        break;
      case 4:
        label.text = @"OT";
        break;
      case 5:
        label.text = @"OT2";
        break;
      default:
        break;
    }
    [self addSubview:label];
    [self.layer addSublayer:quarterLine];
  }
}

- (void)drawTeamLabels
{
  UIColor *teamTextColor = [[UIColor alloc] initWithWhite:1 alpha:0.85];
  UIFont *teamFont = [UIFont fontWithName:@"AvenirNext-Medium" size:14];
  CGRect upperRect = CGRectMake(0, 0, self.frame.size.width, _chartLabelHeight);
  CGRect lowerRect = CGRectMake(0, self.bounds.size.height - _chartLabelHeight, self.frame.size.width, _chartLabelHeight);
  
  NSString *homeTeamText = [NSString stringWithFormat:@"%@ Lead", [_homeTeamName capitalizedString]];
  NSString *awayTeamText = [NSString stringWithFormat:@"%@ Lead", [_awayTeamName capitalizedString]];
  NSString *upperUnitText = [NSString stringWithFormat:@"%.f pts.", _maxY];
  NSString *lowerUnitText = [NSString stringWithFormat:@"%.f pts.", fabs(_minY)];
  
  
  float upperWidth = [homeTeamText boundingRectWithSize:upperRect.size
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:@{ NSFontAttributeName:teamFont }
                                                context:nil].size.width;
  
  float lowerWidth = [awayTeamText boundingRectWithSize:lowerRect.size
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:@{ NSFontAttributeName:teamFont }
                                                context:nil].size.width;
  
  UILabel* homeLabel = [[UILabel alloc] initWithFrame:CGRectMake((self.bounds.size.width - upperWidth) / 2, 0, upperWidth, _chartLabelHeight)];
  UILabel* awayLabel = [[UILabel alloc] initWithFrame:CGRectMake((self.bounds.size.width - lowerWidth) / 2, self.bounds.size.height - _chartLabelHeight, lowerWidth, _chartLabelHeight)];
  UILabel* upperUnitRightLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.bounds.size.width - 48, 0, 44, _chartLabelHeight)];
  UILabel* lowerUnitRightLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.bounds.size.width - 48, self.bounds.size.height - _chartLabelHeight, 44, _chartLabelHeight)];
  UILabel* upperUnitLeftLabel = [[UILabel alloc] initWithFrame:CGRectMake(4, 0, 44, _chartLabelHeight)];
  UILabel* lowerUnitLeftLabel = [[UILabel alloc] initWithFrame:CGRectMake(4, self.bounds.size.height - _chartLabelHeight, 44, _chartLabelHeight)];
  
  
  homeLabel.text = homeTeamText;
  awayLabel.text = awayTeamText;
  homeLabel.font = teamFont;
  awayLabel.font = teamFont;
  homeLabel.textColor = teamTextColor;
  awayLabel.textColor = teamTextColor;
  homeLabel.shadowColor = [UIColor blackColor];
  awayLabel.shadowColor = [UIColor blackColor];
  homeLabel.shadowOffset = CGSizeMake(1, 1);
  awayLabel.shadowOffset = CGSizeMake(1, 1);
  
  upperUnitRightLabel.text = upperUnitText;
  upperUnitLeftLabel.text = upperUnitText;
  lowerUnitRightLabel.text = lowerUnitText;
  lowerUnitLeftLabel.text = lowerUnitText;
  upperUnitRightLabel.font = teamFont;
  upperUnitLeftLabel.font = teamFont;
  lowerUnitRightLabel.font = teamFont;
  lowerUnitLeftLabel.font = teamFont;
  upperUnitRightLabel.textColor = teamTextColor;
  upperUnitLeftLabel.textColor = teamTextColor;
  lowerUnitRightLabel.textColor = teamTextColor;
  lowerUnitLeftLabel.textColor = teamTextColor;
  upperUnitRightLabel.shadowColor = [UIColor blackColor];
  upperUnitLeftLabel.shadowColor = [UIColor blackColor];
  lowerUnitRightLabel.shadowColor = [UIColor blackColor];
  lowerUnitLeftLabel.shadowColor = [UIColor blackColor];
  upperUnitRightLabel.shadowOffset = CGSizeMake(1, 1);
  upperUnitLeftLabel.shadowOffset = CGSizeMake(1, 1);
  lowerUnitRightLabel.shadowOffset = CGSizeMake(1, 1);
  lowerUnitLeftLabel.shadowOffset = CGSizeMake(1, 1);
  upperUnitRightLabel.textAlignment = NSTextAlignmentRight;
  upperUnitLeftLabel.textAlignment = NSTextAlignmentLeft;
  lowerUnitRightLabel.textAlignment = NSTextAlignmentRight;
  lowerUnitLeftLabel.textAlignment = NSTextAlignmentLeft;
  
  [self addSubview:homeLabel];
  [self addSubview:awayLabel];
  [self addSubview:upperUnitRightLabel];
  [self addSubview:upperUnitLeftLabel];
  [self addSubview:lowerUnitRightLabel];
  [self addSubview:lowerUnitLeftLabel];
  
}

- (void)computeBounds
{
  _minX = MAXFLOAT;
  _maxX = -MAXFLOAT;
  _minY = MAXFLOAT;
  _maxY = -MAXFLOAT;
  
  _chartContainer = [[UIView alloc] initWithFrame:CGRectMake(self.bounds.origin.x, self.bounds.origin.y + _chartLabelHeight, self.bounds.size.width, self.bounds.size.height - (2*_chartLabelHeight))];
  
  for (int i = 0; i < _xCoords.count; i++) {
    NSNumber* xCoord = _xCoords[i];
    NSNumber* yCoord = _yCoords[i];
    xCoord.floatValue < _minX ? _minX = xCoord.floatValue : true;
    xCoord.floatValue > _maxX ? _maxX = xCoord.floatValue : true;
    yCoord.floatValue < _minY ? _minY = yCoord.floatValue : true;
    yCoord.floatValue > _maxY ? _maxY = yCoord.floatValue : true;
    
  }
  
  _xScale = _chartContainer.frame.size.width / (_maxX - _minX);
  _yScale = _chartContainer.frame.size.height / (_maxY - _minY);
  
  NSMutableArray *restXCoords = [[NSMutableArray alloc] init];
  NSMutableArray *upperYCoords = [[NSMutableArray alloc] init];
  NSMutableArray *lowerYCoords = [[NSMutableArray alloc] init];
  
  [restXCoords addObjectsFromArray:_xCoords];
  [restXCoords addObject:[NSNumber numberWithFloat:_maxX]];
  [restXCoords addObject:[NSNumber numberWithFloat:_minX]];
  
  [upperYCoords addObjectsFromArray:_yCoords];
  [upperYCoords addObject:[NSNumber numberWithFloat:_maxY]];
  [upperYCoords addObject:[NSNumber numberWithFloat:_maxY]];
  
  [lowerYCoords addObjectsFromArray:_yCoords];
  [lowerYCoords addObject:[NSNumber numberWithFloat:_minY]];
  [lowerYCoords addObject:[NSNumber numberWithFloat:_minY]];
  
  _restXCoords = restXCoords;
  _upperYCoords = upperYCoords;
  _lowerYCoords = lowerYCoords;
  
  [self addSubview:_chartContainer];
  
}

- (UIBezierPath*)generateLinePath:(NSArray*)xCoords yCoords:(NSArray*)yCoords
{
  UIBezierPath* path = [UIBezierPath bezierPath];
  
  for (int i = 0; i < xCoords.count; i++) {
    CGPoint controlPoint[2];
    CGFloat smoothing = _smoothingBuffer * _xScale / 1.25;
    CGPoint p = [self pointForIndex:i xCoords:xCoords yCoords:yCoords];
    
    if (i == 0) {
      [path moveToPoint:[self pointForIndex:0 xCoords:xCoords yCoords:yCoords]];
      continue;
    }
    
    CGPoint prevPoint = [self pointForIndex:i-1 xCoords:xCoords yCoords:yCoords];
    
    controlPoint[0] = prevPoint;
    if (controlPoint[0].x + smoothing <= p.x) {
      controlPoint[0].x += smoothing;
    } else {
      controlPoint[0].x = p.x;
    }
    controlPoint[1] = [self pointForIndex:i xCoords:xCoords yCoords:yCoords];
    if (controlPoint[1].x - smoothing >= prevPoint.x) {
      controlPoint[1].x -= smoothing;
    } else {
      controlPoint[1].x = prevPoint.x;
    }
    [path addCurveToPoint:p controlPoint1:controlPoint[0] controlPoint2:controlPoint[1]];
    
  }
  return path;
}

- (CGPoint)pointForIndex:(int)index xCoords:(NSArray*)xCoords yCoords:(NSArray*)yCoords
{
  NSNumber *xNum = xCoords[index];
  NSNumber *yNum = yCoords[index];
  CGFloat xCoord = xNum.floatValue;
  CGFloat yCoord = yNum.floatValue;
  CGFloat chartEndAdjustment = 0;
  
  if(yCoord == _maxY)
    chartEndAdjustment = (_lineWidth / 2);
  if(yCoord == _minY)
    chartEndAdjustment = -(_lineWidth / 2);
  
  return CGPointMake(xCoord * _xScale, _chartContainer.frame.size.height + chartEndAdjustment - (yCoord - _minY) * _yScale);
  
}

// Return distance between two points
static float distance (CGPoint p1, CGPoint p2)
{
  float dx = p2.x - p1.x;
  float dy = p2.y - p1.y;
  
  return sqrt(dx*dx + dy*dy);
}

//compute path length
-(CGFloat)pathRatio:(NSArray*)xCoords yCoords:(NSArray*)yCoords longerXCoords:(NSArray*)longerXCoords longerYCoords:(NSArray*)longerYCoords
{
  CGFloat length = 0;
  CGFloat longerLength = 0;
  CGFloat dist = 0;
  
  for(int i = 1; i < longerXCoords.count; i++) {
    dist = distance([self pointForIndex:i xCoords:longerXCoords yCoords:longerYCoords], [self pointForIndex:i-1 xCoords:longerXCoords yCoords:longerYCoords]);
    longerLength += dist;
    if (i < xCoords.count)
      length += dist;
  }
  return length / longerLength;
}

- (void)animationDidStart:(CAAnimation *)anim
{
  NSString* value = [anim valueForKey:@"animationType"];
  if ([value isEqual:@"momentAnimation"]) {
    NSString* indexString = [anim valueForKey:@"momentIndex"];
    NSString* isActive = [anim valueForKey:@"isActive"];
    int index = [indexString intValue];
    CAShapeLayer *layer = _momentLayers[index];
    CAShapeLayer *activeLayer = _activeLayers[index];
    if ([isActive isEqual:@"yes"]) {
      activeLayer.opacity = 1;
    } else {
      layer.opacity = 1;
    }
  }
}
//
//- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
//{
//  NSString* value = [anim valueForKey:@"animationType"];
//}

//touch events
- (NSInteger)closestIndexToTouchPoint:(CGPoint)touchPoint centerPoint:(CGPoint *)center
{
  CGFloat touchRadius = 50;
  NSInteger closestIndex = 0;
  CAShapeLayer *closestPoint = _momentLayers[closestIndex];
  CGPoint centerPoint = CGPointMake(closestPoint.frame.origin.x + closestPoint.frame.size.width / 2, closestPoint.frame.origin.y + closestPoint.frame.size.height / 2);
  *center = CGPointMake(closestPoint.bounds.origin.x + closestPoint.bounds.size.width / 2, closestPoint.bounds.origin.y + closestPoint.bounds.size.height / 2);
  CGFloat closestDistance = distance(centerPoint, touchPoint);
  
  for (int i = 1; i < _momentLayers.count; i++) {
    CAShapeLayer *tempPoint = _momentLayers[i];
    CGPoint tempCenter = CGPointMake(tempPoint.frame.origin.x + tempPoint.frame.size.width / 2, tempPoint.frame.origin.y + tempPoint.frame.size.height / 2);
    CGFloat tempDistance = distance(tempCenter, touchPoint);
    if (tempDistance < closestDistance) {
      closestDistance = tempDistance;
      closestIndex = i;
      *center = CGPointMake(tempPoint.bounds.origin.x + tempPoint.bounds.size.width / 2, tempPoint.bounds.origin.y + tempPoint.bounds.size.height / 2);;
    }
  }
  if(closestDistance < touchRadius) {
    return closestIndex;
  } else {
    return -1;
  }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  UITouch *aTouch = [touches anyObject];
  CGPoint point = [aTouch locationInView:self];
  CGPoint centerPoint = CGPointZero;
  
  NSInteger momentIndex = [self closestIndexToTouchPoint:point centerPoint:&centerPoint];
  
  [_eventDispatcher sendInputEventWithName:ChartTouchStarted body:@{
                                                                    @"closestMomentIndex": [NSNumber numberWithInteger:momentIndex],
                                                                    @"x": [NSNumber numberWithFloat:centerPoint.x],
                                                                    @"y": [NSNumber numberWithFloat:centerPoint.y],
                                                                    @"target": self.reactTag
                                                                    }];
  
  [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  [self touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
  UITouch *aTouch = [touches anyObject];
  CGPoint point = [aTouch locationInView:self];
  CGPoint centerPoint = CGPointZero;
  
  
  NSInteger momentIndex = [self closestIndexToTouchPoint:point centerPoint:&centerPoint];
  [_eventDispatcher sendInputEventWithName:ChartTouchEnded body:@{
                                                                  @"closestMomentIndex": [NSNumber numberWithInteger:momentIndex],
                                                                  @"target": self.reactTag
                                                                  }];
  [super touchesEnded:touches withEvent:event];
  
}


@end

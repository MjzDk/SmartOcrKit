//
//  OverView.m
//  TestCamera
//

#import "SmartOCROverView.h"
#import <CoreText/CoreText.h>

@implementation SmartOCROverView{
    CGRect _smallRect;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}

- (void)setSmallrect:(CGRect)smallrect{
    _smallRect = smallrect;
    [self setNeedsDisplay];
    
}

- (void) drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    [[UIColor greenColor] set];
    //获得当前画布区域
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    //设置线的宽度
    CGContextSetLineWidth(currentContext, 2.0f);
    
    CGContextMoveToPoint(currentContext, CGRectGetMinX(_smallRect), CGRectGetMinY(_smallRect));
    CGContextAddLineToPoint(currentContext, CGRectGetMaxX(_smallRect), CGRectGetMinY(_smallRect));
    CGContextAddLineToPoint(currentContext, CGRectGetMaxX(_smallRect), CGRectGetMaxY(_smallRect));
    CGContextAddLineToPoint(currentContext, CGRectGetMinX(_smallRect), CGRectGetMaxY(_smallRect));
    CGContextAddLineToPoint(currentContext, CGRectGetMinX(_smallRect), CGRectGetMinY(_smallRect));

    
    CGContextStrokePath(currentContext);
}


/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect {
 // Drawing code
 }
 */

@end

//
//  NSBundle+Current.m
//  AFNetworking
//
//  Created by mini on 2019/3/11.
//

#import "NSBundle+OCR.h"
#import "OCRClass.h"
@implementation NSBundle (ORC)
+ (NSBundle * )ocrBundle {
    NSBundle *bundle = [NSBundle bundleForClass:[OCRClass class]];
    
    NSURL *url = [bundle URLForResource:@"SmartOcrKit" withExtension:@"bundle"];
    
    return [NSBundle bundleWithURL:url];
}
@end

#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  LKS_CustomDisplayItemsMaker.m
//  LookinServer
//
//  Created by likai.123 on 2023/11/1.
//

#import "LKS_CustomDisplayItemsMaker.h"
#import "CALayer+LookinServer.h"
#import "LookinDisplayItem.h"
#import "NSArray+Lookin.h"
#import "LKS_CustomAttrGroupsMaker.h"
#import <math.h>

@interface LKS_CustomDisplayItemsMaker ()

@property(nonatomic, weak) CALayer *layer;
@property(nonatomic, assign) BOOL saveAttrSetter;
@property(nonatomic, strong) NSMutableArray *allSubitems;
@property(nonatomic, strong) UIImage *windowScreenshot;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *swiftUISnapshotCandidates;

- (NSArray<NSDictionary<NSString *, id> *> *)swiftUISnapshotCandidatesFromRawArray:(NSArray *)rawArray;
- (NSArray<NSValue *> *)exclusionFrameValuesForSwiftUINodeWithIdentifier:(NSString *)semanticIdentifier
                                                               frameValue:(NSValue *)frameValue;
- (UIImage *)screenshotForFrameValue:(NSValue *)frameValue
                 excludingFrameValues:(NSArray<NSValue *> *)excludingFrameValues;

@end

@implementation LKS_CustomDisplayItemsMaker

- (instancetype)initWithLayer:(CALayer *)layer saveAttrSetter:(BOOL)saveAttrSetter {
    if (self = [super init]) {
        self.layer = layer;
        self.saveAttrSetter = saveAttrSetter;
        self.allSubitems = [NSMutableArray array];
    }
    return self;
}

- (NSArray<LookinDisplayItem *> *)make {
    if (!self.layer) {
        NSAssert(NO, @"");
        return nil;
    }
    NSMutableArray<NSString *> *selectors = [NSMutableArray array];
    [selectors addObject:@"lookin_customDebugInfos"];
    for (int i = 0; i < 5; i++) {
        [selectors addObject:[NSString stringWithFormat:@"lookin_customDebugInfos_%@", @(i)]];
    }
    
    for (NSString *name in selectors) {
        [self makeSubitemsForViewOrLayer:self.layer selectorName:name];
        
        UIView *view = self.layer.lks_hostView;
        if (view) {
            [self makeSubitemsForViewOrLayer:view selectorName:name];
        }
    }
    
    if (self.allSubitems.count) {
        return self.allSubitems;
    } else {
        return nil;
    }
}

- (void)makeSubitemsForViewOrLayer:(id)viewOrLayer selectorName:(NSString *)selectorName {
    if (!viewOrLayer || !selectorName.length) {
        return;
    }
    if (![viewOrLayer isKindOfClass:[UIView class]] && ![viewOrLayer isKindOfClass:[CALayer class]]) {
        return;
    }
    SEL selector = NSSelectorFromString(selectorName);
    if (![viewOrLayer respondsToSelector:selector]) {
        return;
    }
    NSMethodSignature *signature = [viewOrLayer methodSignatureForSelector:selector];
    if (signature.numberOfArguments > 2) {
        NSAssert(NO, @"LookinServer - There should be no explicit parameters.");
        return;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:viewOrLayer];
    [invocation setSelector:selector];
    [invocation invoke];
    
    // 小心这里的内存管理
    NSDictionary<NSString *, id> * __unsafe_unretained tempRawData;
    [invocation getReturnValue:&tempRawData];
    NSDictionary<NSString *, id> *rawData = tempRawData;
    
    [self makeSubitemsFromRawData:rawData];
}

- (void)makeSubitemsFromRawData:(NSDictionary<NSString *, id> *)data {
    if (!data || ![data isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSArray *rawSubviews = data[@"subviews"];
    self.swiftUISnapshotCandidates = [self swiftUISnapshotCandidatesFromRawArray:rawSubviews];
    NSArray<LookinDisplayItem *> *newSubitems = [self displayItemsFromRawArray:rawSubviews];
    if (newSubitems) {
        [self.allSubitems addObjectsFromArray:newSubitems];
    }
}

- (NSArray<LookinDisplayItem *> *)displayItemsFromRawArray:(NSArray<NSDictionary *> *)rawArray {
    if (!rawArray || ![rawArray isKindOfClass:[NSArray class]]) {
        return nil;
    }
    NSArray *items = [rawArray lookin_map:^id(NSUInteger idx, NSDictionary *rawDict) {
        if (![rawDict isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        return [self displayItemFromRawDict:rawDict];
    }];
    return items;
}

- (LookinDisplayItem *)displayItemFromRawDict:(NSDictionary<NSString *, id> *)dict {
    NSString *title = dict[@"title"];
    NSString *subtitle = dict[@"subtitle"];
    NSValue *frameValue = dict[@"frameInWindow"];
    NSArray *properties = dict[@"properties"];
    NSArray *subviews = dict[@"subviews"];
    NSString *danceSource = dict[@"lookin_source"];
    NSString *semanticKind = dict[@"semanticKind"];
    NSString *semanticIdentifier = dict[@"semanticIdentifier"];
    
    if (![title isKindOfClass:[NSString class]]) {
        return nil;
    }
    LookinDisplayItem *newItem = [LookinDisplayItem new];
    if (subviews && [subviews isKindOfClass:[NSArray class]]) {
        newItem.subitems = [self displayItemsFromRawArray:subviews];
    }
    newItem.isHidden = NO;
    newItem.alpha = 1.0;
    newItem.customInfo = [LookinCustomDisplayItemInfo new];
    newItem.customInfo.title = title;
    newItem.customInfo.subtitle = subtitle;
    newItem.customInfo.frameInWindow = frameValue;
    newItem.customInfo.danceuiSource = danceSource;
    if ([semanticKind isKindOfClass:[NSString class]]) {
        newItem.customInfo.semanticKind = semanticKind;
    }
    if ([semanticIdentifier isKindOfClass:[NSString class]]) {
        newItem.customInfo.semanticIdentifier = semanticIdentifier;
    }
    if ([semanticKind isEqualToString:@"swiftui-node"]) {
        UIImage *groupScreenshot = [self screenshotForFrameValue:frameValue];
        NSArray<NSValue *> *exclusionFrameValues =
            [self exclusionFrameValuesForSwiftUINodeWithIdentifier:semanticIdentifier frameValue:frameValue];
        UIImage *soloScreenshot = [self screenshotForFrameValue:frameValue
                                            excludingFrameValues:exclusionFrameValues];
        if (groupScreenshot || soloScreenshot) {
            newItem.soloScreenshot = soloScreenshot ?: groupScreenshot;
            newItem.groupScreenshot = groupScreenshot ?: soloScreenshot;
            newItem.screenshotEncodeType = LookinDisplayItemImageEncodeTypeNSData;
        }
    }
    newItem.customAttrGroupList = [LKS_CustomAttrGroupsMaker makeGroupsFromRawProperties:properties saveCustomSetter:self.saveAttrSetter];
    
    return newItem;
}

- (NSArray<NSDictionary<NSString *, id> *> *)swiftUISnapshotCandidatesFromRawArray:(NSArray *)rawArray {
    if (![rawArray isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *dict in rawArray) {
        if (![dict isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *semanticKind = dict[@"semanticKind"];
        NSString *semanticIdentifier = dict[@"semanticIdentifier"];
        NSValue *frameValue = dict[@"frameInWindow"];
        if ([semanticKind isEqualToString:@"swiftui-node"] &&
            [semanticIdentifier isKindOfClass:[NSString class]] &&
            [frameValue isKindOfClass:[NSValue class]]) {
            [result addObject:@{
                @"semanticIdentifier": semanticIdentifier,
                @"frameInWindow": frameValue,
            }];
        }
        [result addObjectsFromArray:[self swiftUISnapshotCandidatesFromRawArray:dict[@"subviews"]]];
    }
    return result;
}

- (NSArray<NSValue *> *)exclusionFrameValuesForSwiftUINodeWithIdentifier:(NSString *)semanticIdentifier
                                                               frameValue:(NSValue *)frameValue {
    if (![semanticIdentifier isKindOfClass:[NSString class]] ||
        ![frameValue isKindOfClass:[NSValue class]]) {
        return @[];
    }
    CGRect frame = CGRectStandardize(frameValue.CGRectValue);
    CGFloat frameArea = CGRectGetWidth(frame) * CGRectGetHeight(frame);
    if (CGRectIsNull(frame) || CGRectIsEmpty(frame) || !isfinite(frameArea) || frameArea <= 0) {
        return @[];
    }

    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *candidate in self.swiftUISnapshotCandidates) {
        if ([candidate[@"semanticIdentifier"] isEqualToString:semanticIdentifier]) {
            continue;
        }
        NSValue *candidateFrameValue = candidate[@"frameInWindow"];
        CGRect candidateFrame = CGRectStandardize(candidateFrameValue.CGRectValue);
        CGFloat candidateArea = CGRectGetWidth(candidateFrame) * CGRectGetHeight(candidateFrame);
        if (CGRectIsNull(candidateFrame) || CGRectIsEmpty(candidateFrame) ||
            !isfinite(candidateArea) || candidateArea <= 0) {
            continue;
        }
        CGRect overlap = CGRectIntersection(frame, candidateFrame);
        if (!CGRectIsNull(overlap) && !CGRectIsEmpty(overlap) && candidateArea <= frameArea) {
            [result addObject:candidateFrameValue];
        }
    }
    return result;
}

- (UIImage *)screenshotForFrameValue:(NSValue *)frameValue {
    return [self screenshotForFrameValue:frameValue excludingFrameValues:@[]];
}

- (UIImage *)screenshotForFrameValue:(NSValue *)frameValue
                 excludingFrameValues:(NSArray<NSValue *> *)excludingFrameValues {
    if (![frameValue isKindOfClass:[NSValue class]]) {
        return nil;
    }
    UIWindow *window = self.layer.lks_hostView.window;
    if (!window) {
        return nil;
    }
    if (!self.windowScreenshot) {
        self.windowScreenshot = [window.layer lks_groupScreenshotWithLowQuality:YES];
    }
    CGImageRef sourceImage = self.windowScreenshot.CGImage;
    CGRect windowBounds = window.bounds;
    CGRect frame = CGRectIntersection(CGRectStandardize(frameValue.CGRectValue), windowBounds);
    if (!sourceImage || CGRectIsNull(frame) || CGRectIsEmpty(frame)) {
        return nil;
    }

    CGFloat scaleX = CGImageGetWidth(sourceImage) / CGRectGetWidth(windowBounds);
    CGFloat scaleY = CGImageGetHeight(sourceImage) / CGRectGetHeight(windowBounds);
    CGRect pixelRect = CGRectMake(
        (CGRectGetMinX(frame) - CGRectGetMinX(windowBounds)) * scaleX,
        (CGRectGetMinY(frame) - CGRectGetMinY(windowBounds)) * scaleY,
        CGRectGetWidth(frame) * scaleX,
        CGRectGetHeight(frame) * scaleY
    );
    pixelRect = CGRectIntersection(
        CGRectIntegral(pixelRect),
        CGRectMake(0, 0, CGImageGetWidth(sourceImage), CGImageGetHeight(sourceImage))
    );
    if (CGRectIsNull(pixelRect) || CGRectIsEmpty(pixelRect)) {
        return nil;
    }

    CGImageRef croppedImage = CGImageCreateWithImageInRect(sourceImage, pixelRect);
    if (!croppedImage) {
        return nil;
    }
    UIImage *result = [UIImage imageWithCGImage:croppedImage
                                         scale:self.windowScreenshot.scale
                                   orientation:self.windowScreenshot.imageOrientation];
    CGImageRelease(croppedImage);
    if (!excludingFrameValues.count) {
        return result;
    }

    UIGraphicsBeginImageContextWithOptions(result.size, NO, result.scale);
    [result drawAtPoint:CGPointZero];
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(context, kCGBlendModeClear);
    for (NSValue *excludedFrameValue in excludingFrameValues) {
        if (![excludedFrameValue isKindOfClass:[NSValue class]]) {
            continue;
        }
        CGRect overlap = CGRectIntersection(frame, CGRectStandardize(excludedFrameValue.CGRectValue));
        if (CGRectIsNull(overlap) || CGRectIsEmpty(overlap)) {
            continue;
        }
        CGRect localRect = CGRectOffset(overlap, -CGRectGetMinX(frame), -CGRectGetMinY(frame));
        CGContextFillRect(context, localRect);
    }
    UIImage *maskedResult = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return maskedResult ?: result;
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */

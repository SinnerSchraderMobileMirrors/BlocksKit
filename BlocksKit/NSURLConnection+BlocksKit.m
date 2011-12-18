//
//  NSURLConnection+BlocksKit.m
//  BlocksKit
//

#import "NSURLConnection+BlocksKit.h"
#import "NSObject+AssociatedObjects.h"
#import "A2BlockDelegate+BlocksKit.h"
#import <objc/runtime.h>

#pragma mark Private

static char kResponseDataKey;
static char kResponseKey;
static char kResponseLengthKey;

@interface NSURLConnection (BlocksKitPrivate)
@property (nonatomic, retain) NSMutableData *bk_responseData;
@property (nonatomic, retain) NSURLResponse *bk_response;
@property (nonatomic) NSUInteger bk_responseLength;
@end

@implementation NSURLConnection (BlocksKitPrivate)

- (NSMutableData *)bk_responseData {
	return [self associatedValueForKey:&kResponseDataKey];
}

- (void)setBk_responseData:(NSMutableData *)responseData {
	[self associateValue:responseData withKey:&kResponseDataKey];
}

- (NSURLResponse *)bk_response {
	return [self associatedValueForKey:&kResponseKey];
}

- (void)setBk_response:(NSURLResponse *)response {
	return [self associateValue:response withKey:&kResponseKey];
}

- (NSUInteger)bk_responseLength {
	return [[self associatedValueForKey:&kResponseLengthKey] unsignedIntegerValue];
}

- (void)setBk_responseLength:(NSUInteger)responseLength {
	NSNumber *value = [NSNumber numberWithUnsignedInteger:responseLength];
	return [self associateValue:value withKey:&kResponseLengthKey];
}

@end

#pragma mark - BKURLConnectionInformalDelegate - iOS 4.3 support

@protocol BKURLConnectionInformalDelegate <NSObject>
@optional
- (BOOL)connection:(NSURLConnection*)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace;
- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection;
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite;
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
@end

@interface A2DynamicBKURLConnectionInformalDelegate : A2DynamicDelegate <BKURLConnectionInformalDelegate>

@end

@implementation A2DynamicBKURLConnectionInformalDelegate

- (BOOL)connection:(NSURLConnection*)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:canAuthenticateAgainstProtectionSpace:)])
        return [connection.delegate connection:connection canAuthenticateAgainstProtectionSpace:protectionSpace];
	
	NSString *authMethod = protectionSpace.authenticationMethod;
	if (authMethod == NSURLAuthenticationMethodServerTrust || authMethod == NSURLAuthenticationMethodClientCertificate)
		return NO;
    return YES;
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didCancelAuthenticationChallenge:)])
        [connection.delegate connection:connection didCancelAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didReceiveAuthenticationChallenge:)])
        [connection.delegate connection:connection didReceiveAuthenticationChallenge:challenge];
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection {
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connectionShouldUseCredentialStorage:)])
        return [connection.delegate connectionShouldUseCredentialStorage:connection];
	
    return YES;   
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:willCacheResponse:)])
        return [connection.delegate connection:connection willCacheResponse:cachedResponse];
    
    return cachedResponse;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:willSendRequest:redirectResponse:)])
        return [connection.delegate connection:connection willSendRequest:request redirectResponse:redirectResponse];
    
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didReceiveResponse:)])
        [connection.delegate connection:connection didReceiveResponse:response];
    
    connection.bk_responseLength = 0;
    [connection.bk_responseData setLength:0];
    
    connection.bk_response = response;
	
	void (^block)(NSURLConnection *, NSURLResponse *) = [self blockImplementationForMethod:_cmd];
	if (block)
		block(connection, response);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didFailWithError:)])
        [connection.delegate connection:connection didFailWithError:error];
	
	connection.bk_responseLength = 0;
	[connection.bk_responseData setLength:0];
	
	void (^block)(NSURLConnection *, NSError *) = [self blockImplementationForMethod:_cmd];
	if (block)
		block(connection, error);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connectionDidFinishLoading:)])
        [connection.delegate connectionDidFinishLoading:connection];
    
    if (!connection.bk_responseData.length)
        connection.bk_responseData = nil;
    
    void(^block)(NSURLConnection *, NSURLResponse *, NSData *) = connection.successBlock;
    if (block)
        block(connection, connection.bk_response, connection.bk_responseData);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    connection.bk_responseLength += data.length;
    
    void (^block)(CGFloat) = connection.downloadBlock;
    if (block && connection.bk_response && connection.bk_response.expectedContentLength != NSURLResponseUnknownLength)
        block((CGFloat)connection.bk_responseLength / (CGFloat)connection.bk_response.expectedContentLength);
	
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didReceiveData:)]) {
        [connection.delegate connection:connection didReceiveData:data];
        return;
    }
    
    NSMutableData *responseData = connection.bk_responseData;
    if (!responseData) {
        responseData = [NSMutableData data];
        connection.bk_responseData = responseData;
    }
    
    [responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:)])
        [connection.delegate connection:connection didSendBodyData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    
    void (^block)(CGFloat) = connection.uploadBlock;
    if (block)
        block((CGFloat)totalBytesWritten/(CGFloat)totalBytesExpectedToWrite);
}

@end

#pragma mark - NSURLConnectionDelegate - iOS 5.0+ support


@interface A2DynamicNSURLConnectionDelegate : A2DynamicDelegate <NSURLConnectionDataDelegate>

@end

@implementation A2DynamicNSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:willSendRequestForAuthenticationChallenge:)])
        [connection.delegate connection:connection willSendRequestForAuthenticationChallenge:challenge];
	else
		[challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:willCacheResponse:)])
        return [connection.delegate connection:connection willCacheResponse:cachedResponse];
    
    return cachedResponse;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:willSendRequest:redirectResponse:)])
        return [connection.delegate connection:connection willSendRequest:request redirectResponse:response];
    
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didReceiveResponse:)])
        [connection.delegate connection:connection didReceiveResponse:response];
    
    connection.bk_responseLength = 0;
    
    if (connection.bk_responseData)
        [connection.bk_responseData setLength:0];
    
    connection.bk_response = response;
	
	void (^block)(NSURLConnection *, NSURLResponse *) = [self blockImplementationForMethod:_cmd];
	if (block)
		block(connection, response);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didFailWithError:)])
        [connection.delegate connection:connection didFailWithError:error];
	
	connection.bk_responseLength = 0;
	[connection.bk_responseData setLength:0];
	
	void (^block)(NSURLConnection *, NSError *) = [self blockImplementationForMethod:_cmd];
	if (block)
		block(connection, error);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if (connection.delegate && [connection.delegate respondsToSelector:@selector(connectionDidFinishLoading:)])
        [connection.delegate connectionDidFinishLoading:connection];
    
    if (!connection.bk_responseData.length)
        connection.bk_responseData = nil;
    
    void(^block)(NSURLConnection *, NSURLResponse *, NSData *) = connection.successBlock;
    if (block)
        block(connection, connection.bk_response, connection.bk_responseData);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    connection.bk_responseLength += data.length;
    
    void (^block)(CGFloat) = connection.downloadBlock;
    if (block && connection.bk_response && connection.bk_response.expectedContentLength != NSURLResponseUnknownLength)
        block((CGFloat)connection.bk_responseLength / (CGFloat)connection.bk_response.expectedContentLength);
	
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didReceiveData:)]) {
        [connection.delegate connection:connection didReceiveData:data];
        return;
    }
    
    NSMutableData *responseData = connection.bk_responseData;
    if (!responseData) {
        responseData = [NSMutableData data];
        connection.bk_responseData = responseData;
    }
    
    [responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if (connection.delegate && [connection.delegate respondsToSelector:@selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:)])
        [connection.delegate connection:connection didSendBodyData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    
    void (^block)(CGFloat) = connection.uploadBlock;
    if (block)
        block((CGFloat)totalBytesWritten/(CGFloat)totalBytesExpectedToWrite);
}

@end

#pragma mark - Category

static NSString *const kSuccessBlockKey = @"NSURLConnectionDidFinishLoading";
static NSString *const kUploadBlockKey = @"NSURLConnectionDidSendData";
static NSString *const kDownloadBlockKey = @"NSURLConnectionDidRecieveData";

@implementation NSURLConnection (BlocksKit)

@dynamic delegate, responseBlock, failureBlock;

+ (void)load {
	@autoreleasepool {
		[self swizzleDelegateProperty];
		[self linkCategoryBlockProperty:@"responseBlock" withDelegateMethod:@selector(connection:didReceiveResponse:)];
		[self linkCategoryBlockProperty:@"failureBlock" withDelegateMethod:@selector(connection:didFailWithError:)];
	}
}

#pragma mark Initializers

+ (NSURLConnection*)connectionWithRequest:(NSURLRequest *)request {
    return BK_AUTORELEASE([[[self class] alloc] initWithRequest:request]);
}

+ (NSURLConnection *)startConnectionWithRequest:(NSURLRequest *)request successHandler:(void(^)(NSURLConnection *, NSURLResponse *, NSData *))success failureHandler:(void(^)(NSURLConnection *, NSError *))failure {
    NSURLConnection *connection = [[[self class] alloc] initWithRequest:request];
    connection.successBlock = success;
    connection.failureBlock = failure;
    [connection start];
    return BK_AUTORELEASE(connection);
}

- (id)initWithRequest:(NSURLRequest *)request {
    return [self initWithRequest:request completionHandler:NULL];
}

- (id)initWithRequest:(NSURLRequest *)request completionHandler:(void(^)(NSURLConnection *, NSURLResponse *, NSData *))block {
	Protocol *delegateProtocol = objc_getProtocol("NSURLConnectionDelegate");
	if (!delegateProtocol)
		delegateProtocol = @protocol(BKURLConnectionInformalDelegate);
    if ((self = [self initWithRequest:request delegate:[self dynamicDelegateForProtocol:delegateProtocol] startImmediately:NO]))
        self.successBlock = block;
    return self;
}

- (void)startWithCompletionBlock:(void(^)(NSURLConnection *, NSURLResponse *, NSData *))block {
    self.successBlock = block;
    [self start];
}

#pragma mark Properties

- (void(^)(NSURLConnection *, NSURLResponse *, NSData *))successBlock {
	return [[self.dynamicDelegate handlers] objectForKey:kSuccessBlockKey];
}

- (void)setSuccessBlock:(void(^)(NSURLConnection *, NSURLResponse *, NSData *))block {
	[[self.dynamicDelegate handlers] setObject:block forKey:kSuccessBlockKey];
}

- (void(^)(CGFloat))uploadBlock {
	return [[self.dynamicDelegate handlers] objectForKey:kUploadBlockKey];
}

- (void)setUploadBlock:(void(^)(CGFloat))block {
	[[self.dynamicDelegate handlers] setObject:block forKey:kUploadBlockKey];
}

- (void(^)(CGFloat))downloadBlock {
	return [[self.dynamicDelegate handlers] objectForKey:kDownloadBlockKey];
}

- (void)setDownloadBlock:(void(^)(CGFloat))block {
	[[self.dynamicDelegate handlers] setObject:block forKey:kDownloadBlockKey];
}

@end
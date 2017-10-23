/**
 * Copyright (c) 2017, Impending
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * @license     Berkeley Software Distribution License (BSD-License 2) http://www.opensource.org/licenses/bsd-license.php
 * @author      Freddie Tilley <freddie.tilley@impending.nl>
 * @copyright   Impending
 * @link        http://www.impending.nl
 */

#import "GopherURLProtocol.h"

#define kDefaultGopherPort 70

@interface GopherURLProtocol () <NSStreamDelegate>

@property(readwrite, retain) NSInputStream *input;
@property(readwrite, retain) NSOutputStream *output;
@property(assign) BOOL hasData;

@end

@implementation GopherURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if ([request.URL.scheme isEqualToString: @"gopher"])
    {
        return YES;
    }
    return NO;
}

+ (BOOL)canInitWithTask:(NSURLSessionTask *)task
{
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSInputStream *inputStream = nil;
    NSOutputStream *outputStream = nil;
    NSInteger port = kDefaultGopherPort;

    if (self.request.URL.port != nil)
    {
        port = [self.request.URL.port integerValue];
    }

    [NSStream getStreamsToHostWithName: self.request.URL.host port: port
                           inputStream: &inputStream
                           outputStream: &outputStream];

    [inputStream setDelegate: self];

    [inputStream scheduleInRunLoop: [NSRunLoop currentRunLoop]
                           forMode: NSDefaultRunLoopMode];
    [inputStream open];
    self.input = inputStream;

    self.hasData = NO;

    [outputStream setDelegate: self];
    [outputStream scheduleInRunLoop: [NSRunLoop currentRunLoop]
                            forMode: NSDefaultRunLoopMode];
    [outputStream open];
    self.output = outputStream;
}

- (void)stopLoading
{
    [self.input removeFromRunLoop: [NSRunLoop currentRunLoop]
                          forMode: NSDefaultRunLoopMode];
    [self.input close];
    self.input = nil;

    [self.output removeFromRunLoop: [NSRunLoop currentRunLoop]
                          forMode: NSDefaultRunLoopMode];
    [self.output close];
    self.output = nil;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode)
    {
        case NSStreamEventHasBytesAvailable:
        {
            uint8_t buffer[512 + 1];
            NSInteger bytesRead = [(NSInputStream*)aStream read: buffer maxLength: 512];

            if (bytesRead < 0)
            {
                [self.client URLProtocol: self didFailWithError: aStream.streamError];
            }

            if (bytesRead > 0)
            {
                if (!self.hasData)
                {
                    NSURLResponse *response = [[NSURLResponse alloc] initWithURL: self.request.URL
                        MIMEType: @"text/plain" expectedContentLength: -1
                        textEncodingName: nil];

                    [self.client URLProtocol: self didReceiveResponse: response
                          cacheStoragePolicy: NSURLCacheStorageAllowed];

                    self.hasData = YES;
                }

                NSData *data = [NSData dataWithBytes: buffer length: bytesRead];

                buffer[bytesRead + 1] = '\0';
                [self.client URLProtocol: self didLoadData: data];
            }
        }
            break;
        case NSStreamEventHasSpaceAvailable:
        {
            NSString *outputString = nil;
            uint8_t *buf = NULL;
            NSUInteger bufLen = 0;

            if (self.request.URL.path.length == 0)
            {
                outputString = @"/\n";
            }
            else
            {
                outputString = [NSString stringWithFormat: @"%@\n", self.request.URL.path];
            }

            bufLen = [outputString lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
            buf = (uint8_t*)[outputString UTF8String];

            NSInteger bytesWritten = [(NSOutputStream*)aStream write: buf maxLength: bufLen];

            if (bytesWritten < 0)
            {
                [self.client URLProtocol: self didFailWithError: aStream.streamError];
            }

            [aStream removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
            [aStream close];
            self.output = nil;
        }
            break;
        case NSStreamEventErrorOccurred:
            [self.client URLProtocol: self didFailWithError: aStream.streamError];
            [aStream removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
            [aStream close];
            break;
        case NSStreamEventEndEncountered:
            [self.client URLProtocolDidFinishLoading: self];
            [aStream removeFromRunLoop: [NSRunLoop currentRunLoop]
                               forMode: NSDefaultRunLoopMode];
            [aStream close];
            self.input = nil;
            break;
        default:
            break;
    }
}

@end
